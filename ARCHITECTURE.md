# BLOKORA — System Architecture (Phase 1)

## 1. Architectural Principles
1. **Strict Separation of Concerns:** Pure gameplay domain rules (`BoardModel`, `PieceDefinition`, `PlacementRules`, `PieceGenerator`, `ScoreManager`, `SaveManager`) inherit from `RefCounted` and have **zero dependencies** on UI nodes or `SceneTree`.
2. **Controlled Gameplay Transactions:** All mutations to the 8×8 grid go through authoritative transaction methods on `GameController` and `BoardModel`. Invalid placements never partially mutate board or tray state.
3. **Zero Circular Dependencies:** Dependencies flow strictly downward (`UI -> GameController -> Core Domain -> Service Contracts`). No global autoload singletons are required.
4. **Mobile Performance First:** Board and piece rendering use reusable `StyleBoxFlat` instances inside `TileRenderer` (`_draw()`), avoiding per-frame node allocations or scene-tree churn.

---

## 2. Directory & Module Structure

```text
res://
├── project.godot
├── scenes/
│   └── Main.tscn                        # Root portrait game scene
├── scripts/
│   ├── core/
│   │   ├── BoardModel.gd                # 8x8 grid occupancy, cell metadata, placement & line clearing
│   │   ├── PieceDefinition.gd           # Data-driven shape offsets, color palette, 17 default shapes
│   │   ├── PieceGenerator.gd            # Seeded RNG, weighted shape selection, candidate evaluation
│   │   ├── PlacementRules.gd            # Bounds validation, collision detection, available-move scanning
│   │   ├── ScoreManager.gd              # Placement points, multi-line bonuses, combo streak counter
│   │   ├── SaveManager.gd               # Versioned JSON persistence & corruption recovery
│   │   └── GameController.gd            # Turn state machine, 3-piece tray lifecycle, transition locking
│   ├── services/
│   │   ├── AdServiceInterface.gd        # Stub contract for future rewarded ad placements
│   │   └── FutureHooks.gd               # Extension contracts for Power-Ups, Difficulty Director, Revive
│   └── ui/
│       ├── TileRenderer.gd              # Zero-allocation rounded tile & highlight renderer
│       ├── BoardView.gd                 # 1:1 square board view, snap math, ghost preview, animations
│       ├── TraySlotView.gd              # Individual tray slot card & touch/mouse drag trigger
│       ├── DragController.gd            # Finger-offset drag, snap preview updates, return tweening
│       └── MainUI.gd                    # Responsive portrait HUD, modals, safe-area layout
└── tests/
    └── TestRunner.gd                    # Headless automated test runner (21 test suites)
```

---

## 3. Turn Transaction Lifecycle

1. **Pickup (`TraySlotView` -> `DragController`):**
   - Touch or mouse press on a non-empty `TraySlotView` emits `drag_requested(slot_index, global_pos, pointer_index)`.
   - `DragController` verifies `GameController.can_accept_input()`, locks onto `pointer_index`, applies an upward finger offset, and scales the piece to match `BoardView` cell dimensions.
2. **Live Preview (`DragController` -> `BoardView`):**
   - As the pointer moves, `BoardView.compute_snap_for_piece()` maps the lifted piece center to grid coordinates.
   - If legal, `BoardView.set_placement_preview()` queries `BoardModel.preview_placement()` to render both the ghost footprint and a highlight over any row/column that will complete upon release.
3. **Commit or Reject (`DragController` -> `GameController`):**
   - **Valid Drop:** Calls `GameController.try_place_tray_piece(slot_index, origin)`:
     1. `BoardModel.place_piece()` validates bounds & occupancy, commits cells with color and metadata, and resolves completed rows and columns simultaneously (deduplicating intersecting cells while counting both the row and column).
     2. `tray[slot_index]` is immediately set to `null` (preventing duplicate placement).
     3. `ScoreManager.record_turn()` calculates placement points, line clear points, simultaneous multi-line bonuses, and consecutive combo streak points, updating persistent `best_score` via `SaveManager`.
     4. If all 3 tray slots are `null`, `GameController` refills the tray via `PieceGenerator.generate_tray()`.
     5. `PlacementRules.can_any_piece_fit(board, tray)` checks whether any remaining tray piece has at least one legal move; if not, `GameState.GAME_OVER` is triggered.
   - **Invalid Drop:** Board and tray states remain untouched; `DragController` animates the piece smoothly back to its `TraySlotView`.

---

## 4. Phase 2+ Extension Points
- **Power-Ups (`FutureHooks.PowerUpType` & `BoardModel` hooks):**
  - `BoardModel.clear_all_occupied()` -> **Mega Bomb**
  - `BoardModel.move_occupied_cell(from, to)` -> **Mighty Hand**
  - `BoardModel.clear_single_cell(pos)` -> **Hammer**
  - `BoardModel.clear_row_direct(row)` -> **Row Blaster**
  - `GameController.set_tray_pieces(...)` -> **Tray Shuffle**
- **Difficulty Director (`FutureHooks.DifficultyState` & `PieceGenerator`):**
  - `PieceGenerator.evaluate_candidate_tray(board, candidate_tray)` computes shape difficulty ratings, fitting piece counts, total available moves, and board occupancy ratios.
  - Supports `NORMAL`, `CHALLENGE`, and `RECOVERY` states while remaining 100% deterministic under fixed seeds.
- **Revive & Rewarded Ads (`AdServiceInterface`):**
  - Decoupled interface ready for Phase 2 implementation without coupling core puzzle logic to third-party ad SDKs.
