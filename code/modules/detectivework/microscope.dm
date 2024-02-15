/obj/machinery/microscope
	name = "electron microscope"
	desc = "A highly advanced microscope capable of zooming up to 3000x."
	icon = 'icons/obj/machines/forensics/microscope.dmi'
	icon_state = "microscope"
	density = TRUE

	var/obj/item/sample
	var/report_num = 0

/obj/machinery/microscope/Destroy()
	QDEL_NULL(sample)
	return ..()

/obj/machinery/microscope/update_overlays()
	. = ..()
	if(!(machine_stat & NOPOWER))
		. += emissive_appearance(icon, "[icon_state]_lights")
		. += "[icon_state]_lights"
	if(sample)
		. += emissive_appearance(icon, "[icon_state]_lights_working")
		. +="[icon_state]_lights_working"

/obj/machinery/microscope/attackby(obj/item/weapon, mob/user, params)
	if(sample)
		to_chat(user, span_warning("There is already a slide in [src]."))
		return

	if(istype(weapon, /obj/item/storage/evidencebag))
		var/obj/item/storage/evidencebag/B = weapon
		if(!length(B.contents))
			return

		var/obj/item/stored = B.contents[1]
		if(B.atom_storage.attempt_remove(stored, src))
			to_chat(user, span_notice("You insert [stored] from [B] into [src]."))
			sample = stored
		return

	if(!user.transferItemToLoc(weapon, src))
		return

	to_chat(user, span_notice("You insert [weapon] into [src]."))
	sample = weapon
	update_appearance(UPDATE_ICON)

/obj/machinery/microscope/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return

	remove_sample(user)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/machinery/microscope/AltClick(mob/user)
	remove_sample(user)

/obj/machinery/microscope/proc/remove_sample(mob/user)
	if(user.incapacitated() || !Adjacent(user))
		return

	if(!sample)
		to_chat(user, span_warning("[src] does not have a sample in it."))
		return

	to_chat(user, span_notice("You remove the sample from [src]."))
	if(!user.put_in_hands(sample))
		sample.forceMove(drop_location())

	sample = null
	update_appearance(UPDATE_ICON)

/obj/machinery/microscope/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	. = TRUE

	if(!sample)
		to_chat(user, span_warning("[src] has no sample to examine."))
		return

	to_chat(user, span_notice("The microscope whirrs as you examine [sample]."))

	if(!do_after(user, src, 5 SECONDS, DO_PUBLIC))
		return

	var/obj/item/paper/report = new()
	report.stamp(100, 320, 0, "stamp-law")

	var/list/evidence = list()
	var/scanned_object = sample.name

	if(istype(sample, /obj/item/swab))
		var/obj/item/swab/swab = sample
		evidence["gunshot_residue"] = swab.sample

	else if(istype(sample, /obj/item/sample/fibers))
		var/obj/item/sample/fibers/fibers = sample
		scanned_object = fibers.label
		evidence["fibers"] = fibers.evidence.Copy()

	else if(istype(sample, /obj/item/sample/print))
		var/obj/item/sample/print/card = sample
		scanned_object = card.label || card.name
		evidence["prints"] = card.evidence.Copy()

	else
		if(length(sample.forensics?.fingerprints))
			evidence["prints"] = sample.return_fingerprints().Copy()
		if(length(sample.forensics?.fibers))
			evidence["fibers"] = sample.return_fibers().Copy()
		if(length(sample.forensics?.gunshot_residue))
			evidence["gunshot_residue"] = sample.return_gunshot_residue().Copy()

	report.name = "Forensic report #[++report_num]: [sample.name]"
	report.info = "<b>Scanned item:</b><br>[scanned_object]<br><br>"

	report.info += "<b>Gunpowder residue analysis</b><br>"
	if(LAZYLEN(evidence["gunshot_residue"]))
		report.info += "<i>Residue from the following bullets detected:</i><br>"
		for(var/residue in evidence["gunshot_residue"])
			report.info += "* [residue]<br>"
	else
		report.info += "<i>None present.</i><br>"

	report.info += "<br><b>Molecular analysis</b><br>"
	if(LAZYLEN(evidence["fibers"]))
		report.info += "<i>Provided sample has the presence of unique fiber strings:</i><br>"
		for(var/fiber in evidence["fibers"])
			report.info += "* Most likely match for fibers: [fiber]<br>"
	else
		report.info += "<i>No fibers found.</i><br>"

	report.info += "<br><b>Fingerprint analysis</b><br>"

	if(LAZYLEN(evidence["prints"]))
		report.info += "<i>Surface analysis has determined unique fingerprint strings:</i><br>"
		for(var/prints in evidence["prints"])
			if(!is_complete_print(evidence["prints"][prints]))
				report.info += "* INCOMPLETE PRINT"
			else
				report.info += "* [prints]"
			report.info += "<br>"
	else
		report.info += "<i>No information available.</i><br>"

	report.forceMove(drop_location())
	return TRUE
