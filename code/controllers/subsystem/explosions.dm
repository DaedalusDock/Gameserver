#define EXPLOSION_THROW_SPEED 4
GLOBAL_LIST_EMPTY(explosions)

SUBSYSTEM_DEF(explosions)
	name = "Explosions"
	init_order = INIT_ORDER_EXPLOSIONS
	wait = 1
	flags = SS_NO_FIRE

	//A list of explosion sources
	var/list/active_explosions = list()

	// Track how many explosions have happened.
	var/explosion_index = 0

	var/currentpart = SSEXPLOSIONS_MOVABLES

	var/iterative_explosions_z_threshold = INFINITY
	var/iterative_explosions_z_multiplier = INFINITY

/datum/controller/subsystem/explosions/Initialize(start_timeofday)
	. = ..()
	// iterative_explosions_z_threshold = CONFIG_GET(number/iterative_explosions_z_threshold)
	// iterative_explosions_z_multiplier = CONFIG_GET(number/iterative_explosions_z_multiplier)

#define SSEX_TURF "turf"
#define SSEX_OBJ "obj"

/datum/controller/subsystem/explosions/proc/begin_exploding(atom/source)
	explosion_index++
	active_explosions += source

/datum/controller/subsystem/explosions/proc/stop_exploding(atom/source)
	active_explosions -= source

/datum/controller/subsystem/explosions/proc/is_exploding()
	return length(active_explosions)

/**
 * Makes a given atom explode.
 *
 * Arguments:
 * - [origin][/atom]: The atom that's exploding.
 * - devastation_range: The range at which the effects of the explosion are at their strongest.
 * - heavy_impact_range: The range at which the effects of the explosion are relatively severe.
 * - light_impact_range: The range at which the effects of the explosion are relatively weak.
 * - flash_range: The range at which the explosion flashes people.
 * - adminlog: Whether to log the explosion/report it to the administration.
 * - ignorecap: Whether to ignore the relevant bombcap. Defaults to FALSE.
 * - flame_range: The range at which the explosion should produce hotspots.
 * - silent: Whether to generate/execute sound effects.
 * - smoke: Whether to generate a smoke cloud provided the explosion is powerful enough to warrant it.
 * - explosion_cause: [Optional] The atom that caused the explosion, when different to the origin. Used for logging.
 */
/proc/explosion(atom/origin, devastation_range = 0, heavy_impact_range = 0, light_impact_range = 0, flame_range = 0, flash_range = 0, adminlog = TRUE, ignorecap = FALSE, silent = FALSE, smoke = FALSE, atom/explosion_cause = null)
	return SSexplosions.iterative_explode(arglist(args))

/**
 * Using default dyn_ex scale:
 *
 * 100 explosion power is a (5, 10, 20) explosion.
 * 75 explosion power is a (4, 8, 17) explosion.
 * 50 explosion power is a (3, 7, 14) explosion.
 * 25 explosion power is a (2, 5, 10) explosion.
 * 10 explosion power is a (1, 3, 6) explosion.
 * 5 explosion power is a (0, 1, 3) explosion.
 * 1 explosion power is a (0, 0, 1) explosion.
 *
 * Arguments:
 * * epicenter: Turf the explosion is centered at.
 * * power - Dyn explosion power. See reference above.
 * * flame_range: Flame range. Equal to the equivalent of the light impact range multiplied by this value.
 * * flash_range: The range at which the explosion flashes people. Equal to the equivalent of the light impact range multiplied by this value.
 * * adminlog: Whether to log the explosion/report it to the administration.
 * * ignorecap: Whether to ignore the relevant bombcap. Defaults to FALSE.
 * * flame_range: The range at which the explosion should produce hotspots.
 * * silent: Whether to generate/execute sound effects.
 * * smoke: Whether to generate a smoke cloud provided the explosion is powerful enough to warrant it.
 * * explosion_cause: [Optional] The atom that caused the explosion, when different to the origin. Used for logging.
 */
/proc/dyn_explosion(turf/epicenter, power, flame_range = 0, flash_range = null, adminlog = TRUE, ignorecap = TRUE, silent = FALSE, smoke = TRUE, atom/explosion_cause = null)
	if(!power)
		return

	var/range = 0
	range = round((2 * power)**GLOB.DYN_EX_SCALE)
	return explosion(epicenter, devastation_range = round(range * 0.25), heavy_impact_range = round(range * 0.5), light_impact_range = round(range), flame_range = flame_range*range, flash_range = flash_range*range, adminlog = adminlog, ignorecap = ignorecap, silent = silent, smoke = smoke, explosion_cause = explosion_cause)

