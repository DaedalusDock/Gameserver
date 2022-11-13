/obj/machinery/power/generator
	name = "thermoelectric generator"
	desc = "It's a high efficiency thermoelectric generator."
	icon = 'icons/obj/atmospherics/components/teg.dmi'
	icon_state = "teg"
	density = TRUE
	use_power = NO_POWER_USE
	obj_flags = USES_TGUI
	interaction_flags_atom = INTERACT_ATOM_UI_INTERACT

	var/obj/machinery/atmospherics/components/binary/circulator/cold_circ
	var/obj/machinery/atmospherics/components/binary/circulator/hot_circ

	var/lastgen = 0
	var/lastgenlev = -1
	var/lastcirc = "00"

	var/datum/looping_sound/teg/soundloop

//for cargo crates
/obj/machinery/power/generator/unwrenched
	anchored = FALSE

/obj/machinery/power/generator/Initialize(mapload)
	. = ..()
	find_circs()
	connect_to_network()
	SSairmachines.start_processing_machine(src)
	update_appearance()
	soundloop = new(src, TRUE)
	soundloop.stop()

/obj/machinery/power/generator/Destroy()
	kill_circs()
	SSairmachines.stop_processing_machine(src)
	QDEL_NULL(soundloop)
	return ..()

/obj/machinery/power/generator/update_overlays()
	. = ..()
	if(machine_stat & (NOPOWER|BROKEN))
		return

	var/L = min(round(lastgenlev / 100000), 11)
	if(L != 0)
		. += mutable_appearance('icons/obj/power.dmi', "teg-op[L]")
	if(hot_circ && cold_circ)
		. += "teg-oc[lastcirc]"


#define GENRATE 800 // generator output coefficient from Q

/obj/machinery/power/generator/process_atmos()

	if(!cold_circ || !hot_circ)
		return

	if(powernet)
		var/datum/gas_mixture/cold_air = cold_circ.return_transfer_air()
		var/datum/gas_mixture/hot_air = hot_circ.return_transfer_air()

		if(cold_air && hot_air)

			var/cold_air_heat_capacity = cold_air.getHeatCapacity()
			var/hot_air_heat_capacity = hot_air.getHeatCapacity()

			var/delta_temperature = hot_air.temperature - cold_air.temperature


			if(delta_temperature > 0 && cold_air_heat_capacity > 0 && hot_air_heat_capacity > 0)
				var/efficiency = 0.65

				var/energy_transfer = delta_temperature*hot_air_heat_capacity*cold_air_heat_capacity/(hot_air_heat_capacity+cold_air_heat_capacity)

				var/heat = energy_transfer*(1-efficiency)
				lastgen += energy_transfer*efficiency

				hot_air.temperature = hot_air.temperature - energy_transfer/hot_air_heat_capacity
				cold_air.temperature = cold_air.temperature + heat/cold_air_heat_capacity

				soundloop.start()
			else
				soundloop.stop()

				//add_avail(lastgen) This is done in process now
		// update icon overlays only if displayed level has changed

		if(hot_air)
			var/datum/gas_mixture/hot_circ_air1 = hot_circ.airs[1]
			hot_circ_air1.merge(hot_air)

		if(cold_air)
			var/datum/gas_mixture/cold_circ_air1 = cold_circ.airs[1]
			cold_circ_air1.merge(cold_air)

		update_appearance()

	var/circ = "[cold_circ?.last_pressure_delta > 0 ? "1" : "0"][hot_circ?.last_pressure_delta > 0 ? "1" : "0"]"
	if(circ != lastcirc)
		lastcirc = circ
		update_appearance()

	src.updateDialog()

/obj/machinery/power/generator/process()
	//Setting this number higher just makes the change in power output slower, it doesnt actualy reduce power output cause **math**
	var/power_output = round(lastgen / 10)
	add_avail(power_output)
	lastgenlev = power_output
	lastgen -= power_output
	..()

//TGUI interaction
/obj/machinery/power/generator/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "Teg")
		ui.open()

