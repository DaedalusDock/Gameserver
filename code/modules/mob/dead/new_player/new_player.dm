/mob/dead/new_player
	flags_1 = NONE
	invisibility = INVISIBILITY_ABSTRACT
	density = FALSE
	stat = DEAD
	hud_possible = list()

	var/datum/new_player_panel/npp

	var/ready = FALSE
	/// Referenced when you want to delete the new_player later on in the code.
	var/spawning = FALSE
	/// For instant transfer once the round is set up
	var/mob/living/new_character
	///Used to make sure someone doesn't get spammed with messages if they're ineligible for roles.
	var/ineligible_for_roles = FALSE

/mob/dead/new_player/Initialize(mapload)
	if(length(GLOB.newplayer_start))
		forceMove(pick(GLOB.newplayer_start))
	else
		forceMove(locate(1,1,1))

	npp = new(src)
	. = ..()

	GLOB.new_player_list += src

/mob/dead/new_player/Destroy()
	GLOB.new_player_list -= src
	QDEL_NULL(npp)
	return ..()

/mob/dead/new_player/prepare_huds()
	return

/mob/dead/new_player/Topic(href, href_list)
	if(usr != src)
		return

	if(href_list["refresh"])
		src << browse(null, "window=playersetup") //closes the player setup window
		npp.open()

//When you cop out of the round (NB: this HAS A SLEEP FOR PLAYER INPUT IN IT)
/mob/dead/new_player/proc/make_me_an_observer(skip_check)
	if(QDELETED(src) || !src.client || src.client.restricted_mode)
		ready = PLAYER_NOT_READY
		return FALSE

	var/less_input_message
	if(SSlag_switch.measures[DISABLE_DEAD_KEYLOOP])
		less_input_message = " - Notice: Observer freelook is currently disabled."

	var/this_is_like_playing_right
	if(!skip_check)
		// Don't convert this to tgui please, it's way too important
		this_is_like_playing_right = alert(usr, "Are you sure you wish to observe? You will not be able to play this round![less_input_message]", "Observe", "Yes", "No")

	if(QDELETED(src) || !src.client || (!skip_check && (this_is_like_playing_right != "Yes")))
		ready = PLAYER_NOT_READY
		src << browse(null, "window=playersetup") //closes the player setup window
		npp?.open()
		return FALSE

	var/mob/dead/observer/observer = new(null, TRUE)
	spawning = TRUE

	close_spawn_windows()
	var/obj/effect/landmark/observer_start/O = locate(/obj/effect/landmark/observer_start) in GLOB.landmarks_list
	to_chat(src, span_notice("Now teleporting."))
	if (O)
		observer.forceMove(O.loc)
	else
		to_chat(src, span_notice("Teleporting failed. Ahelp an admin please"))
		stack_trace("There's no freaking observer landmark available on this map or you're making observers before the map is initialised")
	observer.key = key
	observer.client = client
	observer.restore_ghost_appearance()
	if(observer.client && observer.client.prefs)
		observer.set_real_name(observer.client.prefs.read_preference(/datum/preference/name/real_name))
		observer.client.init_verbs()
	observer.stop_sound_channel(CHANNEL_LOBBYMUSIC)
	deadchat_broadcast(" has observed.", "<b>[observer.real_name]</b>", follow_target = observer, turf_target = get_turf(observer), message_type = DEADCHAT_DEATHRATTLE)
	QDEL_NULL(mind)
	qdel(src)
	return TRUE

/proc/get_job_unavailable_error_message(retval, jobtitle)
	switch(retval)
		if(JOB_AVAILABLE)
			return "[jobtitle] is available."
		if(JOB_UNAVAILABLE_GENERIC)
			return "[jobtitle] is unavailable."
		if(JOB_UNAVAILABLE_BANNED)
			return "You are currently banned from [jobtitle]."
		if(JOB_UNAVAILABLE_PLAYTIME)
			return "You do not have enough relevant playtime for [jobtitle]."
		if(JOB_UNAVAILABLE_ACCOUNTAGE)
			return "Your account is not old enough for [jobtitle]."
		if(JOB_UNAVAILABLE_SLOTFULL)
			return "[jobtitle] is already filled to capacity."
		if(JOB_UNAVAILABLE_ANTAG_INCOMPAT)
			return "[jobtitle] is not compatible with some antagonist role assigned to you."
	return "Error: Unknown job availability."

