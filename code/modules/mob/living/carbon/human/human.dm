/mob/living/carbon/human/Initialize(mapload)
	add_verb(src, /mob/living/proc/mob_sleep)
	add_verb(src, /mob/living/proc/toggle_resting)

	icon_state = "" //Remove the inherent human icon that is visible on the map editor. We're rendering ourselves limb by limb, having it still be there results in a bug where the basic human icon appears below as south in all directions and generally looks nasty.

	create_dna()
	dna.species.create_fresh_body(src)
	setup_human_dna()

	create_carbon_reagents() //Humans init this early as species require it
	set_species(dna.species.type)

	prepare_huds() //Prevents a nasty runtime on human init

	//initialise organs
	create_internal_organs() //most of it is done in set_species now, this is only for parent call
	physiology = new()

	. = ..()

	RegisterSignal(src, COMSIG_COMPONENT_CLEAN_FACE_ACT, PROC_REF(clean_face))
	AddComponent(/datum/component/personal_crafting)
	AddElement(/datum/element/footstep, FOOTSTEP_MOB_HUMAN, 1, -6, TRUE)
	AddComponent(/datum/component/bloodysoles/feet, BLOOD_PRINT_HUMAN)
	AddElement(/datum/element/ridable, /datum/component/riding/creature/human)
	AddElement(/datum/element/strippable, GLOB.strippable_human_items, TYPE_PROC_REF(/mob/living/carbon/human, should_strip))
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	become_area_sensitive()
	GLOB.human_list += src
	become_atmos_sensitive()

/mob/living/carbon/human/proc/setup_human_dna()
	//initialize dna. for spawned humans; overwritten by other code
	create_dna(src)
	randomize_human(src)
	dna.initialize_dna()

/mob/living/carbon/human/Destroy()
	QDEL_NULL(physiology)
	QDEL_LIST(bioware)
	GLOB.human_list -= src
	lose_atmos_sensitivity()
	return ..()

/mob/living/carbon/human/ZImpactDamage(turf/T, levels)
	if(stat != CONSCIOUS || levels > 1) // you're not The One
		return ..()
	var/obj/item/organ/wings/gliders = getorgan(/obj/item/organ/wings)
	if(HAS_TRAIT(src, TRAIT_FREERUNNING) || gliders?.can_soften_fall()) // the power of parkour or wings allows falling short distances unscathed
		visible_message(span_danger("[src] makes a hard landing on [T] but remains unharmed from the fall."), \
						span_userdanger("You brace for the fall. You make a hard landing on [T] but remain unharmed."))
		Knockdown(levels * 40)
		return
	return ..()

/mob/living/carbon/human/prepare_data_huds()
	//Update med hud images...
	..()
	//...sec hud images...
	sec_hud_set_ID()
	sec_hud_set_implants()
	sec_hud_set_security_status()
	//...and display them.
	add_to_all_human_data_huds()

/mob/living/carbon/human/get_status_tab_items()
	. = ..()
	. += "Combat mode: [combat_mode ? "On" : "Off"]"
	. += "Move Mode: [m_intent]"

	var/obj/item/tank/target_tank = internal || external
	if(target_tank)
		var/datum/gas_mixture/internal_air = target_tank.return_air()
		. += ""
		. += "Internal Atmosphere Info: [target_tank.name]"
		. += "Tank Pressure: [internal_air.returnPressure()]"
		. += "Distribution Pressure: [target_tank.distribute_pressure]"

	if(istype(wear_suit, /obj/item/clothing/suit/space))
		var/obj/item/clothing/suit/space/S = wear_suit
		. += "Thermal Regulator: [S.thermal_on ? "on" : "off"]"
		. += "Cell Charge: [S.cell ? "[round(S.cell.percent(), 0.1)]%" : "!invalid!"]"

	if(mind)
		var/datum/antagonist/changeling/changeling = mind.has_antag_datum(/datum/antagonist/changeling)
		if(changeling)
			. += ""
			. += "Chemical Storage: [changeling.chem_charges]/[changeling.total_chem_storage]"
			. += "Absorbed DNA: [changeling.absorbed_count]"

/mob/living/carbon/human/reset_perspective(atom/new_eye, force_reset = FALSE)
	if(dna?.species?.prevent_perspective_change && !force_reset) // This is in case a species needs to prevent perspective changes in certain cases, like Dullahans preventing perspective changes when they're looking through their head.
		update_fullscreen()
		return
	return ..()


/mob/living/carbon/human/Topic(href, href_list)
	if(href_list["item"]) //canUseTopic check for this is handled by mob/Topic()
		var/slot = text2num(href_list["item"])
		if(check_obscured_slots(TRUE) & slot)
			to_chat(usr, span_warning("You can't reach that! Something is covering it."))
			return

	if(href_list["show_death_stats"])
		if(stat != DEAD || !(usr == src || usr.mind?.current != src))
			return

		show_death_stats(usr)
		return

