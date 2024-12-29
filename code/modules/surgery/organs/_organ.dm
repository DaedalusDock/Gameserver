
/obj/item/organ
	name = "organ"
	icon = 'icons/obj/surgery.dmi'
	w_class = WEIGHT_CLASS_SMALL
	throwforce = 0

	//Germ level starts at 0
	germ_level = 0

	///The mob that owns this organ.
	var/mob/living/carbon/owner = null
	///The body zone this organ is supposed to inhabit.
	var/zone = BODY_ZONE_CHEST
	///The organ slot this organ is supposed to inhabit. This should be unique by type. (Lungs, Appendix, Stomach, etc)
	var/slot
	// DO NOT add slots with matching names to different zones - it will break organs_by_slot list!
	var/organ_flags = ORGAN_EDIBLE
	var/maxHealth = 30
	/// Total damage this organ has sustained
	/// Should only ever be modified by applyOrganDamage
	var/damage = 0
	var/decay_factor = 0 //same as above but when without a living owner, set to 0 for generic organs
	var/high_threshold = 0.66
	var/low_threshold = 0.33 //when minor organ damage occurs

	/// The world.time of this organ's death
	var/time_of_death = 0

	/// The relative size of this organ, used for probability to hit.
	var/relative_size = 25
	/// Amount of damage to take when taking damage from an external source
	var/external_damage_modifier = 0.5

	///cooldown for severe effects, used for synthetic organ emp effects.
	var/severe_cooldown

	///Organ variables for determining what we alert the owner with when they pass/clear the damage thresholds
	var/prev_damage = 0
	var/low_threshold_passed
	var/high_threshold_passed
	var/now_failing
	var/now_fixed
	var/high_threshold_cleared
	var/low_threshold_cleared

	///When you take a bite you cant jam it in for surgery anymore.
	var/useable = TRUE
	var/list/food_reagents = list(/datum/reagent/consumable/nutriment = 5)
	///The size of the reagent container
	var/reagent_vol = 10

	///Do we effect the appearance of our mob. Used to save time in preference code
	var/visual = FALSE
	///If the organ is cosmetic only, it loses all organ functionality.
	var/cosmetic_only = FALSE
	/// Traits that are given to the holder of the organ. If you want an effect that changes this, don't add directly to this. Use the add_organ_trait() proc
	var/list/organ_traits = list()

// Players can look at prefs before atoms SS init, and without this
// they would not be able to see external organs, such as moth wings.
// This is also necessary because assets SS is before atoms, and so
// any nonhumans created in that time would experience the same effect.
INITIALIZE_IMMEDIATE(/obj/item/organ)

/obj/item/organ/Initialize(mapload, mob_sprite)
	. = ..()
	if(organ_flags & ORGAN_EDIBLE)
		AddComponent(/datum/component/edible,\
			initial_reagents = food_reagents,\
			foodtypes = RAW | MEAT | GROSS,\
			volume = reagent_vol,\
			after_eat = CALLBACK(src, PROC_REF(OnEatFrom)))

	if(cosmetic_only) //Cosmetic organs don't process.
		if(mob_sprite)
			set_sprite(mob_sprite)

		if(!(organ_flags & ORGAN_UNREMOVABLE))
			color = "#[random_color()]" //A temporary random color that gets overwritten on insertion.
	else
		START_PROCESSING(SSobj, src)
		organ_flags |= ORGAN_CUT_AWAY

/obj/item/organ/Destroy(force)
	if(owner)
		// The special flag is important, because otherwise mobs can die
		// while undergoing transformation into different mobs.
		Remove(owner, special=TRUE)

	if(ownerlimb)
		ownerlimb.remove_organ(src)

	if(!cosmetic_only)
		STOP_PROCESSING(SSobj, src)

	return ..()

/// A little hack to ensure old behavior.
/obj/item/organ/ex_act(severity, target)
	if(ownerlimb)
		return
	return ..()

