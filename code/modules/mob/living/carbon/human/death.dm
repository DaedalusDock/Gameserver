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

/mob/living/carbon/human/death(gibbed, cause_of_death = "Unknown")
	if(stat == DEAD)
		return

	log_health(src, "Died. BRUTE: [getBruteLoss()] | BURN: [getFireLoss()] | TOX: [getFireLoss()] | OXY:[getOxyLoss()] | BLOOD: [blood_volume] | BLOOD OXY: [get_blood_oxygenation()]% | PAIN:[getPain()]")

	stop_sound_channel(CHANNEL_HEARTBEAT)
	var/obj/item/organ/heart/H = getorganslot(ORGAN_SLOT_HEART)
	if(H)
		H.beat = BEAT_NONE

	var/obj/item/organ/brain/B = getorganslot(ORGAN_SLOT_BRAIN)
	if(B && !(B.organ_flags & ORGAN_DEAD))
		B.set_organ_dead(TRUE, change_mob_stat = FALSE)

	. = ..()

	if(!QDELETED(dna)) //The gibbed param is bit redundant here since dna won't exist at this point if they got deleted.
		dna.species.spec_death(gibbed, src)

	if(!SSticker.HasRoundStarted())
		return

	//* PAST THIS POINT THE ROUND HAS STARTED *//

	SSblackbox.ReportDeath(src)
	log_message("has died (BRUTE: [src.getBruteLoss()], BURN: [src.getFireLoss()], TOX: [src.getToxLoss()], OXY: [src.getOxyLoss()], CLONE: [src.getCloneLoss()])", LOG_ATTACK)

	if(mind)
		var/turf/T = get_turf(src)
		var/obj/machinery/light/nearest_light
		var/closest = INFINITY
		for(var/obj/machinery/light/L in range(5, T))
			var/dist = get_dist(L, T)
			if(dist > closest || L.constant_flickering || L.status != LIGHT_OK)
				continue

			if(dist < closest || prob(50))
				nearest_light = L
				closest = dist

		if(nearest_light)
			addtimer(CALLBACK(nearest_light, TYPE_PROC_REF(/obj/machinery/light, start_flickering)), rand(20 SECONDS, 60 SECONDS))

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


