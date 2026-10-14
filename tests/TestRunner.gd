extends SceneTree
## Headless automated test suite for BLOKORA Phase 1.
## Run via: Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/TestRunner.gd

var _passed_count: int = 0
var _failed_count: int = 0
var _results: Array[Dictionary] = []

const TEST_SAVE_PATH: String = "user://blokora_test_save.json"


func _init() -> void:
	print("============================================================")
	print("BLOKORA PHASE 1 — AUTOMATED TEST SUITE")
	print("Engine: Godot %s" % Engine.get_version_info()["string"])
	print("============================================================")

	_run_test("01. Legal placement on an empty board", _test_01_legal_placement_empty_board)
	_run_test("02. Rejection of overlapping pieces", _test_02_reject_overlapping_pieces)
	_run_test("03. Rejection of out-of-bounds placements", _test_03_reject_out_of_bounds)
	_run_test("04. Invalid placement does not change board state", _test_04_invalid_placement_preserves_board)
	_run_test("05. Horizontal line clearing", _test_05_horizontal_line_clearing)
	_run_test("06. Vertical line clearing", _test_06_vertical_line_clearing)
	_run_test("07. Simultaneous row and column clearing", _test_07_simultaneous_row_and_col_clearing)
	_run_test("08. Correct scoring calculations", _test_08_scoring_calculations)
	_run_test("09. Correct combo reset behavior", _test_09_combo_reset_behavior)
	_run_test("10. Piece consumption after valid placement", _test_10_piece_consumption)
	_run_test("11. Tray refill after all pieces are consumed", _test_11_tray_refill)
	_run_test("12. Game-over detection", _test_12_game_over_detection)
	_run_test("13. Restart behavior", _test_13_restart_behavior)
	_run_test("14. Deterministic piece generation using a fixed seed", _test_14_deterministic_seed_generation)
	_run_test("15. Best-score persistence", _test_15_best_score_persistence)
	_run_test("16. Corrupted save-file handling", _test_16_corrupted_save_handling)
	_run_test("17. Piece shape validity (>= 12 shapes + required shapes)", _test_17_piece_shape_validity)
	_run_test("18. Prevention of duplicate placement", _test_18_prevent_duplicate_placement)
	_run_test("19. Correct game-state transitions", _test_19_game_state_transitions)
	_run_test("20. No regression in core board rules after animations", _test_20_no_regression_after_animations)
	_run_test("21. Multi-viewport UI & runtime smoke verification", _test_21_ui_and_viewport_smoke)

	_cleanup_test_files()

	print("------------------------------------------------------------")
	print("TOTAL: %d | PASSED: %d | FAILED: %d" % [_passed_count + _failed_count, _passed_count, _failed_count])
	print("============================================================")

	if _failed_count > 0:
		quit(1)
	else:
		quit(0)


func _run_test(test_name: String, callable_fn: Callable) -> void:
	var result: Variant = callable_fn.call()
	var ok: bool = false
	var detail: String = "OK"
	if result is bool:
		ok = result
		detail = "OK" if ok else "Assertion failed"
	elif result is Dictionary:
		ok = bool(result.get("ok", false))
		detail = String(result.get("detail", ""))

	if ok:
		_passed_count += 1
		print("[PASS] %s — %s" % [test_name, detail])
	else:
		_failed_count += 1
		print("[FAIL] %s — %s" % [test_name, detail])

	_results.append({
		"name": test_name,
		"passed": ok,
		"detail": detail
	})


func _cleanup_test_files() -> void:
	if FileAccess.file_exists(TEST_SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))


# ---------------------------------------------------------------------------
# TEST IMPLEMENTATIONS
# ---------------------------------------------------------------------------

func _test_01_legal_placement_empty_board() -> Dictionary:
	var board := BoardModel.new()
	var gen := PieceGenerator.new(100)
	var piece := gen.get_piece_by_id("square_2x2")
	var tx := board.place_piece(piece, Vector2i(3, 3), {"special": "none"})
	if not bool(tx["success"]):
		return {"ok": false, "detail": "2x2 square failed to place at (3,3) on empty board"}
	if board.get_occupied_count() != 4:
		return {"ok": false, "detail": "Expected 4 occupied cells, got %d" % board.get_occupied_count()}
	for offset in piece.cells:
		var pos := Vector2i(3, 3) + offset
		if not board.is_cell_occupied(pos):
			return {"ok": false, "detail": "Cell %s was not marked occupied" % str(pos)}
		var cell_data := board.get_cell(pos)
		if cell_data["color_id"] != piece.color_id or cell_data["metadata"].get("special") != "none":
			return {"ok": false, "detail": "Cell metadata/color mismatch at %s" % str(pos)}
	return {"ok": true, "detail": "2x2 piece placed at (3,3); 4 cells occupied with color & metadata intact"}


