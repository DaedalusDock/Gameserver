#define ROUND_START_MUSIC_LIST "strings/round_start_sounds.txt"

SUBSYSTEM_DEF(ticker)
	name = "Ticker"
	init_order = INIT_ORDER_TICKER

	priority = FIRE_PRIORITY_TICKER
	flags = SS_KEEP_TIMING
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME

	var/current_state = GAME_STATE_STARTUP //state of current round (used by process()) Use the defines GAME_STATE_* !

	/// When TRUE, the round will end next tick or has already ended. Use SSticker.end_round() instead. This var is used by non-gamemodes to end the round.
	VAR_PRIVATE/force_ending = FALSE

	// If true, there is no lobby phase, the game starts immediately.
	#ifndef LOWMEMORYMODE
	var/start_immediately = FALSE
	#else
	var/start_immediately = TRUE
	#endif
	var/setup_done = FALSE //All game setup done including mode post setup and

	var/datum/game_mode/mode = null
	///The name of the gamemode to show at roundstart. This is here to admins can give fake gamemodes.
	var/mode_display_name = null

	///All players that are readied up and about to spawn in.
	var/list/mob/dead/new_player/ready_players

	///Media track for the music played in the lobby
	var/datum/media/login_music
	///Media track for the round end music.
	var/datum/media/credits_music

	var/round_end_sound //music/jingle played when the world reboots
	var/round_end_sound_sent = TRUE //If all clients have loaded it

	var/list/datum/mind/minds = list() //The characters in the game. Used for objective tracking.

	var/delay_end = FALSE //if set true, the round will not restart on it's own
	var/admin_delay_notice = "" //a message to display to anyone who tries to restart the world after a delay
	var/ready_for_reboot = FALSE //all roundend preparation done with, all that's left is reboot

	var/tipped = FALSE //Did we broadcast the tip of the day yet?
	var/selected_tip // What will be the tip of the day?

	var/timeLeft //pregame timer
	var/start_at

	//Deciseconds to add to world.time for station time. Set in initialize.
	var/gametime_offset = 0

	/// Num of players, used for pregame stats on statpanel
	var/totalPlayers = 0
	/// Num of ready players, used for pregame stats on statpanel (only viewable by admins)
	var/totalPlayersReady = 0
	/// Num of ready admins, used for pregame stats on statpanel (only viewable by admins)
	var/total_admins_ready = 0
	/// Data for lobby player stat panels during the pre-game.
	var/list/player_ready_data = list()

	var/queue_delay = 0
	var/list/queued_players = list() //used for join queues when the server exceeds the hard population cap

	var/news_report
	///Round end statistics of the population
	var/list/popcount


	var/roundend_check_paused = FALSE

	var/round_start_time = 0
	var/round_start_timeofday = 0
	var/list/round_start_events
	var/list/round_end_events
	var/mode_result = "undefined"
	var/end_state = "undefined"

	/// People who have been commended and will receive a heart
	var/list/hearts

	/// Why an emergency shuttle was called
	var/emergency_reason

/datum/controller/subsystem/ticker/Initialize(timeofday)
	gametime_offset = rand(0, 23) HOURS

	pick_login_music()
	pick_credits_music()

	if(!GLOB.syndicate_code_phrase)
		GLOB.syndicate_code_phrase = generate_code_phrase(return_list=TRUE)

		var/codewords = jointext(GLOB.syndicate_code_phrase, "|")
		var/regex/codeword_match = new("([codewords])", "ig")

		GLOB.syndicate_code_phrase_regex = codeword_match

	if(!GLOB.syndicate_code_response)
		GLOB.syndicate_code_response = generate_code_phrase(return_list=TRUE)

		var/codewords = jointext(GLOB.syndicate_code_response, "|")
		var/regex/codeword_match = new("([codewords])", "ig")

		GLOB.syndicate_code_response_regex = codeword_match

	if(!GLOB.revolution_code_phrase)
		GLOB.revolution_code_phrase = generate_code_phrase(return_list=TRUE)

		var/codewords = jointext(GLOB.syndicate_code_phrase, "|")
		var/regex/codeword_match = new("([codewords])", "ig")

		GLOB.revolution_code_phrase_regex = codeword_match

	start_at = world.time + (CONFIG_GET(number/lobby_countdown) * 10)
	if(CONFIG_GET(flag/randomize_shift_time))
		gametime_offset = rand(0, 23) HOURS
	else if(CONFIG_GET(flag/shift_time_realtime))
		gametime_offset = world.timeofday

	if(GLOB.is_debug_server)
		mode = new /datum/game_mode/extended

	return ..()

