
/obj/item/clothing/gloves/cargo_gauntlet
	name = "\improper H.A.U.L. gauntlets"
	desc = "These clunky gauntlets allow you to drag things with more confidence on them not getting nabbed from you."
	icon_state = "haul_gauntlet"
	inhand_icon_state = "bgloves"
	equip_delay_self = 3 SECONDS
	equip_delay_other = 4 SECONDS
	clothing_traits = list(TRAIT_CHUNKYFINGERS)
	undyeable = TRUE
	var/datum/weakref/pull_component_weakref

/obj/item/clothing/gloves/cargo_gauntlet/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_ITEM_EQUIPPED, PROC_REF(on_glove_equip))
	RegisterSignal(src, COMSIG_ITEM_POST_UNEQUIP, PROC_REF(on_glove_unequip))

/// Called when the glove is equipped. Adds a component to the equipper and stores a weak reference to it.
/obj/item/clothing/gloves/cargo_gauntlet/proc/on_glove_equip(datum/source, mob/equipper, slot)
	SIGNAL_HANDLER

	if(slot != ITEM_SLOT_GLOVES)
		return

	var/datum/component/strong_pull/pull_component = pull_component_weakref?.resolve()
	if(pull_component)
		stack_trace("Gloves already have a pull component associated with \[[pull_component.parent]\] when \[[equipper]\] is trying to equip them.")
		QDEL_NULL(pull_component_weakref)

	to_chat(equipper, span_notice("You feel the gauntlets activate as soon as you fit them on, making your pulls stronger!"))

	pull_component_weakref = WEAKREF(equipper.AddComponent(/datum/component/strong_pull))

/*
 * Called when the glove is unequipped. Deletes the component if one exists.
 *
 * No component being associated on equip is a valid state, as holding the gloves in your hands also counts
 * as having them equipped, or even in pockets. They only give the component when they're worn on the hands.
 */
/obj/item/clothing/gloves/cargo_gauntlet/proc/on_glove_unequip(datum/source, force, atom/newloc, no_move, invdrop, silent)
	SIGNAL_HANDLER

	var/datum/component/strong_pull/pull_component = pull_component_weakref?.resolve()

	if(!pull_component)
		return

	to_chat(pull_component.parent, span_warning("You have lost the grip power of [src]!"))

	QDEL_NULL(pull_component_weakref)

/obj/item/clothing/gloves/rapid
	name = "Gloves of the North Star"
	desc = "Just looking at these fills you with an urge to beat the shit out of people."
	icon_state = "rapid"
	inhand_icon_state = "rapid"
	clothing_traits = list(TRAIT_FINGERPRINT_PASSTHROUGH)

/obj/item/clothing/gloves/rapid/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/wearertargeting/punchcooldown)

/obj/item/clothing/gloves/radio
	name = "translation gloves"
	desc = "A pair of electronic gloves which connect to nearby radios wirelessly. Allows for sign language users to 'speak' over comms."
	icon_state = "radio_g"
	inhand_icon_state = "radio_g"
	clothing_traits = list(TRAIT_CAN_SIGN_ON_COMMS)

/obj/item/clothing/gloves/race
	name = "race gloves"
	desc = "Extremely finely made gloves meant for use by sportsmen in speed-shooting competitions."
	clothing_traits = list(TRAIT_DOUBLE_TAP)
	icon_state = "black"
	inhand_icon_state = "blackgloves"

/obj/item/clothing/gloves/forensic
	name = "forensic gloves"
	desc = "Specially made gloves with a distinct luminescent threading."
	inhand_icon_state = "black"
	icon_state = "forensic"
	worn_icon_state = "black"

	siemens_coefficient = 0.5
	permeability_coefficient = 0.05

	heat_protection = HANDS
	cold_protection = HANDS

	min_cold_protection_temperature = GLOVES_MIN_TEMP_PROTECT
	max_heat_protection_temperature = GLOVES_MAX_TEMP_PROTECT
