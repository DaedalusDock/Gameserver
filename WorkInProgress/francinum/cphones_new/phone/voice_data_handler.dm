/datum/packet_handler/voice_data
	/// What atom do we make speak? Think: Phone Handset.
	VAR_PRIVATE/atom/movable/speaker
	/// Are we active and doing things, pretty much noops every function if false.
	VAR_PRIVATE/active = FALSE
	/// Are we mute? We'll still hear packets coming in, we just can't send.
	VAR_PRIVATE/mute = FALSE
	/// Are we *allowed* to mute, useful for
	VAR_PRIVATE/allow_mute = TRUE
	//Visual Configuration, used to pretend to be a radio.
	VAR_PRIVATE/vis_span = "radio"
	VAR_PRIVATE/vis_name = "UNSET_NAME"

	// How far should we listen or broadcast heard messages.
	VAR_PRIVATE/hear_range = 1
	VAR_PRIVATE/broadcast_range = 2

	/* Master Interface:
	 *
	 * output: receive_handler_packet(datum/packet_handler/sender, datum/signal/signal)
	 * > Receives a data-complete voice packet, the master is
	 * expected to make any modifications they need (addressing, etc)
	 * before sending it out via the usual means.
	 *
	 * control:
	 * New(speaker,allow_mute, hear_range, broadcast_range)
	 * > Provide a speaker atom for this handler to parasitize.
	 * > allow_mute allows you to enable or disable use-inhand mute.
	 * > It is not required to mute via proccall. (Think: PA speakers.)
	 * > You can also control the range the speaker can hear/broadcast relayed speech.
	 * handler.activate(vis_name)
	 * > Begin
	 *
	*/


/datum/packet_handler/voice_data/New(_master, _speaker, _allow_mute)
	. = ..()
	allow_mute = _allow_mute
	set_speaker(_speaker)

/datum/packet_handler/voice_data/Destroy(force, ...)
	release_speaker()
	return ..()

/datum/packet_handler/voice_data/proc/set_visuals(_span, _name)
	vis_span = _span || vis_span
	vis_name = _name || vis_name

/datum/packet_handler/voice_data/proc/set_speaker(atom/movable/new_speaker)
	// Do we already have a speaker?
	if(!new_speaker || (speaker && speaker != new_speaker))
		//Release the old one.
		release_speaker()

	speaker = new_speaker
	speaker.become_hearing_sensitive(ref(src))
	RegisterSignal(speaker, COMSIG_MOVABLE_HEAR, PROC_REF(handle_speaker_hearing))
	if(allow_mute)
		RegisterSignal(speaker, COMSIG_ITEM_ATTACK_SELF, PROC_REF(handle_attack_self))

//Release a speaker
/datum/packet_handler/voice_data/proc/release_speaker()
	UnregisterSignal(speaker, list(COMSIG_MOVABLE_HEAR,COMSIG_ITEM_ATTACK_SELF))
	speaker.lose_hearing_sensitivity(ref(src))

/datum/packet_handler/voice_data/proc/handle_attack_self(mob/user)
	SIGNAL_HANDLER
	if(mute)
		to_chat(user, span_notice("You mute the [speaker]."))
	else
		to_chat(user, span_notice("You unmute the [speaker]."))
	set_mute(!mute)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/datum/packet_handler/voice_data/proc/handle_speaker_hearing(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	if(mute)
		return

	// Unpack the vars we need.
	var/atom/movable/heard_speaker = hearing_args[HEARING_SPEAKER]
	var/sound_loc = hearing_args[HEARING_SOUND_LOC]
	var/list/message_mods = hearing_args[HEARING_MESSAGE_MODE]

	var/atom/movable/checked_thing = sound_loc || heard_speaker //If we have a location, we care about that, otherwise we're speaking directly from something.
	if(!IN_GIVEN_RANGE(get_turf(speaker), get_turf(checked_thing), hear_range))
		return

	//START SHAMELESS RADIO CARGOCULTING
	var/filtered_mods = list()
	if (message_mods[MODE_CUSTOM_SAY_EMOTE])
		filtered_mods[MODE_CUSTOM_SAY_EMOTE] = message_mods[MODE_CUSTOM_SAY_EMOTE]
		filtered_mods[MODE_CUSTOM_SAY_ERASE_INPUT] = message_mods[MODE_CUSTOM_SAY_ERASE_INPUT]

	encode_voice(heard_speaker, hearing_args[HEARING_RAW_MESSAGE], , hearing_args[HEARING_SPANS], language=hearing_args[HEARING_LANGUAGE], message_mods=filtered_mods)
	//END SHAMELESS RADIO CARGOCULTING

/datum/packet_handler/voice_data/proc/encode_voice(atom/movable/talking_movable, message, channel, list/spans, datum/language/language, list/message_mods)
	if(mute || !active || !talking_movable || !message || !talking_movable.IsVocal())
		return

	//The third var is the 'radio'. It's null. Go fuck yourself.
	var/atom/movable/virtualspeaker/v_speaker = new(null, talking_movable, null)
	if(isliving(talking_movable))
		var/mob/living/libbing = v_speaker
		v_speaker.voice_type = libbing.voice_type



/datum/packet_handler/voice_data/proc/set_mute(new_mute)
	if(mute == new_mute)
		return

	if(mute)
		mute = FALSE
	else
		mute = TRUE

/// Enable the voice relay behaviour. Will always unmute.
/datum/packet_handler/voice_data/proc/activate(voice_name = null)
	set_visuals(_name = voice_name)
	set_mute(FALSE)
	active = TRUE

/datum/packet_handler/voice_data/proc/deactivate()
	active = FALSE

/datum/packet_handler/voice_data/receive_signal(datum/signal/signal)
	if(!active)
		return TRUE
	if(!speaker)
		CRASH("No speaker. Fix your bullshit.")

	var/list/data = signal.data

	var/list/radio_bullshit_override = list("span"=vis_span, "name"=vis_name)

	var/atom/movable/virtualspeaker/admission_of_defeat = data["virtualspeaker"]
	var/sound/funnysound
	if(admission_of_defeat.voice_type)
		var/funnysound_index = copytext_char(data["message"], -1)
		switch(funnysound_index)
			if("?")
				funnysound = voice_type2sound[admission_of_defeat.voice_type]["?"]
			if("!")
				funnysound = voice_type2sound[admission_of_defeat.voice_type]["!"]
			else
				funnysound = voice_type2sound[admission_of_defeat.voice_type][admission_of_defeat.voice_type]


	playsound(speaker, funnysound || 'modular_pariah/modules/radiosound/sound/radio/syndie.ogg', funnysound ? 300 : 30, TRUE, SHORT_RANGE_SOUND_EXTRARANGE, falloff_exponent = 0)
	var/rendered = speaker.compose_message(data["virtualspeaker"], data["language"], data["message"], radio_bullshit_override, data["spans"], data["message_mods"])
	for(var/atom/movable/hearing_movable as anything in get_hearers_in_view(2, speaker)-speaker)
		if(!hearing_movable)//theoretically this should use as anything because it shouldnt be able to get nulls but there are reports that it does.
			stack_trace("somehow theres a null returned from get_hearers_in_view() in send_speech!")
			continue

		hearing_movable.Hear(rendered, data["virtualspeaker"], data["language"], data["message"], radio_bullshit_override, data["spans"], data["message_mods"], speaker.speaker_location(), message_range = INFINITY)
