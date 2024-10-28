#define BRAIN_DAMAGE_THRESHOLDS 10
#define BRAIN_DECAY_RATE 1

/obj/item/organ/brain
	name = "brain"
	desc = "A piece of juicy meat found in a person's head."
	icon_state = "brain"
	visual = TRUE
	color_source = ORGAN_COLOR_STATIC
	draw_color = null
	throw_range = 5
	layer = ABOVE_MOB_LAYER
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_BRAIN
	organ_flags = ORGAN_VITAL
	attack_verb_continuous = list("attacks", "slaps", "whacks")
	attack_verb_simple = list("attack", "slap", "whack")

	///The brain's organ variables are significantly more different than the other organs, with half the decay rate for balance reasons, and twice the maxHealth
	decay_factor = STANDARD_ORGAN_DECAY * 0.5 //30 minutes of decaying to result in a fully damaged brain, since a fast decay rate would be unfun gameplay-wise

	maxHealth = BRAIN_DAMAGE_DEATH
	low_threshold = 0.5
	high_threshold = 0.75
	external_damage_modifier = 1 // Takes 100% damage.

	organ_traits = list(TRAIT_ADVANCEDTOOLUSER, TRAIT_LITERATE, TRAIT_CAN_STRIP)

	var/damage_threshold_value
	/// How many ticks we can go without oxygen before bad things start happening.
	var/oxygen_reserve = 6

	var/suicided = FALSE
	var/mob/living/brain/brainmob = null
	/// If it's a fake brain with no brainmob assigned. Feedback messages will be faked as if it does have a brainmob. See changelings & dullahans.
	var/decoy_override = FALSE
	/// Two variables necessary for calculating whether we get a brain trauma or not
	var/damage_delta = 0


	var/list/datum/brain_trauma/traumas = list()

	/// List of skillchip items, their location should be this brain.
	var/list/obj/item/skillchip/skillchips
	/// Maximum skillchip complexity we can support before they stop working. Do not reference this var directly and instead call get_max_skillchip_complexity()
	var/max_skillchip_complexity = 3
	/// Maximum skillchip slots available. Do not reference this var directly and instead call get_max_skillchip_slots()
	var/max_skillchip_slots = 5

/obj/item/organ/brain/Initialize(mapload, mob_sprite)
	. = ..()
	set_max_health(maxHealth)

/obj/item/organ/brain/PreRevivalInsertion(special)
	if(owner.mind && owner.mind.has_antag_datum(/datum/antagonist/changeling) && !special) //congrats, you're trapped in a body you don't control
		return

	if(brainmob)
		if(owner.key)
			owner.ghostize()

		if(brainmob.mind)
			brainmob.mind.transfer_to(owner)
		else
			owner.key = brainmob.key

		owner.set_suicide(brainmob.suiciding)

		QDEL_NULL(brainmob)

	else
		owner.set_suicide(suicided)

/obj/item/organ/brain/Insert(mob/living/carbon/C, special = 0)
	. = ..()
	if(!.)
		return

	name = "brain"

	if(C.mind && C.mind.has_antag_datum(/datum/antagonist/changeling) && !special) //congrats, you're trapped in a body you don't control
		if(brainmob && !(C.stat == DEAD || (HAS_TRAIT(C, TRAIT_DEATHCOMA))))
			to_chat(brainmob, span_danger("You can't feel your body! You're still just a brain!"))
		forceMove(C)
		C.update_body_parts()
		return

	for(var/X in traumas)
		var/datum/brain_trauma/BT = X
		BT.owner = owner
		BT.on_gain()

	//Update the body's icon so it doesnt appear debrained anymore
	C.update_body_parts()

/obj/item/organ/brain/Remove(mob/living/carbon/C, special = 0)
	// Delete skillchips first as parent proc sets owner to null, and skillchips need to know the brain's owner.
	if(!QDELETED(C) && length(skillchips))
		to_chat(C, span_notice("You feel your skillchips enable emergency power saving mode, deactivating as your brain leaves your body..."))
		for(var/chip in skillchips)
			var/obj/item/skillchip/skillchip = chip
			// Run the try_ proc with force = TRUE.
			skillchip.try_deactivate_skillchip(FALSE, TRUE)

	. = ..()

	for(var/X in traumas)
		var/datum/brain_trauma/BT = X
		BT.on_lose(TRUE)
		BT.owner = null

	if((!QDELING(src) || !QDELETED(owner)) && !special)
		transfer_identity(C)
	C.update_body_parts()

