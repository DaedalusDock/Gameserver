/datum/packet_handler
	/// Who owns us?
	var/obj/machinery/master

/*
 * Handlers are passed signals via receive_signal.
 * If false, the packet is unhandled and should be passed to the next handler.
 *
 * We're just gonna trust this is only ever being called by the master,
 * if it's not, go fuck yourself. seriously.
 *
 * Standard packet output function:
 * receive_handler_packet(datum/packet_handler/sender, datum/signal/signal)
 *
 * Other handlers may define more required functions.
 */

/obj/machinery/proc/receive_handler_packet(datum/packet_handler/sender, /datum/signal/signal, ...)
	return

/datum/packet_handler/New(_master)
	. = ..()
	master = _master

/datum/packet_handler/Destroy(force, ...)
	master = null
	return ..()

/datum/packet_handler/process(delta_time)
	return
