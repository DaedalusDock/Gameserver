/*

Overview:
	The air controller does everything. There are tons of procs in here.

Class Vars:
	zones - All zones currently holding one or more turfs.
	edges - All processing edges.

	tiles_to_update - Tiles scheduled to update next tick.
	zones_to_update - Zones which have had their air changed and need air archival.
	active_hotspots - All processing fire objects.

	active_zones - The number of zones which were archived last tick. Used in debug verbs.
	next_id - The next UID to be applied to a zone. Mostly useful for debugging purposes as zones do not need UIDs to function.

Class Procs:

	mark_for_update(turf/T)
		Adds the turf to the update list. When updated, update_air_properties() will be called.
		When stuff changes that might affect airflow, call this. It's basically the only thing you need.

	add_zone(zone/Z) and remove_zone(zone/Z)
		Adds zones to the zones list. Does not mark them for update.

	air_blocked(turf/A, turf/B)
		Returns a bitflag consisting of:
		AIR_BLOCKED - The connection between turfs is physically blocked. No air can pass.
		ZONE_BLOCKED - There is a door between the turfs, so zones cannot cross. Air may or may not be permeable.

	has_valid_zone(turf/T)
		Checks the presence and validity of T's zone.
		May be called on unsimulated turfs, returning 0.

	merge(zone/A, zone/B)
		Called when zones have a direct connection and equivalent pressure and temperature.
		Merges the zones to create a single zone.

	connect(turf/simulated/A, turf/B)
		Called by turf/update_air_properties(). The first argument must be simulated.
		Creates a connection between A and B.

	mark_zone_update(zone/Z)
		Adds zone to the update list. Unlike mark_for_update(), this one is called automatically whenever
		air is returned from a simulated turf.

	get_edge(zone/A, zone/B)
	get_edge(zone/A, turf/B)
		Gets a valid connection_edge between A and B, creating a new one if necessary.

	has_same_air(turf/A, turf/B)
		Used to determine if an unsimulated edge represents a specific turf.
		Simulated edges use connection_edge/contains_zone() for the same purpose.
		Returns 1 if A has identical gases and temperature to B.

	remove_edge(connection_edge/edge)
		Called when an edge is erased. Removes it from processing.

*/
GLOBAL_REAL(zas_settings, /datum/zas_controller) = new

SUBSYSTEM_DEF(zas)
	name = "Air Core"
	priority = FIRE_PRIORITY_AIR
	init_order = INIT_ORDER_AIR
	flags = SS_POST_FIRE_TIMING
	runlevels = RUNLEVEL_GAME | RUNLEVEL_POSTGAME
	wait = 0.5 SECONDS

	var/cached_cost = 0
	var/cost_tiles = 0
	var/cost_deferred_tiles = 0
	var/cost_check_edges = 0
	var/cost_edges = 0
	var/cost_fires = 0
	var/cost_hotspots = 0
	var/cost_zones = 0
	var/cost_exposure = 0

	//The variable setting controller
	var/datum/zas_controller/settings
	//A reference to the global var
	var/datum/xgm_gas_data/gas_data

	///A global cache of unsimulated gas mixture singletons, associative by type.
	var/list/unsimulated_gas_cache = list()

	//Geometry lists
	var/list/zones = list()
	var/list/edges = list()


	//Geometry updates lists
	var/list/tiles_to_update = list()
	var/list/zones_to_update = list()
	var/list/active_hotspots = list()
	var/list/active_edges = list()
	var/list/zones_with_sensitive_contents = list()

	var/tmp/list/deferred = list()
	var/tmp/list/processing_edges
	var/tmp/list/processing_fires
	var/tmp/list/processing_hotspots
	var/tmp/list/processing_zones
	var/tmp/list/processing_exposure

	#ifdef ZASDBG
	/// Profile data for zone.tick(), in milliseconds
	var/list/zonetime = list()
	#endif

	#ifdef PROFILE_ZAS_CANPASS
	var/list/canpass_step_usage = list()
	var/list/canpass_time_spent = list()
	var/list/canpass_time_average = list()
	#endif

	var/active_zones = 0
	var/next_id = 1

	///The last process, as a string, before the previous run ended.
	var/last_process