/obj/item/organ/brain/proc/transfer_identity(mob/living/L)
	name = "[L.name]'s brain"
	if(brainmob || decoy_override)
		return
	if(!L.mind)
		return

	brainmob = new(src)
	brainmob.set_real_name(L.real_name)
	brainmob.timeofhostdeath = L.timeofdeath
	brainmob.suiciding = suicided

	if(L.has_dna())
		var/mob/living/carbon/C = L
		if(!brainmob.stored_dna)
			brainmob.stored_dna = new /datum/dna/stored(brainmob)
		C.dna.copy_dna(brainmob.stored_dna)
		if(HAS_TRAIT(L, TRAIT_BADDNA))
			LAZYSET(brainmob.status_traits, TRAIT_BADDNA, L.status_traits[TRAIT_BADDNA])

	if(L.mind && L.mind.current)
		if(!QDELETED(L))
			L.mind.body_appearance = L.appearance
		L.mind.transfer_to(brainmob)

	to_chat(brainmob, span_notice("You feel slightly disoriented. That's normal when you're just a brain."))

/obj/item/organ/brain/attackby(obj/item/O, mob/user, params)
	user.changeNext_move(CLICK_CD_MELEE)

	if(istype(O, /obj/item/borg/apparatus/organ_storage))
		return //Borg organ bags shouldn't be killing brains

	// Cutting out skill chips.
	if(length(skillchips) && (O.sharpness & SHARP_EDGED))
		to_chat(user,span_notice("You begin to excise skillchips from [src]."))
		if(do_after(user, src, 15 SECONDS))
			for(var/chip in skillchips)
				var/obj/item/skillchip/skillchip = chip

				if(!istype(skillchip))
					stack_trace("Item of type [skillchip.type] qdel'd from [src] skillchip list.")
					qdel(skillchip)
					continue

				remove_skillchip(skillchip)

				if(skillchip.removable)
					skillchip.forceMove(drop_location())
					continue

				qdel(skillchip)

			skillchips = null
		return

	if(brainmob) //if we aren't trying to heal the brain, pass the attack onto the brainmob.
		O.attack(brainmob, user) //Oh noooeeeee

	if(O.force != 0 && !(O.item_flags & NOBLUDGEON))
		user.do_attack_animation(src)
		playsound(loc, 'sound/effects/meatslap.ogg', 50)
		setOrganDamage(maxHealth) //fails the brain as the brain was attacked, they're pretty fragile.
		visible_message(span_danger("[user] hits [src] with [O]!"))
		to_chat(user, span_danger("You hit [src] with [O]!"))

/obj/item/organ/brain/examine(mob/user)
	. = ..()
	if(length(skillchips))
		. += span_info("It has a skillchip embedded in it.")
	if(suicided)
		. += span_info("It's started turning slightly grey. They must not have been able to handle the stress of it all.")
		return
	if((brainmob && (brainmob.client || brainmob.get_ghost())) || decoy_override)
		if(organ_flags & ORGAN_DEAD)
			. += span_info("It seems to still have a bit of energy within it, but it's rather damaged... You may be able to restore it with some <b>alkysine</b>.")
		else if(damage >= BRAIN_DAMAGE_DEATH*0.5)
			. += span_info("You can feel the small spark of life still left in this one, but it's got some bruises. You may be able to restore it with some <b>alkysine</b>.")
		else
			. += span_info("You can feel the small spark of life still left in this one.")
	else
		. += span_info("This one is completely devoid of life.")

