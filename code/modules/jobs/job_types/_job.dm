GLOBAL_LIST_INIT(job_display_order, list(
	// Management
	/datum/job/captain,
	/datum/job/head_of_personnel,
	///datum/job/bureaucrat,
	// Security
	/datum/job/head_of_security,
	/datum/job/warden,
	/datum/job/security_officer,
	/datum/job/prisoner,
	// Engineeering
	/datum/job/chief_engineer,
	/datum/job/station_engineer,
	/datum/job/atmospheric_technician,
	// Medical
	/datum/job/augur,
	/datum/job/acolyte,
	/datum/job/paramedic,
	/datum/job/chemist,
	/datum/job/virologist,
	/datum/job/psychologist,
	// Supply
	/datum/job/quartermaster,
	/datum/job/cargo_technician,
	/datum/job/shaft_miner,
	// Other
	/datum/job/detective,
	/datum/job/bartender,
	/datum/job/botanist,
	/datum/job/cook,
	/datum/job/chaplain,
	/datum/job/curator,
	/datum/job/janitor,
	/datum/job/lawyer,
	/datum/job/clown,
	/datum/job/assistant,
	/datum/job/ai,
	/datum/job/cyborg
))

/datum/job
	/// The name of the job , used for preferences, bans and more. Make sure you know what you're doing before changing this.
	var/title = "NOPE"

	/// The description of the job, used for preferences menu.
	/// Keep it short and useful. Avoid in-jokes, these are for new players.
	var/description

	/// A string added to the on-join block to tell you how to use your radio.
	var/radio_help_message = "<b>Prefix your message with :h to speak on your department's radio. To see other prefixes, look closely at your headset.</b>"

	/// Innate skill levels unlocked at roundstart. Based on config.jobs_have_minimal_access config setting, for example with a skeleton crew. Format is list(/datum/skill/foo = SKILL_EXP_NOVICE) with exp as an integer or as per code/_DEFINES/skills.dm
	var/list/skills
	/// Innate skill levels unlocked at roundstart. Based on config.jobs_have_minimal_access config setting, for example with a full crew. Format is list(/datum/skill/foo = SKILL_EXP_NOVICE) with exp as an integer or as per code/_DEFINES/skills.dm
	var/list/minimal_skills

	/// Determines who can demote this position
	var/department_head = list()

	/// Tells the given channels that the given mob is the new department head. See communications.dm for valid channels.
	var/list/head_announce = null

	/// Bitflags for the job
	var/auto_deadmin_role_flags = NONE

	/// Players will be allowed to spawn in as jobs that are set to "Station"
	var/faction = FACTION_NONE

	/// How many players can be this job
	var/total_positions = 0

	/// How many players can spawn in as this job
	var/spawn_positions = 0

	/// How many players have this job
	var/current_positions = 0

	/// Supervisors, who this person answers to directly
	var/supervisors = ""

	/// Selection screen color
	var/selection_color = "#515151"

	/// What kind of mob type joining players with this job as their assigned role are spawned as.
	var/spawn_type = /mob/living/carbon/human

	/// If this is set to 1, a text is printed to the player when jobs are assigned, telling him that he should let admins know that he has to disconnect.
	var/req_admin_notify

	/// If you have the use_age_restriction_for_jobs config option enabled and the database set up, this option will add a requirement for players to be at least minimal_player_age days old. (meaning they first signed in at least that many days before.)
	var/minimal_player_age = 0

	var/outfit = null

	/// The job's outfit that will be assigned for plasmamen.
	var/plasmaman_outfit = null

	/// Different outfits for alternate job titles and different species
	var/list/outfits

	/// Minutes of experience-time required to play in this job. The type is determined by [exp_required_type] and [exp_required_type_department] depending on configs.
	var/exp_requirements = 0
	/// Experience required to play this job, if the config is enabled, and `exp_required_type_department` is not enabled with the proper config.
	var/exp_required_type = ""
	/// Department experience required to play this job, if the config is enabled.
	var/exp_required_type_department = ""
	/// Experience type granted by playing in this job.
	var/exp_granted_type = ""

	var/paycheck = PAYCHECK_MINIMAL
	var/paycheck_department = null

	var/list/mind_traits // Traits added to the mind of the mob assigned this job

	///Lazylist of traits added to the liver of the mob assigned this job (used for the classic "cops heal from donuts" reaction, among others)
	var/list/liver_traits = null

	/// Goodies that can be received via the mail system.
	// this is a weighted list.
	/// Keep the _job definition for this empty and use /obj/item/mail to define general gifts.
	var/list/mail_goodies = list()

	/// If this job's mail goodies compete with generic goodies.
	var/exclusive_mail_goodies = FALSE

	/// Bitfield of departments this job belongs to. These get setup when adding the job into the department, on job datum creation.
	var/departments_bitflags = NONE

	/// If specified, this department will be used for the preferences menu.
	var/datum/job_department/department_for_prefs = null

	/// Lazy list with the departments this job belongs to.
	/// Required to be set for playable jobs.
	/// The first department will be used in the preferences menu,
	/// unless department_for_prefs is set.
	var/list/departments_list = null

	/// Should this job be allowed to be picked for the bureaucratic error event?
	var/allow_bureaucratic_error = TRUE

	///Is this job affected by weird spawns like the ones from station traits
	var/random_spawns_possible = TRUE

	/// List of family heirlooms this job can get with the family heirloom quirk. List of types.
	var/list/family_heirlooms

	/// All values = (JOB_ANNOUNCE_ARRIVAL | JOB_CREW_MANIFEST | JOB_EQUIP_RANK | JOB_CREW_MEMBER | JOB_NEW_PLAYER_JOINABLE | JOB_ASSIGN_QUIRKS | JOB_CAN_BE_INTERN)
	var/job_flags = NONE

	/// Multiplier for general usage of the voice of god.
	var/voice_of_god_power = 1
	/// Multiplier for the silence command of the voice of god.
	var/voice_of_god_silence_power = 1

	/// String. If set to a non-empty one, it will be the key for the policy text value to show this role on spawn.
	var/policy_index = ""

	//PARIAH ADDITION START
	/// Job title to use for spawning. Allows a job to spawn without needing map edits.
	var/job_spawn_title
	//PARIAH ADDITION END

	///RPG job names, for the memes
	var/rpg_title

	/// What company can employ this job? First index is default
	var/list/employers = list()

	/// Default security status. Skipped if null.
	var/default_security_status = null