/mob/dead/new_player/proc/IsJobUnavailable(rank, latejoin = FALSE)
	var/datum/job/job = SSjob.GetJob(rank)
	if(!(job.job_flags & JOB_NEW_PLAYER_JOINABLE))
		return JOB_UNAVAILABLE_GENERIC
	if((job.current_positions >= job.total_positions) && job.total_positions != -1)
		if(is_assistant_job(job))
			if(isnum(client.player_age) && client.player_age <= 14) //Newbies can always be assistants
				return JOB_AVAILABLE
			for(var/datum/job/other_job as anything in SSjob.joinable_occupations)
				if(other_job.current_positions < other_job.total_positions && other_job != job)
					return JOB_UNAVAILABLE_SLOTFULL
		else
			return JOB_UNAVAILABLE_SLOTFULL

	var/eligibility_check = SSjob.check_job_eligibility(src, job, "Mob IsJobUnavailable")
	if(eligibility_check != JOB_AVAILABLE)
		return eligibility_check

	if(latejoin && !job.special_check_latejoin(client))
		return JOB_UNAVAILABLE_GENERIC
	return JOB_AVAILABLE

/mob/dead/new_player/proc/AttemptLateSpawn(rank)
	var/error = IsJobUnavailable(rank)
	if(error != JOB_AVAILABLE)
		tgui_alert(usr, get_job_unavailable_error_message(error, rank))
		return FALSE

	if(SSshuttle.arrivals)
		close_spawn_windows() //In case we get held up
		if(SSshuttle.arrivals.damaged && CONFIG_GET(flag/arrivals_shuttle_require_safe_latejoin))
			src << tgui_alert(usr,"The arrivals shuttle is currently malfunctioning! You cannot join.")
			return FALSE

		if(CONFIG_GET(flag/arrivals_shuttle_require_undocked))
			SSshuttle.arrivals.RequireUndocked(src)

	//Remove the player from the join queue if he was in one and reset the timer
	SSticker.queued_players -= src
	SSticker.queue_delay = 4

	var/datum/job/job = SSjob.GetJob(rank)

	if(!SSjob.AssignRole(src, job, TRUE))
		tgui_alert(usr, "There was an unexpected error putting you into your requested job. If you cannot join with any job, you should contact an admin.")
		return FALSE

	mind.late_joiner = TRUE
	var/atom/destination = mind.assigned_role.get_latejoin_spawn_point()
	if(!destination)
		CRASH("Failed to find a latejoin spawn point.")
	var/mob/living/character = create_character(destination)
	if(!character)
		CRASH("Failed to create a character for latejoin.")
	transfer_character()

	SSjob.EquipRank(character, job, character.client)
	job.after_latejoin_spawn(character)

	#define IS_NOT_CAPTAIN 0
	#define IS_ACTING_CAPTAIN 1
	#define IS_FULL_CAPTAIN 2
	var/is_captain = IS_NOT_CAPTAIN
	// If we already have a captain, are they a "Captain" rank and are we allowing multiple of them to be assigned?
	if(is_captain_job(job))
		is_captain = IS_FULL_CAPTAIN

	// If we don't have an assigned cap yet, check if this person qualifies for some from of captaincy.
	else if(!SSjob.assigned_captain && ishuman(character) && SSjob.chain_of_command[rank] && !is_banned_from(ckey, list(JOB_CAPTAIN)))
		is_captain = IS_ACTING_CAPTAIN

	if(is_captain != IS_NOT_CAPTAIN)
		SSshuttle.arrivals?.OnDock(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(priority_announce), job.get_captaincy_announcement(character), null, null, null, null, FALSE))
		SSjob.promote_to_captain(character, is_captain == IS_ACTING_CAPTAIN)

	#undef IS_NOT_CAPTAIN
	#undef IS_ACTING_CAPTAIN
	#undef IS_FULL_CAPTAIN

	SSticker.minds += character.mind
	character.client.init_verbs() // init verbs for the late join
	var/mob/living/carbon/human/humanc
	if(ishuman(character))
		humanc = character //Let's retypecast the var to be human,

	if(humanc) //These procs all expect humans
		var/chosen_rank = humanc.client?.prefs.alt_job_titles[rank] || rank
		SSdatacore.manifest_inject(humanc, humanc.client)

		if(SSshuttle.arrivals)
			SSshuttle.arrivals.QueueAnnounce(humanc, chosen_rank)
		else
			announce_arrival(humanc, chosen_rank)

		AddEmploymentContract(humanc)

		var/datum/job_department/department = job.departments_list?[1]
		if(department?.department_head == job.type && SSjob.temporary_heads_by_dep[department])
			var/message = "Greetings, [job.title] [humanc.real_name], in your absense, your employee \"[SSjob.temporary_heads_by_dep[department]]\" was granted elevated access to perform your duties."
			aas_pda_message_name(humanc.real_name, DATACORE_RECORDS_STATION, message, "Staff Notice")

		if(GLOB.curse_of_madness_triggered)
			give_madness(humanc, GLOB.curse_of_madness_triggered)

	GLOB.joined_player_list += character.ckey

	if(CONFIG_GET(flag/allow_latejoin_antagonists) && humanc) //Borgs aren't allowed to be antags. Will need to be tweaked if we get true latejoin ais.
		if(SSshuttle.emergency)
			switch(SSshuttle.emergency.mode)
				if(SHUTTLE_RECALL, SHUTTLE_IDLE)
					SSticker.mode.make_antag_chance(humanc)
				if(SHUTTLE_CALL)
					if(SSshuttle.emergency.timeLeft(1) > initial(SSshuttle.emergency_call_time)*0.5)
						SSticker.mode.make_antag_chance(humanc)

	if((job.job_flags & JOB_ASSIGN_QUIRKS) && humanc && CONFIG_GET(flag/roundstart_traits))
		SSquirks.AssignQuirks(humanc, humanc.client)

	log_manifest(character.mind.key,character.mind,character,latejoin = TRUE)

	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, character, rank)


