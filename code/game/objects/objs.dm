
/obj
	animate_movement = SLIDE_STEPS
	speech_span = SPAN_ROBOT
	chat_class = "small"

	var/obj_flags = CAN_BE_HIT

	var/damtype = BRUTE
	var/force = 0

	var/current_skin //Has the item been reskinned?
	var/list/unique_reskin //List of options to reskin.

	// Access levels, used in modules\jobs\access.dm
	var/list/req_access
	var/req_access_txt = "0"
	var/list/req_one_access
	var/req_one_access_txt = "0"
	/// Custom fire overlay icon
	var/custom_fire_overlay

	var/renamedByPlayer = FALSE //set when a player uses a pen on a renamable object

	var/drag_slowdown // Amont of multiplicative slowdown applied if pulled. >1 makes you slower, <1 makes you faster.

	vis_flags = VIS_INHERIT_PLANE //when this be added to vis_contents of something it inherit something.plane, important for visualisation of obj in openspace.

	///How large is the object, used for stuff like whether it can fit in backpacks or not
	var/w_class = null

	/// Map tag for something.  Tired of it being used on snowflake items.  Moved here for some semblance of a standard.
	/// Next pr after the network fix will have me refactor door interactions, so help me god.
	var/id_tag = null

	uses_integrity = TRUE

/obj/vv_edit_var(vname, vval)
	if(vname == NAMEOF(src, obj_flags))
		if ((obj_flags & DANGEROUS_POSSESSION) && !(vval & DANGEROUS_POSSESSION))
			return FALSE
	return ..()

/obj/Destroy(force)
	if((datum_flags & DF_ISPROCESSING))
		if(ismachinery(src))
			STOP_PROCESSING(SSmachines, src)
		else
			STOP_PROCESSING(SSobj, src)
		stack_trace("Obj of type [type] processing after Destroy(), please fix this.")
	SStgui.close_uis(src)
	return ..()


/obj/assume_air(datum/gas_mixture/giver)
	if(loc)
		return loc.assume_air(giver)
	else
		return null

/obj/remove_air(amount)
	if(loc)
		return loc.remove_air(amount)
	else
		return null

/obj/return_air()
	if(loc)
		return loc.return_air()
	else
		return null

/obj/proc/handle_internal_lifeform(mob/lifeform_inside_me, breath_request)
	//Return: (NONSTANDARD)
	// null if object handles breathing logic for lifeform
	// datum/air_group to tell lifeform to process using that breath return
	//DEFAULT: Take air from turf to give to have mob process

	if(breath_request>0)
		var/datum/gas_mixture/environment = return_breathable_air()
		var/breath_percentage = BREATH_VOLUME / environment.volume
		return remove_air(environment.total_moles * breath_percentage)
	else
		return null

/obj/proc/updateUsrDialog()
	if((obj_flags & IN_USE))
		var/is_in_use = FALSE
		var/list/nearby = viewers(1, src)
		for(var/mob/M in nearby)
			if ((M.client && M.machine == src))
				is_in_use = TRUE
				ui_interact(M)
		if(issilicon(usr) || isAdminGhostAI(usr))
			if (!(usr in nearby))
				if (usr.client && usr.machine==src) // && M.machine == src is omitted because if we triggered this by using the dialog, it doesn't matter if our machine changed in between triggering it and this - the dialog is probably still supposed to refresh.
					is_in_use = TRUE
					ui_interact(usr)

		// check for TK users

		if(ishuman(usr))
			var/mob/living/carbon/human/H = usr
			if(!(usr in nearby))
				if(usr.client && usr.machine==src)
					if(H.dna.check_mutation(/datum/mutation/human/telekinesis))
						is_in_use = TRUE
						ui_interact(usr)
		if (is_in_use)
			obj_flags |= IN_USE
		else
			obj_flags &= ~IN_USE

/obj/proc/updateDialog(update_viewers = TRUE,update_ais = TRUE)
	// Check that people are actually using the machine. If not, don't update anymore.
	if(obj_flags & IN_USE)
		var/is_in_use = FALSE
		if(update_viewers)
			for(var/mob/M in viewers(1, src))
				if ((M.client && M.machine == src))
					is_in_use = TRUE
					src.interact(M)
		var/ai_in_use = FALSE
		if(update_ais)
			ai_in_use = AutoUpdateAI(src)

		if(update_viewers && update_ais) //State change is sure only if we check both
			if(!ai_in_use && !is_in_use)
				obj_flags &= ~IN_USE


