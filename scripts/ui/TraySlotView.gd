class_name TraySlotView
extends Control
## Renders a single tray slot card and centered piece preview in the bottom 3-piece tray.

signal drag_requested(slot_index: int, global_pointer_pos: Vector2, pointer_index: int)

var slot_index: int = 0
var piece: PieceDefinition = null
var is_being_dragged: bool = false
var can_fit_on_board: bool = true
var high_contrast: bool = false

var _tile_renderer: TileRenderer = TileRenderer.new()
var _slot_box: StyleBoxFlat = StyleBoxFlat.new()


func _init(p_slot_index: int = 0) -> void:
	slot_index = p_slot_index
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_slot_box.bg_color = Color("#121D38")
	_slot_box.border_color = Color("#223460")
	_slot_box.set_border_width_all(2)
	_slot_box.corner_radius_top_left = 18
	_slot_box.corner_radius_top_right = 18
	_slot_box.corner_radius_bottom_left = 18
	_slot_box.corner_radius_bottom_right = 18


func set_piece(new_piece: PieceDefinition, fits: bool = true) -> void:
	piece = new_piece
	can_fit_on_board = fits
	is_being_dragged = false
	queue_redraw()


func set_dragged_state(dragged: bool) -> void:
	if is_being_dragged == dragged:
		return
	is_being_dragged = dragged
	queue_redraw()


func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	queue_redraw()


func get_slot_center_global() -> Vector2:
	return global_position + size * 0.5


func get_preview_cell_size() -> float:
	var min_dim := minf(size.x, size.y)
	return clampf(min_dim * 0.165, 16.0, 44.0)


func _gui_input(event: InputEvent) -> void:
	if piece == null or is_being_dragged:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			accept_event()
			drag_requested.emit(slot_index, global_position + touch.position, touch.index)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			drag_requested.emit(slot_index, mb.global_position, 0)


func _draw() -> void:
	draw_style_box(_slot_box, Rect2(Vector2.ZERO, size))

	if piece == null or is_being_dragged or piece.cells.is_empty():
		return

	var cell_px := get_preview_cell_size()
	var gap_px := maxf(2.0, cell_px * 0.08)
	var step_px := cell_px + gap_px

	var bounds := piece.get_bounding_size()
	var total_w := float(bounds.x) * cell_px + float(bounds.x - 1) * gap_px
	var total_h := float(bounds.y) * cell_px + float(bounds.y - 1) * gap_px
	var start_pos := (size - Vector2(total_w, total_h)) * 0.5

	var base_col := piece.get_display_color(high_contrast)
	var alpha := 1.0 if can_fit_on_board else 0.42

	for offset in piece.cells:
		var cell_pos := start_pos + Vector2(float(offset.x) * step_px, float(offset.y) * step_px)
		var rect := Rect2(cell_pos, Vector2(cell_px, cell_px))
		_tile_renderer.draw_block_tile(self, rect, base_col, alpha, 1.0)
