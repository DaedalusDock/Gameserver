/proc/get_default_flock()
	var/static/datum/flock/flock
	if(isnull(flock))
		flock = new

	return flock

/datum/flock
	var/name = "BAD FLOCK"

	/// The master of the flock
	var/mob/camera/flock/overmind/overmind

	/// Cache of images used by notices.
	var/list/notice_images = list()
	/// A k:V list of atoms the Overmind has marked for conversion, where the value is TRUE
	var/list/marked_for_deconstruction = list()
	/// A k:V list of reserved_turf = TRUE.
	var/list/turf_reservations = list()
	/// A k:V list of flock mobs to their reserved turf.
	var/list/turf_reservations_by_flock = list()

	var/list/claimed_floors = list()
	var/list/claimed_walls = list()

	/// Every structure we've built.
	var/list/structures = list()

	/// The bits
	var/list/bits = list()
	/// The drones
	var/list/drones = list()
	/// The traces
	var/list/traces = list()

	/// A k:v list of mob : details, contains enemy mobs.
	var/list/enemies = list()
	/// A k:V list of mob : TRUE, where mob is mobs that ai will ignore.
	var/list/ignores = list()

	/// A k:V list of client : image, see ping().
	var/list/active_pings = list()

	var/list/datum/flock_unlockable/unlockables
	/// The total amount of computational power available, before whats being used.
	var/datum/point_holder/compute
	/// The computational power being used.
	var/used_compute = 0
	/// The maximum amount of traces allowed.
	var/max_traces = 0

	var/flock_started = FALSE
	// Did the flock lose?
	var/flock_game_over = FALSE

	/// Current UI tab, saves on data sending.
	var/ui_tab = FLOCK_UI_DRONES

	//* STAT TRACKING *//
	var/stat_drones_made = 0
	var/stat_bits_made = 0
	var/stat_deaths = 0
	var/stat_resources_gained = 0
	var/stat_traces_made = 0
	var/stat_tiles_made = 0
	var/stat_structures_made = 0
	var/stat_highest_compute = 0

/datum/flock/New()
	name = flock_realname(FLOCK_TYPE_OVERMIND)

	compute = new
	create_hud_images()

	unlockables = list()
	for(var/datum/flock_unlockable/unlockable as anything in typesof(/datum/flock_unlockable))
		if(isabstract(unlockable))
			continue
		unlockables += new unlockable

// Called by gamemode code
/datum/flock/process(delta_time)
	if(flock_game_over)
		return

	stat_highest_compute = max(stat_highest_compute, compute.has_points())

/// Called after everything is setup, and clients are in control of their mobs.
/datum/flock/proc/start()
	if(flock_started)
		return

	flock_started = TRUE
	refresh_unlockables()

/// Convert a turf and claim it for the flock.
/datum/flock/proc/convert_turf(turf/T)
	if(isnull(T))
		return

	free_turf(T)
	T = flock_convert_turf(T, src)

	if(isnull(T))
		return

	playsound(T, 'sound/items/deconstruct.ogg', 30, TRUE, extrarange = SHORT_RANGE_SOUND_EXTRARANGE)

	if(iswallturf(T))
		claimed_walls += T
	else
		claimed_floors += T

	T.AddComponent(/datum/component/flock_interest, src)
	SEND_SIGNAL(T, COMSIG_TURF_CLAIMED_BY_FLOCK, src)

/// Reserves a turf, making AI ignore it for the purposes of targetting.
/datum/flock/proc/reserve_turf(mob/living/simple_animal/flock/user, turf/target)
	if(turf_reservations_by_flock[user])
		return FALSE
	if(turf_reservations[target])
		return FALSE

	turf_reservations_by_flock[user] = target
	turf_reservations[target] = user
	add_notice(target, FLOCK_NOTICE_RESERVED)
	RegisterSignal(target, COMSIG_TURF_CHANGE, PROC_REF(reserved_turf_change))
	return TRUE

/// Free a turf from reservation, allowing AI to target it again. override_turf can be given to lookup the user if there isnt a user in this context.
/datum/flock/proc/free_turf(mob/living/simple_animal/flock/user, turf/override_turf)
	var/turf/to_free
	if(user)
		to_free = turf_reservations_by_flock[user]
	else
		user = turf_reservations[override_turf]
		if(isnull(user))
			return

		to_free = override_turf

	if(isnull(to_free))
		return

	remove_notice(to_free, FLOCK_NOTICE_RESERVED)
	remove_notice(to_free, FLOCK_NOTICE_PRIORITY)
	turf_reservations_by_flock -= user
	turf_reservations -= to_free
	marked_for_deconstruction -= to_free
	UnregisterSignal(to_free, COMSIG_TURF_CHANGE)

