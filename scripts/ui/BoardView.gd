class_name BoardView
extends Control
## Renders the 8x8 square puzzle board, ghost placement previews, line-completion highlights,
## and placement/clearing animations.

signal clear_animation_finished()

const BOARD_PADDING_RATIO: float = 0.032
const CELL_GAP_RATIO: float = 0.08
const CLEAR_ANIM_DURATION: float = 0.24
const PLACE_ANIM_DURATION: float = 0.14
const INVALID_FLASH_DURATION: float = 0.22

var board_model: BoardModel
var high_contrast: bool = false

var _tile_renderer: TileRenderer = TileRenderer.new()
var _frame_box: StyleBoxFlat = StyleBoxFlat.new()

# Computed geometry cache
var _grid_origin: Vector2 = Vector2.ZERO
var _cell_size: float = 64.0
var _cell_gap: float = 4.0
var _cell_step: float = 68.0

# Active ghost preview state
var _preview_active: bool = false
var _preview_valid: bool = false
var _preview_piece: PieceDefinition = null
var _preview_origin: Vector2i = Vector2i.ZERO
var _preview_clear_rows: Array[int] = []
var _preview_clear_cols: Array[int] = []

# Active animation states
var _placed_anim_cells: Array[Vector2i] = []
var _placed_anim_timer: float = 0.0
var _clearing_snapshots: Array[Dictionary] = []
var _clearing_anim_timer: float = 0.0
var _invalid_flash_timer: float = 0.0


