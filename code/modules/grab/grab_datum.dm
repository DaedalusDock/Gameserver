/// An associative list of type:instance for grab datums
GLOBAL_LIST_EMPTY(all_grabstates)
/datum/grab
	abstract_type = /datum/grab
	var/icon = 'icons/hud/screen_gen.dmi'
	var/icon_state

	/// The grab that this will upgrade to if it upgrades, null means no upgrade
	var/datum/grab/upgrab
	/// The grab that this will downgrade to if it downgrades, null means break grab on downgrade
	var/datum/grab/downgrab

	// Whether or not the grabbed person can move out of the grab
	var/stop_move = FALSE
	// Whether the assailant is facing forwards or backwards.
	var/reverse_facing = FALSE
	/// Whether this grab state is strong enough to, as a changeling, absorb the person you're grabbing.
	var/can_absorb = FALSE
	/// How much the grab increases point blank damage.
	var/point_blank_mult = 1
	/// Affects how much damage is being dealt using certain actions.
	var/damage_stage = GRAB_PASSIVE
	/// If the grabbed person and the grabbing person are on the same tile.
	var/same_tile = FALSE
	/// If the grabber can throw the person grabbed.
	var/can_throw = FALSE
	/// If the grab needs to be downgraded when the grabber does stuff.
	var/downgrade_on_action = FALSE
	/// If the grab needs to be downgraded when the grabber moves.
	var/downgrade_on_move = FALSE
	/// If the grab is strong enough to be able to force someone to do something harmful to them, like slam their head into glass.
	var/enable_violent_interactions = FALSE
	/// If the grab acts like cuffs and prevents action from the victim.
	var/restrains = FALSE

	var/grab_slowdown = 0

	var/shift = 0

	var/success_up = "You upgrade the grab."
	var/success_down = "You downgrade the grab."

	var/fail_up = "You fail to upgrade the grab."
	var/fail_down = "You fail to downgrade the grab."

	var/upgrade_cooldown = 4 SECONDS
	var/action_cooldown = 4 SECONDS

	var/can_downgrade_on_resist = TRUE

	/// The baseline index of break_chance_table, before modifiers. This can be higher than the length of break_chance_table.
	var/breakability = 2
	var/list/break_chance_table = list(100)

	var/can_grab_self = TRUE

	// The names of different intents for use in attack logs
	var/help_action = ""
	var/disarm_action = ""
	var/grab_action = ""
	var/harm_action = ""

/*
	These procs shouldn't be overriden in the children unless you know what you're doing with them; they handle important core functions.
	Even if you do override them, you should likely be using ..() if you want the behaviour to function properly. That is, of course,
	unless you're writing your own custom handling of things.
*/
/// Called during world/New to setup references.
/datum/grab/proc/refresh_updown()
	if(upgrab)
		upgrab = GLOB.all_grabstates[upgrab]

	if(downgrab)
		downgrab = GLOB.all_grabstates[downgrab]

/// Called by the grab item's setup() proc. May return FALSE to interrupt, otherwise the grab has succeeded.
/datum/grab/proc/setup(obj/item/hand_item/grab)
	SHOULD_CALL_PARENT(TRUE)
	return TRUE

// This is for the strings defined as datum variables. It takes them and swaps out keywords for relevent ones from the grab
// object involved.
/datum/grab/proc/string_process(obj/item/hand_item/grab/G, to_write, obj/item/used_item)
	to_write = replacetext(to_write, "rep_affecting", G.affecting)
	to_write = replacetext(to_write, "rep_assailant", G.assailant)
	if(used_item)
		to_write = replacetext(to_write, "rep_item", used_item)
	return to_write

/datum/grab/proc/upgrade(obj/item/hand_item/grab/G)
	if(!upgrab)
		return

	if (can_upgrade(G))
		upgrade_effect(G)
		return upgrab
	else
		to_chat(G.assailant, span_warning("[string_process(G, fail_up)]"))
		return

