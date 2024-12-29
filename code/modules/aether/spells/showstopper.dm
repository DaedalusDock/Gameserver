/datum/action/cooldown/spell/touch/showstopper
	name = "Showstopper"
	desc = "Drain the beating energy of one's heart, taking it for yourself."
	button_icon_state = "arcane_barrage"

	sound = 'sound/magic/exit_blood.ogg'

	invocation = "Kasyah shach hala"
	invocation_type = INVOCATION_WHISPER
	school = SCHOOL_BLOOD
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC|SPELL_REQUIRES_HUMAN|SPELL_CASTABLE_WITHOUT_INVOCATION

	cooldown_time = 10 MINUTES

	hand_path = /obj/item/melee/touch_attack/showstopper


/datum/action/cooldown/spell/touch/showstopper/cast_on_hand_hit(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	if(!ishuman(victim))
		return FALSE

	var/mob/living/carbon/human/badguy = victim
	if(!badguy.needs_organ(ORGAN_SLOT_HEART))
		return FALSE

	if(badguy.undergoing_cardiac_arrest())
		return FALSE

	badguy.set_heartattack(TRUE)
	caster.adjustBloodVolume(50)

	if(isturf(badguy.loc))
		badguy.add_splatter_floor(badguy.loc)

	return TRUE

/obj/item/melee/touch_attack/showstopper
	name = "\improper ominous energy"
	desc = "Their hand glows with ominous energy"
	icon_state = "disintegrate"
	inhand_icon_state = "disintegrate"
