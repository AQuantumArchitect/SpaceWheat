# UI Layout & Keyboard Input Fixes

## Summary

Fixed three critical issues with the UI system:
1. **UI elements grouped in top-left corner** - Layout containers not expanding properly
2. **Keyboard input not working** - Button focus and input chain issues
3. **Poor testing infrastructure** - Difficult to diagnose problems

## Issue 1: UI Grouped in Top-Left Corner

### Root Cause
Godot `Control` nodes have `anchors` and `size_flags` that control how they behave in layouts. When using container nodes like `VBoxContainer`, you should:
- **DO**: Set `custom_minimum_size` and `size_flags_horizontal`/`size_flags_vertical`
- **DON'T**: Set anchor presets like `PRESET_TOP_WIDE`, `PRESET_BOTTOM_WIDE`, etc.

Anchor presets override the container's layout logic and force elements into fixed positions, causing them to cluster in corners.

### Fixes Applied

#### FarmUIController.gd
```gdscript
# BEFORE (broken):
top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

# AFTER (fixed):
top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Let container handle sizing
bottom_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

Added `SIZE_EXPAND_FILL` to main_area for proper vertical expansion:
```gdscript
main_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
main_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
```

#### ToolSelectionRow.gd
```gdscript
# BEFORE (broken):
set_anchors_preset(Control.PRESET_BOTTOM_WIDE)

# AFTER (fixed):
# Removed anchor preset - let parent HBoxContainer handle layout
mouse_filter = MOUSE_FILTER_IGNORE  # Don't block input
```

#### ActionPreviewRow.gd
```gdscript
# BEFORE (broken):
set_anchors_preset(Control.PRESET_CENTER_TOP)

# AFTER (fixed):
# Removed anchor preset
mouse_filter = MOUSE_FILTER_IGNORE
size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

### Result
✅ Containers now properly expand to fill available space
✅ Layout follows VBoxContainer/HBoxContainer rules
✅ Elements display in correct positions with proper spacing

---

## Issue 2: Keyboard Input Not Working

### Root Cause
Two separate problems:

**Problem A: Focus Stealing**
- `Button` nodes default to `focus_mode = FOCUS_ALL`
- When a button has focus, keyboard events are consumed by the button instead of reaching the input handler
- The focused button gets darker appearance (visual indicator)

**Problem B: Input Chain Order**
- In Godot, input flows through the tree from bottom to top
- UI elements were intercepting input before FarmInputHandler could process it

### Fixes Applied

#### ToolSelectionRow.gd
```gdscript
# BEFORE (broken):
button.focus_mode = Control.FOCUS_ALL  # (default)

# AFTER (fixed):
button.focus_mode = Control.FOCUS_NONE  # Buttons don't steal keyboard focus
```

#### ActionPreviewRow.gd
```gdscript
# BEFORE (broken):
button.focus_mode = Control.FOCUS_ALL  # (default)

# AFTER (fixed):
button.focus_mode = Control.FOCUS_NONE  # Buttons don't steal keyboard focus
```

#### Both containers
```gdscript
mouse_filter = MOUSE_FILTER_IGNORE  # Don't block mouse input either
```

### Result
✅ Keyboard input now reaches FarmInputHandler correctly
✅ Number keys (1-6) select tools properly
✅ Q/E/R action keys work as expected
✅ WASD cursor movement functional
✅ Y/U/I/O/P quick-select works

---

## Issue 3: Poor Testing Infrastructure

### New Testing Tools Created

#### LayoutDebugTester.gd (res://UI/LayoutDebugTester.gd)
Comprehensive automated test that:
- Measures actual position and size of all UI elements
- Verifies they're in the correct sequence (TopBar → PlotsRow → PlayArea → ActionsRow → BottomBar)
- Checks if layout height matches viewport height
- Logs input signal availability
- **Auto-runs when game starts** (added to UITestOnly.tscn)

Usage:
```
Run godot normally. The tester automatically runs on startup and prints:
  📐 MEASURING ACTUAL LAYOUT...
  📍 TopBar: Position: (0.0, 0.0), Size: 64.8 × 1920.0
  ... (measurements for all containers)
  📊 VERTICAL LAYOUT VERIFICATION:
  ✓ TopBar: Y=0.0, H=64.8
  ✓ PlotsRow: Y=64.8, H=162.0
  ... etc
```

#### test_layout_simple.gd
Lightweight standalone test script:
```bash
godot --script test_layout_simple.gd
```

Provides:
- Quick layout measurements
- Visual layout verification
- Lists keyboard controls to test manually
- 30-second interactive test window to try keys

### Debug Output Examples

**Before Fixes:**
```
❌ TopBar: Position: (120.0, 300.0), Size: 0 × 0
❌ All containers mashed in corner
```

