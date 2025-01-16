/**
 * # area
 *
 * A grouping of tiles into a logical space, mostly used by map editors
 */
/area
	name = "Space"
	icon = 'icons/area/areas_misc.dmi'
	icon_state = "unknown"
	layer = AREA_LAYER
	//Keeping this on the default plane, GAME_PLANE, will make area overlays fail to render on FLOOR_PLANE.
	plane = AREA_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	invisibility = INVISIBILITY_LIGHTING

	/// List of all turfs currently inside this area. Acts as a filtered bersion of area.contents
	/// For faster lookup (area.contents is actually a filtered loop over world)
	/// Semi fragile, but it prevents stupid so I think it's worth it
	var/list/turf/contained_turfs = list()
	/// Contained turfs is a MASSIVE list, so rather then adding/removing from it each time we have a problem turf
	/// We should instead store a list of turfs to REMOVE from it, then hook into a getter for it
	/// There is a risk of this and contained_turfs leaking, so a subsystem will run it down to 0 incrementally if it gets too large
	var/list/turf/turfs_to_uncontain = list()

	var/area_flags = VALID_TERRITORY | BLOBS_ALLOWED | UNIQUE_AREA | CULT_PERMITTED

	var/holomap_color = null

	///A var for whether the area allows for detecting fires/etc. Disabled or enabled at a fire alarm.
	var/fire_detect = TRUE
	///A list of all fire locks in this area and on the border of this area.
	var/list/firedoors
	///A list of all fire alarms in this area OR ADJACENT TO IT
	var/list/firealarms
	///A list of all air alarms in this area
	var/list/airalarms
	///Alarm type to count of sources. Not usable for ^ because we handle fires differently
	var/list/active_alarms = list()
	///All the lights in this area
	var/list/obj/machinery/light/lights

	var/lightswitch = TRUE
	var/list/light_switches = list()

	/// All beauty in this area combined, only includes indoor area.
	var/totalbeauty = 0
	/// Beauty average per open turf in the area
	var/beauty = 0
	/// If a room is too big it doesn't have beauty.
	var/beauty_threshold = 150

	/// Used by ghosts to grant new powers. See /datum/component/spook_factor
	var/spook_level

	/// For space, the asteroid, etc. Used with blueprints or with weather to determine if we are adding a new area (vs editing a station room)
	var/outdoors = FALSE

	/// Size of the area in open turfs, only calculated for indoors areas.
	var/areasize = 0

	///Will objects this area be needing power?
	var/requires_power = TRUE
	/// This gets overridden to 1 for space in area/.
	var/always_unpowered = FALSE

	var/obj/machinery/power/apc/apc = null

	var/power_equip = TRUE
	var/power_light = TRUE
	var/power_environ = TRUE

	var/has_gravity = FALSE

	var/parallax_movedir = 0

	var/ambience_index = AMBIENCE_GENERIC
	///A list of sounds to pick from every so often to play to clients.
	var/list/ambientsounds
	///Does this area immediately play an ambience track upon enter?
	var/forced_ambience = FALSE
	///The background droning loop that plays 24/7
	var/ambient_buzz = 'sound/ambience/shipambience.ogg'
	///The volume of the ambient buzz
	var/ambient_buzz_vol = 50
	///Used to decide what the minimum time between ambience is
	var/min_ambience_cooldown = 30 SECONDS
	///Used to decide what the maximum time between ambience is
	var/max_ambience_cooldown = 60 SECONDS

	flags_1 = CAN_BE_DIRTY_1

	var/list/cameras

	///Typepath to limit the areas (subtypes included) that atoms in this area can smooth with. Used for shuttles.
	var/area/area_limited_icon_smoothing

	var/list/power_usage

	/// Wire assignment for airlocks in this area
	var/airlock_wires = /datum/wires/airlock

	///This datum, if set, allows terrain generation behavior to be ran on Initialize()
	var/datum/map_generator/map_generator

	///Used to decide what kind of reverb the area makes sound have
	var/sound_environment = SOUND_ENVIRONMENT_NONE

	var/list/air_vent_info = list()
	var/list/air_scrub_info = list()

	var/datum/alarm_handler/alarm_manager

	/// A lazylist of ckeys that have entered this area. See display_flavor()
	var/list/ckeys_that_have_been_here
	/// A weighted list of flavor texts for display_flavor().
	var/list/flavor_texts