///Stops processing while all ZAS-controlled airs and fires are nulled and the subsystem is reinitialized.
/datum/controller/subsystem/zas/proc/Reboot()
	// Stop processing while we rebuild.
	can_fire = FALSE
	times_fired = 0 // This is done to prevent the geometry bug explained in connect()
	next_id = 0 //Reset atmos zone count.

	// Make sure we don't rebuild mid-tick.
	if (state != SS_IDLE)
		to_chat(world, span_boldannounce("ZAS Rebuild initiated. Waiting for current air tick to complete before continuing."))
		UNTIL(state == SS_IDLE)

	zas_settings = new //Reset the global zas settings

	while (zones.len)
		var/zone/zone = zones[zones.len]
		zones.len--

		zone.invalidate()

	edges.Cut()
	tiles_to_update.Cut()
	zones_to_update.Cut()
	active_hotspots.Cut()
	active_edges.Cut()

	// Re-run setup without air settling.
	Initialize(REALTIMEOFDAY, simulate = FALSE)

	// Update next_fire so the MC doesn't try to make up for missed ticks.
	next_fire = world.time + wait
	can_fire = TRUE

/datum/controller/subsystem/zas/stat_entry(msg)
	if(!can_fire)
		msg += "REBOOTING..."
	else
		msg += "TtU: [length(tiles_to_update)] "
		msg += "ZtU: [length(zones_to_update)] "
		msg += "AH: [length(active_hotspots)] "
		msg += "AE: [length(active_edges)]"
	return ..()

/datum/controller/subsystem/zas/Initialize(timeofday, simulate = TRUE)

	var/starttime = REALTIMEOFDAY
	settings = zas_settings
	gas_data = xgm_gas_data

	to_chat(world, span_debug("ZAS: Processing Geometry..."))

	var/simulated_turf_count = 0

	for(var/turf/S as turf in world)
		if(!S.simulated)
			continue

		simulated_turf_count++
		S.update_air_properties()

		CHECK_TICK

	to_chat(world, span_debug("ZAS:\n - Total Simulated Turfs: [simulated_turf_count]\n - Total Zones: [zones.len]\n - Total Edges: [edges.len]\n - Total Active Edges: [active_edges.len ? "<span class='danger'>[active_edges.len]</span>" : "None"]\n - Total Unsimulated Turfs: [world.maxx*world.maxy*world.maxz - simulated_turf_count]"))

	to_chat(world, span_debug("ZAS: Geometry processing completed in [(REALTIMEOFDAY - starttime)/10] seconds!"))

	if (simulate)
		to_chat(world, span_debug("ZAS: Firing once..."))

		starttime = REALTIMEOFDAY
		fire(FALSE, TRUE)

		to_chat(world, span_debug("ZAS: Air settling completed in [(REALTIMEOFDAY - starttime)/10] seconds!"))

	..(timeofday)

/datum/controller/subsystem/zas/fire(resumed = FALSE, no_mc_tick)
	var/timer = TICK_USAGE_REAL
	if (!resumed)
		processing_edges = active_edges.Copy()
		processing_hotspots = active_hotspots.Copy()
		processing_exposure = zones_with_sensitive_contents.Copy()

	var/list/curr_tiles = tiles_to_update
	var/list/curr_defer = deferred
	var/list/curr_edges = processing_edges
	var/list/curr_hotspot = processing_hotspots
	var/list/curr_zones = zones_to_update
	var/list/curr_zones_again = zones_to_update.Copy()
	var/list/curr_sensitive_zones = processing_exposure

	last_process = "TILES"

/////////TILES//////////
	cached_cost = 0
	while (curr_tiles.len)
		var/turf/T = curr_tiles[curr_tiles.len]
		curr_tiles.len--

		if (!T)
			if (no_mc_tick)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				return

			continue

		//check if the turf is self-zone-blocked
		var/c_airblock
		ATMOS_CANPASS_TURF(c_airblock, T, T)
		if(c_airblock & ZONE_BLOCKED)
			deferred += T
			if (no_mc_tick)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				return
			continue

		T.update_air_properties()
		T.post_update_air_properties()
		T.needs_air_update = 0
		#ifdef ZASDBG
		T.remove_viscontents(zasdbgovl_mark)
		//updated++
		#endif

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			return

	cached_cost += TICK_USAGE_REAL - timer
	cost_tiles = MC_AVERAGE(cost_tiles, TICK_DELTA_TO_MS(cached_cost))

//////////DEFERRED TILES//////////
	last_process = "DEFERRED TILES"
	timer = TICK_USAGE_REAL
	cached_cost = 0
	while (curr_defer.len)
		var/turf/T = curr_defer[curr_defer.len]
		curr_defer.len--

		T.update_air_properties()
		T.post_update_air_properties()
		T.needs_air_update = 0
		#ifdef ZASDBG
		T.remove_viscontents(zasdbgovl_mark)
		//updated++
		#endif

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			return
	cached_cost += TICK_USAGE_REAL - timer
	cost_deferred_tiles = MC_AVERAGE(cost_deferred_tiles, TICK_DELTA_TO_MS(cached_cost))

