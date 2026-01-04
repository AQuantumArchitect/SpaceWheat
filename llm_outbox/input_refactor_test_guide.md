# Input Architecture Refactor - Testing Guide

## 🎯 Test Results Summary

**Status:** ✅ Game boots successfully with new architecture!

**Verified:**
- PlayerShell initializes with modal stack
- Quest Board created
- Farm reference set via `shell.set_farm(farm)`
- FarmInputHandler using `_unhandled_input()`
- No InputController errors (deleted successfully)

---

## 🧪 Manual Test Plan

### Test 1: Quest Board Input Capture ⭐ CRITICAL

**Expected Behavior:** Quest board should capture UIOP/ESC when open

**Steps:**
1. Launch game
2. Press `C` → Quest board should open
3. Press `U` → Should select **slot 0** (NOT farm plot 0)
4. Press `I` → Should select **slot 1** (NOT farm plot 1)
5. Press `O` → Should select **slot 2** (NOT farm plot 2)
6. Press `P` → Should select **slot 3** (NOT farm plot 3)
7. Press `ESC` → Should **close quest board** (NOT open ESC menu)

**Watch Console For:**
```
📚 Modal stack: ["QuestBoard"]    ← Quest board added to modal stack
⌨️ QuestBoard: Selected slot 0   ← U key consumed by quest board
⌨️ QuestBoard: Selected slot 1   ← I key consumed by quest board
⌨️ QuestBoard: Closed             ← ESC consumed by quest board
📚 Modal stack: []                ← Quest board removed from stack
```

**❌ FAILURE SIGNS:**
- U/I/O/P keys select farm plots instead of quest slots
- ESC opens escape menu instead of closing quest board
- Console shows farm input messages instead of quest board messages

---

### Test 2: Farm Input When Quest Board Closed

**Expected Behavior:** Farm should receive input when quest board is closed

**Steps:**
1. Press `C` if quest board is open (close it)
2. Press `U` → Should select **farm plot** at position U
3. Press `I` → Should select **farm plot** at position I
4. Press `Space` → Should apply current tool to selected plot
5. Press `ESC` → Should open **ESC menu**

**Watch Console For:**
```
🎯 Farm: Selected plot (2, 0)     ← U key processed by FarmInputHandler
🎯 Farm: Selected plot (3, 0)     ← I key processed by FarmInputHandler
```

**✅ SUCCESS SIGNS:**
- U/I/O/P keys control farm plots
- Space applies tools
- ESC opens escape menu (not quest board)

---

### Test 3: Modal Stack Behavior

**Expected Behavior:** Modals stack on top of each other

**Steps:**
1. Press `ESC` → Escape menu opens
2. Press `S` → Save/Load menu opens (stacks on top)
3. Press `ESC` → Save/Load closes, escape menu still visible
4. Press `ESC` → Escape menu closes
5. Now at farm level

**Watch Console For:**
```
📚 Modal stack: ["EscapeMenu"]
📚 Modal stack: ["EscapeMenu", "SaveLoadMenu"]
📚 Modal stack: ["EscapeMenu"]
📚 Modal stack: []
```

---

### Test 4: Shell Action Keys

**Expected Behavior:** Shell actions (C/V/K/N/B) work from anywhere

**Steps:**
1. From farm view, press `C` → Quest board toggles
2. From farm view, press `V` → Vocabulary overlay toggles
3. From farm view, press `K` → Keyboard help toggles
4. From farm view, press `N` → Network overlay toggles
5. From farm view, press `B` → Biome inspector toggles

**✅ SUCCESS:** All overlays respond to their toggle keys

---

### Test 5: Input Priority Order

**Expected Behavior:** Input flows down priority chain

**Priority Order:**
1. **Highest:** PlayerShell._input() → modal_stack.handle_input()
2. **Medium:** PlayerShell._input() → _handle_shell_action()
3. **Lowest:** FarmInputHandler._unhandled_input()

**Test:**
1. Open quest board (C)
2. Press Q → Should trigger **quest slot action** (not quit)
3. Close quest board (ESC)
4. Open escape menu (ESC)
5. Press Q → Should trigger **quit** (menu-specific action)
6. Cancel (ESC)
7. Now Q should do nothing (no handler at farm level)

---

## 🐛 Known Issues (Pre-Existing)

These errors appear in console but don't affect input system:

```
SCRIPT ERROR: Invalid call. Nonexistent function 'set_border_enabled_all'
          at: QuantumRigorConfigUI.gd:39
```

**Not related to input refactor** - QuantumRigorConfigUI has pre-existing bugs.

---

## 🔍 Debug Console Commands

### Check Modal Stack State
Open Godot debugger console and run:
```gdscript
get_tree().root.get_node("FarmView/PlayerShell").modal_stack
```

### Check Farm Reference
```gdscript
get_tree().root.get_node("FarmView/PlayerShell").farm
```

### Manually Push/Pop Modals
```gdscript
var shell = get_tree().root.get_node("FarmView/PlayerShell")
var quest_board = shell.overlay_manager.quest_board
shell._push_modal(quest_board)  # Add to stack
shell._pop_modal(quest_board)   # Remove from stack
```

---

## ✅ Success Criteria

**All tests pass if:**
- ✅ Quest board captures UIOP/ESC when open
- ✅ Farm receives UIOP when quest board closed
- ✅ Modal stack properly manages input priority
- ✅ Shell actions (C/V/K/N/B) work from anywhere
- ✅ No InputController errors in console
- ✅ No "farm.has()" errors

---

## 📊 Architecture Verification

**Check these in debugger:**

### PlayerShell has _input() method
```gdscript
var shell = get_tree().root.get_node("FarmView/PlayerShell")
print(shell.has_method("_input"))  # Should print: true
```

### QuestBoard has handle_input() method
```gdscript
var qb = shell.overlay_manager.quest_board
print(qb.has_method("handle_input"))  # Should print: true
```

### FarmInputHandler uses _unhandled_input()
```gdscript
var farm_ui = shell.get_farm_ui()
var input_handler = farm_ui.get_node("FarmInputHandler")
print(input_handler.has_method("_unhandled_input"))  # Should print: true
print(input_handler.has_method("_input"))  # Should print: false (removed!)
```

---

## 🚀 Next Steps After Testing

If all tests pass:
- ✅ Phase 1-7 complete and verified
- ⏭️  Phase 8: Optional main scene restructure
- ⏭️  Phase 9: Touch button integration
- ⏭️  Phase 10: Final comprehensive testing

If tests fail:
- Check console output for error messages
- Verify modal stack contents
- Check which handler is consuming input
- Review PlayerShell._input() logic
