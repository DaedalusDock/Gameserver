/datum/forensics
	/// The object we belong to. This can be null.
	var/atom/parent
	/// A k:v list of fingerprint : partial_or_full_print
	var/list/fingerprints
	/// A k:v list of dna : blood_type
	var/list/blood_DNA
	/// A k:v list of fibers : amount
	var/list/fibers
	/// A k:v FLAT list of residues
	var/list/gunshot_residue
	/// A list of DNA
	var/list/trace_DNA
	/// A k:v list of ckey : thing. For admins.
	var/list/admin_log

/datum/forensics/New(parent)
	src.parent = parent

/datum/forensics/Destroy(force, ...)
	parent = null
	return ..()

/// Adds blood dna. Returns TRUE if the blood dna list expanded.
/datum/forensics/proc/add_blood_DNA(list/dna)
	if(!length(dna))
		return
	var/old_len = length(blood_DNA)
	LAZYINITLIST(blood_DNA)
	for(var/dna_hash in dna)
		blood_DNA[dna_hash] = dna[dna_hash]

	check_blood()
	return old_len < length(blood_DNA)

/datum/forensics/proc/add_trace_DNA(list/dna)
	if(!length(dna))
		return
	LAZYINITLIST(trace_DNA)
	trace_DNA |= dna

/// Adds the fingerprint of M to our fingerprint list
/datum/forensics/proc/add_fingerprint(mob/living/M, ignoregloves = FALSE)
	if(!isliving(M))
		if(!iscameramob(M))
			return
		if(isaicamera(M))
			var/mob/camera/ai_eye/ai_camera = M
			if(!ai_camera.ai)
				return
			M = ai_camera.ai

	log_touch(M)

	if(!ishuman(M))
		return

	var/mob/living/carbon/human/H = M
	parent?.add_fibers(H)
	var/obj/item/gloves = H.gloves

	if(gloves) //Check if the gloves (if any) hide fingerprints
		if(!(gloves.body_parts_covered & HANDS) || HAS_TRAIT(gloves, TRAIT_FINGERPRINT_PASSTHROUGH) || HAS_TRAIT(H, TRAIT_FINGERPRINT_PASSTHROUGH))
			ignoregloves = TRUE

		if(!ignoregloves)
			H.gloves.add_fingerprint(H, TRUE) //ignoregloves = 1 to avoid infinite loop.
			return

	add_partial_print(H.get_fingerprints(ignoregloves, H.get_active_hand()))
	return TRUE

/datum/forensics/proc/add_partial_print(full_print)
	PRIVATE_PROC(TRUE)
	LAZYINITLIST(fingerprints)

	if(!fingerprints[full_print])
		fingerprints[full_print] = stars(full_print, rand(0, 70)) //Initial touch, not leaving much evidence the first time.
		return

	switch(max(stringcount(fingerprints[full_print]), 0)) //tells us how many stars are in the current prints.
		if(28 to 32)
			if(prob(1))
				fingerprints[full_print] = full_print // You rolled a one buddy.
			else
				fingerprints[full_print] = stars(full_print, rand(0,40)) // 24 to 32

		if(24 to 27)
			if(prob(3))
				fingerprints[full_print] = full_print //Sucks to be you.
			else
				fingerprints[full_print] = stars(full_print, rand(15, 55)) // 20 to 29

		if(20 to 23)
			if(prob(5))
				fingerprints[full_print] = full_print //Had a good run didn't ya.
			else
				fingerprints[full_print] = stars(full_print, rand(30, 70)) // 15 to 25

		if(16 to 19)
			if(prob(5))
				fingerprints[full_print] = full_print //Welp.
			else
				fingerprints[full_print]  = stars(full_print, rand(40, 100)) // 0 to 21

		if(0 to 15)
			if(prob(5))
				fingerprints[full_print] = stars(full_print, rand(0,50)) // small chance you can smudge.
			else
				fingerprints[full_print] = full_print

/// Adds the fibers of M to our fiber list.
/datum/forensics/proc/add_fibers(mob/living/carbon/human/M)
	LAZYINITLIST(fibers)

	var/fibertext
	var/item_multiplier = isitem(src)? 1.2 : 1

	if(M.wear_suit)
		fibertext = M.wear_suit.get_fibers()
		if(fibertext && prob(10*item_multiplier))
			fibers[fibertext]++
			. = TRUE

		if(!(M.wear_suit.body_parts_covered & CHEST) && M.w_uniform)
			fibertext = M.w_uniform.get_fibers()
			if(fibertext && prob(12*item_multiplier)) //Wearing a suit means less of the uniform exposed.
				fibers[fibertext]++
				. = TRUE

		if(!(M.wear_suit.body_parts_covered & HANDS) && M.gloves)
			fibertext = M.gloves.get_fibers()
			if(fibertext && prob(20*item_multiplier))
				fibers[fibertext]++
				. = TRUE

	else if(M.w_uniform)
		fibertext = M.w_uniform.get_fibers()
		if(fibertext && prob(15*item_multiplier))
			fibers[fibertext]++
			. = TRUE

		if(!(M.w_uniform.body_parts_covered & HANDS) && M.gloves)
			fibertext = M.gloves.get_fibers()
			if(fibertext && prob(20*item_multiplier))
				fibers[fibertext]++
				. = TRUE

	else if(M.gloves)
		fibertext = M.gloves.get_fibers()
		if(fibertext && prob(20*item_multiplier))
			fibers[fibertext]++
			. = TRUE

	return .