/obj/machinery/power/generator/ui_data(mob/user)
	var/datum/gas_mixture/cold_circ_air1 = cold_circ.airs[1]
	var/datum/gas_mixture/cold_circ_air2 = cold_circ.airs[2]
	var/datum/gas_mixture/hot_circ_air1 = hot_circ.airs[1]
	var/datum/gas_mixture/hot_circ_air2 = hot_circ.airs[2]

	var/list/data = list()
	data["has_hot_circ"] = hot_circ
	data["has_cold_circ"] = cold_circ
	data["has_powernet"] = powernet
	data["power_output"] = display_power(lastgenlev)
	data["cold_temp_in"] = round(cold_circ_air2.temperature, 0.1)
	data["cold_pressure_in"] = round(cold_circ_air2.returnPressure(), 0.1)
	data["cold_temp_out"] = round(cold_circ_air1.temperature, 0.1)
	data["cold_pressure_out"] = round(cold_circ_air1.returnPressure(), 0.1)
	data["hot_temp_in"] = round(hot_circ_air2.temperature, 0.1)
	data["hot_pressure_in"] = round(hot_circ_air2.returnPressure(), 0.1)
	data["hot_temp_out"] = round(hot_circ_air1.temperature, 0.1)
	data["hot_pressure_out"] = round(hot_circ_air1.returnPressure(), 0.1)

	return data

/obj/machinery/power/generator/ui_act(action, params)
	. = ..()
	if(.)
		return
	if(action == "refresh_parts")
		link_parts(usr)

/obj/machinery/power/generator/proc/link_parts(mob/user)
	if(!anchored)
		to_chat(user, span_notice("Secure [src] first!"))
		playsound(src, 'sound/machines/buzz-sigh.ogg', 30, TRUE)
		return
	find_circs()
	if(!cold_circ || !hot_circ)
		to_chat(user, span_notice("Secure [src] first!"))
		playsound(src, 'sound/machines/buzz-sigh.ogg', 30, TRUE)
		return
	playsound(src, 'sound/machines/ping.ogg', 30, TRUE)

/obj/machinery/power/generator/proc/find_circs()
	kill_circs()
	var/list/circs = list()
	var/obj/machinery/atmospherics/components/binary/circulator/C
	var/circpath = /obj/machinery/atmospherics/components/binary/circulator
	if(dir == NORTH || dir == SOUTH)
		C = locate(circpath) in get_step(src, EAST)
		if(C && C.dir == WEST)
			circs += C

		C = locate(circpath) in get_step(src, WEST)
		if(C && C.dir == EAST)
			circs += C

	else
		C = locate(circpath) in get_step(src, NORTH)
		if(C && C.dir == SOUTH)
			circs += C

		C = locate(circpath) in get_step(src, SOUTH)
		if(C && C.dir == NORTH)
			circs += C

	if(circs.len)
		for(C in circs)
			if(C.mode == CIRCULATOR_COLD && !cold_circ)
				cold_circ = C
				C.generator = src
			else if(C.mode == CIRCULATOR_HOT && !hot_circ)
				hot_circ = C
				C.generator = src

/obj/machinery/power/generator/attack_hand(mob/user, list/modifiers)
	. = ..()
	ui_interact(user)

/obj/machinery/power/generator/wrench_act(mob/living/user, obj/item/I)
	. = ..()
	if(!panel_open)
		to_chat(user, span_notice("Open [src]'s panel first!"))
		return TRUE
	return default_change_direction_wrench(user, I)

/obj/machinery/power/generator/wrench_act_secondary(mob/living/user, obj/item/I)
	. = ..()
	if(!panel_open)
		to_chat(user, span_notice("Open [src]'s panel first!"))
		return TRUE
	set_anchored(!anchored)
	I.play_tool_sound(src)
	if(!anchored)
		kill_circs()
	connect_to_network()
	to_chat(user, span_notice("You [anchored?"secure":"unsecure"] [src]."))
	return TRUE

/obj/machinery/power/generator/screwdriver_act(mob/user, obj/item/I)
	if(..())
		return TRUE
	panel_open = !panel_open
	I.play_tool_sound(src)
	to_chat(user, span_notice("You [panel_open?"open":"close"] the panel on [src]."))
	return TRUE

/obj/machinery/power/generator/welder_act(mob/living/user, obj/item/I)
	if(atom_integrity >= max_integrity)
		to_chat(user, span_notice("The [src] does not need any repairs."))
		return TRUE
	if(!I.use_tool(src, user, 0, volume=50, amount=1))
		return TRUE
	user.visible_message(span_notice("[user] repairs some damage to [src]."), span_notice("You repair some damage to [src]."))
	atom_integrity += min(10, max_integrity-atom_integrity)
	if(atom_integrity == max_integrity)
		to_chat(user, span_notice("The [src] is fully repaired."))
	return TRUE

/obj/machinery/power/generator/proc/kill_circs()
	if(hot_circ)
		hot_circ.generator = null
		hot_circ = null
	if(cold_circ)
		cold_circ.generator = null
		cold_circ = null

/obj/machinery/power/generator/examine(mob/user)
	. = ..()
	. += span_notice("With the panel open:")
	. += span_notice(" -Use a wrench with left-click to rotate [src] and right-click to unanchor it.")
