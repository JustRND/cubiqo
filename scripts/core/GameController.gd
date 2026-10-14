class_name GameController
extends Node
## Central gameplay state machine and turn transaction coordinator.
## Orchestrates BoardModel, PieceGenerator, PlacementRules, ScoreManager, and SaveManager.

signal state_changed(old_state: int, new_state: int)
signal game_started(tray: Array)
signal tray_updated(tray: Array)
signal tray_refilled(tray: Array)
signal piece_placed(slot_index: int, piece: PieceDefinition, origin: Vector2i, tx_result: Dictionary, score_breakdown: Dictionary)
signal placement_rejected(slot_index: int, origin: Vector2i, reason: String)
signal lines_cleared(cleared_rows: Array[int], cleared_cols: Array[int], cleared_cells: Array[Vector2i], snapshots: Array[Dictionary], score_breakdown: Dictionary)
signal game_over_triggered(final_score: int, best_score: int)
signal placeholder_feature_requested(feature_category: String, feature_id: String, message: String)

enum GameState {
	IDLE,
	PLAYING,
	TRANSITION_LOCKED,
	GAME_OVER
}

const TRAY_SLOT_COUNT: int = 3

var state: int = GameState.IDLE
var board: BoardModel
var piece_generator: PieceGenerator
var score_manager: ScoreManager
var save_manager: SaveManager
var ad_service: AdServiceInterface

## Array of length 3 holding either a `PieceDefinition` or `null` for consumed slots.
var tray: Array = [null, null, null]
var turn_number: int = 0
var _pending_game_over_after_transition: bool = false


func _init(custom_save_path: String = SaveManager.DEFAULT_SAVE_PATH, initial_seed: int = -1) -> void:
	save_manager = SaveManager.new(custom_save_path)
	board = BoardModel.new()
	piece_generator = PieceGenerator.new(initial_seed)
	score_manager = ScoreManager.new(save_manager.get_best_score())
	ad_service = AdServiceInterface.new()
	score_manager.best_score_changed.connect(_on_best_score_changed)


func _on_best_score_changed(new_best: int) -> void:
	if save_manager != null:
		save_manager.set_best_score(new_best)


func _set_state(new_state: int) -> void:
	if state == new_state:
		return
	var prev := state
	state = new_state
	state_changed.emit(prev, state)


## Starts a fresh game session, optionally resetting RNG with `custom_seed`.
func start_new_game(custom_seed: int = -1) -> void:
	if custom_seed >= 0:
		piece_generator.set_seed(custom_seed)
	_pending_game_over_after_transition = false
	turn_number = 0
	board.reset()
	score_manager.set_best_score(save_manager.get_best_score())
	score_manager.reset_session()
	_refill_tray()
	_set_state(GameState.PLAYING)
	game_started.emit(tray.duplicate())
	_evaluate_game_over_condition()


## Alias for starting a new session from Game Over or Settings.
func restart_game(custom_seed: int = -1) -> void:
	start_new_game(custom_seed)


## Overrides the current tray directly (used for deterministic tests and future Tray Shuffle / Revive).
func set_tray_pieces(custom_pieces: Array) -> void:
	tray = [null, null, null]
	for i in range(mini(TRAY_SLOT_COUNT, custom_pieces.size())):
		if custom_pieces[i] is PieceDefinition:
			tray[i] = custom_pieces[i]
	tray_updated.emit(tray.duplicate())
	if state == GameState.PLAYING:
		_evaluate_game_over_condition()


func get_tray_piece(slot_index: int) -> PieceDefinition:
	if slot_index < 0 or slot_index >= TRAY_SLOT_COUNT:
		return null
	return tray[slot_index] as PieceDefinition


func get_remaining_tray_count() -> int:
	var count: int = 0
	for i in range(TRAY_SLOT_COUNT):
		if tray[i] != null:
			count += 1
	return count


func can_accept_input() -> bool:
	return state == GameState.PLAYING


## Checks whether the piece in `slot_index` can be legally placed at `origin`.
func can_place_tray_piece(slot_index: int, origin: Vector2i) -> bool:
	if state != GameState.PLAYING:
		return false
	var piece := get_tray_piece(slot_index)
	if piece == null:
		return false
	return PlacementRules.can_place_piece(board, piece, origin)