/**
 * A list of teleport locations
 *
 * Adding a wizard area teleport list because motherfucking lag -- Urist
 * I am far too lazy to make it a proper list of areas so I'll just make it run the usual telepot routine at the start of the game
 */
GLOBAL_LIST_EMPTY(teleportlocs)

/**
 * Generate a list of turfs you can teleport to from the areas list
 *
 * Includes areas if they're not a shuttle or not not teleport or have no contents
 *
 * The chosen turf is the first item in the areas contents that is a station level
 *
 * The returned list of turfs is sorted by name
 */
/proc/process_teleport_locs()
	for(var/area/AR in get_sorted_areas())
		if(istype(AR, /area/shuttle) || AR.area_flags & NOTELEPORT)
			continue
		if(GLOB.teleportlocs[AR.name])
			continue
		if (!AR.has_contained_turfs())
			continue
		if (is_station_level(AR.z))
			GLOB.teleportlocs[AR.name] = AR

/**
 * Called when an area loads
 *
 *  Adds the item to the GLOB.areas_by_type list based on area type
 */
/area/New()
	// This interacts with the map loader, so it needs to be set immediately
	// rather than waiting for atoms to initialize.
	if (area_flags & UNIQUE_AREA)
		GLOB.areas_by_type[type] = src
	GLOB.areas += src
	power_usage = new /list(AREA_USAGE_LEN) // Some atoms would like to use power in Initialize()
	alarm_manager = new(src) //Just in case. Apparently.
	return ..()

/*
 * Initalize this area
 *
 * intializes the dynamic area lighting and also registers the area with the z level via
 * reg_in_areas_in_z
 *
 * returns INITIALIZE_HINT_LATELOAD
 */
/area/Initialize(mapload)
	icon = null
	if(!ambientsounds)
		ambientsounds = GLOB.ambience_assoc[ambience_index]

	if((area_flags & AREA_USES_STARLIGHT) && CONFIG_GET(flag/starlight))
		base_lighting_alpha = 0
		base_lighting_color = null
		area_lighting = AREA_LIGHTING_DYNAMIC

	if(!requires_power)
		power_light = TRUE
		power_equip = TRUE
		power_environ = TRUE

	switch(area_lighting)
		if(AREA_LIGHTING_DYNAMIC)
			luminosity = 0

		if(AREA_LIGHTING_STATIC)
			if(isnull(base_lighting_color) || base_lighting_alpha == 0)
				stack_trace("Area of type [type] is set to be statically lit, but has invalid base lighting data. This has been automatically replaced with fullbright.")
				base_lighting_color = COLOR_WHITE
				base_lighting_alpha = 255

	. = ..()

	reg_in_areas_in_z()
	update_base_lighting()

	return INITIALIZE_HINT_LATELOAD

/**
 * Sets machine power levels in the area
 */
/area/LateInitialize()
	power_change() // all machines set to current power level, also updates icon
	update_beauty()

/area/proc/RunGeneration()
	if(map_generator)
		map_generator = new map_generator()
		var/list/turfs = list()
		for(var/turf/T in contents)
			turfs += T
		map_generator.generate_terrain(turfs, src)

/area/proc/test_gen()
	if(map_generator)
		var/list/turfs = list()
		for(var/turf/T in contents)
			turfs += T
		map_generator.generate_terrain(turfs, src)

/area/proc/get_contained_turfs()
	if(length(turfs_to_uncontain))
		cannonize_contained_turfs()
	return contained_turfs

/// Ensures that the contained_turfs list properly represents the turfs actually inside us
/area/proc/cannonize_contained_turfs()
	// This is massively suboptimal for LARGE removal lists
	// Try and keep the mass removal as low as you can. We'll do this by ensuring
	// We only actually add to contained turfs after large changes (Also the management subsystem)
	// Do your damndest to keep turfs out of /area/space as a stepping stone
	// That sucker gets HUGE and will make this take actual tens of seconds if you stuff turfs_to_uncontain
	contained_turfs -= turfs_to_uncontain
	turfs_to_uncontain = list()

/// Returns TRUE if we have contained turfs, FALSE otherwise
/area/proc/has_contained_turfs()
	return length(contained_turfs) - length(turfs_to_uncontain) > 0

/**
 * Register this area as belonging to a z level
 *
 * Ensures the item is added to the SSmapping.areas_in_z list for this z
 */
/area/proc/reg_in_areas_in_z()
	if(!has_contained_turfs())
		return
	var/list/areas_in_z = SSmapping.areas_in_z
	update_areasize()
	if(!z)
		WARNING("No z found for [src]")
		return
	if(!areas_in_z["[z]"])
		areas_in_z["[z]"] = list()
	areas_in_z["[z]"] += src

