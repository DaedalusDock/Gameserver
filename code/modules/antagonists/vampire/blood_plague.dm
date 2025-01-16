/datum/pathogen/blood_plague
	name = "Blood Plague"
	desc = "If left untreated the subject will suffer from lethargy, dizziness and periodic loss of conciousness."

	form = "Disease"
	agent = "Infected blood"

	max_stages = 3
	stage_prob = 0.5

	viable_mobtypes = list(/mob/living/carbon/human)
	severity = PATHOGEN_SEVERITY_BIOHAZARD

	pathogen_flags = NONE
	spread_flags = PATHOGEN_SPREAD_BLOOD
	visibility_flags = HIDDEN_SCANNER|HIDDEN_PANDEMIC

/datum/pathogen/blood_plague/on_process(delta_time, times_fired)
	if(affected_mob.stat != CONSCIOUS)
		return FALSE

	. = ..()
	if(!.)
		return

	switch(stage)
		if(1)
			if(DT_PROB(2.5, delta_time))
				to_chat(affected_mob, span_warning(pick("You feel thirsty.", "Your throat feels scratchy.")))

		if(2)
			if(DT_PROB(2.5, delta_time))
				affected_mob.apply_pain(1, BODY_ZONE_HEAD, "Your teeth ache.")

			else if(DT_PROB(2.5, delta_time))
				to_chat(affected_mob, span_warning(pick("You feel thirsty.", "Your throat feels scratchy.")))

			if(DT_PROB(1, delta_time) && affected_mob.stat == CONSCIOUS)
				affected_mob.Sleeping(10 SECONDS)
				to_chat(affected_mob, span_warning("You black out."))

		if(3)
			if(affected_mob.mind && !affected_mob.mind.has_antag_datum(/datum/antagonist/vampire))
				affected_mob.mind.add_antag_datum(/datum/antagonist/vampire)

/datum/pathogen/blood_plague/force_cure(add_resistance)
	affected_mob.mind.remove_antag_datum(/datum/antagonist/vampire)
	return ..()
