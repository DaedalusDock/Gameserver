/obj/item/reagent_containers/syringe
	name = "syringe"
	desc = "A syringe that can hold up to 15 units."
	icon = 'icons/obj/syringe.dmi'
	base_icon_state = "syringe"
	lefthand_file = 'icons/mob/inhands/equipment/medical_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/medical_righthand.dmi'
	icon_state = "syringe_0"
	worn_icon_state = "pen"
	amount_per_transfer_from_this = 5
	possible_transfer_amounts = list(5, 10, 15)
	volume = 15
	custom_materials = list(/datum/material/iron=10, /datum/material/glass=20)
	reagent_flags = TRANSPARENT
	custom_price = PAYCHECK_EASY * 0.5
	sharpness = SHARP_POINTY

	/// Flags used by the injection
	var/inject_flags = NONE

	/// Tracks if the below lists are populated.
	var/sterile = TRUE
	/// Lazylist. If it exists that means the syringe is non-sterile.
	var/list/dirty_blood_DNA
	/// Lazylist. Contains disease datums. K:V of disease_id : disease datum.
	var/list/dirty_pathogens

/obj/item/reagent_containers/syringe/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/update_icon_updates_onmob)

/obj/item/reagent_containers/syringe/attackby(obj/item/I, mob/user, params)
	return

/obj/item/reagent_containers/syringe/proc/try_syringe(atom/target, mob/user, proximity)
	if(!proximity)
		return FALSE
	if(!target.reagents)
		return FALSE
	if(isliving(user))
		var/mob/living/L = user
		if(L.combat_mode)
			return FALSE

	if(isliving(target))
		var/mob/living/living_target = target
		if(!living_target.try_inject(user, injection_flags = INJECT_TRY_SHOW_ERROR_MESSAGE|inject_flags))
			return FALSE

	// chance of monkey retaliation
	SEND_SIGNAL(target, COMSIG_LIVING_TRY_SYRINGE, user)
	return TRUE

/obj/item/reagent_containers/syringe/afterattack(atom/target, mob/user, proximity)
	. = ..()

	if(DOING_INTERACTION(user, ref(src)))
		return

	if (!try_syringe(target, user, proximity))
		return

	var/contained = reagents.get_reagent_log_string()
	log_combat(user, target, "attempted to inject", src, addition="which had [contained]")

	if(!reagents.total_volume)
		to_chat(user, span_warning("[src] is empty! Right-click to draw."))
		return

	if(!isliving(target) && !target.is_injectable(user))
		to_chat(user, span_warning("You cannot directly fill [target]!"))
		return

	if(target.reagents.total_volume >= target.reagents.maximum_volume)
		to_chat(user, span_notice("[target] is full."))
		return

	if(isliving(target))
		var/mob/living/living_target = target
		if(!living_target.try_inject(user, injection_flags = INJECT_TRY_SHOW_ERROR_MESSAGE|inject_flags))
			return

		if(living_target != user)
			living_target.visible_message(
				span_notice("[user] is trying to inject [living_target] with [src]."),
			)
			if(!do_after(user, living_target, CHEM_INTERACT_DELAY(3 SECONDS, user), DO_PUBLIC, extra_checks = CALLBACK(living_target, TYPE_PROC_REF(/mob/living, try_inject), user, null, INJECT_TRY_SHOW_ERROR_MESSAGE|inject_flags), interaction_key = ref(src), display = src))
				return
			if(!reagents.total_volume)
				return
			if(living_target.reagents.total_volume >= living_target.reagents.maximum_volume)
				return

			living_target.visible_message(
				span_notice("[user] injects [living_target] with [src]."),
			)

		if (living_target == user)
			living_target.visible_message(span_notice("[user] injects [user.p_them()]self with [src]."))
			living_target.log_message("injected themselves ([contained]) with [name]", LOG_ATTACK, color="orange")
		else
			log_combat(user, living_target, "injected", src, addition="which had [contained]")

		contaminate_mob(living_target)
		// Only show the flavor message once.
		if(!LAZYLEN(dirty_blood_DNA))
			user.visible_message(span_subtle("Blood fills [src]'s needle."), vision_distance = 1)
		contaminate(living_target.get_blood_dna_list(), living_target.diseases)

	reagents.trans_to(target, amount_per_transfer_from_this, transfered_by = user, methods = INJECT)
	to_chat(user, span_obviousnotice("You inject [amount_per_transfer_from_this] units of the solution. \The [src] now contains [reagents.total_volume] units."))

