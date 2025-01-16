/datum/antagonist/vampire
	name = "\improper Sanguine Plague Victim"
	roundend_category = "vampires"
	antagpanel_category = "Vampire"
	job_rank = ROLE_VAMPIRE
	antag_hud_name = "traitor"

	/// The thirst!
	var/datum/point_holder/thirst_level = 0
	var/thirst_stage

	var/list/current_states = list()
	var/list/state_datums

	/// Weakref to the last mob drained of blood.
	var/datum/weakref/last_victim_ref

	var/list/innate_actions = list(
		/datum/action/cooldown/neck_bite,
		/datum/action/cooldown/glare,
	)

/datum/antagonist/vampire/New()
	. = ..()
	thirst_level = new()
	thirst_level.add_points(THIRST_THRESHOLD_SATED)
	thirst_level.set_max_points(THIRST_THRESHOLD_DEAD)

	state_datums = list(
		new /datum/vampire_state/bloodlust(src),
		new /datum/vampire_state/sated(src),
		new /datum/vampire_state/hungry(src),
		new /datum/vampire_state/starving(src),
		new /datum/vampire_state/wasting(src),
	)

	for(var/datum/action_path as anything in innate_actions)
		innate_actions -= action_path
		innate_actions += new action_path

/datum/antagonist/vampire/Destroy()
	thirst_level = null
	QDEL_LIST(state_datums)
	return ..()

/datum/antagonist/vampire/on_gain()
	. = ..()
	START_PROCESSING(SSprocessing, src)

/datum/antagonist/vampire/on_removal()
	. = ..()
	STOP_PROCESSING(SSprocessing, src)

/datum/antagonist/vampire/process(delta_time)
	var/mob/living/carbon/human/host = owner.current
	if(!istype(host))
		return

	if(host.stat == DEAD)
		return

	thirst_level.add_points(1)
	update_thirst_stage()

	for(var/datum/vampire_state/current as anything in current_states)
		current.tick(delta_time, host)

/// Sync the thirst stage with the current thirst level.
/datum/antagonist/vampire/proc/update_thirst_stage()
	var/mob/living/carbon/human/host = owner.current
	if(!istype(host))
		return

	var/new_stage
	switch(thirst_level.has_points())
		if(THIRST_THRESHOLD_BLOODLUST to THIRST_THRESHOLD_SATED-1)
			new_stage = THIRST_STAGE_BLOODLUST

		if(THIRST_THRESHOLD_SATED to THIRST_THRESHOLD_HUNGERY-1)
			new_stage = THIRST_STAGE_SATED

		if(THIRST_THRESHOLD_HUNGERY to THIRST_THRESHOLD_STARVING-1)
			new_stage = THIRST_STAGE_HUNGRY

		if(THIRST_THRESHOLD_STARVING to THIRST_THRESHOLD_WASTING-1)
			new_stage = THIRST_STAGE_STARVING

		if(THIRST_THRESHOLD_WASTING to THIRST_THRESHOLD_DEAD-1)
			new_stage = THIRST_STAGE_WASTING

		if(THIRST_THRESHOLD_DEAD to INFINITY)
			death_by_thirst(host)
			return

	set_thirst_stage(new_stage)

/datum/antagonist/vampire/apply_innate_effects(mob/living/mob_override = owner.current)
	if(!ishuman(mob_override))
		return

	var/datum/pathogen/blood_plague/plague = new /datum/pathogen/blood_plague
	if(!mob_override.has_pathogen(plague) && mob_override.try_contract_pathogen(plague, FALSE, TRUE))
		plague.set_stage(3)

	for(var/datum/action/action as anything in innate_actions)
		action.Grant(mob_override)

	for(var/datum/vampire_state/state as anything in current_states)
		state.apply_effects(mob_override)

/datum/antagonist/vampire/remove_innate_effects(mob/living/mob_override = owner.current)
	. = ..()
	if(!ishuman(mob_override))
		return

	for(var/datum/action/action as anything in innate_actions)
		action.Remove(mob_override)

	for(var/datum/vampire_state/state as anything in current_states)
		state.remove_effects(mob_override)

/// You died cuz you aint suckin' hard enough
/datum/antagonist/vampire/proc/death_by_thirst(mob/living/carbon/human/host)
	host.death(cause_of_death = "The Thirst")
	host.setBloodVolume(0)

	for(var/obj/item/organ/O as anything in host.processing_organs)
		if(O.organ_flags & ORGAN_SYNTHETIC)
			continue

		O.germ_level = INFECTION_LEVEL_THREE
		O.set_organ_dead(TRUE)

	thirst_level.remove_points(INFINITY)

/// Setter for the thirst stage.
/datum/antagonist/vampire/proc/set_thirst_stage(new_stage)
	var/old_stage = thirst_stage
	thirst_stage = new_stage
	if(old_stage == thirst_stage)
		return null

	var/mob/living/carbon/human/host = owner.current

	var/list/potential_states = state_datums - current_states
	for(var/datum/vampire_state/current as anything in current_states)
		if(!current.can_be_active())
			current.exit_state(host)
			current_states -= current

	for(var/datum/vampire_state/potential as anything in potential_states)
		if(potential.can_be_active())
			current_states += potential
			potential.enter_state(host)

	var/datum/vampire_state/current_state = current_states[length(current_states)]
	if(!old_stage || thirst_stage < old_stage)
		to_chat(host, current_state.regress_into_message)
	else
		to_chat(host, current_state.progress_into_message)

	return old_stage