///////HUDs///////
	if(href_list["hud"])
		if(!ishuman(usr))
			return
		var/mob/living/carbon/human/H = usr
		var/perpname = get_face_name(get_id_name(""))
		if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD) && !HAS_TRAIT(H, TRAIT_MEDICAL_HUD))
			return

		var/datum/data/record/general_record = SSdatacore.get_record_by_name(perpname, DATACORE_RECORDS_STATION)

		if(href_list["photo_front"] || href_list["photo_side"])
			if(!general_record)
				return
			if(!H.canUseHUD())
				return
			if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD) && !HAS_TRAIT(H, TRAIT_MEDICAL_HUD))
				return
			var/obj/item/photo/P = null
			if(href_list["photo_front"])
				P = general_record.get_front_photo()
			else if(href_list["photo_side"])
				P = general_record.get_side_photo()
			if(P)
				P.show(H)
			return

		if(href_list["hud"] == "m")
			if(!HAS_TRAIT(H, TRAIT_MEDICAL_HUD))
				return
			if(href_list["evaluation"])
				if(!getBruteLoss() && !getFireLoss() && !getOxyLoss() && getToxLoss() < 20)
					to_chat(usr, "[span_notice("No external injuries detected.")]<br>")
					return
				var/span = "notice"
				var/status = ""
				if(getBruteLoss())
					to_chat(usr, "<b>Physical trauma analysis:</b>")
					for(var/X in bodyparts)
						var/obj/item/bodypart/BP = X
						var/brutedamage = BP.brute_dam
						if(brutedamage > 0)
							status = "received minor physical injuries."
							span = "notice"
						if(brutedamage > 20)
							status = "been seriously damaged."
							span = "danger"
						if(brutedamage > 40)
							status = "sustained major trauma!"
							span = "userdanger"
						if(brutedamage)
							to_chat(usr, "<span class='[span]'>[BP] appears to have [status]</span>")
				if(getFireLoss())
					to_chat(usr, "<b>Analysis of skin burns:</b>")
					for(var/X in bodyparts)
						var/obj/item/bodypart/BP = X
						var/burndamage = BP.burn_dam
						if(burndamage > 0)
							status = "signs of minor burns."
							span = "notice"
						if(burndamage > 20)
							status = "serious burns."
							span = "danger"
						if(burndamage > 40)
							status = "major burns!"
							span = "userdanger"
						if(burndamage)
							to_chat(usr, "<span class='[span]'>[BP] appears to have [status]</span>")
				if(getOxyLoss())
					to_chat(usr, span_danger("Patient has signs of suffocation, emergency treatment may be required!"))
				if(getToxLoss() > 20)
					to_chat(usr, span_danger("Gathered data is inconsistent with the analysis, possible cause: poisoning."))
			if(!H.wear_id) //You require access from here on out.
				to_chat(H, span_warning("ERROR: Invalid access"))
				return
			var/list/access = H.wear_id.GetAccess()
			if(!(ACCESS_MEDICAL in access))
				to_chat(H, span_warning("ERROR: Invalid access"))
				return
			if(href_list["p_stat"])
				var/health_status = input(usr, "Specify a new physical status for this person.", "Medical HUD", general_record.fields[DATACORE_PHYSICAL_HEALTH]) in list("Active", "Physically Unfit", "*Unconscious*", "*Deceased*", "Cancel")
				if(!general_record)
					return
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_MEDICAL_HUD))
					return
				if(health_status && health_status != "Cancel")
					general_record.fields[DATACORE_PHYSICAL_HEALTH] = health_status
				return
			if(href_list["m_stat"])
				var/health_status = input(usr, "Specify a new mental status for this person.", "Medical HUD", general_record.fields[DATACORE_MENTAL_HEALTH]) in list("Stable", "*Watch*", "*Unstable*", "*Insane*", "Cancel")
				if(!general_record)
					return
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_MEDICAL_HUD))
					return
				if(health_status && health_status != "Cancel")
					general_record.fields[DATACORE_MENTAL_HEALTH] = health_status
				return
			if(href_list["quirk"])
				var/quirkstring = get_quirk_string(TRUE, CAT_QUIRK_ALL)
				if(quirkstring)
					to_chat(usr,  "<span class='notice ml-1'>Detected physiological traits:</span>\n<span class='notice ml-2'>[quirkstring]</span>")
				else
					to_chat(usr,  "<span class='notice ml-1'>No physiological traits found.</span>")
			return //Medical HUD ends here.

		if(href_list["hud"] == "s")
			if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
				return
			if(usr.stat || usr == src) //|| !usr.canmove || usr.restrained()) Fluff: Sechuds have eye-tracking technology and sets 'arrest' to people that the wearer looks and blinks at.
				return   //Non-fluff: This allows sec to set people to arrest as they get disarmed or beaten
			// Checks the user has security clearence before allowing them to change arrest status via hud, comment out to enable all access
			var/allowed_access = null
			var/obj/item/clothing/glasses/hud/security/G = H.glasses
			if(istype(G) && (G.obj_flags & EMAGGED))
				allowed_access = "@%&ERROR_%$*"
			else //Implant and standard glasses check access
				if(H.wear_id)
					var/list/access = H.wear_id.GetAccess()
					if(ACCESS_SECURITY in access)
						allowed_access = H.get_authentification_name()

			if(!allowed_access)
				to_chat(H, span_warning("ERROR: Invalid access."))
				return

			if(!perpname)
				to_chat(H, span_warning("ERROR: Can not identify target."))
				return

			var/datum/data/record/security/security_record = SSdatacore.get_records(DATACORE_RECORDS_SECURITY)[perpname]

			if(!security_record)
				to_chat(usr, span_warning("ERROR: Unable to locate data core entry for target."))
				return

			if(href_list["status"])
				var/setcriminal = input(usr, "Specify a new criminal status for this person.", "Security HUD", security_record.fields[DATACORE_CRIMINAL_STATUS]) in list(CRIMINAL_NONE, CRIMINAL_WANTED, CRIMINAL_INCARCERATED, CRIMINAL_SUSPECT, CRIMINAL_PAROLE, CRIMINAL_DISCHARGED, "Cancel")
				if(setcriminal != "Cancel")
					if(!security_record)
						return
					if(!H.canUseHUD())
						return
					if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
						return
					investigate_log("[key_name(src)] has been set from [security_record.fields[DATACORE_CRIMINAL_STATUS]] to [setcriminal] by [key_name(usr)].", INVESTIGATE_RECORDS)
					security_record.set_criminal_status(setcriminal)
					sec_hud_set_security_status()
				return

			if(href_list["view"])
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
					return
				to_chat(usr, "<b>Name:</b> [security_record.fields[DATACORE_NAME]] <b>Criminal Status:</b> [security_record.fields[DATACORE_CRIMINAL_STATUS]]")
				for(var/datum/data/crime/c in security_record.fields[DATACORE_CRIMES])
					to_chat(usr, "<b>Crime:</b> [c.crimeName]")
					if (c.crimeDetails)
						to_chat(usr, "<b>Details:</b> [c.crimeDetails]")
					else
						to_chat(usr, "<b>Details:</b> <A href='?src=[REF(src)];hud=s;add_details=1;cdataid=[c.dataId]'>\[Add details]</A>")
					to_chat(usr, "Added by [c.author] at [c.time]")
					to_chat(usr, "----------")
				to_chat(usr, "<b>Notes:</b> [security_record.fields[DATACORE_NOTES]]")
				return

			if(href_list["add_citation"])
				var/maxFine = CONFIG_GET(number/maxfine)
				var/t1 = tgui_input_text(usr, "Citation crime", "Security HUD")
				var/fine = tgui_input_number(usr, "Citation fine", "Security HUD", 50, maxFine, 5)
				if(!fine)
					return
				if(!security_record || !t1 || !allowed_access)
					return
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
					return

				var/datum/data/crime/crime = SSdatacore.new_crime_entry(t1, "", allowed_access, stationtime2text(), fine)
				var/obj/machinery/announcement_system/announcer = pick(GLOB.announcement_systems)
				if(announcer)
					announcer.notify_citation(security_record.fields[DATACORE_NAME], t1, fine)
				// for (var/obj/item/modular_computer/tablet in GLOB.TabletMessengers)
				// 	if(tablet.saved_identification == R.fields[DATACORE_NAME])
				// 		var/message = "You have been fined [fine] credits for '[t1]'. Fines may be paid at security."
				// 		var/datum/signal/subspace/messaging/tablet_msg/signal = new(src, list(
				// 			"name" = "Security Citation",
				// 			"job" = "Citation Server",
				// 			"message" = message,
				// 			"targets" = list(tablet),
				// 			"automated" = TRUE
				// 		))
				// 		signal.send_to_receivers()
				// 		usr.log_message("(PDA: Citation Server) sent \"[message]\" to [signal.format_target()]", LOG_PDA)
				security_record.add_citation(crime)
				investigate_log("New Citation: <strong>[t1]</strong> Fine: [fine] | Added to [security_record.fields[DATACORE_NAME]] by [key_name(usr)]", INVESTIGATE_RECORDS)
				SSblackbox.ReportCitation(crime.dataId, usr.ckey, usr.real_name, security_record.fields[DATACORE_NAME], t1, fine)
				return

			if(href_list["add_crime"])
				var/t1 = tgui_input_text(usr, "Crime name", "Security HUD")
				if(!security_record || !t1 || !allowed_access)
					return
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
					return

				var/crime = SSdatacore.new_crime_entry(t1, null, allowed_access, stationtime2text())
				security_record.add_crime(crime)
				investigate_log("New Crime: <strong>[t1]</strong> | Added to [security_record.fields[DATACORE_NAME]] by [key_name(usr)]", INVESTIGATE_RECORDS)
				to_chat(usr, span_notice("Successfully added a crime."))
				return

			if(href_list["add_details"])
				var/t1 = tgui_input_text(usr, "Crime details", "Security Records", multiline = TRUE)
				if(!security_record || !t1 || !allowed_access)
					return
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
					return

				if(href_list["cdataid"])
					security_record.add_crime_details(href_list["cdataid"], t1)
					investigate_log("New Crime details: [t1] | Added to [security_record.fields[DATACORE_NAME]] by [key_name(usr)]", INVESTIGATE_RECORDS)
					to_chat(usr, span_notice("Successfully added details."))
				return

			if(href_list["view_comment"])
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
					return
				to_chat(usr, "<b>Comments/Log:</b>")
				var/counter = 1
				while(security_record.fields["com_[counter]"])
					to_chat(usr, security_record.fields["com_[counter]"])
					to_chat(usr, "----------")
					counter++
				return

			if(href_list["add_comment"])
				var/t1 = tgui_input_text(usr, "Add a comment", "Security Records", multiline = TRUE)
				if (!security_record || !t1 || !allowed_access)
					return
				if(!H.canUseHUD())
					return
				if(!HAS_TRAIT(H, TRAIT_SECURITY_HUD))
					return
				var/counter = 1
				while(security_record.fields["com_[counter]"])
					counter++
				security_record.fields["com_[counter]"] = "Made by [allowed_access] on [stationtime2text()] [time2text(world.realtime, "MMM DD")], [CURRENT_STATION_YEAR]<BR>[t1]"
				to_chat(usr, span_notice("Successfully added comment."))
				return

	..() //end of this massive fucking chain. TODO: make the hud chain not spooky. - Yeah, great job doing that.

