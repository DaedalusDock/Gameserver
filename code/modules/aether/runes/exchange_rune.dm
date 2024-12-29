/obj/effect/aether_rune/exchange
	invocation_phrases = list(
		"Ar sha cholo shalotzata" = 3 SECONDS,
		"Vunahar ma ol'chak chona" = 3 SECONDS,
		"Hak erevimbok yomrashlo" = 2 SECONDS,
	)

/obj/effect/aether_rune/exchange/wipe_state()
	for(var/item in blackboard[RUNE_BB_EXCHANGE_PARTS])
		unregister_item(item)
	return ..()

/obj/effect/aether_rune/exchange/pre_invoke(mob/living/user, obj/item/aether_tome/tome)
	. = ..()

	var/list/things = list()

	for(var/obj/item/I in orange(1, src))
		if(!isturf(I.loc))
			continue

		if(isbodypart(I) || isorgan(I))
			register_item(I)
			things += I

	blackboard[RUNE_BB_EXCHANGE_PARTS] = things

/obj/effect/aether_rune/exchange/can_invoke()
	. = ..()
	if(!.)
		return

	return length(blackboard[RUNE_BB_EXCHANGE_PARTS])

/obj/effect/aether_rune/exchange/succeed_invoke(mob/living/carbon/human/target_mob)
	var/list/parts = blackboard[RUNE_BB_EXCHANGE_PARTS]
	for(var/obj/item/bodypart/new_limb in parts)
		var/oldloc = get_turf(new_limb)
		var/obj/item/bodypart/old_limb = target_mob.get_bodypart(new_limb.body_zone)

		if(new_limb.replace_limb(target_mob, TRUE))
			old_limb?.forceMove(oldloc)

	for(var/obj/item/organ/new_organ in parts)
		var/oldloc = get_turf(new_organ)
		var/obj/item/organ/old_organ = target_mob.getorganslot(new_organ.slot)

		old_organ.Remove(target_mob, TRUE)
		new_organ.Insert(target_mob, TRUE)
		old_organ.forceMove(oldloc)

	return ..()

/obj/effect/aether_rune/exchange/fail_invoke(failure_reason, failure_source)
	if(failure_reason == RUNE_FAIL_GRACEFUL)
		return ..()

	switch(failure_reason)
		if(RUNE_FAIL_TARGET_MOB_MOVED, RUNE_FAIL_TARGET_STOOD_UP)
			switch(rand(1,10))
				if(1 to 6)
					rip_out_target_heart()
				if(6 to 8)
					dismember_mob(failure_source)
				if(9 to 10)
					rip_out_organs(failure_source)

		if(RUNE_FAIL_HELPER_REMOVED_HAND)
			if(prob(50))
				dismember_mob(failure_source)
			else
				rip_out_organs(failure_source)

		if(RUNE_FAIL_INVOKER_INCAP)
			if(length(touching_rune))
				var/victim = pick(touching_rune)
				if(prob(50))
					dismember_mob(victim)
				else
					rip_out_organs(victim)
			else
				rip_out_target_heart()
		else
			rip_out_target_heart()

	return ..()

/obj/effect/aether_rune/exchange/proc/rip_out_target_heart()
	var/mob/living/carbon/human/victim = blackboard[RUNE_BB_TARGET_MOB]
	var/mob/living/carbon/human/invoker = blackboard[RUNE_BB_INVOKER]
	var/obj/item/organ/heart/victim_heart = victim?.getorganslot(ORGAN_SLOT_HEART)
	if(!victim_heart || !victim || !invoker)
		return

	victim_heart.Remove(victim)
	if(!invoker.pickup_item(victim_heart, invoker.get_empty_held_index(), TRUE))
		victim_heart.forceMove(get_turf(victim))

	victim_heart.Restart()
	victim.add_splatter_floor(get_turf(victim))

/obj/effect/aether_rune/exchange/proc/rip_out_organs(mob/living/carbon/human/victim)
	var/list/organs = victim.processing_organs.Copy()
	organs -= locate(/obj/item/organ/brain) in organs
	if(!length(organs))
		return

	var/turf/victim_turf = get_turf(victim)
	victim.add_splatter_floor(victim_turf)

	for(var/i in 1 to rand(1, 2))
		if(!length(organs))
			return

		var/obj/item/organ/picked_organ = pick_n_take(organs)
		picked_organ.Remove(victim)
		picked_organ.forceMove(victim_turf)
		playsound(loc, 'sound/misc/splort.ogg', 80, TRUE)

		var/turf/target_turf = get_random_perimeter_turf(src, 3)
		picked_organ.throw_at(target_turf, rand(1,3), 1)

/obj/effect/aether_rune/exchange/proc/dismember_mob(mob/living/carbon/human/victim)
	var/list/bodyparts = victim.bodyparts.Copy()

	for(var/i in 1 to 3)
		if(!length(bodyparts))
			return

		var/obj/item/bodypart/picked = pick_n_take(bodyparts)
		picked.dismember()

/obj/effect/aether_rune/exchange/proc/register_item(obj/item/I)
	RegisterSignal(I, list(COMSIG_PARENT_QDELETING, COMSIG_MOVABLE_MOVED), PROC_REF(item_moved_or_deleted))

/obj/effect/aether_rune/exchange/proc/unregister_item(obj/item/I)
	UnregisterSignal(I, list(COMSIG_PARENT_QDELETING, COMSIG_MOVABLE_MOVED))

/obj/effect/aether_rune/exchange/proc/item_moved_or_deleted(datum/source)
	SIGNAL_HANDLER

	var/obj/item/I = source
	if(QDELETED(I))
		try_cancel_invoke(RUNE_FAIL_GRACEFUL)
		return

	if(get_dist(src, I) > 1)
		try_cancel_invoke(RUNE_FAIL_TARGET_ITEM_OUT_OF_RUNE, I)
