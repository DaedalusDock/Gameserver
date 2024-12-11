/obj/machinery/hydroponics/attackby(obj/item/O, mob/user, params)
	//Called when mob user "attacks" it with object O
	if(IS_EDIBLE(O) || istype(O, /obj/item/reagent_containers))  // Syringe stuff (and other reagent containers now too)
		var/obj/item/reagent_containers/reagent_source = O

		if(!reagent_source.reagents.total_volume)
			to_chat(user, span_warning("[reagent_source] is empty!"))
			return 1

		if(reagents.total_volume >= reagents.maximum_volume && !reagent_source.reagents.has_reagent(/datum/reagent/water, 1))
			to_chat(user, span_notice("[src] is full."))
			return

		var/list/trays = list(src)//makes the list just this in cases of syringes and compost etc
		var/target = myseed ? myseed.plantname : src
		var/visi_msg = ""
		var/transfer_amount
		var/irrigate = 0	//How am I supposed to irrigate pill contents?

		if(IS_EDIBLE(reagent_source) || istype(reagent_source, /obj/item/reagent_containers/pill))
			visi_msg="[user] composts [reagent_source], spreading it through [target]"
			transfer_amount = reagent_source.reagents.total_volume
			SEND_SIGNAL(reagent_source, COMSIG_ITEM_ON_COMPOSTED, user)
		else
			transfer_amount = reagent_source.amount_per_transfer_from_this
			if(istype(reagent_source, /obj/item/reagent_containers/syringe))
				var/obj/item/reagent_containers/syringe/syr = reagent_source
				visi_msg="[user] injects [target] with [syr]"
			else if(istype(reagent_source, /obj/item/reagent_containers/spray/))
				visi_msg="[user] sprays [target] with [reagent_source]"
				playsound(loc, 'sound/effects/spray3.ogg', 50, TRUE, -6)
				irrigate = 1
			else if(transfer_amount) // Droppers, cans, beakers, what have you.
				visi_msg="[user] uses [reagent_source] on [target]"
				irrigate = 1
			// Beakers, bottles, buckets, etc.
			if(reagent_source.is_drainable())
				playsound(loc, 'sound/effects/slosh.ogg', 25, TRUE)

		if(irrigate && transfer_amount > 30 && reagent_source.reagents.total_volume >= 30 && using_irrigation)
			trays = FindConnected()
			if (trays.len > 1)
				visi_msg += ", setting off the irrigation system"

		if(visi_msg)
			visible_message(span_notice("[visi_msg]."))

		var/split = round(transfer_amount/trays.len)

		for(var/obj/machinery/hydroponics/H in trays)
		//cause I don't want to feel like im juggling 15 tamagotchis and I can get to my real work of ripping flooring apart in hopes of validating my life choices of becoming a space-gardener
			//This was originally in apply_chemicals, but due to apply_chemicals only holding nutrients, we handle it here now.
			if(reagent_source.reagents.has_reagent(/datum/reagent/water, 1))
				var/water_amt = reagent_source.reagents.get_reagent_amount(/datum/reagent/water) * split / reagent_source.reagents.total_volume
				H.adjust_waterlevel(round(water_amt))
				reagent_source.reagents.remove_reagent(/datum/reagent/water, water_amt)

			reagent_source.reagents.trans_to(H.reagents, split, transfered_by = user)
			lastuser = WEAKREF(user)

			if(IS_EDIBLE(reagent_source) || istype(reagent_source, /obj/item/reagent_containers/pill))
				qdel(reagent_source)
				H.update_appearance()
				return 1

			H.update_appearance()

		if(reagent_source) // If the source wasn't composted and destroyed
			reagent_source.update_appearance()
		return 1

	else if(istype(O, /obj/item/seeds) && !istype(O, /obj/item/seeds/sample))
		if(!myseed)
			if(istype(O, /obj/item/seeds/kudzu))
				investigate_log("had Kudzu planted in it by [key_name(user)] at [AREACOORD(src)].", INVESTIGATE_BOTANY)
			if(!user.transferItemToLoc(O, src))
				return
			SEND_SIGNAL(O, COMSIG_SEED_ON_PLANTED, src)
			to_chat(user, span_notice("You plant [O]."))
			set_seed(O)
			TRAY_NAME_UPDATE
			age = 1
			set_plant_health(myseed.endurance)
			lastcycle = world.time
			return
		else
			to_chat(user, span_warning("[src] already has seeds in it!"))
			return

	else if(istype(O, /obj/item/cultivator))
		if(weedlevel > 0)
			user.visible_message(span_notice("[user] uproots the weeds."), span_notice("You remove the weeds from [src]."))
			set_weedlevel(0)
			return
		else
			to_chat(user, span_warning("This plot is completely devoid of weeds! It doesn't need uprooting."))
			return

	else if(istype(O, /obj/item/secateurs))
		if(!myseed)
			to_chat(user, span_notice("This plot is empty."))
			return
		else if(plant_status != HYDROTRAY_PLANT_HARVESTABLE)
			to_chat(user, span_notice("This plant must be harvestable in order to be grafted."))
			return
		else if(myseed.grafted)
			to_chat(user, span_notice("This plant has already been grafted."))
			return
		else
			user.visible_message(span_notice("[user] grafts off a limb from [src]."), span_notice("You carefully graft off a portion of [src]."))
			var/obj/item/graft/snip = myseed.create_graft()
			if(!snip)
				return // The plant did not return a graft.

			snip.forceMove(drop_location())
			myseed.grafted = TRUE
			adjust_plant_health(-5)
			return

	else if(istype(O, /obj/item/geneshears))
		if(!myseed)
			to_chat(user, span_notice("The tray is empty."))
			return
		if(plant_health <= GENE_SHEAR_MIN_HEALTH)
			to_chat(user, span_notice("This plant looks too unhealty to be sheared right now."))
			return

		var/list/current_traits = list()
		for(var/datum/plant_gene/gene in myseed.genes)
			if(islist(gene))
				continue
			if(!(gene.mutability_flags & PLANT_GENE_REMOVABLE))
				continue // Don't show genes that can't be removed.
			current_traits[gene.name] = gene
		var/removed_trait = tgui_input_list(user, "Trait to remove from the [myseed.plantname]", "Plant Trait Removal", sort_list(current_traits))
		if(isnull(removed_trait))
			return
		if(!user.canUseTopic(src, USE_CLOSE))
			return
		if(!myseed)
			return
		if(plant_health <= GENE_SHEAR_MIN_HEALTH) //Check health again to make sure they're not keeping inputs open to get free shears.
			return
		for(var/datum/plant_gene/gene in myseed.genes)
			if(gene.name == removed_trait)
				if(myseed.genes.Remove(gene))
					gene.on_removed(myseed)
					qdel(gene)
					break
		myseed.reagents_from_genes()
		adjust_plant_health(-15)
		to_chat(user, span_notice("You carefully shear the genes off of the [myseed.plantname], leaving the plant looking weaker."))
		update_appearance()
		return

	else if(istype(O, /obj/item/graft))
		var/obj/item/graft/snip = O
		if(!myseed)
			to_chat(user, span_notice("The tray is empty."))
			return
		if(myseed.apply_graft(snip))
			to_chat(user, span_notice("You carefully integrate the grafted plant limb onto [myseed.plantname], granting it [snip.stored_trait.get_name()]."))
		else
			to_chat(user, span_notice("You integrate the grafted plant limb onto [myseed.plantname], but it does not accept the [snip.stored_trait.get_name()] trait from the [snip]."))
		qdel(snip)
		return

	else if(istype(O, /obj/item/storage/bag/plants))
		attack_hand(user)
		for(var/obj/item/food/grown/G in locate(user.x,user.y,user.z))
			O.atom_storage?.attempt_insert(G, user, TRUE)
		return

	else if(istype(O, /obj/item/shovel/spade))
		if(!myseed && !weedlevel)
			to_chat(user, span_warning("[src] doesn't have any plants or weeds!"))
			return
		user.visible_message(span_notice("[user] starts digging out [src]'s plants..."),
			span_notice("You start digging out [src]'s plants..."))
		if(O.use_tool(src, user, 50, volume=50) || (!myseed && !weedlevel))
			user.visible_message(span_notice("[user] digs out the plants in [src]!"), span_notice("You dig out all of [src]'s plants!"))
			if(myseed) //Could be that they're just using it as a de-weeder
				age = 0
				set_plant_health(0, update_icon = FALSE, forced = TRUE)
				lastproduce = 0
				set_seed(null)
				name = initial(name)
				desc = initial(desc)
			set_weedlevel(0) //Has a side effect of cleaning up those nasty weeds
			return

	else if(istype(O, /obj/item/storage/part_replacer))
		RefreshParts()
		return
	else if(istype(O, /obj/item/gun/energy/floragun))
		var/obj/item/gun/energy/floragun/flowergun = O
		if(flowergun.cell.charge < flowergun.cell.maxcharge)
			to_chat(user, span_notice("[flowergun] must be fully charged to lock in a mutation!"))
			return
		if(!myseed)
			to_chat(user, span_warning("[src] is empty!"))
			return
		if(myseed.endurance <= FLORA_GUN_MIN_ENDURANCE)
			to_chat(user, span_warning("[myseed.plantname] isn't hardy enough to sequence it's mutation!"))
			return
		if(!LAZYLEN(myseed.mutatelist))
			to_chat(user, span_warning("[myseed.plantname] has nothing else to mutate into!"))
			return
		else
			var/list/fresh_mut_list = list()
			for(var/muties in myseed.mutatelist)
				var/obj/item/seeds/another_mut = new muties
				fresh_mut_list[another_mut.plantname] = muties
			var/locked_mutation = tgui_input_list(user, "Mutation to lock", "Plant Mutation Locks", sort_list(fresh_mut_list))
			if(isnull(locked_mutation))
				return
			if(isnull(fresh_mut_list[locked_mutation]))
				return
			if(!user.canUseTopic(src, USE_CLOSE))
				return
			myseed.mutatelist = list(fresh_mut_list[locked_mutation])
			myseed.set_endurance(myseed.endurance/2)
			flowergun.cell.use(flowergun.cell.charge)
			flowergun.update_appearance()
			to_chat(user, span_notice("[myseed.plantname]'s mutation was set to [locked_mutation], depleting [flowergun]'s cell!"))
			return
	else
		return ..()

