# BLOKORA — Phase 1 Automated Test Report

## 1. Test Environment
- **OS:** Windows (64-bit)
- **Godot Version:** `4.7.2.stable.official.ed1daf0bf`
- **Console Runner:** `D:\GodotEngine\Godot_v4.7.2-stable_win64_console.exe`
- **Project Path:** `d:\GoDotProjects\cubiqo`
- **Test Script:** `res://tests/TestRunner.gd`

---

## 2. Commands Executed

### Class Cache Import & Project Validation
```powershell
& "D:\GodotEngine\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\GoDotProjects\cubiqo" --import
```

### Automated Unit, Regression & Multi-Viewport Suite
```powershell
& "D:\GodotEngine\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\GoDotProjects\cubiqo" --script res://tests/TestRunner.gd
```

### Runtime Main Scene Smoke Test
```powershell
& "D:\GodotEngine\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\GoDotProjects\cubiqo" --quit-after 5
```

---

## 3. Actual Test Execution Output

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

============================================================
BLOKORA PHASE 1 — AUTOMATED TEST SUITE
Engine: Godot 4.7.2-stable (official)
============================================================
[PASS] 01. Legal placement on an empty board — 2x2 piece placed at (3,3); 4 cells occupied with color & metadata intact
[PASS] 02. Rejection of overlapping pieces — Overlapping placement rejected with reason 'cell_occupied'
[PASS] 03. Rejection of out-of-bounds placements — Negative, right-edge, and bottom-edge overflows rejected cleanly
[PASS] 04. Invalid placement does not change board state — Board state remained 100% unchanged after rejected placement
[PASS] 05. Horizontal line clearing — Row 5 cleared all 8 cells; unrelated cell at (2,1) preserved
[PASS] 06. Vertical line clearing — Column 3 cleared all 8 cells
[PASS] 07. Simultaneous row and column clearing — 1 row + 1 col counted; intersecting cell (4,4) removed once (15 total cells)
[PASS] 08. Correct scoring calculations — Verified +10/cell, +100/row, +100/col, +50 (2 lines), +150 (3+ lines)
[PASS] 09. Correct combo reset behavior — Combo incremented to 2 on consecutive clears and reset to 0 on non-clearing turn
[PASS] 10. Piece consumption after valid placement — Placed slot 1 disappeared; 2 pieces remain in tray
[PASS] 11. Tray refill after all pieces are consumed — Tray automatically refilled with 3 new pieces after all 3 were placed
[PASS] 12. Game-over detection — Game over accurately triggered when remaining 2x2 piece had 0 legal moves
[PASS] 13. Restart behavior — Restart cleared board, reset score/combo, refilled tray, preserved best score
[PASS] 14. Deterministic piece generation using a fixed seed — Fixed seed 123456 generated identical 15-piece sequences (l_small...)
[PASS] 15. Best-score persistence — Best score (50) persisted to disk and reloaded in new SaveManager instance
[PASS] 16. Corrupted save-file handling — Malformed JSON and negative schema values recovered cleanly to defaults
[PASS] 17. Piece shape validity (>= 12 shapes + required shapes) — 17 valid data-driven shapes verified (all 12 required shapes present)
[PASS] 18. Prevention of duplicate placement — Second placement from already-consumed tray slot rejected with 'slot_empty'
[PASS] 19. Correct game-state transitions — Verified IDLE -> PLAYING -> TRANSITION_LOCKED (input blocked) -> PLAYING
[PASS] 20. No regression in core board rules after animations — Cleared cells immediately reusable and rules intact after transition lock/unlock
[PASS] 21. Multi-viewport UI & runtime smoke verification — Main.tscn verified square BoardView & grid snapping at 720x1280, 1080x1920, 1080x2400
------------------------------------------------------------
TOTAL: 21 | PASSED: 21 | FAILED: 0
============================================================
```

---

## 4. Verification Summary & Known Limitations
- **21 / 21 automated tests passed** with exit code `0`, zero script warnings, and zero leaked ObjectDB instances.
- **Important Testing Note:** Headless automated tests validate board logic, scoring, persistence, state transitions, and layout geometry across `720×1280`, `1080×1920`, and `1080×2400` viewports, but **do not substitute for manual physical touchscreen testing** on real Android and iOS devices to tune finger-offset ergonomics and feel.
