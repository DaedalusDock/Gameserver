/atom/movable
	layer = OBJ_LAYER
	glide_size = 8
	appearance_flags = TILE_BOUND|PIXEL_SCALE|LONG_GLIDE

	/// The last direction we moved in.
	var/tmp/last_move = null
	var/tmp/list/active_movement

	///Are we moving with inertia? Mostly used as an optimization
	var/tmp/inertia_moving = FALSE
	///The last time we pushed off something
	///This is a hack to get around dumb him him me scenarios
	var/tmp/last_pushoff
	///0: not doing a diagonal move. 1 and 2: doing the first/second step of the diagonal move
	var/tmp/moving_diagonally = 0
	/// Tracks if the mob is currently in the movechain during a pulling movement.
	var/tmp/moving_from_pull = FALSE
	/// Tracks if forceMove() should break grabs or not.
	var/tmp/forcemove_should_maintain_grab = FALSE

	///is the mob currently ascending or descending through z levels?
	var/tmp/currently_z_moving

	///Holds information about any movement loops currently running/waiting to run on the movable. Lazy, will be null if nothing's going on
	var/tmp/datum/movement_packet/move_packet
	var/tmp/datum/forced_movement/force_moving = null //handled soley by forced_movement.dm

	/**
	 * an associative lazylist of relevant nested contents by "channel", the list is of the form: list(channel = list(important nested contents of that type))
	 * each channel has a specific purpose and is meant to replace potentially expensive nested contents iteration.
	 * do NOT add channels to this for little reason as it can add considerable memory usage.
	 */
	var/tmp/list/important_recursive_contents
	///contains every client mob corresponding to every client eye in this container. lazily updated by SSparallax and is sparse:
	///only the last container of a client eye has this list assuming no movement since SSparallax's last fire
	var/tmp/list/client_mobs_in_contents

	/// String representing the spatial grid groups we want to be held in.
	/// acts as a key to the list of spatial grid contents types we exist in via SSspatial_grid.spatial_grid_categories.
	/// We do it like this to prevent people trying to mutate them and to save memory on holding the lists ourselves
	var/tmp/spatial_grid_key

	var/tmp/datum/component/orbiter/orbiting

	///Lazylist to keep track on the sources of illumination.
	var/tmp/list/affected_dynamic_lights
	///Highest-intensity light affecting us, which determines our visibility.
	var/tmp/affecting_dynamic_lumi = 0

	///For storing what do_after's someone has, key = string, value = amount of interactions of that type happening.
	var/tmp/list/do_afters

	///A lazylist of grab objects gripping us
	var/tmp/list/grabbed_by

	/// A ref to the throwing datum belonging to us.
	var/tmp/datum/thrownthing/throwing = null

	/// Look, we're defining this here so it doesn't need to be redefined 4 times, okay? Sorry.
	var/tmp/germ_level = GERM_LEVEL_AMBIENT

	var/anchored = FALSE
	var/move_resist = MOVE_RESIST_DEFAULT
	var/move_force = MOVE_FORCE_DEFAULT
	var/pull_force = PULL_FORCE_DEFAULT

	//How many tiles to move per ds when being thrown. Float values are fully supported.
	var/throw_speed = 1
	var/throw_range = 7
	/// How much damage the object deals when impacting something else.
	var/throwforce = 0

	///Max range this atom can be thrown via telekinesis
	var/tk_throw_range = 10
	var/initial_language_holder = /datum/language_holder
	var/datum/language_holder/language_holder // Mindless mobs and objects need language too, some times. Mind holder takes prescedence.
	var/verb_say = "says"
	var/verb_ask = "asks"
	var/verb_exclaim = "exclaims"
	var/verb_whisper = "whispers"
	var/verb_sing = "sings"
	var/verb_yell = "yells"
	var/speech_span

	///Delay in deciseconds between inertia based movement
	var/inertia_move_delay = 5

	/// Things we can pass through while moving. If any of this matches the thing we're trying to pass's [pass_flags_self], then we can pass through.
	var/pass_flags = NONE
	/// If false makes [CanPass][/atom/proc/CanPass] call [CanPassThrough][/atom/movable/proc/CanPassThrough] on this type instead of using default behaviour
	var/generic_canpass = TRUE

	/**
	  * In case you have multiple types, you automatically use the most useful one.
	  * IE: Skating on ice, flippers on water, flying over chasm/space, etc.
	  * I reccomend you use the movetype_handler system and not modify this directly, especially for living mobs.
	  */
	var/movement_type = GROUND

	/// Either FALSE, [EMISSIVE_BLOCK_GENERIC], or [EMISSIVE_BLOCK_UNIQUE]
	var/blocks_emissive = FALSE
	///Internal holder for emissive blocker object, do not use directly use blocks_emissive
	var/tmp/atom/movable/emissive_blocker/em_block

	///Used for the calculate_adjacencies proc for icon smoothing.
	var/can_be_unanchored = FALSE

	/// Whether this atom should have its dir automatically changed when it moves. Setting this to FALSE allows for things such as directional windows to retain dir on moving without snowflake code all of the place.
	var/set_dir_on_move = TRUE

	/// The degree of thermal insulation that mobs in list/contents have from the external environment, between 0 and 1
	var/contents_thermal_insulation = 0
	/// The degree of pressure protection that mobs in list/contents have from the external environment, between 0 and 1
	var/contents_pressure_protection = 0

/mutable_appearance/emissive_blocker

/mutable_appearance/emissive_blocker/New()
	. = ..()
	// Need to do this here because it's overriden by the parent call
	plane = EMISSIVE_PLANE
	color = EM_BLOCK_COLOR
	appearance_flags = EMISSIVE_APPEARANCE_FLAGS

/atom/movable/Initialize(mapload)
	. = ..()
	switch(blocks_emissive)
		if(EMISSIVE_BLOCK_GENERIC)
			var/static/mutable_appearance/emissive_blocker/blocker = new()
			blocker.icon = icon
			blocker.icon_state = icon_state
			blocker.dir = dir
			blocker.appearance_flags |= appearance_flags
			// Ok so this is really cursed, but I want to set with this blocker cheaply while
			// Still allowing it to be removed from the overlays list later
			// So I'm gonna flatten it, then insert the flattened overlay into overlays AND the managed overlays list, directly
			// I'm sorry
			var/mutable_appearance/flat = blocker.appearance
			overlays += flat
			if(managed_overlays)
				if(islist(managed_overlays))
					managed_overlays += flat
				else
					managed_overlays = list(managed_overlays, flat)
			else
				managed_overlays = flat
		if(EMISSIVE_BLOCK_UNIQUE)
			render_target = ref(src)
			em_block = new(null, src)
			overlays += em_block
			if(managed_overlays)
				if(islist(managed_overlays))
					managed_overlays += em_block
				else
					managed_overlays = list(managed_overlays, em_block)
			else
				managed_overlays = em_block

	if(opacity)
		AddElement(/datum/element/light_blocking)
	switch(light_system)
		if(OVERLAY_LIGHT)
			AddComponent(/datum/component/overlay_lighting)
		if(OVERLAY_LIGHT_DIRECTIONAL)
			AddComponent(/datum/component/overlay_lighting, is_directional = TRUE)

