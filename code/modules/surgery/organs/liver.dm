#define LIVER_DEFAULT_TOX_TOLERANCE 3 //amount of toxins the liver can filter out
#define LIVER_DEFAULT_TOX_LETHALITY 0.005 //lower values lower how harmful toxins are to the liver
#define LIVER_FAILURE_STAGE_SECONDS 60 //amount of seconds before liver failure reaches a new stage
/obj/item/organ/liver
	name = "liver"
	icon_state = "liver"
	visual = FALSE
	w_class = WEIGHT_CLASS_SMALL
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_LIVER
	desc = "Pairing suggestion: chianti and fava beans."

	maxHealth = 70
	low_threshold = 0.22
	high_threshold = 0.5
	relative_size = 60

	decay_factor = STANDARD_ORGAN_DECAY // smack in the middle of decay times

	food_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/iron = 5)
	grind_results = list(/datum/reagent/consumable/nutriment/peptides = 5)

/obj/item/organ/liver/Initialize(mapload)
	. = ..()
	// If the liver handles foods like a clown, it honks like a bike horn
	// Don't think about it too much.
	RegisterSignal(src, SIGNAL_ADDTRAIT(TRAIT_COMEDY_METABOLISM), PROC_REF(on_add_comedy_metabolism))

/* Signal handler for the liver gaining the TRAIT_COMEDY_METABOLISM trait
 *
 * Adds the "squeak" component, so clown livers will act just like their
 * bike horns, and honk when you hit them with things, or throw them
 * against things, or step on them.
 *
 * The removal of the component, if this liver loses that trait, is handled
 * by the component itself.
 */
/obj/item/organ/liver/proc/on_add_comedy_metabolism()
	SIGNAL_HANDLER

	// Are clown "bike" horns made from the livers of ex-clowns?
	// Would that make the clown more or less likely to honk it
	AddComponent(/datum/component/squeak, list('sound/items/bikehorn.ogg'=1), 50, falloff_exponent = 20)

#define HAS_SILENT_TOXIN 0 //don't provide a feedback message if this is the only toxin present
#define HAS_NO_TOXIN 1
#define HAS_PAINFUL_TOXIN 2

/obj/item/organ/liver/on_life(delta_time, times_fired)
	var/mob/living/carbon/liver_owner = owner
	. = ..() //perform general on_life()

	if(!istype(liver_owner))
		return
	if(organ_flags & ORGAN_DEAD)
		return

	if (germ_level > INFECTION_LEVEL_ONE)
		if(prob(1))
			to_chat(owner, span_danger("Your skin itches."))
	if (germ_level > INFECTION_LEVEL_TWO)
		if(prob(1))
			owner.vomit(50, TRUE)

	//Detox can heal small amounts of damage
	if (damage < maxHealth && !owner.chem_effects[CE_TOXIN])
		applyOrganDamage(-0.2 * owner.chem_effects[CE_ANTITOX], updating_health = FALSE)

	// Get the effectiveness of the liver.
	var/filter_effect = 3
	if(damage > (low_threshold * maxHealth))
		filter_effect -= 1
	if(damage > (high_threshold * maxHealth))
		filter_effect -= 2
	// Robotic organs filter better but don't get benefits from dylovene for filtering.
	if(organ_flags & ORGAN_SYNTHETIC)
		filter_effect += 1
	else if(owner.chem_effects[CE_ANTITOX])
		filter_effect += 1

	// If you're not filtering well, you're in trouble. Ammonia buildup to toxic levels and damage from alcohol
	if(filter_effect < 2)
		if(owner.chem_effects[CE_ALCOHOL])
			owner.adjustToxLoss(0.5 * max(2 - filter_effect, 0) * (owner.chem_effects[CE_ALCOHOL_TOXIC] + 0.5 * owner.chem_effects[CE_ALCOHOL]), cause_of_death = "Alcohol poisoning")

	if(owner.chem_effects[CE_ALCOHOL_TOXIC])
		applyOrganDamage(owner.chem_effects[CE_ALCOHOL_TOXIC], updating_health = FALSE)
	// Heal a bit if needed and we're not busy. This allows recovery from low amounts of toxloss.
	if(!owner.chem_effects[CE_ALCOHOL] && !owner.chem_effects[CE_TOXIN] && !HAS_TRAIT(owner, TRAIT_IRRADIATED) && damage > 0)
		if(damage < low_threshold * maxHealth)
			applyOrganDamage(-0.3, updating_health = FALSE)
		else if(damage < high_threshold * maxHealth)
			applyOrganDamage(-0.2, updating_health = FALSE)

	if(damage > 10 && DT_PROB(damage/4, delta_time)) //the higher the damage the higher the probability
		to_chat(liver_owner, span_warning("You feel a dull pain in your abdomen."))

	if(owner.blood_volume < BLOOD_VOLUME_NORMAL)
		if(!HAS_TRAIT(owner, TRAIT_NOHUNGER))
			owner.adjust_nutrition(-0.1 * HUNGER_DECAY)
		owner.adjustBloodVolumeUpTo(0.1, BLOOD_VOLUME_NORMAL)

