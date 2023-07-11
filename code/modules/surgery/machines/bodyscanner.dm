/obj/machinery/bodyscanner
	name = "body scanner"
	desc = "A large full-body scanning machine that provides a complete physical assessment of a patient placed inside. Operated using an adjacent console."
	icon = 'icons/obj/cryogenics.dmi'
	icon_state = "body_scanner_open"
	dir = EAST
	density = TRUE

	var/obj/machinery/bodyscanner_console/linked_console

/obj/machinery/bodyscanner/Initialize(mapload)
	. = ..()
	if(!(dir & (EAST|WEST)))
		stack_trace("A bodyscanner was initialized with an invalid direction")
		return INITIALIZE_HINT_QDEL

	if(!linked_console)
		var/turf/T = get_step(src, turn(dir, 180))
		if(!T)
			return
		linked_console = locate(/obj/machinery/bodyscanner_console) in T
		if(linked_console)
			linked_console.linked_scanner = src
			linked_console.update_appearance()

/obj/machinery/bodyscanner/Destroy()
	if(!QDELETED(linked_console))
		qdel(linked_console)
	return ..()

/obj/machinery/bodyscanner/update_icon_state()
	. = ..()
	if(occupant)
		icon_state = "body_scanner_closed"
	else
		icon_state = "body_scanner_open"

/obj/machinery/bodyscanner/set_occupant(atom/movable/new_occupant)
	. = ..()
	update_icon_state()

/obj/machinery/bodyscanner/deconstruct(disassembled)
	. = ..()
	if(linked_console)
		linked_console.linked_scanner = null
		linked_console.update_appearance()

/obj/machinery/bodyscanner/MouseDrop_T(mob/living/carbon/human/target, mob/user)
	if(!istype(target) || !can_interact(user) || HAS_TRAIT(user, TRAIT_UI_BLOCKED) || !Adjacent(user, mover = target) || target.buckled || target.has_buckled_mobs())
		return

	if(occupant)
		to_chat(user, span_warning("[src] is currently occupied!"))
		return

	target.forceMove(src)
	set_occupant(target)
	user.visible_message(span_notice("[user] moves [target] into [src]."))

/obj/machinery/bodyscanner/AltClick(mob/user)
	. = ..()
	if(!user.canUseTopic(src, !issilicon(user)))
		return
	eject_occupant()

/obj/machinery/bodyscanner/proc/eject_occupant()
	if(occupant)
		occupant.forceMove(get_turf(src))
		set_occupant(null)

/obj/machinery/bodyscanner/proc/container_resist_act(mob/living/user)
	eject_occupant()

/////// The Console ////////
/obj/machinery/bodyscanner_console
	var/obj/machinery/bodyscanner/linked_scanner
	icon = 'icons/obj/cryogenics.dmi'
	icon_state = "bodyscanner_console_powered"
	dir = EAST

	/// Data! Maybe there's something to be done with data disks here.
	var/list/scan

/obj/machinery/bodyscanner_console/Initialize(mapload)
	. = ..()
	if(!(dir & (EAST|WEST)))
		stack_trace("A bodyscanner console was initialized with an invalid direction")
		return INITIALIZE_HINT_QDEL

	if(!linked_scanner)
		var/turf/T = get_step(src, dir)
		if(!T)
			return
		linked_scanner = locate(/obj/machinery/bodyscanner) in T
		if(linked_scanner)
			linked_scanner.linked_console = src

/obj/machinery/bodyscanner_console/Destroy()
	if(!QDELETED(linked_scanner))
		qdel(linked_scanner)

	return ..()

/obj/machinery/bodyscanner_console/deconstruct(disassembled)
	. = ..()
	if(linked_scanner)
		linked_scanner.linked_console = null

/obj/machinery/bodyscanner_console/update_icon_state()
	. = ..()
	if((machine_stat & NOPOWER) || !linked_scanner)
		icon_state = "bodyscanner_console_unpowered"
	else
		icon_state = "bodyscanner_console_powered"

/obj/machinery/bodyscanner_console/proc/scan_patient()
	if(!linked_scanner?.occupant)
		return

	var/mob/living/carbon/human/H = linked_scanner.occupant
	scan = H.get_bodyscanner_data()
	updateUsrDialog()

/obj/machinery/bodyscanner_console/proc/clear_scan()
	scan = null
	updateUsrDialog()

/obj/machinery/bodyscanner_console/Topic(href, href_list)
	. = ..()
	if(.)
		return

	if(href_list["scan"])
		scan_patient()
		return TRUE

	if(href_list["eject"])
		eject_occupant()
		return TRUE

	if(href_list["erase"])
		clear_scan()
		return TRUE

	if(href_list["send2display"])
		var/choices = list()
		for(var/obj/machinery/body_scan_display/display as anything in GLOB.bodyscanscreens)
			if(!SSmapping.are_same_zstack(src.z, display.z))
				return
			var/name = "[capitalize(display.name)] at [(get_area(display)).name]"
			if(choices[name])
				choices[name + " (1)"] = choices[name]
				name = name + " (2)"
			while(choices[name])
				name = splicetext(name, -4) + " ([(text2num(copytext(name, -2, -1)) + 1)])"

			choices[name] = display

		if(!length(choices))
			return TRUE

		var/choice = input(usr, "Select Display", "Push to Display") as null|anything in choices
		if(!(choice in choices))
			return

		var/obj/machinery/body_scan_display/display = choices[choice]
		display.push_content(jointext(get_content(scan), null))
		return TRUE

