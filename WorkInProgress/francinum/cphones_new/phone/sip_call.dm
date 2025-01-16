// Holds state about an individual SIP call.

/datum/sip_call

	/// The controlling SIP handler.
	var/datum/sip_handler/owner

	/// Are we originating this call?
	/// Behaviour basically flips if this is false.
	var/originating = TRUE

	/// Randomly generated call ID. Used for tracing and for identification. md5(world.time+ref(src))
	var/call_id

	/// ORIGINATE: The number we are calling.
	/// ANSWER: The number calling us.
	var/calling_number

	var/our_number

	/// Server address
	var/target_addr

	/* Call Setup */
	/// ORIGINATE: Call is being set up, Play no comfort noises. If timeout, cancel and terminate self.
	#define CALLSTATE_SETUP 0
	/// ORIGINATE: Far side is ringing, play ringback.
	/// ANSWER: We are ringing, Instruct the phone to start ringing.
	#define CALLSTATE_RINGING 1


	/// We are talking, Stop noises, instruct the SIP handler to get everything ready for audio.
	#define CALLSTATE_TALKING 2

	/* Call Teardown/Error */
	/// The connection was closed, check cause_code and go from there.
	#define CALLSTATE_TERMINATE 3

	/// Current call state.
	var/state = 0

	/// Q.850 Cause Code (Beats coming up with my own system) for which our call was terminated.
	var/cause_code

/datum/sip_call/New(_master, _our_number, _calling_number, _target_addr, _call_id)
	. = ..()
	call_id = _call_id || md5("[world.time][ref(src)]")
	our_number = _our_number
	calling_number = _calling_number
	target_addr = _target_addr
	if(_call_id)
		// Being supplied a call ID means we are NOT originating.
		originating = FALSE

/datum/sip_call/receive_signal(datum/signal/signal)
	. = ..()

//
/datum/sip_call/proc/place_call(destination = calling_number)
	if(!calling_number)
		calling_number = destination
	var/datum/signal/invite = new(
		null,
		list(
			PACKET_DESTINATION_ADDRESS = target_addr,
			PACKET_FIELD_PROTOCOL = PACKET_PROTOCOL_SIP,
			PACKET_FIELD_VERB = PACKET_SIP_VERB_INVITE,
			PACKET_SIP_INVITE_FIELD_FROM = our_number,
			PACKET_SIP_INVITE_FIELD_TO = calling_number,
			PACKET_SIP_FIELD_CALLID = call_id
		)
	)
	return invite