//We got it covered in on_life() with more detailed thing
/obj/item/organ/liver/handle_regeneration()
	return

/obj/item/organ/liver/on_owner_examine(datum/source, mob/user, list/examine_list)
	if(!ishuman(owner) || !(organ_flags & ORGAN_DEAD))
		return

	var/mob/living/carbon/human/humie_owner = owner
	if(!humie_owner.getorganslot(ORGAN_SLOT_EYES) || humie_owner.is_eyes_covered())
		return

	if(damage > maxHealth * low_threshold)
		examine_list += span_notice("[owner]'s eyes are slightly yellow.")
	else if(damage > maxHealth * high_threshold)
		examine_list += span_notice("[owner]'s eyes are completely yellow, and he is visibly suffering.")

#undef HAS_SILENT_TOXIN
#undef HAS_NO_TOXIN
#undef HAS_PAINFUL_TOXIN
#undef LIVER_FAILURE_STAGE_SECONDS

/obj/item/organ/liver/plasmaman
	name = "reagent processing crystal"
	icon_state = "liver-p"
	desc = "A large crystal that is somehow capable of metabolizing chemicals, these are found in plasmamen."

/obj/item/organ/liver/alien
	name = "alien liver" // doesnt matter for actual aliens because they dont take toxin damage
	icon_state = "liver-x" // Same sprite as fly-person liver.
	desc = "A liver that used to belong to a killer alien, who knows what it used to eat."

/obj/item/organ/liver/vox
	name = "vox liver"
	icon_state = "vox-liver"

/obj/item/organ/liver/cybernetic
	name = "basic cybernetic liver"
	icon_state = "liver-c"
	desc = "A very basic device designed to mimic the functions of a human liver. Handles toxins slightly worse than an organic liver."
	organ_flags = ORGAN_SYNTHETIC
	var/emp_vulnerability = 80 //Chance of permanent effects if emp-ed.

/obj/item/organ/liver/cybernetic/tier2
	name = "cybernetic liver"
	icon_state = "liver-c-u"
	desc = "An electronic device designed to mimic the functions of a human liver. Handles toxins slightly better than an organic liver."
	maxHealth = 100
	emp_vulnerability = 40

/obj/item/organ/liver/cybernetic/tier3
	name = "upgraded cybernetic liver"
	icon_state = "liver-c-u2"
	desc = "An upgraded version of the cybernetic liver, designed to improve further upon organic livers. It is resistant to alcohol poisoning and is very robust at filtering toxins."
	maxHealth = 140
	emp_vulnerability = 20

/obj/item/organ/liver/cybernetic/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	if(!COOLDOWN_FINISHED(src, severe_cooldown)) //So we cant just spam emp to kill people.
		owner.adjustToxLoss(10, cause_of_death = "Faulty prosthetic liver")
		COOLDOWN_START(src, severe_cooldown, 10 SECONDS)

	if(prob(emp_vulnerability/severity)) //Chance of permanent effects
		organ_flags |= ORGAN_SYNTHETIC_EMP //Starts organ faliure - gonna need replacing soon.


