//Landmarks and other helpers which speed up the mapping process and reduce the number of unique instances/subtypes of items/turf/ect



/obj/effect/baseturf_helper //Set the baseturfs of every turf in the /area/ it is placed.
	name = "baseturf editor"
	icon = 'icons/effects/mapping_helpers.dmi'
	icon_state = ""

	var/list/baseturf_to_replace
	var/baseturf

	plane = POINT_PLANE

/obj/effect/baseturf_helper/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/effect/baseturf_helper/LateInitialize()
	if(!baseturf_to_replace)
		baseturf_to_replace = typecacheof(list(/turf/open/space,/turf/baseturf_bottom))
	else if(!length(baseturf_to_replace))
		baseturf_to_replace = list(baseturf_to_replace = TRUE)
	else if(baseturf_to_replace[baseturf_to_replace[1]] != TRUE) // It's not associative
		var/list/formatted = list()
		for(var/i in baseturf_to_replace)
			formatted[i] = TRUE
		baseturf_to_replace = formatted

	var/area/our_area = get_area(src)
	for(var/i in get_area_turfs(our_area, z))
		replace_baseturf(i)

	qdel(src)

/obj/effect/baseturf_helper/proc/replace_baseturf(turf/thing)
	if(length(thing.baseturfs))
		var/list/baseturf_cache = thing.baseturfs.Copy()
		for(var/i in baseturf_cache)
			if(baseturf_to_replace[i])
				baseturf_cache -= i

		thing.baseturfs = baseturfs_string_list(baseturf_cache, thing)

		if(!baseturf_cache.len)
			thing.assemble_baseturfs(baseturf)
		else
			if(!length(thing.baseturfs) || thing.baseturfs[1] != baseturf)
				thing.PlaceOnBottom(baseturf)

	else if(baseturf_to_replace[thing.baseturfs])
		thing.assemble_baseturfs(baseturf)

	else
		if(!length(thing.baseturfs) || thing.baseturfs[1] != baseturf)
			thing.PlaceOnBottom(baseturf)

/obj/effect/baseturf_helper/space
	name = "space baseturf editor"
	baseturf = /turf/open/space

/obj/effect/baseturf_helper/asteroid
	name = "asteroid baseturf editor"
	baseturf = /turf/open/misc/asteroid

/obj/effect/baseturf_helper/asteroid/airless
	name = "asteroid airless baseturf editor"
	baseturf = /turf/open/misc/asteroid/airless

/obj/effect/baseturf_helper/asteroid/basalt
	name = "asteroid basalt baseturf editor"
	baseturf = /turf/open/misc/asteroid/basalt

/obj/effect/baseturf_helper/asteroid/snow
	name = "asteroid snow baseturf editor"
	baseturf = /turf/open/misc/asteroid/snow

/obj/effect/baseturf_helper/beach/sand
	name = "beach sand baseturf editor"
	baseturf = /turf/open/misc/beach/sand

/obj/effect/baseturf_helper/beach/water
	name = "water baseturf editor"
	baseturf = /turf/open/water/beach

/obj/effect/baseturf_helper/lava
	name = "lava baseturf editor"
	baseturf = /turf/open/lava/smooth

/obj/effect/baseturf_helper/reinforced_plating
	name = "reinforced plating baseturf editor"
	baseturf = /turf/open/floor/plating/reinforced
	baseturf_to_replace = list(/turf/open/floor/plating,/turf/open/space,/turf/baseturf_bottom)

//This applies the reinforced plating to the above Z level for every tile in the area where this is placed
/obj/effect/baseturf_helper/reinforced_plating/ceiling
	name = "reinforced ceiling plating baseturf editor"

/obj/effect/baseturf_helper/reinforced_plating/ceiling/replace_baseturf(turf/thing)
	var/turf/ceiling = GetAbove(thing)
	if(isnull(ceiling))
		CRASH("baseturf helper is attempting to modify the Z level above but there is no Z level above above it.")
	if(isspaceturf(ceiling) || istype(ceiling, /turf/open/openspace))
		return
	return ..(ceiling)


/obj/effect/mapping_helpers
	icon = 'icons/effects/mapping_helpers.dmi'
	icon_state = ""
	var/late = FALSE

/obj/effect/mapping_helpers/Initialize(mapload)
	..()
	return late ? INITIALIZE_HINT_LATELOAD : INITIALIZE_HINT_QDEL

//airlock helpers
/obj/effect/mapping_helpers/airlock
	layer = DOOR_HELPER_LAYER
	late = TRUE

/obj/effect/mapping_helpers/airlock/Initialize(mapload)
	. = ..()
	if(!mapload)
		log_mapping("[src] spawned outside of mapload!")
		return

	var/obj/machinery/door/airlock/airlock = locate(/obj/machinery/door/airlock) in loc
	if(!airlock)
		log_mapping("[src] failed to find an airlock at [AREACOORD(src)]")
	else
		payload(airlock)

