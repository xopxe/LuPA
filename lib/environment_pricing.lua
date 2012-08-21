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
local socket_lib = require("socket")
local util = require("util")
local run_shell = util.run_shell

--Table with querying functions
--getval[evname]=function
getval = {}

--Table for caching the results for getval
--getval_cache[evname.."\0"..pars]=value
local getval_cache={}

function purge_cache()
	getval_cache={}
end


commands = {}
commands["os_execute"] = function (params)
	local shell_command=params.shell_command

	local l = run_shell(shell_command)
	
	return {result=l}
end

commands["print"] = function (params)
	print( "ENV: " .. params.message)
end

commands["get_mib"] = function (params)
	local mib = params.mib

	local getenvmib=getenv[mib]
	
	if getenvmib then
		environment.purge_cache()
		local s=getenvmib(params)
		return {value = s}
	else
		return {value = "?", error = "mib not supported"}
	end
end

local socket = socket_lib.udp()
print(configuration.my_host, configuration.my_localstate_port)
socket:setpeername(configuration.my_host, configuration.my_localstate_port)

commands["increasePriceFast"] = function ()
    socket:send("SET BEHAVIOUR IPF")
    local value = socket:receive()
    if not string.find(value,"IPF", 1, true) then
        print(")))       ))   ) Fail at IPF")
    end
end

commands["increasePriceSlow"] = function ()
    socket:send("SET BEHAVIOUR IPS")
    local value = socket:receive()
    if not string.find(value,"IPS", 1, true) then
        print(")))       ))   ) Fail at IPS")
    end
	
end

commands["decreasePriceFast"] = function ()
    socket:send("SET BEHAVIOUR DPF")
    local value = socket:receive()
    if not string.find(value,"DPF", 1, true) then
        print(")))       ))   ) Fail at DPF")
    end
	
end

commands["decreasePriceSlow"] = function ()
    socket:send("SET BEHAVIOUR DPS")
    local value = socket:receive()
    if not string.find(value,"DPS", 1, true) then
        print(")))       ))   ) Fail at DPS")
    end
	
end

commands["keepPrice"] = function ()
    socket:send("SET BEHAVIOUR KP")
    local value = socket:receive()
    if not string.find(value,"KP", 1, true) then
        print(")))       ))   ) Fail at KP")
    end
	
end


--------------------------------------------------------
-- This makes sense in PRICING


getval["price"] = function ()
    socket:send("GET PRICE")
    local value = tonumber(socket:receive())
	return value
end

getval["number_of_clients"] = function ()
    socket:send("GET NUMBER_OF_CLIENTS")
    local value = tonumber(socket:receive())
	return value
end

-- End of PRICING
--------------------------------------------------------

getval["random"] = function ()
	return tostring(math.random())
end