/atom/movable/Destroy(force)
	QDEL_NULL(language_holder)
	QDEL_NULL(em_block)
	if (bound_overlay)
		QDEL_NULL(bound_overlay)

	unbuckle_all_mobs(force = TRUE)

	if(loc)
		//Restore air flow if we were blocking it (movables with zas_canpass() will need to do this manually if necessary)
		if(isturf(loc) && (can_atmos_pass != CANPASS_ALWAYS))
			can_atmos_pass = CANPASS_ALWAYS
			zas_update_loc()

		loc.handle_atom_del(src)

	if(opacity)
		RemoveElement(/datum/element/light_blocking)

	invisibility = INVISIBILITY_ABSTRACT

	if(orbiting)
		orbiting.end_orbit(src)
		orbiting = null

	if(move_packet)
		if(!QDELETED(move_packet))
			qdel(move_packet)
		move_packet = null

	if(spatial_grid_key)
		SSspatial_grid.force_remove_from_grid(src)

	LAZYNULL(client_mobs_in_contents)

	. = ..()

	for(var/movable_content in contents)
		qdel(movable_content)

	moveToNullspace()

	//This absolutely must be after moveToNullspace()
	//We rely on Entered and Exited to manage this list, and the copy of this list that is on any /atom/movable "Containers"
	//If we clear this before the nullspace move, a ref to this object will be hung in any of its movable containers
	LAZYNULL(important_recursive_contents)


	vis_locs = null //clears this atom out of all viscontents
	if(length(vis_contents))
		cut_viscontents()

/atom/movable/proc/update_emissive_block()
	if(!blocks_emissive)
		return
	if (blocks_emissive == EMISSIVE_BLOCK_GENERIC)
		return fast_emissive_blocker(src)

	if(blocks_emissive == EMISSIVE_BLOCK_UNIQUE)
		if(!em_block && !QDELETED(src))
			render_target = ref(src)
			em_block = new(null, src, render_target)
		return em_block

/atom/movable/update_overlays()
	. = ..()
	var/emissive_block = update_emissive_block()
	if(emissive_block)
		. += emissive_block

/atom/movable/vv_edit_var(var_name, var_value)
	var/static/list/banned_edits = list(
		NAMEOF_STATIC(src, step_x) = TRUE,
		NAMEOF_STATIC(src, step_y) = TRUE,
		NAMEOF_STATIC(src, step_size) = TRUE,
		NAMEOF_STATIC(src, bounds) = TRUE
		)
	var/static/list/careful_edits = list(
		NAMEOF_STATIC(src, bound_x) = TRUE,
		NAMEOF_STATIC(src, bound_y) = TRUE,
		NAMEOF_STATIC(src, bound_width) = TRUE,
		NAMEOF_STATIC(src, bound_height) = TRUE
		)
	var/static/list/not_falsey_edits = list(
		NAMEOF_STATIC(src, bound_width) = TRUE,
		NAMEOF_STATIC(src, bound_height) = TRUE
		)
	if(banned_edits[var_name])
		return FALSE //PLEASE no.
	if(careful_edits[var_name] && (var_value % world.icon_size) != 0)
		return FALSE
	if(not_falsey_edits[var_name] && !var_value)
		return FALSE

	switch(var_name)
		if(NAMEOF(src, x))
			var/turf/current_turf = locate(var_value, y, z)
			if(current_turf)
				admin_teleport(current_turf)
				return TRUE
			return FALSE
		if(NAMEOF(src, y))
			var/turf/T = locate(x, var_value, z)
			if(T)
				admin_teleport(T)
				return TRUE
			return FALSE
		if(NAMEOF(src, z))
			var/turf/T = locate(x, y, var_value)
			if(T)
				admin_teleport(T)
				return TRUE
			return FALSE
		if(NAMEOF(src, loc))
			if(isatom(var_value) || isnull(var_value))
				admin_teleport(var_value)
				return TRUE
			return FALSE
		if(NAMEOF(src, anchored))
			set_anchored(var_value)
			. = TRUE
		if(NAMEOF(src, glide_size))
			set_glide_size(var_value)
			. = TRUE

	if(!isnull(.))
		datum_flags |= DF_VAR_EDITED
		return

	return ..()

/atom/movable/proc/set_glide_size(target = 8)
	SEND_SIGNAL(src, COMSIG_MOVABLE_UPDATE_GLIDE_SIZE, target)
	glide_size = target

	for(var/mob/buckled_mob as anything in buckled_mobs)
		buckled_mob.set_glide_size(target)

/**
 * meant for movement with zero side effects. only use for objects that are supposed to move "invisibly" (like camera mobs or ghosts)
 * if you want something to move onto a tile with a beartrap or recycler or tripmine or mouse without that object knowing about it at all, use this
 * most of the time you want forceMove()FALS
 */
/atom/movable/proc/abstract_move(atom/new_loc)
	if(QDELING(src))
		CRASH("Illegal abstract_move() on [type]!")

	RESOLVE_ACTIVE_MOVEMENT

	var/atom/old_loc = loc
	var/direction = get_dir(old_loc, new_loc)
	loc = new_loc
	Moved(old_loc, direction, TRUE, momentum_change = FALSE)

////////////////////////////////////////
// Here's where we rewrite how byond handles movement except slightly different
// To be removed on step_ conversion
// All this work to prevent a second bump
/atom/movable/Move(atom/newloc, direction, glide_size_override = 0, z_movement_flags)
	. = FALSE

	if(!newloc || newloc == loc)
		return

	// A mid-movement... movement... occured, resolve that first.
	RESOLVE_ACTIVE_MOVEMENT

	if(!direction)
		direction = get_dir(src, newloc)

	if(set_dir_on_move && dir != direction && !(dir & (UP|DOWN)))
		setDir(direction)

	var/is_multi_tile_object = bound_width > 32 || bound_height > 32

	var/list/old_locs
	if(is_multi_tile_object && isturf(loc))
		old_locs = locs // locs is a special list, this is effectively the same as .Copy() but with less steps
		for(var/atom/exiting_loc as anything in old_locs)
			if(!exiting_loc.Exit(src, direction))
				return
	else
		if(!loc.Exit(src, direction))
			return

	var/list/new_locs
	if(is_multi_tile_object && isturf(newloc))
		new_locs = block(
			newloc,
			locate(
				min(world.maxx, newloc.x + CEILING(bound_width / 32, 1)),
				min(world.maxy, newloc.y + CEILING(bound_height / 32, 1)),
				newloc.z
				)
		) // If this is a multi-tile object then we need to predict the new locs and check if they allow our entrance.
		for(var/atom/entering_loc as anything in new_locs)
			if(!entering_loc.Enter(src))
				return
			if(SEND_SIGNAL(src, COMSIG_MOVABLE_PRE_MOVE, entering_loc) & COMPONENT_MOVABLE_BLOCK_PRE_MOVE)
				return
	else // Else just try to enter the single destination.
		if(!newloc.Enter(src))
			return
		if(SEND_SIGNAL(src, COMSIG_MOVABLE_PRE_MOVE, newloc) & COMPONENT_MOVABLE_BLOCK_PRE_MOVE)
			return

	// Past this is the point of no return
	var/atom/oldloc = loc
	var/area/oldarea = get_area(oldloc)
	var/area/newarea = get_area(newloc)

	SET_ACTIVE_MOVEMENT(oldloc, direction, FALSE, old_locs)
	loc = newloc

	. = TRUE

	if(old_locs) // This condition will only be true if it is a multi-tile object.
		for(var/atom/exited_loc as anything in (old_locs - new_locs))
			exited_loc.Exited(src, direction)
	else // Else there's just one loc to be exited.
		oldloc.Exited(src, direction)
	if(oldarea != newarea)
		oldarea.Exited(src, direction)

	if(new_locs) // Same here, only if multi-tile.
		for(var/atom/entered_loc as anything in (new_locs - old_locs))
			entered_loc.Entered(src, oldloc, old_locs)
	else
		newloc.Entered(src, oldloc, old_locs)

	if(oldarea != newarea)
		newarea.Entered(src, oldarea)

	RESOLVE_ACTIVE_MOVEMENT

