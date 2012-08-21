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

local environment = require(configuration.environment)
local getenv = environment.getval or {}

local util = require("util")

--counter for the watcher ids
local watcher_counter = util.newCounter()

--list of set-up watchers
--{watcher_id={host,service, _watcher_id, mib, op, value, histeresis, _tracker=co}, ... }
local environment_trackers={}

--returns inrange,mustemit
local function in_out_range(in_range, evval, op, value, hysteresis)
	local evval_n, value_n=tonumber(evval), tonumber(value)
	--print ("==",in_range,mib, evval..op..value, evval_n, value_n,tostring(evval==value), tostring(evval_n==value_n), hysteresis)
			
	if in_range then
		if ((not evval_n or not value_n ) and 
				op=="=" and evval~=value) 
			or
			(evval_n and value_n and ( 
				(op=="=" and (evval_n<value_n-hysteresis or evval_n>value_n+hysteresis)) or
				(op==">" and evval_n<value_n-hysteresis) or
				(op=="<" and evval_n>value_n+hysteresis))) 
		then
			--exiting range, don't return anything
			--print ("saliendo")
			return false, nil
		else
			--stay in range, don't return anything
			--print ("dentro")
			return true, nil
		end			
	else
		--print ("##"..evval..op..value.."##")
		if (op=="=" and evval==value) or
			(evval_n and value_n and ( 
				(op=="=" and evval_n==value_n) or
				(op==">" and evval_n>value_n) or
				(op=="<" and evval_n<value_n))) 
		then
			--entering range, return value
			--print ("entrando")
			--print ("SE CUMPLE QUE : ", evval_n, op, value_n)
			return true, evval_n

		else
			--staying out of range, don't return anything
			--print ("NO SE CUMPLE QUE : ", evval_n, op, value_n)
			return false, nil
		end
	end
end

--function to track an attribute. must be run in a coroutine.
local function value_tracker (params)
	local mib, op, value, hysteresis, timeout = 
        params.mib, params.op, params.value, tonumber(params.hysteresis) or 0, tonumber(params.timeout) or math.huge

print ("---value", mib, op, value, hysteresis, timeout)

	local in_range,ret=false
	local evval
	local ts=os.time()
	local time
	while true do
		evval = getenv[mib](params)

        in_range, ret = in_out_range(in_range, evval, op, value, hysteresis)
        time=os.time()
        if ret or (time-ts > timeout) then
            ts=time
            coroutine.yield(evval)
        else
            coroutine.yield(nil)
        end
	end
end
--function to track a attribute delta. must be run in a coroutine.
local function delta_tracker (params)
	local mib, op, delta, hysteresis, timeout = 
        params.mib, params.op, tonumber(params.delta) or 0, tonumber(params.hysteresis) or 0, 
        tonumber(params.timeout) or math.huge

print ("---delta", mib, op, delta, hysteresis, timeout)

	local in_range,ret=false
	local evval, last_evval, delta_evval
    local ts=os.time()
    local time
	while true do
		evval = tonumber( getenv[mib](params) ) or 0
        delta_evval = evval - (last_evval or evval)
        --print("$$$ Value ", evval, " - is ", delta_evval, op, delta, "?? ")
        last_evval=evval

        in_range, ret = in_out_range(in_range, delta_evval, op, delta, hysteresis)
        --print("$$$ Ret : ", ret)
        time=os.time()
        if ret or (time-ts > timeout) then
            ts=time
            coroutine.yield(evval)
        else
            coroutine.yield(nil)
        end
	end
end
--function to track a attribute delta. must be run in a coroutine.
local function delta_e_tracker (params)
	local mib, op, delta_e, hysteresis, timeout = 
        params.mib, params.op, tonumber(params.delta_e) or 0, tonumber(params.hysteresis) or 0, 
        tonumber(params.timeout) or math.huge

print ("---delta_e", mib, op, delta_e, hysteresis, timeout)

	local in_range,ret=false
	local evval, last_e_evval, delta_evval
    local ts=os.time()
    local time

	evval = tonumber( getenv[mib](params) ) or 0
    last_e_evval=evval
    coroutine.yield(evval)

	while true do
		evval = tonumber( getenv[mib](params) ) or 0
        delta_e_evval = evval - last_e_evval

        in_range, ret = in_out_range(in_range, delta_e_evval, op, delta_e, hysteresis)
        time=os.time()
        if ret or (time-ts > timeout) then
            ts=time
            last_e_evval=evval
            coroutine.yield(evval)
        else
            coroutine.yield(nil)
        end
	end
end


--adds a watcher to a attribute
function register_watcher(parameters)
	--local mib, op, value, histeresis = params.mib, params.op, params.value, params.hysteresis or 0
	
	--local watcher_id = configuration.my_name .. "watcher" .. watcher_counter()
	local watcher_id = parameters.watcher_id or configuration.my_host .. "_watcher_" .. watcher_counter()
	
    local co
    if parameters.value then
	    co = coroutine.create(function ()
	        value_tracker(parameters)
	    end)
    elseif parameters.delta then
	    co = coroutine.create(function ()
	        delta_tracker(parameters)
	    end)
    elseif parameters.delta_e then
	    co = coroutine.create(function ()
	        delta_e_tracker(parameters)
	    end)
    else
        return nil, "malformed watcher request"
    end
	parameters._tracker=co
	parameters._watcher_id=watcher_id
	--table.insert(environment_trackers, parameters)
	environment_trackers[watcher_id]=parameters
	return watcher_id
end

--iterates the watchers list, evaluates and returns the list of actives
function generate_traps()
	local ok,val
	local traps = {}
	environment.purge_cache()
	for watcher_id, watcher in pairs (environment_trackers) do
		--print ("--------------------------------------", watcher_id)
		ok,val = coroutine.resume(watcher._tracker)
		if not ok then
			print ("Error resuming watcher",  val)
		else
			--print ("OK",  val)
			if val	then
                print ("+++", watcher_id, val)
				table.insert(traps, 
					{host=watcher.host, service=watcher.service, 
					watcher_id=watcher._watcher_id, mib=watcher.mib, value=val})
			end
		end
	end
	return traps
end



commands = {}
commands["watch_mib"] = function (params)
	--local mib, op, value, histeresis = params.mib, params.op, params.value, params.hysteresis or 0
	local mib = params.mib
	--print ("##",host,service, mib, op, value, histeresis)
	
	if getenv[mib] then
		local wid, err = register_watcher(params)
		--util.simple_serialize(params)
        if wid then
    		return {status = "ok", watcher_id=wid}
        else
            print ("Error", err)
    		return {status = err}
        end
	else
		return {status = "mib not supported"}
	end
end

commands["remove_watcher"] = function (params)
	local wid=params.watcher_id
	if wid and environment_trackers[wid] then
		environment_trackers[wid]=nil
		return {status = "ok", watcher_id=wid}
	end
end

