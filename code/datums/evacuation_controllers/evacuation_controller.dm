/datum/evacuation_controller
	/// Name of the evacuation controller
	var/name = "Evacuation Controller"
	/// The type of the evacuation controller
	var/id = "evacuation_controller"
	/// The current state of the evacuation
	var/state = EVACUATION_STATE_IDLE
	/// How many times was evacuation triggered
	var/evac_calls_count = 0
	/// Where was the last evacuation call
	var/area/last_evac_call_loc
	/// Did admins block the recall of evacuation
	var/cancel_disabled = FALSE
	/// Did admins block the evacuation
	var/evacuation_disabled = FALSE
	/// The time until the evacuation is delayed.
	/// Used to prevent canceling to reset the timer
	var/delayed_until = 0

/// Returns the current state of the evacuation
/datum/evacuation_controller/proc/get_state()
	switch(state)
		if(EVACUATION_STATE_IDLE)
			return "Idle"
		if(EVACUATION_STATE_INITIATED)
			return "Initiadited"
		if(EVACUATION_STATE_AWAITING)
			return "Awaiting crew"
		if(EVACUATION_STATE_EVACUATED)
			return "Past point of no return"
		if(EVACUATION_STATE_FINISHED)
			return "Finished"

/// Whether we can trigger evacuation sequence at the moment.
/// Returns either TRUE or a string with the reason why it's not possible
/datum/evacuation_controller/proc/can_evac(mob/user)
	if(evacuation_disabled)
		return "Evacuation is disabled"
	if(state != EVACUATION_STATE_IDLE)
		return "Evacuation is already in progress"
	return TRUE

/// Triggers the evacuation sequence, if possible
/datum/evacuation_controller/proc/trigger_evacuation(mob/user, call_reason, admin)
	var/can_evac_or_fail_reason = can_evac(user)
	if(can_evac_or_fail_reason != TRUE)
		to_chat(user, span_alert("[can_evac_or_fail_reason]"))
		return FALSE
	log_evacuation("[key_name(user)] has start the evacuation.")

	var/area/signal_origin = get_area(user)
	if(!admin && prob(70))
		last_evac_call_loc = signal_origin
	else
		last_evac_call_loc = null
	start_evacuation(user, call_reason)

	deadchat_broadcast(" has started the evacuation at [span_name("[signal_origin.name]")].", span_name("[user.real_name]"), user, message_type=DEADCHAT_ANNOUNCEMENT)
	if(call_reason)
		SSblackbox.record_feedback("text", "shuttle_reason", 1, "[call_reason]")
		log_evacuation("Evacuation reason: [call_reason]")
		SSticker.emergency_reason = call_reason
	message_admins("[ADMIN_LOOKUPFLW(user)] has started the evacuation. (<A HREF='?_src_=holder;[HrefToken()];trigger_centcom_recall=[id]'>TRIGGER CENTCOM RECALL</A>)")
	return TRUE

/// Starts the evacuation sequence. Should not be called directly, use trigger_evacuation instead
/datum/evacuation_controller/proc/start_evacuation(mob/user, call_reason)
	CRASH("start_evacuation not implemented. Type: [type]")

/// Starts the automatic evacuation sequence
/// Called when round is going for too long, when most of the crew is dead, etc.
/datum/evacuation_controller/proc/start_automatic_evacuation(reason)
	CRASH("start_automatic_evacuation not implemented. Type: [type]")

/// Whether we can cancel the evacuation sequence at the moment
/datum/evacuation_controller/proc/can_cancel(mob/user)
	if(SSevacuation.cancel_blocked || cancel_disabled)
		return FALSE
	if(delayed_until > world.time)
		return FALSE
	if(state == EVACUATION_STATE_IDLE || state >= EVACUATION_STATE_EVACUATED)
		return FALSE
	return TRUE

/// Cancels the evacuation sequence, if possible
/datum/evacuation_controller/proc/trigger_cancel_evacuation(mob/user, admin)
	if(!can_cancel(user))
		return FALSE
	log_evacuation("[key_name(user)] has canceled the evacuation.")
	var/area/signal_origin = get_area(user)
	if(!admin && prob(70))
		last_evac_call_loc = signal_origin
	else
		last_evac_call_loc = null
	cancel_evacuation(user)
	SSticker.emergency_reason = null
	message_admins("[ADMIN_LOOKUPFLW(user)] has canceled the evacuation.")
	deadchat_broadcast(" has canceled the evacuation from [span_name("[signal_origin.name]")].", span_name("[user.real_name]"), user, message_type=DEADCHAT_ANNOUNCEMENT)
	return TRUE

