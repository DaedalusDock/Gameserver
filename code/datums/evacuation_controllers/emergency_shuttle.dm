//Shouldn't be used anywhere but here
GLOBAL_DATUM(emergency_shuttle, /obj/docking_port/mobile/emergency)
GLOBAL_DATUM(backup_shuttle, /obj/docking_port/mobile/emergency)

/datum/evacuation_controller/emergency_shuttle
	name = "Emergency Shuttle"
	id = "emergency_shuttle"
	var/obj/docking_port/mobile/emergency/emergency
	var/obj/docking_port/mobile/emergency/backup
	var/emergency_call_time = 10 MINUTES
	var/emergency_escape_time = 3 MINUTES
	var/emergency_dock_time = 2 MINUTES
	var/last_mode
	var/last_call_time

/datum/evacuation_controller/emergency_shuttle/New()
	if(GLOB.backup_shuttle)
		backup = GLOB.backup_shuttle
	else
		log_evacuation("Somehow backup shuttle is missing.")

	if(GLOB.emergency_shuttle)
		emergency = GLOB.emergency_shuttle
	else
		log_evacuation("Somehow emergency shuttle is missing. Using backup shuttle.")
		GLOB.emergency_shuttle = backup

	RegisterSignal(SSsecurity_level, COMSIG_SECURITY_LEVEL_CHANGED, PROC_REF(sec_level_updated))

	emergency.call_time = emergency_call_time * get_sec_level_modifier()
	emergency.escape_time = emergency_escape_time
	emergency.dock_time = emergency_dock_time

/datum/evacuation_controller/emergency_shuttle/proc/on_emergency_shuttle_deleted()
	log_evacuation("Emergency shuttle has been deleted. Using backup shuttle.")
	emergency = backup
	emergency.call_time = emergency_call_time * get_sec_level_modifier()
	emergency.escape_time = emergency_escape_time
	emergency.dock_time = emergency_dock_time

/datum/evacuation_controller/emergency_shuttle/proc/get_sec_level_modifier(level = null)
	if(isnull(level))
		level = SSsecurity_level.current_level

	switch(level)
		if(SEC_LEVEL_GREEN)
			return 2
		if(SEC_LEVEL_BLUE)
			return 1
		if(SEC_LEVEL_RED, SEC_LEVEL_DELTA)
			return 0.5

/datum/evacuation_controller/emergency_shuttle/proc/sec_level_updated(datum/source, old_level, new_level)
	var/modifier_result = get_sec_level_modifier(new_level) / get_sec_level_modifier(old_level)
	if(modifier_result != 1)
		emergency.call_time *= modifier_result
		emergency.modTimer(modifier_result)

/datum/evacuation_controller/emergency_shuttle/get_state()
	switch(state)
		if(EVACUATION_STATE_IDLE)
			return "Emergency shuttle is idle at CentCom"
		if(EVACUATION_STATE_INITIATED)
			return "Emergency shuttle is on the way to the station. ETA: [emergency.getTimerStr()]"
		if(EVACUATION_STATE_AWAITING)
			return "Emergency shuttle is docked at the station. Awaiting crew. ETD: [emergency.getTimerStr()]"
		if(EVACUATION_STATE_EVACUATED)
			return "Emergency shuttle has left the station. ETA: [emergency.getTimerStr()]"
		if(EVACUATION_STATE_FINISHED)
			return "Emergency shuttle has arrived at CentCom"

/datum/evacuation_controller/emergency_shuttle/can_evac(mob/user)
	var/srd = CONFIG_GET(number/shuttle_refuel_delay)
	if(world.time - SSticker.round_start_time < srd)
		return "The emergency shuttle is refueling. Please wait [DisplayTimeText(srd - (world.time - SSticker.round_start_time))] before attempting to call."

	if(state >= EVACUATION_STATE_IDLE)
		switch(emergency.mode)
			if(SHUTTLE_CALL)
				return "The emergency shuttle is already on its way."
			if(SHUTTLE_RECALL)
				return "The emergency shuttle may not be called while returning to CentCom."
			if(SHUTTLE_DOCKED)
				return "The emergency shuttle is already here."
			if(SHUTTLE_IGNITING)
				return "The emergency shuttle is firing its engines to leave."
			if(SHUTTLE_ESCAPE)
				return "The emergency shuttle is moving away to a safe distance."
			if(SHUTTLE_STRANDED)
				return "The emergency shuttle has been disabled by CentCom."

	if(evacuation_disabled)
		return "The emergency shuttle has been disabled by CentCom."

	return ..()