func _test_02_reject_overlapping_pieces() -> Dictionary:
	var board := BoardModel.new()
	var gen := PieceGenerator.new(101)
	var p1 := gen.get_piece_by_id("square_2x2")
	var p2 := gen.get_piece_by_id("line_h3")
	board.place_piece(p1, Vector2i(2, 2))
	var tx := board.place_piece(p2, Vector2i(1, 2)) # Overlaps (2,2) and (3,2)
	if bool(tx["success"]) or tx["reason"] != "cell_occupied":
		return {"ok": false, "detail": "Overlapping placement was not rejected with cell_occupied"}
	if not PlacementRules.has_collision(board, p2, Vector2i(1, 2)):
		return {"ok": false, "detail": "PlacementRules.has_collision returned false on overlap"}
	return {"ok": true, "detail": "Overlapping placement rejected with reason 'cell_occupied'"}


func _test_03_reject_out_of_bounds() -> Dictionary:
	var board := BoardModel.new()
	var gen := PieceGenerator.new(102)
	var h4 := gen.get_piece_by_id("line_h4")
	var v4 := gen.get_piece_by_id("line_v4")

	var tx_neg := board.place_piece(h4, Vector2i(-1, 0))
	var tx_right := board.place_piece(h4, Vector2i(6, 0)) # 6..9 exceeds 0..7
	var tx_bottom := board.place_piece(v4, Vector2i(0, 6)) # 6..9 exceeds 0..7

	if bool(tx_neg["success"]) or bool(tx_right["success"]) or bool(tx_bottom["success"]):
		return {"ok": false, "detail": "Out-of-bounds placement unexpectedly succeeded"}
	if tx_right["reason"] != "out_of_bounds" or tx_bottom["reason"] != "out_of_bounds":
		return {"ok": false, "detail": "Expected reason 'out_of_bounds'"}
	return {"ok": true, "detail": "Negative, right-edge, and bottom-edge overflows rejected cleanly"}


func _test_04_invalid_placement_preserves_board() -> Dictionary:
	var board := BoardModel.new()
	var gen := PieceGenerator.new(103)
	var sq := gen.get_piece_by_id("square_2x2")
	var l_piece := gen.get_piece_by_id("l_shape")
	board.place_piece(sq, Vector2i(4, 4))

	# Attempt placement where first two cells (4,2), (4,3) are empty, but (4,4) is occupied
	var tx := board.place_piece(l_piece, Vector2i(4, 2))
	if bool(tx["success"]):
		return {"ok": false, "detail": "Partial overlap placement should have failed"}
	if board.get_occupied_count() != 4:
		return {"ok": false, "detail": "Board occupied count changed from 4 to %d" % board.get_occupied_count()}
	if board.is_cell_occupied(Vector2i(4, 2)) or board.is_cell_occupied(Vector2i(4, 3)):
		return {"ok": false, "detail": "Partial cells were left behind after failed placement"}
	return {"ok": true, "detail": "Board state remained 100% unchanged after rejected placement"}


func _test_05_horizontal_line_clearing() -> Dictionary:
	var board := BoardModel.new()
	var gen := PieceGenerator.new(104)
	for x in range(5):
		board.set_cell_occupied(Vector2i(x, 5), "amber")
	board.set_cell_occupied(Vector2i(2, 1), "cyan")

	var h3 := gen.get_piece_by_id("line_h3")
	var tx := board.place_piece(h3, Vector2i(5, 5))
	if not bool(tx["success"]):
		return {"ok": false, "detail": "Failed to place completing h3 piece"}
	var cleared_rows: Array[int] = tx["cleared_rows"]
	if cleared_rows.size() != 1 or cleared_rows[0] != 5:
		return {"ok": false, "detail": "Expected row 5 cleared, got %s" % str(cleared_rows)}
	if board.get_occupied_count() != 1 or not board.is_cell_occupied(Vector2i(2, 1)):
		return {"ok": false, "detail": "Row 5 did not clear cleanly or unrelated cell was altered"}
	return {"ok": true, "detail": "Row 5 cleared all 8 cells; unrelated cell at (2,1) preserved"}