/obj/effect/mapping_helpers/airlock/LateInitialize()
	. = ..()
	var/obj/machinery/door/airlock/airlock = locate(/obj/machinery/door/airlock) in loc
	if(!airlock)
		qdel(src)
		return
	if(airlock.cyclelinkeddir)
		airlock.cyclelinkairlock()
	if(airlock.closeOtherId)
		airlock.update_other_id()
	if(airlock.abandoned)
		var/outcome = rand(1,100)
		switch(outcome)
			if(1 to 9)
				var/turf/here = get_turf(src)
				for(var/turf/closed/T in range(2, src))
					here.PlaceOnTop(T.type)
					qdel(src)
					return
				here.PlaceOnTop(/turf/closed/wall)
				qdel(src)
				return
			if(9 to 11)
				airlock.lights = FALSE
				airlock.locked = TRUE
			if(12 to 15)
				airlock.locked = TRUE
			if(16 to 23)
				airlock.welded = TRUE
			if(24 to 30)
				airlock.panel_open = TRUE
	if(airlock.cutAiWire)
		wires.cut(WIRE_AI)
	if(airlock.autoname)
		name = get_area_name(src, TRUE)
	update_appearance()
	qdel(src)

/obj/effect/mapping_helpers/airlock/proc/payload(obj/machinery/door/airlock/payload)
	return

/obj/effect/mapping_helpers/airlock/cyclelink_helper
	name = "airlock cyclelink helper"
	icon_state = "airlock_cyclelink_helper"

/obj/effect/mapping_helpers/airlock/cyclelink_helper/payload(obj/machinery/door/airlock/airlock)
	if(airlock.cyclelinkeddir)
		log_mapping("[src] at [AREACOORD(src)] tried to set [airlock] cyclelinkeddir, but it's already set!")
	else
		airlock.cyclelinkeddir = dir

/obj/effect/mapping_helpers/airlock/cyclelink_helper_multi
	name = "airlock multi-cyclelink helper"
	icon_state = "airlock_multicyclelink_helper"
	var/cycle_id

/obj/effect/mapping_helpers/airlock/cyclelink_helper_multi/payload(obj/machinery/door/airlock/airlock)
	if(airlock.closeOtherId)
		log_mapping("[src] at [AREACOORD(src)] tried to set [airlock] closeOtherId, but it's already set!")
	else
		airlock.closeOtherId = cycle_id

/obj/effect/mapping_helpers/airlock/locked
	name = "airlock lock helper"
	icon_state = "airlock_locked_helper"

/obj/effect/mapping_helpers/airlock/locked/payload(obj/machinery/door/airlock/airlock)
	if(airlock.locked)
		log_mapping("[src] at [AREACOORD(src)] tried to bolt [airlock] but it's already locked!")
	else
		airlock.locked = TRUE


/obj/effect/mapping_helpers/airlock/unres
	name = "airlock unresctricted side helper"
	icon_state = "airlock_unres_helper"

/obj/effect/mapping_helpers/airlock/unres/payload(obj/machinery/door/airlock/airlock)
	airlock.unres_sides ^= dir

/obj/effect/mapping_helpers/airlock/abandoned
	name = "airlock abandoned helper"
	icon_state = "airlock_abandoned"

/obj/effect/mapping_helpers/airlock/abandoned/payload(obj/machinery/door/airlock/airlock)
	if(airlock.abandoned)
		log_mapping("[src] at [AREACOORD(src)] tried to make [airlock] abandoned but it's already abandoned!")
	else
		airlock.abandoned = TRUE

/obj/effect/mapping_helpers/airlock/cutaiwire
	name = "airlock cut ai wire helper"
	icon_state = "airlock_cutaiwire"

/obj/effect/mapping_helpers/airlock/cutaiwire/payload(obj/machinery/door/airlock/airlock)
	if(airlock.cutAiWire)
		log_mapping("[src] at [AREACOORD(src)] tried to cut the ai wire on [airlock] but it's already cut!")
	else
		airlock.cutAiWire = TRUE

/obj/effect/mapping_helpers/airlock/autoname
	name = "airlock autoname helper"
	icon_state = "airlock_autoname"

/obj/effect/mapping_helpers/airlock/autoname/payload(obj/machinery/door/airlock/airlock)
	if(airlock.autoname)
		log_mapping("[src] at [AREACOORD(src)] tried to autoname the [airlock] but it's already autonamed!")
	else
		airlock.autoname = TRUE

//needs to do its thing before spawn_rivers() is called
INITIALIZE_IMMEDIATE(/obj/effect/mapping_helpers/no_lava)

/obj/effect/mapping_helpers/no_lava
	icon_state = "no_lava"

/obj/effect/mapping_helpers/no_lava/Initialize(mapload)
	. = ..()
	var/turf/T = get_turf(src)
	T.turf_flags |= NO_LAVA_GEN