/**
 * Destroy an area and clean it up
 *
 * Removes the area from GLOB.areas_by_type and also stops it processing on SSobj
 *
 * This is despite the fact that no code appears to put it on SSobj, but
 * who am I to argue with old coders
 */
/area/Destroy()
	if(GLOB.areas_by_type[type] == src)
		GLOB.areas_by_type[type] = null
	GLOB.sortedAreas -= src
	light_switches.Cut()
	STOP_PROCESSING(SSobj, src)
	QDEL_NULL(alarm_manager)
	return ..()

/**
 * Close and lock a door passed into this proc
 *
 * Does this need to exist on area? probably not
 */
/area/proc/close_and_lock_door(obj/machinery/door/DOOR)
	set waitfor = FALSE
	DOOR.close()
	if(DOOR.density)
		DOOR.lock()

/**
 * Raise a burglar alert for this area
 *
 * Close and locks all doors in the area and alerts silicon mobs of a break in
 *
 * Alarm auto resets after 600 ticks
 */
/area/proc/burglaralert(obj/trigger)
	if (area_flags & NO_ALERTS)
		return
	//Trigger alarm effect
	communicate_fire_alert(FIRE_RAISED_GENERIC, TRUE)
	//Lockdown airlocks
	for(var/obj/machinery/door/door in src)
		close_and_lock_door(door)

/**
 * Update the icon of the area (overridden to always be null for space
 */
/area/space/update_icon_state()
	SHOULD_CALL_PARENT(FALSE)
	icon_state = null


/**
 * Returns int 1 or 0 if the area has power for the given channel
 *
 * evalutes a mixture of variables mappers can set, requires_power, always_unpowered and then
 * per channel power_equip, power_light, power_environ
 */
/area/proc/powered(chan) // return true if the area has power to given channel

	if(!requires_power)
		return TRUE
	if(always_unpowered)
		return FALSE
	switch(chan)
		if(AREA_USAGE_EQUIP)
			return power_equip
		if(AREA_USAGE_LIGHT)
			return power_light
		if(AREA_USAGE_ENVIRON)
			return power_environ

	return FALSE

/**
 * Space is not powered ever, so this returns false
 */
/area/space/powered(chan) //Nope.avi
	return FALSE

/**
 * Called when the area power status changes
 *
 * Updates the area icon, calls power change on all machinees in the area, and sends the `COMSIG_AREA_POWER_CHANGE` signal.
 */
/area/proc/power_change()
	SEND_SIGNAL(src, COMSIG_AREA_POWER_CHANGE)
	update_appearance()


/**
 * Add a static amount of power load to an area
 *
 * Possible channels
 * *AREA_USAGE_STATIC_EQUIP
 * *AREA_USAGE_STATIC_LIGHT
 * *AREA_USAGE_STATIC_ENVIRON
 */
/area/proc/addStaticPower(value, powerchannel)
	switch(powerchannel)
		if(AREA_USAGE_STATIC_START to AREA_USAGE_STATIC_END)
			power_usage[powerchannel] += value

/**
 * Remove a static amount of power load to an area
 *
 * Possible channels
 * *AREA_USAGE_STATIC_EQUIP
 * *AREA_USAGE_STATIC_LIGHT
 * *AREA_USAGE_STATIC_ENVIRON
 */
/area/proc/removeStaticPower(value, powerchannel)
	switch(powerchannel)
		if(AREA_USAGE_STATIC_START to AREA_USAGE_STATIC_END)
			power_usage[powerchannel] -= value

/**
 * Clear all non-static power usage in area
 *
 * Clears all power used for the dynamic equipment, light and environment channels
 */
/area/proc/clear_usage()
	power_usage[AREA_USAGE_EQUIP] = 0
	power_usage[AREA_USAGE_LIGHT] = 0
	power_usage[AREA_USAGE_ENVIRON] = 0


/**
 * Add a power value amount to the stored used_x variables
 */
/area/proc/use_power(amount, chan)
	switch(chan)
		if(AREA_USAGE_DYNAMIC_START to AREA_USAGE_DYNAMIC_END)
			power_usage[chan] += amount

/**
 * Call back when an atom enters an area
 *
 * Sends signals COMSIG_AREA_ENTERED and COMSIG_ENTER_AREA (to a list of atoms)
 *
 * If the area has ambience, then it plays some ambience music to the ambience channel
 */
