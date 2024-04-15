/datum/vote
	// Human readable name for this vote.
	var/name = ""
	// The vote options
	var/list/options
	// k:V list of option : vote_count
	var/list/tally
	// A list of winning vote options
	var/list/winners
	// The winner after the tie breaker
	var/real_winner
	// A k:V list of ckey : option_index
	var/list/voters
	// A list of ckeys that did not vote.
	var/list/non_voters
	// Has this vote concluded and been tallied?
	var/finished = FALSE

/datum/vote/New(list/options)
	. = ..()
	src.options = options || compile_options()
	tally = list()
	winners = list()
	voters = list()

/datum/vote/Destroy(force, ...)
	tally = null
	winners = null
	voters = null
	non_voters = null
	options = null
	return ..()

/// Handy proc for building option lists
/datum/vote/proc/compile_options()
	return list()

/// Counts up the votes.
/datum/vote/proc/tally_votes()
	if(finished)
		return
	// Mark end state
	finished = TRUE

	// Set non-voters
	non_voters = GLOB.directory.Copy()
	non_voters -= voters
	for (var/non_voter_ckey in non_voters)
		var/client/C = non_voters[non_voter_ckey]
		if (!C || C.is_afk())
			non_voters -= non_voter_ckey

	filter_votes()

	//get the highest number of votes
	var/highest_score = 0
	var/total_score = 0

	// Count up the scores
	for(var/option in options)
		var/option_score = tally[option]
		total_score += option_score
		if(option_score > highest_score)
			highest_score = option_score

	// Find the winners
	for(var/option in options)
		if(tally[option] == highest_score)
			winners += option

	real_winner = break_tie()

/// Filters the votes.
/datum/vote/proc/filter_votes()
	PROTECTED_PROC(TRUE)
	return

/// Break a tie between winners, returning the sole victor.
/datum/vote/proc/break_tie()
	if(length(winners))
		return pick(winners)

/// Checks if this vote can run.
/datum/vote/proc/can_run(admin)
	return TRUE

/// Anything to do after the vote has finished and been announced.
/datum/vote/proc/after_completion()
	return

/datum/vote/proc/try_vote(mob/user, vote)
	if(!vote || vote < 1 || vote > options.len)
		return FALSE

	if(!user || !user_can_vote(user))
		return FALSE

	// If user has already voted, remove their specific vote
	if(voters[user.ckey])
		tally[options[voters[user.ckey]]]--

	voters[user.ckey] = vote

	tally[options[vote]]++

	return TRUE

/datum/vote/proc/user_can_vote(mob/user)
	if(CONFIG_GET(flag/no_dead_vote) && user.stat == DEAD && !user.client.holder)
		return FALSE
	return TRUE

/// Custom votes, just for typechecking niceness
/datum/vote/custom
	name = "Custom"

/// Vote datum for changing the map
/datum/vote/change_map
	name = "Change Map"

/datum/vote/change_map/compile_options()
	. = SSmapping.filter_map_options(global.config.maplist.Copy(), TRUE)
	shuffle_inplace(.)

/datum/vote/change_map/can_run(admin)
	if(!admin && SSmapping.map_voted)
		to_chat(usr, span_warning("The next map has already been selected."))
		return FALSE
	return TRUE

/datum/vote/change_map/filter_votes()
	if(CONFIG_GET(flag/default_no_vote))
		return

	for (var/non_voter_ckey in non_voters)
		var/client/C = non_voters[non_voter_ckey]
		var/preferred_map = C.prefs.read_preference(/datum/preference/choiced/preferred_map)
		if(isnull(global.config.defaultmap))
			continue
		if(!(preferred_map in global.config.maplist))
			preferred_map = global.config.defaultmap.map_name

		tally[preferred_map] += 1

/datum/vote/change_map/after_completion()
	if(isnull(real_winner))
		return

	SSmapping.changemap(global.config.maplist[real_winner])
	SSmapping.map_voted = TRUE


#define CONTINUE_PLAYING "Continue Playing"
#define INITIATE_TRANSFER "Initiate Transfer"

/// Automatic vote for calling the shuttle
/datum/vote/crew_transfer
	name = "Crew Transfer"

/datum/vote/crew_transfer/compile_options()
	return list(CONTINUE_PLAYING, INITIATE_TRANSFER)

/datum/vote/crew_transfer/filter_votes()
	tally[CONTINUE_PLAYING] += length(non_voters)

/datum/vote/crew_transfer/after_completion()
	if(!(real_winner == INITIATE_TRANSFER))
		return

	SSevacuation.trigger_auto_evac(EVACUATION_REASON_VOTE)
	log_game("Round end vote passed. Shuttle has been auto-called.")
	message_admins("Round end vote passed. Shuttle has been auto-called.")
	var/obj/machinery/computer/communications/C = locate() in INSTANCES_OF(/obj/machinery/computer/communications)
	if(C)
		C.post_status("shuttle")

#undef CONTINUE_PLAYING
#undef INITIATE_TRANSFER

#define CONTINUE_PLAYING "Continue Playing"
#define RESTART_ROUND "Restart Round"

/// Vote for restarting the server
/datum/vote/restart
	name = "Restart Server"

/datum/vote/restart/can_run(admin)
	return admin || !any_active_admins()

/datum/vote/restart/compile_options()
	return list(CONTINUE_PLAYING, RESTART_ROUND)

/datum/vote/restart/filter_votes()
	tally[CONTINUE_PLAYING] += length(non_voters)

/datum/vote/restart/after_completion()
	if(real_winner != RESTART_ROUND)
		return

	if(!any_active_admins())
		// No delay in case the restart is due to lag
		SSticker.Reboot("Restart vote successful.", "restart vote", 1)
	else
		to_chat(world, span_boldannounce("Notice: Restart vote will not restart the server automatically because there are active admins on."))
		message_admins("A restart vote has passed, but there are active admins on with +server, so it has been canceled. If you wish, you may restart the server.")

/datum/vote/restart/proc/any_active_admins()
	. = TRUE
	for(var/client/C in GLOB.admins + GLOB.deadmins)
		if(!C.is_afk() && check_rights_for(C, R_SERVER))
			return TRUE

#undef CONTINUE_PLAYING
#undef RESTART_ROUND


