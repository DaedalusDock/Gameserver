/datum/vampire_state/starving
	min_stage = THIRST_STAGE_STARVING

	regress_into_message = span_obviousnotice("You feel better, you must continue to feed.")
	progress_into_message = span_obviousnotice("You feel sickly. You must feed.")

/datum/vampire_state/starving/apply_effects(mob/living/carbon/human/host)
	. = ..()
	host.add_movespeed_modifier(/datum/movespeed_modifier/vampire_starving)
	host.mob_mood.add_mood_event("vampire", /datum/mood_event/vampire_starving)

/datum/vampire_state/starving/remove_effects(mob/living/carbon/human/host)
	. = ..()
	host.remove_movespeed_modifier(/datum/movespeed_modifier/vampire_starving)

/datum/vampire_state/starving/tick(delta_time, mob/living/carbon/human/host)
	. = ..()
	if(DT_PROB(0.8, delta_time))
		var/message = pick("Your throat feels dry.", "You lick your teeth.", "Your mouth salivates.", "The Thirst beckons.")
		to_chat(host, span_warning(message))
