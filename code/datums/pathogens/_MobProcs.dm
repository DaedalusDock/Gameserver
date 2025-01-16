
/// Returns TRUE if src is afflicted by a copy of the provided pathogen.
/mob/living/proc/has_pathogen(datum/pathogen/D)
	for(var/datum/pathogen/DD in diseases)
		if(D.IsSame(DD))
			return DD

	return null

/// Returns TRUE if src can contract the passed pathogen.
/// Note: This does not mean that the pathogen will be able to be applied to this mob.
/mob/living/proc/can_contract_pathogen(datum/pathogen/D)
	if(stat == DEAD && !D.process_dead)
		return FALSE

	if(HAS_TRAIT(src, TRAIT_VIRUSIMMUNE) && !D.bypasses_immunity)
		return FALSE

	if(D.get_id() in disease_resistances)
		return FALSE

	if(!(D.infectable_biotypes & mob_biotypes))
		return FALSE

	if(!D.is_viable_mobtype(type))
		return FALSE

	if(has_pathogen(D))
		return FALSE

	return TRUE

/mob/living/carbon/human/can_contract_pathogen(datum/pathogen/D)
	for(var/thing in D.required_organs)
		if(!((locate(thing) in bodyparts) || (locate(thing) in organs)))
			return FALSE
	return ..()

/// Attempt to contract a pathogen. Returns TRUE on infection.
/mob/living/proc/try_contract_pathogen(datum/pathogen/D, make_copy = TRUE, del_on_fail = FALSE)
	if(!can_contract_pathogen(D))
		if(del_on_fail)
			qdel(D)
		return FALSE

	if(!D.try_infect(src, make_copy))
		if(del_on_fail)
			qdel(D)
		return FALSE
	return TRUE

/// Attempt to contract a disease through touch. Returns TRUE on infection.
/mob/living/proc/try_contact_contract_pathogen(datum/pathogen/D)
	return try_contract_pathogen(D)

/mob/living/carbon/try_contact_contract_pathogen(datum/pathogen/D, target_zone)
	if(!can_contract_pathogen(D))
		return FALSE

	var/obj/item/clothing/Cl = null
	var/passed = TRUE

	var/head_ch = 80
	var/body_ch = 100
	var/hands_ch = 35
	var/feet_ch = 15

	if(prob(15/D.contraction_chance_modifier))
		return

	if(satiety>0 && prob(satiety/10)) // positive satiety makes it harder to contract the disease.
		return

	//Lefts and rights do not matter for arms and legs, they both run the same checks
	if(!target_zone)
		target_zone = pick(head_ch;BODY_ZONE_HEAD,body_ch;BODY_ZONE_CHEST,hands_ch;BODY_ZONE_L_ARM,feet_ch;BODY_ZONE_L_LEG)
	else
		target_zone = deprecise_zone(target_zone)



	if(ismonkey(src))
		var/mob/living/carbon/human/M = src
		switch(target_zone)
			if(BODY_ZONE_HEAD)
				if(M.wear_mask && isobj(M.wear_mask))
					Cl = M.wear_mask
					passed = prob((Cl.permeability_coefficient*100) - 1)

	else if(ishuman(src))
		var/mob/living/carbon/human/H = src

		switch(target_zone)
			if(BODY_ZONE_HEAD)
				if(isobj(H.head) && !istype(H.head, /obj/item/paper))
					Cl = H.head
					passed = prob((Cl.permeability_coefficient*100) - 1)
				if(passed && isobj(H.wear_mask))
					Cl = H.wear_mask
					passed = prob((Cl.permeability_coefficient*100) - 1)
				if(passed && isobj(H.wear_neck))
					Cl = H.wear_neck
					passed = prob((Cl.permeability_coefficient*100) - 1)
			if(BODY_ZONE_CHEST)
				if(isobj(H.wear_suit))
					Cl = H.wear_suit
					passed = prob((Cl.permeability_coefficient*100) - 1)
				if(passed && isobj(ITEM_SLOT_ICLOTHING))
					Cl = ITEM_SLOT_ICLOTHING
					passed = prob((Cl.permeability_coefficient*100) - 1)
			if(BODY_ZONE_L_ARM, BODY_ZONE_R_ARM)
				if(isobj(H.wear_suit) && H.wear_suit.body_parts_covered&HANDS)
					Cl = H.wear_suit
					passed = prob((Cl.permeability_coefficient*100) - 1)

				if(passed && isobj(H.gloves))
					Cl = H.gloves
					passed = prob((Cl.permeability_coefficient*100) - 1)
			if(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)
				if(isobj(H.wear_suit) && H.wear_suit.body_parts_covered&FEET)
					Cl = H.wear_suit
					passed = prob((Cl.permeability_coefficient*100) - 1)

				if(passed && isobj(H.shoes))
					Cl = H.shoes
					passed = prob((Cl.permeability_coefficient*100) - 1)

	if(passed)
		D.try_infect(src)

/// Attempt to contract a disease through the air. Returns TRUE on infection.
/mob/living/proc/try_airborne_contract_pathogen(datum/pathogen/D, even_if_not_airborne = FALSE)
	if(!(D.spread_flags & PATHOGEN_SPREAD_AIRBORNE) && !even_if_not_airborne)
		return FALSE

	if(prob((50*D.contraction_chance_modifier) - 1))
		return try_contract_pathogen(D)

/mob/living/carbon/try_airborne_contract_pathogen(datum/pathogen/D, even_if_not_airborne = FALSE)
	if(internal || external)
		return FALSE
	if(HAS_TRAIT(src, TRAIT_NOBREATH))
		return FALSE
	return ..()

/// Returns TRUE if this mob is able to spread airborne pathogens.
/mob/living/proc/can_spread_airborne_pathogens()
	return has_mouth() && !is_mouth_covered()

/mob/living/carbon/can_spread_airborne_pathogens()
	if(!has_mouth() || losebreath)
		return FALSE

	if(head && (head.flags_cover & HEADCOVERSMOUTH) && head.returnArmor().getRating(BIO) >= 25)
		return FALSE

	if(wear_mask && (wear_mask.flags_cover & MASKCOVERSMOUTH) && wear_mask.returnArmor().getRating(BIO) >= 25)
		return FALSE

	var/obj/item/bodypart/head/realhead = get_bodypart(BODY_ZONE_HEAD)
	if(realhead && realhead.returnArmor().getRating(BIO) >= 100)
		return FALSE

	return TRUE