/obj/item/organ/brain/attack(mob/living/carbon/C, mob/user)
	if(!istype(C))
		return ..()

	add_fingerprint(user)

	if(user.zone_selected != BODY_ZONE_HEAD)
		return ..()

	var/target_has_brain = C.getorgan(/obj/item/organ/brain)

	if(!target_has_brain && C.is_eyes_covered())
		to_chat(user, span_warning("You're going to need to remove [C.p_their()] head cover first!"))
		return

	//since these people will be dead M != usr

	if(!target_has_brain)
		if(!C.get_bodypart(BODY_ZONE_HEAD) || !user.temporarilyRemoveItemFromInventory(src))
			return
		var/msg = "[C] has [src] inserted into [C.p_their()] head by [user]."
		if(C == user)
			msg = "[user] inserts [src] into [user.p_their()] head!"

		C.visible_message(span_danger("[msg]"),
						span_userdanger("[msg]"))

		if(C != user)
			to_chat(C, span_notice("[user] inserts [src] into your head."))
			to_chat(user, span_notice("You insert [src] into [C]'s head."))
		else
			to_chat(user, span_notice("You insert [src] into your head.") )

		Insert(C)
	else
		..()

/obj/item/organ/brain/Destroy() //copypasted from MMIs.
	if(brainmob)
		QDEL_NULL(brainmob)
	QDEL_LIST(traumas)

	destroy_all_skillchips()
	if(owner?.mind) //You aren't allowed to return to brains that don't exist
		owner.mind.set_current(null)
	return ..()

/obj/item/organ/brain/set_max_health(new_health)
	. = ..()
	damage_threshold_value = round(maxHealth / BRAIN_DAMAGE_THRESHOLDS)

/obj/item/organ/brain/proc/past_damage_threshold(threshold)
	return round(damage / damage_threshold_value) > threshold

/obj/item/organ/brain/on_life(delta_time, times_fired)
	handle_damage_effects()

	// Brain damage from low oxygenation or lack of blood.
	if(!owner.needs_organ(ORGAN_SLOT_HEART))
		return ..()

	// Brain damage from low oxygenation or lack of blood.
	// No heart? You are going to have a very bad time. Not 100% lethal because heart transplants should be a thing.
	var/blood_percent = owner.get_blood_oxygenation()
	if(blood_percent < BLOOD_CIRC_SURVIVE)
		if(!CHEM_EFFECT_MAGNITUDE(owner, CE_STABLE) || prob(60))
			oxygen_reserve = max(0, oxygen_reserve-1)
	else
		oxygen_reserve = min(initial(oxygen_reserve), oxygen_reserve+1)

	if(!oxygen_reserve) //(hardcrit)
		if(!(TRAIT_KNOCKEDOUT in organ_traits))
			add_organ_trait(TRAIT_KNOCKEDOUT)
			log_health(owner, "Passed out due to brain oxygen reaching zero. BLOOD OXY: [blood_percent]%")
	else if(TRAIT_KNOCKEDOUT in organ_traits)
		log_health(owner, "Brain now has enough oxygen.")
		remove_organ_trait(TRAIT_KNOCKEDOUT)

	var/can_heal = damage && damage < maxHealth && (damage % damage_threshold_value || CHEM_EFFECT_MAGNITUDE(owner, CE_BRAIN_REGEN) || (!past_damage_threshold(3) && owner.chem_effects[CE_STABLE]))
	var/damprob
	//Effects of bloodloss
	switch(blood_percent)
		if(BLOOD_CIRC_SAFE to INFINITY)
			if(can_heal)
				applyOrganDamage(-1)

		if(BLOOD_CIRC_OKAY to BLOOD_CIRC_SAFE)
			if(owner.stat == CONSCIOUS && prob(1))
				to_chat(owner, span_warning("You feel [pick("dizzy","woozy","faint")]..."))
			damprob = CHEM_EFFECT_MAGNITUDE(owner, CE_STABLE) ? 30 : 60
			if(!past_damage_threshold(2) && prob(damprob))
				applyOrganDamage(BRAIN_DECAY_RATE, cause_of_death = "Hypoxemia")

		if(BLOOD_CIRC_BAD to BLOOD_CIRC_OKAY)
			owner.blur_eyes(6)
			damprob = CHEM_EFFECT_MAGNITUDE(owner, CE_STABLE) ? 40 : 80
			if(!past_damage_threshold(4) && prob(damprob))
				applyOrganDamage(BRAIN_DECAY_RATE, cause_of_death = "Hypoxemia")

			if(owner.stat == CONSCIOUS && prob(10))
				log_health(owner, "Passed out due to poor blood oxygenation, random chance.")
				to_chat(owner, span_warning("You feel extremely [pick("dizzy","woozy","faint")]..."))
				owner.Unconscious(rand(1,3) SECONDS)

		if(BLOOD_CIRC_SURVIVE to BLOOD_CIRC_BAD)
			owner.blur_eyes(6)
			damprob = CHEM_EFFECT_MAGNITUDE(owner, CE_STABLE) ? 60 : 100
			if(!past_damage_threshold(6) && prob(damprob))
				applyOrganDamage(BRAIN_DECAY_RATE, updating_health = FALSE, cause_of_death = "Hypoxemia")

			if(owner.stat == CONSCIOUS && prob(15))
				log_health(owner, "Passed out due to poor blood oxygenation, random chance.")
				owner.Unconscious(rand(3,5) SECONDS)
				to_chat(owner, span_warning("You feel extremely [pick("dizzy","woozy","faint")]..."))

		if(-(INFINITY) to BLOOD_VOLUME_SURVIVE) // Also see heart.dm, being below this point puts you into cardiac arrest.
			owner.blur_eyes(6)
			damprob = CHEM_EFFECT_MAGNITUDE(owner, CE_STABLE) ? 80 : 100
			if(prob(damprob))
				applyOrganDamage(BRAIN_DECAY_RATE, updating_health = FALSE, cause_of_death = "Hypoxemia")
			if(prob(damprob))
				applyOrganDamage(BRAIN_DECAY_RATE, updating_health = FALSE, cause_of_death = "Hypoxemia")
	. = ..()

