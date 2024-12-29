/obj/effect/aether_rune/revival

/obj/effect/aether_rune/revival/find_target_mob()
	for(var/mob/living/carbon/human/H in loc)
		if(H.stat != DEAD)
			continue

		var/obj/item/organ/brain/B = H.getorganslot(ORGAN_SLOT_BRAIN)
		if(!B)
			continue

		return H

/obj/effect/aether_rune/revival/succeed_invoke(mob/living/carbon/human/target_mob)
	var/obj/item/organ/brain/B = target_mob.getorganslot(ORGAN_SLOT_BRAIN)
	B.applyOrganDamage(-INFINITY)
	B.set_organ_dead(FALSE)
	target_mob.set_heartattack(FALSE)
	target_mob.revive()

	target_mob.visible_message(
		span_statsgood("Lifeforce floods into [target_mob]'s flesh, briefly turning [target_mob.p_their()] veins a vile green as it crawls through [target_mob.p_them()].")
	)

	target_mob.Knockdown(10 SECONDS)
	target_mob.Paralyze(4 SECONDS)

	if(target_mob.stat == CONSCIOUS)
		spawn(-1)
			target_mob.emote("gasp")
			target_mob.manual_emote("coughs up blood onto [loc].")
			target_mob.add_splatter_floor(loc)

	return ..()

/obj/effect/aether_rune/revival/register_target_mob(target)
	RegisterSignal(target, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING), PROC_REF(clear_revival_target))
	RegisterSignal(target, COMSIG_MOB_STATCHANGE, PROC_REF(target_stat_change))

/obj/effect/aether_rune/revival/unregister_target_mob(target)
	UnregisterSignal(target, list(COMSIG_MOVABLE_MOVED, COMSIG_PARENT_QDELETING, COMSIG_MOB_STATCHANGE))

/obj/effect/aether_rune/revival/proc/clear_revival_target(datum/source)
	SIGNAL_HANDLER

	var/mob/M = source
	if(QDELETED(source))
		try_cancel_invoke(RUNE_FAIL_GRACEFUL)
		return

	if(M.loc != loc)
		try_cancel_invoke(RUNE_FAIL_TARGET_MOB_MOVED, source)

/obj/effect/aether_rune/revival/proc/target_stat_change(datum/source)
	SIGNAL_HANDLER

	var/mob/living/L = source
	if(L.stat != DEAD)
		try_cancel_invoke(RUNE_FAIL_REVIVAL_TARGET_ALIVE, L)