//called when something steps onto a human
/mob/living/carbon/human/proc/on_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER
	if(AM == src)
		return
	spreadFire(AM)

/mob/living/carbon/human/proc/canUseHUD()
	return (mobility_flags & MOBILITY_USE)

/mob/living/carbon/human/can_inject(mob/user, target_zone, injection_flags)
	. = TRUE // Default to returning true.
	if(user && !target_zone)
		target_zone = user.zone_selected
	// we may choose to ignore species trait pierce immunity in case we still want to check skellies for thick clothing without insta failing them (wounds)
	if(injection_flags & INJECT_CHECK_IGNORE_SPECIES)
		if(HAS_TRAIT_NOT_FROM(src, TRAIT_PIERCEIMMUNE, SPECIES_TRAIT))
			. = FALSE
	else if(HAS_TRAIT(src, TRAIT_PIERCEIMMUNE))
		. = FALSE
	var/obj/item/bodypart/the_part = get_bodypart(target_zone) || get_bodypart(BODY_ZONE_CHEST)
	if(!IS_ORGANIC_LIMB(the_part))
		return FALSE
	// Loop through the clothing covering this bodypart and see if there's any thiccmaterials
	if(!(injection_flags & INJECT_CHECK_PENETRATE_THICK))
		for(var/obj/item/clothing/iter_clothing in clothingonpart(the_part))
			if(iter_clothing.clothing_flags & THICKMATERIAL)
				. = FALSE
				break

/mob/living/carbon/human/try_inject(mob/user, target_zone, injection_flags)
	. = ..()
	if(!. && (injection_flags & INJECT_TRY_SHOW_ERROR_MESSAGE) && user)
		var/obj/item/bodypart/the_part = get_bodypart(target_zone || deprecise_zone(user.zone_selected))
		to_chat(user, span_alert("There is no exposed flesh or thin material on [p_their()] [the_part.name]."))

/mob/living/carbon/human/assess_threat(judgement_criteria, lasercolor = "", datum/callback/weaponcheck=null)
	if(judgement_criteria & JUDGE_EMAGGED)
		return 10 //Everyone is a criminal!

	var/threatcount = 0

	//Lasertag bullshit
	if(lasercolor)
		if(lasercolor == "b")//Lasertag turrets target the opposing team, how great is that? -Sieve
			if(istype(wear_suit, /obj/item/clothing/suit/redtag))
				threatcount += 4
			if(is_holding_item_of_type(/obj/item/gun/energy/laser/redtag))
				threatcount += 4
			if(istype(belt, /obj/item/gun/energy/laser/redtag))
				threatcount += 2

		if(lasercolor == "r")
			if(istype(wear_suit, /obj/item/clothing/suit/bluetag))
				threatcount += 4
			if(is_holding_item_of_type(/obj/item/gun/energy/laser/bluetag))
				threatcount += 4
			if(istype(belt, /obj/item/gun/energy/laser/bluetag))
				threatcount += 2

		return threatcount

	//Check for ID
	var/obj/item/card/id/idcard = get_idcard(FALSE)
	if( (judgement_criteria & JUDGE_IDCHECK) && !idcard && name=="Unknown")
		threatcount += 4

	//Check for weapons
	if( (judgement_criteria & JUDGE_WEAPONCHECK) && weaponcheck)
		if(!idcard || !(ACCESS_WEAPONS in idcard.access))
			for(var/obj/item/I in held_items) //if they're holding a gun
				if(weaponcheck.Invoke(I))
					threatcount += 4
			if(weaponcheck.Invoke(belt) || weaponcheck.Invoke(back)) //if a weapon is present in the belt or back slot
				threatcount += 2 //not enough to trigger look_for_perp() on it's own unless they also have criminal status.

	//Check for arrest warrant
	if(judgement_criteria & JUDGE_RECORDCHECK)
		var/perpname = get_face_name(get_id_name())
		var/datum/data/record/security/R = SSdatacore.get_record_by_name(perpname, DATACORE_RECORDS_SECURITY)
		if(R?.fields[DATACORE_CRIMINAL_STATUS])
			switch(R.fields[DATACORE_CRIMINAL_STATUS])
				if(CRIMINAL_WANTED)
					threatcount += 5
				if(CRIMINAL_INCARCERATED)
					threatcount += 2
				if(CRIMINAL_SUSPECT)
					threatcount += 2
				if(CRIMINAL_PAROLE)
					threatcount += 2

	//Check for dresscode violations
	if(istype(head, /obj/item/clothing/head/wizard))
		threatcount += 2

	//Check for nonhuman scum
	if(dna && dna.species.id && dna.species.id != SPECIES_HUMAN)
		threatcount += 1

	//mindshield implants imply trustworthyness
	if(HAS_TRAIT(src, TRAIT_MINDSHIELD))
		threatcount -= 1

	return threatcount