////////////////////////////////////////

/atom/movable/Move(atom/newloc, direct, glide_size_override = 0, z_movement_flags)
	if(!loc || !newloc)
		return FALSE

	if(!moving_from_pull)
		recheck_grabs(z_allowed = TRUE)

	if(direct & (UP|DOWN))
		if(!can_z_move(direct, null, z_movement_flags))
			return FALSE
		set_currently_z_moving(ZMOVING_VERTICAL)

	var/atom/oldloc = loc
	//Early override for some cases like diagonal movement
	if(glide_size_override && glide_size != glide_size_override)
		set_glide_size(glide_size_override)

	if(loc != newloc)
		if (!(direct & (direct - 1))) //Cardinal move
			. = ..()
		else //Diagonal move, split it into cardinal moves
			moving_diagonally = FIRST_DIAG_STEP
			var/first_step_dir
			// The `&& moving_diagonally` checks are so that a forceMove taking
			// place due to a Crossed, Bumped, etc. call will interrupt
			// the second half of the diagonal movement, or the second attempt
			// at a first half if step() fails because we hit something.
			if (direct & NORTH)
				if (direct & EAST)
					if (step(src, NORTH) && moving_diagonally)
						first_step_dir = NORTH
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, EAST)
					else if (moving_diagonally && step(src, EAST))
						first_step_dir = EAST
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, NORTH)
				else if (direct & WEST)
					if (step(src, NORTH) && moving_diagonally)
						first_step_dir = NORTH
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, WEST)
					else if (moving_diagonally && step(src, WEST))
						first_step_dir = WEST
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, NORTH)
			else if (direct & SOUTH)
				if (direct & EAST)
					if (step(src, SOUTH) && moving_diagonally)
						first_step_dir = SOUTH
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, EAST)
					else if (moving_diagonally && step(src, EAST))
						first_step_dir = EAST
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, SOUTH)
				else if (direct & WEST)
					if (step(src, SOUTH) && moving_diagonally)
						first_step_dir = SOUTH
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, WEST)
					else if (moving_diagonally && step(src, WEST))
						first_step_dir = WEST
						moving_diagonally = SECOND_DIAG_STEP
						. = step(src, SOUTH)
			if(moving_diagonally == SECOND_DIAG_STEP)
				if(!. && set_dir_on_move)
					setDir(first_step_dir)
				else if(!inertia_moving)
					newtonian_move(direct)
				if(client_mobs_in_contents)
					update_parallax_contents()
			moving_diagonally = 0
			return

	if(!loc || (loc == oldloc && oldloc != newloc))
		last_move = 0
		set_currently_z_moving(FALSE)
		return

	if(set_dir_on_move && dir != direct)
		setDir(direct)

	if(. && isliving(src) && currently_z_moving != ZMOVING_LATERAL)
		var/mob/living/L = src
		L.handle_grabs_during_movement(oldloc, direct)

	recheck_grabs(only_pulled = TRUE)

	//glide_size strangely enough can change mid movement animation and update correctly while the animation is playing
	//This means that if you don't override it late like this, it will just be set back by the movement update that's called when you move turfs.
	if(glide_size_override)
		set_glide_size(glide_size_override)

	last_move = direct

	if(. && has_buckled_mobs() && !handle_buckled_mob_movement(loc, direct, glide_size_override)) //movement failed due to buckled mob(s)
		. = FALSE

	if(currently_z_moving)
		set_currently_z_moving(FALSE)

/// Called when src is being moved to a target turf because another movable (puller) is moving around.
/atom/movable/proc/move_from_pull(atom/movable/puller, turf/target_turf, glide_size_override)
	moving_from_pull = TRUE
	forcemove_should_maintain_grab = TRUE
	. = Move(target_turf, get_dir(src, target_turf), glide_size_override)
	moving_from_pull = FALSE
	forcemove_should_maintain_grab = FALSE

	update_offsets()

/**
 * Called after a successful Move(). By this point, we've already moved.
 * Arguments:
 * * old_loc is the location prior to the move. Can be null to indicate nullspace.
 * * movement_dir is the direction the movement took place. Can be NONE if it was some sort of teleport.
 * * The forced flag indicates whether this was a forced move, which skips many checks of regular movement.
 * * The old_locs is an optional argument, in case the moved movable was present in multiple locations before the movement.
 * * momentum_change represents whether this movement is due to a "new" force if TRUE or an already "existing" force if FALSE
 **/
/atom/movable/proc/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	SHOULD_CALL_PARENT(TRUE)

	if (!inertia_moving && momentum_change)
		newtonian_move(movement_dir)
	// If we ain't moving diagonally right now, update our parallax
	// We don't do this all the time because diag movements should trigger one call to this, not two
	// Waste of cpu time, and it fucks the animate
	if (!moving_diagonally && client_mobs_in_contents)
		update_parallax_contents()

	SEND_SIGNAL(src, COMSIG_MOVABLE_MOVED, old_loc, movement_dir, forced, old_locs, momentum_change)

	if(old_loc)
		SEND_SIGNAL(old_loc, COMSIG_ATOM_ABSTRACT_EXITED, src, movement_dir)
	if(loc)
		SEND_SIGNAL(loc, COMSIG_ATOM_ABSTRACT_ENTERED, src, old_loc, old_locs)

	var/turf/old_turf = get_turf(old_loc)
	var/turf/new_turf = get_turf(src)

	if (old_turf?.z != new_turf?.z)
		on_changed_z_level(old_turf, new_turf)

	if(HAS_SPATIAL_GRID_CONTENTS(src))
		if(old_turf && new_turf && (old_turf.z != new_turf.z \
			|| GET_SPATIAL_INDEX(old_turf.x) != GET_SPATIAL_INDEX(new_turf.x) \
			|| GET_SPATIAL_INDEX(old_turf.y) != GET_SPATIAL_INDEX(new_turf.y)))

			SSspatial_grid.exit_cell(src, old_turf)
			SSspatial_grid.enter_cell(src, new_turf)

		else if(old_turf && !new_turf)
			SSspatial_grid.exit_cell(src, old_turf)

		else if(new_turf && !old_turf)
			SSspatial_grid.enter_cell(src, new_turf)

	// Z-Mimic hook
	if (bound_overlay)
		// The overlay will handle cleaning itself up on non-openspace turfs.
		if (new_turf)
			var/turf/target = GetAbove(src)
			if (target)
				bound_overlay.forceMove(target)
				if (bound_overlay && dir != bound_overlay.dir)
					bound_overlay.setDir(dir)
			else
				qdel(bound_overlay)
		else	// Not a turf, so we need to destroy immediately instead of waiting for the destruction timer to proc.
			qdel(bound_overlay)

	return TRUE

