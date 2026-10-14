class_name BoardModel
extends RefCounted
## Authoritative 8x8 puzzle board state, cell metadata storage, and controlled placement/clearing transactions.
## Pure domain model with zero scene-tree or UI dependencies.

const BOARD_SIZE: int = 8
const TOTAL_CELLS: int = BOARD_SIZE * BOARD_SIZE

## Flat array of 64 cell dictionaries indexed by `y * BOARD_SIZE + x`.
var _cells: Array[Dictionary] = []


func _init() -> void:
	_cells.resize(TOTAL_CELLS)
	reset()


## Resets all 64 cells to their empty state.
func reset() -> void:
	for i in range(TOTAL_CELLS):
		_cells[i] = _create_empty_cell()


func _create_empty_cell() -> Dictionary:
	return {
		"occupied": false,
		"color_id": "",
		"color": Color.TRANSPARENT,
		"piece_id": "",
		"metadata": {}
	}


func _to_index(pos: Vector2i) -> int:
	return pos.y * BOARD_SIZE + pos.x


## Returns true if `pos` lies inside the 8x8 board `[0, 7] x [0, 7]`.
func is_within_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < BOARD_SIZE and pos.y >= 0 and pos.y < BOARD_SIZE


## Returns true if `pos` is within bounds and currently occupied.
func is_cell_occupied(pos: Vector2i) -> bool:
	if not is_within_bounds(pos):
		return false
	return bool(_cells[_to_index(pos)]["occupied"])


## Returns a safe copy of the cell data at `pos`, or an empty cell dictionary if out of bounds.
func get_cell(pos: Vector2i) -> Dictionary:
	if not is_within_bounds(pos):
		return _create_empty_cell()
	var cell := _cells[_to_index(pos)]
	return {
		"occupied": cell["occupied"],
		"color_id": cell["color_id"],
		"color": cell["color"],
		"piece_id": cell["piece_id"],
		"metadata": (cell["metadata"] as Dictionary).duplicate(true)
	}


## Returns direct read-only dictionary reference for fast rendering without allocations.
func get_cell_fast(x: int, y: int) -> Dictionary:
	return _cells[y * BOARD_SIZE + x]


## Returns the total number of occupied cells on the board (0..64).
func get_occupied_count() -> int:
	var count: int = 0
	for i in range(TOTAL_CELLS):
		if _cells[i]["occupied"]:
			count += 1
	return count


## Returns the board occupancy ratio in the range [0.0, 1.0].
func get_occupancy_ratio() -> float:
	return float(get_occupied_count()) / float(TOTAL_CELLS)


## Checks whether `piece` can be legally placed at `origin` without mutating board state.
func can_place(piece: PieceDefinition, origin: Vector2i) -> bool:
	if piece == null or piece.cells.is_empty():
		return false
	for offset in piece.cells:
		var target := origin + offset
		if not is_within_bounds(target):
			return false
		if _cells[_to_index(target)]["occupied"]:
			return false
	return true


