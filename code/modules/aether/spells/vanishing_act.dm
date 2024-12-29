/datum/action/cooldown/spell/vanishing_act
	name = "Vanishing Act"
	desc = "Conjure a dense cloud that leeches blood from those caught within it. Costs Blood to use."
	button_icon_state = "smoke"

	sound = 'sound/magic/enter_blood.ogg'

	invocation = "KASSHEREV HINTZA!"
	invocation_type = INVOCATION_SHOUT
	school = SCHOOL_BLOOD
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC|SPELL_REQUIRES_HUMAN|SPELL_CASTABLE_WITHOUT_INVOCATION

	cooldown_time = 10 MINUTES

	smoke_type = /datum/effect_system/fluid_spread/smoke/bad/blood
	smoke_amt = 4

/datum/action/cooldown/spell/vanishing_act/cast(atom/cast_on)
	. = ..()
	var/mob/living/carbon/human/caster = cast_on
	caster.adjustBloodVolume(-80)

	for(var/turf/T in RANGE_TURFS(2, caster))
		if(prob(75))
			caster.add_splatter_floor(T)

	to_chat(caster, span_statsbad("Blood rushes outwards from your skin, taking to the air and leaving you feeling drained."))
