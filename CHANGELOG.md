# BLOKORA — Changelog

## [0.1.0-phase1] — 2026-10-14 (`feature/blokora-phase1`)

### Modified Files
- `project.godot`: Configured project name (`BLOKORA`), main scene (`res://scenes/Main.tscn`), portrait mobile viewport (`1080×1920`, `540×960` override, `canvas_items`, `expand`), and touch-from-mouse emulation.

### Created Files
#### Core Puzzle Domain & Controller (`res://scripts/core/`)
- `scripts/core/BoardModel.gd`: 8×8 puzzle grid occupancy, cell metadata, placement transactions, simultaneous row/column line clears, and future power-up hooks.
- `scripts/core/PieceDefinition.gd`: Data-driven piece shape representation, normalized cell coordinates, color palettes (standard + high-contrast), and 17 built-in shapes.
- `scripts/core/PlacementRules.gd`: Legal placement validation, out-of-bounds & overlap checks, and legal-move detection across remaining tray pieces.
- `scripts/core/PieceGenerator.gd`: Seeded `RandomNumberGenerator`, weighted shape selection, and Difficulty Director evaluation hooks.
- `scripts/core/ScoreManager.gd`: Configurable placement scoring, line clear scoring, simultaneous multi-line bonuses, and consecutive-clear combo counter.
- `scripts/core/SaveManager.gd`: Versioned JSON local save persistence (`user://blokora_save.json`), best score storage, settings persistence, and corruption recovery.
- `scripts/core/GameController.gd`: Central turn state machine, 3-piece tray management, duplicate-placement protection, game-over evaluation, restart flow, and transition lock controls.

#### Future Service & Extension Contracts (`res://scripts/services/`)
- `scripts/services/AdServiceInterface.gd`: Interface contract for future rewarded advertisements (no ad SDK integrated in Phase 1).
- `scripts/services/FutureHooks.gd`: Enumerations and context builders for Power-Ups, Difficulty Director (`NORMAL`, `CHALLENGE`, `RECOVERY`), and Revive system.

#### Mobile-First Presentation & Input (`res://scripts/ui/` & `res://scenes/`)
- `scripts/ui/TileRenderer.gd`: Zero-allocation `StyleBoxFlat` renderer for rounded block tiles, bevel highlights, ghost previews, and line-clear overlays.
- `scripts/ui/BoardView.gd`: Square 8×8 board view, grid snap calculation, ghost preview, line-completion highlight, and placement/clearing animations.
- `scripts/ui/TraySlotView.gd`: Individual tray slot card rendering and touch/mouse pickup signal dispatch.
- `scripts/ui/DragController.gd`: Smooth mouse and touchscreen drag-and-drop with upward finger offset, real-time board snapping, and return animation on invalid drops.
- `scripts/ui/MainUI.gd`: Portrait mobile HUD, score/combo display, 3-piece tray, power-up/shop placeholders, Game Over modal (with Restart & placeholder Revive), and Settings dialog.
- `scenes/Main.tscn`: Root playable scene wired to `MainUI.gd`.

#### Automated Testing & Documentation
- `tests/TestRunner.gd`: Headless automated test runner verifying 21 unit, regression, persistence, and multi-viewport UI smoke test scenarios.
- `README.md`: Instructions for running the game and executing the automated tests.
- `ARCHITECTURE.md`: Technical documentation of the system design and extension points.
- `TEST_REPORT.md`: Complete execution logs and results of the automated test suite.
- `CHANGELOG.md`: Record of all modified and created files in Phase 1.
