GLOBAL_LIST_EMPTY(dead_players_during_shift)
/mob/living/carbon/human/gib_animation()
	new /obj/effect/temp_visual/gib_animation(loc, dna.species.gib_anim)

/mob/living/carbon/human/dust_animation()
	new /obj/effect/temp_visual/dust_animation(loc, dna.species.dust_anim)

/mob/living/carbon/human/spawn_gibs(with_bodyparts)
	if(isipc(src))
		new /obj/effect/gibspawner/robot(drop_location(), src)
		return

	if(with_bodyparts)
		new /obj/effect/gibspawner/human(drop_location(), src, get_static_viruses())
	else
		new /obj/effect/gibspawner/human/bodypartless(drop_location(), src, get_static_viruses())

/mob/living/carbon/human/spawn_dust(just_ash = FALSE)
	if(just_ash)
		new /obj/effect/decal/cleanable/ash(loc)
	else
		new /obj/effect/decal/remains/human(loc)

/mob/living/carbon/human/death(gibbed)
	if(stat == DEAD)
		return

	log_health(src, "Died. BRUTE: [getBruteLoss()] | BURN: [getFireLoss()] | TOX: [getFireLoss()] | OXY:[getOxyLoss()] | BLOOD: [blood_volume] | BLOOD OXY: [get_blood_oxygenation()]% | PAIN:[getPain()]")

	stop_sound_channel(CHANNEL_HEARTBEAT)
	var/obj/item/organ/heart/H = getorganslot(ORGAN_SLOT_HEART)
	if(H)
		H.beat = BEAT_NONE

	var/obj/item/organ/brain/B = getorganslot(ORGAN_SLOT_BRAIN)
	if(B && !(B.organ_flags & ORGAN_DEAD))
		stack_trace("Human died without a dead brain.")
		B.set_organ_dead(TRUE)

	. = ..()

	if(client && !suiciding && !(client in GLOB.dead_players_during_shift))
		GLOB.dead_players_during_shift += client
		GLOB.deaths_during_shift++

	if(!QDELETED(dna)) //The gibbed param is bit redundant here since dna won't exist at this point if they got deleted.
		dna.species.spec_death(gibbed, src)

	if(SSticker.HasRoundStarted())
		SSblackbox.ReportDeath(src)
		log_message("has died (BRUTE: [src.getBruteLoss()], BURN: [src.getFireLoss()], TOX: [src.getToxLoss()], OXY: [src.getOxyLoss()], CLONE: [src.getCloneLoss()])", LOG_ATTACK)

	to_chat(src, span_warning("You have died. Barring complete bodyloss, you can in most cases be revived by other players. If you do not wish to be brought back, use the \"Do Not Resuscitate\" verb in the ghost tab."))

	for(var/mob/living/L in viewers(src, world.view) - src)
		if(L.is_blind() || L.stat != CONSCIOUS || !L.client)
			continue

		var/datum/roll_result/result = L.stat_roll(7, /datum/rpg_skill/willpower)
		switch(result.outcome)
			if(FAILURE, CRIT_FAILURE)
				if(L.apply_status_effect(/datum/status_effect/skill_mod/witness_death))
					to_chat(L, result.create_tooltip("For but a moment, there is nothing. Nothing but the gnawing realisation of what you have just witnessed."))

/mob/living/carbon/human/proc/makeSkeleton()
	ADD_TRAIT(src, TRAIT_DISFIGURED, TRAIT_GENERIC)
	set_species(/datum/species/skeleton)
	return TRUE


/mob/living/carbon/proc/Drain()
	become_husk(CHANGELING_DRAIN)
	ADD_TRAIT(src, TRAIT_BADDNA, CHANGELING_DRAIN)
	setBloodVolume(0)
	return TRUE

/mob/living/carbon/proc/makeUncloneable()
	ADD_TRAIT(src, TRAIT_BADDNA, MADE_UNCLONEABLE)
	setBloodVolume(0)
	return TRUE