// Make sure you know what you're doing if you call this, this is intended to only be called by byond directly.
// You probably want CanPass()
/atom/movable/Cross(atom/movable/crosser)
	. = TRUE
	return CanPass(crosser, get_dir(src, crosser))

///default byond proc that is deprecated for us in lieu of signals. do not call
/atom/movable/Crossed(atom/movable/crossed_by, oldloc)
	SHOULD_NOT_OVERRIDE(TRUE)
	CRASH("atom/movable/Crossed() was called!")

/**
 * `Uncross()` is a default BYOND proc that is called when something is *going*
 * to exit this atom's turf. It is prefered over `Uncrossed` when you want to
 * deny that movement, such as in the case of border objects, objects that allow
 * you to walk through them in any direction except the one they block
 * (think side windows).
 *
 * While being seemingly harmless, most everything doesn't actually want to
 * use this, meaning that we are wasting proc calls for every single atom
 * on a turf, every single time something exits it, when basically nothing
 * cares.
 *
 * This overhead caused real problems on Sybil round #159709, where lag
 * attributed to Uncross was so bad that the entire master controller
 * collapsed and people made Among Us lobbies in OOC.
 *
 * If you want to replicate the old `Uncross()` behavior, the most apt
 * replacement is [`/datum/element/connect_loc`] while hooking onto
 * [`COMSIG_ATOM_EXIT`].
 */
/atom/movable/Uncross()
	SHOULD_NOT_OVERRIDE(TRUE)
	CRASH("Uncross() should not be being called, please read the doc-comment for it for why.")

/**
 * default byond proc that is normally called on everything inside the previous turf
 * a movable was in after moving to its current turf
 * this is wasteful since the vast majority of objects do not use Uncrossed
 * use connect_loc to register to COMSIG_ATOM_EXITED instead
 */
/atom/movable/Uncrossed(atom/movable/uncrossed_atom)
	SHOULD_NOT_OVERRIDE(TRUE)
	CRASH("/atom/movable/Uncrossed() was called")

/atom/movable/Bump(atom/bumped_atom)
	if(!bumped_atom)
		CRASH("Bump was called with no argument.")
	SEND_SIGNAL(src, COMSIG_MOVABLE_BUMP, bumped_atom)

	. = ..()

	if(!QDELETED(throwing))
		throwing.finalize(hit = TRUE, target = bumped_atom)
		. = TRUE
		if(QDELETED(bumped_atom))
			return

	bumped_atom.BumpedBy(src)

	if(moving_by_airflow && !QDELING(src))
		if(airflow_speed >= 1 && airflow_dest)
			AirflowBump(bumped_atom)
		else
			SSairflow.Dequeue(src)

/atom/movable/Exited(atom/movable/gone, direction)
	. = ..()

	if(!LAZYLEN(gone.important_recursive_contents))
		return
	var/list/nested_locs = get_nested_locs(src) + src
	for(var/channel in gone.important_recursive_contents)
		for(var/atom/movable/location as anything in nested_locs)
			var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
			recursive_contents[channel] -= gone.important_recursive_contents[channel]
			switch(channel)
				if(RECURSIVE_CONTENTS_CLIENT_MOBS, RECURSIVE_CONTENTS_HEARING_SENSITIVE, RECURSIVE_CONTENTS_RADIO_NONATMOS, RECURSIVE_CONTENTS_RADIO_ATMOS)
					if(!length(recursive_contents[channel]))
						// This relies on a nice property of the linked recursive and gridmap types
						// They're defined in relation to each other, so they have the same value
						SSspatial_grid.remove_grid_awareness(location, channel)
			ASSOC_UNSETEMPTY(recursive_contents, channel)
			UNSETEMPTY(location.important_recursive_contents)

/atom/movable/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()

	if(!LAZYLEN(arrived.important_recursive_contents))
		return
	var/list/nested_locs = get_nested_locs(src) + src
	for(var/channel in arrived.important_recursive_contents)
		for(var/atom/movable/location as anything in nested_locs)
			LAZYINITLIST(location.important_recursive_contents)
			var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
			LAZYINITLIST(recursive_contents[channel])
			switch(channel)
				if(RECURSIVE_CONTENTS_CLIENT_MOBS, RECURSIVE_CONTENTS_HEARING_SENSITIVE, RECURSIVE_CONTENTS_RADIO_NONATMOS, RECURSIVE_CONTENTS_RADIO_ATMOS)
					if(!length(recursive_contents[channel]))
						SSspatial_grid.add_grid_awareness(location, channel)
			recursive_contents[channel] |= arrived.important_recursive_contents[channel]

///allows this movable to hear and adds itself to the important_recursive_contents list of itself and every movable loc its in
/atom/movable/proc/become_hearing_sensitive(trait_source = TRAIT_GENERIC)
	ADD_TRAIT(src, TRAIT_HEARING_SENSITIVE, trait_source)
	if(!HAS_TRAIT(src, TRAIT_HEARING_SENSITIVE))
		return

	for(var/atom/movable/location as anything in get_nested_locs(src) + src)
		LAZYINITLIST(location.important_recursive_contents)
		var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
		if(!length(recursive_contents[RECURSIVE_CONTENTS_HEARING_SENSITIVE]))
			SSspatial_grid.add_grid_awareness(location, SPATIAL_GRID_CONTENTS_TYPE_HEARING)
		recursive_contents[RECURSIVE_CONTENTS_HEARING_SENSITIVE] += list(src)

	var/turf/our_turf = get_turf(src)
	SSspatial_grid.add_grid_membership(src, our_turf, SPATIAL_GRID_CONTENTS_TYPE_HEARING)

///allows this movable to hear and adds itself to the important_recursive_contents list of itself and every movable loc its in
/atom/movable/proc/become_radio_sensitive(trait_source = TRAIT_GENERIC)
	ADD_TRAIT(src, TRAIT_HEARING_SENSITIVE, trait_source)
	if(!HAS_TRAIT(src, TRAIT_HEARING_SENSITIVE))
		return

	for(var/atom/movable/location as anything in get_nested_locs(src) + src)
		LAZYINITLIST(location.important_recursive_contents)
		var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
		if(!length(recursive_contents[RECURSIVE_CONTENTS_HEARING_SENSITIVE]))
			SSspatial_grid.add_grid_awareness(location, SPATIAL_GRID_CONTENTS_TYPE_HEARING)
		recursive_contents[RECURSIVE_CONTENTS_HEARING_SENSITIVE] += list(src)

	var/turf/our_turf = get_turf(src)
	SSspatial_grid.add_grid_membership(src, our_turf, SPATIAL_GRID_CONTENTS_TYPE_HEARING)

/**
 * removes the hearing sensitivity channel from the important_recursive_contents list of this and all nested locs containing us if there are no more sources of the trait left
 * since RECURSIVE_CONTENTS_HEARING_SENSITIVE is also a spatial grid content type, removes us from the spatial grid if the trait is removed
 *
 * * trait_source - trait source define or ALL, if ALL, force removes hearing sensitivity. if a trait source define, removes hearing sensitivity only if the trait is removed
 */
