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

--This module reads the device's configuration
module(..., package.seeall);

local util = require("util")
local run_shell = util.run_shell

package.path=package.path .. ";../bobot/?.lua"
local bobot = require("bobot")
local baseboards = bobot.baseboards
local get_device_name=function (n)
	if not devices[n] then return n	end
	local i=2
	local nn=n.."#"..i
	while devices[nn] do
		i=i+1
		nn=n.."#"..i
	end
	return nn
end
local function read_devices_list()
	print("=Listing Devices")
	local bfound
	devices={}
	for b_name, bb in pairs(baseboards) do
	print("===board", b_name)
		for d_name,d in pairs(bb.devices) do
			local regname = get_device_name(d_name)
			devices[regname]=d
			print("=====d_name", d_name, "regname", regname)
		end
		bfound = true
	end
	if not bfound then print ("WARN: No Baseboard found.") end
end

read_devices_list()


function purge_cache()
end

local function check_open_device(d, ep1, ep2)
	if not d then return end
	if d.handler then
		--print ("ls:Already open", d.name, d.handler)
		return true
	else
		print ("ls:Opening", d.name, d.handler)
		return d:open(ep1 or 1, ep2 or 1) --TODO asignacion de ep?
	end
end
local function split_words(s)
	words={}
	for p in string.gmatch(s, "%S+") do
		words[#words+1]=p
	end
	return words
end

commands = {}
commands["LIST"] = function ()
	local ret,comma = "", ""
	for d_name, _ in pairs(devices) do
		ret = ret .. comma .. d_name
		comma=","
	end
	return {value = ret} 
end
commands["OPEN"] = function (parameters)
	local d, ep1, ep2 = parameters.d, tonumber(parameters.ep1), tonumber(parameters.ep2)

	if not d then
		print("ls:Missing 'device' parameter")
		return
	end
	
	local device = devices[d]
	if check_open_device(device, ep1, ep2) then	
		return {value = "ok"} 
	else
		return {value = "fail"} 
	end
end
commands["DESCRIBE"] = function (parameters)
	local d, ep1, ep2 = parameters.d, tonumber(parameters.ep1), tonumber(parameters.ep2)

	if not d then
		print("ls:Missing 'device' parameter")
		return {err = "Missing 'device' parameter"} 
	end
	
	local device = devices[d]
	if not check_open_device(device, ep1, ep2) then	
		return {err = "Failure to open"} 
	end

	local ret = "{"
	for fname, fdef in pairs(device.api) do
		ret = ret .. fname .. "={"
		ret = ret .. " parameters={"
		for i,pars in ipairs(fdef.parameters) do
			ret = ret .. "[" ..i.."]={"
			for k, v in pairs(pars) do
				ret = ret .."[".. k .."]='"..tostring(v).."',"
			end
			ret = ret .. "},"
		end
		ret = ret .. "}, returns={"
		for i,rets in ipairs(fdef.returns) do
			ret = ret .. "[" ..i.."]={"
			for k, v in pairs(rets) do
				ret = ret .."[".. k .."]='"..tostring(v).."',"
			end
			ret = ret .. "},"
		end
		ret = ret .. "}}," 
	end
	ret=ret.."}"

	return {value = ret} 
end
commands["CALL"] = function (parameters)
	local d, call, params =	parameters.device, parameters.call, parameters.call_params
	local words=split_words(params or '')

	if not (d and call) then
		print("ls:Missing parameters", d, call)
		return {err = "Missing parameter"} 
	end

	local device = devices[d]
	if not check_open_device(device, nil, nil) then	
		return {err = "Failure to open"} 
	end

	local api_call=device.api[call];
	
	if api_call and api_call.call then
		local ret = api_call.call(unpack(words))
		return {value = ret} 
	end
end
commands["CLOSEALL"] = function ()
	if baseboards then
		for _, bb in pairs(baseboards) do
			---bb:close_all()
			bb:force_close_all() --modif andrew
		end
	end
	return {value = "ok"} 
end



--Table with querying functions
--getval[evname]=function
getval = {}

--------------------------------------------------------
--Functions for reading attributes


getval["CALL"] = function (parameters)
	local d, call, params =	parameters.device, parameters.call, parameters.call_params
	local words=split_words(params or '')

	if not (d and call) then
		print("ls:Missing parameters", d, call)
		return "Missing parameters"
	end

	local device = devices[d]
	if not check_open_device(device, nil, nil) then	
		return "fail"
	end

	local api_call=device.api[call];
	
	if api_call and api_call.call then
		local ret = api_call.call(unpack(words))
		return ret
	end
end

getval["processes_running"] = function ()
	
	--local res=run_shell("ps -A | wc -l")-2   --minus header and ps line
	local res=run_shell("ps | wc -l")-2   --minus header and ps line
	return res
end

getval["process_running"] = function (parameters)
	local process=parameters.process
	
	local process_s = process --.. "\n"
	
	local _, res = string.gsub(run_shell("ps w"), process_s, process_s)
	return res
end

getval["free_ram"] = function ()
	local res = string.match(run_shell("cat /proc/meminfo"), "MemFree:%s+(%d+)")
	return res
end

getval["cpu_load_avg"] = function ()
	local res = string.match(run_shell("cat /proc/loadavg"), "^(%S+)")
	return res
end

getval["uptime"] = function ()
	local res = string.match(run_shell("cat /proc/uptime"), "^(%S+)")
	return res
end


