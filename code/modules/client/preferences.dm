GLOBAL_LIST_EMPTY(preferences_datums)

/datum/preferences
	var/client/parent
	//doohickeys for savefiles
	var/path
	var/default_slot = 1 //Holder so it doesn't default to slot 1, rather the last one used
	var/max_save_slots = 10

	//non-preference stuff
	var/muted = 0
	var/last_ip
	var/last_id

	//game-preferences
	var/lastchangelog = "" //Saved changlog filesize to detect if there was a change

	//Antag preferences
	var/list/be_special = list() //Special role selection

	/// Custom keybindings. Map of keybind names to keyboard inputs.
	/// For example, by default would have "swap_hands" -> list("X")
	var/list/key_bindings = list()

	/// Cached list of keybindings, mapping keys to actions.
	/// For example, by default would have "X" -> list("swap_hands")
	var/list/key_bindings_by_key = list()

	var/toggles = TOGGLES_DEFAULT
	var/db_flags
	var/chat_toggles = TOGGLES_DEFAULT_CHAT
	var/ghost_form = "ghost"

	//character preferences
	var/slot_randomized //keeps track of round-to-round randomization of the character slot, prevents overwriting

	var/list/randomise = list()

	//Quirk list
	var/list/all_quirks = list()

	//Job preferences 2.0 - indexed by job title , no key or value implies never
	var/list/job_preferences = list()

	/// The current window, PREFERENCE_TAB_* in [`code/__DEFINES/preferences.dm`]
	var/current_window = PREFERENCE_TAB_CHARACTER_PREFERENCES

	var/unlock_content = 0

	var/list/ignoring = list()

	var/list/exp = list()

	var/action_buttons_screen_locs = list()

	///Someone thought we were nice! We get a little heart in OOC until we join the server past the below time (we can keep it until the end of the round otherwise)
	var/hearted
	///If we have a hearted commendations, we honor it every time the player loads preferences until this time has been passed
	var/hearted_until
	///What outfit typepaths we've favorited in the SelectEquipment menu
	var/list/favorite_outfits = list()

	/// A preview of the current character
	var/atom/movable/screen/character_preview_view/character_preview_view

	/// A list of instantiated middleware
	var/list/datum/preference_middleware/middleware = list()

	/// The savefile relating to core preferences, PREFERENCE_PLAYER
	var/savefile/game_savefile

	/// The savefile relating to character preferences, PREFERENCE_CHARACTER
	var/savefile/character_savefile

	/// A list of keys that have been updated since the last save.
	var/list/recently_updated_keys = list()

	/// A cache of preference entries to values.
	/// Used to avoid expensive READ_FILE every time a preference is retrieved.
	var/value_cache = list()

	/// If set to TRUE, will update character_profiles on the next ui_data tick.
	var/tainted_character_profiles = FALSE

/datum/preferences/Destroy(force, ...)
	QDEL_NULL(character_preview_view)
	QDEL_LIST(middleware)
	value_cache = null
	return ..()

/datum/preferences/New(client/C)
	parent = C

	for (var/middleware_type in subtypesof(/datum/preference_middleware))
		middleware += new middleware_type(src)

	html_new(C)

	if(istype(C))
		if(!is_guest_key(C.key))
			load_path(C.ckey)
			unlock_content = !!C.IsByondMember()
			if(unlock_content)
				max_save_slots = 15

	// give them default keybinds and update their movement keys
	key_bindings = deep_copy_list(GLOB.default_hotkeys)
	key_bindings_by_key = get_key_bindings_by_key(key_bindings)
	randomise = get_default_randomization()

	var/loaded_preferences_successfully = load_preferences()
	if(loaded_preferences_successfully)
		if(load_character())
			return
	//we couldn't load character data so just randomize the character appearance + name
	randomise_appearance_prefs() //let's create a random character then - rather than a fat, bald and naked man.
	if(C)
		apply_all_client_preferences()
		C.set_macros()

	if(!loaded_preferences_successfully)
		save_preferences()
	save_character() //let's save this new random character so it doesn't keep generating new ones.

/datum/preferences/ui_interact(mob/user, datum/tgui/ui)
	// If you leave and come back, re-register the character preview
	if (!isnull(character_preview_view) && !(character_preview_view in user.client?.screen))
		user.client?.register_map_obj(character_preview_view)

	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "PreferencesMenu")
		ui.set_autoupdate(FALSE)
		ui.open()

		// HACK: Without this the character starts out really tiny because of some BYOND bug.
		// You can fix it by changing a preference, so let's just forcably update the body to emulate this.
		addtimer(CALLBACK(character_preview_view, TYPE_PROC_REF(/atom/movable/screen/character_preview_view, update_body)), 1 SECONDS)

