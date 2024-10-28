#define EXT_BOUND 1
#define INT_BOUND 2
#define NO_BOUND 3

#define SIPHONING 0
#define RELEASING 1

#define DEFAULT_PRESSURE_DELTA 10000
/obj/machinery/atmospherics/components/unary/vent_pump
	icon_state = "vent_map-3"

	name = "air vent"
	desc = "Has a valve and pump attached to it."

	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.1
	can_unwrench = TRUE
	welded = FALSE
	layer = GAS_SCRUBBER_LAYER
	hide = TRUE
	shift_underlay_only = FALSE
	pipe_state = "uvent"
	vent_movement = VENTCRAWL_ALLOWED | VENTCRAWL_CAN_SEE | VENTCRAWL_ENTRANCE_ALLOWED

	power_rating = 30000

	///Direction of pumping the gas (RELEASING or SIPHONING)
	var/pump_direction = RELEASING
	///Should we check internal pressure, external pressure, both or none? (EXT_BOUND, INT_BOUND, NO_BOUND)
	var/pressure_checks = EXT_BOUND
	///The external pressure threshold (default 101 kPa)
	var/external_pressure_bound = ONE_ATMOSPHERE
	///The internal pressure threshold (default 0 kPa)
	var/internal_pressure_bound = 0
	// EXT_BOUND: Do not pass external_pressure_bound
	// INT_BOUND: Do not pass internal_pressure_bound
	// NO_BOUND: Do not pass either

	///Frequency id for connecting to the NTNet
	var/frequency = FREQ_ATMOS_CONTROL
	///Reference to the radio datum
	var/datum/radio_frequency/radio_connection
	///Radio connection to the air alarm
	var/radio_filter_out
	///Radio connection from the air alarm
	var/radio_filter_in

	var/can_hibernate = TRUE

/obj/machinery/atmospherics/components/unary/vent_pump/Initialize()
	if(!id_tag)
		id_tag = SSpackets.generate_net_id(src)

	SET_TRACKING(__TYPE__)
	. = ..()

/obj/machinery/atmospherics/components/unary/vent_pump/Destroy()
	UNSET_TRACKING(__TYPE__)
	var/area/vent_area = get_area(src)
	if(vent_area)
		vent_area.air_vent_info -= id_tag
		GLOB.air_vent_names -= id_tag

	SSpackets.remove_object(src,frequency)
	radio_connection = null
	return ..()

/obj/machinery/atmospherics/components/unary/vent_pump/update_icon_nopipes()
	cut_overlays()
	if(showpipe)
		var/image/cap = get_pipe_image(icon, "vent_cap", initialize_directions)
		add_overlay(cap)
	else
		PIPING_LAYER_SHIFT(src, PIPING_LAYER_DEFAULT)

	if(welded)
		icon_state = "vent_welded"
		return

	if(!nodes[1] || !on || !is_operational)
		if(icon_state == "vent_welded")
			icon_state = "vent_off"
			return

		if(pump_direction & RELEASING)
			icon_state = "vent_out-off"
		else // pump_direction == SIPHONING
			icon_state = "vent_in-off"
		return

	if(!COOLDOWN_FINISHED(src, hibernating))
		icon_state = "vent_hibernating"
		return

	if(icon_state == ("vent_out-off" || "vent_in-off" || "vent_off"))
		if(pump_direction & RELEASING)
			icon_state = "vent_out"
			flick("vent_out-starting", src)
		else // pump_direction == SIPHONING
			icon_state = "vent_in"
			flick("vent_in-starting", src)
		return

	if(pump_direction & RELEASING)
		icon_state = "vent_out"
	else // pump_direction == SIPHONING
		icon_state = "vent_in"

