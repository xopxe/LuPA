require("socket")

local name=arg[1] or "lupa_client"
local host=arg[2] or "localhost"
local port=arg[3] or 8182

local subsnid = name .. "_sub" .. tostring(math.random(2^30)) 
local subsn = "SUBSCRIBE\nsubscriptor_id=".. name .."\nsubscription_id=" ..subsnid
			.. "\nttl=20\nFILTER\ntarget=" .. name .."\nEND\n"
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

local f = assert(io.open("fsm_test.lua", "r"))
local fsm = f:read("*all")
f:close()

local escaped_fsm=escape(fsm)

local action ="NOTIFICATION\n"
.."notification_id=cmndid" .. tostring(math.random(2^30))  .."\n"
.."message_type=action\n"
.."source=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target=172.16.185.1/lupa/pep\n"
.."command=set_fsm\n"
.."fsm="..escaped_fsm.. "\n"
.."END\n"



local action_print ="NOTIFICATION\n"
.."notification_id=cmndid" .. tostring(math.random(2^30))  .."\n"
.."message_type=action\n"
.."source=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target=172.16.185.131/lupa/pep\n"
.."command=print\n"
.."message=OPI!\n"
.."END\n"
local action_watch ="NOTIFICATION\n"
.."notification_id=cmndid" .. tostring(math.random(2^30))  .."\n"
.."message_type=action\n"
.."source=" ..name.. "\n"
.."timestamp=" ..os.time().. "\n"
.."target=172.16.185.131/lupa/rmoon\n"
.."command=watch_mib\n"
.."mib=random\n"
.."ifname=eth0\n"
.."op=>\n"
.."value=0.5\n"
.."hysteresis=0.05\n"
.."END\n"


print("Starting", name, host, port)
print("Connecting...")
local client = assert(socket.connect(host, port))
print("Connected.")
if os.execute("/bin/sleep 1") ~= 0 then return end	

client:send(subsn)
print("Subscribed.")
if os.execute("/bin/sleep 2") ~= 0 then return end	

client:send(action)
print("Action  sent.")
--if os.execute("/bin/sleep 1") ~= 0 then return end	
print("===Reading===")
repeat
	local line, err = client:receive()
	if line then 
		print("-", unescape(line) ) 
	end
until err
client:close()
