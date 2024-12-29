#define RUNE_BB_INVOKER "user"
#define RUNE_BB_TOME "tome"
#define RUNE_BB_CANCEL_REASON "cancel_reason"
#define RUNE_BB_CANCEL_SOURCE "cancel_source"
#define RUNE_BB_TARGET_MOB "target_mob"
/// The list of parts to exchange for the exchange rune.
#define RUNE_BB_EXCHANGE_PARTS "exchange_parts"

/// Graceful fails should have NO SIDE EFFECTS.
#define RUNE_FAIL_GRACEFUL "graceful_fail"

// ~& Global failure states, handle these always! &~//
#define RUNE_FAIL_INVOKER_INCAP "invoker_incap"
/// Helper removed their hand from the rune.
#define RUNE_FAIL_HELPER_REMOVED_HAND "helper_incap"
/// Target mob moved off the center.
#define RUNE_FAIL_TARGET_MOB_MOVED "target_mob_moved"
/// Target stood up.
#define RUNE_FAIL_TARGET_STOOD_UP "target_stood_up"
#define RUNE_FAIL_TOME_GONE "tome_gone"
/// An item has moved out of the rune.
#define RUNE_FAIL_TARGET_ITEM_OUT_OF_RUNE "item_out_of_rune"

/// Special failure condition where the revival target was revived mid ritual.
#define RUNE_FAIL_REVIVAL_TARGET_ALIVE "revival_target_alive"

#define RUNE_INVOKING_PENDING_CANCEL -1
#define RUNE_INVOKING_IDLE 0
#define RUNE_INVOKING_ACTIVE 1
