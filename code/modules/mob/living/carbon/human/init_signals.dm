//Called on /mob/living/carbon/Initialize(mapload), for the carbon mobs to register relevant signals.
/mob/living/carbon/human/register_init_signals()
	. = ..()
	RegisterSignal(src, \
		list(
			SIGNAL_ADDTRAIT(TRAIT_INVISIBLE_MAN),
			SIGNAL_REMOVETRAIT(TRAIT_INVISIBLE_MAN),
			SIGNAL_ADDTRAIT(TRAIT_DISFIGURED),
			SIGNAL_REMOVETRAIT(TRAIT_DISFIGURED),
		),\
		PROC_REF(do_name_update))

/mob/living/carbon/human/proc/do_name_update(datum/source)
	SIGNAL_HANDLER
	update_appearance(UPDATE_NAME)
