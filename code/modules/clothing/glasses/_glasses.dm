//Glasses
/obj/item/clothing/glasses
	name = "glasses"
	icon = 'icons/obj/clothing/glasses.dmi'
	fallback_colors = list(list(15, 26), list(18, 26))
	fallback_icon_state = "glasses"
	w_class = WEIGHT_CLASS_SMALL
	flags_cover = GLASSESCOVERSEYES
	slot_flags = ITEM_SLOT_EYES
	strip_delay = 20
	equip_delay_other = 25
	resistance_flags = NONE
	custom_materials = list(/datum/material/glass = 250)
	gender = PLURAL
	supports_variations_flags = CLOTHING_VOX_VARIATION

	var/vision_flags = 0
	var/darkness_view = 2 // Base human is 2
	var/invis_view = SEE_INVISIBLE_LIVING // Admin only for now
	/// Override to allow glasses to set higher than normal see_invis
	var/invis_override = 0
	var/lighting_alpha
	/// The current hud icons
	var/list/icon/current = list()
	/// Does wearing these glasses correct some of our vision defects?
	var/vision_correction = FALSE
	/// Colors your vision when worn
	var/glass_colour_type
	/// Whether or not vision coloring is forcing
	var/forced_glass_color = FALSE
	/// Having this default to false means that its easy to make sure this doesnt apply to any pre-existing items.
	var/can_switch_eye = FALSE
	/// Added to the end of the icon_state to make this easy code-wise, L and R being the wearer's Left and Right.
	var/current_eye = "_R"

/obj/item/clothing/glasses/Initialize()
	. = ..()
	if(!can_switch_eye)	//Just runs the normal code for any item that we havent manually set this as TRUE for
		return
	icon_state += current_eye	//Makes sure the icon initially ends in _R so its a valid sprite (Change current_eye in loadout once thats possible to spawn it on the side of your choice)

/obj/item/clothing/glasses/verb/eyepatch_switcheye()
	set name = "Switch Eyepatch Side"
	set category = null
	set src in usr
	switcheye()

/obj/item/clothing/glasses/proc/switcheye()
	if(!can_use(usr))
		return
	if(!can_switch_eye)
		to_chat(usr, span_warning("You cannot wear this any differently!"))
		return
	eyepatch_do_switch()
	if(current_eye == "_L")
		to_chat(usr, span_notice("You adjust the eyepatch to wear it over your left eye."))
	else if(current_eye == "_R")
		to_chat(usr, span_notice("You adjust the eyepatch to wear it over your right eye."))
	usr.update_inv_glasses()
	usr.update_overlays()

/obj/item/clothing/glasses/proc/eyepatch_do_switch()
	if(current_eye == "_L")
		current_eye = "_R"
	else if(current_eye == "_R")
		current_eye = "_L"
	src.icon_state = "[initial(icon_state)]"+ current_eye

/obj/item/clothing/glasses/suicide_act(mob/living/carbon/user)
	user.visible_message(span_suicide("[user] is stabbing \the [src] into [user.p_their()] eyes! It looks like [user.p_theyre()] trying to commit suicide!"))
	return BRUTELOSS

/obj/item/clothing/glasses/examine(mob/user)
	. = ..()
	if(glass_colour_type && !forced_glass_color && ishuman(user))
		. += span_notice("Alt-click to toggle [p_their()] colors.")
	if(can_switch_eye)
		if(current_eye == "_L")
			. += "Ctrl-click on [src] to wear it over your right eye."
		else
			. += "Ctrl-click on [src] to wear it over your left eye."

/obj/item/clothing/glasses/visor_toggling()
	..()
	if(visor_vars_to_toggle & VISOR_VISIONFLAGS)
		vision_flags ^= initial(vision_flags)
	if(visor_vars_to_toggle & VISOR_DARKNESSVIEW)
		darkness_view ^= initial(darkness_view)
	if(visor_vars_to_toggle & VISOR_INVISVIEW)
		invis_view ^= initial(invis_view)

