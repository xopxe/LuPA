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

-------------------------------------------------------------------
--/STATIC

--actions generated at initialization
local initialization_subs= {
 {target_host="the_node", target_service="/lupa/rmoon", command="watch_mib", mib="process_running", process="top",
	op=">", value=0.5, hysteresis=0.05, notification_id="wt1"..math.random(2^30), watcher_id="toprunning"},	
 {target_host="the_node", target_service="/lupa/rmoon", command="watch_mib", mib="process_running", process="top",
	op="=", value=0, hysteresis=0.05, notification_id="wt2"..math.random(2^30), watcher_id="topnotrunning"}	
}

--predicates
local function is_ev_runing(e)
	return e.message_type=="trap" and e.watcher_id=="toprunning" 
end
local function is_ev_not_runing(e)
	return e.message_type=="trap" and e.watcher_id=="topnotrunning" 
end

--actions
local function action_runing()
	print ("RUNING!") 
	return {
		{target_host="the_node", target_service="/lupa/pep", notification_id=math.random(2^30), 
		command="print", message="RUNING!"},
	}
end
local function action_not_runing()
	print ("NOT RUNING!") 
	return {
		{target_host="the_node", target_service="/lupa/pep", notification_id=math.random(2^30), 
		command="print", message="NOT RUNING!"},
	}
end

--transition
--{state, predicate, new state, action} 
local fsm = FSM{
	{"ini",	is_ev_runing,		"end", 	action_runing	 	},
	{"ini",	is_ev_not_runing, 	"end", 	action_not_runing 	},
   	{"end",	nil,			nil, 	nil			}
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
	local event = window[i_event]
	if not event then return end --window finished
			
	local state=fsm[current_state]
	local a
	--search first transition that verifies e
	for _, l in ipairs(state) do
		if l.matches_event and l.matches_event(event.event) then
			a=l
			break
		end
	end 
	if not a then --last event wasn't recongized 
		current_state=nil
		return nil
	end 
	
	local ret_call
	if a.action then ret_call=a.action() end
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


