#!/usr/bin/lua
--[[

    Copyright 2010 MINA Group, Facultad de Ingenieria, Universidad de la
    Republica, Uruguay.

    LUPA is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    LUPA is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the RAN System.  If not, see <http://www.gnu.org/licenses/>.

--]]

--[[
    This is the main script for the LUPA package.
    It centralizes the communication with the chosen bus as well as the
    execution of the policies.
    Subscritpions will be issued for the three LUPA modules:
        - PDP: The policy decision point.
        - PEP: The policy enforcement point.
        - RMOON: The monitoring service.
    This implies that messages issued for PDP/PEP/RMOON will be received by
    this LUPA script.
    
    As the bus messages arrives, LUPA will appropiately distribute it to the
    right module and call the different functions aimed at proccessing the bus
    messages.
    
--]]

package.path= "lupa/?.lua;" .. package.path .. ";lupa/lib/?.lua;lupa/rmoon/?.lua;lupa/pep/?.lua;lupa/pdp/?.lua"

require("socket")

-- The three sockets necessary for communication with the RNR/RON bus.
local skt_pep, skt_pdp, skt_rmoon

local configuration=require("configuration")
if arg[1] then configuration.load(arg[1]) end

local to_host=configuration.upstream
local to_port=configuration.rnr_port
local my_host=configuration.my_host

local trap_generation_interval=configuration.trap_generation_interval
local pdp_evaluation_interval=configuration.pdp_evaluation_interval
print("CONF my_host", my_host)
print("CONF to_port", to_port)
print("CONF upstream", to_host)

local messages=require("messages")

local pep=require("pep")
local pdp=require("pdp")
local rmoon=require("rmoon")

local util=require("util")
local unescape=util.unescape

function socket.connect(address, port, laddress, lport)
    local sock, err = socket.tcp()
    if not sock then return nil, err end
    if laddress then
        local res, err = sock:bind(laddress, lport, -1)
        if not res then return nil, err end
    end
    local res, err = sock:connect(address, port)
    if not res then return nil, err end
    return sock
end

local sha1, sign_message
if configuration.use_sha1 then
	sha1=require('sha1')
	sign_message=sha1.hmac_sha1_message
else
	print("SHA1 signing disabled")
	sign_message=function(...) return "n/a" end
end


--local hello = "HELLO\nsubscriptor_id=" ..name .."\nEND\n"

--builds a string to be sent to the router, encoding a output of the fsm
local function generate_pdp_output(out)
    --print("Generating PDP output")
	if out._type=="subscription" then
		out._type=nil
		return (messages.generate_subscription(configuration.my_name_pdp,out))
	end
	if out._type=="notification_raw" then
		out._type=nil
		return (messages.generate_notification_raw(configuration.my_name_pdp,out))
	end
	if out._type=="action" or not out._type then --default type
		out._type=nil
		--print("An action is generated")
		local pepino = messages.generate_action(configuration.my_name_pdp,out)
		--print(pepino)
		return (messages.generate_action(configuration.my_name_pdp,out))
	end

	--fallback
	return ""
end

local function parse_params(data)
	local params={}
	local k, v
	for _, linea in ipairs(data) do
		k, v=  string.match(linea, "^%s*(.-)%s*=%s*(.-)%s*$")
		if k and v then
			--print ("+",k,v)
			params[k]=v
		else
			print ("unparseable line", linea)
		end
	end

	if configuration.use_sha1 then
		local signstatus=sign_message(params)
		print("SHA1 signature: ", signstatus)
		if signstatus~='ok' then 
			print("WARN: Purging message (signature check failure)")
			params={} 
		end
	end

	for k, v in pairs(params) do
		params[k]=unescape(v)
	end

	return params
end

local function process_pep(params)
	local message_type, command, target = params.message_type, params.command, params.target
		
	--procesamos segun accion
	if message_type == "action" and command then
		local response
		if pep.commands[command] then
			print ("IN pep action",command)
			local response = pep.commands[command](params)
			if response then
				local msg=messages.generate_response(configuration.my_name_pep,params, response)
				skt_pep:send(msg)
			end
		else
			print ("ERR: unknown command",command)
		end	
	end
end

local function process_pdp(params)
	local message_type, command, target = params.message_type, params.command, params.target
		
	--procesamos segun accion
	if message_type == "action" and command then
		local response
		if pdp.commands[command] then
			print ("IN pdp action",command)
			--local messages
			response, outgoing = pdp.commands[command](params)
			--ademas, devolvemos la salida de inicializar...
			if response then
				local msg=messages.generate_response(configuration.my_name_pdp,params, response)
				skt_pdp:send(msg)
			end
			if outgoing then
				for _, out in ipairs(outgoing) do
					skt_pdp:send( generate_pdp_output(out) )
				end
			end						
		else
			print ("ERR: unknown command",command)
		end
	
	end

	--TODO decidir message_type que evaluar en la fsm: trap y/o action y/o response
	--registramos el evento para la maquina de estados
	--if message_type == "trap" then
	--if message_type ~= "action" then
    local outgoing=pdp.incomming_event(params)
    --print("Elementos outgoing : ", table.maxn(outgoing))
    for _, out in ipairs(outgoing) do
        skt_pdp:send( generate_pdp_output(out) )
        --print("An action was pumped in the socket")
    end		
	--end
end

