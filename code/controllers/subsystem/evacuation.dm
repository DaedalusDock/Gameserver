#define CREW_DEATH_MESSAGE "Automatically starting evacuation sequence due to crew death."

SUBSYSTEM_DEF(evacuation)
	name = "Evacuation"
	wait = 1 SECONDS
	init_order = INIT_ORDER_EVACUATION
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_GAME
	/// Controllers that handle the evacuation of the station
	var/list/datum/evacuation_controller/controllers = list()
	/// A list of things blocking evacuation
	var/list/evacuation_blockers = list()
	/// Whether you can cancel evacuation. Used by automatic evacuation
	var/cancel_blocked = FALSE

/datum/controller/subsystem/evacuation/Initialize(start_timeofday)
	for(var/path in SSmapping.config.evacuation_controllers)
		var/datum/evacuation_controller/controller = new path
		controllers[controller.id] = controller
	return ..()

/datum/controller/subsystem/evacuation/fire(resumed)
	if(!SSticker.HasRoundStarted() || length(evacuation_blockers))
		return

	var/threshold = CONFIG_GET(number/evacuation_autocall_threshold)
	if(!threshold)
		return

	var/alive = 0
	for(var/mob/M as anything in GLOB.player_list)
		if(M.stat != DEAD)
			++alive

	var/total = length(GLOB.joined_player_list)
	if(total <= 0)
		return

	if(alive / total > threshold)
		return

	message_admins(CREW_DEATH_MESSAGE)
	log_evacuation("[CREW_DEATH_MESSAGE] Alive: [alive], Roundstart: [total], Threshold: [threshold]")
	priority_announce("Catastrophic casualties detected: crisis evacuation protocols activated - blocking recall signals across all channels.")
	trigger_auto_evac(EVACUATION_REASON_CREW_DEATH)

/datum/controller/subsystem/evacuation/proc/trigger_auto_evac(reason)
	cancel_blocked = TRUE
	for(var/identifier in controllers)
		if(controllers[identifier].state != EVACUATION_STATE_IDLE)
			return
		if(controllers[identifier].start_automatic_evacuation(reason))
			return

/datum/controller/subsystem/evacuation/proc/can_evac(mob/caller, controller_id)
	var/datum/evacuation_controller/controller = controllers[controller_id]
	if(!controller)
		stack_trace("Invalid controller ID")
		return "Error 500. Please contact your system administrator."
	for(var/identifier in controllers)
		if(controllers[identifier].state >= EVACUATION_STATE_AWAITING)
			return "Evacuation is already in progress."
	return controller.can_evac(caller)

/datum/controller/subsystem/evacuation/proc/request_evacuation(mob/caller, reason, controller_id, admin = FALSE)
	var/datum/evacuation_controller/controller = controllers[controller_id]
	if(!controller)
		CRASH("Evacuation was requested for an invalid controller \"[controller_id]\"")
	for(var/identifier in controllers)
		if(controllers[identifier].state >= EVACUATION_STATE_AWAITING)
			to_chat(caller, "Evacuation is already in progress.")
			return
	return controller.trigger_evacuation(caller, reason, admin)

/datum/controller/subsystem/evacuation/proc/can_cancel(mob/caller, controller_id)
	var/datum/evacuation_controller/controller = controllers[controller_id]
	if(!controller)
		stack_trace("can_cancel() was passed an invalid controller ID")
		return "Error 500. Please contact your system administrator."
	return controller.can_cancel(caller)

/datum/controller/subsystem/evacuation/proc/request_cancel(mob/caller, controller_id)
	var/datum/evacuation_controller/controller = controllers[controller_id]
	if(!controller)
		CRASH("Evacuation cancel was requested for an invalid controller \"[controller_id]\"")
	controller.trigger_cancel_evacuation(caller)

/datum/controller/subsystem/evacuation/proc/add_evacuation_blocker(datum/bad)
	evacuation_blockers += bad
	if(length(evacuation_blockers) == 1)
		for(var/identifier in controllers)
			controllers[identifier].evacuation_blocked()

/datum/controller/subsystem/evacuation/proc/remove_evacuation_blocker(datum/bad)
	evacuation_blockers -= bad
	if(!length(evacuation_blockers))
		for(var/identifier in controllers)
			controllers[identifier].evacuation_unblocked()

/datum/controller/subsystem/evacuation/proc/disable_evacuation(controller_id)
	if(!controllers[controller_id])
		CRASH("Tried to disable evacuation for an invalid controller \"[controller_id]\"")
	controllers[controller_id].disable_evacuation()

/datum/controller/subsystem/evacuation/proc/enable_evacuation(controller_id)
	if(!controllers[controller_id])
		CRASH("Tried to enable evacuation for an invalid controller \"[controller_id]\"")
	controllers[controller_id].enable_evacuation()

/datum/controller/subsystem/evacuation/proc/block_cancel(controller_id)
	if(!controllers[controller_id])
		CRASH("Tried to block cancel for an invalid controller \"[controller_id]\"")
	controllers[controller_id].block_cancel()

/datum/controller/subsystem/evacuation/proc/unblock_cancel(controller_id)
	if(!controllers[controller_id])
		CRASH("Tried to unblock cancel for an invalid controller \"[controller_id]\"")
	controllers[controller_id].unblock_cancel()

