SUBSYSTEM_DEF(packets)
	name = "Packets"
	wait = 0
	priority = FIRE_PRIORITY_PACKETS
	flags = SS_HIBERNATE
	runlevels = RUNLEVELS_DEFAULT | RUNLEVEL_LOBBY

	var/list/saymodes = list()
	var/list/datum/radio_frequency/frequencies = list()

	///All the physical networks to process
	var/list/datum/powernet/queued_networks = list()
	///Radio packets to process
	var/list/queued_radio_packets = list()
	///Subspace/vocal packets to process
	var/list/queued_subspace_vocals = list()

	///Amount of radio packets processed last cycle
	var/last_processed_radio_packets = 0
	///Amount of tabletmessage packets processed last cycle
	var/last_processed_tablet_message_packets = 0
	///Amount of subspace vocal packets processed last cycle
	var/last_processed_ssv_packets = 0

	///The current processing lists
	var/list/current_networks = list()
	var/list/current_radio_packets = list()
	var/list/current_subspace_vocals = list()

	///Tick usage
	var/cached_cost = 0
	var/cost_networks = 0
	var/cost_radios = 0
	var/cost_tablets = 0
	var/cost_subspace_vocals = 0

	///What processing stage we're at
	var/stage = SSPACKETS_POWERNETS

	//Storage Data Vars
	// -Because bloating GLOB is a crime.

	/// Fancy field name to use for virus packets. Randomly picked for flavor and obscurity.
	var/pda_exploitable_register
	/// Magic command sent by the Detomatix to cause PDAs to explode
	var/detomatix_magic_packet
	/// Magic command sent by the Clown Virus to honkify PDAs
	var/clownvirus_magic_packet
	/// Magic command sent by the Mime virus to mute PDAs
	var/mimevirus_magic_packet
	/// Magic command sent by the FRAME virus to install an uplink.
	/// Mostly a formality as this packet MUST be obfuscated.
	var/framevirus_magic_packet
	/// @everyone broadcast key
	var/gprs_broadcast_packet

	/// NetworkInitialize requesters
	/// For objects that need the full network ready. You probably don't need this.
	VAR_PRIVATE/list/atom/network_initializers

/// Generates a unique (at time of read) ID for an atom, It just plays silly with the ref.
/// Pass the target atom in as arg[1]
/datum/controller/subsystem/packets/proc/generate_net_id(invoker)
	if(!invoker)
		CRASH("Attempted to generate netid for null")
	. = ref(invoker)
	. = "[copytext(.,4,(length(.)))]0"

/datum/controller/subsystem/packets/PreInit(timeofday)
	hibernate_checks = list(
		NAMEOF(src, queued_networks),
		NAMEOF(src, queued_radio_packets),
		NAMEOF(src, queued_subspace_vocals),
		NAMEOF(src, current_networks),
		NAMEOF(src, current_radio_packets),
		NAMEOF(src, current_subspace_vocals)
	)

	for(var/_SM in subtypesof(/datum/saymode))
		var/datum/saymode/SM = new _SM()
		saymodes[SM.key] = SM
	return ..()

/datum/controller/subsystem/packets/Initialize(start_timeofday)

	//Calculate the stupid magic bullshit
	detomatix_magic_packet = random_string(rand(16,32), GLOB.hex_characters)
	clownvirus_magic_packet = random_string(rand(16,32), GLOB.hex_characters)
	mimevirus_magic_packet = random_string(rand(16,32), GLOB.hex_characters)
	framevirus_magic_packet = random_string(rand(16,32), GLOB.hex_characters)
	gprs_broadcast_packet = random_string(rand(16,32), GLOB.hex_characters)
	pda_exploitable_register = pick_list(PACKET_STRING_FILE, "packet_field_names")

	// We're late enough in init order that all network devices have late initialized,
	// so the network *should* be stable, we can now safely re-wake anything that has requested network readiness.
	if(network_initializers) //...If there are any, of course
		for(var/atom/initializer in network_initializers)
			initializer.NetworkInitialize()
			CHECK_TICK
		network_initializers.Cut() //Drop the refs.

	. = ..()

