# SpaceWheat Input Architecture - Implementation Summary

## Your Vision vs My Original Proposal

| Aspect | My Original (v1) | Your Vision (v2) |
|--------|------------------|------------------|
| **Entry Point** | Three separate handlers | PlayerShell owns everything |
| **Input Handler** | GlobalShortcutHandler, ModalInputRouter, GameInputHandler | PlayerShell._input() + Farm._unhandled_input() |
| **Modal Tracking** | ModalInputRouter.modal_stack | PlayerShell.modal_stack |
| **Key Handling** | Raw keycodes (KEY_C, KEY_U) | Godot Actions ("toggle_quests", "slot_0") |
| **Farm Relationship** | Separate entity | Swappable child of PlayerShell |
| **Complexity** | 3 new files | 0 new files (refactor existing) |

**Your architecture is better because:**
1. Fewer moving parts
2. PlayerShell naturally owns the modal stack (it's the player's interface)
3. Godot Actions allow rebinding
4. Farm swapping is a first-class concept
5. Matches your game's conceptual model

---

## The Core Insight

```
┌────────────────────────────────────────────────────────┐
│  PlayerShell._input()                                  │
│  ═══════════════════                                   │
│  "I am the player. I handle my stuff first."          │
│                                                        │
│  if modal_open:                                        │
│      route_to_modal() → CONSUME                        │
│  elif is_shell_action:                                │
│      handle_overlay() → CONSUME                        │
│  else:                                                 │
│      PASS (let Godot's unhandled chain take over)     │
└────────────────────────────────────────────────────────┘
                         │
                         ▼ (naturally falls through)
┌────────────────────────────────────────────────────────┐
│  Farm._unhandled_input()                               │
│  ═══════════════════════                               │
│  "I am the game. I get whatever the player didn't."   │
│                                                        │
│  handle_gameplay() → CONSUME                           │
└────────────────────────────────────────────────────────┘
```

---

## Files to Modify

### 1. PlayerShell.gd
**Current:** Creates overlays, loads farm
**Add:** 
- `_input()` method with modal routing
- `modal_stack: Array[Control]`
- `_handle_shell_action()` method
- Use `event.is_action_pressed()` instead of keycodes

### 2. QuestBoard.gd
**Remove:** `_unhandled_key_input()`
**Add:** `handle_input(event: InputEvent) -> bool`
**Change:** Keycodes → Actions

### 3. EscapeMenu.gd
**Remove:** `_unhandled_key_input()`
**Add:** `handle_input(event: InputEvent) -> bool`
**Change:** Keycodes → Actions

### 4. Farm.gd (or create FarmInputHandler.gd)
**Add:** `_unhandled_input()` for gameplay
**Change:** Use Actions

### 5. InputController.gd
**Delete entirely** - no longer needed

### 6. FarmView.gd
**Simplify:** Remove signal wiring for input (PlayerShell handles it)

### 7. project.godot
**Add:** Input Map actions

---

## Input Map Actions to Define

Open **Project → Project Settings → Input Map** and add:

### Shell Actions
| Action Name | Key | Description |
|-------------|-----|-------------|
| `toggle_menu` | Escape | Open/close ESC menu |
| `toggle_quests` | C | Toggle quest board |
| `toggle_vocabulary` | V | Toggle vocabulary |
| `toggle_network` | N | Toggle network |
| `toggle_keyboard_help` | K | Toggle keyboard help |
| `toggle_biome_inspect` | B | Toggle biome inspector |

### Modal Actions
| Action Name | Key | Description |
|-------------|-----|-------------|
| `modal_cancel` | Escape | Close current modal |
| `modal_confirm` | Enter | Confirm selection |
| `slot_0` | U | Select slot/plot 0 |
| `slot_1` | I | Select slot/plot 1 |
| `slot_2` | O | Select slot/plot 2 |
| `slot_3` | P | Select slot/plot 3 |
| `slot_action_primary` | Q | Accept/Complete |
| `slot_action_secondary` | E | Reroll/Abandon |
| `slot_action_tertiary` | R | Lock toggle |

