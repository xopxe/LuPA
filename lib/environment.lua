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
commands["interface_configure"] = function(params)
	local name, ip, mask = params.name, params.ip, params.mask
	
	local errorlevel
	if mask == nil then
		errorlevel=os_execute("/sbin/ifconfig "..tostring(name).." "..tostring(ip))
	else
		errorlevel=os_execute("/sbin/ifconfig "..tostring(name).." "..tostring(ip)
			.." netmask "..tostring(mask))
	end
	
	return {errorlevel=errorlevel}
end

commands["tunnel_add"] = function(params)
	local ipPhisStart, ipPhisEnd, ipTunnStart, ipTunnEnd, name, mode =
			params.ipPhisStart, params.ipPhisEnd, params.ipTunnStart, 
			params.ipTunnEnd, params.name, params.mode
			
	name = name or "tun_"..tostring(tunn_counter())
	mode = mode or "ipip"
	local errorlevel=os_execute("/lupa/pep/scripts/tunnel_add.sh "..tostring(ipPhisStart)
		.." "..tostring(ipPhisEnd).." "..tostring(ipTunnStart).." "
		..tostring(ipTunnEnd).." "..tostring(name).." "..tostring(mode))
		
	return {errorlevel=errorlevel, name=name, mode=mode}
end

commands["tunnel_delete"] = function(params)
	local name=params.name
	
	local errorlevel=os_execute("/lupa/pep/scripts/tunnel_delete.sh "..tostring(name))
	
	return {errorlevel=errorlevel}
end

--[[
commands["tunnel_exists"] = function(params)
	local name=params.name
	
	local errorlevel=os_execute("/usr/sbin/ip tunnel show | /bin/grep '^"..tostring(name).."'")
	
	return {result=errorlevel}
end
--]]

commands["route_add"] = function(params)
	local targetNetworkIp, targetNetworkMaskBits, gatewayIp, interface =
		params.targetNetworkIp, params.targetNetworkMaskBits, params.gatewayIp, params.interface
		
	local errorlevel=os_execute("/lupa/pep/scripts/route_add.sh "..tostring(targetNetworkIp) .." "
		..tostring(targetNetworkMaskBits).." "..tostring(gatewayIp).." "
		..tostring(interface))
		
	return {errorlevel=errorlevel}
end

commands["route_delete"] = function(params)
	local targetNetworkIp, targetNetworkMaskBits, gatewayIp, interface =
		params.targetNetworkIp, params.targetNetworkMaskBits, params.gatewayIp, params.interface
		
	local errorlevel=os_execute("/lupa/pep/scripts/route_delete.sh "..tostring(targetNetworkIp) .." "
		..tostring(targetNetworkMaskBits).." "..tostring(gatewayIp).." "
		..tostring(interface))
		
	return {errorlevel=errorlevel}
end

--[[
commands["route_exists"] = function(params)
	local targetNetworkIp, targetNetworkMaskBits, gatewayIp, interface =
		params.targetNetworkIp, params.targetNetworkMaskBits, params.gatewayIp, params.interface
	local targetNetwork = targetNetworkIp;
	
    if targetNetworkMaskBits ~= "32" and targetNetworkIp ~= "default" then 
        targetNetwork = targetNetwork .. "/" .. targetNetworkMaskBits;
    end
    if targetNetworkIp == "0" and targetNetworkMaskBits == "0" then
        targetNetwork = "default";
    end
	local errorlevel=os_execute("/usr/sbin/ip route show | /bin/grep '^"..tostring(targetNetwork)
		.." via "..tostring(gatewayIp).." dev "..tostring(interface))
		
	return {result=errorlevel}
end
--]]

commands["nvram_set"] = function(params)
	local nvramname, nvramvalue = params.nvramname, params.nvramvalue
	
	local errorlevel=os_execute("nvram set " .. tostring(nvramname) .. "=" .. tostring(nvramvalue))
	
	return {errorlevel=errorlevel}
end

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

--------------------------------------------------
--this makes sense in demos
local http = require("socket.http")
commands["ronctrl"] = function (params)
	--local mib, op, value, histeresis = params.mib, params.op, params.value, params.hysteresis or 0
	local code = params.code
	--print ("##",host,service, mib, op, value, histeresis)
	
	local body, status, h = http.request("http://localhost:8188/run?code="..tostring(code))

	if status==200 then
		return {status = "ok", ret=body}
	else
		print ("Http Error", status)
    		return {status = status}
	end