/atom/movable/proc/lose_hearing_sensitivity(trait_source = TRAIT_GENERIC)
	if(!HAS_TRAIT(src, TRAIT_HEARING_SENSITIVE))
		return
	REMOVE_TRAIT(src, TRAIT_HEARING_SENSITIVE, trait_source)
	if(HAS_TRAIT(src, TRAIT_HEARING_SENSITIVE))
		return

	var/turf/our_turf = get_turf(src)
	/// We get our awareness updated by the important recursive contents stuff, here we remove our membership
	SSspatial_grid.remove_grid_membership(src, our_turf, SPATIAL_GRID_CONTENTS_TYPE_HEARING)

	for(var/atom/movable/location as anything in get_nested_locs(src) + src)
		var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
		recursive_contents[RECURSIVE_CONTENTS_HEARING_SENSITIVE] -= src
		if(!length(recursive_contents[RECURSIVE_CONTENTS_HEARING_SENSITIVE]))
			SSspatial_grid.remove_grid_awareness(location, SPATIAL_GRID_CONTENTS_TYPE_HEARING)
		ASSOC_UNSETEMPTY(recursive_contents, RECURSIVE_CONTENTS_HEARING_SENSITIVE)
		UNSETEMPTY(location.important_recursive_contents)

///allows this movable to know when it has "entered" another area no matter how many movable atoms its stuffed into, uses important_recursive_contents
/atom/movable/proc/become_area_sensitive(trait_source = TRAIT_GENERIC)
	if(!HAS_TRAIT(src, TRAIT_AREA_SENSITIVE))
		for(var/atom/movable/location as anything in get_nested_locs(src) + src)
			LAZYADDASSOCLIST(location.important_recursive_contents, RECURSIVE_CONTENTS_AREA_SENSITIVE, src)
	ADD_TRAIT(src, TRAIT_AREA_SENSITIVE, trait_source)

///removes the area sensitive channel from the important_recursive_contents list of this and all nested locs containing us if there are no more source of the trait left
/atom/movable/proc/lose_area_sensitivity(trait_source = TRAIT_GENERIC)
	if(!HAS_TRAIT(src, TRAIT_AREA_SENSITIVE))
		return
	REMOVE_TRAIT(src, TRAIT_AREA_SENSITIVE, trait_source)
	if(HAS_TRAIT(src, TRAIT_AREA_SENSITIVE))
		return

	for(var/atom/movable/location as anything in get_nested_locs(src) + src)
		LAZYREMOVEASSOC(location.important_recursive_contents, RECURSIVE_CONTENTS_AREA_SENSITIVE, src)

///propogates ourselves through our nested contents, similar to other important_recursive_contents procs
///main difference is that client contents need to possibly duplicate recursive contents for the clients mob AND its eye
/mob/proc/enable_client_mobs_in_contents()
	for(var/atom/movable/movable_loc as anything in get_nested_locs(src) + src)
		LAZYINITLIST(movable_loc.important_recursive_contents)
		var/list/recursive_contents = movable_loc.important_recursive_contents // blue hedgehog velocity
		if(!length(recursive_contents[RECURSIVE_CONTENTS_CLIENT_MOBS]))
			SSspatial_grid.add_grid_awareness(movable_loc, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS)
		LAZYINITLIST(recursive_contents[RECURSIVE_CONTENTS_CLIENT_MOBS])
		recursive_contents[RECURSIVE_CONTENTS_CLIENT_MOBS] |= src

	var/turf/our_turf = get_turf(src)
	/// We got our awareness updated by the important recursive contents stuff, now we add our membership
	SSspatial_grid.add_grid_membership(src, our_turf, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS)

///Clears the clients channel of this mob
/mob/proc/clear_important_client_contents()
	var/turf/our_turf = get_turf(src)
	SSspatial_grid.remove_grid_membership(src, our_turf, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS)

	for(var/atom/movable/movable_loc as anything in get_nested_locs(src) + src)
		var/list/recursive_contents = movable_loc.important_recursive_contents // blue hedgehog velocity
		recursive_contents[RECURSIVE_CONTENTS_CLIENT_MOBS] -= src
		if(!length(recursive_contents[RECURSIVE_CONTENTS_CLIENT_MOBS]))
			SSspatial_grid.remove_grid_awareness(movable_loc, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS)
		ASSOC_UNSETEMPTY(recursive_contents, RECURSIVE_CONTENTS_CLIENT_MOBS)
		UNSETEMPTY(movable_loc.important_recursive_contents)

///called when this movable becomes the parent of a storage component that is currently being viewed by a player. uses important_recursive_contents
/atom/movable/proc/become_active_storage(datum/storage/source)
	if(!HAS_TRAIT(src, TRAIT_ACTIVE_STORAGE))
		for(var/atom/movable/location as anything in get_nested_locs(src) + src)
			LAZYADDASSOCLIST(location.important_recursive_contents, RECURSIVE_CONTENTS_ACTIVE_STORAGE, src)
	ADD_TRAIT(src, TRAIT_ACTIVE_STORAGE, REF(source))

///called when this movable's storage component is no longer viewed by any players, unsets important_recursive_contents
/atom/movable/proc/lose_active_storage(datum/storage/source)
	if(!HAS_TRAIT(src, TRAIT_ACTIVE_STORAGE))
		return
	REMOVE_TRAIT(src, TRAIT_ACTIVE_STORAGE, REF(source))
	if(HAS_TRAIT(src, TRAIT_ACTIVE_STORAGE))
		return

	for(var/atom/movable/location as anything in get_nested_locs(src) + src)
		LAZYREMOVEASSOC(location.important_recursive_contents, RECURSIVE_CONTENTS_ACTIVE_STORAGE, src)

///Sets the anchored var and returns if it was sucessfully changed or not.
/atom/movable/proc/set_anchored(anchorvalue)
	SHOULD_CALL_PARENT(TRUE)
	if(anchored == anchorvalue)
		return
	. = anchored
	anchored = anchorvalue
	SEND_SIGNAL(src, COMSIG_MOVABLE_SET_ANCHORED, anchorvalue)

/// Sets the currently_z_moving variable to a new value. Used to temporarily disable some Move() side effects.
/atom/movable/proc/set_currently_z_moving(new_z_moving_value)
	if(new_z_moving_value == currently_z_moving)
		return FALSE
	currently_z_moving = new_z_moving_value
	return TRUE

/atom/movable/proc/forceMove(atom/destination)
	if(QDELING(src))
		CRASH("Illegal forceMove() on [type]!")

	. = FALSE
	if(destination)
		. = doMove(destination)
	else
		CRASH("No valid destination passed into forceMove")

/atom/movable/proc/moveToNullspace()
	return doMove(null)

