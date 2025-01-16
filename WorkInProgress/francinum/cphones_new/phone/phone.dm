#define PACKET_HANDLER_SIGNALLING "sip"
#define PACKET_HANDLER_VOICE_DATA "rtp"

/obj/machinery/telephony/telephone

	icon = 'goon/icons/obj/phones.dmi'
	icon_state = "phone"

	// Mapload/setup/autodiscovery vars. These are only used to configure the signalling datum during "bootup"
	// At all other times, all signalling state is stored on the signalling datum.

	/// The phone's assigned number, Used for mapload discovery
	var/init_extension = "0000"
	/// The phone's initial Caller NAMe. Used to give a name to the voice on the other side.
	/// This is only used to configure the CNAM on the exchange.
	/// If unset, will not attempt to change an existing CNAM, or if none is ever registered
	/// for an extension, will display the calling phone number instead.
	var/init_cnam
	/// Used to select which exchange to register to. if unset, first come first serve.
	/// Defaults to `"NEVER"`, which will not autoconfigure at all.
	var/init_office_code = "NEVER"
	/// Used to authenticate with the exchange.
	var/tmp/autoconf_secret = ""

	/// Is our write-protect screw installed? If not, Allow entering configuration mode.
	var/config_screwed = TRUE
	/// Are we currently in the config handler? If so, what state are we in.
	var/tmp/configuring = FALSE

	// Queue of packets, We drain this on process. Only broadcast or packets meant for us get queued.
	var/tmp/list/datum/signal/packet_queue

	// Our packet handlers, We use these to compartmentalize behaviour so I don't go fucking insane.
	var/tmp/list/datum/packet_handler/packet_handlers

	var/tmp/obj/item/food/grown/banana/handset

/obj/machinery/telephony/telephone/LateInitialize()
	. = ..()
	packet_queue = list()
	packet_handlers = list()
	//Init our various handlers.
	packet_handlers[PACKET_HANDLER_VOICE_DATA] = new /datum/packet_handler/voice_data(src, /*speaker*/)

/obj/machinery/telephony/telephone/Destroy()
	. = ..()
	QDEL_LIST_ASSOC(packet_handlers)

/obj/machinery/telephony/telephone/examine(mob/user)
	. = ..()
	if(config_screwed)
		. += span_info("Odd. One of the screws is [span_alert("red")].")
	else
		. += span_info("One of the screws is very loose. It's [span_alert("red")], unlike the rest.")



/obj/machinery/telephony/telephone/process()
	// We intentionally delay this until game start.
	if(!packet_handlers[PACKET_HANDLER_SIGNALLING])
		packet_handlers[PACKET_HANDLER_SIGNALLING] = new /datum/packet_handler/sip_registration(
			src,
			init_extension,
			init_office_code,
			autoconf_secret
		)
	else
		packet_handlers[PACKET_HANDLER_SIGNALLING].process()
	if(length(packet_queue))
		handle_packet_queue()

/obj/machinery/telephony/telephone/receive_signal(datum/signal/signal)
	if(..() == RECEIVE_SIGNAL_FINISHED)//Handled by default.
		return
	var/datum/signal/storable = signal.Copy()
	packet_queue += storable

/obj/machinery/telephony/telephone/receive_handler_packet(datum/packet_handler/sender, datum/signal/signal, list/sip_state)
	switch(sender.type)
		if(/datum/packet_handler/sip_registration)
			//SIP data handler can also send control information instead, it'll only send one or the other.
			if(sip_state)
				switch(sip_state[SIP_STATE_CODE])
					if(SIP_STATE_CODE_START_RINGING)
			else
		if(/datum/packet_handler/voice_data)

// time to play dress-up as a subsystem
/obj/machinery/telephony/telephone/proc/handle_packet_queue()
	for(var/datum/signal/packet as anything in packet_queue)
		var/list/data = packet.data
		switch(data[PACKET_FIELD_PROTOCOL])
			if(PACKET_PROTOCOL_SIP)
				packet_handlers[PACKET_HANDLER_SIGNALLING]?.receive_signal(packet)
			if(PACKET_PROTOCOL_RTP)
				packet_handlers[PACKET_HANDLER_VOICE_DATA].receive_signal(packet)
			//else {drop_packet};
		if(data[PACKET_CMD] == NET_COMMAND_PING_REPLY) //If this is a ping reply, it also goes to the SIP handler.
			packet_handlers[PACKET_HANDLER_SIGNALLING]?.receive_signal(packet)
		packet_queue -= packet
		if(TICK_CHECK)
			return
