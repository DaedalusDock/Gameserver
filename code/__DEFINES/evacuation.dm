// States for the evacuation controller
#define EVACUATION_STATE_IDLE 0
#define EVACUATION_STATE_INITIATED 1 // Evacuation has begun, but it can be cancelled
#define EVACUATION_STATE_AWAITING 2 // Awaiting players to board the shuttle/pods/etc, can't be cancelled but can be delayed
#define EVACUATION_STATE_EVACUATED 3 // Shuttle/pods/etc have departed, can't be cancelled nor delayed
#define EVACUATION_STATE_FINISHED 4

// Reasons for automatic evacuation
#define EVACUATION_REASON_CREW_DEATH "crew_death"
#define EVACUATION_REASON_LONG_ROUND "long_round"
#define EVACUATION_REASON_VOTE "vote"
#define EVACUATION_REASON_CONSOLE_DESTROYED "console_destroyed"
#define EVACUATION_REASON_AI_DESTROYED "ai_destroyed"
