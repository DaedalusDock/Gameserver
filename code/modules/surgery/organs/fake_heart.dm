/obj/item/organ/heart/fake
	name = "perennial heart"
	desc = "A symbollic heart made out of wood. To be placed inside those who have been laid to rest in the great pool."
	icon_state = "heart-on"
	base_icon_state = "heart"

	cosmetic_only = TRUE
	relative_size = 0

	organ_flags = ORGAN_DEAD | ORGAN_SYNTHETIC
	maxHealth = 1

/obj/item/organ/heart/fake/is_working()
	return FALSE

/obj/item/organ/heart/fake/set_organ_dead(failing, cause_of_death)
	return FALSE
