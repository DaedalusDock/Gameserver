/datum/vampire_state
	var/datum/antagonist/vampire/parent

	/// The minimum stage for this datum to be active.
	var/min_stage
	/// Actions to grant while this stage is active.
	var/list/actions_to_grant

	/// A message sent when entering this state from a higher one (a good thing)
	var/regress_into_message
	/// A message sent when entering this state from a lower one (a bad thing)
	var/progress_into_message

/datum/vampire_state/New(datum/antagonist/vampire/_parent)
	parent = _parent

	for(var/datum/action/action as anything in actions_to_grant)
		actions_to_grant -= action
		action = new action
		actions_to_grant += action

/datum/vampire_state/Destroy(force, ...)
	parent.state_datums -= src
	parent = null
	QDEL_LIST(actions_to_grant)
	return ..()

/// If this stage can be active.
/datum/vampire_state/proc/can_be_active()
	return parent.thirst_stage >= min_stage

/datum/vampire_state/proc/enter_state(mob/living/carbon/human/host)
	SHOULD_CALL_PARENT(TRUE)
	apply_effects(host)

/// Called when a vampire past this stage is regressing.
/datum/vampire_state/proc/exit_state(mob/living/carbon/human/host)
	SHOULD_CALL_PARENT(TRUE)
	remove_effects(host)

/// Called every second this state is active.
/datum/vampire_state/proc/tick(delta_time, mob/living/carbon/human/host)
	return

/// Apply persistent effects to the mob.
/datum/vampire_state/proc/apply_effects(mob/living/carbon/human/host)
	SHOULD_CALL_PARENT(TRUE)

	for(var/datum/action/action as anything in actions_to_grant)
		action.Grant(host)

/// Remove persistent effects from the mob.
/datum/vampire_state/proc/remove_effects(mob/living/carbon/human/host)
	SHOULD_CALL_PARENT(TRUE)

	for(var/datum/action/action as anything in actions_to_grant)
		action.Remove(host)