/obj/item/clothing/glasses/weldingvisortoggle(mob/user)
	. = ..()
	alternate_worn_layer = up ? ABOVE_BODY_FRONT_HEAD_LAYER : null
	if(. && user)
		user.update_sight()
		if(iscarbon(user))
			var/mob/living/carbon/carbon_user = user
			carbon_user.head_update(src, forced = TRUE)

//called when thermal glasses are emped.
/obj/item/clothing/glasses/proc/thermal_overload()
	if(ishuman(src.loc))
		var/mob/living/carbon/human/H = src.loc
		var/obj/item/organ/eyes/eyes = H.getorganslot(ORGAN_SLOT_EYES)
		if(!H.is_blind())
			if(H.glasses == src)
				to_chat(H, span_danger("[src] overloads and blinds you!"))
				H.flash_act(visual = 1)
				H.blind_eyes(3)
				H.blur_eyes(5)
				eyes.applyOrganDamage(5)

/obj/item/clothing/glasses/CtrlClick(mob/user)
	. = ..()
	if(.)
		return
	if(!user.canUseTopic(src, BE_CLOSE, NO_DEXTERITY, FALSE, !iscyborg(user)))
		return
	else
		switcheye()

/obj/item/clothing/glasses/AltClick(mob/user)
	if(glass_colour_type && !forced_glass_color && ishuman(user))
		var/mob/living/carbon/human/human_user = user

		if (human_user.glasses != src)
			return ..()

		if (HAS_TRAIT_FROM(human_user, TRAIT_SEE_GLASS_COLORS, GLASSES_TRAIT))
			REMOVE_TRAIT(human_user, TRAIT_SEE_GLASS_COLORS, GLASSES_TRAIT)
			to_chat(human_user, span_notice("You will no longer see glasses colors."))
		else
			ADD_TRAIT(human_user, TRAIT_SEE_GLASS_COLORS, GLASSES_TRAIT)
			to_chat(human_user, span_notice("You will now see glasses colors."))
		human_user.update_glasses_color(src, TRUE)
	else
		return ..()

/obj/item/clothing/glasses/proc/change_glass_color(mob/living/carbon/human/H, datum/client_colour/glass_colour/new_color_type)
	var/old_colour_type = glass_colour_type
	if(!new_color_type || ispath(new_color_type)) //the new glass colour type must be null or a path.
		glass_colour_type = new_color_type
		if(H && H.glasses == src)
			if(old_colour_type)
				H.remove_client_colour(old_colour_type)
			if(glass_colour_type)
				H.update_glasses_color(src, 1)


/mob/living/carbon/human/proc/update_glasses_color(obj/item/clothing/glasses/G, glasses_equipped)
	if((HAS_TRAIT(src, TRAIT_SEE_GLASS_COLORS) || G.forced_glass_color) && glasses_equipped)
		add_client_colour(G.glass_colour_type)
	else
		remove_client_colour(G.glass_colour_type)


/obj/item/clothing/glasses/meson
	name = "optical meson scanner"
	desc = "Used by engineering and mining staff to see basic structural and terrain layouts through walls, regardless of lighting conditions."
	icon_state = "meson"
	inhand_icon_state = "meson"
	clothing_traits = list(TRAIT_SUPERMATTER_MADNESS_IMMUNE)
	darkness_view = 2
	vision_flags = SEE_TURFS
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE
	glass_colour_type = /datum/client_colour/glass_colour/lightgreen
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/meson/suicide_act(mob/living/carbon/user)
	user.visible_message(span_suicide("[user] is putting \the [src] to [user.p_their()] eyes and overloading the brightness! It looks like [user.p_theyre()] trying to commit suicide!"))
	return BRUTELOSS

/obj/item/clothing/glasses/meson/night
	name = "night vision meson scanner"
	desc = "An optical meson scanner fitted with an amplified visible light spectrum overlay, providing greater visual clarity in darkness."
	icon_state = "nvgmeson"
	inhand_icon_state = "nvgmeson"
	darkness_view = 8
	flash_protect = FLASH_PROTECTION_SENSITIVE
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE
	glass_colour_type = /datum/client_colour/glass_colour/green
	supports_variations_flags = NONE