//Used for new human mobs created by cloning/goleming/podding
/mob/living/carbon/human/proc/set_cloned_appearance()
	if(gender == MALE)
		facial_hairstyle = "Full Beard"
	else
		facial_hairstyle = "Shaved"
	hairstyle = pick("Bedhead", "Bedhead 2", "Bedhead 3")
	underwear = "Nude"
	update_body(is_creating = TRUE)

/mob/living/carbon/human/singularity_pull(S, current_size)
	..()
	if(current_size >= STAGE_THREE)
		for(var/obj/item/hand in held_items)
			if(prob(current_size * 5) && hand.w_class >= ((11-current_size)/2)  && dropItemToGround(hand))
				step_towards(hand, src)
				to_chat(src, span_warning("\The [S] pulls \the [hand] from your grip!"))

#define CPR_PANIC_SPEED (1 SECONDS)

/// Performs CPR on the target after a delay.
/mob/living/carbon/human/proc/do_cpr(mob/living/carbon/target)
	if(target == src)
		return

	CHECK_DNA_AND_SPECIES(target)

	if (DOING_INTERACTION_WITH_TARGET(src,target))
		return

	if(!can_perform_cpr(target, silent = FALSE))
		return

	visible_message(
		span_notice("[src] places their hands on [target.name]'s chest!"),
		span_notice("You try to perform CPR on [target.name]... Hold still!")
	)

	var/image/cpr_image = image('goon/icons/actions.dmi', "cpr", pixel_y = 40)
	cpr_image.appearance_flags = APPEARANCE_UI | KEEP_APART
	cpr_image.plane = ABOVE_HUD_PLANE
	add_overlay(cpr_image)

	while (TRUE)
		if (!do_after(src, target, 3 SECONDS, DO_PUBLIC, extra_checks = CALLBACK(src, PROC_REF(can_perform_cpr), target)))
			break

		visible_message(
			span_notice("[src] pushes down on [target.name]'s chest!"),
		)

		var/datum/roll_result/result = stat_roll(6, /datum/rpg_skill/skirmish)
		switch(result.outcome)
			if(CRIT_SUCCESS)
				if(target.stat != DEAD && target.undergoing_cardiac_arrest() && target.resuscitate())
					to_chat(src, result.create_tooltip("You feel the pulse of life return to [target.name] beneath your palms."))

			if(SUCCESS)
				var/obj/item/organ/heart/heart = target.getorganslot(ORGAN_SLOT_HEART)
				if(heart)
					// Not gonna lie chief I dont know what this math does, I just used bay's SKILL_EXPERIENCED valie
					heart.external_pump = list(world.time, 0.8  + rand(-0.1,0.1))

			if(CRIT_FAILURE, FAILURE)
				var/obj/item/bodypart/chest/chest = target.get_bodypart(BODY_ZONE_CHEST)
				if(chest.break_bones(TRUE))
					to_chat(src, result.create_tooltip("Your strength betrays you as you shatter [target.name]'s [chest.encased]."))

		log_combat(src, target, "CPRed")

		if(target.breathe(TRUE) == BREATH_OKAY)
			to_chat(target, span_unconscious("You feel a breath of fresh air enter your lungs."))
			target.adjustOxyLoss(-8)


	cut_overlay(cpr_image)

#undef CPR_PANIC_SPEED

/mob/living/carbon/human/proc/can_perform_cpr(mob/living/carbon/target, silent = TRUE)
	if(target.body_position != LYING_DOWN)
		return FALSE

	if(!target.getorganslot(ORGAN_SLOT_LUNGS))
		to_chat(src, span_warning("[target.p_they()] [target.p_dont()] have lungs."))
		return FALSE

	return TRUE

/mob/living/carbon/human/cuff_resist(obj/item/I)
	if(dna?.check_mutation(/datum/mutation/human/hulk))
		say(pick(";RAAAAAAAARGH!", ";HNNNNNNNNNGGGGGGH!", ";GWAAAAAAAARRRHHH!", "NNNNNNNNGGGGGGGGHH!", ";AAAAAAARRRGH!" ), forced = "hulk")
		if(..(I, cuff_break = FAST_CUFFBREAK))
			dropItemToGround(I)
	else
		if(..())
			dropItemToGround(I)

/**
 * Wash the hands, cleaning either the gloves if equipped and not obscured, otherwise the hands themselves if they're not obscured.
 *
 * Returns false if we couldn't wash our hands due to them being obscured, otherwise true
 */
/mob/living/carbon/human/proc/wash_hands(clean_types)
	var/obscured = check_obscured_slots()
	if(obscured & ITEM_SLOT_GLOVES)
		return FALSE

	germ_level = 0

	if(gloves)
		if(gloves.wash(clean_types))
			update_worn_gloves()
	else if((clean_types & CLEAN_TYPE_BLOOD) && blood_in_hands > 0)
		blood_in_hands = 0
		update_worn_gloves()

	return TRUE

/**
 * Used to update the makeup on a human and apply/remove lipstick traits, then store/unstore them on the head object in case it gets severed
 */
/mob/living/carbon/human/proc/update_lips(new_style, new_colour, apply_trait)
	lip_style = new_style
	lip_color = new_colour
	update_body()

	var/obj/item/bodypart/head/hopefully_a_head = get_bodypart(BODY_ZONE_HEAD)
	REMOVE_TRAITS_IN(src, LIPSTICK_TRAIT)
	hopefully_a_head?.stored_lipstick_trait = null

	if(new_style && apply_trait)
		ADD_TRAIT(src, apply_trait, LIPSTICK_TRAIT)
		hopefully_a_head?.stored_lipstick_trait = apply_trait

/**
 * A wrapper for [mob/living/carbon/human/proc/update_lips] that tells us if there were lip styles to change
 */
/mob/living/carbon/human/proc/clean_lips()
	if(isnull(lip_style) && lip_color == initial(lip_color))
		return FALSE
	update_lips(null)
	return TRUE

