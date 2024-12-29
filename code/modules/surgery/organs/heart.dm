/obj/item/organ/heart
	name = "heart"
	desc = "I feel bad for the heartless bastard who lost this."
	icon_state = "heart-on"
	base_icon_state = "heart"
	visual = FALSE
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_HEART

	decay_factor = 2.5 * STANDARD_ORGAN_DECAY //designed to fail around 6 minutes after death

	maxHealth = 45
	high_threshold = 0.66
	low_threshold = 0.15
	relative_size = 5
	external_damage_modifier = 0.7

	low_threshold_passed = "<span class='info'>Prickles of pain appear then die out from within your chest...</span>"
	high_threshold_passed = "<span class='warning'>Something inside your chest hurts, and the pain isn't subsiding. You notice yourself breathing far faster than before.</span>"
	now_fixed = "<span class='info'>Your heart begins to beat again.</span>"
	high_threshold_cleared = "<span class='info'>The pain in your chest has died down, and your breathing becomes more relaxed.</span>"

	// Heart attack code is in code/modules/mob/living/carbon/human/life.dm

	attack_verb_continuous = list("beats", "thumps")
	attack_verb_simple = list("beat", "thump")

	var/beat = BEAT_NONE//is this mob having a heatbeat sound played? if so, which?
	var/failed = FALSE //to prevent constantly running failing code

	var/blockage = FALSE
	/// How fast is our heart pumping blood
	var/pulse = PULSE_NORM
	/// Data containing information about a pump that just occured.
	var/list/external_pump

	/// A grace period applied upon being resuscitated, so bad RNG wont immediately stop the heart.
	COOLDOWN_DECLARE(arrhythmia_grace_period)

/obj/item/organ/heart/update_icon_state()
	icon_state = "[base_icon_state]-[pulse ? "on" : "off"]"
	return ..()

/obj/item/organ/heart/Insert(mob/living/carbon/reciever, special, drop_if_replaced)
	. = ..()
	if(!.)
		return

	owner.med_hud_set_health()
	update_movespeed()
	update_moodlet()

/obj/item/organ/heart/Remove(mob/living/carbon/heartless, special = 0)
	..()
	if(special)
		return

	addtimer(CALLBACK(src, PROC_REF(stop_if_unowned)), 2 MINUTES)
	heartless.med_hud_set_health()
	update_moodlet()

/obj/item/organ/heart/proc/Restart()
	if(organ_flags & ORGAN_DEAD)
		return FALSE

	pulse = PULSE_NORM
	update_appearance(UPDATE_ICON_STATE)
	update_movespeed()
	update_moodlet()

	owner?.med_hud_set_health()
	return TRUE

/obj/item/organ/heart/proc/Stop()
	pulse = PULSE_NONE
	update_appearance(UPDATE_ICON_STATE)
	update_movespeed()
	update_moodlet()

	owner?.med_hud_set_health()

/obj/item/organ/heart/proc/update_movespeed()
	if(isnull(owner))
		return

	if(is_working() || !owner.needs_organ(ORGAN_SLOT_HEART))
		owner.remove_movespeed_modifier(/datum/movespeed_modifier/asystole)
	else
		owner.add_movespeed_modifier(/datum/movespeed_modifier/asystole)

/// Add or remove the heartattack moodlet
/obj/item/organ/heart/proc/update_moodlet()
	if(!owner?.mob_mood)
		return

	if(is_working() || !owner.needs_organ(ORGAN_SLOT_HEART))
		owner.mob_mood?.clear_mood_event("heartattack")
	else
		owner.mob_mood?.add_mood_event("heartattack", /datum/mood_event/cardiac_arrest)

/obj/item/organ/heart/proc/stop_if_unowned()
	if(!owner)
		Stop()

/obj/item/organ/heart/OnEatFrom(eater, feeder)
	. = ..()
	Stop()

/obj/item/organ/heart/proc/is_working()
	if(organ_flags & ORGAN_DEAD)
		return FALSE
	return pulse > PULSE_NONE || (organ_flags & ORGAN_SYNTHETIC)

/obj/item/organ/heart/on_death(delta_time, times_fired)
	. = ..()
	if(pulse && owner)
		Stop()