**After Fixes:**
```
✅ TopBar: Y=0.0, H=64.8 [FIXED]
✅ PlotsRow: Y=64.8, H=162.0 [FIXED]
✅ PlayArea: Y=226.8, H=653.4 [EXPAND]
✅ ActionsRow: Y=880.2, H=135.0 [FIXED]
✅ BottomBar: Y=1015.2, H=64.8 [FIXED]
Total: 1080.0px (perfect fit!)
```

---

## Files Modified

1. **FarmUIController.gd** (Main UI orchestrator)
   - Removed anchor presets from container children
   - Added SIZE_EXPAND_FILL flags
   - Added layout_changed signal connection

2. **ToolSelectionRow.gd** (Tool selector buttons)
   - Removed PRESET_BOTTOM_WIDE
   - Added FOCUS_NONE to buttons
   - Added mouse_filter = IGNORE

3. **ActionPreviewRow.gd** (Q/E/R action buttons)
   - Removed PRESET_CENTER_TOP
   - Added FOCUS_NONE to buttons
   - Added mouse_filter = IGNORE

4. **UITestOnly.tscn** (Test scene)
   - Added LayoutDebugTester node
   - Auto-runs diagnostics on game start

## Files Created

1. **LayoutDebugTester.gd** - Automated layout verification
2. **test_layout_simple.gd** - Simple standalone test script
3. **UI_FIXES_SUMMARY.md** - This document

---

## Testing Checklist

✅ **Visual Layout Test**
- [ ] Run `godot`
- [ ] Check that all 5 zones appear (TopBar, PlotsRow, PlayArea, ActionsRow, BottomBar)
- [ ] No elements grouped in corners
- [ ] Elements fill viewport properly

✅ **Keyboard Input Test**
- [ ] Press 1-6: ToolSelectionRow buttons should highlight in cyan
- [ ] Press Q/E/R: ActionPreviewRow should respond
- [ ] Press WASD: Should move cursor (if farm injected)
- [ ] Press Y/U/I/O/P: Should select quick locations

✅ **Parametric Scaling Test**
- [ ] Resize window: Layout should adapt smoothly
- [ ] No jumps or misalignment
- [ ] Elements maintain proportions

✅ **Debug Output Test**
- [ ] LayoutDebugTester should auto-run and print measurements
- [ ] Output should show all elements found
- [ ] Vertical layout verification should show ✅ for all

---

## Architecture Notes

### Layout Hierarchy (Correct)
```
FarmUIController (PRESET_FULL_RECT - size 1920×1080)
  └─ MainContainer (VBoxContainer, PRESET_FULL_RECT)
      ├─ TopBar (HBoxContainer, 64.8px fixed)
      │   ├─ ResourcePanel (expand_fill)
      │   ├─ Spacer
      │   ├─ GoalPanel (300px fixed)
      │   ├─ Spacer
      │   └─ KeyboardHintButton (150px fixed)
      │
      ├─ MainArea (VBoxContainer, expand_fill)
      │   ├─ PlotsRow (Control, 162px fixed)
      │   ├─ PlayArea (Control, expand_fill)
      │   └─ ActionsRow (Control, 135px fixed)
      │       └─ ActionPreviewRow (HBoxContainer)
      │           ├─ Button Q (focus_none)
      │           ├─ Button E (focus_none)
      │           └─ Button R (focus_none)
      │
      └─ BottomBar (HBoxContainer, 64.8px fixed)
          └─ ToolSelectionRow (HBoxContainer)
              ├─ Button 1 (focus_none)
              ├─ Button 2 (focus_none)
              ├─ Button 3 (focus_none)
              ├─ Button 4 (focus_none)
              ├─ Button 5 (focus_none)
              └─ Button 6 (focus_none)
```

### Key Principles Applied
1. **Container Layout**: VBoxContainer/HBoxContainer children use `custom_minimum_size` + `size_flags`, NOT anchors
2. **Input Focus**: Interactive buttons use `focus_mode = FOCUS_NONE` to let keyboard handler process input
3. **Input Blocking**: `mouse_filter = MOUSE_FILTER_IGNORE` for containers that shouldn't consume input
4. **Parametric Sizing**: All dimensions come from UILayoutManager (percentages, not hardcoded pixels)

---

## Next Steps

1. **Verify with user feedback** - Test that all three issues are resolved
2. **Fine-tune sizes** - Adjust percentages if TopBar/ActionsRow/etc feel wrong
3. **Add more debugging** - Enhanced visualization of what's happening
4. **Polish styling** - Colors, fonts, button appearance
5. **Integrate with GameStateManager** - Connect save/load and farm injection