/datum/evacuation_controller/emergency_shuttle/start_evacuation(mob/user, call_reason, area/signal_origin)
	evac_calls_count++

	var/message = "The emergency shuttle has been called."
	if(seclevel2num(get_security_level()) >= SEC_LEVEL_RED)
		message += " Red Alert state confirmed: Dispatching priority shuttle."

	RegisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_ARRIVAL, PROC_REF(on_emergency_shuttle_arrived))
	state = EVACUATION_STATE_INITIATED
	emergency.request(null)

	message += " It will arrive in [emergency.timeLeft(600)] minutes.\nNature of emergency:\n\n[call_reason]"

	if(last_evac_call_loc)
		message += "\n\nCall signal traced. Results can be viewed on any communications console."

	if(cancel_disabled)
		message += "\n\nWarning: Shuttle recall subroutines disabled; Recall not possible."

	priority_announce(message, FLAVOR_CENTCOM_NAME, sound_type = ANNOUNCER_SHUTTLECALLED)

	var/datum/radio_frequency/frequency = SSpackets.return_frequency(FREQ_STATUS_DISPLAYS)
	var/datum/signal/status_signal = new(src, list("command" = "update")) // Start processing shuttle	-mode displays to display the timer
	frequency.post_signal(status_signal)

/datum/evacuation_controller/emergency_shuttle/start_automatic_evacuation(reason)
	switch(reason)
		if(EVACUATION_REASON_CREW_DEATH)
			RegisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_ARRIVAL, PROC_REF(on_emergency_shuttle_arrived))
			state = EVACUATION_STATE_INITIATED
			UnregisterSignal(SSsecurity_level, COMSIG_SECURITY_LEVEL_CHANGED)
			emergency.call_time = emergency_call_time * 0.5
			emergency.request(null)
		if(EVACUATION_REASON_VOTE, EVACUATION_REASON_LONG_ROUND, EVACUATION_REASON_CONSOLE_DESTROYED)
			RegisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_ARRIVAL, PROC_REF(on_emergency_shuttle_arrived))
			state = EVACUATION_STATE_INITIATED
			emergency.request(null)
			priority_announce("The shift has come to an end and the shuttle called. [SSsecurity_level.current_level == SEC_LEVEL_RED ? "Red Alert state confirmed: Dispatching priority shuttle. " : "" ]It will arrive in [emergency.timeLeft(600)] minutes.", FLAVOR_CENTCOM_NAME, sound_type = ANNOUNCER_SHUTTLECALLED)

/datum/evacuation_controller/emergency_shuttle/proc/on_emergency_shuttle_arrived(datum/source)
	state = EVACUATION_STATE_AWAITING
	UnregisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_ARRIVAL)
	RegisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_ANNOUNCE, PROC_REF(on_emergency_shuttle_announce))
	RegisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_DEPARTING, PROC_REF(on_emergency_shuttle_departed))
	send2adminchat("Server", "The Emergency Shuttle has docked with the station.")
	priority_announce("The Icarus has docked with the station. You have [emergency.timeLeft(600)] minutes to board before departure.", "LRSV Icarus Announcement", sound_type = ANNOUNCER_SHUTTLEDOCK)

/datum/evacuation_controller/emergency_shuttle/proc/on_emergency_shuttle_announce(datum/source)
	priority_announce("Engines spooling up. Prepare for resonance jump.", "LRSV Icarus Announcement", do_not_modify = TRUE)

