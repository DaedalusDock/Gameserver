GLOBAL_LIST_EMPTY(roundstart_races)
GLOBAL_LIST_EMPTY(roundstart_races_by_type)

/// An assoc list of species types to their features (from get_features())
GLOBAL_LIST_EMPTY(features_by_species)

/**
 * # species datum
 *
 * Datum that handles different species in the game.
 *
 * This datum handles species in the game, such as lizardpeople, mothmen, zombies, skeletons, etc.
 * It is used in [carbon humans][mob/living/carbon/human] to determine various things about them, like their food preferences, if they have biological genders, their damage resistances, and more.
 *
 */
/datum/species
	///If the game needs to manually check your race to do something not included in a proc here, it will use this.
	var/id
	///This is the fluff name. They are displayed on health analyzers and in the character setup menu. Must be `\improper`.
	var/name
	/// The formatting of the name of the species in plural context. Defaults to "[name]\s" if unset.
	/// Ex "[Plasmamen] are weak", "[Mothmen] are strong", "[Lizardpeople] don't like", "[Golems] hate"
	var/plural_form
	// Default color. If mutant colors are disabled, this is the color that will be used by that race.
	var/default_color = "#FFFFFF"

	///Whether or not the race has sexual characteristics (biological genders). At the moment this is only FALSE for skeletons and shadows
	var/sexes = TRUE
	///A bitfield of "bodytypes", updated by /datum/obj/item/bodypart/proc/synchronize_bodytypes()
	var/bodytype = BODYTYPE_HUMANOID | BODYTYPE_ORGANIC
	///Clothing offsets. If a species has a different body than other species, you can offset clothing so they look less weird.
	var/list/offset_features = list(OFFSET_UNIFORM = list(0,0), OFFSET_ID = list(0,0), OFFSET_GLOVES = list(0,0), OFFSET_GLASSES = list(0,0), OFFSET_EARS = list(0,0), OFFSET_SHOES = list(0,0), OFFSET_S_STORE = list(0,0), OFFSET_FACEMASK = list(0,0), OFFSET_HEAD = list(0,0), OFFSET_FACE = list(0,0), OFFSET_BELT = list(0,0), OFFSET_BACK = list(0,0), OFFSET_SUIT = list(0,0), OFFSET_NECK = list(0,0))
	///If this species needs special 'fallback' sprites, what is the path to the file that contains them?
	var/fallback_clothing_path

	///The maximum number of bodyparts this species can have.
	var/max_bodypart_count = 6
	///This allows races to have specific hair colors. If null, it uses the H's hair/facial hair colors. If "mutcolor", it uses the H's mutant_color. If "fixedmutcolor", it uses fixedmutcolor
	var/hair_color
	///The alpha used by the hair. 255 is completely solid, 0 is invisible.
	var/hair_alpha = 255

	///This is used for children, it will determine their default limb ID for use of examine. See [/mob/living/carbon/human/proc/examine].
	var/examine_limb_id
	///Never, Optional, or Forced digi legs?
	var/digitigrade_customization = DIGITIGRADE_NEVER
	///Does the species use skintones or not? As of now only used by humans.
	var/use_skintones = FALSE
	///If your race bleeds something other than bog standard blood, change this to reagent id. For example, ethereals bleed liquid electricity.
	var/datum/reagent/exotic_blood

	///What the species drops when gibbed by a gibber machine.
	var/meat = /obj/item/food/meat/slab/human
	///What skin the species drops when gibbed by a gibber machine.
	var/skinned_type
	///Bitfield for food types that the species likes, giving them a mood boost. Lizards like meat, for example.
	var/liked_food = NONE
	///Bitfield for food types that the species dislikes, giving them disgust. Humans hate raw food, for example.
	var/disliked_food = GROSS
	///Bitfield for food types that the species absolutely hates, giving them even more disgust than disliked food. Meat is "toxic" to moths, for example.
	var/toxic_food = TOXIC
	///How are we treated regarding processing reagents, by default we process them as if we're organic
	var/reagent_flags = PROCESS_ORGANIC
	///Inventory slots the race can't equip stuff to. Golems cannot wear jumpsuits, for example.
	var/list/no_equip = list()
	/// Allows the species to equip items that normally require a jumpsuit without having one equipped. Used by golems.
	var/nojumpsuit = FALSE
	///Affects the speech message, for example: Motharula flutters, "My speech message is flutters!"
	var/say_mod = "says"
	///Affects the species' screams, for example: "Motharula buzzes!"
	var/scream_verb = "screams"
	///What languages this species can understand and say. Use a [language holder datum][/datum/language_holder] in this var.
	var/species_language_holder = /datum/language_holder
	/// DEPRECATED: Now only handles legs.
	var/list/mutant_bodyparts = list()
	///Internal organs that are unique to this race, like a tail.
	var/list/mutant_organs = list()
	///The bodyparts this species uses. assoc of bodypart string - bodypart type. Make sure all the fucking entries are in or I'll skin you alive.
	var/list/bodypart_overrides = list(
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right,
		BODY_ZONE_HEAD = /obj/item/bodypart/head,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left,
		BODY_ZONE_R_LEG = /obj/item/bodypart/leg/right,
		BODY_ZONE_CHEST = /obj/item/bodypart/chest,
	)

	/// Robotic bodyparts for preference selection
	var/list/robotic_bodyparts = list(
		BODY_ZONE_L_ARM = /obj/item/bodypart/arm/left/robot/surplus,
		BODY_ZONE_R_ARM = /obj/item/bodypart/arm/right/robot/surplus,
		BODY_ZONE_L_LEG = /obj/item/bodypart/leg/left/robot/surplus,
		BODY_ZONE_R_LEG= /obj/item/bodypart/leg/right/robot/surplus,
	)

	///List of cosmetic organs to generate like horns, frills, wings, etc. list(typepath of organ = "Round Beautiful BDSM Snout"). Still WIP
	var/list/cosmetic_organs = list()

	//* BODY TEMPERATURE THINGS *//
	var/cold_level_3 = 120
	var/cold_level_2 = 200
	var/cold_level_1 = BODYTEMP_COLD_DAMAGE_LIMIT
	var/cold_discomfort_level = 285

	/// The natural body temperature to adjust towards
	var/bodytemp_normal = BODYTEMP_NORMAL

	var/heat_discomfort_level = 315
	var/heat_level_1 = BODYTEMP_HEAT_DAMAGE_LIMIT
	var/heat_level_2 = 400
	var/heat_level_3 = 1000

	/// Minimum amount of kelvin moved toward normal body temperature per tick.
	var/bodytemp_autorecovery_min = BODYTEMP_AUTORECOVERY_MINIMUM
	var/list/heat_discomfort_strings = list(
		"You feel sweat drip down your neck.",
		"You feel uncomfortably warm.",
		"Your skin prickles in the heat."
		)
	var/list/cold_discomfort_strings = list(
		"You feel chilly.",
		"You shiver suddenly.",
		"Your chilly flesh stands out in goosebumps."
	)

	//* MODIFIERS *//
	///Multiplier for the race's speed. Positive numbers make it move slower, negative numbers make it move faster.
	var/speedmod = 0
	///Percentage modifier for overall defense of the race, or less defense, if it's negative.
	var/armor = 0
	///multiplier for brute damage
	var/brutemod = 1
	///multiplier for burn damage
	var/burnmod = 1
	///multiplier for damage from cold temperature
	var/coldmod = 1
	///multiplier for damage from hot temperature
	var/heatmod = 1
	///multiplier for stun durations
	var/stunmod = 1
	///Base electrocution coefficient.  Basically a multiplier for damage from electrocutions.
	var/siemens_coeff = 1
	///To use MUTCOLOR with a fixed color that's independent of the mcolor feature in DNA.
	var/fixed_mut_color = ""
	///Special mutation that can be found in the genepool exclusively in this species. Dont leave empty or changing species will be a headache
	var/inert_mutation = /datum/mutation/human/dwarfism
	///Sounds to override barefeet walking
	var/list/special_step_sounds
	///Special sound for grabbing
	var/grab_sound

	/// A path to an outfit that is important for species life e.g. vox outfit
	var/datum/outfit/outfit_important_for_life

	///Used for picking outfits in _job.dm
	var/job_outfit_type

	///Icon file used for eyes, defaults to 'icons/mob/human_face.dmi' if not set
	var/species_eye_path

	///Is this species a flying species? Used as an easy check for some things
	var/flying_species = FALSE
	///The actual flying ability given to flying species
	var/datum/action/innate/flight/fly
	//Dictates which wing icons are allowed for a given species. If count is >1 a radial menu is used to choose between all icons in list
	var/list/wings_icons = list("Angel")
	///Used to determine what description to give when using a potion of flight, if false it will describe them as growing new wings
	var/has_innate_wings = FALSE

	/// The icon_state of the fire overlay added when sufficently ablaze and standing. see onfire.dmi
	var/fire_overlay = "human_burning"

	///Species-only traits. Can be found in [code/__DEFINES/DNA.dm]
	var/list/species_traits = list()
	///Generic traits tied to having the species.
	var/list/inherent_traits = list(TRAIT_ADVANCEDTOOLUSER, TRAIT_CAN_STRIP)
	/// List of biotypes the mob belongs to. Used by diseases.
	var/inherent_biotypes = MOB_ORGANIC|MOB_HUMANOID
	///List of factions the mob gain upon gaining this species.
	var/list/inherent_factions
	/// The [/mob/living/var/mob_size] of members of this species.
	var/species_mob_size = MOB_SIZE_HUMAN

	///What gas does this species breathe? Used by suffocation screen alerts, most of actual gas breathing is handled by mutantlungs. See [life.dm][code/modules/mob/living/carbon/human/life.dm]
	var/breathid = GAS_OXYGEN

	///What anim to use for dusting
	var/dust_anim = "dust-h"
	///What anim to use for gibbing
	var/gib_anim = "gibbed-h"

	///Forces an item into this species' hands. Only an honorary mutantthing because this is not an organ and not loaded in the same way, you've been warned to do your research.
	var/obj/item/mutanthands

	/// A template for what organs this species should have.
	/// Assign null to simply exclude spawning with one.
	var/list/organs = list(
		ORGAN_SLOT_BRAIN = /obj/item/organ/brain,
		ORGAN_SLOT_HEART = /obj/item/organ/heart,
		ORGAN_SLOT_LUNGS = /obj/item/organ/lungs,
		ORGAN_SLOT_EYES = /obj/item/organ/eyes,
		ORGAN_SLOT_EARS =  /obj/item/organ/ears,
		ORGAN_SLOT_TONGUE = /obj/item/organ/tongue,
		ORGAN_SLOT_STOMACH = /obj/item/organ/stomach,
		ORGAN_SLOT_APPENDIX = /obj/item/organ/appendix,
		ORGAN_SLOT_LIVER = /obj/item/organ/liver,
		ORGAN_SLOT_KIDNEYS = /obj/item/organ/kidneys,
	)

	///Bitflag that controls what in game ways something can select this species as a spawnable source, such as magic mirrors. See [mob defines][code/__DEFINES/mobs.dm] for possible sources.
	var/changesource_flags = null

	///Unique cookie given by admins through prayers
	var/species_cookie = /obj/item/food/cookie

	///For custom overrides for species ass images
	var/icon/ass_image

	/// List of family heirlooms this species can get with the family heirloom quirk. List of types.
	var/list/family_heirlooms

	///List of results you get from knife-butchering. null means you cant butcher it. Associated by resulting type - value of amount
	var/list/knife_butcher_results

	/// Should we preload this species's organs?
	var/preload = TRUE

	/// Do we try to prevent reset_perspective() from working? Useful for Dullahans to stop perspective changes when they're looking through their head.
	var/prevent_perspective_change = FALSE

	///Was the species changed from its original type at the start of the round?
	var/roundstart_changed = FALSE

	var/properly_gained = FALSE

	/// A list of weighted lists to pain emotes. The list with the LOWEST damage requirement needs to be first.
	var/list/pain_emotes = list(
		list(
			"grunts in pain" = 1,
			"moans in pain" = 1,
		) = PAIN_AMT_LOW,

		list(
			"pain" = 1,
		) = PAIN_AMT_MEDIUM,

		list(
			"agony" = 1,
		) = PAIN_AMT_AGONIZING,
	)

