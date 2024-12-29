/mob/living/carbon/Initialize(mapload)
	. = ..()
	create_carbon_reagents()
	update_body_parts() //to update the carbon's new bodyparts appearance
	register_context()

	// Carbons cannot taste anything without a tongue; the tongue organ removes this on Insert
	ADD_TRAIT(src, TRAIT_AGEUSIA, NO_TONGUE_TRAIT)

	GLOB.carbon_list += src
	AddComponent(/datum/component/carbon_sprint)

/mob/living/carbon/Destroy()
	//This must be done first, so the mob ghosts correctly before DNA etc is nulled
	. = ..()
	QDEL_NULL(bloodstream)
	QDEL_NULL(touching)
	QDEL_LIST(hand_bodyparts)
	QDEL_LIST(organs)
	QDEL_LIST(bodyparts)
	QDEL_LIST(implants)

	remove_from_all_data_huds()
	QDEL_NULL(dna)
	GLOB.carbon_list -= src

///Humans need to init these early for species purposes
/mob/living/carbon/proc/create_carbon_reagents()
	if(reagents)
		return
	bloodstream = new /datum/reagents{metabolism_class = CHEM_BLOOD}(120)
	bloodstream.my_atom = src

	reagents = bloodstream

	touching = new /datum/reagents{metabolism_class = CHEM_TOUCH}(1000)
	touching.my_atom = src

/mob/living/carbon/swap_hand(held_index)
	. = ..()
	if(!.)
		return

	if(!held_index)
		held_index = (active_hand_index % held_items.len)+1

	if(!isnum(held_index))
		CRASH("You passed [held_index] into swap_hand instead of a number. WTF man")

	var/oindex = active_hand_index
	active_hand_index = held_index

	if(hud_used)
		var/atom/movable/screen/inventory/hand/H
		H = hud_used.hand_slots["[oindex]"]
		if(H)
			H.update_appearance()
		H = hud_used.hand_slots["[held_index]"]
		if(H)
			H.update_appearance()

	update_mouse_pointer()

/mob/living/carbon/activate_hand(selhand) //l/r OR 1-held_items.len
	if(!selhand)
		selhand = (active_hand_index % held_items.len)+1

	if(istext(selhand))
		selhand = lowertext(selhand)
		if(selhand == "right" || selhand == "r")
			selhand = 2
		if(selhand == "left" || selhand == "l")
			selhand = 1

	if(selhand != active_hand_index)
		swap_hand(selhand)
	else
		mode() // Activate held item

/mob/living/carbon/CtrlShiftClick(mob/user)
	..()
	if(iscarbon(user))
		var/mob/living/carbon/carbon_user = user
		carbon_user.give(src)

/mob/living/carbon/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	. = ..()
	var/hurt = TRUE
	var/extra_speed = 0
	if(throwingdatum.thrower != src)
		extra_speed = min(max(0, throwingdatum.speed - initial(throw_speed)), CARBON_MAX_IMPACT_SPEED_BONUS)

	if(istype(throwingdatum))
		hurt = !throwingdatum.gentle
	if(hurt && hit_atom.density)
		if(isturf(hit_atom))
			Paralyze(2 SECONDS)
			take_bodypart_damage(10 + 5 * extra_speed, check_armor = TRUE)
		else if(isstructure(hit_atom) && extra_speed)
			Paralyze(1 SECONDS)
			take_bodypart_damage(5 + 5 * extra_speed, check_armor = TRUE)
		else if(!iscarbon(hit_atom) && extra_speed)
			take_bodypart_damage(5 * extra_speed, check_armor = TRUE)
	if(iscarbon(hit_atom) && hit_atom != src)
		var/mob/living/carbon/victim = hit_atom
		if(victim.movement_type & FLYING)
			return
		if(hurt)
			victim.take_bodypart_damage(10 + 5 * extra_speed, check_armor = TRUE)
			take_bodypart_damage(10 + 5 * extra_speed, check_armor = TRUE)
			victim.Knockdown(0.1 SECONDS)
			Paralyze(2 SECONDS)
			visible_message(span_danger("[src] crashes into [victim][extra_speed ? " really hard" : ""], knocking them both over!"),\
				span_userdanger("You violently crash into [victim][extra_speed ? " extra hard" : ""]!"))
		playsound(src, SFX_PUNCH ,50,TRUE)
		log_combat(src, victim, "crashed into")

//Throwing stuff
/mob/living/carbon/proc/toggle_throw_mode()
	if(stat)
		return
	if(throw_mode)
		throw_mode_off(THROW_MODE_TOGGLE)
	else
		throw_mode_on(THROW_MODE_TOGGLE)


/mob/living/carbon/proc/throw_mode_off(method)
	if(throw_mode > method) //A toggle doesnt affect a hold
		return
	throw_mode = THROW_MODE_DISABLED
	if(hud_used)
		hud_used.throw_icon.icon_state = "act_throw_off"
	update_mouse_pointer()


/mob/living/carbon/proc/throw_mode_on(mode = THROW_MODE_TOGGLE)
	throw_mode = mode
	if(hud_used)
		hud_used.throw_icon.icon_state = "act_throw_on"
	update_mouse_pointer()

/mob/proc/throw_item(atom/target)
	SEND_SIGNAL(src, COMSIG_MOB_THROW, target)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CARBON_THROW_THING, src, target)
	return

/mob/living/carbon/throw_item(atom/target)
	. = ..()
	throw_mode_off(THROW_MODE_TOGGLE)
	if(!target || !isturf(loc))
		return
	if(istype(target, /atom/movable/screen))
		return

	var/atom/movable/thrown_thing
	var/obj/item/I = get_active_held_item()
	if(isnull(I))
		return

	var/neckgrab_throw = FALSE // we can't check for if it's a neckgrab throw when totaling up power_throw since we've already stopped pulling them by then, so get it early

	if(isgrab(I))
		var/obj/item/hand_item/grab/G = I
		if(isitem(G.affecting))
			I = G.affecting
			thrown_thing = I.on_thrown(src, target)
			if(!thrown_thing)
				return
			release_grabs(I)
		else
			if(!G.current_grab.can_throw || !isliving(G.affecting) || G.affecting == src)
				return

			var/mob/living/throwable_mob = G.affecting
			if(!throwable_mob.buckled)
				thrown_thing = throwable_mob
				if(G.current_grab.damage_stage >= GRAB_NECK)
					neckgrab_throw = TRUE
				release_grabs(throwable_mob)
				if(HAS_TRAIT(src, TRAIT_PACIFISM))
					to_chat(src, span_notice("You gently let go of [throwable_mob]."))
					return
	else
		thrown_thing = I.on_thrown(src, target)

	if(!thrown_thing)
		return

	if(isliving(thrown_thing))
		var/turf/start_T = get_turf(loc) //Get the start and target tile for the descriptors
		var/turf/end_T = get_turf(target)
		if(start_T && end_T)
			log_combat(src, thrown_thing, "thrown", addition="grab from tile in [AREACOORD(start_T)] towards tile at [AREACOORD(end_T)]")

	var/power_throw = 0
	if(HAS_TRAIT(src, TRAIT_HULK))
		power_throw++
	if(HAS_TRAIT(src, TRAIT_DWARF))
		power_throw--
	if(HAS_TRAIT(thrown_thing, TRAIT_DWARF))
		power_throw++
	if(neckgrab_throw)
		power_throw++

	do_attack_animation(target, no_effect = TRUE) //PARIAH EDIT ADDITION - AESTHETICS
	playsound(loc, 'sound/weapons/punchmiss.ogg', 50, TRUE, -1) //PARIAH EDIT ADDITION - AESTHETICS
	visible_message(span_danger("[src] throws [thrown_thing][power_throw ? " really hard!" : "."]"), \
					span_danger("You throw [thrown_thing][power_throw ? " really hard!" : "."]"))
	log_message("has thrown [thrown_thing] [power_throw ? "really hard" : ""]", LOG_ATTACK)
	newtonian_move(get_dir(target, src))
	thrown_thing.safe_throw_at(target, thrown_thing.throw_range, thrown_thing.throw_speed + power_throw, src, null, null, null, move_force)


