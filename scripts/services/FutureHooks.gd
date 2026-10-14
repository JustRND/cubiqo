class_name FutureHooks
extends RefCounted
## Extension contracts and enumerations for Phase 2+ systems:
## Power-Ups, Difficulty Director, Revive System, Shop, and Player Progression.

enum PowerUpType {
	MEGA_BOMB,    ## Destroys all occupied blocks on the board.
	MIGHTY_HAND,  ## Moves an occupied cell to another valid position.
	HAMMER,       ## Removes one selected block.
	ROW_BLASTER,  ## Clears one selected row.
	TRAY_SHUFFLE  ## Replaces remaining tray pieces.
}

enum DifficultyState {
	NORMAL,
	CHALLENGE,
	RECOVERY
}

enum ReviveSource {
	COINS,
	REWARDED_AD,
	DEBUG_FREE
}

const POWERUP_CATALOG: Dictionary = {
	"mega_bomb": {
		"type": PowerUpType.MEGA_BOMB,
		"display_name": "Mega Bomb",
		"description": "Destroys all occupied blocks on the board.",
		"default_coin_cost": 300
	},
	"mighty_hand": {
		"type": PowerUpType.MIGHTY_HAND,
		"display_name": "Mighty Hand",
		"description": "Moves an occupied cell to another valid position.",
		"default_coin_cost": 150
	},
	"hammer": {
		"type": PowerUpType.HAMMER,
		"display_name": "Hammer",
		"description": "Removes one selected block.",
		"default_coin_cost": 120
	},
	"row_blaster": {
		"type": PowerUpType.ROW_BLASTER,
		"display_name": "Row Blaster",
		"description": "Clears one selected row.",
		"default_coin_cost": 200
	},
	"tray_shuffle": {
		"type": PowerUpType.TRAY_SHUFFLE,
		"display_name": "Tray Shuffle",
		"description": "Replaces remaining tray pieces.",
		"default_coin_cost": 100
	}
}


## Builds a standardized snapshot of board and gameplay metrics for a future Difficulty Director.
static func build_difficulty_context(
	occupancy_ratio: float,
	available_moves: int,
	consecutive_clears: int,
	current_score: int,
	state: DifficultyState = DifficultyState.NORMAL
) -> Dictionary:
	return {
		"occupancy_ratio": occupancy_ratio,
		"available_moves": available_moves,
		"consecutive_clears": consecutive_clears,
		"current_score": current_score,
		"difficulty_state": state
	}