///////////
// PROCS //
///////////


/datum/species/New()
	wings_icons = string_list(wings_icons)

	//This isn't a simple \s use because it fucks up the codex.
	plural_form ||= findtext_char(name, "s", -1) ? name : "[name]s"

	return ..()

/// Gets a list of all species available to choose in roundstart.
/proc/get_selectable_species()
	RETURN_TYPE(/list)

	if (!GLOB.roundstart_races.len)
		generate_selectable_species()

	return GLOB.roundstart_races

/proc/get_selectable_species_by_type()
	RETURN_TYPE(/list)

	if (!GLOB.roundstart_races_by_type.len)
		generate_selectable_species()

	return GLOB.roundstart_races_by_type

/**
 * Generates species available to choose in character setup at roundstart
 *
 * This proc generates which species are available to pick from in character setup.
 * If there are no available roundstart species, defaults to human.
 */
/proc/generate_selectable_species()
	var/list/selectable_species = list()
	var/list/species_by_type = list()

	for(var/species_type in subtypesof(/datum/species))
		var/datum/species/species = new species_type
		if(species.check_roundstart_eligible())
			selectable_species += species.id
			species_by_type += species_type
			qdel(species)

	if(!selectable_species.len)
		selectable_species += SPECIES_HUMAN
		species_by_type += /datum/species/human

	GLOB.roundstart_races = selectable_species
	GLOB.roundstart_races_by_type = species_by_type
	return

/**
 * Checks if a species is eligible to be picked at roundstart.
 *
 * Checks the config to see if this species is allowed to be picked in the character setup menu.
 * Used by [/proc/generate_selectable_species].
 */
/datum/species/proc/check_roundstart_eligible()
	if(id in (CONFIG_GET(keyed_list/roundstart_races)))
		return TRUE
	return FALSE

/**
 * Generates a random name for a carbon.
 *
 * This generates a random unique name based on a human's species and gender.
 * Arguments:
 * * gender - The gender that the name should adhere to. Use MALE for male names, use anything else for female names.
 * * unique - If true, ensures that this new name is not a duplicate of anyone else's name currently on the station.
 * * lastname - Does this species' naming system adhere to the last name system? Set to false if it doesn't.
 */
/datum/species/proc/random_name(gender,unique,lastname)
	if(unique)
		return random_unique_name(gender)

	var/randname
	if(gender == MALE)
		randname = pick(GLOB.first_names_male)
	else
		randname = pick(GLOB.first_names_female)

	if(lastname)
		randname += " [lastname]"
	else
		randname += " [pick(GLOB.last_names)]"

	return randname

/**
 * Copies some vars and properties over that should be kept when creating a copy of this species.
 *
 * Used by slimepeople to copy themselves, and by the DNA datum to hardset DNA to a species
 * Arguments:
 * * old_species - The species that the carbon used to be before copying
 */
/datum/species/proc/copy_properties_from(datum/species/old_species)
	return

/datum/species/proc/should_organ_apply_to(mob/living/carbon/target, obj/item/organ/organpath)
	if(isnull(organpath) || isnull(target))
		CRASH("passed a null path or mob to 'should_external_organ_apply_to'")

	var/feature_key = initial(organpath.feature_key)
	if(isnull(feature_key))
		return TRUE

	if(target.dna.features[feature_key] != SPRITE_ACCESSORY_NONE)
		return TRUE
	return FALSE

/**
 * Corrects organs in a carbon, removing ones it doesn't need and adding ones it does.
 *
 * Takes all organ slots, removes organs a species should not have, adds organs a species should have.
 * can use replace_current to refresh all organs, creating an entirely new set.
 *
 * Arguments:
 * * C - carbon, the owner of the species datum AKA whoever we're regenerating organs in
 * * old_species - datum, used when regenerate organs is called in a switching species to remove old mutant organs.
 * * replace_current - boolean, forces all old organs to get deleted whether or not they pass the species' ability to keep that organ
 * * excluded_zones - list, add zone defines to block organs inside of the zones from getting handled. see headless mutation for an example
 * * visual_only - boolean, only load organs that change how the species looks. Do not use for normal gameplay stuff
 */
/datum/species/proc/regenerate_organs(mob/living/carbon/C, datum/species/old_species, replace_current = TRUE, list/excluded_zones, visual_only = FALSE)
	for(var/slot in organs)
		var/obj/item/organ/oldorgan = C.getorganslot(slot) //used in removing
		var/obj/item/organ/neworgan = organs[slot] //used in adding

		if(visual_only && !initial(neworgan.visual))
			continue

		var/used_neworgan = FALSE
		var/should_have = !!neworgan
		if(should_have)
			neworgan = SSwardrobe.provide_type(neworgan)

		if(oldorgan && (!should_have || replace_current) && !(oldorgan.zone in excluded_zones) && !(oldorgan.organ_flags & ORGAN_UNREMOVABLE))
			if(slot == ORGAN_SLOT_BRAIN)
				var/obj/item/organ/brain/brain = oldorgan
				if(!brain.decoy_override)//"Just keep it if it's fake" - confucius, probably
					brain.before_organ_replacement(neworgan)
					brain.Remove(C,TRUE) //brain argument used so it doesn't cause any... sudden death.
					QDEL_NULL(brain)
					oldorgan = null //now deleted
			else
				oldorgan.before_organ_replacement(neworgan)
				oldorgan.Remove(C,TRUE)
				QDEL_NULL(oldorgan) //we cannot just tab this out because we need to skip the deleting if it is a decoy brain.
				oldorgan = null

		if(oldorgan)
			oldorgan.setOrganDamage(0)
			oldorgan.germ_level = 0
		else if(should_have && !(initial(neworgan.zone) in excluded_zones))
			used_neworgan = TRUE
			neworgan.Insert(C, TRUE, FALSE)

		if(!used_neworgan)
			qdel(neworgan)

	if(old_species)
		for(var/mutantorgan in old_species.mutant_organs)
			// Snowflake check. If our species share this mutant organ, let's not remove it
			// just yet as we'll be properly replacing it later.
			if(mutantorgan in mutant_organs)
				continue
			var/obj/item/organ/I = C.getorgan(mutantorgan)
			if(I)
				I.Remove(C, TRUE)
				qdel(I)

		for(var/mutantorgan in old_species.cosmetic_organs)
			if(mutantorgan in cosmetic_organs)
				continue
			var/obj/item/organ/I = C.getorgan(mutantorgan)
			if(I)
				I.Remove(C)
				qdel(I)

		if(replace_current)
			for(var/slot in old_species.organs)
				if(!(slot in organs))
					var/obj/item/organ/O = C.getorganslot(slot)
					if(!O)
						continue
					O.Remove(C, TRUE)
					qdel(O)

	for(var/organ_path in mutant_organs)
		var/obj/item/organ/current_organ = C.getorgan(organ_path)
		if(!current_organ || replace_current)
			var/obj/item/organ/replacement = SSwardrobe.provide_type(organ_path)
			// If there's an existing mutant organ, we're technically replacing it.
			// Let's abuse the snowflake proc that skillchips added. Basically retains
			// feature parity with every other organ too.
			if(current_organ)
				current_organ.before_organ_replacement(replacement)
			// organ.Insert will qdel any current organs in that slot, so we don't need to.
			replacement.Insert(C, TRUE, FALSE)

	for(var/obj/item/organ/organ_path as anything in cosmetic_organs)
		if(!should_organ_apply_to(C, organ_path))
			continue
		//Load a persons preferences from DNA
		var/obj/item/organ/new_organ = SSwardrobe.provide_type(organ_path)
		new_organ.Insert(C, FALSE, FALSE)

/**
 * Proc called when a carbon becomes this species.
 *
 * This sets up and adds/changes/removes things, qualities, abilities, and traits so that the transformation is as smooth and bugfree as possible.
 * Produces a [COMSIG_SPECIES_GAIN] signal.
 * Arguments:
 * * C - Carbon, this is whoever became the new species.
 * * old_species - The species that the carbon used to be before becoming this race, used for regenerating organs.
 * * pref_load - Preferences to be loaded from character setup, loads in preferred mutant things like bodyparts, digilegs, skin color, etc.
 */
