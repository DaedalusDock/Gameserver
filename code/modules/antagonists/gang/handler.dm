#define LOWPOP_FAMILIES_COUNT 50

#define TWO_STARS_HIGHPOP 11
#define THREE_STARS_HIGHPOP 16
#define FOUR_STARS_HIGHPOP 21
#define FIVE_STARS_HIGHPOP 31

#define TWO_STARS_LOW 6
#define THREE_STARS_LOW 9
#define FOUR_STARS_LOW 12
#define FIVE_STARS_LOW 15

#define CREW_SIZE_MIN 4
#define CREW_SIZE_MAX 8


///Forces the Families theme to be the one in this variable via variable editing. Used for debugging.
GLOBAL_VAR(families_override_theme)

/**
 * # Families gamemode / dynamic ruleset handler
 *
 * A special datum used by the families gamemode and dynamic rulesets to centralize code. "Family" and "gang" used interchangeably in code.
 *
 * This datum centralizes code used for the families gamemode / dynamic rulesets. Families incorporates a significant
 * amount of unique processing; without this datum, that could would be duplicated. To ensure the maintainability
 * of the families gamemode / rulesets, the code was moved to this datum. The gamemode / rulesets instance this
 * datum, pass it lists (lists are passed by reference; removing candidates here removes candidates in the gamemode),
 * and call its procs. Additionally, the families antagonist datum and families induction package also
 * contain vars that reference this datum, allowing for new families / family members to add themselves
 * to this datum's lists thereof (primarily used for point calculation). Despite this, the basic team mechanics
 * themselves should function regardless of this datum's instantiation, should a player have the gang or cop
 * antagonist datum added to them through methods external to the families gamemode / rulesets.
 *
 */
/datum/gang_handler
	/// A counter used to minimize the overhead of computationally intensive, periodic family point gain checks. Used and set internally.
	var/check_counter = 0
	/// The time, in deciseconds, that the datum's pre_setup() occured at. Used in end_time. Used and set internally.
	var/start_time = null
	/// The time, in deciseconds, that the space cops will arrive at. Calculated based on wanted level and start_time. Used and set internally.
	var/end_time = null
	/// Whether the gamemode-announcing announcement has been sent. Used and set internally.
	var/sent_announcement = FALSE
	/// Whether the "5 minute warning" announcement has been sent. Used and set internally.
	var/sent_second_announcement = FALSE
	/// Whether the space cops have arrived. Set internally; used internally, and for updating the wanted HUD.
	var/cops_arrived = FALSE
	/// The current wanted level. Set internally; used internally, and for updating the wanted HUD.
	var/wanted_level
	/// List of all /datum/team/gang. Used internally; added to externally by /datum/antagonist/gang when it generates a new /datum/team/gang.
	var/list/gangs = list()
	/// List of all family member minds. Used internally; added to internally, and externally by /obj/item/gang_induction_package when used to induct a new family member.
	var/list/gangbangers = list()
	/// List of all undercover cop minds. Used and set internally.
	var/list/undercover_cops = list()
	/// The number of families (and 1:1 corresponding undercover cops) that should be generated. Can be set externally; used internally.
	var/gangs_to_generate = 3
	/// The number of family members more that a family may have over other active families. Can be set externally; used internally.
	var/gang_balance_cap = 5
	/// Whether the handler corresponds to a ruleset that does not trigger at round start. Should be set externally only if applicable; used internally.
	var/midround_ruleset = FALSE
	/// Whether we want to use the 30 to 15 minute timer instead of the 60 to 30 minute timer, for Dynamic.
	var/use_dynamic_timing = FALSE

	/// List of all eligible starting family members / undercover cops. Set externally (passed by reference) by gamemode / ruleset; used internally. Note that dynamic uses a list of mobs to handle candidates while game_modes use lists of minds! Don't be fooled!
	var/list/antag_candidates = list()
	/// List of jobs not eligible for starting family member / undercover cop. Set externally (passed by reference) by gamemode / ruleset; used internally.
	var/list/restricted_jobs
	/// The current chosen gamemode theme. Decides the available Gangs, objectives, and equipment.
	var/datum/gang_theme/current_theme

/**
 * Sets antag_candidates and restricted_jobs.
 *
 * Sets the antag_candidates and restricted_jobs lists to the equivalent
 * lists of its instantiating game_mode / dynamic_ruleset datum. As lists
 * are passed by reference, the variable set in this datum and the passed list
 * list used to set it are literally the same; changes to one affect the other.
 * Like all New() procs, called when the datum is first instantiated.
 * There's an annoying caveat here, though -- dynamic rulesets don't have
 * lists of minds for candidates, they have lists of mobs. Ghost mobs, before
 * the round has started. But we still want to preserve the structure of the candidates
 * list by not duplicating it and making sure to remove the candidates as we use them.
 * So there's a little bit of boilerplate throughout to preserve the sanctity of this reference.
 * Arguments:
 * * given_candidates - The antag_candidates list or equivalent of the datum instantiating this one.
 * * revised_restricted - The restricted_jobs list or equivalent of the datum instantiating this one.
 */
/datum/gang_handler/New(list/given_candidates, list/revised_restricted)
	antag_candidates = given_candidates
	restricted_jobs = revised_restricted