// Explosion SFX defines...
/// The probability that a quaking explosion will make the station creak per unit. Maths!
#define QUAKE_CREAK_PROB 30
/// The probability that an echoing explosion will make the station creak per unit.
#define ECHO_CREAK_PROB 5
/// Time taken for the hull to begin to creak after an explosion, if applicable.
#define CREAK_DELAY (5 SECONDS)
/// Lower limit for far explosion SFX volume.
#define FAR_LOWER 40
/// Upper limit for far explosion SFX volume.
#define FAR_UPPER 60
/// The probability that a distant explosion SFX will be a far explosion sound rather than an echo. (0-100)
#define FAR_SOUND_PROB 75
/// The upper limit on screenshake amplitude for nearby explosions.
#define NEAR_SHAKE_CAP 5
/// The upper limit on screenshake amplifude for distant explosions.
#define FAR_SHAKE_CAP 1.5
/// The duration of the screenshake for nearby explosions.
#define NEAR_SHAKE_DURATION (1.5 SECONDS)
/// The duration of the screenshake for distant explosions.
#define FAR_SHAKE_DURATION (1 SECONDS)
/// The lower limit for the randomly selected hull creaking frequency.
#define FREQ_LOWER 25
/// The upper limit for the randomly selected hull creaking frequency.
#define FREQ_UPPER 40

/**
 * Handles the sfx and screenshake caused by an explosion.
 *
 * Arguments:
 * - [epicenter][/turf]: The location of the explosion.
 * - near_distance: How close to the explosion you need to be to get the full effect of the explosion.
 * - far_distance: How close to the explosion you need to be to hear more than echos.
 * - quake_factor: Main scaling factor for screenshake.
 * - echo_factor: Whether to make the explosion echo off of very distant parts of the station.
 * - creaking: Whether to make the station creak. Autoset if null.
 * - [near_sound][/sound]: The sound that plays if you are close to the explosion.
 * - [far_sound][/sound]: The sound that plays if you are far from the explosion.
 * - [echo_sound][/sound]: The sound that plays as echos for the explosion.
 * - [creaking_sound][/sound]: The sound that plays when the station creaks during the explosion.
 * - [hull_creaking_sound][/sound]: The sound that plays when the station creaks after the explosion.
 */
/datum/controller/subsystem/explosions/proc/shake_the_room(turf/epicenter, near_distance, far_distance, quake_factor, echo_factor, creaking, sound/near_sound = sound(get_sfx(SFX_EXPLOSION)), sound/far_sound = sound('sound/effects/explosionfar.ogg'), sound/echo_sound = sound('sound/effects/explosion_distant.ogg'), sound/creaking_sound = sound(get_sfx(SFX_EXPLOSION_CREAKING)), hull_creaking_sound = sound(get_sfx(SFX_HULL_CREAKING)))
	var/frequency = get_rand_frequency()
	var/blast_z = epicenter.z
	if(isnull(creaking)) // Autoset creaking.
		var/on_station = SSmapping.level_trait(epicenter.z, ZTRAIT_STATION)
		if(on_station && prob((quake_factor * QUAKE_CREAK_PROB) + (echo_factor * ECHO_CREAK_PROB))) // Huge explosions are near guaranteed to make the station creak and whine, smaller ones might.
			creaking = TRUE // prob over 100 always returns true
		else
			creaking = FALSE

	for(var/mob/listener as anything in GLOB.player_list)
		var/turf/listener_turf = get_turf(listener)
		if(!listener_turf || listener_turf.z != blast_z)
			continue

		var/distance = get_dist(epicenter, listener_turf)
		if(epicenter == listener_turf)
			distance = 0

		var/base_shake_amount = isobserver(listener) ? 0 : sqrt(near_distance / (distance + 1))

		if(distance <= round(near_distance + world.view - 2, 1)) // If you are close enough to see the effects of the explosion first-hand (ignoring walls)
			listener.playsound_local(epicenter, null, 100, TRUE, frequency, sound_to_use = near_sound)
			if(base_shake_amount > 0)
				shake_camera(listener, NEAR_SHAKE_DURATION, clamp(base_shake_amount, 0, NEAR_SHAKE_CAP))

		else if(distance < far_distance) // You can hear a far explosion if you are outside the blast radius. Small explosions shouldn't be heard throughout the station.
			var/far_volume = clamp(far_distance / 2, FAR_LOWER, FAR_UPPER)
			if(creaking)
				listener.playsound_local(epicenter, null, far_volume, TRUE, frequency, sound_to_use = creaking_sound, distance_multiplier = 0)
			else if(prob(FAR_SOUND_PROB)) // Sound variety during meteor storm/tesloose/other bad event
				listener.playsound_local(epicenter, null, far_volume, TRUE, frequency, sound_to_use = far_sound, distance_multiplier = 0)
			else
				listener.playsound_local(epicenter, null, far_volume, TRUE, frequency, sound_to_use = echo_sound, distance_multiplier = 0)

			if(base_shake_amount || quake_factor)
				base_shake_amount = max(base_shake_amount, quake_factor * 3, 0) // Devastating explosions rock the station and ground
				shake_camera(listener, FAR_SHAKE_DURATION, min(base_shake_amount, FAR_SHAKE_CAP))

		else if(!isspaceturf(listener_turf) && echo_factor) // Big enough explosions echo through the hull.
			var/echo_volume
			if(quake_factor)
				echo_volume = 60
				shake_camera(listener, FAR_SHAKE_DURATION, clamp(quake_factor / 4, 0, FAR_SHAKE_CAP))
			else
				echo_volume = 40
			listener.playsound_local(epicenter, null, echo_volume, TRUE, frequency, sound_to_use = echo_sound, distance_multiplier = 0)

		if(creaking) // 5 seconds after the bang, the station begins to creak
			addtimer(CALLBACK(listener, TYPE_PROC_REF(/mob, playsound_local), epicenter, null, rand(FREQ_LOWER, FREQ_UPPER), TRUE, frequency, null, null, FALSE, hull_creaking_sound, 0), CREAK_DELAY)

