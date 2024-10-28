GLOBAL_LIST_EMPTY(ghost_images_simple) //this is a list of all ghost images as the simple white ghost
GLOBAL_LIST_EMPTY(ghost_images_robust) //this is a list of all ghost images as appearance copies

GLOBAL_VAR_INIT(observer_default_invisibility, INVISIBILITY_OBSERVER)

GLOBAL_VAR_INIT(ghost_adjectives, __ghost_adjectives())
GLOBAL_VAR_INIT(ghost_synonyms, __ghost_synonyms())
GLOBAL_VAR_INIT(fresh_ghost_adjectives, __fresh_ghost_adjectives())

/mob/dead/observer
	name = "ghost"
	desc = "It's a g-g-g-g-ghooooost!" //jinkies!
	icon = 'icons/mob/mob.dmi'
	icon_state = "ghost"
	plane = GHOST_PLANE
	stat = DEAD
	density = FALSE
	appearance_flags = KEEP_TOGETHER
	see_invisible = SEE_INVISIBLE_OBSERVER
	see_in_dark = 100
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE
	invisibility = INVISIBILITY_OBSERVER
	hud_type = /datum/hud/ghost
	movement_type = GROUND | FLYING
	light_system = OVERLAY_LIGHT
	light_outer_range = 1
	light_power = 2
	light_on = FALSE
	shift_to_open_context_menu = FALSE
	simulated = FALSE

	var/can_reenter_corpse
	var/datum/hud/living/carbon/hud = null // hud
	var/bootime = 0

	/// Prefixed adjective to the ghost's name
	var/ghost_adjective = ""
	/// name = "[ghost_adjective] [ghost_term] of [real_name]"
	var/ghost_term = ""

	//This variable is set to 1 when you enter the game as an observer.
	//If you died in the game and are a ghost - this will remain false.
	//Note that this is not a reliable way to determine if admins started as observers, since they change mobs a lot.
	var/started_as_observer = FALSE
	/// Was this ghost spawned using the admin ghost command.
	var/admin_ghost = FALSE
	#warn TODO
	var/exorcised = FALSE

	var/atom/movable/following = null
	var/fun_verbs = 0

	var/ghostvision = 1 //is the ghost able to see things humans can't?
	var/mob/observetarget = null //The target mob that the ghost is observing. Used as a reference in logout()
	var/data_huds_on = 0 //Are data HUDs currently enabled?
	var/health_scan = FALSE //Are health scans currently enabled?
	var/chem_scan = FALSE //Are chem scans currently enabled?
	var/gas_scan = FALSE //Are gas scans currently enabled?
	var/list/datahuds = list(DATA_HUD_SECURITY_ADVANCED, DATA_HUD_MEDICAL_ADVANCED, DATA_HUD_DIAGNOSTIC_ADVANCED) //list of data HUDs shown to ghosts.
	var/ghost_orbit = GHOST_ORBIT_CIRCLE

	// Used for displaying in ghost chat, without changing the actual name
	// of the mob
	var/deadchat_name
	var/datum/spawners_menu/spawners_menu
	var/datum/minigames_menu/minigames_menu

/mob/dead/observer/Initialize(mapload, started_as_observer = FALSE, admin_ghost = FALSE)
	src.started_as_observer = started_as_observer
	src.admin_ghost = admin_ghost

	set_invisibility(GLOB.observer_default_invisibility)

	add_verb(src, list(
		/mob/dead/observer/proc/dead_tele,
		/mob/dead/observer/proc/open_spawners_menu,
		/mob/dead/observer/proc/tray_view,
		/mob/dead/observer/proc/open_minigames_menu))

	ghost_term = pick(GLOB.ghost_synonyms)
	ghost_adjective = pick(GLOB.ghost_adjectives)

	var/turf/T
	var/mob/body = loc
	var/mind_or_body_name

	if(ismob(body))
		T = get_turf(body) //Where is the body located?

		mind = body.mind //we don't transfer the mind but we keep a reference to it.
		set_suicide(body.suiciding) // Transfer whether they committed suicide.

		gender = body.gender
		died_as_name = body.died_as_name

		// Pick a name
		if(body.mind && body.mind.name)
			if(body.mind.ghostname)
				mind_or_body_name = body.mind.ghostname
			else
				mind_or_body_name = body.mind.name
		else
			if(body.real_name)
				mind_or_body_name = body.real_name
			else
				mind_or_body_name = random_unique_name(gender)

		// If they actually died in round, copy their body.
		if(!(started_as_observer || admin_ghost))
			set_ghost_appearance(body)
			ghost_adjective = pick(GLOB.fresh_ghost_adjectives)

	if(!mind_or_body_name) //To prevent nameless ghosts
		mind_or_body_name = random_unique_name(gender)

	set_real_name(mind_or_body_name)

	if(!T || is_secret_level(T.z))
		var/list/turfs = get_area_turfs(/area/shuttle/arrival)
		if(length(turfs))
			T = pick(turfs)
		else
			T = SSmapping.get_station_center()

	abstract_move(T)

	if(!fun_verbs)
		remove_verb(src, /mob/dead/observer/verb/boo)
		remove_verb(src, /mob/dead/observer/verb/possess)

	AddElement(/datum/element/movetype_handler)

	add_to_dead_mob_list()

	for(var/v in GLOB.active_alternate_appearances)
		if(!v)
			continue
		var/datum/atom_hud/alternate_appearance/AA = v
		AA.onNewMob(src)

	. = ..()

	grant_all_languages()
	show_data_huds()
	data_huds_on = 1

	SSpoints_of_interest.make_point_of_interest(src)
	ADD_TRAIT(src, TRAIT_HEAR_THROUGH_DARKNESS, ref(src))

	if(!started_as_observer)
		var/static/list/powers = list(
			/datum/action/cooldown/ghost_whisper = SPOOK_LEVEL_WEAK_POWERS,
			/datum/action/cooldown/flicker = SPOOK_LEVEL_WEAK_POWERS,
			/datum/action/cooldown/knock_sound = SPOOK_LEVEL_WEAK_POWERS,
			/datum/action/cooldown/ghost_light = SPOOK_LEVEL_MEDIUM_POWERS,
			/datum/action/cooldown/chilling_presence = SPOOK_LEVEL_MEDIUM_POWERS,
			/datum/action/cooldown/shatter_light = SPOOK_LEVEL_DESTRUCTIVE_POWERS,
			/datum/action/cooldown/shatter_glass = SPOOK_LEVEL_DESTRUCTIVE_POWERS,
		)
		AddComponent(/datum/component/spooky_powers, powers)

