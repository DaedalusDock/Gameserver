/obj/machinery/telephony/exchange
	name = "Telephone Exchange"
	icon_state = "blackbox_b"
	network_flags = NETWORK_FLAGS_STANDARD_CONNECTION
	net_class = NETCLASS_EXCHANGE

	// This is... A complicated datastructure
	// see extensions_info.txt in this folder for the layout.
	var/list/datum/tel_extension/extensions

	/// Defaults to 000, Used to select an exchange to register to in 'complex environments'
	var/office_number = "000"

/obj/machinery/telephony/exchange/Initialize(mapload)
	. = ..()
	// Request NetInit for autodiscovery.
	SSpackets.request_network_initialize(src)
	extensions = list()


/obj/machinery/telephony/exchange/NetworkInitialize()
	. = ..()
	// Load ping_additional with the office code, so pinging devices can find us.
	ping_addition = list("office_code" = office_number)
	// The network is ready, we can now use it to resolve networked phones.
	if(!netjack)
		return //Or we can just go fuck ourselves that works too.

	//Determine all phones on our network.
	for(var/obj/machinery/power/data_terminal/possible_jack as anything in netjack.powernet.data_nodes)
		var/obj/machinery/telephony/telephone/registrant = possible_jack.connected_machine
		if(!istype(registrant) || (registrant.init_office_code && (registrant.init_office_code != office_number)))
			continue //Not you.

		var/datum/tel_extension/ext_record = assert_extension(registrant.init_extension)

		registrant.autoconf_secret = ext_record.auth_secret
		//Program the office number so it knows who to care about.
		registrant.init_office_code = office_number
		if(!registrant.init_cnam)
			continue // Not setting or writing a CNAM.
		if(ext_record.cnam && (ext_record.cnam != registrant.init_cnam))
			stack_trace("Init phone CNAM conflict for extension [registrant.init_extension].")
			ext_record.cnam = registrant.init_cnam


/// Creates a new extension. Returns the generated tel_extension record.
/// If the extension already exists, Return the existing record.
/obj/machinery/telephony/exchange/proc/assert_extension(new_ext) as /datum/tel_extension
	RETURN_TYPE(/datum/tel_extension)
	// Secrets must be numeric so they can be entered via config mode.
	if(extensions[new_ext])
		return extensions[new_ext]
	var/datum/tel_extension/record = new()

	record.name = new_ext
	record.auth_secret = random_string(8, GLOB.numerals)

	extensions[new_ext] = record

	return record

/obj/machinery/telephony/exchange/receive_signal(datum/signal/signal)
	. = ..()