/mob/living/carbon/proc/canBeHandcuffed()
	return FALSE

/mob/living/carbon/on_fall()
	. = ..()
	loc.handle_fall(src)//it's loc so it doesn't call the mob's handle_fall which does nothing

/mob/living/carbon/is_muzzled()
	if(!has_mouth())
		return FALSE
	for (var/obj/item/clothing/clothing in get_equipped_items())
		if(clothing.clothing_flags & BLOCKS_SPEECH)
			return TRUE
	return FALSE

/mob/living/carbon/hallucinating()
	if(hallucination)
		return TRUE
	else
		return FALSE

/mob/living/carbon/resist_buckle()
	if(HAS_TRAIT(src, TRAIT_ARMS_RESTRAINED))
		changeNext_move(CLICK_CD_BREAKOUT)
		last_special = world.time + CLICK_CD_BREAKOUT
		var/buckle_cd = 60 SECONDS

		if(handcuffed)
			var/obj/item/restraints/O = src.get_item_by_slot(ITEM_SLOT_HANDCUFFED)
			buckle_cd = O.breakouttime

		visible_message(
			span_warning("[src] attempts to unbuckle [p_them()]self!"),
			span_notice("You attempt to unbuckle yourself... (This will take around [round(buckle_cd/600,1)] minute\s, and you need to stay still.)")

		)

		if(do_after(src, src, buckle_cd, timed_action_flags = DO_IGNORE_HELD_ITEM))
			if(!buckled)
				return
			return !!buckled.user_unbuckle_mob(src,src)
		else
			if(src && buckled)
				to_chat(src, span_warning("You fail to unbuckle yourself!"))
	else
		return !!buckled.user_unbuckle_mob(src,src)

/mob/living/carbon/resist_fire()
	adjust_fire_stacks(-5)
	Paralyze(60, ignore_canstun = TRUE)
	spin(32,2)
	visible_message(
		span_danger("[src] rolls on the floor, trying to put [p_them()]self out!"), \
		span_danger("You hurl yourself to the floor, rolling frantically around!"))
	sleep(30)
	return

/mob/living/carbon/resist_restraints()
	var/obj/item/I = null
	var/type = 0

	if(handcuffed)
		I = handcuffed
		type = 1

	else if(legcuffed)
		I = legcuffed
		type = 2

	if(I)
		if(type == 1)
			changeNext_move(CLICK_CD_BREAKOUT)
			last_special = world.time + CLICK_CD_BREAKOUT

		if(type == 2)
			changeNext_move(CLICK_CD_RANGE)
			last_special = world.time + CLICK_CD_RANGE

		cuff_resist(I)


/mob/living/carbon/proc/cuff_resist(obj/item/I, breakouttime = 1 MINUTES, cuff_break = 0)
	if(I.item_flags & BEING_REMOVED)
		to_chat(src, span_warning("You're already attempting to remove [I]!"))
		return
	if(buckled)
		to_chat(src, span_warning("There is no hope for escape."))
		return

	I.item_flags |= BEING_REMOVED
	breakouttime = I.breakouttime

	if(!cuff_break)
		visible_message(span_warning("[src] attempts to remove [I]!"))
		to_chat(src, span_notice("You attempt to remove [I]... (This will take around [DisplayTimeText(breakouttime)] and you need to stand still.)"))

		if(do_after(src, src, breakouttime, timed_action_flags = DO_IGNORE_HELD_ITEM))
			. = clear_cuffs(I, cuff_break)
		else
			to_chat(src, span_warning("You fail to remove [I]!"))

	else if(cuff_break == FAST_CUFFBREAK)
		breakouttime = 50
		visible_message(span_warning("[src] is trying to break [I]!"))
		to_chat(src, span_notice("You attempt to break [I]... (This will take around 5 seconds and you need to stand still.)"))

		if(do_after(src, src, breakouttime, timed_action_flags = DO_IGNORE_HELD_ITEM))
			. = clear_cuffs(I, cuff_break)
		else
			to_chat(src, span_warning("You fail to break [I]!"))

	else if(cuff_break == INSTANT_CUFFBREAK)
		. = clear_cuffs(I, cuff_break)

	I.item_flags &= ~BEING_REMOVED

/mob/living/carbon/proc/remove_handcuffs(new_location, cuff_break, silent)
	if(!handcuffed)
		return FALSE

	if(!silent)
		visible_message(span_danger("[src] manages to [cuff_break ? "break" : "remove"] [handcuffed]!"))

	if(cuff_break)
		qdel(handcuffed)
	else
		transferItemToLoc(handcuffed, new_location, TRUE)
	return TRUE

/mob/living/carbon/proc/remove_legcuffs(new_location, cuff_break, silent)
	if(!legcuffed)
		return FALSE

	if(!silent)
		visible_message(span_danger("[src] manages to [cuff_break ? "break" : "remove"] [legcuffed]!"))

	if(cuff_break)
		qdel(legcuffed)
	else
		transferItemToLoc(legcuffed, new_location, TRUE)
	return TRUE

/mob/living/carbon/proc/clear_cuffs(obj/item/I, cuff_break)
	if(!I.loc || buckled)
		return FALSE

	if(I != handcuffed && I != legcuffed)
		return FALSE

	if(I == handcuffed)
		return remove_handcuffs(drop_location(), cuff_break)

	if(I == legcuffed)
		return remove_legcuffs(drop_location(), cuff_break)

/mob/living/carbon/proc/accident(obj/item/I)
	if(!I || (I.item_flags & ABSTRACT) || HAS_TRAIT(I, TRAIT_NODROP))
		return

	dropItemToGround(I)

	var/modifier = 0
	if(HAS_TRAIT(src, TRAIT_CLUMSY))
		modifier -= 40 //Clumsy people are more likely to hit themselves -Honk!

	switch(rand(1,100)+modifier) //91-100=Nothing special happens
		if(-INFINITY to 0) //attack yourself
			INVOKE_ASYNC(I, TYPE_PROC_REF(/obj/item, attack), src, src)
		if(1 to 30) //throw it at yourself
			I.throw_impact(src)
		if(31 to 60) //Throw object in facing direction
			var/turf/target = get_turf(loc)
			var/range = rand(2,I.throw_range)
			for(var/i in 1 to range-1)
				var/turf/new_turf = get_step(target, dir)
				target = new_turf
				if(new_turf.density)
					break
			I.throw_at(target,I.throw_range,I.throw_speed,src)
		if(61 to 90) //throw it down to the floor
			var/turf/target = get_turf(loc)
			I.safe_throw_at(target,I.throw_range,I.throw_speed,src, force = move_force)