/obj/item/organ/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(owner)
		Remove(owner)
		stack_trace("Organ removed while it still had an owner.")

	if(ownerlimb)
		ownerlimb.remove_organ(src)
		stack_trace("Organ removed while it still had an ownerlimb.")


/*
 * Insert the organ into the select mob.
 *
 * reciever - the mob who will get our organ
 * special - "quick swapping" an organ out - when TRUE, the mob will be unaffected by not having that organ for the moment
 * drop_if_replaced - if there's an organ in the slot already, whether we drop it afterwards
 */
/obj/item/organ/proc/Insert(mob/living/carbon/reciever, special = FALSE, drop_if_replaced = TRUE)
	if(!iscarbon(reciever) || owner == reciever)
		return FALSE

	var/obj/item/bodypart/limb
	limb = reciever.get_bodypart(deprecise_zone(zone))
	if(!limb)
		return FALSE

	var/obj/item/organ/replaced = reciever.getorganslot(slot)
	if(replaced)
		replaced.Remove(reciever, special = TRUE)
		if(drop_if_replaced)
			replaced.forceMove(get_turf(reciever))
		else
			qdel(replaced)

	organ_flags &= ~ORGAN_CUT_AWAY

	SEND_SIGNAL(src, COMSIG_ORGAN_IMPLANTED, reciever)
	SEND_SIGNAL(reciever, COMSIG_CARBON_GAIN_ORGAN, src, special)

	if(ownerlimb)
		ownerlimb.remove_organ(src)

	forceMove(limb)
	limb.add_organ(src)
	item_flags |= ABSTRACT

	owner = reciever
	RegisterSignal(owner, COMSIG_PARENT_EXAMINE, PROC_REF(on_owner_examine))
	update_organ_traits(reciever)
	for(var/datum/action/action as anything in actions)
		action.Grant(reciever)

	//Add to internal organs
	owner.organs |= src
	owner.organs_by_slot[slot] = src
	ADD_TRAIT(src, TRAIT_INSIDE_BODY, REF(owner))

	if(!cosmetic_only)
		STOP_PROCESSING(SSobj, src)
		owner.processing_organs |= src
		/// processing_organs must ALWAYS be ordered in the same way as organ_process_order
		/// Otherwise life processing breaks down
		sortTim(owner.processing_organs, GLOBAL_PROC_REF(cmp_organ_slot_asc))

	if(visual)
		if(!stored_feature_id && reciever.dna?.features) //We only want this set *once*
			stored_feature_id = reciever.dna.features[feature_key]

		reciever.cosmetic_organs.Add(src)
		reciever.update_body_parts()

	PreRevivalInsertion(special)
	if(!special && !cosmetic_only && owner.stat == DEAD && (organ_flags & ORGAN_VITAL) && !(organ_flags & ORGAN_DEAD) && owner.needs_organ(slot))
		attempt_vital_organ_revival(owner)

	return TRUE

/*
 * Called before attempt_vital_organ_revival during a successful Insert()
 *
 * special - "quick swapping" an organ out - when TRUE, the mob will be unaffected by not having that organ for the moment
 */
/obj/item/organ/proc/PreRevivalInsertion(special)
	return

/*
 * Remove the organ from the select mob.
 *
 * organ_owner - the mob who owns our organ, that we're removing the organ from.
 * special - "quick swapping" an organ out - when TRUE, the mob will be unaffected by not having that organ for the moment
 */