/datum/controller/subsystem/ticker/fire()
	switch(current_state)
		if(GAME_STATE_STARTUP)
			if(Master.initializations_finished_with_no_players_logged_in)
				start_at = world.time + (CONFIG_GET(number/lobby_countdown) * 10)
			for(var/client/C in GLOB.clients)
				window_flash(C, ignorepref = TRUE) //let them know lobby has opened up.
			to_chat(world, span_notice("<b>Welcome to [station_name()]!</b>"))
			var/newround_staple = CONFIG_GET(string/chat_newgame_staple)
			send2chat("New round starting on [SSmapping.config.map_name][newround_staple ? ", [newround_staple]" : null]!", CONFIG_GET(string/chat_announce_new_game))
			current_state = GAME_STATE_PREGAME
			SEND_SIGNAL(src, COMSIG_TICKER_ENTER_PREGAME)

			fire()
		if(GAME_STATE_PREGAME)
				//lobby stats for statpanels
			if(isnull(timeLeft))
				timeLeft = max(0,start_at - world.time)
			totalPlayers = LAZYLEN(GLOB.new_player_list)
			totalPlayersReady = 0
			total_admins_ready = 0
			player_ready_data.Cut()
			var/list/players = list()

			for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
				if(player.ready == PLAYER_READY_TO_PLAY || player.ready == PLAYER_READY_TO_OBSERVE)
					++totalPlayersReady
					if(player.client?.holder)
						++total_admins_ready

					players[player.key] = player

			sortTim(players, GLOBAL_PROC_REF(cmp_text_asc))

			if(CONFIG_GET(flag/show_job_estimation))
				for(var/ckey in players)
					var/mob/dead/new_player/player = players[ckey]
					var/datum/preferences/prefs = player.client?.prefs
					if(!prefs)
						continue
					if(!prefs.read_preference(/datum/preference/toggle/ready_job))
						continue

					var/display = player.client?.holder?.fakekey || ckey
					if(player.ready == PLAYER_READY_TO_OBSERVE)
						player_ready_data += "* [display] as Observer"
						continue

					var/datum/job/J = prefs.get_highest_priority_job()
					if(!J)
						player_ready_data += "* [display] forgot to pick a job!"
						continue
					var/title = prefs.alt_job_titles?[J.title] || J.title
					if(player.ready == PLAYER_READY_TO_PLAY)
						player_ready_data += "* [display] as [title]"

				if(length(player_ready_data))
					player_ready_data.Insert(1, "------------------")
					player_ready_data.Insert(1, "Job Estimation:")
					player_ready_data.Insert(1, "")


			if(start_immediately)
				timeLeft = 0

			//countdown
			if(timeLeft < 0)
				return
			timeLeft -= wait

			if(timeLeft <= 300 && !tipped)
				send_tip_of_the_round(world, selected_tip)
				tipped = TRUE

			if(timeLeft <= 0)
				SEND_SIGNAL(src, COMSIG_TICKER_ENTER_SETTING_UP)
				current_state = GAME_STATE_SETTING_UP
				Master.SetRunLevel(RUNLEVEL_SETUP)
				if(start_immediately)
					fire()

		if(GAME_STATE_SETTING_UP)
			if(!setup())
				//setup failed
				start_immediately = FALSE //If the game failed to start, don't keep trying
				current_state = GAME_STATE_STARTUP
				start_at = world.time + (CONFIG_GET(number/lobby_countdown) * 10)
				timeLeft = null
				Master.SetRunLevel(RUNLEVEL_LOBBY)
				SEND_SIGNAL(src, COMSIG_TICKER_ERROR_SETTING_UP)

		if(GAME_STATE_PLAYING)
			if(mode.datum_flags & DF_ISPROCESSING)
				mode.process(wait * 0.1)
			check_queue()

			if(force_ending || (!roundend_check_paused && mode.check_finished()))
				current_state = GAME_STATE_FINISHED
				toggle_ooc(TRUE) // Turn it on
				toggle_dooc(TRUE)
				declare_completion(force_ending)
				check_maprotate()
				Master.SetRunLevel(RUNLEVEL_POSTGAME)