/obj/attack_ghost(mob/user)
	. = ..()
	if(.)
		return
	SEND_SIGNAL(src, COMSIG_ATOM_UI_INTERACT, user)
	ui_interact(user)

/mob/proc/unset_machine()
	SIGNAL_HANDLER
	if(!machine)
		return
	UnregisterSignal(machine, COMSIG_PARENT_QDELETING)
	machine.on_unset_machine(src)
	machine = null

//called when the user unsets the machine.
/atom/movable/proc/on_unset_machine(mob/user)
	return

/mob/proc/set_machine(obj/O)
	if(QDELETED(src) || QDELETED(O))
		return

	if(machine)
		unset_machine()
	machine = O
	RegisterSignal(O, COMSIG_PARENT_QDELETING, PROC_REF(unset_machine))
	if(istype(O))
		O.obj_flags |= IN_USE

/obj/item/proc/updateSelfDialog()
	var/mob/M = src.loc
	if(istype(M) && M.client && M.machine == src)
		src.attack_self(M)

/obj/singularity_pull(S, current_size)
	..()
	if(move_resist == INFINITY)
		return
	if(!anchored || current_size >= STAGE_FIVE)
		step_towards(src,S)

/obj/get_dumping_location()
	return get_turf(src)

/obj/proc/check_uplink_validity()
	return 1

/obj/vv_get_dropdown()
	. = ..()
	VV_DROPDOWN_OPTION("", "---")
	VV_DROPDOWN_OPTION(VV_HK_MASS_DEL_TYPE, "Delete all of type")
	VV_DROPDOWN_OPTION(VV_HK_OSAY, "Object Say")
	VV_DROPDOWN_OPTION(VV_HK_ARMOR_MOD, "Modify armor values")

/obj/vv_do_topic(list/href_list)
	if(!(. = ..()))
		return
	if(href_list[VV_HK_OSAY])
		if(check_rights(R_FUN, FALSE))
			usr.client.object_say(src)
	if(href_list[VV_HK_ARMOR_MOD])
		var/list/pickerlist = list()
		var/list/armorlist = returnArmor().getList()

		for (var/i in armorlist)
			pickerlist += list(list("value" = armorlist[i], "name" = i))

		var/list/result = presentpicker(usr, "Modify armor", "Modify armor: [src]", Button1="Save", Button2 = "Cancel", Timeout=FALSE, inputtype = "text", values = pickerlist)

		if (islist(result))
			if (result["button"] != 2) // If the user pressed the cancel button
				// text2num conveniently returns a null on invalid values
				setArmor(returnArmor().setRating(
						blunt = text2num(result["values"][BLUNT]),
						puncture = text2num(result["values"][PUNCTURE]),
						slash = text2num(result["values"][SLASH]),
						laser = text2num(result["values"][LASER]),
						energy = text2num(result["values"][ENERGY]),
						bomb = text2num(result["values"][BOMB]),
						bio = text2num(result["values"][BIO]),
						fire = text2num(result["values"][FIRE]),
						acid = text2num(result["values"][ACID])
					)
				)
				log_admin("[key_name(usr)] modified the armor on [src] ([type]) to blunt: [armor.blunt], puncture: [armor.puncture], slash: [armor.slash], laser: [armor.laser], energy: [armor.energy], bomb: [armor.bomb], bio: [armor.bio], fire: [armor.fire], acid: [armor.acid]")
				message_admins(span_notice("[key_name_admin(usr)] modified the armor on [src] ([type]) to blunt: [armor.blunt], puncture: [armor.puncture], slash: [armor.slash], laser: [armor.laser], energy: [armor.energy], bomb: [armor.bomb], bio: [armor.bio], fire: [armor.fire], acid: [armor.acid]"))
	if(href_list[VV_HK_MASS_DEL_TYPE])
		if(check_rights(R_DEBUG|R_SERVER))
			var/action_type = tgui_alert(usr, "Strict type ([type]) or type and all subtypes?",,list("Strict type","Type and subtypes","Cancel"))
			if(action_type == "Cancel" || !action_type)
				return

			if(tgui_alert(usr, "Are you really sure you want to delete all objects of type [type]?",,list("Yes","No")) != "Yes")
				return

			if(tgui_alert(usr, "Second confirmation required. Delete?",,list("Yes","No")) != "Yes")
				return

			var/O_type = type
			switch(action_type)
				if("Strict type")
					var/i = 0
					for(var/obj/Obj in world)
						if(Obj.type == O_type)
							i++
							qdel(Obj)
						CHECK_TICK
					if(!i)
						to_chat(usr, "No objects of this type exist")
						return
					log_admin("[key_name(usr)] deleted all objects of type [O_type] ([i] objects deleted) ")
					message_admins(span_notice("[key_name(usr)] deleted all objects of type [O_type] ([i] objects deleted) "))
				if("Type and subtypes")
					var/i = 0
					for(var/obj/Obj in world)
						if(istype(Obj,O_type))
							i++
							qdel(Obj)
						CHECK_TICK
					if(!i)
						to_chat(usr, "No objects of this type exist")
						return
					log_admin("[key_name(usr)] deleted all objects of type or subtype of [O_type] ([i] objects deleted) ")
					message_admins(span_notice("[key_name(usr)] deleted all objects of type or subtype of [O_type] ([i] objects deleted) "))