/// Cancels the evacuation sequence. Should not be called directly, use trigger_cancel_evacuation instead
/datum/evacuation_controller/proc/cancel_evacuation(mob/user)
	CRASH("trigger_cancel_evacuation not implemented. Type: [type]")

/// Returns a list of shuttles that can be replaced with a custom shuttle
/datum/evacuation_controller/proc/get_customizable_shuttles()
	return list()

/// Returns assoc list of evac areas = TRUE. E.g. escape pods, shuttles, etc. Doesn't include CentCom
/datum/evacuation_controller/proc/get_endgame_areas()
	return list()

/// Called when the evacuation is blocked for some reason
/datum/evacuation_controller/proc/evacuation_blocked()
	return

/// Called when the evacuation is unblocked
/datum/evacuation_controller/proc/evacuation_unblocked()
	return

/// Called when admins force-disable evacuation
/datum/evacuation_controller/proc/disable_evacuation()
	if(evacuation_disabled)
		return FALSE
	evacuation_disabled = TRUE
	return TRUE

/// Called when admins re-enable evacuation
/datum/evacuation_controller/proc/enable_evacuation()
	if(!evacuation_disabled)
		return FALSE
	evacuation_disabled = FALSE
	return TRUE

/// Called when admins force-disable evacuation cancellation
/datum/evacuation_controller/proc/block_cancel()
	if(cancel_disabled)
		return FALSE
	cancel_disabled = TRUE
	return TRUE

/// Called when admins allow cancellation of evacuation
/datum/evacuation_controller/proc/unblock_cancel()
	if(!cancel_disabled)
		return FALSE
	cancel_disabled = FALSE
	return TRUE

/// Called when you need to delay the evacuation for some reason.
/datum/evacuation_controller/proc/delay_evacuation(delay)
	if(delayed_until > world.time)
		delayed_until = world.time + delay
	else
		delayed_until += delay

/// Called when admin cancels the evacuation through CentCom for RP reasons
/datum/evacuation_controller/proc/centcom_recall(message)
	return

/// Returns a list of strings to display in the evacuation status panel
/datum/evacuation_controller/proc/get_stat_data()
	return list()

/// Returns assoc list of world status
/datum/evacuation_controller/proc/get_world_topic_status()
	return list()

/// Returns a string with the current state of the evacuation for the Discord message
/datum/evacuation_controller/proc/get_discord_status()
	return ""

/// Returns a string with the current state of the evacuation for the status display
/datum/evacuation_controller/proc/emergency_status_display_process(obj/machinery/status_display/evac/display)
	return // should return list with 2 strings

/// Returns a list of strigns to display when examining the status display during evacuation
/datum/evacuation_controller/proc/status_display_examine(mob/user, obj/machinery/status_display/evac/display)
	return list()

/// Returns data for the communication console
/datum/evacuation_controller/proc/get_evac_ui_data(mob/user)
	. = list(
		"id" = id, // unique identifier for the evacuation
		"started" = null, // if the evacuation has started
		"actionName" = null, // name for the button to call or recall
		"canEvacOrRecall" = null, // whether the user can call or recall the evacuation. If not, the reason
		"status" = null, // current status of the evacuation
		"traceString" = null, // string to display if last evacuation call was traced
		"icon" = null,
	)

	if(state != EVACUATION_STATE_IDLE)
		.["started"] = TRUE
		.["actionName"] = "Cancel Evacuation ([name]})"
		.["canEvacOrRecall"] = can_cancel(user)
		.["status"] = get_state()
	else
		.["started"] = FALSE
		.["actionName"] = "Start Evacuation [name]"
		.["canEvacOrRecall"] = can_evac(user)

	if(last_evac_call_loc)
		.["traceString"] = "Last evacuation call was traced to [last_evac_call_loc]"
	else if(evac_calls_count > 0)
		.["traceString"] = "Unable to trace last evacuation call"

	return .

/datum/evacuation_controller/proc/admin_panel()
	return list()

/datum/evacuation_controller/proc/panel_act(list/href_list)
	return

/datum/evacuation_controller/proc/escape_shuttle_replaced()
	return