/datum/controller/subsystem/ticker/proc/setup()
	to_chat(world, span_boldannounce("Starting game..."))
	var/init_start = world.timeofday

	ready_players = list() // This needs to be reset every setup, incase the gamemode fails to start.
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/player = i
		if(player.ready == PLAYER_READY_TO_PLAY && player.mind && player.check_preferences())
			ready_players.Add(player)

	// Set up gamemode, divide up jobs.
	if(!initialize_gamemode())
		return FALSE

	to_chat(world, span_boldannounce("The gamemode is: [get_mode_name()]."))
	if(mode_display_name)
		message_admins("The real gamemode is: [get_mode_name(TRUE)].")
	to_chat(world, "<br><hr><br>")

	CHECK_TICK

	// There may be various config settings that have been set or modified by this point.
	// This is the point of no return before spawning in new players, let's run over the
	// job trim singletons and update them based on any config settings.
	SSid_access.refresh_job_trim_singletons()

	CHECK_TICK

	if(!CONFIG_GET(flag/ooc_during_round))
		toggle_ooc(FALSE) // Turn it off

	CHECK_TICK

	//Shuffle the order of spawn points so they dont always predictably spawn bottom-up and right-to-left
	GLOB.start_landmarks_list = shuffle(GLOB.start_landmarks_list)
	for(var/name in GLOB.start_landmarks_by_name)
		GLOB.start_landmarks_by_name[name] = shuffle(GLOB.start_landmarks_by_name[name])

	create_characters() //Create player characters
	collect_minds()
	equip_characters()

	SSdatacore.generate_manifest()

	transfer_characters() //transfer keys to the new mobs

	for(var/I in round_start_events)
		var/datum/callback/cb = I
		cb.InvokeAsync()
	LAZYCLEARLIST(round_start_events)

	SEND_SIGNAL(src, COMSIG_TICKER_ROUND_STARTING)

	log_world("Game start took [(world.timeofday - init_start)/10]s")
	round_start_time = world.time
	round_start_timeofday = REALTIMEOFDAY
	INVOKE_ASYNC(SSdbcore, TYPE_PROC_REF(/datum/controller/subsystem/dbcore,SetRoundStart))

	to_chat(world, span_notice("<B>Welcome to [station_name()], enjoy your stay!</B>"))
	SEND_SOUND(world, sound(SSstation.announcer.get_rand_welcome_sound()))

	current_state = GAME_STATE_PLAYING
	Master.SetRunLevel(RUNLEVEL_GAME)

	if(SSevents.holidays)
		to_chat(world, span_notice("and..."))
		for(var/holidayname in SSevents.holidays)
			var/datum/holiday/holiday = SSevents.holidays[holidayname]
			to_chat(world, "<h4>[holiday.greet()]</h4>")

	//Setup the antags AFTTTTER theyve gotten their jobs
	mode.setup_antags()
	PostSetup()
	SSticker.ready_players = null
	return TRUE

