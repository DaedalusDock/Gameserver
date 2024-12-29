/obj/machinery/computer/pager
	name = "account lookup console"
	desc = "Used to view crewmember accounts and purchases."
	icon_screen = "request"
	icon_keyboard = "med_key"
	circuit = /obj/item/circuitboard/computer/accounting
	light_color = LIGHT_COLOR_GREEN

	var/pager_class = "common"

	var/text_content = ""

/obj/machinery/computer/pager/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "PagerConsole", name)
		ui.open()

/obj/machinery/computer/pager/ui_data(mob/user)
	var/list/data = list()
	data["content"] = text_content

	return data

/obj/machinery/computer/pager/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	switch(action)
		if("Post")
			var/message = "[stationtime2text("hh:mm")] | [params["message"]]"

			var/datum/signal/signal = new(src, list(PACKET_SOURCE_ADDRESS = net_id, PACKET_ARG_PAGER_CLASS = pager_class, PACKET_ARG_PAGER_MESSAGE = message))
			var/datum/radio_frequency/connection = SSpackets.return_frequency(FREQ_COMMON)
			connection.post_signal(signal, RADIO_PAGER_MESSAGE)
			text_content = ""
			return TRUE

		if("UpdateContent")
			text_content = copytext_char(params["message"], 1, 42)
			return TRUE

