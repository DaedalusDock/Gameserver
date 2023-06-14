/datum/loadout_item/mask
	category = LOADOUT_CATEGORY_MASK

/datum/loadout_item/mask/insert_path_into_outfit(datum/outfit/outfit, mob/living/carbon/human/equipper, visuals_only = FALSE)
	. = outfit.mask
	outfit.mask = path


//MISC
/datum/loadout_item/mask/balaclava
	path = /obj/item/clothing/mask/balaclava

/datum/loadout_item/mask/moustache
	path = /obj/item/clothing/mask/fakemoustache

/datum/loadout_item/mask/italianmoustache
	path = /obj/item/clothing/mask/fakemoustache/italian

/datum/loadout_item/mask/bandana_red
	path = /obj/item/clothing/mask/bandana/red

/datum/loadout_item/mask/bandana_blue
	path = /obj/item/clothing/mask/bandana/blue

/datum/loadout_item/mask/bandana_green
	path = /obj/item/clothing/mask/bandana/green

/datum/loadout_item/mask/bandana_gold
	path = /obj/item/clothing/mask/bandana/gold

/datum/loadout_item/mask/bandana_black
	path = /obj/item/clothing/mask/bandana/black

/datum/loadout_item/mask/bandana_skull
	path = /obj/item/clothing/mask/bandana/skull

/datum/loadout_item/mask/breath_mask
	path = /obj/item/clothing/mask/breath

/datum/loadout_item/mask/breath_mask_vox
	path = /obj/item/clothing/mask/breath/vox
/datum/loadout_item/mask/security_hailer
	path = /obj/item/clothing/mask/gas/sechailer
	restricted_roles = list(JOB_SECURITY_OFFICER,JOB_HEAD_OF_SECURITY,JOB_WARDEN)
	customization_flags = CUSTOMIZE_NAME_DESC //has no parts to recolor