/atom/movable/proc/doMove(atom/destination)
	. = FALSE
	RESOLVE_ACTIVE_MOVEMENT

	var/atom/oldloc = loc
	var/is_multi_tile = bound_width > world.icon_size || bound_height > world.icon_size

	SET_ACTIVE_MOVEMENT(oldloc, NONE, TRUE, null)
	if(destination)
		var/same_loc = oldloc == destination
		var/area/old_area = get_area(oldloc)
		var/area/destarea = get_area(destination)
		var/movement_dir = get_dir(src, destination)

		moving_diagonally = 0

		loc = destination

		if(!same_loc)
			if(is_multi_tile && isturf(destination))
				var/list/new_locs = block(
					destination,
					locate(
						min(world.maxx, destination.x + ROUND_UP(bound_width / 32)),
						min(world.maxy, destination.y + ROUND_UP(bound_height / 32)),
						destination.z
					)
				)
				if(old_area && old_area != destarea)
					old_area.Exited(src, movement_dir)
				for(var/atom/left_loc as anything in locs - new_locs)
					left_loc.Exited(src, movement_dir)

				for(var/atom/entering_loc as anything in new_locs - locs)
					entering_loc.Entered(src, movement_dir)

				if(old_area && old_area != destarea)
					destarea.Entered(src, movement_dir)
			else
				if(oldloc)
					oldloc.Exited(src, movement_dir)
					if(old_area && old_area != destarea)
						old_area.Exited(src, movement_dir)
				destination.Entered(src, oldloc)
				if(destarea && old_area != destarea)
					destarea.Entered(src, old_area)

		. = TRUE

	//If no destination, move the atom into nullspace (don't do this unless you know what you're doing)
	else
		. = TRUE

		if (oldloc)
			loc = null
			var/area/old_area = get_area(oldloc)
			if(is_multi_tile && isturf(oldloc))
				for(var/atom/old_loc as anything in locs)
					old_loc.Exited(src, NONE)
			else
				oldloc.Exited(src, NONE)

			if(old_area)
				old_area.Exited(src, NONE)

	RESOLVE_ACTIVE_MOVEMENT

/**
 * Called when a movable changes z-levels.
 *
 * Arguments:
 * * old_z - The previous z-level they were on before.
 * * notify_contents - Whether or not to notify the movable's contents that their z-level has changed.
 */
/atom/movable/proc/on_changed_z_level(turf/old_turf, turf/new_turf, notify_contents = TRUE)
	SEND_SIGNAL(src, COMSIG_MOVABLE_Z_CHANGED, old_turf, new_turf)

	bound_overlay?.z_shift()

	if(!notify_contents)
		return

	for (var/atom/movable/content as anything in src) // Notify contents of Z-transition.
		content.on_changed_z_level(old_turf, new_turf)

/**
 * Called whenever an object moves and by mobs when they attempt to move themselves through space
 * And when an object or action applies a force on src, see [newtonian_move][/atom/movable/proc/newtonian_move]
 *
 * Return FALSE to have src start/keep drifting in a no-grav area and TRUE to stop/not start drifting
 *
 * Mobs should return 1 if they should be able to move of their own volition, see [/client/proc/Move]
 *
 * Arguments:
 * * movement_dir - 0 when stopping or any dir when trying to move
 * * continuous_move - If this check is coming from something in the context of already drifting
 */
/atom/movable/proc/Process_Spacemove(movement_dir = 0, continuous_move = FALSE)
	if(anchored)
		return TRUE

	if(has_gravity())
		return TRUE

	if(SEND_SIGNAL(src, COMSIG_MOVABLE_SPACEMOVE, movement_dir, continuous_move) & COMSIG_MOVABLE_STOP_SPACEMOVE)
		return TRUE

	// If we are being pulled by something AND (we are NOT pulling them OR we are moving from a pull), do not drift
	if(LAZYLEN(grabbed_by))
		var/can_drift = TRUE
		if(isliving(src))
			var/mob/living/L = src
			for(var/obj/item/hand_item/grab/G in grabbed_by)
				if(!L.is_grabbing(G.assailant))
					can_drift = FALSE // Something is grabbing us and we're not grabbing them
		else
			can_drift = FALSE

		if(!can_drift || moving_from_pull)
			return TRUE

	if(throwing)
		return TRUE

	if(!isturf(loc))
		return TRUE

	if(locate(/obj/structure/lattice) in range(1, get_turf(src))) //Not realistic but makes pushing things in space easier
		return TRUE

	return FALSE


/// Only moves the object if it's under no gravity
/// Accepts the direction to move, if the push should be instant, and an optional parameter to fine tune the start delay
/atom/movable/proc/newtonian_move(direction, instant = FALSE, start_delay = 0)
	if(!isturf(loc) || Process_Spacemove(direction, continuous_move = TRUE))
		return FALSE

	if(SEND_SIGNAL(src, COMSIG_MOVABLE_NEWTONIAN_MOVE, direction, start_delay) & COMPONENT_MOVABLE_NEWTONIAN_BLOCK)
		return TRUE

	AddComponent(/datum/component/drift, direction, instant, start_delay)

	return TRUE

/atom/movable/proc/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	set waitfor = FALSE
	var/hitpush = TRUE
	var/impact_signal = SEND_SIGNAL(src, COMSIG_MOVABLE_IMPACT, hit_atom, throwingdatum)
	if(impact_signal & COMPONENT_MOVABLE_IMPACT_FLIP_HITPUSH)
		hitpush = FALSE // hacky, tie this to something else or a proper workaround later

	if(!(impact_signal && (impact_signal & COMPONENT_MOVABLE_IMPACT_NEVERMIND))) // in case a signal interceptor broke or deleted the thing before we could process our hit
		return hit_atom.hitby(src, throwingdatum=throwingdatum, hitpush=hitpush)

/atom/movable/hitby(atom/movable/hitting_atom, skipcatch, hitpush = TRUE, blocked, datum/thrownthing/throwingdatum)
	if(!anchored && hitpush && (!throwingdatum || (throwingdatum.force >= (move_resist * MOVE_FORCE_PUSH_RATIO))))
		step(src, hitting_atom.dir)
	..()

/atom/movable/proc/safe_throw_at(atom/target, range, speed, mob/thrower, spin = TRUE, diagonals_first = FALSE, datum/callback/callback, force = MOVE_FORCE_STRONG, gentle = FALSE)
	if((force < (move_resist * MOVE_FORCE_THROW_RATIO)) || (move_resist == INFINITY))
		return
	return throw_at(target, range, speed, thrower, spin, diagonals_first, callback, force, gentle)

