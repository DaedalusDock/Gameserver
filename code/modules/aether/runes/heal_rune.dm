/obj/effect/aether_rune/heal

/obj/effect/aether_rune/heal/succeed_invoke(mob/living/carbon/human/target_mob)
	visible_message(span_statsgood("Strands of [target_mob.p_s()] skin knit themselves together over [target_mob.p_their()] wounds."))
	target_mob.fully_heal()
	return ..()

/obj/effect/aether_rune/heal/fail_invoke(failure_reason, failure_source)
	if(failure_reason == RUNE_FAIL_GRACEFUL)
		return ..()

	var/mob/living/carbon/human/target_mob = blackboard[RUNE_BB_TARGET_MOB]
	var/list/blood_dna = target_mob.get_blood_dna_list()
	visible_message(span_statsbad("Untamed energy floods into [target_mob], and [target_mob.p_their()] body rapidly expands."))

	for(var/_dir in GLOB.alldirs)
		target_mob.spray_blood(_dir, 3)

	target_mob.gib()

	switch(failure_reason)
		if(RUNE_FAIL_TARGET_MOB_MOVED, RUNE_FAIL_TARGET_STOOD_UP)
			for(var/mob/living/carbon/human/H in touching_rune + blackboard[RUNE_BB_INVOKER])
				cover_in_blood(H, blood_dna)

		if(RUNE_FAIL_HELPER_REMOVED_HAND, RUNE_FAIL_INVOKER_INCAP)
			cover_in_blood(failure_source, blood_dna)

	return ..()

/obj/effect/aether_rune/heal/proc/cover_in_blood(mob/living/carbon/human/victim, list/blood_dna_list)
	victim.add_blood_DNA_to_items(blood_dna_list)