/datum/controller/subsystem/packets/Recover()
	. = ..()
	//Functional vars first
	frequencies = SSpackets.frequencies
	queued_radio_packets = SSpackets.queued_radio_packets
	queued_subspace_vocals = SSpackets.queued_subspace_vocals
	//Data vars
	pda_exploitable_register = SSpackets.pda_exploitable_register
	detomatix_magic_packet = SSpackets.detomatix_magic_packet
	clownvirus_magic_packet = SSpackets.clownvirus_magic_packet
	mimevirus_magic_packet = SSpackets.mimevirus_magic_packet
	framevirus_magic_packet = SSpackets.framevirus_magic_packet
	gprs_broadcast_packet = SSpackets.gprs_broadcast_packet

/datum/controller/subsystem/packets/stat_entry(msg)
	msg += "RP: [length(queued_radio_packets)]{[last_processed_radio_packets]}|"
	// msg += "TM: [length(queued_tablet_messages)]{[last_processed_tablet_message_packets]}|"
	msg += "SSV: [length(queued_subspace_vocals)]{[last_processed_ssv_packets]}|"
	msg += "C:{"
	msg += "CN:[round(cost_networks, 1)]|"
	msg += "CR:[round(cost_radios, 1)]|"
	msg += "CSSV:[round(cost_subspace_vocals, 1)]|"
	msg += "}"

	return ..()