/obj/item/organ/heart/on_life(delta_time, times_fired)
	. = ..()
	handle_pulse()
	// If the owner doesn't need a heart, we don't need to do anything with it.
	if(!owner.needs_organ(ORGAN_SLOT_HEART))
		return
	if(pulse)
		handle_heartbeat()
		if(pulse == PULSE_2FAST && prob(1))
			applyOrganDamage(0.25, updating_health = FALSE)
		if(pulse == PULSE_THREADY && prob(5))
			applyOrganDamage(0.35, updating_health = FALSE)

/obj/item/organ/heart/proc/handle_pulse()
	if(organ_flags & ORGAN_SYNTHETIC)
		if(pulse != PULSE_NONE)
			Stop()	//that's it, you're dead (or your metal heart is), nothing can influence your pulse
		return

	var/starting_pulse = pulse

	// pulse mod starts out as just the chemical effect amount
	var/pulse_mod = CHEM_EFFECT_MAGNITUDE(owner, CE_PULSE)
	var/is_stable = CHEM_EFFECT_MAGNITUDE(owner, CE_STABLE)

	var/can_heartattack = owner.can_heartattack()

	// If you have enough heart chemicals to be over 2, you're likely to take extra damage.
	if(pulse_mod > 2 && !is_stable)
		var/damage_chance = (pulse_mod - 2) ** 2
		if(prob(damage_chance))
			applyOrganDamage(0.5, updating_health = FALSE)
			. = TRUE

	// Now pulse mod is impacted by shock stage and other things too
	if(owner.shock_stage > SHOCK_TIER_2)
		pulse_mod++
	if(owner.shock_stage > SHOCK_TIER_5)
		pulse_mod++

	var/blood_oxygenation = owner.get_blood_oxygenation()
	if(blood_oxygenation < BLOOD_CIRC_BAD + 10) //brain wants us to get MOAR OXY
		pulse_mod++
	if(blood_oxygenation < BLOOD_CIRC_BAD) //MOAR
		pulse_mod++

	//If heart is stopped, it isn't going to restart itself randomly.
	if(pulse == PULSE_NONE)
		return

	else if(can_heartattack)//and if it's beating, let's see if it should
		// Cardiovascular shock, not enough liquid to pump
		var/blood_circulation = owner.get_blood_circulation()
		var/should_stop = prob(80) && (blood_circulation < BLOOD_CIRC_SURVIVE)
		if(should_stop)
			log_health(owner, "Heart stopped due to poor blood circulation: [blood_circulation]%")

		// Severe brain damage, unable to operate the heart.
		if(!should_stop)
			var/brainloss_stop_chance = max(0, owner.getBrainLoss() - owner.maxHealth * 0.75)
			should_stop = prob(brainloss_stop_chance)
			if(should_stop)
				log_health(owner, "Heart stopped due to brain damage: [brainloss_stop_chance]% chance. ")

		// Erratic heart patterns, usually caused by oxyloss.
		if(!should_stop && COOLDOWN_FINISHED(src, arrhythmia_grace_period))
			should_stop = (prob(5) && pulse == PULSE_THREADY)
			if(should_stop)
				log_health(owner, "Heart stopped due to cardiac arrhythmia. Oxyloss: [owner.getOxyLoss()]")

		// The heart has stopped due to going into traumatic or cardiovascular shock.
		if(should_stop)
			if(owner.stat != DEAD)
				to_chat(owner, span_alert("Your heart has stopped."))
			if(pulse != NONE)
				Stop()
				return

	// Pulse normally shouldn't go above PULSE_2FAST, unless extreme amounts of bad stuff in blood
	if (pulse_mod < 6)
		pulse = clamp(PULSE_NORM + pulse_mod, PULSE_SLOW, PULSE_2FAST)
	else
		pulse = clamp(PULSE_NORM + pulse_mod, PULSE_SLOW, PULSE_THREADY)

	// If fibrillation, then it can be PULSE_THREADY
	var/fibrillation = blood_oxygenation <= BLOOD_CIRC_SURVIVE || (prob(30) && owner.shock_stage > SHOCK_AMT_FOR_FIBRILLATION)

	if(pulse && fibrillation) //I SAID MOAR OXYGEN
		pulse = PULSE_THREADY

	// Stablising chemicals pull the heartbeat towards the center
	if(pulse != PULSE_NORM && is_stable)
		if(pulse > PULSE_NORM)
			pulse--
		else
			pulse++

	if(pulse != starting_pulse)
		owner.med_hud_set_health()