/mob/dead/observer/Destroy()
	if(data_huds_on)
		remove_data_huds()

	// Update our old body's medhud since we're abandoning it
	if(isliving(mind?.current))
		mind.current.med_hud_set_status()

	QDEL_NULL(spawners_menu)
	QDEL_NULL(minigames_menu)
	return ..()

/mob/dead/observer/get_photo_description(obj/item/camera/camera)
	if(!invisibility || camera.see_ghosts)
		return "You can also see a g-g-g-g-ghooooost!"

/mob/dead/observer/narsie_act()
	var/old_color = color
	color = "#960000"
	animate(src, color = old_color, time = 10, flags = ANIMATION_PARALLEL)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, update_atom_colour)), 10)

/mob/dead/observer/get_visible_name()
	return "[ghost_adjective] [ghost_term] of [real_name]"

/mob/dead/observer/update_name(updates)
	. = ..()
	deadchat_name = name

/// Helper for setting can_reenter_corpse to FALSE
/mob/dead/observer/proc/unset_reenter_corpse()
	can_reenter_corpse = FALSE
	mind = null

/// Adds or removes the monochrome filter based on certain traits.
/mob/dead/observer/proc/update_monochrome()
	if(admin_ghost || started_as_observer)
		remove_client_colour(/datum/client_colour/ghostmono)
		return

	if(exorcised || client?.prefs?.read_preference(/datum/preference/toggle/monochrome_ghost) == FALSE) // Null != false
		remove_client_colour(/datum/client_colour/ghostmono)
		return

	add_client_colour(/datum/client_colour/ghostmono)

/// Exorcise the ghost.
/mob/dead/observer/proc/exorcise(mob/living/priest)
	exorcised = TRUE

	unset_reenter_corpse()
	update_monochrome()
	qdel(GetComponent(/datum/component/spooky_powers))

	ghost_adjective = pick(GLOB.ghost_adjectives)
	verb_say = initial(verb_say)
	verb_exclaim = initial(verb_exclaim)
	verb_sing = initial(verb_sing)
	verb_whisper = initial(verb_whisper)
	verb_yell = initial(verb_yell)

	update_appearance(UPDATE_NAME)
	set_ghost_appearance(null)

	if(client)
		// tgchat displays doc strings with formatting, so we do stupid shit instead
		var/list/text = list(
			"<div style='text-align:center'>[span_statsgood("<span style='font-size: 300%;font-style: normal'>You were laid to rest.</span>")]</div>",
			"<hr>",
			span_obviousnotice("Your soul has moved on from the mortal realm, and may no longer interact with it. You may now return to the lobby, and begin anew."),
		)
		to_chat(src, examine_block(jointext(text, "")))

		playsound_local(src, 'goon/sounds/ghostrespawn.ogg', 50, FALSE, pressure_affected = FALSE)

	if(priest)
		deadchat_broadcast("'s restless spirit has been put to rest by [priest.name].", real_name, priest, message_type = DEADCHAT_ANNOUNCEMENT)

/*
 * Increase the brightness of a color by calculating the average distance between the R, G and B values,
 * and maximum brightness, then adding 30% of that average to R, G and B.
 *
 * I'll make this proc global and move it to its own file in a future update. |- Ricotez - UPDATE: They never did :(
 */
