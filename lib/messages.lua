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

local util=require("util")
local response_counter = util.newCounter()
local util_escape=util.escape

local sha1, sign_message
if configuration.use_sha1 then
	sha1=require('sha1')
	sign_message=sha1.hmac_sha1_message
else
	print("SHA1 signing disabled")
	sign_message=function(...) return "n/a" end
end

local table_insert=table.insert
local table_concat=table.concat
local string_gsub=string.gsub
local os_time=os.time
local math_random=math.random

local BIGN = 2^30

local tags_not_to_escape = {op=true, hysteresis=true, ttl=true, host=true, service=true, timestamp=true, mib=true}

local function build_target_string(s_host, s_serv)
	--print("===========", s_host, s_serv)
	local target="target_host="..s_host 
	if s_serv then target=target.."\ntarget_service="..s_serv end
	return target
end

local response_template ="NOTIFICATION\n"
.."notification_id=@NID@\n"
.."message_type=response\n"
.."host="..configuration.my_host.."\n"
.."service=@MYSERV@\n"
.."timestamp=@TS@\n"
.."@TARGET@\n"
.."reply_to=@REPLYTO@\n"
.."@RET@\n"
.."sha1=@SHA1@\n"
.."END\n"
function generate_response(my_service, params, ret)
	local retlins={}
	for k, v in pairs(ret) do
		if tags_not_to_escape[k] then
			table_insert(retlins, k.."="..v)
		else
			table_insert(retlins, k.."="..util_escape(v))
		end
	end

	local trad= {}
	trad["@MYSERV@"]=my_service
	trad["@NID@"]="resp" .. response_counter() .. params.notification_id .. "_" .. math.random(100)
	trad["@TS@"]=os_time()
	trad["@TARGET@"]=build_target_string(params.host, params.service)
	trad["@REPLYTO@"]=params.notification_id
	trad["@RET@"]=table_concat(retlins, "\n")	
	local response=string_gsub(response_template, "(@%u-@)", trad )

	response=string.gsub(response, '@SHA1@', (sign_message(response)))
	
	return response
end

local trap_template ="NOTIFICATION\n"
.."notification_id=@NID@\n"
.."message_type=trap\n"
.."host="..configuration.my_host.."\n"
.."service=@MYSERV@\n"
.."timestamp=@TS@\n"
.."@TARGET@\n"
.."watcher_id=@WATCHID@\n"
.."mib=@MIB@\n"
.."value=@VALUE@\n"
.."sha1=@SHA1@\n"
.."END\n"
function generate_trap(my_service, trap)
	local trad= {}
	trad["@MYSERV@"]=my_service
	trad["@NID@"]="trap_" .. math_random(BIGN)
	trad["@TS@"]=os_time()
	trad["@TARGET@"]=build_target_string(trap.host, trap.service)
	trad["@WATCHID@"]=trap.watcher_id
	trad["@MIB@"]=trap.mib	
	trad["@VALUE@"]=trap.value
	local response=string_gsub(trap_template, "(@%u-@)", trad )

	response=string.gsub(response, '@SHA1@', (sign_message(response)))
	
	return response
end


local action_template ="NOTIFICATION\n"
.."host=@MYHOST@\n"
.."service=@MYSERV@\n"
.."timestamp=@TS@\n"
.."@PARS@\n"
.."sha1=@SHA1@\n"
.."END\n"
local action_template_fixed = {host=true,service=true,timestamp=true}
function generate_action(my_service, params)
	local parlins={}
	for k, v in pairs(params) do
		if not action_template_fixed[k] then
			if tags_not_to_escape[k] then
				table_insert(parlins, k.."="..v)
			else
				table_insert(parlins, k.."="..util_escape(v))
			end			
		end
	end
	if not params.message_type then
	    table_insert(parlins, "message_type=action")
	end

	local trad= {}
	trad["@MYSERV@"]=my_service
	trad["@MYHOST@"]=configuration.my_host
	trad["@TS@"]=os_time()
	trad["@PARS@"]=table_concat(parlins, "\n")	
	local action=string_gsub(action_template, "(@%u-@)", trad )

	action=string.gsub(action, '@SHA1@', (sign_message(action)))
	
	return action	
end


local subscription_template ="NOTIFICATION\n"
.."subscription_id=@SID@\n"
.."host="..configuration.my_host.."\n"
.."service=@MYSERV@\n"
.."timestamp=@TS@\n"
.."@TTL@"
.."FILTER\n"
.."@FILT@\n"
.."END\n"
function generate_subscription(my_service, params)
	local filtlins={}
	local params_filter=params.filter
	for _, filter in ipairs(params_filter) do
		local k, op, v = filter[1], filter[2], filter[3]
		if tags_not_to_escape[k] then
			table_insert(filtlins, k..op..v)
		else
			table_insert(filtlins, k..op..util_escape(v))
		end			
	end

	local ttl, ttl_string = params.ttl, ""
	if ttl then
		ttl_string = "ttl=".. ttl .. "\n"
	end

	local trad= {}
	trad["@MYSERV@"]=my_service
	trad["@SID@"]=params.subscription_id or my_service.."_subs_"..math_random(BIGN)
	trad["@TS@"]=os_time()
	trad["@TTL@"]=ttl_string
	trad["@FILT@"]=table_concat(filtlins, "\n")	
	local s=string_gsub(subscription_template, "(@%u-@)", trad )

	return s	
end

function generate_notification_raw(my_service, params)
	if not params.timestamp then
		params.timestamp=os_time()
	end

	params.host=params.host or configuration.my_host
	params.service=params.service or my_service

	params.notification_id = params.notification_id or "notif_autoid_"..math_random(BIGN)

	local parlins={"NOTIFICATION"}
	for k, v in pairs(params) do
		if not action_template_fixed[k] then
			if tags_not_to_escape[k] then
				table_insert(parlins, k.."="..v)
			else
				table_insert(parlins, k.."="..util_escape(v))
			end			
		end
	end	
	table_insert(parlins, "END\n")
	local action=table_concat(parlins, "\n")

	return action	
end