/obj/item/organ/heart/proc/handle_heartbeat()
	var/can_hear_heart = owner.shock_stage >= SHOCK_TIER_3 || get_step(owner, 0)?.is_below_sound_pressure() || owner.has_status_effect(owner.has_status_effect(/datum/status_effect/jitter))

	var/static/sound/slowbeat = sound('sound/health/slowbeat.ogg', repeat = TRUE)
	var/static/sound/fastbeat = sound('sound/health/fastbeat.ogg', repeat = TRUE)
	if(!can_hear_heart)
		owner.stop_sound_channel(CHANNEL_HEARTBEAT)
		beat = BEAT_NONE
		return

	if(pulse >= PULSE_2FAST && beat != BEAT_FAST)
		owner.playsound_local(owner, fastbeat, 55, 0, channel = CHANNEL_HEARTBEAT, pressure_affected = FALSE, use_reverb = FALSE)
		beat = BEAT_FAST
	else if(beat != BEAT_SLOW)
		owner.playsound_local(owner, slowbeat, 55, 0, channel = CHANNEL_HEARTBEAT, pressure_affected = FALSE, use_reverb = FALSE)
		beat = BEAT_SLOW

/obj/item/organ/heart/get_scan_results(tag)
	. = ..()
	if(pulse == PULSE_NONE)
		. += tag ? "<span style='font-weight: bold; color: [COLOR_MEDICAL_INTERNAL_DANGER]'>Asystole</span>" : "Asystole"

/datum/client_colour/cursed_heart_blood
	priority = 100 //it's an indicator you're dying, so it's very high priority
	colour = "red"

/obj/item/organ/heart/cybernetic
	name = "basic cybernetic heart"
	desc = "A basic electronic device designed to mimic the functions of an organic human heart."
	icon_state = "heart-c"
	organ_flags = ORGAN_SYNTHETIC

	var/dose_available = FALSE
	var/rid = /datum/reagent/medicine/epinephrine
	var/ramount = 10
	var/emp_vulnerability = 80 //Chance of permanent effects if emp-ed.

/obj/item/organ/heart/cybernetic/tier2
	name = "cybernetic heart"
	desc = "An electronic device designed to mimic the functions of an organic human heart. Also holds an emergency dose of epinephrine, used automatically after facing severe trauma."
	icon_state = "heart-c-u"
	maxHealth = 60
	dose_available = TRUE
	emp_vulnerability = 40

/obj/item/organ/heart/cybernetic/tier3
	name = "upgraded cybernetic heart"
	desc = "An electronic device designed to mimic the functions of an organic human heart. Also holds an emergency dose of epinephrine, used automatically after facing severe trauma. This upgraded model can regenerate its dose after use."
	icon_state = "heart-c-u2"
	maxHealth = 90
	dose_available = TRUE
	emp_vulnerability = 20

/obj/item/organ/heart/cybernetic/emp_act(severity)
	. = ..()

	// If the owner doesn't need a heart, we don't need to do anything with it.
	if(!owner.needs_organ(ORGAN_SLOT_HEART))
		return

	if(. & EMP_PROTECT_SELF)
		return
	if(!COOLDOWN_FINISHED(src, severe_cooldown)) //So we cant just spam emp to kill people.
		owner.set_timed_status_effect(20 SECONDS, /datum/status_effect/dizziness, only_if_higher = TRUE)
		owner.losebreath += 10
		COOLDOWN_START(src, severe_cooldown, 20 SECONDS)
	if(prob(emp_vulnerability/severity)) //Chance of permanent effects
		organ_flags |= ORGAN_SYNTHETIC_EMP //Starts organ faliure - gonna need replacing soon.
		Stop()
		owner.visible_message(span_danger("[owner] clutches at [owner.p_their()] chest as if [owner.p_their()] heart is stopping!"), \
						span_userdanger("You feel a terrible pain in your chest, as if your heart has stopped!"))
		addtimer(CALLBACK(src, PROC_REF(Restart)), 10 SECONDS)

/obj/item/organ/heart/cybernetic/on_life(delta_time, times_fired)
	. = ..()
	if(dose_available && owner.health <= owner.crit_threshold && !owner.reagents.has_reagent(rid))
		used_dose()

/obj/item/organ/heart/cybernetic/proc/used_dose()
	owner.reagents.add_reagent(rid, ramount)
	dose_available = FALSE

/obj/item/organ/heart/cybernetic/tier3/used_dose()
	. = ..()
	addtimer(VARSET_CALLBACK(src, dose_available, TRUE), 5 MINUTES)

