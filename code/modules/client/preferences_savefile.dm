//This is the lowest supported version, anything below this is completely obsolete and the entire savefile will be wiped.
#define SAVEFILE_VERSION_MIN 42

//This is the current version, anything below this will attempt to update (if it's not obsolete)
// You do not need to raise this if you are adding new values that have sane defaults.
// Only raise this value when changing the meaning/format/name/layout of an existing value
// where you would want the updater procs below to run
#define SAVEFILE_VERSION_MAX 44

/*
SAVEFILE UPDATING/VERSIONING - 'Simplified', or rather, more coder-friendly ~Carn
	This proc checks if the current directory of the savefile S needs updating
	It is to be used by the load_character and load_preferences procs.
	(S.cd=="/" is preferences, S.cd=="/character[integer]" is a character slot, etc)

	if the current directory's version is below SAVEFILE_VERSION_MIN it will simply wipe everything in that directory
	(if we're at root "/" then it'll just wipe the entire savefile, for instance.)

	if its version is below SAVEFILE_VERSION_MAX but above the minimum, it will load data but later call the
	respective update_preferences() or update_character() proc.
	Those procs allow coders to specify format changes so users do not lose their setups and have to redo them again.

	Failing all that, the standard sanity checks are performed. They simply check the data is suitable, reverting to
	initial() values if necessary.
*/
/datum/preferences/proc/savefile_needs_update(savefile/S)
	var/savefile_version
	READ_FILE(S["version"], savefile_version)

	if(savefile_version < SAVEFILE_VERSION_MIN)
		S.dir.Cut()
		return -2
	if(savefile_version < SAVEFILE_VERSION_MAX)
		return savefile_version
	return -1

//should these procs get fairly long
//just increase SAVEFILE_VERSION_MIN so it's not as far behind
//SAVEFILE_VERSION_MAX and then delete any obsolete if clauses
//from these procs.
//This only really meant to avoid annoying frequent players
//if your savefile is 3 months out of date, then 'tough shit'.

/datum/preferences/proc/update_preferences(current_version, savefile/S)
	return

/datum/preferences/proc/update_character(current_version, savefile/savefile)
	// Job name update 1
	if(current_version < 44)
		var/list/migrate_jobs = list(
			"Head of Security" = JOB_SECURITY_MARSHAL,
			"Detective" = JOB_DETECTIVE,
			"Medical Doctor" = JOB_ACOLYTE,
			"Curator" = JOB_ARCHIVIST,
			"Cargo Technician" = JOB_DECKHAND,
		)

		var/list/job_prefs = read_preference(/datum/preference/blob/job_priority)
		for(var/job in job_prefs)
			if(job in migrate_jobs)
				var/old_value = job_prefs[job]
				job_prefs -= job
				job_prefs[migrate_jobs[job]] = old_value
		write_preference(/datum/preference/blob/job_priority, job_prefs)

	return

/// Called when reading preferences if a savefile update is detected. This proc is for
/// overriding preference datum values before they are sanitized by deserialize()
/datum/preferences/proc/early_update_character(current_version, savefile/savefile)
	if(current_version < 43)
		var/species
		READ_FILE(savefile["species"], species)
		if(species == "felinid")
			write_preference(/datum/preference/choiced/species, SPECIES_HUMAN)

			var/list/augs = read_preference(/datum/preference/blob/augments)
			var/datum/augment_item/implant/ears = GLOB.augment_items[/datum/augment_item/implant/cat_ears]
			var/datum/augment_item/implant/tail = GLOB.augment_items[/datum/augment_item/implant/cat_tail]
			augs[AUGMENT_SLOT_IMPLANTS] = list(
				ears.type = ears.get_choices()[1],
				tail.type = tail.get_choices()[1]
			)
			write_preference(/datum/preference/blob/augments, augs)