/datum/preferences/ui_state(mob/user)
	return GLOB.always_state

// Without this, a hacker would be able to edit other people's preferences if
// they had the ref to Topic to.
/datum/preferences/ui_status(mob/user, datum/ui_state/state)
	return user.client == parent ? UI_INTERACTIVE : UI_CLOSE

/datum/preferences/ui_data(mob/user)
	var/list/data = list()

	if (isnull(character_preview_view))
		character_preview_view = create_character_preview_view(user)
	else if (character_preview_view.client != parent)
		// The client re-logged, and doing this when they log back in doesn't seem to properly
		// carry emissives.
		character_preview_view.register_to_client(parent)

	if (tainted_character_profiles)
		data["character_profiles"] = create_character_profiles()
		tainted_character_profiles = FALSE

	//PARIAH EDIT BEGIN
	data["preview_options"] = list(PREVIEW_PREF_JOB, PREVIEW_PREF_LOADOUT, PREVIEW_PREF_UNDERWEAR)
	data["preview_selection"] = preview_pref
	//PARIAH EDIT END

	data["character_preferences"] = compile_character_preferences(user)

	data["active_slot"] = default_slot

	for (var/datum/preference_middleware/preference_middleware as anything in middleware)
		data += preference_middleware.get_ui_data(user)

	return data

/datum/preferences/ui_static_data(mob/user)
	var/list/data = list()

	data["character_profiles"] = create_character_profiles()

	data["character_preview_view"] = character_preview_view.assigned_map
	data["overflow_role"] = SSjob.GetJobType(SSjob.overflow_role).title
	data["window"] = current_window

	data["content_unlocked"] = unlock_content

	for (var/datum/preference_middleware/preference_middleware as anything in middleware)
		data += preference_middleware.get_ui_static_data(user)

	return data

/datum/preferences/ui_assets(mob/user)
	var/list/assets = list(
		get_asset_datum(/datum/asset/spritesheet/preferences),
		get_asset_datum(/datum/asset/json/preferences),
	)

	for (var/datum/preference_middleware/preference_middleware as anything in middleware)
		assets += preference_middleware.get_ui_assets()

	return assets

