require("socket")

local name=arg[1] or "lupa_client"
local host=arg[2] or "localhost"
local port=arg[3] or 8182

local subsnid = name .. "_sub" .. tostring(math.random(2^30)) 
local subsn = "SUBSCRIBE\nsubscriptor_id=".. name .."\nsubscription_id=" ..subsnid
			.. "\nttl=20\nFILTER\ntarget=" .. name .."\nEND\n"
local subsnid = name .. "_sub" .. tostring(math.random(2^30)) 
local subsn1 = "SUBSCRIBE\nsubscriptor_id=".. name .."\nsubscription_id=" ..subsnid
			.. "\nttl=20\nFILTER\nmessage_type=trap\nEND\n"
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

print("Starting", name, host, port)
print("Connecting...")
local client = assert(socket.connect(host, port))
print("Connected.")
if os.execute("/bin/sleep 1") ~= 0 then return end	

client:send(subsn)
client:send(subsn1)
print("Subscribed.")
if os.execute("/bin/sleep 2") ~= 0 then return end	

--if os.execute("/bin/sleep 1") ~= 0 then return end	
print("===Reading===")
repeat
	local line, err = client:receive()
	if line then 
		print("-", unescape(line) ) 
	end
until err
client:close()
