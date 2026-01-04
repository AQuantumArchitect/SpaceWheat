# Input Architecture Refactor - Complete Change Log

**Date:** 2026-01-03
**Status:** ✅ Phases 1-7 Complete, Ready for Testing

---

## 🎯 Objective

Fix quest board input capture issue by implementing proper Godot input architecture:
- PlayerShell owns input routing via `_input()`
- Modals use `handle_input() -> bool` pattern
- Farm uses `_unhandled_input()` for gameplay
- Delete InputController entirely

---

## ✅ Completed Changes

### Phase 1: Input Map Actions (project.godot)

**File:** `project.godot`

**Added 24 new input actions:**

**Shell Actions:**
- `toggle_quests` → C
- `toggle_vocabulary` → V
- `toggle_network` → N
- `toggle_keyboard_help` → K
- `toggle_biome_inspect` → B
- `quantum_config` → Shift+Q

**Modal Actions:**
- `modal_cancel` → ESC
- `modal_confirm` → Enter
- `slot_0` → U
- `slot_1` → I
- `slot_2` → O
- `slot_3` → P
- `slot_action_primary` → Q
- `slot_action_secondary` → E
- `slot_action_tertiary` → R

**Farm Actions:**
- `apply_tool` → Space
- `navigate_left` → Left, A
- `navigate_right` → Right, D
- `navigate_up` → Up, W
- `navigate_down` → Down, S
- `cycle_goal` → Tab, G

**Note:** `slot_X` and `select_plot_X` use same physical keys (UIOP) intentionally. Context determines which action fires.

---

### Phase 2: PlayerShell Refactor

**File:** `UI/PlayerShell.gd`

**Added:**
- `var modal_stack: Array[Control] = []` - Manages modal input priority
- `func _input(event: InputEvent)` - High-priority input router
- `func _handle_shell_action(event: InputEvent) -> bool` - Shell action handler
- `func _toggle_quest_board()` - Opens/closes quest board with biome passing
- `func _toggle_escape_menu()` - Opens/closes escape menu
- `func _push_modal(modal: Control)` - Adds modal to stack
- `func _pop_modal(modal: Control)` - Removes modal from stack
- `func set_farm(farm_ref: Node)` - Sets farm reference for input routing
- `process_mode = Node.PROCESS_MODE_ALWAYS` - Processes input when paused

**Modified:**
- `func load_farm()` - Now calls `set_farm()` to update reference

**Input Flow:**
```gdscript
func _input(event: InputEvent) -> void:
    # Layer 1: Modal input
    if not modal_stack.is_empty():
        if modal_stack[-1].handle_input(event):
            consume and return

    # Layer 2: Shell actions
    if _handle_shell_action(event):
        consume and return

    # Layer 3: Falls through to _unhandled_input
```

---

### Phase 3: Modal Refactor

#### QuestBoard.gd

**File:** `UI/Panels/QuestBoard.gd`

**Removed:**
- `func _unhandled_key_input(event)` - Old handler (too low priority)
- `func _handle_board_input(event)` - Old keycode-based handler

**Added:**
- `func handle_input(event: InputEvent) -> bool` - New modal handler

**Changes:**
- Uses Actions: `event.is_action_pressed("slot_0")` instead of `KEY_U`
- Returns `true` if input consumed, `false` otherwise
- Routes to faction browser if open

#### EscapeMenu.gd

**File:** `UI/Panels/EscapeMenu.gd`

**Removed:**
- `func _unhandled_key_input(event)` - Old handler

**Added:**
- `func handle_input(event: InputEvent) -> bool` - New modal handler

**Changes:**
- Uses Actions for common controls (ESC, Enter, arrows)
- Uses keycodes for menu-specific shortcuts (S/L/D/R/Q)
- Checks SaveLoadMenu.handle_input() if that modal is open

---

### Phase 4: Farm Input Handler

**File:** `UI/FarmInputHandler.gd`

**Changed:**
- `func _input(event)` → `func _unhandled_input(event)` ⭐ CRITICAL
- Updated docstring to reflect low-priority handling

**Why Critical:**
- Previously used `_input()` which runs at high priority
- Grabbed input before modals could see it
- Now uses `_unhandled_input()` which only processes input PlayerShell didn't consume

---

### Phase 5: OverlayManager Cleanup

**File:** `UI/Managers/OverlayManager.gd`

**Removed:**
- `var farm` - No longer stores farm reference

**Modified:**
- `func toggle_quest_board()` - Simplified to not use farm
  - PlayerShell now handles biome passing directly
  - Just emits signals for compatibility

- `func toggle_biome_inspector(farm_ref: Node = null)` - Takes farm as parameter
  - PlayerShell passes farm when calling

- `func show_overlay(name)` - Legacy quest offers disabled
  - Added warning that farm reference removed

**Architecture Change:**
```gdscript
// OLD (bad)
overlay_manager.farm = farm
overlay_manager.toggle_quest_board()  // Uses stored farm reference

// NEW (good)
var biome = farm.biotic_flux_biome
quest_board.set_biome(biome)
quest_board.open_board()
player_shell._push_modal(quest_board)
```

---

### Phase 6: FarmView Cleanup

**File:** `UI/FarmView.gd`

**Removed:**
- `const InputController` - No longer needed
- `var input_controller: InputController` - Deleted reference
- Lines 107-174: All InputController creation and signal wiring
- `func _on_overlay_state_changed()` - No longer needed

**Modified:**
- Lines 105-119: Now just calls `shell.set_farm(farm)`
- Connects quit/restart signals directly from escape_menu

