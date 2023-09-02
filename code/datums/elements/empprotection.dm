/datum/element/empprotection
	element_flags = ELEMENT_BESPOKE | ELEMENT_DETACH // Detach for turfs
	id_arg_index = 2
	var/flags = NONE

/datum/element/empprotection/Attach(datum/target, _flags)
	. = ..()
	if(. == ELEMENT_INCOMPATIBLE || !isatom(target))
		return ELEMENT_INCOMPATIBLE
	flags = _flags
	RegisterSignal(target, COMSIG_ATOM_EMP_ACT, PROC_REF(getEmpFlags))

/datum/element/empprotection/Detach(atom/target)
	UnregisterSignal(target, COMSIG_ATOM_EMP_ACT)
	return ..()

/datum/element/empprotection/proc/getEmpFlags(datum/source, severity)
	SIGNAL_HANDLER

	return flags