/datum/species/proc/on_species_gain(mob/living/carbon/C, datum/species/old_species, pref_load)
	SHOULD_CALL_PARENT(TRUE)
	// Drop the items the new species can't wear
	if((AGENDER in species_traits))
		C.gender = PLURAL
	for(var/slot_id in no_equip)
		var/obj/item/thing = C.get_item_by_slot(slot_id)
		if(thing && (!thing.species_exception || !is_type_in_list(src,thing.species_exception)))
			C.dropItemToGround(thing)
	if(C.hud_used)
		C.hud_used.update_locked_slots()

	C.mob_size = species_mob_size
	C.mob_biotypes = inherent_biotypes

	if(type != old_species?.type)
		replace_body(C, src)

	regenerate_organs(C, old_species, visual_only = C.visual_only_organs)

	C.dna.blood_type = get_random_blood_type()

	if(old_species.mutanthands)
		for(var/obj/item/I in C.held_items)
			if(istype(I, old_species.mutanthands))
				qdel(I)

	if(mutanthands)
		// Drop items in hands
		// If you're lucky enough to have a TRAIT_NODROP item, then it stays.
		for(var/V in C.held_items)
			var/obj/item/I = V
			if(istype(I))
				C.dropItemToGround(I)
			else //Entries in the list should only ever be items or null, so if it's not an item, we can assume it's an empty hand
				INVOKE_ASYNC(C, TYPE_PROC_REF(/mob, put_in_hands), new mutanthands)

	for(var/X in inherent_traits)
		ADD_TRAIT(C, X, SPECIES_TRAIT)

	if(TRAIT_VIRUSIMMUNE in inherent_traits)
		for(var/datum/pathogen/A in C.diseases)
			A.force_cure(add_resistance = FALSE)

	if(TRAIT_TOXIMMUNE in inherent_traits)
		C.setToxLoss(0, TRUE, TRUE)

	if(TRAIT_NOMETABOLISM in inherent_traits)
		C.reagents.end_metabolization(C, keep_liverless = TRUE)

	if(TRAIT_GENELESS in inherent_traits)
		C.dna.remove_all_mutations() // Radiation immune mobs can't get mutations normally

	if(inherent_factions)
		for(var/i in inherent_factions)
			C.faction += i //Using +=/-= for this in case you also gain the faction from a different source.

	if(flying_species && isnull(fly))
		fly = new
		fly.Grant(C)

	C.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/species, slowdown=speedmod)

	SEND_SIGNAL(C, COMSIG_SPECIES_GAIN, src, old_species)

	properly_gained = TRUE

/**
 * Proc called when a carbon is no longer this species.
 *
 * This sets up and adds/changes/removes things, qualities, abilities, and traits so that the transformation is as smooth and bugfree as possible.
 * Produces a [COMSIG_SPECIES_LOSS] signal.
 * Arguments:
 * * C - Carbon, this is whoever lost this species.
 * * new_species - The new species that the carbon became, used for genetics mutations.
 * * pref_load - Preferences to be loaded from character setup, loads in preferred mutant things like bodyparts, digilegs, skin color, etc.
 */
/datum/species/proc/on_species_loss(mob/living/carbon/human/C, datum/species/new_species, pref_load)
	SHOULD_CALL_PARENT(TRUE)
	for(var/X in inherent_traits)
		REMOVE_TRAIT(C, X, SPECIES_TRAIT)

	for(var/path in cosmetic_organs)
		var/obj/item/organ/organ = locate(path) in C.organs
		if(!organ)
			continue
		organ.Remove(C, TRUE)
		qdel(organ)

	//If their inert mutation is not the same, swap it out
	if((inert_mutation != new_species.inert_mutation) && LAZYLEN(C.dna.mutation_index) && (inert_mutation in C.dna.mutation_index))
		C.dna.remove_mutation(inert_mutation)
		//keep it at the right spot, so we can't have people taking shortcuts
		var/location = C.dna.mutation_index.Find(inert_mutation)
		C.dna.mutation_index[location] = new_species.inert_mutation
		C.dna.default_mutation_genes[location] = C.dna.mutation_index[location]
		C.dna.mutation_index[new_species.inert_mutation] = create_sequence(new_species.inert_mutation)
		C.dna.default_mutation_genes[new_species.inert_mutation] = C.dna.mutation_index[new_species.inert_mutation]

	if(inherent_factions)
		for(var/i in inherent_factions)
			C.faction -= i

	C.remove_movespeed_modifier(/datum/movespeed_modifier/species)

	SEND_SIGNAL(C, COMSIG_SPECIES_LOSS, src)

/**
 * Handles the body of a human
 *
 * Handles lipstick, having no eyes, eye color, undergarnments like underwear, undershirts, and socks, and body layers.
 * Calls [handle_mutant_bodyparts][/datum/species/proc/handle_mutant_bodyparts]
 * Arguments:
 * * species_human - Human, whoever we're handling the body for
 */
/datum/species/proc/handle_body(mob/living/carbon/human/species_human)
	species_human.remove_overlay(BODY_LAYER)
	if(HAS_TRAIT(species_human, TRAIT_INVISIBLE_MAN))
		return
	var/list/standing = list()

	var/obj/item/bodypart/head/noggin = species_human.get_bodypart(BODY_ZONE_HEAD)

	if(noggin && !(HAS_TRAIT(species_human, TRAIT_HUSK)))
		// lipstick
		if(species_human.lip_style && (LIPS in species_traits))
			var/mutable_appearance/lip_overlay = mutable_appearance('icons/mob/human_face.dmi', "lips_[species_human.lip_style]", -BODY_LAYER)
			lip_overlay.color = species_human.lip_color
			if(OFFSET_FACE in species_human.dna.species.offset_features)
				lip_overlay.pixel_x += species_human.dna.species.offset_features[OFFSET_FACE][1]
				lip_overlay.pixel_y += species_human.dna.species.offset_features[OFFSET_FACE][2]
			standing += lip_overlay

		// blush
		if (HAS_TRAIT(species_human, TRAIT_BLUSHING)) // Caused by either the *blush emote or the "drunk" mood event
			var/mutable_appearance/blush_overlay = mutable_appearance('icons/mob/human_face.dmi', "blush", -BODY_ADJ_LAYER) //should appear behind the eyes
			blush_overlay.color = COLOR_BLUSH_PINK
			standing += blush_overlay

	// organic body markings
	if(HAS_MARKINGS in species_traits)
		var/obj/item/bodypart/chest/chest = species_human.get_bodypart(BODY_ZONE_CHEST)
		var/obj/item/bodypart/arm/right/right_arm = species_human.get_bodypart(BODY_ZONE_R_ARM)
		var/obj/item/bodypart/arm/left/left_arm = species_human.get_bodypart(BODY_ZONE_L_ARM)
		var/obj/item/bodypart/leg/right/right_leg = species_human.get_bodypart(BODY_ZONE_R_LEG)
		var/obj/item/bodypart/leg/left/left_leg = species_human.get_bodypart(BODY_ZONE_L_LEG)
		var/datum/sprite_accessory/markings = GLOB.moth_markings_list[species_human.dna.features["moth_markings"]]

		if(!HAS_TRAIT(species_human, TRAIT_HUSK))
			if(noggin && (IS_ORGANIC_LIMB(noggin)))
				var/mutable_appearance/markings_head_overlay = mutable_appearance(markings.icon, "[markings.icon_state]_head", -BODY_LAYER)
				standing += markings_head_overlay

			if(chest && (IS_ORGANIC_LIMB(chest)))
				var/mutable_appearance/markings_chest_overlay = mutable_appearance(markings.icon, "[markings.icon_state]_chest", -BODY_LAYER)
				standing += markings_chest_overlay

			if(right_arm && (IS_ORGANIC_LIMB(right_arm)))
				var/mutable_appearance/markings_r_arm_overlay = mutable_appearance(markings.icon, "[markings.icon_state]_r_arm", -BODY_LAYER)
				standing += markings_r_arm_overlay

			if(left_arm && (IS_ORGANIC_LIMB(left_arm)))
				var/mutable_appearance/markings_l_arm_overlay = mutable_appearance(markings.icon, "[markings.icon_state]_l_arm", -BODY_LAYER)
				standing += markings_l_arm_overlay

			if(right_leg && (IS_ORGANIC_LIMB(right_leg)))
				var/mutable_appearance/markings_r_leg_overlay = mutable_appearance(markings.icon, "[markings.icon_state]_r_leg", -BODY_LAYER)
				standing += markings_r_leg_overlay

			if(left_leg && (IS_ORGANIC_LIMB(left_leg)))
				var/mutable_appearance/markings_l_leg_overlay = mutable_appearance(markings.icon, "[markings.icon_state]_l_leg", -BODY_LAYER)
				standing += markings_l_leg_overlay

	//Underwear, Undershirts & Socks
	if(!(NO_UNDERWEAR in species_traits))
		if(species_human.underwear)
			var/datum/sprite_accessory/underwear/underwear = GLOB.underwear_list[species_human.underwear]
			var/mutable_appearance/underwear_overlay
			if(underwear)
				if(species_human.dna.species.sexes && species_human.physique == FEMALE && (underwear.gender == MALE))
					underwear_overlay = wear_female_version(underwear.icon_state, underwear.icon, BODY_LAYER, FEMALE_UNIFORM_FULL)
				else
					underwear_overlay = mutable_appearance(underwear.icon, underwear.icon_state, -BODY_LAYER)
				if(!underwear.use_static)
					underwear_overlay.color = species_human.underwear_color
				standing += underwear_overlay

		if(species_human.undershirt)
			var/datum/sprite_accessory/undershirt/undershirt = GLOB.undershirt_list[species_human.undershirt]
			if(undershirt)
				if(species_human.dna.species.sexes && species_human.physique == FEMALE)
					standing += wear_female_version(undershirt.icon_state, undershirt.icon, BODY_LAYER)
				else
					standing += mutable_appearance(undershirt.icon, undershirt.icon_state, -BODY_LAYER)

		if(species_human.socks && species_human.num_legs >= 2 && !(src.bodytype & BODYTYPE_DIGITIGRADE))
			var/datum/sprite_accessory/socks/socks = GLOB.socks_list[species_human.socks]
			if(socks)
				standing += mutable_appearance(socks.icon, socks.icon_state, -BODY_LAYER)

	if(standing.len)
		species_human.overlays_standing[BODY_LAYER] = standing

	species_human.apply_overlay(BODY_LAYER)

//This exists so sprite accessories can still be per-layer without having to include that layer's
//number in their sprite name, which causes issues when those numbers change.
/datum/species/proc/mutant_bodyparts_layertext(layer)
	switch(layer)
		if(BODY_BEHIND_LAYER)
			return "BEHIND"
		if(BODY_ADJ_LAYER)
			return "ADJ"
		if(BODY_FRONT_LAYER)
			return "FRONT"

///Proc that will randomise the hair, or primary appearance element (i.e. for moths wings) of a species' associated mob
/datum/species/proc/randomize_main_appearance_element(mob/living/carbon/human/human_mob)
	human_mob.hairstyle = random_hairstyle(human_mob.gender)
	human_mob.update_body_parts()

///Proc that will randomise the underwear (i.e. top, pants and socks) of a species' associated mob
/datum/species/proc/randomize_active_underwear(mob/living/carbon/human/human_mob)
	human_mob.undershirt = random_undershirt(human_mob.gender)
	human_mob.underwear = random_underwear(human_mob.gender)
	human_mob.socks = random_socks(human_mob.gender)
	human_mob.update_body()