//////////CHECK_EDGES/////////
	last_process = "CHECK EDGES"
	timer = TICK_USAGE_REAL
	cached_cost = 0
	while (curr_zones_again.len)
		var/zone/Z = curr_zones_again[curr_zones_again.len]
		curr_zones_again.len--

		var/list/cache_for_speed = Z.edges
		for(var/edge_source in Z.edges)
			var/connection_edge/E = cache_for_speed[edge_source]
			if(!E.excited)
				E.recheck()

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			return

	cached_cost += TICK_USAGE_REAL - timer
	cost_check_edges = MC_AVERAGE(cost_check_edges, TICK_DELTA_TO_MS(cached_cost))

//////////EDGES//////////
	last_process = "EDGES"
	timer = TICK_USAGE_REAL
	cached_cost = 0
	while (curr_edges.len)
		var/connection_edge/edge = curr_edges[curr_edges.len]
		curr_edges.len--

		if (!edge)
			if (no_mc_tick)
				CHECK_TICK
			else if (MC_TICK_CHECK)
				return
			continue

		edge.tick()

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			return

	cached_cost += TICK_USAGE_REAL - timer
	cost_edges = MC_AVERAGE(cost_edges, TICK_DELTA_TO_MS(cached_cost))

//////////HOTSPOTS//////////
	last_process = "HOTSPOTS"
	timer = TICK_USAGE_REAL
	cached_cost = 0
	while (curr_hotspot.len)
		var/obj/effect/hotspot/F = curr_hotspot[curr_hotspot.len]
		curr_hotspot.len--

		F.process()

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			return

	cached_cost += TICK_USAGE_REAL - timer
	cost_hotspots = MC_AVERAGE(cost_hotspots, TICK_DELTA_TO_MS(cached_cost))

//////////ZONES//////////
	last_process = "ZONES"
	timer = TICK_USAGE_REAL
	cached_cost = 0
	while (curr_zones.len)
		var/zone/Z = curr_zones[curr_zones.len]
		curr_zones.len--

		Z.tick()
		Z.needs_update = FALSE

		if (no_mc_tick)
			CHECK_TICK
		else if (MC_TICK_CHECK)
			return

	cached_cost += TICK_USAGE_REAL - timer
	cost_zones = MC_AVERAGE(cost_zones, TICK_DELTA_TO_MS(cached_cost))

	if(no_mc_tick) //Initialization doesn't need to process exposure, waste of time
		return

/////////ATMOS EXPOSE//////

	last_process = "ATMOS EXPOSE"
	timer = TICK_USAGE_REAL
	cached_cost = 0
	while(curr_sensitive_zones.len)
		var/zone/Z = curr_sensitive_zones[curr_sensitive_zones.len]
		curr_sensitive_zones.len--

		for(var/atom/sensitive as area|turf|obj|mob in Z.atmos_sensitive_contents)
			sensitive.atmos_expose(Z.air, Z.air.temperature)

		if(MC_TICK_CHECK)
			return

	cached_cost += TICK_USAGE_REAL - timer
	cost_exposure = MC_AVERAGE(cost_exposure, TICK_DELTA_TO_MS(cached_cost))


///Adds a zone to the subsystem, gives it's identifer, and marks it for update.
/datum/controller/subsystem/zas/proc/add_zone(zone/z)
	zones += z
	z.name = "Zone [next_id++]"
	mark_zone_update(z)

///Removes a zone from the subsystem.
/datum/controller/subsystem/zas/proc/remove_zone(zone/z)
	zones -= z
	zones_to_update -= z
	zones_with_sensitive_contents -= z

///Checks to see if air can flow between A and B.
/datum/controller/subsystem/zas/proc/air_blocked(turf/A, turf/B)
	#ifdef ZASDBG
	ASSERT(isturf(A))
	ASSERT(isturf(B))
	#endif
	var/ablock
	ATMOS_CANPASS_TURF(ablock, A, B)
	if(ablock & AIR_BLOCKED)
		return AIR_BLOCKED|ZONE_BLOCKED
	ATMOS_CANPASS_TURF(., B, A)
	return ablock | .

///Merges two zones. Largest by turf count wins.
/datum/controller/subsystem/zas/proc/merge(zone/A, zone/B)
	#ifdef ZASDBG
	ASSERT(istype(A))
	ASSERT(istype(B))
	ASSERT(!A.invalid)
	ASSERT(!B.invalid)
	ASSERT(A != B)
	#endif
	if(A.contents.len < B.contents.len)
		A.merge_into(B)
		mark_zone_update(B)
	else
		B.merge_into(A)
		mark_zone_update(A)