/obj/AltClick(mob/user)
	. = ..()
	if(unique_reskin && !current_skin)
		reskin_obj(user)

/**
 * Reskins object based on a user's choice
 *
 * Arguments:
 * * M The mob choosing a reskin option
 */
/obj/proc/reskin_obj(mob/M)
	if(!LAZYLEN(unique_reskin))
		return

	var/list/items = list()
	for(var/reskin_option in unique_reskin)
		var/image/item_image = image(icon = src.icon, icon_state = unique_reskin[reskin_option])
		items += list("[reskin_option]" = item_image)
	sort_list(items)

	var/pick = show_radial_menu(M, src, items, custom_check = CALLBACK(src, PROC_REF(check_reskin_menu), M), radius = 38, require_near = TRUE)
	if(!pick)
		return
	if(!unique_reskin[pick])
		return
	current_skin = pick
	icon_state = unique_reskin[pick]
	to_chat(M, "[src] is now skinned as '[pick].'")

/**
 * Checks if we are allowed to interact with a radial menu for reskins
 *
 * Arguments:
 * * user The mob interacting with the menu
 */
/obj/proc/check_reskin_menu(mob/user)
	if(QDELETED(src))
		return FALSE
	if(current_skin)
		return FALSE
	if(!istype(user))
		return FALSE
	if(user.incapacitated())
		return FALSE
	return TRUE

/obj/analyzer_act(mob/living/user, obj/item/analyzer/tool)
	if(atmos_scan(user=user, target=src, tool=tool, silent=FALSE))
		return TRUE
	return ..()

/obj/proc/plunger_act(obj/item/plunger/P, mob/living/user, reinforced)
	return

// Should move all contained objects to it's location.
/obj/proc/dump_contents()
	CRASH("Unimplemented.")

/obj/handle_ricochet(obj/projectile/P)
	. = ..()
	if(. && receive_ricochet_damage_coeff)
		take_damage(P.damage * receive_ricochet_damage_coeff, P.damage_type, P.armor_flag, 0, turn(P.dir, 180), P.armor_penetration) // pass along receive_ricochet_damage_coeff damage to the structure for the ricochet

/obj/update_overlays()
	. = ..()
	if(resistance_flags & ON_FIRE)
		. += custom_fire_overlay ? custom_fire_overlay : GLOB.fire_overlay

/// Handles exposing an object to reagents.
/obj/expose_reagents(list/reagents, datum/reagents/source, methods=TOUCH, volume_modifier=1, show_message=TRUE, exposed_temperature)
	. = ..()
	if(. & COMPONENT_NO_EXPOSE_REAGENTS)
		return

	SEND_SIGNAL(source, COMSIG_REAGENTS_EXPOSE_OBJ, src, reagents, methods, volume_modifier, show_message, exposed_temperature)
	for(var/reagent in reagents)
		var/datum/reagent/R = reagent
		. |= R.expose_obj(src, reagents[R], exposed_temperature)

///attempt to freeze this obj if possible. returns TRUE if it succeeded, FALSE otherwise.
/obj/proc/freeze()
	if(HAS_TRAIT(src, TRAIT_FROZEN))
		return FALSE
	if(obj_flags & FREEZE_PROOF)
		return FALSE

	AddElement(/datum/element/frozen)
	return TRUE

///unfreezes this obj if its frozen
/obj/proc/unfreeze()
	SEND_SIGNAL(src, COMSIG_OBJ_UNFREEZE)

/// Removes a BLOCK_Z_OUT_* flag, and then tries to get every movable in the turf to fall.
/obj/proc/lose_block_z_out(flag_to_lose)
	if(!(obj_flags & flag_to_lose))
		return

	obj_flags &= ~flag_to_lose
	var/turf/T = get_turf(src)
	if(!T)
		return

	for(var/atom/movable/AM as anything in T)
		AM.zFall()