end
--/this makes sense in demos
--------------------------------------------------

--------------------------------------------------
--this makes sense in simularan

commands["gateway_start"] = function(params)
--print ("####################",environment.gateway_start_ts)
	if not environment.gateway_start_ts==nil then
		return {status="error", error="gateway already up"}
	end
--print (os.time(),"GATEWAY_START")

	environment.gateway_start_ts=os.time()
	environment.gateway_traffic=0	
	--environment.cost_as_gateway=40 ---------------------------------

--print (environment.gateway_start_ts)
	return {status="ok", cost=environment.cost_as_gateway}
end
commands["gateway_stop"] = function(params)
--print ("###################!",environment.gateway_start_ts)
	if environment.gateway_start_ts==nil then
		return {status="error", error="gateway already down"}
	end
--print (os.time(),"GATEWAY_STOP")

	local total_time=environment.gateway_start_ts
	environment.gateway_start_ts=nil
	--environment.cost_as_gateway=200 ---------------------------------

--print (environment.gateway_start_ts)
	return {status="ok", total_traffic=environment.gateway_traffic, total_time=total_time}
end
commands["gateway_traffic"] = function(params)
	if not environment.gateway_start_ts then
		return {status="error", error="gateway down"}
	end
	local traffic = params.traffic	
	
	local total_time=environment.gateway_start_ts
	environment.gateway_traffic=environment.gateway_traffic+traffic

--print("----------------------",environment.gateway_traffic)
	return {status="ok", total_traffic=environment.gateway_traffic, total_time=total_time}
end
commands["gateway_cost_mult"] = function(params)
	local coef = params.coef
	
	environment.cost_as_gateway=coef*environment.cost_as_gateway

	return {status="ok", cost_as_gateway=environment.cost_as_gateway}
end
commands["gateway_cost_set"] = function(params)
	local cost = params.cost
	
	environment.cost_as_gateway=cost

	return {status="ok", cost_as_gateway=environment.cost_as_gateway}
end
commands["gateway_set"] = function(params)
	local gateway = params.gateway
--print (os.time(),"GATEWAY_SET", gateway)
	
	environment.my_gateway=gateway

	return {status="ok", gateway=environment.my_gateway}
end
--/this makes sense in simularan
--------------------------------------------------

--------------------------------------------------------
-- This makes sense in PRICING

price = 100

getval["price"] = function ()
	local priceToReturn = price
	--print("LOCURA!")
	--price = price + 1
	return priceToReturn
end

-- End of PRICING
--------------------------------------------------------

--------------------------------------------------------
--Functions for reading attributes

getval["processes_running"] = function ()
	local in_cache=getval_cache["processes_running"]
	if in_cache then
		return in_cache
	end
	
	--local res=run_shell("ps -A | wc -l")-2   --minus header and ps line
	local res=run_shell("ps | wc -l")-2   --minus header and ps line
	getval_cache["processes_running"]=res
	return res
end

getval["process_running"] = function (params)
	local process=params.process
	
	local cachekey="processes_running".."\0"..process
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	

	local process_s = process --.. "\n"
	
	local _, res = string.gsub(run_shell("ps w"), process_s, process_s)
--print ("######", run_shell("ps -a"))
	getval_cache[cachekey]=res
	return res
end

getval["free_ram"] = function ()
	local in_cache=getval_cache["free_ram"]
	if in_cache then
		return in_cache
	end	
	
	local res = string.match(run_shell("cat /proc/meminfo"), "MemFree:%s+(%d+)")
	getval_cache["free_ram"]=res
	return res
end

getval["cpu_load_avg"] = function ()
	local in_cache=getval_cache["cpu_load_avg"]
	if in_cache then
		return in_cache
	end		
	
	local res = string.match(run_shell("cat /proc/loadavg"), "^(%S+)")
	getval_cache["cpu_load_avg"]=res
	return res
end

getval["uptime"] = function ()
	local in_cache=getval_cache["uptime"]
	if in_cache then
		return in_cache
	end		
	
	local res = string.match(run_shell("cat /proc/uptime"), "^(%S+)")
	getval_cache["uptime"]=res
	return res