///If this returns FALSE then callback will not be called.
/atom/movable/proc/throw_at(atom/target, range, speed, mob/thrower, spin = TRUE, diagonals_first = FALSE, datum/callback/callback, force = MOVE_FORCE_STRONG, gentle = FALSE, quickstart = TRUE)
	. = FALSE

	if(QDELETED(src))
		CRASH("Qdeleted thing being thrown around.")

	if (!target || speed <= 0)
		return

	if(SEND_SIGNAL(src, COMSIG_MOVABLE_PRE_THROW, args) & COMPONENT_CANCEL_THROW)
		return

	//They are moving! Wouldn't it be cool if we calculated their momentum and added it to the throw?
	if (thrower && thrower.last_move && thrower.client && thrower.client.move_delay >= world.time + world.tick_lag*2)
		var/user_momentum = thrower.movement_delay
		if (!user_momentum) //no movement_delay, this means they move once per byond tick, lets calculate from that instead.
			user_momentum = world.tick_lag

		user_momentum = 1 / user_momentum // convert from ds to the tiles per ds that throw_at uses.

		if (get_dir(thrower, target) & last_move)
			user_momentum = user_momentum //basically a noop, but needed
		else if (get_dir(target, thrower) & last_move)
			user_momentum = -user_momentum //we are moving away from the target, lets slowdown the throw accordingly
		else
			user_momentum = 0


		if (user_momentum)
			//first lets add that momentum to range.
			range *= (user_momentum / speed) + 1
			//then lets add it to speed
			speed += user_momentum
			if (speed <= 0)
				return//no throw speed, the user was moving too fast.

	. = TRUE // No failure conditions past this point.

	var/target_zone
	if(QDELETED(thrower))
		thrower = null //Let's not pass a qdeleting reference if any.
	else
		target_zone = thrower.zone_selected

	var/datum/thrownthing/thrown_thing = new(src, target, get_dir(src, target), range, speed, thrower, diagonals_first, force, gentle, callback, target_zone, spin)

	var/dist_x = abs(target.x - src.x)
	var/dist_y = abs(target.y - src.y)
	var/dx = (target.x > src.x) ? EAST : WEST
	var/dy = (target.y > src.y) ? NORTH : SOUTH

	if (dist_x == dist_y)
		thrown_thing.pure_diagonal = 1

	else if(dist_x <= dist_y)
		var/olddist_x = dist_x
		var/olddx = dx
		dist_x = dist_y
		dist_y = olddist_x
		dx = dy
		dy = olddx
	thrown_thing.dist_x = dist_x
	thrown_thing.dist_y = dist_y
	thrown_thing.dx = dx
	thrown_thing.dy = dy
	thrown_thing.diagonal_error = dist_x/2 - dist_y
	thrown_thing.start_time = world.time

	if(LAZYLEN(grabbed_by))
		free_from_all_grabs()

	if (quickstart && (throwing || SSthrowing.state == SS_RUNNING)) //Avoid stack overflow edgecases.
		quickstart = FALSE
	throwing = thrown_thing
	if(spin)
		SpinAnimation(2)

	SEND_SIGNAL(src, COMSIG_MOVABLE_POST_THROW, thrown_thing, spin)
	SSthrowing.processing[src] = thrown_thing
	if (SSthrowing.state == SS_PAUSED && length(SSthrowing.currentrun))
		SSthrowing.currentrun[src] = thrown_thing
	if (quickstart)
		thrown_thing.tick()

/atom/movable/proc/handle_buckled_mob_movement(newloc, direct, glide_size_override)
	for(var/mob/living/buckled_mob as anything in buckled_mobs)
		if(!buckled_mob.Move(newloc, direct, glide_size_override)) //If a mob buckled to us can't make the same move as us
			Move(buckled_mob.loc, direct) //Move back to its location
			last_move = buckled_mob.last_move
			return FALSE
	return TRUE

/atom/movable/proc/force_pushed(atom/movable/pusher, force = MOVE_FORCE_DEFAULT, direction)
	return FALSE

/atom/movable/proc/force_push(atom/movable/pushed_atom, force = move_force, direction, silent = FALSE)
	. = pushed_atom.force_pushed(src, force, direction)
	if(!silent && .)
		visible_message(span_warning("[src] forcefully pushes against [pushed_atom]!"), span_warning("You forcefully push against [pushed_atom]!"))

/atom/movable/proc/move_crush(atom/movable/crushed_atom, force = move_force, direction, silent = FALSE)
	. = crushed_atom.move_crushed(src, force, direction)
	if(!silent && .)
		visible_message(span_danger("[src] crushes past [crushed_atom]!"), span_danger("You crush [crushed_atom]!"))

/atom/movable/proc/move_crushed(atom/movable/pusher, force = MOVE_FORCE_DEFAULT, direction)
	return FALSE

/atom/movable/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(mover in buckled_mobs)
		return TRUE

/// Returns true or false to allow src to move through the blocker, mover has final say
/atom/movable/proc/CanPassThrough(atom/blocker, movement_dir, blocker_opinion)
	SHOULD_CALL_PARENT(TRUE)
	SHOULD_BE_PURE(TRUE)
	return blocker_opinion

/// called when this atom is removed from a storage item, which is passed on as S. The loc variable is already set to the new destination before this is called.
/atom/movable/proc/on_exit_storage(datum/storage/master_storage)
	SHOULD_CALL_PARENT(TRUE)
	SEND_SIGNAL(src, COMSIG_ITEM_UNSTORED, master_storage)

/// called when this atom is added into a storage item, which is passed on as S. The loc variable is already set to the storage item.
/atom/movable/proc/on_enter_storage(datum/storage/master_storage)
	SHOULD_CALL_PARENT(TRUE)
	SEND_SIGNAL(src, COMSIG_ITEM_STORED, master_storage)

/atom/movable/proc/get_spacemove_backup()
	for(var/checked_range in orange(1, get_turf(src)))
		if(isarea(checked_range))
			continue
		if(isturf(checked_range))
			var/turf/turf = checked_range
			if(!turf.density)
				continue
			return turf
		var/atom/movable/checked_atom = checked_range
		if(checked_atom.density || !checked_atom.CanPass(src, get_dir(src, checked_atom)))
			if(checked_atom.last_pushoff == world.time)
				continue
			return checked_atom

///called when a mob resists while inside a container that is itself inside something.
/atom/movable/proc/relay_container_resist_act(mob/living/user, obj/container)
	return


/atom/movable/proc/do_attack_animation(atom/attacked_atom, visual_effect_icon, obj/item/used_item, no_effect, fov_effect = TRUE)
	if(!no_effect && (visual_effect_icon || used_item))
		do_item_attack_animation(attacked_atom, visual_effect_icon, used_item)

	if(attacked_atom == src)
		do_hurt_animation()
		return //don't do an animation if attacking self

	var/pixel_x_diff = 0
	var/pixel_y_diff = 0
	var/turn_dir = 1

	var/direction = get_dir(src, attacked_atom)
	if(direction & NORTH)
		pixel_y_diff = 8
		turn_dir = prob(50) ? -1 : 1
	else if(direction & SOUTH)
		pixel_y_diff = -8
		turn_dir = prob(50) ? -1 : 1

	if(direction & EAST)
		pixel_x_diff = 8
	else if(direction & WEST)
		pixel_x_diff = -8
		turn_dir = -1

	if(fov_effect)
		play_fov_effect(attacked_atom, 5, "attack")

	var/matrix/initial_transform = matrix(transform)
	var/matrix/rotated_transform = transform.Turn(15 * turn_dir)
	for(var/atom/movable/AM as anything in get_associated_mimics() + src)
		animate(AM, pixel_x = pixel_x + pixel_x_diff, pixel_y = pixel_y + pixel_y_diff, transform=rotated_transform, time = 1, easing=BACK_EASING|EASE_IN, flags = ANIMATION_PARALLEL)
		animate(pixel_x = pixel_x - pixel_x_diff, pixel_y = pixel_y - pixel_y_diff, transform=initial_transform, time = 2, easing=SINE_EASING, flags = ANIMATION_PARALLEL)

	attacked_atom.do_hurt_animation()

/// Plays an animation for getting hit.
/atom/proc/do_hurt_animation()
	return