/**
 * Called on the COMSIG_COMPONENT_CLEAN_FACE_ACT signal
 */
/mob/living/carbon/human/proc/clean_face(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!is_mouth_covered() && clean_lips())
		. = TRUE

	if(glasses && is_eyes_covered(FALSE, TRUE, TRUE) && glasses.wash(clean_types))
		update_worn_glasses()
		. = TRUE

	var/obscured = check_obscured_slots()
	if(wear_mask && !(obscured & ITEM_SLOT_MASK) && wear_mask.wash(clean_types))
		update_worn_mask()
		. = TRUE

/**
 * Called when this human should be washed
 */
/mob/living/carbon/human/wash(clean_types)
	. = ..()

	// Wash equipped stuff that cannot be covered
	if(wear_suit?.wash(clean_types))
		update_worn_oversuit()
		. = TRUE

	if(belt?.wash(clean_types))
		update_worn_belt()
		. = TRUE

	// Check and wash stuff that can be covered
	var/obscured = check_obscured_slots()

	if(w_uniform && !(obscured & ITEM_SLOT_ICLOTHING) && w_uniform.wash(clean_types))
		update_worn_undersuit()
		. = TRUE

	if(!is_mouth_covered() && clean_lips())
		. = TRUE

	// Wash hands if exposed
	if(!gloves && (clean_types & CLEAN_TYPE_BLOOD) && blood_in_hands > 0 && !(obscured & ITEM_SLOT_GLOVES))
		blood_in_hands = 0
		update_worn_gloves()
		. = TRUE

//Turns a mob black, flashes a skeleton overlay
//Just like a cartoon!
/mob/living/carbon/human/proc/electrocution_animation(anim_duration)
	//Handle mutant parts if possible
	if(dna?.species)
		add_atom_colour("#000000", TEMPORARY_COLOUR_PRIORITY)
		var/static/mutable_appearance/electrocution_skeleton_anim
		if(!electrocution_skeleton_anim)
			electrocution_skeleton_anim = mutable_appearance(icon, "electrocuted_base")
			electrocution_skeleton_anim.appearance_flags |= RESET_COLOR|KEEP_APART
		add_overlay(electrocution_skeleton_anim)
		addtimer(CALLBACK(src, PROC_REF(end_electrocution_animation), electrocution_skeleton_anim), anim_duration)

	else //or just do a generic animation
		flick_overlay_view(image(icon,src,"electrocuted_generic",ABOVE_MOB_LAYER), src, anim_duration)

/mob/living/carbon/human/proc/end_electrocution_animation(mutable_appearance/MA)
	remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, "#000000")
	cut_overlay(MA)

/mob/living/carbon/human/resist_restraints()
	if(wear_suit?.breakouttime)
		changeNext_move(CLICK_CD_BREAKOUT)
		last_special = world.time + CLICK_CD_BREAKOUT
		cuff_resist(wear_suit)
	else
		..()

/mob/living/carbon/human/clear_cuffs(obj/item/I, cuff_break)
	. = ..()
	if(.)
		return
	if(!I.loc || buckled)
		return FALSE
	if(I == wear_suit)
		visible_message(span_danger("[src] manages to [cuff_break ? "break" : "remove"] [I]!"))
		to_chat(src, span_notice("You successfully [cuff_break ? "break" : "remove"] [I]."))
		return TRUE

/mob/living/carbon/human/replace_records_name(oldname,newname) // Only humans have records right now, move this up if changed.
	for(var/id as anything in SSdatacore.library)
		var/datum/data_library/library = SSdatacore.library[id]
		var/datum/data/record/R = library.get_record_by_name(oldname)
		if(R)
			R.fields[DATACORE_NAME] = newname
			library.records_by_name -= oldname
			library.records_by_name[newname] = R

/mob/living/carbon/human/get_total_tint()
	. = ..()
	if(glasses)
		. += glasses.tint

/mob/living/carbon/human/update_health_hud()
	if(!client || !hud_used)
		return

	if(hud_used.healths) // Kapu note: We don't use this on humans due to human health being brain health. It'd be confusing.
		if(..()) //not dead
			switch(hal_screwyhud)
				if(SCREWYHUD_CRIT)
					hud_used.healths.icon_state = "health6"
				if(SCREWYHUD_DEAD)
					hud_used.healths.icon_state = "health7"
				if(SCREWYHUD_HEALTHY)
					hud_used.healths.icon_state = "health0"

	if(hud_used.healthdoll)
		var/list/new_overlays = list()
		hud_used.healthdoll.cut_overlays()
		if(stat != DEAD)
			hud_used.healthdoll.icon_state = "healthdoll_OVERLAY"
			for(var/obj/item/bodypart/body_part as anything in bodyparts)
				var/icon_num = 0

				//Hallucinations
				if(body_part.type in hal_screwydoll)
					icon_num = hal_screwydoll[body_part.type]
					new_overlays += image('icons/hud/screen_gen.dmi', "[body_part.body_zone][icon_num]")
					continue

				if(hal_screwyhud == SCREWYHUD_HEALTHY)
					icon_num = 0
				//Not hallucinating
				else
					var/dam_state = min(1,((body_part.brute_dam + body_part.burn_dam) / max(1,body_part.max_damage)))
					if(dam_state)
						icon_num = max(1, min(Ceil(dam_state * 6), 6))

				if(icon_num)
					new_overlays += image('icons/hud/screen_gen.dmi', "[body_part.body_zone][icon_num]")

				if(body_part.getPain() > 20)
					new_overlays += image('icons/hud/screen_gen.dmi', "[body_part.body_zone]pain")

				if(body_part.bodypart_disabled) //Disabled limb
					new_overlays += image('icons/hud/screen_gen.dmi', "[body_part.body_zone]7")

			for(var/t in get_missing_limbs()) //Missing limbs
				new_overlays += image('icons/hud/screen_gen.dmi', "[t]6")

			if(undergoing_cardiac_arrest())
				new_overlays += image('icons/hud/screen_gen.dmi', "softcrit")

			if(on_fire)
				new_overlays += image('icons/hud/screen_gen.dmi', "burning")

			//Add all the overlays at once, more performant!
			hud_used.healthdoll.add_overlay(new_overlays)
		else
			hud_used.healthdoll.icon_state = "healthdoll_DEAD"

/mob/living/carbon/human/revive(full_heal, admin_revive, excess_healing)
	. = ..()
	if(!.)
		return

	log_health(src, "Brought back to life.")

