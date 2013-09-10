#!/usr/bin/lua
--[[

 Copyright 2008 MINA Group, Facultad de Ingenieria, Universidad de la
Republica, Uruguay.

 This file is part of the RAN System.

    The RAN System is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    The RAN System is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the RAN System.  If not, see <http://www.gnu.org/licenses/>.

--]]

module(..., package.seeall);

local socket=require('socket')
local gettime=socket.gettime

local list = require("list")
local List=list.List

local table_insert=table.insert

local configuration = require("configuration")
local pdp_window_size=configuration.pdp_window_size
local max_events_in_window=configuration.max_events_in_window

local window_moved = false

--event window
--pending_events={ {event,ts} ...}
local pending_events=List.new()

local fsm_box = require("fsm_box")
local fsm_env = fsm_box.env

--window copy for fsm, as an array. prepended happening_events.
--{ {event=e, ts=arrived_ts}, ...}
local window = {}
fsm_env.window = window

--state maintaining events, exported into fsm and administered in there.
--{event,...}
fsm_env.happening_events = {}

local function evaluate_in_box(call)
--print ("#evaluate_in_box", call)	
	--the incomming fsm should provide the function
	if not call then 
		print ("Error: function not in box", call)
		return nil, 'function not in box '..tostring(call)
	end

	--local pending_events_processed = create_processed_window()
	--fsm_env.window = pending_events_processed  --publish the window in the fsm
  local function process_output(ok, ...)
    if ok then
      return ...
    else
      print("Error evaluating fsm",...) end
    return nil, ...
  end
	return process_output(pcall (call))
end

--borra eventos caducos por la izq. omitiendo happenings
local function maintain_window(w)
 	local ts_cutout=gettime()-pdp_window_size
  local moved = false
  for i=1, #w do
    local e = w[i]
    if not fsm_env.happening_events[e] and (tonumber(e.ts) > ts_cutout or #w>max_events_in_window) then
      moved = true
      table.remove(w, i)
    end
  end
  return moved
end


local function step_window()
  local moved = maintain_window(window)
   
	if moved then
    evaluate_in_box(fsm_env.reset)
  end
    
  local ret = {}
  local stalled = false
  repeat
		local notifs, waiting, final = evaluate_in_box(fsm_env.step)
    if final then
      --step deberia sacar todo lo reconocido
      for _, v in ipairs(notifs) do ret[#ret+1] = v end
      evaluate_in_box(fsm_env.reset)
    elseif not waiting then
      --sacar el primero no happening
      stalled = true
      for i=1, #window do
        local e = window[i]
        if not fsm_env.happening_events[e] then
          table.remove(window, i)
          stalled = false
          break
        end
      end
      evaluate_in_box(fsm_env.reset)
    end  
  until waiting or stalled
    
  return ret
end

function incomming_event(data)
	if not fsm_env.step then return {} end
print ("#incomming_event",  data.watcher_id)
  
	window[#window+1] = {event=data, ts=gettime()}
  
  return step_window()
end

function tick()
	--if window empty, or no fsm, skip
	if not fsm_env.step or #window==0 then return {} end
	
  return step_window()
end

commands = {}
--returns the answer to be sent by the command caller, 
--and the resulting list from calling initialize
commands["set_fsm"] = function (params)
	local fsm = params.fsm
	
	local runproc, err = loadstring (fsm)
	if not runproc then
		print ("Error loading",err)
		return {status = tostring(err)}		
	end
	
	setfenv (runproc, fsm_env)       
	local ret = assert(runproc)()
	
	local outgoing_s, outgoing_n = evaluate_in_box(fsm_env.initialize)
	
	return {status = "ok", ret=tostring(ret)}, outgoing_s, outgoing_n
end

commands["set_fsm_file"] = function (params)
	--local fsm = params.fsm
	local fsm_name = params.fsm_name
	if not fsm_name then
	    print ("Error opening huge FSM")
	    return {status = "error, huge fsm has nil location"}
	end
	local f = assert(io.open(fsm_name, "r"))
	local fsm = f:read("*all")
	f:close()
	
	--local runproc, err = loadstring (fsm, fsm_name)
	local runproc, err = loadfile (fsm)
	if not runproc then
		print ("Error loading",err)
		return {status = tostring(err)}		
	end
	
	setfenv (runproc, fsm_env)       
	local ret = assert(runproc)()
	
	local outgoing_s, outgoing_n = evaluate_in_box(fsm_env.initialize)

	return {status = "ok", ret=tostring(ret)}, outgoing_s, outgoing_n
end