/obj/item/clothing/glasses/meson/gar
	name = "gar mesons"
	desc = "Do the impossible, see the invisible!"
	icon_state = "gar_meson"
	inhand_icon_state = "gar_meson"
	alternate_worn_layer = ABOVE_BODY_FRONT_HEAD_LAYER
	force = 10
	throwforce = 10
	throw_speed = 4
	attack_verb_continuous = list("slices")
	attack_verb_simple = list("slice")
	hitsound = 'sound/weapons/bladeslice.ogg'
	sharpness = SHARP_EDGED
	supports_variations_flags = NONE

/obj/item/clothing/glasses/science
	name = "science goggles"
	desc = "A pair of snazzy goggles used to protect against chemical spills. Fitted with an analyzer for scanning items and reagents."
	icon_state = "purple"
	inhand_icon_state = "glasses"
	glass_colour_type = /datum/client_colour/glass_colour/purple
	resistance_flags = ACID_PROOF
	armor = list(MELEE = 0, BULLET = 0, LASER = 0, ENERGY = 0, BOMB = 0, BIO = 0, FIRE = 80, ACID = 100)
	clothing_traits = list(TRAIT_REAGENT_SCANNER, TRAIT_RESEARCH_SCANNER)
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/science/item_action_slot_check(slot)
	if(slot == ITEM_SLOT_EYES)
		return 1

/obj/item/clothing/glasses/science/suicide_act(mob/living/carbon/user)
	user.visible_message(span_suicide("[user] is tightening \the [src]'s straps around [user.p_their()] neck! It looks like [user.p_theyre()] trying to commit suicide!"))
	return OXYLOSS

/obj/item/clothing/glasses/science/night
	name = "night vision science goggles"
	desc = "Lets the user see in the dark and recognize chemical compounds at a glance."
	icon_state = "scihudnight"
	darkness_view = 8
	flash_protect = FLASH_PROTECTION_SENSITIVE
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE
	glass_colour_type = /datum/client_colour/glass_colour/green
	supports_variations_flags = NONE

/obj/item/clothing/glasses/night
	name = "night vision goggles"
	desc = "You can totally see in the dark now!"
	icon_state = "night"
	inhand_icon_state = "glasses"
	darkness_view = 8
	flash_protect = FLASH_PROTECTION_SENSITIVE
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE
	glass_colour_type = /datum/client_colour/glass_colour/green
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/eyepatch
	name = "eyepatch"
	desc = "Yarr."
	icon_state = "eyepatch"
	inhand_icon_state = "eyepatch"
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION
	can_switch_eye = TRUE

/obj/item/clothing/glasses/eyepatch/wrap
	name = "eye wrap"
	desc = "A glorified bandage. At least this one's actually made for your head..."
	icon_state = "eyewrap"
	supports_variations_flags = NONE

/obj/item/clothing/glasses/eyepatch/white
	name = "white eyepatch"
	desc = "This is what happens when a pirate gets a PhD."
	icon_state = "eyepatch_white"
	supports_variations_flags = NONE

/obj/item/clothing/glasses/monocle
	name = "monocle"
	desc = "Such a dapper eyepiece!"
	icon_state = "monocle"
	inhand_icon_state = "headset" // lol
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/material
	name = "optical material scanner"
	desc = "Very confusing glasses."
	icon_state = "material"
	inhand_icon_state = "glasses"
	vision_flags = SEE_OBJS
	glass_colour_type = /datum/client_colour/glass_colour/lightblue
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/material/mining
	name = "optical material scanner"
	desc = "Used by miners to detect ores deep within the rock."
	icon_state = "material"
	inhand_icon_state = "glasses"
	darkness_view = 0