/mob/living/carbon/get_status_tab_items()
	. = ..()
	var/obj/item/organ/alien/plasmavessel/vessel = getorgan(/obj/item/organ/alien/plasmavessel)
	if(vessel)
		. += "Plasma Stored: [vessel.stored_plasma]/[vessel.max_plasma]"
	var/obj/item/organ/heart/vampire/darkheart = getorgan(/obj/item/organ/heart/vampire)
	if(darkheart)
		. += "Current blood level: [blood_volume]/[BLOOD_VOLUME_MAXIMUM]."
	if(locate(/obj/item/assembly/health) in src)
		. += "Health: [health]"

/mob/living/carbon/attack_ui(slot, params)
	if(!has_hand_for_held_index(active_hand_index))
		return 0
	return ..()

/mob/living/carbon/proc/vomit(lost_nutrition = 10, blood = FALSE, stun = TRUE, distance = 1, message = TRUE, vomit_type = VOMIT_TOXIC, harm = TRUE, force = FALSE, purge_ratio = 0.1)
	if((HAS_TRAIT(src, TRAIT_NOHUNGER) || HAS_TRAIT(src, TRAIT_TOXINLOVER)) && !force)
		return TRUE

	if(nutrition < 100 && !blood && !force)
		if(message)
			visible_message(span_warning("[src] dry heaves!"), \
							span_userdanger("You try to throw up, but there's nothing in your stomach!"))
		if(stun)
			Paralyze(200)
		return TRUE

	if(is_mouth_covered()) //make this add a blood/vomit overlay later it'll be hilarious
		if(message)
			visible_message(span_danger("[src] throws up all over [p_them()]self!"), \
							span_userdanger("You throw up all over yourself!"))
		distance = 0
	else
		if(message)
			visible_message(span_danger("[src] throws up!"), span_userdanger("You throw up!"))

	if(stun)
		Paralyze(80)

	playsound(get_turf(src), 'sound/effects/splat.ogg', 50, TRUE)
	var/turf/T = get_turf(src)
	if(!blood)
		adjust_nutrition(-lost_nutrition)
		adjustToxLoss(-3)

	for(var/i=0 to distance)
		if(blood)
			if(T)
				add_splatter_floor(T)
			if(harm)
				adjustBruteLoss(3)
		else
			if(T)
				T.add_vomit_floor(src, vomit_type, purge_ratio) //toxic barf looks different || call purge when doing detoxicfication to pump more chems out of the stomach.
		T = get_step(T, dir)
		if (T?.is_blocked_turf())
			break
	return TRUE

/**
 * Expel the reagents you just tried to ingest
 *
 * When you try to ingest reagents but you do not have a stomach
 * you will spew the reagents on the floor.
 *
 * Vars:
 * * bite: /atom the reagents to expel
 * * amount: int The amount of reagent
 */
/mob/living/carbon/proc/expel_ingested(atom/bite, amount)
	visible_message(span_danger("[src] throws up all over [p_them()]self!"), \
					span_userdanger("You are unable to keep the [bite] down without a stomach!"))

	var/turf/floor = get_turf(src)
	var/obj/effect/decal/cleanable/vomit/spew = new(floor, get_static_viruses())
	bite.reagents.trans_to(spew, amount, transfered_by = src)

/mob/living/carbon/proc/spew_organ(power = 5, amt = 1)
	for(var/i in 1 to amt)
		if(!processing_organs.len)
			break //Guess we're out of organs!
		var/obj/item/organ/guts = pick(processing_organs)
		var/turf/T = get_turf(src)
		guts.Remove(src)
		guts.forceMove(T)
		var/atom/throw_target = get_edge_target_turf(guts, dir)
		guts.throw_at(throw_target, power, 4, src)


/mob/living/carbon/fully_replace_character_name(oldname,newname)
	..()
	if(dna)
		dna.real_name = real_name


/mob/living/carbon/set_body_position(new_value)
	. = ..()
	if(isnull(.))
		return
	if(new_value == LYING_DOWN)
		add_movespeed_modifier(/datum/movespeed_modifier/carbon_crawling)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/carbon_crawling)


//Updates the mob's health from bodyparts and mob damage variables
/mob/living/carbon/updatehealth(cause_of_death)
	if(status_flags & GODMODE)
		return

	set_health(round(maxHealth - getBrainLoss(), DAMAGE_PRECISION))
	update_damage_hud()
	update_health_hud()
	update_stat(cause_of_death)
	SEND_SIGNAL(src, COMSIG_CARBON_HEALTH_UPDATE)

/mob/living/carbon/on_stamina_update()
	var/stam = stamina.current
	var/max = stamina.maximum
	var/is_exhausted = HAS_TRAIT_FROM(src, TRAIT_EXHAUSTED, STAMINA)
	var/is_stam_stunned = HAS_TRAIT_FROM(src, TRAIT_INCAPACITATED, STAMINA)
	if((stam < max * STAMINA_EXHAUSTION_THRESHOLD_MODIFIER) && !is_exhausted)
		ADD_TRAIT(src, TRAIT_EXHAUSTED, STAMINA)
		ADD_TRAIT(src, TRAIT_NO_SPRINT, STAMINA)
	if((stam < max * STAMINA_STUN_THRESHOLD_MODIFIER) && !is_stam_stunned && stat == CONSCIOUS)
		stamina_stun()
	if(is_exhausted && (stam > max * STAMINA_EXHAUSTION_RECOVERY_THRESHOLD_MODIFIER))
		REMOVE_TRAIT(src, TRAIT_EXHAUSTED, STAMINA)
		REMOVE_TRAIT(src, TRAIT_NO_SPRINT, STAMINA)
	update_stamina_hud()

