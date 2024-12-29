///What percentage of the crew can become traitors.
#define TRAITOR_SCALING_COEFF 0.15

/datum/game_mode/traitor
	name = "Traitor"

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

	antag_datum = /datum/antagonist/traitor
	antag_flag = ROLE_TRAITOR

/datum/game_mode/traitor/pre_setup()
	. = ..()

	var/num_traitors = 1

	num_traitors = max(1, round(length(SSticker.ready_players) * TRAITOR_SCALING_COEFF))

	for (var/i in 1 to num_traitors)
		if(possible_antags.len <= 0)
			break
		var/mob/M = pick_n_take(possible_antags)
		select_antagonist(M.mind)