/obj/item/organ/heart/freedom
	name = "heart of freedom"
	desc = "This heart pumps with the passion to give... something freedom."
	organ_flags = ORGAN_SYNTHETIC //the power of freedom prevents heart attacks
	/// The cooldown until the next time this heart can give the host an adrenaline boost.
	COOLDOWN_DECLARE(adrenaline_cooldown)

/obj/item/organ/heart/freedom/on_life(delta_time, times_fired)
	. = ..()
	if(owner.health < 5 && COOLDOWN_FINISHED(src, adrenaline_cooldown))
		COOLDOWN_START(src, adrenaline_cooldown, rand(25 SECONDS, 1 MINUTES))
		to_chat(owner, span_userdanger("You feel yourself dying, but you refuse to give up!"))
		owner.heal_overall_damage(15, 15, BODYTYPE_ORGANIC)
		if(owner.reagents.get_reagent_amount(/datum/reagent/medicine/epinephrine) < 20)
			owner.reagents.add_reagent(/datum/reagent/medicine/epinephrine, 10)

/obj/item/organ/heart/ethereal
	name = "crystal core"
	icon_state = "ethereal_heart" //Welp. At least it's more unique in functionaliy.
	visual = TRUE //This is used by the ethereal species for color
	desc = "A crystal-like organ that functions similarly to a heart for Ethereals. It can revive its owner."

	///Cooldown for the next time we can crystalize
	COOLDOWN_DECLARE(crystalize_cooldown)
	///Timer ID for when we will be crystalized, If not preparing this will be null.
	var/crystalize_timer_id
	///The current crystal the ethereal is in, if any
	var/obj/structure/ethereal_crystal/current_crystal
	///Damage taken during crystalization, resets after it ends
	var/crystalization_process_damage = 0
	///Color of the heart, is set by the species on gain
	var/ethereal_color = "#9c3030"

/obj/item/organ/heart/ethereal/Initialize(mapload)
	. = ..()
	add_atom_colour(ethereal_color, FIXED_COLOUR_PRIORITY)

/obj/item/organ/heart/ethereal/Insert(mob/living/carbon/owner, special = 0)
	. = ..()
	if(!.)
		return

	RegisterSignal(owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))
	RegisterSignal(owner, COMSIG_LIVING_POST_FULLY_HEAL, PROC_REF(on_owner_fully_heal))
	RegisterSignal(owner, COMSIG_PARENT_PREQDELETED, PROC_REF(owner_deleted))

/obj/item/organ/heart/ethereal/Remove(mob/living/carbon/owner, special = 0)
	UnregisterSignal(owner, list(COMSIG_MOB_STATCHANGE, COMSIG_LIVING_POST_FULLY_HEAL, COMSIG_PARENT_PREQDELETED))
	REMOVE_TRAIT(owner, TRAIT_CORPSELOCKED, SPECIES_TRAIT)
	stop_crystalization_process(owner)
	QDEL_NULL(current_crystal)
	return ..()

/obj/item/organ/heart/ethereal/update_overlays()
	. = ..()
	var/mutable_appearance/shine = mutable_appearance(icon, icon_state = "[icon_state]_shine")
	shine.appearance_flags = RESET_COLOR //No color on this, just pure white
	. += shine


/obj/item/organ/heart/ethereal/proc/on_owner_fully_heal(mob/living/carbon/healed, admin_heal)
	SIGNAL_HANDLER

	QDEL_NULL(current_crystal) //Kicks out the ethereal

///Ran when examined while crystalizing, gives info about the amount of time left
/obj/item/organ/heart/ethereal/proc/on_examine(mob/living/carbon/human/examined_human, mob/user, list/examine_list)
	SIGNAL_HANDLER

	if(!crystalize_timer_id)
		return

	switch(timeleft(crystalize_timer_id))
		if(0 to CRYSTALIZE_STAGE_ENGULFING)
			examine_list += span_warning("Crystals are almost engulfing [examined_human]! ")
		if(CRYSTALIZE_STAGE_ENGULFING to CRYSTALIZE_STAGE_ENCROACHING)
			examine_list += span_notice("Crystals are starting to cover [examined_human]. ")
		if(CRYSTALIZE_STAGE_SMALL to INFINITY)
			examine_list += span_notice("Some crystals are coming out of [examined_human]. ")

