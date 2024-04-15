#define TIME_LEFT (SSshuttle.emergency.timeLeft())
#define ENGINES_START_TIME 100
#define ENGINES_STARTED (SSshuttle.emergency.mode == SHUTTLE_IGNITING)
#define IS_DOCKED (SSshuttle.emergency.mode == SHUTTLE_DOCKED || (ENGINES_STARTED))
#define SHUTTLE_CONSOLE_ACTION_DELAY (5 SECONDS)

/obj/machinery/computer/emergency_shuttle
	name = "emergency shuttle console"
	desc = "For shuttle control."
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	resistance_flags = INDESTRUCTIBLE
	var/shuttle_id
	var/auth_need = 3
	var/list/authorized = list()
	var/list/acted_recently = list()

/obj/machinery/computer/emergency_shuttle/Initialize(mapload, obj/item/circuitboard/C)
	.=..()
	var/obj/docking_port/mobile/port = SSshuttle.get_containing_shuttle(src)
	if(!port)
		return INITIALIZE_HINT_QDEL
	shuttle_id = port.id

/obj/machinery/computer/emergency_shuttle/attackby(obj/item/I, mob/user,params)
	if(istype(I, /obj/item/card/id))
		say("Please equip your ID card into your ID slot to authenticate.")
	. = ..()

/obj/machinery/computer/emergency_shuttle/ui_state(mob/user)
	return GLOB.human_adjacent_state

/obj/machinery/computer/emergency_shuttle/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "EmergencyShuttleConsole", name)
		ui.open()

/obj/machinery/computer/emergency_shuttle/ui_data(user)
	var/obj/docking_port/mobile/M = SSshuttle.getShuttle(shuttle_id)
	var/list/data = list()

	data["timer_str"] = M.getTimerStr()
	data["engines_started"] = M.mode == SHUTTLE_IGNITING
	data["authorizations_remaining"] = max((auth_need - authorized.len), 0)
	var/list/A = list()
	for(var/i in authorized)
		var/obj/item/card/id/ID = i
		var/name = ID.registered_name
		var/job = ID.assignment

		if(obj_flags & EMAGGED)
			name = Gibberish(name)
			job = Gibberish(job)
		A += list(list("name" = name, "job" = job))
	data["authorizations"] = A

	data["enabled"] = (M.mode == SHUTTLE_DOCKED) && !(user in acted_recently)
	data["emagged"] = obj_flags & EMAGGED ? 1 : 0
	return data

/obj/machinery/computer/emergency_shuttle/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	if(!shuttle_id)
		return
	var/obj/docking_port/mobile/M = SSshuttle.getShuttle(shuttle_id)
	if(M.mode != SHUTTLE_DOCKED) // shuttle computer only has uses when onstation
		return
	if(!isliving(usr))
		return

	var/mob/living/user = usr
	. = FALSE

	var/obj/item/card/id/ID = user.get_idcard(TRUE)

	if(!ID)
		to_chat(user, span_warning("You don't have an ID."))
		return

	if(!(ACCESS_HEADS in ID.access))
		to_chat(user, span_warning("The access level of your card is not high enough."))
		return

	if (user in acted_recently)
		return

	var/old_len = authorized.len
	addtimer(CALLBACK(src, PROC_REF(clear_recent_action), user), SHUTTLE_CONSOLE_ACTION_DELAY)

	switch(action)
		if("authorize")
			. = authorize(user)

		if("repeal")
			authorized -= ID

		if("abort")
			if(authorized.len)
				// Abort. The action for when heads are fighting over whether
				// to launch early.
				authorized.Cut()
				. = TRUE

	if((old_len != authorized.len) && M.mode != SHUTTLE_IGNITING)
		var/alert = (authorized.len > old_len)
		var/repeal = (authorized.len < old_len)
		var/remaining = max(0, auth_need - authorized.len)
		if(authorized.len && remaining)
			minor_announce("[remaining] authorizations needed until shuttle is launched early", null, alert)
		if(repeal)
			minor_announce("Early launch authorization revoked, [remaining] authorizations needed")

	acted_recently += user
	ui_interact(user)

/obj/machinery/computer/emergency_shuttle/proc/authorize(mob/living/user, source)
	var/obj/item/card/id/ID = user.get_idcard(TRUE)

	if(ID in authorized)
		return FALSE
	for(var/i in authorized)
		var/obj/item/card/id/other = i
		if(other.registered_name == ID.registered_name)
			return FALSE // No using IDs with the same name

	authorized += ID

	message_admins("[ADMIN_LOOKUPFLW(user)] has authorized early shuttle launch")
	log_evacuation("[key_name(user)] has authorized early shuttle launch in [COORD(src)]")
	// Now check if we're on our way
	. = TRUE
	process(SSMACHINES_DT)

