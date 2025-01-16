/mob/living/Initialize(mapload)
	. = ..()
	stamina = new(src)
	stats = new(src)

	register_init_signals()
	if(unique_name)
		give_unique_name()

	var/datum/atom_hud/data/human/medical/advanced/medhud = GLOB.huds[DATA_HUD_MEDICAL_ADVANCED]
	medhud.add_atom_to_hud(src)

	for(var/datum/atom_hud/data/diagnostic/diag_hud in GLOB.huds)
		diag_hud.add_atom_to_hud(src)

	faction += "[REF(src)]"
	GLOB.mob_living_list += src
	SSpoints_of_interest.make_point_of_interest(src)
	voice_type = pick(voice_type2sound)
	mob_mood = new(src)

	AddElement(/datum/element/movetype_handler)
	gravity_setup()

/mob/living/prepare_huds()
	..()
	prepare_data_huds()

/mob/living/proc/prepare_data_huds()
	update_med_hud()

/mob/living/Destroy()
	QDEL_NULL(z_eye)
	QDEL_NULL(stamina)
	QDEL_NULL(stats)
	QDEL_NULL(mob_mood)

	for(var/datum/status_effect/effect as anything in status_effects)
		// The status effect calls on_remove when its mob is deleted
		if(effect.on_remove_on_mob_delete)
			qdel(effect)

		else
			effect.be_replaced()


	if(buckled)
		buckled.unbuckle_mob(src,force=1)

	remove_from_all_data_huds()
	GLOB.mob_living_list -= src
	QDEL_LAZYLIST(diseases)
	return ..()

/mob/living/onZImpact(turf/T, levels, message = TRUE)
	if(m_intent == MOVE_INTENT_WALK && levels <= 1 && !throwing && !incapacitated())
		visible_message(
			span_notice("<b>[src]</b> climbs down from the floor above.")
		)
		Stun(1 SECOND, TRUE)
		setDir(global.reverse_dir[dir])
		var/old_pixel_y = pixel_y
		var/old_alpha = alpha
		pixel_y = pixel_y + 32
		alpha = 90
		animate(src, time = 1 SECONDS, pixel_y = old_pixel_y)
		animate(src, time = 1 SECONDS, alpha = old_alpha, flags = ANIMATION_PARALLEL)
		return

	if(!isgroundlessturf(T))
		ZImpactDamage(T, levels)
		message = FALSE
	return ..()

/mob/living/proc/ZImpactDamage(turf/T, levels)
	if(SEND_SIGNAL(src, COMSIG_LIVING_Z_IMPACT, levels, T) & NO_Z_IMPACT_DAMAGE)
		return

	visible_message(span_danger("<b>[src]</b> slams into [T]!"), blind_message = span_hear("You hear something slam into the deck."))
	TakeFallDamage(levels)
	return TRUE

/mob/living/proc/TakeFallDamage(levels)
	adjustBruteLoss((levels * 5) ** 1.5)
	Knockdown(levels * 5 SECONDS)
	Stun(levels * 2 SECONDS)
	return TRUE

//Generic Bump(). Override MobBump() and ObjBump() instead of this.
/mob/living/Bump(atom/A)
	if(..()) //we are thrown onto something
		return
	if(buckled || now_pushing)
		return
	if(ismob(A))
		var/mob/M = A
		if(MobBump(M))
			return
	if(isobj(A))
		var/obj/O = A
		if(ObjBump(O))
			return
	if(ismovable(A))
		var/atom/movable/AM = A
		if(PushAM(AM, move_force))
			return

/mob/living/BumpedBy(atom/movable/AM)
	..()
	last_bumped = world.time

//Called when we bump onto a mob
/mob/living/proc/MobBump(mob/M)
	//No bumping/swapping/pushing others if you are on walk intent
	if(m_intent == MOVE_INTENT_WALK)
		return TRUE

	SEND_SIGNAL(src, COMSIG_LIVING_MOB_BUMP, M)
	//Even if we don't push/swap places, we "touched" them, so spread fire
	spreadFire(M)

	if(now_pushing)
		return TRUE


	if(isliving(M))
		var/mob/living/L = M
		//Also spread diseases
		for(var/thing in diseases)
			var/datum/pathogen/D = thing
			if(D.spread_flags & PATHOGEN_SPREAD_CONTACT_SKIN)
				L.try_contact_contract_pathogen(D)

		for(var/thing in L.diseases)
			var/datum/pathogen/D = thing
			if(D.spread_flags & PATHOGEN_SPREAD_CONTACT_SKIN)
				try_contact_contract_pathogen(D)

		//Should stop you pushing a restrained person out of the way
		if(LAZYLEN(L.grabbed_by) && !is_grabbing(L) && HAS_TRAIT(L, TRAIT_ARMS_RESTRAINED))
			if(!(world.time % 5))
				to_chat(src, span_warning("[L] is restrained, you cannot push past."))
			return TRUE

		var/list/grabs = L.active_grabs
		if(length(grabs))
			for(var/obj/item/hand_item/grab/G in grabs)
				if(ismob(G.affecting))
					var/mob/P = G.affecting
					if(HAS_TRAIT(P, TRAIT_ARMS_RESTRAINED))
						if(!(world.time % 5))
							to_chat(src, span_warning("[L] is restraining [P], you cannot push past."))
						return TRUE

	if(moving_diagonally)//no mob swap during diagonal moves.
		return TRUE

	if(!M.buckled && !M.has_buckled_mobs())
		if(can_mobswap_with(M))
			//switch our position with M
			if(loc && !loc.MultiZAdjacent(M.loc))
				return TRUE

			now_pushing = TRUE

			var/oldloc = loc
			var/oldMloc = M.loc
			forceMove(oldMloc)
			M.forceMove(oldloc)
			M.update_offsets()

			now_pushing = FALSE
			return TRUE

	//okay, so we didn't switch. but should we push?
	//not if he's not CANPUSH of course
	if(!(M.status_flags & CANPUSH))
		return TRUE

	if(isliving(M))
		var/mob/living/L = M
		if(HAS_TRAIT(L, TRAIT_PUSHIMMUNE))
			return TRUE

	//If they're a human, and they're not in help intent, block pushing
	if(ishuman(M))
		var/mob/living/carbon/human/human = M
		if(human.combat_mode)
			return TRUE

	//if they are a cyborg, and they're alive and in combat mode, block pushing
	if(iscyborg(M))
		var/mob/living/silicon/robot/borg = M
		if(borg.combat_mode && borg.stat != DEAD)
			return TRUE

	//anti-riot equipment is also anti-push
	for(var/obj/item/I in M.held_items)
		if(!istype(M, /obj/item/clothing))
			if(I.try_block_attack(M, src, "the push", 0, LEAP_ATTACK)) //close enough?
				return TRUE

/mob/living/proc/can_mobswap_with(mob/other)
	if (HAS_TRAIT(other, TRAIT_NOMOBSWAP) || HAS_TRAIT(src, TRAIT_NOMOBSWAP))
		return FALSE

	var/they_can_move = TRUE
	var/their_combat_mode = FALSE

	if(isliving(other))
		var/mob/living/other_living = other
		their_combat_mode = other_living.combat_mode
		they_can_move = other_living.mobility_flags & MOBILITY_MOVE

	var/too_strong = other.move_resist > move_force

	// They cannot move, see if we can push through them
	if (!they_can_move)
		return !too_strong

	// We are pulling them and can move through
	if (is_grabbing(other) && !too_strong)
		return TRUE

	// If we're in combat mode and not restrained we don't try to pass through people
	if (combat_mode && !HAS_TRAIT(src, TRAIT_ARMS_RESTRAINED))
		return FALSE

	// Nor can we pass through non-restrained people in combat mode (or if they're restrained but still too strong for us)
	if (their_combat_mode && (!HAS_TRAIT(other, TRAIT_ARMS_RESTRAINED) || too_strong))
		return FALSE

	if (isnull(other.client) || isnull(client))
		return TRUE

	// If both of us are trying to move in the same direction, let the fastest one through first
	if (client.intended_direction == other.client.intended_direction)
		return movement_delay < other.movement_delay

	// Else, sure, let us pass
	return TRUE

/mob/living/get_photo_description(obj/item/camera/camera)
	var/list/mob_details = list()
	var/list/holding = list()
	var/len = length(held_items)
	if(len)
		for(var/obj/item/I in held_items)
			if(!holding.len)
				holding += "[p_they(TRUE)] [p_are()] holding \a [I]"
			else if(held_items.Find(I) == len)
				holding += ", and \a [I]."
			else
				holding += ", \a [I]"
	holding += "."
	mob_details += "You can also see [src] on the photo[health < (maxHealth * 0.75) ? ", looking a bit hurt":""][holding ? ". [holding.Join("")]":"."]."
	return mob_details.Join("")

//Called when we bump onto an obj
/mob/living/proc/ObjBump(obj/O)
	return

//Called when we want to push an atom/movable
/mob/living/proc/PushAM(atom/movable/AM, force = move_force)
	if(now_pushing)
		return TRUE
	if(moving_diagonally)// no pushing during diagonal moves.
		return TRUE
	if(!client && (mob_size < MOB_SIZE_SMALL))
		return
	now_pushing = TRUE
	SEND_SIGNAL(src, COMSIG_LIVING_PUSHING_MOVABLE, AM)
	var/dir_to_target = get_dir(src, AM)

	// If there's no dir_to_target then the player is on the same turf as the atom they're trying to push.
	// This can happen when a player is stood on the same turf as a directional window. All attempts to push
	// the window will fail as get_dir will return 0 and the player will be unable to move the window when
	// it should be pushable.
	// In this scenario, we will use the facing direction of the /mob/living attempting to push the atom as
	// a fallback.
	if(!dir_to_target)
		dir_to_target = dir

	var/push_anchored = FALSE
	if((AM.move_resist * MOVE_FORCE_CRUSH_RATIO) <= force)
		if(move_crush(AM, move_force, dir_to_target))
			push_anchored = TRUE

	if((AM.move_resist * MOVE_FORCE_FORCEPUSH_RATIO) <= force) //trigger move_crush and/or force_push regardless of if we can push it normally
		if(force_push(AM, move_force, dir_to_target, push_anchored))
			push_anchored = TRUE

	if(ismob(AM))
		var/mob/mob_to_push = AM
		var/atom/movable/mob_buckle = mob_to_push.buckled
		// If we can't pull them because of what they're buckled to, make sure we can push the thing they're buckled to instead.
		// If neither are true, we're not pushing anymore.
		if(mob_buckle && (mob_buckle.buckle_prevents_pull || (force < (mob_buckle.move_resist * MOVE_FORCE_PUSH_RATIO))))
			now_pushing = FALSE
			return

	if((AM.anchored && !push_anchored) || (force < (AM.move_resist * MOVE_FORCE_PUSH_RATIO)))
		now_pushing = FALSE
		return

	if(istype(AM, /obj/structure/window))
		var/obj/structure/window/W = AM
		if(W.fulltile)
			for(var/obj/structure/window/win in get_step(W, dir_to_target))
				now_pushing = FALSE
				return

	release_grabs(AM)

	var/current_dir
	if(isliving(AM))
		current_dir = AM.dir
	if(AM.Move(get_step(AM.loc, dir_to_target), dir_to_target, glide_size))
		AM.add_fingerprint(src)
		Move(get_step(loc, dir_to_target), dir_to_target)
	if(current_dir)
		AM.setDir(current_dir)
	now_pushing = FALSE

