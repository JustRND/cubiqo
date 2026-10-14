class_name MainUI
extends Control
## Root mobile-first portrait UI controller for BLOKORA Phase 1.
## Coordinates the Top HUD, Centered 8x8 BoardView, 3-Piece Tray, Power-Up/Shop Placeholders,
## DragController, Game Over Modal, and Settings Modal.

var game_controller: GameController
var board_view: BoardView
var drag_controller: DragController
var tray_slots: Array[TraySlotView] = []

# Layout containers
var _safe_margin: MarginContainer
var _main_vbox: VBoxContainer
var _board_area_wrapper: Control

# Top HUD labels
var _score_value_label: Label
var _best_value_label: Label
var _combo_badge_panel: PanelContainer
var _combo_label: Label
var _level_label: Label
var _coins_label: Label

# Feedback toast / floating banner
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_timer: float = 0.0

# Game Over modal controls
var _game_over_overlay: ColorRect
var _go_final_score_label: Label
var _go_best_score_label: Label
var _go_new_best_label: Label
var _go_status_label: Label

# Settings modal controls
var _settings_overlay: ColorRect
var _sound_toggle: CheckButton
var _haptics_toggle: CheckButton
var _contrast_toggle: CheckButton

# Animated score display state
var _displayed_score: float = 0.0
var _target_score: int = 0


func _ready() -> void:
	if _safe_margin == null:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		_build_interface()
		_initialize_controller()
		resized.connect(_on_root_resized)
	_on_root_resized()


func _draw() -> void:
	# Rich deep navy background
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0A1124"), true)
	# Subtle upper atmospheric glow band
	var top_band := Rect2(Vector2.ZERO, Vector2(size.x, size.y * 0.42))
	draw_rect(top_band, Color(0.11, 0.19, 0.38, 0.25), true)


func _process(delta: float) -> void:
	if absf(_displayed_score - float(_target_score)) > 0.5:
		_displayed_score = lerpf(_displayed_score, float(_target_score), minf(1.0, delta * 14.0))
		if _score_value_label != null:
			_score_value_label.text = _format_number(roundi(_displayed_score))
	elif int(_displayed_score) != _target_score:
		_displayed_score = float(_target_score)
		if _score_value_label != null:
			_score_value_label.text = _format_number(_target_score)

	if _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_panel != null:
			if _toast_timer < 0.25:
				_toast_panel.modulate.a = _toast_timer / 0.25
			else:
				_toast_panel.modulate.a = 1.0
			if _toast_timer == 0.0:
				_toast_panel.visible = false


func _initialize_controller() -> void:
	game_controller = GameController.new()
	add_child(game_controller)

	board_view.bind_board(game_controller.board)
	drag_controller.setup(game_controller, board_view, tray_slots)

	# Connect signals
	game_controller.game_started.connect(_on_game_started)
	game_controller.tray_updated.connect(_on_tray_updated)
	game_controller.piece_placed.connect(_on_piece_placed)
	game_controller.lines_cleared.connect(_on_lines_cleared)
	game_controller.game_over_triggered.connect(_on_game_over_triggered)
	game_controller.placeholder_feature_requested.connect(_on_placeholder_feature_requested)
	game_controller.score_manager.score_changed.connect(_on_score_changed)
	game_controller.score_manager.combo_changed.connect(_on_combo_changed)
	board_view.clear_animation_finished.connect(_on_board_clear_animation_finished)

	# Apply saved settings
	var hc := bool(game_controller.save_manager.get_setting("high_contrast", false))
	_apply_high_contrast(hc)
	if _sound_toggle != null:
		_sound_toggle.button_pressed = bool(game_controller.save_manager.get_setting("sound_enabled", true))
	if _haptics_toggle != null:
		_haptics_toggle.button_pressed = bool(game_controller.save_manager.get_setting("haptics_enabled", true))
	if _contrast_toggle != null:
		_contrast_toggle.button_pressed = hc

	game_controller.start_new_game()


