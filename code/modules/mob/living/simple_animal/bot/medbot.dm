//MEDBOT
//MEDBOT PATHFINDING
//MEDBOT ASSEMBLY
#define MEDBOT_PANIC_NONE 0
#define MEDBOT_PANIC_LOW 15
#define MEDBOT_PANIC_MED 35
#define MEDBOT_PANIC_HIGH 55
#define MEDBOT_PANIC_FUCK 70
#define MEDBOT_PANIC_ENDING 90
#define MEDBOT_PANIC_END 100

#define MEDBOT_NEW_PATIENTSPEAK_DELAY (30 SECONDS)
#define MEDBOT_PATIENTSPEAK_DELAY (20 SECONDS)
#define MEDBOT_FREAKOUT_DELAY (15 SECONDS)

/mob/living/simple_animal/bot/medbot
	name = "\improper Medibot"
	desc = "A little medical robot. He looks somewhat underwhelmed."
	icon = 'icons/mob/aibots.dmi'
	icon_state = "medibot0"
	base_icon_state = "medibot"
	density = FALSE
	anchored = FALSE
	health = 20
	maxHealth = 20
	pass_flags = PASSMOB | PASSFLAPS
	status_flags = (CANPUSH | CANSTUN)

	maints_access_required = list(ACCESS_ROBOTICS, ACCESS_MEDICAL)
	radio_key = /obj/item/encryptionkey/headset_med
	radio_channel = RADIO_CHANNEL_MEDICAL
	bot_type = MED_BOT
	data_hud_type = DATA_HUD_MEDICAL_ADVANCED
	hackables = "health processor circuits"
	path_image_color = "#DDDDFF"

	var/list/idle_phrases = list(
		MEDIBOT_VOICED_MASK_ON = 'sound/voice/medbot/radar.ogg',
		MEDIBOT_VOICED_ALWAYS_A_CATCH = 'sound/voice/medbot/catch.ogg',
		MEDIBOT_VOICED_PLASTIC_SURGEON = 'sound/voice/medbot/surgeon.ogg',
		MEDIBOT_VOICED_LIKE_FLIES = 'sound/voice/medbot/flies.ogg',
		MEDIBOT_VOICED_DELICIOUS = 'sound/voice/medbot/delicious.ogg',
		MEDIBOT_VOICED_SUFFER = 'sound/voice/medbot/why.ogg'
	)

	var/list/finish_healing_phrases = list(
		MEDIBOT_VOICED_ALL_PATCHED_UP = 'sound/voice/medbot/patchedup.ogg',
		MEDIBOT_VOICED_APPLE_A_DAY = 'sound/voice/medbot/apple.ogg',
		MEDIBOT_VOICED_FEEL_BETTER = 'sound/voice/medbot/feelbetter.ogg',
	)

	var/list/located_patient_phrases = list(
		MEDIBOT_VOICED_HOLD_ON = 'sound/voice/medbot/coming.ogg',
		MEDIBOT_VOICED_WANT_TO_HELP = 'sound/voice/medbot/help.ogg',
		MEDIBOT_VOICED_YOU_ARE_INJURED = 'sound/voice/medbot/injured.ogg'
	)

	var/list/patient_died_phrases = list(
		MEDIBOT_VOICED_STAY_WITH_ME = 'sound/voice/medbot/no.ogg',
		MEDIBOT_VOICED_LIVE = 'sound/voice/medbot/live.ogg',
		MEDIBOT_VOICED_NEVER_LOST = 'sound/voice/medbot/lost.ogg'
	)

	var/list/pre_tip_phrases = list(
		MEDIBOT_VOICED_WAIT = 'sound/voice/medbot/hey_wait.ogg',
		MEDIBOT_VOICED_DONT = 'sound/voice/medbot/please_dont.ogg',
		MEDIBOT_VOICED_TRUSTED_YOU = 'sound/voice/medbot/i_trusted_you.ogg',
		MEDIBOT_VOICED_NO_SAD = 'sound/voice/medbot/nooo.ogg',
		MEDIBOT_VOICED_OH_FUCK = 'sound/voice/medbot/oh_fuck.ogg',
	)

	var/list/untip_phrases = list(
		MEDIBOT_VOICED_FORGIVE = 'sound/voice/medbot/forgive.ogg',
		MEDIBOT_VOICED_THANKS = 'sound/voice/medbot/thank_you.ogg',
		MEDIBOT_VOICED_GOOD_PERSON = 'sound/voice/medbot/youre_good.ogg',
		MEDIBOT_VOICED_FUCK_YOU = 'sound/voice/medbot/fuck_you.ogg',
		MEDIBOT_VOICED_BEHAVIOUR_REPORTED = 'sound/voice/medbot/reported.ogg'
	)

	var/list/panic_phrases = list(
		MEDIBOT_VOICED_ASSISTANCE = 'sound/voice/medbot/i_require_asst.ogg',
		MEDIBOT_VOICED_PUT_BACK = 'sound/voice/medbot/please_put_me_back.ogg',
		MEDIBOT_VOICED_IM_SCARED = 'sound/voice/medbot/please_im_scared.ogg',
		MEDIBOT_VOICED_NEED_HELP = 'sound/voice/medbot/dont_like.ogg',
		MEDIBOT_VOICED_THIS_HURTS = 'sound/voice/medbot/pain_is_real.ogg',
		MEDIBOT_VOICED_THE_END = 'sound/voice/medbot/is_this_the_end.ogg',
		MEDIBOT_VOICED_NOOO = 'sound/voice/medbot/nooo.ogg'
	)

	/// Compiled list of all the phrase lists.
	var/list/all_phrases

	/// drop determining variable
	var/healthanalyzer = /obj/item/healthanalyzer
	/// drop determining variable
	var/medkit_type = /obj/item/storage/medkit
	///based off medkit_X skins in aibots.dmi for your selection; X goes here IE medskin_tox means skin var should be "tox"
	var/skin
	var/mob/living/carbon/patient
	var/mob/living/carbon/oldpatient
	var/last_found = 0
	/// How much healing do we do at a time?
	var/heal_amount = 2.5
	/// Start healing when they have this much damage in a category
	var/heal_threshold = 10
	/// What damage type does this bot support. Because the default is brute, if the medkit is brute-oriented there is a slight bonus to healing. set to "all" for it to heal any of the 4 base damage types
	var/damagetype_healer = BRUTE

	///Flags Medbots use to decide how they should be acting.
	var/medical_mode_flags = MEDBOT_DECLARE_CRIT | MEDBOT_SPEAK_MODE