/mob/living/proc/reset_pull_offsets(override)
	if(!override && buckled)
		return
	animate(src, pixel_x = src.base_pixel_x, pixel_y = src.base_pixel_y, 1)

//mob verbs are a lot faster than object verbs
//for more info on why this is not atom/pull, see examinate() in mob.dm
/mob/living/verb/pulled(atom/movable/AM as mob|obj in oview(1))
	set name = "Pull"
	set category = "Object"

	if(istype(AM) && Adjacent(AM))
		try_make_grab(AM)

/mob/living/verb/stop_pulling1()
	set name = "Stop Pulling"
	set category = "IC"
	release_all_grabs()

//same as above
/mob/living/pointed(atom/A as mob|obj|turf in view(client.view, src))
	if(incapacitated())
		return FALSE

	return ..()

/mob/living/_pointed(atom/pointing_at)
	if(!..())
		return FALSE
	log_message("points at [pointing_at]", LOG_EMOTE)
	visible_message("<span class='infoplain'>[span_name("[src]")] points at [pointing_at].</span>", span_notice("You point at [pointing_at]."))

/mob/living/verb/succumb(whispered as null)
	set hidden = TRUE
	if (stat == CONSCIOUS)
		to_chat(src, text="You are unable to succumb to death! This life continues.", type=MESSAGE_TYPE_INFO)
		return
	log_message("Has [whispered ? "whispered his final words" : "succumbed to death"] with [round(health, 0.1)] points of health!", LOG_ATTACK)
	adjustOxyLoss(health - HEALTH_THRESHOLD_DEAD)
	updatehealth()
	if(!whispered)
		to_chat(src, span_notice("You have given up life and succumbed to death."))
	death()

/**
 * Checks if a mob is incapacitated
 *
 * Normally being restrained, agressively grabbed, or in stasis counts as incapacitated
 * unless there is a flag being used to check if it's ignored
 *
 * args:
 * * flags (optional) bitflags that determine if special situations are exempt from being considered incapacitated
 *
 * bitflags: (see code/__DEFINES/status_effects.dm)
 * * IGNORE_RESTRAINTS - mob in a restraint (handcuffs) is not considered incapacitated
 * * IGNORE_STASIS - mob in stasis (stasis bed, etc.) is not considered incapacitated
 * * IGNORE_GRAB - mob that is agressively grabbed is not considered incapacitated
**/
/mob/living/incapacitated(flags)
	if(HAS_TRAIT(src, TRAIT_INCAPACITATED))
		return TRUE

	if(!(flags & IGNORE_RESTRAINTS) && HAS_TRAIT(src, TRAIT_ARMS_RESTRAINED))
		return TRUE

	if(!(flags & IGNORE_GRAB))
		for(var/obj/item/hand_item/grab/G in grabbed_by)
			if(G.current_grab.restrains && !G.assailant == src)
				return TRUE

	if(!(flags & IGNORE_STASIS) && IS_IN_HARD_STASIS(src))
		return TRUE
	return FALSE

/mob/living/canUseStorage()
	if (usable_hands <= 0)
		return FALSE
	return TRUE


//This proc is used for mobs which are affected by pressure to calculate the amount of pressure that actually
//affects them once clothing is factored in. ~Errorage
/mob/living/proc/calculate_affecting_pressure(pressure)
	return pressure

// MOB PROCS //END

/mob/living/proc/mob_sleep()
	set name = "Sleep"
	set category = "IC"

	if(IsSleeping())
		to_chat(src, span_warning("You are already sleeping!"))
		return
	else
		if(tgui_alert(usr, "You sure you want to sleep for a while?", "Sleep", list("Yes", "No")) == "Yes")
			SetSleeping(400) //Short nap


/mob/proc/get_contents()


/**
 * Gets ID card from a mob.
 * Argument:
 * * hand_firsts - boolean that checks the hands of the mob first if TRUE.
 */
/mob/living/proc/get_idcard(hand_first, bypass_wallet)
	RETURN_TYPE(/obj/item/card/id)

	if(!length(held_items)) //Early return for mobs without hands.
		return
	//Check hands
	var/obj/item/held_item = get_active_held_item()
	if(held_item) //Check active hand
		. = held_item.GetID(bypass_wallet)
	if(!.) //If there is no id, check the other hand
		held_item = get_inactive_held_item()
		if(held_item)
			. = held_item.GetID(bypass_wallet)

/mob/living/proc/get_id_in_hand()
	var/obj/item/held_item = get_active_held_item()
	if(!held_item)
		return
	return held_item.GetID()

//Returns the bank account of an ID the user may be holding.
/mob/living/proc/get_bank_account()
	RETURN_TYPE(/datum/bank_account)
	var/datum/bank_account/account
	var/obj/item/card/id/I = get_idcard()

	if(I?.registered_account)
		account = I.registered_account
		return account

/mob/living/proc/toggle_resting()
	set name = "Rest"
	set category = "IC"

	set_resting(!resting, FALSE)


///Proc to hook behavior to the change of value in the resting variable.
/mob/living/proc/set_resting(new_resting, silent = TRUE, instant = FALSE)
	if(!(mobility_flags & MOBILITY_REST))
		return
	if(new_resting == resting)
		return
	. = resting
	resting = new_resting
	if(new_resting)
		if(body_position == LYING_DOWN)
			if(!silent)
				to_chat(src, span_notice("You will now try to stay lying down on the floor."))
		else if(HAS_TRAIT(src, TRAIT_FORCED_STANDING) || (buckled && buckled.buckle_lying != NO_BUCKLE_LYING))
			if(!silent)
				to_chat(src, span_notice("You will now lay down as soon as you are able to."))
		else
			if(!silent)
				to_chat(src, span_notice("You lay down."))
			set_lying_down()
	else
		if(body_position == STANDING_UP)
			if(!silent)
				to_chat(src, span_notice("You will now try to remain standing up."))
		else if(HAS_TRAIT(src, TRAIT_FLOORED) || (buckled && buckled.buckle_lying != NO_BUCKLE_LYING))
			if(!silent)
				to_chat(src, span_notice("You will now stand up as soon as you are able to."))
		else
			if(!silent)
				to_chat(src, span_notice("You stand up."))
			get_up(instant)

	update_resting()


/// Proc to append and redefine behavior to the change of the [/mob/living/var/resting] variable.
/mob/living/proc/update_resting()
	update_rest_hud_icon()


/mob/living/proc/get_up(instant = FALSE)
	set waitfor = FALSE
	if(!instant && !do_after(src, src, 1 SECONDS, timed_action_flags = (DO_IGNORE_USER_LOC_CHANGE|DO_IGNORE_TARGET_LOC_CHANGE|DO_IGNORE_HELD_ITEM), extra_checks = CALLBACK(src, TYPE_PROC_REF(/mob/living, rest_checks_callback)), interaction_key = DOAFTER_SOURCE_GETTING_UP))
		return
	if(resting || body_position == STANDING_UP || HAS_TRAIT(src, TRAIT_FLOORED))
		return

	set_body_position(STANDING_UP)
	set_lying_angle(0)

/mob/living/proc/rest_checks_callback()
	if(resting || body_position == STANDING_UP || HAS_TRAIT(src, TRAIT_FLOORED))
		return FALSE
	return TRUE


/// Change the [body_position] to [LYING_DOWN] and update associated behavior.
/mob/living/proc/set_lying_down(new_lying_angle)
	set_body_position(LYING_DOWN)

/// Proc to append behavior related to lying down.
/mob/living/proc/on_lying_down(new_lying_angle)
	if(layer == initial(layer)) //to avoid things like hiding larvas.
		layer = LYING_MOB_LAYER //so mob lying always appear behind standing mobs

	ADD_TRAIT(src, TRAIT_UI_BLOCKED, LYING_DOWN_TRAIT)
	ADD_TRAIT(src, TRAIT_PULL_BLOCKED, LYING_DOWN_TRAIT)

	set_density(FALSE) // We lose density and stop bumping passable dense things.

	if(HAS_TRAIT(src, TRAIT_FLOORED) && !(dir & (NORTH|SOUTH)))
		setDir(pick(NORTH, SOUTH)) // We are and look helpless.

	if(rotate_on_lying)
		body_position_pixel_y_offset = PIXEL_Y_OFFSET_LYING

	playsound(loc, 'goon/sounds/body_thud.ogg', ishuman(src) ? 40 : 15, 1, 0.3)
	throw_alert("lying_down", /atom/movable/screen/alert/lying_down)

/// Proc to append behavior related to lying down.
/mob/living/proc/on_standing_up()
	if(layer == LYING_MOB_LAYER)
		layer = initial(layer)

	set_density(initial(density)) // We were prone before, so we become dense and things can bump into us again.

	REMOVE_TRAIT(src, TRAIT_UI_BLOCKED, LYING_DOWN_TRAIT)
	REMOVE_TRAIT(src, TRAIT_PULL_BLOCKED, LYING_DOWN_TRAIT)

	body_position_pixel_y_offset = get_pixel_y_offset_standing(current_size)

	clear_alert("lying_down")

/// Returns what the body_position_pixel_y_offset should be if the current size were `value`
/mob/living/proc/get_pixel_y_offset_standing(size)
	return (size-1) * get_icon_height() * 0.5

//Recursive function to find everything a mob is holding. Really shitty proc tbh.
/mob/living/get_contents()
	var/list/ret = list()
	ret |= contents //add our contents
	for(var/atom/iter_atom as anything in ret.Copy()) //iterate storage objects
		iter_atom.atom_storage?.return_inv(ret)
	for(var/obj/item/folder/F in ret.Copy()) //very snowflakey-ly iterate folders
		ret |= F.contents
	return ret

/**
 * Returns whether or not the mob can be injected. Should not perform any side effects.
 *
 * Arguments:
 * * user - The user trying to inject the mob.
 * * target_zone - The zone being targeted.
 * * injection_flags - A bitflag for extra properties to check.
 *   Check __DEFINES/injection.dm for more details, specifically the ones prefixed INJECT_CHECK_*.
 */
/mob/living/proc/can_inject(mob/user, target_zone, injection_flags)
	return TRUE

/**
 * Like can_inject, but it can perform side effects.
 *
 * Arguments:
 * * user - The user trying to inject the mob.
 * * target_zone - The zone being targeted.
 * * injection_flags - A bitflag for extra properties to check. Check __DEFINES/injection.dm for more details.
 *   Check __DEFINES/injection.dm for more details. Unlike can_inject, the INJECT_TRY_* defines will behave differently.
 */
/mob/living/proc/try_inject(mob/user, target_zone, injection_flags)
	return can_inject(user, target_zone, injection_flags)

/mob/living/is_injectable(mob/user, allowmobs = TRUE)
	return (allowmobs && reagents && can_inject(user))

/mob/living/is_drawable(mob/user, allowmobs = TRUE)
	return (allowmobs && reagents && can_inject(user))


///Sets the current mob's health value. Do not call directly if you don't know what you are doing, use the damage procs, instead.
/mob/living/proc/set_health(new_value)
	. = health
	health = new_value


/mob/living/proc/updatehealth(cause_of_death)
	if(status_flags & GODMODE)
		return

	set_health(maxHealth - getOxyLoss() - getToxLoss() - getFireLoss() - getBruteLoss() - getCloneLoss())
	med_hud_set_health()
	update_health_hud()
	update_stat(cause_of_death)

