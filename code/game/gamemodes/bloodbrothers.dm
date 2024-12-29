///What percentage of the crew can become bros :flooshed:.
#define BROTHER_SCALING_COEFF 0.15
//The minimum amount of people in a blood brothers team. Set this below 2 and you're stupid.
#define BROTHER_MINIMUM_TEAM_SIZE 2

/datum/game_mode/brothers
	name = "Blood Brothers"

	weight = GAMEMODE_WEIGHT_RARE
	required_enemies = BROTHER_MINIMUM_TEAM_SIZE

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

	antag_datum = /datum/antagonist/brother
	antag_flag = ROLE_BROTHER

	var/list/datum/team/brother_team/pre_brother_teams = list()

/datum/game_mode/brothers/pre_setup()
	. = ..()

	var/num_teams = max(1, round((length(SSticker.ready_players) * BROTHER_SCALING_COEFF) / BROTHER_MINIMUM_TEAM_SIZE))

	for(var/j in 1 to num_teams)
		if(length(possible_antags) < BROTHER_MINIMUM_TEAM_SIZE) //This shouldn't ever happen but, just in case
			break

		var/datum/team/brother_team/team = new
		// 10% chance to add 1 more member
		var/team_size = prob(10) ? min(BROTHER_MINIMUM_TEAM_SIZE + 1, possible_antags) : BROTHER_MINIMUM_TEAM_SIZE

		for(var/k in 1 to team_size)
			var/mob/bro = pick_n_take(possible_antags)
			team.add_member(bro.mind)
			select_antagonist(bro.mind)

		pre_brother_teams += team

/datum/game_mode/brothers/setup_antags()
	for(var/datum/team/brother_team/team in pre_brother_teams)
		team.pick_meeting_area()
		team.forge_brother_objectives()
		team.update_name()

	return ..()

/datum/game_mode/brothers/give_antag_datums()
	for(var/datum/team/brother_team/team in pre_brother_teams)
		for(var/datum/mind/M in team.members)
			M.add_antag_datum(/datum/antagonist/brother, team)
