#define DRAIN_INFO_INDEX_TIME "time"
#define DRAIN_INFO_INDEX_BUDGET "amt"

/// How much blood we can siphon from a target per SAME_TARGET_COOLDOWN
#define BLOOD_DRAIN_PER_TARGET 100
/// Drain per second
#define BLOOD_DRAIN_RATE 5
/// Coeff for calculating thirst satiation per unit of blood.
#define BLOOD_THIRST_EXCHANGE_COEFF 18 // A full drain is equivalent to 15 minutes of life.
/// The amount of time before a victim can be fully drained again.
#define SAME_TARGET_COOLDOWN (10 MINUTES)
/// Calculate how much of a mob's blood budget will have been regenerated over a given time.
#define BUDGET_REGEN_FOR_DELTA(time_delta) (time_delta * (BLOOD_DRAIN_PER_TARGET / SAME_TARGET_COOLDOWN))

/datum/action/cooldown/neck_bite
	name = "Feed"
	desc = "Sate the thirst by sinking your teeth into the neck of a humanoid."
	button_icon = 'goon/icons/actions.dmi'
	button_icon_state = "bite"

	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_HANDS_BLOCKED

	/// A k:v list of weakref(mob) : blood_drained
	var/list/already_drained = list()

/datum/action/cooldown/neck_bite/process()
	// Kind of hacky but I can't be bothered to care. We can accurately track all unavailable -> available transitions, but not the other way around.
	if(IsAvailable())
		build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/cooldown/neck_bite/Grant(mob/granted_to)
	. = ..()
	RegisterSignal(granted_to, list(COMSIG_LIVING_START_GRAB, COMSIG_LIVING_NO_LONGER_GRABBING, COMSIG_LIVING_GRAB_DOWNGRADE, COMSIG_LIVING_GRAB_UPGRADE), PROC_REF(on_owner_grab_change))
	START_PROCESSING(SSslowprocess, src)

/datum/action/cooldown/neck_bite/Remove(mob/removed_from)
	. = ..()
	UnregisterSignal(removed_from, list(COMSIG_LIVING_START_GRAB, COMSIG_LIVING_NO_LONGER_GRABBING, COMSIG_LIVING_GRAB_DOWNGRADE, COMSIG_LIVING_GRAB_UPGRADE))
	START_PROCESSING(SSslowprocess, src)

/datum/action/cooldown/neck_bite/IsAvailable(feedback)
	. = ..()
	if(!.)
		return

	var/error = ""
	if(!select_target(&error))
		if(feedback && error)
			to_chat(owner, span_warning(error))
		return FALSE

	return TRUE

/datum/action/cooldown/neck_bite/Activate(atom/target)
	var/mob/living/carbon/human/user = target
	var/mob/living/carbon/human/victim = select_target()

	user.visible_message(span_danger("[user] bites down on [victim]'s neck!"), vision_distance = COMBAT_MESSAGE_RANGE)

	var/datum/callback/checks_callback = CALLBACK(src, PROC_REF(can_bite), user, victim)
	if(!do_after(user, victim, 3 SECONDS, DO_IGNORE_HELD_ITEM|DO_IGNORE_SLOWDOWNS|DO_PUBLIC, extra_checks = checks_callback, display = image('goon/icons/actions.dmi', "bite")))
		return FALSE

	. = ..()

	spawn(-1)
		ADD_TRAIT(user, TRAIT_MUTE, ref(src))
		var/image/succ_image = image('goon/icons/actions.dmi', "blood")
		while(TRUE)
			if(!can_bite(user, victim))
				break

			if(!do_after(user, victim, 1 SECOND, DO_IGNORE_HELD_ITEM|DO_IGNORE_SLOWDOWNS|DO_PUBLIC, extra_checks = checks_callback, display = succ_image))
				user.visible_message(span_notice("[user] removes [p_their()] teeth from [victim]'s neck."))
				break

			siphon_blood(user, victim)

		REMOVE_TRAIT(user, TRAIT_MUTE, ref(src))