### Farm Actions
| Action Name | Key | Description |
|-------------|-----|-------------|
| `select_plot_0` | U | Select plot 0 |
| `select_plot_1` | I | Select plot 1 |
| `select_plot_2` | O | Select plot 2 |
| `select_plot_3` | P | Select plot 3 |
| `apply_tool` | Space | Apply current tool |
| `navigate_left` | Left, A | Move selection left |
| `navigate_right` | Right, D | Move selection right |
| `navigate_up` | Up, W | Move selection up |
| `navigate_down` | Down, S | Move selection down |
| `cycle_goal` | Tab, G | Cycle active goal |

**Note:** `slot_X` and `select_plot_X` use the same keys intentionally. When modal is open, PlayerShell consumes `slot_X` before Farm ever sees `select_plot_X`.

---

## Quick Implementation Checklist

### Phase 1: Setup Input Map (15 min)
- [ ] Add all shell actions to Input Map
- [ ] Add all modal actions to Input Map  
- [ ] Add all farm actions to Input Map
- [ ] Test that actions fire correctly with `print(event.get_action())`

### Phase 2: Refactor PlayerShell (45 min)
- [ ] Add `modal_stack: Array[Control] = []`
- [ ] Add `_push_modal()` and `_pop_modal()` methods
- [ ] Add `_input()` method with modal check
- [ ] Add `_handle_shell_action()` using actions
- [ ] Connect overlay visibility to modal stack

### Phase 3: Update Modals (30 min)
- [ ] QuestBoard: Add `handle_input() -> bool`, remove `_unhandled_key_input()`
- [ ] EscapeMenu: Add `handle_input() -> bool`, remove `_unhandled_key_input()`
- [ ] SaveLoadMenu: Add `handle_input() -> bool` if needed
- [ ] Use action names, not keycodes

### Phase 4: Update Farm (30 min)
- [ ] Add `_unhandled_input()` to Farm or FarmInputHandler
- [ ] Move gameplay input handling from InputController
- [ ] Use action names

### Phase 5: Cleanup (15 min)
- [ ] Delete InputController.gd
- [ ] Remove InputController signal wiring from FarmView.gd
- [ ] Test all input scenarios

---

## Testing Scenarios

### Modal Input Capture
1. Press C → QuestBoard opens
2. Press U → Slot 0 selected (NOT plot 0)
3. Press ESC → QuestBoard closes
4. Press U → Plot 0 selected (farm receives input now)

### Farm Swap
1. Load Farm A
2. Press U → Plot 0 on Farm A selected
3. `player_shell.set_farm(farm_b)`
4. Press U → Plot 0 on Farm B selected
5. No signal rewiring needed

### Non-Blocking Overlay
1. Press B → Biome inspector shows
2. Press U → Plot 0 selected (biome inspector doesn't block!)
3. Press B → Biome inspector hides

### Modal Stack
1. Press ESC → Escape menu opens
2. Press S → Save/Load menu opens (stacks on top)
3. Press ESC → Save/Load closes, Escape menu still open
4. Press ESC → Escape menu closes
5. Now at farm level

---

## Key Code Patterns

### PlayerShell._input()
```gdscript
func _input(event: InputEvent) -> void:
    # Modal first
    if not modal_stack.is_empty():
        if modal_stack[-1].handle_input(event):
            get_viewport().set_input_as_handled()
            return
    
    # Shell actions second
    if _handle_shell_action(event):
        get_viewport().set_input_as_handled()
        return
    
    # Everything else falls through to _unhandled_input
```

### Modal.handle_input()
```gdscript
func handle_input(event: InputEvent) -> bool:
    if not visible:
        return false
    
    if event.is_action_pressed("slot_0"):
        select_slot(0)
        return true  # Consumed
    
    # ... more actions ...
    
    return false  # Not consumed
```

### Farm._unhandled_input()
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("select_plot_0"):
        select_plot(0)
        get_viewport().set_input_as_handled()
```

---

## Final Notes

Your mental model was right all along:
- **PlayerShell** = The player's persistent interface
- **Farm** = A swappable game instance
- **Input flows down**: Shell catches what it wants, rest goes to farm
- **Actions, not keycodes**: Godot's Input Map is the right abstraction

The key fix is:
1. PlayerShell uses `_input()` (high priority)
2. Farm uses `_unhandled_input()` (low priority)
3. Modals get routed through PlayerShell, not their own handlers
4. No flags, no signal timing issues, just Godot's natural input flow