func _test_06_vertical_line_clearing() -> Dictionary:
	var board := BoardModel.new()
	var gen := PieceGenerator.new(105)
	for y in range(5):
		board.set_cell_occupied(Vector2i(3, y), "emerald")

	var v3 := gen.get_piece_by_id("line_v3")
	var tx := board.place_piece(v3, Vector2i(3, 5))
	if not bool(tx["success"]):
		return {"ok": false, "detail": "Failed to place completing v3 piece"}
	var cleared_cols: Array[int] = tx["cleared_cols"]
	if cleared_cols.size() != 1 or cleared_cols[0] != 3:
		return {"ok": false, "detail": "Expected col 3 cleared, got %s" % str(cleared_cols)}
	if board.get_occupied_count() != 0:
		return {"ok": false, "detail": "Expected 0 occupied cells after col clear, got %d" % board.get_occupied_count()}
	return {"ok": true, "detail": "Column 3 cleared all 8 cells"}


func _test_07_simultaneous_row_and_col_clearing() -> Dictionary:
	var board := BoardModel.new()
	var gen := PieceGenerator.new(106)
	for i in range(8):
		if i != 4:
			board.set_cell_occupied(Vector2i(i, 4), "coral")
			board.set_cell_occupied(Vector2i(4, i), "indigo")

	var single := gen.get_piece_by_id("single_1x1")
	var tx := board.place_piece(single, Vector2i(4, 4))
	if not bool(tx["success"]):
		return {"ok": false, "detail": "Failed to place intersection piece at (4,4)"}

	var rows: Array[int] = tx["cleared_rows"]
	var cols: Array[int] = tx["cleared_cols"]
	var cleared_cells: Array[Vector2i] = tx["cleared_cells"]

	if rows.size() != 1 or cols.size() != 1:
		return {"ok": false, "detail": "Expected 1 row and 1 col cleared simultaneously"}
	if cleared_cells.size() != 15:
		return {"ok": false, "detail": "Expected 15 deduplicated cleared cells, got %d" % cleared_cells.size()}
	if board.get_occupied_count() != 0:
		return {"ok": false, "detail": "Board should be empty after simultaneous clear"}
	return {"ok": true, "detail": "1 row + 1 col counted; intersecting cell (4,4) removed once (15 total cells)"}


func _test_08_scoring_calculations() -> Dictionary:
	var sm := ScoreManager.new(0)

	var b1 := sm.calculate_turn_score(4, 0, 0, 0)
	if int(b1["turn_total"]) != 40:
		return {"ok": false, "detail": "Expected 40 pts for 4-cell placement, got %d" % int(b1["turn_total"])}

	var b2 := sm.calculate_turn_score(3, 1, 0, 0)
	if int(b2["turn_total"]) != 130:
		return {"ok": false, "detail": "Expected 130 pts for 3 cells + 1 row, got %d" % int(b2["turn_total"])}

	var b3 := sm.calculate_turn_score(1, 1, 1, 0)
	if int(b3["turn_total"]) != 260 or int(b3["multi_line_bonus"]) != 50:
		return {"ok": false, "detail": "Expected 260 pts (50 bonus) for 2 lines, got %d" % int(b3["turn_total"])}

	var b4 := sm.calculate_turn_score(4, 2, 1, 0)
	if int(b4["turn_total"]) != 490 or int(b4["multi_line_bonus"]) != 150:
		return {"ok": false, "detail": "Expected 490 pts (150 bonus) for 3 lines, got %d" % int(b4["turn_total"])}

	return {"ok": true, "detail": "Verified +10/cell, +100/row, +100/col, +50 (2 lines), +150 (3+ lines)"}


func _test_09_combo_reset_behavior() -> Dictionary:
	var sm := ScoreManager.new(0)
	sm.record_turn(2, 1, 0)
	if sm.combo_count != 1:
		return {"ok": false, "detail": "Expected combo 1 after first clear, got %d" % sm.combo_count}
	var t2 := sm.record_turn(2, 0, 1)
	if sm.combo_count != 2 or int(t2["combo_bonus"]) <= 0:
		return {"ok": false, "detail": "Expected combo 2 and positive combo bonus on consecutive clear"}
	sm.record_turn(3, 0, 0)
	if sm.combo_count != 0:
		return {"ok": false, "detail": "Expected combo to reset to 0 on non-clearing turn, got %d" % sm.combo_count}
	return {"ok": true, "detail": "Combo incremented to 2 on consecutive clears and reset to 0 on non-clearing turn"}