/mob/living/update_health_hud()
	var/severity = 0
	var/healthpercent = (health/maxHealth) * 100
	if(hud_used?.healthdoll) //to really put you in the boots of a simplemob
		var/atom/movable/screen/healthdoll/living/livingdoll = hud_used.healthdoll
		switch(healthpercent)
			if(100 to INFINITY)
				severity = 0
			if(80 to 100)
				severity = 1
			if(60 to 80)
				severity = 2
			if(40 to 60)
				severity = 3
			if(20 to 40)
				severity = 4
			if(1 to 20)
				severity = 5
			else
				severity = 6
		livingdoll.icon_state = "living[severity]"
		if(!livingdoll.filtered)
			livingdoll.filtered = TRUE
			var/icon/mob_mask = icon(icon, icon_state)
			if(mob_mask.Height() > world.icon_size || mob_mask.Width() > world.icon_size)
				var/health_doll_icon_state = health_doll_icon ? health_doll_icon : "megasprite"
				mob_mask = icon('icons/hud/screen_gen.dmi', health_doll_icon_state) //swap to something generic if they have no special doll
			livingdoll.add_filter("mob_shape_mask", 1, alpha_mask_filter(icon = mob_mask))
			livingdoll.add_filter("inset_drop_shadow", 2, drop_shadow_filter(size = -1))
	if(severity > 0)
		overlay_fullscreen("brute", /atom/movable/screen/fullscreen/brute, severity)
	else
		clear_fullscreen("brute")

//Proc used to resuscitate a mob, for full_heal see fully_heal()
/mob/living/proc/revive(full_heal = FALSE, admin_revive = FALSE, excess_healing = 0)
	if(QDELETED(src))
		return

	if(excess_healing)
		if(iscarbon(src))
			var/mob/living/carbon/C = src
			if(!(C.dna?.species && (NOBLOOD in C.dna.species.species_traits)))
				C.blood_volume += (excess_healing*2)//1 excess = 10 blood

			for(var/obj/item/organ/organ as anything in C.processing_organs)
				if(organ.organ_flags & ORGAN_SYNTHETIC)
					continue
				organ.applyOrganDamage(excess_healing * -1)//1 excess = 5 organ damage healed

		adjustOxyLoss(-20, TRUE)
		adjustToxLoss(-20, TRUE, TRUE) //slime friendly
		updatehealth()

	grab_ghost()

	if(full_heal)
		fully_heal(admin_revive = admin_revive)

	if(stat == DEAD && can_be_revived()) //in some cases you can't revive (e.g. no brain)
		set_suicide(FALSE)
		set_stat(UNCONSCIOUS) //the mob starts unconscious,
		updatehealth() //then we check if the mob should wake up.
		if(admin_revive)
			get_up(TRUE)
		update_sight()
		update_eye_blur()
		clear_alert(ALERT_NOT_ENOUGH_OXYGEN)
		reload_fullscreen()
		to_chat(src, span_obviousnotice("A rapidly growing speck of white floods your vision as the spark of life returns!"))
		. = TRUE

		if(excess_healing)
			INVOKE_ASYNC(src, PROC_REF(emote), "gasp")
			log_combat(src, src, "revived")

	else if(admin_revive)
		updatehealth()
		get_up(TRUE)

	if(.)
		qdel(GetComponent(/datum/component/spook_factor))
		mob_mood?.add_mood_event("revival", /datum/mood_event/revival)

	// The signal is called after everything else so components can properly check the updated values
	SEND_SIGNAL(src, COMSIG_LIVING_REVIVE, full_heal, admin_revive)


/*
 * Heals up the [target] to up to [heal_to] of the main damage types.
 * EX: If heal_to is 50, and they have 150 brute damage, they will heal 100 brute (up to 50 brute damage)
 *
 * If the target is dead, also revives them and heals their organs / restores blood.
 * If we have a [revive_message], play a visible message if the revive was successful.
 *
 * Arguments
 * * heal_to - the health threshold to heal the mob up to for each of the main damage types.
 * * revive_message - if provided, a visible message to show on a successful revive.
 *
 * Returns TRUE if the mob is alive afterwards, or FALSE if they're still dead (revive failed).
 */
/mob/living/proc/heal_and_revive(heal_to = 50, revive_message)

	// Heal their brute and burn up to the threshold we're looking for
	var/brute_to_heal = heal_to - getBruteLoss()
	var/burn_to_heal = heal_to - getFireLoss()
	var/oxy_to_heal = heal_to - getOxyLoss()
	var/tox_to_heal = heal_to - getToxLoss()
	if(brute_to_heal < 0)
		adjustBruteLoss(brute_to_heal, FALSE)
	if(burn_to_heal < 0)
		adjustFireLoss(burn_to_heal, FALSE)
	if(oxy_to_heal < 0)
		adjustOxyLoss(oxy_to_heal, FALSE)
	if(tox_to_heal < 0)
		adjustToxLoss(tox_to_heal, FALSE, TRUE)

	// Run updatehealth once to set health for the revival check
	updatehealth()

	// We've given them a decent heal.
	// If they happen to be dead too, try to revive them - if possible.
	if(stat == DEAD && can_be_revived())
		// If the revive is successful, show our revival message (if present).
		if(revive(FALSE, FALSE, 10) && revive_message)
			visible_message(revive_message)

	// Finally update health again after we're all done
	updatehealth()

	return stat != DEAD

/mob/living/proc/remove_CC()
	SetStun(0)
	SetKnockdown(0)
	SetImmobilized(0)
	SetParalyzed(0)
	SetSleeping(0)
	setStaminaLoss(0)
	SetUnconscious(0)





//proc used to completely heal a mob.
//admin_revive = TRUE is used in other procs, for example mob/living/carbon/fully_heal()
/mob/living/proc/fully_heal(admin_revive = FALSE)
	restore_blood()
	setToxLoss(0, 0) //zero as second argument not automatically call updatehealth().
	setOxyLoss(0, 0)
	setCloneLoss(0, 0)
	remove_CC()
	set_disgust(0)
	losebreath = 0
	set_nutrition(NUTRITION_LEVEL_FED + 50)
	bodytemperature = get_body_temp_normal(apply_change=FALSE)
	set_blindness(0)
	set_blurriness(0)
	cure_nearsighted()
	cure_blind()
	cure_husk()
	hallucination = 0
	heal_overall_damage(INFINITY, INFINITY, null, TRUE) //heal brute and burn dmg on both organic and robotic limbs, and update health right away.
	stamina.adjust(INFINITY)
	exit_stamina_stun()
	extinguish_mob()
	set_drowsyness(0)
	stop_sound_channel(CHANNEL_HEARTBEAT)
	SEND_SIGNAL(src, COMSIG_LIVING_POST_FULLY_HEAL, admin_revive)


//proc called by revive(), to check if we can actually ressuscitate the mob (we don't want to revive him and have him instantly die again)
/mob/living/proc/can_be_revived()
	. = TRUE
	if(health <= HEALTH_THRESHOLD_DEAD)
		return FALSE

/mob/living/proc/update_damage_overlays()
	return

/// Proc that only really gets called for humans, to handle bleeding overlays.
/mob/living/proc/update_wound_overlays()
	return

/mob/living/Move(atom/newloc, direct, glide_size_override, z_movement_flags)
	if(lying_angle != 0)
		lying_angle_on_movement(direct)
	if (buckled && buckled.loc != newloc) //not updating position
		if (buckled.anchored)
			return FALSE
		return buckled.move_from_pull(newloc, buckled, glide_size)

	var/old_direction = dir
	var/turf/T = loc

	update_pull_movespeed()

	. = ..()

	if(active_storage)
		var/storage_in_self = (active_storage.parent in important_recursive_contents?[RECURSIVE_CONTENTS_ACTIVE_STORAGE])
		if(!storage_in_self && !active_storage.can_be_reached_by(src))
			active_storage.hide_contents(src)

	if(!ISDIAGONALDIR(direct) && newloc != T && body_position == LYING_DOWN && !buckled && has_gravity())
		if(length(grabbed_by))
			drag_damage(newloc, T, old_direction)
		else
			makeBloodTrail(newloc, T, old_direction)


///Called by mob Move() when the lying_angle is different than zero, to better visually simulate crawling.
/mob/living/proc/lying_angle_on_movement(direct)
	if(direct & EAST)
		set_lying_angle(LYING_ANGLE_EAST)
	else if(direct & WEST)
		set_lying_angle(LYING_ANGLE_WEST)

/mob/living/setDir(ndir)
	. = ..()
	if(isnull(.))
		return

	for(var/atom/movable/AM as anything in important_recursive_contents?[RECURSIVE_CONTENTS_ACTIVE_STORAGE])
		if(UNLINT(length(AM.atom_storage.is_using)))
			AM.atom_storage.update_viewability()

/mob/living/carbon/alien/humanoid/lying_angle_on_movement(direct)
	return

/// Take damage from being dragged while prone. Or not. You decide.
/mob/living/proc/drag_damage(turf/new_loc, turf/old_loc, direction)
	if(prob(getBruteLoss() / 2))
		makeBloodTrail(new_loc, old_loc, direction, TRUE)

	if(prob(10))
		visible_message(span_danger("[src]'s wounds worsen as they're dragged across the ground."))
		adjustBruteLoss(2)

/// Creates a trail of blood on Start, facing Direction
/mob/living/proc/makeBloodTrail(turf/target_turf, turf/start, direction, being_dragged)
	if(!isturf(start) || !leavesBloodTrail())
		return

	var/trail_type = getTrail(being_dragged)
	if(!trail_type)
		return

	var/blood_exists = locate(/obj/effect/decal/cleanable/blood/trail_holder) in start

	var/newdir = get_dir(target_turf, start)
	if(newdir != direction)
		newdir = newdir | direction
		if(newdir == (NORTH|SOUTH))
			newdir = NORTH
		else if(newdir == (EAST|WEST))
			newdir = EAST

	if((!(newdir & (newdir - 1))) && (prob(50))) // Cardinal move
		newdir = turn(get_dir(target_turf, start), 180)

	if(!blood_exists)
		new /obj/effect/decal/cleanable/blood/trail_holder(start, get_static_viruses())

	for(var/obj/effect/decal/cleanable/blood/trail_holder/TH in start)
		if(TH.existing_dirs.len >= 16) //maximum amount of overlays is 16 (all light & heavy directions filled)
			continue
		if(!(newdir in TH.existing_dirs) || trail_type == "bleedtrail_heavy")
			TH.existing_dirs += newdir
			TH.add_overlay(image('icons/effects/blood.dmi', icon_state = trail_type, dir = newdir))
			TH.transfer_mob_blood_dna(src)

/// Returns TRUE if we should try to leave a blood trail.
/mob/living/proc/leavesBloodTrail()
	if(!blood_volume)
		return FALSE

	return TRUE

/mob/living/proc/getTrail(being_dragged)
	if(getBruteLoss() < 75)
		return "bleedtrail_light_[rand(1,4)]"
	else
		return "bleedtrail_heavy"

/mob/living/can_resist()
	if(next_move > world.time)
		return FALSE
	if(HAS_TRAIT(src, TRAIT_INCAPACITATED))
		return FALSE
	return TRUE

