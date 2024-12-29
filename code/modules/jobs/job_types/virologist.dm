/datum/job/virologist
	title = JOB_VIROLOGIST
	description = "Study the effects of various diseases and synthesize a \
		vaccine for them. Engineer beneficial viruses."
	department_head = list(JOB_AUGUR)
	faction = FACTION_STATION
	total_positions = 1
	spawn_positions = 1
	supervisors = "the medical director"
	selection_color = "#013d3b"
	exp_requirements = 60
	exp_required_type = EXP_TYPE_CREW
	exp_granted_type = EXP_TYPE_CREW

	employers = list(
		/datum/employer/aether,
	)

	outfits = list(
		"Default" = list(
			SPECIES_HUMAN = /datum/outfit/job/virologist,
			SPECIES_PLASMAMAN = /datum/outfit/job/virologist/plasmaman,
		),
	)

	paycheck = PAYCHECK_MEDIUM
	paycheck_department = ACCOUNT_MED

	liver_traits = list(TRAIT_MEDICAL_METABOLISM)

	departments_list = list(
		/datum/job_department/medical,
		)

	family_heirlooms = list(/obj/item/reagent_containers/syringe)

	mail_goodies = list(
		/obj/item/reagent_containers/glass/bottle/random_virus = 15,
		/obj/item/reagent_containers/glass/bottle/space_cleaner = 10,
		/obj/item/reagent_containers/glass/bottle/synaptizine = 10,
		/obj/item/stack/sheet/mineral/plasma = 10,
		/obj/item/stack/sheet/mineral/uranium = 5,
	)
	rpg_title = "Plague Doctor"
	job_flags = JOB_ANNOUNCE_ARRIVAL | JOB_CREW_MANIFEST | JOB_EQUIP_RANK | JOB_CREW_MEMBER | JOB_NEW_PLAYER_JOINABLE | JOB_REOPEN_ON_ROUNDSTART_LOSS | JOB_ASSIGN_QUIRKS | JOB_CAN_BE_INTERN


/datum/outfit/job/virologist
	name = "Virologist"
	jobtype = /datum/job/virologist

	id_trim = /datum/id_trim/job/virologist
	uniform = /obj/item/clothing/under/rank/medical/virologist
	suit = /obj/item/clothing/suit/toggle/labcoat/virologist
	suit_store = /obj/item/flashlight/pen
	belt = /obj/item/modular_computer/tablet/pda/viro
	ears = /obj/item/radio/headset/headset_med
	mask = /obj/item/clothing/mask/surgical
	shoes = /obj/item/clothing/shoes/sneakers/white

	backpack = /obj/item/storage/backpack/virology
	satchel = /obj/item/storage/backpack/satchel/vir
	duffelbag = /obj/item/storage/backpack/duffelbag/virology

	box = /obj/item/storage/box/survival/medical

/datum/outfit/job/virologist/plasmaman
	name = "Virologist (Plasmaman)"

	uniform = /obj/item/clothing/under/plasmaman/viro
	gloves = /obj/item/clothing/gloves/color/plasmaman/white
	head = /obj/item/clothing/head/helmet/space/plasmaman/viro
	mask = /obj/item/clothing/mask/breath
	r_hand = /obj/item/tank/internals/plasmaman/belt/full
