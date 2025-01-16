/*
Contains helper procs for airflow, handled in /connection_group.
This entire system is an absolute mess.
*/
#define AIRBORNE_DAMAGE(airborne_thing) (min(airborne_thing.airflow_speed, (airborne_thing.airborne_acceleration*2)) * zas_settings.airflow_damage)

/mob
	var/tmp/last_airflow_stun = 0

/atom/movable
	///The location the atom is trying to step towards during airflow.
	var/tmp/turf/airflow_dest
	///The speed the object is travelling during airflow
	var/tmp/airflow_speed = 0
	///Time (ticks) spent in airflow
	var/tmp/airflow_time = 0
	/// Cooldown for airflow push.
	COOLDOWN_DECLARE(airflow_push_cooldown)
	var/tmp/airborne_acceleration = 0

	var/tmp/airflow_xo
	var/tmp/airflow_yo
	///If the movable is dense by default, it won't step into tiles containing other dense objects
	var/tmp/airflow_old_density
	var/tmp/airflow_process_delay
	var/tmp/airflow_skip_speedcheck
	///Bump() magic
	var/moving_by_airflow = FALSE



///Applies the effects of the mob colliding with another movable due to airflow.
/mob/proc/airflow_stun(delta_p)
	return

/mob/living/airflow_stun(delta_p)
	if(stat == DEAD)
		return FALSE

	if(last_airflow_stun > world.time - zas_settings.airflow_stun_cooldown)
		return FALSE

	if(!(status_flags & CANSTUN) || !(status_flags & CANKNOCKDOWN))
		return FALSE

	if(HAS_TRAIT(src, TRAIT_NEGATES_GRAVITY)) //Magboots
		return FALSE

	if(body_position == LYING_DOWN)
		return FALSE

	Knockdown(zas_settings.airflow_stun * clamp((delta_p / zas_settings.airflow_stun_pressure), 1, 3))

	visible_message(
		span_danger("[src] is thrown to the floor!"),
		blind_message = span_hear("You hear a gust of air, followed by a soft thud.")
	)

	last_airflow_stun = world.time

/mob/living/silicon/airflow_stun(delta_p)
	return

/mob/living/simple_animal/slime/airflow_stun(delta_p)
	return

/// Checks to see if airflow can move this movable.
/atom/movable/proc/can_airflow_move(delta_p)
	//We're just hoping nothing goes wrong
	return TRUE

/mob/can_airflow_move(delta_p)
	if(status_flags & GODMODE)
		return FALSE
	if(buckled)
		return FALSE
	if(delta_p < zas_settings.airflow_mob_pressure)
		return FALSE
	if(HAS_TRAIT(src, TRAIT_NEGATES_GRAVITY)) //Magboots
		return FALSE
	return ..()

/mob/living/silicon/can_airflow_move(delta_p)
	return FALSE

/obj/can_airflow_move(delta_p)
	if(anchored) // zone/proc/movables() checks this already for real spacewind, but other things may use this proc.
		return FALSE
	if(density && (delta_p < zas_settings.airflow_dense_pressure))
		return FALSE
	return ..()

/obj/item/can_airflow_move(delta_p)
	switch(w_class)
		if(0,WEIGHT_CLASS_TINY,WEIGHT_CLASS_SMALL)
			if(delta_p < zas_settings.airflow_lightest_pressure)
				return FALSE
		if(WEIGHT_CLASS_NORMAL)
			if(delta_p < zas_settings.airflow_light_pressure)
				return FALSE
		if(WEIGHT_CLASS_BULKY, WEIGHT_CLASS_HUGE)
			if(delta_p < zas_settings.airflow_medium_pressure)
				return FALSE
		if(WEIGHT_CLASS_GIGANTIC)
			if(delta_p < zas_settings.airflow_mob_pressure)
				return FALSE
	return ..()

///The typecache of objects airflow can't push objects into the same tile of
GLOBAL_LIST_INIT(airflow_step_blacklist, typecacheof(list(
	/obj/structure,
	/obj/machinery/door
	)))

/// Called when a movable Bump()s another atom due to forced airflow movement.
/atom/movable/proc/AirflowBump(atom/A)
	var/turf/T = get_turf(A)
	if(airborne_acceleration > 1)
		airflow_hit(A)
		A.airflow_hit_act(src)

	else if(istype(src, /mob/living/carbon/human) && A.density)
		var/mob/living/carbon/human/human_src = src
		to_chat(human_src, span_warning("You are pinned against \the [A] by airflow.</span>"))
		human_src.Stun(2 SECONDS) // :)
		SSairflow.Dequeue(src)
		return
	/*
	If the turf of the atom we bumped is NOT dense, then we check if the flying object is dense.
	We check the special var because flying objects gain density so they can Bump() objects.
	If the object is NOT normally dense, we remove our density and the target's density,
	enabling us to step into their turf. Then, we set the density back to the way its supposed to be for airflow.
	*/
	if(!T.density && ismovable(A) && !(GLOB.airflow_step_blacklist[A.type]))
		var/atom/movable/bumped_movable = A
		if(bumped_movable.airflow_old_density)
			return

		set_density(FALSE)
		bumped_movable.set_density(FALSE)
		step_towards(src, airflow_dest)
		set_density(TRUE)
		bumped_movable.set_density(TRUE)


