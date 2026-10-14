class_name AdServiceInterface
extends RefCounted
## Interface contract for future rewarded advertisement integration (Phase 2+).
## Phase 1 strictly does NOT integrate any real ad SDK or trigger forced ad flows.

signal rewarded_ad_completed(placement_id: String, rewarded: bool)
signal rewarded_ad_failed(placement_id: String, reason: String)

enum Placement {
	REVIVE,
	POWERUP_REWARD,
	SHOP_BONUS_COINS,
	TRAY_SHUFFLE
}


func is_rewarded_ad_available(_placement_id: String) -> bool:
	return false


func request_rewarded_ad(placement_id: String) -> void:
	rewarded_ad_failed.emit(placement_id, "Rewarded ads are disabled in Phase 1.")
