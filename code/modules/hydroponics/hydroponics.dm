
/obj/machinery/hydroponics
	name = "hydroponics tray"
	icon = 'icons/obj/hydroponics/equipment.dmi'
	icon_state = "hydrotray"
	density = TRUE
	pass_flags_self = PASSMACHINE | LETPASSTHROW
	pixel_z = 8
	obj_flags = CAN_BE_HIT | UNIQUE_RENAME
	circuit = /obj/item/circuitboard/machine/hydroponics
	use_power = NO_POWER_USE
	///The amount of water in the tray (max 100)
	var/waterlevel = 100
	///The maximum amount of water in the tray
	var/maxwater = 100
	///How many units of nutrients will be drained in the tray.
	var/nutridrain = 1
	///The maximum nutrient reagent container size of the tray.
	var/maxnutri = 20
	///The amount of pests in the tray (max 10)
	var/pestlevel = 0
	///The amount of weeds in the tray (max 10)
	var/weedlevel = 0
	///Nutriment's effect on yield
	var/yieldmod = 1
	///Nutriment's effect on mutations
	var/mutmod = 1
	///Toxicity in the tray?
	var/toxic = 0
	///Current age
	var/age = 0
	///The status of the plant in the tray. Whether it's harvestable, alive, missing or dead.
	var/plant_status = HYDROTRAY_NO_PLANT
	///Its health
	var/plant_health
	///Last time it was harvested
	var/lastproduce = 0
	///Used for timing of cycles.
	var/lastcycle = 0
	///About 10 seconds / cycle
	var/cycledelay = 200
	///The currently planted seed
	var/obj/item/seeds/myseed
	///Obtained from the quality of the parts used in the tray, determines nutrient drain rate.
	var/rating = 1
	///Can it be unwrenched to move?
	var/unwrenchable = TRUE
	///Have we been visited by a bee recently, so bees dont overpollinate one plant
	var/recent_bee_visit = FALSE
	var/using_irrigation = FALSE
	///The last user to add a reagent to the tray, mostly for logging purposes.
	var/datum/weakref/lastuser
	///If the tray generates nutrients and water on its own
	var/self_sustaining = FALSE
	///The icon state for the overlay used to represent that this tray is self-sustaining.
	var/self_sustaining_overlay_icon_state = "gaia_blessing"

/o

/obj/machinery/hydroponics/bullet_act(obj/projectile/Proj) //Works with the Somatoray to modify plant variables.
	if(!myseed)
		return ..()
	if(istype(Proj , /obj/projectile/energy/floramut))
		mutate()
	else if(istype(Proj , /obj/projectile/energy/florayield))
		return myseed.bullet_act(Proj)
	else if(istype(Proj , /obj/projectile/energy/florarevolution))
		if(myseed)
			if(LAZYLEN(myseed.mutatelist))
				myseed.set_instability(myseed.instability/2)
		mutatespecie()
	else
		return ..()

/obj/machinery/hydroponics/power_change()
	. = ..()
	if((machine_stat & NOPOWER) && self_sustaining)
		set_self_sustaining(FALSE)

/obj/machinery/hydroponics/process(delta_time)
	var/needs_update = 0 // Checks if the icon needs updating so we don't redraw empty trays every time

	if(self_sustaining)
		if(powered())
			adjust_waterlevel(rand(1,2) * delta_time * 0.5)
			adjust_weedlevel(-0.5 * delta_time)
			adjust_pestlevel(-0.5 * delta_time)
		else
			set_self_sustaining(FALSE)
			visible_message(span_warning("[name]'s auto-grow functionality shuts off!"))

	if(world.time < (lastcycle + cycledelay))
		return

	lastcycle = world.time

	if(myseed && plant_status != HYDROTRAY_PLANT_DEAD)
		// Advance age
		age++
		if(age < myseed.maturation)
			lastproduce = age

		needs_update = 1


//Nutrients//////////////////////////////////////////////////////////////
		// Nutrients deplete at a constant rate, since new nutrients can boost stats far easier.
		apply_chemicals(lastuser?.resolve())
		if(self_sustaining)
			reagents.remove_all(min(0.5, nutridrain))
		else
			reagents.remove_all(nutridrain)

		// Lack of nutrients hurts non-weeds
		if(reagents.total_volume <= 0 && !myseed.get_gene(/datum/plant_gene/product_trait/plant_type/weed_hardy))
			adjust_plant_health(-rand(1,3))