//	Selections:  MEDBOT_DECLARE_CRIT | MEDBOT_STATIONARY_MODE | MEDBOT_SPEAK_MODE

	///Is the medbot currently tending wounds
	var/tending = FALSE
	///How panicked we are about being tipped over (why would you do this?)
	var/tipped_status = MEDBOT_PANIC_NONE
	///The name we got when we were tipped
	var/tipper_name

	///Last announced healing a person in critical condition
	COOLDOWN_DECLARE(last_patient_message)
	///Last announced trying to catch up to a new patient
	COOLDOWN_DECLARE(last_newpatient_speak)
	///Last time we were tipped/righted and said a voice line
	COOLDOWN_DECLARE(last_tipping_action_voice)

/mob/living/simple_animal/bot/medbot/autopatrol
	bot_mode_flags = BOT_MODE_ON | BOT_MODE_AUTOPATROL | BOT_MODE_REMOTE_ENABLED | BOT_MODE_PAI_CONTROLLABLE

/mob/living/simple_animal/bot/medbot/stationary
	medical_mode_flags = MEDBOT_DECLARE_CRIT | MEDBOT_STATIONARY_MODE | MEDBOT_SPEAK_MODE

/mob/living/simple_animal/bot/medbot/mysterious
	name = "\improper Mysterious Medibot"
	desc = "International Medibot of mystery."
	skin = "bezerk"
	damagetype_healer = "all"
	heal_amount = 10

/mob/living/simple_animal/bot/medbot/derelict
	name = "\improper Old Medibot"
	desc = "Looks like it hasn't been modified since the late 2080s."
	skin = "bezerk"
	damagetype_healer = "all"
	medical_mode_flags = MEDBOT_SPEAK_MODE
	heal_threshold = 0
	heal_amount = 5