/obj/item/clothing/glasses/material/mining/gar
	name = "gar material scanner"
	desc = "Do the impossible, see the invisible!"
	icon_state = "gar_meson"
	inhand_icon_state = "gar_meson"
	alternate_worn_layer = ABOVE_BODY_FRONT_HEAD_LAYER
	force = 10
	throwforce = 20
	throw_speed = 4
	attack_verb_continuous = list("slices")
	attack_verb_simple = list("slice")
	hitsound = 'sound/weapons/bladeslice.ogg'
	sharpness = SHARP_EDGED
	glass_colour_type = /datum/client_colour/glass_colour/lightgreen
	supports_variations_flags = NONE

/obj/item/clothing/glasses/regular
	name = "prescription glasses"
	desc = "Made by Nerd. Co."
	icon_state = "glasses"
	inhand_icon_state = "glasses"
	vision_correction = TRUE //corrects nearsightedness
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/regular/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/knockoff,25,list(BODY_ZONE_PRECISE_EYES),list(ITEM_SLOT_EYES))
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = .proc/on_entered,
	)
	AddElement(/datum/element/connect_loc, loc_connections)


/obj/item/clothing/glasses/regular/proc/on_entered(datum/source, atom/movable/movable)
	SIGNAL_HANDLER
	if(damaged_clothes == CLOTHING_SHREDDED)
		return
	if(item_flags & IN_INVENTORY)
		return
	if(isliving(movable))
		var/mob/living/crusher = movable
		if(crusher.m_intent != MOVE_INTENT_WALK && (!(crusher.movement_type & (FLYING|FLOATING)) || crusher.buckled))
			playsound(src, 'sound/effects/glass_step.ogg', 30, TRUE)
			visible_message(span_warning("[crusher] steps on [src], damaging it!"))
			take_damage(100, sound_effect = FALSE)

/obj/item/clothing/glasses/regular/atom_destruction(damage_flag)
	. = ..()
	vision_correction = FALSE

/obj/item/clothing/glasses/regular/welder_act(mob/living/user, obj/item/I)
	. = ..()
	if(damaged_clothes == CLOTHING_PRISTINE)
		return
	if(!I.tool_start_check(user, amount=1))
		return
	if(I.use_tool(src, user, 10, volume=30, amount=1))
		user.visible_message(span_notice("[user] welds [src] back together."),\
					span_notice("You weld [src] back together."))
		repair()
		return TRUE

/obj/item/clothing/glasses/regular/repair()
	. = ..()
	vision_correction = TRUE

/obj/item/clothing/glasses/regular/thin
	name = "thin prescription glasses"
	desc = "More expensive, more fragile and much less practical, but oh so fashionable."
	icon_state = "glasses_thin"

/obj/item/clothing/glasses/regular/jamjar
	name = "jamjar glasses"
	desc = "Also known as Virginity Protectors."
	icon_state = "jamjar_glasses"
	inhand_icon_state = "jamjar_glasses"
	supports_variations_flags = NONE

/obj/item/clothing/glasses/regular/hipster
	name = "prescription glasses"
	desc = "Made by Uncool. Co."
	icon_state = "hipster_glasses"
	inhand_icon_state = "hipster_glasses"

/obj/item/clothing/glasses/regular/circle
	name = "circle glasses"
	desc = "Why would you wear something so controversial yet so brave?"
	icon_state = "circle_glasses"
	inhand_icon_state = "circle_glasses"
	supports_variations_flags = NONE

//Here lies green glasses, so ugly they died. RIP

/obj/item/clothing/glasses/sunglasses
	name = "sunglasses"
	desc = "Strangely ancient technology used to help provide rudimentary eye cover. Enhanced shielding blocks flashes."
	icon_state = "sun"
	inhand_icon_state = "sunglasses"
	darkness_view = 1
	flash_protect = FLASH_PROTECTION_FLASH
	tint = 1
	glass_colour_type = /datum/client_colour/glass_colour/gray
	dog_fashion = /datum/dog_fashion/head
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/sunglasses/reagent
	name = "beer goggles"
	icon_state = "sunhudbeer"
	desc = "A pair of sunglasses outfitted with apparatus to scan reagents, as well as providing an innate understanding of liquid viscosity while in motion."
	clothing_traits = list(TRAIT_BOOZE_SLIDER, TRAIT_REAGENT_SCANNER)
	supports_variations_flags = NONE