/datum/evacuation_controller/emergency_shuttle/proc/on_emergency_shuttle_departed(datum/source)
	state = EVACUATION_STATE_EVACUATED
	UnregisterSignal(emergency, list(COMSIG_EMERGENCYSHUTTLE_DEPARTING, COMSIG_EMERGENCYSHUTTLE_ANNOUNCE))
	RegisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_RETURNED, PROC_REF(on_emergency_shuttle_returned))
	priority_announce("The Icarus has entered the resonance gate and is enroute to it's destination. Estimate [emergency.timeLeft(600)] minutes until the shuttle docks at Sector Control.", "LRSV Icarus Announcement")
	INVOKE_ASYNC(SSticker, TYPE_PROC_REF(/datum/controller/subsystem/ticker, poll_hearts))
	SSmapping.mapvote() //If no map vote has been run yet, start one.

/datum/evacuation_controller/emergency_shuttle/proc/on_emergency_shuttle_returned(datum/source)
	state = EVACUATION_STATE_FINISHED
	UnregisterSignal(emergency, COMSIG_EMERGENCYSHUTTLE_RETURNED)

/datum/evacuation_controller/emergency_shuttle/can_cancel(mob/user)
	// Point of no return after 50% of the time has passed
	if(emergency.timeLeft(1) < emergency_call_time * get_sec_level_modifier() * 0.5)
		return FALSE
	return ..()

/datum/evacuation_controller/emergency_shuttle/cancel_evacuation(mob/user)
	state = EVACUATION_STATE_IDLE
	emergency.cancel()
	//TODO: Signal changes here
	priority_announce("The emergency shuttle has been recalled.[last_evac_call_loc ? " Recall signal traced. Results can be viewed on any communications console." : "" ]", FLAVOR_CENTCOM_NAME, sound_type = ANNOUNCER_SHUTTLERECALLED)

/datum/evacuation_controller/emergency_shuttle/get_customizable_shuttles()
	return list(emergency)

/datum/evacuation_controller/emergency_shuttle/get_endgame_areas()
	return emergency.shuttle_areas

/datum/evacuation_controller/emergency_shuttle/evacuation_blocked()
	if(emergency.mode != SHUTTLE_DOCKED)
		return
	emergency.mode = SHUTTLE_STRANDED
	emergency.timer = null
	emergency.sound_played = FALSE
	priority_announce("Hostile environment detected. \
		Departure has been postponed indefinitely pending \
		conflict resolution.",
		"LRSV Icarus Announcement",
		do_not_modify = TRUE
	)

/datum/evacuation_controller/emergency_shuttle/evacuation_unblocked()
	if(emergency.mode != SHUTTLE_STRANDED)
		return
	emergency.mode = SHUTTLE_DOCKED
	emergency.setTimer(emergency_dock_time)
	priority_announce("Hostile environment resolved. \
		You have 3 minutes to board the Emergency Shuttle.",
		"LRSV Icarus Announcement",
		sound_type = ANNOUNCER_SHUTTLEDOCK,
		do_not_modify = TRUE
	)

/datum/evacuation_controller/emergency_shuttle/disable_evacuation()
	if(!..())
		return FALSE
	last_mode = emergency.mode
	last_call_time = emergency.timeLeft(1)
	emergency.setTimer(0)
	emergency.mode = SHUTTLE_DISABLED
	priority_announce(
		"Warning: Emergency Shuttle uplink failure, shuttle disabled until further notice.",
		"LRSV Icarus Announcement",
		"Emergency Shuttle Uplink Alert",
		'sound/misc/announce_dig.ogg'
	)
	return TRUE

/datum/evacuation_controller/emergency_shuttle/enable_evacuation()
	if(!..())
		return FALSE
	emergency.mode = last_mode
	if(last_call_time < 10 SECONDS && last_mode != SHUTTLE_IDLE)
		last_call_time = 10 SECONDS //Make sure no insta departures.
	emergency.setTimer(last_call_time)
	priority_announce("Warning: Emergency Shuttle uplink reestablished, shuttle enabled.", "LRSV Icarus Announcement", "Emergency Shuttle Uplink Alert", 'sound/misc/announce_dig.ogg')
	return TRUE

/datum/evacuation_controller/emergency_shuttle/delay_evacuation(delay)
	..()
	emergency.setTimer(emergency.timeLeft(1) + delay)