end

getval["iface_available"] = function (params)
	local ifname=params.ifname
	
	local cachekey="iface_available".."\0"..ifname
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	
	
	local res
	if string.match(run_shell("ifconfig " .. ifname), "^" .. ifname) then 
		res= "true"
	else
		res= "false"
	end
 	getval_cache[cachekey]=res
	return res
end

getval["iface_has_ipv4"] = function (params)
	local ifname=params.ifname

	local cachekey="iface_has_ipv4".."\0"..ifname
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	
		
	local res
	if string.match(run_shell("ifconfig " .. ifname), "inet addr:") then 
		res= "true"
	else
		res= "false"
	end
	getval_cache[cachekey]=res
	return res
end

getval["iface_has_ipv6"] = function (params)
	local ifname=params.ifname

	local cachekey="iface_has_ipv6".."\0"..ifname
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	
	
	local res
	if string.match(run_shell("ifconfig " .. ifname), "inet6 addr:") then 
		res= "true"
	else
		res= "false"
	end
	getval_cache[cachekey]=res
	return res
end

getval["iface_throughput_tx"] = function (params)
	local ifname=params.ifname

	local cachekey="iface_throughput_tx".."\0"..ifname
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	
		
	local res = string.match(run_shell("cat /tmp/throughput_" .. ifname .. ".txt"), "tx%s+(%S+)") 

	getval_cache[cachekey]=res
	return res
end
getval["iface_throughput_rx"] = function (params)
	local ifname=params.ifname

	local cachekey="iface_throughput_rx".."\0"..ifname
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	
		
	local res = string.match(run_shell("cat /tmp/throughput_" .. ifname .. ".txt"), "rx%s+(%S+)") 

	getval_cache[cachekey]=res
	return res
end
getval["route_exists"] = function(params)
	local targetNetworkIp, targetNetworkMaskBits, gatewayIp, interface =
		params.targetNetworkIp, params.targetNetworkMaskBits, params.gatewayIp, params.interface
		
	local targetNetwork = targetNetworkIp;
    	if targetNetworkMaskBits ~= "32" and targetNetworkIp ~= "default" then 
        	targetNetwork = targetNetwork .. "/" .. targetNetworkMaskBits;
    	end
    	if targetNetworkIp == "0" and targetNetworkMaskBits == "0" then
        	targetNetwork = "default";
    	end
	
	local cachekey="route_exists".."\0"..targetNetwork.."\0"..gatewayIp.."\0"..interface
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	
	
	
	local res
	if string.match(run_shell("/usr/sbin/ip route show"), "^"..tostring(targetNetwork)
		.." via "..tostring(gatewayIp).." dev "..tostring(interface)) then
		res= "true"
	else
		res= "false"
	end
	getval_cache[cachekey]=res
	return res
end

getval["tunnel_exists"] = function(params)
	local tunnelname=params.tunnelname

	local cachekey="route_exists".."\0"..tunnelname
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	
		
 	local res
 	if string.match(run_shell("/usr/sbin/ip route show"), "^"..tostring(tunnelname)) then
		 res= "true"
	 else
		 res= "false"
	 end
	 getval_cache[cachekey]=res
	 return res
end

getval["random"] = function ()
	return tostring(math.random())
end

--------------------------------------------------------
--Functions for reading from demos
local http = require("socket.http")

getval["ronctrl"] = function (parameters)
	local expr=parameters.expr

	local cachekey="ronctrl".."\0"..expr
	local in_cache=getval_cache[cachekey]
	if in_cache then
		return in_cache
	end	

	local body, status, _ = http.request("http://localhost:8188/run?code=return("..tostring(expr)..')')

	local res
	if status==200 then
		res = body
	else
		res = 'Error ' .. status
	end

	getval_cache[cachekey]=res
	return res
end

--/Functions for reading from demos
--------------------------------------------------------

--------------------------------------------------------
--Functions for reading from USB4ALL

local usb4all, baseboards, devices
local get_device_name, read_devices_list, check_open_device, split_words