///Helpers used for injecting stuff into atoms on the map.
/obj/effect/mapping_helpers/atom_injector
	name = "Atom Injector"
	icon_state = "injector"
	late = TRUE
	///Will inject into all fitting the criteria if false, otherwise first found.
	var/first_match_only = TRUE
	///Will inject into atoms of this type.
	var/target_type
	///Will inject into atoms with this name.
	var/target_name

//Late init so everything is likely ready and loaded (no warranty)
/obj/effect/mapping_helpers/atom_injector/LateInitialize()
	if(!check_validity())
		return
	var/turf/target_turf = get_turf(src)
	var/matches_found = 0
	for(var/atom/atom_on_turf as anything in target_turf.get_all_contents())
		if(atom_on_turf == src)
			continue
		if(target_name && atom_on_turf.name != target_name)
			continue
		if(target_type && !istype(atom_on_turf, target_type))
			continue
		inject(atom_on_turf)
		matches_found++
		if(first_match_only)
			qdel(src)
			return
	if(!matches_found)
		stack_trace(generate_stack_trace())
	qdel(src)

///Checks if whatever we are trying to inject with is valid
/obj/effect/mapping_helpers/atom_injector/proc/check_validity()
	return TRUE

///Injects our stuff into the atom
/obj/effect/mapping_helpers/atom_injector/proc/inject(atom/target)
	return

///Generates text for our stack trace
/obj/effect/mapping_helpers/atom_injector/proc/generate_stack_trace()
	. = "[name] found no targets at ([x], [y], [z]). First Match Only: [first_match_only ? "true" : "false"] target type: [target_type] | target name: [target_name]"

/obj/effect/mapping_helpers/atom_injector/obj_flag
	name = "Obj Flag Injector"
	icon_state = "objflag_helper"
	var/inject_flags = NONE

/obj/effect/mapping_helpers/atom_injector/obj_flag/inject(atom/target)
	if(!isobj(target))
		return
	var/obj/obj_target = target
	obj_target.obj_flags |= inject_flags

///This helper applies components to things on the map directly.
/obj/effect/mapping_helpers/atom_injector/component_injector
	name = "Component Injector"
	icon_state = "component"
	///Typepath of the component.
	var/component_type
	///Arguments for the component.
	var/list/component_args = list()

/obj/effect/mapping_helpers/atom_injector/component_injector/check_validity()
	if(!ispath(component_type, /datum/component))
		CRASH("Wrong component type in [type] - [component_type] is not a component")
	return TRUE

/obj/effect/mapping_helpers/atom_injector/component_injector/inject(atom/target)
	var/arguments = list(component_type)
	arguments += component_args
	target._AddComponent(arguments)

/obj/effect/mapping_helpers/atom_injector/component_injector/generate_stack_trace()
	. = ..()
	. += " | component type: [component_type] | component arguments: [list2params(component_args)]"

///This helper applies elements to things on the map directly.
/obj/effect/mapping_helpers/atom_injector/element_injector
	name = "Element Injector"
	icon_state = "element"
	///Typepath of the element.
	var/element_type
	///Arguments for the element.
	var/list/element_args = list()

/obj/effect/mapping_helpers/atom_injector/element_injector/check_validity()
	if(!ispath(element_type, /datum/element))
		CRASH("Wrong element type in [type] - [element_type] is not a element")
	return TRUE

/obj/effect/mapping_helpers/atom_injector/element_injector/inject(atom/target)
	var/arguments = list(element_type)
	arguments += element_args
	target._AddElement(arguments)

/obj/effect/mapping_helpers/atom_injector/element_injector/generate_stack_trace()
	. = ..()
	. += " | element type: [element_type] | element arguments: [list2params(element_args)]"

///This helper applies traits to things on the map directly.
/obj/effect/mapping_helpers/atom_injector/trait_injector
	name = "Trait Injector"
	icon_state = "trait"
	///Name of the trait, in the lower-case text (NOT the upper-case define) form.
	var/trait_name

/obj/effect/mapping_helpers/atom_injector/trait_injector/check_validity()
	if(!istext(trait_name))
		CRASH("Wrong trait in [type] - [trait_name] is not a trait")
	if(!GLOB.trait_name_map)
		GLOB.trait_name_map = generate_trait_name_map()
	if(!GLOB.trait_name_map.Find(trait_name))
		stack_trace("Possibly wrong trait in [type] - [trait_name] is not a trait in the global trait list")
	return TRUE

/obj/effect/mapping_helpers/atom_injector/trait_injector/inject(atom/target)
	ADD_TRAIT(target, trait_name, MAPPING_HELPER_TRAIT)

/obj/effect/mapping_helpers/atom_injector/trait_injector/generate_stack_trace()
	. = ..()
	. += " | trait name: [trait_name]"

///Fetches an external dmi and applies to the target object
/obj/effect/mapping_helpers/atom_injector/custom_icon
	name = "Custom Icon Injector"
	icon_state = "icon"
	///This is the var that will be set with the fetched icon. In case you want to set some secondary icon sheets like inhands and such.
	var/target_variable = "icon"
	///This should return raw dmi in response to http get request. For example: "https://github.com/tgstation/SS13-sprites/raw/master/mob/medu.dmi?raw=true"
	var/icon_url
	///The icon file we fetched from the http get request.
	var/icon_file

