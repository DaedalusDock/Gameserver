#define MIXED_WEIGHT_TRAITOR 100
#define MIXED_WEIGHT_CHANGELING 0
#define MIXED_WEIGHT_HERETIC 20
#define MIXED_WEIGHT_WIZARD 1

///What percentage of the pop can become antags
#define MIXED_ANTAG_COEFF 0.15

/datum/game_mode/mixed
	name = "Mixed"
	weight = GAMEMODE_WEIGHT_COMMON
	restricted_jobs = list(JOB_CYBORG, JOB_AI)
	protected_jobs = list(
		JOB_SECURITY_OFFICER,
		JOB_WARDEN,
		JOB_HEAD_OF_PERSONNEL,
		JOB_SECURITY_MARSHAL,
		JOB_CAPTAIN,
		JOB_CHIEF_ENGINEER,
		JOB_AUGUR
	)

	force_pre_setup_check = TRUE

	var/list/antag_weight_map = list(
		ROLE_TRAITOR = MIXED_WEIGHT_TRAITOR,
		ROLE_CHANGELING = MIXED_WEIGHT_CHANGELING,
		ROLE_HERETIC = MIXED_WEIGHT_HERETIC,
		ROLE_WIZARD = MIXED_WEIGHT_WIZARD
	)

/datum/game_mode/mixed/pre_setup()
	. = ..()

	var/list/antag_pool = list()

	var/number_of_antags = max(1, round(length(SSticker.ready_players) * MIXED_ANTAG_COEFF))

	//Setup a list of antags to try to spawn
	while(number_of_antags)
		antag_pool[pick_weight(antag_weight_map)] += 1
		number_of_antags--

	var/list/role_to_players_map = list(
		ROLE_TRAITOR = list(),
		ROLE_HERETIC = list(),
		ROLE_CHANGELING = list(),
		ROLE_WIZARD = list()
	)

	//Filter out our possible_antags list into a mixed-specific map of role : elligible players
	for(var/mob/dead/new_player/candidate_player in possible_antags)
		var/client/candidate_client = GET_CLIENT(candidate_player)

		for(var/role in antag_pool)
			if (is_banned_from(candidate_player.ckey, list(role, ROLE_SYNDICATE)))
				continue

			var/list/antag_prefs = candidate_client.prefs.read_preference(/datum/preference/blob/antagonists)
			if(antag_prefs[role])
				role_to_players_map[role] += candidate_player
				continue

	if(antag_pool[ROLE_TRAITOR])
		for(var/i in 1 to antag_pool[ROLE_TRAITOR])
			if(!length(role_to_players_map[ROLE_TRAITOR]))
				break
			var/mob/M = pick_n_take(role_to_players_map[ROLE_TRAITOR])
			select_antagonist(M.mind, /datum/antagonist/traitor)

	if(antag_pool[ROLE_CHANGELING])
		for(var/i in 1 to antag_pool[ROLE_CHANGELING])
			if(!length(role_to_players_map[ROLE_CHANGELING]))
				break
			var/mob/M = pick_n_take(role_to_players_map[ROLE_CHANGELING])
			select_antagonist(M.mind, /datum/antagonist/changeling)

	if(antag_pool[ROLE_HERETIC])
		for(var/i in 1 to antag_pool[ROLE_HERETIC])
			if(!length(role_to_players_map[ROLE_HERETIC]))
				break
			var/mob/M = pick_n_take(role_to_players_map[ROLE_HERETIC])
			select_antagonist(M.mind, /datum/antagonist/heretic)

	if(length(GLOB.wizardstart) && antag_pool[ROLE_WIZARD])
		for(var/i in 1 to antag_pool[ROLE_WIZARD])
			if(!length(role_to_players_map[ROLE_WIZARD]))
				break
			var/mob/M = pick_n_take(role_to_players_map[ROLE_WIZARD])
			select_antagonist(M.mind, /datum/antagonist/wizard)