///On stat changes, if the victim is no longer dead but they're crystalizing, cancel it, if they become dead, start the crystalizing process if possible
/obj/item/organ/heart/ethereal/proc/on_stat_change(mob/living/victim, new_stat)
	SIGNAL_HANDLER

	if(new_stat != DEAD)
		if(crystalize_timer_id)
			stop_crystalization_process(victim)
		return


	if(QDELETED(victim) || victim.suiciding)
		return //lol rip

	if(!COOLDOWN_FINISHED(src, crystalize_cooldown))
		return //lol double rip

	if(HAS_TRAIT(victim, TRAIT_CANNOT_CRYSTALIZE))
		return // no reviving during mafia, or other inconvenient times.

	victim.visible_message(
		span_notice("Crystals start forming around [victim]."),
		span_nicegreen("Crystals start forming around your dead body."),
	)
	ADD_TRAIT(victim, TRAIT_CORPSELOCKED, SPECIES_TRAIT)

	crystalize_timer_id = addtimer(CALLBACK(src, PROC_REF(crystalize), victim), CRYSTALIZE_PRE_WAIT_TIME, TIMER_STOPPABLE)

	RegisterSignal(victim, COMSIG_HUMAN_DISARM_HIT, PROC_REF(reset_crystalizing))
	RegisterSignal(victim, COMSIG_PARENT_EXAMINE, PROC_REF(on_examine), override = TRUE)
	RegisterSignal(victim, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_take_damage))

///Ran when disarmed, prevents the ethereal from reviving
/obj/item/organ/heart/ethereal/proc/reset_crystalizing(mob/living/defender, mob/living/attacker, zone)
	SIGNAL_HANDLER
	defender.visible_message(
		span_notice("The crystals on [defender] are gently broken off."),
		span_notice("The crystals on your corpse are gently broken off, and will need some time to recover."),
	)
	deltimer(crystalize_timer_id)
	crystalize_timer_id = addtimer(CALLBACK(src, PROC_REF(crystalize), defender), CRYSTALIZE_DISARM_WAIT_TIME, TIMER_STOPPABLE) //Lets us restart the timer on disarm


///Actually spawns the crystal which puts the ethereal in it.
/obj/item/organ/heart/ethereal/proc/crystalize(mob/living/ethereal)

	var/location = ethereal.loc

	if(!COOLDOWN_FINISHED(src, crystalize_cooldown) || ethereal.stat != DEAD)
		return //Should probably not happen, but lets be safe.

	if(ismob(location) || isitem(location)) //Stops crystallization if they are eaten by a dragon, turned into a legion, consumed by his grace, etc.
		to_chat(ethereal, span_warning("You were unable to finish your crystallization, for obvious reasons."))
		stop_crystalization_process(ethereal, FALSE)
		return
	COOLDOWN_START(src, crystalize_cooldown, INFINITY) //Prevent cheeky double-healing until we get out, this is against stupid admemery
	current_crystal = new(get_turf(ethereal), src)
	stop_crystalization_process(ethereal, TRUE)

///Stop the crystalization process, unregistering any signals and resetting any variables.
/obj/item/organ/heart/ethereal/proc/stop_crystalization_process(mob/living/ethereal, succesful = FALSE)
	UnregisterSignal(ethereal, COMSIG_HUMAN_DISARM_HIT)
	UnregisterSignal(ethereal, COMSIG_PARENT_EXAMINE)
	UnregisterSignal(ethereal, COMSIG_MOB_APPLY_DAMAGE)

	crystalization_process_damage = 0 //Reset damage taken during crystalization

	if(!succesful)
		REMOVE_TRAIT(owner, TRAIT_CORPSELOCKED, SPECIES_TRAIT)
		QDEL_NULL(current_crystal)

	if(crystalize_timer_id)
		deltimer(crystalize_timer_id)
		crystalize_timer_id = null

/obj/item/organ/heart/ethereal/proc/owner_deleted(datum/source)
	SIGNAL_HANDLER

	stop_crystalization_process(owner)
	return

///Lets you stop the process with enough brute damage
/obj/item/organ/heart/ethereal/proc/on_take_damage(datum/source, damage, damagetype, def_zone)
	SIGNAL_HANDLER
	if(damagetype != BRUTE)
		return

	crystalization_process_damage += damage

	if(crystalization_process_damage < BRUTE_DAMAGE_REQUIRED_TO_STOP_CRYSTALIZATION)
		return

	var/mob/living/carbon/human/ethereal = source

	ethereal.visible_message(
		span_notice("The crystals on [ethereal] are completely shattered and stopped growing."),
		span_warning("The crystals on your body have completely broken."),
	)

	stop_crystalization_process(ethereal)