/datum/job/New()
	. = ..()
	//PARIAH ADDITION START
	if(!job_spawn_title)
		job_spawn_title = title
	//PARIAH ADDITION END
	var/list/jobs_changes = get_map_changes()
	if(!jobs_changes)
		return
	if(isnum(jobs_changes["spawn_positions"]))
		spawn_positions = jobs_changes["spawn_positions"]
	if(isnum(jobs_changes["total_positions"]))
		total_positions = jobs_changes["total_positions"]

/// Loads up map configs if necessary and returns job changes for this job.
/datum/job/proc/get_map_changes()
	var/string_type = "[type]"
	var/list/splits = splittext(string_type, "/")
	var/endpart = splits[splits.len]

	var/list/job_changes = SSmapping.config.job_changes
	if(!(endpart in job_changes))
		return list()

	return job_changes[endpart]


/// Executes after the mob has been spawned in the map. Client might not be yet in the mob, and is thus a separate variable.
/datum/job/proc/after_spawn(mob/living/spawned, client/player_client)
	SHOULD_CALL_PARENT(TRUE)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_JOB_AFTER_SPAWN, src, spawned, player_client)
	for(var/trait in mind_traits)
		ADD_TRAIT(spawned.mind, trait, JOB_TRAIT)

	var/obj/item/organ/liver/liver = spawned.getorganslot(ORGAN_SLOT_LIVER)
	if(liver)
		for(var/trait in liver_traits)
			ADD_TRAIT(liver, trait, JOB_TRAIT)

	if(!ishuman(spawned))
		return

	var/list/roundstart_experience

	if(!config) //Needed for robots.
		roundstart_experience = minimal_skills

	if(CONFIG_GET(flag/jobs_have_minimal_access))
		roundstart_experience = minimal_skills
	else
		roundstart_experience = skills

	if(roundstart_experience)
		var/mob/living/carbon/human/experiencer = spawned
		for(var/i in roundstart_experience)
			experiencer.mind.adjust_experience(i, roundstart_experience[i], TRUE)

