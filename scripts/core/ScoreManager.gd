class_name ScoreManager
extends RefCounted
## Authoritative scoring and consecutive-clear combo manager.
##
## Scoring Rules (configurable via `config`):
## - Placed cell: +10 points per cell (`points_per_cell`)
## - Completed row: +100 points per row (`points_per_row`)
## - Completed column: +100 points per column (`points_per_col`)
## - Simultaneous lines bonus:
##     - Exactly 2 lines cleared on the same turn: +50 (`two_lines_bonus`)
##     - 3 or more lines cleared on the same turn: +150 (`three_plus_lines_bonus`)
## - Consecutive-clear combo counter:
##     - Any turn that clears >= 1 line increments `combo_count` by 1.
##     - Any turn that clears 0 lines resets `combo_count` to 0.
##     - When `combo_bonus_enabled` is true and `combo_count >= 2`, awards
##       `(combo_count - 1) * combo_bonus_per_streak` additional points.

signal score_changed(current_score: int, best_score: int, turn_breakdown: Dictionary)
signal combo_changed(combo_count: int)
signal best_score_changed(new_best_score: int)

const DEFAULT_CONFIG: Dictionary = {
	"points_per_cell": 10,
	"points_per_row": 100,
	"points_per_col": 100,
	"two_lines_bonus": 50,
	"three_plus_lines_bonus": 150,
	"combo_bonus_enabled": true,
	"combo_bonus_per_streak": 50
}

var config: Dictionary = DEFAULT_CONFIG.duplicate(true)
var current_score: int = 0
var best_score: int = 0
var combo_count: int = 0


func _init(initial_best_score: int = 0, custom_config: Dictionary = {}) -> void:
	best_score = maxi(0, initial_best_score)
	if not custom_config.is_empty():
		set_config(custom_config)


## Updates one or more scoring configuration parameters.
func set_config(overrides: Dictionary) -> void:
	for k in overrides.keys():
		config[k] = overrides[k]


func get_config() -> Dictionary:
	return config.duplicate(true)


## Resets current session score and combo counter while preserving `best_score`.
func reset_session() -> void:
	current_score = 0
	if combo_count != 0:
		combo_count = 0
		combo_changed.emit(combo_count)
	score_changed.emit(current_score, best_score, {
		"placed_points": 0,
		"row_points": 0,
		"col_points": 0,
		"multi_line_bonus": 0,
		"combo_bonus": 0,
		"turn_total": 0,
		"combo_count": combo_count,
		"current_score": current_score,
		"best_score": best_score,
		"new_best_achieved": false
	})


func set_best_score(value: int) -> void:
	best_score = maxi(0, value)


## Pure calculation helper that computes the breakdown for a turn given current `combo_count` without mutating state.
func calculate_turn_score(
	placed_cells_count: int,
	cleared_rows_count: int,
	cleared_cols_count: int,
	prior_combo_count: int = combo_count
) -> Dictionary:
	var cells_pts: int = maxi(0, placed_cells_count) * int(config.get("points_per_cell", 10))
	var rows_pts: int = maxi(0, cleared_rows_count) * int(config.get("points_per_row", 100))
	var cols_pts: int = maxi(0, cleared_cols_count) * int(config.get("points_per_col", 100))

	var total_lines: int = maxi(0, cleared_rows_count) + maxi(0, cleared_cols_count)
	var multi_bonus: int = 0
	if total_lines == 2:
		multi_bonus = int(config.get("two_lines_bonus", 50))
	elif total_lines >= 3:
		multi_bonus = int(config.get("three_plus_lines_bonus", 150))

	var next_combo: int = prior_combo_count + 1 if total_lines > 0 else 0
	var combo_bonus: int = 0
	if bool(config.get("combo_bonus_enabled", true)) and next_combo >= 2:
		combo_bonus = (next_combo - 1) * int(config.get("combo_bonus_per_streak", 50))

	var turn_total: int = cells_pts + rows_pts + cols_pts + multi_bonus + combo_bonus

	return {
		"placed_points": cells_pts,
		"row_points": rows_pts,
		"col_points": cols_pts,
		"total_lines": total_lines,
		"multi_line_bonus": multi_bonus,
		"combo_bonus": combo_bonus,
		"turn_total": turn_total,
		"combo_count": next_combo
	}


## Authoritatively records a completed placement turn, updating `current_score`, `combo_count`, and `best_score`.
func record_turn(placed_cells_count: int, cleared_rows_count: int, cleared_cols_count: int) -> Dictionary:
	var breakdown := calculate_turn_score(placed_cells_count, cleared_rows_count, cleared_cols_count, combo_count)

	var prev_combo := combo_count
	combo_count = int(breakdown["combo_count"])
	if combo_count != prev_combo:
		combo_changed.emit(combo_count)

	current_score += int(breakdown["turn_total"])
	var new_best := false
	if current_score > best_score:
		best_score = current_score
		new_best = true
		best_score_changed.emit(best_score)

	breakdown["current_score"] = current_score
	breakdown["best_score"] = best_score
	breakdown["new_best_achieved"] = new_best

	score_changed.emit(current_score, best_score, breakdown)
	return breakdown