/mob/living/simple_animal/bot/medbot/examine(mob/user)
	. = ..()
	if(tipped_status == MEDBOT_PANIC_NONE)
		return

	switch(tipped_status)
		if(MEDBOT_PANIC_NONE to MEDBOT_PANIC_LOW)
			. += "It appears to be tipped over, and is quietly waiting for someone to set it right."
		if(MEDBOT_PANIC_LOW to MEDBOT_PANIC_MED)
			. += "It is tipped over and requesting help."
		if(MEDBOT_PANIC_MED to MEDBOT_PANIC_HIGH)
			. += "They are tipped over and appear visibly distressed." // now we humanize the medbot as a they, not an it
		if(MEDBOT_PANIC_HIGH to MEDBOT_PANIC_FUCK)
			. += span_warning("They are tipped over and visibly panicking!")
		if(MEDBOT_PANIC_FUCK to INFINITY)
			. += span_warning("<b>They are freaking out from being tipped over!</b>")

/mob/living/simple_animal/bot/medbot/update_icon_state()
	. = ..()
	if(!(bot_mode_flags & BOT_MODE_ON))
		icon_state = "[base_icon_state]0"
		return
	if(HAS_TRAIT(src, TRAIT_INCAPACITATED))
		icon_state = "[base_icon_state]a"
		return
	if(mode == BOT_HEALING)
		icon_state = "[base_icon_state]s[get_bot_flag(medical_mode_flags, MEDBOT_STATIONARY_MODE)]"
		return
	icon_state = "[base_icon_state][get_bot_flag(medical_mode_flags, MEDBOT_STATIONARY_MODE) ? 2 : 1]" //Bot has yellow light to indicate stationary mode.

/mob/living/simple_animal/bot/medbot/update_overlays()
	. = ..()
	if(skin)
		. += "medskin_[skin]"

/mob/living/simple_animal/bot/medbot/Initialize(mapload, new_skin)
	. = ..()

	// Doing this hurts my soul, but simplebot access reworks are for another day.
	var/datum/id_trim/job/para_trim = SSid_access.trim_singletons_by_path[/datum/id_trim/job/paramedic]
	access_card.add_access(para_trim.access + para_trim.wildcard_access)
	prev_access = access_card.access.Copy()

	skin = new_skin
	update_appearance()

	all_phrases = idle_phrases + located_patient_phrases + finish_healing_phrases + patient_died_phrases + pre_tip_phrases + untip_phrases + panic_phrases

	AddComponent(/datum/component/tippable, \
		tip_time = 3 SECONDS, \
		untip_time = 3 SECONDS, \
		self_right_time = 3.5 MINUTES, \
		pre_tipped_callback = CALLBACK(src, PROC_REF(pre_tip_over)), \
		post_tipped_callback = CALLBACK(src, PROC_REF(after_tip_over)), \
		post_untipped_callback = CALLBACK(src, PROC_REF(after_righted)))

/mob/living/simple_animal/bot/medbot/bot_reset()
	..()
	patient = null
	oldpatient = null
	last_found = world.time
	update_appearance()

/mob/living/simple_animal/bot/medbot/proc/soft_reset() //Allows the medibot to still actively perform its medical duties without being completely halted as a hard reset does.
	path = list()
	patient = null
	mode = BOT_IDLE
	last_found = world.time
	update_appearance()

/mob/living/simple_animal/bot/medbot/attack_paw(mob/user, list/modifiers)
	return attack_hand(user, modifiers)

// Variables sent to TGUI
/mob/living/simple_animal/bot/medbot/ui_data(mob/user)
	var/list/data = ..()
	if(!(bot_cover_flags & BOT_COVER_LOCKED) || issilicon(user) || isAdminGhostAI(user))
		data["custom_controls"]["heal_threshold"] = heal_threshold
		data["custom_controls"]["speaker"] = medical_mode_flags & MEDBOT_SPEAK_MODE
		data["custom_controls"]["crit_alerts"] = medical_mode_flags & MEDBOT_DECLARE_CRIT
		data["custom_controls"]["stationary_mode"] = medical_mode_flags & MEDBOT_STATIONARY_MODE
	return data

