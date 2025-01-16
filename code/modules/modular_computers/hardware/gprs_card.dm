// Since we can't assure that the PDA program is running at all times,
// We need to do this in "hardware"
//This is the definition of overdesigned, but the way it used to work was also awful, so eat shit.

#define GPRS_ENABLED TRUE
#define GPRS_DISABLED FALSE

/obj/item/computer_hardware/network_card/packetnet
	name = "\improper GPRS network card"
	desc = "A cheap network card with an attached GPRS Modem. Supports NTNet and GPRS Messaging."
	var/gprs_frequency = FREQ_COMMON
	var/datum/radio_frequency/radio_connection

	/// Stores up to [queue_max] messages until the PDA asks for them.
	VAR_PRIVATE/list/datum/signal/packet_queue
	/// Maximum amount of messages held by [packet_queue]
	var/queue_max = 5
	/// Hardware PDA discovery
	/// TGUI display format, list(list("target_addr"="addr","name"="name","job"="job"),...)
	var/list/known_pdas
	var/radio_state = GPRS_DISABLED

/obj/item/computer_hardware/network_card/packetnet/Initialize(mapload)
	. = ..()
	packet_queue = list()
	known_pdas = list()

/obj/item/computer_hardware/network_card/packetnet/on_install(obj/item/modular_computer/install_into, mob/living/user)
	. = ..()
	enable_changed(install_into.enabled)


/obj/item/computer_hardware/network_card/packetnet/on_remove(obj/item/modular_computer/remove_from, mob/living/user)
	. = ..()
	enable_changed(FALSE)
	packet_queue.Cut() // Volatile memory~
	known_pdas.Cut()

/obj/item/computer_hardware/network_card/packetnet/Destroy()
	SSpackets.remove_object(src, gprs_frequency, RADIO_PDAMESSAGE)
	radio_connection = null
	packet_queue.Cut()
	. = ..()

/obj/item/computer_hardware/network_card/packetnet/diagnostics(mob/user)
	..()
	to_chat(user, "GPRS - General Packet Radio Service")
	to_chat(user, "┗ TX/RX Band - [format_frequency(gprs_frequency)]")

/obj/item/computer_hardware/network_card/packetnet/examine(mob/user)
	. = ..()
	if(get_dist(get_turf(src), get_turf(user)) >= 2)
		. += span_info("You're too far away to read the board...")
		return
	. += span_info("The silkscreen reads...")
	. += "\t[span_info("GPRS FREQ: [span_robot(format_frequency(gprs_frequency))]")]"
	. += "\t[span_info("GPRS ADDR: [span_robot(hardware_id)]")]"

/obj/item/computer_hardware/network_card/packetnet/receive_signal(datum/signal/signal)
	if(!holder || !signal.data) //Basic checks
		return
	if(signal.transmission_method != TRANSMISSION_RADIO)
		CRASH("[src] received non-radio packet, transmission method ID [signal.transmission_method], Expected [TRANSMISSION_RADIO]")
	var/list/signal_data = signal.data //medium velocity silver hedgehog
	var/signal_d_addr = signal_data[PACKET_DESTINATION_ADDRESS]
	if(signal_d_addr == NET_ADDRESS_PING) //Ping.
		var/datum/signal/outgoing = new(
			src,
			list(
				PACKET_DESTINATION_ADDRESS = signal_data[PACKET_SOURCE_ADDRESS],
				PACKET_CMD = NET_COMMAND_PING_REPLY,
				PACKET_NETCLASS = NETCLASS_GRPS_CARD,
				"netaddr" = hardware_id
			)
		)
		if(signal_data["pda_scan"] && istype(holder, /obj/item/modular_computer/tablet))
			// If we're on an actual tablet, pass along the user info. No privacy here.
			var/obj/item/modular_computer/tablet/tab_holder = holder
			var/list/og_data = outgoing.data
			og_data["reg_name"] = tab_holder.saved_identification
			og_data["reg_job"] = tab_holder.saved_job
		post_signal(outgoing)
	//Either it's broadcast or directed to us.
	if(isnull(signal_d_addr) || signal_d_addr == hardware_id)
		// If it's a ping reply, check for a PDA.
		if(signal.data[PACKET_CMD] == NET_COMMAND_PING_REPLY)
			//If it's from a GPRS card, respond, otherwise, who cares.
			if(signal.data[PACKET_NETCLASS] == NETCLASS_GRPS_CARD)
				var/list/new_pda_info = list(
					"target_addr" = signal.data[PACKET_SOURCE_ADDRESS],
					"name" = signal.data["reg_name"] || "#UNK",
					"job" = signal.data["reg_job"] || "#UNK"
				)
				known_pdas += list(new_pda_info)
			// Trash other ping reply packets, they'll just clog the buffer.
			return
		//We don't really care what it is, just store it.
		append_signal(signal)


/obj/item/computer_hardware/network_card/packetnet/proc/post_signal(datum/signal/signal)
	if(!radio_connection || !signal)
		return FALSE // Something went wrong.
	signal.data[PACKET_SOURCE_ADDRESS] = hardware_id //Readdress outgoing packets.
	signal.author = WEAKREF(src)
	radio_connection.post_signal(signal, RADIO_PDAMESSAGE)
	return TRUE //We at least tried.

/// Take a signal out of the queue.
/obj/item/computer_hardware/network_card/packetnet/proc/pop_signal()
	if(!length(packet_queue))
		return FALSE //Nothing left, chief.
	var/datum/signal/popped = packet_queue[1]
	packet_queue -= popped
	return popped

/// Push a signal onto the queue, Drop a packet if we're over the limit.
/obj/item/computer_hardware/network_card/packetnet/proc/append_signal(datum/signal/signal)
	PRIVATE_PROC(TRUE)
	if(signal.has_magic_data & MAGIC_DATA_MUST_DISCARD)
		return //We can't hold volatile signals.
	if(length(packet_queue) == queue_max)
		pop_signal() //Discard the first signal in the queue
	packet_queue += signal.Copy()
	return

/// Get the length of the packet queue
/obj/item/computer_hardware/network_card/packetnet/proc/check_queue()
	return length(packet_queue)

/obj/item/computer_hardware/network_card/packetnet/proc/set_radio_state(new_state)
	if(radio_state == new_state)
		return
	radio_state = new_state
	if(radio_state)
		radio_connection = SSpackets.add_object(src, gprs_frequency, RADIO_PDAMESSAGE)
	else
		SSpackets.remove_object(src, gprs_frequency)
		radio_connection = null

/obj/item/computer_hardware/network_card/packetnet/enable_changed(new_state)
	set_radio_state(new_state)
	..()


#undef GPRS_ENABLED
#undef GPRS_DISABLED
