/datum/surgery_step/sanctify
	can_infect = 0
	surgery_flags = SURGERY_CANNOT_FAIL
	min_duration = 1 SECOND
	max_duration = 2 SECONDS

	allowed_tools = list()

/datum/surgery_step/sanctify/assess_bodypart(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	var/obj/item/bodypart/affected = ..()
	if(!istype(affected, /obj/item/bodypart/chest))
		return FALSE

	return TRUE

/datum/surgery_step/sanctify/pre_surgery_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	if(target.stat != DEAD)
		to_chat(user, span_warning("They are not yet ready to pass over."))
		return FALSE

	if(!target.getorganslot(ORGAN_SLOT_BRAIN))
		to_chat(user, span_warning("They cannot be sanctified without their brain."))
		return FALSE

	if(!istype(target.getorganslot(ORGAN_SLOT_HEART), /obj/item/organ/heart/fake))
		to_chat(user, span_warning("They cannot be sanctified without perennial heart."))
		return FALSE
	return TRUE

/datum/surgery_step/sanctify/succeed_step(mob/living/user, mob/living/carbon/human/target, target_zone, obj/item/tool)
	. = ..()
	var/mob/dead/observer/ghost = target.grab_ghost() || target.ghostize()
	if(ghost)
		ghost.exorcise()

	// Robots don't understand
	var/list/exclude = list()
	for(var/mob/living/carbon/human/H in viewers(world.view, target))
		if(isipc(H))
			exclude += H

	status_effect_to_viewers(
		target,
		/datum/status_effect/skill_mod/sanctify_corpse,
		span_statsgood("You feel at peace."),
		exclude_mobs = exclude,
	)