/obj/effect/mapping_helpers/atom_injector/custom_icon/check_validity()
	var/static/icon_cache = list()
	var/static/query_in_progress = FALSE //We're using a single tmp file so keep it linear.
	if(query_in_progress)
		UNTIL(!query_in_progress)
	if(icon_cache[icon_url])
		icon_file = icon_cache[icon_url]
		return TRUE
	log_asset("Custom Icon Helper fetching dmi from: [icon_url]")
	var/datum/http_request/request = new()
	var/file_name = "tmp/custom_map_icon.dmi"
	request.prepare(RUSTG_HTTP_METHOD_GET, icon_url, "", "", file_name)
	query_in_progress = TRUE
	request.begin_async()
	UNTIL(request.is_complete())
	var/datum/http_response/response = request.into_response()
	if(response.errored || response.status_code != 200)
		query_in_progress = FALSE
		CRASH("Failed to fetch mapped custom icon from url [icon_url], code: [response.status_code], error: [response.error]")
	var/icon/new_icon = new(file_name)
	icon_cache[icon_url] = new_icon
	query_in_progress = FALSE
	icon_file = new_icon
	return TRUE

/obj/effect/mapping_helpers/atom_injector/custom_icon/inject(atom/target)
	if(IsAdminAdvancedProcCall())
		return
	target.vars[target_variable] = icon_file

/obj/effect/mapping_helpers/atom_injector/custom_icon/generate_stack_trace()
	. = ..()
	. += " | target variable: [target_variable] | icon url: [icon_url]"

///Fetches an external sound and applies to the target object
/obj/effect/mapping_helpers/atom_injector/custom_sound
	name = "Custom Sound Injector"
	icon_state = "sound"
	///This is the var that will be set with the fetched sound.
	var/target_variable = "hitsound"
	///This should return raw sound in response to http get request. For example: "https://github.com/DaedalusDock/Gameserver/blob/master/sound/misc/bang.ogg?raw=true"
	var/sound_url
	///The sound file we fetched from the http get request.
	var/sound_file

/obj/effect/mapping_helpers/atom_injector/custom_sound/check_validity()
	var/static/sound_cache = list()
	var/static/query_in_progress = FALSE //We're using a single tmp file so keep it linear.
	if(query_in_progress)
		UNTIL(!query_in_progress)
	if(sound_cache[sound_url])
		sound_file = sound_cache[sound_url]
		return TRUE
	log_asset("Custom Sound Helper fetching sound from: [sound_url]")
	var/datum/http_request/request = new()
	var/file_name = "tmp/custom_map_sound.ogg"
	request.prepare(RUSTG_HTTP_METHOD_GET, sound_url, "", "", file_name)
	query_in_progress = TRUE
	request.begin_async()
	UNTIL(request.is_complete())
	var/datum/http_response/response = request.into_response()
	if(response.errored || response.status_code != 200)
		query_in_progress = FALSE
		CRASH("Failed to fetch mapped custom sound from url [sound_url], code: [response.status_code], error: [response.error]")
	var/sound/new_sound = new(file_name)
	sound_cache[sound_url] = new_sound
	query_in_progress = FALSE
	sound_file = new_sound
	return TRUE

/obj/effect/mapping_helpers/atom_injector/custom_sound/inject(atom/target)
	if(IsAdminAdvancedProcCall())
		return
	target.vars[target_variable] = sound_file

/obj/effect/mapping_helpers/atom_injector/custom_sound/generate_stack_trace()
	. = ..()
	. += " | target variable: [target_variable] | sound url: [sound_url]"

/obj/effect/mapping_helpers/dead_body_placer
	name = "Dead Body placer"
	late = TRUE
	icon_state = "deadbodyplacer"
	var/bodycount = 2 //number of bodies to spawn

/obj/effect/mapping_helpers/dead_body_placer/LateInitialize()
	var/area/my_area = get_area(src)
	var/list/trays = list()
	for (var/obj/structure/bodycontainer/morgue/tray as anything in INSTANCES_OF(/obj/structure/bodycontainer/morgue))
		if(get_area(tray) == my_area)
			trays += tray

	if(!trays.len)
		log_mapping("[src] at [x],[y] could not find any morgues.")
		return

	for (var/i = 1 to bodycount)
		var/obj/structure/bodycontainer/morgue/j = pick(trays)
		var/mob/living/carbon/human/h = new /mob/living/carbon/human(j, 1)
		h.death()
		for (var/part in h.processing_organs) //randomly remove organs from each body, set those we keep to be in stasis
			if (prob(40))
				qdel(part)
			else
				var/obj/item/organ/O = part
				O.organ_flags |= ORGAN_FROZEN
		j.update_appearance()
	qdel(src)


