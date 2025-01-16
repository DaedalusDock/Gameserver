/datum/action/cooldown/blood_track
	name = "Blood Hunt"
	desc = "Find your last victim."
	button_icon = 'goon/icons/actions.dmi'
	button_icon_state = "blood_static"

	cooldown_time = 60 SECONDS

	var/image/pointer

/datum/action/cooldown/blood_track/Remove(mob/removed_from)
	. = ..()
	if(pointer)
		remove_image(removed_from, now = TRUE)

/datum/action/cooldown/blood_track/IsAvailable(feedback)
	. = ..()
	if(!.)
		return

	var/datum/antagonist/vampire/vamp_datum = owner.mind.has_antag_datum(/datum/antagonist/vampire)
	return !!vamp_datum.last_victim_ref

/datum/action/cooldown/blood_track/Activate(atom/target)
	var/mob/living/carbon/human/human_owner = owner
	if(human_owner.internal || human_owner.external)
		to_chat(owner, span_warning("You are unable to catch a scent while wearing [human_owner.internal || human_owner.external]."))
		return

	var/turf/T = get_turf(owner)
	if(T.is_below_sound_pressure())
		to_chat(owner, span_notice("You are unable to catch a scent here."))
		return

	. = ..()

	var/datum/antagonist/vampire/vamp_datum = owner.mind.has_antag_datum(/datum/antagonist/vampire)
	var/mob/living/carbon/human/victim = vamp_datum.last_victim_ref.resolve()
	var/turf/victim_turf = get_turf(victim)
	var/turf/owner_turf = get_turf(owner)

	if(isnull(victim) || owner_turf.z != victim_turf.z)
		to_chat(owner, span_warning("Your target is too far away to locate."))
		return

	owner.emote("sniff")

	pointer = pointer_image_to(owner, victim_turf)
	owner.client?.images += pointer

	addtimer(CALLBACK(src, PROC_REF(remove_image), owner), 4 SECONDS)

/datum/action/cooldown/blood_track/proc/remove_image(mob/remove_from, now = FALSE)
	set waitfor = FALSE

	if(!now)
		animate(pointer, alpha = 0, time = 2 SECONDS)
		sleep(2 SECONDS)

	remove_from.client?.images -= pointer
	pointer = null