///Forms a /connection/ between two turfs.
/datum/controller/subsystem/zas/proc/connect(turf/A, turf/B)
	#ifdef ZASDBG
	ASSERT(A.simulated)
	ASSERT(isturf(B))
	ASSERT(A.zone)
	ASSERT(!A.zone.invalid)
	//ASSERT(B.zone)
	ASSERT(A != B)
	#endif
	var/block = air_blocked(A,B)
	if(block & AIR_BLOCKED)
		return

	var/direct = !(block & ZONE_BLOCKED)
	//var/space = istype(B, /turf/open/space)
	var/space = !B.simulated

	if(!space)
		// Ok. This is super fucking cursed, but, it has to be this way.
		// Basically, it's possible that during the initial geometry build, a zone can be created in a spot
		// such that it merges over zone-blocker due to the minimum size requirement being met to merge over blockers.
		// To fix this, we disable that during the geometry build, which takes place during Initialize()
		if((times_fired && min(length(A.zone.contents), length(B.zone.contents)) < ZONE_MIN_SIZE) || (direct && A.zone.air.compare(B.zone.air)))
			merge(A.zone,B.zone)
			return TRUE
	else if(isnull(B.air))
		/// The logic around get_edge() requires air to exist at this point, which it probably should.
		B.make_air()

	var/a_to_b = get_dir(A,B)
	var/b_to_a = get_dir(B,A)

	if(!A.connections)
		A.connections = new
	if(!B.connections)
		B.connections = new

	if(A.connections.get_connection_for_dir(a_to_b))
		return
	if(B.connections.get_connection_for_dir(b_to_a))
		return
	if(!space && (A.zone == B.zone))
		return


	var/connection/c = new /connection(A,B)

	A.connections.place(c, a_to_b)
	B.connections.place(c, b_to_a)

	if(direct)
		c.mark_direct()

	return TRUE

///Marks a turf for update.
/datum/controller/subsystem/zas/proc/mark_for_update(turf/T)
	#ifdef ZASDBG
	ASSERT(isturf(T))
	#endif
	if(T.needs_air_update)
		return
	tiles_to_update += T
	#ifdef ZASDBG
	T.add_viscontents(zasdbgovl_mark)
	#endif
	T.needs_air_update = 1

///Marks a zone for update.
/datum/controller/subsystem/zas/proc/mark_zone_update(zone/Z)
	#ifdef ZASDBG
	ASSERT(istype(Z))
	#endif
	if(Z.needs_update)
		return
	zones_to_update += Z
	Z.needs_update = 1

///Sleeps an edge, preventing it from processing.
/datum/controller/subsystem/zas/proc/sleep_edge(connection_edge/E)
	#ifdef ZASDBG
	ASSERT(istype(E))
	#endif
	if(!E.excited)
		return
	active_edges -= E
	E.excited = FALSE

	#ifdef ZASDBG
	for(var/turf/T as anything in E.connecting_turfs)
		T.remove_viscontents(zasdbgovl_edge)
	#endif

///Wakes an edge, adding it to the active process list.
/datum/controller/subsystem/zas/proc/excite_edge(connection_edge/E)
	#ifdef ZASDBG
	ASSERT(istype(E))
	#endif
	if(E.excited)
		return
	active_edges += E
	E.excited = TRUE

	#ifdef ZASDBG
	for(var/turf/T as anything in E.connecting_turfs)
		T.add_viscontents(zasdbgovl_edge)
	#endif

///Returns the edge between zones A and B.  If one doesn't exist, it creates one. See header for more information
/datum/controller/subsystem/zas/proc/get_edge(zone/A, zone/B) //Note: B can also be a turf.
	var/connection_edge/edge

	if(isturf(B)) //Zone-to-turf connection.
		for(var/turf/T in A.edges)
			if(B.air.isEqual(T.air)) //Operator overloading :)
				return A.edges[T]
	else
		edge = A.edges[B] //Zone-to-zone connection

	edge ||= create_edge(A,B)

	return edge

///Create an edge of the appropriate type between zone A and zone-or-turf B.
/datum/controller/subsystem/zas/proc/create_edge(zone/A, datum/B)
	var/connection_edge/edge

	if(B.type == /zone) //Zone-to-zone connection
		edge = new/connection_edge/zone(A,B)
	else //Zone-to-turf connection
		edge = new/connection_edge/unsimulated(A,B)

	return edge

///Removes an edge from the subsystem.
/datum/controller/subsystem/zas/proc/remove_edge(connection_edge/E)
	edges -= E
	if(E.excited)
		active_edges -= E
	if(processing_edges)
		processing_edges -= E

/datum/controller/subsystem/zas/StartLoadingMap()
	. = ..()
	can_fire = FALSE

/datum/controller/subsystem/zas/StopLoadingMap()
	. = ..()
	can_fire = TRUE