/datum/controller/subsystem/ticker/proc/PostSetup()
	set waitfor = FALSE
	mode.post_setup()
	GLOB.start_state = new /datum/station_state()
	GLOB.start_state.count()

	var/list/adm = get_admin_counts()
	var/list/allmins = adm["present"]
	send2adminchat("Server", "Round [GLOB.round_id ? "#[GLOB.round_id]:" : "of"] [SSticker.get_mode_name()] has started[allmins.len ? ".":" with no active admins online!"]")
	setup_done = TRUE

	for(var/obj/effect/landmark/start/S as anything in GLOB.start_landmarks_list)
		if(istype(S)) //we can not runtime here. not in this important of a proc.
			S.after_round_start()
		else
			stack_trace("[S] [S.type] found in start landmarks list, which isn't a start landmark!")

	// handle persistence stuff that requires ckeys, in this case hardcore mode and temporal scarring
	for(var/i in GLOB.player_list)
		if(!ishuman(i))
			continue
		var/mob/living/carbon/human/iter_human = i

		if(!iter_human.hardcore_survival_score)
			continue
		if(iter_human.mind?.special_role)
			to_chat(iter_human, span_notice("You will gain [round(iter_human.hardcore_survival_score) * 2] hardcore random points if you greentext this round!"))
		else
			to_chat(iter_human, span_notice("You will gain [round(iter_human.hardcore_survival_score)] hardcore random points if you survive this round!"))

/datum/controller/subsystem/ticker/proc/end_round()
	force_ending = TRUE

//These callbacks will fire after roundstart key transfer
/datum/controller/subsystem/ticker/proc/OnRoundstart(datum/callback/cb)
	if(!HasRoundStarted())
		LAZYADD(round_start_events, cb)
	else
		cb.InvokeAsync()

//These callbacks will fire before roundend report
/datum/controller/subsystem/ticker/proc/OnRoundend(datum/callback/cb)
	if(current_state >= GAME_STATE_FINISHED)
		cb.InvokeAsync()
	else
		LAZYADD(round_end_events, cb)

/datum/controller/subsystem/ticker/proc/station_explosion_detonation(atom/bomb)
	if(bomb) //BOOM
		qdel(bomb)

/datum/controller/subsystem/ticker/proc/create_characters()
	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(!player.mind)
			//New player has logged out.
			continue

		switch(player.ready)
			if(PLAYER_READY_TO_OBSERVE)
				player.make_me_an_observer(TRUE)

			if(PLAYER_READY_TO_PLAY)
				GLOB.joined_player_list += player.ckey
				var/atom/spawn_loc = player.mind.assigned_role.get_roundstart_spawn_point()
				player.create_character(spawn_loc)

			else //PLAYER_NOT_READY
				//Reload their player panel so they see latejoin instead of ready.
				player.npp.update()

		CHECK_TICK

/// Returns a (probably) unused latejoin spawn point. Used by roundstart code to spread players out.
/datum/controller/subsystem/ticker/proc/get_random_spawnpoint()
	var/static/list/spawnpoints
	if(!length(spawnpoints))
		if(length(SSjob.latejoin_trackers))
			spawnpoints = SSjob.latejoin_trackers.Copy()
		else
			return SSjob.get_last_resort_spawn_points()
	return pick_n_take(spawnpoints)

/datum/controller/subsystem/ticker/proc/collect_minds()
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/P = i
		if(P.new_character && P.new_character.mind)
			SSticker.minds += P.new_character.mind
		CHECK_TICK


/datum/controller/subsystem/ticker/proc/equip_characters()
	var/mob/dead/new_player/picked_spare_id_candidate = get_captain_or_backup()
	// This is a bitfield!!!
	var/departments_without_heads = filter_headless_departments(SSjob.get_necessary_departments())

	for(var/mob/dead/new_player/new_player_mob as anything in GLOB.new_player_list)
		if(QDELETED(new_player_mob) || !isliving(new_player_mob.new_character))
			CHECK_TICK
			continue

		var/mob/living/new_player_living = new_player_mob.new_character
		if(!new_player_living.mind)
			CHECK_TICK
			continue

		var/datum/job/player_assigned_role = new_player_living.mind.assigned_role
		if(player_assigned_role.job_flags & JOB_EQUIP_RANK)
			SSjob.EquipRank(new_player_living, player_assigned_role, new_player_mob.client)

		player_assigned_role.after_roundstart_spawn(new_player_living, new_player_mob.client)

		if(picked_spare_id_candidate == new_player_mob)
			var/acting_captain = !is_captain_job(player_assigned_role)
			SSjob.promote_to_captain(new_player_living, acting_captain)
			SSshuttle.arrivals?.OnDock(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(priority_announce), player_assigned_role.get_captaincy_announcement(new_player_living), null, null, null, null, FALSE))

		if(departments_without_heads && (player_assigned_role.departments_bitflags & departments_without_heads))
			departments_without_heads &= ~SSjob.promote_to_department_head(new_player_living, player_assigned_role)

		if((player_assigned_role.job_flags & JOB_ASSIGN_QUIRKS) && ishuman(new_player_living) && CONFIG_GET(flag/roundstart_traits))
			SSquirks.AssignQuirks(new_player_living, new_player_mob.client)

		CHECK_TICK

/datum/controller/subsystem/ticker/proc/get_captain_or_backup()
	var/list/spare_id_candidates = list()
	var/datum/job_department/management = SSjob.get_department_type(/datum/job_department/command)

	// Find a suitable player to hold captaincy.
	for(var/mob/dead/new_player/new_player_mob as anything in GLOB.new_player_list)
		if(is_banned_from(new_player_mob.ckey, list(JOB_CAPTAIN)))
			CHECK_TICK
			continue

		if(!ishuman(new_player_mob.new_character))
			continue

		var/mob/living/carbon/human/new_player_human = new_player_mob.new_character
		if(!new_player_human.mind || is_unassigned_job(new_player_human.mind.assigned_role))
			continue

		// Keep a rolling tally of who'll get the cap's spare ID vault code.
		// Check assigned_role's priority and curate the candidate list appropriately.
		if(new_player_human.mind.assigned_role.departments_bitflags & management.department_bitflags)
			spare_id_candidates += new_player_human

		CHECK_TICK

	if(length(spare_id_candidates))
		return pick(spare_id_candidates)