func _test_10_piece_consumption() -> Dictionary:
	_cleanup_test_files()
	var gc := GameController.new(TEST_SAVE_PATH, 42)
	gc.start_new_game(42)
	var p0 := gc.piece_generator.get_piece_by_id("single_1x1")
	var p1 := gc.piece_generator.get_piece_by_id("line_h2")
	var p2 := gc.piece_generator.get_piece_by_id("line_v2")
	gc.set_tray_pieces([p0, p1, p2])

	var res := gc.try_place_tray_piece(1, Vector2i(0, 0))
	var slot_1_after := gc.get_tray_piece(1)
	var remaining := gc.get_remaining_tray_count()
	gc.free()

	if not bool(res["success"]):
		return {"ok": false, "detail": "Failed to place tray slot 1"}
	if slot_1_after != null:
		return {"ok": false, "detail": "Consumed tray slot 1 is not null"}
	if remaining != 2:
		return {"ok": false, "detail": "Expected 2 remaining tray pieces, got %d" % remaining}
	return {"ok": true, "detail": "Placed slot 1 disappeared; 2 pieces remain in tray"}


func _test_11_tray_refill() -> Dictionary:
	_cleanup_test_files()
	var gc := GameController.new(TEST_SAVE_PATH, 77)
	gc.start_new_game(77)
	var p := gc.piece_generator.get_piece_by_id("single_1x1")
	gc.set_tray_pieces([p.duplicate_piece(), p.duplicate_piece(), p.duplicate_piece()])

	gc.try_place_tray_piece(0, Vector2i(0, 0))
	gc.try_place_tray_piece(2, Vector2i(2, 0))
	var rem_before := gc.get_remaining_tray_count()
	gc.try_place_tray_piece(1, Vector2i(4, 0))
	var rem_after := gc.get_remaining_tray_count()
	gc.free()

	if rem_before != 1:
		return {"ok": false, "detail": "Expected 1 piece before final consumption"}
	if rem_after != 3:
		return {"ok": false, "detail": "Expected tray to refill to 3 pieces, got %d" % rem_after}
	return {"ok": true, "detail": "Tray automatically refilled with 3 new pieces after all 3 were placed"}


func _test_12_game_over_detection() -> Dictionary:
	_cleanup_test_files()
	var gc := GameController.new(TEST_SAVE_PATH, 88)
	gc.start_new_game(88)

	for y in range(8):
		for x in range(8):
			if (x + y) % 2 == 0:
				gc.board.set_cell_occupied(Vector2i(x, y), "amber")

	var single := gc.piece_generator.get_piece_by_id("single_1x1")
	var sq2 := gc.piece_generator.get_piece_by_id("square_2x2")
	gc.set_tray_pieces([single, sq2, null])

	var state_before := gc.state
	var res := gc.try_place_tray_piece(0, Vector2i(0, 1))
	var state_after := gc.state
	gc.free()

	if state_before != GameController.GameState.PLAYING:
		return {"ok": false, "detail": "Game should remain PLAYING while single_1x1 can fit"}
	if not bool(res["success"]):
		return {"ok": false, "detail": "Placement of single_1x1 failed"}
	if state_after != GameController.GameState.GAME_OVER:
		return {"ok": false, "detail": "Expected GAME_OVER when remaining 2x2 piece has no valid moves"}
	return {"ok": true, "detail": "Game over accurately triggered when remaining 2x2 piece had 0 legal moves"}


func _test_13_restart_behavior() -> Dictionary:
	_cleanup_test_files()
	var gc := GameController.new(TEST_SAVE_PATH, 99)
	gc.start_new_game(99)
	var sq := gc.piece_generator.get_piece_by_id("square_2x2")
	gc.set_tray_pieces([sq, sq.duplicate_piece(), sq.duplicate_piece()])
	gc.try_place_tray_piece(0, Vector2i(0, 0))

	var best_before := gc.score_manager.best_score
	gc.restart_game(99)

	var ok_state := (gc.state == GameController.GameState.PLAYING)
	var ok_board := (gc.board.get_occupied_count() == 0)
	var ok_score := (gc.score_manager.current_score == 0 and gc.score_manager.combo_count == 0)
	var ok_best := (gc.score_manager.best_score == best_before and best_before > 0)
	var ok_tray := (gc.get_remaining_tray_count() == 3)
	gc.free()

	if not ok_state or not ok_board or not ok_score or not ok_best or not ok_tray:
		return {"ok": false, "detail": "Restart state validation failed"}
	return {"ok": true, "detail": "Restart cleared board, reset score/combo, refilled tray, preserved best score"}