//Photosynthesis/////////////////////////////////////////////////////////
		// Lack of light hurts non-mushrooms
		if(isturf(loc))
			var/turf/currentTurf = loc
			var/lightAmt = currentTurf.get_lumcount()
			var/is_fungus = myseed.get_gene(/datum/plant_gene/product_trait/plant_type/fungal_metabolism)
			if(lightAmt < (is_fungus ? 0.2 : 0.4))
				adjust_plant_health((is_fungus ? -1 : -2) / rating)

//Water//////////////////////////////////////////////////////////////////
		// Drink random amount of water
		adjust_waterlevel(-0.4 / rating)

		// If the plant is dry, it loses health pretty fast, unless mushroom
		if(waterlevel <= 10 && !myseed.get_gene(/datum/plant_gene/product_trait/plant_type/fungal_metabolism))
			adjust_plant_health(-rand(0,1) / rating)
			if(waterlevel <= 0)
				adjust_plant_health(-rand(0,2) / rating)

		// Sufficient water level and nutrient level = plant healthy but also spawns weeds
		else if(waterlevel > 10 && reagents.total_volume > 0)
			adjust_plant_health(rand(1,2) / rating)
			if(myseed && prob(myseed.weed_chance))
				adjust_weedlevel(myseed.weed_rate)
			else if(prob(5))  //5 percent chance the weed population will increase
				adjust_weedlevel(1 / rating)

//Toxins/////////////////////////////////////////////////////////////////

		// Too much toxins cause harm, but when the plant drinks the contaiminated water, the toxins disappear slowly
		if(toxic >= 40 && toxic < 80)
			adjust_plant_health(-1 / rating)
			adjust_toxic(-rating * 2)
		else if(toxic >= 80) // I don't think it ever gets here tbh unless above is commented out
			adjust_plant_health(-3)
			adjust_toxic(-rating * 3)

//Pests & Weeds//////////////////////////////////////////////////////////

		if(pestlevel >= 8)
			if(!myseed.get_gene(/datum/plant_gene/product_trait/carnivory))
				if(myseed.potency >=30)
					myseed.adjust_potency(-rand(2,6)) //Pests eat leaves and nibble on fruit, lowering potency.
					myseed.set_potency(min((myseed.potency), CARNIVORY_POTENCY_MIN, MAX_PLANT_POTENCY))
			else
				adjust_plant_health(2 / rating)
				adjust_pestlevel(-1 / rating)

		else if(pestlevel >= 4)
			if(!myseed.get_gene(/datum/plant_gene/product_trait/carnivory))
				if(myseed.potency >=30)
					myseed.adjust_potency(-rand(1,4))
					myseed.set_potency(min((myseed.potency), CARNIVORY_POTENCY_MIN, MAX_PLANT_POTENCY))

			else
				adjust_plant_health(1 / rating)
				if(prob(50))
					adjust_pestlevel(-1 / rating)

		else if(pestlevel < 4 && myseed.get_gene(/datum/plant_gene/product_trait/carnivory))
			if(prob(5))
				adjust_pestlevel(-1 / rating)

		// If it's a weed, it doesn't stunt the growth
		if(weedlevel >= 5 && !myseed.get_gene(/datum/plant_gene/product_trait/plant_type/weed_hardy))
			if(myseed.yield >=3)
				myseed.adjust_yield(-rand(1,2)) //Weeds choke out the plant's ability to bear more fruit.
				myseed.set_yield(min((myseed.yield), WEED_HARDY_YIELD_MIN, MAX_PLANT_YIELD))

//This is the part with pollination
		pollinate()

//This is where stability mutations exist now.
		if(myseed.instability >= 80)
			var/mutation_chance = myseed.instability - 75
			mutate(0, 0, 0, 0, 0, 0, 0, mutation_chance, 0) //Scaling odds of a random trait or chemical
		if(myseed.instability >= 60)
			if(prob((myseed.instability)/2) && !self_sustaining && LAZYLEN(myseed.mutatelist)) //Minimum 30%, Maximum 50% chance of mutating every age tick when not on autogrow.
				mutatespecie()
				myseed.set_instability(myseed.instability/2)
		if(myseed.instability >= 40)
			if(prob(myseed.instability))
				hardmutate()
		if(myseed.instability >= 20 )
			if(prob(myseed.instability))
				mutate()