/// Removes departments with a head present from the given list, returning the values as bitflags
/datum/controller/subsystem/ticker/proc/filter_headless_departments(list/departments)
	. = NONE

	for(var/path in departments - /datum/job_department/command)
		var/datum/job_department/department = SSjob.get_department_type(path)
		var/datum/job/head_role = SSjob.GetJobType(department.department_head)
		if(head_role.current_positions == 0)
			. |= department.department_bitflags

	return .

/datum/controller/subsystem/ticker/proc/transfer_characters()
	var/list/livings = list()
	for(var/i in GLOB.new_player_list)
		var/mob/dead/new_player/player = i
		var/mob/living = player.transfer_character()
		if(living)
			qdel(player)
			living.notransform = TRUE
			living.client?.init_verbs()
			livings += living

	if(livings.len)
		addtimer(CALLBACK(src, PROC_REF(release_characters), livings), 30, TIMER_CLIENT_TIME)

/datum/controller/subsystem/ticker/proc/release_characters(list/livings)
	for(var/I in livings)
		var/mob/living/L = I
		L.notransform = FALSE

/datum/controller/subsystem/ticker/proc/check_queue()
	if(!queued_players.len)
		return
	var/hpc = CONFIG_GET(number/hard_popcap)
	if(!hpc)
		list_clear_nulls(queued_players)
		for (var/mob/dead/new_player/NP in queued_players)
			to_chat(NP, span_userdanger("The alive players limit has been released!<br><a href='?src=[REF(NP)];late_join=override'>[html_encode(">>Join Game<<")]</a>"))
			SEND_SOUND(NP, sound('sound/misc/notice1.ogg'))
			NP.npp.LateChoices()
		queued_players.len = 0
		queue_delay = 0
		return

	queue_delay++
	var/mob/dead/new_player/next_in_line = queued_players[1]

	switch(queue_delay)
		if(5) //every 5 ticks check if there is a slot available
			list_clear_nulls(queued_players)
			if(living_player_count() < hpc)
				if(next_in_line?.client)
					to_chat(next_in_line, span_userdanger("A slot has opened! You have approximately 20 seconds to join. <a href='?src=[REF(next_in_line)];late_join=override'>\>\>Join Game\<\<</a>"))
					SEND_SOUND(next_in_line, sound('sound/misc/notice1.ogg'))
					next_in_line.npp.LateChoices()
					return
				queued_players -= next_in_line //Client disconnected, remove he
			queue_delay = 0 //No vacancy: restart timer
		if(25 to INFINITY)  //No response from the next in line when a vacancy exists, remove he
			to_chat(next_in_line, span_danger("No response received. You have been removed from the line."))
			queued_players -= next_in_line
			queue_delay = 0

/datum/controller/subsystem/ticker/proc/check_maprotate()
	if(!CONFIG_GET(flag/maprotation))
		return
	if(world.time - SSticker.round_start_time < 10 MINUTES) //Not forcing map rotation for very short rounds.
		return
	INVOKE_ASYNC(SSmapping, TYPE_PROC_REF(/datum/controller/subsystem/mapping, maprotate))

/datum/controller/subsystem/ticker/proc/HasRoundStarted()
	return current_state >= GAME_STATE_PLAYING

/datum/controller/subsystem/ticker/proc/IsRoundInProgress()
	return current_state == GAME_STATE_PLAYING

/datum/controller/subsystem/ticker/Recover()
	current_state = SSticker.current_state
	force_ending = SSticker.force_ending
	mode = SSticker.mode

	login_music = SSticker.login_music
	round_end_sound = SSticker.round_end_sound

	minds = SSticker.minds

	delay_end = SSticker.delay_end

	tipped = SSticker.tipped
	selected_tip = SSticker.selected_tip

	timeLeft = SSticker.timeLeft

	totalPlayers = SSticker.totalPlayers
	totalPlayersReady = SSticker.totalPlayersReady
	total_admins_ready = SSticker.total_admins_ready

	queue_delay = SSticker.queue_delay
	queued_players = SSticker.queued_players
	round_start_time = SSticker.round_start_time

	queue_delay = SSticker.queue_delay
	queued_players = SSticker.queued_players

	if (Master) //Set Masters run level if it exists
		switch (current_state)
			if(GAME_STATE_SETTING_UP)
				Master.SetRunLevel(RUNLEVEL_SETUP)
			if(GAME_STATE_PLAYING)
				Master.SetRunLevel(RUNLEVEL_GAME)
			if(GAME_STATE_FINISHED)
				Master.SetRunLevel(RUNLEVEL_POSTGAME)