/mob/living/carbon/human/proc/show_death_stats(mob/user)
	var/list/scan = time_of_death_stats
	var/list/ui_content = list()

	var/datum/browser/popup = new(user, "timeofdeathinfo", "Time of Death Information", 600, 800)

	ui_content += {"
		<fieldset class='computerPaneSimple' style='margin: 0 auto'>
	"}

	ui_content += {"
			<table style='min-width:100%'>
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Scan Results For:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[scan["name"]]
					</td>
				</tr>
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Scan Performed At:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[scan["time"]]
					</td>
				</tr>
	"}

	var/brain_activity = scan["brain_activity"]
	switch(brain_activity)
		if(0)
			brain_activity = span_bad("None, patient is braindead")
		if(-1)
			brain_activity = span_bad("Patient is missing a brain")
		if(100)
			brain_activity = span_good("[brain_activity]%")
		else
			brain_activity = span_mild("[brain_activity]%")

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Brain Activity:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[brain_activity]
					</td>
				</tr>
	"}
	var/pulse_string
	if(scan["pulse"] == -1)
		pulse_string = "[span_average("N/A")]"
	else if(scan["pulse"] == -2)
		pulse_string = "N/A"
	else if(scan["pulse"] == -3)
		pulse_string = "[span_bad("250+bpm")]"
	else if(scan["pulse"] == 0)
		pulse_string = "[span_bad("[scan["pulse"]]bpm")]"
	else if(scan["pulse"] >= 140)
		pulse_string = "[span_bad("[scan["pulse"]]bpm")]"
	else if(scan["pulse"] >= 120)
		pulse_string = "[span_average("[scan["pulse"]]bpm")]"
	else
		pulse_string = "[scan["pulse"]]bpm"

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Pulse Rate:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[pulse_string]
					</td>
				</tr>
	"}
	var/pressure_string
	var/ratio = scan["blood_volume"]/scan["blood_volume_max"]
	if(scan["blood_o2"] <= 70)
		pressure_string = "([span_bad("[scan["blood_o2"]]% blood oxygenation")])"
	else if(scan["blood_o2"] <= 85)
		pressure_string = "([span_average("[scan["blood_o2"]]% blood oxygenation")])</td></tr>"
	else if(scan["blood_o2"] <= 90)
		pressure_string = "(["<span style='color:[COLOR_MEDICAL_OXYLOSS]'>[scan["blood_o2"]]% blood oxygenation</span>"])</td></tr>"
	else
		pressure_string = "([scan["blood_o2"]]% blood oxygenation)</td></tr>"

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Blood Pressure:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[pressure_string]
					</td>
				</tr>
	"}
	if(ratio <= 0.7)
		ui_content += {"
				<tr>
					<td colspan = '2'>
						[span_bad("Patient is in hypovolemic shock. Transfusion highly recommended.")]
					</td>
				</tr>
		"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Blood Volume:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[scan["blood_volume"]]u/[scan["blood_volume_max"]]u ([scan["blood_type"]])
					</td>
				</tr>
	"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Body Temperature:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[scan["temperature"]-T0C]&deg;C ([FAHRENHEIT(scan["temperature"])]&deg;F)
					</td>
				</tr>
	"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>DNA:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[scan["dna"]]
					</td>
				</tr>
	"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Physical Trauma:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[get_damage_severity(scan["brute"],TRUE)]
					</td>
				</tr>
	"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Burn Severity:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[get_damage_severity(scan["burn"],TRUE)]
					</td>
				</tr>
	"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Systematic Organ Failure:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[get_damage_severity(scan["toxin"],TRUE)]
					</td>
				</tr>
	"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Oxygen Deprivation:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[get_damage_severity(scan["oxygen"],TRUE)]
					</td>
				</tr>
	"}

	ui_content += {"
				<tr>
					<td style='padding-left: 5px;padding-right: 5px'>
						<strong>Genetic Damage:</strong>
					</td>
					<td style='padding-left: 5px;padding-right: 5px'>
						[get_damage_severity(scan["genetic"],TRUE)]
					</td>
				</tr>
	"}

	if(scan["dna_ruined"])
		ui_content += {"
					<tr>
						<td colspan = '2' style='text-align:center'>
							[span_bad("<strong>ERROR: patient's DNA sequence is unreadable.</strong>")]
						</td>
					</tr>
					<tr><td colspan='2'></td></tr>
		"}

	if(scan["husked"])
		ui_content += {"
					<tr>
						<td colspan = '2' style='text-align:center'>
							[span_bad("Husked cadaver detected: Replacement tissue required.")]
						</td>
					</tr>
					<tr><td colspan='2'></td></tr>
		"}
	if(scan["radiation"])
		ui_content += {"
					<tr>
						<td colspan = '2' style='text-align:center'>
							<span style='color: [COLOR_MEDICAL_RADIATION]'>Irradiated</span>
						</td>
					</tr>
					<tr><td colspan='2'></td></tr>
		"}

	if(scan["genetic_instability"])
		ui_content += {"
					<tr>
						<td colspan = '2' style='text-align:center'>
							[span_bad("Genetic instability detected.")]
						</td>
					</tr>
					<tr><td colspan='2'></td></tr>
		"}


	if(length(scan["reagents"]))
		ui_content += {"
						<tr>
							<td colspan = '2' style='text-align:center'>
								<strong>Reagents detected in patient's bloodstream:</strong>
							</td>
						</tr>
						<tr>
							<td colspan='2'>
			"}
		for(var/list/R as anything in scan["reagents"])
			if(R["visible"])
				ui_content += {"
						<tr>
							<td colspan = '2' style='padding-left: 35%'>
								["[R["quantity"]]u [R["name"]][R["overdosed"] ? " <span class='bad'>OVERDOSED" : ""]"]
							</td>
						</tr>
				"}
			else
				ui_content += {"
							<tr>
								<td colspan = '2' style='padding-left: 35%'>
									[span_average("Unknown Reagent")]
								</td>
							</tr>
					"}

	ui_content += {"
			<tr>
				<td colspan='2'>
					<center>
						<table class='block' border='1' width='95%'>
							<tr>
								<th colspan='3'>Body Status</th>
							</tr>
							<tr>
								<th>Organ</th>
								<th>Damage</th>
								<th>Status</th>
							</tr>
	"}

	for(var/list/limb as anything in scan["bodyparts"])
		ui_content += {"
			<tr>
				<td style='padding-left: 5px;padding-right: 5px'>[limb["name"]]
				</td>
		"}

		if(limb["is_stump"])
			ui_content += {"
				<td style='padding-left: 5px;padding-right: 5px'>
					<span style='font-weight: bold; color: [COLOR_MEDICAL_MISSING]'>Missing</span>
				</td>
				<td style='padding-left: 5px;padding-right: 5px'>
					<span>[english_list(limb["scan_results"], nothing_text = "&nbsp;")]</span>
				</td>
			"}
		else
			ui_content += "<td style='padding-left: 5px;padding-right: 5px'>"
			if(!(limb["brute_dam"] || limb["burn_dam"]))
				ui_content += "None</td>"

			else
				if(limb["brute_dam"])
					ui_content += {"
						<span style='font-weight: bold; color: [COLOR_MEDICAL_BRUTE]'>[capitalize(get_wound_severity(limb["brute_ratio"]))] physical trauma</span><br>
					"}
				if(limb["burn_dam"])
					ui_content += {"
						<span style='font-weight: bold; color: [COLOR_MEDICAL_BURN]'>[capitalize(get_wound_severity(limb["burn_ratio"]))] burns</span>
					"}

				ui_content += "</td>"

			ui_content += {"
				<td style='padding-left: 5px;padding-right: 5px'>
					<span>[english_list(limb["scan_results"], nothing_text = "&nbsp;")]</span>
				</td>
			"}

		ui_content += "</tr>"

	ui_content += "<tr><th colspan='3'><center>Internal Organs</center></th></tr>"
	for(var/list/organ as anything in scan["organs"])
		ui_content += "<tr><td style='padding-left: 5px;padding-right: 5px'>[organ["name"]]</td>"

		if(organ["damage_percent"])
			ui_content += "<td style='padding-left: 5px;padding-right: 5px'>[get_damage_severity(organ["damage_percent"], TRUE)]</td>"
		else
			ui_content += "<td style='padding-left: 5px;padding-right: 5px'>None</td>"

		ui_content += {"
			<td style='padding-left: 5px;padding-right: 5px'>
				[span_bad("[english_list(organ["scan_results"], nothing_text="&nbsp;")]")]
			</td>
		</tr>
		"}

	if(scan["nearsight"])
		ui_content += "<tr><td colspan='3'>[span_average( "Retinal misalignment detected.")]</td></tr>"

	ui_content += "</table></center></td></tr>"
	ui_content += "</table></fieldset>"


	popup.set_content(jointext(ui_content, ""))
	popup.open(user)
