/datum/round_event_control/contractor
	name = "Drifting Contractor"
	typepath = /datum/round_event/ghost_role/contractor
	weight = 4
	max_occurrences = 1
	earliest_start = 40 MINUTES

/datum/round_event/ghost_role/contractor
	minimum_required = 1
	role_name = "Drifting Contractor"
	fakeable = FALSE

/datum/round_event/ghost_role/contractor/spawn_role()
	var/list/candidates = get_candidates(ROLE_DRIFTING_CONTRACTOR)
	if(!length(candidates))
		return NOT_ENOUGH_PLAYERS

	var/mob/dead/selected = pick(candidates)

	var/list/spawn_locs = list()
	for(var/obj/effect/landmark/carpspawn/carp in GLOB.landmarks_list)
		spawn_locs += carp.loc
	if(!length(spawn_locs))
		return MAP_ERROR

	var/mob/living/carbon/human/operative = new(pick(spawn_locs))
	operative.randomize_human_appearance(~RANDOMIZE_SPECIES)
	operative.dna.update_dna_identity()
	var/datum/mind/mind = new /datum/mind(selected.key)
	mind.set_assigned_role(SSjob.GetJobType(/datum/job/drifting_contractor))
	mind.special_role = ROLE_DRIFTING_CONTRACTOR
	mind.active = TRUE
	mind.transfer_to(operative)
	mind.add_antag_datum(/datum/antagonist/contractor)

	message_admins("[ADMIN_LOOKUPFLW(operative)] has been made into a [src] by an event.")
	log_game("[key_name(operative)] was spawned as a [src] by an event.")
	spawned_mobs += operative
	return SUCCESSFUL_SPAWN
