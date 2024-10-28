/datum/preference/toggle/monochrome_ghost
	category = PREFERENCE_CATEGORY_GAME_PREFERENCES
	savefile_key = "monochrome_ghost"
	savefile_identifier = PREFERENCE_PLAYER

	default_value = TRUE

/datum/preference/toggle/monochrome_ghost/apply_to_client(client/client, value)
	var/mob/dead/observer/M = client.mob
	if(!istype(M))
		return

	M.update_monochrome()