/mob/proc/brighten_color(input_color)
	if(input_color[1] == "#")
		input_color = copytext(input_color, 2) // Removing the # at the beginning.
	var/r_val
	var/b_val
	var/g_val
	var/color_format = length(input_color)
	if(color_format != length_char(input_color))
		return 0
	if(color_format == 3)
		r_val = hex2num(copytext(input_color, 1, 2)) * 16
		g_val = hex2num(copytext(input_color, 2, 3)) * 16
		b_val = hex2num(copytext(input_color, 3, 4)) * 16
	else if(color_format == 6)
		r_val = hex2num(copytext(input_color, 1, 3))
		g_val = hex2num(copytext(input_color, 3, 5))
		b_val = hex2num(copytext(input_color, 5, 7))
	else
		return 0 //If the color format is not 3 or 6, you're using an unexpected way to represent a color.

	r_val += (255 - r_val) * 0.4
	if(r_val > 255)
		r_val = 255
	g_val += (255 - g_val) * 0.4
	if(g_val > 255)
		g_val = 255
	b_val += (255 - b_val) * 0.4
	if(b_val > 255)
		b_val = 255

	return "#" + copytext(rgb(r_val, g_val, b_val), 2)

/*
Transfer_mind is there to check if mob is being deleted/not going to have a body.
Works together with spawning an observer, noted above.
*/

/mob/proc/ghostize(can_reenter_corpse = TRUE, admin_ghost)
	if(!key)
		return
	if(key[1] == "@") // Skip aghosts.
		return

	if(HAS_TRAIT(src, TRAIT_CORPSELOCKED))
		if(can_reenter_corpse) //If you can re-enter the corpse you can't leave when corpselocked
			return
		if(ishuman(usr)) //following code only applies to those capable of having an ethereal heart, ie humans
			var/mob/living/carbon/human/crystal_fella = usr
			var/our_heart = crystal_fella.getorganslot(ORGAN_SLOT_HEART)
			if(istype(our_heart, /obj/item/organ/heart/ethereal)) //so you got the heart?
				var/obj/item/organ/heart/ethereal/ethereal_heart = our_heart
				ethereal_heart.stop_crystalization_process(crystal_fella) //stops the crystallization process

	stop_sound_channel(CHANNEL_HEARTBEAT) //Stop heartbeat sounds because You Are A Ghost Now
	var/mob/dead/observer/ghost = new(src, FALSE, admin_ghost) // Transfer safety to observer spawning proc.
	SStgui.on_transfer(src, ghost) // Transfer NanoUIs.

	ghost.verb_say = verb_say
	ghost.verb_exclaim = verb_exclaim
	ghost.verb_sing = verb_sing
	ghost.verb_whisper = verb_whisper
	ghost.verb_yell = verb_yell
	if(!can_reenter_corpse)
		ghost.exorcise()

	ghost.key = key
	ghost.client?.init_verbs()
	return ghost

/mob/living/ghostize(can_reenter_corpse = TRUE, admin_ghost)
	. = ..()
	if(. && can_reenter_corpse)
		var/mob/dead/observer/ghost = .
		ghost.mind.current?.med_hud_set_status()

/*
This is the proc mobs get to turn into a ghost. Forked from ghostize due to compatibility issues.
*/
/mob/living/verb/ghost()
	set category = "OOC"
	set name = "Ghost"
	set desc = "Relinquish your life and enter the land of the dead."

	if(stat != DEAD)
		succumb()
	if(stat == DEAD)
		ghostize(TRUE)
		return TRUE
	var/response = tgui_alert(usr, "Are you sure you want to ghost? If you ghost whilst still alive you cannot re-enter your body!", "Confirm Ghost Observe", list("Ghost", "Stay in Body"))
	if(response != "Ghost")
		return FALSE//didn't want to ghost after-all
	ghostize(FALSE) // FALSE parameter is so we can never re-enter our body. U ded.
	return TRUE

/mob/camera/verb/ghost()
	set category = "OOC"
	set name = "Ghost"
	set desc = "Relinquish your life and enter the land of the dead."

	var/response = tgui_alert(usr, "Are you sure you want to ghost? If you ghost whilst still alive you cannot re-enter your body!", "Confirm Ghost Observe", list("Ghost", "Stay in Body"))
	if(response != "Ghost")
		return
	ghostize(FALSE)

/mob/dead/observer/keyLoop(client/user)
	if(observetarget)
		var/trying_to_move = FALSE
		for(var/_key in user?.keys_held)
			if(user.movement_keys[_key])
				trying_to_move = TRUE
				break
		if(trying_to_move)
			stop_observing()
	return ..()