/obj/machinery/computer/emergency_shuttle/proc/clear_recent_action(mob/user)
	acted_recently -= user
	if (!QDELETED(user))
		ui_interact(user)

/obj/machinery/computer/emergency_shuttle/process()
	// Launch check is in process in case auth_need changes for some reason
	// probably external.
	. = FALSE
	var/obj/docking_port/mobile/M = SSshuttle.getShuttle(shuttle_id)
	if(M.mode == SHUTTLE_STRANDED)
		authorized.Cut()
		obj_flags &= ~(EMAGGED)

	if(M.mode != SHUTTLE_DOCKED)
		return .

	// Check to see if we've reached criteria for early launch
	if((authorized.len >= auth_need) || (obj_flags & EMAGGED))
		// shuttle timers use 1/10th seconds internally
		M.setTimer(ENGINES_START_TIME)
		var/system_error = obj_flags & EMAGGED ? "SYSTEM ERROR:" : null
		minor_announce("The emergency shuttle will launch in \
			[M.timeLeft()] seconds", system_error, alert=TRUE)
		. = TRUE

/obj/machinery/computer/emergency_shuttle/emag_act(mob/user)
	// How did you even get on the shuttle before it go to the station?
	var/obj/docking_port/mobile/M = SSshuttle.getShuttle(shuttle_id)
	if(M.mode != SHUTTLE_DOCKED)
		return

	if((obj_flags & EMAGGED) || M.mode == SHUTTLE_IGNITING) //SYSTEM ERROR: THE SHUTTLE WILL LA-SYSTEM ERROR: THE SHUTTLE WILL LA-SYSTEM ERROR: THE SHUTTLE WILL LAUNCH IN 10 SECONDS
		to_chat(user, span_warning("The shuttle is already about to launch!"))
		return

	var/time = M.timeLeft()
	message_admins("[ADMIN_LOOKUPFLW(user)] has emagged the emergency shuttle [time] seconds before launch.")
	log_shuttle("[key_name(user)] has emagged the emergency shuttle in [COORD(src)] [time] seconds before launch.")

	obj_flags |= EMAGGED
	M.movement_force = list("KNOCKDOWN" = 60, "THROW" = 20)//YOUR PUNY SEATBELTS can SAVE YOU NOW, MORTAL
	var/datum/species/S = new
	for(var/i in 1 to 10)
		// the shuttle system doesn't know who these people are, but they
		// must be important, surely
		var/obj/item/card/id/ID = new(src)
		var/datum/job/J = pick(SSjob.joinable_occupations)
		ID.registered_name = S.random_name(pick(MALE, FEMALE))
		ID.assignment = J.title

		authorized += ID

	process(SSMACHINES_DT)

/obj/machinery/computer/emergency_shuttle/Destroy()
	// Our fake IDs that the emag generated are just there for colour
	// They're not supposed to be accessible

	for(var/obj/item/card/id/ID in src)
		qdel(ID)
	if(authorized?.len)
		authorized.Cut()
	authorized = null

	. = ..()

/obj/docking_port/mobile/emergency
	name = "LRSV Icarus"
	id = "emergency"

	dwidth = 9
	width = 22
	height = 11
	dir = EAST
	port_direction = WEST
	var/sound_played = 0 //If the launch sound has been sent to all players on the shuttle itself
	//Set by the evacuation controller
	var/call_time
	var/escape_time
	var/dock_time

/obj/docking_port/mobile/emergency/canDock(obj/docking_port/stationary/S)
	return SHUTTLE_CAN_DOCK //If the emergency shuttle can't move, the whole game breaks, so it will force itself to land even if it has to crush a few departments in the process

/obj/docking_port/mobile/emergency/register()
	. = ..()
	GLOB.emergency_shuttle = src

/obj/docking_port/mobile/emergency/request(obj/docking_port/stationary/S)
	switch(mode)
		// The shuttle can not normally be called while "recalling", so
		// if this proc is called, it's via admin fiat
		if(SHUTTLE_RECALL, SHUTTLE_IDLE, SHUTTLE_CALL)
			mode = SHUTTLE_CALL
			setTimer(call_time * engine_coeff)