/obj/item/organ/brain/check_damage_thresholds(mob/M)
	. = ..()
	//if we're not more injured than before, return without gambling for a trauma
	if(damage <= prev_damage)
		return
	damage_delta = damage - prev_damage
	if(damage > BRAIN_DAMAGE_SEVERE)
		if(prob(damage_delta * (1 + max(0, (damage - BRAIN_DAMAGE_MILD)/100)))) //Base chance is the hit damage; for every point of damage past the threshold the chance is increased by 1% //learn how to do your bloody math properly goddamnit
			gain_trauma_type(BRAIN_TRAUMA_MILD, natural_gain = TRUE)

	var/is_boosted = (owner && HAS_TRAIT(owner, TRAIT_SPECIAL_TRAUMA_BOOST))
	if(damage > BRAIN_DAMAGE_CRITICAL)
		if(prob(damage_delta * (1 + max(0, (damage - BRAIN_DAMAGE_SEVERE)/100)))) //Base chance is the hit damage; for every point of damage past the threshold the chance is increased by 1%
			if(prob(20 + (is_boosted * 30)))
				gain_trauma_type(BRAIN_TRAUMA_SPECIAL, is_boosted ? TRAUMA_RESILIENCE_SURGERY : null, natural_gain = TRUE)
			else
				gain_trauma_type(BRAIN_TRAUMA_SEVERE, natural_gain = TRUE)

	if (owner && damage >= (maxHealth * high_threshold) && prev_damage < (maxHealth * high_threshold))
		handle_severe_brain_damage()

/obj/item/organ/brain/proc/handle_severe_brain_damage()
	set waitfor = FALSE
	to_chat(owner, span_notice(span_reallybig("<B>Where am I...?</B>")))
	sleep(5 SECONDS)
	if (QDELETED(src) || !owner || owner.stat == DEAD || (organ_flags & ORGAN_DEAD))
		return

	to_chat(owner, span_notice(span_reallybig("<B>What's going on...?</B>")))
	sleep(10 SECONDS)
	if (QDELETED(src) || !owner || owner.stat == DEAD || (organ_flags & ORGAN_DEAD))
		return

	to_chat(owner, span_notice(span_reallybig("<B>What happened...?</B>")))
	alert(owner, "You have taken massive brain damage! This could affect speech, memory, or any other skill, but provided you've been treated, it shouldn't be permanent.", "Brain Damaged")