func _build_interface() -> void:
	_safe_margin = MarginContainer.new()
	_safe_margin.name = "SafeAreaMargin"
	_safe_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_safe_margin)

	_main_vbox = VBoxContainer.new()
	_main_vbox.name = "MainColumn"
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 18)
	_safe_margin.add_child(_main_vbox)

	_build_top_section(_main_vbox)
	_build_middle_board_section(_main_vbox)
	_build_bottom_section(_main_vbox)

	# Drag overlay above board and tray
	drag_controller = DragController.new()
	drag_controller.name = "DragController"
	add_child(drag_controller)

	# Modals above drag controller
	_build_game_over_modal()
	_build_settings_modal()


func _build_top_section(parent: VBoxContainer) -> void:
	var top_vbox := VBoxContainer.new()
	top_vbox.name = "TopSection"
	top_vbox.add_theme_constant_override("separation", 14)
	parent.add_child(top_vbox)

	# Row 1: Level Badge | Brand Title | Coins Pill | Settings Button
	var util_row := HBoxContainer.new()
	util_row.name = "TopUtilityBar"
	util_row.add_theme_constant_override("separation", 12)
	top_vbox.add_child(util_row)

	var level_pill := _create_styled_panel(Color("#152242"), Color("#273D72"), 14, 14, 8)
	_level_label = _create_label("LVL 1", 22, Color("#93C5FD"))
	level_pill.add_child(_level_label)
	util_row.add_child(level_pill)

	var brand_label := _create_label("BLOKORA", 32, Color("#F8FAFC"))
	brand_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	util_row.add_child(brand_label)

	var coin_pill := _create_styled_panel(Color("#152242"), Color("#273D72"), 14, 14, 8)
	_coins_label = _create_label("COINS: 0", 22, Color("#FBBF24"))
	coin_pill.add_child(_coins_label)
	util_row.add_child(coin_pill)

	var settings_btn := _create_styled_button("SET", 22, Color("#1E315C"), Color("#365396"), Vector2(88, 54))
	settings_btn.name = "SettingsButton"
	settings_btn.pressed.connect(_on_settings_button_pressed)
	util_row.add_child(settings_btn)

	# Row 2: Score & Best Score Cards + Combo Pill
	var score_row := HBoxContainer.new()
	score_row.name = "ScoreRow"
	score_row.add_theme_constant_override("separation", 16)
	top_vbox.add_child(score_row)

	# Current Score Card
	var score_card := _create_styled_panel(Color("#13203E"), Color("#263C70"), 18, 22, 14)
	score_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var score_vbox := VBoxContainer.new()
	score_vbox.add_theme_constant_override("separation", 4)
	var score_title_row := HBoxContainer.new()
	var score_title := _create_label("SCORE", 20, Color("#94A3B8"))
	score_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_title_row.add_child(score_title)

	_combo_badge_panel = _create_styled_panel(Color("#F59E0B"), Color("#FDE68A"), 10, 10, 2)
	_combo_badge_panel.visible = false
	_combo_label = _create_label("COMBO x2", 18, Color("#0F172A"))
	_combo_badge_panel.add_child(_combo_label)
	score_title_row.add_child(_combo_badge_panel)

	score_vbox.add_child(score_title_row)
	_score_value_label = _create_label("0", 48, Color("#FFFFFF"))
	score_vbox.add_child(_score_value_label)
	score_card.add_child(score_vbox)
	score_row.add_child(score_card)

	# Best Score Card
	var best_card := _create_styled_panel(Color("#13203E"), Color("#3B3561"), 18, 22, 14)
	best_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var best_vbox := VBoxContainer.new()
	best_vbox.add_theme_constant_override("separation", 4)
	var best_title := _create_label("BEST SCORE", 20, Color("#FBBF24"))
	best_vbox.add_child(best_title)
	_best_value_label = _create_label("0", 48, Color("#FDE68A"))
	best_vbox.add_child(_best_value_label)
	best_card.add_child(best_vbox)
	score_row.add_child(best_card)


