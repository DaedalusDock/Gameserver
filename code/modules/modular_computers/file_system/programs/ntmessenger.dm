// PDA Message Nonsense: https://hackmd.io/OajA9tVpS-K7xA68t6gv8Q

/datum/computer_file/program/messenger
	filename = "nt_messenger"
	filedesc = "Messenger"
	category = PROGRAM_CATEGORY_MISC
	program_icon_state = "command"
	program_state = PROGRAM_STATE_BACKGROUND
	extended_desc = "This program allows old-school communication with other modular devices."
	size = 8
	usage_flags = PROGRAM_TABLET
	ui_header = "ntnrc_idle.gif"
	available_on_ntnet = TRUE
	tgui_id = "NtosMessenger"
	program_icon = "comment-alt"
	alert_able = TRUE

	/// The current ringtone (displayed in the chat when a message is received).
	var/ringtone = "beep"
	/// Whether or not the ringtone is currently on.
	var/ringer_status = TRUE
	/// The messages currently saved in the app.
	var/messages = list()
	/// great wisdom from PDA.dm - "no spamming" (prevents people from spamming the same message over and over)
	var/last_text
	/// even more wisdom from PDA.dm - "no everyone spamming" (prevents people from spamming the same message over and over)
	var/last_text_everyone
	/// Whether or not we're currently looking at the message list.
	var/viewing_messages = FALSE
	// Whether or not we're sorting by job.
	var/sort_by_job = TRUE
	// Whether or not we're sending (or trying to send) a virus.
	var/sending_virus = FALSE


	/// Whether or not this app is loaded on a silicon's tablet.
	var/is_silicon = FALSE
	/// Whether or not we're in a mime PDA.
	var/mime_mode = FALSE

	/// Cache of the network card, so we don't need to drag it out of the list every time.
	var/obj/item/computer_hardware/network_card/packetnet/netcard_cache
	/// Learned PDA info tuples
	///
	///list(d_addr1 = list(d_addr1, name, job), d_addr2=list(d_addr2, name, job),...)
	var/list/known_cells = list()


/datum/computer_file/program/messenger/ui_state(mob/user)
	if(istype(user, /mob/living/silicon))
		return GLOB.reverse_contained_state
	return GLOB.default_state

/datum/computer_file/program/messenger/can_run(mob/user, loud, access_to_check, transfer, list/access)
	. = ..()
	if(!. || transfer) //Already declined for other reason.
	//Or We're checking just download access here, not runtime compatibility
		return .
	var/obj/item/computer_hardware/network_card/packetnet/pnetcard = computer.all_components[MC_NET]
	if(!istype(pnetcard))
		if(loud)
			to_chat(user, span_danger("\The [computer] flashes a \"GPRS Error - Incompatible Network card\" warning."))
		return FALSE

/datum/computer_file/program/messenger/event_hardware_changed(background)
	. = ..()
	if(netcard_cache != computer.all_components[MC_NET])
		if(background)
			computer.visible_message(span_danger("\The [computer]'s screen displays a \"Process [filename].[filetype] (PID [rand(100,999)]) terminated - GPRS hardware error\" error"))
		else
			computer.visible_message(span_danger("\The [computer]'s screen briefly freezes and then shows \"NETWORK ERROR - GPRS hardware error. Verify hardware presence or contact a certified technician.\" error."))
		kill_program(TRUE)

/datum/computer_file/program/messenger/run_program(mob/living/user)
	. = ..()
	if(!.)
		return
	//If we got here, it's safe to assume this, probably.
	netcard_cache = computer.all_components[MC_NET]

/datum/computer_file/program/messenger/process_tick(delta_time)
	. = ..()
	while(netcard_cache.check_queue())
		process_signal(netcard_cache.pop_signal())

/datum/computer_file/program/messenger/kill_program(forced)
	. = ..()
	netcard_cache = null