/mob/dead/observer/Move(NewLoc, direct, glide_size_override = 32, z_movement_flags)
	if(observetarget)
		stop_observing()

	setDir(direct)

	if(glide_size_override)
		set_glide_size(glide_size_override)
	if(NewLoc)
		abstract_move(NewLoc)
	else
		var/turf/destination = get_turf(src)

		if((direct & NORTH) && y < world.maxy)
			destination = get_step(destination, NORTH)

		else if((direct & SOUTH) && y > 1)
			destination = get_step(destination, SOUTH)

		if((direct & EAST) && x < world.maxx)
			destination = get_step(destination, EAST)

		else if((direct & WEST) && x > 1)
			destination = get_step(destination, WEST)

		abstract_move(destination)//Get out of closets and such as a ghost

	return TRUE

/mob/dead/observer/forceMove(atom/destination)
	abstract_move(destination) // move like the wind
	return TRUE

/mob/dead/observer/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	var/area/new_area = get_area(src)
	if(new_area != ambience_tracked_area)
		update_ambience_area(new_area)

/mob/dead/observer/verb/reenter_corpse()
	set category = "Ghost"
	set name = "Re-enter Corpse"
	if(!client)
		return
	if(!mind || QDELETED(mind.current))
		to_chat(src, span_warning("You have no body."))
		return
	if(!can_reenter_corpse)
		to_chat(src, span_warning("You cannot re-enter your body."))
		return
	if(mind.current.key && mind.current.key[1] != "@") //makes sure we don't accidentally kick any clients
		to_chat(usr, span_warning("Another consciousness is in your body...It is resisting you."))
		return
	client.view_size.setDefault(getScreenSize(client.prefs.read_preference(/datum/preference/toggle/widescreen)))//Let's reset so people can't become allseeing gods
	SStgui.on_transfer(src, mind.current) // Transfer NanoUIs.
	if(mind.current.stat == DEAD && SSlag_switch.measures[DISABLE_DEAD_KEYLOOP])
		to_chat(src, span_warning("To leave your body again use the Ghost verb."))
	mind.current.key = key
	mind.current.client.init_verbs()
	return TRUE

/mob/dead/observer/verb/stay_dead()
	set category = "Ghost"
	set name = "Do Not Resuscitate"
	if(!client)
		return
	if(!can_reenter_corpse)
		to_chat(usr, span_warning("You're already stuck out of your body!"))
		return FALSE

	var/response = tgui_alert(usr, "Are you sure you want to prevent (almost) all means of resuscitation? This cannot be undone.", "Are you sure you want to stay dead?", list("DNR","Save Me"))
	if(response != "DNR")
		return

	// Update med huds
	var/mob/living/carbon/current = mind.current
	current.med_hud_set_status()

	exorcise()
	return TRUE

/mob/dead/observer/proc/notify_revival(message, sound, atom/source, flashwindow = TRUE)
	if(flashwindow)
		window_flash(client)
	if(message)
		to_chat(src, span_ghostalert("[message]"))
		if(source)
			var/atom/movable/screen/alert/A = throw_alert("[REF(source)]_notify_revival", /atom/movable/screen/alert/notify_revival)
			if(A)
				var/ui_style = client?.prefs?.read_preference(/datum/preference/choiced/ui_style)
				if(ui_style)
					A.icon = ui_style2icon(ui_style)
				A.desc = message
				var/old_layer = source.layer
				var/old_plane = source.plane
				source.layer = FLOAT_LAYER
				source.plane = FLOAT_PLANE
				A.add_overlay(source)
				source.layer = old_layer
				source.plane = old_plane
	to_chat(src, span_ghostalert("<a href=?src=[REF(src)];reenter=1>(Click to re-enter)</a>"))
	if(sound)
		SEND_SOUND(src, sound(sound))

/mob/dead/observer/proc/dead_tele()
	set category = "Ghost"
	set name = "Teleport"
	set desc= "Teleport to a location"
	if(!isobserver(usr))
		to_chat(usr, span_warning("Not when you're not dead!"))
		return
	var/list/filtered = list()
	for(var/area/A in get_sorted_areas())
		if(!(A.area_flags & HIDDEN_AREA))
			filtered += A

	var/area/thearea = tgui_input_list(usr, "Area to jump to", "BOOYEA", filtered)

	if(isnull(thearea))
		return
	if(!isobserver(usr))
		to_chat(usr, span_warning("Not when you're not dead!"))
		return

	var/list/L = list()
	for(var/turf/T in get_area_turfs(thearea.type))
		L+=T

	if(!L || !length(L))
		to_chat(usr, span_warning("No area available."))
		return

	usr.abstract_move(pick(L))

/mob/dead/observer/verb/follow()
	set category = "Ghost"
	set name = "Orbit" // "Haunt"
	set desc = "Follow and orbit a mob."

	GLOB.orbit_menu.show(src)

