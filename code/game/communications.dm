/*
 * HOW IT WORKS
 *
 *The SSradio is a global object maintaining all radio transmissions, think about it as about "ether".
 *Note that walkie-talkie, intercoms and headsets handle transmission using nonstandard way.
 *procs:
 *
 * add_object(obj/device as obj, new_frequency as num, filter as text|null = null)
 *   Adds listening object.
 *   parameters:
 *     device - device receiving signals, must have proc receive_signal (see description below).
 *       one device may listen several frequencies, but not same frequency twice.
 *     new_frequency - see possibly frequencies below;
 *     filter - thing for optimization. Optional, but recommended.
 *              All filters should be consolidated in this file, see defines later.
 *              Device without listening filter will receive all signals (on specified frequency).
 *              Device with filter will receive any signals sent without filter.
 *              Device with filter will not receive any signals sent with different filter.
 *   returns:
 *    Reference to frequency object.
 *
 * remove_object (obj/device, old_frequency)
 *   Obliviously, after calling this proc, device will not receive any signals on old_frequency.
 *   Other frequencies will left unaffected.
 *
 *return_frequency(var/frequency as num)
 *   returns:
 *    Reference to frequency object. Use it if you need to send and do not need to listen.
 *
 *radio_frequency is a global object maintaining list of devices that listening specific frequency.
 *procs:
 *
 *   post_signal(obj/source as obj|null, datum/signal/signal, filter as text|null = null, range as num|null = null)
 *     Sends signal to all devices that wants such signal.
 *     parameters:
 *       source - object, emitted signal. Usually, devices will not receive their own signals.
 *       signal - see description below.
 *       filter - described above.
 *       range - radius of regular byond's square circle on that z-level. null means everywhere, on all z-levels.
 *
 * obj/proc/receive_signal(datum/signal/signal)
 *   Handler from received signals. By default does nothing. Define your own for your object.
 *   Avoid of sending signals directly from this proc, use spawn(0). Do not use sleep() here please.
 *     parameters:
 *       signal - see description below. Extract all needed data from the signal before doing sleep(), spawn() or return!
 *
 * datum/signal
 *   vars:
 *   source
 *     an object that emitted signal. Used for debug and bearing.
 *   data
 *     list with transmitting data. Usual use pattern:
 *       data["msg"] = "hello world"
 *   encryption
 *     Some number symbolizing "encryption key".
 *     Note that game actually do not use any cryptography here.
 *     If receiving object don't know right key, it must ignore encrypted signal in its receive_signal.
 *
 */
/* the radio controller is a confusing piece of shit and didnt work
	so i made radios not use the radio controller.
*/
GLOBAL_LIST_EMPTY(all_radios)

/proc/add_radio(obj/item/radio, freq)
	if(!freq || !radio)
		return
	if(!GLOB.all_radios["[freq]"])
		GLOB.all_radios["[freq]"] = list(radio)
		return freq

	GLOB.all_radios["[freq]"] |= radio
	return freq

/proc/remove_radio(obj/item/radio, freq)
	if(!freq || !radio)
		return
	if(!GLOB.all_radios["[freq]"])
		return

	GLOB.all_radios["[freq]"] -= radio

/proc/remove_radio_all(obj/item/radio)
	for(var/freq in GLOB.all_radios)
		GLOB.all_radios["[freq]"] -= radio

// For information on what objects or departments use what frequencies,
// see __DEFINES/radio.dm. Mappers may also select additional frequencies for
// use in maps, such as in intercoms.

GLOBAL_LIST_INIT(radiochannels, list(
	RADIO_CHANNEL_COMMON = FREQ_COMMON,
	RADIO_CHANNEL_SCIENCE = FREQ_SCIENCE,
	RADIO_CHANNEL_COMMAND = FREQ_COMMAND,
	RADIO_CHANNEL_MEDICAL = FREQ_MEDICAL,
	RADIO_CHANNEL_ENGINEERING = FREQ_ENGINEERING,
	RADIO_CHANNEL_SECURITY = FREQ_SECURITY,
	RADIO_CHANNEL_CENTCOM = FREQ_CENTCOM,
	RADIO_CHANNEL_SYNDICATE = FREQ_SYNDICATE,
	RADIO_CHANNEL_SUPPLY = FREQ_SUPPLY,
	RADIO_CHANNEL_SERVICE = FREQ_SERVICE,
	RADIO_CHANNEL_AI_PRIVATE = FREQ_AI_PRIVATE,
	RADIO_CHANNEL_CTF_RED = FREQ_CTF_RED,
	RADIO_CHANNEL_CTF_BLUE = FREQ_CTF_BLUE,
	RADIO_CHANNEL_CTF_GREEN = FREQ_CTF_GREEN,
	RADIO_CHANNEL_CTF_YELLOW = FREQ_CTF_YELLOW
))

