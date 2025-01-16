/obj/machinery/light
	var/maploaded = FALSE //So we don't have a lot of stress on startup.
	var/turning_on = FALSE //More stress stuff.
	var/constant_flickering = FALSE // Are we always flickering?
	var/flicker_timer = null
	var/roundstart_flicker = FALSE
	var/firealarm = FALSE

/obj/machinery/light/proc/turn_on(trigger, play_sound = TRUE)
	if(QDELETED(src))
		return
	turning_on = FALSE
	if(!on)
		return
	var/OR = bulb_outer_range
	var/IR = bulb_inner_range
	var/PO = bulb_power
	var/CO = bulb_colour
	var/FC = bulb_falloff
	if(color)
		CO = color
	if (firealarm)
		CO = bulb_emergency_colour
	else if (nightshift_enabled)
		OR = nightshift_outer_range
		IR = nightshift_inner_range
		PO = nightshift_light_power
		if(!color)
			CO = nightshift_light_color
		FC = nightshift_falloff

	var/matching = light && OR == light.light_outer_range && IR == light.light_inner_range && PO == light.light_power && CO == light.light_color && FC == light.light_falloff_curve
	if(!matching)
		switchcount++
		if(rigged)
			if(status == LIGHT_OK && trigger)
				explode()
		else if( prob( min(60, (switchcount**2)*0.01) ) )
			if(trigger)
				burn_out()
		else
			if(use_power != NO_POWER_USE)
				use_power = ACTIVE_POWER_USE
			set_light(l_outer_range = OR, l_inner_range = IR, l_power = PO, l_falloff_curve = FC, l_color = CO)
			if(play_sound)
				playsound(src.loc, 'modular_pariah/modules/aesthetics/lights/sound/light_on.ogg', 65, 1)

/obj/machinery/light/proc/start_flickering()
	if(constant_flickering)
		return

	on = FALSE
	update(FALSE, TRUE, FALSE)

	constant_flickering = TRUE

	flicker_timer = addtimer(CALLBACK(src, PROC_REF(flicker_on)), rand(5, 10))

/obj/machinery/light/proc/stop_flickering()
	if(!constant_flickering)
		return

	constant_flickering = FALSE

	if(flicker_timer)
		deltimer(flicker_timer)
		flicker_timer = null

	set_on(has_power())

/obj/machinery/light/proc/alter_flicker(enable = TRUE)
	if(!constant_flickering)
		return
	if(has_power())
		on = enable
		update(FALSE, TRUE, FALSE)

/obj/machinery/light/proc/flicker_on()
	alter_flicker(TRUE)
	flicker_timer = addtimer(CALLBACK(src, PROC_REF(flicker_off)), rand(5, 10), TIMER_STOPPABLE|TIMER_DELETE_ME)

/obj/machinery/light/proc/flicker_off()
	alter_flicker(FALSE)
	flicker_timer = addtimer(CALLBACK(src, PROC_REF(flicker_on)), rand(5, 50), TIMER_STOPPABLE|TIMER_DELETE_ME)

/obj/machinery/light/proc/firealarm_on()
	SIGNAL_HANDLER

	firealarm = TRUE
	update()

/obj/machinery/light/proc/firealarm_off()
	SIGNAL_HANDLER

	firealarm = FALSE
	update()

/obj/machinery/light/Initialize(mapload)
	. = ..()
	if(on)
		maploaded = TRUE

	if(roundstart_flicker)
		start_flickering()

/obj/item/light/tube
	icon = 'modular_pariah/modules/aesthetics/lights/icons/lighting.dmi'