func _test_14_deterministic_seed_generation() -> Dictionary:
	var gen_a := PieceGenerator.new(123456)
	var gen_b := PieceGenerator.new(123456)

	var seq_a: Array[String] = []
	var seq_b: Array[String] = []
	for _i in range(15):
		seq_a.append(gen_a.generate_piece().id)
		seq_b.append(gen_b.generate_piece().id)

	if seq_a != seq_b:
		return {"ok": false, "detail": "Seeded generators produced different sequences"}
	return {"ok": true, "detail": "Fixed seed 123456 generated identical 15-piece sequences (%s...)" % seq_a[0]}


func _test_15_best_score_persistence() -> Dictionary:
	_cleanup_test_files()
	var gc1 := GameController.new(TEST_SAVE_PATH, 500)
	gc1.start_new_game(500)
	var h5 := gc1.piece_generator.get_piece_by_id("line_h5")
	gc1.set_tray_pieces([h5, null, null])
	gc1.try_place_tray_piece(0, Vector2i(0, 0)) # 50 points

	var saved_best := gc1.score_manager.best_score
	gc1.free()

	if saved_best != 50:
		return {"ok": false, "detail": "Expected best score 50, got %d" % saved_best}

	var sm_reloaded := SaveManager.new(TEST_SAVE_PATH)
	if sm_reloaded.get_best_score() != 50:
		return {"ok": false, "detail": "Reloaded SaveManager returned %d instead of 50" % sm_reloaded.get_best_score()}
	return {"ok": true, "detail": "Best score (50) persisted to disk and reloaded in new SaveManager instance"}


func _test_16_corrupted_save_handling() -> Dictionary:
	_cleanup_test_files()
	var f := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f.store_string("{corrupted_json: [1, 2, }")
	f.close()

	var sm := SaveManager.new(TEST_SAVE_PATH)
	if not sm.was_corrupted or sm.get_best_score() != 0:
		return {"ok": false, "detail": "SaveManager did not recover from malformed JSON"}

	var f2 := FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	f2.store_string('{"version": 1, "best_score": -999}')
	f2.close()
	var sm2 := SaveManager.new(TEST_SAVE_PATH)
	if not sm2.was_corrupted or sm2.get_best_score() != 0:
		return {"ok": false, "detail": "Negative best_score schema corruption was not caught"}

	return {"ok": true, "detail": "Malformed JSON and negative schema values recovered cleanly to defaults"}


func _test_17_piece_shape_validity() -> Dictionary:
	var catalog := PieceDefinition.create_default_catalog()
	if catalog.size() < 12:
		return {"ok": false, "detail": "Expected at least 12 shapes, got %d" % catalog.size()}

	var required_ids: Array[String] = [
		"single_1x1", "line_h2", "line_h3", "line_h4", "line_h5",
		"line_v2", "line_v3", "line_v4", "square_2x2",
		"l_shape", "t_shape", "z_shape"
	]
	var found_ids: Dictionary = {}
	for piece in catalog:
		if not piece.is_valid_definition():
			return {"ok": false, "detail": "Invalid piece definition for %s" % piece.id}
		found_ids[piece.id] = true

	for req in required_ids:
		if not found_ids.has(req):
			return {"ok": false, "detail": "Missing required shape ID: %s" % req}

	return {"ok": true, "detail": "%d valid data-driven shapes verified (all 12 required shapes present)" % catalog.size()}


func _test_18_prevent_duplicate_placement() -> Dictionary:
	_cleanup_test_files()
	var gc := GameController.new(TEST_SAVE_PATH, 303)
	gc.start_new_game(303)
	var sq := gc.piece_generator.get_piece_by_id("square_2x2")
	gc.set_tray_pieces([sq, sq.duplicate_piece(), null])

	var first := gc.try_place_tray_piece(0, Vector2i(0, 0))
	var second := gc.try_place_tray_piece(0, Vector2i(3, 3))
	var occ := gc.board.get_occupied_count()
	gc.free()

	if not bool(first["success"]):
		return {"ok": false, "detail": "First placement failed"}
	if bool(second["success"]) or second["reason"] != "slot_empty":
		return {"ok": false, "detail": "Duplicate placement of consumed slot 0 was not blocked"}
	if occ != 4:
		return {"ok": false, "detail": "Board occupied count changed on duplicate placement attempt"}
	return {"ok": true, "detail": "Second placement from already-consumed tray slot rejected with 'slot_empty'"}