## Authoritative turn transaction: attempts to place the piece at `slot_index` onto `origin`.
func try_place_tray_piece(slot_index: int, origin: Vector2i) -> Dictionary:
	if state != GameState.PLAYING:
		placement_rejected.emit(slot_index, origin, "invalid_game_state")
		return {"success": false, "reason": "invalid_game_state"}

	if slot_index < 0 or slot_index >= TRAY_SLOT_COUNT:
		placement_rejected.emit(slot_index, origin, "invalid_slot_index")
		return {"success": false, "reason": "invalid_slot_index"}

	var piece: PieceDefinition = tray[slot_index]
	if piece == null:
		placement_rejected.emit(slot_index, origin, "slot_empty")
		return {"success": false, "reason": "slot_empty"}

	var tx := board.place_piece(piece, origin)
	if not bool(tx.get("success", false)):
		var reject_reason := String(tx.get("reason", "illegal_placement"))
		placement_rejected.emit(slot_index, origin, reject_reason)
		return {"success": false, "reason": reject_reason}

	# Consume the tray slot immediately to prevent accidental double placement
	tray[slot_index] = null
	turn_number += 1

	var placed_cells: Array[Vector2i] = tx["placed_cells"]
	var cleared_rows: Array[int] = tx["cleared_rows"]
	var cleared_cols: Array[int] = tx["cleared_cols"]
	var cleared_cells: Array[Vector2i] = tx["cleared_cells"]
	var snapshots: Array[Dictionary] = tx["cleared_snapshots"]

	var score_breakdown := score_manager.record_turn(
		placed_cells.size(),
		cleared_rows.size(),
		cleared_cols.size()
	)

	piece_placed.emit(slot_index, piece, origin, tx, score_breakdown)
	tray_updated.emit(tray.duplicate())

	if not cleared_rows.is_empty() or not cleared_cols.is_empty():
		lines_cleared.emit(cleared_rows, cleared_cols, cleared_cells, snapshots, score_breakdown)

	# Refill tray when all 3 pieces have been used
	if get_remaining_tray_count() == 0:
		_refill_tray()

	# Check whether any remaining piece in the tray can fit on the board
	_evaluate_game_over_condition()

	return {
		"success": true,
		"reason": "ok",
		"transaction": tx,
		"score_breakdown": score_breakdown,
		"game_state": state
	}


func _refill_tray() -> void:
	var context := FutureHooks.build_difficulty_context(
		board.get_occupancy_ratio(),
		0,
		score_manager.combo_count,
		score_manager.current_score,
		piece_generator.get_difficulty_state()
	)
	var generated := piece_generator.generate_tray(TRAY_SLOT_COUNT, context)
	tray = [null, null, null]
	for i in range(mini(TRAY_SLOT_COUNT, generated.size())):
		tray[i] = generated[i]
	tray_updated.emit(tray.duplicate())
	tray_refilled.emit(tray.duplicate())


func _evaluate_game_over_condition() -> void:
	if not PlacementRules.can_any_piece_fit(board, tray):
		if state == GameState.TRANSITION_LOCKED:
			_pending_game_over_after_transition = true
		else:
			_set_state(GameState.GAME_OVER)
			game_over_triggered.emit(score_manager.current_score, score_manager.best_score)


## Locks gameplay input during critical visual transitions (e.g., line-clearing animations).
func lock_for_transition() -> void:
	if state == GameState.PLAYING:
		_set_state(GameState.TRANSITION_LOCKED)
	elif state == GameState.GAME_OVER:
		_pending_game_over_after_transition = true


## Releases the transition lock and restores PLAYING or triggers pending GAME_OVER.
func unlock_after_transition() -> void:
	if state == GameState.TRANSITION_LOCKED:
		if _pending_game_over_after_transition or not PlacementRules.can_any_piece_fit(board, tray):
			_pending_game_over_after_transition = false
			_set_state(GameState.GAME_OVER)
			game_over_triggered.emit(score_manager.current_score, score_manager.best_score)
		else:
			_set_state(GameState.PLAYING)


## Placeholder hook for Phase 2 Revive functionality (strictly no ads in Phase 1).
func request_placeholder_revive() -> void:
	placeholder_feature_requested.emit(
		"revive",
		"revive_placeholder",
		"Revive system will be enabled in Phase 2 (no ads in Phase 1)."
	)


## Placeholder hook for Phase 2 Power-Up activation.
func request_placeholder_powerup(powerup_id: String) -> void:
	var info: Dictionary = FutureHooks.POWERUP_CATALOG.get(powerup_id, {})
	var display_name: String = String(info.get("display_name", powerup_id.capitalize()))
	placeholder_feature_requested.emit(
		"powerup",
		powerup_id,
		"%s power-up is a Phase 2 placeholder." % display_name
	)


## Placeholder hook for Phase 2 Shop panel.
func request_placeholder_shop() -> void:
	placeholder_feature_requested.emit(
		"shop",
		"shop_placeholder",
		"Power-up & Coin Shop will open in Phase 2."
	)