/mob/living/verb/resist()
	set name = "Resist"
	set category = "IC"

	DEFAULT_QUEUE_OR_CALL_VERB(VERB_CALLBACK(src, PROC_REF(execute_resist)))

///proc extender of [/mob/living/verb/resist] meant to make the process queable if the server is overloaded when the verb is called
/mob/living/proc/execute_resist()
	if(!can_resist())
		return
	changeNext_move(CLICK_CD_RESIST)

	SEND_SIGNAL(src, COMSIG_LIVING_RESIST, src)
	//resisting grabs (as if it helps anyone...)
	if(!HAS_TRAIT(src, TRAIT_ARMS_RESTRAINED) && LAZYLEN(grabbed_by))
		resist_grab()
		return

	//unbuckling yourself
	if(buckled && last_special <= world.time)
		resist_buckle()

	//Breaking out of a container (Locker, sleeper, cryo...)
	else if(loc != get_turf(src))
		loc.container_resist_act(src)

	else if(mobility_flags & MOBILITY_MOVE)
		if(on_fire)
			resist_fire() //stop, drop, and roll
		else if(last_special <= world.time)
			resist_restraints() //trying to remove cuffs.

/// Attempt to break free of grabs. Returning TRUE means the user broke free and can move.
/mob/proc/resist_grab(moving_resist)
	return TRUE

/mob/living/resist_grab(moving_resist)
	if(!LAZYLEN(grabbed_by))
		return TRUE

	if(!moving_resist)
		visible_message(span_danger("\The [src] struggles to break free!"))

	. = TRUE
	for(var/obj/item/hand_item/grab/G as anything in grabbed_by)
		if(G.assailant == src) //Grabbing our own bodyparts
			continue
		log_combat(src, G.assailant, "resisted grab")
		if(!G.handle_resist())
			. = FALSE

/// Attempt to break out of a buckle. Returns TRUE if successful.
/mob/living/proc/resist_buckle()
	return !!buckled.user_unbuckle_mob(src,src)

/mob/living/proc/resist_fire()
	return

/mob/living/proc/resist_restraints()
	return

/mob/living/proc/update_gravity(gravity)
	// Handle movespeed stuff
	var/speed_change = max(0, gravity - STANDARD_GRAVITY)
	if(speed_change)
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/gravity, slowdown=speed_change)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/gravity)

	// Time to add/remove gravity alerts. sorry for the mess it's gotta be fast
	var/atom/movable/screen/alert/gravity_alert = alerts[ALERT_GRAVITY]
	switch(gravity)
		if(-INFINITY to NEGATIVE_GRAVITY)
			if(!istype(gravity_alert, /atom/movable/screen/alert/negative))
				throw_alert(ALERT_GRAVITY, /atom/movable/screen/alert/negative)
				var/matrix/flipped_matrix = transform
				flipped_matrix.b = -flipped_matrix.b
				flipped_matrix.e = -flipped_matrix.e
				animate(src, transform = flipped_matrix, pixel_y = pixel_y+4, time = 0.5 SECONDS, easing = EASE_OUT)
				base_pixel_y += 4
		if(NEGATIVE_GRAVITY + 0.01 to 0)
			if(!istype(gravity_alert, /atom/movable/screen/alert/weightless))
				throw_alert(ALERT_GRAVITY, /atom/movable/screen/alert/weightless)
				ADD_TRAIT(src, TRAIT_MOVE_FLOATING, NO_GRAVITY_TRAIT)
		if(0.01 to STANDARD_GRAVITY)
			if(gravity_alert)
				clear_alert(ALERT_GRAVITY)
		if(STANDARD_GRAVITY + 0.01 to GRAVITY_DAMAGE_THRESHOLD - 0.01)
			throw_alert(ALERT_GRAVITY, /atom/movable/screen/alert/highgravity)
		if(GRAVITY_DAMAGE_THRESHOLD to INFINITY)
			throw_alert(ALERT_GRAVITY, /atom/movable/screen/alert/veryhighgravity)

	// If we had no gravity alert, or the same alert as before, go home
	if(!gravity_alert || alerts[ALERT_GRAVITY] == gravity_alert)
		return
	// By this point we know that we do not have the same alert as we used to
	if(istype(gravity_alert, /atom/movable/screen/alert/weightless))
		REMOVE_TRAIT(src, TRAIT_MOVE_FLOATING, NO_GRAVITY_TRAIT)
	if(istype(gravity_alert, /atom/movable/screen/alert/negative))
		var/matrix/flipped_matrix = transform
		flipped_matrix.b = -flipped_matrix.b
		flipped_matrix.e = -flipped_matrix.e
		animate(src, transform = flipped_matrix, pixel_y = pixel_y-4, time = 0.5 SECONDS, easing = EASE_OUT)
		base_pixel_y -= 4

/mob/living/singularity_pull(S, current_size)
	..()
	if(move_resist == INFINITY)
		return
	if(current_size >= STAGE_SIX) //your puny magboots/wings/whatever will not save you against supermatter singularity
		throw_at(S, 14, 3, src, TRUE)
	else if(!src.mob_negates_gravity())
		step_towards(src,S)

/mob/living/proc/get_temperature(datum/gas_mixture/environment)
	var/loc_temp = environment ? environment.temperature : T0C
	if(isobj(loc))
		var/obj/oloc = loc
		var/obj_temp = oloc.return_temperature()
		if(obj_temp != null)
			loc_temp = obj_temp
	else if(isspaceturf(get_turf(src)))
		var/turf/heat_turf = get_turf(src)
		loc_temp = heat_turf.temperature
	if(ismovable(loc))
		var/atom/movable/occupied_space = loc
		loc_temp = ((1 - occupied_space.contents_thermal_insulation) * loc_temp) + (occupied_space.contents_thermal_insulation * bodytemperature)
	return loc_temp

/mob/living/cancel_camera()
	..()
	cameraFollow = null

/mob/living/proc/can_track(mob/living/user)
	//basic fast checks go first. When overriding this proc, I recommend calling ..() at the end.
	if(SEND_SIGNAL(src, COMSIG_LIVING_CAN_TRACK, args) & COMPONENT_CANT_TRACK)
		return FALSE
	var/turf/T = get_turf(src)
	if(!T)
		return FALSE
	if(is_centcom_level(T.z)) //dont detect mobs on centcom
		return FALSE
	if(is_away_level(T.z))
		return FALSE
	if(user != null && src == user)
		return FALSE
	if(invisibility || alpha == 0)//cloaked
		return FALSE
	// Now, are they viewable by a camera? (This is last because it's the most intensive check)
	if(!near_camera(src))
		return FALSE
	return TRUE

//used in datum/reagents/reaction() proc
/mob/living/proc/get_permeability_protection(list/target_zones)
	return 0

/mob/living/proc/harvest(mob/living/user) //used for extra objects etc. in butchering
	return

/mob/living/can_hold_items(obj/item/I)
	return usable_hands && ..()

/mob/living/canUseTopic(atom/target, flags)
	if(stat != CONSCIOUS)
		to_chat(src, span_warning("You cannot do that while unconscious."))
		return FALSE

	// If the MOBILITY_UI bitflag is not set it indicates the mob's hands are cutoff, blocked, or handcuffed
	// Note - AI's and borgs have the MOBILITY_UI bitflag set even though they don't have hands
	// Also if it is not set, the mob could be incapcitated, knocked out, unconscious, asleep, EMP'd, etc.
	if(!(mobility_flags & MOBILITY_UI) && !(flags & USE_RESTING))
		to_chat(src, span_warning("You cannot do that right now."))
		return FALSE

	// NEED_HANDS is already checked by MOBILITY_UI for humans so this is for silicons
	if((flags & USE_NEED_HANDS) && !can_hold_items(isitem(target) ? target : null)) //almost redundant if it weren't for mobs,
		to_chat(src, span_warning("You are not physically capable of doing that."))
		return FALSE

	if((flags & USE_CLOSE) && !target.IsReachableBy(src) && (recursive_loc_check(src, target)))
		if(issilicon(src) && !ispAI(src))
			if(!(flags & USE_SILICON_REACH)) // silicons can ignore range checks (except pAIs)
				to_chat(src, span_warning("You are too far away."))
				return FALSE

		else if(flags & USE_IGNORE_TK)
			to_chat(src, span_warning("You are too far away."))
			return FALSE

		else
			var/datum/dna/D = has_dna()
			if(!D || !D.check_mutation(/datum/mutation/human/telekinesis) || !tkMaxRangeCheck(src, target))
				to_chat(src, span_warning("You are too far away."))
				return FALSE

	if((flags & USE_DEXTERITY) && !ISADVANCEDTOOLUSER(src))
		to_chat(src, span_warning("You do not have the dexterity required to do that."))
		return FALSE

	if((flags & USE_LITERACY) && !is_literate())
		to_chat(src, span_warning("You cannot comprehend this."))
		return FALSE
	return TRUE

/mob/living/proc/can_use_guns(obj/item/G)//actually used for more than guns!
	if(G.trigger_guard == TRIGGER_GUARD_NONE)
		to_chat(src, span_warning("You are unable to fire that."))
		return FALSE
	if(G.trigger_guard != TRIGGER_GUARD_ALLOW_ALL && (!ISADVANCEDTOOLUSER(src) && !HAS_TRAIT(src, TRAIT_GUN_NATURAL)))
		to_chat(src, span_warning("You attempt to fire [G], but cannot pull the trigger."))
		return FALSE
	return TRUE

///Called by [update()][/datum/stamina_container/proc/update]
/mob/living/proc/on_stamina_update()
	return

/mob/living/carbon/alien/on_stamina_update()
	return

/mob/living/throw_at(atom/target, range, speed, mob/thrower, spin=1, diagonals_first = 0, datum/callback/callback, force, gentle = FALSE, quickstart = TRUE)
	release_all_grabs()
	. = ..()