/mob/dead/new_player/proc/AddEmploymentContract(mob/living/carbon/human/employee)
	//TODO:  figure out a way to exclude wizards/nukeops/demons from this.
	for(var/C in GLOB.employmentCabinets)
		var/obj/structure/filingcabinet/employment/employmentCabinet = C
		if(!employmentCabinet.virgin)
			employmentCabinet.addFile(employee)

/// Creates, assigns and returns the new_character to spawn as. Assumes a valid mind.assigned_role exists.
/mob/dead/new_player/proc/create_character(atom/destination)
	spawning = TRUE
	close_spawn_windows()

	mind.active = FALSE //we wish to transfer the key manually
	var/mob/living/spawning_mob = mind.assigned_role.get_spawn_mob(client, destination)
	if(QDELETED(src) || !client)
		return // Disconnected while checking for the appearance ban.
	if(!isAI(spawning_mob)) // Unfortunately there's still snowflake AI code out there.
		// transfer_to sets mind to null
		var/datum/mind/preserved_mind = mind
		preserved_mind.transfer_to(spawning_mob) //won't transfer key since the mind is not active
		preserved_mind.set_original_character(spawning_mob)
	client.init_verbs()
	. = spawning_mob
	new_character = .


/mob/dead/new_player/proc/transfer_character()
	. = new_character
	if(!.)
		return
	new_character.key = key //Manually transfer the key to log them in,
	new_character.stop_sound_channel(CHANNEL_LOBBYMUSIC)
	new_character.client?.show_location_blurb()
	var/area/joined_area = get_area(new_character.loc)
	if(joined_area)
		joined_area.on_joining_game(new_character)
	new_character = null
	qdel(src)

/mob/dead/new_player/Move()
	return 0

/mob/dead/new_player/proc/close_spawn_windows()
	src << browse(null, "window=playersetup")
	src << browse(null, "window=latechoices") //closes late choices window (Hey numbnuts go make this tgui)