/datum/species/proc/spec_life(mob/living/carbon/human/H, delta_time, times_fired)
	// If you're dirty, your gloves will become dirty, too.
	if(H.gloves && (H.germ_level > H.gloves.germ_level) && prob(10))
		H.gloves.germ_level += 1

/datum/species/proc/spec_death(gibbed, mob/living/carbon/human/H)
	return

/datum/species/proc/can_equip(obj/item/I, slot, disable_warning, mob/living/carbon/human/H, bypass_equip_delay_self = FALSE)
	if(slot in no_equip)
		if(!I.species_exception || !is_type_in_list(src, I.species_exception))
			return FALSE

	// if there's an item in the slot we want, fail
	if(H.get_item_by_slot(slot))
		return FALSE

	// For whatever reason, this item cannot be equipped by this species
	if(slot != ITEM_SLOT_HANDS && (bodytype & I.restricted_bodytypes))
		return FALSE

	// this check prevents us from equipping something to a slot it doesn't support, WITH the exceptions of storage slots (pockets, suit storage, and backpacks)
	// we don't require having those slots defined in the item's slot_flags, so we'll rely on their own checks further down
	if(!(I.slot_flags & slot))
		var/excused = FALSE
		// Anything that's small or smaller can fit into a pocket by default
		if((slot == ITEM_SLOT_RPOCKET || slot == ITEM_SLOT_LPOCKET) && I.w_class <= WEIGHT_CLASS_SMALL)
			excused = TRUE
		else if(slot == ITEM_SLOT_SUITSTORE || slot == ITEM_SLOT_BACKPACK || slot == ITEM_SLOT_HANDS || slot == ITEM_SLOT_HANDCUFFED || slot == ITEM_SLOT_LEGCUFFED)
			excused = TRUE
		if(!excused)
			return FALSE

	switch(slot)
		if(ITEM_SLOT_HANDS)
			var/empty_hands = length(H.get_empty_held_indexes())
			if(HAS_TRAIT(I, TRAIT_NEEDS_TWO_HANDS) && ((empty_hands < 2) || H.usable_hands < 2))
				if(!disable_warning)
					to_chat(H, span_warning("You need two hands to hold [I]."))
				return FALSE

			if(empty_hands)
				return TRUE
			return FALSE

		if(ITEM_SLOT_MASK)
			if(!H.get_bodypart(BODY_ZONE_HEAD))
				return FALSE
			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_NECK)
			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_BACK)
			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_OCLOTHING)
			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_GLOVES)
			if(H.num_hands < 2)
				return FALSE
			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_FEET)
			if(H.num_legs < 2)
				return FALSE

			if((bodytype & BODYTYPE_DIGITIGRADE) && !(I.item_flags & IGNORE_DIGITIGRADE))
				if(!(I.supports_variations_flags & (CLOTHING_DIGITIGRADE_VARIATION|CLOTHING_DIGITIGRADE_VARIATION_NO_NEW_ICON)))
					if(!disable_warning)
						to_chat(H, span_warning("The footwear around here isn't compatible with your feet!"))
					return FALSE

			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_BELT)
			var/obj/item/bodypart/O = H.get_bodypart(BODY_ZONE_CHEST)

			if(!H.w_uniform && !nojumpsuit && (!O || IS_ORGANIC_LIMB(O)))
				if(!disable_warning)
					to_chat(H, span_warning("You need a jumpsuit before you can attach this [I.name]!"))
				return FALSE

			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_EYES)
			if(!H.get_bodypart(BODY_ZONE_HEAD))
				return FALSE

			var/obj/item/organ/eyes/E = H.getorganslot(ORGAN_SLOT_EYES)
			if(E?.no_glasses)
				return FALSE

			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_HEAD)
			if(!H.get_bodypart(BODY_ZONE_HEAD))
				return FALSE

			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_EARS)
			if(!H.get_bodypart(BODY_ZONE_HEAD))
				return FALSE

			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_ICLOTHING)
			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_ID)
			var/obj/item/bodypart/O = H.get_bodypart(BODY_ZONE_CHEST)
			if(!H.w_uniform && !nojumpsuit && (!O || IS_ORGANIC_LIMB(O)))
				if(!disable_warning)
					to_chat(H, span_warning("You need a jumpsuit before you can attach this [I.name]!"))
				return FALSE

			return H.equip_delay_self_check(I, bypass_equip_delay_self)

		if(ITEM_SLOT_LPOCKET)
			if(HAS_TRAIT(I, TRAIT_NODROP)) //Pockets aren't visible, so you can't move TRAIT_NODROP items into them.
				return FALSE
			if(H.l_store) // no pocket swaps at all
				return FALSE

			var/obj/item/bodypart/O = H.get_bodypart(BODY_ZONE_L_LEG)
			if(!H.w_uniform && !nojumpsuit && (!O || IS_ORGANIC_LIMB(O)))
				if(!disable_warning)
					to_chat(H, span_warning("You need a jumpsuit before you can attach this [I.name]!"))
				return FALSE

			return TRUE

		if(ITEM_SLOT_RPOCKET)
			if(HAS_TRAIT(I, TRAIT_NODROP))
				return FALSE
			if(H.r_store)
				return FALSE

			var/obj/item/bodypart/O = H.get_bodypart(BODY_ZONE_R_LEG)

			if(!H.w_uniform && !nojumpsuit && (!O || IS_ORGANIC_LIMB(O)))
				if(!disable_warning)
					to_chat(H, span_warning("You need a jumpsuit before you can attach this [I.name]!"))
				return FALSE

			return TRUE

		if(ITEM_SLOT_SUITSTORE)
			if(HAS_TRAIT(I, TRAIT_NODROP))
				return FALSE

			if(!H.wear_suit)
				if(!disable_warning)
					to_chat(H, span_warning("You need a suit before you can attach this [I.name]!"))
				return FALSE

			if(!H.wear_suit.allowed)
				if(!disable_warning)
					to_chat(H, span_warning("You somehow have a suit with no defined allowed items for suit storage, stop that."))
				return FALSE

			if(I.w_class > WEIGHT_CLASS_BULKY)
				if(!disable_warning)
					to_chat(H, span_warning("The [I.name] is too big to attach!")) //should be src?
				return FALSE

			if( istype(I, /obj/item/modular_computer/tablet) || istype(I, /obj/item/pen) || is_type_in_list(I, H.wear_suit.allowed) )
				return TRUE

			return FALSE

		if(ITEM_SLOT_HANDCUFFED)
			if(H.handcuffed)
				return FALSE
			if(!istype(I, /obj/item/restraints/handcuffs))
				return FALSE
			if(H.num_hands < 2)
				return FALSE
			return TRUE

		if(ITEM_SLOT_LEGCUFFED)
			if(H.legcuffed)
				return FALSE
			if(!istype(I, /obj/item/restraints/legcuffs))
				return FALSE
			if(H.num_legs < 2)
				return FALSE
			return TRUE

		if(ITEM_SLOT_BACKPACK)
			if(H.back && H.back.atom_storage?.can_insert(I, H, messages = TRUE))
				return TRUE
			return FALSE

	return FALSE //Unsupported slot

/datum/species/proc/equip_delay_self_check(obj/item/I, mob/living/carbon/human/H, bypass_equip_delay_self)
	if(!I.equip_delay_self || bypass_equip_delay_self)
		return TRUE

	H.visible_message(
		span_notice("[H] start putting on [I]..."),
		span_notice("You start putting on [I]...")
	)
	return do_after(H, H, I.equip_delay_self, DO_PUBLIC, display = I)

/// Equips the necessary species-relevant gear before putting on the rest of the uniform.
/datum/species/proc/pre_equip_species_outfit(datum/outfit/O, mob/living/carbon/human/equipping, visuals_only = FALSE)
	return

/**
 * Equip the outfit required for life. Replaces items currently worn.
 */
/datum/species/proc/give_important_for_life(mob/living/carbon/human/human_to_equip)
	if(!outfit_important_for_life)
		return

	human_to_equip.equipOutfit(outfit_important_for_life)

/**
 * Species based handling for irradiation
 *
 * Arguments:
 * - [source][/mob/living/carbon/human]: The mob requesting handling
 * - time_since_irradiated: The amount of time since the mob was first irradiated
 * - delta_time: The amount of time that has passed since the last tick
 */
/datum/species/proc/handle_radiation(mob/living/carbon/human/source, time_since_irradiated, delta_time)
	if(time_since_irradiated > RAD_MOB_KNOCKDOWN && DT_PROB(RAD_MOB_KNOCKDOWN_PROB, delta_time))
		if(!source.IsParalyzed())
			source.emote("collapse")
		source.Paralyze(RAD_MOB_KNOCKDOWN_AMOUNT)
		to_chat(source, span_danger("You feel weak."))

	if(time_since_irradiated > RAD_MOB_VOMIT && DT_PROB(RAD_MOB_VOMIT_PROB, delta_time))
		source.vomit(10, TRUE)

	if(time_since_irradiated > RAD_MOB_MUTATE && DT_PROB(RAD_MOB_MUTATE_PROB, delta_time))
		to_chat(source, span_danger("You mutate!"))
		source.easy_random_mutate(NEGATIVE + MINOR_NEGATIVE)
		source.emote("gasp")
		source.domutcheck()

	if(time_since_irradiated > RAD_MOB_HAIRLOSS && DT_PROB(RAD_MOB_HAIRLOSS_PROB, delta_time))
		if(source.has_hair(TRUE))
			to_chat(source, span_danger("Your hair starts to fall out in clumps..."))
			addtimer(CALLBACK(src, PROC_REF(go_bald), source), 5 SECONDS)

/**
 * Makes the target human bald.
 *
 * Arguments:
 * - [target][/mob/living/carbon/human]: The mob to make go bald.
 */
/datum/species/proc/go_bald(mob/living/carbon/human/target)
	if(QDELETED(target)) //may be called from a timer
		return
	target.facial_hairstyle = "Shaved"
	target.hairstyle = "Bald"
	target.update_body_parts()

//////////////////
// ATTACK PROCS //
//////////////////

/datum/species/proc/spec_updatehealth(mob/living/carbon/human/H)
	return

/datum/species/proc/spec_fully_heal(mob/living/carbon/human/H)
	return


/datum/species/proc/help(mob/living/carbon/human/user, mob/living/carbon/human/target, datum/martial_art/attacker_style)
	target.add_fingerprint_on_clothing_or_self(user, BODY_ZONE_CHEST)

	if(target.body_position == STANDING_UP || (target.health >= 0 && !(HAS_TRAIT(target, TRAIT_FAKEDEATH) || target.undergoing_cardiac_arrest())))
		target.help_shake_act(user)
		if(target != user)
			log_combat(user, target, "shaken")
		return TRUE

	user.do_cpr(target)