**Before (67 lines of wiring):**
```gdscript
input_controller = InputController.new()
input_controller.menu_toggled.connect(...)
input_controller.vocabulary_requested.connect(...)
# ... 60 more lines of signal connections
```

**After (5 lines):**
```gdscript
shell.set_farm(farm)
shell.overlay_manager.escape_menu.quit_pressed.connect(_on_quit_requested)
shell.overlay_manager.escape_menu.restart_pressed.connect(_on_restart_requested)
```

---

### Phase 7: InputController Deletion

**Deleted:**
- `UI/Controllers/InputController.gd` - Entire file removed (228 lines)

**Updated:**
- `UI/Panels/SaveLoadMenu.gd`:
  - Removed `var input_controller` reference
  - Removed `func inject_input_controller()`
  - Removed input disable/enable logic
  - PlayerShell's modal stack handles input routing now

---

## 📊 Code Metrics

**Lines Removed:** ~350 lines
- InputController.gd: 228 lines
- FarmView signal wiring: 67 lines
- SaveLoadMenu injection logic: 15 lines
- OverlayManager farm reference code: 40 lines

**Lines Added:** ~170 lines
- PlayerShell input routing: 120 lines
- QuestBoard.handle_input(): 30 lines
- EscapeMenu.handle_input(): 20 lines

**Net Change:** -180 lines (simpler architecture!)

---

## 🏗️ Architecture Comparison

### Before (Broken)

```
FarmView (main scene)
  ├── PlayerShell
  │   └── OverlayManager
  │       ├── farm reference ❌
  │       └── QuestBoard (_unhandled_key_input ❌)
  └── InputController (_input ❌)
      └── Tries to block with flags ❌

Input flow: InputController → flags → sometimes works
```

### After (Fixed)

```
FarmView (main scene)
  └── PlayerShell
      ├── _input() ✅ (high priority)
      ├── modal_stack ✅
      ├── farm reference ✅
      └── OverlayManager
          └── QuestBoard (handle_input ✅)

FarmInputHandler (_unhandled_input ✅ low priority)

Input flow: PlayerShell → modals → shell actions → farm
```

---

## 🎯 Key Improvements

1. **Proper Godot Input Order:**
   - `_input()` (high) → modals capture UIOP/ESC
   - `_unhandled_input()` (low) → farm gets remaining input
   - Natural priority chain, no flags needed

2. **Modal Stack Pattern:**
   - Modals managed by PlayerShell
   - Input routed to topmost modal
   - Stack visualization in console: `📚 Modal stack: ["QuestBoard"]`

3. **Action-Based Input:**
   - Uses Godot's Input Map system
   - Allows rebinding keys
   - Context-sensitive: U → `slot_0` (modal) or `select_plot_u` (farm)

4. **Decoupled Architecture:**
   - OverlayManager doesn't store farm reference
   - PlayerShell passes data as parameters
   - No circular dependencies

5. **Swappable Farm:**
   - Farm reference stored in PlayerShell
   - Can swap farms without rewiring signals
   - `shell.set_farm(new_farm)` just works

---

## 🧪 Testing Status

**Boot Test:** ✅ PASS
- Game boots without errors
- PlayerShell initializes
- Farm reference set correctly
- No InputController errors

**Manual Testing:** 🔄 PENDING
- See `llm_outbox/input_refactor_test_guide.md`
- Critical test: Quest board captures UIOP/ESC when open

---

## 📝 Remaining Work

### Phase 8: Main Scene Restructure (Optional)
- Change main scene from FarmView to PlayerShell
- Make FarmView a child of PlayerShell
- **Status:** Can work as-is, not blocking

### Phase 9: Touch Button Integration
- Create TouchScreenButton components
- Emit Input Actions for mobile/web
- Context-sensitive action emission
- **Status:** Framework ready, implementation pending

### Phase 10: Comprehensive Testing
- All input scenarios
- Modal stacking
- Farm swapping
- Touch inputs
- **Status:** Ready to begin

---

## 🐛 Rollback Plan

If issues arise, rollback steps:

```bash
# Restore InputController
git checkout HEAD~1 -- UI/Controllers/InputController.gd

# Revert PlayerShell changes
git checkout HEAD~1 -- UI/PlayerShell.gd

# Revert modal changes
git checkout HEAD~1 -- UI/Panels/QuestBoard.gd
git checkout HEAD~1 -- UI/Panels/EscapeMenu.gd

# Revert FarmView
git checkout HEAD~1 -- UI/FarmView.gd

# Revert OverlayManager
git checkout HEAD~1 -- UI/Managers/OverlayManager.gd

# Revert FarmInputHandler
git checkout HEAD~1 -- UI/FarmInputHandler.gd
```

Or create feature branch first:
```bash
git checkout -b refactor/input-architecture-backup
git commit -am "Backup before input refactor"
git checkout master
# ... do refactor ...
```

---

## 📚 References

- User spec: `llm_inbox/input_fix/SPACEWHEAT_IMPLEMENTATION_GUIDE.md`
- Original plan: `.claude/plans/spacewheat-input-refactor-plan.md`
- Test guide: `llm_outbox/input_refactor_test_guide.md`
- Problem analysis: `llm_outbox/quest_board_input_issue/`

---

## ✅ Sign-Off

**Implementation:** Complete for Phases 1-7
**Boot Test:** Passed
**Ready For:** Manual testing
**Blocking Issues:** None
**Pre-existing Issues:** QuantumRigorConfigUI errors (unrelated)

**Next Step:** Run manual tests per test guide, verify quest board captures input correctly.
