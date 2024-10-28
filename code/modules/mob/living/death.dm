/**
 * Blow up the mob into giblets
 *
 * Arguments:
 * * no_brain - Should the mob NOT drop a brain?
 * * no_organs - Should the mob NOT drop organs?
 * * no_bodyparts - Should the mob NOT drop bodyparts?
*/
/mob/living/proc/gib(no_brain, no_organs, no_bodyparts)
	var/prev_lying = lying_angle
	if(stat != DEAD)
		death(TRUE)

	if(!prev_lying)
		gib_animation()

	spill_organs(no_brain, no_organs, no_bodyparts)

	if(!no_bodyparts)
		spread_bodyparts(no_brain, no_organs)

	spawn_gibs(no_bodyparts)
	qdel(src)

/mob/living/proc/gib_animation()
	return

/mob/living/proc/spawn_gibs()
	new /obj/effect/gibspawner/generic(drop_location(), src, get_static_viruses())

/mob/living/proc/spill_organs()
	return

/mob/living/proc/spread_bodyparts()
	return

/**
 * This is the proc for turning a mob into ash.
 * Dusting robots does not eject the MMI, so it's a bit more powerful than gib()
 *
 * Arguments:
 * * just_ash - If TRUE, ash will spawn where the mob was, as opposed to remains
 * * drop_items - Should the mob drop their items before dusting?
 * * force - Should this mob be FORCABLY dusted?
*/
/mob/living/proc/dust(just_ash, drop_items, force)
	death(TRUE)

	if(drop_items)
		unequip_everything()

	if(buckled)
		buckled.unbuckle_mob(src, force = TRUE)

	dust_animation()
	spawn_dust(just_ash)
	QDEL_IN(src,5) // since this is sometimes called in the middle of movement, allow half a second for movement to finish, ghosting to happen and animation to play. Looks much nicer and doesn't cause multiple runtimes.

/mob/living/proc/dust_animation()
	return

/mob/living/proc/spawn_dust(just_ash = FALSE)
	new /obj/effect/decal/cleanable/ash(loc)

/*
 * Called when the mob dies. Can also be called manually to kill a mob.
 *
 * Arguments:
 * * gibbed - Was the mob gibbed?
 * * cod (cause of death) - A string that plainly describes how the mob died.
*/
/mob/living/proc/death(gibbed, cause_of_death = "Unknown")
	set_stat(DEAD)
	unset_machine()

	died_as_name = name
	timeofdeath = world.time
	timeofdeath_as_ingame = stationtime2text()

	// tgchat displays doc strings with formatting, so we do stupid shit instead
	var/list/death_message = list(
		"<div style='text-align:center'><i>[span_statsbad("<span style='font-size: 300%;font-style: normal'>You Died</span>")]</i></div>",
		"<div style='text-align:center'><i>[span_statsbad("<span style='font-size: 200%;font-style: normal'>Cause of Death: [cause_of_death]</span>")]</i></div>",
		"<hr>",
		span_obviousnotice("Your story may not be over yet. You are able to be resuscitated as long as your brain was not destroyed, and you have not been dead for 10 minutes."),
	)

	if(ishuman(src))
		death_message.Insert(3, "<div style='text-align:center'><i>[button_element(src, "Click here to see stats", "show_death_stats=1")]</i></div>")
		var/mob/living/carbon/human/H = src
		H.time_of_death_stats = H.get_bodyscanner_data()

	death_message = examine_block(jointext(death_message, ""))
	to_chat(src, death_message)

	playsound_local(src, 'goon/sounds/revfocus.ogg', 50, vary = FALSE, pressure_affected = FALSE)

	var/turf/T = get_turf(src)

	if(mind && mind.name && mind.active)
		if(!istype(T.loc, /area/centcom/ctf))
			deadchat_broadcast(" has died at <b>[get_area_name(T)]</b>.", "<b>[mind.name]</b>", follow_target = src, turf_target = T, message_type=DEADCHAT_DEATHRATTLE)

		if(SSlag_switch.measures[DISABLE_DEAD_KEYLOOP] && !client?.holder)
			to_chat(src, span_deadsay(span_big("Observer freelook is disabled.\nPlease use Orbit, Teleport, and Jump to look around.")))
			ghostize(TRUE)

	set_disgust(0)
	SetSleeping(0, 0)

	reset_perspective(null)
	reload_fullscreen()
	update_mob_action_buttons()
	update_damage_hud()
	update_health_hud()
	update_med_hud()

	release_all_grabs()

	set_typing_indicator(FALSE)

	SEND_SIGNAL(src, COMSIG_LIVING_DEATH, gibbed)
	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_MOB_DEATH, src, gibbed)

	if (client)
		client.move_delay = initial(client.move_delay)

	if(!gibbed)
		AddComponent(/datum/component/spook_factor, SPOOK_AMT_CORPSE)
	return TRUE
