#define DRYING_TIME 5 * 60*10 //for 1 unit of depth in puddle (amount var)

#define BLOOD_MERGE_SPLATTER (1<<0)
#define BLOOD_MERGE_POOL (1<<1)
#define BLOOD_MERGE_FOOTPRINTS (1<<2)
#define BLOOD_MERGE_DRIP (1<<3)
#define BLOOD_MERGE_SQUIRT (1<<4)

/obj/effect/decal/cleanable/blood
	name = "blood"
	desc = "It's red and gooey. Perhaps it's the chef's cooking?"
	icon = 'icons/effects/blood.dmi'
	icon_state = "floor1"
	appearance_flags = TILE_BOUND|PIXEL_SCALE|LONG_GLIDE|NO_CLIENT_COLOR

	random_icon_states = list("floor1", "floor2", "floor3", "floor4", "floor5", "floor6", "floor7")
	beauty = -100

	clean_type = CLEAN_TYPE_BLOOD
	mergeable_decal = FALSE //We handle this on our own.

	bloodiness = BLOOD_AMOUNT_PER_DECAL

	/// What decals can we merge into
	var/blood_merge_into_other = BLOOD_MERGE_POOL
	/// What decals can merge into us
	var/blood_merge_into_us = BLOOD_MERGE_POOL | BLOOD_MERGE_SPLATTER

	var/spook_factor = SPOOK_AMT_BLOOD_SPLATTER

	var/smell_intensity =  INTENSITY_STRONG
	var/smell_name = "blood"

	var/blood_print = null

	var/should_dry = TRUE
	/// How long should it take for blood to dry?
	var/dry_duration = 10 MINUTES
	var/dryname = "dried blood" //when the blood lasts long enough, it becomes dry and gets a new name
	var/drydesc = "It's dry and crusty. Someone isn't doing their job."
	/// World.time + dry_duration
	var/drytime = 0
	var/is_dry = FALSE

/obj/effect/decal/cleanable/blood/Initialize(mapload, list/datum/pathogen/diseases, list/blood_dna = list("Unknown DNA" = random_blood_type()))
	. = ..()
	if((. == INITIALIZE_HINT_QDEL) || !should_dry)
		return

	if(isturf(loc))
		for(var/obj/effect/decal/cleanable/blood/B in loc)
			if(QDELETED(B) || B == src)
				continue

			if(can_merge_into(B))
				merge_into(B)
				return INITIALIZE_HINT_QDEL

			if(B.can_merge_into(src))
				B.merge_into(src)
				qdel(B)

	if(bloodiness)
		start_drying()
		AddComponent(/datum/component/smell, smell_intensity, SCENT_ODOR, smell_name, 3)
	else
		dry()

/obj/effect/decal/cleanable/blood/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/effect/decal/cleanable/blood/process()
	if(world.time > drytime)
		dry()

/obj/effect/decal/cleanable/blood/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/effect/decal/cleanable/blood/add_blood_DNA(list/dna)
	. = ..()
	if(dna)
		blood_color = get_blood_dna_color(dna)
		if(!is_dry)
			color = blood_color

/obj/effect/decal/cleanable/blood/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(ishuman(user) && blood_DNA_length())
		var/mob/living/carbon/human/H = user
		H.add_blood_DNA_to_items(return_blood_DNA(), ITEM_SLOT_GLOVES)
		H.visible_message(span_notice("[user.name] runs [H.p_their()] fingers through [src]."))

/obj/effect/decal/cleanable/blood/proc/get_timer()
	drytime = world.time + dry_duration

/obj/effect/decal/cleanable/blood/proc/start_drying()
	get_timer()
	START_PROCESSING(SSobj, src)

///This is what actually "dries" the blood. Returns true if it's all out of blood to dry, and false otherwise
/obj/effect/decal/cleanable/blood/proc/dry()
	if(reagents.get_reagent_amount(/datum/reagent/blood) > 20)
		reagents.remove_reagent(/datum/reagent/blood, BLOOD_AMOUNT_PER_DECAL)
		get_timer()
		return FALSE
	else
		name = dryname
		desc = drydesc
		reagents.remove_reagent(/datum/reagent/blood, INFINITY, , include_subtypes = TRUE)
		var/list/temp_color = rgb2hsv(color || COLOR_WHITE)
		color = hsv2rgb(temp_color[1], temp_color[2], max(temp_color[3] - 100, 0))
		qdel(GetComponent(/datum/component/smell))
		if(spook_factor)
			AddComponent(/datum/component/spook_factor, spook_factor)
		is_dry = TRUE
		return PROCESS_KILL