/mob/living/carbon/human/fully_heal(admin_revive = FALSE)
	log_health(src, "Received an adminheal.")
	dna?.species.spec_fully_heal(src)
	if(admin_revive)
		regenerate_limbs()
		regenerate_organs()

	for(var/obj/item/bodypart/BP as anything in bodyparts)
		BP.set_sever_artery(FALSE)
		BP.set_sever_tendon(FALSE)
		BP.set_dislocated(FALSE)
		BP.heal_bones()
		BP.adjustPain(-INFINITY)
		BP.germ_level = 0

	remove_all_embedded_objects()
	set_heartattack(FALSE)
	for(var/datum/mutation/human/HM in dna.mutations)
		if(HM.quality != POSITIVE)
			dna.remove_mutation(HM.name)
	set_coretemperature(get_body_temp_normal(apply_change=FALSE))
	return ..()

/mob/living/carbon/human/vomit(lost_nutrition = 10, blood = FALSE, stun = TRUE, distance = 1, message = TRUE, vomit_type = VOMIT_TOXIC, harm = TRUE, force = FALSE, purge_ratio = 0.1)
	if(blood && (NOBLOOD in dna.species.species_traits) && !HAS_TRAIT(src, TRAIT_TOXINLOVER))
		if(message)
			visible_message(span_warning("[src] dry heaves!"), \
							span_userdanger("You try to throw up, but there's nothing in your stomach!"))
		if(stun)
			Paralyze(200)
		return 1
	..()

/mob/living/carbon/human/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("", "---------")
	VV_DROPDOWN_OPTION(VV_HK_COPY_OUTFIT, "Copy Outfit")
	VV_DROPDOWN_OPTION(VV_HK_MOD_MUTATIONS, "Add/Remove Mutation")
	VV_DROPDOWN_OPTION(VV_HK_MOD_QUIRKS, "Add/Remove Quirks")
	VV_DROPDOWN_OPTION(VV_HK_SET_SPECIES, "Set Species")

/mob/living/carbon/human/vv_do_topic(list/href_list)
	. = ..()
	if(href_list[VV_HK_COPY_OUTFIT])
		if(!check_rights(R_SPAWN))
			return
		copy_outfit()
	if(href_list[VV_HK_MOD_MUTATIONS])
		if(!check_rights(R_SPAWN))
			return

		var/list/options = list("Clear"="Clear")
		for(var/x in subtypesof(/datum/mutation/human))
			var/datum/mutation/human/mut = x
			var/name = initial(mut.name)
			options[dna.check_mutation(mut) ? "[name] (Remove)" : "[name] (Add)"] = mut

		var/result = input(usr, "Choose mutation to add/remove","Mutation Mod") as null|anything in sort_list(options)
		if(result)
			if(result == "Clear")
				dna.remove_all_mutations()
			else
				var/mut = options[result]
				if(dna.check_mutation(mut))
					dna.remove_mutation(mut)
				else
					dna.add_mutation(mut)
	if(href_list[VV_HK_MOD_QUIRKS])
		if(!check_rights(R_SPAWN))
			return

		var/list/options = list("Clear"="Clear")
		for(var/type in subtypesof(/datum/quirk))
			var/datum/quirk/quirk_type = type

			if(isabstract(quirk_type))
				continue

			var/qname = initial(quirk_type.name)
			options[has_quirk(quirk_type) ? "[qname] (Remove)" : "[qname] (Add)"] = quirk_type

		var/result = input(usr, "Choose quirk to add/remove","Quirk Mod") as null|anything in sort_list(options)
		if(result)
			if(result == "Clear")
				for(var/datum/quirk/q in quirks)
					remove_quirk(q.type)
			else
				var/T = options[result]
				if(has_quirk(T))
					remove_quirk(T)
				else
					add_quirk(T)
	if(href_list[VV_HK_SET_SPECIES])
		if(!check_rights(R_SPAWN))
			return
		var/result = input(usr, "Please choose a new species","Species") as null|anything in GLOB.species_list
		if(result)
			var/newtype = GLOB.species_list[result]
			admin_ticket_log("[key_name_admin(usr)] has modified the bodyparts of [src] to [result]")
			set_species(newtype)

/mob/living/carbon/human/mouse_buckle_handling(mob/living/M, mob/living/user)
	var/obj/item/hand_item/grab/G = is_grabbing(M)
	if(combat_mode)
		return FALSE

	if(!G || G.current_grab.damage_stage != GRAB_AGGRESSIVE || stat != CONSCIOUS)
		return FALSE

	//If they dragged themselves to you and you're currently aggressively grabbing them try to piggyback
	if(user == M && can_piggyback(M))
		piggyback(M)
		return TRUE

	//If you dragged them to you and you're aggressively grabbing try to fireman carry them
	if(can_be_firemanned(M))
		fireman_carry(M)
		return TRUE

//src is the user that will be carrying, target is the mob to be carried
/mob/living/carbon/human/proc/can_piggyback(mob/living/carbon/target)
	return (istype(target) && target.stat == CONSCIOUS)

/mob/living/carbon/human/proc/can_be_firemanned(mob/living/carbon/target)
	return ishuman(target) && target.body_position == LYING_DOWN

/mob/living/carbon/human/proc/fireman_carry(mob/living/carbon/target)
	if(!can_be_firemanned(target) || incapacitated(IGNORE_GRAB))
		to_chat(src, span_warning("You can't fireman carry [target] while [target.p_they()] [target.p_are()] standing!"))
		return

	var/carrydelay = 5 SECONDS //if you have latex you are faster at grabbing
	var/skills_space = "" //cobby told me to do this
	if(HAS_TRAIT(src, TRAIT_QUICKER_CARRY))
		carrydelay = 3 SECONDS
		skills_space = " very quickly"
	else if(HAS_TRAIT(src, TRAIT_QUICK_CARRY))
		carrydelay = 4 SECONDS
		skills_space = " quickly"

	visible_message(span_notice("[src] starts[skills_space] lifting [target] onto [p_their()] back..."),
		span_notice("You[skills_space] start to lift [target] onto your back..."))
	if(!do_after(src, target, carrydelay, DO_PUBLIC, display = image('icons/hud/do_after.dmi', "help")))
		visible_message(span_warning("[src] fails to fireman carry [target]!"))
		return

	//Second check to make sure they're still valid to be carried
	if(!can_be_firemanned(target) || incapacitated(IGNORE_GRAB) || target.buckled)
		visible_message(span_warning("[src] fails to fireman carry [target]!"))
		return

	return buckle_mob(target, TRUE, TRUE, CARRIER_NEEDS_ARM)

/mob/living/carbon/human/proc/piggyback(mob/living/carbon/target)
	if(!can_piggyback(target))
		to_chat(target, span_warning("You can't piggyback ride [src] right now!"))
		return

	visible_message(span_notice("[target] starts to climb onto [src]..."))
	if(!do_after(target, src, 1.5 SECONDS) || !can_piggyback(target))
		visible_message(span_warning("[target] fails to climb onto [src]!"))
		return

	if(target.incapacitated(IGNORE_GRAB) || incapacitated(IGNORE_GRAB))
		target.visible_message(span_warning("[target] can't hang onto [src]!"))
		return

	return buckle_mob(target, TRUE, TRUE, RIDER_NEEDS_ARMS)