/datum/action/cooldown/neck_bite/proc/siphon_blood(mob/living/carbon/human/user, mob/living/carbon/human/victim)
	user.visible_message(span_danger("[user] siphons blood from [victim]'s neck!"), vision_distance = COMBAT_MESSAGE_RANGE, ignored_mobs = victim)
	if(victim.stat == CONSCIOUS)
		to_chat(victim, span_danger("You can feel blood draining from your neck."))

	if(isturf(victim.loc))
		victim.add_splatter_floor(victim.loc, TRUE)

	var/list/drain_info = already_drained[WEAKREF(victim)]
	if(isnull(drain_info))
		// Set default
		already_drained[WEAKREF(victim)] = drain_info = list(
			DRAIN_INFO_INDEX_TIME = world.time,
			DRAIN_INFO_INDEX_BUDGET = BLOOD_DRAIN_PER_TARGET - BLOOD_DRAIN_RATE,
		)
	else
		var/last_drain_time = drain_info[DRAIN_INFO_INDEX_TIME]
		var/last_budget = drain_info[DRAIN_INFO_INDEX_BUDGET]

		var/time_delta = world.time - last_drain_time
		var/new_budget_val = last_budget - BLOOD_DRAIN_RATE + BUDGET_REGEN_FOR_DELTA(time_delta)
		drain_info[DRAIN_INFO_INDEX_BUDGET] = clamp(new_budget_val, 0, BLOOD_DRAIN_PER_TARGET)
		drain_info[DRAIN_INFO_INDEX_TIME] = world.time

	victim.adjustBloodVolume(-BLOOD_DRAIN_RATE)
	user.adjustBloodVolumeUpTo(BLOOD_DRAIN_RATE, BLOOD_VOLUME_NORMAL)

	var/datum/antagonist/vampire/vamp_datum = user.mind.has_antag_datum(/datum/antagonist/vampire)
	vamp_datum.thirst_level.remove_points(BLOOD_DRAIN_RATE * BLOOD_THIRST_EXCHANGE_COEFF)
	vamp_datum.update_thirst_stage()

	var/had_victim = vamp_datum.last_victim_ref
	vamp_datum.last_victim_ref = WEAKREF(victim)
	if(!had_victim)
		var/datum/action/cooldown/blood_track/track = locate() in owner.actions
		if(track)
			track.build_all_button_icons(UPDATE_BUTTON_STATUS)

	victim.add_trace_DNA(user, user.get_trace_dna())

	// Draining an opposing vampire really, really messes them up.
	var/datum/antagonist/vampire/victim_vamp_datum = victim.mind?.has_antag_datum(/datum/antagonist/vampire)
	if(victim_vamp_datum)
		victim_vamp_datum.thirst_level.add_points(-(BLOOD_DRAIN_RATE * BLOOD_THIRST_EXCHANGE_COEFF))
		victim_vamp_datum.update_thirst_stage()

	else if(prob(1)) // A chance to spread the plague!
		var/datum/pathogen/blood_plague/vampirism = new /datum/pathogen/blood_plague
		victim.try_contract_pathogen(vampirism, FALSE, TRUE)

	build_all_button_icons(UPDATE_BUTTON_STATUS)

/datum/action/cooldown/neck_bite/proc/can_bite(mob/living/carbon/human/user, mob/living/carbon/human/victim, error_string_ptr)
	if(!owner)
		return FALSE

	if(victim.stat == DEAD)
		if(error_string_ptr)
			*error_string_ptr = "You cannot feast on the dead."
		return FALSE

	if(!user.is_grabbing(victim))
		return FALSE

	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(!head || !IS_ORGANIC_LIMB(head))
		if(error_string_ptr)
			*error_string_ptr = "[victim] does not have a neck."
		return FALSE

	if(victim.blood_volume < BLOOD_DRAIN_PER_TARGET)
		if(error_string_ptr)
			*error_string_ptr = "[victim] does not have enough blood."
		return FALSE

	var/list/drain_info = already_drained[WEAKREF(victim)]
	if(length(drain_info))
		var/left_to_drain = drain_info[DRAIN_INFO_INDEX_BUDGET]
		var/time_delta = world.time - drain_info[DRAIN_INFO_INDEX_TIME]
		var/regenerated_blood = BUDGET_REGEN_FOR_DELTA(time_delta)
		var/effective_budget = left_to_drain + regenerated_blood
		if(effective_budget < BLOOD_DRAIN_RATE)
			if(error_string_ptr)
				*error_string_ptr = "You must wait before draining [victim] again."
			return FALSE

	return TRUE

/// Gets a possible victim, or returns null.
/datum/action/cooldown/neck_bite/proc/select_target(error_string_ptr)
	var/mob/living/carbon/human/user = owner

	if(!length(user.active_grabs))
		if(error_string_ptr)
			*error_string_ptr = "You aren't holding anyone."
		return null

	for(var/obj/item/hand_item/grab/grab in user.active_grabs)
		var/mob/living/carbon/human/potential_victim = grab.affecting
		if(!ishuman(potential_victim) || ismonkey(potential_victim))
			if(ismob(potential_victim) && error_string_ptr)
				*error_string_ptr = "You cannot feast on [potential_victim]."
			continue

		if((grab.current_grab.damage_stage < GRAB_NECK))
			if(error_string_ptr)
				*error_string_ptr = "You need a stronger grip on [potential_victim]."
			continue

		if(can_bite(user, potential_victim, error_string_ptr))
			return potential_victim

	return null

/// Called when the owner grabs or releases an object.
/datum/action/cooldown/neck_bite/proc/on_owner_grab_change(datum/source)
	SIGNAL_HANDLER

	build_all_button_icons(UPDATE_BUTTON_STATUS)

#undef DRAIN_INFO_INDEX_TIME
#undef DRAIN_INFO_INDEX_BUDGET
#undef BLOOD_DRAIN_PER_TARGET
#undef SAME_TARGET_COOLDOWN
#undef BLOOD_DRAIN_RATE
#undef BUDGET_REGEN_FOR_DELTA