/datum/job/proc/announce_job(mob/living/joining_mob)
	if(head_announce)
		announce_head(joining_mob, head_announce)

//Used for a special check of whether to allow a client to latejoin as this job.
/datum/job/proc/special_check_latejoin(client/latejoin)
	return TRUE


/mob/living/proc/on_job_equipping(datum/job/equipping)
	return

/mob/living/carbon/human/on_job_equipping(datum/job/equipping, datum/preferences/used_pref)
	var/datum/bank_account/bank_account = new(real_name, equipping)
	account_id = bank_account.account_id
	bank_account.replaceable = FALSE

	dress_up_as_job(equipping, FALSE, used_pref, TRUE)
	var/obj/item/storage/wallet/W = wear_id
	if(istype(W))
		var/monero = round(equipping.paycheck, 10)
		SSeconomy.spawn_ones_for_amount(monero, W)
	else
		bank_account.payday()

/mob/living/proc/dress_up_as_job(datum/job/equipping, visual_only = FALSE)
	return

/mob/living/carbon/human/dress_up_as_job(datum/job/equipping, visual_only = FALSE, datum/preferences/used_pref, use_loadout = FALSE)
	//Find job title in the first list, then pick the outfit based on species.
	if(!equipping.outfits)
		dna.species.pre_equip_species_outfit(null, src, visual_only)
		return//for jobs that don't come with any equipment or load outfits differently

	var/species2try = dna.species.job_outfit_type || dna.species.id //Uses the job_outfit_type of the species, if possible.
	var/datum/outfit/outfit2wear = equipping.outfits[used_pref?.alt_job_titles[equipping.title] || "Default"]?[species2try]
	outfit2wear ||= equipping.outfits["Default"]?[species2try]//A fallback that uses the default job title outfit for the species.
	outfit2wear ||= equipping.outfits["Default"]?[SPECIES_HUMAN]//Second fallback that uses the default job title and human outfit.
	if(!outfit2wear)
		outfit2wear = /datum/outfit/job//Emergency fallback that equips the generic "job outfit". This shouldn't happen unless something is wrong.
		stack_trace("[equipping] has no valid outfits in its list.")

	outfit2wear = new outfit2wear()
	dna.species.pre_equip_species_outfit(outfit2wear, src, visual_only)
	if(use_loadout)
		equip_outfit_and_loadout(outfit2wear, used_pref, visual_only, equipping)
	else
		equipOutfit(outfit2wear, visual_only)


/datum/job/proc/announce_head(mob/living/carbon/human/H, channels) //tells the given channel that the given mob is the new department head. See communications.dm for valid channels.
	if(!H)
		return

	//timer because these should come after the captain announcement
	SSshuttle.arrivals?.OnDock(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(_addtimer), CALLBACK(pick(GLOB.announcement_systems), TYPE_PROC_REF(/obj/machinery/announcement_system, announce), "NEWHEAD", H.real_name, H.job, channels), 1))

//If the configuration option is set to require players to be logged as old enough to play certain jobs, then this proc checks that they are, otherwise it just returns 1
/datum/job/proc/player_old_enough(client/player)
	if(!player || !available_in_days(player))
		return TRUE //Available in 0 days = available right now = player is old enough to play.
	return FALSE


/datum/job/proc/available_in_days(client/player)
	if(!player)
		return 0
	if(!CONFIG_GET(flag/use_age_restriction_for_jobs))
		return 0
	if(!SSdbcore.Connect())
		return 0 //Without a database connection we can't get a player's age so we'll assume they're old enough for all jobs
	if(!isnum(minimal_player_age))
		return 0

	return max(0, minimal_player_age - player.player_age)