//On Ian's birthday, the hop's office is decorated.
/obj/effect/mapping_helpers/ianbirthday
	name = "Ian's Bday Helper"
	late = TRUE
	icon_state = "iansbdayhelper"
	var/balloon_clusters = 2

/obj/effect/mapping_helpers/ianbirthday/LateInitialize()
	if(locate(/datum/holiday/ianbirthday) in SSevents.holidays)
		birthday()
	qdel(src)

/obj/effect/mapping_helpers/ianbirthday/proc/birthday()
	var/area/a = get_area(src)
	var/list/table = list()//should only be one aka the front desk, but just in case...
	var/list/openturfs = list()

	//confetti and a corgi balloon! (and some list stuff for more decorations)
	for(var/turf/T as anything in a.get_contained_turfs())
		if(isopenturf(T))
			new /obj/effect/decal/cleanable/confetti(T)

		if(locate(/obj/structure/bed/dogbed/ian) in T)
			new /obj/item/toy/balloon/corgi(T)
		else
			openturfs += T

		var/table_or_null = locate(/obj/structure/table/reinforced) in T
		if(table_or_null)
			table += table_or_null


	//cake + knife to cut it!
	if(length(table))
		var/turf/food_turf = get_turf(pick(table))
		new /obj/item/knife/kitchen(food_turf)
		var/obj/item/food/cake/birthday/iancake = new(food_turf)
		iancake.desc = "Happy birthday, Ian!"

	//some balloons! this picks an open turf and pops a few balloons in and around that turf, yay.
	for(var/i in 1 to balloon_clusters)
		var/turf/clusterspot = pick_n_take(openturfs)
		new /obj/item/toy/balloon(clusterspot)
		var/balloons_left_to_give = 3 //the amount of balloons around the cluster
		var/list/dirs_to_balloon = GLOB.cardinals.Copy()
		while(balloons_left_to_give > 0)
			balloons_left_to_give--
			var/chosen_dir = pick_n_take(dirs_to_balloon)
			var/turf/balloonstep = get_step(clusterspot, chosen_dir)
			var/placed = FALSE
			if(isopenturf(balloonstep))
				var/obj/item/toy/balloon/B = new(balloonstep)//this clumps the cluster together
				placed = TRUE
				if(chosen_dir == NORTH)
					B.pixel_y -= 10
				if(chosen_dir == SOUTH)
					B.pixel_y += 10
				if(chosen_dir == EAST)
					B.pixel_x -= 10
				if(chosen_dir == WEST)
					B.pixel_x += 10
			if(!placed)
				new /obj/item/toy/balloon(clusterspot)
	//remind me to add wall decor!

/obj/effect/mapping_helpers/ianbirthday/admin//so admins may birthday any room
	name = "generic birthday setup"
	icon_state = "bdayhelper"

/obj/effect/mapping_helpers/ianbirthday/admin/LateInitialize()
	birthday()
	qdel(src)

//Ian, like most dogs, loves a good new years eve party.
/obj/effect/mapping_helpers/iannewyear
	name = "Ian's New Years Helper"
	late = TRUE
	icon_state = "iansnewyrshelper"

/obj/effect/mapping_helpers/iannewyear/LateInitialize()
	if(SSevents.holidays && SSevents.holidays[NEW_YEAR])
		fireworks()
	qdel(src)

/obj/effect/mapping_helpers/iannewyear/proc/fireworks()
	var/area/a = get_area(src)
	var/list/table = list()//should only be one aka the front desk, but just in case...
	var/list/openturfs = list()

	for(var/thing in a.contents)
		if(istype(thing, /obj/structure/table/reinforced))
			table += thing
		else if(isopenturf(thing))
			if(locate(/obj/structure/bed/dogbed/ian) in thing)
				new /obj/item/clothing/head/festive(thing)
				var/obj/item/reagent_containers/food/drinks/bottle/champagne/iandrink = new(thing)
				iandrink.name = "dog champagne"
				iandrink.pixel_y += 8
				iandrink.pixel_x += 8
			else
				openturfs += thing

	var/turf/fireworks_turf = get_turf(pick(table))
	var/obj/item/storage/box/matches/matchbox = new(fireworks_turf)
	matchbox.pixel_y += 8
	matchbox.pixel_x -= 3
	new /obj/item/storage/box/fireworks/dangerous(fireworks_turf) //dangerous version for extra holiday memes.

//lets mappers place notes on airlocks with custom info or a pre-made note from a path
/obj/effect/mapping_helpers/airlock_note_placer
	name = "Airlock Note Placer"
	late = TRUE
	icon_state = "airlocknoteplacer"
	var/note_info //for writing out custom notes without creating an extra paper subtype
	var/note_name //custom note name
	var/note_path //if you already have something wrote up in a paper subtype, put the path here

