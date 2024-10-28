DEFINE_INTERACTABLE(/mob/living)
/mob/living
	see_invisible = SEE_INVISIBLE_LIVING
	sight = 0
	see_in_dark = 2
	hud_possible = list(
		HEALTH_HUD = 'icons/mob/huds/hud.dmi',
		STATUS_HUD = 'icons/mob/huds/hud.dmi',
	)
	//pressure_resistance = 10

	hud_type = /datum/hud/living

	var/resize = 1 ///Badminnery resize
	var/lastattacker = null
	var/lastattackerckey = null

	//Health and life related vars
	/// Maximum health that should be possible.
	var/maxHealth = MAX_LIVING_HEALTH
	/// The mob's current health.
	var/health = MAX_LIVING_HEALTH

	/// The container for stats and skills
	var/datum/stats/stats
	///The holder for stamina handling
	var/datum/stamina_container/stamina

	//Damage related vars, NOTE: THESE SHOULD ONLY BE MODIFIED BY PROCS
	VAR_PROTECTED/bruteloss = 0 //!Brutal damage caused by brute force (punching, being clubbed by a toolbox ect... this also accounts for pressure damage)
	VAR_PROTECTED/oxyloss = 0 //!Oxygen depravation damage (no air in lungs)
	VAR_PROTECTED/toxloss = 0 //!Toxic damage caused by being poisoned or radiated
	VAR_PROTECTED/fireloss = 0 //!Burn damage caused by being way too hot, too cold or burnt.
	VAR_PROTECTED/cloneloss = 0 //!Damage caused by being cloned or ejected from the cloner early. slimes also deal cloneloss damage to victims

	var/crit_threshold = HEALTH_THRESHOLD_CRIT /// when the mob goes from "normal" to crit
	///When the mob enters hard critical state and is fully incapacitated.
	var/hardcrit_threshold = HEALTH_THRESHOLD_FULLCRIT

	/// Rate at which fire stacks should decay from this mob
	var/fire_stack_decay_rate = -0.05

	//Damage dealing vars! These are meaningless outside of specific instances where it's checked and defined.
	// Lower bound of damage done by unarmed melee attacks. Mob code is a mess, only works where this is checked for.
	var/melee_damage_lower = 0
	// Upper bound of damage done by unarmed melee attacks. Please ensure you check the xyz_defenses.dm for the mobs in question to see if it uses this or hardcoded values.
	var/melee_damage_upper = 0

	/// Generic bitflags for boolean conditions at the [/mob/living] level. Keep this for inherent traits of living types, instead of runtime-changeable ones.
	var/living_flags = NONE

	/// Flags that determine the potential of a mob to perform certain actions. Do not change this directly.
	var/mobility_flags = MOBILITY_FLAGS_DEFAULT

	var/resting = FALSE

	/// Variable to track the body position of a mob, regardgless of the actual angle of rotation (usually matching it, but not necessarily).
	var/body_position = STANDING_UP
	/// Number of degrees of rotation of a mob. 0 means no rotation, up-side facing NORTH. 90 means up-side rotated to face EAST, and so on.
	VAR_PROTECTED/lying_angle = 0
	/// Value of lying lying_angle before last change. TODO: Remove the need for this.
	var/lying_prev = 0

	var/hallucination = 0 ///Directly affects how long a mob will hallucinate for

	var/last_special = 0 ///Used by the resist verb, likely used to prevent players from bypassing next_move by logging in/out.
	/// Time of death as world.time
	var/timeofdeath = 0

	/// Helper vars for quick access to firestacks, these should be updated every time firestacks are adjusted
	var/on_fire = FALSE
	var/fire_stacks = 0

	/**			mind.mob_appearance = appearance
	  * Allows mobs to move through dense areas without restriction. For instance, in space or out of holder objects.
	  *
	  * FALSE is off, [INCORPOREAL_MOVE_BASIC] is normal, [INCORPOREAL_MOVE_SHADOW] is for ninjas
	  * and [INCORPOREAL_MOVE_JAUNT] is blocked by holy water/salt
	  */
	var/incorporeal_move = FALSE

	var/list/quirks = list()

	/// A lazylist of active surgeries and their relevant data.
	var/list/surgeries_in_progress

	///Mob specific surgery speed modifier
	var/mob_surgery_speed_mod = 1

	var/now_pushing = null //! Used by [living/Bump()][/mob/living/proc/Bump] and [living/PushAM()][/mob/living/proc/PushAM] to prevent potential infinite loop.

	var/cameraFollow = null

	/// Time of death in the in-game time format
	var/timeofdeath_as_ingame = null

	var/limb_destroyer = 0 //1 Sets AI behavior that allows mobs to target and dismember limbs with their basic attack.

	var/mob_size = MOB_SIZE_HUMAN
	var/mob_biotypes = MOB_ORGANIC
	var/metabolism_efficiency = 1 ///more or less efficiency to metabolize helpful/harmful reagents and regulate body temperature..
	var/has_limbs = FALSE ///does the mob have distinct limbs?(arms,legs, chest,head)

	///How many legs does this mob have by default. This shouldn't change at runtime.
	var/default_num_legs = 2
	///How many legs does this mob currently have. Should only be changed through set_num_legs()
	var/num_legs = 2
	///How many usable legs this mob currently has. Should only be changed through set_usable_legs()
	var/usable_legs = 2

	///How many hands does this mob have by default. This shouldn't change at runtime.
	var/default_num_hands = 2
	///How many hands hands does this mob currently have. Should only be changed through set_num_hands()
	var/num_hands = 2
	///How many usable hands does this mob currently have. Should only be changed through set_usable_hands()
	var/usable_hands = 2

	var/list/pipes_shown = list()
	var/last_played_vent = 0
	/// The last direction we moved in a vent. Used to make holding two directions feel nice
	var/last_vent_dir = 0
	/// Cell tracker datum we use to manage the pipes around us, for faster ventcrawling
	/// Should only exist if you're in a pipe
	var/datum/cell_tracker/pipetracker

	var/smoke_delay = 0 ///used to prevent spam with smoke reagent reaction on mob.

	var/bubble_icon = "default" ///what icon the mob uses for speechbubbles
	var/health_doll_icon ///if this exists AND the normal sprite is bigger than 32x32, this is the replacement icon state (because health doll size limitations). the icon will always be screen_gen.dmi

	var/last_bumped = 0
	var/unique_name = FALSE ///if a mob's name should be appended with an id when created e.g. Mob (666)
	var/numba = 0 ///the id a mob gets when it's created

	var/list/butcher_results = null ///these will be yielded from butchering with a probability chance equal to the butcher item's effectiveness
	var/list/guaranteed_butcher_results = null ///these will always be yielded from butchering
	var/butcher_difficulty = 0 ///effectiveness prob. is modified negatively by this amount; positive numbers make it more difficult, negative ones make it easier

	var/stun_absorption = null ///converted to a list of stun absorption sources this mob has when one is added

	var/blood_volume = 0 ///how much blood the mob has

	var/see_override = 0 ///0 for no override, sets see_invisible = see_override in silicon & carbon life process via update_sight()

	var/list/status_effects ///a list of all status effects the mob has
	var/list/implants = null

	var/last_words ///used for database logging

	var/ventcrawl_layer = PIPING_LAYER_DEFAULT
	var/losebreath = 0

	//List of active diseases
	var/list/diseases /// list of all diseases in a mob
	var/list/disease_resistances

	/// List of changes to body temperature, used by desease symtoms like fever
	var/list/body_temp_changes = list()

	/// The type of /obj/item/mob_holder to create if the mob is picked up.
	var/held_type = /obj/item/mob_holder
	/// The w_class of the holder when held.
	var/held_w_class = WEIGHT_CLASS_NORMAL
	///if it can be held, can it be equipped to any slots? (think pAI's on head)
	var/worn_slot_flags = NONE
	//this stuff is here to make it simple for admins to mess with custom held sprites
	var/icon/held_lh = 'icons/mob/pets_held_lh.dmi'//icons for holding mobs
	var/icon/held_rh = 'icons/mob/pets_held_rh.dmi'
	var/icon/head_icon = 'icons/mob/pets_held.dmi'//what it looks like on your head
	var/held_state = ""//icon state for the above

	///If combat mode is on or not
	var/combat_mode = FALSE

	/// Is this mob allowed to be buckled/unbuckled to/from things?
	var/can_buckle_to = TRUE

	/// A lazylist of grab objects we have
	var/list/active_grabs

	///The y amount a mob's sprite should be offset due to the current position they're in (e.g. lying down moves your sprite down)
	var/body_position_pixel_x_offset = 0
	///The x amount a mob's sprite should be offset due to the current position they're in
	var/body_position_pixel_y_offset = 0

	///what multiplicative slowdown we get from turfs currently.
	var/current_turf_slowdown = 0

	///The amount of times we've opened our stupid mouth
	var/talkcount = 0

	///The talk chime set to use when speaking.
	var/voice_type

	COOLDOWN_DECLARE(smell_time)
	var/datum/weakref/next_smell

	/// What our current gravity state is. Used to avoid duplicate animates and such
	var/gravity_state = null

	///Used for lookup/lookdown verbs
	var/mob/camera/z_eye/z_eye

	///Gunpoint container
	var/obj/effect/abstract/aim_overlay/gunpoint
	var/gunpoint_flags = TARGET_CAN_MOVE | TARGET_CAN_INTERACT | TARGET_CAN_RADIO
	var/use_gunpoint = FALSE

	/// How many ticks of Life() has this mob gone through
	var/life_ticks = 0
	/// Chemical effects. Built by the chemical processing stage of Life().
	var/list/chem_effects = list()

	/// For each life tick, how many do we skip?
	var/stasis_level = 0
	/// List of stasis sources to their given value
	var/list/stasis_sources = list()