if configuration.use_usb4all then
	--package.path=package.path .. ";../lubot/?.lua;../lubot/source/usb4all/?.lua"
    package.path=package.path .. ";../bobot/?.lua"
	usb4all = require("bobot")
	baseboards = usb4all.baseboards
	devices = {}

	get_device_name=function (n)
		if not devices[n] then return n	end
		local i=2
		local nn=n.."#"..i
		while devices[nn] do
			i=i+1
			nn=n.."#"..i
		end
		return nn
	end
	read_devices_list=function ()
		local bfound
		devices={}
		for b_name, bb in pairs(baseboards) do
			for d_name,d in pairs(bb.devices) do
				local regname = get_device_name(d_name)
				devices[regname]=d
				print("=====d_name", d_name, "regname", regname)
			end
			bfound = true
		end
		if not bfound then print ("ls:WARN: No Baseboard found.") end
	end
	check_open_device=function (d, ep1, ep2)
		if not d then return end
		if d.handler then
			return true
		else
			print ("ls:Opening", d.name, d.handler)
			return d:open(ep1 or 1, ep2 or 1) --TODO asignacion de ep?
		end
	end
	function split_words (s)
		words={}
		for p in string.gmatch(s, "%S+") do
			words[#words+1]=p
		end
		return words
	end

	read_devices_list()

	getval["usb4all"] = function (parameters)
		local d, call, params =	parameters.device, parameters.call, parameters.call_params
		--local d  = 'temp'
		--local call  = 'get_temperature'
		local words=split_words(params or '')

		local res

		local device = devices[d]
		if not check_open_device(device, nil, nil) or (not device.api) then	
			res = "failure opening device"
		else
			local api_call=device.api[call];	 
			if api_call and api_call.call then 
				res = api_call.call(unpack(words))
			else
				res = "failure querying device"
			end
		end

	--print("###", res)
		return res
	end

end

--/Functions for reading from USB4ALL
--------------------------------------------------------


--[[
--------------------------------------------------------
--Functions for reading from the PICDEM.net2_3.7 firmware

local http = require("socket.http")
getval["picdem_pot"] = function ()
	local in_cache=getval_cache["picdem_pot"]
	if in_cache then
		return in_cache
	end

	local s=http.request('http://192.168.3.125/Index.cgi') or ''
	local res=tonumber( string.match(s, 'Pot0: (%d+)<br>') ) or 0

	getval_cache["picdem_pot"]=res

print("###", res)
	return res
end

--/Functions for reading from the PICDEM.net2_3.7 firmware
--------------------------------------------------------
--]]

--[[
--------------------------------------------------
--this makes sense in simularan

--speed of convergency for delta calculation.
local conv_pond=0.3

--if this is a gateway, the cost of using it.
cost_as_gateway=200

--gateway activated timestamp (nil if stopped)
gateway_start_ts=nil

--traffic received for gateway since started
gateway_traffic=0

--my gateway, and it's cost
my_gateway=nil
my_gateway_cost=nil

--mibs for accesing
getval["gatewaying_cost"] = function ()
--print (os.time(),"GATEWAY_COST",cost_as_gateway)
	return cost_as_gateway
end
local last_gatewaying_cost = getval["gatewaying_cost"]()
getval["delta_gatewaying_cost"] = function ()
	local current_gatewaying_cost = getval["gatewaying_cost"]()
	local delta = current_gatewaying_cost - last_gatewaying_cost
	last_gatewaying_cost = conv_pond*current_gatewaying_cost + (1-conv_pond)*last_gatewaying_cost
	return delta
end
getval["using_gateway"] = function ()
	return my_gateway
end
getval["is_gateway_up"] = function ()
	if gateway_start_ts then
		return "true"
	else
		return "false"
	end
end
getval["gateway_throughput"] = function ()
	if gateway_start_ts then
		return gateway_traffic / (os.time() - gateway_start_ts)
	else
		return 0
	end
end
local last_gateway_throughput = getval["gateway_throughput"]()
getval["delta_gateway_throughput"] = function ()
	local current_gateway_throughput = getval["gateway_throughput"]()
	local delta = current_gateway_throughput - last_gateway_throughput
--print (os.time(),"GATEWAY_THROUGHPUT",current_gateway_throughput,last_gateway_throughput)
	last_gateway_throughput = conv_pond*current_gateway_throughput + (1-conv_pond)*last_gateway_throughput
	return delta
end
getval["using_gateway_cost"] = function ()
	return my_gateway_cost
end
--/this makes sense in simularan
--------------------------------------------------
--]]

