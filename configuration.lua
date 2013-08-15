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
	local mult={256,256,256,128} --en el kamikaze8.09.1 los enteros son de 31 bits... signo?                                            
	for f = 1, 4 do res = res*mult[f]+(fl:read(1)):byte(1, 1); end;                                                                     
	fl:close();
	math.randomseed(res);
end;

randomize()

--valores por defecto
--local id=tostring(math.random(2^30)) 
my_host = "host"..tostring(math.random(2^30)) 
rnr_port=8182

--my_name_pdp=id .. "/lupa/pdp"
--my_name_pep=id .. "/lupa/pep"
--my_name_rmoon=id .. "/lupa/rmoon"
environment="environment" --package to require for environment

time_step=1 --tick
sleep_on_reconnect = 5 --pausa para reconeccion
trap_generation_interval = 3 --cada cuanto generamos traps
pdp_evaluation_interval  = 5 --cada cuanto evaluamos la politica
pdp_window_size = 5 --tamaño de la ventana en segundos para el pdp
max_events_in_window = 100 --cantidad maxima de eventos en la ventana. Al superarse, se dropean los mas viejos
use_usb4all	=false 	--cargar el modulo de usb4all

upstream = "127.0.0.1"

enable_pdp = true
enable_rmoon = true
enable_pep = true

use_sha1 	= false --true	--load sha1 module
use_sha1_cache	= true  --faster sha1, uses more memory	
sha1_key	= "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" --key used to sign messages
--sha1_fields	= {}	--fields o a message to be signed
sha1_fields	= {'host', 'service', 'watcher_id', 'mib', 'value', 
		'notification_id', 'message_type', 'reply_to'}	--fields o a message to be signed

--carga un archivo de configuracion
function load(file)
	local f, err = loadfile(file)
	assert(f,err)
	setfenv(f, configuration)
	f()
end
