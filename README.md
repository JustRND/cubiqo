# BLOKORA — Phase 1 Core Prototype

**BLOKORA** is a mobile-first 8×8 block puzzle prototype built in **Godot 4.7.2** using **GDScript** with a strict separation between authoritative puzzle domain logic and presentation.

> **Status:** Phase 1 Core Prototype (Verified via automated unit, regression, and headless smoke tests; not yet production-ready—manual on-device touchscreen testing and Phase 2+ meta systems remain scheduled for upcoming phases).

---

## 1. Requirements & Engine Version
- **Engine:** Godot `4.7.2.stable.official.ed1daf0bf`
- **Orientation:** Portrait (`1080×1920` base viewport, `540×960` desktop window override)
- **Renderer:** Mobile (`canvas_items` stretch mode, `expand` aspect)

---

## 2. How to Run the Game

### Option A — From the Godot Editor
1. Launch Godot `4.7.2-stable` (`D:\GodotEngine\Godot_v4.7.2-stable_win64.exe`).
2. Import or open `d:\GoDotProjects\cubiqo\project.godot`.
3. Press **F5** (or click **Run Project**) to launch `res://scenes/Main.tscn`.

### Option B — From the Command Line (PowerShell)
```powershell
& "D:\GodotEngine\Godot_v4.7.2-stable_win64.exe" --path "d:\GoDotProjects\cubiqo"
```

---

## 3. How to Run the Automated Test Suite

Run the headless test suite via the Godot console executable:
```powershell
& "D:\GodotEngine\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\GoDotProjects\cubiqo" --script res://tests/TestRunner.gd
```

Run a headless runtime smoke test on the main scene:
```powershell
& "D:\GodotEngine\Godot_v4.7.2-stable_win64_console.exe" --headless --path "d:\GoDotProjects\cubiqo" --quit-after 5
```

---

## 4. Gameplay & Controls (Phase 1)
- **Drag & Drop:** Click/touch and drag any of the 3 pieces from the bottom tray onto the 8×8 board.
- **Finger Offset:** Dragged pieces lift above the pointer so your finger never obscures the shape on mobile screens.
- **Placement Preview:** Valid board positions show a ghost preview of the piece; if dropping the piece will complete one or more rows/columns, those lines highlight before release.
- **Invalid Drops:** Releasing a piece outside the board or overlapping occupied cells triggers visual feedback and smoothly animates the piece back to its tray slot without mutating board state.
- **Scoring:**
  - `+10` points per placed block cell
  - `+100` points per cleared row
  - `+100` points per cleared column
  - `+50` bonus for clearing 2 lines simultaneously
  - `+150` bonus for clearing 3 or more lines simultaneously
  - Consecutive-clear combo counter increments on every turn that clears at least 1 line (and resets to `0` on any turn without a line clear), awarding `+50 × (combo - 1)` configurable streak bonus points.
- **Persistence:** Best score and user settings (Sound, Haptics, High-Contrast Blocks) are saved automatically to `user://blokora_save.json` in a versioned JSON schema with automatic corruption recovery.