/obj/item/reagent_containers/syringe/afterattack_secondary(atom/target, mob/user, proximity_flag, click_parameters)
	if (!try_syringe(target, user, proximity_flag))
		return SECONDARY_ATTACK_CONTINUE_CHAIN

	if(reagents.total_volume >= reagents.maximum_volume)
		to_chat(user, span_notice("[src] is full."))
		return SECONDARY_ATTACK_CONTINUE_CHAIN

	if(isliving(target))
		var/mob/living/living_target = target
		var/drawn_amount = reagents.maximum_volume - reagents.total_volume
		if(target != user)
			target.visible_message(
				span_notice("[user] is trying to take a blood sample from [target]."),
			)

			if(!do_after(user, target, CHEM_INTERACT_DELAY(3 SECONDS, user), DO_PUBLIC, extra_checks = CALLBACK(living_target, TYPE_PROC_REF(/mob/living, try_inject), user, null, INJECT_TRY_SHOW_ERROR_MESSAGE|inject_flags), interaction_key = ref(src), display = src))
				return SECONDARY_ATTACK_CONTINUE_CHAIN
			if(reagents.total_volume >= reagents.maximum_volume)
				return SECONDARY_ATTACK_CONTINUE_CHAIN

		var/target_str = living_target == user ? "[user.p_them()]self" : "[living_target]"
		if(living_target.transfer_blood_to(src, drawn_amount))
			contaminate_mob(living_target)
			user.visible_message(span_notice("[user] takes a blood sample from [target_str] with [src]."))
			contaminate(living_target.get_blood_dna_list(), living_target.diseases)
		else
			to_chat(user, span_warning("You are unable to draw any blood from [target_str]."))
	else
		if(!target.reagents.total_volume)
			to_chat(user, span_warning("[target] is empty!"))
			return SECONDARY_ATTACK_CONTINUE_CHAIN

		if(!target.is_drawable(user))
			to_chat(user, span_warning("You cannot directly remove reagents from [target]."))
			return SECONDARY_ATTACK_CONTINUE_CHAIN

		var/trans = target.reagents.trans_to(src, amount_per_transfer_from_this, transfered_by = user) // transfer from, transfer to - who cares?

		to_chat(user, span_obviousnotice("You fill [src] with [trans] units of the solution. It now contains [reagents.total_volume] units."))
	playsound(src, 'sound/effects/syringe_extract.ogg', 50)
	return SECONDARY_ATTACK_CONTINUE_CHAIN

/*
 * On accidental consumption, inject the eater with 2/3rd of the syringe and reveal it
 */
/obj/item/reagent_containers/syringe/on_accidental_consumption(mob/living/carbon/victim, mob/living/carbon/user, obj/item/source_item,  discover_after = TRUE)
	if(source_item)
		to_chat(victim, span_boldwarning("There's a [src] in [source_item]!!"))
	else
		to_chat(victim, span_boldwarning("[src] injects you!"))

	victim.apply_damage(5, BRUTE, BODY_ZONE_HEAD)
	reagents?.trans_to(victim, round(reagents.total_volume*(2/3)), transfered_by = user, methods = INJECT)

	return discover_after

/obj/item/reagent_containers/syringe/update_icon_state()
	var/rounded_vol = get_rounded_vol()
	icon_state = "[base_icon_state]_[rounded_vol]"
	return ..()

/obj/item/reagent_containers/syringe/update_overlays()
	. = ..()
	if(reagents?.total_volume)
		var/mutable_appearance/filling_overlay = mutable_appearance('icons/obj/reagentfillings.dmi', "syringe[get_rounded_vol()]")
		filling_overlay.color = mix_color_from_reagents(reagents.reagent_list)
		. += filling_overlay

	if(!sterile)
		. += image(icon, "tainted_overlay")

///Used by update_appearance() and update_overlays()
/obj/item/reagent_containers/syringe/proc/get_rounded_vol()
	if(!reagents?.total_volume)
		return 0
	return clamp(round((reagents.total_volume / volume * 15), 5), 1, 15)

/// Remove unsterile things.
/obj/item/reagent_containers/syringe/proc/sterilize()
	LAZYNULL(dirty_blood_DNA)
	QDEL_LIST(dirty_pathogens)
	sterile = TRUE
	update_appearance(UPDATE_OVERLAYS)

/// Contaminates the syringe with the given blood DNA and pathogens. Copies the pathogens.
/obj/item/reagent_containers/syringe/proc/contaminate(list/blood_DNA, list/pathogens_to_copy)
	if(!length(blood_DNA))
		return

	for(var/datum/pathogen/P in pathogens_to_copy)
		if(!(P.spread_flags & PATHOGEN_SPREAD_BLOOD))
			continue

		var/id = P.get_id()
		if(dirty_pathogens?[id])
			continue

		LAZYSET(dirty_pathogens, id, P.Copy())

	LAZYOR(dirty_blood_DNA, blood_DNA)
	sterile = FALSE
	update_appearance(UPDATE_OVERLAYS)

/// Spread the icky bad stuff in the syringe to a mob.
/obj/item/reagent_containers/syringe/proc/contaminate_mob(mob/living/carbon/human/H)
	if(sterile || !ishuman(H))
		return

	for(var/disease_id in dirty_pathogens)
		var/datum/pathogen/P = dirty_pathogens[disease_id]
		H.try_contract_pathogen(P, make_copy = TRUE) // It's probably a good idea to not leave refs to an active disease in the syringe.

	#warn add some kind of bloodborne disease here?
	H.germ_level = max(H.germ_level, INFECTION_LEVEL_TWO)

