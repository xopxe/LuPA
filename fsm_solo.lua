--STATIC
-------------------------------------------------------------------
print ("FSM loading...")

local function FSM(t)
	local a = {}
	for _,v in ipairs(t) do
		local old, matches_event, new, action = v[1], v[2], v[3], v[4]
			if a[old] == nil then a[old] = {} end
			table.insert(a[old],{new = new, action = action, matches_event = matches_event})
	  	end
  	return a
end

local i_event=1 --current event in window
local current_state="ini" --current state

--auxiliar functions to be used whe detecting happening events
local function register_as_happening(event)
	table.insert(happening_events, event)
end
local function unregister_as_happening(filter)
	for i, event in ipairs(happening_events) do
		local matches = true
		for key, value in pairs(filter) do
			if not event[key]==value then
				matches=false
				break
			end
		end
		if matches then
			--print("%%%%%%%unregistering ", i)
			table.remove(happening_events, i)
		end
	end	
end

-------------------------------------------------------------------
--/STATIC

--actions generated at initialization
local initialization_subs= {
	{target="127.0.0.1/lupa/rmoon", command="watch_mib", mib="delta_gateway_throughput",
		op=">", value=1, hysteresis=0.1, notification_id="watching_gt_inc", watcher_id="watching_gt_inc"},	
 	{target="127.0.0.1/lupa/rmoon", command="watch_mib", mib="delta_gateway_throughput",
		op="<", value=-11, hysteresis=0.1, notification_id="watching_gt_dec", watcher_id="watching_gt_dec"},	
	{target="127.0.0.1/lupa/rmoon", command="watch_mib", mib="delta_gatewaying_cost",
		op=">", value=1, hysteresis=0.1, notification_id="watching_gc_inc", watcher_id="watching_gc_inc"},	
 	{target="127.0.0.1/lupa/rmoon", command="watch_mib", mib="delta_gatewaying_cost",
		op="<", value=-11, hysteresis=0.1, notification_id="watching_gc_dec", watcher_id="watching_gc_dec"},	
 	{target="127.0.0.1/lupa/rmoon", command="watch_mib", mib="random",
		op="<", value=0.1, hysteresis=0.05, notification_id="watching_random", watcher_id="wrandom"},	
 	{target="127.0.0.1/lupa/rmoon", command="watch_mib", mib="is_gateway_up",
		op="=", value="true", notification_id="watching_gateway_up", watcher_id="wgateway_up"},	
 	{target="127.0.0.1/lupa/rmoon", command="watch_mib", mib="is_gateway_up",
		op="=", value="false", notification_id="watching_gateway_down", watcher_id="wgateway_down"},	
}

--predicates
local function is_gt_inc(e)
	return e.message_type=="trap" and e.watcher_id=="watching_gt_inc" 
end
local function is_gt_dec(e)
	return e.message_type=="trap" and e.watcher_id=="watching_gt_dec" 
end
local function is_gc_inc(e)
	return e.message_type=="trap" and e.watcher_id=="watching_gc_inc" 
end
local function is_gc_dec(e)
	return e.message_type=="trap" and e.watcher_id=="watching_gc_dec" 
end
local function is_random(e)
	return e.message_type=="trap" and e.watcher_id=="wrandom" 
end
local function is_gateway_up(e)
	return e.message_type=="trap" and e.mib=="is_gateway_up" and e.value=="true"
end
local function is_gateway_down(e)
	return e.message_type=="trap" and e.mib=="is_gateway_up" and e.value=="false"
end

--actions
local function gt_inc()
	print ("--------->gt_inc!") 
	return {}
end
local function gt_dec()
	print ("--------->gt_dec!") 
	return {}
end
local function gc_inc()
	print ("--------->gc_inc!") 
	return {}
end
local function gc_dec()
	print ("--------->gc_dec!") 
	return {}
end
local function wrandom()
	print ("--------->random!") 
	return {}
end
local function gateway_up(event)
	print ("--------->gateway_up!", event.watcher_id) 
	unregister_as_happening({mib="is_gateway_up"})
	register_as_happening(event)
	return {}
end
local function gateway_down(event)
	print ("--------->gateway_down!", event.watcher_id) 
	unregister_as_happening({mib="is_gateway_up"})
	register_as_happening(event)
	return {}
end

--transition
--{state, predicate, new state, action} 
local fsm = FSM{
	{"ini", is_gt_inc,		"end", gt_inc },
	{"ini", is_gt_dec,		"end", gt_dec },
	{"ini", is_gc_inc,		"end", gc_inc },
	{"ini", is_gc_dec,		"end", gc_dec },
	{"ini", is_random,		"end", wrandom },
	{"ini", is_gateway_up,		"ini", gateway_up },
	{"ini", is_gateway_down,	"ini", gateway_down },
   	{"end", nil, nil, nil }
}

--STATIC
-------------------------------------------------------------------
function initialize()
 	print("FSM: initializing")
	return initialization_subs or {}
end

--advances the machine a single step.
--returns nil if arrives at the end the window, or the state is not recognized
--otherwise, returns the resulting list from the action
local function fst_step()
	local event_reg = window[i_event]
	if not event_reg then return end --window finished
	local event=event_reg.event
			
	local state=fsm[current_state]
	local a
	--search first transition that verifies e
	for _, l in ipairs(state) do
		if l.matches_event and l.matches_event(event) then
			a=l
			break
		end
	end 
	if not a then --last event wasn't recongized 
		current_state=nil
		return nil
	end 
	
	local ret_call
	if a.action then ret_call=a.action(event) end
	i_event=i_event+1
	current_state = a.new

	return ret_call	or {}
end

local function dump_window()
	local s="=> "
	for _,e in ipairs(window) do
		s=s .. tostring(e.event.watcher_id) ..","
	end
	return s
end

function proccess_window_add()
	print("FSM: WINDOW ADD ", table.maxn(window), dump_window())
	
	local ret = {}
	if current_state then --and fsm[current_state] then
		local ret_call=fst_step()
		if ret_call then 
			--queue generated actions
			for _, r in ipairs(ret_call) do
				table.insert(ret, r)
			end		
		end
	end
	if table.maxn(ret)>0 then
		print ("FSM: INCOMMING generating output ", table.maxn(ret), current_state)
	end
	return ret
end

function proccess_window_move()
	print("FSM: WINDOW MOVE", table.maxn(window), dump_window())

	i_event, current_state = 1, "ini"
	local ret={}
	while current_state do --and fsm[current_state] do
		local ret_call=fst_step()
		if not ret_call then break end --window finished or chain not recognized
		--queue generated actions
		for _, r in ipairs(ret_call) do
			table.insert(ret, r)
		end		
	end
	if table.maxn(ret)>0 then
		print ("FSM: DROPPED generating output ", table.maxn(ret), current_state)
	end
	return ret
end

print ("FSM loaded.")
-------------------------------------------------------------------
--/STATIC