#undef CREAK_DELAY
#undef QUAKE_CREAK_PROB
#undef ECHO_CREAK_PROB
#undef FAR_UPPER
#undef FAR_LOWER
#undef FAR_SOUND_PROB
#undef NEAR_SHAKE_CAP
#undef FAR_SHAKE_CAP
#undef NEAR_SHAKE_DURATION
#undef FAR_SHAKE_DURATION
#undef FREQ_UPPER
#undef FREQ_LOWER


#define EXPLFX_BOTH 3
#define EXPLFX_SOUND 2
#define EXPLFX_SHAKE 1
#define EXPLFX_NONE 0

// All the vars used on the turf should be on unsimulated turfs too, we just don't care about those generally.
#define SEARCH_DIR(dir) \
	search_direction = dir;\
	search_turf = get_step(current_turf, search_direction);\
	if (isturf(search_turf)) {\
		turf_queue += search_turf;\
		dir_queue += search_direction;\
		power_queue += current_power;\
	}

#define GET_EXPLOSION_BLOCK(thing) (thing.explosion_block == EXPLOSION_BLOCK_PROC ? thing.GetExplosionBlock() : thing.explosion_block)

/datum/controller/subsystem/explosions/proc/iterative_explode(atom/epicenter, devastation_range, heavy_impact_range, light_impact_range, flame_range, flash_range, admin_log, ignorecap, silent, smoke, atom/explosion_cause)
	set waitfor = FALSE

	explosion_cause ||= epicenter

	var/list/arguments = list(
		EXARG_KEY_ORIGIN = epicenter,
		EXARG_KEY_DEV_RANGE = devastation_range,
		EXARG_KEY_HEAVY_RANGE = heavy_impact_range,
		EXARG_KEY_LIGHT_RANGE = light_impact_range,
		EXARG_KEY_FLAME_RANGE = flame_range,
		EXARG_KEY_FLASH_RANGE = flash_range,
		EXARG_KEY_ADMIN_LOG = admin_log,
		EXARG_KEY_IGNORE_CAP = ignorecap,
		EXARG_KEY_SILENT = silent,
		EXARG_KEY_SMOKE = smoke,
		EXARG_KEY_EXPLOSION_CAUSE = explosion_cause ,
	)

	if(try_cancel_explosion(epicenter, arguments) & COMSIG_CANCEL_EXPLOSION)
		return COMSIG_CANCEL_EXPLOSION


	epicenter = get_turf(epicenter)
	if(!epicenter)
		return

	begin_exploding(explosion_cause)
	var/explosion_num = explosion_index

	// Archive the uncapped explosion for the doppler array
	var/orig_dev_range = devastation_range
	var/orig_heavy_range = heavy_impact_range
	var/orig_light_range = light_impact_range
	var/orig_max_distance = max(devastation_range, heavy_impact_range, light_impact_range, flame_range, flash_range) + 1

	// Bomb cap
	if(!ignorecap)
		//Zlevel specific bomb cap multiplier
		var/cap_multiplier = SSmapping.level_trait(epicenter.z, ZTRAIT_BOMBCAP_MULTIPLIER)
		if (isnull(cap_multiplier))
			cap_multiplier = 1

		devastation_range = min(zas_settings.maxex_devastation_range * cap_multiplier, devastation_range)
		heavy_impact_range = min(zas_settings.maxex_heavy_range * cap_multiplier, heavy_impact_range)
		light_impact_range = min(zas_settings.maxex_light_range * cap_multiplier, light_impact_range)
		flash_range = min(zas_settings.maxex_flash_range * cap_multiplier, flash_range)
		flame_range = min(zas_settings.maxex_fire_range * cap_multiplier, flame_range)

	var/power = max(devastation_range, heavy_impact_range, light_impact_range, flame_range) + 1
	if(power <= 0)
		return

	var/dev_power = power - devastation_range
	var/heavy_power = power - heavy_impact_range
	var/flame_power = power - flame_range

	if(admin_log)
		find_and_log_explosion_source(
			epicenter,
			explosion_cause,
			devastation_range,
			heavy_impact_range,
			light_impact_range,
			flame_range,
			flash_range,
			orig_dev_range,
			orig_heavy_range,
			orig_light_range
		)

	if(devastation_range)
		SSblackbox.record_feedback("amount", "devastating_booms", 1)

	//Zlevel specific bomb cap multiplier
	var/cap_multiplier = SSmapping.level_trait(epicenter.z, ZTRAIT_BOMBCAP_MULTIPLIER)
	if (isnull(cap_multiplier))
		cap_multiplier = 1

	if(!ignorecap)
		devastation_range = min(zas_settings.maxex_devastation_range * cap_multiplier, devastation_range)
		heavy_impact_range = min(zas_settings.maxex_heavy_range * cap_multiplier, heavy_impact_range)
		light_impact_range = min(zas_settings.maxex_light_range * cap_multiplier, light_impact_range)
		flash_range = min(zas_settings.maxex_flash_range * cap_multiplier, flash_range)
		flame_range = min(zas_settings.maxex_fire_range * cap_multiplier, flame_range)

	log_game("iexpl: (EX [explosion_num]) Beginning discovery phase.")
	var/time = REALTIMEOFDAY
	var/start_time = REALTIMEOFDAY

	var/list/act_turfs = list()
	act_turfs[epicenter] = power

	discover_turfs(epicenter, power, act_turfs)

	log_game("iexpl: (EX [explosion_num]) Discovery completed in [(REALTIMEOFDAY-time)/10] seconds.")
	log_game("iexpl: (EX [explosion_num]) Beginning SFX phase.")
	time = REALTIMEOFDAY

	perform_special_effects(epicenter, power, devastation_range, heavy_impact_range, light_impact_range, flame_range, flash_range, smoke, silent, orig_max_distance)

	log_game("iexpl: (EX [explosion_num]) SFX phase completed in [(REALTIMEOFDAY-time)/10] seconds.")
	log_game("iexpl: (EX [explosion_num]) Beginning application phase.")
	time = REALTIMEOFDAY

	var/turf_tally = 0
	var/movable_tally = 0
	perform_explosion(epicenter, act_turfs, heavy_power, dev_power, flame_power, &turf_tally, &movable_tally)

	var/took = (REALTIMEOFDAY - time) / 10
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_EXPLOSION, \
		epicenter, \
		devastation_range, \
		heavy_impact_range, \
		light_impact_range, \
		took, \
		orig_dev_range, \
		orig_heavy_range, \
		orig_light_range, \
		explosion_cause, \
		explosion_index \
	)
	log_game("iexpl: (EX [explosion_num]) Ex_act() phase completed in [took] seconds; processed [turf_tally] turfs and [movable_tally] movables.")
	log_game("iexpl: (EX [explosion_num]) Beginning throw phase.")
	time = REALTIMEOFDAY

	throw_movables(epicenter, act_turfs)

	log_game("iexpl: (EX [explosion_num]) Throwing phase completed in [(REALTIMEOFDAY - time) / 10] seconds.")
	log_game("iexpl: (EX [explosion_num]) All phases completed in [(REALTIMEOFDAY - start_time) / 10] seconds.")

	stop_exploding(explosion_cause)

