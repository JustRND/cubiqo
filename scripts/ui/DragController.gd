class_name DragController
extends Control
## Handles mouse and touch drag-and-drop with upward finger-offset, real-time board snap preview,
## smooth return animation on invalid drops, and multi-touch / double-drop protection.

const PICKUP_TWEEN_DURATION: float = 0.09
const RETURN_ANIM_DURATION: float = 0.17
const FINGER_OFFSET_CELL_MULTIPLIER: float = 2.1

var game_controller: GameController
var board_view: BoardView
var tray_slots: Array[TraySlotView] = []
var high_contrast: bool = false

var _tile_renderer: TileRenderer = TileRenderer.new()

var _is_dragging: bool = false
var _is_returning: bool = false
var _active_slot_index: int = -1
var _active_pointer_index: int = 0
var _active_piece: PieceDefinition = null

var _pointer_global_pos: Vector2 = Vector2.ZERO
var _pickup_progress: float = 0.0
var _return_progress: float = 0.0
var _return_start_center: Vector2 = Vector2.ZERO
var _return_target_center: Vector2 = Vector2.ZERO
var _start_cell_size: float = 28.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50


func setup(
	p_game_controller: GameController,
	p_board_view: BoardView,
	p_tray_slots: Array[TraySlotView]
) -> void:
	game_controller = p_game_controller
	board_view = p_board_view
	tray_slots = p_tray_slots
	for slot in tray_slots:
		if not slot.drag_requested.is_connected(_on_slot_drag_requested):
			slot.drag_requested.connect(_on_slot_drag_requested)


func set_high_contrast(enabled: bool) -> void:
	high_contrast = enabled
	queue_redraw()


func is_busy() -> bool:
	return _is_dragging or _is_returning


func cancel_active_drag() -> void:
	if _active_slot_index >= 0 and _active_slot_index < tray_slots.size():
		tray_slots[_active_slot_index].set_dragged_state(false)
	_is_dragging = false
	_is_returning = false
	_active_slot_index = -1
	_active_piece = null
	if board_view != null:
		board_view.clear_placement_preview()
	queue_redraw()


func _on_slot_drag_requested(slot_index: int, global_pointer_pos: Vector2, pointer_index: int) -> void:
	if _is_dragging or _is_returning:
		return
	if game_controller == null or not game_controller.can_accept_input():
		return
	var piece := game_controller.get_tray_piece(slot_index)
	if piece == null:
		return

	_is_dragging = true
	_is_returning = false
	_active_slot_index = slot_index
	_active_pointer_index = pointer_index
	_active_piece = piece
	_pointer_global_pos = global_pointer_pos
	_pickup_progress = 0.0

	if slot_index >= 0 and slot_index < tray_slots.size():
		_start_cell_size = tray_slots[slot_index].get_preview_cell_size()
		tray_slots[slot_index].set_dragged_state(true)

	_update_board_preview()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _is_dragging or _is_returning:
		return

	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _active_pointer_index:
			_pointer_global_pos = sd.position
			_update_board_preview()
			queue_redraw()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _active_pointer_index == 0:
			_pointer_global_pos = mm.global_position
			_update_board_preview()
			queue_redraw()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index == _active_pointer_index and not st.pressed:
			_pointer_global_pos = st.position
			_complete_drag_drop()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _active_pointer_index == 0:
			_pointer_global_pos = mb.global_position
			_complete_drag_drop()


func _process(delta: float) -> void:
	if _is_dragging and _pickup_progress < 1.0:
		_pickup_progress = minf(1.0, _pickup_progress + delta / PICKUP_TWEEN_DURATION)
		_update_board_preview()
		queue_redraw()
	elif _is_returning:
		_return_progress = minf(1.0, _return_progress + delta / RETURN_ANIM_DURATION)
		if _return_progress >= 1.0:
			_finish_return_animation()
		queue_redraw()


func _get_finger_offset() -> Vector2:
	if board_view == null:
		return Vector2(0.0, -140.0)
	var max_lift := board_view.get_cell_step() * FINGER_OFFSET_CELL_MULTIPLIER
	var eased := 1.0 - pow(1.0 - _pickup_progress, 3.0)
	return Vector2(0.0, -max_lift * eased)


