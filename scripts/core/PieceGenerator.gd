class_name PieceGenerator
extends RefCounted
## Deterministic, weighted block piece generator with extension hooks for a future Difficulty Director.

const TRAY_SIZE: int = 3

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _catalog: Array[PieceDefinition] = []
var _catalog_by_id: Dictionary = {}
var _weight_overrides: Dictionary = {}
var _difficulty_state: int = FutureHooks.DifficultyState.NORMAL
var _current_seed: int = 0


func _init(initial_seed: int = -1, custom_catalog: Array[PieceDefinition] = []) -> void:
	if custom_catalog.is_empty():
		set_catalog(PieceDefinition.create_default_catalog())
	else:
		set_catalog(custom_catalog)

	if initial_seed >= 0:
		set_seed(initial_seed)
	else:
		_rng.randomize()
		_current_seed = int(_rng.seed)


## Sets a fixed deterministic seed on the internal RandomNumberGenerator.
func set_seed(seed_value: int) -> void:
	_current_seed = seed_value
	_rng.seed = seed_value


func get_seed() -> int:
	return _current_seed


## Replaces the active shape catalog.
func set_catalog(pieces: Array[PieceDefinition]) -> void:
	_catalog.clear()
	_catalog_by_id.clear()
	for p in pieces:
		if p != null and p.is_valid_definition():
			_catalog.append(p)
			_catalog_by_id[p.id] = p


## Registers an additional shape definition or updates an existing shape by ID.
func register_shape(piece: PieceDefinition) -> bool:
	if piece == null or not piece.is_valid_definition():
		return false
	if _catalog_by_id.has(piece.id):
		for i in range(_catalog.size()):
			if _catalog[i].id == piece.id:
				_catalog[i] = piece
				break
	else:
		_catalog.append(piece)
	_catalog_by_id[piece.id] = piece
	return true


func get_catalog() -> Array[PieceDefinition]:
	return _catalog.duplicate()


func get_piece_by_id(shape_id: String) -> PieceDefinition:
	if _catalog_by_id.has(shape_id):
		return (_catalog_by_id[shape_id] as PieceDefinition).duplicate_piece()
	return null


## Overrides the selection weight for a specific shape ID.
func set_shape_weight(shape_id: String, weight: float) -> void:
	_weight_overrides[shape_id] = maxf(0.0, weight)


func clear_weight_overrides() -> void:
	_weight_overrides.clear()


func get_effective_weight(piece: PieceDefinition, context: Dictionary = {}) -> float:
	if piece == null:
		return 0.0
	var base_w: float = float(_weight_overrides.get(piece.id, piece.weight))
	if base_w <= 0.0:
		return 0.0

	var state: int = int(context.get("difficulty_state", _difficulty_state))
	if state == FutureHooks.DifficultyState.RECOVERY:
		# Favor lower-difficulty shapes during recovery
		if piece.difficulty_rating == 1:
			base_w *= 1.5
		elif piece.difficulty_rating >= 3:
			base_w *= 0.5
	elif state == FutureHooks.DifficultyState.CHALLENGE:
		# Slightly increase larger/complex shapes during challenge state
		if piece.difficulty_rating >= 3:
			base_w *= 1.35

	return base_w


func set_difficulty_state(state: int) -> void:
	_difficulty_state = state


func get_difficulty_state() -> int:
	return _difficulty_state


## Generates a single random piece using weighted selection from the catalog.
func generate_piece(context: Dictionary = {}) -> PieceDefinition:
	if _catalog.is_empty():
		return null

	var total_weight: float = 0.0
	var weights: Array[float] = []
	weights.resize(_catalog.size())

	for i in range(_catalog.size()):
		var w := get_effective_weight(_catalog[i], context)
		weights[i] = w
		total_weight += w

	if total_weight <= 0.0:
		var fallback_idx := _rng.randi_range(0, _catalog.size() - 1)
		return _catalog[fallback_idx].duplicate_piece()

	var roll := _rng.randf() * total_weight
	var cumulative: float = 0.0
	for i in range(_catalog.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return _catalog[i].duplicate_piece()

	return _catalog[_catalog.size() - 1].duplicate_piece()


## Generates a tray of `count` pieces (default 3).
func generate_tray(count: int = TRAY_SIZE, context: Dictionary = {}) -> Array[PieceDefinition]:
	var tray: Array[PieceDefinition] = []
	for _i in range(count):
		var p := generate_piece(context)
		if p != null:
			tray.append(p)
	return tray


## Extension point for future Difficulty Director: evaluates a candidate tray against a board state.
func evaluate_candidate_tray(board: BoardModel, candidate_tray: Array[PieceDefinition]) -> Dictionary:
	var total_difficulty: int = 0
	var total_cells: int = 0
	var fit_count: int = 0
	for p in candidate_tray:
		if p != null:
			total_difficulty += p.difficulty_rating
			total_cells += p.get_cell_count()
			if board != null and PlacementRules.can_piece_fit_anywhere(board, p):
				fit_count += 1

	var available_moves: int = 0
	var occupancy_ratio: float = 0.0
	if board != null:
		available_moves = PlacementRules.count_available_moves_for_tray(board, candidate_tray)
		occupancy_ratio = board.get_occupancy_ratio()

	return {
		"total_difficulty": total_difficulty,
		"total_cells": total_cells,
		"fitting_pieces_count": fit_count,
		"available_moves": available_moves,
		"board_occupancy_ratio": occupancy_ratio
	}