/datum/controller/subsystem/explosions/proc/find_and_log_explosion_source(turf/epicenter, atom/explosion_cause, devastation_range, heavy_impact_range, light_impact_range, flame_range, flash_range, orig_dev_range, orig_heavy_range, orig_light_range)
	// Now begins a bit of a logic train to find out whodunnit.
	var/who_did_it = "N/A"
	var/who_did_it_game_log = "N/A"

	// Projectiles have special handling. They rely on a firer var and not fingerprints. Check special cases for firer being
	// mecha, mob or an object such as the gun itself. Handle each uniquely.
	if(isprojectile(explosion_cause))
		var/obj/projectile/fired_projectile = explosion_cause
		if(ismecha(fired_projectile.firer))
			var/obj/vehicle/sealed/mecha/firing_mecha = fired_projectile.firer
			var/list/mob/drivers = firing_mecha.return_occupants()
			if(length(drivers))
				who_did_it = "\[Mecha drivers:"
				who_did_it_game_log = "\[Mecha drivers:"
				for(var/mob/driver in drivers)
					who_did_it += " [ADMIN_LOOKUPFLW(driver)]"
					who_did_it_game_log = " [key_name(driver)]"
				who_did_it += "\]"
				who_did_it_game_log += "\]"
		else if(ismob(fired_projectile.firer))
			who_did_it = "\[Projectile firer: [ADMIN_LOOKUPFLW(fired_projectile.firer)]\]"
			who_did_it_game_log = "\[Projectile firer: [key_name(fired_projectile.firer)]\]"
		else
			who_did_it = "\[Projectile firer: [ADMIN_LOOKUPFLW(fired_projectile.firer.fingerprintslast)]\]"
			who_did_it_game_log = "\[Projectile firer: [key_name(fired_projectile.firer.fingerprintslast)]\]"
	// Otherwise if the explosion cause is an atom, try get the fingerprints.

	else if(istype(explosion_cause))
		who_did_it = ADMIN_LOOKUPFLW(explosion_cause.fingerprintslast)
		who_did_it_game_log = key_name(explosion_cause.fingerprintslast)

	message_admins("Explosion with size (Devast: [devastation_range], Heavy: [heavy_impact_range], Light: [light_impact_range], Flame: [flame_range]) in [ADMIN_VERBOSEJMP(epicenter)]. Possible cause: [explosion_cause || "NULL"]. Last fingerprints: [who_did_it].")
	log_game("Explosion with size ([devastation_range], [heavy_impact_range], [light_impact_range], [flame_range]) in [loc_name(epicenter)].  Possible cause: [explosion_cause]. Last fingerprints: [who_did_it_game_log || "NULL"].")
	var/area/areatype = get_area(epicenter)
	SSblackbox.record_feedback(
		"associative",
		"explosion",
		1,
		list(
			"dev" = devastation_range,
			"heavy" = heavy_impact_range,
			"light" = light_impact_range,
			"flame" = flame_range,
			"flash" = flash_range,
			"orig_dev" = orig_dev_range,
			"orig_heavy" = orig_heavy_range,
			"orig_light" = orig_light_range,
			"x" = epicenter.x,
			"y" = epicenter.y,
			"z" = epicenter.z,
			"area" = areatype.type,
			"time" = time_stamp("YYYY-MM-DD hh:mm:ss", 1),
			"possible_cause" = explosion_cause,
			"possible_suspect" = who_did_it_game_log
			)
		)

