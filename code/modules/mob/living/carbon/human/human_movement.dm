/mob/living/carbon/human/get_movespeed_modifiers()
	var/list/considering = ..()
	if(HAS_TRAIT(src, TRAIT_IGNORESLOWDOWN))
		for(var/id in considering)
			var/datum/movespeed_modifier/M = considering[id]
			if(!(M.flags & IGNORE_NOSLOW) && M.slowdown > 0)
				considering -= id

	return considering

/mob/living/carbon/human/slip(knockdown_amount, obj/slipped_on, lube_flags, paralyze, force_drop = FALSE)
	if(HAS_TRAIT(src, TRAIT_NO_SLIP_ALL))
		return FALSE

	if(HAS_TRAIT(src, TRAIT_NO_SLIP_WATER) && !(lube_flags & GALOSHES_DONT_HELP))
		return FALSE

	if(HAS_TRAIT(src, TRAIT_NO_SLIP_ICE) && (lube_flags & SLIDE_ICE))
		return FALSE

	return ..()

/mob/living/carbon/human/mob_negates_gravity()
	if(dna.species.negates_gravity(src) || ..())
		return TRUE

/mob/living/carbon/human/Move(NewLoc, direct, glide_size_override, z_movement_flags)
	. = ..()
	if(shoes && body_position == STANDING_UP && loc == NewLoc && has_gravity(loc))
		SEND_SIGNAL(shoes, COMSIG_SHOES_STEP_ACTION)

/mob/living/carbon/human/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()

	if(!client || !isturf(old_loc) || !isturf(loc))
		return

	var/area/my_area = loc:loc
	if(LAZYACCESS(my_area.ckeys_that_have_been_here, ckey))
		return

	LAZYADDASSOC(my_area.ckeys_that_have_been_here, ckey, TRUE)

	if(prob(1))
		my_area.display_flavor(src)

/mob/living/carbon/human/Process_Spacemove(movement_dir = 0, continuous_move = FALSE)
	if(movement_type & FLYING || HAS_TRAIT(src, TRAIT_FREE_FLOAT_MOVEMENT))
		return TRUE
	return ..()