/obj/effect/decal/cleanable/blood/can_merge_into(obj/effect/decal/cleanable/blood/other, force)
	if(isnull(other.blood_merge_into_us) || isnull(blood_merge_into_other))
		return FALSE

	if(other.blood_merge_into_us & blood_merge_into_other)
		return TRUE

	return FALSE

/obj/effect/decal/cleanable/blood/merge_into(obj/effect/decal/cleanable/merger)
	. = ..()
	merger.add_blood_DNA(return_blood_DNA())
	if (bloodiness)
		merger.bloodiness = min((merger.bloodiness + bloodiness), BLOOD_AMOUNT_PER_DECAL)

/obj/effect/decal/cleanable/blood/old
	reagent_amount = 0
	icon_state = "floor1-old"

/obj/effect/decal/cleanable/blood/old/Initialize(mapload, list/datum/pathogen/diseases)
	add_blood_DNA(list("Non-human DNA" = random_blood_type())) // Needs to happen before ..()
	. = ..()
	AddComponent(/datum/component/spook_factor, SPOOK_AMT_BLOOD_SPLATTER)

/obj/effect/decal/cleanable/blood/splatter
	icon_state = "gibbl1"
	random_icon_states = list("gibbl1", "gibbl2", "gibbl3", "gibbl4", "gibbl5")

	blood_merge_into_other = BLOOD_MERGE_SPLATTER
	blood_merge_into_us = ALL

/obj/effect/decal/cleanable/blood/splatter/over_window // special layer/plane set to appear on windows
	layer = ABOVE_WINDOW_LAYER
	plane = GAME_PLANE
	turf_loc_check = FALSE
	alpha = 180

	blood_merge_into_other = null
	blood_merge_into_us = null

/obj/effect/decal/cleanable/blood/splatter/over_window/can_merge_into(obj/effect/decal/cleanable/blood/other)
	if(istype(other, /obj/effect/decal/cleanable/blood/splatter/over_window))
		return TRUE

	return ..()

/obj/effect/decal/cleanable/blood/tracks
	icon_state = "tracks"
	desc = "They look like tracks left by wheels."
	random_icon_states = null
	beauty = -50
	dryname = "dried tracks"
	drydesc = "Some old bloody tracks left by wheels. Machines are evil, perhaps."
	smell_intensity = INTENSITY_SUBTLE

/obj/effect/decal/cleanable/blood/trail_holder
	name = "blood"
	icon = 'icons/effects/blood.dmi'
	icon_state = null
	random_icon_states = null
	desc = "Your instincts say you shouldn't be following these."
	beauty = -50

	blood_merge_into_us = null
	blood_merge_into_other = null

	var/list/existing_dirs = list()

/obj/effect/decal/cleanable/blood/gibs
	name = "gibs"
	desc = "They look bloody and gruesome."
	icon = 'icons/effects/blood.dmi'
	icon_state = "gib1"

	layer = LOW_OBJ_LAYER
	plane = GAME_PLANE
	random_icon_states = list("gib1", "gib2", "gib3", "gib4", "gib5", "gib6")
	turf_loc_check = FALSE

	dryname = "rotting gibs"
	drydesc = "They look bloody and gruesome while some terrible smell fills the air."
	decal_reagent = /datum/reagent/liquidgibs
	reagent_amount = 5

	smell_intensity = INTENSITY_OVERPOWERING
	smell_name = "viscera"

	blood_merge_into_other = null
	blood_merge_into_us = null

	///Information about the diseases our streaking spawns
	var/list/streak_diseases

/obj/effect/decal/cleanable/blood/gibs/Initialize(mapload, list/datum/pathogen/diseases)
	. = ..()
	RegisterSignal(src, COMSIG_MOVABLE_PIPE_EJECTING, PROC_REF(on_pipe_eject))
	AddComponent(/datum/component/spook_factor, SPOOK_AMT_BLOOD_STREAK)
	var/image/gib_overlay = image(icon, "[icon_state]-overlay")
	gib_overlay.appearance_flags = RESET_COLOR
	add_overlay(gib_overlay)

/obj/effect/decal/cleanable/blood/gibs/can_merge_into(obj/effect/decal/cleanable/C)
	return FALSE //Never fail to place us