// Used in polymorph code to shapeshift mobs into other creatures
/mob/living/proc/wabbajack(randomize)
	// If the mob has a shapeshifted form, we want to pull out the reference of the caster's original body from it.
	// We then want to restore this original body through the shapeshift holder itself.
	var/obj/shapeshift_holder/shapeshift = locate() in src
	if(shapeshift)
		shapeshift.restore()
		if(shapeshift.stored != src) // To reduce the risk of an infinite loop.
			return shapeshift.stored.wabbajack(randomize)

	if(stat == DEAD || notransform || (GODMODE & status_flags))
		return

	notransform = TRUE
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, MAGIC_TRAIT)
	ADD_TRAIT(src, TRAIT_HANDS_BLOCKED, MAGIC_TRAIT)
	icon = null
	cut_overlays()
	invisibility = INVISIBILITY_ABSTRACT

	var/list/item_contents = list()

	if(iscyborg(src))
		var/mob/living/silicon/robot/Robot = src
		// Disconnect AI's in shells
		if(Robot.connected_ai)
			Robot.connected_ai.disconnect_shell()
		if(Robot.mmi)
			qdel(Robot.mmi)
		Robot.notify_ai(AI_NOTIFICATION_NEW_BORG)
	else
		for(var/obj/item/item in src)
			if(!dropItemToGround(item) || (item.item_flags & ABSTRACT))
				qdel(item)
				continue
			item_contents += item

	var/mob/living/new_mob

	if(!randomize)
		randomize = pick("monkey","robot","slime","xeno","humanoid","animal")
	switch(randomize)
		if("monkey")
			new_mob = new /mob/living/carbon/human/species/monkey(loc)

		if("robot")
			var/robot = pick(
				200 ; /mob/living/silicon/robot,
				/mob/living/silicon/robot/model/syndicate,
				/mob/living/silicon/robot/model/syndicate/medical,
				/mob/living/silicon/robot/model/syndicate/saboteur,
				200 ; /mob/living/simple_animal/drone/polymorphed,
			)
			new_mob = new robot(loc)
			if(issilicon(new_mob))
				new_mob.gender = gender
				new_mob.invisibility = 0
				new_mob.job = JOB_CYBORG
				var/mob/living/silicon/robot/Robot = new_mob
				Robot.lawupdate = FALSE
				Robot.connected_ai = null
				Robot.mmi.transfer_identity(src) //Does not transfer key/client.
				Robot.clear_inherent_laws(announce = FALSE)
				Robot.clear_zeroth_law(announce = FALSE)

		if("slime")
			new_mob = new /mob/living/simple_animal/slime/random(loc)

		if("xeno")
			var/xeno_type
			if(ckey)
				xeno_type = pick(
					/mob/living/carbon/alien/humanoid/hunter,
					/mob/living/carbon/alien/humanoid/sentinel,
				)
			else
				xeno_type = pick(
					/mob/living/carbon/alien/humanoid/hunter,
					/mob/living/simple_animal/hostile/alien/sentinel,
				)
			new_mob = new xeno_type(loc)

		if("animal")
			var/path = pick(
				/mob/living/simple_animal/hostile/carp,
				/mob/living/simple_animal/hostile/bear,
				/mob/living/simple_animal/hostile/mushroom,
				/mob/living/simple_animal/hostile/statue,
				/mob/living/simple_animal/hostile/retaliate/bat,
				/mob/living/simple_animal/hostile/retaliate/goat,
				/mob/living/simple_animal/hostile/killertomato,
				/mob/living/simple_animal/hostile/blob/blobbernaut/independent,
				/mob/living/simple_animal/hostile/carp/ranged,
				/mob/living/simple_animal/hostile/carp/ranged/chaos,
				/mob/living/simple_animal/hostile/asteroid/basilisk/watcher,
				/mob/living/simple_animal/hostile/headcrab,
				/mob/living/simple_animal/hostile/morph,
				/mob/living/simple_animal/hostile/gorilla,
				/mob/living/simple_animal/parrot,
				/mob/living/simple_animal/pet/dog/corgi,
				/mob/living/simple_animal/crab,
				/mob/living/simple_animal/pet/dog/pug,
				/mob/living/simple_animal/pet/cat,
				/mob/living/simple_animal/mouse,
				/mob/living/simple_animal/chicken,
				/mob/living/basic/cow,
				/mob/living/simple_animal/hostile/lizard,
				/mob/living/simple_animal/pet/fox,
				/mob/living/simple_animal/butterfly,
				/mob/living/simple_animal/pet/cat/cak,
				/mob/living/simple_animal/chick,
			)
			new_mob = new path(loc)

		if("humanoid")
			var/mob/living/carbon/human/new_human = new (loc)

			if(prob(50))
				var/list/chooseable_races = list()
				for(var/speciestype in subtypesof(/datum/species))
					var/datum/species/S = speciestype
					if(initial(S.changesource_flags) & WABBAJACK)
						chooseable_races += speciestype

				if(length(chooseable_races))
					new_human.set_species(pick(chooseable_races))

			// Randomize everything but the species, which was already handled above.
			new_human.randomize_human_appearance(~RANDOMIZE_SPECIES)
			new_human.update_body(is_creating = TRUE)
			new_human.dna.update_dna_identity()
			new_mob = new_human

	if(!new_mob)
		return

	// Some forms can still wear some items
	for(var/obj/item/item as anything in item_contents)
		new_mob.equip_to_appropriate_slot(item)

	log_message("became [new_mob.name]([new_mob.type])", LOG_ATTACK, color="orange")
	new_mob.set_combat_mode(TRUE)
	wabbajack_act(new_mob)
	to_chat(new_mob, span_warning("Your form morphs into that of a [randomize]."))

	var/poly_msg = get_policy(POLICY_POLYMORPH)
	if(poly_msg)
		to_chat(new_mob, poly_msg)

	transfer_observers_to(new_mob)

	. = new_mob
	qdel(src)

// Called when we are hit by a bolt of polymorph and changed
// Generally the mob we are currently in is about to be deleted
/mob/living/proc/wabbajack_act(mob/living/new_mob)
	log_game("[key_name(src)] is being wabbajack polymorphed into: [new_mob.name]([new_mob.type]).")
	new_mob.set_real_name(real_name)

	if(mind)
		mind.transfer_to(new_mob)
	else
		new_mob.key = key

	for(var/para in hasparasites())
		var/mob/living/simple_animal/hostile/guardian/G = para
		G.summoner = new_mob
		G.Recall()
		to_chat(G, span_holoparasite("Your summoner has changed form!"))

/mob/living/proc/unfry_mob() //Callback proc to tone down spam from multiple sizzling frying oil dipping.
	REMOVE_TRAIT(src, TRAIT_OIL_FRIED, "cooking_oil_react")

//Mobs on Fire

/// Global list that containes cached fire overlays for mobs
GLOBAL_LIST_EMPTY(fire_appearances)

/mob/living/proc/ignite_mob()
	if(fire_stacks <= 0)
		return FALSE

	var/datum/status_effect/fire_handler/fire_stacks/fire_status = has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
	if(!fire_status || fire_status.on_fire)
		return FALSE

	return fire_status.ignite()

/mob/living/proc/update_fire()
	var/datum/status_effect/fire_handler/fire_stacks/fire_stacks = has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
	if(fire_stacks)
		fire_stacks.update_overlay()

/**
 * Extinguish all fire on the mob
 *
 * This removes all fire stacks, fire effects, alerts, and moods
 * Signals the extinguishing.
 */
/mob/living/proc/extinguish_mob()
	var/datum/status_effect/fire_handler/fire_stacks/fire_status = has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
	if(!fire_status || !fire_status.on_fire)
		return

	remove_status_effect(/datum/status_effect/fire_handler/fire_stacks)

/**
 * Adjust the amount of fire stacks on a mob
 *
 * This modifies the fire stacks on a mob.
 *
 * Vars:
 * * stacks: int The amount to modify the fire stacks
 * * fire_type: type Type of fire status effect that we apply, should be subtype of /datum/status_effect/fire_handler/fire_stacks
 */

/mob/living/proc/adjust_fire_stacks(stacks, fire_type = /datum/status_effect/fire_handler/fire_stacks)
	if(stacks < 0)
		stacks = max(-fire_stacks, stacks)
	apply_status_effect(fire_type, stacks)

/mob/living/proc/adjust_wet_stacks(stacks, wet_type = /datum/status_effect/fire_handler/wet_stacks)
	if(stacks < 0)
		stacks = max(fire_stacks, stacks)
	apply_status_effect(wet_type, stacks)

/**
 * Set the fire stacks on a mob
 *
 * This sets the fire stacks on a mob, stacks are clamped between -20 and 20.
 * If the fire stacks are reduced to 0 then we will extinguish the mob.
 *
 * Vars:
 * * stacks: int The amount to set fire_stacks to
 * * fire_type: type Type of fire status effect that we apply, should be subtype of /datum/status_effect/fire_handler/fire_stacks
 * * remove_wet_stacks: bool If we remove all wet stacks upon doing this
 */

/mob/living/proc/set_fire_stacks(stacks, fire_type = /datum/status_effect/fire_handler/fire_stacks, remove_wet_stacks = TRUE)
	if(stacks < 0) //Shouldn't happen, ever
		CRASH("set_fire_stacks recieved negative [stacks] fire stacks")

	if(remove_wet_stacks)
		remove_status_effect(/datum/status_effect/fire_handler/wet_stacks)

	if(stacks == 0)
		remove_status_effect(fire_type)
		return

	apply_status_effect(fire_type, stacks, TRUE)

/mob/living/proc/set_wet_stacks(stacks, wet_type = /datum/status_effect/fire_handler/wet_stacks, remove_fire_stacks = TRUE)
	if(stacks < 0)
		CRASH("set_wet_stacks recieved negative [stacks] wet stacks")

	if(remove_fire_stacks)
		remove_status_effect(/datum/status_effect/fire_handler/fire_stacks)

	if(stacks == 0)
		remove_status_effect(wet_type)
		return

	apply_status_effect(wet_type, stacks, TRUE)

//Share fire evenly between the two mobs
//Called in MobBump() and Crossed()
/mob/living/proc/spreadFire(mob/living/spread_to)
	if(!istype(spread_to))
		return

	// can't spread fire to mobs that don't catch on fire
	if(HAS_TRAIT(spread_to, TRAIT_NOFIRE_SPREAD) || HAS_TRAIT(src, TRAIT_NOFIRE_SPREAD))
		return

	var/datum/status_effect/fire_handler/fire_stacks/fire_status = has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
	var/datum/status_effect/fire_handler/fire_stacks/their_fire_status = spread_to.has_status_effect(/datum/status_effect/fire_handler/fire_stacks)
	if(fire_status && fire_status.on_fire)
		if(their_fire_status && their_fire_status.on_fire)
			var/firesplit = (fire_stacks + spread_to.fire_stacks) / 2
			var/fire_type = (spread_to.fire_stacks > fire_stacks) ? their_fire_status.type : fire_status.type
			set_fire_stacks(firesplit, fire_type)
			spread_to.set_fire_stacks(firesplit, fire_type)
			return

		adjust_fire_stacks(-fire_stacks / 2, fire_status.type)
		spread_to.adjust_fire_stacks(fire_stacks, fire_status.type)
		if(spread_to.ignite_mob())
			log_game("[key_name(src)] bumped into [key_name(spread_to)] and set them on fire")
		return

	if(!their_fire_status || !their_fire_status.on_fire)
		return

	spread_to.adjust_fire_stacks(-spread_to.fire_stacks / 2, their_fire_status.type)
	adjust_fire_stacks(spread_to.fire_stacks, their_fire_status.type)
	ignite_mob()

/**
 * Sets fire overlay of the mob.
 *
 * Vars:
 * * stacks: Current amount of fire_stacks
 * * on_fire: If we're lit on fire
 * * last_icon_state: Holds last fire overlay icon state, used for optimization
 * * suffix: Suffix for the fire icon state for special fire types
 *
 * This should return last_icon_state for the fire status efect
 */

/mob/living/proc/update_fire_overlay(stacks, on_fire, last_icon_state, suffix = "")
	return last_icon_state

/**
 * Handles effects happening when mob is on normal fire
 *
 * Vars:
 * * delta_time
 * * times_fired
 * * fire_handler: Current fire status effect that called the proc
 */

/mob/living/proc/on_fire_stack(delta_time, times_fired, datum/status_effect/fire_handler/fire_stacks/fire_handler)
	return

//Mobs on Fire end