//Health & Age///////////////////////////////////////////////////////////

		// Plant dies if plant_health <= 0
		if(plant_health <= 0)
			plantdies()
			adjust_weedlevel(1 / rating) // Weeds flourish

		// If the plant is too old, lose health fast
		if(age > myseed.lifespan)
			adjust_plant_health(-rand(1,5) / rating)

		// Harvest code
		if(age > myseed.production && (age - lastproduce) > myseed.production && plant_status == HYDROTRAY_PLANT_GROWING)
			if(myseed && myseed.yield != -1) // Unharvestable shouldn't be harvested
				set_plant_status(HYDROTRAY_PLANT_HARVESTABLE)
			else
				lastproduce = age
		if(prob(5))  // On each tick, there's a 5 percent chance the pest population will increase
			adjust_pestlevel(1 / rating)
	else
		if(waterlevel > 10 && reagents.total_volume > 0 && prob(10))  // If there's no plant, the percentage chance is 10%
			adjust_weedlevel(1 / rating)

	// Weeeeeeeeeeeeeeedddssss
	if(weedlevel >= 10 && prob(50) && !self_sustaining) // At this point the plant is kind of fucked. Weeds can overtake the plant spot.
		if(myseed && myseed.yield >= 3)
			myseed.adjust_yield(-rand(1,2)) //Loses even more yield per tick, quickly dropping to 3 minimum.
			myseed.set_yield(min((myseed.yield), WEED_HARDY_YIELD_MIN, MAX_PLANT_YIELD))
		if(!myseed)
			weedinvasion()
		needs_update = 1
	if (needs_update)
		update_appearance()

	if(myseed)
		SEND_SIGNAL(myseed, COMSIG_SEED_ON_GROW, src)

/**
 * Called after plant mutation, update the appearance of the tray content and send a visible_message()
 */
/obj/machinery/hydroponics/proc/after_mutation(message)
		update_appearance()
		visible_message(message)
		TRAY_NAME_UPDATE

/**
 * Plant Death Proc.
 * Cleans up various stats for the plant upon death, including pests, harvestability, and plant health.
 */
/obj/machinery/hydroponics/proc/plantdies()
	set_plant_health(0, update_icon = FALSE, forced = TRUE)
	set_plant_status(HYDROTRAY_PLANT_DEAD)
	set_pestlevel(0, update_icon = FALSE) // Pests die
	lastproduce = 0
	update_appearance()
	SEND_SIGNAL(src, COMSIG_HYDROTRAY_PLANT_DEATH)


/obj/machinery/hydroponics/attackby_secondary(obj/item/weapon, mob/user, params)
	if (istype(weapon, /obj/item/reagent_containers/syringe))
		to_chat(user, span_warning("You can't get any extract out of this plant."))
		return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN
	return SECONDARY_ATTACK_CALL_NORMAL

/obj/machinery/hydroponics/CtrlClick(mob/user, list/params)
	. = ..()
	if(!user.canUseTopic(src, USE_CLOSE|USE_IGNORE_TK))
		return
	if(!powered())
		to_chat(user, span_warning("[name] has no power."))
		update_use_power(NO_POWER_USE)
		return
	if(!anchored)
		return
	set_self_sustaining(!self_sustaining)
	to_chat(user, span_notice("You [self_sustaining ? "activate" : "deactivated"] [src]'s autogrow function[self_sustaining ? ", maintaining the tray's health while using high amounts of power" : ""]."))

/obj/machinery/hydroponics/AltClick(mob/user)
	return ..() // This hotkey is BLACKLISTED since it's used by /datum/component/simple_rotation

/**
 * Update Tray Proc
 * Handles plant harvesting on the tray side, by clearing the sead, names, description, and dead stat.
 * Shuts off autogrow if enabled.
 * Sends messages to the cleaer about plants harvested, or if nothing was harvested at all.
 * * User - The mob who clears the tray.
 */
/obj/machinery/hydroponics/proc/update_tray(mob/user, product_count)
	lastproduce = age
	if(istype(myseed, /obj/item/seeds/replicapod))
		to_chat(user, span_notice("You harvest from the [myseed.plantname]."))
	else if(product_count <= 0)
		to_chat(user, span_warning("You fail to harvest anything useful!"))
	else
		to_chat(user, span_notice("You harvest [product_count] items from the [myseed.plantname]."))
	if(!myseed.get_gene(/datum/plant_gene/product_trait/repeated_harvest))
		set_seed(null)
		name = initial(name)
		desc = initial(desc)
		TRAY_NAME_UPDATE
		if(self_sustaining) //No reason to pay for an empty tray.
			set_self_sustaining(FALSE)
	else
		set_plant_status(HYDROTRAY_PLANT_GROWING)
	update_appearance()
	SEND_SIGNAL(src, COMSIG_HYDROTRAY_ON_HARVEST, user, product_count)


