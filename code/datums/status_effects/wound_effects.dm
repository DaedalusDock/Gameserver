
// The shattered remnants of your broken limbs fill you with determination!
/atom/movable/screen/alert/status_effect/determined
	name = "Determined"
	desc = "The serious wounds you've sustained have put your body into fight-or-flight mode! Now's the time to look for an exit!"
	icon_state = "regenerative_core"

/datum/status_effect/determined
	id = "determined"
	alert_type = /atom/movable/screen/alert/status_effect/determined

/datum/status_effect/determined/on_apply()
	. = ..()
	owner.visible_message(span_danger("[owner]'s body tenses up noticeably, gritting against [owner.p_their()] pain!"), span_notice("<b>Your senses sharpen as your body tenses up from the wounds you've sustained!</b>"), \
		vision_distance=COMBAT_MESSAGE_RANGE)
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.bleed_mod *= WOUND_DETERMINATION_BLEED_MOD

/datum/status_effect/determined/on_remove()
	owner.visible_message(span_danger("[owner]'s body slackens noticeably!"), span_warning("<b>Your adrenaline rush dies off, and the pain from your wounds come aching back in...</b>"), vision_distance=COMBAT_MESSAGE_RANGE)
	if(ishuman(owner))
		var/mob/living/carbon/human/human_owner = owner
		human_owner.physiology.bleed_mod /= WOUND_DETERMINATION_BLEED_MOD
	return ..()

/datum/status_effect/limp
	id = "limp"
	status_type = STATUS_EFFECT_REPLACE
	tick_interval = 0
	alert_type = /atom/movable/screen/alert/status_effect/limp
	var/msg_stage = 0//so you dont get the most intense messages immediately
	/// The left leg of the limping person
	var/obj/item/bodypart/leg/left/left
	/// The right leg of the limping person
	var/obj/item/bodypart/leg/right/right
	/// Which leg we're limping with next
	var/obj/item/bodypart/next_leg
	/// How many deciseconds we limp for on the left leg
	var/slowdown_left = 0
	/// How many deciseconds we limp for on the right leg
	var/slowdown_right = 0
	/// The chance we limp with the left leg each step it takes
	var/limp_chance_left = 0
	/// The chance we limp with the right leg each step it takes
	var/limp_chance_right = 0

	/// Keeps track of how many steps have been taken on the left leg
	var/steps_left = 0
	/// Keeps track of how many steps have been taken on the right leg.
	var/steps_right = 0

/datum/status_effect/limp/on_apply()
	if(!iscarbon(owner))
		return FALSE
	var/mob/living/carbon/C = owner

	left = C.get_bodypart(BODY_ZONE_L_LEG)
	right = C.get_bodypart(BODY_ZONE_R_LEG)

	update_limp()
	RegisterSignal(C, COMSIG_MOVABLE_MOVED, PROC_REF(check_step))
	RegisterSignal(C, list(COMSIG_CARBON_ATTACH_LIMB, COMSIG_CARBON_REMOVED_LIMB), PROC_REF(update_limp))

	if(left)
		RegisterSignal(left, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_limp))
	if(right)
		RegisterSignal(right, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_limp))
	return TRUE

/datum/status_effect/limp/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_CARBON_ATTACH_LIMB, COMSIG_CARBON_REMOVED_LIMB))
	if(left)
		UnregisterSignal(left, COMSIG_LIMB_UPDATE_INTERACTION_SPEED)
	if(right)
		UnregisterSignal(right, COMSIG_LIMB_UPDATE_INTERACTION_SPEED)

	left = null
	right = null

/atom/movable/screen/alert/status_effect/limp
	name = "Limping"
	desc = "One or more of your legs has been wounded, slowing down steps with that leg! Get it fixed, or at least in a sling of gauze!"

/datum/status_effect/limp/proc/check_step(mob/whocares, OldLoc, Dir, forced)
	SIGNAL_HANDLER

	if(!owner.client || owner.body_position == LYING_DOWN || !owner.has_gravity() || (owner.movement_type & FLYING) || forced || owner.buckled)
		return

	// less limping while we have determination still
	var/determined_mod = owner.has_status_effect(/datum/status_effect/determined) ? 0.5 : 1

	if(next_leg == left)
		// Apply slowdown, if there is any
		if(prob(limp_chance_left * determined_mod))
			owner.client.move_delay += slowdown_left * determined_mod

		// Apply pain every 10 steps if the leg is broken.
		steps_left++
		if(steps_left %% 10 == 0)
			steps_left = 0
		if(steps_left == 0 && !left.splint && (left.bodypart_flags & BP_BROKEN_BONES))
			pain(left)

		if(right)
			next_leg = right
	else
		// Apply slowdown, if there is any
		if(prob(limp_chance_right * determined_mod))
			owner.client.move_delay += slowdown_right * determined_mod

		// Apply pain every 10 steps if the leg is broken.
		steps_right++
		if(steps_right %% 10 == 0)
			steps_right = 0
		if(steps_right == 0 && !right.splint && (right.bodypart_flags & BP_BROKEN_BONES))
			pain(right)

		if(left)
			next_leg = left

/datum/status_effect/limp/proc/pain(obj/item/bodypart/leg/leg)
	if(leg.bodypart_flags & BP_NO_PAIN)
		return

	owner.apply_pain(40, leg, "A terrible pain shoots through your [leg.plaintext_zone].", TRUE)

