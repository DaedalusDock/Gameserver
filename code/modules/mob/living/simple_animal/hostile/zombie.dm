/mob/living/simple_animal/hostile/zombie
	name = "Shambling Corpse"
	desc = "When there is no more room in hell, the dead will walk in outer space."
	icon = 'icons/mob/simple_human.dmi'
	icon_state = "zombie"
	icon_living = "zombie"
	mob_biotypes = MOB_ORGANIC|MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	speak_chance = 0
	stat_attack = UNCONSCIOUS //braains
	maxHealth = 100
	health = 100
	harm_intent_damage = 5
	melee_damage_lower = 21
	melee_damage_upper = 21
	attack_verb_continuous = "bites"
	attack_verb_simple = "bite"
	attack_sound = 'sound/hallucinations/growl1.ogg'
	attack_vis_effect = ATTACK_EFFECT_BITE
	combat_mode = TRUE
	atmos_requirements = list("min_oxy" = 0, "max_oxy" = 0, "min_plas" = 0, "max_plas" = 0, "min_co2" = 0, "max_co2" = 0, "min_n2" = 0, "max_n2" = 0)
	minbodytemp = 0
	status_flags = CANPUSH
	del_on_death = 1
	var/zombiejob = JOB_ACOLYTE
	var/infection_chance = 0

/mob/living/simple_animal/hostile/zombie/Initialize(mapload)
	. = ..()
	INVOKE_ASYNC(src, PROC_REF(setup_visuals))

/mob/living/simple_animal/hostile/zombie/proc/setup_visuals()
	var/datum/job/job = SSjob.GetJob(zombiejob)

	var/datum/outfit/outfit = job.outfits["Default"]?[SPECIES_HUMAN]

	var/mob/living/carbon/human/dummy/dummy = new
	qdel(dummy.get_item_for_held_index(1))
	qdel(dummy.get_item_for_held_index(2))
	dummy.equipOutfit(outfit)
	dummy.set_species(/datum/species/zombie)
	icon = getFlatIcon(dummy)
	qdel(dummy)

/mob/living/simple_animal/hostile/zombie/AttackingTarget()
	. = ..()
	if(. && ishuman(target) && prob(infection_chance))
		try_to_zombie_infect(target)