## Authoritative transaction: places `piece` at `origin` if legal, then resolves any completed rows and columns.
## If placement is illegal, board state is untouched and `{"success": false, ...}` is returned.
func place_piece(piece: PieceDefinition, origin: Vector2i, cell_metadata: Dictionary = {}) -> Dictionary:
	if piece == null or piece.cells.is_empty():
		return {
			"success": false,
			"reason": "invalid_piece",
			"placed_cells": [] as Array[Vector2i],
			"cleared_rows": [] as Array[int],
			"cleared_cols": [] as Array[int],
			"cleared_cells": [] as Array[Vector2i],
			"cleared_snapshots": [] as Array[Dictionary]
		}

	var world_cells: Array[Vector2i] = []
	for offset in piece.cells:
		var target := origin + offset
		if not is_within_bounds(target):
			return {
				"success": false,
				"reason": "out_of_bounds",
				"placed_cells": [] as Array[Vector2i],
				"cleared_rows": [] as Array[int],
				"cleared_cols": [] as Array[int],
				"cleared_cells": [] as Array[Vector2i],
				"cleared_snapshots": [] as Array[Dictionary]
			}
		if _cells[_to_index(target)]["occupied"]:
			return {
				"success": false,
				"reason": "cell_occupied",
				"placed_cells": [] as Array[Vector2i],
				"cleared_rows": [] as Array[int],
				"cleared_cols": [] as Array[int],
				"cleared_cells": [] as Array[Vector2i],
				"cleared_snapshots": [] as Array[Dictionary]
			}
		world_cells.append(target)

	# Commit placement to cells
	var base_meta := piece.metadata.duplicate(true)
	for k in cell_metadata.keys():
		base_meta[k] = cell_metadata[k]

	for cell_pos in world_cells:
		var idx := _to_index(cell_pos)
		_cells[idx] = {
			"occupied": true,
			"color_id": piece.color_id,
			"color": piece.color,
			"piece_id": piece.id,
			"metadata": base_meta.duplicate(true)
		}

	# Check and clear completed rows and columns simultaneously
	var clear_result := resolve_completed_lines()

	return {
		"success": true,
		"reason": "ok",
		"placed_cells": world_cells,
		"cleared_rows": clear_result["cleared_rows"],
		"cleared_cols": clear_result["cleared_cols"],
		"cleared_cells": clear_result["cleared_cells"],
		"cleared_snapshots": clear_result["cleared_snapshots"]
	}


## Evaluates all rows and columns simultaneously, clearing any full lines.
## Intersecting cells between a cleared row and column are only removed once.
func resolve_completed_lines() -> Dictionary:
	var full_rows := find_full_rows()
	var full_cols := find_full_cols()
	var cleared_cells: Array[Vector2i] = []
	var cleared_snapshots: Array[Dictionary] = []

	if full_rows.is_empty() and full_cols.is_empty():
		return {
			"cleared_rows": full_rows,
			"cleared_cols": full_cols,
			"cleared_cells": cleared_cells,
			"cleared_snapshots": cleared_snapshots
		}

	var unique_indices: Dictionary = {}

	for r in full_rows:
		for x in range(BOARD_SIZE):
			var pos := Vector2i(x, r)
			var idx := _to_index(pos)
			if not unique_indices.has(idx):
				unique_indices[idx] = pos

	for c in full_cols:
		for y in range(BOARD_SIZE):
			var pos := Vector2i(c, y)
			var idx := _to_index(pos)
			if not unique_indices.has(idx):
				unique_indices[idx] = pos

	for idx in unique_indices.keys():
		var pos: Vector2i = unique_indices[idx]
		var prev_cell := _cells[idx]
		cleared_cells.append(pos)
		cleared_snapshots.append({
			"pos": pos,
			"color_id": prev_cell["color_id"],
			"color": prev_cell["color"],
			"piece_id": prev_cell["piece_id"],
			"metadata": (prev_cell["metadata"] as Dictionary).duplicate(true)
		})
		_cells[idx] = _create_empty_cell()

	return {
		"cleared_rows": full_rows,
		"cleared_cols": full_cols,
		"cleared_cells": cleared_cells,
		"cleared_snapshots": cleared_snapshots
	}


## Returns indices (0..7) of all completely filled horizontal rows.
func find_full_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in range(BOARD_SIZE):
		var full := true
		var row_offset := y * BOARD_SIZE
		for x in range(BOARD_SIZE):
			if not _cells[row_offset + x]["occupied"]:
				full = false
				break
		if full:
			rows.append(y)
	return rows


## Returns indices (0..7) of all completely filled vertical columns.
func find_full_cols() -> Array[int]:
	var cols: Array[int] = []
	for x in range(BOARD_SIZE):
		var full := true
		for y in range(BOARD_SIZE):
			if not _cells[y * BOARD_SIZE + x]["occupied"]:
				full = false
				break
		if full:
			cols.append(x)
	return cols


