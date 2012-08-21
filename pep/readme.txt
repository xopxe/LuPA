
Levantar PEP
==========

lua init.lua [conffile]


Configuration file
==================
----------------------------------
my_name= "pep1"
my_router = {"127.0.0.1", 8182}
----------------------------------



Mensaje de comando
==================

----------------------------------
NOTIFICATION
notification_id = notid		*
source=sss			*
timestamp=ttt			*
message_type=action		*
target=targetid			*
command=comm			*
param1 = valor1
param2 = valor2
...
END
----------------------------------


Mensaje de respuesta
====================

----------------------------------
NOTIFICATION
notification_id = notid		*
source=sss			*
timestamp=ttt			*
message_type=response		*
target=targetid			*
reply_to=notid			*
param1 = valor1
param2 = valor2
...
END
----------------------------------


Mensaje de trap
===============

----------------------------------
NOTIFICATION
notification_id = notid		*
source=sss			*
timestamp=ttt			*
message_type=trap		*
watcher_id=wid			*
reply_to=notid			*
mib=mib				*
value=v				*
END
----------------------------------

Comandos y respuestas
=====================

Los comandos soportados y la lista de 
parámetros correspondientes son:

Command 
	Parámetros
	Respuestas
	
interface_configure
	name, ip, mask
	errorlevel
	
tunnel_add
	ipPhisStart, ipPhisEnd, ipTunnStart, ipTunnEnd, name, mode
	errorlevel
	
tunnel_delete
	name
	errorlevel
	
//tunnel_exists
//	name
//	errorlevel
	
route_add
	targetNetworkIp, targetNetworkMaskBits, gatewayIp, interface
	result
	
route_delete
	targetNetworkIp, targetNetworkMaskBits, gatewayIp, interface
	errorlevel
	
//route_exists
//	targetNetworkIp, targetNetworkMaskBits, gatewayIp, interface
//	result
	
nvram_set
	nvramname, nvramvalue
	errorlevel
	
os_execute
	shell_command
	result
	
print
	message
	-

get_mib
	mib
	value, error?
	
watch_mib
	mib, op, value, hysteresis
	status, watcher_id?
	
	

	
	