// used by secbot and monkeys Crossed
/mob/living/proc/knockOver(mob/living/carbon/C)
	if(C.key) //save us from monkey hordes
		C.visible_message("<span class='warning'>[pick( \
						"[C] dives out of [src]'s way!", \
						"[C] stumbles over [src]!", \
						"[C] jumps out of [src]'s path!", \
						"[C] trips over [src] and falls!", \
						"[C] topples over [src]!", \
						"[C] leaps out of [src]'s way!")]</span>")
	C.Paralyze(40)

/// Called when mob changes from a standing position into a prone while lacking the ability to stand up at the moment.
/mob/living/proc/on_fall()
	return

/mob/living/forceMove(atom/destination)
	var/old_loc = loc
	if(!currently_z_moving)
		if(buckled && !HAS_TRAIT(src, TRAIT_CANNOT_BE_UNBUCKLED))
			buckled.unbuckle_mob(src, force = TRUE)
		if(has_buckled_mobs())
			unbuckle_all_mobs(force = TRUE)

	. = ..()
	if(!.)
		return

	if(!QDELETED(src) && currently_z_moving == ZMOVING_VERTICAL) // Lateral Z movement handles this on it's own
		handle_grabs_during_movement(old_loc, get_dir(old_loc, src))
		recheck_grabs()

	else if(!forcemove_should_maintain_grab && length(active_grabs))
		recheck_grabs()

	if(client)
		reset_perspective()


/mob/living/proc/update_z(new_z) // 1+ to register, null to unregister
	if (registered_z != new_z)
		if (registered_z)
			SSmobs.clients_by_zlevel[registered_z] -= src
		if (client)
			if (new_z)
				//Figure out how many clients were here before
				var/oldlen = SSmobs.clients_by_zlevel[new_z].len
				SSmobs.clients_by_zlevel[new_z] += src
				for (var/I in length(SSidlenpcpool.idle_mobs_by_zlevel[new_z]) to 1 step -1) //Backwards loop because we're removing (guarantees optimal rather than worst-case performance), it's fine to use .len here but doesn't compile on 511
					var/mob/living/simple_animal/SA = SSidlenpcpool.idle_mobs_by_zlevel[new_z][I]
					if (SA)
						if(oldlen == 0)
							//Start AI idle if nobody else was on this z level before (mobs will switch off when this is the case)
							SA.toggle_ai(AI_IDLE)

						//If they are also within a close distance ask the AI if it wants to wake up
						if(get_dist(get_turf(src), get_turf(SA)) < MAX_SIMPLEMOB_WAKEUP_RANGE)
							SA.consider_wakeup() // Ask the mob if it wants to turn on it's AI
					//They should clean up in destroy, but often don't so we get them here
					else
						SSidlenpcpool.idle_mobs_by_zlevel[new_z] -= SA


			registered_z = new_z
		else
			registered_z = null

/mob/living/on_changed_z_level(turf/old_turf, turf/new_turf)
	..()
	update_z(new_turf?.z)

/mob/living/MouseDroppedOn(atom/dropping, atom/user)
	var/mob/living/U = user
	if(isliving(dropping))
		var/mob/living/M = dropping
		if(U.is_grabbing(M) && !U.combat_mode && mob_size > M.mob_size)
			M.mob_try_pickup(U)//blame kevinz
			return//dont open the mobs inventory if you are picking them up
	. = ..()

/**
 * Attempt to pick up a mob.
 *
 * `src` is the mob being picked up, `user` is the mob doing the pick upping.
 *
 * Arguments:
 * * mob/living/user - The user attempting to pick up this mob.
 * * instant - Should the mob be picked up instantly?
 */
/mob/living/proc/mob_try_pickup(mob/living/user, instant = FALSE)
	. = FALSE
	if(!mob_pickup_checks(user))
		return
	if(!instant)
		user.visible_message(span_warning("[user] starts trying to pick up [src]!"),
			span_danger("You start trying to pick up [src]..."), ignored_mobs = src)
		to_chat(src, span_userdanger("[user] starts trying to pick you up!"))
		if(!do_after(user, src, 2 SECONDS))
			return
		if(!mob_pickup_checks(user)) // Check everything again after the timer
			return
	mob_pickup(user)
	return TRUE

/mob/living/proc/mob_pickup_checks(mob/living/user, display_messages = TRUE)
	if(QDELETED(src) || !istype(user))
		return FALSE
	if(!user.get_empty_held_indexes())
		if(display_messages)
			to_chat(user, span_warning("Your hands are full!"))
		return FALSE
	if(buckled)
		if(display_messages)
			to_chat(user, span_warning("[src] is buckled to [buckled] and cannot be picked up!"))
		return FALSE
	return TRUE

/**
 * Spawn a [/obj/item/mob_holder], move `src` into it, and put it into the hands of `user`.
 *
 * [/mob/living/proc/mob_try_pickup] should be called instead of this under most circumstances.
 *
 * Arguments:
 * * mob/living/user - The user picking up this mob.
 */
/mob/living/proc/mob_pickup(mob/living/user)
	var/obj/item/mob_holder/holder = new held_type(get_turf(src), src, held_state, head_icon, held_lh, held_rh, worn_slot_flags)
	user.visible_message(span_warning("[user] picks up [src]!"))
	user.put_in_hands(holder)
	return holder

/mob/living/remove_air(amount) //To prevent those in contents suffocating
	return loc ? loc.remove_air(amount) : null

/// Gives simple mobs their unique/randomized name.
/mob/living/proc/give_unique_name()
	numba = rand(1, 1000)
	set_real_name("[name] ([numba])")

/mob/living/proc/get_static_viruses() //used when creating blood and other infective objects
	if(!LAZYLEN(diseases))
		return
	var/list/datum/pathogen/result = list()
	for(var/datum/pathogen/D in diseases)
		var/static_virus = D.Copy()
		result += static_virus
	return result

/mob/living/reset_perspective(atom/A)
	if(!..())
		return
	update_sight()
	update_fullscreen()
	update_pipe_vision()

/// Proc used to handle the fullscreen overlay updates, realistically meant for the reset_perspective() proc.
/mob/living/proc/update_fullscreen()
	if(client.eye && client.eye != src)
		var/atom/client_eye = client.eye
		client_eye.get_remote_view_fullscreens(src)
	else
		clear_fullscreen("remote_view", 0)

/mob/living/vv_edit_var(var_name, var_value)
	switch(var_name)
		if (NAMEOF(src, maxHealth))
			if (!isnum(var_value) || var_value <= 0)
				return FALSE
		if(NAMEOF(src, health)) //this doesn't work. gotta use procs instead.
			return FALSE
		if(NAMEOF(src, resting))
			set_resting(var_value)
			. = TRUE
		if(NAMEOF(src, lying_angle))
			set_lying_angle(var_value)
			. = TRUE
		if(NAMEOF(src, buckled))
			set_buckled(var_value)
			. = TRUE
		if(NAMEOF(src, num_legs))
			set_num_legs(var_value)
			. = TRUE
		if(NAMEOF(src, usable_legs))
			set_usable_legs(var_value)
			. = TRUE
		if(NAMEOF(src, num_hands))
			set_num_hands(var_value)
			. = TRUE
		if(NAMEOF(src, usable_hands))
			set_usable_hands(var_value)
			. = TRUE
		if(NAMEOF(src, body_position))
			set_body_position(var_value)
			. = TRUE
		if(NAMEOF(src, current_size))
			if(var_value == 0) //prevents divisions of and by zero.
				return FALSE
			update_transform(var_value/current_size)
			. = TRUE

	if(!isnull(.))
		datum_flags |= DF_VAR_EDITED
		return

	. = ..()

	switch(var_name)
		if(NAMEOF(src, maxHealth))
			updatehealth()
		if(NAMEOF(src, lighting_alpha))
			sync_lighting_plane_alpha()


/mob/living/vv_get_header()
	. = ..()
	var/refid = REF(src)
	. += {"
		<br><font size='1'>[VV_HREF_TARGETREF(refid, VV_HK_GIVE_DIRECT_CONTROL, "[ckey || "no ckey"]")] / [VV_HREF_TARGETREF_1V(refid, VV_HK_BASIC_EDIT, "[real_name || "no real name"]", NAMEOF(src, real_name))]</font>
		<br><font size='1'>
			BRUTE:<font size='1'><a href='?_src_=vars;[HrefToken()];mobToDamage=[refid];adjustDamage=brute' id='brute'>[getBruteLoss()]</a>
			FIRE:<font size='1'><a href='?_src_=vars;[HrefToken()];mobToDamage=[refid];adjustDamage=fire' id='fire'>[getFireLoss()]</a>
			TOXIN:<font size='1'><a href='?_src_=vars;[HrefToken()];mobToDamage=[refid];adjustDamage=toxin' id='toxin'>[getToxLoss()]</a>
			OXY:<font size='1'><a href='?_src_=vars;[HrefToken()];mobToDamage=[refid];adjustDamage=oxygen' id='oxygen'>[getOxyLoss()]</a>
			CLONE:<font size='1'><a href='?_src_=vars;[HrefToken()];mobToDamage=[refid];adjustDamage=clone' id='clone'>[getCloneLoss()]</a>
			BRAIN:<font size='1'><a href='?_src_=vars;[HrefToken()];mobToDamage=[refid];adjustDamage=brain' id='brain'>[getOrganLoss(ORGAN_SLOT_BRAIN)]</a>
			STAMINA:<font size='1'><a href='?_src_=vars;[HrefToken()];mobToDamage=[refid];adjustDamage=stamina' id='stamina'>[stamina.current]</a>
		</font>
	"}

/mob/living/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("", "---------")
	VV_DROPDOWN_OPTION(VV_HK_GIVE_SPEECH_IMPEDIMENT, "Impede Speech (Slurring, stuttering, etc)")

/mob/living/vv_do_topic(list/href_list)
	. = ..()

	if(href_list[VV_HK_GIVE_SPEECH_IMPEDIMENT])
		if(!check_rights(NONE))
			return
		admin_give_speech_impediment(usr)

/mob/living/proc/move_to_error_room()
	var/obj/effect/landmark/error/error_landmark = locate(/obj/effect/landmark/error) in GLOB.landmarks_list
	if(error_landmark)
		forceMove(error_landmark.loc)
	else
		forceMove(locate(4,4,1)) //Even if the landmark is missing, this should put them in the error room.
		//If you're here from seeing this error, I'm sorry. I'm so very sorry. The error landmark should be a sacred object that nobody has any business messing with, and someone did!
		//Consider seeing a therapist.
		var/ERROR_ERROR_LANDMARK_ERROR = "ERROR-ERROR: ERROR landmark missing!"
		log_mapping(ERROR_ERROR_LANDMARK_ERROR)
		CRASH(ERROR_ERROR_LANDMARK_ERROR)

/**
 * Changes the inclination angle of a mob, used by humans and others to differentiate between standing up and prone positions.
 *
 * In BYOND-angles 0 is NORTH, 90 is EAST, 180 is SOUTH and 270 is WEST.
 * This usually means that 0 is standing up, 90 and 270 are horizontal positions to right and left respectively, and 180 is upside-down.
 * Mobs that do now follow these conventions due to unusual sprites should require a special handling or redefinition of this proc, due to the density and layer changes.
 * The return of this proc is the previous value of the modified lying_angle if a change was successful (might include zero), or null if no change was made.
 */
/mob/living/proc/set_lying_angle(new_lying)
	if(new_lying == lying_angle)
		return
	. = lying_angle
	lying_angle = new_lying
	if(lying_angle != lying_prev)
		update_transform()
		lying_prev = lying_angle


/**
 * add_body_temperature_change Adds modifications to the body temperature
 *
 * This collects all body temperature changes that the mob is experiencing to the list body_temp_changes
 * the aggrogate result is used to derive the new body temperature for the mob
 *
 * arguments:
 * * key_name (str) The unique key for this change, if it already exist it will be overridden
 * * amount (int) The amount of change from the base body temperature
 */
/mob/living/proc/add_body_temperature_change(key_name, amount)
	body_temp_changes["[key_name]"] = amount

/**
 * remove_body_temperature_change Removes the modifications to the body temperature
 *
 * This removes the recorded change to body temperature from the body_temp_changes list
 *
 * arguments:
 * * key_name (str) The unique key for this change that will be removed
 */
/mob/living/proc/remove_body_temperature_change(key_name)
	body_temp_changes -= key_name

/**
 * get_body_temp_normal_change Returns the aggregate change to body temperature
 *
 * This aggregates all the changes in the body_temp_changes list and returns the result
 */
/mob/living/proc/get_body_temp_normal_change()
	var/total_change = 0
	if(body_temp_changes.len)
		for(var/change in body_temp_changes)
			total_change += body_temp_changes["[change]"]
	return total_change

/**
 * get_body_temp_normal Returns the mobs normal body temperature with any modifications applied
 *
 * This applies the result from proc/get_body_temp_normal_change() against the BODYTEMP_NORMAL and returns the result
 *
 * arguments:
 * * apply_change (optional) Default True This applies the changes to body temperature normal
 */
/mob/living/proc/get_body_temp_normal(apply_change=TRUE)
	if(!apply_change)
		return BODYTEMP_NORMAL
	return BODYTEMP_NORMAL + get_body_temp_normal_change()

///Returns the body temperature at which this mob will start taking heat damage.
/mob/living/proc/get_body_temp_heat_damage_limit()
	return BODYTEMP_HEAT_DAMAGE_LIMIT

///Returns the body temperature at which this mob will start taking cold damage.
/mob/living/proc/get_body_temp_cold_damage_limit()
	return BODYTEMP_COLD_DAMAGE_LIMIT


/mob/living/set_stat(new_stat)
	. = ..()
	if(isnull(.))
		return

	switch(.) //Previous stat.
		if(CONSCIOUS)
			if(stat >= UNCONSCIOUS)
				ADD_TRAIT(src, TRAIT_IMMOBILIZED, TRAIT_KNOCKEDOUT)
				ADD_TRAIT(src, TRAIT_HANDS_BLOCKED, STAT_TRAIT)
				ADD_TRAIT(src, TRAIT_INCAPACITATED, STAT_TRAIT)
				ADD_TRAIT(src, TRAIT_FLOORED, STAT_TRAIT)
				mob_mood?.update_mood_icon()

		if(UNCONSCIOUS)
			cure_blind(UNCONSCIOUS_TRAIT)
			REMOVE_TRAIT(src, TRAIT_DEAF, STAT_TRAIT)

		if(DEAD)
			remove_from_dead_mob_list()
			add_to_alive_mob_list()


	switch(stat) //Current stat.
		if(CONSCIOUS)
			if(. >= UNCONSCIOUS)
				REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, TRAIT_KNOCKEDOUT)
				mob_mood?.update_mood()
				blur_eyes(4)

			REMOVE_TRAIT(src, TRAIT_HANDS_BLOCKED, STAT_TRAIT)
			REMOVE_TRAIT(src, TRAIT_INCAPACITATED, STAT_TRAIT)
			REMOVE_TRAIT(src, TRAIT_FLOORED, STAT_TRAIT)
			REMOVE_TRAIT(src, TRAIT_NO_SPRINT, STAT_TRAIT)

		if(UNCONSCIOUS)
			become_blind(UNCONSCIOUS_TRAIT)
			ADD_TRAIT(src, TRAIT_DEAF, STAT_TRAIT)

		if(DEAD)
			remove_from_alive_mob_list()
			add_to_dead_mob_list()


/mob/living/carbon/set_stat(new_stat)
	. = ..()
	if(isnull(.))
		return

	switch(stat) //Current stat
		if(DEAD)
			bloodstream.end_metabolization(src)
			var/datum/reagents/R = get_ingested_reagents()
			if(R)
				R.end_metabolization(src)

/mob/living/do_set_blindness(blindness_level)
	. = ..()
	switch(blindness_level)
		if(BLIND_SLEEPING, BLIND_PHYSICAL)
			stats?.set_skill_modifier(-4, /datum/rpg_skill/skirmish, SKILL_SOURCE_BLINDNESS)
		else
			stats?.remove_skill_modifier(/datum/rpg_skill/skirmish, SKILL_SOURCE_BLINDNESS)

///Reports the event of the change in value of the buckled variable.
/mob/living/proc/set_buckled(new_buckled)
	if(new_buckled == buckled)
		return
	SEND_SIGNAL(src, COMSIG_LIVING_SET_BUCKLED, new_buckled)
	. = buckled
	buckled = new_buckled
	if(buckled)
		if(!HAS_TRAIT(buckled, TRAIT_NO_IMMOBILIZE))
			ADD_TRAIT(src, TRAIT_IMMOBILIZED, BUCKLED_TRAIT)
		switch(buckled.buckle_lying)
			if(NO_BUCKLE_LYING) // The buckle doesn't force a lying angle.
				REMOVE_TRAIT(src, TRAIT_FLOORED, BUCKLED_TRAIT)
			if(0) // Forcing to a standing position.
				REMOVE_TRAIT(src, TRAIT_FLOORED, BUCKLED_TRAIT)
				set_body_position(STANDING_UP)
				set_lying_angle(0)
			else // Forcing to a lying position.
				ADD_TRAIT(src, TRAIT_FLOORED, BUCKLED_TRAIT)
				set_body_position(LYING_DOWN)
				set_lying_angle(buckled.buckle_lying)
	else
		REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, BUCKLED_TRAIT)
		REMOVE_TRAIT(src, TRAIT_FLOORED, BUCKLED_TRAIT)
		if(.) // We unbuckled from something.
			var/atom/movable/old_buckled = .
			if(old_buckled.buckle_lying == 0 && (resting || HAS_TRAIT(src, TRAIT_FLOORED))) // The buckle forced us to stay up (like a chair)
				set_lying_down() // We want to rest or are otherwise floored, so let's drop on the ground.