/obj/effect/decal/cleanable/blood/gibs/dry()
	. = ..()
	if(!.)
		return
	AddComponent(/datum/component/rot, 0, 5 MINUTES, 0.7)

/obj/effect/decal/cleanable/blood/gibs/ex_act(severity, target)
	return FALSE

/obj/effect/decal/cleanable/blood/gibs/on_entered(datum/source, atom/movable/L)
	if(isliving(L) && has_gravity(loc))
		playsound(loc, 'sound/effects/gib_step.ogg', HAS_TRAIT(L, TRAIT_LIGHT_STEP) ? 20 : 50, TRUE)
	. = ..()

/obj/effect/decal/cleanable/blood/gibs/proc/on_pipe_eject(atom/source, direction)
	SIGNAL_HANDLER

	var/list/dirs
	if(direction)
		dirs = list(direction, turn(direction, -45), turn(direction, 45))
	else
		dirs = GLOB.alldirs.Copy()

	streak(dirs)

/obj/effect/decal/cleanable/blood/gibs/proc/streak(list/directions, mapload=FALSE)
	SEND_SIGNAL(src, COMSIG_GIBS_STREAK, directions, streak_diseases)
	var/direction = pick(directions)
	streak_diseases = list()
	var/delay = 2
	var/range = pick(0, 200; 1, 150; 2, 50; 3, 17; 50) //the 3% chance of 50 steps is intentional and played for laughs.
	if(!step_to(src, get_step(src, direction), 0))
		return
	if(mapload)
		for (var/i = 1, i < range, i++)
			new /obj/effect/decal/cleanable/blood/splatter(loc, streak_diseases)
			if (!step_to(src, get_step(src, direction), 0))
				break
		return

	var/datum/move_loop/loop = SSmove_manager.move_to(src, get_step(src, direction), delay = delay, timeout = range * delay, priority = MOVEMENT_ABOVE_SPACE_PRIORITY)
	RegisterSignal(loop, COMSIG_MOVELOOP_POSTPROCESS, PROC_REF(spread_movement_effects))

/obj/effect/decal/cleanable/blood/gibs/proc/spread_movement_effects(datum/move_loop/has_target/source)
	SIGNAL_HANDLER
	new /obj/effect/decal/cleanable/blood/splatter(loc, streak_diseases)

/obj/effect/decal/cleanable/blood/gibs/up
	icon_state = "gibup1"
	random_icon_states = list("gib1", "gib2", "gib3", "gib4", "gib5", "gib6","gibup1","gibup1","gibup1")

/obj/effect/decal/cleanable/blood/gibs/down
	icon_state = "gibdown1"
	random_icon_states = list("gib1", "gib2", "gib3", "gib4", "gib5", "gib6","gibdown1","gibdown1","gibdown1")

/obj/effect/decal/cleanable/blood/gibs/body
	icon_state = "gibtorso"
	random_icon_states = list("gibhead", "gibtorso")

/obj/effect/decal/cleanable/blood/gibs/torso
	icon_state = "gibtorso"
	random_icon_states = null

/obj/effect/decal/cleanable/blood/gibs/limb
	icon_state = "gibleg"
	random_icon_states = list("gibleg", "gibarm")

/obj/effect/decal/cleanable/blood/gibs/core
	icon_state = "gibmid1"
	random_icon_states = list("gibmid1", "gibmid2", "gibmid3")

/obj/effect/decal/cleanable/blood/gibs/old
	name = "old rotting gibs"
	desc = "Space Jesus, why didn't anyone clean this up? They smell terrible."
	icon_state = "gib1-old"
	should_dry = FALSE
	dryname = "old rotting gibs"
	drydesc = "Space Jesus, why didn't anyone clean this up? They smell terrible."

	reagent_amount = 0

/obj/effect/decal/cleanable/blood/gibs/old/Initialize(mapload, list/datum/pathogen/diseases)
	. = ..()
	setDir(pick(1,2,4,8))
	add_blood_DNA(list("Non-human DNA" = random_blood_type()))
	dry()