/datum/species/proc/grab(mob/living/carbon/human/user, mob/living/carbon/human/target, datum/martial_art/attacker_style, list/params)
	if(attacker_style?.grab_act(user,target) == MARTIAL_ATTACK_SUCCESS)
		return TRUE

	else
		user.try_make_grab(target, use_offhand = params?[RIGHT_CLICK])
		return TRUE

///This proc handles punching damage.
/datum/species/proc/harm(mob/living/carbon/human/user, mob/living/carbon/human/target, datum/martial_art/attacker_style)
	// Pacifists can't harm.
	if(HAS_TRAIT(user, TRAIT_PACIFISM))
		to_chat(user, span_warning("You don't want to harm [target]!"))
		return FALSE

	// If martial arts did something, bail.
	if(attacker_style?.harm_act(user,target) == MARTIAL_ATTACK_SUCCESS)
		return ATTACK_HANDLED

	// Find what bodypart we are attacking with.
	var/obj/item/organ/brain/brain = user.getorganslot(ORGAN_SLOT_BRAIN)
	var/obj/item/bodypart/attacking_bodypart
	if(brain)
		attacking_bodypart = brain.get_attacking_limb(target)

	if(!attacking_bodypart)
		attacking_bodypart = user.get_active_hand()

	var/atk_verb = attacking_bodypart.unarmed_attack_verb
	var/atk_effect = attacking_bodypart.unarmed_attack_effect

	// If we're biting them, make sure we can bite, or bail.
	if(atk_effect == ATTACK_EFFECT_BITE)
		if(!user.has_mouth())
			to_chat(user, span_warning("You can't [atk_verb] without a mouth!"))
			return FALSE

		if(user.is_mouth_covered(mask_only = TRUE))
			to_chat(user, span_warning("You can't [atk_verb] with your mouth covered!"))
			return FALSE

	// By this point, we are attempting an attack!!!
	user.do_attack_animation(target, atk_effect)

	// Set damage and find hit bodypart using weighted rng
	var/target_zone = deprecise_zone(user.zone_selected)
	var/bodyzone_modifier = GLOB.bodyzone_gurps_mods[target_zone]
	var/roll = !HAS_TRAIT(user, TRAIT_PERFECT_ATTACKER) ? user.stat_roll(10, /datum/rpg_skill/skirmish, bodyzone_modifier, -7, target).outcome : SUCCESS
	// If we succeeded, hit the target area.
	var/attacking_zone = (roll >= SUCCESS) ? target_zone : target.get_random_valid_zone()
	var/obj/item/bodypart/affecting
	if(attacking_zone)
		affecting = target.get_bodypart(attacking_zone)

	var/damage = rand(attacking_bodypart.unarmed_damage_low, attacking_bodypart.unarmed_damage_high)

	if(!damage || !affecting || roll == CRIT_FAILURE)
		var/rolled = target.body_position == LYING_DOWN && !target.incapacitated()
		playsound(target.loc, attacking_bodypart.unarmed_miss_sound, 25, TRUE, -1)

		target.visible_message(
			span_danger("[user]'s [atk_verb] misses [target][rolled ? "as [target.p_they()] roll out of the way" : ""]!"),
			null,
			span_hear("You hear a swoosh!"),
			COMBAT_MESSAGE_RANGE,
		)
		if(rolled)
			target.setDir(pick(GLOB.cardinals))

		log_combat(user, target, "attempted to punch (missed)")
		return FALSE

	switch(atk_effect)
		if(ATTACK_EFFECT_BITE)
			target.add_trace_DNA_on_clothing_or_self(user, attacking_zone)
		if(ATTACK_EFFECT_PUNCH, ATTACK_EFFECT_CLAW, ATTACK_EFFECT_SLASH)
			target.add_fingerprint_on_clothing_or_self(user, attacking_zone)

	var/armor_block = target.run_armor_check(affecting, BLUNT)

	playsound(target.loc, attacking_bodypart.unarmed_attack_sound, 25, TRUE, -1)

	user.visible_message(
		span_danger("<b>[user]</b> [atk_verb]ed <b>[target]</b> in the [affecting.plaintext_zone]!"),
		null,
		span_hear("You hear a scuffle!"),
		COMBAT_MESSAGE_RANGE
	)

	target.lastattacker = user.real_name
	target.lastattackerckey = user.ckey

	if(user.limb_destroyer)
		target.dismembering_strike(user, affecting.body_zone)

	var/attack_direction = get_dir(user, target)
	var/attack_type = attacking_bodypart.attack_type

	if(atk_effect == ATTACK_EFFECT_KICK)//kicks deal 1.5x raw damage
		log_combat(user, target, "kicked")
		target.apply_damage(damage, attack_type, affecting, armor_block, attack_direction = attack_direction)
		target.stamina.adjust(-1 * (STAMINA_DAMAGE_UNARMED*3)) //Kicks do alot of stamina damage

	else//other attacks deal full raw damage + 1.5x in stamina damage

		target.apply_damage(damage, attack_type, affecting, armor_block, attack_direction = attack_direction)
		target.stamina.adjust(-STAMINA_DAMAGE_UNARMED)
		log_combat(user, target, "punched")
		. |= ATTACK_CONSUME_STAMINA

	return ATTACK_CONTINUE | .

/datum/species/proc/disarm(mob/living/carbon/human/user, mob/living/carbon/human/target, datum/martial_art/attacker_style)
	if(attacker_style?.disarm_act(user,target) == MARTIAL_ATTACK_SUCCESS)
		user.animate_interact(target, INTERACT_DISARM)
		return TRUE
	if(user.body_position != STANDING_UP)
		return FALSE
	if(user == target)
		return FALSE
	if(user.loc == target.loc)
		return FALSE

	user.disarm(target)
	return TRUE


/datum/species/proc/spec_hitby(atom/movable/AM, mob/living/carbon/human/H)
	return

/datum/species/proc/spec_attack_hand(mob/living/carbon/human/M, mob/living/carbon/human/H, datum/martial_art/attacker_style, modifiers)
	if(!istype(M))
		return
	CHECK_DNA_AND_SPECIES(M)
	CHECK_DNA_AND_SPECIES(H)

	if(!istype(M)) //sanity check for drones.
		return
	if(M.mind)
		attacker_style = M.mind.martial_art
	if((M != H) && M.combat_mode && H.check_block(M, 0, M.name, attack_type = UNARMED_ATTACK))
		log_combat(M, H, "attempted to touch")
		H.visible_message(span_warning("[M] attempts to touch [H]!"), \
						span_danger("[M] attempts to touch you!"), span_hear("You hear a swoosh!"), COMBAT_MESSAGE_RANGE, M)
		to_chat(M, span_warning("You attempt to touch [H]!"))
		return

	SEND_SIGNAL(M, COMSIG_MOB_ATTACK_HAND, M, H, attacker_style)

	if(LAZYACCESS(modifiers, RIGHT_CLICK))
		. = disarm(M, H, attacker_style)
		if(.)
			M.animate_interact(H, INTERACT_DISARM)
		return // dont attack after

	if(M.combat_mode)
		. = harm(M, H, attacker_style)
		if(. & ATTACK_CONTINUE)
			M.animate_interact(H, INTERACT_HARM)
		if(. & ATTACK_CONSUME_STAMINA)
			M.stamina_swing(STAMINA_SWING_COST_UNARMED)
	else
		. = help(M, H, attacker_style)
		if(.)
			M.animate_interact(H, INTERACT_HELP)

/datum/species/proc/on_hit(obj/projectile/P, mob/living/carbon/human/H)
	// called when hit by a projectile
	switch(P.type)
		if(/obj/projectile/energy/floramut) // overwritten by plants/pods
			H.show_message(span_notice("The radiation beam dissipates harmlessly through your body."))
		if(/obj/projectile/energy/florayield)
			H.show_message(span_notice("The radiation beam dissipates harmlessly through your body."))
		if(/obj/projectile/energy/florarevolution)
			H.show_message(span_notice("The radiation beam dissipates harmlessly through your body."))

/datum/species/proc/bullet_act(obj/projectile/P, mob/living/carbon/human/H)
	// called before a projectile hit
	return 0

//////////////////////////
// ENVIRONMENT HANDLERS //
//////////////////////////

/**
 * Environment handler for species
 *
 * vars:
 * * environment (required) The environment gas mix
 * * humi (required)(type: /mob/living/carbon/human) The mob we will target
 */
/datum/species/proc/handle_environment(mob/living/carbon/human/humi, datum/gas_mixture/environment, delta_time, times_fired)
	. = handle_environment_pressure(humi, environment, delta_time, times_fired)

/**
 * Body temperature handler for species
 *
 * These procs manage body temp, bamage, and alerts
 * Some of these will still fire when not alive to balance body temp to the room temp.
 * vars:
 * * humi (required)(type: /mob/living/carbon/human) The mob we will target
 */
/datum/species/proc/handle_body_temperature(mob/living/carbon/human/humi, delta_time, times_fired)
	//Only stabilise core temp when alive and not in statis
	if(humi.stat < DEAD && !IS_IN_STASIS(humi))
		body_temperature_core(humi, delta_time, times_fired)

	//These do run in statis
	body_temperature_skin(humi, delta_time, times_fired)
	body_temperature_alerts(humi, delta_time, times_fired)

	SET_STASIS_LEVEL(humi, STASIS_CRYOGENIC_FREEZING, get_cryogenic_factor(humi.coretemperature))

	//Do not cause more damage in statis
	if(!IS_IN_HARD_STASIS(humi))
		. = body_temperature_damage(humi, delta_time, times_fired)

/**
 * Used to stabilize the core temperature back to normal on living mobs
 *
 * The metabolisim heats up the core of the mob trying to keep it at the normal body temp
 * vars:
 * * humi (required) The mob we will stabilize
 */
/datum/species/proc/body_temperature_core(mob/living/carbon/human/humi, delta_time, times_fired)
	var/natural_change = get_temp_change_amount(humi.get_body_temp_normal() - humi.coretemperature, 0.06 * delta_time)
	humi.adjust_coretemperature(humi.metabolism_efficiency * natural_change)

/**
 * Used to normalize the skin temperature on living mobs
 *
 * The core temp effects the skin, then the enviroment effects the skin, then we refect that back to the core.
 * This happens even when dead so bodies revert to room temp over time.
 * vars:
 * * humi (required) The mob we will targeting
 * - delta_time: The amount of time that is considered as elapsing
 * - times_fired: The number of times SSmobs has fired
 */
