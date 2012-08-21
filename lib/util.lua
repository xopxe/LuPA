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


--Provides a counter function
function newCounter ()
	local i = 0
	return function ()   -- anonymous function
   		i = i + 1
   		return i
	end
end

--executes s on the console and returns the output
run_shell = function(s)
	local f = io.popen(s) -- runs command
	local l = f:read("*a") -- read output of command
	f:close()
	return l
end

--escapes a string using url-encode
function escape (s)
  	s = string.gsub(s, "([&=+%c])", function (c)
		return string.format("%%%02X", string.byte(c))
  		end)
  	s = string.gsub(s, " ", "+")
  	return s
end

--unescapes a string using url-encode
function unescape (s)
	s = string.gsub(s, "+", " ")
  	s = string.gsub(s, "%%(%x%x)", function (h)
		return string.char(tonumber(h, 16))
	  	end)
  	return s
end

--[[
local lua_reserved_words = {}
for _, v in ipairs{
    "and", "break", "do", "else", "elseif", "end", "false", 
    "for", "function", "if", "in", "local", "nil", "not", "or", 
    "repeat", "return", "then", "true", "until", "while"
            } do lua_reserved_words [v] = true end
			
--serializa una variable
--soporta tablas con identificadores validos y sin ciclos 
function simple_serialize (o)
  	if type(o) == "number" then
		io.write(o)
  	elseif type(o) == "string" then
		io.write(string.format("%q", o))
  	elseif type(o) == "table" then
		io.write("{\n")
		for k,v in pairs(o) do
			if lua_reserved_words [k] then
				io.write("  [")
				simple_serialize(k)
				io.write("] = ")
			else
				io.write("  ", k, " = ")
			end
			simple_serialize(v)
		  	io.write(",\n")
		end
		io.write("}\n")
	else
		error("cannot serialize a " .. type(o))
  	end
end
--]]