/mob/living/carbon/human/buckle_mob(mob/living/target, force = FALSE, check_loc = TRUE, buckle_mob_flags= NONE)
	if(!is_type_in_typecache(target, can_ride_typecache))
		target.visible_message(span_warning("[target] really can't seem to mount [src]..."))
		return

	if(!force)//humans are only meant to be ridden through piggybacking and special cases
		return

	return ..()

/mob/living/carbon/human/updatehealth(cause_of_death)
	. = ..()
	dna?.species.spec_updatehealth(src)

/mob/living/carbon/human/pre_stamina_change(diff as num, forced)
	if(diff < 0) //Taking damage, not healing
		return diff * physiology.stamina_mod
	return diff

/mob/living/carbon/human/adjust_nutrition(change)
	if(isipc(src))
		var/obj/item/organ/cell/C = getorganslot(ORGAN_SLOT_CELL)
		if(C)
			if(change > 0)
				. = C.give(change)
			else
				. = C.use(change, TRUE)
		return .

	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/set_nutrition(change) //Seriously fuck you oldcoders.
	if(HAS_TRAIT(src, TRAIT_NOHUNGER))
		return FALSE
	return ..()

/mob/living/carbon/human/is_bleeding()
	if(NOBLOOD in dna.species.species_traits)
		return FALSE
	return ..()

/mob/living/carbon/human/get_total_bleed_rate()
	if(NOBLOOD in dna.species.species_traits)
		return FALSE
	return ..()

/mob/living/carbon/human/get_exp_list(minutes)
	. = ..()

	if(mind.assigned_role.title in SSjob.name_occupations)
		.[mind.assigned_role.title] = minutes

/mob/living/carbon/human/atmos_expose(datum/gas_mixture/air, exposed_temperature)
	var/plasma_exposure = air.gas[GAS_PLASMA]
	if(plasma_exposure)
		expose_plasma(plasma_exposure)

/mob/living/carbon/human/monkeybrain
	ai_controller = /datum/ai_controller/monkey

/mob/living/carbon/human/species
	var/race = null
	var/use_random_name = TRUE

/mob/living/carbon/human/species/create_dna()
	dna = new /datum/dna(src)
	if (!isnull(race))
		dna.species = new race

/mob/living/carbon/human/species/set_species(datum/species/mrace, icon_update, pref_load)
	. = ..()
	if(use_random_name)
		fully_replace_character_name(real_name, dna.species.random_name())

/mob/living/carbon/human/species/abductor
	race = /datum/species/abductor

/mob/living/carbon/human/species/android
	race = /datum/species/android

/mob/living/carbon/human/species/fly
	race = /datum/species/fly

/mob/living/carbon/human/species/jelly
	race = /datum/species/jelly

/mob/living/carbon/human/species/jelly/slime
	race = /datum/species/jelly/slime

/mob/living/carbon/human/species/jelly/stargazer
	race = /datum/species/jelly/stargazer

/mob/living/carbon/human/species/jelly/luminescent
	race = /datum/species/jelly/luminescent

/mob/living/carbon/human/species/lizard
	race = /datum/species/lizard

/mob/living/carbon/human/species/ethereal
	race = /datum/species/ethereal

/mob/living/carbon/human/species/moth
	race = /datum/species/moth

/mob/living/carbon/human/species/pod
	race = /datum/species/pod

/mob/living/carbon/human/species/teshari
	race = /datum/species/teshari

/mob/living/carbon/human/species/shadow
	race = /datum/species/shadow

/mob/living/carbon/human/species/shadow/nightmare
	race = /datum/species/shadow/nightmare

/mob/living/carbon/human/species/skeleton
	race = /datum/species/skeleton

/mob/living/carbon/human/species/vampire
	race = /datum/species/vampire

/mob/living/carbon/human/species/zombie
	race = /datum/species/zombie

/mob/living/carbon/human/species/zombie/infectious
	race = /datum/species/zombie/infectious

/mob/living/carbon/human/species/vox
	race = /datum/species/vox

/mob/living/carbon/human/species/ipc
	race = /datum/species/ipc

/mob/living/carbon/human/species/ipc/saurian
	race = /datum/species/ipc/saurian