/// Adds gunshot residue to our list
/datum/forensics/proc/add_gunshot_residue(text)
	if(!text)
		return

	LAZYOR(gunshot_residue, text)

/// For admins. Logs when mobs players with this thing.
/datum/forensics/proc/log_touch(mob/M)
	if(!isliving(M))
		if(!iscameramob(M))
			return
		if(isaicamera(M))
			var/mob/camera/ai_eye/ai_camera = M
			if(!ai_camera.ai)
				return
			M = ai_camera.ai

	if(!M.ckey)
		return

	var/hasgloves = ""
	if(ishuman(M))
		var/mob/living/carbon/human/H = M
		if(H.gloves)
			hasgloves = "(gloves)"

	var/current_time = time_stamp()

	if(!LAZYACCESS(admin_log, M.ckey))
		LAZYSET(admin_log, M.ckey, "First: \[[current_time]\] \"[M.real_name]\"[hasgloves]. Ckey: [M.ckey]")
	else
		var/laststamppos = findtext(LAZYACCESS(admin_log, M.ckey), "\nLast: ")
		if(laststamppos)
			LAZYSET(admin_log, M.ckey, copytext(admin_log[M.ckey], 1, laststamppos))
		admin_log[M.ckey] += "\nLast: \[[current_time]\] \"[M.real_name]\"[hasgloves]. Ckey: [M.ckey]" //made sure to be existing by if(!LAZYACCESS);else

	parent?.fingerprintslast = M.ckey
	return TRUE

/// Add a list of fingerprints
/datum/forensics/proc/add_fingerprint_list(list/_fingerprints)
	if(!length(_fingerprints))
		return

	LAZYINITLIST(fingerprints)
	for(var/print in _fingerprints) //We use an associative list, make sure we don't just merge a non-associative list into ours.
		if(!fingerprints[print])
			fingerprints[print] = _fingerprints[print]
		else
			fingerprints[print] = stringmerge(fingerprints[print], _fingerprints[print])
	return TRUE

/// Adds a list of fibers.
/datum/forensics/proc/add_fiber_list(list/_fibertext) //list(text)
	if(!length(_fibertext))
		return

	LAZYINITLIST(fibers)

	for(var/fiber in _fibertext) //We use an associative list, make sure we don't just merge a non-associative list into ours.
		fibers[fiber] += _fibertext[fiber]

	return TRUE

/// Adds a list of gunshot residue
/datum/forensics/proc/add_gunshot_residue_list(list/_gunshot_residue)
	if(!length(_gunshot_residue))
		return

	LAZYINITLIST(gunshot_residue)

	gunshot_residue |= _gunshot_residue
	return TRUE

/// see [datum/forensics/proc/log_touch]
/datum/forensics/proc/log_touch_list(list/_hiddenprints)
	if(!length(_hiddenprints))
		return

	LAZYINITLIST(admin_log)
	for(var/i in _hiddenprints) //We use an associative list, make sure we don't just merge a non-associative list into ours.
		admin_log[i] = _hiddenprints[i]
	return TRUE

/// Adds blood to our parent object if we have any
/datum/forensics/proc/check_blood()
	if(!isitem(parent))
		return
	if(!length(blood_DNA))
		return

	parent.AddElement(/datum/element/decal/blood, _color = get_blood_dna_color(blood_DNA))

/// Called by [atom/proc/wash].
/datum/forensics/proc/wash(clean_types)
	if(clean_types & CLEAN_TYPE_FINGERPRINTS)
		wipe_fingerprints()
		wipe_gunshot_residue()
		. ||= TRUE

	if(clean_types & CLEAN_TYPE_BLOOD)
		wipe_blood_DNA()
		. ||= TRUE

	if(clean_types & CLEAN_TYPE_FIBERS)
		wipe_fibers()
		. ||= TRUE

/// Clear fingerprints list.
/datum/forensics/proc/wipe_fingerprints()
	LAZYNULL(fingerprints)
	return TRUE

/// Clear blood dna list.
/datum/forensics/proc/wipe_blood_DNA()
	LAZYNULL(blood_DNA)
	return TRUE

/// Clear fibers list.
/datum/forensics/proc/wipe_fibers()
	LAZYNULL(fibers)
	return TRUE

/// Clear the trace DNA list
/datum/forensics/proc/wipe_trace_DNA()
	LAZYNULL(trace_DNA)
	return TRUE

/// Clear the gunshot residue list.
/datum/forensics/proc/wipe_gunshot_residue()
	LAZYNULL(gunshot_residue)

/// Delete all non-admin evidence
/datum/forensics/proc/remove_evidence()
	wipe_fingerprints()
	wipe_blood_DNA()
	wipe_fibers()
	wipe_gunshot_residue()