## Non-mutating query returning which rows and columns would clear if `piece` were placed at `origin`.
func preview_placement(piece: PieceDefinition, origin: Vector2i) -> Dictionary:
	if not can_place(piece, origin):
		return {
			"valid": false,
			"placed_cells": [] as Array[Vector2i],
			"would_clear_rows": [] as Array[int],
			"would_clear_cols": [] as Array[int]
		}

	var placed_cells := piece.get_world_cells(origin)
	var temp_lookup: Dictionary = {}
	for p in placed_cells:
		temp_lookup[_to_index(p)] = true

	var would_rows: Array[int] = []
	for y in range(BOARD_SIZE):
		var full := true
		var row_offset := y * BOARD_SIZE
		for x in range(BOARD_SIZE):
			var idx := row_offset + x
			if not _cells[idx]["occupied"] and not temp_lookup.has(idx):
				full = false
				break
		if full:
			would_rows.append(y)

	var would_cols: Array[int] = []
	for x in range(BOARD_SIZE):
		var full := true
		for y in range(BOARD_SIZE):
			var idx := y * BOARD_SIZE + x
			if not _cells[idx]["occupied"] and not temp_lookup.has(idx):
				full = false
				break
		if full:
			would_cols.append(x)

	return {
		"valid": true,
		"placed_cells": placed_cells,
		"would_clear_rows": would_rows,
		"would_clear_cols": would_cols
	}


## Controlled transaction helper to occupy a single cell (used by tests and board setup).
func set_cell_occupied(
	pos: Vector2i,
	color_id: String = "cyan",
	color: Color = Color("#06B6D4"),
	metadata: Dictionary = {},
	piece_id: String = "manual"
) -> bool:
	if not is_within_bounds(pos):
		return false
	_cells[_to_index(pos)] = {
		"occupied": true,
		"color_id": color_id,
		"color": color,
		"piece_id": piece_id,
		"metadata": metadata.duplicate(true)
	}
	return true


## Future Power-Up Hook (Hammer): Clears one occupied cell.
func clear_single_cell(pos: Vector2i) -> bool:
	if not is_within_bounds(pos):
		return false
	var idx := _to_index(pos)
	if not _cells[idx]["occupied"]:
		return false
	_cells[idx] = _create_empty_cell()
	return true


## Future Power-Up Hook (Row Blaster): Clears all occupied cells in a given row.
func clear_row_direct(row: int) -> Array[Vector2i]:
	var cleared: Array[Vector2i] = []
	if row < 0 or row >= BOARD_SIZE:
		return cleared
	for x in range(BOARD_SIZE):
		var pos := Vector2i(x, row)
		var idx := _to_index(pos)
		if _cells[idx]["occupied"]:
			_cells[idx] = _create_empty_cell()
			cleared.append(pos)
	return cleared


## Future Power-Up Hook (Mega Bomb): Clears all occupied cells on the board.
func clear_all_occupied() -> Array[Vector2i]:
	var cleared: Array[Vector2i] = []
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos := Vector2i(x, y)
			var idx := _to_index(pos)
			if _cells[idx]["occupied"]:
				_cells[idx] = _create_empty_cell()
				cleared.append(pos)
	return cleared


## Future Power-Up Hook (Mighty Hand): Moves an occupied cell to an empty destination cell.
func move_occupied_cell(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not is_within_bounds(from_pos) or not is_within_bounds(to_pos):
		return false
	var from_idx := _to_index(from_pos)
	var to_idx := _to_index(to_pos)
	if not _cells[from_idx]["occupied"] or _cells[to_idx]["occupied"]:
		return false
	_cells[to_idx] = _cells[from_idx].duplicate(true)
	_cells[from_idx] = _create_empty_cell()
	return true


## Creates a deep copy of the board model for AI / Difficulty Director simulation.
func clone() -> BoardModel:
	var copy := BoardModel.new()
	for i in range(TOTAL_CELLS):
		copy._cells[i] = {
			"occupied": _cells[i]["occupied"],
			"color_id": _cells[i]["color_id"],
			"color": _cells[i]["color"],
			"piece_id": _cells[i]["piece_id"],
			"metadata": (_cells[i]["metadata"] as Dictionary).duplicate(true)
		}
	return copy
