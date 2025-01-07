//Random seeds; stats, traits, and plant type are randomized for each seed.
/datum/plant/random
	species = "?????"
	name = "strange plant"

	icon_grow = "xpod-grow"
	icon_dead = "xpod-dead"
	icon_harvest = "xpod-harvest"
	growthstages = 4

	seed_path = /obj/item/seeds/random
	product_path = /obj/item/food/grown/random

/obj/item/seeds/random
	name = "pack of strange seeds"
	desc = "Mysterious seeds as strange as their name implies. Spooky."
	icon_state = "seed-x"

	custom_premium_price = PAYCHECK_EASY * 2

/obj/item/seeds/random/Initialize(mapload)
	. = ..()
	plant_datum.gene_holder.try_mutate_stats(5)

	if(prob(60))
		add_random_reagents(1, 3)
	if(prob(50))
		add_random_traits(1, 2)
	if(prob(35))
		add_random_plant_type()

/obj/item/seeds/random/proc/add_random_plant_type()
	var/random_plant_type = pick(subtypesof(/datum/plant_gene/trait/plant_type))
	var/datum/plant_gene/trait/plant_type/P = new random_plant_type
	if(P.can_add(src))
		genes += P
	else
		qdel(P)

/obj/item/seeds/random/proc/add_random_traits(lower = 0, upper = 2)
	var/amount_random_traits = rand(lower, upper)
	for(var/i in 1 to amount_random_traits)
		var/random_trait = pick(subtypesof(/datum/plant_gene/trait))
		var/datum/plant_gene/trait/picked_random_trait = new random_trait
		if((picked_random_trait.mutability_flags & PLANT_GENE_MUTATABLE) && picked_random_trait.can_add(src))
			genes += picked_random_trait
		else
			qdel(picked_random_trait)

/obj/item/seeds/random/proc/add_random_reagents(lower = 0, upper = 2)
	var/amount_random_reagents = rand(lower, upper)
	for(var/i in 1 to amount_random_reagents)
		var/random_amount = rand(4, 15) * 0.01 // this must be multiplied by 0.01, otherwise, it will not properly associate
		var/datum/plant_gene/reagent/R = new(get_random_reagent_id(), random_amount)
		if(R.can_add(src))
			if(!R.try_upgrade_gene(src))
				genes += R
		else
			qdel(R)

	reagents_from_genes()

/obj/item/food/grown/random
	seed = /obj/item/seeds/random
	name = "strange plant"
	desc = "What could this even be?"
	icon_state = "crunchy"

/obj/item/food/grown/random/Initialize(mapload)
	. = ..()
	wine_power = rand(10,150)
	if(prob(1))
		wine_power = 200
