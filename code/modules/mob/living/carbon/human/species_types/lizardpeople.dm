/datum/species/lizard
	// Reptilian humanoids with scaled skin and tails.
	name = "\improper Jinan"
	plural_form = "Jinans"
	id = SPECIES_LIZARD
	say_mod = "hisses"
	default_color = COLOR_VIBRANT_LIME
	species_traits = list(MUTCOLORS, EYECOLOR, LIPS, BODY_RESIZABLE, SCLERA)
	inherent_traits = list(
		TRAIT_ADVANCEDTOOLUSER,
		TRAIT_CAN_STRIP,
		TRAIT_CAN_USE_FLIGHT_POTION,
	)
	inherent_biotypes = MOB_ORGANIC|MOB_HUMANOID|MOB_REPTILE
	mutant_bodyparts = list("legs" = "Normal Legs")
	cosmetic_organs = list(
		/obj/item/organ/horns = "None",
		/obj/item/organ/frills = "None",
		/obj/item/organ/snout = "Round",
		/obj/item/organ/spines = "None",
		/obj/item/organ/tail/lizard = "Smooth",
	)

	coldmod = 1.5
	heatmod = 0.67
	payday_modifier = 0.75
	job_outfit_type = SPECIES_HUMAN
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_PRIDE | MIRROR_MAGIC | RACE_SWAP | ERT_SPAWN | SLIME_EXTRACT
	species_cookie = /obj/item/food/meat/slab
	meat = /obj/item/food/meat/slab/human/mutant/lizard
	skinned_type = /obj/item/stack/sheet/animalhide/lizard
	exotic_bloodtype = "L"
	disliked_food = GRAIN | DAIRY | CLOTH
	liked_food = GROSS | MEAT | SEAFOOD | NUTS
	inert_mutation = /datum/mutation/human/firebreath
	wings_icons = list("Dragon")
	species_language_holder = /datum/language_holder/lizard
	digitigrade_customization = DIGITIGRADE_OPTIONAL

	// Lizards are coldblooded and can stand a greater temperature range than humans
	cold_level_3 = 130
	cold_level_2 = 220
	cold_level_1 = 280

	bodytemp_normal = BODYTEMP_NORMAL - 10

	heat_level_1 = 420
	heat_level_2 = 480
	heat_level_3 = 1100

	heat_discomfort_strings = list(
		"You feel soothingly warm.",
		"You feel the heat sink into your bones.",
		"You feel warm enough to take a nap."
	)

	cold_discomfort_strings = list(
		"You feel chilly.",
		"You feel sluggish and cold.",
		"Your scales bristle against the cold."
	)
	ass_image = 'icons/ass/asslizard.png'

	bodypart_overrides = list(
		BODY_ZONE_HEAD = /obj/item/bodypart/head/lizard,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest/lizard,
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/lizard,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/lizard,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/lizard,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right/lizard,
	)

	organs = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain,
		ORGAN_SLOT_HEART = /obj/item/organ/heart,
		ORGAN_SLOT_LUNGS = /obj/item/organ/lungs,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes,
		ORGAN_SLOT_EARS =  /obj/item/organ/ears,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue/lizard,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach,
		ORGAN_SLOT_APPENDIX = /obj/item/organ/appendix,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver,
		ORGAN_SLOT_KIDNEYS = /obj/item/organ/kidneys
	)


	pain_emotes = list(
		list(
			"groan" = 1,
			"hiss" = 1
		) = 20,
		list(
			"scream" = 1,
			"hiss" = 1,
		) = 50,
		list(
			"wheeze" = 1,
			"bellow" = 1,
			"howl" = 1
		) = 80
	)

/datum/species/lizard/get_deathgasp_sound(mob/living/carbon/human/H)
	return 'sound/voice/lizard/deathsound.ogg'

/// Lizards are cold blooded and do not stabilize body temperature naturally
/datum/species/lizard/body_temperature_core(mob/living/carbon/human/humi, delta_time, times_fired)
	return

/datum/species/lizard/random_name(gender,unique,lastname)
	if(unique)
		return random_unique_lizard_name(gender)

	var/randname = lizard_name(gender)

	if(lastname)
		randname += " [lastname]"

	return randname

/datum/species/lizard/randomize_main_appearance_element(mob/living/carbon/human/human_mob)
	var/tail = pick(GLOB.tails_list_lizard)
	human_mob.dna.features["tail_lizard"] = tail
	mutant_bodyparts["tail_lizard"] = tail
	human_mob.update_body()

/datum/species/lizard/get_scream_sound(mob/living/carbon/human/lizard)
	return pick(
		'sound/voice/lizard/lizard_scream_1.ogg',
		'sound/voice/lizard/lizard_scream_2.ogg',
		'sound/voice/lizard/lizard_scream_3.ogg',
	)

/datum/species/lizard/get_species_description()
	return {"
		The peaceful Jinan people originate from the planet Jitarai.
		They are adept with robotics and artifical intelligence,
		which is how their governing body came to be an AI known as Companion.
		"}

/datum/species/lizard/get_species_lore()
	return list(
		"The face of conspiracy theory was changed forever the day mankind met the lizards.",

		"Jinans are a species of intelligent humanoid reptiles from the planet Jitarai. They are most known for \
		their innovation in the field of robotics, at the time of first contact, they were over one hundred years \
		ahead of Humanity. Jitarai has one governing body, a century year old artificial intelligence known as Companion. \
		Developed by the Old Jinar (Great Ones) to lead their people to greatness, Companion succeeded it's goal \
		and united the planet under one government. Despite the success of the Companion project, some of the Jinan people \
		have a distrust in their artificial leader. Many seek to leave the planet as soon as they acquire means, be it out of fear \
		or disgust that their people are controlled by a machine. The way the government operates is not fully known, \
		with some outsiders theorizing there is a Jinan council that maintains Companion.",

		"The Jinan people created and popularized the Integrated Positronic Chassis (IPC), a fully autonomous robot capable \
		of performing the same tasks as a normal person. Their primary export is robotics equipment, industrial equipment, and positronic brains. \
		Many companies from Earth have created their own versions of IPCs, and sell them on the market with middling success.",

		"Jinans were the first species to be discovered by Humanity, with their probe having crash landed onto Mercury in 1953, \
		sparking the Space Race. Eventually, contact was made by the United States, and a positive relationship quickly \
		developed between the two peoples. ",
	)

// Override for the default temperature perks, so we can give our specific "cold blooded" perk.
/datum/species/lizard/create_pref_temperature_perks()
	var/list/to_add = list()

	to_add += list(list(
		SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
		SPECIES_PERK_ICON = "thermometer-empty",
		SPECIES_PERK_NAME = "Cold-blooded",
		SPECIES_PERK_DESC = "Jinans have higher tolerance for hot temperatures, but lower \
			tolerance for cold temperatures. Additionally, they cannot self-regulate their body temperature - \
			they are as cold or as warm as the environment around them is. Stay warm!",
	))

	return to_add
