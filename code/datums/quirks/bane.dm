//predominantly negative traits
/datum/quirk/item_quirk/blindness
	name = "Blind"
	desc = "You are completely blind, nothing can counteract this."
	icon = "eye-slash"
	quirk_genre = QUIRK_GENRE_BANE
	gain_text = "<span class='danger'>You can't see anything.</span>"
	lose_text = "<span class='notice'>You miraculously gain back your vision.</span>"
	medical_record_text = "Patient has permanent blindness."
	quirk_flags = 	QUIRK_HUMAN_ONLY|QUIRK_CHANGES_APPEARANCE

/datum/quirk/item_quirk/blindness/add_unique(client/client_source)
	give_item_to_holder(/obj/item/clothing/glasses/blindfold/white, list(LOCATION_EYES = ITEM_SLOT_EYES, LOCATION_BACKPACK = ITEM_SLOT_BACKPACK, LOCATION_HANDS = ITEM_SLOT_HANDS))

/datum/quirk/item_quirk/blindness/add()
	quirk_holder.become_blind(QUIRK_TRAIT)

/datum/quirk/item_quirk/blindness/remove()
	quirk_holder.cure_blind(QUIRK_TRAIT)

/datum/quirk/deafness
	name = "Deaf"
	desc = "You are incurably deaf."
	icon = "deaf"
	quirk_genre = QUIRK_GENRE_BANE
	mob_trait = TRAIT_DEAF
	gain_text = "<span class='danger'>You can't hear anything.</span>"
	lose_text = "<span class='notice'>You're able to hear again!</span>"
	medical_record_text = "Patient's cochlear nerve is incurably damaged."

/datum/quirk/heavy_sleeper
	name = "Heavy Sleeper"
	desc = "You sleep like a rock! Whenever you're put to sleep or knocked unconscious, you take a little bit longer to wake up."
	icon = "bed"
	mob_trait = TRAIT_HEAVY_SLEEPER
	gain_text = "<span class='danger'>You feel sleepy.</span>"
	lose_text = "<span class='notice'>You feel awake again.</span>"
	medical_record_text = "Patient has abnormal sleep study results and is difficult to wake up."

/datum/quirk/light_drinker
	name = "Light Drinker"
	desc = "You just can't handle your drinks and get drunk very quickly."
	icon = "cocktail"
	quirk_genre = QUIRK_GENRE_BANE
	mob_trait = TRAIT_LIGHT_DRINKER
	gain_text = "<span class='notice'>Just the thought of drinking alcohol makes your head spin.</span>"
	lose_text = "<span class='danger'>You're no longer severely affected by alcohol.</span>"
	medical_record_text = "Patient demonstrates a low tolerance for alcohol. (Wimp)"

/datum/quirk/item_quirk/nearsighted
	name = "Nearsighted"
	desc = "You are nearsighted without prescription glasses, but spawn with a pair."
	icon = "glasses"
	quirk_genre = QUIRK_GENRE_BANE
	gain_text = "<span class='danger'>Things far away from you start looking blurry.</span>"
	lose_text = "<span class='notice'>You start seeing faraway things normally again.</span>"
	medical_record_text = "Patient requires prescription glasses in order to counteract nearsightedness."
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_CHANGES_APPEARANCE
	var/glasses

/datum/quirk/item_quirk/nearsighted/add_unique(client/client_source)
	glasses = client_source?.prefs.read_preference(/datum/preference/choiced/glasses) || "Regular"
	switch(glasses)
		if ("Thin")
			glasses = /obj/item/clothing/glasses/regular/thin
		if ("Circle")
			glasses = /obj/item/clothing/glasses/regular/circle
		if ("Hipster")
			glasses = /obj/item/clothing/glasses/regular/hipster
		else
			glasses = /obj/item/clothing/glasses/regular

	give_item_to_holder(glasses, list(LOCATION_EYES = ITEM_SLOT_EYES, LOCATION_BACKPACK = ITEM_SLOT_BACKPACK, LOCATION_HANDS = ITEM_SLOT_HANDS))

/datum/quirk/item_quirk/nearsighted/add()
	quirk_holder.become_nearsighted(QUIRK_TRAIT)

/datum/quirk/item_quirk/nearsighted/remove()
	quirk_holder.cure_nearsighted(QUIRK_TRAIT)

