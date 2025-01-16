//I promise that this isn't just 100% stolen from goon. Honest~ -Francinum

/obj/machinery/power/data_terminal
	name = "data terminal"
	icon_state = "dterm"
	network_flags = NETWORK_FLAG_POWERNET_DATANODE
	layer = LOW_OBJ_LAYER
	var/obj/machinery/connected_machine // Whatever machine that got built over us, We proxy it's packets back and forth.

/obj/machinery/power/data_terminal/Initialize(mapload)
	. = ..()
	connect_to_network()
	AddElement(/datum/element/undertile, TRAIT_T_RAY_VISIBLE)

/obj/machinery/power/data_terminal/Destroy()
	// Disconnect from the seizing machine.
	disconnect_machine(connected_machine)
	return ..()

/obj/machinery/power/data_terminal/should_have_node()
	return TRUE

/obj/machinery/power/data_terminal/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return
	/// Oop, we have a connected machine, make sure they're sure.
	if(connected_machine && !(tgui_alert(user, "The link light is on, deconstructing this will disconnect the device.", "Disconnect?",list("Disconnect","Abort")) == "Disconnect"))
		return TOOL_ACT_TOOLTYPE_SUCCESS

	user.visible_message(
		"[user] starts unscrewing [src] from \the [src.loc].",
		"You start unscrewing [src] from \the [src.loc]",
		"You hear quiet metal scraping.")
	tool.play_tool_sound(src, 50)
	if(!do_after(user, src, 10 SECONDS, DO_PUBLIC))
		to_chat(user, span_warning("You need to stand still to unscrew [src]!"))
		return TOOL_ACT_TOOLTYPE_SUCCESS

	playsound(src.loc, 'sound/machines/click.ogg', 75, TRUE)
	user.visible_message("[user] unscrewed \the [src] from \the [src.loc]", "You unscrewed \the [src] from \the [src.loc]")
	new /obj/item/data_terminal_construct(src.loc)
	qdel(src)
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/machinery/power/data_terminal/receive_signal(datum/signal/signal)
	SHOULD_CALL_PARENT(FALSE) //We *ARE* the signal poster.
	if(!powernet) //Did we somehow receive a signal without a powernet?
		return //*shrug*
	if(signal.transmission_method != TRANSMISSION_WIRE)
		CRASH("Data terminal received a non-wire data packet")
	if(connected_machine)
		connected_machine.receive_signal(signal)

/obj/machinery/power/data_terminal/post_signal(datum/signal/signal)
	SHOULD_CALL_PARENT(FALSE) //We *ARE* the signal poster.
	if(!powernet || !signal)
		return //What do you expect me to transmit on, the fucking air?
	if(signal.author.resolve() != connected_machine)
		CRASH("Data terminal was told to pass a signal from something other than it's master machine?")
	signal.transmission_method = TRANSMISSION_WIRE
	//Fuck you, we're the author now bitch.
	signal.author = WEAKREF(src)
	powernet.queue_signal(signal)

/// Request to connect this data terminal to a machine
/// see `_DEFINES/packetnet.dm` for return values
/// Machines connected to terminals should never move.
/obj/machinery/power/data_terminal/proc/connect_machine(obj/machinery/new_machine)
	if(connected_machine) //Ideally shouldn't happen, but just in case.
		return NETJACK_CONNECT_CONFLICT
	if(get_turf(src) != get_turf(new_machine)) //REALLY shouldn't happen.
		return NETJACK_CONNECT_NOTSAMETURF
	// Be ready to tear ourselves out if they move.
	RegisterSignal(new_machine, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/machinery/power/data_terminal, tear_out))
	//Actually link them.
	connected_machine = new_machine
	new_machine.netjack = src
	return NETJACK_CONNECT_SUCCESS

/// Attempt to disconnect from a data terminal.
/obj/machinery/power/data_terminal/proc/disconnect_machine(obj/machinery/leaving_machine)
	if(!leaving_machine || !connected_machine) // One of these is null, beating you with a hammer.
		return
	if(leaving_machine != connected_machine)//Let's just be sure.
		CRASH("[leaving_machine] [REF(leaving_machine)] attempted to disconnect despite not owning the data terminal (owned by [connected_machine] [REF(connected_machine)])!")
	leaving_machine.netjack_disconnected(src)
	UnregisterSignal(leaving_machine, COMSIG_MOVABLE_MOVED)
	leaving_machine.netjack = null
	connected_machine = null

/// Our connected machine moved. Disconnect and complain at them!
/obj/machinery/power/data_terminal/proc/tear_out(datum/source)
	SIGNAL_HANDLER
	do_sparks(10, FALSE, src)
	visible_message(span_warning("As [connected_machine] moves, \the [src] violently sparks as it disconnects from the network!")) //Good job fuckface
	disconnect_machine(connected_machine)

/// Data terminal item

/obj/item/data_terminal_construct
	name = "disconnected data terminal"
	desc = "A data terminal, used for connecting to powerline networks."
	icon_state = "dterm_construct"
	icon = 'icons/obj/power.dmi'

/obj/item/data_terminal_construct/examine(mob/user)
	. = ..()
	. += span_notice("You can [span_bold("screw")] it to the floor to install it.")

/obj/item/data_terminal_construct/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return

	if(HAS_TRAIT(src, TRAIT_NODROP) && loc == user)
		to_chat(user, span_warning("\The [src] is stuck to your hand!"))
		return TOOL_ACT_TOOLTYPE_SUCCESS

	var/turf/T = get_turf(src)
	if(T.underfloor_accessibility < UNDERFLOOR_INTERACTABLE && isfloorturf(T))
		to_chat(user, span_warning("You can only install the [src] if the floor plating is removed!"))
		return TOOL_ACT_TOOLTYPE_SUCCESS

	user.visible_message(
		"[user] starts screwing [src] into \the [T].",
		"You start screwing [src] into \the [T]",
		"You hear quiet metal scraping.")
	tool.play_tool_sound(src, 50)
	if(!do_after(user, src, 5 SECONDS, DO_PUBLIC))
		to_chat(user, span_warning("You need to stand still to install [src]!"))
		return TOOL_ACT_TOOLTYPE_SUCCESS

	playsound(src.loc, 'sound/machines/click.ogg', 75, TRUE)
	user.visible_message("[user] installed \the [src] on \the [T]", "You installed \the [src] on \the [T]")
	new /obj/machinery/power/data_terminal(T)
	qdel(src)
	return TOOL_ACT_TOOLTYPE_SUCCESS
