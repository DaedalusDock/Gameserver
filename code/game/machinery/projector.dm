// This is currently just used for the sec intro and is written as such. Fix it if you want to use it. Or bug me about it.
/obj/machinery/projector
	name = "projector"
	icon = 'icons/obj/machines/projector.dmi'
	base_icon_state = "projector"
	icon_state = "projector0"

	dir = SOUTH
	light_on = FALSE
	light_color = LIGHT_COLOR_BABY_BLUE
	light_power = 0.4
	light_inner_range = 0.8
	light_outer_range = 3

	var/playing = FALSE

/obj/machinery/projector/Initialize(mapload)
	. = ..()
	if(!SSticker.HasRoundStarted())
		SSticker.OnRoundstart(CALLBACK(src, PROC_REF(play), 5 SECONDS))

/obj/machinery/projector/update_icon_state()
	icon_state = "[base_icon_state][playing]"
	return ..()

/obj/machinery/projector/proc/play(initial_delay = 3 SECONDS)
	set waitfor = FALSE

	say("Incoming transmission.")
	if(initial_delay)
		sleep(initial_delay)

	var/turf/destination = get_ranged_target_turf(src, SOUTH, 2)
	var/obj/effect/overlay/holoray/ray = new(loc)
	var/obj/effect/abstract/projected_image/guy = new(destination)


	guy.icon = icon
	guy.icon_state = "sec"

	guy.makeHologram()
	guy.add_overlay(emissive_appearance(guy.icon, guy.icon_state, alpha = 180))

	guy.alpha = 0
	ray.alpha = 0
	update_ray(ray, destination, destination)

	animate(ray, alpha = 255, time = 2 SECONDS)
	animate(guy, alpha = 255, time = 2 SECONDS)

	visible_message("[icon2html(src, viewers(src))] [src] clicks on.")
	playing = TRUE
	set_light(l_on = TRUE)
	update_appearance()

	sleep(4 SECONDS)

	var/list/phrases = list(
		'sound/misc/sec_intro/1.ogg' = "BEGIN TRANSMISSION.",
		'sound/misc/sec_intro/2.ogg' = "HELLO PEACEKEEPERS.",
		'sound/misc/sec_intro/3.ogg' = "YOUR JOB IS TO ENSURE COMPLIANCE WITH THE MANAGERS.",
		'sound/misc/sec_intro/4.ogg' = "THIS IS TO ENSURE THE SAFETY OF THE PUBLIC.",
		'sound/misc/sec_intro/5.ogg' = "YOU WILL BE PAID HANDSOMELY FOR YOUR WORK.",
		'sound/misc/sec_intro/6.ogg' = "DO NOT ALLOW THE TERRIBLE THING TO SPREAD.",
		'sound/misc/sec_intro/7.ogg' = "END TRANSMISSION.",
	)

	SSsound_cache.cache_sounds(phrases)

	for(var/sound in phrases)
		guy.say(phrases[sound])
		playsound(src, sound, 100, FALSE)
		sleep(SSsound_cache.get_sound_length(sound) + 0.6 SECONDS)

	animate(guy, alpha = 0, time = 2 SECONDS)
	animate(ray, alpha = 0, time = 2 SECONDS)

	sleep(2 SECONDS)

	visible_message("[icon2html(src, viewers(src))] [src] clicks off.")
	playing = FALSE
	set_light(l_on = FALSE)
	update_appearance()

	qdel(guy)
	qdel(ray)

/obj/machinery/projector/proc/update_ray(obj/effect/overlay/holoray/ray, turf/new_turf, turf/old_turf, animate = TRUE)
	var/disty = old_turf.y - ray.y
	var/distx = old_turf.x - ray.x
	var/newangle
	if(!disty)
		if(distx >= 0)
			newangle = 90
		else
			newangle = 270
	else
		newangle = arctan(distx/disty)
		if(disty < 0)
			newangle += 180
		else if(distx < 0)
			newangle += 360

	var/matrix/new_transform = matrix()
	new_transform.Scale(1, sqrt(distx * distx + disty * disty))
	new_transform.Turn(newangle)

	if (animate)
		animate(ray, transform = new_transform, time = 1)
	else
		ray.transform = new_transform

/obj/machinery/projector/proc/makeicon()
	var/mob/living/carbon/human/H = new()
	H.equipOutfit(new /datum/outfit/centcom/ert/commander)

	var/icon/icon = getFlatIcon(H)
	// Zoom in on the top of the head and the chest
	// I have no idea how to do this dynamically.
	icon.Scale(64, 64)

	// This is probably better as a Crop, but I cannot figure it out.
	icon.Shift(WEST, 15)
	icon.Shift(SOUTH, 30)

	icon.Crop(1, 1, 32, 32)

	if(!fexists("data/saved_icons.dmi"))
		fcopy("", "data/saved_icons.dmi")

	var/icon/local = icon("data/saved_icons.dmi")
	local.Insert(icon, "temp")
	fcopy(local, "data/saved_icons.dmi")

/obj/effect/abstract/projected_image
	name = "projection"
	chat_class = null

	light_color = LIGHT_COLOR_BABY_BLUE
	light_power = 0.4
	light_inner_range = 0.5
	light_outer_range = 2