local function process_rmoon(params)
	local message_type, command, target = params.message_type, params.command, params.target
		
	--procesamos segun accion
	if message_type == "action" and command then
		local response
		if rmoon.commands[command] then
			print ("IN rmoon action",command)
			response = rmoon.commands[command](params)
			if response then
				local msg=messages.generate_response(configuration.my_name_rmoon,params, response)
				skt_rmoon:send(msg)
			end
		else
			print ("ERR: unknown command",command)
		end
	end
end

while true do
	local err,err_pep,err_pdp,err_rmoon
	print("Connecting...")
	skt_pep = socket.connect(to_host, to_port)
	skt_pdp = socket.connect(to_host, to_port)
	skt_rmoon = socket.connect(to_host, to_port)

	local last_rmoon_timestamp = 0
	local last_pdp_timestamp = 0
	if skt_pep and skt_pdp and skt_rmoon then	
		print("Connected.")
		local skts={[1]=skt_pep, [2]=skt_pdp, [3]=skt_rmoon}
		for _, skt in ipairs(skts) do skt:settimeout(nil) end

		local subsnid = "_sub_"..tostring(math.random(2^30)) 
		local subsn_pep = "SUBSCRIBE\nhost=".. configuration.my_host 
				.."\nservice=".. configuration.my_name_pep .."\nsubscription_id=pep"..subsnid
				.. "\nFILTER\ntarget_host=".. configuration.my_host .."\ntarget_service=".. configuration.my_name_pep .."\nEND\n"
		local subsn_pdp = "SUBSCRIBE\nhost=".. configuration.my_host 
				.."\nservice=".. configuration.my_name_pdp .."\nsubscription_id=pdp"..subsnid
				.. "\nFILTER\ntarget_host=".. configuration.my_host .."\ntarget_service=".. configuration.my_name_pdp .."\nEND\n"
		local subsn_rmoon = "SUBSCRIBE\nhost=".. configuration.my_host 
				.."\nservice=".. configuration.my_name_rmoon .."\nsubscription_id=rmoon"..subsnid
				.. "\nFILTER\ntarget_host=".. configuration.my_host .."\ntarget_service=".. configuration.my_name_rmoon .."\nEND\n"
		
		_,err_pep = skt_pep:send(subsn_pep or "")
		if err_pep then print ("Error sending subsn_pep", err)end
		_,err_pdp = skt_pdp:send(subsn_pdp or "")
		if err_pdp then print ("Error sending subsn_pdp", err)end
		_,err_rmoon = skt_rmoon:send(subsn_rmoon or "")
		if err_rmoon then print ("Error sending subsn_rmoon", err)end
		print("Subscribed.")
		
		--client:settimeout(configuration.time_step)
		print("Tick", configuration.time_step)
		
		print("===Listening===")
	
		local line, data_pep, data_pdp, data_rmoon, ts
		while err_pep ~= "closed" or err_pdp ~= "closed" or err_rmoon ~= "closed" do
			local data_skts, _, err = socket.select(skts, nil, configuration.time_step)
			io.flush()
			ts = socket.gettime()
			--verify pending jobs
			--process watchers
			if ts - last_rmoon_timestamp >= trap_generation_interval then
--print('--', ts)
				local traps=rmoon.generate_traps()
				for _, trap in ipairs(traps) do
					skt_rmoon:send( messages.generate_trap(configuration.my_name_rmoon,trap) )
				end
				last_rmoon_timestamp=ts
			end
			--process policy in pdp
			if ts - last_pdp_timestamp >= pdp_evaluation_interval then
				local outgoing=pdp.tick()
				for _, notif in ipairs(outgoing) do
					skt_pdp:send( messages.generate_action(configuration.my_name_pdp,notif) )
				end
				last_pdp_timestamp=ts
			end
			if err~="timeout" then
				if data_skts[skt_pep] then
					line, err = skt_pep:receive()
					--accumulate message lines
					if data_pep then
						if line=="END" then
							local params=parse_params(data_pep)
							process_pep(params)
							data_pep = nil
						else
							table.insert(data_pep, line)
						end
					else
						if line=="NOTIFICATION" then
							data_pep = {}
						end
					end
				end
				if data_skts[skt_pdp] then
					line, err = skt_pdp:receive()
					--accumulate message lines
					if data_pdp then
						if line=="END" then
							local params=parse_params(data_pdp)
							process_pdp(params)
							data_pdp = nil
						else
							table.insert(data_pdp, line)
						end
					else
						if line=="NOTIFICATION" then
							data_pdp = {}
						end
					end
				end
				if data_skts[skt_rmoon] then
					line, err = skt_rmoon:receive()
					--accumulate message lines
					if data_rmoon then
						if line=="END" then
							local params=parse_params(data_rmoon)
							process_rmoon(params)
							data_rmoon = nil
						else
							table.insert(data_rmoon, line)
						end
					else
						if line=="NOTIFICATION" then
							data_rmoon = {}
						end
					end
				end
			end
		end
	end
		
	--wait to reconnect
	print ("Connection closed, waiting")
	if skt_pep then skt_pep:close() end
	if skt_pdp then skt_pdp:close() end
	if skt_rmoon then skt_rmoon:close() end
	socket.sleep(configuration.sleep_on_reconnect or 1)
end

if skt_pep then skt_pep:close() end
if skt_pdp then skt_pdp:close() end
if skt_rmoon then skt_rmoon:close() end
print("Closed")