func _build_middle_board_section(parent: VBoxContainer) -> void:
	_board_area_wrapper = Control.new()
	_board_area_wrapper.name = "BoardAreaWrapper"
	_board_area_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_area_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_area_wrapper.custom_minimum_size = Vector2(260, 260)
	_board_area_wrapper.resized.connect(_layout_square_board)
	parent.add_child(_board_area_wrapper)

	board_view = BoardView.new()
	board_view.name = "BoardView"
	_board_area_wrapper.add_child(board_view)

	# Floating feedback toast centered near top of board
	_toast_panel = _create_styled_panel(Color(0.08, 0.14, 0.28, 0.94), Color("#38BDF8"), 16, 20, 10)
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _create_label("", 24, Color("#F8FAFC"))
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_panel.add_child(_toast_label)
	_board_area_wrapper.add_child(_toast_panel)


func _build_bottom_section(parent: VBoxContainer) -> void:
	var bottom_vbox := VBoxContainer.new()
	bottom_vbox.name = "BottomSection"
	bottom_vbox.add_theme_constant_override("separation", 16)
	parent.add_child(bottom_vbox)

	# 1. Three-Piece Tray Container
	var tray_panel := _create_styled_panel(Color("#0E1830"), Color("#1E305A"), 22, 16, 16)
	tray_panel.custom_minimum_size = Vector2(0, 230)
	bottom_vbox.add_child(tray_panel)

	var tray_hbox := HBoxContainer.new()
	tray_hbox.name = "PieceTrayHBox"
	tray_hbox.add_theme_constant_override("separation", 16)
	tray_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tray_panel.add_child(tray_hbox)

	tray_slots.clear()
	for i in range(GameController.TRAY_SLOT_COUNT):
		var slot := TraySlotView.new(i)
		slot.name = "TraySlot_%d" % i
		slot.custom_minimum_size = Vector2(180, 196)
		tray_hbox.add_child(slot)
		tray_slots.append(slot)

	# 2. Power-up Toolbar Placeholders + Shop Button Placeholder
	var toolbar_hbox := HBoxContainer.new()
	toolbar_hbox.name = "BottomToolbar"
	toolbar_hbox.add_theme_constant_override("separation", 10)
	bottom_vbox.add_child(toolbar_hbox)

	var powerups: Array[Dictionary] = [
		{"id": "mega_bomb", "label": "BOMB"},
		{"id": "mighty_hand", "label": "HAND"},
		{"id": "hammer", "label": "HAMMER"},
		{"id": "row_blaster", "label": "ROW"},
		{"id": "tray_shuffle", "label": "SHUFFLE"}
	]

	for p_item in powerups:
		var p_id := String(p_item["id"])
		var btn := _create_styled_button(
			String(p_item["label"]),
			18,
			Color("#152242"),
			Color("#273B69"),
			Vector2(0, 64)
		)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func() -> void:
			if game_controller != null:
				game_controller.request_placeholder_powerup(p_id)
		)
		toolbar_hbox.add_child(btn)

	var shop_btn := _create_styled_button(
		"SHOP",
		20,
		Color("#2A1F4A"),
		Color("#7C3AED"),
		Vector2(130, 64)
	)
	shop_btn.name = "ShopPlaceholderButton"
	shop_btn.pressed.connect(func() -> void:
		if game_controller != null:
			game_controller.request_placeholder_shop()
	)
	toolbar_hbox.add_child(shop_btn)