/// checks through keybindings for outdated unbound keys and updates them
/datum/preferences/proc/check_keybindings()
	if(!parent)
		return
	var/list/binds_by_key = get_key_bindings_by_key(key_bindings)
	var/list/notadded = list()
	for (var/name in GLOB.keybindings_by_name)
		var/datum/keybinding/kb = GLOB.keybindings_by_name[name]
		if(kb.name in key_bindings)
			continue // key is unbound and or bound to something

		var/addedbind = FALSE
		key_bindings[kb.name] = list()

		if(parent.hotkeys)
			for(var/hotkeytobind in kb.hotkey_keys)
				if(!length(binds_by_key[hotkeytobind]) && hotkeytobind != "Unbound") //Only bind to the key if nothing else is bound expect for Unbound
					key_bindings[kb.name] |= hotkeytobind
					addedbind = TRUE
		else
			for(var/classickeytobind in kb.classic_keys)
				if(!length(binds_by_key[classickeytobind]) && classickeytobind != "Unbound") //Only bind to the key if nothing else is bound expect for Unbound
					key_bindings[kb.name] |= classickeytobind
					addedbind = TRUE

		if(!addedbind)
			notadded += kb
	save_preferences() //Save the players pref so that new keys that were set to Unbound as default are permanently stored
	if(length(notadded))
		addtimer(CALLBACK(src, PROC_REF(announce_conflict), notadded), 5 SECONDS)

/datum/preferences/proc/announce_conflict(list/notadded)
	to_chat(parent, "<span class='warningplain'><b><u>Keybinding Conflict</u></b></span>\n\
					<span class='warningplain'><b>There are new <a href='?src=[REF(src)];open_keybindings=1'>keybindings</a> that default to keys you've already bound. The new ones will be unbound.</b></span>")
	for(var/item in notadded)
		var/datum/keybinding/conflicted = item
		to_chat(parent, span_danger("[conflicted.category]: [conflicted.full_name] needs updating"))


/datum/preferences/proc/load_path(ckey,filename="preferences.sav")
	if(!ckey)
		return
	path = "data/player_saves/[ckey[1]]/[ckey]/[filename]"

/datum/preferences/proc/load_preferences()
	if(!path)
		return FALSE
	if(!fexists(path))
		return FALSE

	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/"

	var/needs_update = savefile_needs_update(S)
	if(needs_update == -2) //fatal, can't load any data
		var/bacpath = "[path].updatebac" //todo: if the savefile version is higher then the server, check the backup, and give the player a prompt to load the backup
		if (fexists(bacpath))
			fdel(bacpath) //only keep 1 version of backup
		fcopy(S, bacpath) //byond helpfully lets you use a savefile for the first arg.
		return FALSE

	apply_all_client_preferences()

	//general preferences
	READ_FILE(S["lastchangelog"], lastchangelog)

	READ_FILE(S["default_slot"], default_slot)
	READ_FILE(S["chat_toggles"], chat_toggles)
	READ_FILE(S["toggles"], toggles)
	READ_FILE(S["ignoring"], ignoring)

	// OOC commendations
	READ_FILE(S["hearted_until"], hearted_until)
	if(hearted_until > world.realtime)
		hearted = TRUE
	//favorite outfits
	READ_FILE(S["favorite_outfits"], favorite_outfits)

	var/list/parsed_favs = list()
	for(var/typetext in favorite_outfits)
		var/datum/outfit/path = text2path(typetext)
		if(ispath(path)) //whatever typepath fails this check probably doesn't exist anymore
			parsed_favs += path
	favorite_outfits = unique_list(parsed_favs)

	// Custom hotkeys
	READ_FILE(S["key_bindings"], key_bindings)

	//try to fix any outdated data if necessary
	if(needs_update >= 0)
		var/bacpath = "[path].updatebac" //todo: if the savefile version is higher then the server, check the backup, and give the player a prompt to load the backup
		if (fexists(bacpath))
			fdel(bacpath) //only keep 1 version of backup
		fcopy(S, bacpath) //byond helpfully lets you use a savefile for the first arg.
		update_preferences(needs_update, S) //needs_update = savefile_version if we need an update (positive integer)

	//Sanitize
	lastchangelog = sanitize_text(lastchangelog, initial(lastchangelog))
	default_slot = sanitize_integer(default_slot, 1, max_save_slots, initial(default_slot))
	toggles = sanitize_integer(toggles, 0, SHORT_REAL_LIMIT-1, initial(toggles))
	key_bindings = sanitize_keybindings(key_bindings)
	favorite_outfits = SANITIZE_LIST(favorite_outfits)

	check_keybindings() // this apparently fails every time and overwrites any unloaded prefs with the default values, so don't load anything after this line or it won't actually save
	key_bindings_by_key = get_key_bindings_by_key(key_bindings)

	if(needs_update >= 0) //save the updated version
		var/old_default_slot = default_slot
		var/old_max_save_slots = max_save_slots

		for (var/slot in S.dir) //but first, update all current character slots.
			if (copytext(slot, 1, 10) != "character")
				continue
			var/slotnum = text2num(copytext(slot, 10))
			if (!slotnum)
				continue
			max_save_slots = max(max_save_slots, slotnum) //so we can still update byond member slots after they lose memeber status
			default_slot = slotnum
			if (load_character())
				save_character()
		default_slot = old_default_slot
		max_save_slots = old_max_save_slots
		save_preferences()

	return TRUE

