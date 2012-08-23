require("socket")

local name=arg[1] or "test_rmoon"
local host=arg[2] or "localhost"
local port=arg[3] or 8182

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
			.. "\nttl=20\nFILTER\ntarget_host=" .. name .."\nEND\n"
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

--[[
local action_watch ="NOTIFICATION\n"
.."notification_id=cmndid" .. tostring(math.random(2^30))  .."\n"
.."message_type=action\n"
.."host=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target_host=sensor\n"
.."target_service=/lupa/rmoon\n"
.."command=watch_mib\n"
.."mib=random\n"
.."ifname=eth0\n"
.."op=>\n"
.."value=0.5\n"
.."hysteresis=0.05\n"
.."END\n"
--]]

--[[
local action_watch ="NOTIFICATION\n"
.."notification_id=command_watch_pote\n"
.."message_type=action\n"
.."host=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target_host=sensor\n"
.."target_service=/lupa/rmoon\n"
.."command=watch_mib\n"
.."mib=usb4all\n"
.."device=pote\n"
.."call=get_pote\n"
.."op=>\n"
.."value=50\n"
.."hysteresis=0.05\n"
.."END\n"
--]]

---[[
local action_watch ="NOTIFICATION\n"
.."notification_id=command_watch_temp_"..math.random().."\n"
.."message_type=action\n"
.."host=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target_host=sensor\n"
.."target_service=/lupa/rmoon\n"
.."command=watch_mib\n"
.."watcher_id=watch_temp\n"
.."mib=usb4all\n"
.."device=temp\n"
.."call=get_temperature\n"
.."op=>\n"
.."delta_e=0.1\n"
.."hysteresis=0.05\n"
--.."timeout=15\n"
.."END\n"
--]]

---[[
local action_unwatch ="NOTIFICATION\n"
.."notification_id=command_remove_temp_"..math.random().."\n"
.."message_type=action\n"
.."host=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target_host=sensor\n"
.."target_service=/lupa/rmoon\n"
.."command=remove_watcher\n"
.."watcher_id=watch_temp\n"
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

client:send(action_watch)
print("action_watch  sent.")
--if os.execute("/bin/sleep 1") ~= 0 then return end	
print("===Reading===")
local tini=os.time()
repeat
	local line, err = client:receive()
	if line then 
		print("-", unescape(line) ) 
	end

    if os.time()-tini>20 then
        client:send(action_unwatch)
        print("-----------Closing" ) 
        client:close()
    end

until err=="closed"
client:close()