//Perhaps move it to SShuttle?
/datum/controller/subsystem/evacuation/proc/get_customizable_shuttles()
	var/list/shuttles = list()
	for(var/identifier in controllers)
		shuttles += controllers[identifier].get_customizable_shuttles()
	return shuttles

/datum/controller/subsystem/evacuation/proc/get_endgame_areas()
	var/list/areas = list()
	for(var/identifier in controllers)
		var/datum/evacuation_controller/controller = controllers[identifier]
		// We only want to add the areas if the controller is in a state where evacuation has finished
		if(controller.state >= EVACUATION_STATE_EVACUATED)
			areas += controller.get_endgame_areas()
	return areas

/datum/controller/subsystem/evacuation/proc/get_stat_data()
	var/list/data = list()
	for(var/identifier in controllers)
		data += controllers[identifier].get_stat_data()
	return data

/datum/controller/subsystem/evacuation/proc/get_world_topic_status()
	var/list/status = list()
	for(var/identifier in controllers)
		status += controllers[identifier].get_world_topic_status()
	return status

/datum/controller/subsystem/evacuation/proc/evacuation_in_progress()
	for(var/identifier in controllers)
		if(controllers[identifier].state == EVACUATION_STATE_AWAITING)
			return TRUE
	return FALSE

/datum/controller/subsystem/evacuation/proc/evacuation_can_be_cancelled()
	for(var/identifier in controllers)
		if(!controllers[identifier].can_cancel(null))
			return FALSE
	return TRUE

/datum/controller/subsystem/evacuation/proc/station_evacuated()
	for(var/identifier in controllers)
		if(controllers[identifier].state >= EVACUATION_STATE_EVACUATED)
			return TRUE
	return FALSE

/datum/controller/subsystem/evacuation/proc/evacuation_finished()
	for(var/identifier in controllers)
		if(controllers[identifier].state >= EVACUATION_STATE_FINISHED)
			return TRUE
	return FALSE

/datum/controller/subsystem/evacuation/proc/delay_evacuation(controller_id, delay)
	if(!controllers[controller_id])
		CRASH("Tried to delay evacuation for an invalid controller \"[controller_id]\"")
	controllers[controller_id].delay_evacuation(delay)

/datum/controller/subsystem/evacuation/proc/get_controllers_names(active_only = FALSE)
	var/list/names = list()
	for(var/identifier in controllers)
		if(!active_only || controllers[identifier].state >= EVACUATION_STATE_AWAITING)
			names[controllers[identifier].name] = identifier
	return names

/datum/controller/subsystem/evacuation/proc/get_controllers_list_ai()
	var/list/names = list()
	for(var/identifier in controllers)
		names["[controllers[identifier].name] | [controllers[identifier].get_state()]"] = identifier
	return names

/datum/controller/subsystem/evacuation/proc/get_initiated_controller()
	for(var/identifier in controllers)
		if(controllers[identifier].state == EVACUATION_STATE_INITIATED)
			return identifier
	return null

/datum/controller/subsystem/evacuation/proc/get_discord_status()
	. = ""
	for(var/identifier in controllers)
		if(controllers[identifier].state != EVACUATION_STATE_IDLE)
			. += "\n" + controllers[identifier].get_discord_status()
	return .

/datum/controller/subsystem/evacuation/proc/emergency_status_display_process(obj/machinery/status_display/evac/display)
	for(var/identifier in controllers)
		if(controllers[identifier].state != EVACUATION_STATE_IDLE)
			. = controllers[identifier].emergency_status_display_process(display)
			if(.)
				return .
	return list("", "")

/datum/controller/subsystem/evacuation/proc/status_display_examine(mob/user, obj/machinery/status_display/evac/display)
	. = list()
	for(var/identifier in controllers)
		. += controllers[identifier].status_display_examine(user, display)
	return .

/datum/controller/subsystem/evacuation/proc/centcom_recall(identifier, message)
	if(controllers[identifier])
		if(controllers[identifier].state != EVACUATION_STATE_INITIATED)
			return
		controllers[identifier].centcom_recall(message)

/datum/controller/subsystem/evacuation/proc/get_evac_ui_data(mob/user)
	var/list/data = list()
	for(var/identifier in controllers)
		data += list(controllers[identifier].get_evac_ui_data(user))
	return data

/datum/controller/subsystem/evacuation/proc/panel_act(list/href_list)
	if(href_list["evac_controller"])
		controllers[href_list["evac_controller"]]?.panel_act(href_list)

/datum/controller/subsystem/evacuation/proc/admin_panel()
	var/list/dat = list("<html><head><meta http-equiv='Content-Type' content='text/html; charset=UTF-8'><title>Evacuation Panel</title></head><body><h1><B>Evacuation Panel</B></h1>")
	for(var/identifier in controllers)
		dat += "<hr>"
		dat += "<h3><B>[controllers[identifier].name]</B></h3><br/>"
		dat += controllers[identifier].admin_panel()
	usr << browse(dat.Join(), "window=evac_panel;size=500x500")
	return

/datum/controller/subsystem/evacuation/proc/escape_shuttle_replaced()
	for(var/identifier in controllers)
		controllers[identifier].escape_shuttle_replaced()

#undef CREW_DEATH_MESSAGE