/datum/controller/subsystem/explosions/proc/try_cancel_explosion(atom/origin, list/arguments)
	var/atom/location = isturf(origin) ? origin : origin.loc
	if(SEND_SIGNAL(origin, COMSIG_ATOM_EXPLODE, arguments) & COMSIG_CANCEL_EXPLOSION)
		return COMSIG_CANCEL_EXPLOSION // Signals are incompatible with `arglist(...)` so we can't actually use that for these. Additionally,

	while(location)
		var/next_loc = location.loc
		if(SEND_SIGNAL(location, COMSIG_ATOM_INTERNAL_EXPLOSION, arguments) & COMSIG_CANCEL_EXPLOSION)
			return COMSIG_CANCEL_EXPLOSION
		if(isturf(location))
			break
		location = next_loc

	if(!location)
		return

	var/area/epicenter_area = get_area(location)
	if(SEND_SIGNAL(epicenter_area, COMSIG_AREA_INTERNAL_EXPLOSION, arguments) & COMSIG_CANCEL_EXPLOSION)
		return COMSIG_CANCEL_EXPLOSION

/datum/controller/subsystem/explosions/proc/discover_turfs(turf/epicenter, power, list/act_turfs)
	power -= GET_EXPLOSION_BLOCK(epicenter)

	if (power >= iterative_explosions_z_threshold)
		var/turf/above = GetAbove(epicenter)
		if(!isnull(above))
			iterative_explode(above, power * iterative_explosions_z_multiplier, UP)

		var/turf/below = GetBelow(epicenter)
		if(!isnull(below))
			iterative_explode(below, power * iterative_explosions_z_multiplier, DOWN)

	// These three lists must always be the same length.
	var/list/turf_queue = list(epicenter, epicenter, epicenter, epicenter)
	var/list/dir_queue = list(NORTH, SOUTH, EAST, WEST)
	var/list/power_queue = list(power, power, power, power)

	var/turf/current_turf
	var/turf/search_turf
	var/origin_direction
	var/search_direction
	var/current_power
	var/index = 1
	while (index <= turf_queue.len)
		current_turf = turf_queue[index]
		origin_direction = dir_queue[index]
		current_power = power_queue[index]
		++index

		if (!istype(current_turf) || current_power <= 0)
			CHECK_TICK
			continue

		if (act_turfs[current_turf] >= current_power && current_turf != epicenter)
			CHECK_TICK
			continue

		act_turfs[current_turf] = current_power
		current_power -= GET_EXPLOSION_BLOCK(current_turf)

		// Attempt to shortcut on empty tiles: if a turf only has a LO on it, we don't need to check object resistance. Some turfs might not have LOs, so we need to check it actually has one.
		if (length(current_turf.contents))
			for (var/obj/O as obj in current_turf)
				if (O.explosion_block)
					current_power -= GET_EXPLOSION_BLOCK(O)

		if (current_power <= 0)
			CHECK_TICK
			continue

		SEARCH_DIR(origin_direction)
		SEARCH_DIR(turn(origin_direction, 90))
		SEARCH_DIR(turn(origin_direction, -90))

		CHECK_TICK