/// Returns TRUE if the given turf is not reserved.
/datum/flock/proc/is_turf_free(turf/T)
	return !turf_reservations[T]

/// Returns TRUE if the given mob is an enemy.
/datum/flock/proc/is_mob_enemy(mob/M)
	return enemies[M]

/// Returns TRUE if the given mob is ignored by the flock.
/datum/flock/proc/is_mob_ignored(mob/M)
	return ignores[M]

/datum/flock/proc/add_unit(mob/unit)
	if(isflocktrace(unit))
		traces += unit

		var/mob/camera/flock/trace/ghostbird = unit
		add_compute_influence(ghostbird.compute_provided)
		return

	if(isflockdrone(unit))
		drones += unit

	else if(isflockbit(unit))
		bits += unit

	unit.AddComponent(/datum/component/flock_interest, src)

	var/mob/living/simple_animal/flock/bird = unit
	add_compute_influence(bird.compute_provided)

/datum/flock/proc/free_unit(mob/unit)
	if(isflocktrace(unit))
		var/mob/camera/flock/trace/ghostbird = unit
		ghostbird.flock = null
		traces -= unit
		remove_compute_influence(ghostbird.compute_provided)
		return

	else if(isflockdrone(unit))
		var/mob/living/simple_animal/flock/drone/bird = unit
		bird.flock = null
		drones -= unit
		remove_compute_influence(bird.compute_provided)

	else if(isflockbit(unit))
		var/mob/living/simple_animal/flock/bit/bitty_bird = unit
		bitty_bird.flock = null
		bits -= unit
		remove_compute_influence(bitty_bird.compute_provided)

	remove_notice(unit, FLOCK_NOTICE_HEALTH)
	free_turf(unit)
	qdel(unit.GetComponent(/datum/component/flock_interest))

	consider_game_over()

/datum/flock/proc/add_structure(obj/structure/flock/struct)
	structures += struct
	struct.flock = src
	struct.AddComponent(/datum/component/flock_interest, src)
	add_compute_influence(struct.compute_provided)

/datum/flock/proc/free_structure(obj/structure/flock/struct)
	structures -= struct
	qdel(struct.GetComponent(/datum/component/flock_interest))
	struct.flock = null
	if(struct.active)
		remove_compute_influence(-struct.active_compute_cost)
	else
		remove_compute_influence(struct.compute_provided)

/datum/flock/proc/create_structure(turf/location, structure_type)
	new /obj/structure/flock/tealprint(location, structure_type)

/// Wrapper for handling compute alongside used_compute for new mobs
/datum/flock/proc/add_compute_influence(num)
	if(num < 0)
		used_compute += abs(num)
	else
		compute.adjust_points(num)

	refresh_unlockables()

/// Wrapper for handling compute alongside used_compute for mobs leaving the flock
/datum/flock/proc/remove_compute_influence(num)
	if(num < 0)
		used_compute -= abs(num)
	else
		compute.adjust_points(-num)

	refresh_unlockables()

/datum/flock/proc/refresh_unlockables()
	PRIVATE_PROC(TRUE)
	if(!flock_started)
		return

	var/new_total = compute.has_points()
	var/new_available = available_compute()

	for(var/datum/flock_unlockable/unlockable as anything in unlockables)
		unlockable.refresh_lock_status(src, new_total, new_available)

/// Returns the amount of available compute. Can return negative if over budget.
/datum/flock/proc/available_compute()
	return compute.has_points() - used_compute

/// Returns TRUE if the flock has the required compute
/datum/flock/proc/can_afford(amt)
	return amt <= max(available_compute(), 0)

/// Sets the flock's overmind
/datum/flock/proc/register_overmind(mob/camera/flock_overmind)
	overmind = flock_overmind