/datum/job/proc/config_check()
	return TRUE

/datum/job/proc/map_check()
	var/list/job_changes = get_map_changes()
	if(!job_changes)
		return FALSE
	return TRUE

/datum/outfit/job
	name = "Standard Gear"

	var/jobtype = null
	/// If this job uses the Jumpskirt/Jumpsuit pref
	var/allow_jumpskirt = TRUE
	uniform = /obj/item/clothing/under/color/grey
	id = /obj/item/card/id/advanced
	ears = /obj/item/radio/headset
	back = /obj/item/storage/backpack
	shoes = /obj/item/clothing/shoes/sneakers/black
	box = /obj/item/storage/box/survival

	id_in_wallet = TRUE
	preload = TRUE // These are used by the prefs ui, and also just kinda could use the extra help at roundstart

	var/backpack = /obj/item/storage/backpack
	var/satchel = /obj/item/storage/backpack/satchel
	var/duffelbag = /obj/item/storage/backpack/duffelbag

	var/pda_slot = ITEM_SLOT_BELT

/datum/outfit/job/pre_equip(mob/living/carbon/human/H, visualsOnly = FALSE)
	if(ispath(back, /obj/item/storage/backpack))
		switch(H.backpack)
			if(GBACKPACK)
				back = /obj/item/storage/backpack //Grey backpack
			if(GSATCHEL)
				back = /obj/item/storage/backpack/satchel //Grey satchel
			if(GDUFFELBAG)
				back = /obj/item/storage/backpack/duffelbag //Grey Duffel bag
			if(LSATCHEL)
				back = /obj/item/storage/backpack/satchel/leather //Leather Satchel
			if(DSATCHEL)
				back = satchel //Department satchel
			if(DDUFFELBAG)
				back = duffelbag //Department duffel bag
			else
				back = backpack //Department backpack

	/// Handles jumpskirt pref
	if(allow_jumpskirt && H.jumpsuit_style == PREF_SKIRT)
		uniform = text2path("[uniform]/skirt") || uniform

	var/client/client = GLOB.directory[ckey(H.mind?.key)]

	if(client?.is_veteran() && client?.prefs.read_preference(/datum/preference/toggle/playtime_reward_cloak))
		neck = /obj/item/clothing/neck/cloak/skill_reward/playing

/datum/outfit/job/post_equip(mob/living/carbon/human/H, visualsOnly = FALSE)
	if(visualsOnly)
		return

	var/datum/job/J = SSjob.GetJobType(jobtype)
	if(!J)
		J = SSjob.GetJob(H.job)

	var/obj/item/card/id/card = H.wear_id.GetID(TRUE)
	if(istype(card))
		ADD_TRAIT(card, TRAIT_JOB_FIRST_ID_CARD, ROUNDSTART_TRAIT)
		shuffle_inplace(card.access) // Shuffle access list to make NTNet passkeys less predictable

		card.registered_name = H.real_name
		if(H.age)
			card.registered_age = H.age
		card.blood_type = H.dna.blood_type
		card.dna_hash = H.dna.unique_identity
		card.fingerprint = H.get_fingerprints(TRUE)
		card.update_label()
		card.update_icon()

		var/datum/bank_account/B = SSeconomy.bank_accounts_by_id["[H.account_id]"]
		if(B && B.account_id == H.account_id)
			card.registered_account = B
			B.bank_cards += card

		H.sec_hud_set_ID()
		if(!SSdatacore.finished_setup)
			card.RegisterSignal(SSdcs, COMSIG_GLOB_DATACORE_READY, TYPE_PROC_REF(/obj/item/card/id, datacore_ready))
		else
			spawn(5 SECONDS) //Race condition? I hardly knew her!
				card.set_icon()

	var/obj/item/modular_computer/tablet/pda/PDA = H.get_item_by_slot(pda_slot)
	if(istype(PDA))
		PDA.saved_identification = H.real_name
		PDA.saved_job = J.title
		PDA.UpdateDisplay()
		if(H.mind)
			spawn(-1) //Ssshhh linter don't worry about the lack of a user it's all gonna be okay.
				PDA.turn_on()