/datum/controller/subsystem/ticker/proc/send_news_report()
	var/news_message
	var/news_source = "Nearspace News Network"
	var/decoded_station_name = html_decode(station_name()) //decode station_name to avoid minor_announce double encode
	switch(news_report)
		if(NUKE_SYNDICATE_BASE)
			news_message = "In a daring raid, the heroic crew of [decoded_station_name] detonated a nuclear device in the heart of a terrorist base."
		if(STATION_DESTROYED_NUKE)
			news_message = "We would like to reassure all employees that the reports of a Syndicate backed nuclear attack on [decoded_station_name] are, in fact, a hoax. Have a secure day!"
		if(STATION_EVACUATED)
			if(emergency_reason)
				news_message = "[decoded_station_name] has been evacuated after transmitting the following distress beacon:\n\n[html_decode(emergency_reason)]"
			else
				news_message = "The crew of [decoded_station_name] has been evacuated amid unconfirmed reports of enemy activity."
		if(BLOB_WIN)
			news_message = "[decoded_station_name] was overcome by an unknown biological outbreak, killing all crew on board. Don't let it happen to you! Remember, a clean work station is a safe work station."
		if(BLOB_NUKE)
			news_message = "[decoded_station_name] is currently undergoing decontanimation after a controlled burst of radiation was used to remove a biological ooze. All employees were safely evacuated prior, and are enjoying a relaxing vacation."
		if(BLOB_DESTROYED)
			news_message = "[decoded_station_name] is currently undergoing decontamination procedures after the destruction of a biological hazard. As a reminder, any crew members experiencing cramps or bloating should report immediately to security for incineration."
		if(CULT_ESCAPE)
			news_message = "Security Alert: A group of religious fanatics have escaped from [decoded_station_name]."
		if(CULT_FAILURE)
			news_message = "Following the dismantling of a restricted cult aboard [decoded_station_name], we would like to remind all employees that worship outside of the Chapel is strictly prohibited, and cause for termination."
		if(CULT_SUMMON)
			news_message = "Company officials would like to clarify that [decoded_station_name] was scheduled to be decommissioned following meteor damage earlier this year. Earlier reports of an unknowable eldritch horror were made in error."
		if(NUKE_MISS)
			news_message = "The Syndicate have bungled a terrorist attack [decoded_station_name], detonating a nuclear weapon in empty space nearby."
		if(OPERATIVES_KILLED)
			news_message = "Repairs to [decoded_station_name] are underway after an elite Syndicate death squad was wiped out by the crew."
		if(OPERATIVE_SKIRMISH)
			news_message = "A skirmish between security forces and Syndicate agents aboard [decoded_station_name] ended with both sides bloodied but intact."
		if(REVS_WIN)
			news_message = "Company officials have reassured investors that despite a union led revolt aboard [decoded_station_name] there will be no wage increases for workers."
		if(REVS_LOSE)
			news_message = "[decoded_station_name] quickly put down a misguided attempt at mutiny. Remember, unionizing is illegal!"
		if(WIZARD_KILLED)
			news_message = "Tensions have flared with the Space Wizard Federation following the death of one of their members aboard [decoded_station_name]."
		if(STATION_NUKED)
			news_message = "[decoded_station_name] activated its self-destruct device for unknown reasons. Attempts to clone the Captain for arrest and execution are underway."
		if(SHUTTLE_HIJACK)
			news_message = "During routine evacuation procedures, the emergency shuttle of [decoded_station_name] had its navigation protocols corrupted and went off course, but was recovered shortly after."
		if(GANG_OPERATING)
			news_message = "The company would like to state that any rumors of criminal organizing on board stations such as [decoded_station_name] are falsehoods, and not to be emulated."
		if(GANG_DESTROYED)
			news_message = "The crew of [decoded_station_name] would like to thank the Spinward Stellar Coalition Police Department for quickly resolving a minor terror threat to the station."

	if(news_message)
		send2otherserver(news_source, news_message,"News_Report")

/datum/controller/subsystem/ticker/proc/GetTimeLeft()
	if(isnull(SSticker.timeLeft))
		return max(0, start_at - world.time)
	return timeLeft

/datum/controller/subsystem/ticker/proc/SetTimeLeft(newtime)
	if(newtime >= 0 && isnull(timeLeft)) //remember, negative means delayed
		start_at = world.time + newtime
	else
		timeLeft = newtime

