/obj/item/mcobject
	name = "mechcomp object"
	icon = 'goon/icons/obj/mechcomp.dmi'

	///Our interface for communicating with other mcobjects
	var/datum/mcinterface/interface
	///Configuration options
	var/list/configs
	///Inputs, basically pre-set acts. use MC_ADD_INPUT() to add.
	var/list/inputs

/obj/item/mcobject/Initialize(mapload)
	. = ..()
	interface = new(src)
	configs = list()
	inputs = list()
	update_icon_state()

	MC_ADD_CONFIG(MC_CFG_UNLINK_ALL, unlink_all)
	MC_ADD_CONFIG(MC_CFG_LINK, add_linker)

/obj/item/mcobject/Destroy(force)
	qdel(interface)
	return ..()

/obj/item/mcobject/update_icon_state()
	. = ..()
	icon_state = anchored ? "u[base_icon_state]" : base_icon_state

/obj/item/mcobject/wrench_act(mob/living/user, obj/item/tool)
	if(default_unfasten_wrench(user, tool))
		on_wrench()

///Called on a successful wrench or unwrench
/obj/item/mcobject/proc/on_wrench()
	SHOULD_CALL_PARENT(TRUE)
	update_icon_state()
	if(!anchored)
		interface.ClearConnections()
	else
		pixel_x = base_pixel_x
		pixel_y = base_pixel_y

/obj/item/mcobject/multitool_act(mob/living/user, obj/item/tool)
	var/datum/component/mclinker/link = tool.GetComponent(/datum/component/mclinker)
	if(link)
		if(!create_link(user, link.target))
			return
		qdel(link)
		user.animate_interact(src, INTERACT_GENERIC)
		return

	var/action = input("Select a config to modify", "Configure Component", null) as null|anything in configs
	if(!action)
		return

	if(call(src, configs[action])(user, tool))
		user.animate_interact(src, INTERACT_GENERIC)

///A multitool interaction is happening. Let's act on it.
/obj/item/mcobject/proc/unlink_all(mob/user, obj/item/tool)
	interface.ClearConnections()
	to_chat(user, span_notice("You remove all connections from [src]."))
	return TRUE

/obj/item/mcobject/proc/add_linker(mob/user, obj/item/tool)
	if(!tool)
		CRASH("Something tried to create a multitool linker without a multitool.")
	if(!anchored)
		to_chat(user, span_warning("You cannot link an unsecured device!"))
		return
	tool.AddComponent(/datum/component/mclinker, src)
	to_chat(user, span_notice("You prepare to link [src] with another device."))
	return TRUE

/obj/item/mcobject/proc/create_link(mob/user, obj/item/mcobject/target)
	SHOULD_CALL_PARENT(TRUE)

	if(!anchored)
		to_chat(user, span_warning("You cannot link an unsecured device!"))
		return

	if(src == target)
		to_chat(user, span_warning("You cannot link a device to itself!"))
		return

	if(get_dist(src, target) > MC_LINK_RANGE)
		to_chat(user, span_warning("Those devices are too far apart to be linked!"))
		return
	if(interface.inputs[target.interface])
		to_chat(user, span_warning("You cannot have multiple inputs taken by the same device!"))
		return

	var/list/options = inputs.Copy()

	for(var/thing in interface.inputs)
		options -= interface.inputs[thing]

	if(!length(options))
		to_chat(user, span_warning("[src] has no more inputs available!"))
		return

	var/choice = input(user, "Link Input", "Configure Component") as null|anything in options
	if(!choice)
		return

	to_chat(user, span_notice("You link [target] to [src]."))
	interface.AddInput(target.interface, choice)
	target.linked_to(src, user)
	return TRUE

///Called by create_link.
/obj/item/mcobject/proc/linked_to(obj/item/mcobject/output, mob/user)
	return