/datum/grab/proc/downgrade(obj/item/hand_item/grab/G)
	// Starts the process of letting go if there's no downgrade grab
	if(can_downgrade())
		downgrade_effect(G)
		return downgrab
	else
		to_chat(G.assailant, span_warning("[string_process(G, fail_down)]"))
		return

/// DO NOT CALL THIS DIRECTLY GOOD LORD!!! This should ONLY be called by /obj/item/hand_item/grab/Destroy()
/datum/grab/proc/let_go(obj/item/hand_item/grab/G)
	SHOULD_NOT_OVERRIDE(TRUE)
	if(!G)
		return

	remove_bodyzone_effects(G, G.target_zone)
	if(G.is_grab_unique(src))
		remove_unique_grab_effects(G.affecting)

	update_stage_effects(G, src, TRUE)
	G.affecting.update_offsets()

	SEND_SIGNAL(G.affecting, COMSIG_ATOM_NO_LONGER_GRABBED, G.assailant)
	SEND_SIGNAL(G.assailant, COMSIG_LIVING_NO_LONGER_GRABBING, G.affecting)

/datum/grab/proc/on_target_change(obj/item/hand_item/grab/G, old_zone, new_zone)
	remove_bodyzone_effects(G, old_zone, new_zone)
	G.special_target_functional = check_special_target(G)
	if(G.special_target_functional)
		special_bodyzone_change(G, old_zone, new_zone)
		special_bodyzone_effects(G)

/datum/grab/proc/hit_with_grab(obj/item/hand_item/grab/G, atom/target, params)
	if(G.is_currently_resolving_hit)
		return FALSE

	if(!COOLDOWN_FINISHED(G, action_cd))
		to_chat(G.assailant, span_warning("You must wait [round(COOLDOWN_TIMELEFT(G, action_cd) * 0.1, 0.1)] seconds before you can perform a grab action."))
		return FALSE

	if(downgrade_on_action)
		G.downgrade()

	G.is_currently_resolving_hit = TRUE

	var/combat_mode = G.assailant.combat_mode
	if(params[RIGHT_CLICK])
		if(on_hit_disarm(G, target))
			. = disarm_action || TRUE

	else if(params[CTRL_CLICK])
		if(on_hit_grab(G, target))
			. = grab_action || TRUE


	else if(combat_mode)
		if(on_hit_harm(G, target))
			. = harm_action || TRUE
	else
		if(on_hit_help(G, target))
			. = help_action || TRUE

	if(QDELETED(G))
		return

	G.is_currently_resolving_hit = FALSE

	if(!.)
		return

	G.action_used()
	if(G.assailant)
		G.assailant.changeNext_move(CLICK_CD_GRABBING)
		if(istext(.) && G.affecting)
			make_log(G, "used [.] on")

	if(downgrade_on_action)
		G.downgrade()

/datum/grab/proc/make_log(obj/item/hand_item/grab/G, action)
	log_combat(G.assailant, G.affecting, "[action] their victim")

/*
	Override these procs to set how the grab state will work. Some of them are best
	overriden in the parent of the grab set (for example, the behaviour for on_hit_intent(var/obj/item/hand_item/grab/G)
	procs is determined in /datum/grab/normal and then inherited by each intent).
*/

// What happens when you upgrade from one grab state to the next.
/datum/grab/proc/upgrade_effect(obj/item/hand_item/grab/G)
	SHOULD_CALL_PARENT(TRUE)

	G.remove_competing_grabs()

// Conditions to see if upgrading is possible
/datum/grab/proc/can_upgrade(obj/item/hand_item/grab/G)
	if(!upgrab)
		return FALSE

	var/mob/living/L = G.get_affecting_mob()
	if(!isliving(L))
		return FALSE

	if(!(L.status_flags & CANPUSH) || HAS_TRAIT(L, TRAIT_PUSHIMMUNE))
		to_chat(G.assailant, span_warning("[src] can't be grabbed more aggressively!"))
		return FALSE

	if(upgrab.damage_stage >= GRAB_AGGRESSIVE && HAS_TRAIT(G.assailant, TRAIT_PACIFISM))
		to_chat(G.assailant, span_warning("You don't want to risk hurting [src]!"))
		return FALSE

	for(var/obj/item/hand_item/grab/other_grab in L.grabbed_by - G)
		if(other_grab.assailant.move_force > G.assailant.move_force)
			to_chat(G.assailant, span_warning("[G.assailant]'s grip is too strong."))
			return FALSE
	return TRUE