/datum/controller/subsystem/packets/fire(resumed)
	if(!resumed)
		current_networks = queued_networks.Copy()
		current_radio_packets = queued_radio_packets.Copy()
		// current_tablet_messages = queued_tablet_messages.Copy()
		current_subspace_vocals = queued_subspace_vocals.Copy()

	var/timer = TICK_USAGE_REAL

	///Network packets
	if(stage == SSPACKETS_POWERNETS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0

		var/datum/powernet/net
		var/obj/machinery/power/poster
		while(length(current_networks))
			net = current_networks[length(current_networks)]
			if(QDELETED(net))
				current_networks.len--
				queued_networks -= net
				continue

			///Cycle the packet queue
			if(!length(net.current_packet_queue))
				net.current_packet_queue = net.next_packet_queue.Copy()
				net.next_packet_queue.Cut()

			///No packets no problem
			if(!length(net.current_packet_queue))
				current_networks.len--
				queued_networks -= net
				continue

			for(var/datum/signal/signal as anything in net.current_packet_queue)
				// Find the poster so we don't send the signal to it's author
				// A null is fine.
				poster = signal.author?.resolve()

				for(var/obj/machinery/power/client_machine as anything in net.data_nodes - poster)
					///This might need [set waitfor = FALSE] alongside a [CHECK_TICK]
					client_machine.receive_signal(signal)

				///Remove this signal from the queue and see if we're strangling the server
				net.current_packet_queue -= signal

				cached_cost += TICK_USAGE_REAL - timer

				if(MC_TICK_CHECK)
					return

			// Only cut it from the current run when it's done
			current_networks.len--
			// We may have generated more packets in the course of rs calls, If so, don't dequeue it.
			if(!length(net.next_packet_queue))
				queued_networks -= net

		cost_networks = MC_AVERAGE(cost_networks, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		// Next up: Radios!
		stage = SSPACKETS_RADIOS

	if(stage == SSPACKETS_RADIOS)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
			last_processed_radio_packets = 0

		var/datum/signal/packet
		while(length(current_radio_packets))
			packet = current_radio_packets[1]
			current_radio_packets.Cut(1,2)
			queued_radio_packets -= packet

			ImmediateRadioPacketSend(packet)
			cached_cost += TICK_USAGE_REAL - timer
			last_processed_radio_packets++
			if(MC_TICK_CHECK)
				return

		cost_radios = MC_AVERAGE(cost_radios, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE
		stage = SSPACKETS_SUBSPACE_VOCAL

	if(stage == SSPACKETS_SUBSPACE_VOCAL)
		timer = TICK_USAGE_REAL
		if(!resumed)
			cached_cost = 0
			last_processed_ssv_packets = 0

		var/datum/signal/subspace/vocal/packet
		while(length(current_subspace_vocals))
			packet = current_subspace_vocals[1]
			current_subspace_vocals.Cut(1,2)
			queued_subspace_vocals -= packet

			ImmediateSubspaceVocalSend(packet)
			cached_cost += TICK_USAGE_REAL - timer
			last_processed_ssv_packets++
			if(MC_TICK_CHECK)
				return


		cost_subspace_vocals = MC_AVERAGE(cost_subspace_vocals, TICK_DELTA_TO_MS(cached_cost))
		resumed = FALSE

	///Reset to the first stage
	stage = SSPACKETS_POWERNETS



///Immediately send a packet to it's target(s). Used for high-importance packets.
/datum/controller/subsystem/packets/proc/ImmediatePacketSend(datum/signal/packet, datum/target)
	if(islist(target))
		for(var/datum/receiver as anything in target)
			receiver.receive_signal(packet)
	else
		target.receive_signal(packet)

/datum/controller/subsystem/packets/proc/ImmediateRadioPacketSend(datum/signal/packet)
	//If checking range, find the source turf
	var/source = packet.author?.resolve()

	var/turf/start_point
	if(packet.range)
		start_point = get_turf(source)
		if(!start_point)
			return
		//Spatial Grids don't like being asked for negative ranges. -1 is valid and doesn't care about range anyways.
		if(packet.frequency == FREQ_ATMOS_CONTROL && packet.range > 0)
			_irps_spatialgrid_atmos(packet,source,start_point) //heehoo big list.
			return
	var/datum/radio_frequency/freq = packet.frequency_datum
	//Send the data
	for(var/current_filter in packet.filter_list)
		if(isnull(freq.devices[current_filter]))
			continue //Filter lists are lazy and may not exist.
		for(var/datum/weakref/device_ref as anything in freq.devices[current_filter] - packet.author)
			var/obj/device = device_ref.resolve()
			if(isnull(device))
				freq.devices[current_filter] -= device_ref
				continue
			if(packet.range)
				var/turf/end_point = get_turf(device)
				if(!end_point)
					continue
				if(start_point.z != end_point.z || (packet.range > 0 && get_dist(start_point, end_point) > packet.range))
					continue
			device.receive_signal(packet)

/// Do Spatial Grid handling for IRPS, Atmos Radio group.
/// These are separate to save just that little bit more overhead.
/datum/controller/subsystem/packets/proc/_irps_spatialgrid_atmos(datum/signal/packet, datum/source, turf/start_point)
	PRIVATE_PROC(TRUE) //Touch this and I eat your legs.

	var/datum/radio_frequency/freq = packet.frequency_datum
	//Send the data

	var/list/spatial_grid_results = SSspatial_grid.orthogonal_range_search(start_point, SPATIAL_GRID_CONTENTS_TYPE_RADIO_ATMOS, packet.range)

	for(var/obj/listener as anything in spatial_grid_results - source)
		var/found = FALSE
		for(var/filter in packet.filter_list)
		//This is safe because to be in a radio list, an object MUST already have a weakref.
			if(listener.weak_reference in freq.devices[filter])
				found = TRUE
				break
		if(!found)
			continue
		if((get_dist(start_point, listener) > packet.range))
			continue
		listener.receive_signal(packet)

/// Do Spatial Grid handling for IRPS, Non-Atmos Radio group.
/// These are separate to save just that little bit more overhead.
/datum/controller/subsystem/packets/proc/_irps_spatialgrid_everyone_else(datum/signal/packet, datum/source, turf/start_point)
	PRIVATE_PROC(TRUE) //Touch this and I eat your arms.

	var/datum/radio_frequency/freq = packet.frequency_datum
	//Send the data

	var/list/spatial_grid_results = SSspatial_grid.orthogonal_range_search(start_point, SPATIAL_GRID_CONTENTS_TYPE_RADIO_NONATMOS, packet.range)

	for(var/obj/listener as anything in spatial_grid_results - source)
		var/found = FALSE
		for(var/filter in packet.filter_list)
		//This is safe because to be in a radio list, an object MUST already have a weakref.
			if(listener.weak_reference in freq.devices[filter])
				found = TRUE
				break
		if(!found)
			continue
		if((get_dist(start_point, listener) > packet.range))
			continue
		listener.receive_signal(packet)


/datum/controller/subsystem/packets/proc/ImmediateSubspaceVocalSend(datum/signal/subspace/vocal/packet)
	// Perform final composition steps on the message.
	var/message = copytext_char(packet.data["message"], 1, MAX_BROADCAST_LEN)
	if(!message)
		return
	var/compression = packet.data["compression"]
	if(compression > 0)
		message = Gibberish(message, compression >= 30)

	var/list/signal_reaches_every_z_level = packet.levels

	var/atom/movable/virtualspeaker/virt = packet.virt
	var/list/data = packet.data
	var/datum/language/language = packet.language

	if(0 in packet.levels)
		signal_reaches_every_z_level = RADIO_NO_Z_LEVEL_RESTRICTION

	var/frequency = packet.frequency

	// Assemble the list of radios
	var/list/radios = list()
	switch (packet.transmission_method)
		if (TRANSMISSION_SUBSPACE)
			// Reaches any radios on the levels
			var/list/all_radios_of_our_frequency = GLOB.all_radios["[frequency]"]
			radios = all_radios_of_our_frequency.Copy()

			for(var/obj/item/radio/subspace_radio in radios)
				if(!subspace_radio.can_receive(frequency, signal_reaches_every_z_level))
					radios -= subspace_radio

			// Syndicate radios can hear all well-known radio channels
			if (num2text(frequency) in GLOB.reverseradiochannels)
				for(var/obj/item/radio/syndicate_radios in GLOB.all_radios["[FREQ_SYNDICATE]"])
					if(syndicate_radios.can_receive(FREQ_SYNDICATE, RADIO_NO_Z_LEVEL_RESTRICTION))
						radios |= syndicate_radios

		if (TRANSMISSION_RADIO)
			// Only radios not currently in subspace mode
			for(var/obj/item/radio/non_subspace_radio in GLOB.all_radios["[frequency]"])
				if(!non_subspace_radio.subspace_transmission && non_subspace_radio.can_receive(frequency, signal_reaches_every_z_level))
					radios += non_subspace_radio

		if (TRANSMISSION_SUPERSPACE)
			// Only radios which are independent
			for(var/obj/item/radio/independent_radio in GLOB.all_radios["[frequency]"])
				if(independent_radio.independent && independent_radio.can_receive(frequency, signal_reaches_every_z_level))
					radios += independent_radio

	// From the list of radios, find all mobs who can hear those.
	var/list/receive = get_hearers_in_radio_ranges(radios)
	var/list/globally_receiving = list()

	// Add observers who have ghost radio enabled.
	for(var/mob/dead/observer/ghost in GLOB.player_list)
		if(!ghost.observetarget && (ghost.client.prefs?.chat_toggles & CHAT_GHOSTRADIO))
			globally_receiving |= ghost

	// Render the message and have everybody hear it.
	// Always call this on the virtualspeaker to avoid issues.
	var/spans = data["spans"]
	var/list/message_mods = data["mods"]
	var/rendered = virt.compose_message(virt, language, message, frequency, spans)

	for(var/obj/item/radio/radio as anything in receive)
		SEND_SIGNAL(radio, COMSIG_RADIO_RECEIVE, virt.source, message, frequency, data)
		for(var/atom/movable/hearer as anything in receive[radio])
			if(!hearer)
				stack_trace("null found in the hearers list returned by the spatial grid. this is bad")
				continue

			hearer.Hear(rendered, virt, language, message, frequency, spans, message_mods, sound_loc = radio.speaker_location(), message_range = INFINITY)

	// Let the global hearers (ghosts, etc) hear this message
	for(var/atom/movable/hearer as anything in globally_receiving)
		hearer.Hear(rendered, virt, language, message, frequency, spans, message_mods, message_range = INFINITY)

	// This following recording is intended for research and feedback in the use of department radio channels
	if(length(receive))
		SSblackbox.LogBroadcast(frequency)

	var/spans_part = ""
	if(length(spans))
		spans_part = "(spans:"
		for(var/S in spans)
			spans_part = "[spans_part] [S]"
		spans_part = "[spans_part] ) "

	var/lang_name = data["language"]
	var/log_text = "\[[get_radio_name(frequency)]\] [spans_part]\"[message]\" (language: [lang_name])"

	var/mob/source_mob = virt.source

	if(ismob(source_mob))
		source_mob.log_message(log_text, LOG_TELECOMMS)
	else
		log_telecomms("[virt.source] [log_text] [loc_name(get_turf(virt.source))]")

	QDEL_IN(virt, 50)  // Make extra sure the virtualspeaker gets qdeleted

/datum/controller/subsystem/packets/proc/add_object(obj/device, new_frequency as num, filter = null as text|null)
	if(QDELETED(device))
		CRASH("Attempted to add a qdeleting or nonexistent object to radio frequency!")
	var/f_text = num2text(new_frequency)
	var/datum/radio_frequency/frequency = frequencies[f_text]
	if(!frequency)
		frequencies[f_text] = frequency = new(new_frequency)
	frequency.add_listener(device, filter)
	return frequency

/datum/controller/subsystem/packets/proc/remove_object(obj/device, old_frequency)
	var/f_text = num2text(old_frequency)
	var/datum/radio_frequency/frequency = frequencies[f_text]
	if(frequency)
		frequency.remove_listener(device)
		// let's don't delete frequencies in case a non-listener keeps a reference
	return 1

/datum/controller/subsystem/packets/proc/return_frequency(new_frequency as num)
	var/f_text = num2text(new_frequency)
	var/datum/radio_frequency/frequency = frequencies[f_text]
	if(!frequency)
		frequencies[f_text] = frequency = new(new_frequency)
	return frequency

/// Add the respective sensitivity and gridmap membership to a device.
/// This is here instead of /atom/movable because there's no good reason for them to do it themselves
/// (and it centralizes all the radio weirdness). Handles the atmos/nonatmos bucket split internally.
/datum/controller/subsystem/packets/proc/make_radio_sensitive(obj/device, frequency)
	switch(frequency)
		if(FREQ_ATMOS_CONTROL)
			ADD_TRAIT(device, TRAIT_RADIO_LISTENER_ATMOS, "[frequency]")

			for(var/atom/movable/location as anything in get_nested_locs(device) + device)
				LAZYINITLIST(location.important_recursive_contents)
				var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
				if(!length(recursive_contents[RECURSIVE_CONTENTS_RADIO_ATMOS]))
					SSspatial_grid.add_grid_awareness(location, SPATIAL_GRID_CONTENTS_TYPE_RADIO_ATMOS)
				recursive_contents[RECURSIVE_CONTENTS_RADIO_ATMOS] += list(device)

			var/turf/our_turf = get_turf(device)
			SSspatial_grid.add_grid_membership(device, our_turf, SPATIAL_GRID_CONTENTS_TYPE_RADIO_ATMOS)
		else
			ADD_TRAIT(device, TRAIT_RADIO_LISTENER_NONATMOS, "[frequency]")

			for(var/atom/movable/location as anything in get_nested_locs(device) + device)
				LAZYINITLIST(location.important_recursive_contents)
				var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
				if(!length(recursive_contents[RECURSIVE_CONTENTS_RADIO_NONATMOS]))
					SSspatial_grid.add_grid_awareness(location, SPATIAL_GRID_CONTENTS_TYPE_RADIO_NONATMOS)
				recursive_contents[RECURSIVE_CONTENTS_RADIO_NONATMOS] += list(device)

			var/turf/our_turf = get_turf(device)
			SSspatial_grid.add_grid_membership(device, our_turf, SPATIAL_GRID_CONTENTS_TYPE_RADIO_NONATMOS)

/datum/controller/subsystem/packets/proc/remove_radio_sensitive(obj/device, frequency)
	switch(frequency)
		if(FREQ_ATMOS_CONTROL)
			if(!HAS_TRAIT(device, TRAIT_RADIO_LISTENER_ATMOS))
				return
			REMOVE_TRAIT(device, TRAIT_RADIO_LISTENER_ATMOS, "[frequency]")
			if(HAS_TRAIT(device, TRAIT_RADIO_LISTENER_ATMOS))
				CRASH("ATOM STILL HAS ATMOS RADIO LISTENER AFTER remove_radio_sensitive([device.type],[frequency])?? [json_encode(device.status_traits)]")
				//This should never be true, but just in case.
			var/turf/our_turf = get_turf(device)
			/// We get our awareness updated by the important recursive contents stuff, here we remove our membership
			SSspatial_grid.remove_grid_membership(device, our_turf, SPATIAL_GRID_CONTENTS_TYPE_RADIO_ATMOS)

			for(var/atom/movable/location as anything in get_nested_locs(device) + device)
				var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
				recursive_contents[RECURSIVE_CONTENTS_RADIO_ATMOS] -= device
				if(!length(recursive_contents[RECURSIVE_CONTENTS_RADIO_ATMOS]))
					SSspatial_grid.remove_grid_awareness(location, SPATIAL_GRID_CONTENTS_TYPE_RADIO_ATMOS)
				ASSOC_UNSETEMPTY(recursive_contents, RECURSIVE_CONTENTS_RADIO_ATMOS)
				UNSETEMPTY(location.important_recursive_contents)
		else
			if(!HAS_TRAIT(device, TRAIT_RADIO_LISTENER_NONATMOS))
				return
			REMOVE_TRAIT(device, TRAIT_RADIO_LISTENER_NONATMOS, "[frequency]")
			if(HAS_TRAIT(device, TRAIT_RADIO_LISTENER_NONATMOS))
				return //Beats counting.
			var/turf/our_turf = get_turf(device)
			/// We get our awareness updated by the important recursive contents stuff, here we remove our membership
			SSspatial_grid.remove_grid_membership(device, our_turf, SPATIAL_GRID_CONTENTS_TYPE_RADIO_NONATMOS)

			for(var/atom/movable/location as anything in get_nested_locs(device) + device)
				var/list/recursive_contents = location.important_recursive_contents // blue hedgehog velocity
				recursive_contents[RECURSIVE_CONTENTS_RADIO_NONATMOS] -= device
				if(!length(recursive_contents[RECURSIVE_CONTENTS_RADIO_NONATMOS]))
					SSspatial_grid.remove_grid_awareness(location, SPATIAL_GRID_CONTENTS_TYPE_RADIO_NONATMOS)
				ASSOC_UNSETEMPTY(recursive_contents, RECURSIVE_CONTENTS_RADIO_NONATMOS)
				UNSETEMPTY(location.important_recursive_contents)

/datum/controller/subsystem/packets/proc/request_network_initialize(atom/initializer)
	if(initialized)
		//Hi. If you're here, you might have tried to load a device that requests this as part of a
		//post-roundstart map load. I apologize that the idea of touching the code required to support that
		//at the current time of 02:09:24 EST is... Not on the table. Suck my dick.
		CRASH("Attempted to request NetworkInitialize() after SSpackets has initialized!")

	LAZYADD(network_initializers, initializer)