/obj/item/clothing/glasses/sunglasses/chemical
	name = "science glasses"
	icon_state = "sunhudsci"
	desc = "A pair of tacky purple sunglasses that allow the wearer to recognize various chemical compounds with only a glance."
	clothing_traits = list(TRAIT_REAGENT_SCANNER, TRAIT_RESEARCH_SCANNER)
	supports_variations_flags = NONE

/obj/item/clothing/glasses/sunglasses/gar
	name = "black gar glasses"
	desc = "Go beyond impossible and kick reason to the curb!"
	icon_state = "gar_black"
	inhand_icon_state = "gar_black"
	alternate_worn_layer = ABOVE_BODY_FRONT_HEAD_LAYER
	force = 10
	throwforce = 10
	throw_speed = 4
	attack_verb_continuous = list("slices")
	attack_verb_simple = list("slice")
	hitsound = 'sound/weapons/bladeslice.ogg'
	sharpness = SHARP_EDGED

/obj/item/clothing/glasses/sunglasses/gar/orange
	name = "gar glasses"
	desc = "Just who the hell do you think I am?!"
	icon_state = "gar"
	inhand_icon_state = "gar"
	glass_colour_type = /datum/client_colour/glass_colour/orange
	supports_variations_flags = NONE

/obj/item/clothing/glasses/sunglasses/gar/giga
	name = "black giga gar glasses"
	desc = "Believe in us humans."
	icon_state = "gigagar_black"
	force = 12
	throwforce = 12

/obj/item/clothing/glasses/sunglasses/gar/giga/red
	name = "giga gar glasses"
	desc = "We evolve past the person we were a minute before. Little by little we advance with each turn. That's how a drill works!"
	icon_state = "gigagar_red"
	inhand_icon_state = "gar"
	glass_colour_type = /datum/client_colour/glass_colour/red
	supports_variations_flags = NONE

/obj/item/clothing/glasses/welding
	name = "welding goggles"
	desc = "Protects the eyes from bright flashes; approved by the mad scientist association."
	icon_state = "welding-g"
	inhand_icon_state = "welding-g"
	actions_types = list(/datum/action/item_action/toggle)
	flash_protect = FLASH_PROTECTION_WELDER
	custom_materials = list(/datum/material/iron = 250)
	tint = 2
	visor_vars_to_toggle = VISOR_FLASHPROTECT | VISOR_TINT
	flags_cover = GLASSESCOVERSEYES
	glass_colour_type = /datum/client_colour/glass_colour/gray
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/welding/attack_self(mob/user)
	weldingvisortoggle(user)


/obj/item/clothing/glasses/blindfold
	name = "blindfold"
	desc = "Covers the eyes, preventing sight."
	icon_state = "blindfold"
	inhand_icon_state = "blindfold"
	flash_protect = FLASH_PROTECTION_WELDER
	tint = 3
	darkness_view = 1
	dog_fashion = /datum/dog_fashion/head
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/blindfold/equipped(mob/living/carbon/human/user, slot)
	. = ..()
	if(slot == ITEM_SLOT_EYES)
		user.become_blind(BLINDFOLD_TRAIT)

/obj/item/clothing/glasses/blindfold/dropped(mob/living/carbon/human/user)
	..()
	user.cure_blind(BLINDFOLD_TRAIT)

/obj/item/clothing/glasses/trickblindfold
	name = "blindfold"
	desc = "A see-through blindfold perfect for cheating at games like pin the stun baton on the clown."
	icon_state = "trickblindfold"
	inhand_icon_state = "blindfold"
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/blindfold/white
	name = "blind personnel blindfold"
	desc = "Indicates that the wearer suffers from blindness."
	icon_state = "blindfoldwhite"
	inhand_icon_state = "blindfoldwhite"
	var/colored_before = FALSE