/datum/quirk/paraplegic
	name = "Paraplegic"
	desc = "Your legs do not function. Nothing will ever fix this. But hey, free wheelchair!"
	icon = "wheelchair"
	quirk_genre = QUIRK_GENRE_BANE
	quirk_flags = QUIRK_HUMAN_ONLY
	gain_text = null // Handled by trauma.
	lose_text = null
	medical_record_text = "Patient has an untreatable impairment in motor function in the lower extremities."

/datum/quirk/paraplegic/add_unique(client/client_source)
	if(quirk_holder.buckled) // Handle late joins being buckled to arrival shuttle chairs.
		quirk_holder.buckled.unbuckle_mob(quirk_holder)

	var/turf/holder_turf = get_turf(quirk_holder)
	var/obj/structure/chair/spawn_chair = locate() in holder_turf

	var/obj/vehicle/ridden/wheelchair/wheels
	if(client_source?.get_award_status(HARDCORE_RANDOM_SCORE) >= 5000) //More than 5k score? you unlock the gamer wheelchair.
		wheels = new /obj/vehicle/ridden/wheelchair/gold(holder_turf)
	else
		wheels = new(holder_turf)
	if(spawn_chair) // Makes spawning on the arrivals shuttle more consistent looking
		wheels.setDir(spawn_chair.dir)

	wheels.buckle_mob(quirk_holder)

	// During the spawning process, they may have dropped what they were holding, due to the paralysis
	// So put the things back in their hands.
	for(var/obj/item/dropped_item in holder_turf)
		if(dropped_item.fingerprintslast == quirk_holder.ckey)
			quirk_holder.put_in_hands(dropped_item)

/datum/quirk/paraplegic/add()
	var/mob/living/carbon/human/human_holder = quirk_holder
	human_holder.gain_trauma(/datum/brain_trauma/severe/paralysis/paraplegic, TRAUMA_RESILIENCE_ABSOLUTE)

/datum/quirk/paraplegic/remove()
	var/mob/living/carbon/human/human_holder = quirk_holder
	human_holder.cure_trauma_type(/datum/brain_trauma/severe/paralysis/paraplegic, TRAUMA_RESILIENCE_ABSOLUTE)

/datum/quirk/item_quirk/junkie
	name = "Junkie"
	desc = "You can't get enough of hard drugs."
	icon = "pills"
	quirk_genre = QUIRK_GENRE_BANE
	gain_text = "<span class='danger'>You suddenly feel the craving for drugs.</span>"
	medical_record_text = "Patient has a history of hard drugs."
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_PROCESSES
	var/drug_list = list(/datum/reagent/drug/blastoff, /datum/reagent/drug/krokodil, /datum/reagent/medicine/morphine, /datum/reagent/drug/methamphetamine) //List of possible IDs
	var/datum/reagent/reagent_type //!If this is defined, reagent_id will be unused and the defined reagent type will be instead.
	var/datum/reagent/reagent_instance //! actual instanced version of the reagent
	var/where_drug //! Where the drug spawned
	var/obj/item/drug_container_type //! If this is defined before pill generation, pill generation will be skipped. This is the type of the pill bottle.
	var/where_accessory //! where the accessory spawned
	var/obj/item/accessory_type //! If this is null, an accessory won't be spawned.
	var/process_interval = 30 SECONDS //! how frequently the quirk processes
	var/next_process = 0 //! ticker for processing
	var/drug_flavour_text = "Better hope you don't run out..."