/obj/item/organ/proc/Remove(mob/living/carbon/organ_owner, special = FALSE)
	if(!istype(organ_owner))
		CRASH("Tried to remove an organ with no owner argument.")

	UnregisterSignal(owner, COMSIG_PARENT_EXAMINE)

	item_flags &= ~ABSTRACT

	owner = null
	for(var/datum/action/action as anything in actions)
		action.Remove(organ_owner)

	for(var/trait in organ_traits)
		REMOVE_TRAIT(organ_owner, trait, REF(src))

	SEND_SIGNAL(src, COMSIG_ORGAN_REMOVED, organ_owner)
	SEND_SIGNAL(organ_owner, COMSIG_CARBON_LOSE_ORGAN, src, special)

	organ_flags |= ORGAN_CUT_AWAY

	REMOVE_TRAIT(src, TRAIT_INSIDE_BODY, REF(organ_owner))
	organ_owner.organs -= src
	if(organ_owner.organs_by_slot[slot] == src)
		organ_owner.organs_by_slot.Remove(slot)

	if(!cosmetic_only)
		if((organ_flags & ORGAN_VITAL) && !special && !(organ_owner.status_flags & GODMODE) && organ_owner.needs_organ(slot))
			organ_owner.death(cause_of_death = "Brain removal")
		organ_owner.processing_organs -= src
		START_PROCESSING(SSobj, src)

	if(ownerlimb)
		ownerlimb.remove_organ(src)

	if(visual)
		organ_owner.cosmetic_organs.Remove(src)
		organ_owner.update_body_parts()

/// Cut an organ away from it's container, but do not remove it from the container physically.
/obj/item/organ/proc/cut_away()
	if(!ownerlimb)
		return

	var/obj/item/bodypart/old_owner = ownerlimb
	Remove(owner)
	old_owner.add_cavity_item(src)

/// Updates the traits of the organ on the specific organ it is called on. Should be called anytime an organ is given a trait while it is already in a body.
/obj/item/organ/proc/update_organ_traits()
	for(var/trait in organ_traits)
		ADD_TRAIT(owner, trait, REF(src))

/// Add a trait to an organ that it will give its owner.
/obj/item/organ/proc/add_organ_trait(trait)
	organ_traits |= trait
	update_organ_traits()

/// Removes a trait from an organ, and by extension, its owner.
/obj/item/organ/proc/remove_organ_trait(trait)
	organ_traits -= trait
	REMOVE_TRAIT(owner, trait, REF(src))