/obj/item/organ/brain/proc/handle_damage_effects()
	if(owner.stat)
		return

	if(damage > 0 && prob(1))
		owner.pain_message("Your head feels numb and painful.", 10)

	if(damage >= (maxHealth * low_threshold) && prob(1) && owner.eye_blurry <= 0)
		to_chat(owner, span_warning("It becomes hard to see for some reason."))
		owner.blur_eyes(10)

	if(damage >= 0.5*maxHealth && prob(1) && owner.get_active_hand())
		to_chat(owner, span_danger("Your hand won't respond properly, and you drop what you are holding!"))
		owner.dropItemToGround(owner.get_active_held_item())

	if(damage >= 0.6*maxHealth)
		owner.set_slurring_if_lower(10 SECONDS)

	if(damage >= (maxHealth * high_threshold))
		if(owner.body_position == STANDING_UP)
			to_chat(owner, span_danger("You black out!"))
		owner.Unconscious(5 SECOND)

/obj/item/organ/brain/applyOrganDamage(damage_amount, maximum, silent, updating_health = TRUE, cause_of_death = "Organ failure")
	. = ..()
	if(. >= 20) //This probably won't be triggered by oxyloss or mercury. Probably.
		var/damage_secondary = min(. * 0.2, 20)
		if (owner)
			owner.flash_act(visual = TRUE)
			owner.blur_eyes(.)
			owner.adjust_confusion(. SECONDS)
			owner.Unconscious(damage_secondary SECONDS)

/obj/item/organ/brain/getToxLoss()
	return 0

/obj/item/organ/brain/set_organ_dead(failing, cause_of_death)
	. = ..()
	if(!.)
		return
	if(failing)
		if(owner)
			owner.death(cause_of_death = cause_of_death)
		else if(brainmob)
			brainmob.death(cause_of_death = cause_of_death)
		return
	else
		if(owner)
			owner.revive()
		else if(brainmob)
			brainmob.revive()
		return

/obj/item/organ/brain/before_organ_replacement(obj/item/organ/replacement)
	. = ..()
	var/obj/item/organ/brain/replacement_brain = replacement
	if(!istype(replacement_brain))
		return

	// If we have some sort of brain type or subtype change and have skillchips, engage the failsafe procedure!
	if(owner && length(skillchips) && (replacement_brain.type != type))
		activate_skillchip_failsafe(FALSE)

	// Check through all our skillchips, remove them from this brain, add them to the replacement brain.
	for(var/chip in skillchips)
		var/obj/item/skillchip/skillchip = chip

		// We're technically doing a little hackery here by bypassing the procs, but I'm the one who wrote them
		// and when you know the rules, you can break the rules.

		// Technically the owning mob is the same. We don't need to activate or deactivate the skillchips.
		// All the skillchips themselves care about is what brain they're in.
		// Because the new brain will ultimately be owned by the same body, we can safely leave skillchip logic alone.

		// Directly change the new holding_brain.
		skillchip.holding_brain = replacement_brain
		//And move the actual obj into the new brain (contents)
		skillchip.forceMove(replacement_brain)

		// Directly add them to the skillchip list in the new brain.
		LAZYADD(replacement_brain.skillchips, skillchip)

	// Any skillchips has been transferred over, time to empty the list.
	LAZYCLEARLIST(skillchips)

/obj/item/organ/brain/machine_wash(obj/machinery/washing_machine/brainwasher)
	. = ..()
	if(HAS_TRAIT(brainwasher, TRAIT_BRAINWASHING))
		setOrganDamage(0)
		cure_all_traumas(TRAUMA_RESILIENCE_LOBOTOMY)
	else
		setOrganDamage(BRAIN_DAMAGE_DEATH)

/obj/item/organ/brain/alien
	name = "alien brain"
	desc = "We barely understand the brains of terrestial animals. Who knows what we may find in the brain of such an advanced species?"
	icon_state = "brain-x"
	organ_traits = list(TRAIT_CAN_STRIP)

