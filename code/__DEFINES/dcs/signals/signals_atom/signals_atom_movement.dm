// Atom movement signals. Format:
// When the signal is called: (signal arguments)
// All signals send the source datum of the signal as the first argument

///signal sent out by an atom when it checks if it can be grabbed, for additional checks
#define COMSIG_ATOM_CAN_BE_GRABBED "movable_can_be_grabbed"
	#define COMSIG_ATOM_NO_GRAB (1 << 0)
///signal sent out by an atom when it is no longer being pulled by something else : (atom/puller)
#define COMSIG_ATOM_NO_LONGER_GRABBED "movable_no_longer_grabbed"
///signal sent out by a living mob when it is no longer pulling something : (atom/pulling)
#define COMSIG_LIVING_NO_LONGER_GRABBING "living_no_longer_grabbing"
///called for each movable in a turf contents on /turf/zImpact(): (atom/movable/A, levels)
#define COMSIG_ATOM_INTERCEPT_Z_FALL "movable_intercept_z_impact"
///called on a movable when it starts pulling (atom/movable/pulled, state, force)
#define COMSIG_LIVING_START_GRAB "movable_start_grab"
///called on a movable when it has been grabbed
#define COMSIG_ATOM_GET_GRABBED "movable_start_grabbed"
///called on /living, when a grab is attempted, but before it completes, from base of [/mob/living/make_grab]: (atom/movable/thing, grab_type)
#define COMSIG_LIVING_TRY_GRAB "living_try_pull"
	#define COMSIG_LIVING_CANCEL_GRAB (1 << 0)

///called on /living when it downgrades a grab
#define COMSIG_LIVING_GRAB_DOWNGRADE "living_grab_downgrade"
///called on /living when it upgrades a grab
#define COMSIG_LIVING_GRAB_UPGRADE "living_grab_upgrade"

/// Called from /mob/living/PushAM -- Called when this mob is about to push a movable, but before it moves
/// (aotm/movable/being_pushed)
#define COMSIG_LIVING_PUSHING_MOVABLE "living_pushing_movable"
///from base of [/atom/proc/interact]: (mob/user)
#define COMSIG_ATOM_UI_INTERACT "atom_ui_interact"
///from base of atom/relaymove(): (mob/living/user, direction)
#define COMSIG_ATOM_RELAYMOVE "atom_relaymove"
	///prevents the "you cannot move while buckled! message"
	#define COMSIG_BLOCK_RELAYMOVE (1<<0)
///from base of atom/setDir(): (old_dir, new_dir). Called before the direction changes.
#define COMSIG_ATOM_DIR_CHANGE "atom_dir_change"
///from base of atom/set_density(): (old_density, new_density). Called before the density changes.
#define COMSIG_ATOM_DENSITY_CHANGE "atom_density_change"
/// from /datum/component/singularity/proc/can_move(), as well as /obj/energy_ball/proc/can_move()
/// if a callback returns `SINGULARITY_TRY_MOVE_BLOCK`, then the singularity will not move to that turf
#define COMSIG_ATOM_SINGULARITY_TRY_MOVE "atom_singularity_try_move"
	/// When returned from `COMSIG_ATOM_SINGULARITY_TRY_MOVE`, the singularity will move to that turf
	#define SINGULARITY_TRY_MOVE_BLOCK (1 << 0)
///from base of atom/experience_pressure_difference(): (pressure_difference, direction, pressure_resistance_prob_delta)
#define COMSIG_ATOM_PRE_PRESSURE_PUSH "atom_pre_pressure_push"
	///prevents pressure movement
	#define COMSIG_ATOM_BLOCKS_PRESSURE (1<<0)