/datum/quirk/item_quirk/junkie/add_unique(client/client_source)
	var/mob/living/carbon/human/human_holder = quirk_holder

	if(!reagent_type)
		reagent_type = pick(drug_list)

	reagent_instance = new reagent_type()

	for(var/addiction in reagent_instance.addiction_types)
		human_holder.last_mind?.add_addiction_points(addiction, 1000)

	var/current_turf = get_turf(quirk_holder)

	if(!drug_container_type)
		drug_container_type = /obj/item/storage/pill_bottle

	var/obj/item/drug_instance = new drug_container_type(current_turf)
	if(istype(drug_instance, /obj/item/storage/pill_bottle))
		var/pill_state = "pill[rand(1,20)]"
		for(var/i in 1 to 7)
			var/obj/item/reagent_containers/pill/pill = new(drug_instance)
			pill.icon_state = pill_state
			pill.reagents.add_reagent(reagent_type, 3)

	give_item_to_holder(
		drug_instance,
		list(
			LOCATION_LPOCKET = ITEM_SLOT_LPOCKET,
			LOCATION_RPOCKET = ITEM_SLOT_RPOCKET,
			LOCATION_BACKPACK = ITEM_SLOT_BACKPACK,
			LOCATION_HANDS = ITEM_SLOT_HANDS,
		),
		flavour_text = drug_flavour_text,
	)

	if(accessory_type)
		give_item_to_holder(
		accessory_type,
		list(
			LOCATION_LPOCKET = ITEM_SLOT_LPOCKET,
			LOCATION_RPOCKET = ITEM_SLOT_RPOCKET,
			LOCATION_BACKPACK = ITEM_SLOT_BACKPACK,
			LOCATION_HANDS = ITEM_SLOT_HANDS,
		)
	)

/datum/quirk/item_quirk/junkie/remove()
	if(quirk_holder && reagent_instance)
		for(var/addiction_type in subtypesof(/datum/addiction))
			quirk_holder.mind.remove_addiction_points(addiction_type, MAX_ADDICTION_POINTS)

/datum/quirk/item_quirk/junkie/process(delta_time)
	if(HAS_TRAIT(quirk_holder, TRAIT_NOMETABOLISM))
		return

	var/mob/living/carbon/human/human_holder = quirk_holder
	if(world.time > next_process)
		next_process = world.time + process_interval
		var/deleted = QDELETED(reagent_instance)
		var/missing_addiction = FALSE
		for(var/addiction_type in reagent_instance.addiction_types)
			if(!LAZYACCESS(human_holder.last_mind?.active_addictions, addiction_type))
				missing_addiction = TRUE

		if(deleted || missing_addiction)
			if(deleted)
				reagent_instance = new reagent_type()

			to_chat(quirk_holder, span_alert("You thought you kicked it, but you feel like you're falling back onto bad habits.."))

			for(var/addiction in reagent_instance.addiction_types)
				human_holder.last_mind?.add_addiction_points(addiction, 1000) ///Max that shit out

/datum/quirk/item_quirk/junkie/smoker
	name = "Smoker"
	desc = "Sometimes you just really want a smoke. Probably not great for your lungs."
	icon = "smoking"
	quirk_genre = QUIRK_GENRE_BANE
	gain_text = "<span class='danger'>You could really go for a smoke right about now.</span>"
	medical_record_text = "Patient is a current smoker."
	reagent_type = /datum/reagent/drug/nicotine
	accessory_type = /obj/item/lighter/greyscale
	mob_trait = TRAIT_SMOKER
	drug_flavour_text = "Make sure you get your favorite brand when you run out."

/datum/quirk/item_quirk/junkie/smoker/New()
	drug_container_type = pick(/obj/item/storage/fancy/cigarettes,
		/obj/item/storage/fancy/cigarettes/cigpack_midori,
		/obj/item/storage/fancy/cigarettes/cigpack_uplift,
		/obj/item/storage/fancy/cigarettes/cigpack_robust,
		/obj/item/storage/fancy/cigarettes/cigpack_robustgold,
		/obj/item/storage/fancy/cigarettes/cigpack_carp)

	return ..()

/datum/quirk/item_quirk/junkie/smoker/post_add()
	. = ..()
	var/brand = initial(drug_container_type.name)
	quirk_holder.mind.add_memory(MEMORY_QUIRK_DRUG, list(DETAIL_FAV_BRAND = brand), memory_flags = MEMORY_FLAG_NOLOCATION | MEMORY_FLAG_NOPERSISTENCE, story_value = STORY_VALUE_SHIT)
	// smoker lungs have 25% less health and healing
	var/obj/item/organ/lungs/smoker_lungs = quirk_holder.getorganslot(ORGAN_SLOT_LUNGS)
	if (smoker_lungs && !(smoker_lungs.organ_flags & ORGAN_SYNTHETIC)) // robotic lungs aren't affected
		smoker_lungs.maxHealth = smoker_lungs.maxHealth * 0.75