/datum/outfit/job/get_chameleon_disguise_info()
	var/list/types = ..()
	types -= /obj/item/storage/backpack //otherwise this will override the actual backpacks
	types += backpack
	types += satchel
	types += duffelbag
	return types

/datum/outfit/job/get_types_to_preload()
	var/list/preload = ..()
	preload += backpack
	preload += satchel
	preload += duffelbag
	preload += /obj/item/storage/backpack/satchel/leather
	var/skirtpath = "[uniform]/skirt"
	preload += text2path(skirtpath)
	return preload

/// An overridable getter for more dynamic goodies.
/datum/job/proc/get_mail_goodies(mob/recipient)
	return mail_goodies


/datum/job/proc/award_service(client/winner, award)
	return


/datum/job/proc/get_captaincy_announcement(mob/living/captain)
	return "Due to extreme staffing shortages, newly promoted Acting Captain [captain.real_name] on deck!"


/// Returns either an atom the mob should spawn in, or null, if we have no special overrides.
/datum/job/proc/get_roundstart_spawn_point()
	if(random_spawns_possible)
		return get_latejoin_spawn_point()

	if(length(GLOB.high_priority_spawns[title]))
		return pick(GLOB.high_priority_spawns[title])

	return null //We don't care where we go. Let Ticker decide for us.


/// Handles finding and picking a valid roundstart effect landmark spawn point, in case no uncommon different spawning events occur.
/datum/job/proc/get_default_roundstart_spawn_point()
	var/obj/effect/landmark/start/spawnpoint = get_start_landmark_for(title)
	if(!spawnpoint)
		log_world("Couldn't find a round start spawn point for [title].")

	spawnpoint.used = TRUE

	return spawnpoint

/// Finds a valid latejoin spawn point, checking for events and special conditions.
/datum/job/proc/get_latejoin_spawn_point()
	if(length(GLOB.high_priority_spawns[title])) //We're doing something special today.
		return pick(GLOB.high_priority_spawns[title])

	if(length(SSjob.latejoin_trackers))
		return pick(SSjob.latejoin_trackers)

	return SSjob.get_last_resort_spawn_points()


/// Spawns the mob to be played as, taking into account preferences and the desired spawn point.
/datum/job/proc/get_spawn_mob(client/player_client, atom/spawn_point)
	var/mob/living/spawn_instance
	if(ispath(spawn_type, /mob/living/silicon/ai))
		// This is unfortunately necessary because of snowflake AI init code. To be refactored.
		spawn_instance = new spawn_type(get_turf(spawn_point), null, player_client.mob)
	else
		spawn_instance = new spawn_type(player_client.mob.loc)
		spawn_point.JoinPlayerHere(spawn_instance, TRUE)
	spawn_instance.apply_prefs_job(player_client, src)
	if(!player_client)
		qdel(spawn_instance)
		return // Disconnected while checking for the appearance ban.
	return spawn_instance


/// Applies the preference options to the spawning mob, taking the job into account. Assumes the client has the proper mind.
/mob/living/proc/apply_prefs_job(client/player_client, datum/job/job)


/mob/living/carbon/human/apply_prefs_job(client/player_client, datum/job/job)
	var/fully_randomize = GLOB.current_anonymous_theme || is_banned_from(player_client.ckey, "Appearance")
	if(!player_client)
		return // Disconnected while checking for the appearance ban.

	var/require_human = FALSE

	src.job = job.title

	if(fully_randomize)
		player_client.prefs.apply_prefs_to(src)

		if(require_human)
			randomize_human_appearance(~RANDOMIZE_SPECIES)
		else
			randomize_human_appearance()

		if (require_human)
			set_species(/datum/species/human)
			dna.species.roundstart_changed = TRUE

		if(GLOB.current_anonymous_theme)
			fully_replace_character_name(null, GLOB.current_anonymous_theme.anonymous_name(src))
	else
		var/is_antag = (player_client.mob.mind in GLOB.pre_setup_antags)
		player_client.prefs.safe_transfer_prefs_to(src, TRUE, is_antag)

		if(require_human && !ishumanbasic(src))
			set_species(/datum/species/human)
			dna.species.roundstart_changed = TRUE
			apply_pref_name(/datum/preference/name/backup_human, player_client)

		if(CONFIG_GET(flag/force_random_names))
			var/species_type = player_client.prefs.read_preference(/datum/preference/choiced/species)
			var/datum/species/species = new species_type

			var/gender = player_client.prefs.read_preference(/datum/preference/choiced/gender)
			set_real_name(species.random_name(gender, TRUE))
	dna.update_dna_identity()