/// Only defined for carbons who can wear masks and helmets, we just assume other mobs have visible faces
/mob/living/proc/is_face_visible()
	return TRUE


///Proc to modify the value of num_legs and hook behavior associated to this event.
/mob/living/proc/set_num_legs(new_value)
	if(num_legs == new_value)
		return
	. = num_legs
	num_legs = new_value


///Proc to modify the value of usable_legs and hook behavior associated to this event.
/mob/living/proc/set_usable_legs(new_value)
	if(usable_legs == new_value)
		return
	if(new_value < 0) // Sanity check
		stack_trace("[src] had set_usable_legs() called on them with a negative value!")
		new_value = 0

	. = usable_legs
	usable_legs = new_value

	if(new_value > .) // Gained leg usage.
		REMOVE_TRAIT(src, TRAIT_FLOORED, LACKING_LOCOMOTION_APPENDAGES_TRAIT)
		REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, LACKING_LOCOMOTION_APPENDAGES_TRAIT)
	else if(!(movement_type & (FLYING | FLOATING))) //Lost leg usage, not flying.
		if(!usable_legs)
			ADD_TRAIT(src, TRAIT_FLOORED, LACKING_LOCOMOTION_APPENDAGES_TRAIT)
			if(!usable_hands)
				ADD_TRAIT(src, TRAIT_IMMOBILIZED, LACKING_LOCOMOTION_APPENDAGES_TRAIT)

	if(usable_legs < default_num_legs)
		var/limbless_slowdown = (default_num_legs - usable_legs) * 3
		if(!usable_legs && usable_hands < default_num_hands)
			limbless_slowdown += (default_num_hands - usable_hands) * 3
		add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/limbless, slowdown = limbless_slowdown)
	else
		remove_movespeed_modifier(/datum/movespeed_modifier/limbless)


///Proc to modify the value of num_hands and hook behavior associated to this event.
/mob/living/proc/set_num_hands(new_value)
	if(num_hands == new_value)
		return
	. = num_hands
	num_hands = new_value


///Proc to modify the value of usable_hands and hook behavior associated to this event.
/mob/living/proc/set_usable_hands(new_value)
	if(usable_hands == new_value)
		return
	. = usable_hands
	usable_hands = new_value

	if(new_value > .) // Gained hand usage.
		REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, LACKING_LOCOMOTION_APPENDAGES_TRAIT)
	else if(!(movement_type & (FLYING | FLOATING)) && !usable_hands && !usable_legs) //Lost a hand, not flying, no hands left, no legs.
		ADD_TRAIT(src, TRAIT_IMMOBILIZED, LACKING_LOCOMOTION_APPENDAGES_TRAIT)


/// Whether or not this mob will escape from storages while being picked up/held.
/mob/living/proc/will_escape_storage()
	return FALSE

//Used specifically for the clown box suicide act
/mob/living/carbon/human/will_escape_storage()
	return TRUE

/// Sets the mob's hunger levels to a safe overall level. Useful for TRAIT_NOHUNGER species changes.
/mob/living/proc/set_safe_hunger_level()
	// Nutrition reset and alert clearing.
	set_nutrition(NUTRITION_LEVEL_FED)
	clear_alert(ALERT_NUTRITION)
	satiety = 0

	// Trait removal if obese
	if(HAS_TRAIT_FROM(src, TRAIT_FAT, OBESITY))
		if(overeatduration >= (200 SECONDS))
			to_chat(src, span_notice("Your transformation restores your body's natural fitness!"))

		REMOVE_TRAIT(src, TRAIT_FAT, OBESITY)
		remove_movespeed_modifier(/datum/movespeed_modifier/obesity)
		update_worn_undersuit()
		update_worn_oversuit()

	// Reset overeat duration.
	overeatduration = 0


/// Changes the value of the [living/body_position] variable.
/mob/living/proc/set_body_position(new_value)
	if(body_position == new_value)
		return
	if((new_value == LYING_DOWN) && !(mobility_flags & MOBILITY_LIEDOWN))
		return
	. = body_position
	body_position = new_value
	SEND_SIGNAL(src, COMSIG_LIVING_SET_BODY_POSITION)
	if(new_value == LYING_DOWN) // From standing to lying down.
		on_lying_down()
	else // From lying down to standing up.
		on_standing_up()

	UPDATE_OO_IF_PRESENT


/// Proc to append behavior to the condition of being floored. Called when the condition starts.
/mob/living/proc/on_floored_start()
	if(body_position == STANDING_UP) //force them on the ground
		set_lying_angle(pick(LYING_ANGLE_EAST, LYING_ANGLE_WEST))
		set_body_position(LYING_DOWN)
		on_fall()
		stats?.set_skill_modifier(-2, /datum/rpg_skill/skirmish, SKILL_SOURCE_FLOORED)

/// Proc to append behavior to the condition of being floored. Called when the condition ends.
/mob/living/proc/on_floored_end()
	if(!resting)
		get_up()
		stats?.remove_skill_modifier(/datum/rpg_skill/skirmish, SKILL_SOURCE_FLOORED)

/// Proc to append behavior to the condition of being handsblocked. Called when the condition starts.
/mob/living/proc/on_handsblocked_start()
	drop_all_held_items()
	ADD_TRAIT(src, TRAIT_UI_BLOCKED, TRAIT_HANDS_BLOCKED)
	ADD_TRAIT(src, TRAIT_PULL_BLOCKED, TRAIT_HANDS_BLOCKED)