/atom/movable/vv_get_dropdown()
	. = ..()
	. += "<option value='?_src_=holder;[HrefToken()];adminplayerobservefollow=[REF(src)]'>Follow</option>"
	. += "<option value='?_src_=holder;[HrefToken()];admingetmovable=[REF(src)]'>Get</option>"


/* Language procs
* Unless you are doing something very specific, these are the ones you want to use.
*/

/// Gets or creates the relevant language holder. For mindless atoms, gets the local one. For atom with mind, gets the mind one.
/atom/movable/proc/get_language_holder(get_minds = TRUE)
	RETURN_TYPE(/datum/language_holder)
	if(!language_holder)
		language_holder = new initial_language_holder(src)
	return language_holder

/// Grants the supplied language and sets omnitongue true.
/atom/movable/proc/grant_language(language, understood = TRUE, spoken = TRUE, source = LANGUAGE_ATOM)
	return get_language_holder().grant_language(language, understood, spoken, source)

/// Grants every language.
/atom/movable/proc/grant_all_languages(understood = TRUE, spoken = TRUE, grant_omnitongue = TRUE, source = LANGUAGE_MIND)
	return get_language_holder().grant_all_languages(understood, spoken, grant_omnitongue, source)

/// Removes a single language.
/atom/movable/proc/remove_language(language, understood = TRUE, spoken = TRUE, source = LANGUAGE_ALL)
	return get_language_holder().remove_language(language, understood, spoken, source)

/// Removes every language and sets omnitongue false.
/atom/movable/proc/remove_all_languages(source = LANGUAGE_ALL, remove_omnitongue = FALSE)
	return get_language_holder().remove_all_languages(source, remove_omnitongue)

/// Adds a language to the blocked language list. Use this over remove_language in cases where you will give languages back later.
/atom/movable/proc/add_blocked_language(language, source = LANGUAGE_ATOM)
	return get_language_holder().add_blocked_language(language, source)

/// Removes a language from the blocked language list.
/atom/movable/proc/remove_blocked_language(language, source = LANGUAGE_ATOM)
	return get_language_holder().remove_blocked_language(language, source)

/// Checks if atom has the language. If spoken is true, only checks if atom can speak the language.
/atom/movable/proc/has_language(language, spoken = FALSE)
	return get_language_holder().has_language(language, spoken)

/// Checks if atom can speak the language.
/atom/movable/proc/can_speak_language(language)
	return get_language_holder().can_speak_language(language)

/// Returns selected language, if it can be spoken, or finds, sets and returns a new selected language if possible.
/atom/movable/proc/get_selected_language()
	return get_language_holder().get_selected_language()

/// Gets a random understood language, useful for hallucinations and such.
/atom/movable/proc/get_random_understood_language()
	return get_language_holder().get_random_understood_language()

/// Gets a random spoken language, useful for forced speech and such.
/atom/movable/proc/get_random_spoken_language()
	return get_language_holder().get_random_spoken_language()

/// Copies all languages into the supplied atom/language holder. Source should be overridden when you
/// do not want the language overwritten by later atom updates or want to avoid blocked languages.
/atom/movable/proc/copy_languages(from_holder, source_override)
	if(isatom(from_holder))
		var/atom/movable/thing = from_holder
		from_holder = thing.get_language_holder()

	return get_language_holder().copy_languages(from_holder, source_override)

/// Empties out the atom specific languages and updates them according to the current atoms language holder.
/// As a side effect, it also creates missing language holders in the process.
/atom/movable/proc/update_atom_languages()
	return get_language_holder().update_atom_languages(src)

/* End language procs */

//Returns an atom's power cell, if it has one. Overload for individual items.
/atom/movable/proc/get_cell()
	return

/**
 * Adds the deadchat_plays component to this atom with simple movement commands.
 *
 * Returns the component added.
 * Arguments:
 * * mode - Either ANARCHY_MODE or DEMOCRACY_MODE passed to the deadchat_control component. See [/datum/component/deadchat_control] for more info.
 * * cooldown - The cooldown between command inputs passed to the deadchat_control component. See [/datum/component/deadchat_control] for more info.
 */
/atom/movable/proc/deadchat_plays(mode = ANARCHY_MODE, cooldown = 12 SECONDS)
	return AddComponent(/datum/component/deadchat_control/cardinal_movement, mode, list(), cooldown)

/atom/movable/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION(VV_HK_EDIT_PARTICLES, "Edit Particles")
	VV_DROPDOWN_OPTION(VV_HK_DEADCHAT_PLAYS, "Start/Stop Deadchat Plays")
	VV_DROPDOWN_OPTION(VV_HK_ADD_FANTASY_AFFIX, "Add Fantasy Affix")

/atom/movable/vv_do_topic(list/href_list)
	. = ..()

	if(!.)
		return

	if(href_list[VV_HK_EDIT_PARTICLES] && check_rights(R_VAREDIT))
		var/client/C = usr.client
		C?.open_particle_editor(src)

	if(href_list[VV_HK_DEADCHAT_PLAYS] && check_rights(R_FUN))
		if(tgui_alert(usr, "Allow deadchat to control [src] via chat commands?", "Deadchat Plays [src]", list("Allow", "Cancel")) != "Allow")
			return

		// Alert is async, so quick sanity check to make sure we should still be doing this.
		if(QDELETED(src))
			return

		// This should never happen, but if it does it should not be silent.
		if(deadchat_plays() == COMPONENT_INCOMPATIBLE)
			to_chat(usr, span_warning("Deadchat control not compatible with [src]."))
			CRASH("deadchat_control component incompatible with object of type: [type]")

		to_chat(usr, span_notice("Deadchat now control [src]."))
		log_admin("[key_name(usr)] has added deadchat control to [src]")
		message_admins(span_notice("[key_name(usr)] has added deadchat control to [src]"))

/**
* A wrapper for setDir that should only be able to fail by living mobs.
*
* Called from [/atom/movable/proc/keyLoop], this exists to be overwritten by living mobs with a check to see if we're actually alive enough to change directions
*/
/atom/movable/proc/keybind_face_direction(direction)
	setDir(direction)

/**
 * Show a message to this mob (visual or audible)
 * This is /atom/movable so mimics can get these and relay them to their parent.
 */
/atom/movable/proc/show_message(msg, type, alt_msg, alt_type, avoid_highlighting = FALSE)
	return

/// Tests if src can move from their current loc to an adjacent destination, without doing the move.
/atom/movable/proc/can_step_into(turf/destination)
	var/current_loc = get_turf(src)
	var/direction = get_dir(current_loc, destination)
	if(loc)
		if(!loc.Exit(src, direction, TRUE))
			return FALSE

	return destination.Enter(src, TRUE)

/atom/movable/wash(clean_types)
	. = ..()
	germ_level = 0

/atom/movable/proc/add_passmob(source)
	if(!source)
		return
	ADD_TRAIT(src, TRAIT_PASSMOB, source)
	pass_flags |= PASSMOB

/atom/movable/proc/remove_passmob(source)
	REMOVE_TRAIT(src, TRAIT_PASSMOB, source)
	if(!HAS_TRAIT(src, TRAIT_PASSMOB))
		pass_flags &= ~PASSMOB