/datum/controller/subsystem/ticker/proc/SetRoundEndSound(the_sound)
	set waitfor = FALSE
	round_end_sound_sent = FALSE
	round_end_sound = fcopy_rsc(the_sound)
	for(var/thing in GLOB.clients)
		var/client/C = thing
		if (!C)
			continue
		C.Export("##action=load_rsc", round_end_sound)
	round_end_sound_sent = TRUE

/datum/controller/subsystem/ticker/proc/Reboot(reason, end_string, delay, roll_credits = TRUE)
	set waitfor = FALSE
	if(usr && !check_rights(R_SERVER, TRUE))
		return

	if(!delay)
		delay = CONFIG_GET(number/round_end_countdown) * 10

	var/skip_delay = check_rights()
	if(delay_end && !skip_delay)
		to_chat(world, span_boldannounce("An admin has delayed the round end."))
		return

	to_chat(world, span_boldannounce("Rebooting World in [DisplayTimeText(delay)]. [reason]"))

	var/roll_credits_in = CONFIG_GET(number/eor_credits_delay) * 10
	if(roll_credits)
		if(roll_credits_in)
			addtimer(CALLBACK(SScredits, TYPE_PROC_REF(/datum/controller/subsystem/credits, compile_credits)), roll_credits_in)
		else
			SScredits.compile_credits()

	var/start_wait = world.time
	UNTIL(round_end_sound_sent || (world.time - start_wait) > (delay * 2)) //don't wait forever
	sleep(delay - (world.time - start_wait))

	if(delay_end && !skip_delay)
		to_chat(world, span_boldannounce("Reboot was cancelled by an admin."))
		return
	if(end_string)
		end_state = end_string

	var/statspage = CONFIG_GET(string/roundstatsurl)
	var/gamelogloc = CONFIG_GET(string/gamelogurl)
	if(statspage)
		to_chat(world, span_info("Round statistics and logs can be viewed <a href=\"[statspage][GLOB.round_id]\">at this website!</a>"))
	else if(gamelogloc)
		to_chat(world, span_info("Round logs can be located <a href=\"[gamelogloc]\">at this website!</a>"))

	log_game(span_boldannounce("Rebooting World. [reason]"))

	world.Reboot()

/datum/controller/subsystem/ticker/Shutdown()
	gather_newscaster() //called here so we ensure the log is created even upon admin reboot
	save_admin_data()
	update_everything_flag_in_db()
	if(!round_end_sound)
		round_end_sound = choose_round_end_song()
	///The reference to the end of round sound that we have chosen.
	var/sound/end_of_round_sound_ref = sound(round_end_sound)
	for(var/mob/M in GLOB.player_list)
		if(M.client.prefs?.toggles & SOUND_ENDOFROUND)
			SEND_SOUND(M.client, end_of_round_sound_ref)

/datum/controller/subsystem/ticker/proc/choose_round_end_song()
	var/list/reboot_sounds = flist("[global.config.directory]/reboot_themes/")
	var/list/possible_themes = list()

	for(var/themes in reboot_sounds)
		possible_themes += themes
	if(possible_themes.len)
		return "[global.config.directory]/reboot_themes/[pick(possible_themes)]"

/datum/controller/subsystem/ticker/proc/set_login_music(datum/media/track)
	if(!istype(track))
		CRASH("Non-datum/media given to set_login_music()!")

	if(credits_music == login_music)
		credits_music = track
	login_music = track

	for(var/mob/dead/new_player/player as anything in GLOB.new_player_list)
		if(!player.client)
			continue
		player.client.playtitlemusic()