/// Updates a mob's enemy status. If they are already an enemy, their entry will be updated with new information.
/datum/flock/proc/update_enemy(atom/movable/enemy)
	if(is_mob_ignored(enemy))
		return FALSE

	for(var/mob/living/L in enemy.buckled_mobs)
		update_enemy(L)

	if(!isliving(enemy))
		return FALSE
	if(!enemies[enemy])
		RegisterSignal(enemy, COMSIG_PARENT_QDELETING, PROC_REF(on_enemy_gone))
		add_notice(enemy, FLOCK_NOTICE_ENEMY)
	enemies[enemy] = get_area_name(enemy)
	return TRUE

/datum/flock/proc/remove_enemy(atom/movable/enemy, skip_buckled)
	if(!skip_buckled)
		for(var/mob/living/L in enemy.buckled_mobs)
			remove_enemy(L)

	if(!isliving(enemy))
		return

	enemies -= enemy
	UnregisterSignal(enemy, COMSIG_PARENT_QDELETING)
	remove_notice(enemy, FLOCK_NOTICE_ENEMY)
	return

/datum/flock/proc/add_ignore(atom/movable/ignore)
	for(var/mob/living/L in ignore.buckled_mobs)
		add_ignore(L)

	if(!isliving(ignore))
		return

	if(!enemies[ignore])
		RegisterSignal(ignore, COMSIG_PARENT_QDELETING, PROC_REF(on_ignore_gone))
		add_notice(ignore, FLOCK_NOTICE_IGNORE)
	ignores[ignore] = TRUE

/datum/flock/proc/remove_ignore(atom/movable/ignore, skip_buckled)
	if(!skip_buckled)
		for(var/mob/living/L in ignore.buckled_mobs)
			add_ignore(L)

	if(!isliving(ignore))
		return

	ignores -= ignore
	remove_notice(ignore, FLOCK_NOTICE_IGNORE)
	UnregisterSignal(ignore, COMSIG_PARENT_QDELETING)

/datum/flock/proc/add_notice(atom/target, notice_type)
	var/image/I = image(notice_images[notice_type], loc = target)
	return target.add_alt_appearance(/datum/atom_hud/alternate_appearance/basic/flock, notice_type, I, NONE, src)

/datum/flock/proc/remove_notice(atom/target, notice_type)
	target.remove_alt_appearance(notice_type)

/datum/flock/proc/get_priority_turfs(mob/living/simple_animal/flock/bird)
	if(!length(marked_for_deconstruction))
		return null

	return marked_for_deconstruction - turf_reservations

/datum/flock/proc/ping(turf/T, mob/camera/flock/pinger)
	var/message = "System interrupt. Designating new target: [T] in [get_area(T)]."
	flock_talk(pinger, message, src, TRUE, list("italics"))
	for(var/mob/camera/flock/ghost_bird in (traces + overmind))
		if(isnull(ghost_bird.client))
			continue

		ghost_bird.playsound_local(null, 'goon/sounds/flockmind/ping.ogg', 50, TRUE)
		if(ghost_bird == pinger)
			continue

		var/image/pointer = pointer_image_to(ghost_bird, T)
		//T._AddComponent(list(/datum/component/flock_ping, 5 SECONDS))

		animate(pointer, time = 3 SECONDS, alpha = 0)
		add_ping_image(ghost_bird.client, pointer, 3 SECONDS)

/datum/flock/proc/reserved_turf_change(datum/source)
	SIGNAL_HANDLER
	free_turf(override_turf = source)

/datum/flock/proc/add_ping_image(client/C, image/ping, duration)
	if(isnull(C))
		return

	C.images += ping
	active_pings[C] += list(ping)
	RegisterSignal(C, COMSIG_PARENT_QDELETING, PROC_REF(on_client_gone), override = TRUE)
	addtimer(CALLBACK(src, PROC_REF(cleanup_ping_images), C, ping), 3 SECONDS)

/datum/flock/proc/cleanup_ping_images(client/C, list/images_to_clean)
	if(isnull(C))
		return

	var/list/images = images_to_clean || active_pings[C]
	C.images -= images
	active_pings[C] -= images
	if(!length(active_pings[C]))
		active_pings -= C
		UnregisterSignal(C, COMSIG_PARENT_QDELETING)

/datum/flock/proc/on_client_gone(client/source)
	SIGNAL_HANDLER
	cleanup_ping_images()

/datum/flock/proc/on_unit_death(datum/source)
	SIGNAL_HANDLER
	free_unit(source)

/datum/flock/proc/on_enemy_gone(datum/source)
	SIGNAL_HANDLER
	remove_enemy(source, TRUE)

