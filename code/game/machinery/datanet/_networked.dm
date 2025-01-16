#define VALIDATE_WIRED_SIGNAL if(!src.signal){return};if(signal.transmission_method != TRANSMISSION_WIRE){CRASH("Received signal with invalid transport mode for this media!")}


/// A wrapper to generate basic, minimally-compliant data packets easily.
/// Returns a `datum/signal` with prefilled `s_addr` and `d_addr` added to `datagram`
/obj/machinery/proc/create_signal(destination_id, list/datagram)
	if(!datagram || !destination_id)
		return //Unfortunately /dev/null isn't network-scale.
	var/list/sig_data = datagram.Copy()
	sig_data[PACKET_SOURCE_ADDRESS] = src.net_id
	sig_data[PACKET_DESTINATION_ADDRESS] = destination_id
	return new /datum/signal(src, sig_data, TRANSMISSION_WIRE)


/// Send a signal from a ref. Data sent in signals must be dereferenced.
/// If you're sending a forged source address (You should have a good reason for this...) set `preserve_s_addr = TRUE
///
/// NONE OF THE ABOVE IS TRUE IF YOU ARE `machinery/power`, AS THEY DEAL DIRECTLY WITH SSPACKETS INSTEAD OF ABSTRACTED TERMINALS
/obj/machinery/proc/post_signal(datum/signal/sending_signal, preserve_s_addr = FALSE)
	if(isnull(netjack) || isnull(sending_signal)) //nullcheck for sanic speed
		return //You need a pipe and something to send down it, though.
	if(!preserve_s_addr)
		sending_signal.data[PACKET_SOURCE_ADDRESS] = src.net_id
	sending_signal.transmission_method = TRANSMISSION_WIRE
	sending_signal.author = WEAKREF(src) // Override the sending signal author.
	src.netjack.post_signal(sending_signal)

/obj/machinery/receive_signal(datum/signal/signal)
	SHOULD_CALL_PARENT(TRUE)
	. = ..() //Should the subtype *probably* stop caring about this packet?
	if(isnull(signal))
		return RECEIVE_SIGNAL_FINISHED
	if(machine_stat & (BROKEN|NOPOWER))
		return RECEIVE_SIGNAL_FINISHED
	var/sigdat = signal.data //cache for sanic speed this joke is getting old.
	if(sigdat[PACKET_DESTINATION_ADDRESS] != src.net_id)//This packet doesn't belong to us directly
		if(sigdat[PACKET_DESTINATION_ADDRESS] == NET_ADDRESS_PING)// But it could be a ping, if so, reply
			var/tmp_filter = sigdat["filter"]
			if(!isnull(tmp_filter) && tmp_filter != net_class)
				return RECEIVE_SIGNAL_FINISHED
			//Blame kapu for how stupid this looks :3
			post_signal(
				create_signal(
					sigdat[PACKET_SOURCE_ADDRESS],
					list(
						"command"=NET_COMMAND_PING_REPLY,
						"netclass"=src.net_class,
						"netaddr"=src.net_id
						)+src.ping_addition
					)
				)
		return RECEIVE_SIGNAL_FINISHED//regardless, return 1 so that machines don't process packets not intended for them.
	return RECEIVE_SIGNAL_CONTINUE // We are the designated recipient of this packet, we need to handle it.

//Handle the network jack

///Attempt to locate a network jack on the same tile and link to it, unlinking from any existing terminal.
/// Passes through the return code from [/obj/machinery/power/data_terminal/proc/connect_machine()]
/obj/machinery/proc/link_to_jack()
	if(!(src.network_flags & NETWORK_FLAG_USE_DATATERMINAL))
		CRASH("Machine that doesn't use data networks attempted to link to network terminal!")
	if(!loc)
		CRASH("Attempted to link to a network jack while in nullspace!")
	var/obj/machinery/power/data_terminal/new_transmission_terminal = locate() in get_turf(src)
	if(netjack == new_transmission_terminal)
		return NETJACK_CONNECT_SUCCESS //Already connected, pretend it's a success.
	unlink_from_jack()//If our new jack is null, then we've somehow lost it? Don't care and just go along with it.
	if(!new_transmission_terminal)
		return
	return new_transmission_terminal.connect_machine(src)

/// Unlink from a network terminal
/// `ignore_check` is used as part of machinery destroy.
/obj/machinery/proc/unlink_from_jack(ignore_check = FALSE)
	if(!ignore_check && !(src.network_flags & NETWORK_FLAG_USE_DATATERMINAL))
		CRASH("Machine that doesn't use data networks attempted to unlink to network terminal (outside destroy)!")
	if(!netjack)
		return
	netjack.disconnect_machine(src)

/// Called just before the network jack is removed.
/// Cannot be used to abort disconnection.
/obj/machinery/proc/netjack_disconnected(var/obj/machinery/power/data_terminal/disconnecting)
	return
