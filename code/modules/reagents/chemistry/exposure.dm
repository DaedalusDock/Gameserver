/// Applies this reagent to an [/atom]
/datum/reagent/proc/expose_atom(atom/exposed_atom, reac_volume, exposed_temperature)
	SHOULD_CALL_PARENT(TRUE)

	. = 0
	. |= SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_ATOM, exposed_atom, reac_volume, exposed_temperature)
	. |= SEND_SIGNAL(exposed_atom, COMSIG_ATOM_EXPOSE_REAGENT, src, reac_volume, exposed_temperature)

/// Applies this reagent to a [/mob/living]
/datum/reagent/proc/expose_mob(mob/living/exposed_mob, exposed_temperature, reac_volume, methods=TOUCH, show_message = TRUE, touch_protection = 0)
	SHOULD_CALL_PARENT(TRUE)

	. = SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_MOB, exposed_mob, reac_volume, exposed_temperature, methods, show_message, touch_protection)

	var/amount = round(reac_volume*clamp((1 - touch_protection), 0, 1), 0.1)
	if((methods & penetrates_skin)) //smoke, foam, spray
		if(amount >= 0.5)
			exposed_mob.reagents.add_reagent(type, amount) //This handles carbon bloodstreams

	else if(iscarbon(exposed_mob) && amount >= 0.1)
		var/mob/living/carbon/C = exposed_mob

		if(methods & VAPOR)
			// Incredibly unscientific but might be cool.
			//C.bloodstream.add_reagent(type, amount * 0.1)
			C.touching.add_reagent(type, amount * 0.4)

		else if(methods & INGEST)
			var/datum/reagents/R = C.get_ingested_reagents()
			R.add_reagent(type, amount)

		else if(methods & INJECT)
			C.bloodstream.add_reagent(type, amount)

		else
			touching.add_reagent(type, amount)

/// Applies this reagent to an [/obj]
/datum/reagent/proc/expose_obj(obj/exposed_obj, reac_volume, exposed_temperature)
	SHOULD_CALL_PARENT(TRUE)

	return SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_OBJ, exposed_obj, reac_volume, exposed_temperature)

/// Applies this reagent to a [/turf]
/datum/reagent/proc/expose_turf(turf/exposed_turf, reac_volume, exposed_temperature)
	SHOULD_CALL_PARENT(TRUE)

	return SEND_SIGNAL(src, COMSIG_REAGENT_EXPOSE_TURF, exposed_turf, reac_volume, exposed_temperature)
