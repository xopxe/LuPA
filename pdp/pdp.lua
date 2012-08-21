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
fsm_env.window = {}

--state maintaining events, exported into fsm and administered in there.
--{event,...}
local happening_events = {}
fsm_env.happening_events = happening_events

--Generate a copy of the window with the happening_events inserted
local function create_processed_window()
	local window={}

	--insert events from the happening list
	local oldest_ts
	if pending_events[pending_events.first] then
		oldest_ts=pending_events[pending_events.first].ts
	else
		oldest_ts=gettime()
	end
	for _, e in ipairs(happening_events) do
		table_insert(window, {event=e, ts=oldest_ts} )
	end

	--sort window (happenings) by event watcher_id if available, otherwise by timestamp
	if configuration.pdp_sort_window then
		table.sort(window, function (a,b)
			local wa,wb=a.event.watcher_id, b.event.watcher_id
			if wa and wb then
				return wa < wb
			else
		      		return (a.event.timestamp < b.event.timestamp)
			end
	    	end)
		window_moved = true
	end

	--insert events from the original window	
	for i=pending_events.first, pending_events.last do
		table_insert(window, pending_events[i] )
	end

	return window
end

local function evaluate_in_box(call)
--print ("#evaluate_in_box", call)	
	--the incomming fsm should provide the function
	if not call then 
		print ("Error: function not in box", call)
		return {}
	end

	--local pending_events_processed = create_processed_window()
	--fsm_env.window = pending_events_processed  --publish the window in the fsm
	
	local ok, ret = pcall (call)
	
	if ok and ret then
		return ret
	end
	if not ok then print("Error evaluating fsm",ret)end
	return {}
end


function incomming_event(data)
	if not fsm_env.proccess_window_add then return {} end
print ("#incomming_event",  data.watcher_id)
	local ts_now=gettime()
	List.pushright(pending_events, {event=data, ts=ts_now} )
	--verify window size
	if pending_events.last - pending_events.first < max_events_in_window then
		if pdp_sort_window then
			--regenerate window copy and publish it into fsm
			fsm_env.window = create_processed_window()  
		else
			--insert also into window copy for fsm
			table_insert(fsm_env.window, {event=data, ts=ts_now})
		end

	else
		--window too big, prune
		List.popleft(pending_events)
		window_moved = true
		
		--regenerate window copy and publish it into fsm
		fsm_env.window = create_processed_window()  
	end

	if window_moved then
		window_moved = false
		return evaluate_in_box(fsm_env.proccess_window_move)
	else
		return evaluate_in_box(fsm_env.proccess_window_add)
	end

end

function tick()
	--if window empty, or no fsm, skip
	if pending_events.first>pending_events.last or not fsm_env.proccess_window_move then return {} end
	
	local ts_cutout=gettime()-pdp_window_size
	local ret = {}
	
	while pending_events[pending_events.first] 
			and (tonumber(pending_events[pending_events.first].ts) < ts_cutout) do
		--purge obsolete events from window
		List.popleft(pending_events)

		--regenerate window copy and publish it into fsm
		fsm_env.window = create_processed_window()  

		local ret_call=evaluate_in_box(fsm_env.proccess_window_move)
		--enqueue generated actions
		for _, r in ipairs(ret_call) do
			table_insert(ret, r)
		end
	end
	
	return ret
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
	
	local outgoing=evaluate_in_box(fsm_env.initialize)
	
	return {status = "ok", ret=tostring(ret)}, outgoing or {}
end

