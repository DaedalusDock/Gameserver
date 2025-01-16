/obj/item/swab
	name = "swab"
	desc = "A sterilized cotton swab and vial used to take forensic samples."
	icon = 'icons/obj/forensics.dmi'
	icon_state = "swab"

	item_flags = parent_type::item_flags | NOBLUDGEON | NO_EVIDENCE_ON_ATTACK

	var/used = FALSE

	var/sample_name
	var/datum/forensics/swabbed_forensics

/obj/item/swab/Initialize(mapload)
	. = ..()
	swabbed_forensics = new()

/obj/item/swab/Destroy(force)
	QDEL_NULL(swabbed_forensics)
	return ..()

/obj/item/swab/update_name(updates)
	name = "[initial(name)] ([sample_name])"
	return ..()

/obj/item/swab/update_icon_state()
	. = ..()
	if(used)
		icon_state = "swab_used"

/obj/item/swab/attack(mob/living/M, mob/living/user, params)
	if(!ishuman(M))
		return ..()

	if(used)
		return

	var/mob/living/carbon/human/target = M

	// Resisting
	if(user != target && (target.combat_mode && target.body_position == STANDING_UP && !target.incapacitated()))
		user.visible_message(span_warning("[user] tries to swab [target], but they move away."))
		return

	// Swab their mouth.
	if(user.zone_selected == BODY_ZONE_PRECISE_MOUTH)
		if(!target.get_bodypart(BODY_ZONE_HEAD))
			to_chat(user, span_warning("They have no head."))
			return TRUE
		if(!target.has_mouth())
			to_chat(user, span_warning("They have no mouth."))
			return TRUE
		if(!target.has_dna())
			to_chat(user, span_warning("You feel like this wouldn't be useful."))
			return TRUE

		user.visible_message(span_notice("[user] swabs [target]'s mouth."))
		swabbed_forensics.add_trace_DNA(target.get_trace_dna())
		set_used(target.get_face_name())
		return TRUE

	var/zone = deprecise_zone(user.zone_selected)
	var/obj/item/bodypart/BP = target.get_bodypart(zone)
	if(!BP)
		to_chat(user, span_warning("They don't have \a [zone]"))
		return TRUE

	if(target.get_item_covering_bodypart(BP))
		return FALSE

	if(!is_valid_target(target))
		to_chat(user, span_warning("[target] has nothing to swab on their body."))
		return TRUE

	return TRUE

/obj/item/swab/afterattack(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	if(used)
		to_chat(user, span_warning("This swab has been used."))
		return

	if(ishuman(target))
		var/mob/living/carbon/H = target
		target = H.get_item_covering_zone(deprecise_zone(user.zone_selected))
		if(!target)
			return
		if(!is_valid_target(target))
			to_chat(user, span_warning("There is no evidence on [H]'s [target]."))
			return

	if(!is_valid_target(target))
		to_chat(user, span_warning("There is no evidence on [target]."))
		return

	swabbed_forensics.add_trace_DNA(target.return_trace_DNA())
	swabbed_forensics.add_blood_DNA(target.return_blood_DNA())
	swabbed_forensics.add_gunshot_residue_list(target.return_gunshot_residue())
	set_used(target)
	user.visible_message(span_notice("[user] swabs [target]."))
	return TRUE

/obj/item/swab/proc/set_used(sample_name)
	used = TRUE
	src.sample_name = "[sample_name]"
	update_appearance()

/obj/item/swab/proc/is_valid_target(atom/target)
	return length(target.return_blood_DNA()) || length(target.return_trace_DNA()) || length(target.return_gunshot_residue())