// Used to make sure that a player has a valid job preference setup, used to knock players out of eligibility for anything if their prefs don't make sense.
// A "valid job preference setup" in this situation means at least having one job set to low, or not having "return to lobby" enabled
// Prevents "antag rolling" by setting antag prefs on, all jobs to never, and "return to lobby if preferences not available"
// Doing so would previously allow you to roll for antag, then send you back to lobby if you didn't get an antag role
// This also does some admin notification and logging as well, as well as some extra logic to make sure things don't go wrong
/mob/dead/new_player/proc/check_preferences()
	var/client/mob_client = GET_CLIENT(src)
	if(!mob_client)
		return FALSE //Not sure how this would get run without the mob having a client, but let's just be safe.

	var/list/job_priority = client.prefs.read_preference(/datum/preference/blob/job_priority)
	var/datum/employer/employer_path = client.prefs.read_preference(/datum/preference/choiced/employer)

	var/write_pref = FALSE
	for(var/job_name in job_priority)
		var/datum/job/J = SSjob.GetJob(job_name)
		if(!(employer_path in J.employers))
			job_priority -= job_name
			write_pref = TRUE

	if(write_pref)
		to_chat(src, span_danger("One or more jobs did not fit your current employer and have been removed in your selection."))
		client.prefs.write_preference(/datum/preference/blob/job_priority, job_priority)

	if(mob_client.prefs.read_preference(/datum/preference/choiced/jobless_role) != RETURNTOLOBBY)
		return TRUE

	// If they have antags enabled, they're potentially doing this on purpose instead of by accident. Notify admins if so.
	var/has_antags = FALSE
	var/num_antags = 0
	var/list/client_antags = client.prefs.read_preference(/datum/preference/blob/antagonists)
	for(var/antagonist in client_antags)
		if(client_antags[antagonist])
			has_antags = TRUE
			num_antags++

	if(job_priority.len == 0)
		if(!ineligible_for_roles)
			to_chat(src, span_danger("You have no jobs enabled, along with return to lobby if job is unavailable. This makes you ineligible for any round start role, please update your job preferences."))
		ineligible_for_roles = TRUE
		ready = PLAYER_NOT_READY
		if(has_antags)
			log_admin("[src.ckey] has no jobs enabled, return to lobby if job is unavailable enabled and [num_antags] antag preferences enabled. The player has been forcefully returned to the lobby.")
			message_admins("[src.ckey] has no jobs enabled, return to lobby if job is unavailable enabled and [num_antags] antag preferences enabled. This is an old antag rolling technique. The player has been asked to update their job preferences and has been forcefully returned to the lobby.")
		return FALSE //This is the only case someone should actually be completely blocked from antag rolling as well
	return TRUE

/**
 * Prepares a client for the interview system, and provides them with a new interview
 *
 * This proc will both prepare the user by removing all verbs from them, as well as
 * giving them the interview form and forcing it to appear.
 */
/mob/dead/new_player/proc/register_for_interview()
	// Then we create the interview form and show it to the client
	var/datum/interview/I = GLOB.interviews.interview_for_client(client)
	if (I)
		I.ui_interact(src)

	// Add verb for re-opening the interview panel, fixing chat and re-init the verbs for the stat panel
	add_verb(src, /mob/dead/new_player/proc/open_interview, bypass_restricted = TRUE)
	add_verb(client, /client/verb/fix_tgui_panel, bypass_restricted = TRUE)

//Small verb that allows +DEBUG admins to bypass the observer prep lock
/mob/dead/new_player/verb/immediate_observe()
	set desc = "Bypass all safety checks and observe immediately (+DEBUG)"
	if(!check_rights(R_DEBUG))
		return
	//This is bypassing a LOT of safety checks, so we're just going to send this immediately.
	to_chat_immediate(usr, span_userdanger("Bypassing all safety checks and spawning you in immediately.\nDon't complain on the repo if this breaks shit!"))
	make_me_an_observer(1)

/mob/dead/new_player/get_status_tab_items()
	. = ..()
	if(SSticker.HasRoundStarted())
		return

	. += SSticker.player_ready_data
