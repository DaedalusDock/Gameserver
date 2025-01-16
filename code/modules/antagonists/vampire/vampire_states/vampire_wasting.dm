/datum/vampire_state/wasting
	min_stage = THIRST_STAGE_WASTING

	progress_into_message = span_obviousnotice("You feel as though you will not last long. If you do not feed, the Thirst will claim you soon enough.")

	actions_to_grant = list(
		/datum/action/cooldown/desperate_feed,
	)

/datum/vampire_state/wasting/apply_effects(mob/living/carbon/human/host)
	. = ..()
	host.apply_status_effect(/datum/status_effect/grouped/concussion, VAMPIRE_EFFECT)
	host.add_movespeed_modifier(/datum/movespeed_modifier/vampire_wasting)
	host.mob_mood.add_mood_event("vampire", /datum/mood_event/vampire_wasting)

/datum/vampire_state/wasting/remove_effects(mob/living/carbon/human/host)
	. = ..()
	host.remove_status_effect(/datum/status_effect/grouped/concussion, VAMPIRE_EFFECT)
	host.remove_movespeed_modifier(/datum/movespeed_modifier/vampire_wasting)
	host.mob_mood.clear_mood_event("vampire")

/datum/vampire_state/wasting/tick(delta_time, mob/living/carbon/human/host)
	. = ..()

	if(DT_PROB(33, delta_time))
		host.adjust_nutrition(-2)

	if(DT_PROB(1, delta_time))
		spawn(-1)
			host.emote("gasp")

	if(DT_PROB(2, delta_time) && !host.has_status_effect(/datum/status_effect/jitter))
		host.adjust_jitter(20 SECONDS)
		to_chat(host, span_warning("You feel your heart pounding."))
		return

	if(DT_PROB(1, delta_time) && !host.has_status_effect(/datum/status_effect/dizziness))
		host.adjust_dizzy(10 SECONDS)
		to_chat(host, span_warning("Your head spins."))
		return

	if(DT_PROB(1, delta_time) && !host.has_status_effect(/datum/status_effect/speech/stutter))
		host.adjust_stutter(15 SECONDS)
		to_chat(host, span_warning("You feel choked up."))
		return

	if(DT_PROB(1, delta_time) && !host.has_status_effect(/datum/status_effect/confusion))
		host.adjust_confusion(15 SECONDS)
		to_chat(host, span_warning("You are unable to think clearly"))
		return
