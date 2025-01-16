/datum/vampire_state/hungry
	min_stage = THIRST_STAGE_HUNGRY

	regress_into_message = span_obviousnotice("You feel stronger, you must continue to feed.")
	progress_into_message = span_obviousnotice("The Thirst grows stronger, you must feed.")

	actions_to_grant = list(
		/datum/action/cooldown/blood_track,
	)

/datum/vampire_state/hungry/enter_state(mob/living/carbon/human/host)
	. = ..()
	host.mob_mood.add_mood_event("vampire", /datum/mood_event/vampire_hungry)

/datum/vampire_state/hungry/exit_state(mob/living/carbon/human/host)
	. = ..()
	host.mob_mood.clear_mood_event("vampire")