/obj/item/organ/brain/vox
	name = "cortical stack"
	desc = "A peculiarly advanced bio-electronic device that seems to hold the memories and identity of a Vox."
	icon_state = "cortical-stack"
	organ_flags = ORGAN_SYNTHETIC|ORGAN_VITAL

/obj/item/organ/brain/vox/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(owner.stat == DEAD)
		return
	switch(severity)
		if(1)
			to_chat(owner, span_boldwarning("You feel [pick("like your brain is being fried", "a sharp pain in your head")]!"))
			owner.adjustOrganLoss(ORGAN_SLOT_BRAIN, 20, 150)
			owner.adjust_timed_status_effect(30 SECONDS, /datum/status_effect/jitter)
			owner.adjust_timed_status_effect(30 SECONDS, /datum/status_effect/speech/stutter)
			owner.adjust_timed_status_effect(10 SECONDS, /datum/status_effect/confusion)
		if(2)
			to_chat(owner, span_warning("You feel [pick("disoriented", "confused", "dizzy")]."))
			owner.adjustOrganLoss(ORGAN_SLOT_BRAIN, 10, 150)
			owner.adjust_timed_status_effect(10 SECONDS, /datum/status_effect/jitter)
			owner.adjust_timed_status_effect(10 SECONDS, /datum/status_effect/speech/stutter)
			owner.adjust_timed_status_effect(3 SECONDS, /datum/status_effect/confusion)


////////////////////////////////////TRAUMAS////////////////////////////////////////

/obj/item/organ/brain/proc/has_trauma_type(brain_trauma_type = /datum/brain_trauma, resilience = TRAUMA_RESILIENCE_ABSOLUTE)
	for(var/X in traumas)
		var/datum/brain_trauma/BT = X
		if(istype(BT, brain_trauma_type) && (BT.resilience <= resilience))
			return BT

/obj/item/organ/brain/proc/get_traumas_type(brain_trauma_type = /datum/brain_trauma, resilience = TRAUMA_RESILIENCE_ABSOLUTE)
	. = list()
	for(var/X in traumas)
		var/datum/brain_trauma/BT = X
		if(istype(BT, brain_trauma_type) && (BT.resilience <= resilience))
			. += BT

/obj/item/organ/brain/proc/can_gain_trauma(datum/brain_trauma/trauma, resilience, natural_gain = FALSE)
	if(!ispath(trauma))
		trauma = trauma.type
	if(!initial(trauma.can_gain))
		return FALSE
	if(!resilience)
		resilience = initial(trauma.resilience)

	var/resilience_tier_count = 0
	for(var/X in traumas)
		if(istype(X, trauma))
			return FALSE
		var/datum/brain_trauma/T = X
		if(resilience == T.resilience)
			resilience_tier_count++

	var/max_traumas
	switch(resilience)
		if(TRAUMA_RESILIENCE_BASIC)
			max_traumas = TRAUMA_LIMIT_BASIC
		if(TRAUMA_RESILIENCE_SURGERY)
			max_traumas = TRAUMA_LIMIT_SURGERY
		if(TRAUMA_RESILIENCE_WOUND)
			max_traumas = TRAUMA_LIMIT_WOUND
		if(TRAUMA_RESILIENCE_LOBOTOMY)
			max_traumas = TRAUMA_LIMIT_LOBOTOMY
		if(TRAUMA_RESILIENCE_MAGIC)
			max_traumas = TRAUMA_LIMIT_MAGIC
		if(TRAUMA_RESILIENCE_ABSOLUTE)
			max_traumas = TRAUMA_LIMIT_ABSOLUTE

	if(natural_gain && resilience_tier_count >= max_traumas)
		return FALSE
	return TRUE

//Proc to use when directly adding a trauma to the brain, so extra args can be given
/obj/item/organ/brain/proc/gain_trauma(datum/brain_trauma/trauma, resilience, ...)
	var/list/arguments = list()
	if(args.len > 2)
		arguments = args.Copy(3)
	. = brain_gain_trauma(trauma, resilience, arguments)

