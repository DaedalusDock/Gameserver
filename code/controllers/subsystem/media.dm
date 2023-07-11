SUBSYSTEM_DEF(media)
	name = "RIAA"

	init_order = INIT_ORDER_MEDIA //We need to finish up before SSTicker for lobby music reasons.
	flags = SS_NO_FIRE

	//Media definitions grouped by their `media_tags`, All tracks share the implicit tag `all`
	VAR_PRIVATE/list/datum/media/tracks_by_tag

	var/const/list/byond_sound_formats = list(
		"mid" = TRUE,
		"midi" = TRUE,
		"mod" = TRUE,
		"it" = TRUE,
		"s3m" = TRUE,
		"xm" = TRUE,
		"oxm" = TRUE,
		"wav" = TRUE,
		"ogg" = TRUE,
		"raw" = TRUE,
		"wma" = TRUE,
		"aiff" = TRUE,
		"mp3" = TRUE,
	)

/datum/controller/subsystem/media/Initialize(start_timeofday)
	//I'm not even going to bother supporting the existing jukebox shit. Jsons are easier.
	tracks_by_tag = list()
	var/basedir = "[global.config.directory]/media/jsons/"
	var/invalid_jsons_exist = FALSE
	//Fetch
	for(var/json_record in flist(basedir))
		//Decode
		var/list/json_data = json_decode(file2text("[basedir][json_record]"))

		//Validate
		if(json_data["name"] == "EXAMPLE")
			continue //Skip the example file.

		//Fixup
		var/jd_tag_cache = json_data["media_tags"]+MEDIA_TAG_ALLMEDIA //cache for sanic speed, We add the allmedia check here for universal validations.
		var/jd_full_filepath = "[global.config.directory]/media/[json_data["file"]]"

		//Tag-Specific Validations
		var/tag_error
		for(var/jd_tag in jd_tag_cache)
			switch(jd_tag)
				if(MEDIA_TAG_LOBBYMUSIC_COMMON)
					if(MEDIA_TAG_LOBBYMUSIC_RARE in jd_tag_cache)
						tag_error = list(MEDIA_TAG_LOBBYMUSIC_COMMON, "Track tagged as BOTH COMMON and RARE lobby music.")
						break
				if(MEDIA_TAG_ROUNDEND_COMMON)
					if(MEDIA_TAG_ROUNDEND_RARE in jd_tag_cache)
						tag_error = list(MEDIA_TAG_ROUNDEND_COMMON, "Track tagged as BOTH COMMON and RARE endround music.")
				if(MEDIA_TAG_ALLMEDIA)
					//Validation relevant for ALL tracks.
					if(!json_data["name"])
						tag_error = list(MEDIA_TAG_ALLMEDIA, "Track has no name.")
					if(!fexists(json_data["file"]))
						tag_error = list(MEDIA_TAG_ALLMEDIA, "File [json_data["file"]] does not exist.")
						break
				if(MEDIA_TAG_JUKEBOX)
					//Validation specific to jukebox tracks.
					if(!json_data["duration"])
						tag_error = list(MEDIA_TAG_JUKEBOX, "Jukebox tracks MUST have a valid duration.")
						break

		//Failed Validation?
		if(tag_error)
			log_config("MEDIA: [json_record] INVALID, [tag_error[1]]:[tag_error[2]]")
			if(!invalid_jsons_exist)
				//Only fire this once. Just check config_error...
				invalid_jsons_exist = TRUE
				spawn(0)
					UNTIL(SSmedia.initialized)
					message_admins("MEDIA: At least 1 Media JSON is invalid. Please check config_error.log")
			continue //Skip the track.

		//JSON is fully validated. Wrap it in the datum and add it to the lists.
		var/datum/media/media_datum = new(
			json_data["name"],
			json_data["author"],
			json_data["file"],
			jd_tag_cache,
			json_data["map"],
			json_data["rare"],
			json_data["duration"]
			)
		for(var/jd_tag in jd_tag_cache)
			LAZYADD(tracks_by_tag[jd_tag], media_datum)
		//Tag-specific validation
	return ..()

/datum/controller/subsystem/media/get_track_pool(media_tag)
	var/list/pool = tracks_by_tag[media_tag]
	return pool.Copy()




/datum/media
	/// Name of the track. Should be "friendly".
	var/name
	/// Author of the track.
	var/author
	/// File path of the actual sound.
	var/path
	/// OPTIONAL for LOBBY tagged music, Map-specific tracks.
	var/map
	/// OPTIONAL for LOBBY tagged music, Rarity control flag. 0 By default.
	var/rare
	/// List of Media tags, used to allow tracks to be shared between various pools, such as
	/// lobby tracks also being jukebox playable.
	var/list/media_tags
	/// REQUIRED for JUKEBOX tagged music, Duration of the track in Deciseconds. Yes it's a shit unit, blame BYOND.
	var/duration = 0

/datum/media/New(name, author, path, tags, map, rare, length)
	src.name = name
	src.author = author
	src.path = path
	src.map = map
	src.rare = rare || 0
	media_tags = tags
	duration = length