/obj/docking_port/mobile/emergency/cancel()
	if(mode != SHUTTLE_CALL)
		return

	invertTimer()
	mode = SHUTTLE_RECALL

/obj/docking_port/mobile/emergency/proc/ShuttleDBStuff()
	set waitfor = FALSE
	if(!SSdbcore.Connect())
		return
	var/datum/db_query/query_round_shuttle_name = SSdbcore.NewQuery({"
		UPDATE [format_table_name("round")] SET shuttle_name = :name WHERE id = :round_id
	"}, list("name" = name, "round_id" = GLOB.round_id))
	query_round_shuttle_name.Execute()
	qdel(query_round_shuttle_name)

/obj/docking_port/mobile/emergency/check()
	if(!timer)
		return
	var/time_left = timeLeft(1)

	// The emergency shuttle doesn't work like others so this
	// ripple check is slightly different
	if(!ripples.len && (time_left <= SHUTTLE_RIPPLE_TIME) && ((mode == SHUTTLE_CALL) || (mode == SHUTTLE_ESCAPE)))
		var/destination
		if(mode == SHUTTLE_CALL)
			destination = SSshuttle.getDock("emergency_home")
		else if(mode == SHUTTLE_ESCAPE)
			destination = SSshuttle.getDock("emergency_away")
		create_ripples(destination)

	switch(mode)
		if(SHUTTLE_RECALL)
			if(time_left <= 0)
				mode = SHUTTLE_IDLE
				timer = 0
		if(SHUTTLE_CALL)
			if(time_left <= 0)
				//move emergency shuttle to station
				if(initiate_docking(SSshuttle.getDock("emergency_home")) != DOCKING_SUCCESS)
					setTimer(20)
					return
				mode = SHUTTLE_DOCKED
				setTimer(dock_time)
				SEND_SIGNAL(src, COMSIG_EMERGENCYSHUTTLE_ARRIVAL)
				ShuttleDBStuff()

		if(SHUTTLE_DOCKED)
			if(time_left <= ENGINES_START_TIME)
				mode = SHUTTLE_IGNITING
				for(var/A in SSshuttle.mobile_docking_ports)
					var/obj/docking_port/mobile/M = A
					if(M.launch_status == UNLAUNCHED) //Pods will not launch from the mine/planet, and other ships won't launch unless we tell them to.
						M.check_transit_zone()

		if(SHUTTLE_IGNITING)
			var/success = TRUE

			success &= (check_transit_zone() == TRANSIT_READY)
			for(var/A in SSshuttle.mobile_docking_ports)
				var/obj/docking_port/mobile/M = A
				if(M.launch_status == UNLAUNCHED)
					success &= (M.check_transit_zone() == TRANSIT_READY)
			if(!success)
				setTimer(ENGINES_START_TIME)

			if(time_left <= 50 && !sound_played) //4 seconds left:REV UP THOSE ENGINES BOYS. - should sync up with the launch
				sound_played = 1 //Only rev them up once.
				SEND_SIGNAL(src, COMSIG_EMERGENCYSHUTTLE_ANNOUNCE)
				var/list/areas = list()
				for(var/area/shuttle/escape/E in GLOB.areas)
					areas += E
				hyperspace_sound(HYPERSPACE_WARMUP, areas)

			if(time_left <= 0)
				//move each escape pod (or applicable spaceship) to its corresponding transit dock
				for(var/A in SSshuttle.mobile_docking_ports)
					var/obj/docking_port/mobile/M = A
					M.on_emergency_launch()

				//now move the actual emergency shuttle to its transit dock
				var/list/areas = list()
				for(var/area/shuttle/escape/E in GLOB.areas)
					areas += E
				hyperspace_sound(HYPERSPACE_LAUNCH, areas)
				enterTransit()
				mode = SHUTTLE_ESCAPE
				launch_status = ENDGAME_LAUNCHED
				for(var/obj/docking_port/mobile/M in SSshuttle.mobile_docking_ports)
					M.post_emergency_launch()
				if(prob(10))
					SSuniverse.SetUniversalState(/datum/universal_state/resonance_jump, list(ZTRAIT_TRANSIT))
				setTimer(escape_time * engine_coeff)
				SEND_SIGNAL(src, COMSIG_EMERGENCYSHUTTLE_DEPARTING)

		if(SHUTTLE_ESCAPE)
			if(sound_played && time_left <= HYPERSPACE_END_TIME)
				var/list/areas = list()
				for(var/area/shuttle/escape/E in GLOB.areas)
					areas += E
				hyperspace_sound(HYPERSPACE_END, areas)
			if(time_left <= PARALLAX_LOOP_TIME)
				var/area_parallax = FALSE
				for(var/place in shuttle_areas)
					var/area/shuttle/shuttle_area = place
					if(shuttle_area.parallax_movedir)
						area_parallax = TRUE
						break
				if(area_parallax)
					parallax_slowdown()
					for(var/A in SSshuttle.mobile_docking_ports)
						var/obj/docking_port/mobile/M = A
						if(M.launch_status == ENDGAME_LAUNCHED)
							if(istype(M, /obj/docking_port/mobile/pod))
								M.parallax_slowdown()

			if(time_left <= 0)
				//move each escape pod to its corresponding escape dock
				SEND_SIGNAL(src, COMSIG_EMERGENCYSHUTTLE_RETURNED)
				for(var/A in SSshuttle.mobile_docking_ports)
					var/obj/docking_port/mobile/M = A
					M.on_emergency_dock()

				dock_id("emergency_away")
				mode = SHUTTLE_ENDGAME
				timer = 0

/obj/docking_port/mobile/emergency/transit_failure()
	..()
	message_admins("Moving emergency shuttle directly to centcom dock to prevent deadlock.")

	mode = SHUTTLE_ESCAPE
	launch_status = ENDGAME_LAUNCHED
	setTimer(escape_time)
	priority_announce("The Emergency Shuttle is preparing for direct jump. Estimate [timeLeft(600)] minutes until the shuttle docks at [FLAVOR_CENTCOM_SHORT].", "LSRV Icarus Announcement")

/obj/docking_port/mobile/pod
	name = "escape pod"
	id = "pod"
	dwidth = 1
	width = 3
	height = 4
	launch_status = UNLAUNCHED

/obj/docking_port/mobile/pod/request(obj/docking_port/stationary/S)
	var/obj/machinery/computer/shuttle/C = getControlConsole()
	if(!istype(C, /obj/machinery/computer/shuttle/pod))
		return ..()
	if(SSsecurity_level.current_level >= SEC_LEVEL_RED || (C && (C.obj_flags & EMAGGED)))
		if(launch_status == UNLAUNCHED)
			launch_status = EARLY_LAUNCHED
			return ..()
	else
		to_chat(usr, span_warning("Escape pods will only launch during \"Code Red\" security alert."))
		return TRUE

/obj/docking_port/mobile/pod/cancel()
	return

/obj/machinery/computer/shuttle/pod
	name = "pod control computer"
	locked = TRUE
	possible_destinations = "pod_asteroid"
	icon = 'icons/obj/terminals.dmi'
	icon_state = "dorm_available"
	icon_keyboard = null
	light_color = LIGHT_COLOR_BLUE
	density = FALSE

/obj/machinery/computer/shuttle/pod/Initialize(mapload)
	. = ..()
	RegisterSignal(SSsecurity_level, COMSIG_SECURITY_LEVEL_CHANGED, PROC_REF(check_lock))
	AddElement(/datum/element/update_icon_blocker)

/obj/machinery/computer/shuttle/pod/emag_act(mob/user)
	if(obj_flags & EMAGGED)
		return
	obj_flags |= EMAGGED
	locked = FALSE
	to_chat(user, span_warning("You fry the pod's alert level checking system."))

/obj/machinery/computer/shuttle/pod/connect_to_shuttle(obj/docking_port/mobile/port, obj/docking_port/stationary/dock)
	. = ..()
	if(port)
		possible_destinations += ";[port.id]_lavaland"

/**
 * Signal handler for checking if we should lock or unlock escape pods accordingly to a newly set security level
 *
 * Arguments:
 * * source The datum source of the signal
 * * new_level The new security level that is in effect
 */
/obj/machinery/computer/shuttle/pod/proc/check_lock(datum/source, old_level, new_level)
	SIGNAL_HANDLER

	if(obj_flags & EMAGGED)
		return
	locked = new_level < SEC_LEVEL_RED

/obj/docking_port/stationary/random
	name = "escape pod"
	id = "pod"
	dwidth = 1
	width = 3
	height = 4
	hidden = TRUE
	var/target_area = /area/mine/unexplored
	var/edge_distance = 16
	// Minimal distance from the map edge, setting this too low can result in shuttle landing on the edge and getting "sliced"

/obj/docking_port/stationary/random/Initialize(mapload)
	. = ..()
	if(!mapload)
		return

	var/list/turfs = get_area_turfs(target_area)
	var/original_len = turfs?.len
	while(turfs?.len)
		var/turf/T = pick(turfs)
		if(T.x<edge_distance || T.y<edge_distance || (world.maxx+1-T.x)<edge_distance || (world.maxy+1-T.y)<edge_distance)
			turfs -= T
		else
			forceMove(T)
			return

	// Fallback: couldn't find anything
	WARNING("docking port '[id]' could not be randomly placed in [target_area]: of [original_len] turfs, none were suitable")
	return INITIALIZE_HINT_QDEL

//Pod suits/pickaxes


/obj/item/clothing/head/helmet/space/orange
	name = "emergency space helmet"
	icon_state = "syndicate-helm-orange"
	inhand_icon_state = "syndicate-helm-orange"

/obj/item/clothing/suit/space/orange
	name = "emergency space suit"
	icon_state = "syndicate-orange"
	inhand_icon_state = "syndicate-orange"
	slowdown = 3
	supports_variations_flags = CLOTHING_DIGITIGRADE_VARIATION | CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/pickaxe/emergency
	name = "emergency disembarkation tool"
	desc = "For extracting yourself from rough landings."

/obj/item/storage/pod
	name = "emergency space suits"
	desc = "A wall mounted safe containing space suits. Will only open in emergencies."
	anchored = TRUE
	density = FALSE
	icon = 'icons/obj/storage.dmi'
	icon_state = "safe"
	var/unlocked = FALSE

/obj/item/storage/pod/PopulateContents()
	new /obj/item/clothing/head/helmet/space/orange(src)
	new /obj/item/clothing/head/helmet/space/orange(src)
	new /obj/item/clothing/suit/space/orange(src)
	new /obj/item/clothing/suit/space/orange(src)
	new /obj/item/clothing/mask/gas(src)
	new /obj/item/clothing/mask/gas(src)
	new /obj/item/tank/internals/oxygen/red(src)
	new /obj/item/tank/internals/oxygen/red(src)
	new /obj/item/pickaxe/emergency(src)
	new /obj/item/pickaxe/emergency(src)
	new /obj/item/survivalcapsule(src)
	new /obj/item/storage/toolbox/emergency(src)
	new /obj/item/bodybag/environmental(src)
	new /obj/item/bodybag/environmental(src)

/obj/item/storage/pod/attackby(obj/item/W, mob/user, params)
	if (can_interact(user))
		return ..()

/obj/item/storage/pod/attackby_secondary(obj/item/weapon, mob/user, params)
	if (!can_interact(user))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	return ..()

/obj/item/storage/pod/attack_hand(mob/user, list/modifiers)
	if (can_interact(user))
		atom_storage?.show_contents(user)
	return TRUE

/obj/item/storage/pod/MouseDrop(over_object, src_location, over_location)
	if(can_interact(usr))
		return ..()

/obj/item/storage/pod/attack_hand_secondary(mob/user, list/modifiers)
	if(!can_interact(user))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	return ..()

/obj/item/storage/pod/AltClick(mob/user)
	if(!can_interact(user))
		return
	..()

/obj/item/storage/pod/can_interact(mob/user)
	if(!..())
		return FALSE
	if(SSsecurity_level.current_level >= SEC_LEVEL_RED || unlocked)
		return TRUE
	to_chat(user, "The storage unit will only unlock during a Red or Delta security alert.")
	return FALSE

/obj/docking_port/mobile/emergency/backup
	name = "backup shuttle"
	id = "backup"
	dwidth = 2
	width = 8
	height = 8
	dir = EAST
	important = TRUE

/obj/docking_port/mobile/emergency/backup/Initialize(mapload)
	// We want to be a valid emergency shuttle but not be the main one, keep whatever's set
	// valid.
	// backup shuttle ignores `timid` because THERE SHOULD BE NO TOUCHING IT
	var/current_emergency = GLOB.emergency_shuttle
	. = ..()
	GLOB.emergency_shuttle = current_emergency
	GLOB.backup_shuttle = src

/obj/docking_port/mobile/emergency/shuttle_build/register()
	. = ..()
	initiate_docking(SSshuttle.getDock("emergency_home"))

#undef TIME_LEFT
#undef ENGINES_START_TIME
#undef ENGINES_STARTED
#undef IS_DOCKED
#undef SHUTTLE_CONSOLE_ACTION_DELAY