/datum/quirk/item_quirk/allergic
	name = "Medicine Allergy"
	desc = "Ever since you were a kid, you've been allergic to a drug."
	icon = "prescription-bottle"
	quirk_genre = QUIRK_GENRE_BANE
	gain_text = "<span class='danger'>You feel your immune system shift.</span>"
	lose_text = "<span class='notice'>You feel your immune system phase back into perfect shape.</span>"
	medical_record_text = "Patient's immune system responds poorly to certain chemicals."
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_PROCESSES
	/// Typepath of the reagent we're allergic to
	var/datum/reagent/medicine/allergy
	var/list/blacklist = list(/datum/reagent/medicine/inaprovaline, /datum/reagent/medicine/epinephrine, /datum/reagent/medicine/adminordrazine,/datum/reagent/medicine/tricordrazine/godblood,/datum/reagent/cordiolis_hepatico,/datum/reagent/medicine/diphenhydramine)
	var/allergy_string

/datum/quirk/item_quirk/allergic/add_unique(client/client_source)
	var/datum/reagent/medicine/allergy = pick(subtypesof(/datum/reagent/medicine) - blacklist)
	allergy_string = initial(allergy.name)
	name = "[allergy_string] Allergy"
	medical_record_text = "[allergy_string] triggers an immune response."

	var/mob/living/carbon/human/human_holder = quirk_holder
	var/obj/item/clothing/accessory/allergy_dogtag/dogtag = new(get_turf(human_holder))
	dogtag.display = allergy_string

	give_item_to_holder(dogtag, list(LOCATION_BACKPACK = ITEM_SLOT_BACKPACK, LOCATION_HANDS = ITEM_SLOT_HANDS), flavour_text = "Make sure medical staff can see this...")

/datum/quirk/item_quirk/allergic/post_add()
	quirk_holder.mind.add_memory(MEMORY_ALLERGY, list(DETAIL_ALLERGY_TYPE = allergy_string), memory_flags = MEMORY_FLAG_NOLOCATION | MEMORY_FLAG_NOPERSISTENCE, story_value = STORY_VALUE_SHIT)
	to_chat(quirk_holder, span_boldnotice("You are allergic to [allergy_string], make sure not to consume any of these!"))

/datum/quirk/item_quirk/allergic/process(delta_time)
	if(!iscarbon(quirk_holder))
		return

	if(IS_IN_STASIS(quirk_holder))
		return

	if(quirk_holder.stat == DEAD)
		return

	var/mob/living/carbon/carbon_quirk_holder = quirk_holder
	var/datum/reagent/instantiated_med = carbon_quirk_holder.reagents.has_reagent(allergy)
	if(!instantiated_med)
		return

	//Just halts the progression, I'd suggest you run to medbay asap to get it fixed
	if(carbon_quirk_holder.reagents.has_reagent(/datum/reagent/medicine/epinephrine))
		return

	carbon_quirk_holder.reagents.add_reagent(/datum/reagent/toxin/histamine, 0.5 * delta_time)

	if(DT_PROB(10, delta_time))
		carbon_quirk_holder.vomit()
		carbon_quirk_holder.adjustOrganLoss(pick(ORGAN_SLOT_BRAIN,ORGAN_SLOT_APPENDIX,ORGAN_SLOT_LUNGS,ORGAN_SLOT_HEART,ORGAN_SLOT_LIVER,ORGAN_SLOT_STOMACH),10)

/datum/quirk/insanity
	name = "Schizophrenia"
	desc = "You suffer from a severe disorder that causes vivid audio-visual hallucinations. Mindbreaker Toxin can be used to suppress the effects temporarily."
	icon = "grin-tongue-wink"
	quirk_genre = QUIRK_GENRE_BANE
	mob_trait = TRAIT_INSANITY
	medical_record_text = "Patient suffers from schizophrenia and experiences vivid audio-visual hallucinations."
	quirk_flags = QUIRK_HUMAN_ONLY|QUIRK_PROCESSES

/datum/quirk/insanity/process(delta_time)
	if(quirk_holder.stat >= UNCONSCIOUS || quirk_holder.IsSleeping() || quirk_holder.IsUnconscious())
		return

	if(DT_PROB(2, delta_time))
		quirk_holder.hallucination += rand(10, 25)