/obj/item/clothing/glasses/blindfold/white/visual_equipped(mob/living/carbon/human/user, slot)
	if(ishuman(user) && slot == ITEM_SLOT_EYES)
		update_icon(ALL, user)
		user.update_inv_glasses() //Color might have been changed by update_icon.
	..()

/obj/item/clothing/glasses/blindfold/white/update_icon(updates=ALL, mob/living/carbon/human/user)
	. = ..()
	if(ishuman(user) && !colored_before)
		add_atom_colour(user.eye_color, FIXED_COLOUR_PRIORITY)
		colored_before = TRUE

/obj/item/clothing/glasses/blindfold/white/worn_overlays(mutable_appearance/standing, isinhands = FALSE, file2use)
	. = ..()
	if(isinhands || !ishuman(loc) || colored_before)
		return

	var/mob/living/carbon/human/H = loc
	var/mutable_appearance/M = mutable_appearance('icons/mob/clothing/eyes.dmi', "blindfoldwhite")
	M.appearance_flags |= RESET_COLOR
	M.color = H.eye_color
	. += M

/obj/item/clothing/glasses/sunglasses/big
	desc = "Strangely ancient technology used to help provide rudimentary eye cover. Larger than average enhanced shielding blocks flashes."
	icon_state = "bigsunglasses"
	inhand_icon_state = "bigsunglasses"

/obj/item/clothing/glasses/thermal
	name = "optical thermal scanner"
	desc = "Thermals in the shape of glasses."
	icon_state = "thermal"
	inhand_icon_state = "glasses"
	vision_flags = SEE_MOBS
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_VISIBLE
	flash_protect = FLASH_PROTECTION_SENSITIVE
	glass_colour_type = /datum/client_colour/glass_colour/red
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/thermal/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	thermal_overload()

/obj/item/clothing/glasses/thermal/xray
	name = "syndicate xray goggles"
	desc = "A pair of xray goggles manufactured by the Syndicate."
	vision_flags = SEE_TURFS|SEE_MOBS|SEE_OBJS

/obj/item/clothing/glasses/thermal/xray/equipped(mob/living/carbon/human/user, slot)
	. = ..()
	if(slot != ITEM_SLOT_EYES || !istype(user))
		return
	ADD_TRAIT(user, TRAIT_XRAY_VISION, GLASSES_TRAIT)

/obj/item/clothing/glasses/thermal/xray/dropped(mob/living/carbon/human/user)
	. = ..()
	REMOVE_TRAIT(user, TRAIT_XRAY_VISION, GLASSES_TRAIT)

/obj/item/clothing/glasses/thermal/syndi //These are now a traitor item, concealed as mesons. -Pete
	name = "chameleon thermals"
	desc = "A pair of thermal optic goggles with an onboard chameleon generator."

	var/datum/action/item_action/chameleon/change/chameleon_action

/obj/item/clothing/glasses/thermal/syndi/Initialize(mapload)
	. = ..()
	chameleon_action = new(src)
	chameleon_action.chameleon_type = /obj/item/clothing/glasses
	chameleon_action.chameleon_name = "Glasses"
	chameleon_action.chameleon_blacklist = typecacheof(/obj/item/clothing/glasses/changeling, only_root_path = TRUE)
	chameleon_action.initialize_disguises()

/obj/item/clothing/glasses/thermal/syndi/emp_act(severity)
	. = ..()
	if(. & EMP_PROTECT_SELF)
		return
	chameleon_action.emp_randomise()

/obj/item/clothing/glasses/thermal/monocle
	name = "thermoncle"
	desc = "Never before has seeing through walls felt so gentlepersonly."
	icon_state = "thermoncle"
	flags_1 = null //doesn't protect eyes because it's a monocle, duh

/obj/item/clothing/glasses/thermal/monocle/examine(mob/user) //Different examiners see a different description!
	if(user.gender == MALE)
		desc = replacetext(desc, "person", "man")
	else if(user.gender == FEMALE)
		desc = replacetext(desc, "person", "woman")
	. = ..()
	desc = initial(desc)

