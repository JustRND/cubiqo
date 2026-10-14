class_name PlacementRules
extends RefCounted
## Stateless validation and legal-move evaluation rules for piece placement on a BoardModel.


## Returns true if `piece` can be legally placed at `origin` on `board`.
static func can_place_piece(board: BoardModel, piece: PieceDefinition, origin: Vector2i) -> bool:
	if board == null or piece == null or piece.cells.is_empty():
		return false
	return board.can_place(piece, origin)


## Returns true if any cell of `piece` placed at `origin` falls outside the 8x8 board boundaries.
static func is_out_of_bounds(board: BoardModel, piece: PieceDefinition, origin: Vector2i) -> bool:
	if board == null or piece == null or piece.cells.is_empty():
		return true
	for offset in piece.cells:
		if not board.is_within_bounds(origin + offset):
			return true
	return false


## Returns true if `piece` placed at `origin` is within bounds but overlaps at least one occupied cell.
static func has_collision(board: BoardModel, piece: PieceDefinition, origin: Vector2i) -> bool:
	if board == null or piece == null or piece.cells.is_empty():
		return false
	for offset in piece.cells:
		var target := origin + offset
		if board.is_within_bounds(target) and board.is_cell_occupied(target):
			return true
	return false


## Returns all legal board origin coordinates where `piece` can be placed.
static func get_valid_origins(board: BoardModel, piece: PieceDefinition) -> Array[Vector2i]:
	var valid_origins: Array[Vector2i] = []
	if board == null or piece == null or piece.cells.is_empty():
		return valid_origins

	var bounds := piece.get_bounding_size()
	var max_origin_x := BoardModel.BOARD_SIZE - bounds.x
	var max_origin_y := BoardModel.BOARD_SIZE - bounds.y
	if max_origin_x < 0 or max_origin_y < 0:
		return valid_origins

	for y in range(max_origin_y + 1):
		for x in range(max_origin_x + 1):
			var origin := Vector2i(x, y)
			if board.can_place(piece, origin):
				valid_origins.append(origin)

	return valid_origins


## Returns true if `piece` has at least one legal placement origin on `board`.
static func can_piece_fit_anywhere(board: BoardModel, piece: PieceDefinition) -> bool:
	if board == null or piece == null or piece.cells.is_empty():
		return false

	var bounds := piece.get_bounding_size()
	var max_origin_x := BoardModel.BOARD_SIZE - bounds.x
	var max_origin_y := BoardModel.BOARD_SIZE - bounds.y
	if max_origin_x < 0 or max_origin_y < 0:
		return false

	for y in range(max_origin_y + 1):
		for x in range(max_origin_x + 1):
			if board.can_place(piece, Vector2i(x, y)):
				return true
	return false


## Returns true if at least one non-null piece in `tray_pieces` can fit somewhere on `board`.
static func can_any_piece_fit(board: BoardModel, tray_pieces: Array) -> bool:
	if board == null or tray_pieces.is_empty():
		return false
	for entry in tray_pieces:
		if entry is PieceDefinition and can_piece_fit_anywhere(board, entry):
			return true
	return false


## Returns the total number of legal placement positions across all non-null pieces in `tray_pieces`.
## Used by the Difficulty Director extension hook to evaluate candidate tray playability.
static func count_available_moves_for_tray(board: BoardModel, tray_pieces: Array) -> int:
	if board == null or tray_pieces.is_empty():
		return 0
	var total_moves: int = 0
	for entry in tray_pieces:
		if entry is PieceDefinition:
			total_moves += get_valid_origins(board, entry).size()
	return total_moves
