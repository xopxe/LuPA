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

local list = require("list")


--configuration proxy
local conf = {}
setmetatable(conf,  {
	__index=function(t,k) return configuration[k] end,
	__newindex=function(t,k,v) print ('Attempt to change conf from pdp!', t,k,v) end
	}
)

--environment for running fsm
env = {}

--provide some useful stuff
env.print=print
env.ipairs=ipairs
env.pairs=pairs
env.next=next
env.tonumber=tonumber
env.tostring=tostring
env.type=type
env.unpack=unpack
env.math=math
env.string=string
env.table=table
env.os={}
env.os.clock=os.clock
env.os.date=os.date
env.os.difftime=os.difftime
env.os.time=os.time
env.List=list.List
env.configuration = conf


