/*

Overview:
	The connection_manager class stores connections in each cardinal direction on a turf.
	It isn't always present if a turf has no connections, check if(connections) before using.
	Contains procs for mass manipulation of connection data.

Class Vars:

	NSEWUD - Connections to this turf in each cardinal direction.

Class Procs:

	get(d)
		Returns the connection (if any) in this direction.
		Preferable to accessing the connection directly because it checks validity.

	place(connection/c, d)
		Called by air_master.connect(). Sets the connection in the specified direction to c.

	update_all()
		Called after turf/update_air_properties(). Updates the validity of all connections on this turf.

	erase_all()
		Called when the turf is changed with ChangeTurf(). Erases all existing connections.

Macros:
	check(connection/c)
		Checks for connection validity. It's possible to have a reference to a connection that has been erased.


*/

/turf
	var/tmp/connection_manager/connections

/connection_manager/
	var/connection/N
	var/connection/S
	var/connection/E
	var/connection/W

#ifdef MULTIZAS
	var/connection/U
	var/connection/D
#endif

/// Return a valid connection for a given direction.
/connection_manager/proc/get_connection_for_dir(d)
	switch(d)
		if(NORTH)
			if(N?.valid())
				return N

		if(SOUTH)
			if(S?.valid())
				return S
		if(EAST)
			if(E?.valid())
				return E
		if(WEST)
			if(W?.valid())
				return W

		#ifdef MULTIZAS
		if(UP)
			if(U?.valid())
				return U
		if(DOWN)
			if(D?.valid())
				return D
		#endif

/connection_manager/proc/place(connection/c, d)
	switch(d)
		if(NORTH) N = c
		if(SOUTH) S = c
		if(EAST) E = c
		if(WEST) W = c

		#ifdef MULTIZAS
		if(UP) U = c
		if(DOWN) D = c
		#endif

/connection_manager/proc/update_all()
	if(N?.valid()) N.update()
	if(S?.valid()) S.update()
	if(E?.valid()) E.update()
	if(W?.valid()) W.update()
	#ifdef MULTIZAS
	if(U?.valid()) U.update()
	if(D?.valid()) D.update()
	#endif

/connection_manager/proc/erase_all()
	if(N?.valid()) N.erase()
	if(S?.valid()) S.erase()
	if(E?.valid()) E.erase()
	if(W?.valid()) W.erase()
	#ifdef MULTIZAS
	if(U?.valid()) U.erase()
	if(D?.valid()) D.erase()
	#endif