GLOBAL_LIST_INIT(reverseradiochannels, list(
	"[FREQ_COMMON]" = RADIO_CHANNEL_COMMON,
	"[FREQ_SCIENCE]" = RADIO_CHANNEL_SCIENCE,
	"[FREQ_COMMAND]" = RADIO_CHANNEL_COMMAND,
	"[FREQ_MEDICAL]" = RADIO_CHANNEL_MEDICAL,
	"[FREQ_ENGINEERING]" = RADIO_CHANNEL_ENGINEERING,
	"[FREQ_SECURITY]" = RADIO_CHANNEL_SECURITY,
	"[FREQ_CENTCOM]" = RADIO_CHANNEL_CENTCOM,
	"[FREQ_SYNDICATE]" = RADIO_CHANNEL_SYNDICATE,
	"[FREQ_SUPPLY]" = RADIO_CHANNEL_SUPPLY,
	"[FREQ_SERVICE]" = RADIO_CHANNEL_SERVICE,
	"[FREQ_AI_PRIVATE]" = RADIO_CHANNEL_AI_PRIVATE,
	"[FREQ_CTF_RED]" = RADIO_CHANNEL_CTF_RED,
	"[FREQ_CTF_BLUE]" = RADIO_CHANNEL_CTF_BLUE,
	"[FREQ_CTF_GREEN]" = RADIO_CHANNEL_CTF_GREEN,
	"[FREQ_CTF_YELLOW]" = RADIO_CHANNEL_CTF_YELLOW
))

/// Frequency to file name. See chat_icons.dm
GLOBAL_LIST_INIT(freq2icon, list(
	"[FREQ_COMMON]" = "radio.png",
	// Companies
	"[FREQ_ENGINEERING]" = "eng.png",
	"[FREQ_MEDICAL]" = "med.png",
	"[FREQ_SUPPLY]" = "mail.png",
	"[FREQ_SECURITY]" = "sec.png",
	"[FREQ_COMMAND]" = "ntboss.png",
	// Other
	"[FREQ_AI_PRIVATE]" = "ai.png",
	"[FREQ_SYNDICATE]" = "syndieboss.png",
))

/datum/radio_frequency
	var/frequency
	/// List of filters -> list of devices
	var/list/list/datum/weakref/devices = list()

/datum/radio_frequency/New(freq)
	frequency = freq

//If range is null, or 0, signal is TRULY global (skips z_level checks) (Be careful with this.)
//If range > 0, only post to devices on the same z_level and within range
//Use range = -1, to restrain to the same z_level without limiting range
/datum/radio_frequency/proc/post_signal(datum/signal/signal, filter = null as text|null, range = null as num|null)
	if(!istype(signal))
		CRASH("LEGACY POST SIGNAL SHIT")

	//Ensure the signal's data is fully filled
	signal.frequency = frequency

	//Apply filter to the signal. If none supply, broadcast to every devices
	//_default channel is always checked
	if(filter)
		signal.filter_list = list(filter,"_default")
	else
		signal.filter_list = devices

	// Store routing data for SSPackets to handle.
	signal.frequency_datum = src
	signal.range = range

	SSpackets.queued_radio_packets += signal

/datum/radio_frequency/proc/add_listener(obj/device, filter as text|null)
	if (!filter)
		filter = "_default"

	var/list/devices_line = devices[filter]
	if(!devices_line)
		devices[filter] = devices_line = list()
	devices_line += WEAKREF(device)
	SSpackets.make_radio_sensitive(device, frequency)


/datum/radio_frequency/proc/remove_listener(obj/device)
	for(var/devices_filter in devices)
		var/list/devices_line = devices[devices_filter]
		if(!devices_line)
			devices -= devices_filter
		devices_line -= WEAKREF(device)
		if(!devices_line.len)
			devices -= devices_filter
	SSpackets.remove_radio_sensitive(device, frequency)

/datum/proc/receive_signal(datum/signal/signal)
	//SHOULD_CALL_PARENT(TRUE)
	. = TRUE

/datum/signal
	///The author/sender of this packet.
	var/datum/weakref/author
	///The medium of which this packet is travelling
	var/transmission_method
	///The player-accessible data of the packet
	var/list/data

	///A ref to the radio frequency datum, used by... radios.
	var/datum/radio_frequency/frequency_datum
	///Radio frequency
	var/frequency = 0
	///Radio range
	var/range = null
	///Radio filter list
	var/list/filter_list

	///Admin logging
	var/logging_data

	///Does this packet contain anything but standard data?
	///Anything that captures packets should either generate garbage data or discard these packets.
	var/has_magic_data = FALSE

/datum/signal/New(author, data, transmission_method = TRANSMISSION_RADIO, logging_data = null)
	src.author = isnull(author) ? null : WEAKREF(author)
	if(islist(author))
		stack_trace("Something is using the old signal/New() argument order!")
		src.data = author
	src.data = data || list()
	src.transmission_method = transmission_method
	src.logging_data = logging_data

/// Create a duplicate of the signal that's safe for store-and-forward situations.
/// No assurance is made that the *data* can survive this, of course.
/datum/signal/proc/Copy()
	var/datum/signal/duplicate = new(null, data.Copy(), transmission_method, logging_data)
	// Now for the vars new doesn't do for us.
	duplicate.author = author
	duplicate.frequency_datum = frequency_datum
	duplicate.frequency = frequency
	duplicate.range = range
	duplicate.filter_list = filter_list
	duplicate.has_magic_data = has_magic_data