//Direct trauma gaining proc. Necessary to assign a trauma to its brain. Avoid using directly.
/obj/item/organ/brain/proc/brain_gain_trauma(datum/brain_trauma/trauma, resilience, list/arguments)
	if(!can_gain_trauma(trauma, resilience))
		return FALSE

	var/datum/brain_trauma/actual_trauma
	if(ispath(trauma))
		if(!LAZYLEN(arguments))
			actual_trauma = new trauma() //arglist with an empty list runtimes for some reason
		else
			actual_trauma = new trauma(arglist(arguments))
	else
		actual_trauma = trauma

	if(actual_trauma.brain) //we don't accept used traumas here
		WARNING("gain_trauma was given an already active trauma.")
		return FALSE

	traumas += actual_trauma
	actual_trauma.brain = src
	if(owner)
		actual_trauma.owner = owner
		SEND_SIGNAL(owner, COMSIG_CARBON_GAIN_TRAUMA, trauma)
		actual_trauma.on_gain()
	if(resilience)
		actual_trauma.resilience = resilience
	SSblackbox.record_feedback("tally", "traumas", 1, actual_trauma.type)
	return actual_trauma

//Add a random trauma of a certain subtype
/obj/item/organ/brain/proc/gain_trauma_type(brain_trauma_type = /datum/brain_trauma, resilience, natural_gain = FALSE)
	var/list/datum/brain_trauma/possible_traumas = list()
	for(var/T in subtypesof(brain_trauma_type))
		var/datum/brain_trauma/BT = T
		if(can_gain_trauma(BT, resilience, natural_gain) && initial(BT.random_gain))
			possible_traumas += BT

	if(!LAZYLEN(possible_traumas))
		return

	var/trauma_type = pick(possible_traumas)
	return gain_trauma(trauma_type, resilience)

//Cure a random trauma of a certain resilience level
/obj/item/organ/brain/proc/cure_trauma_type(brain_trauma_type = /datum/brain_trauma, resilience = TRAUMA_RESILIENCE_BASIC)
	var/list/traumas = get_traumas_type(brain_trauma_type, resilience)
	if(LAZYLEN(traumas))
		qdel(pick(traumas))

/obj/item/organ/brain/proc/cure_all_traumas(resilience = TRAUMA_RESILIENCE_BASIC)
	var/amount_cured = 0
	var/list/traumas = get_traumas_type(resilience = resilience)
	for(var/X in traumas)
		qdel(X)
		amount_cured++
	return amount_cured

/// This proc lets the mob's brain decide what bodypart to attack with in an unarmed strike.
/obj/item/organ/brain/proc/get_attacking_limb(mob/living/carbon/human/target)
	var/obj/item/bodypart/arm/active_hand = owner.get_active_hand()

	if(target.body_position == LYING_DOWN && owner.usable_legs)
		var/obj/item/bodypart/found_bodypart = owner.get_bodypart((active_hand.held_index % 2) ? BODY_ZONE_L_LEG : BODY_ZONE_R_LEG)
		return found_bodypart || active_hand

	return active_hand

/obj/item/organ/brain/get_scan_results(tag)
	. = ..()
	var/list/traumas = owner?.get_traumas()
	if(!length(traumas))
		return

	var/list/trauma_text = list()

	for(var/datum/brain_trauma/trauma in traumas)
		var/trauma_desc = ""
		switch(trauma.resilience)
			if(TRAUMA_RESILIENCE_SURGERY)
				trauma_desc += "severe "
			if(TRAUMA_RESILIENCE_LOBOTOMY)
				trauma_desc += "deep-rooted "
			if(TRAUMA_RESILIENCE_WOUND)
				trauma_desc += "fracture-derived "
			if(TRAUMA_RESILIENCE_MAGIC, TRAUMA_RESILIENCE_ABSOLUTE)
				trauma_desc += "permanent "
		trauma_desc += trauma.scan_desc
		trauma_text += trauma_desc
	. += tag ? "<span style='font-weight: bold; color:#ff9933'>Cerebral traumas detected: [english_list(trauma_text)]</span>" : "Cerebral traumas detected: [english_list(trauma_text)]"

#undef BRAIN_DAMAGE_THRESHOLDS
#undef BRAIN_DECAY_RATE
