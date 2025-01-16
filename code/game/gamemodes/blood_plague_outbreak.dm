///What percentage of the crew can become traitors.
#define VAMPIRE_SCALING_COEFF 0.1

/datum/game_mode/blood_plague
	name = "Sanguine Plague Outbreak"

	weight = GAMEMODE_WEIGHT_COMMON
	restricted_jobs = list(JOB_CYBORG, JOB_AI)
	protected_jobs = list(
		JOB_WARDEN,
		JOB_SECURITY_MARSHAL,
		JOB_CAPTAIN,
		JOB_CHIEF_ENGINEER,
		JOB_MEDICAL_DIRECTOR
	)

	antag_datum = /datum/antagonist/vampire
	antag_flag = ROLE_VAMPIRE

/datum/game_mode/blood_plague/pre_setup()
	. = ..()

	var/num_vampires = 1

	num_vampires = max(1, round(length(SSticker.ready_players) * VAMPIRE_SCALING_COEFF))

	for (var/i in 1 to num_vampires)
		if(possible_antags.len <= 0)
			break

		var/mob/M = pick_n_take(possible_antags)
		select_antagonist(M.mind)

/datum/game_mode/blood_plague/trim_candidates(list/candidates)
	. = ..()
	for(var/mob/dead/new_player/candidate_player in candidates)
		var/client/candidate_client = GET_CLIENT(candidate_player)
		if (!candidate_client || !candidate_player.mind) // Are they connected?
			candidates.Remove(candidate_player)
			continue

		var/datum/preferences/prefs = candidate_client.prefs
		var/species_type = prefs.read_preference(/datum/preference/choiced/species)
		if(ispath(species_type, /datum/species/ipc))
			candidates.Remove(candidate_player)
			continue

/datum/game_mode/blood_plague/check_finished()
	. = ..()
	if(.)
		return

	// If there's no non-vampires left alive, end the round.
	// If this becomes too common, something is wrong, this is NOT a conversion antagonist.
	for(var/mob/living/carbon/human in GLOB.human_list)
		if(!human.ckey)
			continue

		var/turf/pos = get_turf(human)
		if(!is_station_level(pos.z))
			continue

		if(IS_VAMPIRE(human))
			continue

		return TRUE