// What happens when you downgrade from one grab state to the next.
/datum/grab/proc/downgrade_effect(obj/item/hand_item/grab/G)
	SEND_SIGNAL(G.assailant, COMSIG_LIVING_GRAB_DOWNGRADE, G)
	return

// Conditions to see if downgrading is possible
/datum/grab/proc/can_downgrade(obj/item/hand_item/grab/G)
	return TRUE

// What happens when you let go of someone by either dropping the grab
// or by downgrading from the lowest grab state.
/datum/grab/proc/let_go_effect(obj/item/hand_item/grab/G)
	PRIVATE_PROC(TRUE)

	remove_bodyzone_effects(G, G.target_zone)
	if(G.is_grab_unique(src))
		remove_unique_grab_effects(G.affecting)

	update_stage_effects(G, src, TRUE)

	SEND_SIGNAL(G.affecting, COMSIG_ATOM_NO_LONGER_GRABBED, G.assailant)
	SEND_SIGNAL(G.assailant, COMSIG_LIVING_NO_LONGER_GRABBING, G.affecting)

/// Add effects that apply based on damage_stage here
/datum/grab/proc/update_stage_effects(obj/item/hand_item/grab/G, datum/grab/old_grab, dropping_grab)
	var/old_damage_stage = old_grab?.damage_stage || GRAB_PASSIVE
	var/new_stage = dropping_grab ? GRAB_PASSIVE : damage_stage

	var/trait_source = ref(G)
	var/atom/movable/affected_movable = G.affecting

	switch(new_stage) // Current state.
		if(GRAB_PASSIVE)
			REMOVE_TRAIT(affected_movable, TRAIT_IMMOBILIZED, trait_source)
			REMOVE_TRAIT(affected_movable, TRAIT_HANDS_BLOCKED, trait_source)
			if(old_damage_stage >= GRAB_AGGRESSIVE)
				REMOVE_TRAIT(affected_movable, TRAIT_AGGRESSIVE_GRAB, trait_source)
				REMOVE_TRAIT(affected_movable, TRAIT_FLOORED, trait_source)
				affected_movable.layer -= 0.001

		if(GRAB_AGGRESSIVE)
			if(old_damage_stage >= GRAB_NECK) // Grab got downgraded.
				REMOVE_TRAIT(affected_movable, TRAIT_FLOORED, trait_source)
			else // Grab got upgraded from a passive one.
				ADD_TRAIT(affected_movable, TRAIT_IMMOBILIZED, trait_source)
				ADD_TRAIT(affected_movable, TRAIT_HANDS_BLOCKED, trait_source)
				ADD_TRAIT(affected_movable, TRAIT_AGGRESSIVE_GRAB, trait_source)
				affected_movable.layer += 0.001

		if(GRAB_NECK, GRAB_KILL)
			if(old_damage_stage < GRAB_AGGRESSIVE)
				ADD_TRAIT(affected_movable, TRAIT_AGGRESSIVE_GRAB, REF(G))
				affected_movable.layer += 0.001
			if(old_damage_stage <= GRAB_AGGRESSIVE)
				ADD_TRAIT(affected_movable, TRAIT_FLOORED, REF(G))
				ADD_TRAIT(affected_movable, TRAIT_HANDS_BLOCKED, REF(G))
				ADD_TRAIT(affected_movable, TRAIT_IMMOBILIZED, REF(G))

	//DEBUG CODE
	if((new_stage < GRAB_AGGRESSIVE) && HAS_TRAIT_FROM_ONLY(affected_movable, TRAIT_AGGRESSIVE_GRAB, trait_source))
		stack_trace("AAAAAA a grab victim somehow still has trait_aggressive_grab when they shouldnt, removing it!")
		REMOVE_TRAIT(affected_movable, TRAIT_AGGRESSIVE_GRAB, trait_source)