/mob/living/carbon/update_sight()
	if(!client)
		return
	if(stat == DEAD)
		if(SSmapping.level_trait(z, ZTRAIT_NOXRAY))
			sight = null
		else if(is_secret_level(z))
			sight = initial(sight)
		else
			sight = (SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_in_dark = 8
		see_invisible = SEE_INVISIBLE_OBSERVER
		return

	sight = initial(sight)
	lighting_alpha = initial(lighting_alpha)
	var/obj/item/organ/eyes/E = getorganslot(ORGAN_SLOT_EYES)
	if(!E)
		update_tint()
	else
		see_invisible = E.see_invisible
		see_in_dark = E.see_in_dark
		sight |= E.sight_flags
		if(!isnull(E.lighting_alpha))
			lighting_alpha = E.lighting_alpha

	if(client.eye && client.eye != src)
		var/atom/A = client.eye
		if(A.update_remote_sight(src)) //returns 1 if we override all other sight updates.
			return

	if(glasses)
		var/obj/item/clothing/glasses/G = glasses
		sight |= G.vision_flags
		see_in_dark = max(G.darkness_view, see_in_dark)
		if(G.invis_override)
			see_invisible = G.invis_override
		else
			see_invisible = min(G.invis_view, see_invisible)
		if(!isnull(G.lighting_alpha))
			lighting_alpha = min(lighting_alpha, G.lighting_alpha)

	if(HAS_TRAIT(src, TRAIT_TRUE_NIGHT_VISION))
		lighting_alpha = min(lighting_alpha, LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE)
		see_in_dark = max(see_in_dark, 8)

	if(HAS_TRAIT(src, TRAIT_MESON_VISION))
		sight |= SEE_TURFS
		lighting_alpha = min(lighting_alpha, LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE)

	if(HAS_TRAIT(src, TRAIT_THERMAL_VISION))
		sight |= SEE_MOBS
		lighting_alpha = min(lighting_alpha, LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE)

	if(HAS_TRAIT(src, TRAIT_XRAY_VISION))
		sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS
		see_in_dark = max(see_in_dark, 8)

	if(see_override)
		see_invisible = see_override

	if(SSmapping.level_trait(z, ZTRAIT_NOXRAY))
		sight = null

	if(!(sight & (SEE_TURFS|SEE_MOBS|SEE_OBJS)))
		sight |= SEE_BLACKNESS

	return ..()


//to recalculate and update the mob's total tint from tinted equipment it's wearing.
/mob/living/carbon/proc/update_tint()
	if(!GLOB.tinted_weldhelh)
		return
	tinttotal = get_total_tint()
	if(tinttotal >= TINT_BLIND)
		become_blind(EYES_COVERED)
	else if(tinttotal >= TINT_DARKENED)
		cure_blind(EYES_COVERED)
		overlay_fullscreen("tint", /atom/movable/screen/fullscreen/impaired, 2)
	else
		cure_blind(EYES_COVERED)
		clear_fullscreen("tint", 0)

/mob/living/carbon/proc/get_total_tint()
	. = 0
	if(isclothing(head))
		. += head.tint
	if(isclothing(wear_mask))
		. += wear_mask.tint

	var/obj/item/organ/eyes/E = getorganslot(ORGAN_SLOT_EYES)
	if(E)
		. += E.tint

	else
		. += INFINITY

/mob/living/carbon/get_permeability_protection(list/target_zones = list(HANDS,CHEST,GROIN,LEGS,FEET,ARMS,HEAD))
	var/list/tally = list()
	for(var/obj/item/I in get_equipped_items())
		for(var/zone in target_zones)
			if(I.body_parts_covered & zone)
				tally["[zone]"] = max(1 - I.permeability_coefficient, target_zones["[zone]"])
	var/protection = 0
	for(var/key in tally)
		protection += tally[key]
	protection *= INVERSE(target_zones.len)
	return protection

//this handles hud updates
/mob/living/carbon/update_damage_hud()

	if(!client)
		return

	if(health < maxHealth/2)
		var/severity = 0
		switch(health - maxHealth/2)
			if(-20 to -10)			severity = 1
			if(-30 to -20)			severity = 2
			if(-40 to -30)			severity = 3
			if(-50 to -40)			severity = 4
			if(-60 to -50)			severity = 5
			if(-70 to -60)			severity = 6
			if(-80 to -70)			severity = 7
			if(-90 to -80)			severity = 8
			if(-95 to -90)			severity = 9
			if(-INFINITY to -95)	severity = 10

		overlay_fullscreen("crit", /atom/movable/screen/fullscreen/crit/vision, severity)

		if(stat == UNCONSCIOUS)
			overlay_fullscreen("critvision", /atom/movable/screen/fullscreen/crit/vision, severity)
		else
			clear_fullscreen("critvision")

	else
		clear_fullscreen("crit")
		clear_fullscreen("critvision")


	//Oxygen damage overlay
	if(getOxyLoss())
		var/severity = 0
		switch(getOxyLoss())
			if(10 to 20)		severity = 1
			if(20 to 25)		severity = 2
			if(25 to 30)		severity = 3
			if(30 to 35)		severity = 4
			if(35 to 40)		severity = 5
			if(40 to 45)		severity = 6
			if(45 to INFINITY)	severity = 7
		overlay_fullscreen("oxy", /atom/movable/screen/fullscreen/oxy, severity)
	else
		clear_fullscreen("oxy")

	//Fire and Brute damage overlay (BSSR)
	var/hurtdamage = getBruteLoss() + getFireLoss() + damageoverlaytemp
	if(hurtdamage)
		var/severity = 0
		switch(hurtdamage)
			if(5 to 15)
				severity = 1
			if(15 to 30)
				severity = 2
			if(30 to 45)
				severity = 3
			if(45 to 70)
				severity = 4
			if(70 to 85)
				severity = 5
			if(85 to INFINITY)
				severity = 6
		overlay_fullscreen("brute", /atom/movable/screen/fullscreen/brute, severity)
	else
		clear_fullscreen("brute")

/mob/living/carbon/update_health_hud(shown_health_amount)
	if(!client || !hud_used)
		return
	if(hud_used.healths)
		if(stat != DEAD)
			. = 1
			if(shown_health_amount == null)
				shown_health_amount = health
			if(shown_health_amount >= maxHealth)
				hud_used.healths.icon_state = "health0"
			else if(shown_health_amount > maxHealth*0.8)
				hud_used.healths.icon_state = "health1"
			else if(shown_health_amount > maxHealth*0.6)
				hud_used.healths.icon_state = "health2"
			else if(shown_health_amount > maxHealth*0.4)
				hud_used.healths.icon_state = "health3"
			else if(shown_health_amount > maxHealth*0.2)
				hud_used.healths.icon_state = "health4"
			else if(shown_health_amount > 0)
				hud_used.healths.icon_state = "health5"
			else
				hud_used.healths.icon_state = "health6"
		else
			hud_used.healths.icon_state = "health7"

/mob/living/carbon/update_stamina_hud(shown_stamina_amount)
	if(!client || !hud_used?.stamina)
		return
	if(stat == DEAD)
		hud_used.stamina.icon_state = "stamina6"
	else
		var/max = stamina.maximum
		if(shown_stamina_amount == null)
			shown_stamina_amount = stamina.current
		if(shown_stamina_amount == max)
			hud_used.stamina.icon_state = "stamina0"
		else if(shown_stamina_amount > max*0.8)
			hud_used.stamina.icon_state = "stamina1"
		else if(shown_stamina_amount > max*0.6)
			hud_used.stamina.icon_state = "stamina2"
		else if(shown_stamina_amount > max*0.4)
			hud_used.stamina.icon_state = "stamina3"
		else if(shown_stamina_amount > max*0.2)
			hud_used.stamina.icon_state = "stamina4"
		else if(shown_stamina_amount > 1)
			hud_used.stamina.icon_state = "stamina5"
		else
			hud_used.stamina.icon_state = "stamina6"

/mob/living/carbon/proc/update_spacesuit_hud_icon(cell_state = "empty")
	if(hud_used?.spacesuit)
		hud_used.spacesuit.icon_state = "spacesuit_[cell_state]"


/mob/living/carbon/set_health(new_value)
	. = ..()
	if(. < crit_threshold && !HAS_TRAIT(src, TRAIT_NOSOFTCRIT))
		ADD_TRAIT(src, TRAIT_SOFT_CRITICAL_CONDITION, STAT_TRAIT)
	else
		REMOVE_TRAIT(src, TRAIT_SOFT_CRITICAL_CONDITION, STAT_TRAIT)

	if(CONFIG_GET(flag/near_death_experience))
		if(. > HEALTH_THRESHOLD_NEARDEATH)
			if(health <= HEALTH_THRESHOLD_NEARDEATH && !HAS_TRAIT(src, TRAIT_NODEATH))
				ADD_TRAIT(src, TRAIT_SIXTHSENSE, "near-death")
		else if(health > HEALTH_THRESHOLD_NEARDEATH)
			REMOVE_TRAIT(src, TRAIT_SIXTHSENSE, "near-death")


/mob/living/carbon/update_stat(cause_of_death)
	if(status_flags & GODMODE)
		return

	if(stat != DEAD)
		if(HAS_TRAIT(src, TRAIT_KNOCKEDOUT))
			set_stat(UNCONSCIOUS)
		else
			set_stat(CONSCIOUS)

	med_hud_set_status()

//called when we get cuffed/uncuffed
/mob/living/carbon/proc/update_handcuffed()
	PRIVATE_PROC(TRUE)

	if(handcuffed)
		drop_all_held_items()
		release_all_grabs()
		throw_alert(ALERT_HANDCUFFED, /atom/movable/screen/alert/restrained/handcuffed, new_master = src.handcuffed)
		ADD_TRAIT(src, TRAIT_ARMS_RESTRAINED, HANDCUFFED_TRAIT)
	else
		REMOVE_TRAIT(src, TRAIT_ARMS_RESTRAINED, HANDCUFFED_TRAIT)
		clear_alert(ALERT_HANDCUFFED)
		if(buckled?.buckle_requires_restraints)
			buckled.unbuckle_mob(src)

	update_mob_action_buttons() //some of our action buttons might be unusable when we're handcuffed.
	update_worn_handcuffs()
	update_hud_handcuffed()

/mob/living/carbon/heal_and_revive(heal_to = 75, revive_message)
	// We can't heal them if they're missing a heart
	if(needs_organ(ORGAN_SLOT_HEART) && !getorganslot(ORGAN_SLOT_HEART))
		return FALSE

	// We can't heal them if they're missing their lungs
	if(!HAS_TRAIT(src, TRAIT_NOBREATH) && !getorganslot(ORGAN_SLOT_LUNGS))
		return FALSE

	// And we can't heal them if they're missing their liver
	if(!getorganslot(ORGAN_SLOT_LIVER))
		return FALSE

	return ..()

/mob/living/carbon/fully_heal(admin_revive = FALSE)
	if(reagents)
		reagents.clear_reagents()
	if(touching)
		touching.clear_reagents()
	if(bloodstream)
		bloodstream.clear_reagents()

	shock_stage = 0

	if(mind)
		for(var/addiction_type in subtypesof(/datum/addiction))
			mind.remove_addiction_points(addiction_type, MAX_ADDICTION_POINTS) //Remove the addiction!

	for(var/obj/item/organ/organ as anything in processing_organs)
		organ.setOrganDamage(0)
		organ.set_organ_dead(FALSE)

	for(var/thing in diseases)
		var/datum/pathogen/D = thing
		if(D.severity != PATHOGEN_SEVERITY_POSITIVE)
			D.force_cure(add_resistance = FALSE)

	if(admin_revive)
		suiciding = FALSE
		regenerate_limbs()
		regenerate_organs()
		remove_handcuffs()
		remove_legcuffs()
		client?.prefs?.apply_prefs_to(src)

	cure_all_traumas(TRAUMA_RESILIENCE_MAGIC)
	exit_stamina_stun()
	..()

/mob/living/carbon/can_be_revived()
	. = TRUE

	if(HAS_TRAIT(src, TRAIT_HUSK))
		return FALSE

	if(needs_organ(ORGAN_SLOT_BRAIN) && (!mind || !mind.has_antag_datum(/datum/antagonist/changeling)))
		var/obj/item/organ/brain/B = getorganslot(ORGAN_SLOT_BRAIN)
		if(!B || (B.organ_flags & ORGAN_DEAD))
			return FALSE

	if(needs_organ(ORGAN_SLOT_POSIBRAIN))
		var/obj/item/organ/posibrain/B = getorganslot(ORGAN_SLOT_POSIBRAIN)
		if(!B || (B.organ_flags & ORGAN_DEAD))
			return FALSE

	if(needs_organ(ORGAN_SLOT_CELL))
		var/obj/item/organ/cell/C = getorganslot(ORGAN_SLOT_CELL)
		if(!C || (C.get_percent() == 0))
			return FALSE

/mob/living/carbon/harvest(mob/living/user)
	if(QDELETED(src))
		return
	var/organs_amt = 0
	for(var/obj/item/organ/organ as anything in processing_organs)
		if(prob(50))
			organs_amt++
			organ.Remove(src)
			organ.forceMove(drop_location())
	if(organs_amt)
		to_chat(user, span_notice("You retrieve some of [src]\'s internal organs!"))
	remove_all_embedded_objects()

/mob/living/carbon/proc/create_bodyparts(list/overrides)
	var/l_arm_index_next = -1
	var/r_arm_index_next = 0
	for(var/obj/item/bodypart/bodypart_path as anything in bodyparts)
		var/real_body_part_path = overrides?[initial(bodypart_path.body_zone)] || bodypart_path
		var/obj/item/bodypart/bodypart_instance = new real_body_part_path()
		bodyparts.Remove(bodypart_path)
		add_bodypart(bodypart_instance)
		switch(bodypart_instance.body_part)
			if(ARM_LEFT)
				l_arm_index_next += 2
				bodypart_instance.held_index = l_arm_index_next //1, 3, 5, 7...
				hand_bodyparts += bodypart_instance
			if(ARM_RIGHT)
				r_arm_index_next += 2
				bodypart_instance.held_index = r_arm_index_next //2, 4, 6, 8...
				hand_bodyparts += bodypart_instance

	sortTim(bodyparts, GLOBAL_PROC_REF(cmp_bodypart_by_body_part_asc))

///Proc to hook behavior on bodypart additions. Do not directly call. You're looking for [/obj/item/bodypart/proc/attach_limb()].
/mob/living/carbon/proc/add_bodypart(obj/item/bodypart/new_bodypart)
	SHOULD_NOT_OVERRIDE(TRUE)

	bodyparts += new_bodypart
	new_bodypart.set_owner(src)
	new_bodypart.forceMove(src)
	new_bodypart.item_flags |= ABSTRACT
	ADD_TRAIT(new_bodypart, TRAIT_INSIDE_BODY, REF(src))

	if(new_bodypart.bodypart_flags & BP_IS_MOVEMENT_LIMB)
		set_num_legs(num_legs + 1)
		if(!new_bodypart.bodypart_disabled)
			set_usable_legs(usable_legs + 1)
	if(new_bodypart.bodypart_flags & BP_IS_GRABBY_LIMB)
		set_num_hands(num_hands + 1)
		if(!new_bodypart.bodypart_disabled)
			set_usable_hands(usable_hands + 1)


///Proc to hook behavior on bodypart removals.  Do not directly call. You're looking for [/obj/item/bodypart/proc/drop_limb()].
/mob/living/carbon/proc/remove_bodypart(obj/item/bodypart/old_bodypart)
	SHOULD_NOT_OVERRIDE(TRUE)

	REMOVE_TRAIT(old_bodypart, TRAIT_INSIDE_BODY, REF(src))
	bodyparts -= old_bodypart
	old_bodypart.item_flags &= ~ABSTRACT
	if(old_bodypart.bodypart_flags & BP_IS_MOVEMENT_LIMB)
		set_num_legs(num_legs - 1)
		if(!old_bodypart.bodypart_disabled)
			set_usable_legs(usable_legs - 1)

	if(old_bodypart.bodypart_flags & BP_IS_GRABBY_LIMB)
		set_num_hands(num_hands - 1)
		if(!old_bodypart.bodypart_disabled)
			set_usable_hands(usable_hands - 1)


/mob/living/carbon/proc/create_internal_organs()
	for(var/obj/item/organ/organ in organs)
		organ.Insert(src)

/proc/cmp_organ_slot_asc(obj/item/organ/slot_a, obj/item/organ/slot_b)
	return GLOB.organ_process_order.Find(slot_a.slot) - GLOB.organ_process_order.Find(slot_b.slot)

/mob/living/carbon/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("", "---------")
	VV_DROPDOWN_OPTION(VV_HK_MAKE_AI, "Make AI")
	VV_DROPDOWN_OPTION(VV_HK_MODIFY_BODYPART, "Modify bodypart")
	VV_DROPDOWN_OPTION(VV_HK_MODIFY_ORGANS, "Modify organs")
	VV_DROPDOWN_OPTION(VV_HK_HALLUCINATION, "Hallucinate")
	VV_DROPDOWN_OPTION(VV_HK_MARTIAL_ART, "Give Martial Arts")
	VV_DROPDOWN_OPTION(VV_HK_GIVE_TRAUMA, "Give Brain Trauma")
	VV_DROPDOWN_OPTION(VV_HK_CURE_TRAUMA, "Cure Brain Traumas")

/mob/living/carbon/vv_do_topic(list/href_list)
	. = ..()
	if(href_list[VV_HK_MODIFY_BODYPART])
		if(!check_rights(R_SPAWN))
			return
		var/edit_action = input(usr, "What would you like to do?","Modify Body Part") as null|anything in list("replace","remove")
		if(!edit_action)
			return
		var/list/limb_list = list()
		if(edit_action == "remove")
			for(var/obj/item/bodypart/B as anything in bodyparts)
				limb_list += B.body_zone
				limb_list -= BODY_ZONE_CHEST
		else
			limb_list = list(BODY_ZONE_HEAD, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG, BODY_ZONE_CHEST)
		var/result = input(usr, "Please choose which bodypart to [edit_action]","[capitalize(edit_action)] Bodypart") as null|anything in sort_list(limb_list)
		if(result)
			var/obj/item/bodypart/BP = get_bodypart(result)
			var/list/limbtypes = list()
			switch(result)
				if(BODY_ZONE_CHEST)
					limbtypes = typesof(/obj/item/bodypart/chest)
				if(BODY_ZONE_R_ARM)
					limbtypes = typesof(/obj/item/bodypart/arm/right)
				if(BODY_ZONE_L_ARM)
					limbtypes = typesof(/obj/item/bodypart/arm/left)
				if(BODY_ZONE_HEAD)
					limbtypes = typesof(/obj/item/bodypart/head)
				if(BODY_ZONE_L_LEG)
					limbtypes = typesof(/obj/item/bodypart/leg/left)
				if(BODY_ZONE_R_LEG)
					limbtypes = typesof(/obj/item/bodypart/leg/right)
			switch(edit_action)
				if("remove")
					if(BP)
						BP.drop_limb(special = TRUE)
						admin_ticket_log("[key_name_admin(usr)] has removed [src]'s [parse_zone(BP.body_zone)]")
					else
						to_chat(usr, span_boldwarning("[src] doesn't have such bodypart."))
						admin_ticket_log("[key_name_admin(usr)] has attempted to modify the bodyparts of [src]")
				if("replace")
					var/limb2add = input(usr, "Select a bodypart type to add", "Add/Replace Bodypart") as null|anything in sort_list(limbtypes)
					var/obj/item/bodypart/new_bp = new limb2add()

					if(new_bp.replace_limb(src, special = TRUE))
						admin_ticket_log("key_name_admin(usr)] has replaced [src]'s [BP.type] with [new_bp.type]")
						qdel(BP)
					else
						to_chat(usr, "Failed to replace bodypart! They might be incompatible.")
						admin_ticket_log("[key_name_admin(usr)] has attempted to modify the bodyparts of [src]")

	if(href_list[VV_HK_MAKE_AI])
		if(!check_rights(R_SPAWN))
			return
		if(tgui_alert(usr,"Confirm mob type change?",,list("Transform","Cancel")) != "Transform")
			return
		usr.client.holder.Topic("vv_override", list("makeai"=href_list[VV_HK_TARGET]))
	if(href_list[VV_HK_MODIFY_ORGANS])
		if(!check_rights(NONE))
			return
		usr.client.manipulate_organs(src)
	if(href_list[VV_HK_MARTIAL_ART])
		if(!check_rights(NONE))
			return
		var/list/artpaths = subtypesof(/datum/martial_art)
		var/list/artnames = list()
		for(var/i in artpaths)
			var/datum/martial_art/M = i
			artnames[initial(M.name)] = M
		var/result = input(usr, "Choose the martial art to teach","JUDO CHOP") as null|anything in sort_list(artnames, GLOBAL_PROC_REF(cmp_typepaths_asc))
		if(!usr)
			return
		if(QDELETED(src))
			to_chat(usr, span_boldwarning("Mob doesn't exist anymore."))
			return
		if(result)
			var/chosenart = artnames[result]
			var/datum/martial_art/MA = new chosenart
			MA.teach(src)
			log_admin("[key_name(usr)] has taught [MA] to [key_name(src)].")
			message_admins(span_notice("[key_name_admin(usr)] has taught [MA] to [key_name_admin(src)]."))
	if(href_list[VV_HK_GIVE_TRAUMA])
		if(!check_rights(NONE))
			return
		var/list/traumas = subtypesof(/datum/brain_trauma)
		var/result = input(usr, "Choose the brain trauma to apply","Traumatize") as null|anything in sort_list(traumas, GLOBAL_PROC_REF(cmp_typepaths_asc))
		if(!usr)
			return
		if(QDELETED(src))
			to_chat(usr, "Mob doesn't exist anymore")
			return
		if(!result)
			return
		var/datum/brain_trauma/BT = gain_trauma(result)
		if(BT)
			log_admin("[key_name(usr)] has traumatized [key_name(src)] with [BT.name]")
			message_admins(span_notice("[key_name_admin(usr)] has traumatized [key_name_admin(src)] with [BT.name]."))
	if(href_list[VV_HK_CURE_TRAUMA])
		if(!check_rights(NONE))
			return
		cure_all_traumas(TRAUMA_RESILIENCE_ABSOLUTE)
		log_admin("[key_name(usr)] has cured all traumas from [key_name(src)].")
		message_admins(span_notice("[key_name_admin(usr)] has cured all traumas from [key_name_admin(src)]."))
	if(href_list[VV_HK_HALLUCINATION])
		if(!check_rights(NONE))
			return
		var/list/hallucinations = subtypesof(/datum/hallucination)
		var/result = input(usr, "Choose the hallucination to apply","Send Hallucination") as null|anything in sort_list(hallucinations, GLOBAL_PROC_REF(cmp_typepaths_asc))
		if(!usr)
			return
		if(QDELETED(src))
			to_chat(usr, "Mob doesn't exist anymore")
			return
		if(result)
			new result(src, TRUE)

/mob/living/carbon/can_resist()
	return bodyparts.len > 2 && ..()

/mob/living/carbon/proc/hypnosis_vulnerable()
	if(HAS_TRAIT(src, TRAIT_MINDSHIELD))
		return FALSE
	if(hallucinating())
		return TRUE
	if(IsSleeping())
		return TRUE
	if(HAS_TRAIT(src, TRAIT_DUMB))
		return TRUE

/mob/living/carbon/wash(clean_types)
	. = ..()

	// Wash equipped stuff that cannot be covered
	for(var/obj/item/held_thing in held_items)
		if(held_thing.wash(clean_types))
			. = TRUE

	if(back?.wash(clean_types))
		update_worn_back(0)
		. = TRUE

	if(head?.wash(clean_types))
		update_worn_head()
		. = TRUE

	// Check and wash stuff that can be covered
	var/obscured = check_obscured_slots()

	// If the eyes are covered by anything but glasses, that thing will be covering any potential glasses as well.
	if(glasses && is_eyes_covered(FALSE, TRUE, TRUE) && glasses.wash(clean_types))
		update_worn_glasses()
		. = TRUE

	if(wear_mask && !(obscured & ITEM_SLOT_MASK) && wear_mask.wash(clean_types))
		update_worn_mask()
		. = TRUE

	if(ears && !(obscured & ITEM_SLOT_EARS) && ears.wash(clean_types))
		update_worn_ears()
		. = TRUE

	if(wear_neck && !(obscured & ITEM_SLOT_NECK) && wear_neck.wash(clean_types))
		update_worn_neck()
		. = TRUE

	if(shoes && !(obscured & ITEM_SLOT_FEET) && shoes.wash(clean_types))
		update_worn_shoes()
		. = TRUE

	if(gloves && !(obscured & ITEM_SLOT_GLOVES) && gloves.wash(clean_types))
		update_worn_gloves()
		. = TRUE

	if(shoes && !(obscured & ITEM_SLOT_FEET) && shoes.wash(clean_types))
		update_worn_shoes()
		. = TRUE

	if(get_permeability_protection() > 0.5)
		touching.clear_reagents()

/// if any of our bodyparts are bleeding
/mob/living/carbon/proc/is_bleeding()
	for(var/obj/item/bodypart/part as anything in bodyparts)
		if(part.get_modified_bleed_rate())
			return TRUE

/// get our total bleedrate
/mob/living/carbon/proc/get_total_bleed_rate()
	var/total_bleed_rate = 0
	for(var/obj/item/bodypart/part as anything in bodyparts)
		total_bleed_rate += part.get_modified_bleed_rate()

	return total_bleed_rate

/mob/living/carbon/is_face_visible()
	return !(wear_mask?.flags_inv & HIDEFACE) && !(head?.flags_inv & HIDEFACE)

/// Returns whether or not the carbon should be able to be shocked
/mob/living/carbon/proc/should_electrocute(power_source)
	if (ismecha(loc))
		return FALSE

	if (wearing_shock_proof_gloves())
		return FALSE

	if(!get_powernet_info_from_source(power_source))
		return FALSE

	if (HAS_TRAIT(src, TRAIT_SHOCKIMMUNE))
		return FALSE

	return TRUE

/// Returns if the carbon is wearing shock proof gloves
/mob/living/carbon/proc/wearing_shock_proof_gloves()
	return gloves?.siemens_coefficient == 0

/// Modifies max_skillchip_count and updates active skillchips
/mob/living/carbon/proc/adjust_skillchip_complexity_modifier(delta)
	skillchip_complexity_modifier += delta

	var/obj/item/organ/brain/brain = getorganslot(ORGAN_SLOT_BRAIN)

	if(!brain)
		return

	brain.update_skillchips()


/// Modifies the handcuffed value if a different value is passed, returning FALSE otherwise. The variable should only be changed through this proc.
/mob/living/carbon/proc/set_handcuffed(new_value)
	PRIVATE_PROC(TRUE)
	if(handcuffed == new_value)
		return FALSE

	. = handcuffed
	handcuffed = new_value

	update_handcuffed()

/mob/living/carbon/on_lying_down(new_lying_angle)
	. = ..()
	if(!buckled || buckled.buckle_lying != 0)
		lying_angle_on_lying_down(new_lying_angle)


/// Special carbon interaction on lying down, to transform its sprite by a rotation.
/mob/living/carbon/proc/lying_angle_on_lying_down(new_lying_angle)
	if(!new_lying_angle)
		set_lying_angle(pick(LYING_ANGLE_EAST, LYING_ANGLE_WEST))
	else
		set_lying_angle(new_lying_angle)


/mob/living/carbon/vv_edit_var(var_name, var_value)
	switch(var_name)
		if(NAMEOF(src, disgust))
			set_disgust(var_value)
			. = TRUE
		if(NAMEOF(src, hal_screwyhud))
			set_screwyhud(var_value)
			. = TRUE
		if(NAMEOF(src, handcuffed))
			set_handcuffed(var_value)
			. = TRUE

	if(!isnull(.))
		datum_flags |= DF_VAR_EDITED
		return

	return ..()


/mob/living/carbon/get_attack_type()
	if(has_active_hand())
		var/obj/item/bodypart/arm/active_arm = get_active_hand()
		return active_arm.attack_type
	return ..()


/mob/living/carbon/proc/attach_rot()
	if(mob_biotypes & (MOB_ORGANIC|MOB_UNDEAD))
		AddComponent(/datum/component/rot, 6 MINUTES, 10 MINUTES, 1)

// Checks to see how many hands this person has to sign with.
/mob/living/carbon/proc/check_signables_state()
	var/obj/item/bodypart/left_arm = get_bodypart(BODY_ZONE_L_ARM)
	var/obj/item/bodypart/right_arm = get_bodypart(BODY_ZONE_R_ARM)

	var/empty_indexes = get_empty_held_indexes()
	var/exit_right = (!right_arm || right_arm.bodypart_disabled)
	var/exit_left = (!left_arm || left_arm.bodypart_disabled)
	if(length(empty_indexes) == 0 || (length(empty_indexes) < 2 && (exit_left || exit_right)))//All existing hands full, can't sign
		return SIGN_HANDS_FULL // These aren't booleans

	if(exit_left && exit_right)//Can't sign with no arms!
		return SIGN_ARMLESS

	if(handcuffed) // Cuffed, usually will show visual effort to sign
		return SIGN_CUFFED

	if(HAS_TRAIT(src, TRAIT_HANDS_BLOCKED) || HAS_TRAIT(src, TRAIT_EMOTEMUTE))
		return SIGN_TRAIT_BLOCKED

	if(length(empty_indexes) == 1 || exit_left || exit_right) // One arm gone
		return SIGN_ONE_HAND

/**
 * This proc is a helper for spraying blood for things like slashing/piercing wounds and dismemberment.
 *
 * The strength of the splatter in the second argument determines how much it can dirty and how far it can go
 *
 * Arguments:
 * * splatter_direction: Which direction the blood is flying
 * * splatter_strength: How many tiles it can go, and how many items it can pass over and dirty
 */
/mob/living/carbon/proc/spray_blood(splatter_direction, splatter_strength = 3)
	if(!isturf(loc))
		return
	var/obj/effect/decal/cleanable/blood/hitsplatter/our_splatter = new(loc)
	if(QDELETED(our_splatter))
		return
	our_splatter.add_blood_DNA(get_blood_dna_list())
	our_splatter.blood_dna_info = get_blood_dna_list()
	var/turf/targ = get_ranged_target_turf(src, splatter_direction, splatter_strength)
	our_splatter.fly_towards(targ, splatter_strength)

/mob/living/carbon/update_fire_overlay(stacks, on_fire, last_icon_state, suffix = "")
	var/fire_icon = "generic_burning[suffix]"

	if(!GLOB.fire_appearances[fire_icon])
		var/mutable_appearance/new_fire_overlay = mutable_appearance('icons/mob/onfire.dmi', fire_icon, -FIRE_LAYER)
		new_fire_overlay.appearance_flags = RESET_COLOR
		GLOB.fire_appearances[fire_icon] = new_fire_overlay

	if((stacks > 0 && on_fire) || HAS_TRAIT(src, TRAIT_PERMANENTLY_ONFIRE))
		if(fire_icon == last_icon_state)
			return last_icon_state

		remove_overlay(FIRE_LAYER)
		overlays_standing[FIRE_LAYER] = GLOB.fire_appearances[fire_icon]
		apply_overlay(FIRE_LAYER)
		return fire_icon

	if(!last_icon_state)
		return last_icon_state

	remove_overlay(FIRE_LAYER)
	apply_overlay(FIRE_LAYER)
	return null

/mob/living/carbon/proc/can_autoheal(damtype)
	if(!damtype)
		CRASH("No damage type given to can_autoheal")

	switch(damtype)
		if(BRUTE)
			return getBruteLoss() < (maxHealth/2)
		if(BURN)
			return getFireLoss() < (maxHealth/2)

/mob/living/carbon/proc/get_wounds()
	RETURN_TYPE(/list)
	. = list()
	for(var/obj/item/bodypart/BP as anything in bodyparts)
		if(LAZYLEN(BP.wounds))
			. += BP.wounds

/mob/living/carbon/ZImpactDamage(turf/T, levels)
	. = ..()
	if(!.)
		return

	var/atom/highest
	for(var/atom/movable/hurt_atom as anything in T)
		if(hurt_atom == src)
			continue
		if(!hurt_atom.density)
			continue
		if(isobj(hurt_atom) || ismob(hurt_atom))
			if(hurt_atom.layer > highest?.layer)
				highest = hurt_atom

	if(!highest)
		return

	if(isobj(highest))
		var/obj/O = highest
		if(!O.uses_integrity)
			return
		O.take_damage(30 * levels)

	if(ismob(highest))
		var/mob/living/L = highest
		var/armor = L.run_armor_check(BODY_ZONE_HEAD, BLUNT)
		L.apply_damage(15 * levels, blocked = armor, spread_damage = TRUE)
		L.Paralyze(10 SECONDS)

	visible_message(span_warning("[src] slams into [highest] from above!"))

/mob/living/carbon/get_ingested_reagents()
	RETURN_TYPE(/datum/reagents)
	return getorganslot(ORGAN_SLOT_STOMACH)?.reagents

///generates realistic-ish pulse output based on preset levels as text
/mob/living/carbon/proc/get_pulse(method)	//method 0 is for hands, 1 is for machines, more accurate
	var/obj/item/organ/heart/heart_organ = getorganslot(ORGAN_SLOT_HEART)
	if(!heart_organ)
		// No heart, no pulse
		return "0"

	var/bpm = get_pulse_as_number()
	if(bpm >= PULSE_MAX_BPM)
		return method ? ">[PULSE_MAX_BPM]" : "extremely weak and fast, patient's artery feels like a thread"

	return "[method ? bpm : bpm + rand(-10, 10)]"
// output for machines ^	 ^ ^ ^ ^ ^ ^ ^ ^ ^ ^ output for people

/mob/living/carbon/proc/pulse()
	if (stat == DEAD)
		return PULSE_NONE
	var/obj/item/organ/heart/H = getorganslot(ORGAN_SLOT_HEART)
	return H ? H.pulse : PULSE_NONE

/mob/living/carbon/proc/get_pulse_as_number()
	var/obj/item/organ/heart/heart_organ = getorganslot(ORGAN_SLOT_HEART)
	if(!heart_organ)
		return 0

	switch(pulse())
		if(PULSE_NONE)
			return 0
		if(PULSE_SLOW)
			return rand(40, 60)
		if(PULSE_NORM)
			return rand(60, 90)
		if(PULSE_FAST)
			return rand(90, 120)
		if(PULSE_2FAST)
			return rand(120, 160)
		if(PULSE_THREADY)
			return PULSE_MAX_BPM
	return 0

//Get fluffy numbers
/mob/living/carbon/proc/get_blood_pressure()
	if(HAS_TRAIT(src, TRAIT_FAKEDEATH))
		return "[FLOOR(120+rand(-5,5), 1)*0.25]/[FLOOR(80+rand(-5,5)*0.25, 1)]"
	var/blood_result = get_blood_circulation()
	return "[FLOOR((120+rand(-5,5))*(blood_result/100), 1)]/[FLOOR((80+rand(-5,5))*(blood_result/100), 1)]"

/mob/living/carbon/proc/resuscitate()
	if(!undergoing_cardiac_arrest())
		return

	var/obj/item/organ/heart/heart = getorganslot(ORGAN_SLOT_HEART)
	if(istype(heart) && !(heart.organ_flags & ORGAN_DEAD))
		if(!nervous_system_failure())
			visible_message("\The [src] jerks and gasps for breath!")
		else
			visible_message("\The [src] twitches a bit as \his heart restarts!")

		shock_stage = min(shock_stage, SHOCK_AMT_FOR_FIBRILLATION - 25)

		// Clamp oxy loss to 70 for 200 health mobs. This is a 0.65 modifier for blood oxygenation.
		if(getOxyLoss() >= maxHealth * 0.35)
			setOxyLoss(maxHealth * 0.35)

		COOLDOWN_START(heart, arrhythmia_grace_period, 10 SECONDS)
		heart.Restart()
		heart.handle_pulse()
		return TRUE

/mob/living/carbon/proc/nervous_system_failure()
	return getBrainLoss() >= maxHealth * 0.75

/mob/living/carbon/has_mouth()
	var/obj/item/bodypart/head/H = get_bodypart(BODY_ZONE_HEAD)
	if(!H?.can_ingest_reagents)
		return FALSE
	return TRUE

/mob/living/carbon/dropItemToGround(obj/item/I, force, silent, invdrop, animate = TRUE)
	if(I && HAS_TRAIT(I, TRAIT_INSIDE_BODY))
		stack_trace("Something tried to drop an organ or bodypart that isn't allowed to be dropped")
		return FALSE
	return ..()
