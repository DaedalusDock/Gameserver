#define NO_MAXVOTES_CAP -1

SUBSYSTEM_DEF(autotransfer)
	name = "Autotransfer Vote"
	flags = SS_KEEP_TIMING | SS_BACKGROUND
	wait = 1 MINUTES

	var/starttime
	var/targettime
	var/voteinterval
	var/maxvotes
	var/curvotes = 0

/datum/controller/subsystem/autotransfer/Initialize(timeofday)
	var/init_vote = CONFIG_GET(number/vote_autotransfer_initial)
	if(!init_vote) //Autotransfer voting disabled.
		can_fire = FALSE
		return ..()
	starttime = REALTIMEOFDAY
	targettime = REALTIMEOFDAY + init_vote
	voteinterval = CONFIG_GET(number/vote_autotransfer_interval)
	maxvotes = CONFIG_GET(number/vote_autotransfer_maximum)
	return ..()

/datum/controller/subsystem/autotransfer/Recover()
	starttime = SSautotransfer.starttime
	voteinterval = SSautotransfer.voteinterval
	curvotes = SSautotransfer.curvotes

/datum/controller/subsystem/autotransfer/fire()
	if(REALTIMEOFDAY < targettime)
		return

	if(maxvotes == NO_MAXVOTES_CAP || maxvotes > curvotes)
		SSvote.initiate_vote(/datum/vote/crew_transfer, "server")
		targettime = targettime + voteinterval
		curvotes++
	else
		SSevacuation.trigger_auto_evac(EVACUATION_REASON_LONG_ROUND)

#undef NO_MAXVOTES_CAP