/**
 * pre_setup() or pre_execute() equivalent.
 *
 * This proc is always called externally, by the instantiating game_mode / dynamic_ruleset.
 * This is done during the pre_setup() or pre_execute() phase, after first instantiation
 * and the modification of gangs_to_generate, gang_balance_cap, and midround_ruleset.
 * It is intended to take the place of the code that would normally occupy the pre_setup()
 * or pre_execute() proc, were the code localized to the game_mode or dynamic_ruleset datum respectively
 * as opposed to this handler. As such, it picks players to be chosen for starting familiy members.
 * Takes no arguments.
 */
/datum/gang_handler/proc/pre_setup_analogue()
	if(!GLOB.families_override_theme)
		var/theme_to_use = pick(subtypesof(/datum/gang_theme))
		current_theme = new theme_to_use
	else
		current_theme = new GLOB.families_override_theme

	message_admins("Families has chosen the theme: [current_theme.name]")
	log_game("FAMILIES: The following theme has been chosen: [current_theme.name]")

	var/gangsters_to_make = length(current_theme.involved_gangs) * current_theme.starting_gangsters
	for(var/i in 1 to gangsters_to_make)
		if (!antag_candidates.len)
			break
		var/taken = pick_n_take(antag_candidates) // original used antag_pick, but that's local to game_mode and rulesets use pick_n_take so this is fine maybe

		var/datum/mind/gangbanger
		if(istype(taken, /mob))
			var/mob/T = taken
			gangbanger = T.mind
		else
			gangbanger = taken

		gangbangers += gangbanger
		gangbanger.restricted_roles = restricted_jobs
		log_game("[key_name(gangbanger)] has been selected as a starting gangster!")
		if(!midround_ruleset)
			GLOB.pre_setup_antags += gangbanger

	start_time = world.time
	end_time = start_time + ((60 MINUTES) / (midround_ruleset ? 2 : 1)) // midround families rounds end quicker
	return TRUE

/**
 * post_setup() or execute() equivalent.
 *
 * This proc is always called externally, by the instantiating game_mode / dynamic_ruleset.
 * This is done during the post_setup() or execute() phase, after the pre_setup() / pre_execute() phase.
 * It is intended to take the place of the code that would normally occupy the pre_setup()
 * or pre_execute() proc. As such, it ensures that all prospective starting family members /
 * undercover cops are eligible, and picks replacements if there were ineligible cops / family members.
 * It then assigns gear to the finalized family members and undercover cops, adding them to its lists,
 * and sets the families announcement proc (that does the announcing) to trigger in five minutes.
 * Additionally, if given the argument TRUE, it will return FALSE if there are no eligible starting family members.
 * This is only to be done if the instantiating datum is a dynamic_ruleset, as these require returns
 * while a game_mode is not expected to return early during this phase.
 * Arguments:
 * * return_if_no_gangs - Boolean that determines if the proc should return FALSE should it find no eligible family members. Should be used for dynamic only.
 */
/datum/gang_handler/proc/post_setup_analogue(return_if_no_gangs = FALSE)
	var/list/gangs_to_use = current_theme.involved_gangs.Copy()
	var/amount_of_gangs = gangs_to_use.len
	var/amount_of_gangsters = amount_of_gangs * current_theme.starting_gangsters
	for(var/_ in 1 to amount_of_gangsters)
		if(!gangbangers.len) // We ran out of candidates!
			break
		if(!gangs_to_use.len)
			gangs_to_use = current_theme.involved_gangs.Copy()
		var/gang_to_use = pick_n_take(gangs_to_use) // Evenly distributes Leaders among the gangs
		var/datum/mind/gangster_mind = pick_n_take(gangbangers)
		var/datum/antagonist/gang/new_gangster = new gang_to_use()
		new_gangster.handler = src
		new_gangster.starter_gangster = TRUE
		gangster_mind.add_antag_datum(new_gangster)


		// see /datum/antagonist/gang/create_team() for how the gang team datum gets instantiated and added to our gangs list

	addtimer(CALLBACK(src, PROC_REF(announce_gang_locations)), 5 MINUTES)
	return TRUE

/**
 * process() or rule_process() equivalent.
 *
 * This proc is always called externally, by the instantiating game_mode / dynamic_ruleset.
 * This is done during the process() or rule_process() phase, after post_setup() or
 * execute() and at regular intervals thereafter. process() and rule_process() are optional
 * for a game_mode / dynamic_ruleset, but are important for this gamemode. It is of central
 * importance to the gamemode's flow, calculating wanted level updates, family point gain,
 * and announcing + executing the arrival of the space cops, achieved through calling internal procs.
 * Takes no arguments.
 */
/datum/gang_handler/proc/process_analogue()

/**
 * set_round_result() or round_result() equivalent.
 *
 * This proc is always called externally, by the instantiating game_mode / dynamic_ruleset.
 * This is done by the set_round_result() or round_result() procs, at roundend.
 * Sets the ticker subsystem to the correct result based off of the relative populations
 * of space cops and family members.
 * Takes no arguments.
 */
/datum/gang_handler/proc/set_round_result_analogue()
	SSticker.mode_result = "win - gangs survived"
	SSticker.news_report = GANG_OPERATING
	return TRUE

/// Internal. Announces the presence of families to the entire station and sets sent_announcement to true to allow other checks to occur.
/datum/gang_handler/proc/announce_gang_locations()
	priority_announce(current_theme.description, current_theme.name, sound_type = 'sound/voice/beepsky/radio.ogg')
	sent_announcement = TRUE