/obj/effect/mapping_helpers/airlock_note_placer/LateInitialize()
	var/turf/turf = get_turf(src)
	if(note_path && !istype(note_path, /obj/item/paper)) //don't put non-paper in the paper slot thank you
		log_mapping("[src] at [x],[y] had an improper note_path path, could not place paper note.")
		qdel(src)
		return
	if(locate(/obj/machinery/door/airlock) in turf)
		var/obj/machinery/door/airlock/found_airlock = locate(/obj/machinery/door/airlock) in turf
		if(note_path)
			found_airlock.note = note_path
			found_airlock.update_appearance()
			qdel(src)
			return
		if(note_info)
			var/obj/item/paper/paper = new /obj/item/paper(src)
			if(note_name)
				paper.name = note_name
			paper.info = "[note_info]"
			found_airlock.note = paper
			paper.forceMove(found_airlock)
			found_airlock.update_appearance()
			qdel(src)
			return
		log_mapping("[src] at [x],[y] had no note_path or note_info, cannot place paper note.")
		qdel(src)
		return
	log_mapping("[src] at [x],[y] could not find an airlock on current turf, cannot place paper note.")
	qdel(src)

/**
 * ## trapdoor placer!
 *
 * This places an unlinked trapdoor in the tile its on (so someone with a remote needs to link it up first)
 * Admins may spawn this in the round for additional trapdoors if they so desire
 * if YOU want to learn more about trapdoors, read about the component at trapdoor.dm
 * note: this is not a turf subtype because the trapdoor needs the type of the turf to turn back into
 */
/obj/effect/mapping_helpers/trapdoor_placer
	name = "trapdoor placer"
	late = TRUE
	icon_state = "trapdoor"

/obj/effect/mapping_helpers/trapdoor_placer/LateInitialize()
	var/turf/component_target = get_turf(src)
	component_target.AddComponent(/datum/component/trapdoor, starts_open = FALSE)
	qdel(src)

/obj/effect/mapping_helpers/ztrait_injector
	name = "ztrait injector"
	icon_state = "ztrait"
	late = TRUE
	/// List of traits to add to this Z-level.
	var/list/traits_to_add = list()

/obj/effect/mapping_helpers/ztrait_injector/LateInitialize()
	var/datum/space_level/level = SSmapping.z_list[z]
	if(!level || !length(traits_to_add))
		return
	level.traits |= traits_to_add
	SSweather.update_z_level(level) //in case of someone adding a weather for the level, we want SSweather to update for that

/obj/effect/mapping_helpers/circuit_spawner
	name = "circuit spawner"
	icon_state = "circuit"
	/// The shell for the circuit.
	var/atom/movable/circuit_shell
	/// Capacity of the shell.
	var/shell_capacity = SHELL_CAPACITY_VERY_LARGE
	/// The url for the json. Example: "https://pastebin.com/raw/eH7VnP9d"
	var/json_url

/obj/effect/mapping_helpers/circuit_spawner/Initialize(mapload)
	. = ..()
	INVOKE_ASYNC(src, PROC_REF(spawn_circuit))

/obj/effect/mapping_helpers/circuit_spawner/proc/spawn_circuit()
	var/list/errors = list()
	var/obj/item/integrated_circuit/loaded/new_circuit = new(loc)
	var/json_data = load_data()
	new_circuit.load_circuit_data(json_data, errors)
	if(!circuit_shell)
		return
	circuit_shell = new(loc)
	var/datum/component/shell/shell_component = circuit_shell.GetComponent(/datum/component/shell)
	if(shell_component)
		shell_component.shell_flags |= SHELL_FLAG_CIRCUIT_UNMODIFIABLE|SHELL_FLAG_CIRCUIT_UNREMOVABLE
		shell_component.attach_circuit(new_circuit)
	else
		shell_component = circuit_shell.AddComponent(/datum/component/shell, \
			capacity = shell_capacity, \
			shell_flags = SHELL_FLAG_CIRCUIT_UNMODIFIABLE|SHELL_FLAG_CIRCUIT_UNREMOVABLE, \
			starting_circuit = new_circuit, \
			)

/obj/effect/mapping_helpers/circuit_spawner/proc/load_data()
	var/static/json_cache = list()
	var/static/query_in_progress = FALSE //We're using a single tmp file so keep it linear.
	if(query_in_progress)
		UNTIL(!query_in_progress)
	if(json_cache[json_url])
		return json_cache[json_url]
	log_asset("Circuit Spawner fetching json from: [json_url]")
	var/datum/http_request/request = new()
	request.prepare(RUSTG_HTTP_METHOD_GET, json_url, "")
	query_in_progress = TRUE
	request.begin_async()
	UNTIL(request.is_complete())
	var/datum/http_response/response = request.into_response()
	if(response.errored || response.status_code != 200)
		query_in_progress = FALSE
		CRASH("Failed to fetch mapped custom json from url [json_url], code: [response.status_code], error: [response.error]")
	var/json_data = response.body
	json_cache[json_url] = json_data
	query_in_progress = FALSE
	return json_data

//DM Editor 'simplified' maphelpers.
#if defined(SIMPLE_MAPHELPERS)
#define PAINT_PREFIX "s_"
#else
#define PAINT_PREFIX ""
#endif