func _build_game_over_modal() -> void:
	_game_over_overlay = ColorRect.new()
	_game_over_overlay.name = "GameOverOverlay"
	_game_over_overlay.color = Color(0.03, 0.06, 0.14, 0.84)
	_game_over_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.visible = false
	_game_over_overlay.z_index = 100
	add_child(_game_over_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_over_overlay.add_child(center)

	var card := _create_styled_panel(Color("#13203E"), Color("#3B82F6"), 26, 36, 34)
	card.custom_minimum_size = Vector2(640, 560)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	card.add_child(vbox)

	var title := _create_label("OUT OF MOVES", 44, Color("#F8FAFC"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_go_new_best_label = _create_label("NEW BEST SCORE!", 24, Color("#FBBF24"))
	_go_new_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_new_best_label.visible = false
	vbox.add_child(_go_new_best_label)

	var scores_box := _create_styled_panel(Color("#0D162C"), Color("#223560"), 18, 24, 20)
	var scores_vbox := VBoxContainer.new()
	scores_vbox.add_theme_constant_override("separation", 12)
	scores_box.add_child(scores_vbox)

	var final_title := _create_label("FINAL SCORE", 20, Color("#94A3B8"))
	final_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores_vbox.add_child(final_title)

	_go_final_score_label = _create_label("0", 54, Color("#FFFFFF"))
	_go_final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores_vbox.add_child(_go_final_score_label)

	var best_title := _create_label("BEST SCORE", 20, Color("#FBBF24"))
	best_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores_vbox.add_child(best_title)

	_go_best_score_label = _create_label("0", 36, Color("#FDE68A"))
	_go_best_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scores_vbox.add_child(_go_best_score_label)

	vbox.add_child(scores_box)

	_go_status_label = _create_label("", 20, Color("#93C5FD"))
	_go_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_go_status_label.visible = false
	vbox.add_child(_go_status_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var revive_btn := _create_styled_button(
		"REVIVE (SOON)",
		24,
		Color("#1E293B"),
		Color("#475569"),
		Vector2(0, 76)
	)
	revive_btn.name = "RevivePlaceholderButton"
	revive_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	revive_btn.pressed.connect(func() -> void:
		if game_controller != null:
			game_controller.request_placeholder_revive()
		_go_status_label.text = "Revive system unlocks in Phase 2 (no ads in Phase 1)."
		_go_status_label.visible = true
	)
	btn_row.add_child(revive_btn)

	var restart_btn := _create_styled_button(
		"PLAY AGAIN",
		26,
		Color("#059669"),
		Color("#34D399"),
		Vector2(0, 76)
	)
	restart_btn.name = "RestartButton"
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.pressed.connect(_on_restart_button_pressed)
	btn_row.add_child(restart_btn)


func _build_settings_modal() -> void:
	_settings_overlay = ColorRect.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.color = Color(0.03, 0.06, 0.14, 0.82)
	_settings_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	_settings_overlay.z_index = 105
	add_child(_settings_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(center)

	var card := _create_styled_panel(Color("#13203E"), Color("#2E4885"), 26, 34, 30)
	card.custom_minimum_size = Vector2(600, 480)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	card.add_child(vbox)

	var title := _create_label("SETTINGS", 38, Color("#F8FAFC"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_sound_toggle = CheckButton.new()
	_sound_toggle.text = "Sound Effects"
	_sound_toggle.add_theme_font_size_override("font_size", 24)
	_sound_toggle.toggled.connect(func(on: bool) -> void:
		if game_controller != null:
			game_controller.save_manager.set_setting("sound_enabled", on)
	)
	vbox.add_child(_sound_toggle)

	_haptics_toggle = CheckButton.new()
	_haptics_toggle.text = "Haptic Vibration"
	_haptics_toggle.add_theme_font_size_override("font_size", 24)
	_haptics_toggle.toggled.connect(func(on: bool) -> void:
		if game_controller != null:
			game_controller.save_manager.set_setting("haptics_enabled", on)
	)
	vbox.add_child(_haptics_toggle)

	_contrast_toggle = CheckButton.new()
	_contrast_toggle.text = "High-Contrast Blocks"
	_contrast_toggle.add_theme_font_size_override("font_size", 24)
	_contrast_toggle.toggled.connect(func(on: bool) -> void:
		if game_controller != null:
			game_controller.save_manager.set_setting("high_contrast", on)
		_apply_high_contrast(on)
	)
	vbox.add_child(_contrast_toggle)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var restart_btn := _create_styled_button("RESTART GAME", 22, Color("#1E3A8A"), Color("#3B82F6"), Vector2(0, 68))
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.pressed.connect(func() -> void:
		_settings_overlay.visible = false
		_on_restart_button_pressed()
	)
	btn_row.add_child(restart_btn)

	var close_btn := _create_styled_button("RESUME", 22, Color("#059669"), Color("#34D399"), Vector2(0, 68))
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void:
		_settings_overlay.visible = false
	)
	btn_row.add_child(close_btn)


# ---------------------------------------------------------------------------
# RESPONSIVE LAYOUT & SAFE AREA
# ---------------------------------------------------------------------------

func _on_root_resized() -> void:
	queue_redraw()
	if _safe_margin == null:
		return

	# Respect DisplayServer safe area margins on mobile while maintaining clean portrait padding
	var pad_x := maxf(24.0, size.x * 0.038)
	var pad_top := maxf(32.0, size.y * 0.025)
	var pad_bottom := maxf(28.0, size.y * 0.024)

	_safe_margin.add_theme_constant_override("margin_left", int(pad_x))
	_safe_margin.add_theme_constant_override("margin_right", int(pad_x))
	_safe_margin.add_theme_constant_override("margin_top", int(pad_top))
	_safe_margin.add_theme_constant_override("margin_bottom", int(pad_bottom))

	_layout_square_board()


func _layout_square_board() -> void:
	if _board_area_wrapper == null or board_view == null:
		return
	var avail := _board_area_wrapper.size
	var side := maxf(200.0, minf(avail.x, avail.y))
	board_view.size = Vector2(side, side)
	board_view.position = (avail - Vector2(side, side)) * 0.5
	board_view._recalculate_metrics()

	if _toast_panel != null:
		var toast_w := minf(side * 0.86, 560.0)
		_toast_panel.size = Vector2(toast_w, 56.0)
		_toast_panel.position = Vector2((avail.x - toast_w) * 0.5, board_view.position.y + 14.0)


## Synchronously applies a target viewport size for automated multi-resolution verification.
func apply_test_viewport_size(target_size: Vector2) -> void:
	if _board_area_wrapper == null:
		_build_interface()
		_initialize_controller()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = target_size
	_on_root_resized()
	var inner_w := maxf(240.0, target_size.x - 64.0)
	var inner_h := maxf(400.0, target_size.y - 540.0)
	_board_area_wrapper.size = Vector2(inner_w, inner_h)
	_layout_square_board()


# ---------------------------------------------------------------------------
# SIGNAL HANDLERS
# ---------------------------------------------------------------------------

func _on_game_started(new_tray: Array) -> void:
	if drag_controller != null:
		drag_controller.cancel_active_drag()
	if _game_over_overlay != null:
		_game_over_overlay.visible = false
	if _go_status_label != null:
		_go_status_label.visible = false

	_displayed_score = 0.0
	_target_score = 0
	if _score_value_label != null:
		_score_value_label.text = "0"
	if _best_value_label != null and game_controller != null:
		_best_value_label.text = _format_number(game_controller.score_manager.best_score)

	_on_tray_updated(new_tray)
	if board_view != null:
		board_view.queue_redraw()


func _on_tray_updated(current_tray: Array) -> void:
	for i in range(tray_slots.size()):
		var piece: PieceDefinition = current_tray[i] if i < current_tray.size() else null
		var fits := true
		if piece != null and game_controller != null:
			fits = PlacementRules.can_piece_fit_anywhere(game_controller.board, piece)
		tray_slots[i].set_piece(piece, fits)


func _on_piece_placed(
	_slot_index: int,
	_piece: PieceDefinition,
	_origin: Vector2i,
	tx_result: Dictionary,
	_score_breakdown: Dictionary
) -> void:
	if board_view != null:
		var placed_cells: Array[Vector2i] = tx_result["placed_cells"]
		board_view.play_placement_animation(placed_cells)


func _on_lines_cleared(
	cleared_rows: Array[int],
	cleared_cols: Array[int],
	_cleared_cells: Array[Vector2i],
	snapshots: Array[Dictionary],
	score_breakdown: Dictionary
) -> void:
	var total_lines := cleared_rows.size() + cleared_cols.size()
	var pts := int(score_breakdown.get("turn_total", 0))
	var combo := int(score_breakdown.get("combo_count", 1))

	var banner_text := "LINE CLEAR! +%d" % pts
	if total_lines == 2:
		banner_text = "DOUBLE CLEAR! +%d" % pts
	elif total_lines >= 3:
		banner_text = "MEGA %d-LINE CLEAR! +%d" % [total_lines, pts]
	if combo >= 2:
		banner_text += " (COMBO x%d!)" % combo

	_show_toast(banner_text, Color("#34D399"))

	if board_view != null and not snapshots.is_empty():
		if game_controller != null:
			game_controller.lock_for_transition()
		board_view.play_line_clear_animation(snapshots)


func _on_board_clear_animation_finished() -> void:
	if game_controller != null:
		game_controller.unlock_after_transition()


func _on_score_changed(current_score: int, best_score: int, _breakdown: Dictionary) -> void:
	_target_score = current_score
	if _best_value_label != null:
		_best_value_label.text = _format_number(best_score)


func _on_combo_changed(combo_count: int) -> void:
	if _combo_badge_panel == null or _combo_label == null:
		return
	if combo_count >= 1:
		_combo_badge_panel.visible = true
		_combo_label.text = "COMBO x%d" % combo_count
	else:
		_combo_badge_panel.visible = false


func _on_game_over_triggered(final_score: int, best_score: int) -> void:
	if drag_controller != null:
		drag_controller.cancel_active_drag()
	if _go_final_score_label != null:
		_go_final_score_label.text = _format_number(final_score)
	if _go_best_score_label != null:
		_go_best_score_label.text = _format_number(best_score)
	if _go_new_best_label != null:
		_go_new_best_label.visible = (final_score > 0 and final_score >= best_score)
	if _game_over_overlay != null:
		_game_over_overlay.visible = true


func _on_placeholder_feature_requested(_category: String, _feature_id: String, message: String) -> void:
	_show_toast(message, Color("#FBBF24"))


func _on_restart_button_pressed() -> void:
	if game_controller != null:
		game_controller.restart_game()


func _on_settings_button_pressed() -> void:
	if _settings_overlay != null:
		_settings_overlay.visible = true


func _apply_high_contrast(enabled: bool) -> void:
	if board_view != null:
		board_view.set_high_contrast(enabled)
	if drag_controller != null:
		drag_controller.set_high_contrast(enabled)
	for slot in tray_slots:
		slot.set_high_contrast(enabled)


func _show_toast(msg: String, border_color: Color = Color("#38BDF8")) -> void:
	if _toast_panel == null or _toast_label == null:
		return
	_toast_label.text = msg
	var sb := _toast_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if sb != null:
		sb.border_color = border_color
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_timer = 2.0


# ---------------------------------------------------------------------------
# UI FACTORY HELPERS
# ---------------------------------------------------------------------------

func _create_styled_panel(
	bg_col: Color,
	border_col: Color,
	radius: int,
	pad_h: int,
	pad_v: int
) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_col
	sb.border_color = border_col
	sb.set_border_width_all(2)
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	pc.add_theme_stylebox_override("panel", sb)
	return pc


func _create_styled_button(
	text_str: String,
	font_size: int,
	bg_col: Color,
	border_col: Color,
	min_size: Vector2
) -> Button:
	var btn := Button.new()
	btn.text = text_str
	btn.custom_minimum_size = min_size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", Color("#F8FAFC"))
	btn.add_theme_color_override("font_hover_color", Color("#FFFFFF"))
	btn.add_theme_color_override("font_pressed_color", Color("#E2E8F0"))

	var normal_sb := StyleBoxFlat.new()
	normal_sb.bg_color = bg_col
	normal_sb.border_color = border_col
	normal_sb.set_border_width_all(2)
	normal_sb.corner_radius_top_left = 14
	normal_sb.corner_radius_top_right = 14
	normal_sb.corner_radius_bottom_left = 14
	normal_sb.corner_radius_bottom_right = 14

	var hover_sb := normal_sb.duplicate() as StyleBoxFlat
	hover_sb.bg_color = bg_col.lightened(0.12)

	var pressed_sb := normal_sb.duplicate() as StyleBoxFlat
	pressed_sb.bg_color = bg_col.darkened(0.15)

	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	return btn


func _create_label(text_str: String, font_size: int, font_col: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text_str
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", font_col)
	return lbl


func _format_number(value: int) -> String:
	var s := str(abs(value))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = s[i] + out
		count += 1
	return ("-" + out) if value < 0 else out