func _init() -> void:
	_frame_box.bg_color = Color("#152242")
	_frame_box.border_color = Color("#283D70")
	_frame_box.set_border_width_all(3)
	_frame_box.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	_frame_box.shadow_size = 14
	_frame_box.shadow_offset = Vector2(0, 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	resized.connect(_recalculate_metrics)
	_recalculate_metrics()


func bind_board(model: BoardModel) -> void:
	board_model = model
	queue_redraw()


func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	queue_redraw()


func get_cell_size() -> float:
	return _cell_size


func get_cell_step() -> float:
	return _cell_step


func _recalculate_metrics() -> void:
	var side := minf(size.x, size.y)
	if side <= 10.0:
		return

	var pad := side * BOARD_PADDING_RATIO
	var inner_side := side - pad * 2.0
	# 8 cells + 7 gaps where gap = cell_size * CELL_GAP_RATIO
	_cell_size = inner_side / (float(BoardModel.BOARD_SIZE) + float(BoardModel.BOARD_SIZE - 1) * CELL_GAP_RATIO)
	_cell_gap = _cell_size * CELL_GAP_RATIO
	_cell_step = _cell_size + _cell_gap

	var total_grid_px := _cell_size * float(BoardModel.BOARD_SIZE) + _cell_gap * float(BoardModel.BOARD_SIZE - 1)
	_grid_origin = (size - Vector2(total_grid_px, total_grid_px)) * 0.5

	var frame_radius := maxi(10, int(side * 0.038))
	_frame_box.corner_radius_top_left = frame_radius
	_frame_box.corner_radius_top_right = frame_radius
	_frame_box.corner_radius_bottom_left = frame_radius
	_frame_box.corner_radius_bottom_right = frame_radius
	queue_redraw()


func _process(delta: float) -> void:
	var needs_redraw := false

	if _placed_anim_timer > 0.0:
		_placed_anim_timer = maxf(0.0, _placed_anim_timer - delta)
		if _placed_anim_timer == 0.0:
			_placed_anim_cells.clear()
		needs_redraw = true

	if _clearing_anim_timer > 0.0:
		_clearing_anim_timer = maxf(0.0, _clearing_anim_timer - delta)
		if _clearing_anim_timer == 0.0:
			_clearing_snapshots.clear()
			clear_animation_finished.emit()
		needs_redraw = true

	if _invalid_flash_timer > 0.0:
		_invalid_flash_timer = maxf(0.0, _invalid_flash_timer - delta)
		needs_redraw = true

	if needs_redraw:
		queue_redraw()


## Computes the snapped grid origin for a piece whose visual center is at `global_piece_center`.
## Returns `{"in_range": bool, "origin": Vector2i, "valid": bool}`.
func compute_snap_for_piece(global_piece_center: Vector2, piece: PieceDefinition) -> Dictionary:
	if board_model == null or piece == null or _cell_step <= 1.0:
		return {"in_range": false, "origin": Vector2i(-1, -1), "valid": false}

	var local_center := global_piece_center - global_position - _grid_origin
	var raw_origin := (local_center / _cell_step) - piece.get_center_offset()
	var snapped_origin := Vector2i(roundi(raw_origin.x), roundi(raw_origin.y))

	var bounds := piece.get_bounding_size()
	var margin_cells := 1.15
	var in_board_vicinity := (
		raw_origin.x >= -margin_cells
		and raw_origin.y >= -margin_cells
		and (raw_origin.x + float(bounds.x)) <= float(BoardModel.BOARD_SIZE) + margin_cells
		and (raw_origin.y + float(bounds.y)) <= float(BoardModel.BOARD_SIZE) + margin_cells
	)

	if not in_board_vicinity:
		return {"in_range": false, "origin": snapped_origin, "valid": false}

	var is_valid := board_model.can_place(piece, snapped_origin)
	return {
		"in_range": true,
		"origin": snapped_origin,
		"valid": is_valid
	}


## Updates the active placement preview while dragging.
func set_placement_preview(piece: PieceDefinition, origin: Vector2i, is_valid: bool) -> void:
	_preview_active = piece != null
	_preview_piece = piece
	_preview_origin = origin
	_preview_valid = is_valid
	_preview_clear_rows.clear()
	_preview_clear_cols.clear()

	if _preview_active and _preview_valid and board_model != null:
		var preview_data := board_model.preview_placement(piece, origin)
		if bool(preview_data.get("valid", false)):
			_preview_clear_rows = preview_data["would_clear_rows"]
			_preview_clear_cols = preview_data["would_clear_cols"]

	queue_redraw()


func clear_placement_preview() -> void:
	if not _preview_active:
		return
	_preview_active = false
	_preview_piece = null
	_preview_clear_rows.clear()
	_preview_clear_cols.clear()
	queue_redraw()


func play_placement_animation(placed_cells: Array[Vector2i]) -> void:
	_placed_anim_cells = placed_cells.duplicate()
	_placed_anim_timer = PLACE_ANIM_DURATION
	queue_redraw()


func play_line_clear_animation(snapshots: Array[Dictionary]) -> void:
	if snapshots.is_empty():
		clear_animation_finished.emit()
		return
	_clearing_snapshots = snapshots.duplicate(true)
	_clearing_anim_timer = CLEAR_ANIM_DURATION
	queue_redraw()


func play_invalid_drop_feedback() -> void:
	_invalid_flash_timer = INVALID_FLASH_DURATION
	queue_redraw()


func is_animating_clear() -> bool:
	return _clearing_anim_timer > 0.0


func _get_cell_rect(x: int, y: int) -> Rect2:
	var pos := _grid_origin + Vector2(float(x) * _cell_step, float(y) * _cell_step)
	return Rect2(pos, Vector2(_cell_size, _cell_size))


func _resolve_color(color_id: String, fallback: Color) -> Color:
	if high_contrast and PieceDefinition.HIGH_CONTRAST_PALETTE.has(color_id):
		return PieceDefinition.HIGH_CONTRAST_PALETTE[color_id]
	if PieceDefinition.PALETTE.has(color_id):
		return PieceDefinition.PALETTE[color_id]
	return fallback


func _draw() -> void:
	var side := minf(size.x, size.y)
	if side <= 10.0:
		return

	var board_rect := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	if _invalid_flash_timer > 0.0:
		var t := _invalid_flash_timer / INVALID_FLASH_DURATION
		_frame_box.border_color = Color("#283D70").lerp(Color("#F43F5E"), t)
	else:
		_frame_box.border_color = Color("#283D70")

	draw_style_box(_frame_box, board_rect)

	# 1. Draw all 64 recessed empty cells and occupied blocks
	var placed_lookup: Dictionary = {}
	if _placed_anim_timer > 0.0:
		for p in _placed_anim_cells:
			placed_lookup[p] = true

	var place_scale := 1.0
	if _placed_anim_timer > 0.0:
		var progress := 1.0 - (_placed_anim_timer / PLACE_ANIM_DURATION)
		place_scale = 0.84 + 0.16 * sin(progress * PI * 0.5)

	for y in range(BoardModel.BOARD_SIZE):
		for x in range(BoardModel.BOARD_SIZE):
			var cell_rect := _get_cell_rect(x, y)
			_tile_renderer.draw_empty_cell(self, cell_rect)

			if board_model != null:
				var cell := board_model.get_cell_fast(x, y)
				if bool(cell["occupied"]):
					var col := _resolve_color(String(cell["color_id"]), cell["color"])
					var pos_vec := Vector2i(x, y)
					var s := place_scale if placed_lookup.has(pos_vec) else 1.0
					_tile_renderer.draw_block_tile(self, cell_rect, col, 1.0, s)

	# 2. Draw ghost placement preview
	if _preview_active and _preview_piece != null:
		if _preview_valid:
			var ghost_col := _preview_piece.get_display_color(high_contrast)
			for offset in _preview_piece.cells:
				var target := _preview_origin + offset
				if target.x >= 0 and target.x < BoardModel.BOARD_SIZE and target.y >= 0 and target.y < BoardModel.BOARD_SIZE:
					_tile_renderer.draw_ghost_tile(self, _get_cell_rect(target.x, target.y), ghost_col)

			# Highlight full rows/cols that will clear upon drop
			for r in _preview_clear_rows:
				for x in range(BoardModel.BOARD_SIZE):
					_tile_renderer.draw_line_clear_preview_overlay(self, _get_cell_rect(x, r))
			for c in _preview_clear_cols:
				for y in range(BoardModel.BOARD_SIZE):
					_tile_renderer.draw_line_clear_preview_overlay(self, _get_cell_rect(c, y))

	# 3. Draw active line-clearing burst animations
	if _clearing_anim_timer > 0.0 and not _clearing_snapshots.is_empty():
		var progress := 1.0 - (_clearing_anim_timer / CLEAR_ANIM_DURATION)
		var alpha := clampf(1.0 - progress, 0.0, 1.0)
		var shrink_scale := lerpf(1.08, 0.22, progress)
		for snap in _clearing_snapshots:
			var pos: Vector2i = snap["pos"]
			var base_col := _resolve_color(String(snap.get("color_id", "")), snap.get("color", Color.WHITE))
			var flash_col := base_col.lerp(Color.WHITE, 0.55 * (1.0 - progress))
			_tile_renderer.draw_block_tile(self, _get_cell_rect(pos.x, pos.y), flash_col, alpha, shrink_scale)