/obj/item/organ/proc/on_owner_examine(datum/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	return

/obj/item/organ/proc/on_find(mob/living/finder)
	return

/obj/item/organ/process(delta_time, times_fired)
	if(cosmetic_only)
		CRASH("Cosmetic organ processing!")
	on_death(delta_time, times_fired) //Kinda hate doing it like this, but I really don't want to call process directly.


/// This is on_life() but for when the owner is dead or outside of a mob. Bad name.
/obj/item/organ/proc/on_death(delta_time, times_fired)
	if(organ_flags & (ORGAN_SYNTHETIC|ORGAN_FROZEN|ORGAN_DEAD))
		return

	germ_level += rand(1,3)
	if(germ_level >= INFECTION_LEVEL_TWO)
		germ_level += rand(1,3)
	if(germ_level >= INFECTION_LEVEL_THREE)
		set_organ_dead(TRUE, "Necrosis")

/// Called once every life tick on every organ in a carbon's body
/// NOTE: THIS IS VERY HOT. Be careful what you put in here
/// To give you some scale, if there's 100 carbons in the game, they each have maybe 9 organs
/// So that's 900 calls to this proc every life process. Please don't be dumb
/// Return TRUE to call updatehealth(). Please only call inside of on_life() if it's important.
/obj/item/organ/proc/on_life(delta_time, times_fired)
	if(cosmetic_only)
		CRASH("Cosmetic organ processing!")

	if(organ_flags & ORGAN_SYNTHETIC_EMP) //Synthetic organ has been emped, is now failing.
		return applyOrganDamage(decay_factor * maxHealth * delta_time, updating_health = FALSE)

	if(organ_flags & ORGAN_SYNTHETIC)
		return

	if(owner.bodytemperature > TCRYO && !(organ_flags & ORGAN_FROZEN))
		handle_antibiotics()
		. = handle_germ_effects()


	if(damage) // No sense healing if you're not even hurt bro
		. = handle_regeneration() || .

/obj/item/organ/proc/handle_regeneration()
	if((organ_flags & ORGAN_SYNTHETIC) || CHEM_EFFECT_MAGNITUDE(owner, CE_TOXIN) || owner.undergoing_cardiac_arrest())
		return

	if(damage < maxHealth * 0.1)
		return applyOrganDamage(-0.1, updating_health = FALSE)

//Germs
/obj/item/organ/proc/handle_antibiotics()
	if(!owner || !germ_level)
		return

	if (!CHEM_EFFECT_MAGNITUDE(owner, CE_ANTIBIOTIC))
		return

	if (germ_level < INFECTION_LEVEL_ONE)
		germ_level = 0	//cure instantly
	else if (germ_level < INFECTION_LEVEL_TWO)
		germ_level -= 5	//at germ_level == 500, this should cure the infection in 5 minutes
	else
		germ_level -= 3 //at germ_level == 1000, this will cure the infection in 10 minutes

	if(owner.body_position == LYING_DOWN)
		germ_level -= 2

	germ_level = max(0, germ_level)


/obj/item/organ/proc/handle_germ_effects()
	//** Handle the effects of infections
	var/antibiotics = owner.reagents.get_reagent_amount(/datum/reagent/medicine/spaceacillin)

	if (germ_level > 0 && germ_level < INFECTION_LEVEL_ONE/2 && prob(0.3))
		germ_level--

	if (germ_level >= INFECTION_LEVEL_ONE/2)
		//aiming for germ level to go from ambient to INFECTION_LEVEL_TWO in an average of 15 minutes, when immunity is full.
		if(antibiotics < 5 && prob(round(germ_level/6 * 0.01)))
			germ_level += 1

	if(germ_level >= INFECTION_LEVEL_ONE)
		var/fever_temperature = (owner.dna.species.heat_level_1 - owner.dna.species.bodytemp_normal - 5)* min(germ_level/INFECTION_LEVEL_TWO, 1) + owner.dna.species.bodytemp_normal
		owner.bodytemperature += clamp((fever_temperature - T20C)/BODYTEMP_COLD_DIVISOR + 1, 0, fever_temperature - owner.bodytemperature)

	if (germ_level >= INFECTION_LEVEL_TWO)
		//spread germs
		if (antibiotics < 5 && ownerlimb.germ_level < germ_level && ( ownerlimb.germ_level < INFECTION_LEVEL_ONE*2 || prob(0.3) ))
			ownerlimb.germ_level++

		if (prob(3))	//about once every 30 seconds
			applyOrganDamage(1,silent=prob(30), updating_health = FALSE)

/obj/item/organ/examine(mob/user)
	. = ..()

	. += span_notice("It should be inserted in the [parse_zone(zone)].")

	if(organ_flags & ORGAN_DEAD)
		if(organ_flags & ORGAN_SYNTHETIC)
			. += span_warning("\The [src] looks completely spent.")
		else
			if(can_recover())
				. += span_warning("It has begun to decay.")
			else
				. += span_warning("The decay has set into [src].")

	else if(damage > high_threshold * maxHealth)
		. += span_warning("[src] is starting to look discolored.")

/obj/item/organ/proc/get_visible_state()
	if(damage > maxHealth)
		. = "bits and pieces of a destroyed "
	else if(damage > (maxHealth * high_threshold))
		. = "broken "
	else if(damage > (maxHealth * low_threshold))
		. = "badly damaged "
	else if(damage > 5)
		. = "damaged "
	if(organ_flags & ORGAN_DEAD)
		if(can_recover())
			. = "decaying [.]"
		else
			. = "necrotic [.]"
	. = "[.][name]"

///Used as callbacks by object pooling
/obj/item/organ/proc/exit_wardrobe()
	if(!cosmetic_only)
		START_PROCESSING(SSobj, src)

//See above
/obj/item/organ/proc/enter_wardrobe()
	if(!cosmetic_only)
		STOP_PROCESSING(SSobj, src)

/obj/item/organ/proc/OnEatFrom(eater, feeder)
	useable = FALSE //You can't use it anymore after eating it you spaztic

/obj/item/organ/item_action_slot_check(slot,mob/user)
	return //so we don't grant the organ's action to mobs who pick up the organ.

/obj/item/organ/proc/set_max_health(new_max)
	maxHealth = FLOOR(new_max, 1)
	damage = min(damage, maxHealth)

///Adjusts an organ's damage by the amount "damage_amount", up to a maximum amount, which is by default max damage
/obj/item/organ/proc/applyOrganDamage(damage_amount, maximum = maxHealth, silent, updating_health = TRUE, cause_of_death = "Organ failure") //use for damaging effects
	if(!damage_amount || cosmetic_only) //Micro-optimization.
		return
	if(maximum < damage)
		return
	// If the organ can't be healed, don't heal it.
	if(damage_amount < 0 && !can_recover())
		return

	var/old_damage = damage
	damage = min(clamp(damage + damage_amount, 0, maximum), maxHealth)
	. = damage - old_damage

	var/mess = check_damage_thresholds(owner)
	check_failing_thresholds(cause_of_death = cause_of_death)
	prev_damage = damage
	if(!silent && damage_amount > 0 && owner && owner.stat < UNCONSCIOUS && !(organ_flags & ORGAN_SYNTHETIC) && (damage_amount > 5 || prob(10)))
		if(!mess)
			var/obj/item/bodypart/BP = loc
			if(!BP)
				return
			var/degree = ""
			if(damage < low_threshold)
				degree = " a lot"
			else if(damage_amount < 5)
				degree = " a bit"

			owner.apply_pain(damage_amount, ownerlimb.body_zone, "Something inside your [BP.plaintext_zone] hurts[degree].", updating_health = FALSE)

///SETS an organ's damage to the amount "damage_amount", and in doing so clears or sets the failing flag, good for when you have an effect that should fix an organ if broken
/obj/item/organ/proc/setOrganDamage(damage_amount) //use mostly for admin heals
	applyOrganDamage(damage_amount - damage)
	check_failing_thresholds(TRUE)

/obj/item/organ/proc/getToxLoss()
	return organ_flags & ORGAN_SYNTHETIC ? damage * 0.5 : damage

/** check_damage_thresholds
 * input: mob/organ_owner (a mob, the owner of the organ we call the proc on)
 * output: returns a message should get displayed.
 * description: By checking our current damage against our previous damage, we can decide whether we've passed an organ threshold.
 *  If we have, send the corresponding threshold message to the owner, if such a message exists.
 */
/obj/item/organ/proc/check_damage_thresholds(mob/organ_owner)
	if(damage == prev_damage)
		return
	var/delta = damage - prev_damage
	if(delta > 0)
		if(damage >= maxHealth)
			return now_failing
		if(damage > (high_threshold * maxHealth) && prev_damage <= (high_threshold * maxHealth))
			return high_threshold_passed
		if(damage > (low_threshold * maxHealth) && prev_damage <= (low_threshold * maxHealth))
			return low_threshold_passed
	else
		if(prev_damage > (low_threshold * maxHealth)  && damage <= (low_threshold * maxHealth))
			return low_threshold_cleared
		if(prev_damage > (high_threshold * maxHealth) && damage <= (high_threshold * maxHealth))
			return high_threshold_cleared
		if(prev_damage == maxHealth)
			return now_fixed

///Checks if an organ should/shouldn't be failing and gives the appropriate organ flag
/obj/item/organ/proc/check_failing_thresholds(revivable, cause_of_death)
	if(damage >= maxHealth)
		set_organ_dead(TRUE, cause_of_death = cause_of_death)
	else if(revivable)
		set_organ_dead(FALSE)

/// Set or unset the organ as failing. Returns TRUE on success.
/obj/item/organ/proc/set_organ_dead(failing, cause_of_death)
	if(failing)
		if(organ_flags & ORGAN_DEAD)
			return FALSE
		organ_flags |= ORGAN_DEAD
		time_of_death = world.time
		return TRUE
	else
		if(organ_flags & ORGAN_DEAD)
			organ_flags &= ~ORGAN_DEAD
			time_of_death = 0
			return TRUE

/// Can this organ be revived from the dead?
/obj/item/organ/proc/can_recover()
	if(maxHealth < 0)
		return FALSE

	// You can always repair a cyber organ
	if((organ_flags & ORGAN_SYNTHETIC))
		return TRUE

	if(organ_flags & ORGAN_DEAD)
		if(world.time >= (time_of_death + ORGAN_RECOVERY_THRESHOLD))
			return FALSE

	return TRUE

/// Called by Insert() if the organ is vital and the target is dead.
/obj/item/organ/proc/attempt_vital_organ_revival(mob/living/carbon/human/owner)
	set waitfor = FALSE
	if(!owner.revive())
		return FALSE

	. = TRUE
	owner.grab_ghost()
	if(!HAS_TRAIT(owner, TRAIT_NOBREATH))
		spawn(-1)
			owner.emote("gasp")

/mob/living/proc/regenerate_organs()
	return FALSE

/mob/living/carbon/regenerate_organs()
	if(dna?.species)
		dna.species.regenerate_organs(src)
		return

	else
		var/obj/item/organ/lungs/lungs = getorganslot(ORGAN_SLOT_LUNGS)
		if(!lungs)
			lungs = new()
			lungs.Insert(src)
		lungs.setOrganDamage(0)

		var/obj/item/organ/heart/heart = getorganslot(ORGAN_SLOT_HEART)
		if(!heart)
			heart = new()
			heart.Insert(src)
		heart.setOrganDamage(0)

		var/obj/item/organ/tongue/tongue = getorganslot(ORGAN_SLOT_TONGUE)
		if(!tongue)
			tongue = new()
			tongue.Insert(src)
		tongue.setOrganDamage(0)

		var/obj/item/organ/eyes/eyes = getorganslot(ORGAN_SLOT_EYES)
		if(!eyes)
			eyes = new()
			eyes.Insert(src)
		eyes.setOrganDamage(0)

		var/obj/item/organ/ears/ears = getorganslot(ORGAN_SLOT_EARS)
		if(!ears)
			ears = new()
			ears.Insert(src)
		ears.setOrganDamage(0)

/** get_availability
 * returns whether the species should innately have this organ.
 *
 * regenerate organs works with generic organs, so we need to get whether it can accept certain organs just by what this returns.
 * This is set to return true or false, depending on if a species has a specific organless trait. stomach for example checks if the species has NOSTOMACH and return based on that.
 * Arguments:
 * owner_species - species, needed to return whether the species has an organ specific trait
 */
/obj/item/organ/proc/get_availability(datum/species/owner_species)
	return TRUE

/// Called before organs are replaced in regenerate_organs with new ones
/obj/item/organ/proc/before_organ_replacement(obj/item/organ/replacement)
	return

/// Called by medical scanners to get a simple summary of how healthy the organ is. Returns an empty string if things are fine.
/obj/item/organ/proc/get_scan_results(tag)
	RETURN_TYPE(/list)
	SHOULD_CALL_PARENT(TRUE)
	. = list()

	// Necrotic
	if(organ_flags & ORGAN_DEAD)
		if(organ_flags & ORGAN_SYNTHETIC)
			if(can_recover())
				. += tag ? "<span style='font-weight: bold; color: [COLOR_MEDICAL_INTERNAL_DANGER]'>Failing</span>" : "Failing"
			else
				. += tag ? "<span style='font-weight: bold; color: [COLOR_MEDICAL_NECROTIC]'>Irreparably Damaged</span>" : "Irreperably Damaged"
		else
			if(can_recover())
				. += tag ? "<span style='font-weight: bold; color: [COLOR_MEDICAL_INTERNAL_DANGER]'>Decaying</span>" : "Decaying"
			else
				. += tag ? "<span style='font-weight: bold; color: [COLOR_MEDICAL_NECROTIC]'>Necrotic</span>" : "Necrotic"

	// Infection
	var/germ_message
	switch (germ_level)
		if (INFECTION_LEVEL_ONE to INFECTION_LEVEL_ONE + ((INFECTION_LEVEL_TWO - INFECTION_LEVEL_ONE) / 3))
			germ_message =  "Mild Infection"
		if (INFECTION_LEVEL_ONE + ((INFECTION_LEVEL_TWO - INFECTION_LEVEL_ONE) / 3) to INFECTION_LEVEL_ONE + (2 * (INFECTION_LEVEL_TWO - INFECTION_LEVEL_ONE) / 3))
			germ_message =  "Mild Infection+"
		if (INFECTION_LEVEL_ONE + (2 * (INFECTION_LEVEL_TWO - INFECTION_LEVEL_ONE) / 3) to INFECTION_LEVEL_TWO)
			germ_message =  "Mild Infection++"
		if (INFECTION_LEVEL_TWO to INFECTION_LEVEL_TWO + ((INFECTION_LEVEL_THREE - INFECTION_LEVEL_THREE) / 3))
			germ_message =  "Acute Infection"
		if (INFECTION_LEVEL_TWO + ((INFECTION_LEVEL_THREE - INFECTION_LEVEL_THREE) / 3) to INFECTION_LEVEL_TWO + (2 * (INFECTION_LEVEL_THREE - INFECTION_LEVEL_TWO) / 3))
			germ_message =  "Acute Infection+"
		if (INFECTION_LEVEL_TWO + (2 * (INFECTION_LEVEL_THREE - INFECTION_LEVEL_TWO) / 3) to INFECTION_LEVEL_THREE)
			germ_message =  "Acute Infection++"
		if (INFECTION_LEVEL_THREE to INFINITY)
			germ_message =  "Septic"
	if (germ_message)
		. += tag ? "<span style='font-weight: bold; color: [COLOR_MEDICAL_TOXIN]'>[germ_message]</span>" : germ_message

	// Add more info if Technetium is in their blood
	if(owner?.has_reagent(/datum/reagent/technetium))
		. += tag ? "<span style='font-weight: bold; color:#E42426'> organ is [round((damage/maxHealth)*100, 1)]% damaged.</span>" : "[round((damage/maxHealth)*100, 1)]"
	else if(damage > high_threshold)
		. +=  tag ? "<span style='font-weight: bold; color:#ff9933'>Severely Damaged</span>" : "Severely Damaged"
	else if (damage > low_threshold)
		. += tag ? "<span style='font-weight: bold; color:#ffcc33'>Mildly Damaged</span>" : "Mildly Damaged"

	return

/// Used for the fix_organ surgery, lops off some of the maxHealth if the organ was very damaged.
/obj/item/organ/proc/surgically_fix(mob/user)
	if(damage > maxHealth * low_threshold)
		var/scarring = damage/maxHealth
		scarring = 1 - 0.3 * scarring ** 2 // Between ~15 and 30 percent loss
		var/new_max_dam = FLOOR(scarring * maxHealth, 1)
		if(new_max_dam < maxHealth)
			to_chat(user, span_warning("Not every part of [src] could be saved, some dead tissue had to be removed, making it more suspectable to damage in the future."))
			set_max_health(new_max_dam)
	applyOrganDamage(-damage)