/datum/preferences/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if (.)
		return

	switch (action)
		if ("change_slot")
			// Save existing character
			save_character()

			// SAFETY: `load_character` performs sanitization the slot number
			if (!load_character(params["slot"]))
				tainted_character_profiles = TRUE
				randomise_appearance_prefs()
				save_character()

			for (var/datum/preference_middleware/preference_middleware as anything in middleware)
				preference_middleware.on_new_character(usr)

			character_preview_view.update_body()

			return TRUE
		if ("rotate")
			character_preview_view.dir = turn(character_preview_view.dir, -90)

			return TRUE
		if ("set_preference")
			var/requested_preference_key = params["preference"]
			var/value = params["value"]

			for (var/datum/preference_middleware/preference_middleware as anything in middleware)
				if (preference_middleware.pre_set_preference(usr, requested_preference_key, value))
					return TRUE

			var/datum/preference/requested_preference = GLOB.preference_entries_by_key[requested_preference_key]
			if (isnull(requested_preference))
				return FALSE

			// SAFETY: `update_preference` performs validation checks
			if (!update_preference(requested_preference, value))
				return FALSE

			if (istype(requested_preference, /datum/preference/name))
				tainted_character_profiles = TRUE

			return TRUE
		if ("set_color_preference")
			var/requested_preference_key = params["preference"]

			var/datum/preference/requested_preference = GLOB.preference_entries_by_key[requested_preference_key]
			if (isnull(requested_preference))
				return FALSE

			if (!istype(requested_preference, /datum/preference/color))
				return FALSE

			var/default_value = read_preference(requested_preference.type)

			// Yielding
			var/new_color = input(
				usr,
				"Select new color",
				null,
				default_value || COLOR_WHITE,
			) as color | null

			if (!new_color)
				return FALSE

			if (!update_preference(requested_preference, new_color))
				return FALSE

			return TRUE

		//PARIAH EDIT ADDITION
		if("update_preview")
			preview_pref = params["updated_preview"]
			character_preview_view.update_body()
			return TRUE

		if ("open_loadout")
			if(parent.open_loadout_ui)
				parent.open_loadout_ui.ui_interact(usr)
			else
				var/datum/loadout_manager/tgui = new(usr)
				tgui.ui_interact(usr)
			return TRUE
		//PARIAH EDIT END

		if ("set_tricolor_preference")
			var/requested_preference_key = params["preference"]
			var/index_key = params["value"]

			var/datum/preference/requested_preference = GLOB.preference_entries_by_key[requested_preference_key]
			if (isnull(requested_preference))
				return FALSE

			if (!istype(requested_preference, /datum/preference/tri_color))
				return FALSE

			var/default_value_list = read_preference(requested_preference.type)
			if (!islist(default_value_list))
				return FALSE
			var/default_value = default_value_list[index_key]

			// Yielding
			var/new_color = input(
				usr,
				"Select new color",
				null,
				default_value || COLOR_WHITE,
			) as color | null

			if (!new_color)
				return FALSE

			default_value_list[index_key] = new_color

			if (!update_preference(requested_preference, default_value_list))
				return FALSE

			return TRUE

		if("appearance_mods")
			var/datum/preference/requested_preference = GLOB.preference_entries_by_key["appearance_mods"]
			if (isnull(requested_preference))
				return FALSE

			var/list/prefs = read_preference(/datum/preference/appearance_mods):Copy()
			var/species_type = read_preference(/datum/preference/choiced/species)
			var/list/existing_mods = list()
			//All of pref code is written with the assumption that pref values about to be saved are serialized
			prefs = requested_preference.serialize(prefs)

			for(var/_type in prefs)
				var/datum/appearance_modifier/path = prefs[_type]["path"]
				path = text2path(path)
				existing_mods[initial(path.name)] = _type

			var/list/options = list("Add", "Remove")
			if(length(prefs))
				options += "Modify"

			var/input = input(usr, "Select an action", "Appearance Mods", "Add...") as null|anything in options
			if(!input)
				return FALSE

			switch(input)
				if("Add")
					var/list/add_new = global.ModManager.modnames_by_species[species_type] ^ existing_mods
					var/choice = tgui_input_list(usr, "Add Appearance Mod", "Appearance Mods", add_new)
					if(!choice)
						return FALSE

					var/datum/appearance_modifier/mod = global.ModManager.mods_by_name[choice]
					var/list/new_mod_data = list(
						"path" = "[mod.type]",
						"color" = "#FFFFFF",
						"priority" = 0,
						"color_blend" = "[mod.color_blend_func]",
					)

					if(mod.colorable)
						var/color = input(usr, "Appearance Mod Color", "Appearance Mods", COLOR_WHITE) as null|color
						if(!color)
							return FALSE
						new_mod_data["color"] = color

					var/priority = input(usr, "Appearance Mod Priority", "Appearance Mods", 0) as null|num
					if(isnull(priority))
						return

					new_mod_data["priority"] = "[priority]"

					if(!global.ModManager.ValidateSerializedList(new_mod_data))
						return FALSE

					prefs[mod.type] = new_mod_data

					if(!update_preference(requested_preference, prefs))
						return FALSE

					return TRUE

				if("Remove")
					var/name2remove = tgui_input_list(usr, "Remove Appearance Mod", "Appearance Mods", existing_mods)
					if(!name2remove)
						return FALSE

					prefs -= existing_mods[name2remove]
					if(!update_preference(requested_preference, prefs))
						return FALSE
					return TRUE

				if("Modify")
					var/type2modify = tgui_input_list(usr, "Modify Appearance Mod", "Appearance Mods", existing_mods)
					if(!type2modify)
						return FALSE

					var/static/list/modifiable_values = list("priority")
					var/datum/appearance_modifier/type2check = text2path(existing_mods[type2modify])
					if(initial(type2check.colorable))
						modifiable_values += "color"

					var/value2modify = tgui_input_list(usr, "Select Var to Modify", "Appearance Mods", modifiable_values)
					if(!value2modify)
						return FALSE

					switch(value2modify)
						if("color")
							var/color = input(usr, "Appearance Mod Color", "Appearance Mods", COLOR_WHITE) as null|color
							if(!color)
								return FALSE

							prefs[existing_mods[type2modify]]["color"] = color

						if("priority")
							var/priority = input(usr, "Appearance Mod Priority", "Appearance Mods", 0) as null|num
							if(isnull(priority))
								return
							prefs[existing_mods[type2modify]]["priority"] = "[priority]"

					if(!update_preference(requested_preference, prefs))
						return FALSE
					return TRUE


	for (var/datum/preference_middleware/preference_middleware as anything in middleware)
		var/delegation = preference_middleware.action_delegations[action]
		if (!isnull(delegation))
			return call(preference_middleware, delegation)(params, usr)

	return FALSE