/datum/controller/subsystem/ticker/proc/pick_login_music()
	var/list/title_music_data = SSmedia.get_track_pool(MEDIA_TAG_LOBBYMUSIC_COMMON)
	var/list/rare_music_data = SSmedia.get_track_pool(MEDIA_TAG_LOBBYMUSIC_RARE)
	///The full path of the last song used
	var/old_login_music_t
	///The full datum of the last song used.
	var/datum/media/old_login_music

	if(rustg_file_exists("data/last_round_lobby_music.txt")) //The define isn't truthy
		old_login_music_t = rustg_file_read("data/last_round_lobby_music.txt")
	var/list/music_tracks = title_music_data + rare_music_data
	//Filter map-specific tracks
	for(var/datum/media/music_filtered as anything in music_tracks)
		if(old_login_music_t && (music_filtered.path == old_login_music_t))
			old_login_music = music_filtered
		if(music_filtered.map && music_filtered.map != SSmapping.config.map_name)
			rare_music_data -= music_filtered
			title_music_data -= music_filtered
	//Remove the previous song
	if(old_login_music)
		//Remove the old login music from the current pool if it wouldn't empty the pool.
		if((MEDIA_TAG_LOBBYMUSIC_RARE in old_login_music.media_tags) && (length(rare_music_data) > 1))
			rare_music_data -= old_login_music
		else if(length(title_music_data) > 1)
			title_music_data -= old_login_music

	//Try to set a song json
	var/use_rare_music = prob(10)
	if(use_rare_music && length(rare_music_data))
		login_music = pick(rare_music_data)
	if(!login_music && length(title_music_data))
		login_music = pick(title_music_data)

	//If there's no valid jsons, fallback to the classic ROUND_START_MUSIC_LIST.
	if(!login_music)
		var/music = pick(world.file2list(ROUND_START_MUSIC_LIST, "\n"))
		var/list/split_path = splittext(music, "/")
		//Construct a minimal music track to satisfy the system.
		login_music = new(name = split_path[length(split_path)], path = music)

	//Write the last round file to our current choice
	rustg_file_write(login_music.path, "data/last_round_lobby_music.txt")

/datum/controller/subsystem/ticker/proc/pick_credits_music()
	var/list/music_data = SSmedia.get_track_pool(MEDIA_TAG_ROUNDEND_COMMON)
	var/list/rare_music_data = SSmedia.get_track_pool(MEDIA_TAG_ROUNDEND_RARE)

	//Try to set a song json
	var/use_rare_music = prob(10)
	if(use_rare_music && length(rare_music_data))
		credits_music = pick(rare_music_data)
	if(!credits_music && length(music_data))
		credits_music = pick(music_data)

	if(!credits_music)
		credits_music = login_music

///Generate a list of gamemodes we can play.
/datum/controller/subsystem/ticker/proc/draft_gamemodes()
	var/list/datum/game_mode/runnable_modes = list()
	for(var/path in subtypesof(/datum/game_mode))
		var/datum/game_mode/M = new path()
		if(!(M.weight == GAMEMODE_WEIGHT_NEVER) && !M.check_for_errors())
			runnable_modes[path] = M.weight
	return runnable_modes

/datum/controller/subsystem/ticker/proc/get_mode_name(bypass_secret)
	if(!istype(mode))
		return "Undecided"
	if(bypass_secret || !mode_display_name)
		return mode.name

	return mode_display_name

/datum/controller/subsystem/ticker/proc/initialize_gamemode()
	if(!mode)
		var/list/datum/game_mode/runnable_modes = draft_gamemodes()
		if(!runnable_modes.len)
			message_admins(world, "<B>No viable gamemodes to play.</B> Running Extended.")
			mode = new /datum/game_mode/extended
		else
			mode = pick_weight(runnable_modes)
			mode = new mode

	else
		if(istype(mode, /datum/game_mode/extended) && GLOB.is_debug_server)
			message_admins("Using Extended gamemode during debugging. Use Set Gamemode to change this.")

		var/potential_error = mode.check_for_errors()
		if(potential_error)
			if(mode_display_name)
				message_admins(span_adminnotice("Unable to force secret [get_mode_name(TRUE)]. [potential_error]"))
				to_chat(world, "<B>Unable to choose playable game mode.</B> Reverting to pre-game lobby.")
			else
				to_chat(world, "<B>Unable to start [get_mode_name(TRUE)].</B> [potential_error] Reverting to pre-game lobby.")

			QDEL_NULL(mode)
			SSjob.ResetOccupations()
			return FALSE

	CHECK_TICK
	//Configure mode and assign player to special mode stuff
	var/can_continue = 0
	can_continue = src.mode.execute_roundstart() //Choose antagonists
	CHECK_TICK
	can_continue = can_continue && SSjob.DivideOccupations(mode.required_jobs) //Distribute jobs
	CHECK_TICK

	if(!GLOB.Debug2)
		if(!can_continue)
			log_game("[get_mode_name(TRUE)] failed pre_setup, cause: [mode.setup_error].")
			message_admins("[get_mode_name(TRUE)] failed pre_setup, cause: [mode.setup_error].")
			to_chat(world, "<B>Error setting up [get_mode_name(TRUE)].</B> Reverting to pre-game lobby.")
			mode.on_failed_execute()
			QDEL_NULL(mode)
			SSjob.ResetOccupations()
			return FALSE
	else
		message_admins(span_notice("DEBUG: Bypassing prestart checks..."))

	log_game("Gamemode successfully initialized, chose: [mode.name]")
	return TRUE