/datum/computer_file/program/messenger/proc/process_signal(datum/signal/signal)
	if(!signal)
		CRASH("Messenger program attempted to process null signal??")
	var/list/signal_data = signal.data
	if(!signal_data)
		return
	var/signal_command = signal_data[PACKET_CMD]
	//Network ID verification is "hardware accelerated" (AKA: Done for us by the card)

	var/rigged = FALSE//are we going to explode?

	//Due to BYOND's lack of dynamic switch statements, we get to run this massive ifchain..

	// "Exploiting a bug" my ass this shit is going to suck to write.
	// ESPECIALLY THIS FUCKER RIGHT HERE vvvv
	if(signal_data[SSpackets.pda_exploitable_register] == SSpackets.detomatix_magic_packet)
		//This one falls through to standard PDA behaviour, so we need to be checked first.
		if(signal_data[PACKET_DESTINATION_ADDRESS] == netcard_cache.hardware_id)//No broadcast bombings, fuck off.
			//Calculate our "difficulty"
			var/difficulty
			var/obj/item/computer_hardware/hard_drive/role/our_jobdisk = computer.all_components[MC_HDD_JOB]
			if(our_jobdisk)
				difficulty += bit_count(our_jobdisk & (DISK_MED | DISK_SEC | DISK_POWER | DISK_MANIFEST))
				if(our_jobdisk.disk_flags & DISK_MANIFEST)
					difficulty++ //if cartridge has manifest access it has extra snowflake difficulty
			if(!((SEND_SIGNAL(computer, COMSIG_TABLET_CHECK_DETONATE) & COMPONENT_TABLET_NO_DETONATE) || prob(difficulty * 15)))
				rigged = TRUE //Cool, we're allowed to blow up. Really glad this whole check wasn't for nothing.
				var/trait_timer_key = signal_data[PACKET_SOURCE_ADDRESS]
				ADD_TRAIT(computer, TRAIT_PDA_CAN_EXPLODE, trait_timer_key)
				ADD_TRAIT(computer, TRAIT_PDA_MESSAGE_MENU_RIGGED, trait_timer_key)
				addtimer(TRAIT_CALLBACK_REMOVE(computer, TRAIT_PDA_MESSAGE_MENU_RIGGED, trait_timer_key), 10 SECONDS)
			//Intentional fallthrough.

	if(signal_command == NETCMD_PDAMESSAGE)
		log_message(
			signal_data["name"] || "#UNK",
			signal_data["job"] || "#UNK",
			html_decode("\"[signal_data["message"]]\"") || "#ERROR_MISSING_FIELD",
			FALSE,
			signal_data["automated"] || FALSE,
			signal_data[PACKET_SOURCE_ADDRESS] || null
			)

		if(ringer_status)
			computer.ring(ringtone)

		if(computer.hardware_flag == PROGRAM_TABLET) //We need to render the extraneous bullshit to chat.
			show_in_chat(signal_data, rigged)
		return

	if(signal_data[SSpackets.pda_exploitable_register] == SSpackets.clownvirus_magic_packet)
		computer.honkamnt = rand(15, 25)
		return

	if(signal_data[SSpackets.pda_exploitable_register] == SSpackets.mimevirus_magic_packet)
		ringer_status = FALSE
		ringtone = ""
		return

	if(signal_data[SSpackets.pda_exploitable_register] == SSpackets.framevirus_magic_packet)
		if(computer.hardware_flag != PROGRAM_TABLET)
			return //If it's not a PDA, too bad!
		if(!(signal.has_magic_data & MAGIC_DATA_MUST_OBFUSCATE))
			return //Must be obfuscated, due to the ability to create uplinkss.

		var/datum/component/uplink/hidden_uplink = computer.GetComponent(/datum/component/uplink)
		if(!hidden_uplink)
			var/datum/mind/target_mind
			var/list/backup_players = list()
			for(var/datum/mind/player as anything in get_crewmember_minds())
				if(player.assigned_role?.title == computer.saved_job)
					backup_players += player
				if(player.name == computer.saved_identification)
					target_mind = player
					break
			if(!target_mind)
				if(!length(backup_players))
					target_mind = signal_data["fallback_mind"] //yea...
				else
					target_mind = pick(backup_players)
			hidden_uplink = computer.AddComponent(/datum/component/uplink, target_mind, enabled = TRUE, starting_tc = signal_data["telecrystals"], has_progression = TRUE)
			hidden_uplink.uplink_handler.has_objectives = TRUE
			hidden_uplink.uplink_handler.owner = target_mind
			hidden_uplink.uplink_handler.can_take_objectives = FALSE
			hidden_uplink.uplink_handler.progression_points = min(SStraitor.current_global_progression, signal_data["current_progression"])
			hidden_uplink.uplink_handler.generate_objectives()
			SStraitor.register_uplink_handler(hidden_uplink.uplink_handler)
		else
			hidden_uplink.add_telecrystals(signal_data["telecrystals"])
		//Unlock it regardless of if we created it or not.
		hidden_uplink.locked = FALSE
		hidden_uplink.active = TRUE

