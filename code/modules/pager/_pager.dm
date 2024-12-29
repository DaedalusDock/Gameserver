/obj/item/pager
	name = "pager"
	desc = "A bleeding edge small formfactor device used to receive messages from a long distance."
	icon = 'goon/icons/items/pda.dmi'
	icon_state = "pda"
	base_icon_state = "pda"

	w_class = WEIGHT_CLASS_NORMAL
	slot_flags = ITEM_SLOT_BELT

	var/static/list/flash_images

	/// Self explanatory
	var/receiving = FALSE
	var/blinking = FALSE
	/// Set to TRUE upon receiving a message, set to FALSE when opening the UI
	var/has_unread_messages = FALSE
	/// Filter for what kind of pager messages we get
	var/pager_class = "common"
	/// FIFO list of recent messages
	var/list/recent_messages

	/// The radio connection we listen to.
	var/datum/radio_frequency/radio_connection

/obj/item/pager/Initialize(mapload)
	. = ..()
	if(isnull(flash_images))
		flash_images = list()
		flash_images += image(icon, "blink")
		flash_images += emissive_appearance(icon, "blink")

	recent_messages = list()
	toggle_receiving()

/obj/item/pager/Destroy(force)
	SSpackets.remove_object(src, FREQ_COMMON)
	return ..()

/obj/item/pager/examine(mob/user)
	. = ..()
	. += span_notice("The receiver is switched [receiving ? "on" : "off"].")

/obj/item/pager/update_overlays()
	. = ..()
	if(has_unread_messages)
		. += image(icon, "pda-r")

/obj/item/pager/proc/toggle_receiving(mob/user)
	receiving = !receiving
	if(receiving)
		radio_connection = SSpackets.add_object(src, FREQ_COMMON, RADIO_PAGER_MESSAGE)
	else
		SSpackets.remove_object(src, FREQ_COMMON)

	if(user)
		playsound(src, 'sound/machines/pda_button2.ogg', 50, extrarange = SILENCED_SOUND_EXTRARANGE)
		user.visible_message(span_notice("[user] flips the receiver switch on [src]."), vision_distance = 2)

/obj/item/pager/receive_signal(datum/signal/signal)
	if(signal.data[PACKET_ARG_PAGER_CLASS] != pager_class)
		return

	var/message = signal.data[PACKET_ARG_PAGER_MESSAGE]
	recent_messages.Insert(1, message)
	if(length(recent_messages) > 5)
		recent_messages.len = 5

	playsound(src, 'sound/machines/twobeep.ogg', 10, extrarange = SILENCED_SOUND_EXTRARANGE)

	var/list/icon_recipients = hearers(2, get_turf(src))
	var/chat_image = icon2html(src, icon_recipients)

	audible_message(span_hear("[chat_image] beeps."), span_notice("[chat_image] The [name]'s screen lights up and begins to blink."), hearing_distance = 2)
	blink()

	if(!length(SStgui.get_open_uis(src)) && !has_unread_messages)
		has_unread_messages = TRUE
		update_appearance(UPDATE_OVERLAYS)

/obj/item/pager/proc/blink()
	addtimer(CALLBACK(src, PROC_REF(remove_blink)), 6.2 SECONDS, TIMER_DELETE_ME | TIMER_UNIQUE)
	if(blinking)
		return

	blinking = TRUE
	add_overlay(flash_images)

/obj/item/pager/proc/remove_blink()
	blinking = FALSE
	cut_overlay(flash_images)

/obj/item/pager/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if (!ui)
		ui = new(user, src, "Pager")
		ui.open()

	has_unread_messages = FALSE
	update_appearance(UPDATE_OVERLAYS)

/obj/item/pager/ui_data(mob/user)
	return list(
		"messages" = recent_messages,
		"the_time" = stationtime2text("hh:mm"),
		"receiving" = receiving,
	)

/obj/item/pager/ui_act(action, list/params)
	. = ..()
	if(.)
		return

	switch(action)
		if("ToggleReceiving")
			toggle_receiving(usr)
			return TRUE

/obj/item/pager/aether
	pager_class = PAGER_CLASS_AETHER