///Called when src collides with A during airflow
/atom/movable/proc/airflow_hit(atom/A)
	SHOULD_CALL_PARENT(TRUE)
	SSairflow.Dequeue(src)

/mob/living/airflow_hit(atom/A)
	var/b_loss = AIRBORNE_DAMAGE(src)
	apply_damage(b_loss, BRUTE)
	return ..()

/mob/living/carbon/airflow_hit(atom/A)
	if(!(istype(A, /obj/structure) || iswallturf(A)))
		return ..()

	if(airflow_speed > 10)
		Paralyze(round(airflow_speed * zas_settings.airflow_stun))
		Stun(round(airflow_speed * zas_settings.airflow_stun) + 3)
		loc.add_blood_DNA(return_blood_DNA())
		visible_message(
			span_danger("[src] splats against \the [A]!"),
			span_userdanger("You slam into \the [A] with tremendous force!"),
			span_hear("You hear a loud thud.")
		)
		INVOKE_ASYNC(emote("scream"))
	else
		Stun(round(airflow_speed * zas_settings.airflow_stun/2))
		visible_message(
			span_danger("[src] slams into \the [A]!"),
			span_userdanger("You're thrown against \the [A] by pressure!"),
			span_hear("You hear a loud thud.")
		)

	return ..()

///Called when "flying" calls airflow_hit() on src
/atom/proc/airflow_hit_act(atom/movable/flying)
	return

/mob/living/airflow_hit_act(atom/movable/flying)
	. = ..()
	visible_message(
		span_danger("A flying [flying.name] slams into \the [src]!"),
		blind_message = span_danger("You hear a soft thud.")
	)

	playsound(loc, "punch", 25, 1, -1)
	var/weak_amt
	if(istype(flying,/obj/item))
		weak_amt = flying:w_class*2 ///Heheheh
	else if(flying.airflow_old_density) //If the object is dense by default (this var is stupidly named)
		weak_amt = 5 //Getting crushed by a flying canister or computer is going to fuck you up
	else
		weak_amt = rand(1, 3)

	Knockdown(weak_amt SECONDS)

/obj/airflow_hit_act(atom/movable/flying)
	. = ..()
	if(flying.airflow_old_density)
		visible_message(
			span_danger("A flying [flying.name] slams into \the [src]!"),
			null,
			span_danger("You hear a loud slam!")
		)

	playsound(loc, "smash.ogg", 25, 1, -1)

	if(!uses_integrity)
		return

	take_damage(zas_settings.airflow_damage, BRUTE)

/mob/living/carbon/human/airflow_hit_act(atom/movable/flying)
	. = ..()

	if (prob(33))
		loc.add_blood_DNA(return_blood_DNA())

	var/b_loss = AIRBORNE_DAMAGE(flying)

	apply_damage(b_loss/3, BRUTE, BODY_ZONE_HEAD)

	apply_damage(b_loss/3, BRUTE, BODY_ZONE_CHEST)


	if(airflow_speed > 10)
		Paralyze(round(flying.airflow_speed * zas_settings.airflow_stun))
		Stun(round(flying.airflow_speed * zas_settings.airflow_stun) + 3)
	else
		Stun(round(flying.airflow_speed * zas_settings.airflow_stun/2))

/zone/proc/movables()
	RETURN_TYPE(/list)
	. = list()
	for(var/turf/T as anything in contents)
		for(var/atom/movable/A as anything in T)
			if(!A.simulated || A.anchored)
				continue
			. += A

/atom/movable/proc/prepare_airflow(strength)
	if (!airflow_dest || airflow_dest == loc) // This should no longer happen, but just in case, ignore it.
		return FALSE

	COOLDOWN_START(src, airflow_push_cooldown, zas_settings.airflow_retrigger_delay)

	var/airflow_falloff = 9 - get_dist_euclidean(loc, airflow_dest)
	if (airflow_falloff < 1)
		return FALSE

	airflow_speed = clamp(strength * (9 / airflow_falloff), 1, 9)
	return TRUE

/mob/prepare_airflow(strength)
	. = ..()
	if(!.)
		return

	to_chat(src, span_warning("A strong air current drags you away."))

/atom/movable/proc/GotoAirflowDest(strength)
	if (!prepare_airflow(strength))
		airflow_dest = null
		return
	airflow_xo = airflow_dest.x - x
	airflow_yo = airflow_dest.y - y
	airflow_dest = null
	SSairflow.Enqueue(src)

/atom/movable/proc/RepelAirflowDest(strength)
	if (!prepare_airflow(strength))
		airflow_dest = null
		return
	airflow_xo = -(airflow_dest.x - x)
	airflow_yo = -(airflow_dest.y - y)
	airflow_dest = null
	SSairflow.Enqueue(src)

#undef AIRBORNE_DAMAGE