/datum/controller/subsystem/explosions/proc/perform_special_effects(turf/epicenter, power, devastation_range, heavy_impact_range, light_impact_range, flame_range, flash_range, smoke, silent, original_max_distance)
	//flash mobs
	if(flash_range)
		for(var/mob/living/L in viewers(flash_range, epicenter))
			L.flash_act()

	//Explosion effects
	if(heavy_impact_range > 1)
		var/datum/effect_system/explosion/E
		if(smoke)
			E = new /datum/effect_system/explosion/smoke
			var/datum/effect_system/explosion/smoke/smoke_dispenser = E
			smoke_dispenser.smoke_range = heavy_impact_range
		else
			E = new /datum/effect_system/explosion

		E.set_up(epicenter)
		E.start()

	if(power >= 5)
		new /obj/effect/temp_visual/shockwave(epicenter, min(power, 20)) //Lets be reasonable here.

	if(!silent)
		var/far_dist = 0
		far_dist += heavy_impact_range * 15
		far_dist += devastation_range * 20
		shake_the_room(epicenter, original_max_distance, far_dist, devastation_range, heavy_impact_range)

	// Flicker lights
	var/effective_range = devastation_range * 5 + heavy_impact_range * 2 + light_impact_range
	for(var/obj/machinery/light/L as anything in INSTANCES_OF(/obj/machinery/light))
		if(!isturf(L.loc))
			continue

		var/dist = get_dist_euclidean(L.loc, epicenter)
		if(dist > effective_range)
			continue

		var/delay = clamp(ceil(dist) * (0.1 SECONDS), 0, 5 SECONDS)
		if(delay)
			addtimer(CALLBACK(L, TYPE_PROC_REF(/obj/machinery/light, flicker), pick(1, 3)), delay)
		else
			L.flicker(pick(1, 3))