/obj/effect/decal/cleanable/blood/drip
	name = "drips of blood"
	desc = "It's red."
	icon = 'icons/effects/drip.dmi'
	icon_state = "5" //using drip5 since the others tend to blend in with pipes & wires.
	random_icon_states = list("1","2","3", "4","5")

	color = COLOR_HUMAN_BLOOD

	blood_merge_into_us = BLOOD_MERGE_DRIP
	blood_merge_into_other = BLOOD_MERGE_DRIP | BLOOD_MERGE_POOL | BLOOD_MERGE_SPLATTER

	bloodiness = BLOOD_AMOUNT_PER_DECAL / 10
	dryname = "drips of blood"
	drydesc = "It's red."
	smell_intensity = INTENSITY_SUBTLE
	dry_duration = 4 MINUTES

	reagent_amount = BLOOD_AMOUNT_PER_DECAL / 10
	spook_factor = SPOOK_AMT_BLOOD_DROP

	/// Keeps track of how many drops of blood this decal has. See blood.dm
	var/drips = 1

/obj/effect/decal/cleanable/blood/drip/merge_into(obj/effect/decal/cleanable/blood/other)
	var/is_drip = istype(other, /obj/effect/decal/cleanable/blood/drip)

	if(!is_drip)
		return ..()

	var/obj/effect/decal/cleanable/blood/drip/other_drip = other
	if(other_drip.drips < 5)
		other_drip.add_blood_DNA(return_blood_DNA())
		other_drip.increment_drips()
		return

	var/temp_blood_dna = other_drip.return_blood_DNA()
	var/turf/spawn_loc = other.loc
	qdel(other)//the drip is replaced by a biFgger splatter
	new /obj/effect/decal/cleanable/blood/splatter(spawn_loc, null, return_blood_DNA() + temp_blood_dna)

/obj/effect/decal/cleanable/blood/drip/can_bloodcrawl_in()
	return TRUE

/obj/effect/decal/cleanable/blood/drip/proc/increment_drips()
	PRIVATE_PROC(TRUE)
	var/image/I = image(icon, pick(random_icon_states), pixel_x = rand(-5, 5), pixel_y = rand(-5, 5))
	add_overlay(I)
	drips++

//BLOODY FOOTPRINTS
/obj/effect/decal/cleanable/blood/footprints
	name = "footprints"
	desc = "WHOSE FOOTPRINTS ARE THESE?"
	icon = 'icons/effects/footprints.dmi'
	icon_state = "blood1"
	random_icon_states = null

	blood_merge_into_us = BLOOD_MERGE_FOOTPRINTS
	blood_merge_into_other = BLOOD_MERGE_FOOTPRINTS | BLOOD_MERGE_POOL | BLOOD_MERGE_SPLATTER

	var/entered_dirs = 0
	var/exited_dirs = 0

	/// List of shoe or other clothing that covers feet types that have made footprints here.
	var/list/shoe_types = list()

	dryname = "dried footprints"
	drydesc = "HMM... SOMEONE WAS HERE!"
	smell_intensity = INTENSITY_SUBTLE

/obj/effect/decal/cleanable/blood/footprints/Initialize(
	mapload,
	list/datum/pathogen/diseases,
	list/blood_dna = list("Unknown DNA" = random_blood_type()),
	blood_print
	)
	src.blood_print = blood_print
	. = ..()
	icon_state = "" //All of the footprint visuals come from overlays
	if(mapload)
		entered_dirs |= dir //Keep the same appearance as in the map editor
	update_appearance(mapload ? (ALL) : UPDATE_NAME)

//Rotate all of the footprint directions too
/obj/effect/decal/cleanable/blood/footprints/setDir(newdir)
	if(dir == newdir)
		return ..()

	var/ang_change = dir2angle(newdir) - dir2angle(dir)
	var/old_entered_dirs = entered_dirs
	var/old_exited_dirs = exited_dirs
	entered_dirs = 0
	exited_dirs = 0

	for(var/Ddir in GLOB.cardinals)
		if(old_entered_dirs & Ddir)
			entered_dirs |= angle2dir_cardinal(dir2angle(Ddir) + ang_change)
		if(old_exited_dirs & Ddir)
			exited_dirs |= angle2dir_cardinal(dir2angle(Ddir) + ang_change)

	update_appearance()
	return ..()

/obj/effect/decal/cleanable/blood/footprints/update_name(updates)
	switch(blood_print)
		if(BLOOD_PRINT_CLAWS)
			name = "bloody claw tracks"
		if(BLOOD_PRINT_HUMAN)
			name = "bloody feet tracks"
		if(BLOOD_PRINT_PAWS)
			name = "bloody paw tracks"
	return ..()