/area/Entered(atom/movable/arrived, area/old_area)
	SHOULD_CALL_PARENT(FALSE)
	set waitfor = FALSE
	SEND_SIGNAL(src, COMSIG_AREA_ENTERED, arrived, old_area)

	if(ismob(arrived))
		var/mob/M = arrived
		M.update_ambience_area(src)

	if(!arrived.important_recursive_contents?[RECURSIVE_CONTENTS_AREA_SENSITIVE])
		return

	for(var/atom/movable/recipient as anything in arrived.important_recursive_contents[RECURSIVE_CONTENTS_AREA_SENSITIVE])
		SEND_SIGNAL(recipient, COMSIG_ENTER_AREA, src)

/**
 * Called when an atom exits an area
 *
 * Sends signals COMSIG_AREA_EXITED and COMSIG_EXIT_AREA (to a list of atoms)
 */
/area/Exited(atom/movable/gone, direction)
	SHOULD_CALL_PARENT(FALSE)
	SEND_SIGNAL(src, COMSIG_AREA_EXITED, gone, direction)

	if(!gone.important_recursive_contents?[RECURSIVE_CONTENTS_AREA_SENSITIVE])
		return
	for(var/atom/movable/recipient as anything in gone.important_recursive_contents[RECURSIVE_CONTENTS_AREA_SENSITIVE])
		SEND_SIGNAL(recipient, COMSIG_EXIT_AREA, src)

///Divides total beauty in the room by roomsize to allow us to get an average beauty per tile.
/area/proc/update_beauty()
	if(!areasize)
		beauty = 0
		return FALSE
	if(areasize >= beauty_threshold)
		beauty = 0
		return FALSE //Too big
	beauty = totalbeauty / areasize

/**
 * Setup an area (with the given name)
 *
 * Sets the area name, sets all status var's to false and adds the area to the sorted area list
 */
/area/proc/setup(a_name)
	name = a_name
	power_equip = FALSE
	power_light = FALSE
	power_environ = FALSE
	always_unpowered = FALSE
	area_flags &= ~VALID_TERRITORY
	area_flags &= ~BLOBS_ALLOWED
	require_area_resort()
/**
 * Set the area size of the area
 *
 * This is the number of open turfs in the area contents, or FALSE if the outdoors var is set
 *
 */
/area/proc/update_areasize()
	if(outdoors)
		return FALSE
	areasize = 0
	for(var/turf/open/T in get_contained_turfs())
		areasize++

/**
 * Causes a runtime error
 */
/area/AllowDrop()
	CRASH("Bad op: area/AllowDrop() called")

/**
 * Causes a runtime error
 */
/area/drop_location()
	CRASH("Bad op: area/drop_location() called")

/// A hook so areas can modify the incoming args (of what??)
/area/proc/PlaceOnTopReact(list/new_baseturfs, turf/fake_turf_type, flags)
	return flags


/// Called when a living mob that spawned here, joining the round, receives the player client.
/area/proc/on_joining_game(mob/living/boarder)
	SHOULD_CALL_PARENT(TRUE)
	if(prob(5) && boarder.client && ishuman(boarder))
		LAZYADDASSOC(ckeys_that_have_been_here, boarder.ckey, TRUE)
		spawn(0)
			display_flavor(boarder)

///Called by airalarms and firealarms to communicate the status of the area to relevant machines
/area/proc/communicate_fire_alert(code)
	for(var/obj/machinery/light/L as anything in lights)
		L.update()

	for(var/datum/listener in airalarms + firealarms + firedoors)
		SEND_SIGNAL(listener, COMSIG_FIRE_ALERT, code)

/area/add_viscontents(atom/A)
	CRASH("Tried to mutate area vis_contents.")

/area/distinct_add_viscontents(atom/A)
	CRASH("Tried to mutate area vis_contents.")

/area/remove_viscontents(atom/A)
	CRASH("Tried to mutate area vis_contents.")

/area/cut_viscontents()
	CRASH("Tried to mutate area vis_contents.")

/// Adjusts the spook level and sends out a signal
/area/proc/adjust_spook_level(adj)
	var/old = spook_level
	spook_level += adj
	SEND_SIGNAL(src, AREA_SPOOK_LEVEL_CHANGED, src, old)

/area/proc/display_flavor(mob/living/carbon/human/pawn)
	if(!length(flavor_texts))
		return

	to_chat(pawn, pick_weight(flavor_texts))