/datum/controller/subsystem/explosions/proc/perform_explosion(epicenter, list/act_turfs, heavy_power, dev_power, flame_power, turf_tally_ptr, movable_tally_ptr)
	var/turf_tally = 0
	var/movable_tally = 0
	for (var/turf/T as anything in act_turfs)
		var/turf_power = act_turfs[T]
		if (turf_power <= 0)
			CHECK_TICK
			continue

		var/severity
		if(turf_power >= dev_power)
			severity = EXPLODE_DEVASTATE
		else if(turf_power >= heavy_power)
			severity = EXPLODE_HEAVY
		else
			severity = EXPLODE_LIGHT

		if(flame_power && turf_power > flame_power)
			T.create_fire(2, rand(2, 10))

		if (T.simulated)
			T.ex_act(severity)

		if (length(T.contents))
			for (var/atom/movable/AM as anything in T)
				if (AM.simulated)
					EX_ACT(AM, severity)
					movable_tally++
				CHECK_TICK

		var/throw_range = min(turf_power, 10)
		if(T.explosion_throw_details < throw_range)
			T.explosion_throw_details = throw_range

		turf_tally++
		CHECK_TICK

	*turf_tally_ptr = turf_tally
	*movable_tally_ptr = movable_tally

/datum/controller/subsystem/explosions/proc/throw_movables(turf/epicenter, list/act_turfs)
	for(var/turf/T as anything in act_turfs)
		var/throw_range = T.explosion_throw_details
		if(isnull(throw_range))
			CHECK_TICK
			continue

		T.explosion_throw_details = null
		if(throw_range < 1)
			CHECK_TICK
			continue

		for(var/atom/movable/AM as anything in T)
			if(QDELETED(AM) || AM.anchored || !AM.simulated)
				CHECK_TICK
				continue

			if(AM.move_resist != INFINITY)
				var/turf/throw_target = get_ranged_target_turf_direct(AM, epicenter, throw_range, 180)
				AM.throw_at(throw_target, throw_range, EXPLOSION_THROW_SPEED)
			CHECK_TICK

		CHECK_TICK

/datum/controller/subsystem/explosions/proc/throw_exploded_movable(datum/callback/CB)
	if(QDELETED(CB.object))
		return

	addtimer(CB, 0)

/client/proc/check_bomb_impacts()
	set name = "Check Bomb Impact"
	set category = "Debug"

	var/turf/epicenter = get_turf(mob)
	if(!epicenter)
		return

	var/dev = 0
	var/heavy = 0
	var/light = 0
	var/list/choices = list("Small Bomb","Medium Bomb","Big Bomb","Custom Bomb")
	var/choice = tgui_input_list(usr, "Pick the bomb size", "Bomb Size?", choices)
	switch(choice)
		if(null)
			return 0
		if("Small Bomb")
			dev = 1
			heavy = 2
			light = 3
		if("Medium Bomb")
			dev = 2
			heavy = 3
			light = 4
		if("Big Bomb")
			dev = 3
			heavy = 5
			light = 7
		if("Custom Bomb")
			dev = input("Devastation range (Tiles):") as num
			heavy = input("Heavy impact range (Tiles):") as num
			light = input("Light impact range (Tiles):") as num

	var/power = max(dev, heavy, light) + 1 //Add ensure that explosions always affect atleast one turf.
	var/dev_power = power - dev
	var/heavy_power = power - heavy

	var/list/wipe_colors = list()
	var/list/act_turfs = list()

	SSexplosions.discover_turfs(epicenter, power, act_turfs)

	for (var/turf/T as anything in act_turfs)
		var/turf_power = act_turfs[T]
		if (turf_power <= 0)
			continue

		wipe_colors += T

		if(turf_power >= dev_power)
			T.color = "red"
			T.maptext = MAPTEXT("Dev")
		else if(turf_power >= heavy_power)
			T.color = "yellow"
			T.maptext = MAPTEXT("Heavy")
		else
			T.color = "blue"
			T.maptext = MAPTEXT("Light")

	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wipe_color_and_text), wipe_colors), 10 SECONDS)

/proc/wipe_color_and_text(list/atom/wiping)
	for(var/i in wiping)
		var/atom/A = i
		A.color = null
		A.maptext = ""

#undef SEARCH_DIR
#undef EXPLFX_BOTH
#undef EXPLFX_SOUND
#undef EXPLFX_SHAKE
#undef EXPLFX_NONE