/datum/computer_file/program/messenger/proc/show_in_chat(list/signal_data, rigged)
	var/mob/living/L = null
	if(holder.holder.loc && isliving(holder.holder.loc))
		L = holder.holder.loc
	//Maybe they are a pAI!
	else
		L = get(holder.holder, /mob/living/silicon)

	if(L && L.stat == CONSCIOUS)
		var/reply = "(<a href='byond://?src=[REF(src)];choice=[rigged ? "Mess_us_up" : "Message"];skiprefresh=1;target=[signal_data[PACKET_SOURCE_ADDRESS]]'>Reply</a>)"
		var/hrefstart
		var/hrefend
		var/job_string = signal_data["job"] ? " ([signal_data["job"]])" : ""
		if (isAI(L))
			hrefstart = "<a href='?src=[REF(L)];track=[html_encode(signal_data["name"])]'>"
			hrefend = "</a>"

		if(signal_data[PACKET_SOURCE_ADDRESS] == null)
			reply = "\[#ERRNOADDR\]"

		if(signal_data["automated"])
			reply = "\[Automated Message\]"


		var/inbound_message = "\"[signal_data["message"]]\""
		inbound_message = emoji_parse(inbound_message)

		if(ringer_status)
			to_chat(L, "<span class='infoplain'>[icon2html(src, L)] <b>PDA message from [hrefstart][signal_data["name"]][job_string][hrefend], </b>[inbound_message] [reply]</span>")

/datum/computer_file/program/messenger/Topic(href, href_list)
	..()

	if(!href_list["close"] && usr.canUseTopic(computer, USE_CLOSE|USE_IGNORE_TK))
		switch(href_list["choice"])
			if("Message")
				send_message(usr, href_list["target"])
			if("Mess_us_up")
				if(!HAS_TRAIT(src, TRAIT_PDA_CAN_EXPLODE))
					var/obj/item/modular_computer/tablet/comp = computer
					comp.explode(usr, from_message_menu = TRUE)
					return

/datum/computer_file/program/messenger/proc/msg_input(mob/living/U = usr)
	var/text_message = null

	if(mime_mode)
		text_message = emoji_sanitize(tgui_input_text(U, "Enter emojis", "NT Messaging"))
	else
		text_message = tgui_input_text(U, "Enter a message", "NT Messaging")

	if (!text_message || !netcard_cache.radio_state)
		return
	if(!U.canUseTopic(computer, USE_CLOSE))
		return
	return sanitize(text_message)

/datum/computer_file/program/messenger/proc/send_message(mob/living/user, target_address, everyone = FALSE, staple = null, fake_name = null, fake_job = null)
	var/message = msg_input(user)
	if(!message)
		return
	if(!netcard_cache.radio_state)
		to_chat(usr, span_notice("ERROR: GPRS Modem Disabled."))
		return
	if((last_text && world.time < last_text + 10) || (everyone && last_text_everyone && world.time < last_text_everyone + 2 MINUTES))
		return FALSE

	var/turf/position = get_turf(computer)
	for(var/obj/item/jammer/jammer as anything in GLOB.active_jammers)
		var/turf/jammer_turf = get_turf(jammer)
		if(position?.z == jammer_turf.z && (get_dist(position, jammer_turf) <= jammer.range))
			return FALSE

	var/list/filter_result = CAN_BYPASS_FILTER(user) ? null : is_ic_filtered_for_pdas(message)
	if (filter_result)
		REPORT_CHAT_FILTER_TO_USER(user, filter_result)
		return FALSE

	var/list/soft_filter_result = CAN_BYPASS_FILTER(user) ? null : is_soft_ic_filtered_for_pdas(message)
	if (soft_filter_result)
		if(tgui_alert(usr,"Your message contains \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\". \"[soft_filter_result[CHAT_FILTER_INDEX_REASON]]\", Are you sure you want to send it?", "Soft Blocked Word", list("Yes", "No")) != "Yes")
			return FALSE
		message_admins("[ADMIN_LOOKUPFLW(usr)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term in PDA messages. Message: \"[html_encode(message)]\"")
		log_admin_private("[key_name(usr)] has passed the soft filter for \"[soft_filter_result[CHAT_FILTER_INDEX_WORD]]\" they may be using a disallowed term in PDA messages. Message: \"[message]\"")

	// Send the signal
	var/datum/signal/pda_message = new(
		src,
		list(
			PACKET_CMD = NETCMD_PDAMESSAGE,
			"name" = fake_name || computer.saved_identification,
			"job" = fake_job || computer.saved_job,
			"message" = html_decode(message),
			PACKET_DESTINATION_ADDRESS = target_address
		),
		logging_data = user
	)
	netcard_cache.post_signal(pda_message)
	// Log it in our logs
	log_message(fake_name || computer.saved_identification,fake_job || computer.saved_job,html_decode(message),TRUE,FALSE,target_address)

