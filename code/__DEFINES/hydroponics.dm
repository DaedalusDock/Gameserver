// Plant states
#define PLANT_DEAD "dead"
#define PLANT_PLANTED "planted"
#define PLANT_GROWING "growing"
#define PLANT_MATURE "mature"
#define PLANT_HARVESTABLE "harvestable"

// Plant stats
#define PLANT_STAT_GROW_TIME "time_to_grow"
#define PLANT_STAT_PRODUCE_TIME "time_to_produce"
#define PLANT_STAT_YIELD "yield"
#define PLANT_STAT_HARVEST_AMT "harvest_amt"
#define PLANT_STAT_ENDURANCE "endurance"
#define PLANT_STAT_POTENCY "potency"

#define PLANT_STAT_PROB_ROUND(num) (trunc(num) + prob(fract(num) * 100) * SIGN(num))

/// Water level above this is considered drowning the plant.
#define HYDRO_WATER_DROWNING_LIMIT 50

/// Growth per process tick (1 second) base
#define HYDRO_BASE_GROWTH_RATE 1
/// Damage per process tick (1 second) if the plant has no water.
#define HYDRO_NO_WATER_DAMAGE 1

// Plant damage types
/// Lack of water during process tick
#define PLANT_DAMAGE_NO_WATER "no_water"