/// Apply effects that should only be applied when a grab type is first used on a mob.
/datum/grab/proc/apply_unique_grab_effects(atom/movable/affecting)
	SHOULD_CALL_PARENT(TRUE)
	if(same_tile && ismob(affecting))
		affecting.add_passmob(ref(src))

/// Remove effects added by apply_unique_grab_effects()
/datum/grab/proc/remove_unique_grab_effects(atom/movable/affecting)
	SHOULD_CALL_PARENT(TRUE)
	if(same_tile && ismob(affecting))
		affecting.remove_passmob(ref(src))

/// Handles special targeting like eyes and mouth being covered.
/// CLEAR OUT ANY EFFECTS USING remove_bodyzone_effects()
/datum/grab/proc/special_bodyzone_effects(obj/item/hand_item/grab/G)
	SHOULD_CALL_PARENT(TRUE)
	var/mob/living/carbon/C = G.affecting
	if(!istype(C))
		return

	var/obj/item/bodypart/BP = C.get_bodypart(deprecise_zone(G.target_zone))
	if(!BP)
		return

	ADD_TRAIT(BP, TRAIT_BODYPART_GRABBED, REF(G))

/// Clear out any effects from special_bodyzone_effects()
/datum/grab/proc/remove_bodyzone_effects(obj/item/hand_item/grab/G, old_zone, new_zone)
	SHOULD_CALL_PARENT(TRUE)
	var/mob/living/carbon/C = G.affecting
	if(!istype(C))
		return

	var/obj/item/bodypart/BP = C.get_bodypart(deprecise_zone(old_zone))
	if(!BP)
		return

	REMOVE_TRAIT(BP, TRAIT_BODYPART_GRABBED, REF(G))

// Handles when they change targeted areas and something is supposed to happen.
/datum/grab/proc/special_bodyzone_change(obj/item/hand_item/grab/G, diff_zone)

// Checks if the special target works on the grabbed humanoid.
/datum/grab/proc/check_special_target(obj/item/hand_item/grab/G)

// What happens when you hit the grabbed person with the grab on help intent.
/datum/grab/proc/on_hit_help(obj/item/hand_item/grab/G)
	return FALSE

// What happens when you hit the grabbed person with the grab on disarm intent.
/datum/grab/proc/on_hit_disarm(obj/item/hand_item/grab/G)
	return FALSE

// What happens when you hit the grabbed person with the grab on grab intent.
/datum/grab/proc/on_hit_grab(obj/item/hand_item/grab/G)
	return FALSE

// What happens when you hit the grabbed person with the grab on harm intent.
/datum/grab/proc/on_hit_harm(obj/item/hand_item/grab/G)
	return FALSE

// What happens when you hit the grabbed person with an open hand and you want it
// to do some special snowflake action based on some other factor such as
// intent.
/datum/grab/proc/resolve_openhand_attack(obj/item/hand_item/grab/G)
	return FALSE

// Used when you want an effect to happen when the grab enters this state as an upgrade
/// Return TRUE unless the grab state is changing during this proc (for example, calling upgrade())
/datum/grab/proc/enter_as_up(obj/item/hand_item/grab/G, silent)
	SHOULD_CALL_PARENT(TRUE)
	return TRUE

// Used when you want an effect to happen when the grab enters this state as a downgrade
/// Return TRUE unless the grab state is changing during this proc (for example, calling upgrade())
/datum/grab/proc/enter_as_down(obj/item/hand_item/grab/G, silent)
	SHOULD_CALL_PARENT(TRUE)
	return TRUE

/datum/grab/proc/item_attack(obj/item/hand_item/grab/G, obj/item)

/datum/grab/proc/resolve_item_attack(obj/item/hand_item/grab/G, mob/living/carbon/human/user, obj/item/I, target_zone)
	return FALSE

