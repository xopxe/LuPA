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

local function randomize ()
	local fl = io.open("/dev/urandom");
	local res = 0;
	for f = 1, 4 do res = res*256+(fl:read(1)):byte(1, 1); end;
	fl:close();
	math.randomseed(res);
end;

randomize()

--default values
local id=tostring(math.random(2^30)) 
my_name_pdp=id .. "/lupa/pdp"

time_step=1 --tick
sleep_on_reconnect = 5 --pause before reconnecting, secs.
pdp_window_size = 5 --size for the window for the pdp, in secs.
max_events_in_window = 100 --max amount of events in the window. When overflown, oldest events get dropped

upstream = {"127.0.0.1", 8182}


pdp_sort_window = true --wether the pdp will sort the events in the window


--loads configuration file
function load(file)
	local f, err = loadfile(file)
	assert(f,err)
	setfenv(f, configuration)
	f()
end