/mob/living/silicon/ai/apply_prefs_job(client/player_client, datum/job/job)
	if(GLOB.current_anonymous_theme)
		fully_replace_character_name(real_name, GLOB.current_anonymous_theme.anonymous_ai_name(TRUE))
		return
	apply_pref_name(/datum/preference/name/ai, player_client) // This proc already checks if the player is appearance banned.
	set_core_display_icon(null, player_client)


/mob/living/silicon/robot/apply_prefs_job(client/player_client, datum/job/job)
	if(mmi)
		var/organic_name
		if(GLOB.current_anonymous_theme)
			organic_name = GLOB.current_anonymous_theme.anonymous_name(src)
		else if(CONFIG_GET(flag/force_random_names) || is_banned_from(player_client.ckey, "Appearance"))
			if(!player_client)
				return // Disconnected while checking the appearance ban.

			var/species_type = player_client.prefs.read_preference(/datum/preference/choiced/species)
			var/datum/species/species = new species_type
			organic_name = species.random_name(player_client.prefs.read_preference(/datum/preference/choiced/gender), TRUE)
		else
			if(!player_client)
				return // Disconnected while checking the appearance ban.
			organic_name = player_client.prefs.read_preference(/datum/preference/name/real_name)

		mmi.name = "[initial(mmi.name)]: [organic_name]"
		if(mmi.brain)
			mmi.brain.name = "[organic_name]'s brain"
		if(mmi.brainmob)
			mmi.brainmob.set_real_name(organic_name)//the name of the brain inside the cyborg is the robotized human's name.

	// If this checks fails, then the name will have been handled during initialization.
	if(!GLOB.current_anonymous_theme && player_client.prefs.read_preference(/datum/preference/name/cyborg) != DEFAULT_CYBORG_NAME)
		apply_pref_name(/datum/preference/name/cyborg, player_client)

/**
 * Called after a successful roundstart spawn.
 * Client is not yet in the mob.
 * This happens after after_spawn()
 */
/datum/job/proc/after_roundstart_spawn(mob/living/spawning, client/player_client)
	SHOULD_CALL_PARENT(TRUE)


/**
 * Called after a successful latejoin spawn.
 * Client is in the mob.
 * This happens after after_spawn()
 */
/datum/job/proc/after_latejoin_spawn(mob/living/spawning)
	SHOULD_CALL_PARENT(TRUE)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_JOB_AFTER_LATEJOIN_SPAWN, src, spawning)

/// Called by SSjob when a player joins the round as this job.
/datum/job/proc/on_join_message(client/C, job_title_pref)
	var/job_header = "<u><span style='font-size: 200%'>You are the <span style='color:[selection_color]'>[job_title_pref]</span></span></u>."

	var/job_info = list("<br><br>[description]")

	if(supervisors)
		job_info += "<br><br>As the <span style='color:[selection_color]'>[job_title_pref == title ? job_title_pref : "[job_title_pref] ([title])"]</span> \
		you answer directly to [supervisors]. Special circumstances may change this."

	job_info += "<br><br>[radio_help_message]"

	to_chat(C, examine_block("[job_header][jointext(job_info, "")]"))

/// Called by SSjob when a player joins the round as this job.
/datum/job/proc/on_join_popup(client/C, job_title_pref)
	return