/obj/item/organ/heart/vox
	name = "vox heart"
	icon_state = "vox-heart-on"
	base_icon_state = "vox-heart"

/obj/structure/ethereal_crystal
	name = "ethereal resurrection crystal"
	desc = "It seems to contain the corpse of an ethereal mending its wounds."
	icon = 'icons/obj/ethereal_crystal.dmi'
	icon_state = "ethereal_crystal"
	damage_deflection = 0
	max_integrity = 100
	resistance_flags = FIRE_PROOF
	density = TRUE
	anchored = TRUE
	///The organ this crystal belongs to
	var/obj/item/organ/heart/ethereal/ethereal_heart
	///Timer for the healing process. Stops if destroyed.
	var/crystal_heal_timer
	///Is the crystal still being built? True by default, gets changed after a timer.
	var/being_built = TRUE

/obj/structure/ethereal_crystal/Initialize(mapload, obj/item/organ/heart/ethereal/ethereal_heart)
	. = ..()
	if(!ethereal_heart)
		stack_trace("Our crystal has no related heart")
		return INITIALIZE_HINT_QDEL
	src.ethereal_heart = ethereal_heart
	ethereal_heart.owner.visible_message(span_notice("The crystals fully encase [ethereal_heart.owner]!"))
	to_chat(ethereal_heart.owner, span_notice("You are encased in a huge crystal!"))
	playsound(get_turf(src), 'sound/effects/ethereal_crystalization.ogg', 50)
	ethereal_heart.owner.forceMove(src) //put that ethereal in
	add_atom_colour(ethereal_heart.ethereal_color, FIXED_COLOUR_PRIORITY)
	crystal_heal_timer = addtimer(CALLBACK(src, PROC_REF(heal_ethereal)), CRYSTALIZE_HEAL_TIME, TIMER_STOPPABLE)
	set_light(l_outer_range = 4, l_power = 10, l_color = ethereal_heart.ethereal_color)
	update_icon()
	flick("ethereal_crystal_forming", src)
	addtimer(CALLBACK(src, PROC_REF(start_crystalization)), 1 SECONDS)

/obj/structure/ethereal_crystal/proc/start_crystalization()
	being_built = FALSE
	update_icon()


/obj/structure/ethereal_crystal/atom_destruction(damage_flag)
	playsound(get_turf(ethereal_heart.owner), 'sound/effects/ethereal_revive_fail.ogg', 100)
	return ..()


/obj/structure/ethereal_crystal/Destroy()
	if(!ethereal_heart)
		return ..()
	ethereal_heart.current_crystal = null
	COOLDOWN_START(ethereal_heart, crystalize_cooldown, CRYSTALIZE_COOLDOWN_LENGTH)
	ethereal_heart.owner.forceMove(get_turf(src))
	REMOVE_TRAIT(ethereal_heart.owner, TRAIT_CORPSELOCKED, SPECIES_TRAIT)
	deltimer(crystal_heal_timer)
	visible_message(span_notice("The crystals shatters, causing [ethereal_heart.owner] to fall out"))
	return ..()

/obj/structure/ethereal_crystal/update_overlays()
	. = ..()
	if(!being_built)
		var/mutable_appearance/shine = mutable_appearance(icon, icon_state = "[icon_state]_shine")
		shine.appearance_flags = RESET_COLOR //No color on this, just pure white
		. += shine

/obj/structure/ethereal_crystal/proc/heal_ethereal()
	ethereal_heart.owner.revive(TRUE, FALSE)
	to_chat(ethereal_heart.owner, span_notice("You burst out of the crystal with vigour... </span><span class='userdanger'>But at a cost."))
	var/datum/brain_trauma/picked_trauma
	if(prob(10)) //10% chance for a severe trauma
		picked_trauma = pick(subtypesof(/datum/brain_trauma/severe))
	else
		picked_trauma = pick(subtypesof(/datum/brain_trauma/mild))
	ethereal_heart.owner.gain_trauma(picked_trauma, TRAUMA_RESILIENCE_ABSOLUTE)
	playsound(get_turf(ethereal_heart.owner), 'sound/effects/ethereal_revive.ogg', 100)
	qdel(src)