/obj/effect/decal/cleanable/blood/footprints/update_icon()
	. = ..()
	color = blood_color
	alpha = min(BLOODY_FOOTPRINT_BASE_ALPHA + (255 - BLOODY_FOOTPRINT_BASE_ALPHA) * reagents.get_reagent_amount(/datum/reagent/blood) / (BLOOD_ITEM_MAX / 2), 255)

/obj/effect/decal/cleanable/blood/footprints/update_overlays()
	. = ..()
	//Cache of bloody footprint images
	//Key:
	//"entered-[blood_print]-[blood_color]-[dir_of_image]"
	//or: "exited-[blood_print]-[blood_color]--[dir_of_image]"

	var/static/list/bloody_footprints_cache = list()
	for(var/Ddir in GLOB.cardinals)
		if(entered_dirs & Ddir)
			var/image/bloodstep_overlay = bloody_footprints_cache["entered-[blood_print]-[blood_color]-[Ddir]"]
			if(!bloodstep_overlay)
				bloody_footprints_cache["entered-[blood_print]-[blood_color]-[Ddir]"] = bloodstep_overlay = image(icon, "[blood_print]1", dir = Ddir)
			. += bloodstep_overlay

		if(exited_dirs & Ddir)
			var/image/bloodstep_overlay = bloody_footprints_cache["exited-[blood_print]-[blood_color]-[Ddir]"]
			if(!bloodstep_overlay)
				bloody_footprints_cache["exited-[blood_print]-[blood_color]-[Ddir]"] = bloodstep_overlay = image(icon, "[blood_print]2", dir = Ddir)
			. += bloodstep_overlay


/obj/effect/decal/cleanable/blood/footprints/examine(mob/user)
	. = ..()
	if(!shoe_types.len)
		return

	. += span_notice("You recognise the footprints as belonging to:")
	for(var/sole in shoe_types)
		var/obj/item/clothing/item = sole
		var/article = initial(item.gender) == PLURAL ? "Some" : "A"
		. += span_notice("* [icon2html(initial(item.icon), user, initial(item.icon_state))] [article] <B>[initial(item.name)]</B>.")

/obj/effect/decal/cleanable/blood/footprints/can_merge_into(obj/effect/decal/cleanable/blood/C)
	if(blood_color != C.blood_color || blood_print != C.blood_print) //We only replace footprints of the same type as us
		return FALSE
	return ..()

/obj/effect/decal/cleanable/blood/hitsplatter
	name = "blood splatter"
	pass_flags = PASSTABLE | PASSGRILLE
	icon_state = "hitsplatter1"
	random_icon_states = list("hitsplatter1", "hitsplatter2", "hitsplatter3")
	smell_intensity = INTENSITY_SUBTLE

	blood_merge_into_other = null
	blood_merge_into_us = null

	/// The turf we just came from, so we can back up when we hit a wall
	var/turf/prev_loc
	/// The cached info about the blood
	var/list/blood_dna_info
	/// Skip making the final blood splatter when we're done, like if we're not in a turf
	var/skip = FALSE
	/// How many tiles/items/people we can paint red
	var/splatter_strength = 3
	/// Insurance so that we don't keep moving once we hit a stoppoint
	var/hit_endpoint = FALSE

/obj/effect/decal/cleanable/blood/hitsplatter/Initialize(mapload, splatter_strength, list/blood_dna_info)
	. = ..()
	prev_loc = loc //Just so we are sure prev_loc exists
	if(splatter_strength)
		src.splatter_strength = splatter_strength

/obj/effect/decal/cleanable/blood/hitsplatter/Destroy()
	if(isturf(loc) && !skip)
		playsound(src, pick('sound/effects/wounds/splatter.ogg', 'sound/effects/wounds/splatter2.ogg'), 60, TRUE, -1)
		if(blood_dna_info)
			loc.add_blood_DNA(blood_dna_info)
	return ..()

/// Set the splatter up to fly through the air until it rounds out of steam or hits something
/obj/effect/decal/cleanable/blood/hitsplatter/proc/fly_towards(turf/target_turf, range)
	var/delay = 2
	var/datum/move_loop/loop = SSmove_manager.move_towards(src, target_turf, delay, timeout = delay * range, priority = MOVEMENT_ABOVE_SPACE_PRIORITY, flags = MOVEMENT_LOOP_START_FAST)
	RegisterSignal(loop, COMSIG_MOVELOOP_PREPROCESS_CHECK, PROC_REF(pre_move))
	RegisterSignal(loop, COMSIG_MOVELOOP_POSTPROCESS, PROC_REF(post_move))
	RegisterSignal(loop, COMSIG_PARENT_QDELETING, PROC_REF(loop_done))