/obj/machinery/atmospherics/components/unary/vent_pump/process_atmos()
	if(!is_operational)
		return
	if(!nodes[1])
		on = FALSE
	if(!on || welded)
		return
	var/turf/open/us = loc
	if(!istype(us))
		return

	var/datum/gas_mixture/air_contents = airs[1]
	var/datum/gas_mixture/environment = us.unsafe_return_air() //We SAFE_ZAS_UPDATE later!
	var/pressure_delta = get_pressure_delta(environment)
	if((environment.temperature || air_contents.temperature) && pressure_delta > 0.5)
		SAFE_ZAS_UPDATE(us)
		if(pump_direction & RELEASING) //internal -> external
			var/transfer_moles = calculate_transfer_moles(air_contents, environment, pressure_delta)
			var/draw = pump_gas(air_contents, environment, transfer_moles, power_rating)
			if(draw > -1)
				ATMOS_USE_POWER(draw)
				update_parents()
			else if(can_hibernate)
				COOLDOWN_START(src, hibernating, 15 SECONDS)

		else //external -> internal
			var/transfer_moles = calculate_transfer_moles(environment, air_contents, pressure_delta, parents[1]?.combined_volume || 0)

			//limit flow rate from turfs
			transfer_moles = min(transfer_moles, environment.total_moles*air_contents.volume/environment.volume)	//group_multiplier gets divided out here
			var/draw = pump_gas(environment, air_contents, transfer_moles, power_rating)
			if(draw > -1)
				ATMOS_USE_POWER(draw)
				update_parents()
			else if(can_hibernate)
				COOLDOWN_START(src, hibernating, 15 SECONDS)



	else
		if(pump_direction && (pressure_checks&EXT_BOUND) && can_hibernate)
			COOLDOWN_START(src, hibernating, 15 SECONDS)

	update_icon_nopipes()

/obj/machinery/atmospherics/components/unary/vent_pump/proc/get_pressure_delta(datum/gas_mixture/environment)
	var/pressure_delta = DEFAULT_PRESSURE_DELTA
	var/environment_pressure = environment.returnPressure()
	var/datum/gas_mixture/air_contents = airs[1]

	if(pump_direction) //internal -> external
		if(pressure_checks & EXT_BOUND)
			pressure_delta = min(pressure_delta, external_pressure_bound - environment_pressure) //increasing the pressure here
		if(pressure_checks & INT_BOUND)
			pressure_delta = min(pressure_delta, air_contents.returnPressure() - internal_pressure_bound) //decreasing the pressure here
	else //external -> internal
		if(pressure_checks & EXT_BOUND)
			pressure_delta = min(pressure_delta, environment_pressure - external_pressure_bound) //decreasing the pressure here
		if(pressure_checks & INT_BOUND)
			pressure_delta = min(pressure_delta, internal_pressure_bound - air_contents.returnPressure()) //increasing the pressure here

	return pressure_delta
//Radio remote control

/obj/machinery/atmospherics/components/unary/vent_pump/proc/set_frequency(new_frequency)
	SSpackets.remove_object(src, frequency)
	frequency = new_frequency
	if(frequency)
		radio_connection = SSpackets.add_object(src, frequency, radio_filter_in)

/obj/machinery/atmospherics/components/unary/vent_pump/proc/broadcast_status()
	if(!radio_connection)
		return

	var/datum/signal/signal = new(src, list(
		"tag" = id_tag,
		"frequency" = frequency,
		"device" = "VP",
		"timestamp" = world.time,
		"power" = on,
		"direction" = pump_direction,
		"checks" = pressure_checks,
		"internal" = internal_pressure_bound,
		"external" = external_pressure_bound,
		"sigtype" = "status"
	))

	var/area/vent_area = get_area(src)
	if(!GLOB.air_vent_names[id_tag])
		// If we do not have a name, assign one.
		// Produces names like "Port Quarter Solar vent pump hZ2l6".
		update_appearance(UPDATE_NAME)
		GLOB.air_vent_names[id_tag] = name

	vent_area.air_vent_info[id_tag] = signal.data

	radio_connection.post_signal(signal, radio_filter_out)

/obj/machinery/atmospherics/components/unary/vent_pump/update_name()
	. = ..()
	if(override_naming)
		return
	var/area/vent_area = get_area(src)
	name = "\proper [vent_area.name] [name] [id_tag]"


/obj/machinery/atmospherics/components/unary/vent_pump/atmos_init()
	//some vents work his own spesial way
	radio_filter_in = frequency==FREQ_ATMOS_CONTROL?(RADIO_FROM_AIRALARM):null
	radio_filter_out = frequency==FREQ_ATMOS_CONTROL?(RADIO_TO_AIRALARM):null
	if(frequency)
		set_frequency(frequency)
	broadcast_status()
	..()

