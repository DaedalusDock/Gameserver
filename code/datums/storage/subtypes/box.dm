/datum/storage/box
	open_sound = 'sound/storage/box.ogg'

/datum/storage/box/syringe
	max_slots = 9

/datum/storage/box/syringe/New(atom/parent, max_slots, max_specific_storage, max_total_storage, numerical_stacking, allow_quick_gather, allow_quick_empty, collection_mode, attack_hand_interact)
	. = ..()
	set_holdable(list(
		/obj/item/reagent_containers/syringe,
		/obj/item/reagent_containers/hypospray,
		/obj/item/pen,
	))