/datum/species/proc/body_temperature_skin(mob/living/carbon/human/humi, delta_time, times_fired)

	// change the core based on the skin temp
	var/skin_core_diff = humi.bodytemperature - humi.coretemperature
	// change rate of 0.04 per second to be slightly below area to skin change rate and still have a solid curve
	var/skin_core_change = get_temp_change_amount(skin_core_diff, 0.04 * delta_time)

	humi.adjust_coretemperature(skin_core_change)

	// get the enviroment details of where the mob is standing
	var/datum/gas_mixture/environment = humi.loc?.unsafe_return_air()
	if(!environment) // if there is no environment (nullspace) drop out here.
		return

	// Get the temperature of the environment for area
	var/area_temp = humi.get_temperature(environment)

	// Get the insulation value based on the area's temp
	var/thermal_protection = humi.get_insulation_protection(area_temp)

	// Changes to the skin temperature based on the area
	var/area_skin_diff = area_temp - humi.bodytemperature
	if(!humi.on_fire || area_skin_diff > 0)
		// change rate of 0.05 as area temp has large impact on the surface
		var/area_skin_change = get_temp_change_amount(area_skin_diff, 0.05 * delta_time)

		// We need to apply the thermal protection of the clothing when applying area to surface change
		// If the core bodytemp goes over the normal body temp you are overheating and becom sweaty
		// This will cause the insulation value of any clothing to reduced in effect (70% normal rating)
		// we add 10 degree over normal body temp before triggering as thick insulation raises body temp
		if(humi.get_body_temp_normal(apply_change=FALSE) + 10 < humi.coretemperature)
			// we are overheating and sweaty insulation is not as good reducing thermal protection
			area_skin_change = (1 - (thermal_protection * 0.7)) * area_skin_change
		else
			area_skin_change = (1 - thermal_protection) * area_skin_change

		humi.adjust_bodytemperature(area_skin_change)

	// Core to skin temp transfer, when not on fire
	if(!humi.on_fire)
		// Get the changes to the skin from the core temp
		var/core_skin_diff = humi.coretemperature - humi.bodytemperature
		// change rate of 0.045 to reflect temp back to the skin at the slight higher rate then core to skin
		var/core_skin_change = (1 + thermal_protection) * get_temp_change_amount(core_skin_diff, 0.045 * delta_time)

		// We do not want to over shoot after using protection
		if(core_skin_diff > 0)
			core_skin_change = min(core_skin_change, core_skin_diff)
		else
			core_skin_change = max(core_skin_change, core_skin_diff)

		humi.adjust_bodytemperature(core_skin_change)


/**
 * Used to set alerts and debuffs based on body temperature
 * vars:
 * * humi (required) The mob we will targeting
 */
/datum/species/proc/body_temperature_alerts(mob/living/carbon/human/humi)
	var/old_bodytemp = humi.old_bodytemperature
	var/bodytemp = humi.bodytemperature
	// Body temperature is too hot, and we do not have resist traits
	if(bodytemp > heat_level_1 && !HAS_TRAIT(humi, TRAIT_RESISTHEAT))

		//Remove any slowdown from the cold.
		humi.remove_movespeed_modifier(/datum/movespeed_modifier/cold)
		// display alerts based on how hot it is
		// Can't be a switch due to http://www.byond.com/forum/post/2750423
		if(bodytemp in heat_level_1 to heat_level_2)
			humi.throw_alert(ALERT_TEMPERATURE, /atom/movable/screen/alert/hot, 1)
		else if(bodytemp in heat_level_2 to heat_level_3)
			humi.throw_alert(ALERT_TEMPERATURE, /atom/movable/screen/alert/hot, 2)
		else
			humi.throw_alert(ALERT_TEMPERATURE, /atom/movable/screen/alert/hot, 3)

	// Body temperature is too cold, and we do not have resist traits
	else if(bodytemp < cold_level_1 && !HAS_TRAIT(humi, TRAIT_RESISTCOLD))
		// clear any hot moods and apply cold mood
		// Apply cold slow down
		humi.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/cold, slowdown = ((cold_level_1 - humi.bodytemperature) / COLD_SLOWDOWN_FACTOR))
		// Display alerts based how cold it is
		// Can't be a switch due to http://www.byond.com/forum/post/2750423
		if(bodytemp in cold_level_1 to cold_level_2)
			humi.throw_alert(ALERT_TEMPERATURE, /atom/movable/screen/alert/cold, 1)
		else if(bodytemp in cold_level_2 to cold_level_3)
			humi.throw_alert(ALERT_TEMPERATURE, /atom/movable/screen/alert/cold, 2)
		else
			humi.throw_alert(ALERT_TEMPERATURE, /atom/movable/screen/alert/cold, 3)

	// We are not to hot or cold, remove status and moods
	// Optimization here, we check these things based off the old temperature to avoid unneeded work
	// We're not perfect about this, because it'd just add more work to the base case, and resistances are rare
	else if (old_bodytemp > heat_level_1 || old_bodytemp < cold_level_1)
		humi.clear_alert(ALERT_TEMPERATURE)
		humi.remove_movespeed_modifier(/datum/movespeed_modifier/cold)


	if((humi.stat == CONSCIOUS) && prob(5))
		if(bodytemp < cold_discomfort_level)
			to_chat(humi, span_warning(pick(cold_discomfort_strings)))
		else if(bodytemp > heat_discomfort_level)
			to_chat(humi, span_warning(pick(heat_discomfort_strings)))

	// Store the old bodytemp for future checking
	humi.old_bodytemperature = bodytemp

/**
 * Used to apply wounds and damage based on core/body temp
 * vars:
 * * humi (required) The mob we will targeting
 */
/datum/species/proc/body_temperature_damage(mob/living/carbon/human/humi, delta_time, times_fired)
	// Body temperature is too hot, and we do not have resist traits
	// Apply some burn damage to the body
	if(humi.coretemperature > heat_level_1 && !HAS_TRAIT(humi, TRAIT_RESISTHEAT))
		var/firemodifier = humi.fire_stacks / 50
		if (!humi.on_fire) // We are not on fire, reduce the modifier
			firemodifier = min(firemodifier, 0)

		// this can go below 5 at log 2.5
		var/burn_damage = max(log(2 - firemodifier, (humi.coretemperature - humi.get_body_temp_normal(apply_change=FALSE))) - 5, 0)

		// Apply species and physiology modifiers to heat damage
		burn_damage = burn_damage * heatmod * humi.physiology.heat_mod * 0.5 * delta_time

		// 40% for level 3 damage on humans to scream in pain
		if (humi.stat < UNCONSCIOUS && (prob(burn_damage) * 10) / 4)
			humi.pain_emote(1000, TRUE) //AGONY!!!!

		// Apply the damage to all body parts
		humi.adjustFireLoss(burn_damage, FALSE)
		. = TRUE

	if(humi.coretemperature < cold_level_1 && !HAS_TRAIT(humi, TRAIT_RESISTCOLD) && !CHEM_EFFECT_MAGNITUDE(humi, CE_CRYO))
		var/damage_mod = coldmod * humi.physiology.cold_mod
		// Can't be a switch due to http://www.byond.com/forum/post/2750423
		if(humi.coretemperature in cold_level_1 to cold_level_2)
			humi.adjustFireLoss(COLD_DAMAGE_LEVEL_1 * damage_mod * delta_time, FALSE)
		else if(humi.coretemperature in cold_level_2 to cold_level_3)
			humi.adjustFireLoss(COLD_DAMAGE_LEVEL_2 * damage_mod * delta_time, FALSE)
		else
			humi.adjustFireLoss(COLD_DAMAGE_LEVEL_3 * damage_mod * delta_time, FALSE)
		. = TRUE


/// Handle the air pressure of the environment
/datum/species/proc/handle_environment_pressure(mob/living/carbon/human/H, datum/gas_mixture/environment, delta_time, times_fired)
	var/pressure = environment.returnPressure()
	var/adjusted_pressure = H.calculate_affecting_pressure(pressure)

	// Set alerts and apply damage based on the amount of pressure
	switch(adjusted_pressure)
		// Very high pressure, show an alert and take damage
		if(HAZARD_HIGH_PRESSURE to INFINITY)
			if(!HAS_TRAIT(H, TRAIT_RESISTHIGHPRESSURE))
				var/pressure_damage = min(((adjusted_pressure / HAZARD_HIGH_PRESSURE) - 1) * PRESSURE_DAMAGE_COEFFICIENT, MAX_HIGH_PRESSURE_DAMAGE) * H.physiology.pressure_mod * H.physiology.brute_mod * delta_time
				H.adjustBruteLoss(pressure_damage, updating_health = FALSE, required_status = BODYTYPE_ORGANIC)
				H.adjustOrganLoss(ORGAN_SLOT_EARS, pressure_damage, updating_health = FALSE)
				H.adjustOrganLoss(ORGAN_SLOT_EYES, pressure_damage, updating_health = FALSE)
				. = TRUE
				H.throw_alert(ALERT_PRESSURE, /atom/movable/screen/alert/highpressure, 2)
			else
				H.clear_alert(ALERT_PRESSURE)

		// High pressure, show an alert
		if(WARNING_HIGH_PRESSURE to HAZARD_HIGH_PRESSURE)
			H.throw_alert(ALERT_PRESSURE, /atom/movable/screen/alert/highpressure, 1)

		// No pressure issues here clear pressure alerts
		if(WARNING_LOW_PRESSURE to WARNING_HIGH_PRESSURE)
			H.clear_alert(ALERT_PRESSURE)

		// Low pressure here, show an alert
		if(HAZARD_LOW_PRESSURE to WARNING_LOW_PRESSURE)
			// We have low pressure resit trait, clear alerts
			if(HAS_TRAIT(H, TRAIT_RESISTLOWPRESSURE))
				H.clear_alert(ALERT_PRESSURE)
			else
				H.throw_alert(ALERT_PRESSURE, /atom/movable/screen/alert/lowpressure, 1)

		// Very low pressure, show an alert and take damage
		else
			// We have low pressure resit trait, clear alerts
			if(HAS_TRAIT(H, TRAIT_RESISTLOWPRESSURE))
				H.clear_alert(ALERT_PRESSURE)
			else
				var/pressure_damage = LOW_PRESSURE_DAMAGE * H.physiology.pressure_mod * H.physiology.brute_mod * delta_time
				H.adjustBruteLoss(pressure_damage, required_status = BODYTYPE_ORGANIC)
				H.adjustOrganLoss(ORGAN_SLOT_EARS, (pressure_damage * 0.1))
				H.adjustOrganLoss(ORGAN_SLOT_EYES, (pressure_damage * 0.1))
				. = TRUE
				H.throw_alert(ALERT_PRESSURE, /atom/movable/screen/alert/lowpressure, 2)


