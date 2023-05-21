/datum/preference/blob/quirks
	savefile_identifier = PREFERENCE_CHARACTER
	savefile_key = "quirked_up"

/datum/preference/blob/quirks/deserialize(input, datum/preferences/preferences)
	if(!islist(input))
		return create_default_value()

	SSquirks.filter_invalid_quirks(input)

	if(GetQuirkBalance(input) < 0)
		return create_default_value()

	return input

/datum/preference/blob/quirks/create_default_value()
	return list()

/datum/preference/blob/quirks/proc/GetQuirkBalance(list/all_quirks)
	var/bal = 0
	for(var/V in all_quirks)
		var/datum/quirk/T = SSquirks.quirks[V]
		bal -= initial(T.value)
	return bal

/datum/preference/blob/quirks/proc/GetPositiveQuirkCount(list/all_quirks)
	. = 0
	for(var/q in all_quirks)
		if(SSquirks.quirk_points[q] > 0)
			.++

/datum/preference/blob/quirks/user_edit(mob/user, datum/preferences/prefs, list/params)
	if(params["select"])
		prefs.selected_quirk = params["select"]
		return TRUE

	if(params["toggle_quirk"]) //Deserialize sanitizes this fine so we can accept junk data
		var/quirk = params["toggle_quirk"]
		var/list/user_quirks = prefs.read_preference(type)
		if(quirk in user_quirks)
			user_quirks -= quirk
		else
			user_quirks += quirk
		return prefs.update_preference(src, user_quirks)
