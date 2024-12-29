///What percentage of the crew can become heretics.
#define HERETIC_SCALING_COEFF 0.1

/datum/game_mode/heretic
	name = "Heretic"

	weight = GAMEMODE_WEIGHT_RARE
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

	antag_datum = /datum/antagonist/heretic
	antag_flag = ROLE_HERETIC

/datum/game_mode/heretic/pre_setup()
	. = ..()

	var/num_heretics = 1

	num_heretics = max(1, round(length(SSticker.ready_players) * HERETIC_SCALING_COEFF))

	for (var/i in 1 to num_heretics)
		if(possible_antags.len <= 0)
			break
		var/mob/M = pick_n_take(possible_antags)
		select_antagonist(M.mind)
