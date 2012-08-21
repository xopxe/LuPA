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
local getenv = environment.getval

local util = require("util")
local run_shell = util.run_shell
local tunn_counter = util.newCounter()

local os_execute=os.execute

commands = environment.commands or {}

--TODO agregar validaciones en todos los commands[] 
---------------------------------------------------------------------------------
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