/mob/living/carbon/human/verb/checkpulse()
	set name = "Check Pulse"
	set category = "IC"
	set desc = "Approximately count somebody's pulse. Requires you to stand still at least 6 seconds."
	set src in view(1)

	if(!isliving(src) || usr.stat || usr.incapacitated())
		return

	var/self = FALSE
	if(usr == src)
		self = TRUE

	if(!self)
		usr.visible_message(
			span_notice("[usr] kneels down, puts \his hand on [src]'s wrist and begins counting their pulse."),
			span_notice("You begin counting [src]'s pulse")
		)
	else
		usr.visible_message(
			span_notice("[usr] begins counting their pulse."),
			span_notice("You begin counting your pulse.")
		)


	if (!pulse() || HAS_TRAIT(src, TRAIT_FAKEDEATH))
		to_chat(usr, span_danger("[src] has no pulse!"))
		return
	else
		to_chat(usr, span_notice("[self ? "You have a" : "[src] has a"] pulse. Counting..."))

	to_chat(usr, span_notice("You must[self ? "" : " both"] remain still until counting is finished."))

	if(do_after(usr, src, 6 SECONDS, DO_PUBLIC))
		to_chat(usr, span_notice("[self ? "Your" : "[src]'s"] pulse is [src.get_pulse(GETPULSE_HAND)]."))

///Accepts an organ slot, returns whether or not the mob needs one to survive (or just should have one for non-vital organs).
/mob/living/carbon/human/needs_organ(slot)
	if(!dna || !dna.species)
		return FALSE

	switch(slot)
		if(ORGAN_SLOT_STOMACH)
			if(HAS_TRAIT(src, TRAIT_NOHUNGER))
				return FALSE
		if(ORGAN_SLOT_LUNGS)
			if(HAS_TRAIT(src, TRAIT_NOBREATH))
				return FALSE
		if(ORGAN_SLOT_LIVER)
			if(HAS_TRAIT(src, TRAIT_NOMETABOLISM))
				return FALSE
		if(ORGAN_SLOT_EARS)
			if(HAS_TRAIT(src, TRAIT_NOEARS))
				return FALSE

	return dna.species.organs[slot]

//Used by various things that knock people out by applying blunt trauma to the head.
//Checks that the species has a "head" (brain containing organ) and that hit_zone refers to it.
/mob/living/carbon/human/proc/can_head_trauma_ko()
	var/obj/item/organ/brain = getorganslot(ORGAN_SLOT_BRAIN)
	if(!brain || !needs_organ(ORGAN_SLOT_BRAIN))
		return FALSE

	//if the parent organ is significantly larger than the brain organ, then hitting it is not guaranteed
	var/obj/item/bodypart/head = get_bodypart(BODY_ZONE_HEAD)
	if(!head)
		return FALSE
	if(head.w_class > brain.w_class + 1)
		return prob(100 / 2**(head.w_class - brain.w_class - 1))
	return TRUE

/mob/living/carbon/human/up()
	. = ..()
	if(.)
		return
	var/obj/climbable = check_zclimb()
	if(!climbable)
		can_z_move(UP, get_turf(src), ZMOVE_FEEDBACK|ZMOVE_FLIGHT_FLAGS)
		return FALSE

	return ClimbUp(climbable)

/mob/living/carbon/human/drag_damage(turf/new_loc, turf/old_loc, direction)
	if(prob(getBruteLoss() * 0.6))
		makeBloodTrail(new_loc, old_loc, direction, TRUE)

	adjustBloodVolume(-1)
	if(!prob(10))
		return

	var/list/wounds = get_wounds()
	shuffle_inplace(wounds)

	var/datum/wound/cut/C = locate() in wounds
	var/datum/wound/puncture/P = locate() in wounds

	if(C && P)
		if(prob(50))
			C = null
		else
			P = null

	var/datum/wound/W = C || P
	if(!W)
		return

	W.open_wound(5)

	if(!IS_ORGANIC_LIMB(W.parent))
		visible_message(
			span_warning("The damage to [src]'s [W.parent.plaintext_zone] worsens."),
			span_warning("The damage to your [W.parent.plaintext_zone] worsens."),
			span_hear("You hear the screech of abused metal."),
			COMBAT_MESSAGE_RANGE,
		)
	else
		visible_message(
			span_warning("The [W.desc] on [src]'s [W.parent.plaintext_zone] widens with a nasty ripping noise."),
			span_warning("The [W.desc] on your [W.parent.plaintext_zone] widens with a nasty ripping noise."),
			span_hear("You hear a nasty ripping noise, as if flesh is being torn apart."),
			COMBAT_MESSAGE_RANGE,
		)


/mob/living/carbon/human/getTrail(being_dragged)
	if(get_bleed_rate() < (being_dragged ? 1.5 : 2.5))
		return "bleedtrail_light_[rand(1,4)]"
	else
		return "bleedtrail_heavy"

/mob/living/carbon/human/leavesBloodTrail()
	if(!is_bleeding() || HAS_TRAIT(src, TRAIT_NOBLEED))
		return FALSE

	return ..()

/mob/living/carbon/human/get_blood_print()
	var/obj/item/bodypart/leg/L = get_bodypart(BODY_ZONE_R_LEG) || get_bodypart(BODY_ZONE_L_LEG)
	return L?.blood_print

/mob/living/carbon/human/proc/get_fingerprints(ignore_gloves, hand)
	if(!ignore_gloves && (gloves || (check_obscured_slots() & ITEM_SLOT_GLOVES)))
		return

	var/obj/item/bodypart/arm/arm
	if(hand)
		if(isbodypart(hand))
			arm = hand
		arm ||= get_bodypart(hand)
	else
		arm = get_bodypart(BODY_ZONE_R_ARM) || get_bodypart(BODY_ZONE_L_ARM)

	return arm?.fingerprints

/// Takes a user and body_zone, if the body_zone is covered by clothing, add a fingerprint to it. Otherwise, add one to us.
/mob/living/carbon/human/proc/add_fingerprint_on_clothing_or_self(mob/user, body_zone)
	var/obj/item/I = get_item_covering_zone(body_zone)
	if(I)
		I.add_fingerprint(user)
		log_touch(user)
	else
		add_fingerprint(user)

/// Takes a user and body_zone, if the body_zone is covered by clothing, add trace dna to it. Otherwise, add one to us.
/mob/living/carbon/human/proc/add_trace_DNA_on_clothing_or_self(mob/living/carbon/human/user, body_zone)
	if(!istype(user))
		return

	var/obj/item/I = get_item_covering_zone(body_zone)
	if(I)
		I.add_trace_DNA(user.get_trace_dna())
	else
		add_trace_DNA(user.get_trace_dna())

/mob/living/carbon/human/fire_act(exposed_temperature, exposed_volume, turf/adjacent)
	. = ..()
	var/head_exposure = 1
	var/chest_exposure = 1
	var/groin_exposure = 1
	var/legs_exposure = 1
	var/arms_exposure = 1

	//Get heat transfer coefficients for clothing.

	for(var/obj/item/C in get_all_worn_items(FALSE))
		if(C.max_heat_protection_temperature >= exposed_temperature)
			if(C.heat_protection & HEAD)
				head_exposure = 0
			if(C.heat_protection & CHEST)
				chest_exposure = 0
			if(C.heat_protection & GROIN)
				groin_exposure = 0
			if( C.heat_protection & LEGS)
				legs_exposure = 0
			if(C.heat_protection & ARMS)
				arms_exposure = 0
		else
			if((C.body_parts_covered | C.heat_protection) & HEAD)
				head_exposure = 0.5
			if((C.body_parts_covered | C.heat_protection) & CHEST)
				chest_exposure = 0.5
			if((C.body_parts_covered | C.heat_protection) & GROIN)
				groin_exposure = 0.5
			if((C.body_parts_covered | C.heat_protection) & LEGS)
				legs_exposure = 0.5
			if((C.body_parts_covered | C.heat_protection) & ARMS)
				arms_exposure = 0.5

	//minimize this for low-pressure environments
	var/temp_multiplier = 2 * clamp(0, exposed_temperature / PHORON_MINIMUM_BURN_TEMPERATURE, 1)

	//Always check these damage procs first if fire damage isn't working. They're probably what's wrong.
	if(head_exposure)
		apply_damage(0.9 * temp_multiplier * head_exposure, BURN, BODY_ZONE_HEAD)
	if(chest_exposure || groin_exposure)
		apply_damage(2.5 * temp_multiplier * chest_exposure, BURN, BODY_ZONE_CHEST)
		apply_damage(2.0 * temp_multiplier * groin_exposure, BURN, BODY_ZONE_CHEST)
	if(arms_exposure)
		apply_damage(0.4 * temp_multiplier * arms_exposure, BURN, BODY_ZONE_L_ARM)
		apply_damage(0.4 * temp_multiplier * arms_exposure, BURN, BODY_ZONE_R_ARM)
	if(legs_exposure)
		apply_damage(0.6 * temp_multiplier * legs_exposure, BURN, BODY_ZONE_L_LEG)
		apply_damage(0.6 * temp_multiplier * legs_exposure, BURN, BODY_ZONE_R_LEG)