/datum/evacuation_controller/emergency_shuttle/centcom_recall(message)
	emergency.cancel()
	//TODO: Signal changes here

	if(!message)
		message = pick(GLOB.admiral_messages)
	var/intercepttext = "<font size = 3><b>Daedalus Industries Update</b>: Request For Shuttle.</font><hr>\
						To whom it may concern:<br><br>\
						We have taken note of the situation upon [station_name()] and have come to the \
						conclusion that it does not warrant the abandonment of the station.<br>\
						If you do not agree with our opinion we suggest that you open a direct \
						line with us and explain the nature of your crisis.<br><br>\
						<i>This message has been automatically generated based upon readings from long \
						range diagnostic tools. To assure the quality of your request every finalized report \
						is reviewed by an on-call rear admiral.<br>\
						<b>Rear Admiral's Notes:</b> \
						[message]"
	print_command_report(intercepttext, announce = TRUE)

/datum/evacuation_controller/emergency_shuttle/get_stat_data()
	var/ETA = emergency.getModeStr()
	if(ETA)
		return list("[ETA] [emergency.getTimerStr()]")
	return list()

/datum/evacuation_controller/emergency_shuttle/get_world_topic_status()
	return list(
		"shuttle_mode" = emergency.mode,
		"shuttle_timer" = emergency.timeLeft()
	)

/datum/evacuation_controller/emergency_shuttle/get_discord_status()
	if(emergency.getModeStr())
		. = "[emergency.getModeStr()]: [emergency.getTimerStr()]"
		if(SSticker.emergency_reason)
			. += ", Shuttle call reason: [SSticker.emergency_reason]"
		return .
	return ""

/datum/evacuation_controller/emergency_shuttle/emergency_status_display_process(obj/machinery/status_display/evac/display)
	return list("-[emergency.getModeStr()]-", emergency.getTimerStr())

/datum/evacuation_controller/emergency_shuttle/status_display_examine(mob/user, obj/machinery/status_display/evac/display)
	return list(
		display.examine_shuttle(user, emergency)
	)

/datum/evacuation_controller/emergency_shuttle/get_evac_ui_data(mob/user)
	.=..()
	.["icon"] = "space-shuttle"
	if(state != EVACUATION_STATE_IDLE)
		.["actionName"] = "Recall Emergency Shuttle"
	else
		.["actionName"] = "Call Emergency Shuttle"

/datum/evacuation_controller/emergency_shuttle/admin_panel()
	var/list/dat = list()
	if(state == EVACUATION_STATE_IDLE)
		dat += "<a href='?_src_=holder;[HrefToken()];evac_controller=[id];call_shuttle=1'>Call Shuttle</a><br>"
	else
		dat += "[emergency.getModeStr()]: <a href='?_src_=holder;[HrefToken()];evac_controller=[id];edit_shuttle_time=1'>[emergency.getTimerStr()]</a><BR>"
		if(state == EVACUATION_STATE_INITIATED)
			dat += "<a href='?_src_=holder;[HrefToken()];evac_controller=[id];recall_shuttle=1'>Recall Shuttle</a><br>"
	return dat

/datum/evacuation_controller/emergency_shuttle/panel_act(list/href_list)
	if(!check_rights(R_ADMIN))
		return

	if(href_list["call_shuttle"] && state == EVACUATION_STATE_IDLE)
		SSevacuation.request_evacuation(usr, null, id, admin = TRUE)

	if(href_list["recall_shuttle"] && state != EVACUATION_STATE_IDLE)
		SSevacuation.request_cancel(usr, id)

	if(href_list["edit_shuttle_time"])
		var/timer = input("Enter new shuttle duration (seconds):","Edit Shuttle Timeleft", emergency.timeLeft() ) as num|null
		if(!timer)
			return
		emergency.setTimer(timer SECONDS)
		log_evacuation("[key_name(usr)] edited the Emergency Shuttle's timeleft to [timer] seconds.")
		minor_announce("The emergency shuttle will reach its destination in [DisplayTimeText(timer SECONDS)].")
		message_admins(span_adminnotice("[key_name_admin(usr)] edited the Emergency Shuttle's timeleft to [timer] seconds."))

/datum/evacuation_controller/emergency_shuttle/escape_shuttle_replaced()
	emergency = GLOB.emergency_shuttle
