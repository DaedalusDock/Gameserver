/proc/status_effect_to_viewers(target, mod_path, message, range = world.view, exclude_mobs)
	for(var/mob/living/carbon/human/M in viewers(target, range) - exclude_mobs)
		if(M.is_blind() || M.stat != CONSCIOUS)
			continue

		M.apply_status_effect(mod_path)
		if(message)
			to_chat(M, message)

/datum/status_effect/stat_mod
	tick_interval = -1
	status_type = STATUS_EFFECT_MULTIPLE
	alert_type = null

	/// Type path of the s
	var/stat_path
	/// Amount to modify by
	var/modify_amt
	/// A string source like "Incapacitated".
	var/source

/datum/status_effect/stat_mod/on_apply()
	. = ..()
	if(!owner.stats)
		return FALSE

	owner.stats.set_stat_modifier(modify_amt, stat_path, source)

/datum/status_effect/stat_mod/on_remove()
	owner.stats.remove_stat_modifier(stat_path, source)

/datum/status_effect/skill_mod
	tick_interval = -1
	status_type = STATUS_EFFECT_MULTIPLE
	alert_type = null

	/// Type path of the skill to modify
	var/skill_path
	/// Amount to modify by
	var/modify_amt
	/// A string source like "Incapacitated".
	var/source

/datum/status_effect/skill_mod/on_apply()
	. = ..()
	if(!owner.stats)
		return FALSE

	owner.stats.set_skill_modifier(modify_amt, skill_path, source)

/datum/status_effect/skill_mod/on_remove()
	owner.stats.remove_skill_modifier(skill_path, source)