/datum/computer_file/program/messenger/proc/log_message(name, job, message, outgoing, automated, reply_addr)
	var/list/message_data = list(
		"name" = name,
		"job" = job,
		"contents" = message,
		"outgoing" = outgoing,
		//If there's no reply address, pretend it's automated so we don't give them a null link
		"automated" = !reply_addr || automated,
		"target_addr" = reply_addr,
	)

	messages += list(message_data) //Needs to be wrapped for engine reasons.

/datum/computer_file/program/messenger/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	switch(action)
		if("PDA_ringSet")
			var/t = tgui_input_text(usr, "Enter a new ringtone", "Ringtone", "", 20)
			var/mob/living/usr_mob = usr
			//This is uplink shit. If it's not a tablet, we only care about the basic range check.
			if(in_range(computer, usr_mob) && (computer.hardware_flag == PROGRAM_TABLET && computer.loc == usr_mob) && t)
				if(SEND_SIGNAL(computer, COMSIG_TABLET_CHANGE_ID, usr_mob, t) & COMPONENT_STOP_RINGTONE_CHANGE)
					return
				else
					ringtone = t
					return(UI_UPDATE)
		if("PDA_ringer_status")
			ringer_status = !ringer_status
			return(UI_UPDATE)
		if("PDA_sAndR")
			netcard_cache.set_radio_state(!netcard_cache.radio_state)
			return(UI_UPDATE)
		if("PDA_viewMessages")
			viewing_messages = !viewing_messages
			return(UI_UPDATE)
		if("PDA_clearMessages")
			messages = list()
			return(UI_UPDATE)
		if("PDA_changeSortStyle")
			sort_by_job = !sort_by_job
			return(UI_UPDATE)
		if("PDA_sendEveryone")
			if(!netcard_cache.radio_state)
				to_chat(usr, span_notice("ERROR: GPRS Modem Disabled."))
				return
			//So much easier with GPRS.
			send_message(usr, null, TRUE)

			return(UI_UPDATE)
		if("PDA_sendMessage")
			if(!netcard_cache.radio_state)
				to_chat(usr, span_notice("ERROR: GPRS Modem Disabled."))
				return
			var/target_addr = params["target_addr"]
			if(sending_virus)
				var/obj/item/computer_hardware/hard_drive/role/virus/disk = computer.all_components[MC_HDD_JOB]
				if(istype(disk))
					disk.send_virus(target_addr, usr)
					return(UI_UPDATE)
			send_message(usr, target_addr)
			return(UI_UPDATE)
		if("PDA_toggleVirus")
			sending_virus = !sending_virus
			return(UI_UPDATE)
		if("PDA_scanForPDAs")
			var/obj/item/computer_hardware/network_card/packetnet/pnetcard = computer.all_components[MC_NET]
			pnetcard.known_pdas = list() //Flush.
			if(!istype(pnetcard)) //This catches nulls too, so...
				to_chat(usr, span_warning("Radio missing or bad driver!"))
			var/datum/signal/ping_sig = new(src, list(
				PACKET_DESTINATION_ADDRESS = NET_ADDRESS_PING,
				"pda_scan" = "true"
			))
			pnetcard.post_signal(ping_sig)
			// The UI update loop from the computer will handle the scan refresh.
			return(UI_UPDATE)

/datum/computer_file/program/messenger/ui_data(mob/user)
	var/list/data = get_header_data()

	var/obj/item/computer_hardware/hard_drive/role/disk = computer.all_components[MC_HDD_JOB]

	data["owner"] = computer.saved_identification
	data["messages"] = messages
	data["ringer_status"] = ringer_status
	data["sending_and_receiving"] = netcard_cache.radio_state
	data["messengers"] = netcard_cache.known_pdas
	data["viewing_messages"] = viewing_messages
	data["sortByJob"] = sort_by_job
	data["isSilicon"] = is_silicon

	if(disk)
		data["canSpam"] = disk.CanSpam()
		data["virus_attach"] = istype(disk, /obj/item/computer_hardware/hard_drive/role/virus)
		data["sending_virus"] = sending_virus

	return data
