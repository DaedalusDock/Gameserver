/// Gas tank air sensor.
/// These always hook to monitors, be mindful of them
/obj/machinery/air_sensor
	name = "gas sensor"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "gsensor1"
	resistance_flags = FIRE_PROOF

	var/on = TRUE

	var/frequency = FREQ_ATMOS_STORAGE
	var/datum/radio_frequency/radio_connection

	/// The unique string that represents which atmos chamber to associate with.
	var/chamber_id

/obj/machinery/air_sensor/Initialize(mapload)
	id_tag = chamber_id + "_sensor"
	SSairmachines.start_processing_machine(src)
	radio_connection = SSpackets.add_object(src, frequency, RADIO_ATMOSIA)
	return ..()

/obj/machinery/air_sensor/Destroy()
	SSpackets.remove_object(src, frequency)
	broadcast_destruction(frequency)
	SSairmachines.stop_processing_machine(src)
	return ..()

/obj/machinery/air_sensor/proc/broadcast_destruction(frequency)
	var/datum/signal/signal = new(null, list(
		"sigtype" = "destroyed",
		"tag" = id_tag,
		"timestamp" = world.time,
	))
	var/datum/radio_frequency/connection = SSpackets.return_frequency(frequency)
	connection.post_signal(signal, filter = RADIO_ATMOSIA)

/obj/machinery/air_sensor/update_icon_state()
	icon_state = "gsensor[on]"
	return ..()

/obj/machinery/air_sensor/process_atmos()
	if(!on)
		return

	var/datum/gas_mixture/air_sample = loc.unsafe_return_air()
	var/datum/signal/signal = new(src, list(
		"sigtype" = "status",
		"tag" = id_tag,
		"timestamp" = world.time,
		"gasmix" = gas_mixture_parser(air_sample),
	))
	radio_connection.post_signal(signal, filter = RADIO_ATMOSIA)