/obj/effect/mapping_helpers/paint_wall
	name = "Paint Wall Helper"
	icon = 'icons/effects/paint_helpers.dmi'
	icon_state = "paint"
	late = TRUE
	/// What wall (or airlock) paint this helper will apply
	var/wall_paint = null
	/// What stripe paint this helper will apply
	var/stripe_paint = null

/obj/effect/mapping_helpers/paint_wall/LateInitialize()
	for(var/obj/effect/mapping_helpers/paint_wall/paint in loc)
		if(paint == src)
			continue
		WARNING("Duplicate paint helper found at [x], [y], [z]")
		qdel(src)
		return

	var/did_anything = FALSE

	if(istype(loc, /turf/closed/wall))
		var/turf/closed/wall/target_wall = loc
		if(!isnull(wall_paint))
			target_wall.paint_wall(wall_paint)
		if(!isnull(stripe_paint))
			target_wall.paint_stripe(stripe_paint)
		did_anything = TRUE

	else
		var/obj/structure/low_wall/low_wall = locate() in loc
		if(low_wall)
			if(!isnull(wall_paint))
				low_wall.paint_wall(wall_paint)
			if(!isnull(stripe_paint))
				low_wall.paint_stripe(stripe_paint)
			did_anything = TRUE
		else
			var/obj/structure/falsewall/falsewall = locate() in loc
			if(falsewall)
				if(!isnull(wall_paint))
					falsewall.paint_wall(wall_paint)
				if(!isnull(stripe_paint))
					falsewall.paint_stripe(stripe_paint)
				did_anything = TRUE

			else
				var/obj/machinery/door/airlock/airlock = locate() in loc
				if(airlock)
					if(!isnull(wall_paint))
						airlock.airlock_paint = wall_paint
					if(!isnull(stripe_paint))
						airlock.stripe_paint = stripe_paint
					airlock.update_appearance()
					did_anything = TRUE


	if(!did_anything)
		WARNING("Redundant paint helper found at [x], [y], [z]")

	qdel(src)

/obj/effect/mapping_helpers/paint_wall/bridge
	name = "Command Wall Paint"
	wall_paint = PAINT_WALL_COMMAND
	stripe_paint = PAINT_STRIPE_COMMAND
	icon_state = PAINT_PREFIX+"paint_bridge"

/obj/effect/mapping_helpers/paint_wall/medical
	name = "Medical Wall Paint"
	wall_paint = PAINT_WALL_MEDICAL
	stripe_paint = PAINT_STRIPE_MEDICAL
	icon_state = PAINT_PREFIX+"paint_medical"

/obj/effect/mapping_helpers/paint_wall/daedalus
	name = "Daedalus Wall Paint"
	wall_paint = PAINT_WALL_DAEDALUS
	stripe_paint = PAINT_STRIPE_DAEDALUS
	icon_state = PAINT_PREFIX+"paint_daedalus"

/obj/effect/mapping_helpers/paint_wall/priapus
	name = "Priapus Wall Paint"
	wall_paint = PAINT_WALL_PRIAPUS
	stripe_paint = PAINT_STRIPE_PRIAPUS
	icon_state = PAINT_PREFIX+"paint_priapus"

/obj/effect/mapping_helpers/paint_wall/centcom
	name = "Central Command Wall Paint"
	wall_paint = PAINT_WALL_CENTCOM
	stripe_paint = PAINT_STRIPE_CENTCOM
	icon_state = PAINT_PREFIX+"paint_centcom"


/obj/effect/mapping_helpers/broken_floor
	name = "broken floor"
	icon = 'icons/turf/damage.dmi'
	icon_state = "damaged1"
	late = TRUE

/obj/effect/mapping_helpers/broken_floor/LateInitialize()
	var/turf/open/floor/floor = get_turf(src)
	floor.break_tile()
	qdel(src)

/obj/effect/mapping_helpers/burnt_floor
	name = "burnt floor"
	icon = 'icons/turf/damage.dmi'
	icon_state = "floorscorched1"
	late = TRUE

/obj/effect/mapping_helpers/burnt_floor/LateInitialize()
	var/turf/open/floor/floor = get_turf(src)
	floor.burn_tile()
	qdel(src)


/obj/effect/mapping_helpers/lightsout
	name = "lights-out helper"
	icon_state = "lightsout"

/obj/effect/mapping_helpers/lightsout/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_LATELOAD

/obj/effect/mapping_helpers/lightsout/LateInitialize()
	var/area/A = get_area(src)
	A.lightswitch = FALSE
	A.power_change()
	qdel(src)

// -----------
// Smart Cable
// -----------
/obj/structure/cable/smart_cable
	icon_state = "mapping_helper"
	color = "yellow"
	var/connect_to_same_color = TRUE
	var/has_become_cable = FALSE

/obj/structure/cable/smart_cable/Initialize(mapload)
	spawn_cable()
	return ..()