// Actions received from TGUI
/mob/living/simple_animal/bot/medbot/ui_act(action, params)
	. = ..()
	if(. || (bot_cover_flags & BOT_COVER_LOCKED && !usr.has_unlimited_silicon_privilege))
		return

	switch(action)
		if("heal_threshold")
			var/adjust_num = round(text2num(params["threshold"]))
			heal_threshold = adjust_num
			if(heal_threshold < 5)
				heal_threshold = 5
			if(heal_threshold > 75)
				heal_threshold = 75
		if("speaker")
			medical_mode_flags ^= MEDBOT_SPEAK_MODE
		if("crit_alerts")
			medical_mode_flags ^= MEDBOT_DECLARE_CRIT
		if("stationary_mode")
			medical_mode_flags ^= MEDBOT_STATIONARY_MODE
			path = list()

	update_appearance()

/mob/living/simple_animal/bot/medbot/attackby(obj/item/W as obj, mob/user as mob, params)
	var/current_health = health
	..()
	if(health < current_health) //if medbot took some damage
		step_to(src, (get_step_away(src,user)))

/mob/living/simple_animal/bot/medbot/emag_act(mob/user)
	..()
	if(!(bot_cover_flags & BOT_COVER_EMAGGED))
		return
	medical_mode_flags &= ~MEDBOT_DECLARE_CRIT
	if(user)
		to_chat(user, span_notice("You short out [src]'s reagent synthesis circuits."))
	audible_message(span_danger("[src] buzzes oddly!"))
	z_flick("medibot_spark", src)
	playsound(src, SFX_SPARKS, 75, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	if(user)
		oldpatient = user

/mob/living/simple_animal/bot/medbot/process_scan(mob/living/carbon/human/H)
	if(H.stat == DEAD)
		return null
	if((H == oldpatient) && (world.time < last_found + 200))
		return null
	if(!assess_patient(H))
		return null

	last_found = world.time
	if(COOLDOWN_FINISHED(src, last_newpatient_speak))
		COOLDOWN_START(src, last_newpatient_speak, MEDBOT_NEW_PATIENTSPEAK_DELAY)
		medbot_phrase(pick(located_patient_phrases), H)
	return H

/*
 * Proc used in a callback for before this medibot is tipped by the tippable component.
 *
 * user - the mob who is tipping us over
 */
/mob/living/simple_animal/bot/medbot/proc/pre_tip_over(mob/user)
	if(!COOLDOWN_FINISHED(src, last_tipping_action_voice))
		return

	COOLDOWN_START(src, last_tipping_action_voice, MEDBOT_FREAKOUT_DELAY) // message for tipping happens when we start interacting, message for righting comes after finishing
	medbot_phrase(pick(pre_tip_phrases), user)

/*
 * Proc used in a callback for after this medibot is tipped by the tippable component.
 *
 * user - the mob who tipped us over
 */
/mob/living/simple_animal/bot/medbot/proc/after_tip_over(mob/user)
	mode = BOT_TIPPED
	tipper_name = user.name
	playsound(src, 'sound/machines/warning-buzzer.ogg', 50)

/*
 * Proc used in a callback for after this medibot is righted, either by themselves or by a mob, by the tippable component.
 *
 * user - the mob who righted us. Can be null.
 */
/mob/living/simple_animal/bot/medbot/proc/after_righted(mob/user)
	var/phrase
	if(user)
		if(user.name == tipper_name)
			phrase = MEDIBOT_VOICED_FORGIVE
		else
			phrase = pick(MEDIBOT_VOICED_THANKS, MEDIBOT_VOICED_GOOD_PERSON)
	else
		phrase = pick(MEDIBOT_VOICED_FUCK_YOU, MEDIBOT_VOICED_BEHAVIOUR_REPORTED)

	tipper_name = null

	if(COOLDOWN_FINISHED(src, last_tipping_action_voice))
		COOLDOWN_START(src, last_tipping_action_voice, MEDBOT_FREAKOUT_DELAY)
		medbot_phrase(phrase, user)

	tipped_status = MEDBOT_PANIC_NONE
	mode = BOT_IDLE

/// if someone tipped us over, check whether we should ask for help or just right ourselves eventually
/mob/living/simple_animal/bot/medbot/proc/handle_panic()
	tipped_status++
	var/phrase

	switch(tipped_status)
		if(MEDBOT_PANIC_LOW)
			phrase = MEDIBOT_VOICED_ASSISTANCE
		if(MEDBOT_PANIC_MED)
			phrase = MEDIBOT_VOICED_PUT_BACK
		if(MEDBOT_PANIC_HIGH)
			phrase = MEDIBOT_VOICED_IM_SCARED
		if(MEDBOT_PANIC_FUCK)
			phrase = pick(MEDIBOT_VOICED_NEED_HELP, MEDIBOT_VOICED_THIS_HURTS)
		if(MEDBOT_PANIC_ENDING)
			phrase = pick(MEDIBOT_VOICED_NOOO, MEDIBOT_VOICED_THE_END)
		if(MEDBOT_PANIC_END)
			speak("PSYCH ALERT: Crewmember [tipper_name] recorded displaying antisocial tendencies torturing bots in [get_area(src)]. Please schedule psych evaluation.", radio_channel)

	if(prob(tipped_status))
		do_jitter_animation(tipped_status * 0.1)

	if(phrase)
		medbot_phrase(phrase)

	else if(prob(tipped_status * 0.2))
		playsound(src, 'sound/machines/warning-buzzer.ogg', 30, extrarange=-2)

/mob/living/simple_animal/bot/medbot/handle_automated_action()
	. = ..()
	if(!.)
		return

	switch(mode)
		if(BOT_TIPPED)
			handle_panic()
			return
		if(BOT_HEALING)
			return

	if(IsStun() || IsParalyzed())
		oldpatient = patient
		patient = null
		mode = BOT_IDLE
		return

	if(frustration > 8)
		oldpatient = patient
		soft_reset()

	if(QDELETED(patient))
		if(medical_mode_flags & MEDBOT_SPEAK_MODE && prob(1))
			if(bot_cover_flags & BOT_COVER_EMAGGED && prob(30))
				var/list/i_need_scissors = list(
					'sound/voice/medbot/fuck_you.ogg',
					'sound/voice/medbot/turn_off.ogg',
					'sound/voice/medbot/im_different.ogg',
					'sound/voice/medbot/close.ogg',
					'sound/voice/medbot/shindemashou.ogg',
				)
				playsound(src, pick(i_need_scissors), 70)
			else
				medbot_phrase(pick(idle_phrases))

		var/scan_range = (medical_mode_flags & MEDBOT_STATIONARY_MODE ? 1 : DEFAULT_SCAN_RANGE) //If in stationary mode, scan range is limited to adjacent patients.
		patient = scan(list(/mob/living/carbon/human), oldpatient, scan_range)
		oldpatient = patient

	if(patient && (get_dist(src,patient) <= 1) && !tending) //Patient is next to us, begin treatment!
		if(mode != BOT_HEALING)
			mode = BOT_HEALING
			update_appearance()
			frustration = 0
			medicate_patient(patient)
		return

	//Patient has moved away from us!
	else if(patient && path.len && (get_dist(patient,path[path.len]) > 2))
		path = list()
		mode = BOT_IDLE
		last_found = world.time

	else if(medical_mode_flags & MEDBOT_STATIONARY_MODE && patient) //Since we cannot move in this mode, ignore the patient and wait for another.
		soft_reset()
		return

	if(patient && path.len == 0 && (get_dist(src,patient) > 1) && mode != BOT_MOVING)
		mode = BOT_MOVING
		path = jps_path_to(src, patient, max_distance=30, access = access_card?.GetAccess())
		if(!path.len) //try to get closer if you can't reach the patient directly
			path = jps_path_to(src, patient, max_distance=30, mintargetdist=1, access = access_card?.GetAccess())
			if(!path.len) //Do not chase a patient we cannot reach.
				soft_reset()

	if(path.len > 0 && patient)
		if(!bot_move(path[path.len]))
			oldpatient = patient
			soft_reset()
		return

	if(path.len > 8 && patient)
		frustration++

	if(bot_mode_flags & BOT_MODE_AUTOPATROL && !(medical_mode_flags & MEDBOT_STATIONARY_MODE) && !patient)
		switch(mode)
			if(BOT_IDLE, BOT_START_PATROL)
				start_patrol()
			if(BOT_PATROL)
				bot_patrol()

/mob/living/simple_animal/bot/medbot/proc/assess_patient(mob/living/carbon/C)
	. = FALSE
	//Time to see if they need medical help!
	if(medical_mode_flags & MEDBOT_STATIONARY_MODE && !Adjacent(C)) //YOU come to ME, BRO
		return FALSE

	if(C.stat == DEAD || (HAS_TRAIT(C, TRAIT_FAKEDEATH)))
		return FALSE //welp too late for them!

	if(!(loc == C.loc) && !(isturf(C.loc) && isturf(loc)))
		return FALSE

	if(C.suiciding)
		return FALSE //Kevorkian school of robotic medical assistants.

	if(bot_cover_flags & BOT_COVER_EMAGGED) //Everyone needs our medicine. (Our medicine is toxins)
		return TRUE

	if(HAS_TRAIT(C, TRAIT_MEDIBOTCOMINGTHROUGH) && !HAS_TRAIT_FROM(C, TRAIT_MEDIBOTCOMINGTHROUGH, tag)) //the early medbot gets the worm (or in this case the patient)
		return FALSE

	if(ishuman(C))
		var/mob/living/carbon/human/H = C
		if (H.wear_suit && H.head && istype(H.wear_suit, /obj/item/clothing) && istype(H.head, /obj/item/clothing))
			var/obj/item/clothing/CS = H.wear_suit
			var/obj/item/clothing/CH = H.head
			if (CS.clothing_flags & CH.clothing_flags & THICKMATERIAL)
				return FALSE // Skip over them if they have no exposed flesh.

	if(medical_mode_flags & MEDBOT_DECLARE_CRIT && C.health <= 0) //Critical condition! Call for help!
		declare(C)

	//They're injured enough for it!
	var/list/treat_me_for = list()
	if(C.getBruteLoss() > heal_threshold)
		treat_me_for += BRUTE

	if(C.getOxyLoss() > (5 + heal_threshold))
		treat_me_for += OXY

	if(C.getFireLoss() > heal_threshold)
		treat_me_for += BURN

	if(C.getToxLoss() > heal_threshold)
		treat_me_for += TOX

	if(damagetype_healer in treat_me_for)
		return TRUE
	if(damagetype_healer == "all" && treat_me_for.len)
		return TRUE

/mob/living/simple_animal/bot/medbot/UnarmedAttack(atom/A, proximity_flag, list/modifiers)
	if(HAS_TRAIT(src, TRAIT_HANDS_BLOCKED))
		return
	if(iscarbon(A) && !tending)
		var/mob/living/carbon/C = A
		patient = C
		mode = BOT_HEALING
		update_appearance()
		medicate_patient(C)
		update_appearance()
		return
	..()

/mob/living/simple_animal/bot/medbot/examinate(atom/A as mob|obj|turf in view())
	..()
	if(!is_blind())
		chemscan(src, A)

/mob/living/simple_animal/bot/medbot/proc/medicate_patient(mob/living/carbon/C)
	if(!(bot_mode_flags & BOT_MODE_ON))
		return

	if(!istype(C))
		oldpatient = patient
		soft_reset()
		return

	if(C.stat == DEAD || (HAS_TRAIT(C, TRAIT_FAKEDEATH)))
		medbot_phrase(pick(patient_died_phrases), C)
		oldpatient = patient
		soft_reset()
		return

	tending = TRUE
	while(tending)
		var/treatment_method
		var/list/potential_methods = list()

		if(C.getBruteLoss() > heal_threshold)
			potential_methods += BRUTE

		if(C.getFireLoss() > heal_threshold)
			potential_methods += BURN

		if(C.getOxyLoss() > (5 + heal_threshold))
			potential_methods += OXY

		if(C.getToxLoss() > heal_threshold)
			potential_methods += TOX

		for(var/i in potential_methods)
			if(i != damagetype_healer)
				continue
			treatment_method = i

		if(damagetype_healer == "all" && potential_methods.len)
			treatment_method = pick(potential_methods)

		if(!treatment_method && !(bot_cover_flags & BOT_COVER_EMAGGED)) //If they don't need any of that they're probably cured!
			if(C.maxHealth - C.get_organic_health() < heal_threshold)
				to_chat(src, span_notice("[C] is healthy! Your programming prevents you from tending the wounds of anyone without at least [heal_threshold] damage of any one type ([heal_threshold + 5] for oxygen damage.)"))

			var/message = pick(finish_healing_phrases)
			speak(message)
			playsound(src, finish_healing_phrases[message], 50)

			bot_reset()
			tending = FALSE

		else if(patient)
			C.visible_message(span_notice("[src] is trying to tend the wounds of [patient]."))

			if(do_after(src, patient, 2 SECONDS, DO_PUBLIC, display = image('icons/obj/syringe.dmi', "syringe_0"))) //Slightly faster than default tend wounds, but does less HPS
				if((get_dist(src, patient) <= 1) && (bot_mode_flags & BOT_MODE_ON) && assess_patient(patient))
					var/healies = heal_amount
					var/obj/item/storage/medkit/medkit = medkit_type
					if(treatment_method == BRUTE && initial(medkit.damagetype_healed) == BRUTE) //specialized brute gets a bit of bonus, as a snack.
						healies *= 1.1

					if(bot_cover_flags & BOT_COVER_EMAGGED)
						patient.reagents.add_reagent(/datum/reagent/toxin/chloralhydrate, 5)
						patient.apply_damage(healies * 1, treatment_method, spread_damage = TRUE)
						log_combat(src, patient, "pretended to tend wounds on", "internal tools", "([uppertext(treatment_method)]) (EMAGGED)")
					else
						patient.heal_damage_type(healies * -1, treatment_method) //don't need to check treatment_method since we know by this point that they were actually damaged.
						log_combat(src, patient, "tended the wounds of", "internal tools", "([uppertext(treatment_method)])")

					C.visible_message(span_notice("[src] tends the wounds of [patient]."))

					ADD_TRAIT(patient,TRAIT_MEDIBOTCOMINGTHROUGH,tag)
					addtimer(TRAIT_CALLBACK_REMOVE(patient, TRAIT_MEDIBOTCOMINGTHROUGH, tag), (30 SECONDS))
				else
					tending = FALSE
			else
				tending = FALSE

			update_appearance()
			if(!tending)
				visible_message("<span class='infoplain'>[src] places its tools back into itself.</span>")
				soft_reset()
		else
			tending = FALSE

/mob/living/simple_animal/bot/medbot/explode()
	var/atom/Tsec = drop_location()

	drop_part(medkit_type, Tsec)
	new /obj/item/assembly/prox_sensor(Tsec)
	drop_part(healthanalyzer, Tsec)

	if(bot_cover_flags & BOT_COVER_EMAGGED && prob(25))
		playsound(src, 'sound/voice/medbot/insult.ogg', 50)
	return ..()

/mob/living/simple_animal/bot/medbot/proc/declare(crit_patient)
	if(!COOLDOWN_FINISHED(src, last_patient_message))
		return
	COOLDOWN_START(src, last_patient_message, MEDBOT_PATIENTSPEAK_DELAY)

	var/area/location = get_area(crit_patient)
	speak("Medical emergency! [crit_patient] is in critical condition at [location]!", radio_channel)

/mob/living/simple_animal/bot/medbot/proc/medbot_phrase(phrase, mob/target)
	var/sound_path = all_phrases[phrase]
	if(target)
		phrase = replacetext(phrase, "%TARGET%", "[target]")

	speak(phrase)
	playsound(src, sound_path, 75, FALSE)

#undef MEDBOT_NEW_PATIENTSPEAK_DELAY
#undef MEDBOT_PATIENTSPEAK_DELAY
#undef MEDBOT_FREAKOUT_DELAY

#undef MEDBOT_PANIC_NONE
#undef MEDBOT_PANIC_LOW
#undef MEDBOT_PANIC_MED
#undef MEDBOT_PANIC_HIGH
#undef MEDBOT_PANIC_FUCK
#undef MEDBOT_PANIC_ENDING
#undef MEDBOT_PANIC_END
