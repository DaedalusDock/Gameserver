/**
 * This is the file you should use to add alternate titles for each job, just
 * follow the way they're done here, it's easy enough and shouldn't take any
 * time at all to add more or add some for a job that doesn't have any.
 */


/datum/job
	/// The list of alternative job titles people can pick from, null by default.
	var/list/alt_titles = null

// Heads
/datum/job/chief_engineer
	alt_titles = list(JOB_CHIEF_ENGINEER)

/datum/job/augur
	alt_titles = list(JOB_AUGUR)

/datum/job/head_of_security
	alt_titles = list(JOB_SECURITY_MARSHAL)

// Security

/datum/job/security_officer
	alt_titles = list(JOB_SECURITY_OFFICER, "Security Guard")

/datum/job/warden
	alt_titles = list(JOB_WARDEN)

/datum/job/detective
	alt_titles = list(JOB_DETECTIVE)

/datum/job/prisoner
	alt_titles = list(JOB_PRISONER)

// Medical

/datum/job/acolyte
	alt_titles = list(JOB_ACOLYTE)

/datum/job/paramedic
	alt_titles = list(JOB_PARAMEDIC)

/datum/job/chemist
	alt_titles = list(JOB_CHEMIST)

/datum/job/virologist
	alt_titles = list(JOB_VIROLOGIST)

/datum/job/psychologist
	alt_titles = list(JOB_PSYCHOLOGIST)

// Engineering

/datum/job/station_engineer
	alt_titles = list(JOB_STATION_ENGINEER, "Maintenance Technician", "Electrician", "Engine Technician")

/datum/job/atmospheric_technician
	alt_titles = list(JOB_ATMOSPHERIC_TECHNICIAN)

// Cargo
/datum/job/quartermaster
	alt_titles = list(JOB_QUARTERMASTER)

/datum/job/cargo_technician
	alt_titles = list(JOB_DECKHAND, "Mailman")

/datum/job/shaft_miner
	alt_titles = list(JOB_PROSPECTOR)

// Service

/datum/job/cook
	alt_titles = list(JOB_COOK, "Chef", "Culinary Artist")

/datum/job/bartender
	alt_titles = list(JOB_BARTENDER, "Mixologist", "Barkeeper")

/datum/job/botanist
	alt_titles = list(JOB_BOTANIST)

/datum/job/curator
	alt_titles = list(JOB_ARCHIVIST)

/datum/job/janitor
	alt_titles = list(JOB_JANITOR, "Custodian", "Sanitation Technician")

/datum/job/chaplain
	alt_titles = list(JOB_CHAPLAIN, "Priest", "Preacher", "Reverend", "Oracle", "Pontifex", "Magister", "High Priest", "Imam", "Rabbi", "Monk", "Counselor")

/datum/job/lawyer
	alt_titles = list(JOB_LAWYER, "Human Resources Agent", "Defence Attorney", "Public Defender", "Prosecutor")