/obj/structure/cable/smart_cable/proc/spawn_cable()
	var/passed_directions = NONE
	var/dir_count = 0
	var/turf/my_turf = loc
	var/obj/machinery/power/terminal/terminal_on_myturf = locate() in my_turf
	var/obj/machinery/power/smes/smes_on_myturf = locate() in my_turf
	for(var/cardinal in GLOB.cardinals)
		var/turf/step_turf = get_step(my_turf, cardinal)
		for(var/obj/structure/cable/smart_cable/cable_spawner in step_turf)
			if((connect_to_same_color && cable_spawner.connect_to_same_color) && (color != cable_spawner.color))
				continue
			// If we are on a terminal, and there's an SMES in our step direction, disregard the connection
			if(terminal_on_myturf)
				var/obj/machinery/power/smes/smes = locate() in step_turf
				if(smes)
					var/obj/machinery/power/apc/apc_on_myturf = locate() in my_turf
					// Unless there's an APC on our turf (which means it's a terminal for the APC, and not for the SMES)
					if(!apc_on_myturf)
						continue
			// If we are on an SMES, and there's a terminal on our step direction, disregard the connection
			if(smes_on_myturf)
				var/obj/machinery/power/terminal/terminal = locate() in step_turf
				if(terminal)
					var/obj/machinery/power/apc/apc_on_myturf = locate() in step_turf
					// Unless there's an APC on the step turf (which means it's a terminal for the APC, and not for the SMES)
					if(!apc_on_myturf)
						continue
			dir_count++
			passed_directions |= cardinal
	if(dir_count == 0)
		WARNING("Smart cable mapping helper failed to spawn, connected to 0 directions, at [loc.x],[loc.y],[loc.z]")
		return
	switch(dir_count)
		if(1)
			//We spawn one cable with an open knot
			spawn_cable_for_direction(passed_directions)
		if(2)
			//We spawn one cable that connects with 2 directions
			spawn_cable_for_direction(passed_directions)
		if(3)
			//We spawn two cables, connecting with 3 directions total
			spawn_cables_for_directions(passed_directions)
		if(4)
			//We spawn four cables, connecting with 4 directions total
			spawn_cables_for_directions(passed_directions)
	// if we want a knot, and we connect with more than 1 direction, spawn an extra open knotted cable connecting with any of the directions
	if(dir_count > 1 && knot_desirable())
		spawn_knotty_connecting_to_directions(passed_directions)

/obj/structure/cable/smart_cable/proc/knot_desirable()
	var/turf/my_turf = loc
	var/obj/machinery/power/terminal/terminal = locate() in my_turf
	if(terminal)
		return TRUE
	var/obj/structure/grille/grille = locate() in my_turf
	if(grille)
		return TRUE
	var/obj/machinery/power/smes/smes = locate() in my_turf
	if(smes)
		return TRUE
	var/obj/machinery/power/apc/apc = locate() in my_turf
	if(apc)
		return TRUE
	var/obj/machinery/power/emitter/emitter = locate() in my_turf
	if(emitter)
		return TRUE
	return FALSE

/obj/structure/cable/smart_cable/proc/spawn_cable_for_direction(direction)
	var/obj/structure/cable/cable
	if(has_become_cable)
		cable = new(loc)
	else
		cable = src
		has_become_cable = TRUE
	cable.color = color
	cable.set_directions(direction)

/obj/structure/cable/smart_cable/proc/spawn_cables_for_directions(directions)
	if((directions & NORTH) && (directions & EAST))
		spawn_cable_for_direction(NORTH|EAST)
	if((directions & EAST) && (directions & SOUTH))
		spawn_cable_for_direction(EAST|SOUTH)
	if((directions & SOUTH) && (directions & WEST))
		spawn_cable_for_direction(SOUTH|WEST)
	if((directions & WEST) && (directions & NORTH))
		spawn_cable_for_direction(WEST|NORTH)

/obj/structure/cable/smart_cable/proc/spawn_knotty_connecting_to_directions(directions)
	if(directions & NORTH)
		spawn_cable_for_direction(NORTH)
		return
	if(directions & SOUTH)
		spawn_cable_for_direction(SOUTH)
		return
	if(directions & EAST)
		spawn_cable_for_direction(EAST)
		return
	if(directions & WEST)
		spawn_cable_for_direction(WEST)
		return

/obj/structure/cable/smart_cable/color
	connect_to_same_color = TRUE

/obj/structure/cable/smart_cable/color/yellow
	color = "yellow"

/obj/structure/cable/smart_cable/color/red
	color = "red"

/obj/structure/cable/smart_cable/color/blue
	color = "blue"

/obj/structure/cable/smart_cable/color_connector
	connect_to_same_color = FALSE

/obj/structure/cable/smart_cable/color_connector/yellow
	color = "yellow"

/obj/structure/cable/smart_cable/color_connector/red
	color = "red"

/obj/structure/cable/smart_cable/color_connector/blue
	color = "blue"