//////////
// FIRE //
//////////

/datum/species/proc/handle_fire(mob/living/carbon/human/H, delta_time, times_fired, no_protection = FALSE)
	return no_protection

////////////
//  Stun  //
////////////

/datum/species/proc/spec_stun(mob/living/carbon/human/H,amount)
	if(H.movement_type & FLYING)
		var/obj/item/organ/wings/functional/wings = H.getorganslot(ORGAN_SLOT_EXTERNAL_WINGS)
		if(wings)
			wings.toggle_flight(H)
			wings.fly_slip(H)
	. = stunmod * H.physiology.stun_mod * amount

/datum/species/proc/negates_gravity(mob/living/carbon/human/H)
	if(H.movement_type & FLYING)
		return TRUE
	return FALSE

///////////////
//FLIGHT SHIT//
///////////////

/datum/species/proc/GiveSpeciesFlight(mob/living/carbon/human/H)
	if(flying_species) //species that already have flying traits should not work with this proc
		return
	flying_species = TRUE
	var/wings_icon
	if(wings_icons.len > 1)
		if(!H.client)
			wings_icon = pick(wings_icons)
		else
			var/list/wings = list()
			for(var/W in wings_icons)
				var/datum/sprite_accessory/S = GLOB.wings_list[W] //Gets the datum for every wing this species has, then prompts user with a radial menu
				var/image/img = image(icon = 'icons/mob/clothing/wings.dmi', icon_state = "m_wingsopen_[S.icon_state]_BEHIND") //Process the HUD elements
				img.transform *= 0.5
				img.pixel_x = -32
				if(wings[S.name])
					stack_trace("Different wing types with repeated names. Please fix as this may cause issues.")
				else
					wings[S.name] = img
			wings_icon = show_radial_menu(H, H, wings, tooltips = TRUE)
			if(!wings_icon)
				wings_icon = pick(wings_icons)
	else
		wings_icon = wings_icons[1]

	var/obj/item/organ/wings/functional/wings = new(null, wings_icon, H.physique)
	wings.Insert(H)

/// Returns a list of strings representing features this species has.
/// Used by the preferences UI to know what buttons to show.
/datum/species/proc/get_features()
	SHOULD_NOT_OVERRIDE(TRUE)
	var/cached_features = GLOB.features_by_species[type]
	if (!isnull(cached_features))
		return cached_features

	var/list/features = list()

	for (var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]

		if(length(preference.exclude_species_traits & species_traits))
			continue

		if ( \
			(preference.relevant_mutant_bodypart in mutant_bodyparts) \
			|| (preference.relevant_species_trait in species_traits) \
			|| (preference.relevant_external_organ in cosmetic_organs)
		)
			features[preference.savefile_key] = preference

	for (var/obj/item/organ/organ_type as anything in cosmetic_organs)
		var/preference = initial(organ_type.preference)
		if (!isnull(preference))
			features[preference] = GLOB.preference_entries_by_key[preference]

	if(use_skintones)
		features["skin_tone"] = GLOB.preference_entries[/datum/preference/choiced/skin_tone]

	features += populate_features()
	#ifdef TESTING
	for(var/feat in features)
		if(!features[feat])
			stack_trace("Feature key [feat] has no associated preference.")
	#endif
	sortTim(features, GLOBAL_PROC_REF(cmp_pref_name), associative = TRUE)

	GLOB.features_by_species[type] = features

	return features

/datum/species/proc/populate_features()
	SHOULD_CALL_PARENT(TRUE)
	. = list()
	return

/// Given a human, will adjust it before taking a picture for the preferences UI.
/// This should create a CONSISTENT result, so the icons don't randomly change.
/datum/species/proc/prepare_human_for_preview(mob/living/carbon/human/human)
	return

/// Returns the species's scream sound.
/datum/species/proc/get_scream_sound(mob/living/carbon/human/human)
	if(human.gender == MALE)
		return pick(
			'goon/sounds/voice/mascream4.ogg',
			'sound/voice/human/malescream_2.ogg',
			'sound/voice/human/malescream_2.ogg', //He gets two chances to roll because he's special and we love him
			'goon/sounds/voice/mascream5.ogg',
			'goon/sounds/voice/mascream7.ogg',
			'sound/voice/human/malescream_5.ogg',
			'sound/voice/human/malescream_6.ogg',
			'sound/voice/human/malescream_7.ogg',
			'sound/voice/human/malescream_4.ogg',
		)

	return pick(
		'sound/voice/human/femalescream_1.ogg',
		'sound/voice/human/femalescream_2.ogg',
		'sound/voice/human/femalescream_3.ogg',
		'sound/voice/human/femalescream_6.ogg',
		'sound/voice/human/femalescream_7.ogg',
		'goon/sounds/voice/fescream1.ogg',
		'goon/sounds/voice/fescream5.ogg',
	)

/datum/species/proc/get_agony_sound(mob/living/carbon/human/human)
	return get_scream_sound(human)

/datum/species/proc/get_pain_sound(mob/living/carbon/human/human)
	return get_scream_sound(human)

/datum/species/proc/get_types_to_preload()
	var/list/to_store = list()
	to_store += mutant_organs
	for(var/obj/item/organ/horny as anything in cosmetic_organs)
		to_store += horny //Haha get it?

	//Don't preload brains, cause reuse becomes a horrible headache
	to_store += organs[ORGAN_SLOT_HEART]
	to_store += organs[ORGAN_SLOT_LUNGS]
	to_store += organs[ORGAN_SLOT_EYES]
	to_store += organs[ORGAN_SLOT_EARS]
	to_store += organs[ORGAN_SLOT_TONGUE]
	to_store += organs[ORGAN_SLOT_LIVER]
	to_store += organs[ORGAN_SLOT_STOMACH]
	to_store += organs[ORGAN_SLOT_APPENDIX]

	list_clear_nulls(to_store)
	//We don't cache mutant hands because it's not constrained enough, too high a potential for failure
	return to_store


/**
 * Owner login
 */

/**
 * A simple proc to be overwritten if something needs to be done when a mob logs in. Does nothing by default.
 *
 * Arguments:
 * * owner - The owner of our species.
 */
/datum/species/proc/on_owner_login(mob/living/carbon/human/owner)
	return

/**
 * Gets a short description for the specices. Should be relatively succinct.
 * Used in the preference menu.
 *
 * Returns a string.
 */
/datum/species/proc/get_species_mechanics()
	SHOULD_CALL_PARENT(FALSE)
	return "WIP"

/**
 * Gets the lore behind the type of species. Can be long.
 * Used in the preference menu.
 *
 * Returns a list of strings.
 * Between each entry in the list, a newline will be inserted, for formatting.
 */
/datum/species/proc/get_species_lore()
	SHOULD_CALL_PARENT(FALSE)
	RETURN_TYPE(/list)

	return list("WIP")

/**
 * Translate the species liked foods from bitfields into strings
 * and returns it in the form of an associated list.
 *
 * Returns a list, or null if they have no diet.
 */
/datum/species/proc/get_species_diet()
	if(TRAIT_NOHUNGER in inherent_traits)
		return null

	var/list/food_flags = FOOD_FLAGS

	return list(
		"liked_food" = bitfield_to_list(liked_food, food_flags),
		"disliked_food" = bitfield_to_list(disliked_food, food_flags),
		"toxic_food" = bitfield_to_list(toxic_food, food_flags),
	)

GLOBAL_LIST_EMPTY(species_perks)
/proc/get_species_constant_data(datum/species/path)
	RETURN_TYPE(/list)
	. = GLOB.species_perks[path]
	if(.)
		return

	path = new path
	GLOB.species_perks[path.type] = path.get_constant_data()
	return GLOB.species_perks[path.type]

/// Generates nested lists of constant data for UIs.
/datum/species/proc/get_constant_data()
	. = new /list(2)

	.[SPECIES_DATA_PERKS] = get_perk_data()
	.[SPECIES_DATA_LANGUAGES] = get_innate_languages()

	return .

/// Returns a list of each language we know innately.
/datum/species/proc/get_innate_languages()
	. = list()

	var/datum/language_holder/temp_holder = new species_language_holder()
	for(var/datum/language/path as anything in temp_holder.understood_languages | temp_holder.spoken_languages)
		. += path

/**
 * Perks of varying types.
 * (Postives, neutrals, and negatives)
 * in the format of a list of lists.
 * Used in the preference menu.
 *
 * "Perk" format is as followed:
 * list(
 *   SPECIES_PERK_TYPE = type of perk (postiive, negative, neutral - use the defines)
 *   SPECIES_PERK_ICON = icon used, unused due to no longer being on tgui prefs
 *   SPECIES_PERK_NAME = name of the perk on hover
 *   SPECIES_PERK_DESC = description of the perk on hover
 * )
 *
 * Returns a list of lists.
 * The outer list is an assoc list of [perk type]s to a list of perks.
 * The innter list is a list of perks. Can be empty, but won't be null.
 */
/datum/species/proc/get_perk_data()
	var/list/species_perks = list()
	// Let us get every perk we can concieve of in one big list.
	// The order these are called (kind of) matters.
	// Species unique perks first, as they're more important than genetic perks,
	// and language perk last, as it comes at the end of the perks list
	species_perks += create_pref_unique_perks()
	species_perks += create_pref_blood_perks()
	species_perks += create_pref_damage_perks()
	species_perks += create_pref_temperature_perks()
	species_perks += create_pref_traits_perks()
	species_perks += create_pref_biotypes_perks()
	species_perks += create_pref_language_perk()

	// Some overrides may return `null`, prevent those from jamming up the list.
	list_clear_nulls(species_perks)

	// Now let's sort them out for cleanliness and sanity
	var/list/perks_to_return = list(
		SPECIES_POSITIVE_PERK = list(),
		SPECIES_NEUTRAL_PERK = list(),
		SPECIES_NEGATIVE_PERK =  list(),
	)

	// Filter invalid perks
	for(var/list/perk as anything in species_perks)
		var/perk_type = perk[SPECIES_PERK_TYPE]
		// If we find a perk that isn't postiive, negative, or neutral,
		// it's a bad entry - don't add it to our list. Throw a stack trace and skip it instead.
		if(isnull(perks_to_return[perk_type]))
			stack_trace("Invalid species perk ([perk[SPECIES_PERK_NAME]]) found for species [name]. \
				The type should be positive, negative, or neutral. (Got: [perk_type])")
			continue

		perks_to_return[perk_type] += list(perk)

	return perks_to_return

/**
 * Used to add any species specific perks to the perk list.
 *
 * Returns null by default. When overriding, return a list of perks.
 */
/datum/species/proc/create_pref_unique_perks()
	return null