/datum/preferences/ui_close(mob/user)
	save_character()
	save_preferences()
	QDEL_NULL(character_preview_view)

/datum/preferences/Topic(href, list/href_list)
	. = ..()
	if (.)
		return

	if (href_list["open_keybindings"])
		current_window = PREFERENCE_TAB_KEYBINDINGS
		update_static_data(usr)
		ui_interact(usr)
		return TRUE

	return html_topic(href, href_list)

/datum/preferences/proc/create_character_preview_view(mob/user)
	character_preview_view = new(null, src, user.client)
	character_preview_view.update_body()
	character_preview_view.register_to_client(user.client)

	return character_preview_view

/datum/preferences/proc/compile_character_preferences(mob/user)
	var/list/preferences = list()

	for (var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if (!preference.is_accessible(src))
			continue

		LAZYINITLIST(preferences[preference.category])

		var/value = read_preference(preference.type)
		var/data = preference.compile_ui_data(user, value)

		preferences[preference.category][preference.savefile_key] = data

	for (var/datum/preference_middleware/preference_middleware as anything in middleware)
		var/list/append_character_preferences = preference_middleware.get_character_preferences(user)
		if (isnull(append_character_preferences))
			continue

		for (var/category in append_character_preferences)
			if (category in preferences)
				preferences[category] += append_character_preferences[category]
			else
				preferences[category] = append_character_preferences[category]

	return preferences

/// Applies all PREFERENCE_PLAYER preferences
/datum/preferences/proc/apply_all_client_preferences()
	for (var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if (preference.savefile_identifier != PREFERENCE_PLAYER)
			continue

		value_cache -= preference.type
		preference.apply_to_client(parent, read_preference(preference.type))

// This is necessary because you can open the set preferences menu before
// the atoms SS is done loading.
INITIALIZE_IMMEDIATE(/atom/movable/screen/character_preview_view)

/// A preview of a character for use in the preferences menu
/atom/movable/screen/character_preview_view
	name = "character_preview"
	del_on_map_removal = FALSE
	layer = GAME_PLANE
	plane = GAME_PLANE

	/// The body that is displayed
	var/mob/living/carbon/human/dummy/body

	/// The preferences this refers to
	var/datum/preferences/preferences

	var/list/plane_masters = list()

	/// The client that is watching this view
	var/client/client

	var/list/atom/movable/screen/subscreens = list()

/atom/movable/screen/character_preview_view/Initialize(mapload, datum/preferences/preferences, client/client)
	. = ..()

	assigned_map = "character_preview_map"

	src.preferences = preferences

/atom/movable/screen/character_preview_view/Destroy()
	QDEL_NULL(body)
	QDEL_LIST_ASSOC_VAL(subscreens)

	for (var/plane_master in plane_masters)
		client?.screen -= plane_master
		qdel(plane_master)

	client?.clear_map(assigned_map)

	preferences?.character_preview_view = null

	client = null
	plane_masters = null
	preferences = null

	return ..()

/// Updates the currently displayed body
/atom/movable/screen/character_preview_view/proc/update_body()
	if (isnull(body))
		create_body()
	else
		body.wipe_state()
	preferences.render_new_preview_appearance(body)
	for(var/index in subscreens)
		var/atom/movable/screen/subscreen = subscreens[index]
		var/cache_dir = subscreen.dir
		subscreen.appearance = body.appearance
		subscreen.dir = cache_dir

/atom/movable/screen/character_preview_view/proc/create_body()
	QDEL_NULL(body)

	body = new

	// Without this, it doesn't show up in the menu
	body.appearance_flags &= ~KEEP_TOGETHER

/// Registers the relevant map objects to a client
/atom/movable/screen/character_preview_view/proc/register_to_client(client/client)
	QDEL_LIST(plane_masters)

	src.client = client

	if (!client)
		return

	for (var/plane_master_type in subtypesof(/atom/movable/screen/plane_master) - /atom/movable/screen/plane_master/blackness)
		var/atom/movable/screen/plane_master/plane_master = new plane_master_type()
		plane_master.screen_loc = "[assigned_map]:0,CENTER"
		client?.screen |= plane_master

		plane_masters += plane_master

	var/pos
	for(var/dir in GLOB.cardinals)
		pos++
		var/atom/movable/screen/subscreen/preview = subscreens["preview-[dir]"]
		if(!preview)
			preview = new
			subscreens["preview-[dir]"] = preview
			client?.register_map_obj(preview)
		preview.appearance = body.appearance
		preview.dir = dir
		preview.set_position(0, pos)


	client?.register_map_obj(src)

INITIALIZE_IMMEDIATE(/atom/movable/screen/subscreen)
/atom/movable/screen/subscreen
	name = "preview_subscreen"
	assigned_map = "character_preview_map"

/datum/preferences/proc/create_character_profiles()
	var/list/profiles = list()

	var/savefile/savefile = new(path)
	for (var/index in 1 to max_save_slots)
		// It won't be updated in the savefile yet, so just read the name directly
		if (index == default_slot)
			profiles += read_preference(/datum/preference/name/real_name)
			continue

		savefile.cd = "/character[index]"

		var/name
		READ_FILE(savefile["real_name"], name)

		if (isnull(name))
			profiles += null
			continue

		profiles += name

	return profiles

/datum/preferences/proc/set_job_preference_level(datum/job/job, level)
	if (!job)
		return FALSE

	if (level == JP_HIGH)
		var/datum/job/overflow_role = SSjob.overflow_role
		var/overflow_role_title = initial(overflow_role.title)

		for(var/other_job in job_preferences)
			if(job_preferences[other_job] == JP_HIGH)
				// Overflow role needs to go to NEVER, not medium!
				if(other_job == overflow_role_title)
					job_preferences[other_job] = null
				else
					job_preferences[other_job] = JP_MEDIUM

	job_preferences[job.title] = level

	return TRUE

/datum/preferences/proc/GetQuirkBalance()
	var/bal = 0
	for(var/V in all_quirks)
		var/datum/quirk/T = SSquirks.quirks[V]
		bal -= initial(T.value)
	return bal

/datum/preferences/proc/GetPositiveQuirkCount()
	. = 0
	for(var/q in all_quirks)
		if(SSquirks.quirk_points[q] > 0)
			.++

/datum/preferences/proc/validate_quirks()
	if(GetQuirkBalance() < 0)
		all_quirks = list()

/// Sanitizes the preferences, applies the randomization prefs, and then applies the preference to the human mob.
/datum/preferences/proc/safe_transfer_prefs_to(mob/living/carbon/human/character, icon_updates = TRUE, is_antag = FALSE)
	apply_character_randomization_prefs(is_antag)
	apply_prefs_to(character, icon_updates)

/// Applies the given preferences to a human mob.
/datum/preferences/proc/apply_prefs_to(mob/living/carbon/human/character, icon_updates = TRUE)
	for (var/datum/preference/preference as anything in get_preferences_in_priority_order())
		if (preference.savefile_identifier != PREFERENCE_CHARACTER)
			continue
		if(preference.requires_accessible && !preference.is_accessible(src))
			continue
		preference.apply_to_human(character, read_preference(preference.type))

	character.dna.real_name = character.real_name

	if(icon_updates)
		character.icon_render_keys = list()
		character.update_body(is_creating = TRUE)


/// Returns whether the parent mob should have the random hardcore settings enabled. Assumes it has a mind.
/datum/preferences/proc/should_be_random_hardcore(datum/job/job, datum/mind/mind)
	if(!read_preference(/datum/preference/toggle/random_hardcore))
		return FALSE
	if(job.departments_bitflags & DEPARTMENT_BITFLAG_COMMAND) //No command staff
		return FALSE
	for(var/datum/antagonist/antag as anything in mind.antag_datums)
		if(antag.get_team()) //No team antags
			return FALSE
	return TRUE

/// Inverts the key_bindings list such that it can be used for key_bindings_by_key
/datum/preferences/proc/get_key_bindings_by_key(list/key_bindings)
	var/list/output = list()

	for (var/action in key_bindings)
		for (var/key in key_bindings[action])
			LAZYADD(output[key], action)

	return output

/// Returns the default `randomise` variable ouptut
/datum/preferences/proc/get_default_randomization()
	var/list/default_randomization = list()

	for (var/preference_key in GLOB.preference_entries_by_key)
		var/datum/preference/preference = GLOB.preference_entries_by_key[preference_key]
		if (preference.is_randomizable() && preference.randomize_by_default)
			default_randomization[preference_key] = RANDOM_ENABLED

	return default_randomization