// This is the ghost's follow verb with an argument
/mob/dead/observer/proc/ManualFollow(atom/movable/target)
	if (!istype(target) || !target.z || target == src || (is_secret_level(target.z) && !client?.holder))
		return

	var/icon/I = icon(target.icon,target.icon_state,target.dir)

	var/orbitsize = (I.Width()+I.Height())*0.5
	orbitsize -= (orbitsize/world.icon_size)*(world.icon_size*0.25)

	var/rot_seg

	switch(ghost_orbit)
		if(GHOST_ORBIT_TRIANGLE)
			rot_seg = 3
		if(GHOST_ORBIT_SQUARE)
			rot_seg = 4
		if(GHOST_ORBIT_PENTAGON)
			rot_seg = 5
		if(GHOST_ORBIT_HEXAGON)
			rot_seg = 6
		else //Circular
			rot_seg = 36 //360/10 bby, smooth enough aproximation of a circle

	orbit(target,orbitsize, FALSE, 20, rot_seg)

/mob/dead/observer/orbit()
	if(observetarget)
		stop_observing()

	setDir(2)//reset dir so the right directional sprites show up
	return ..()

/mob/dead/observer/stop_orbit(datum/component/orbiter/orbits)
	. = ..()
	//restart our floating animation after orbit is done.
	pixel_y = base_pixel_y

/mob/dead/observer/verb/jumptomob() //Moves the ghost instead of just changing the ghosts's eye -Nodrak
	set category = "Ghost"
	set name = "Jump to Mob"
	set desc = "Teleport to a mob"

	if(!isobserver(usr)) //Make sure they're an observer!
		return

	var/list/possible_destinations = SSpoints_of_interest.get_mob_pois()
	var/target = null

	target = tgui_input_list(usr, "Please, select a player!", "Jump to Mob", possible_destinations)
	if(isnull(target))
		return
	if (!isobserver(usr))
		return

	var/mob/destination_mob = possible_destinations[target] //Destination mob

	// During the break between opening the input menu and selecting our target, has this become an invalid option?
	if(!SSpoints_of_interest.is_valid_poi(destination_mob))
		return

	var/mob/source_mob = src  //Source mob
	var/turf/destination_turf = get_turf(destination_mob) //Turf of the destination mob

	if(isturf(destination_turf))
		source_mob.abstract_move(destination_turf)
	else
		to_chat(source_mob, span_danger("This mob is not located in the game world."))

/mob/dead/observer/verb/change_view_range()
	set category = "Ghost"
	set name = "View Range"
	set desc = "Change your view range."

	if(SSlag_switch.measures[DISABLE_GHOST_ZOOM_TRAY] && !client?.holder)
		to_chat(usr, span_notice("That verb is currently globally disabled."))
		return

	var/max_view = client.prefs.unlock_content ? GHOST_MAX_VIEW_RANGE_MEMBER : GHOST_MAX_VIEW_RANGE_DEFAULT
	if(client.view_size.getView() == client.view_size.default)
		var/list/views = list()
		for(var/i in 7 to max_view)
			views |= i
		var/new_view = tgui_input_list(usr, "New view", "Modify view range", views)
		if(new_view)
			client.view_size.setTo(clamp(new_view, 7, max_view) - 7)
	else
		client.view_size.resetToDefault()

/mob/dead/observer/verb/add_view_range(input as num)
	set name = "Add View Range"
	set hidden = TRUE

	if(SSlag_switch.measures[DISABLE_GHOST_ZOOM_TRAY] && !client?.holder)
		to_chat(usr, span_notice("That verb is currently globally disabled."))
		return

	var/max_view = client.prefs.unlock_content ? GHOST_MAX_VIEW_RANGE_MEMBER : GHOST_MAX_VIEW_RANGE_DEFAULT
	if(input)
		client.rescale_view(input, 0, ((max_view*2)+1) - 15)

/mob/dead/observer/verb/boo()
	set category = "Ghost"
	set name = "Boo!"
	set desc= "Scare your crew members because of boredom!"

	if(bootime > world.time)
		return
	var/obj/machinery/light/L = locate(/obj/machinery/light) in view(1, src)
	if(L?.flicker())
		bootime = world.time + 600
	//Maybe in the future we can add more <i>spooky</i> code here!


/mob/dead/observer/verb/toggle_ghostsee()
	set name = "Toggle Ghost Vision"
	set desc = "Toggles your ability to see things only ghosts can see, like other ghosts"
	set category = "Ghost"
	ghostvision = !(ghostvision)
	update_sight()
	to_chat(usr, span_boldnotice("You [(ghostvision?"now":"no longer")] have ghost vision."))

/mob/dead/observer/verb/toggle_darkness()
	set name = "Toggle Darkness"
	set category = "Ghost"
	switch(lighting_alpha)
		if (LIGHTING_PLANE_ALPHA_VISIBLE)
			lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE
		if (LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE)
			lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE
		if (LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE)
			lighting_alpha = LIGHTING_PLANE_ALPHA_INVISIBLE
		else
			lighting_alpha = LIGHTING_PLANE_ALPHA_VISIBLE

	update_sight()

