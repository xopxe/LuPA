require("socket")

local name=arg[1] or "test_demos"
local host=arg[2] or "localhost"
local port=arg[3] or 9182

local function randomize ()
	local fl = io.open("/dev/urandom");
	local res = 0;
	for f = 1, 4 do res = res*256+(fl:read(1)):byte(1, 1); end;
	fl:close();
	math.randomseed(res);
end;
randomize()

local subsnid = name .. "_sub" --.. tostring(math.random(2^30)) 
local subsn = "SUBSCRIBE\nhost=".. name .."\nsubscription_id=" ..subsnid
			.. "\nFILTER\ntarget_host=" .. name .."\nEND\n"
--local hello = "HELLO\nsubscriptor_id="..name.."\nEND\n"

local function unescape (s)
	s = string.gsub(s, "+", " ")
  	s = string.gsub(s, "%%(%x%x)", function (h)
		return string.char(tonumber(h, 16))
	  	end)
  	return s
end
local function escape (s)
  	s = string.gsub(s, "([&=+%c])", function (c)
		return string.format("%%%02X", string.byte(c))
  		end)
  	s = string.gsub(s, " ", "+")
  	return s
end

---[[
local action_watch ="NOTIFICATION\n"
.."notification_id=command_watch_ronctrl_"..math.random().."\n"
.."message_type=action\n"
.."host=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target_host=localnode\n"
.."target_service=/lupa/rmoon\n"
.."command=watch_mib\n"
.."mib=ronctrl\n"
.."expr=s_messages:len()\n"
.."op=>\n"
.."value=0\n"
.."hysteresis=0.05\n"
.."timeout=10\n"
.."END\n"
--]]

---[[
local action_pep ="NOTIFICATION\n"
.."notification_id=command_pep_ronctrl_"..math.random().."\n"
.."message_type=action\n"
.."host=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target_host=localnode\n"
.."target_service=/lupa/pep\n"
.."command=ronctrl\n"
.."code=return(configuration.send_views_timeout)\n"
.."END\n"
--]]

print("Starting", name, host, port)
print("Connecting...")
local client = assert(socket.connect(host, port))
client:settimeout(1)
print("Connected.")
if os.execute("/bin/sleep 1") ~= 0 then return end	

client:send(subsn)
print("Subscribed.")
if os.execute("/bin/sleep 1") ~= 0 then return end	

client:send(action_pep)
print("action_pep  sent.")

--if os.execute("/bin/sleep 10") ~= 0 then return end	

client:send(action_watch)
print("action_watch  sent.")


print("===Reading===")
local tini=os.time()
repeat
	local line, err = client:receive()
	if line then 
		print("-", unescape(line) ) 
	end

	--[[
	if os.time()-tini>120 then
	        client:send(action_unwatch)
	        print("-----------Closing" ) 
	        client:close()
	    end
	--]]

until err=="closed"
client:close()
