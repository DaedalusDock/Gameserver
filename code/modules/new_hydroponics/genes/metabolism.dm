/datum/plant_gene/metabolism_slow
	name = "Slow Metabolism"
	desc = "This gene slows the growth of a plant, but reduces water consumption."

/datum/plant_gene/metabolism_slow/tick(delta_time, obj/machinery/hydroponics_tray/tray, datum/plant/plant, datum/plant_tick/plant_tick)
	. = ..()
	if(.)
		return

	plant_tick.water_consumption -= 0.5
	plant_tick.overall_multiplier -= 0.25

/datum/plant_gene/metabolism_fast
	name = "Fast Metabolism"
	desc = "This gene causes a plant to grow faster, but also consume water more rapidly."

/datum/plant_gene/metabolism_slow/tick(delta_time, obj/machinery/hydroponics_tray/tray, datum/plant/plant, datum/plant_tick/plant_tick)
	. = ..()
	if(.)
		return

	plant_tick.water_consumption += 1
	plant_tick.overall_multiplier += 0.5