/datum/status_effect/limp/proc/update_limp()
	SIGNAL_HANDLER

	var/mob/living/carbon/C = owner
	var/new_left = C.get_bodypart(BODY_ZONE_L_LEG)
	var/new_right = C.get_bodypart(BODY_ZONE_R_LEG)
	if(new_left != left)
		if(left)
			UnregisterSignal(left, COMSIG_LIMB_UPDATE_INTERACTION_SPEED)
		left = null
		if(new_left)
			left = new_left
			RegisterSignal(left, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_limp))
	if(new_right != right)
		if(right)
			UnregisterSignal(right, COMSIG_LIMB_UPDATE_INTERACTION_SPEED)
		right = null
		if(new_right)
			right = new_right
			RegisterSignal(right, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_limp))

	if(!left && !right)
		C.remove_status_effect(src)
		return

	slowdown_left = 1
	slowdown_right = 1
	limp_chance_left = 0
	limp_chance_right = 0

	if(left)
		slowdown_left = left.interaction_speed_modifier
		limp_chance_left = 100

	if(right)
		slowdown_right = right.interaction_speed_modifier
		limp_chance_right = 100

	// this handles losing your leg with the limp and the other one being in good shape as well
	if(slowdown_left + slowdown_right == 2)
		C.remove_status_effect(src)
		return


/atom/movable/screen/alert/status_effect/broken_arm
	name = "Restricted Arm"
	desc = "One or more of your arms is restricted or broken, it is difficult to use!"

/datum/status_effect/arm_slowdown
	id = "arm_broke"
	status_type = STATUS_EFFECT_UNIQUE
	tick_interval = 0
	alert_type = /atom/movable/screen/alert/status_effect/broken_arm

	/// The left leg of the limping person
	var/obj/item/bodypart/arm/left
	var/obj/item/bodypart/arm/right

	var/speed_left
	var/speed_right

/datum/status_effect/arm_slowdown/on_remove()
	. = ..()
	var/mob/living/carbon/C = owner
	C.remove_actionspeed_modifier(/datum/actionspeed_modifier/broken_arm)

/datum/status_effect/arm_slowdown/on_apply()
	if(!iscarbon(owner))
		return FALSE

	var/mob/living/carbon/C = owner
	left = C.get_bodypart(BODY_ZONE_L_ARM)
	right = C.get_bodypart(BODY_ZONE_R_ARM)

	RegisterSignal(owner, COMSIG_MOB_SWAP_HANDS, PROC_REF(on_hand_swap))
	RegisterSignal(owner, list(COMSIG_CARBON_REMOVED_LIMB, COMSIG_CARBON_ATTACH_LIMB), PROC_REF(update_slow))
	if(left)
		speed_left = left.interaction_speed_modifier
		RegisterSignal(left, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_slow))
	if(right)
		speed_right = right.interaction_speed_modifier
		RegisterSignal(right, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_slow))

	apply_to_mob()
	return TRUE

/datum/status_effect/arm_slowdown/proc/update_slow()
	SIGNAL_HANDLER

	var/mob/living/carbon/C = owner
	var/new_left = C.get_bodypart(BODY_ZONE_L_ARM)
	var/new_right = C.get_bodypart(BODY_ZONE_R_ARM)
	if(new_left != left)
		if(left)
			UnregisterSignal(left, COMSIG_LIMB_UPDATE_INTERACTION_SPEED)
		left = null
		if(new_left)
			left = new_left
			RegisterSignal(left, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_slow))
	if(new_right != right)
		if(right)
			UnregisterSignal(right, COMSIG_LIMB_UPDATE_INTERACTION_SPEED)
		right = null
		if(new_right)
			right = new_right
			RegisterSignal(right, COMSIG_LIMB_UPDATE_INTERACTION_SPEED, PROC_REF(update_slow))

	speed_left = left?.interaction_speed_modifier || 1
	speed_right = right?.interaction_speed_modifier || 1

	if((speed_left + speed_left) == 2) // 1 + 1 = 2
		C.remove_status_effect(src)
		return

	apply_to_mob()

/datum/status_effect/arm_slowdown/proc/apply_to_mob()
	SIGNAL_HANDLER
	var/mob/living/carbon/C = owner
	var/hand = C.get_active_hand()?.body_zone

	if(hand == BODY_ZONE_R_ARM)
		if(speed_right == 1)
			C.remove_actionspeed_modifier(/datum/actionspeed_modifier/broken_arm)
		else
			C.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/broken_arm, slowdown = speed_right)
	else if(hand == BODY_ZONE_L_ARM)
		if(speed_left == 1)
			C.remove_actionspeed_modifier(/datum/actionspeed_modifier/broken_arm)
		else
			C.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/broken_arm, slowdown = speed_left)

/datum/status_effect/arm_slowdown/proc/on_hand_swap()
	SIGNAL_HANDLER
	spawn(0) // The SWAP_HANDS comsig fires before we actually change our active hand.
		apply_to_mob()

/datum/status_effect/arm_slowdown/nextmove_modifier()
	var/mob/living/carbon/C = owner

	var/hand = C.get_active_hand().body_zone
	if(hand)
		if(hand == BODY_ZONE_R_ARM)
			return speed_right
		else
			return speed_left
	return 1

/////////////////////////
//////// WOUNDS /////////
/////////////////////////

// wound alert
/atom/movable/screen/alert/status_effect/wound
	name = "Wounded"
	desc = "Your body has sustained serious damage, click here to inspect yourself."

/atom/movable/screen/alert/status_effect/wound/Click()
	. = ..()
	if(!.)
		return

	var/mob/living/carbon/carbon_owner = owner
	carbon_owner.check_self_for_injuries()