/mob/dead/observer/update_sight()
	if(observetarget)
		return

	if(!ghostvision)
		see_invisible = SEE_INVISIBLE_LIVING
	else
		see_invisible = SEE_INVISIBLE_OBSERVER
	..()

/mob/dead/observer/verb/possess()
	set category = "Ghost"
	set name = "Possess!"
	set desc= "Take over the body of a mindless creature!"

	var/list/possessible = list()
	for(var/mob/living/L in GLOB.alive_mob_list)
		if(istype(L,/mob/living/carbon/human/dummy) || !get_turf(L)) //Haha no.
			continue
		if(!(L in GLOB.player_list) && !L.mind)
			possessible += L

	var/mob/living/target = tgui_input_list(usr, "Your new life begins today!", "Possess Mob", sort_names(possessible))

	if(!target)
		return FALSE

	if(ismegafauna(target))
		to_chat(src, span_warning("This creature is too powerful for you to possess!"))
		return FALSE

	if(can_reenter_corpse && mind?.current)
		if(tgui_alert(usr, "Your soul is still tied to your former life as [mind.current.name], if you go forward there is no going back to that life. Are you sure you wish to continue?", "Move On", list("Yes", "No")) == "No")
			return FALSE
	if(target.key)
		to_chat(src, span_warning("Someone has taken this body while you were choosing!"))
		return FALSE

	target.key = key
	target.faction = list("neutral")
	return TRUE

/mob/dead/observer/_pointed(atom/pointed_at)
	if(!..())
		return FALSE

	usr.visible_message(span_deadsay("<b>[src]</b> points to [pointed_at]."))

/mob/dead/observer/verb/view_manifest()
	set name = "View Crew Manifest"
	set category = "Ghost"

	show_crew_manifest(src)

//this is called when a ghost is drag clicked to something.
/mob/dead/observer/MouseDrop(atom/over)
	if(!usr || !over)
		return
	if (isobserver(usr) && usr.client.holder && (isliving(over) || iscameramob(over)) )
		if (usr.client.holder.cmd_ghost_drag(src,over))
			return

	return ..()

/mob/dead/observer/Topic(href, href_list)
	..()
	if(usr == src)
		if(href_list["follow"])
			var/atom/movable/target = locate(href_list["follow"])
			if(istype(target) && (target != src))
				ManualFollow(target)
				return
		if(href_list["x"] && href_list["y"] && href_list["z"])
			var/tx = text2num(href_list["x"])
			var/ty = text2num(href_list["y"])
			var/tz = text2num(href_list["z"])
			var/turf/target = locate(tx, ty, tz)
			if(istype(target))
				abstract_move(target)
				return
		if(href_list["reenter"])
			reenter_corpse()
			return

//We don't want to update the current var
//But we will still carry a mind.
/mob/dead/observer/mind_initialize()
	return

/mob/dead/observer/proc/show_data_huds()
	for(var/hudtype in datahuds)
		var/datum/atom_hud/H = GLOB.huds[hudtype]
		H.show_to(src)

/mob/dead/observer/proc/remove_data_huds()
	for(var/hudtype in datahuds)
		var/datum/atom_hud/H = GLOB.huds[hudtype]
		H.hide_from(src)

/mob/dead/observer/verb/toggle_data_huds()
	set name = "Toggle Sec/Med/Diag HUD"
	set desc = "Toggles whether you see medical/security/diagnostic HUDs"
	set category = "Ghost"

	if(data_huds_on) //remove old huds
		remove_data_huds()
		to_chat(src, span_notice("Data HUDs disabled."))
		data_huds_on = 0
	else
		show_data_huds()
		to_chat(src, span_notice("Data HUDs enabled."))
		data_huds_on = 1

/mob/dead/observer/verb/toggle_health_scan()
	set name = "Toggle Health Scan"
	set desc = "Toggles whether you health-scan living beings on click"
	set category = "Ghost"

	if(health_scan) //remove old huds
		to_chat(src, span_notice("Health scan disabled."))
		health_scan = FALSE
	else
		to_chat(src, span_notice("Health scan enabled."))
		health_scan = TRUE

/mob/dead/observer/verb/toggle_chem_scan()
	set name = "Toggle Chem Scan"
	set desc = "Toggles whether you scan living beings for chemicals and addictions on click"
	set category = "Ghost"

	if(chem_scan) //remove old huds
		to_chat(src, span_notice("Chem scan disabled."))
		chem_scan = FALSE
	else
		to_chat(src, span_notice("Chem scan enabled."))
		chem_scan = TRUE

/mob/dead/observer/verb/toggle_gas_scan()
	set name = "Toggle Gas Scan"
	set desc = "Toggles whether you analyze gas contents on click"
	set category = "Ghost"

	if(gas_scan)
		to_chat(src, span_notice("Gas scan disabled."))
		gas_scan = FALSE
	else
		to_chat(src, span_notice("Gas scan enabled."))
		gas_scan = TRUE

