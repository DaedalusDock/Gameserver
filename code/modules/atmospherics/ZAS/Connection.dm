#define CONNECTION_DIRECT (1<<0)
#define CONNECTION_UNSIMULATED (1<<1)
#define CONNECTION_INVALID (1<<3)

/*

Overview:
	Connections are made between turfs by SSzas.connect(). They represent a single point where two zones converge.

Class Vars:
	A - Always a simulated turf.
	B - A simulated or unsimulated turf.

	zoneA - The archived zone of A. Used to check that the zone hasn't changed.
	zoneB - The archived zone of B. May be null in case of unsimulated connections.

	edge - Stores the edge this connection is in. Can reference an edge that is no longer processed
		   after this connection is removed, so make sure to check edge.coefficient > 0 before re-adding it.

Class Procs:

	mark_direct()
		Marks this connection as direct. Does not update the edge.
		Called when the connection is made and there are no doors between A and B.
		Also called by update() as a correction.

	mark_indirect()
		Unmarks this connection as direct. Does not update the edge.
		Called by update() as a correction.

	mark_space()
		Marks this connection as unsimulated. Updating the connection will check the validity of this.
		Called when the connection is made.
		This will not be called as a correction, any connections failing a check against this mark are erased and rebuilt.

	direct()
		Returns 1 if no doors are in between A and B.

	valid()
		Returns 1 if the connection has not been erased.

	erase()
		Called by update() and connection_manager/erase_all().
		Marks the connection as erased and removes it from its edge.

	update()
		Called by connection_manager/update_all().
		Makes numerous checks to decide whether the connection is still valid. Erases it automatically if not.

*/

/connection
	var/turf/A
	var/turf/B
	var/zone/zoneA
	var/zone/zoneB

	var/connection_edge/edge

	///Invalid or Valid
	var/state = 0

	#ifdef ZASDBG
	///Set to true during testing to get verbose debug information
	var/tmp/verbose = FALSE
	#endif

/connection/New(turf/A, turf/B)
	#ifdef ZASDBG
	ASSERT(TURF_HAS_VALID_ZONE(A))
	#endif
	src.A = A
	src.B = B
	zoneA = A.zone
	if(!B.simulated)
		mark_unsimulated()
		edge = SSzas.get_edge(A.zone,B)
		edge.add_connection(src)
	else
		zoneB = B.zone
		edge = SSzas.get_edge(A.zone,B.zone)
		edge.add_connection(src)

///Unmarks this connection as direct. Does not update the edge. Called by update() as a correction.
/connection/proc/mark_direct()
	if(!direct())
		state |= CONNECTION_DIRECT
		edge.direct++

	#ifdef ZASDBG
	if(verbose)
		zas_log("Marked direct.")
	#endif

///Unmarks this connection as direct. Does not update the edge. Called by update() as a correction.
/connection/proc/mark_indirect()
	if(direct())
		state &= ~CONNECTION_DIRECT
		edge.direct--

	#ifdef ZASDBG
	if(verbose)
		zas_log("Marked indirect.")
	#endif

///Marks this connection as unsimulated. Updating the connection will check the validity of this. See file header for more information.
/connection/proc/mark_unsimulated()
	state |= CONNECTION_UNSIMULATED

///Returns 1 if no doors are in between A and B.
/connection/proc/direct()
	return (state & CONNECTION_DIRECT)

///Returns 1 if the connection has not been erased.
/connection/proc/valid()
	return !(state & CONNECTION_INVALID)

///Called by update() and connection_manager/erase_all(). Marks the connection as erased and removes it from its edge.
/connection/proc/erase()
	edge.remove_connection(src)
	state |= CONNECTION_INVALID

	#ifdef ZASDBG
	if(verbose)
		zas_log("Connection Erased: [state]")
	#endif

///Makes numerous checks to decide whether the connection is still valid. Erases it automatically if not.
/connection/proc/update()
	#ifdef ZASDBG
	if(verbose)
		zas_log("Updated, \...")
	#endif

	if(!A.simulated) //If turf A isn't simulated, erase this connection.
		#ifdef ZASDBG
		if(verbose)
			zas_log("Invalid A. Erasing...")
		#endif

		erase()
		return

	var/block_status = SSzas.air_blocked(A,B)
	if(block_status & AIR_BLOCKED) //If turfs A and B cant mingle, erase this connection
		#ifdef ZASDBG
		if(verbose)
			zas_log("Blocked connection. Erasing...")
		#endif

		erase()
		return

	else if(block_status & ZONE_BLOCKED) //If they can mingle but they can't merge zones, mark this connection as indirect
		mark_indirect()
	else
		mark_direct()

	var/b_is_space = !B.simulated

	if(state & CONNECTION_UNSIMULATED)
		if(!b_is_space) //If this is an unsimulated connection and B isn't unsimulated, erase.
			#ifdef ZASDBG
			if(verbose)
				zas_log("Invalid B. Erasing...")
			#endif
			erase()
			return

		if(A.zone != zoneA) //If turf A's zone has changed, attempt to migrate the connection to the new zone. Otherwise, erase.
			#ifdef ZASDBG
			if(verbose)
				zas_log("Zone changed, \...")
			#endif

			if(!A.zone) //No zone, erase.
				erase()

				#ifdef ZASDBG
				if(verbose)
					zas_log("Turf A's zone has disappeared. Erasing...")
				#endif
				return

			else
				edge.remove_connection(src)
				edge = SSzas.get_edge(A.zone, B)
				edge.add_connection(src)
				zoneA = A.zone

		#ifdef ZASDBG
		if(verbose)
			zas_log("Connection is valid.")
		#endif
		return

	else if(b_is_space) //If B is unsimulated and this isn't an unsimulated connection, erase.
		#ifdef ZASDBG
		if(verbose)
			zas_log("Turf B is unsimulated, but this is a simulated connection. Erasing...")
		#endif
		erase()
		return

	if(A.zone == B.zone) //If both turfs share a zone, erase.
		#ifdef ZASDBG
		if(verbose)
			zas_log("Turf A and Turf B share a zone. Erasing...")
		#endif
		erase()
		return

	if(A.zone != zoneA || (zoneB && (B.zone != zoneB))) //If either turf's zone changed
		#ifdef ZASDBG
		if(verbose)
			zas_log("Zones changed, \...")
		#endif

		if(A.zone && B.zone) //Find where we're supposed to be and move us there
			edge.remove_connection(src)
			edge = SSzas.get_edge(A.zone, B.zone)
			edge.add_connection(src)
			zoneA = A.zone
			zoneB = B.zone
		else
			#ifdef ZASDBG
			if(verbose)
				zas_log("Turf A or B lost it's zone. Erasing...")
			#endif
			erase()
			return

	#ifdef ZASDBG
	if(verbose)
		zas_log("Connection is valid.")
	#endif

/connection_edge/proc/queue_spacewind()
	set waitfor = FALSE
	return