/// Proc to append behavior to the condition of being handsblocked. Called when the condition ends.
/mob/living/proc/on_handsblocked_end()
	REMOVE_TRAIT(src, TRAIT_UI_BLOCKED, TRAIT_HANDS_BLOCKED)
	REMOVE_TRAIT(src, TRAIT_PULL_BLOCKED, TRAIT_HANDS_BLOCKED)


/// Returns the attack damage type of a living mob such as [BRUTE].
/mob/living/proc/get_attack_type()
	return BRUTE


/**
 * Apply a martial art move from src to target.
 *
 * This is used to process martial art attacks against nonhumans.
 * It is also used to process martial art attacks by nonhumans, even against humans
 * Human vs human attacks are handled in species code right now.
 */
/mob/living/proc/apply_martial_art(mob/living/target, modifiers, is_grab = FALSE)
	if(HAS_TRAIT(target, TRAIT_MARTIAL_ARTS_IMMUNE))
		return MARTIAL_ATTACK_INVALID
	var/datum/martial_art/style = mind?.martial_art
	if (!style)
		return MARTIAL_ATTACK_INVALID
	// will return boolean below since it's not invalid
	if (is_grab)
		return style.grab_act(src, target)
	if (LAZYACCESS(modifiers, RIGHT_CLICK))
		return style.disarm_act(src, target)
	if(combat_mode)
		if (HAS_TRAIT(src, TRAIT_PACIFISM))
			return FALSE
		return style.harm_act(src, target)
	return style.help_act(src, target)

/**
 * Returns an assoc list of assignments and minutes for updating a client's exp time in the databse.
 *
 * Arguments:
 * * minutes - The number of minutes to allocate to each valid role.
 */
/mob/living/proc/get_exp_list(minutes)
	var/list/exp_list = list()

	if(mind && mind.special_role && !(mind.datum_flags & DF_VAR_EDITED))
		exp_list[mind.special_role] = minutes

	if(mind.assigned_role.title in GLOB.exp_specialmap[EXP_TYPE_SPECIAL])
		exp_list[mind.assigned_role.title] = minutes

	return exp_list

/**
 * A proc triggered by callback when someone gets slammed by the tram and lands somewhere.
 *
 * This proc is used to force people to fall through things like lattice and unplated flooring at the expense of some
 * extra damage, so jokers can't use half a stack of iron rods to make getting hit by the tram immediately lethal.
 */
/mob/living/proc/tram_slam_land()
	if(!istype(loc, /turf/open/openspace) && !istype(loc, /turf/open/floor/plating))
		return

	if(istype(loc, /turf/open/floor/plating))
		var/turf/open/floor/smashed_plating = loc
		visible_message(span_danger("[src] is thrown violently into [smashed_plating], smashing through it and punching straight through!"),
				span_userdanger("You're thrown violently into [smashed_plating], smashing through it and punching straight through!"))
		apply_damage(rand(5,20), BRUTE, BODY_ZONE_CHEST)
		smashed_plating.ScrapeAway(1, CHANGETURF_INHERIT_AIR)

	for(var/obj/structure/lattice/lattice in loc)
		visible_message(span_danger("[src] is thrown violently into [lattice], smashing through it and punching straight through!"),
			span_userdanger("You're thrown violently into [lattice], smashing through it and punching straight through!"))
		apply_damage(rand(5,10), BRUTE, BODY_ZONE_CHEST)
		lattice.deconstruct(FALSE)

/**
 * Proc used by different station pets such as Ian and Poly so that some of their data can persist between rounds.
 * This base definition only contains a trait and comsig to stop memory from being (over)written.
 * Specific behavior is defined on subtypes that use it.
 */
/mob/living/proc/Write_Memory(dead, gibbed)
	SHOULD_CALL_PARENT(TRUE)
	if(HAS_TRAIT(src, TRAIT_DONT_WRITE_MEMORY)) //always prevent data from being written.
		return FALSE
	// for selective behaviors that may or may not prevent data from being written.
	if(SEND_SIGNAL(src, COMSIG_LIVING_WRITE_MEMORY, dead, gibbed) & COMPONENT_DONT_WRITE_MEMORY)
		return FALSE
	return TRUE

/// Admin only proc for giving a certain speech impediment to this mob
/mob/living/proc/admin_give_speech_impediment(mob/admin)
	if(!admin || !check_rights(NONE))
		return

	var/list/impediments = list()
	for(var/datum/status_effect/possible as anything in typesof(/datum/status_effect/speech))
		if(!initial(possible.id))
			continue

		impediments[initial(possible.id)] = possible

	var/chosen = tgui_input_list(admin, "What speech impediment?", "Impede Speech", impediments)
	if(!chosen || !ispath(impediments[chosen], /datum/status_effect/speech) || QDELETED(src) || !check_rights(NONE))
		return

	var/duration = tgui_input_number(admin, "How long should it last (in seconds)? Max is infinite duration.", "Duration", 0, INFINITY, 0 SECONDS)
	if(!isnum(duration) || duration <= 0 || QDELETED(src) || !check_rights(NONE))
		return

	adjust_timed_status_effect(duration SECONDS, impediments[chosen])

///Take away stamina from an attack being thrown.
/mob/living/proc/stamina_swing(cost as num)
	if((stamina.current - cost) > STAMINA_MAXIMUM_TO_SWING)
		stamina.adjust(-cost)

///Called by the stamina holder, passing the change in stamina to modify.
/mob/living/proc/pre_stamina_change(diff as num, forced)
	return diff

///Checks if the user is incapacitated or on cooldown.
/mob/living/proc/can_look_up()
	return !(incapacitated(IGNORE_RESTRAINTS))

/mob/living/verb/lookup()
	set name = "Look Upwards"
	set desc = "If you want to know what's above."
	set category = "IC"


	do_look_up()

/mob/living/verb/lookdown()
	set name = "Look Downwards"
	set desc = "If you want to know what's below."
	set category = "IC"

	do_look_down()

/mob/living/proc/do_look_up()
	if(z_eye)
		QDEL_NULL(z_eye)
		to_chat(src, span_notice("You stop looking up."))
		return

	if(!can_look_up())
		to_chat(src, span_notice("You can't look up right now."))
		return

	var/turf/above = GetAbove(src)

	if(above)
		to_chat(src, span_notice("You look up."))
		z_eye = new /mob/camera/z_eye(above, src)
		return

	to_chat(src, span_notice("You can see \the [above ? above : "ceiling"]."))

/mob/living/proc/do_look_down()
	if(z_eye)
		QDEL_NULL(z_eye)
		to_chat(src, span_notice("You stop looking down."))
		return

	if(!can_look_up())
		to_chat(src, span_notice("You can't look up right now."))
		return

	var/turf/T = get_turf(src)

	if(HasBelow(T.z))
		z_eye = new /mob/camera/z_eye(GetBelow(T), src)
		to_chat(src, span_notice("You look down."))
		return

	to_chat(src, span_notice("You can see \the [T ? T : "floor"]."))

/mob/living/proc/toggle_gunpoint_flag(permission)
	gunpoint_flags ^= permission

	var/message = "no longer permitted to "
	var/use_span = "warning"
	if (gunpoint_flags & permission)
		message = "now permitted to "
		use_span = "notice"

	switch(permission)
		if (TARGET_CAN_MOVE)
			message += "move"
		if (TARGET_CAN_INTERACT)
			message += "use items"
		if (TARGET_CAN_RADIO)
			message += "use a radio"
		if(TARGET_CAN_RUN)
			message += "run"
		else
			return

	to_chat(src, "<span class='[use_span]'>\The [gunpoint?.target || "victim"] is [message].</span>")
	if(gunpoint?.target)
		to_chat(gunpoint.target, "<span class='[use_span]'>You are [message].</span>")

/mob/living/proc/get_ingested_reagents()
	RETURN_TYPE(/datum/reagents)
	return reagents

/mob/living/proc/needs_organ(slot)
	return FALSE

/mob/proc/has_mouth()
	return FALSE

/mob/living/has_mouth()
	return TRUE

/mob/living/get_mouse_pointer_icon(check_sustained)
	if(istype(loc, /obj/vehicle/sealed))
		var/obj/vehicle/sealed/E = loc
		if(E.mouse_pointer)
			return E.mouse_pointer

	var/atom/A = SSmouse_entered.sustained_hovers[client]
	if(isnull(A))
		return

	if(istype(A, /atom/movable/screen/movable/action_button))
		var/atom/movable/screen/movable/action_button/action = A
		if(action.can_usr_use(src))
			return MOUSE_ICON_HOVERING_INTERACTABLE
		return

	if(A.is_mouseover_interactable && (mobility_flags & MOBILITY_USE) && can_interact_with(A))
		if(isitem(A))
			if(!isturf(loc) || (mobility_flags & MOBILITY_PICKUP))
				return MOUSE_ICON_HOVERING_INTERACTABLE
		else
			return MOUSE_ICON_HOVERING_INTERACTABLE


/mob/living/do_hurt_animation()
	if(stat > CONSCIOUS)
		return

	var/pixel_x = src.pixel_x
	var/pixel_y = src.pixel_y
	var/offset_x = pixel_x + pick(-3, -2, -1, 1, 2, 3)
	var/offset_y = pixel_y + pick(-3, -2, -1, 1, 2, 3)

	for(var/atom/movable/AM as anything in get_associated_mimics() + src)
		animate(AM, pixel_x = offset_x, pixel_y = offset_y, time = rand(2, 4))
		animate(pixel_x = pixel_x, pixel_y = pixel_y, time = 2)

/mob/living/proc/get_blood_print()
	return BLOOD_PRINT_PAWS

/mob/living/zap_act(power, zap_flags)
	..()
	var/shock_damage = (zap_flags & ZAP_MOB_DAMAGE) ? TESLA_POWER_TO_MOB_DAMAGE(power) : 0
	electrocute_act(shock_damage, 1, SHOCK_USE_AVG_SIEMENS | ((zap_flags & ZAP_MOB_STUN) ? NONE : SHOCK_NOSTUN))
	return power * 0.66

/// Proc for giving a mob a new 'friend', generally used for AI control and targeting. Returns false if already friends.
/mob/living/proc/befriend(mob/living/new_friend)
	SHOULD_CALL_PARENT(TRUE)
	var/friend_ref = REF(new_friend)
	if (faction.Find(friend_ref))
		return FALSE
	faction |= friend_ref
	ai_controller?.insert_blackboard_key_lazylist(BB_FRIENDS_LIST, new_friend)

	SEND_SIGNAL(src, COMSIG_LIVING_BEFRIENDED, new_friend)
	return TRUE

/// Proc for removing a friend you added with the proc 'befriend'. Returns true if you removed a friend.
/mob/living/proc/unfriend(mob/living/old_friend)
	SHOULD_CALL_PARENT(TRUE)
	var/friend_ref = REF(old_friend)
	if (!faction.Find(friend_ref))
		return FALSE
	faction -= friend_ref
	ai_controller?.remove_thing_from_blackboard_key(BB_FRIENDS_LIST, old_friend)

	SEND_SIGNAL(src, COMSIG_LIVING_UNFRIENDED, old_friend)
	return TRUE

/mob/living/set_nutrition(change)
	. = ..()
	mob_mood?.update_nutrition_moodlets()