/mob/dead/observer/proc/set_ghost_appearance(mob/living/to_copy)
	var/mutable_appearance/appearance = to_copy?.mind?.body_appearance || to_copy

	if(!appearance || !appearance.icon)
		icon = initial(icon)
		icon_state = "ghost"
		alpha = 255
		overlays.Cut()
	else
		icon = appearance.icon
		icon_state = appearance.icon_state
		overlays = appearance.overlays
		alpha = 127

/mob/dead/observer/canUseTopic(atom/movable/target, flags)
	return isAdminGhostAI(usr)

/mob/dead/observer/is_literate()
	return TRUE

/mob/dead/observer/can_read(atom/viewed_atom, reading_check_flags, silent)
	return TRUE // we want to bypass all the checks

/mob/dead/observer/vv_edit_var(var_name, var_value)
	. = ..()
	switch(var_name)
		if(NAMEOF(src, fun_verbs))
			if(fun_verbs)
				add_verb(src, /mob/dead/observer/verb/boo)
				add_verb(src, /mob/dead/observer/verb/possess)
			else
				remove_verb(src, /mob/dead/observer/verb/boo)
				remove_verb(src, /mob/dead/observer/verb/possess)

/mob/dead/observer/reset_perspective(atom/A)
	if(client && observetarget)
		stop_observing()
		return

	if(..())
		if(hud_used)
			client.screen = list()
			hud_used.show_hud(hud_used.hud_version)


/mob/dead/observer/proc/stop_observing()
	if(isnull(observetarget))
		return

	if(!QDELETED(src))
		if(QDELETED(observetarget))
			var/obj/effect/landmark/observer_start/O = locate(/obj/effect/landmark/observer_start) in GLOB.landmarks_list
			if (O)
				forceMove(O.loc)
		else
			abstract_move(get_turf(observetarget))

	var/mob/target = observetarget
	observetarget = null
	reset_perspective(null) // Comes after nulling, otherwise it would cause an infinite loop

	client?.perspective = initial(client.perspective)
	sight = initial(sight)
	see_invisible = initial(see_invisible)

	if(target)
		hide_other_mob_action_buttons(target)
		UnregisterSignal(target, COMSIG_MOB_UPDATE_SIGHT)
		LAZYREMOVE(target.observers, src)

	client?.update_ambience_pref()

/mob/dead/observer/verb/observe()
	set name = "Observe"
	set category = "Ghost"

	if(!isobserver(usr)) //Make sure they're an observer!
		return

	var/was_observing = observetarget
	reset_perspective(null)
	if(was_observing)
		return

	var/list/possible_destinations = SSpoints_of_interest.get_mob_pois(cliented_mobs_only = TRUE)
	var/target = null

	target = tgui_input_list(usr, "Please, select a player!", "Jump to Mob", possible_destinations)
	if(isnull(target))
		return
	if (!isobserver(usr))
		return

	if(target == usr)
		return

	var/mob/chosen_target = possible_destinations[target]

	// During the break between opening the input menu and selecting our target, has this become an invalid option?
	if(!SSpoints_of_interest.is_valid_poi(chosen_target))
		return

	if(!client || client.restricted_mode)
		ManualFollow(chosen_target)
	else
		do_observe(chosen_target)

/mob/dead/observer/proc/do_observe(mob/mob_eye)
	//Istype so we filter out points of interest that are not mobs
	if(!client || !istype(mob_eye) || mob_eye == src)
		return

	if(isnewplayer(mob_eye))
		stack_trace("/mob/dead/new_player: \[[mob_eye]\] is being observed by [key_name(src)]. This should never happen and has been blocked.")
		message_admins("[ADMIN_LOOKUPFLW(src)] attempted to observe someone in the lobby: [ADMIN_LOOKUPFLW(mob_eye)]. This should not be possible and has been blocked.")
		return

	orbit(mob_eye)

	client.eye = mob_eye
	client.perspective = EYE_PERSPECTIVE
	sight = mob_eye.sight
	see_invisible = mob_eye.see_invisible

	if(mob_eye.hud_used)
		client.screen = list()
		LAZYOR(mob_eye.observers, src)
		mob_eye.hud_used.show_hud(mob_eye.hud_used.hud_version, src)
		observetarget = mob_eye

	RegisterSignal(mob_eye, COMSIG_MOB_UPDATE_SIGHT, PROC_REF(on_observing_sight_changed))

	SSambience.remove_ambience_client(client)
	moveToNullspace()

/mob/dead/observer/proc/on_observing_sight_changed(datum/source)
	SIGNAL_HANDLER

	sight = observetarget.sight

/mob/dead/observer/verb/register_pai_candidate()
	set category = "Ghost"
	set name = "pAI Setup"
	set desc = "Upload a fragment of your personality to the global pAI databanks"

	register_pai()