/datum/flock/proc/on_ignore_gone(datum/source)
	SIGNAL_HANDLER
	remove_ignore(source, TRUE)

/datum/flock/proc/create_hud_images()
	notice_images[FLOCK_NOTICE_RESERVED] = new /image{
		icon = 'goon/icons/mob/featherzone.dmi';
		icon_state = "frontier";
		plane = ABOVE_LIGHTING_PLANE;
		appearance_flags = RESET_ALPHA | RESET_COLOR | PIXEL_SCALE | RESET_TRANSFORM;
		alpha = 80;
	}

	notice_images[FLOCK_NOTICE_PRIORITY] = new /image{
		icon = 'goon/icons/mob/featherzone.dmi';
		icon_state = "frontier";
		plane = ABOVE_LIGHTING_PLANE;
		appearance_flags = RESET_ALPHA | RESET_COLOR | PIXEL_SCALE | RESET_TRANSFORM;
		alpha = 180;
	}

	notice_images[FLOCK_NOTICE_ENEMY] = new /image{
		icon = 'goon/icons/mob/featherzone.dmi';
		icon_state = "hazard";
		pixel_y = 16;
		plane = ABOVE_LIGHTING_PLANE;
		appearance_flags = RESET_ALPHA | RESET_COLOR | PIXEL_SCALE | RESET_TRANSFORM;
	}

	notice_images[FLOCK_NOTICE_IGNORE] = new /image{
		icon = 'goon/icons/mob/featherzone.dmi';
		icon_state = "ignore";
		pixel_y = 16;
		plane = ABOVE_LIGHTING_PLANE;
		appearance_flags = RESET_ALPHA | RESET_COLOR | PIXEL_SCALE | RESET_TRANSFORM;
	}

	notice_images[FLOCK_NOTICE_FLOCKMIND_CONTROL] = new /image{
		icon = 'goon/icons/mob/featherzone.dmi';
		icon_state = "flockmind_face";
		pixel_y = 16;
		plane = ABOVE_LIGHTING_PLANE;
		appearance_flags = RESET_ALPHA | RESET_COLOR | PIXEL_SCALE | RESET_TRANSFORM;
	}

	notice_images[FLOCK_NOTICE_FLOCKTRACE_CONTROL] = new /image{
		icon = 'goon/icons/mob/featherzone.dmi';
		icon_state = "flocktrace_face";
		pixel_y = 16;
		plane = ABOVE_LIGHTING_PLANE;
		appearance_flags = RESET_ALPHA | RESET_COLOR | PIXEL_SCALE | RESET_TRANSFORM;
	}

	notice_images[FLOCK_NOTICE_HEALTH] = new /image{
		icon = 'goon/icons/mob/featherzone.dmi';
		icon_state = "hp-100";
		pixel_x = 10;
		pixel_y = 16;
		plane = ABOVE_LIGHTING_PLANE;
		appearance_flags = RESET_ALPHA | RESET_COLOR | PIXEL_SCALE | RESET_TRANSFORM;
	}

/// Ends the flock if it is unable to continue spreading.
/datum/flock/proc/consider_game_over()
	if(flock_game_over)
		return

	if(length(drones))
		return

	if(locate(/obj/structure/flock/egg, structures) || locate(/obj/structure/flock/rift, structures))
		return

	game_over()

/datum/flock/proc/game_over(completely_destroy = TRUE)
	// Cleanup any pings
	for(var/client/C in active_pings)
		cleanup_ping_images(C)

	// Cleanup turf claims
	for(var/turf/T as anything in turf_reservations)
		free_turf(override_turf = T)

	claimed_floors.Cut()
	claimed_walls.Cut()

	// Extra lives
	if(!completely_destroy)
		return

	flock_game_over = TRUE

	// Kill overmind
	overmind?.so_very_sad_death() // Overmind can be null here if it died outside of game_over().

	// Kill traces
	for(var/mob/camera/flock/trace/ghostbird as anything in traces)
		ghostbird.so_very_sad_death()

	// Free units
	for(var/mob/living/simple_animal/flock/bird as anything in (bits + drones))
		free_unit(bird)

	// Remove ignores
	for(var/mob/M as anything in ignores)
		remove_ignore(M, TRUE)

	// Remove enemies
	for(var/mob/M as anything in enemies)
		remove_enemy(M, TRUE)