/obj/item/clothing/glasses/thermal/eyepatch
	name = "optical thermal eyepatch"
	desc = "An eyepatch with built-in thermal optics."
	icon_state = "eyepatch"
	inhand_icon_state = "eyepatch"
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/cold
	name = "cold goggles"
	desc = "A pair of goggles meant for low temperatures."
	icon_state = "cold"
	inhand_icon_state = "cold"

/obj/item/clothing/glasses/heat
	name = "heat goggles"
	desc = "A pair of goggles meant for high temperatures."
	icon_state = "heat"
	inhand_icon_state = "heat"

/obj/item/clothing/glasses/orange
	name = "orange glasses"
	desc = "A sweet pair of orange shades."
	icon_state = "orangeglasses"
	inhand_icon_state = "orangeglasses"
	glass_colour_type = /datum/client_colour/glass_colour/lightorange

/obj/item/clothing/glasses/red
	name = "red glasses"
	desc = "Hey, you're looking good, senpai!"
	icon_state = "redglasses"
	inhand_icon_state = "redglasses"
	glass_colour_type = /datum/client_colour/glass_colour/red

/obj/item/clothing/glasses/geist_gazers
	name = "geist gazers"
	icon_state = "geist_gazers"
	worn_icon_state = "geist_gazers"
	glass_colour_type = /datum/client_colour/glass_colour/green

/obj/item/clothing/glasses/psych
	name = "psych glasses"
	icon_state = "psych_glasses"
	worn_icon_state = "psych_glasses"
	glass_colour_type = /datum/client_colour/glass_colour/red

/obj/item/clothing/glasses/debug
	name = "debug glasses"
	desc = "Medical, security and diagnostic hud. Alt click to toggle xray."
	icon_state = "nvgmeson"
	inhand_icon_state = "nvgmeson"
	flags_cover = GLASSESCOVERSEYES
	darkness_view = 8
	flash_protect = FLASH_PROTECTION_WELDER
	lighting_alpha = LIGHTING_PLANE_ALPHA_MOSTLY_INVISIBLE
	glass_colour_type = FALSE
	vision_flags = SEE_TURFS
	clothing_traits = list(TRAIT_REAGENT_SCANNER, TRAIT_SUPERMATTER_MADNESS_IMMUNE)
	var/list/hudlist = list(DATA_HUD_MEDICAL_ADVANCED, DATA_HUD_DIAGNOSTIC_ADVANCED, DATA_HUD_SECURITY_ADVANCED)
	var/xray = FALSE

/obj/item/clothing/glasses/debug/equipped(mob/user, slot)
	. = ..()
	if(slot != ITEM_SLOT_EYES)
		return
	if(ishuman(user))
		for(var/hud in hudlist)
			var/datum/atom_hud/H = GLOB.huds[hud]
			H.add_hud_to(user)
		ADD_TRAIT(user, TRAIT_MEDICAL_HUD, GLASSES_TRAIT)
		ADD_TRAIT(user, TRAIT_SECURITY_HUD, GLASSES_TRAIT)
		if(xray)
			ADD_TRAIT(user, TRAIT_XRAY_VISION, GLASSES_TRAIT)

/obj/item/clothing/glasses/debug/dropped(mob/user)
	. = ..()
	REMOVE_TRAIT(user, TRAIT_MEDICAL_HUD, GLASSES_TRAIT)
	REMOVE_TRAIT(user, TRAIT_SECURITY_HUD, GLASSES_TRAIT)
	REMOVE_TRAIT(user, TRAIT_XRAY_VISION, GLASSES_TRAIT)
	if(ishuman(user))
		for(var/hud in hudlist)
			var/datum/atom_hud/H = GLOB.huds[hud]
			H.remove_hud_from(user)

/obj/item/clothing/glasses/debug/AltClick(mob/user)
	. = ..()
	if(ishuman(user))
		if(xray)
			vision_flags -= SEE_MOBS|SEE_OBJS
			REMOVE_TRAIT(user, TRAIT_XRAY_VISION, GLASSES_TRAIT)
		else
			vision_flags += SEE_MOBS|SEE_OBJS
			ADD_TRAIT(user, TRAIT_XRAY_VISION, GLASSES_TRAIT)
		xray = !xray
		var/mob/living/carbon/human/H = user
		H.update_sight()