/mob/dead/observer/proc/register_pai()
	if(isobserver(src))
		SSpai.recruitWindow(src)
	else
		to_chat(usr, span_warning("Can't become a pAI candidate while not dead!"))

/mob/dead/observer/verb/mafia_game_signup()
	set category = "Ghost"
	set name = "Signup for Mafia"
	set desc = "Sign up for a game of Mafia to pass the time while dead."

	mafia_signup()

/mob/dead/observer/proc/mafia_signup()
	if(!client)
		return
	if(!isobserver(src))
		to_chat(usr, span_warning("You must be a ghost to join mafia!"))
		return
	var/datum/mafia_controller/game = GLOB.mafia_game //this needs to change if you want multiple mafia games up at once.
	if(!game)
		game = create_mafia_game("mafia")
	game.ui_interact(usr)

/mob/dead/observer/CtrlShiftClick(mob/user)
	if(isobserver(user) && check_rights(R_SPAWN))
		change_mob_type( /mob/living/carbon/human , null, null, TRUE) //always delmob, ghosts shouldn't be left lingering

/mob/dead/observer/examine(mob/user)
	. = ..()
	if(!invisibility)
		. += "It seems extremely obvious."

/mob/dead/observer/examine_more(mob/user)
	if(!isAdminObserver(user))
		return ..()
	. = list(span_notice("<i>You examine [src] closer, and note the following...</i>"))
	. += list("\t>[span_admin("[ADMIN_FULLMONTY(src)]")]")


/mob/dead/observer/proc/set_invisibility(value)
	invisibility = value
	set_light_on(!value ? TRUE : FALSE)


// Ghosts have no momentum, being massless ectoplasm
/mob/dead/observer/Process_Spacemove(movement_dir, continuous_move = FALSE)
	return TRUE

/mob/dead/observer/vv_edit_var(var_name, var_value)
	. = ..()
	if(var_name == NAMEOF(src, invisibility))
		set_invisibility(invisibility) // updates light

/proc/set_observer_default_invisibility(amount, message=null)
	for(var/mob/dead/observer/G in GLOB.player_list)
		G.set_invisibility(amount)
		if(message)
			to_chat(G, message)
	GLOB.observer_default_invisibility = amount

/mob/dead/observer/proc/open_spawners_menu()
	set name = "Spawners Menu"
	set desc = "See all currently available spawners"
	set category = "Ghost"
	if(!spawners_menu)
		spawners_menu = new(src)

	spawners_menu.ui_interact(src)

/mob/dead/observer/proc/open_minigames_menu()
	set name = "Minigames Menu"
	set desc = "See all currently available minigames"
	set category = "Ghost"
	if(!client)
		return
	if(!isobserver(src))
		to_chat(usr, span_warning("You must be a ghost to play minigames!"))
		return
	if(!minigames_menu)
		minigames_menu = new(src)

	minigames_menu.ui_interact(src)

/mob/dead/observer/proc/tray_view()
	set category = "Ghost"
	set name = "T-ray view"
	set desc = "Toggles a view of sub-floor objects"

	var/static/t_ray_view = FALSE
	if(SSlag_switch.measures[DISABLE_GHOST_ZOOM_TRAY] && !client?.holder && !t_ray_view)
		to_chat(usr, span_notice("That verb is currently globally disabled."))
		return
	t_ray_view = !t_ray_view

	var/list/t_ray_images = list()
	var/static/list/stored_t_ray_images = list()
	for(var/obj/O in orange(client.view, src) )
		if(HAS_TRAIT(O, TRAIT_T_RAY_VISIBLE))
			var/image/I = new(loc = get_turf(O))
			var/mutable_appearance/MA = new(O)
			MA.alpha = 128
			MA.dir = O.dir
			I.appearance = MA
			t_ray_images += I
	stored_t_ray_images += t_ray_images
	if(length(t_ray_images))
		if(t_ray_view)
			client.images += t_ray_images
		else
			client.images -= stored_t_ray_images

/mob/dead/observer/default_lighting_alpha()
	var/datum/preferences/prefs = client?.prefs
	if(!prefs || (client?.combo_hud_enabled && prefs.toggles & COMBOHUD_LIGHTING))
		return ..()
	return GLOB.ghost_lighting_options[prefs.read_preference(/datum/preference/choiced/ghost_lighting)]

/mob/dead/observer/hear_location()
	return observetarget || orbit_target || ..()

/proc/__ghost_synonyms()
	return list(
		"ghost",
		"spirit",
		"phantom",
	)

/proc/__ghost_adjectives()
	return list(
		"fleeting",
		"wayward",
		"weak",
		"fading",
		"ephemeral",
		"passing",
		"wandering",
		"restful",
	)

/proc/__fresh_ghost_adjectives()
	return list(
		"restless",
		"troubled",
		"unruly",
		"disturbed",
	)