func _test_19_game_state_transitions() -> Dictionary:
	_cleanup_test_files()
	var gc := GameController.new(TEST_SAVE_PATH, 404)
	var s0 := gc.state
	gc.start_new_game(404)
	var s1 := gc.state
	gc.lock_for_transition()
	var s2 := gc.state
	var blocked := gc.try_place_tray_piece(0, Vector2i(0, 0))
	gc.unlock_after_transition()
	var s3 := gc.state
	gc.free()

	if s0 != GameController.GameState.IDLE:
		return {"ok": false, "detail": "Initial state must be IDLE"}
	if s1 != GameController.GameState.PLAYING:
		return {"ok": false, "detail": "State after start_new_game must be PLAYING"}
	if s2 != GameController.GameState.TRANSITION_LOCKED:
		return {"ok": false, "detail": "State after lock_for_transition must be TRANSITION_LOCKED"}
	if bool(blocked["success"]) or blocked["reason"] != "invalid_game_state":
		return {"ok": false, "detail": "Placement was not blocked during TRANSITION_LOCKED"}
	if s3 != GameController.GameState.PLAYING:
		return {"ok": false, "detail": "State after unlock_after_transition must be PLAYING"}

	return {"ok": true, "detail": "Verified IDLE -> PLAYING -> TRANSITION_LOCKED (input blocked) -> PLAYING"}


func _test_20_no_regression_after_animations() -> Dictionary:
	_cleanup_test_files()
	var gc := GameController.new(TEST_SAVE_PATH, 606)
	gc.start_new_game(606)

	for x in range(6):
		gc.board.set_cell_occupied(Vector2i(x, 0), "cyan")

	var h2 := gc.piece_generator.get_piece_by_id("line_h2")
	var sq := gc.piece_generator.get_piece_by_id("square_2x2")
	gc.set_tray_pieces([h2, sq, null])

	var res1 := gc.try_place_tray_piece(0, Vector2i(6, 0))
	gc.lock_for_transition()
	gc.unlock_after_transition()
	var res2 := gc.try_place_tray_piece(1, Vector2i(0, 0))
	var occ := gc.board.get_occupied_count()
	gc.free()

	if not bool(res1["success"]):
		return {"ok": false, "detail": "Failed line-clearing placement"}
	if not bool(res2["success"]) or occ != 4:
		return {"ok": false, "detail": "Could not place piece onto cleared cells after animation transition"}

	return {"ok": true, "detail": "Cleared cells immediately reusable and rules intact after transition lock/unlock"}


func _test_21_ui_and_viewport_smoke() -> Dictionary:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	if packed == null:
		return {"ok": false, "detail": "Failed to load res://scenes/Main.tscn"}

	var instance: MainUI = packed.instantiate() as MainUI
	if instance == null:
		return {"ok": false, "detail": "Failed to instantiate Main.tscn as MainUI"}

	root.add_child(instance)

	var viewports: Array[Vector2i] = [
		Vector2i(720, 1280),
		Vector2i(1080, 1920),
		Vector2i(1080, 2400)
	]

	for vp in viewports:
		instance.apply_test_viewport_size(Vector2(vp.x, vp.y))
		var bsize := instance.board_view.size
		if absf(bsize.x - bsize.y) > 1.0 or bsize.x < 200.0:
			instance.free()
			return {"ok": false, "detail": "BoardView not square (%s) at viewport %s" % [str(bsize), str(vp)]}

	# Verify snap calculation on BoardView
	var single := instance.game_controller.piece_generator.get_piece_by_id("single_1x1")
	var cell_00_center := instance.board_view.global_position + instance.board_view._grid_origin + Vector2(instance.board_view.get_cell_size() * 0.5, instance.board_view.get_cell_size() * 0.5)
	var snap := instance.board_view.compute_snap_for_piece(cell_00_center, single)
	if not bool(snap["valid"]) or snap["origin"] != Vector2i(0, 0):
		instance.free()
		return {"ok": false, "detail": "BoardView snap calculation failed for cell (0,0): %s" % str(snap)}

	root.remove_child(instance)
	instance.free()
	return {"ok": true, "detail": "Main.tscn verified square BoardView & grid snapping at 720x1280, 1080x1920, 1080x2400"}
