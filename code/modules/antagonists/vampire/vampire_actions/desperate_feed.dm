/datum/action/cooldown/desperate_feed
	name = "Desperate Feast"
	desc = "Feast upon your own arm."
	button_icon = 'goon/icons/actions.dmi'
	button_icon_state = "bite"

	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_HANDS_BLOCKED

/datum/action/cooldown/desperate_feed/is_valid_target(atom/cast_on)
	var/mob/living/carbon/human/user = owner
	var/obj/item/bodypart/arm/arm = user.get_active_hand()
	if(!arm)
		return FALSE

	if(arm.get_damage() >= arm.max_damage)
		return FALSE

	if(!IS_ORGANIC_LIMB(arm))
		return FALSE

	return TRUE


/datum/action/cooldown/desperate_feed/Activate(atom/target)
	. = ..()
	spawn(-1)
		var/mob/living/carbon/human/user = owner
		var/obj/item/bodypart/arm/arm = user.get_active_hand()
		var/obj/item/covering = user.get_item_covering_bodypart(arm)

		if(covering)
			user.visible_message(span_notice("[user] bites down onto [user.p_their()] arm covered by [covering]."))
			return

		user.visible_message(span_danger("[user] bites into [user.p_their()] [arm.plaintext_zone]."))

		ADD_TRAIT(user, TRAIT_MUTE, ref(src))
		var/image/succ_image = image('goon/icons/actions.dmi', "blood")

		var/datum/callback/checks_callback = CALLBACK(src, PROC_REF(can_tear_arm), user, arm)
		while(TRUE)
			if(!do_after(user, user, 3 SECONDS, DO_IGNORE_USER_LOC_CHANGE|DO_IGNORE_TARGET_LOC_CHANGE|DO_IGNORE_SLOWDOWNS|DO_PUBLIC, extra_checks = checks_callback, display = succ_image))
				user.visible_message(span_notice("[user] removes [user.p_their()] teeth from [user.p_their()] arm."))
				break

			tear_flesh(user, arm)

		REMOVE_TRAIT(user, TRAIT_MUTE, ref(src))

		user.visible_message(span_danger("[user] removes [p_their()] teeth from [p_their()] [arm.plaintext_zone]."))

/datum/action/cooldown/desperate_feed/proc/can_tear_arm(mob/living/carbon/human/user, obj/item/bodypart/arm/arm)
	if(arm.owner != user)
		return FALSE

	if(arm.get_damage() >= arm.max_damage)
		to_chat(user, span_warning("You cannot feast upon that arm any more."))
		return FALSE

	var/obj/item/covering = user.get_item_covering_bodypart(arm)
	if(covering)
		return FALSE

	return TRUE

/datum/action/cooldown/desperate_feed/proc/tear_flesh(mob/living/carbon/human/user, obj/item/bodypart/arm/arm)
	user.visible_message(span_danger("[user] tears flesh off of [user.p_their()] [arm.plaintext_zone]."))
	arm.receive_damage(10, sharpness = SHARP_POINTY, modifiers = (DAMAGE_CAN_FRACTURE | DAMAGE_CAN_JOSTLE_BONES))

	// Really dumb looking if block to say "2% chance to sever tendon, don't play a sound if we do."
	if(prob(98) || !arm.set_sever_tendon(TRUE))
		var/list/sound_pool = list(
			'sound/effects/dismember.ogg',
			'sound/effects/wounds/blood1.ogg',
			'sound/effects/wounds/blood2.ogg',
			'sound/effects/wounds/blood3.ogg',
			'sound/effects/wounds/crack1.ogg',
			'sound/effects/wounds/crackandbleed.ogg',
		)

		playsound(user, pick(sound_pool), 15, TRUE)

	if(isturf(user.loc))
		user.add_splatter_floor(user.loc, TRUE)

	var/datum/antagonist/vampire/vamp_datum = user.mind.has_antag_datum(/datum/antagonist/vampire)
	vamp_datum.thirst_level.remove_points(10)
	vamp_datum.update_thirst_stage()