/obj/machinery/hydroponics/can_be_unfasten_wrench(mob/user, silent)
	if (!unwrenchable)  // case also covered by NODECONSTRUCT checks in default_unfasten_wrench
		return CANT_UNFASTEN
	if (using_irrigation)
		if (!silent)
			to_chat(user, "<span class='warning'>Disconnect the hoses first!</span>")
		return FAILED_UNFASTEN

	return ..()

/obj/machinery/hydroponics/attack_hand(mob/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(issilicon(user)) //How does AI know what plant is?
		return
	if(plant_status == HYDROTRAY_PLANT_HARVESTABLE)
		return myseed.harvest(user)

	else if(plant_status == HYDROTRAY_PLANT_DEAD)
		to_chat(user, span_notice("You remove the dead plant from [src]."))
		clear_plant()
		update_appearance()
	else
		if(user)
			user.examinate(src)

/obj/machinery/hydroponics/attack_hand_secondary(mob/user, list/modifiers)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return

	if(!anchored)
		update_appearance()
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

	var/warning = tgui_alert(user, "Are you sure you wish to empty the tray's reagent container?","Empty Tray?", list("Yes", "No"))
	if(warning == "Yes" && user.canUseTopic(src, USE_CLOSE|USE_IGNORE_TK))
		reagents.clear_reagents()
		to_chat(user, span_warning("You empty [src]'s reagent container."))

	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/machinery/hydroponics/AltClick(mob/user)
	return ..() // This hotkey is BLACKLISTED since it's used by /datum/component/simple_rotation

/obj/machinery/hydroponics/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	default_unfasten_wrench(user, tool)
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/machinery/hydroponics/wirecutter_act(mob/living/user, obj/item/tool)
	. = ..()
	if(!unwrenchable)
		return
	if (!anchored)
		to_chat(user, "<span class='warning'>Anchor the tray first!</span>")
		return TOOL_ACT_TOOLTYPE_SUCCESS

	using_irrigation = !using_irrigation
	tool.play_tool_sound(src)
	user.visible_message("<span class='notice'>[user] [using_irrigation ? "" : "dis"]connects [src]'s irrigation hoses.</span>", \
	"<span class='notice'>You [using_irrigation ? "" : "dis"]connect [src]'s irrigation hoses.</span>")
	for(var/obj/machinery/hydroponics/h in range(1,src))
		h.update_icon_state()
	return TOOL_ACT_TOOLTYPE_SUCCESS