/obj/machinery/atmospherics/components/unary/vent_pump/receive_signal(datum/signal/signal)
	if(!is_operational || !signal.data["tag"] || (signal.data["tag"] != id_tag) || (signal.data["sigtype"]!="command"))
		return


	// Check if we're reporting status, Early return if we are.
	if("status" in signal.data)
		broadcast_status()
		return // do not update_appearance if we don't actually do anything.

	COOLDOWN_RESET(src, hibernating)

	var/atom/signal_sender = signal.data["user"]

	if("purge" in signal.data)
		pressure_checks &= ~EXT_BOUND
		pump_direction = SIPHONING

	if("stabilize" in signal.data)
		pressure_checks |= EXT_BOUND
		pump_direction = RELEASING

	if("power" in signal.data)
		on = text2num(signal.data["power"])

	if("power_toggle" in signal.data)
		on = !on

	if("checks" in signal.data)
		var/old_checks = pressure_checks
		pressure_checks = text2num(signal.data["checks"])
		if(pressure_checks != old_checks)
			investigate_log(" pressure checks were set to [pressure_checks] by [key_name(signal_sender)]",INVESTIGATE_ATMOS)

	if("checks_toggle" in signal.data)
		pressure_checks = (pressure_checks?0:NO_BOUND)

	if("direction" in signal.data)
		pump_direction = text2num(signal.data["direction"])

	if("set_internal_pressure" in signal.data)
		var/old_pressure = internal_pressure_bound
		internal_pressure_bound = clamp(text2num(signal.data["set_internal_pressure"]),0,ONE_ATMOSPHERE*50)
		if(old_pressure != internal_pressure_bound)
			investigate_log(" internal pressure was set to [internal_pressure_bound] by [key_name(signal_sender)]",INVESTIGATE_ATMOS)

	if("set_external_pressure" in signal.data)
		var/old_pressure = external_pressure_bound
		external_pressure_bound = clamp(text2num(signal.data["set_external_pressure"]),0,ONE_ATMOSPHERE*50)
		if(old_pressure != external_pressure_bound)
			investigate_log(" external pressure was set to [external_pressure_bound] by [key_name(signal_sender)]",INVESTIGATE_ATMOS)

	if("reset_external_pressure" in signal.data)
		external_pressure_bound = ONE_ATMOSPHERE

	if("reset_internal_pressure" in signal.data)
		internal_pressure_bound = 0

	if("adjust_internal_pressure" in signal.data)
		internal_pressure_bound = clamp(internal_pressure_bound + text2num(signal.data["adjust_internal_pressure"]),0,ONE_ATMOSPHERE*50)

	if("adjust_external_pressure" in signal.data)
		external_pressure_bound = clamp(external_pressure_bound + text2num(signal.data["adjust_external_pressure"]),0,ONE_ATMOSPHERE*50)

		// log_admin("DEBUG \[[world.timeofday]\]: vent_pump/receive_signal: unknown command \"[signal.data["command"]]\"\n[signal.debug_print()]")
	broadcast_status()
	update_appearance()

/obj/machinery/atmospherics/components/unary/vent_pump/welder_act(mob/living/user, obj/item/welder)
	..()
	if(!welder.tool_start_check(user, amount=0))
		return TRUE
	to_chat(user, span_notice("You begin welding the vent..."))
	if(welder.use_tool(src, user, 20, volume=50))
		if(!welded)
			user.visible_message(span_notice("[user] welds the vent shut."), span_notice("You weld the vent shut."), span_hear("You hear welding."))
			welded = TRUE
		else
			user.visible_message(span_notice("[user] unwelded the vent."), span_notice("You unweld the vent."), span_hear("You hear welding."))
			welded = FALSE
		update_appearance()
		pipe_vision_img = image(src, loc, dir = dir)
		pipe_vision_img.plane = ABOVE_HUD_PLANE
		investigate_log("was [welded ? "welded shut" : "unwelded"] by [key_name(user)]", INVESTIGATE_ATMOS)
		add_fingerprint(user)
	return TRUE

/obj/machinery/atmospherics/components/unary/vent_pump/can_unwrench(mob/user)
	. = ..()
	if(. && on && is_operational)
		to_chat(user, span_warning("You cannot unwrench [src], turn it off first!"))
		return FALSE

/obj/machinery/atmospherics/components/unary/vent_pump/examine(mob/user)
	. = ..()
	if(welded)
		. += "It seems welded shut."
	if(!COOLDOWN_FINISHED(src, hibernating))
		. += span_notice("It is sleeping to conserve power.")

