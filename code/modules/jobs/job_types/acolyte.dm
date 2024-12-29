/datum/job/acolyte
	title = JOB_ACOLYTE
	description = "Save lives, run around the station looking for victims, \
		scan everyone in sight"
	department_head = list(JOB_AUGUR)
	faction = FACTION_STATION
	total_positions = 5
	spawn_positions = 3
	supervisors = "the medical director"
	selection_color = "#013d3b"
	exp_granted_type = EXP_TYPE_CREW

	employers = list(
		/datum/employer/aether,
	)

	outfits = list(
		"Default" = list(
			SPECIES_HUMAN = /datum/outfit/job/doctor,
			SPECIES_PLASMAMAN = /datum/outfit/job/doctor/plasmaman,
		),
	)

	paycheck = PAYCHECK_MEDIUM
	paycheck_department = ACCOUNT_MED

	liver_traits = list(TRAIT_MEDICAL_METABOLISM)

	departments_list = list(
		/datum/job_department/medical,
		)

	family_heirlooms = list(/obj/item/storage/medkit/ancient/heirloom)

	mail_goodies = list(
		/obj/item/scalpel/advanced = 6,
		/obj/item/retractor/advanced = 6,
		/obj/item/cautery/advanced = 6,
		/obj/item/reagent_containers/glass/bottle/space_cleaner = 6,
		/obj/effect/spawner/random/medical/organs = 5,
		/obj/effect/spawner/random/medical/memeorgans = 1
	)
	rpg_title = "Cleric"
	job_flags = JOB_ANNOUNCE_ARRIVAL | JOB_CREW_MANIFEST | JOB_EQUIP_RANK | JOB_CREW_MEMBER | JOB_NEW_PLAYER_JOINABLE | JOB_REOPEN_ON_ROUNDSTART_LOSS | JOB_ASSIGN_QUIRKS | JOB_CAN_BE_INTERN


/datum/outfit/job/doctor
	name = JOB_ACOLYTE
	jobtype = /datum/job/acolyte

	id_trim = /datum/id_trim/job/medical_doctor
	uniform = /obj/item/clothing/under/rank/medical/doctor
	suit = /obj/item/clothing/suit/toggle/labcoat/md
	suit_store = /obj/item/flashlight/pen
	belt = /obj/item/pager/aether
	ears = /obj/item/radio/headset/headset_med
	shoes = /obj/item/clothing/shoes/sneakers/white
	l_hand = /obj/item/storage/medkit/surgery

	backpack = /obj/item/storage/backpack/medic
	satchel = /obj/item/storage/backpack/satchel/med
	duffelbag = /obj/item/storage/backpack/duffelbag/med

	box = /obj/item/storage/box/survival/medical
	chameleon_extras = /obj/item/gun/syringe

/datum/outfit/job/doctor/plasmaman
	name = JOB_ACOLYTE + " (Plasmaman)"

	uniform = /obj/item/clothing/under/plasmaman/medical
	gloves = /obj/item/clothing/gloves/color/plasmaman/white
	head = /obj/item/clothing/head/helmet/space/plasmaman/medical
	mask = /obj/item/clothing/mask/breath
	r_hand = /obj/item/tank/internals/plasmaman/belt/full

/datum/outfit/job/doctor/mod
	name = JOB_ACOLYTE + " (MODsuit)"

	suit_store = /obj/item/tank/internals/oxygen
	back = /obj/item/mod/control/pre_equipped/medical
	suit = null
	mask = /obj/item/clothing/mask/breath/medical
	r_pocket = /obj/item/flashlight/pen
	internals_slot = ITEM_SLOT_SUITSTORE
	backpack_contents = null
	box = null