/**
 * Adds adds any perks related to sustaining damage.
 * For example, brute damage vulnerability, or fire damage resistance.
 *
 * Returns a list containing perks, or an empty list.
 */
/datum/species/proc/create_pref_damage_perks()
	var/list/to_add = list()

	// Brute related
	if(brutemod > 1)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "band-aid",
			SPECIES_PERK_NAME = "Brutal Weakness",
			SPECIES_PERK_DESC = "[plural_form] are weak to brute damage.",
		))

	if(brutemod < 1)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "shield-alt",
			SPECIES_PERK_NAME = "Brutal Resilience",
			SPECIES_PERK_DESC = "[plural_form] are resilient to bruising and brute damage.",
		))

	// Burn related
	if(burnmod > 1)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "burn",
			SPECIES_PERK_NAME = "Fire Weakness",
			SPECIES_PERK_DESC = "[plural_form] are weak to fire and burn damage.",
		))

	if(burnmod < 1)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "shield-alt",
			SPECIES_PERK_NAME = "Fire Resilience",
			SPECIES_PERK_DESC = "[plural_form] are resilient to flames, and burn damage.",
		))

	// Shock damage
	if(siemens_coeff > 1)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "bolt",
			SPECIES_PERK_NAME = "Shock Vulnerability",
			SPECIES_PERK_DESC = "[plural_form] are vulnerable to being shocked.",
		))

	if(siemens_coeff < 1)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "shield-alt",
			SPECIES_PERK_NAME = "Shock Resilience",
			SPECIES_PERK_DESC = "[plural_form] are resilient to being shocked.",
		))

	return to_add

/**
 * Adds adds any perks related to how the species deals with temperature.
 *
 * Returns a list containing perks, or an empty list.
 */
/datum/species/proc/create_pref_temperature_perks()
	var/list/to_add = list()

	// Hot temperature tolerance
	if(heatmod > 1 || heat_level_1 < BODYTEMP_HEAT_DAMAGE_LIMIT)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "temperature-high",
			SPECIES_PERK_NAME = "Heat Vulnerability",
			SPECIES_PERK_DESC = "[plural_form] are vulnerable to high temperatures.",
		))

	if(heatmod < 1 || heat_level_1 > BODYTEMP_HEAT_DAMAGE_LIMIT)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "thermometer-empty",
			SPECIES_PERK_NAME = "Heat Resilience",
			SPECIES_PERK_DESC = "[plural_form] are resilient to hotter environments.",
		))

	// Cold temperature tolerance
	if(coldmod > 1 || cold_level_1 > BODYTEMP_COLD_DAMAGE_LIMIT)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "temperature-low",
			SPECIES_PERK_NAME = "Cold Vulnerability",
			SPECIES_PERK_DESC = "[plural_form] are vulnerable to cold temperatures.",
		))

	if(coldmod < 1 || cold_level_1 < BODYTEMP_COLD_DAMAGE_LIMIT)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "thermometer-empty",
			SPECIES_PERK_NAME = "Cold Resilience",
			SPECIES_PERK_DESC = "[plural_form] are resilient to colder environments.",
		))

	return to_add

/**
 * Adds adds any perks related to the species' blood (or lack thereof).
 *
 * Returns a list containing perks, or an empty list.
 */
/datum/species/proc/create_pref_blood_perks()
	var/list/to_add = list()

	// NOBLOOD takes priority by default
	if(NOBLOOD in species_traits)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "tint-slash",
			SPECIES_PERK_NAME = "Bloodletted",
			SPECIES_PERK_DESC = "[plural_form] do not have blood.",
		))

	// Otherwise, check if their exotic blood is a valid typepath
	else if(ispath(exotic_blood))
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
			SPECIES_PERK_ICON = "tint",
			SPECIES_PERK_NAME = initial(exotic_blood.name),
			SPECIES_PERK_DESC = "[name] blood is [initial(exotic_blood.name)], which can make recieving medical treatment harder.",
		))

	return to_add

/**
 * Adds adds any perks related to the species' inherent_traits list.
 *
 * Returns a list containing perks, or an empty list.
 */
/datum/species/proc/create_pref_traits_perks()
	var/list/to_add = list()

	if(TRAIT_LIMBATTACHMENT in inherent_traits)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "user-plus",
			SPECIES_PERK_NAME = "Limbs Easily Reattached",
			SPECIES_PERK_DESC = "[plural_form] limbs are easily readded, and as such do not \
				require surgery to restore. Simply pick it up and pop it back in, champ!",
		))

	if(TRAIT_EASYDISMEMBER in inherent_traits)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEGATIVE_PERK,
			SPECIES_PERK_ICON = "user-times",
			SPECIES_PERK_NAME = "Limbs Easily Dismembered",
			SPECIES_PERK_DESC = "[plural_form] limbs are not secured well, and as such they are easily dismembered.",
		))

	if(TRAIT_TOXINLOVER in inherent_traits)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_NEUTRAL_PERK,
			SPECIES_PERK_ICON = "syringe",
			SPECIES_PERK_NAME = "Toxins Lover",
			SPECIES_PERK_DESC = "Toxins damage dealt to [plural_form] are reversed - healing toxins will instead cause harm, and \
				causing toxins will instead cause healing. Be careful around purging chemicals!",
		))

	return to_add

/**
 * Adds adds any perks related to the species' inherent_biotypes flags.
 *
 * Returns a list containing perks, or an empty list.
 */
/datum/species/proc/create_pref_biotypes_perks()
	var/list/to_add = list()

	if(inherent_biotypes & MOB_UNDEAD)
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "skull",
			SPECIES_PERK_NAME = "Undead",
			SPECIES_PERK_DESC = "[plural_form] are of the undead! The undead do not have the need to eat or breathe, and \
				most viruses will not be able to infect a walking corpse. Their worries mostly stop at remaining in one piece, really.",
		))

	return to_add

/**
 * Adds in a language perk based on all the languages the species
 * can speak by default (according to their language holder).
 *
 * Returns a list containing perks, or an empty list.
 */
/datum/species/proc/create_pref_language_perk()
	var/list/to_add = list()

	// Grab galactic common as a path, for comparisons
	var/datum/language/common_language = /datum/language/common

	// Now let's find all the languages they can speak that aren't common
	var/list/bonus_languages = list()
	var/datum/language_holder/temp_holder = new species_language_holder()
	for(var/datum/language/language_type as anything in temp_holder.spoken_languages)
		if(ispath(language_type, common_language))
			continue
		bonus_languages += initial(language_type.name)

	// If we have any languages we can speak: create a perk for them all
	if(length(bonus_languages))
		to_add += list(list(
			SPECIES_PERK_TYPE = SPECIES_POSITIVE_PERK,
			SPECIES_PERK_ICON = "comment",
			SPECIES_PERK_NAME = "Native Speaker",
			SPECIES_PERK_DESC = "Alongside [initial(common_language.name)], [plural_form] gain the ability to speak [english_list(bonus_languages)].",
		))

	qdel(temp_holder)

	return to_add

///Handles replacing all of the bodyparts with their species version during set_species()
/datum/species/proc/replace_body(mob/living/carbon/target, datum/species/new_species)
	new_species ||= target.dna.species //If no new species is provided, assume its src.
	//Note for future: Potentionally add a new C.dna.species() to build a template species for more accurate limb replacement

	var/is_digitigrade = FALSE
	if((new_species.digitigrade_customization == DIGITIGRADE_OPTIONAL && target.dna.features["legs"] == "Digitigrade Legs") || new_species.digitigrade_customization == DIGITIGRADE_FORCED)
		is_digitigrade = TRUE

	for(var/obj/item/bodypart/old_part as anything in target.bodyparts)
		if(old_part.change_exempt_flags & BP_BLOCK_CHANGE_SPECIES)
			continue

		var/path = new_species.bodypart_overrides?[old_part.body_zone]
		var/obj/item/bodypart/new_part
		if(path)
			new_part = new path()
			if(istype(new_part, /obj/item/bodypart/leg) && is_digitigrade)
				new_part:set_digitigrade(TRUE)
			new_part.replace_limb(target, TRUE)
			new_part.update_limb(is_creating = TRUE)
			qdel(old_part)

/// Creates body parts for the target completely from scratch based on the species
/datum/species/proc/create_fresh_body(mob/living/carbon/target)
	target.create_bodyparts(bodypart_overrides)

/datum/species/proc/replace_missing_bodyparts(mob/living/carbon/target)
	var/is_digitigrade = FALSE
	if((digitigrade_customization == DIGITIGRADE_OPTIONAL && target.dna.features["legs"] == "Digitigrade Legs") || digitigrade_customization == DIGITIGRADE_FORCED)
		is_digitigrade = TRUE

	for(var/slot in target.get_missing_limbs())
		var/obj/item/bodypart/path = bodypart_overrides[slot]
		if(path)
			path = new path()
			if(istype(path, /obj/item/bodypart/leg) && is_digitigrade)
				path:set_digitigrade(TRUE)
			path.attach_limb(target, TRUE)
			path.update_limb(is_creating = TRUE)

	for(var/obj/item/bodypart/BP as anything in target.bodyparts)
		if(BP.type == bodypart_overrides[BP.body_zone])
			continue

		var/obj/item/bodypart/new_part = bodypart_overrides[BP.body_zone]
		if(new_part)
			new_part = new new_part()
			if(istype(new_part, /obj/item/bodypart/leg) && is_digitigrade)
				new_part:set_digitigrade(TRUE)
			new_part.replace_limb(target, TRUE)
			new_part.update_limb(is_creating = TRUE)
			qdel(BP)

/datum/species/proc/get_cryogenic_factor(bodytemperature)
	if(bodytemperature >= bodytemp_normal)
		return 0

	if(bodytemperature > 243)
		return 0

	else if(bodytemperature > 200)
		. = 5 * (1 - (bodytemperature - 200) / (243 - 200))
		. = min(2, .)
	else if(bodytemperature > 120)
		. = 20 * (1 - (bodytemperature - 120) / (200 - 120))
		. = min(5, .)
	else
		. = 80 * (1 - bodytemperature / 120)
		. = min(., 20)

	return (round(.))


/datum/species/proc/get_pain_emote(amount)
	var/chosen

	for(var/list/L as anything in pain_emotes)
		if(amount >= pain_emotes[L])
			chosen = L
		else
			break

	return pick_weight(chosen)

/datum/species/proc/get_deathgasp_sound(mob/living/carbon/human/H)
	return pick('goon/sounds/voice/death_1.ogg', 'goon/sounds/voice/death_2.ogg')

/// Returns a random blood type for this species
/datum/species/proc/get_random_blood_type()
	return random_blood_type()