func _get_active_visual_center_global() -> Vector2:
	if _is_returning:
		var eased := 1.0 - pow(1.0 - _return_progress, 3.0)
		return _return_start_center.lerp(_return_target_center, eased)
	return _pointer_global_pos + _get_finger_offset()


func _get_active_cell_size() -> float:
	var target_board_cell := board_view.get_cell_size() if board_view != null else 64.0
	if _is_returning:
		var eased := 1.0 - pow(1.0 - _return_progress, 3.0)
		return lerpf(target_board_cell, _start_cell_size, eased)
	var eased_pickup := 1.0 - pow(1.0 - _pickup_progress, 3.0)
	return lerpf(_start_cell_size, target_board_cell, eased_pickup)


func _update_board_preview() -> void:
	if board_view == null or _active_piece == null or not _is_dragging:
		return
	var snap := board_view.compute_snap_for_piece(_get_active_visual_center_global(), _active_piece)
	if bool(snap.get("in_range", false)) and bool(snap.get("valid", false)):
		board_view.set_placement_preview(_active_piece, snap["origin"], true)
	else:
		board_view.clear_placement_preview()


func _complete_drag_drop() -> void:
	if not _is_dragging or _active_piece == null:
		return

	if board_view != null:
		board_view.clear_placement_preview()

	var can_commit := false
	var snap_origin := Vector2i(-1, -1)
	var in_board_range := false

	if board_view != null and game_controller != null and game_controller.can_accept_input():
		var snap := board_view.compute_snap_for_piece(_get_active_visual_center_global(), _active_piece)
		in_board_range = bool(snap.get("in_range", false))
		snap_origin = snap.get("origin", Vector2i(-1, -1))
		can_commit = in_board_range and bool(snap.get("valid", false))

	if can_commit:
		var slot_idx := _active_slot_index
		_is_dragging = false
		_is_returning = false
		_active_slot_index = -1
		_active_piece = null
		queue_redraw()

		var result := game_controller.try_place_tray_piece(slot_idx, snap_origin)
		if not bool(result.get("success", false)):
			# Safety fallback if rejected
			if slot_idx >= 0 and slot_idx < tray_slots.size():
				tray_slots[slot_idx].set_dragged_state(false)
		return

	# Invalid drop -> play feedback if dropped over board and smoothly return to tray slot
	if in_board_range and board_view != null:
		board_view.play_invalid_drop_feedback()

	_return_start_center = _get_active_visual_center_global()
	if _active_slot_index >= 0 and _active_slot_index < tray_slots.size():
		_return_target_center = tray_slots[_active_slot_index].get_slot_center_global()
	else:
		_return_target_center = _pointer_global_pos

	_is_dragging = false
	_is_returning = true
	_return_progress = 0.0
	queue_redraw()


func _finish_return_animation() -> void:
	if _active_slot_index >= 0 and _active_slot_index < tray_slots.size():
		tray_slots[_active_slot_index].set_dragged_state(false)
	_is_returning = false
	_active_slot_index = -1
	_active_piece = null
	queue_redraw()


func _draw() -> void:
	if (not _is_dragging and not _is_returning) or _active_piece == null:
		return

	var center_local := _get_active_visual_center_global() - global_position
	var cell_px := _get_active_cell_size()
	var gap_px := maxf(2.0, cell_px * BoardView.CELL_GAP_RATIO)
	var step_px := cell_px + gap_px

	var bounds := _active_piece.get_bounding_size()
	var total_w := float(bounds.x) * cell_px + float(bounds.x - 1) * gap_px
	var total_h := float(bounds.y) * cell_px + float(bounds.y - 1) * gap_px
	var top_left := center_local - Vector2(total_w, total_h) * 0.5

	var base_col := _active_piece.get_display_color(high_contrast)
	for offset in _active_piece.cells:
		var cell_pos := top_left + Vector2(float(offset.x) * step_px, float(offset.y) * step_px)
		var rect := Rect2(cell_pos, Vector2(cell_px, cell_px))
		_tile_renderer.draw_block_tile(self, rect, base_col, 0.96, 1.0)