/datum/preferences/proc/save_preferences()
	if(!path)
		return FALSE
	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/"

	WRITE_FILE(S["version"] , SAVEFILE_VERSION_MAX) //updates (or failing that the sanity checks) will ensure data is not invalid at load. Assume up-to-date

	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		if (preference.savefile_identifier != PREFERENCE_PLAYER)
			continue

		if (!(preference.type in recently_updated_keys))
			continue

		recently_updated_keys -= preference.type

		if (preference_type in value_cache)
			write_preference(preference, preference.serialize(value_cache[preference_type]))

	//general preferences
	WRITE_FILE(S["lastchangelog"], lastchangelog)
	WRITE_FILE(S["default_slot"], default_slot)
	WRITE_FILE(S["toggles"], toggles)
	WRITE_FILE(S["chat_toggles"], chat_toggles)
	WRITE_FILE(S["ignoring"], ignoring)
	WRITE_FILE(S["key_bindings"], key_bindings)
	WRITE_FILE(S["hearted_until"], (hearted_until > world.realtime ? hearted_until : null))
	WRITE_FILE(S["favorite_outfits"], favorite_outfits)
	return TRUE

/datum/preferences/proc/load_character(slot)
	SHOULD_NOT_SLEEP(TRUE)

	if(!path)
		return FALSE
	if(!fexists(path))
		return FALSE

	character_savefile = null

	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/"
	if(!slot)
		slot = default_slot
	slot = sanitize_integer(slot, 1, max_save_slots, initial(default_slot))
	if(slot != default_slot)
		default_slot = slot
		WRITE_FILE(S["default_slot"] , slot)

	S.cd = "/character[slot]"
	var/needs_update = savefile_needs_update(S)
	if(needs_update == -2) //fatal, can't load any data
		return FALSE

	if(needs_update >= 0)
		early_update_character(needs_update, S)

	// Read everything into cache
	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		if (preference.savefile_identifier != PREFERENCE_CHARACTER)
			continue

		value_cache -= preference_type
		read_preference(preference_type)

	//Load prefs
	READ_FILE(S["alt_job_titles"], alt_job_titles)

	//try to fix any outdated data if necessary
	//preference updating will handle saving the updated data for us.
	if(needs_update >= 0)
		update_character(needs_update, S) //needs_update == savefile_version if we need an update (positive integer)

	var/mob/dead/new_player/body = parent?.mob
	if(istype(body))
		spawn(-1)
			body.npp.open()

	return TRUE

/datum/preferences/proc/save_character()
	SHOULD_NOT_SLEEP(TRUE)

	if(!path)
		return FALSE
	var/savefile/S = new /savefile(path)
	if(!S)
		return FALSE
	S.cd = "/character[default_slot]"

	for (var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if (preference.savefile_identifier != PREFERENCE_CHARACTER)
			continue

		if (!(preference.type in recently_updated_keys))
			continue

		recently_updated_keys -= preference.type

		if (preference.type in value_cache)
			write_preference(preference, preference.serialize(value_cache[preference.type]))

	WRITE_FILE(S["version"] , SAVEFILE_VERSION_MAX) //load_character will sanitize any bad data, so assume up-to-date.)

	//Write prefs
	WRITE_FILE(S["alt_job_titles"], alt_job_titles)

	return TRUE

/proc/sanitize_keybindings(value)
	var/list/base_bindings = sanitize_islist(value,list())
	for(var/keybind_name in base_bindings)
		if (!(keybind_name in GLOB.keybindings_by_name))
			base_bindings -= keybind_name
	return base_bindings

#undef SAVEFILE_VERSION_MAX
#undef SAVEFILE_VERSION_MIN

#ifdef TESTING
//DEBUG
//Some crude tools for testing savefiles
//path is the savefile path
/client/verb/savefile_export(path as text)
	var/savefile/S = new /savefile(path)
	S.ExportText("/",file("[path].txt"))
//path is the savefile path
/client/verb/savefile_import(path as text)
	var/savefile/S = new /savefile(path)
	S.ImportText("/",file("[path].txt"))

#endif
