//Acts like a normal vent, but has an input AND output.
///pressure_checks defines for external_pressure_bound and input_pressure_min
#define EXT_BOUND 1
#define INPUT_MIN 2
#define OUTPUT_MAX 4

/obj/machinery/atmospherics/components/binary/dp_vent_pump
	icon = 'icons/obj/atmospherics/components/unary_devices.dmi' //We reuse the normal vent icons!
	icon_state = "dpvent_map-3"

	//node2 is output port
	//node1 is input port

	name = "dual-port air vent"
	desc = "Has a valve and pump attached to it. There are two ports."

	use_power = IDLE_POWER_USE
	power_rating = 45000

	hide = TRUE
	initial_volume = ATMOS_DEFAULT_VOLUME_PUMP
	///Variable for radio frequency
	var/frequency = FREQ_ATMOS_CONTROL
	///Variable for radio id
	var/id = null
	///Stores the radio connection
	var/datum/radio_frequency/radio_connection
	///Indicates that the direction of the pump, if 0 is siphoning, if 1 is releasing
	var/pump_direction = 1
	///Set the maximum allowed external pressure
	var/external_pressure_bound = ONE_ATMOSPHERE
	///Set the maximum pressure at the input port
	var/input_pressure_min = 0
	///Set the maximum pressure at the output port
	var/output_pressure_max = 0
	///Set the flag for the pressure bound
	var/pressure_checks = EXT_BOUND

	var/radio_filter_in
	var/radio_filter_out

/obj/machinery/atmospherics/components/binary/dp_vent_pump/Initialize(mapload)
	if(!id_tag)
		id_tag = SSpackets.generate_net_id(src)
	. = ..()

/obj/machinery/atmospherics/components/binary/dp_vent_pump/Destroy()
	var/area/vent_area = get_area(src)
	if(vent_area)
		vent_area.air_vent_info -= id_tag
		GLOB.air_vent_names -= id_tag

	SSpackets.remove_object(src, frequency)
	radio_connection = null
	return ..()

/obj/machinery/atmospherics/components/binary/dp_vent_pump/update_name()
	. = ..()
	if(override_naming)
		return
	var/area/vent_area = get_area(src)
	name = "\proper [vent_area.name] [name] [id_tag]"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/update_icon_nopipes()
	cut_overlays()
	if(showpipe)
		var/image/cap = get_pipe_image(icon, "dpvent_cap", dir, pipe_color, piping_layer = piping_layer)
		add_overlay(cap)

	if(!on || !is_operational)
		icon_state = "vent_off"
	else
		icon_state = pump_direction ? "vent_out" : "vent_in"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/process_atmos()
	if(!on)
		return

	var/turf/location = get_turf(loc)
	if(isclosedturf(location))
		return

	var/datum/gas_mixture/air1 = airs[1]
	var/datum/gas_mixture/air2 = airs[2]

	var/datum/gas_mixture/environment = loc.unsafe_return_air() //We SAFE_ZAS_UPDATE later!
	var/environment_pressure = environment.returnPressure()

	if(pump_direction) //input -> external
		var/pressure_delta = 10000

		if(pressure_checks&EXT_BOUND)
			pressure_delta = min(pressure_delta, (external_pressure_bound - environment_pressure))
		if(pressure_checks&INPUT_MIN)
			pressure_delta = min(pressure_delta, (air1.returnPressure() - input_pressure_min))

		if(pressure_delta <= 0)
			return
		if(air1.temperature <= 0)
			return
		if(!air1.total_moles)
			return

		var/transfer_moles = calculate_transfer_moles(air1, environment, pressure_delta)
		var/draw = pump_gas(air1, environment, transfer_moles, power_rating)
		if(draw > -1)
			var/datum/pipeline/parent1 = parents[1]
			parent1.update = TRUE
			ATMOS_USE_POWER(draw)

	else //external -> output
		var/pressure_delta = 10000

		if(pressure_checks&EXT_BOUND)
			pressure_delta = min(pressure_delta, (environment_pressure - external_pressure_bound))
		if(pressure_checks&INPUT_MIN)
			pressure_delta = min(pressure_delta, (output_pressure_max - air2.returnPressure()))

		if(pressure_delta <= 0)
			return
		if(environment.temperature <= 0)
			return
		if(!environment.total_moles)
			return
		var/transfer_moles = calculate_transfer_moles(environment, air2, pressure_delta, parents[2]?.combined_volume || 0)

		var/draw = pump_gas(environment, air2, transfer_moles, power_rating)
		if(draw > -1)
			var/datum/pipeline/parent2 = parents[2]
			parent2.update = TRUE
			ATMOS_USE_POWER(draw)

	SAFE_ZAS_UPDATE(loc)

//Radio remote control