/obj/machinery/atmospherics/components/unary/vent_pump/power_change()
	. = ..()
	update_icon_nopipes()

/obj/machinery/atmospherics/components/unary/vent_pump/attack_alien(mob/user, list/modifiers)
	if(!welded || !(do_after(user, src, 20)))
		return
	user.visible_message(span_warning("[user] furiously claws at [src]!"), span_notice("You manage to clear away the stuff blocking the vent."), span_hear("You hear loud scraping noises."))
	welded = FALSE
	update_appearance()
	pipe_vision_img = image(src, loc, dir = dir)
	pipe_vision_img.plane = ABOVE_HUD_PLANE
	playsound(loc, 'sound/weapons/bladeslice.ogg', 100, TRUE)

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume
	name = "large air vent"
	power_channel = AREA_USAGE_EQUIP

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/Initialize()
	. = ..()
	var/datum/gas_mixture/air_contents = airs[1]
	air_contents.volume = 1000

/obj/machinery/atmospherics/components/unary/vent_pump/multitool_act(mob/living/user, obj/item/tool)
	. = ..()
	can_hibernate = !can_hibernate
	to_chat(user, span_notice("\The [src] will [can_hibernate ? "now" : "no longer"] sleep to conserve energy."))
	if(!can_hibernate)
		COOLDOWN_RESET(src, hibernating)

	return TOOL_ACT_TOOLTYPE_SUCCESS
// mapping
/obj/machinery/atmospherics/components/unary/vent_pump/layer2
	piping_layer = 2
	icon_state = "vent_map-2"

/obj/machinery/atmospherics/components/unary/vent_pump/layer4
	piping_layer = 4
	icon_state = "vent_map-4"

/obj/machinery/atmospherics/components/unary/vent_pump/on
	on = TRUE
	icon_state = "vent_map_on-3"

/obj/machinery/atmospherics/components/unary/vent_pump/on/layer2
	piping_layer = 2
	icon_state = "vent_map_on-2"

/obj/machinery/atmospherics/components/unary/vent_pump/on/layer4
	piping_layer = 4
	icon_state = "vent_map_on-4"

/obj/machinery/atmospherics/components/unary/vent_pump/siphon
	pump_direction = SIPHONING
	pressure_checks = INT_BOUND
	internal_pressure_bound = 4000
	external_pressure_bound = 0

/obj/machinery/atmospherics/components/unary/vent_pump/siphon/layer2
	piping_layer = 2
	icon_state = "vent_map-2"

/obj/machinery/atmospherics/components/unary/vent_pump/siphon/layer4
	piping_layer = 4
	icon_state = "vent_map-4"

/obj/machinery/atmospherics/components/unary/vent_pump/siphon/on
	on = TRUE
	icon_state = "vent_map_siphon_on-3"

/obj/machinery/atmospherics/components/unary/vent_pump/siphon/on/layer2
	piping_layer = 2
	icon_state = "vent_map_siphon_on-2"

/obj/machinery/atmospherics/components/unary/vent_pump/siphon/on/layer4
	piping_layer = 4
	icon_state = "vent_map_siphon_on-4"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/layer2
	piping_layer = 2
	icon_state = "vent_map-2"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/layer4
	piping_layer = 4
	icon_state = "map_vent-4"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/on
	on = TRUE
	icon_state = "vent_map_on-3"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/on/layer2
	piping_layer = 2
	icon_state = "vent_map_on-2"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/on/layer4
	piping_layer = 4
	icon_state = "map_vent_on-4"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/siphon
	pump_direction = SIPHONING
	pressure_checks = INT_BOUND
	internal_pressure_bound = 2000
	external_pressure_bound = 0

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/siphon/layer2
	piping_layer = 2
	icon_state = "vent_map-2"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/siphon/layer4
	piping_layer = 4
	icon_state = "map_vent-4"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/siphon/on
	on = TRUE
	icon_state = "vent_map_siphon_on-3"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/siphon/on/layer2
	piping_layer = 2
	icon_state = "vent_map_siphon_on-2"

/obj/machinery/atmospherics/components/unary/vent_pump/high_volume/siphon/on/layer4
	piping_layer = 4
	icon_state = "vent_map_siphon_on-4"

#undef INT_BOUND
#undef EXT_BOUND
#undef NO_BOUND

#undef SIPHONING
#undef RELEASING