/obj/item/clothing/glasses/osi
	name = "O.S.I. Sunglasses"
	desc = "There's no such thing as good news! Just bad news and... weird news.."
	icon_state = "osi_glasses"
	inhand_icon_state = "osi_glasses"

/obj/item/clothing/glasses/phantom
	name = "Phantom Thief Mask"
	desc = "Lookin' cool."
	icon_state = "phantom_glasses"
	inhand_icon_state = "phantom_glasses"

/obj/item/clothing/glasses/regular/kim
	name = "binoclard lenses"
	desc = "Shows you know how to sew a lapel and center a back vent."
	icon_state = "binoclard_lenses"
	inhand_icon_state = "binoclard_lenses"
	supports_variations_flags = NONE

/obj/item/clothing/glasses/salesman
	name = "colored glasses"
	desc = "A pair of glasses with uniquely colored lenses. The frame is inscribed with 'Best Salesman 1997'."
	icon_state = "salesman"
	inhand_icon_state = "salesman"
	///Tells us who the current wearer([BIGSHOT]) is.
	var/mob/living/carbon/human/bigshot

/obj/item/clothing/glasses/salesman/equipped(mob/living/carbon/human/user, slot)
	..()
	if(slot != ITEM_SLOT_EYES)
		return
	bigshot = user
	RegisterSignal(bigshot, COMSIG_CARBON_SANITY_UPDATE, .proc/moodshift)

/obj/item/clothing/glasses/salesman/dropped(mob/living/carbon/human/user)
	..()
	UnregisterSignal(bigshot, COMSIG_CARBON_SANITY_UPDATE)
	bigshot = initial(bigshot)
	icon_state = initial(icon_state)
	desc = initial(desc)

/obj/item/clothing/glasses/salesman/proc/moodshift(atom/movable/source, amount)
	SIGNAL_HANDLER
	if(amount < SANITY_UNSTABLE)
		icon_state = "salesman_fzz"
		desc = "A pair of glasses, the lenses are full of TV static. They've certainly seen better days..."
		bigshot.update_inv_glasses()
	else
		icon_state = initial(icon_state)
		desc = initial(desc)
		bigshot.update_inv_glasses()

/obj/item/clothing/glasses/nightmare_vision
	name = "nightmare vision goggles"
	desc = "They give off a putrid stench. Seemingly no effect on anything."
	icon_state = "nightmare"
	inhand_icon_state = "glasses"
	glass_colour_type = /datum/client_colour/glass_colour/nightmare
	forced_glass_color = TRUE

/obj/item/clothing/glasses/thin
	name = "thin glasses"
	desc = "Often seen staring down at someone taking a book."
	icon_state = "glasses_thin"
	inhand_icon_state = "glasses"
	vision_correction = TRUE
	supports_variations_flags = CLOTHING_TESHARI_VARIATION | CLOTHING_VOX_VARIATION

/obj/item/clothing/glasses/betterunshit
	name = "modern glasses"
	desc = "After Nerd. Co went bankrupt for tax evasion and invasion, they were bought out by Dork.Co, who revamped their classic design."
	icon_state = "glasses_alt"
	inhand_icon_state = "glasses_rimless"
	vision_correction = TRUE

/obj/item/clothing/glasses/kim
	name = "binoclard lenses"
	desc = "Stylish round lenses subtly shaded for your protection and criminal discomfort."
	icon_state = "binoclard_lenses"
	inhand_icon_state = "glasses_rimless"
	vision_correction = TRUE

// Like sunglasses, but without any protection
/obj/item/clothing/glasses/fake_sunglasses
	name = "low-UV sunglasses"
	desc = "A cheaper brand of sunglasses rated for much lower UV levels. Offers the user no protection against bright lights."
	icon_state = "sun"
	inhand_icon_state = "sunglasses"