/obj/item/reagent_containers/syringe/epinephrine
	name = "syringe (epinephrine)"
	desc = "Contains epinephrine - used to stabilize patients."
	list_reagents = list(/datum/reagent/medicine/epinephrine = 15)

/obj/item/reagent_containers/syringe/dylovene
	name = "syringe (dylovene)"
	desc = "Contains dylovene. Diluted with granibitaluri."
	list_reagents = list(/datum/reagent/medicine/dylovene = 15)

/obj/item/reagent_containers/syringe/antiviral
	name = "syringe (spaceacillin)"
	desc = "Contains antiviral agents."
	list_reagents = list(/datum/reagent/medicine/spaceacillin = 15)

/obj/item/reagent_containers/syringe/bioterror
	name = "bioterror syringe"
	desc = "Contains several paralyzing reagents."
	list_reagents = list(/datum/reagent/consumable/ethanol/neurotoxin = 5, /datum/reagent/toxin/mutetoxin = 5, /datum/reagent/toxin/sodium_thiopental = 5)

/obj/item/reagent_containers/syringe/dexalin
	name = "syringe (dexalin)"
	desc = "Contains dexalin."
	list_reagents = list(/datum/reagent/medicine/dexalin = 15)

/obj/item/reagent_containers/syringe/plasma
	name = "syringe (plasma)"
	desc = "Contains plasma."
	list_reagents = list(/datum/reagent/toxin/plasma = 15)

/obj/item/reagent_containers/syringe/lethal
	name = "lethal injection syringe"
	desc = "A syringe used for lethal injections. It can hold up to 50 units."
	amount_per_transfer_from_this = 50
	volume = 50

/obj/item/reagent_containers/syringe/lethal/choral
	list_reagents = list(/datum/reagent/toxin/chloralhydrate = 50)

/obj/item/reagent_containers/syringe/lethal/execution
	list_reagents = list(/datum/reagent/toxin/plasma = 15, /datum/reagent/toxin/cyanide = 10, /datum/reagent/toxin/acid/fluacid = 10)

/obj/item/reagent_containers/syringe/mulligan
	name = "Mulligan"
	desc = "A syringe used to completely change the users identity."
	amount_per_transfer_from_this = 1
	volume = 1
	list_reagents = list(/datum/reagent/mulligan = 1)

/obj/item/reagent_containers/syringe/bluespace
	name = "bluespace syringe"
	desc = "An advanced syringe that can hold 60 units of chemicals."
	icon_state = "bluespace_0"
	base_icon_state = "bluespace"
	amount_per_transfer_from_this = 20
	possible_transfer_amounts = list(10, 20, 30, 40, 50, 60)
	volume = 60

/obj/item/reagent_containers/syringe/piercing
	name = "piercing syringe"
	desc = "A diamond-tipped syringe that pierces armor when launched at high velocity. It can hold up to 10 units."
	icon_state = "piercing_0"
	base_icon_state = "piercing"
	volume = 10
	possible_transfer_amounts = list(5, 10)
	inject_flags = INJECT_CHECK_PENETRATE_THICK

/obj/item/reagent_containers/syringe/crude
	name = "crude syringe"
	desc = "A crudely made syringe. The flimsy wooden construction makes it hold a minimal amounts of reagents, but its very disposable."
	icon_state = "crude_0"
	base_icon_state = "crude"
	possible_transfer_amounts = list(1,5)
	volume = 5

/obj/item/reagent_containers/syringe/spider_extract
	name = "spider extract syringe"
	desc = "Contains crikey juice - makes any gold core create the most deadly companions in the world."
	list_reagents = list(/datum/reagent/spider_extract = 1)

/obj/item/reagent_containers/syringe/contraband
	name = "unlabeled syringe"
	desc = "A syringe containing some sort of unknown chemical cocktail."

/obj/item/reagent_containers/syringe/contraband/space_drugs
	list_reagents = list(/datum/reagent/drug/space_drugs = 15)

/obj/item/reagent_containers/syringe/contraband/krokodil
	list_reagents = list(/datum/reagent/drug/krokodil = 15)

/obj/item/reagent_containers/syringe/contraband/saturnx
	list_reagents = list(/datum/reagent/drug/saturnx = 15)

/obj/item/reagent_containers/syringe/contraband/methamphetamine
	list_reagents = list(/datum/reagent/drug/methamphetamine = 15)

/obj/item/reagent_containers/syringe/contraband/bath_salts
	list_reagents = list(/datum/reagent/drug/bath_salts = 15)

/obj/item/reagent_containers/syringe/contraband/fentanyl
	list_reagents = list(/datum/reagent/toxin/fentanyl = 15)

/obj/item/reagent_containers/syringe/contraband/morphine
	list_reagents = list(/datum/reagent/medicine/morphine = 15)