/obj/machinery/bodyscanner_console/ui_interact(mob/user, datum/tgui/ui)
	. = ..()

	var/datum/browser/popup = new(user, "bodyscanner", "Body Scanner", 600, 800)
	var/content = {"
		<fieldset class='computerPaneSimple' style='margin: 10px auto;text-align:center'>
				[button_element(src, "Scan", "scan=1")]
				[button_element(src, "Eject Occupant", "eject=1")]
				[button_element(src, "Erase Scan", "erase=1")]
				[button_element(src, "Push to Display", "send2display=1")]
		</fieldset>
	"}

	popup.set_content(content + jointext(get_content(scan), null))
	popup.open()


/obj/machinery/bodyscanner_console/proc/get_content(list/scan)
	RETURN_TYPE(/list)
	. = list()

	. += {"
		<fieldset class='computerPaneSimple' style='margin: 0 auto'>
	"}

	if(!scan)
		. += "<center>["<strong>NO DATA TO DISPLAY</strong>"]</center></fieldset>"
		return

	if(!scan["name"])
		. += "<center>[span_bad("<strong>SCAN READOUT ERROR.</strong>")]</center></fieldset>"
		return

	.+= {"
			<table style='min-width:100%'>
				<tr>
					<td>
						<strong>Scan Results For:</strong>
					</td>
					<td>
						[scan["name"]]
					</td>
				</tr>
				<tr>
					<td>
						<strong>Scan Performed At:</strong>
					</td>
					<td>
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

	. += {"
				<tr>
					<td>
						<strong>Brain Activity:</strong>
					</td>
					<td>
						[brain_activity]
					</td>
				</tr>
	"}

	. += {"
				<tr>
					<td>
						<strong>Blood Volume:</strong>
					</td>
					<td>
						[scan["blood_volume"]]u/[scan["blood_volume_max"]]u
					</td>
				</tr>
	"}

	. += {"
				<tr>
					<td>
						<strong>Body Temperature:</strong>
					</td>
					<td>
						[scan["temperature"]-T0C]&deg;C ([scan["temperature"]*1.8-459.67]&deg;F)
					</td>
				</tr>
	"}

	. += {"
				<tr>
					<td>
						<strong>Physical Trauma:</strong>
					</td>
					<td>
						[get_severity(scan["brute"],TRUE)]
					</td>
				</tr>
	"}

	. += {"
				<tr>
					<td>
						<strong>Burn Severity:</strong>
					</td>
					<td>
						[get_severity(scan["burn"],TRUE)]
					</td>
				</tr>
	"}

	. += {"
				<tr>
					<td>
						<strong>Systematic Organ Failure:</strong>
					</td>
					<td>
						[get_severity(scan["toxin"],TRUE)]
					</td>
				</tr>
	"}

	. += {"
				<tr>
					<td>
						<strong>Oxygen Deprivation:</strong>
					</td>
					<td>
						[get_severity(scan["oxygen"],TRUE)]
					</td>
				</tr>
	"}

	. += {"
				<tr>
					<td>
						<strong>Genetic Damage:</strong>
					</td>
					<td>
						[get_severity(scan["genetic"],TRUE)]
					</td>
				</tr>
	"}

	if(scan["radiation"])
		. += {"
					<tr>
						<td colspan = '2' style='text-align:center'>
							<span style='color: [COLOR_MEDICAL_RADIATION]'>Irradiated</span>
						</td>
					</tr>
					<tr><td colspan='2'></td></tr>
		"}

	if(length(scan["reagents"]))
		. += {"
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
				. += {"
						<tr>
							<td colspan = '2' style='padding-left: 35%'>
								["[R["quantity"]]u [R["name"]]"]
							</td>
						</tr>
				"}
			else
				. += {"
							<tr>
								<td colspan = '2' style='padding-left: 35%'>
									[span_average("Unknown Reagent")]
								</td>
							</tr>
					"}

	. += {"
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
		.+= {"
			<tr>
				<td>[limb["name"]]
				</td>
		"}

		if(limb["is_stump"])
			. += {"
				<td>
					<span style='font-weight: bold; color: [COLOR_MEDICAL_MISSING]'>Missing</span>
				</td>
				<td>
					<span>[english_list(limb["scan_results"], nothing_text = "&nbsp;")]</span>
				</td>
			"}
		else
			. += "<td>"
			if(!(limb["brute_dam"] || limb["burn_dam"]))
				. += "None</td>"

			if(limb["brute_dam"])
				. += {"
					<span style='font-weight: bold; color: [COLOR_MEDICAL_BRUTE]'>[capitalize(get_wound_severity(limb["brute_ratio"]))] physical trauma</span><br>
				"}
			if(limb["burn_dam"])
				. += {"
					<span style='font-weight: bold; color: [COLOR_MEDICAL_BURN]'>[capitalize(get_wound_severity(limb["burn_ratio"]))] burns</span>
					</td>
				"}
			. += {"
				<td>
					<span>[english_list(limb["scan_results"], nothing_text = "&nbsp;")]</span>
				</td>
			"}
		. += "</tr>"

	. += "<tr><th colspan='3'><center>Internal Organs</center></th></tr>"
	for(var/list/organ as anything in scan["organs"])
		. += "<tr><td>[organ["name"]]</td>"

		if(organ["damage_percent"])
			. += "<td>[get_severity(organ["damage_percent"], TRUE)]</td>"
		else
			. += "<td>None</td>"

		. += {"
			<td>
				[span_bad("[english_list(organ["scan_results"], nothing_text="&nbsp;")]")]
			</td>
		</tr>
		"}

	if(scan["nearsight"])
		. += "<tr><td colspan='3'>[span_average( "Retinal misalignment detected.")]</td></tr>"

	. += "</table></center></td></tr>"
	. += "</table></fieldset>"