/obj/effect/decal/cleanable/blood/hitsplatter/proc/pre_move(datum/move_loop/source)
	SIGNAL_HANDLER
	prev_loc = loc

/obj/effect/decal/cleanable/blood/hitsplatter/proc/post_move(datum/move_loop/source)
	SIGNAL_HANDLER
	var/turf/T = get_turf(src)

	for(var/atom/movable/iter_atom as anything in T)
		if(hit_endpoint)
			return
		if(splatter_strength <= 0)
			break
		if(QDELETED(iter_atom))
			return
		if(isitem(iter_atom))
			iter_atom.add_blood_DNA(blood_dna_info)
			splatter_strength--

		else if(ishuman(iter_atom))
			var/mob/living/carbon/human/splashed_human = iter_atom
			if(!splashed_human.is_eyes_covered())
				splashed_human.blur_eyes(3)
				to_chat(splashed_human, span_alert("You're blinded by a spray of blood!"))
			splashed_human.add_blood_DNA_to_items(blood_dna_info)
			splatter_strength--

	if(splatter_strength <= 0) // we used all the puff so we delete it.
		qdel(src)
		return

	new /obj/effect/decal/cleanable/blood/squirt(T, get_dir(prev_loc, loc), blood_dna_info)

/obj/effect/decal/cleanable/blood/hitsplatter/proc/loop_done(datum/source)
	SIGNAL_HANDLER
	if(!QDELETED(src))
		qdel(src)

/obj/effect/decal/cleanable/blood/hitsplatter/Bump(atom/bumped_atom)
	if(!iswallturf(bumped_atom) && !istype(bumped_atom, /obj/structure/window))
		qdel(src)
		return

	if(istype(bumped_atom, /obj/structure/window))
		var/obj/structure/window/bumped_window = bumped_atom
		if(!bumped_window.fulltile)
			qdel(src)
			return

	hit_endpoint = TRUE
	if(isturf(prev_loc))
		var/turf/T = get_turf(bumped_atom)
		new /obj/effect/decal/cleanable/blood/squirt(T, get_dir(prev_loc, T), blood_dna_info)
		abstract_move(bumped_atom)
		skip = TRUE
		//Adjust pixel offset to make splatters appear on the wall
		if(istype(bumped_atom, /obj/structure/window))
			land_on_window(bumped_atom)
		else
			var/obj/effect/decal/cleanable/blood/splatter/over_window/final_splatter = new(prev_loc, null, blood_dna_info)
			final_splatter.pixel_x = (dir == EAST ? 32 : (dir == WEST ? -32 : 0))
			final_splatter.pixel_y = (dir == NORTH ? 32 : (dir == SOUTH ? -32 : 0))
	else // This will only happen if prev_loc is not even a turf, which is highly unlikely.
		abstract_move(bumped_atom)
		qdel(src)

/// A special case for hitsplatters hitting windows, since those can actually be moved around, store it in the window and slap it in the vis_contents
/obj/effect/decal/cleanable/blood/hitsplatter/proc/land_on_window(obj/structure/window/the_window)
	if(!the_window.fulltile)
		return
	var/obj/effect/decal/cleanable/blood/splatter/over_window/final_splatter = new(the_window, null, blood_dna_info)
	the_window.vis_contents += final_splatter
	the_window.bloodied = TRUE
	qdel(src)

/obj/effect/decal/cleanable/blood/squirt
	name = "blood trail"
	icon_state = "squirt"
	random_icon_states = null
	color = COLOR_HUMAN_BLOOD

	blood_merge_into_us = BLOOD_MERGE_SQUIRT
	blood_merge_into_other = BLOOD_MERGE_SQUIRT | BLOOD_MERGE_POOL | BLOOD_MERGE_SPLATTER

	smell_intensity = INTENSITY_SUBTLE
	spook_factor = SPOOK_AMT_BLOOD_STREAK

/obj/effect/decal/cleanable/blood/squirt/Initialize(mapload, direction, list/blood_dna)
	. = ..()
	setDir(direction)

/obj/effect/decal/cleanable/blood/dry()
	. = ..()
	if(.)
		color = "#350303"
