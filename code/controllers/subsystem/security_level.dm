SUBSYSTEM_DEF(security_level)
	name = "Security Level"
	flags = SS_NO_FIRE
	/// Currently set security level
	var/current_level = SEC_LEVEL_GREEN
	var/list/datum/keycard_auth_action/kad_actions

/datum/controller/subsystem/security_level/Initialize(start_timeofday)

	kad_actions = list()
	for(var/datum/keycard_auth_action/kaa_type as anything in subtypesof(/datum/keycard_auth_action))
		if(isabstract(kaa_type) || !initial(kaa_type.available_roundstart))
			continue
		kad_actions[kaa_type] = new kaa_type

	. = ..()

/**
 * Sets a new security level as our current level
 *
 * Arguments:
 * * new_level The new security level that will become our current level
 */
/datum/controller/subsystem/security_level/proc/set_level(new_level)
	var/old_level = SSsecurity_level.current_level
	SSsecurity_level.current_level = new_level
	SEND_SIGNAL(src, COMSIG_SECURITY_LEVEL_CHANGED, old_level, new_level)
	SSnightshift.check_nightshift()
	SSblackbox.record_feedback("tally", "security_level_changes", 1, get_security_level())