/// Handle resist actions from the affected mob. Returns TRUE if the grab was broken.
/datum/grab/proc/handle_resist(obj/item/hand_item/grab/G)
	var/mob/living/carbon/human/affecting = G.affecting
	var/mob/living/carbon/human/assailant = G.assailant

	var/break_strength = breakability + size_difference(affecting, assailant)
	var/affecting_shock = affecting.getPain()
	var/assailant_shock = assailant.getPain()

	// Target modifiers
	if(affecting.incapacitated(IGNORE_GRAB))
		break_strength--
	if(affecting.has_status_effect(/datum/status_effect/confusion))
		break_strength--
	if(affecting.eye_blind || HAS_TRAIT(affecting, TRAIT_BLIND))
		break_strength--
	if(affecting.eye_blurry)
		break_strength--
	if(affecting_shock >= 10)
		break_strength--
	if(affecting_shock >= 30)
		break_strength--
	if(affecting_shock >= 50)
		break_strength--

	// User modifiers
	if(assailant.has_status_effect(/datum/status_effect/confusion))
		break_strength++
	if(assailant.eye_blind || HAS_TRAIT(assailant, TRAIT_BLIND))
		break_strength++
	if(assailant.eye_blurry)
		break_strength++
	if(assailant_shock >= 10)
		break_strength++
	if(assailant_shock >= 30)
		break_strength++
	if(assailant_shock >= 50)
		break_strength++

	if(break_strength < 1)
		to_chat(G.affecting, span_warning("You try to break free but feel that unless something changes, you'll never escape!"))
		return FALSE

	if (assailant.incapacitated(IGNORE_GRAB))
		qdel(G)
		stack_trace("Someone resisted a grab while the assailant was incapacitated. This shouldn't ever happen.")
		return TRUE

	var/break_chance = break_chance_table[clamp(break_strength, 1, length(break_chance_table))]
	if(prob(break_chance))
		if(can_downgrade_on_resist && !prob((break_chance+100)/2))
			affecting.visible_message(span_danger("[affecting] has loosened [assailant]'s grip!"), vision_distance = COMBAT_MESSAGE_RANGE)
			G.downgrade()
			return FALSE
		else
			affecting.visible_message(span_danger("[affecting] has broken free of [assailant]'s grip!"), vision_distance = COMBAT_MESSAGE_RANGE)
			qdel(G)
			return TRUE

/datum/grab/proc/size_difference(mob/living/A, mob/living/B)
	return mob_size_difference(A.mob_size, B.mob_size)

/datum/grab/proc/moved_effect(obj/item/hand_item/grab/G)
	return

/// Add screentip context, user will always be assailant.
/datum/grab/proc/add_context(list/context, obj/item/held_item, mob/living/user, atom/movable/target)
	if(!(isgrab(held_item) && held_item:current_grab == src))
		return

	if(disarm_action)
		context[SCREENTIP_CONTEXT_RMB] = capitalize(disarm_action)

	if(grab_action)
		context[SCREENTIP_CONTEXT_CTRL_LMB] = capitalize(grab_action)

	if(user.combat_mode)
		if(harm_action)
			context[SCREENTIP_CONTEXT_LMB] = capitalize(harm_action)

	else if(help_action)
		context[SCREENTIP_CONTEXT_LMB] = capitalize(help_action)

/datum/grab/proc/get_grab_offsets(obj/item/hand_item/grab/G, grab_direction, pixel_x_pointer, pixel_y_pointer)
	if(!grab_direction || !G.current_grab.shift)
		return

	if(grab_direction & WEST)
		*pixel_x_pointer = min(*pixel_x_pointer + shift, G.affecting.base_pixel_x + shift)

	else if(grab_direction & EAST)
		*pixel_x_pointer = max(*pixel_x_pointer - shift, G.affecting.base_pixel_x - shift)

	if(grab_direction & NORTH)
		*pixel_y_pointer = max(*pixel_y_pointer - shift, G.affecting.base_pixel_y - shift)

	else if(grab_direction & SOUTH)
		*pixel_y_pointer = min(*pixel_y_pointer + shift, G.affecting.base_pixel_y + shift)

