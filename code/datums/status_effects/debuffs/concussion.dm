/datum/status_effect/grouped/concussion
	id = "concussion"
	duration = -1
	tick_interval = -1
	status_type = STATUS_EFFECT_UNIQUE
	alert_type = null

/datum/status_effect/grouped/concussion/on_apply()
	. = ..()
	if(!.)
		return

	RegisterSignal(owner, COMSIG_MOB_HUD_CREATED, PROC_REF(apply_blur))
	RegisterSignal(owner, COMSIG_MOB_MOTION_SICKNESS_UPDATE, PROC_REF(pref_update))

	if(owner.hud_used)
		apply_blur()

/datum/status_effect/grouped/concussion/on_remove()
	. = ..()
	UnregisterSignal(owner, list(COMSIG_MOB_HUD_CREATED, COMSIG_MOB_MOTION_SICKNESS_UPDATE))
	remove_blur()

/datum/status_effect/grouped/concussion/proc/apply_blur(datum/source)
	SIGNAL_HANDLER

	if(owner.client?.prefs?.read_preference(/datum/preference/toggle/motion_sickness))
		return

	var/atom/movable/screen/plane_master/PM = owner.hud_used.plane_masters["[RENDER_PLANE_GAME]"]
	PM.add_filter("concussion_angular_blur", 3, angular_blur_filter(0, 0, 0.7))
	PM.add_filter("concussion_radial_blur", 4, radial_blur_filter(0, 0, 0))

	animate(PM.get_filter("concussion_angular_blur"), size = 1.8, time = 2 SECONDS, SINE_EASING|EASE_IN, loop = -1, flags = ANIMATION_PARALLEL)
	animate(size = 0.7, time = 2 SECONDS, SINE_EASING|EASE_OUT)
	animate(size = 0.7, time = 18.3 SECONDS) // I just want to offset it from life ticks, so it feels more random.

	animate(PM.get_filter("concussion_radial_blur"), size = 0.18, time = 2 SECONDS, easing = SINE_EASING|EASE_IN, loop = -1, flags = ANIMATION_PARALLEL)
	animate(size = 0, time = 2 SECONDS, SINE_EASING|EASE_OUT)
	animate(size = 0, time = 18.3 SECONDS) // I just want to offset it from life ticks, so it feels more random.

/datum/status_effect/grouped/concussion/proc/remove_blur()
	if(!owner.hud_used)
		return

	var/atom/movable/screen/plane_master/PM = owner.hud_used.plane_masters["[RENDER_PLANE_GAME]"]
	PM.remove_filter("concussion_radial_blur")
	PM.remove_filter("concussion_angular_blur")

/datum/status_effect/grouped/concussion/proc/pref_update(datum/source, new_value)
	SIGNAL_HANDLER

	if(new_value)
		remove_blur()
	else
		apply_blur()
