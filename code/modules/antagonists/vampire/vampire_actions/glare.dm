/datum/action/cooldown/glare
	name = "Glare"
	desc = "Enfeeble a target with a single glare."
	button_icon = 'goon/icons/actions.dmi'
	button_icon_state = "hypno"
	ranged_mousepointer = 'icons/effects/mouse_pointers/cult_target.dmi'

	check_flags = AB_CHECK_CONSCIOUS
	click_to_activate = TRUE

	cooldown_time = 180 SECONDS

/datum/action/cooldown/glare/is_valid_target(atom/cast_on)
	var/mob/living/carbon/human/victim = cast_on
	if(!istype(cast_on))
		return FALSE

	if(victim == owner)
		return FALSE

	if(victim.stat != CONSCIOUS)
		return FALSE

	if(get_dist(victim, cast_on) > 2)
		to_chat(owner, span_warning("[victim] is too far away."))
		return FALSE

	if(victim.loc != owner.loc)
		var/victim_to_attacker = get_dir(victim, owner)
		if(victim.dir & REVERSE_DIR(victim_to_attacker))
			to_chat(owner, span_warning("[victim] is not looking at you."))
			return FALSE
	return TRUE

/datum/action/cooldown/glare/IsAvailable(feedback)
	. = ..()
	if(!.)
		return

	if(owner.incapacitated(IGNORE_RESTRAINTS|IGNORE_GRAB))
		if (feedback)
			to_chat(owner, span_warning("You cannot use [name] while incapacitated."))
		return FALSE

	var/mob/living/carbon/human/human_owner = owner
	var/obj/item/organ/eyes/eyes = human_owner.getorganslot(ORGAN_SLOT_EYES)
	if(!eyes || (eyes.organ_flags & ORGAN_DEAD))
		if (feedback)
			to_chat(owner, span_warning("You cannot use [name] while you have no eyes."))
		return FALSE

	if(human_owner.is_blind())
		if (feedback)
			to_chat(owner, span_warning("You cannot use [name] while you are blind."))
		return FALSE

/datum/action/cooldown/glare/Activate(atom/target)
	. = ..()
	var/mob/living/carbon/human/victim = target

	glare_visual(get_turf(owner))
	addtimer(CALLBACK(src, PROC_REF(glare_visual), victim.loc), 0.1 SECONDS)
	playsound(target, 'goon/sounds/glare.ogg', 50, TRUE, extrarange = MEDIUM_RANGE_SOUND_EXTRARANGE)
	owner.visible_message(span_notice("[owner] glances into [target]'s eyes."), vision_distance = COMBAT_MESSAGE_RANGE)

	if(victim.get_total_tint() || victim.get_eye_protection())
		return // Lol owned

	if(!victim.flash_act(INFINITY, FALSE, FALSE, TRUE))
		return // Lol owned

	victim.stamina.adjust(-300)
	victim.adjust_drowsyness(50)

/datum/action/cooldown/glare/proc/glare_visual(loc)
	new /obj/effect/temp_visual/vamp_glare(loc)