/**
 * Called in atmos_init(), used to change or remove the radio frequency from the component
 * Arguments:
 * * -new_frequency: the frequency that should be used for the radio to attach to the component, use 0 to remove the radio
 */
/obj/machinery/atmospherics/components/binary/dp_vent_pump/proc/set_frequency(new_frequency)
	SSpackets.remove_object(src, frequency)
	frequency = new_frequency
	if(frequency)
		radio_connection = SSpackets.add_object(src, frequency, radio_filter_in)

/**
 * Called in atmos_init(), send the component status to the radio device connected
 */
/obj/machinery/atmospherics/components/binary/dp_vent_pump/proc/broadcast_status()
	if(!radio_connection)
		return

	var/datum/signal/signal = new(src, list(
		"tag" = id,
		"device" = "ADVP",
		"power" = on,
		"direction" = pump_direction?("release"):("siphon"),
		"checks" = pressure_checks,
		"input" = input_pressure_min,
		"output" = output_pressure_max,
		"external" = external_pressure_bound,
		"sigtype" = "status"
	))

	var/area/vent_area = get_area(src)
	if(!GLOB.air_vent_names[id_tag])
		update_appearance(UPDATE_NAME)
		GLOB.air_vent_names[id_tag] = name

	vent_area.air_vent_info[id_tag] = signal.data
	radio_connection.post_signal(signal, filter = radio_filter_out)

/obj/machinery/atmospherics/components/binary/dp_vent_pump/atmos_init()
	radio_filter_in = frequency==FREQ_ATMOS_CONTROL?(RADIO_FROM_AIRALARM):null
	radio_filter_out = frequency==FREQ_ATMOS_CONTROL?(RADIO_TO_AIRALARM):null
	if(frequency)
		set_frequency(frequency)
	broadcast_status()
	..()

/obj/machinery/atmospherics/components/binary/dp_vent_pump/receive_signal(datum/signal/signal)
	if(!signal.data["tag"] || (signal.data["tag"] != id) || (signal.data["sigtype"]!="command"))
		return

	if(("status" in signal.data)) //Send stauts and early return, I'm cargoculting the timer here.
		broadcast_status()
		return

	if("power" in signal.data)
		on = text2num(signal.data["power"])

	if("power_toggle" in signal.data)
		on = !on

	if("set_direction" in signal.data)
		pump_direction = text2num(signal.data["set_direction"])

	if("checks" in signal.data)
		pressure_checks = text2num(signal.data["checks"])

	if("purge" in signal.data)
		pressure_checks &= ~1
		pump_direction = 0

	if("stabilize" in signal.data)
		pressure_checks |= 1
		pump_direction = 1

	if("set_input_pressure" in signal.data)
		input_pressure_min = clamp(text2num(signal.data["set_input_pressure"]),0,MAX_PUMP_PRESSURE)

	if("set_output_pressure" in signal.data)
		output_pressure_max = clamp(text2num(signal.data["set_output_pressure"]),0,MAX_PUMP_PRESSURE)

	if("set_external_pressure" in signal.data)
		external_pressure_bound = clamp(text2num(signal.data["set_external_pressure"]),0,MAX_PUMP_PRESSURE)

	addtimer(CALLBACK(src, PROC_REF(broadcast_status)), 2)
	update_appearance()



/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume
	name = "large dual-port air vent"
	initial_volume = 1000
	power_rating = 45000

// Mapping

/obj/machinery/atmospherics/components/binary/dp_vent_pump/layer2
	piping_layer = 2
	icon_state = "dpvent_map-2"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/layer4
	piping_layer = 4
	icon_state = "dpvent_map-4"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/on
	on = TRUE
	icon_state = "dpvent_map_on-3"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/on/layer2
	piping_layer = 2
	icon_state = "dpvent_map_on-2"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/on/layer4
	piping_layer = 4
	icon_state = "dpvent_map_on-4"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/incinerator_ordmix
	id = INCINERATOR_ORDMIX_DP_VENTPUMP
	frequency = FREQ_AIRLOCK_CONTROL

/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/incinerator_atmos
	id = INCINERATOR_ATMOS_DP_VENTPUMP
	frequency = FREQ_AIRLOCK_CONTROL

/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/layer2
	piping_layer = 2
	icon_state = "dpvent_map-2"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/layer4
	piping_layer = 4
	icon_state = "dpvent_map-4"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/on
	on = TRUE
	icon_state = "dpvent_map_on-3"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/on/layer2
	piping_layer = 2
	icon_state = "dpvent_map_on-2"

/obj/machinery/atmospherics/components/binary/dp_vent_pump/high_volume/on/layer4
	piping_layer = 4
	icon_state = "dpvent_map_on-4"

#undef EXT_BOUND
#undef INPUT_MIN
#undef OUTPUT_MAX
