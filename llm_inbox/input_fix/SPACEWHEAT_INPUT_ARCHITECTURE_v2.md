# SpaceWheat Input Architecture v2
## Player Shell → Farm Chain of Responsibility

**Design Philosophy:** The Player Shell is the player's interface. Farms are swappable game instances underneath. Input flows down through the shell to the currently active farm.

---

## Hierarchy

```
Player (conceptual)
└── PlayerShell (Control, persistent)
    ├── Overlays/Modals (QuestBoard, EscapeMenu, Vocabulary, etc.)
    ├── Resources Panel
    ├── Quest Tracker
    └── FarmContainer (swappable)
        └── Farm (current farm instance)
            ├── Plots[]
            │   └── Biome reference
            └── Biome
                └── QuantumComputer
                    └── Qubits
```

**Key principle:** PlayerShell persists. Farms swap in/out. Input routing lives in PlayerShell.

---

## Input Flow

```
┌──────────────────────────────────────────────────────────────────┐
│  GODOT ENGINE                                                    │
│  Keyboard/Touch → Input Map → Actions                            │
│  (KEY_C → "toggle_quests", KEY_U → "select_slot_0", etc.)       │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  PLAYER SHELL._input()                                           │
│  ════════════════════                                            │
│                                                                  │
│  1. Is a MODAL open? (QuestBoard, EscapeMenu, SaveLoad)         │
│     YES → modal.handle_input(event) → CONSUME                   │
│     NO  → continue                                               │
│                                                                  │
│  2. Is this a SHELL action? (toggle_quests, toggle_vocab, etc.) │
│     YES → handle_shell_action(event) → CONSUME                  │
│     NO  → continue                                               │
│                                                                  │
│  3. Let input FALL THROUGH to _unhandled_input()                │
│     (Do NOT call set_input_as_handled)                          │
└──────────────────────────────────────────────────────────────────┘
                              │
                    (input not consumed)
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  FARM._unhandled_input() (or FarmInputHandler)                   │
│  ══════════════════════════════════════════════                  │
│                                                                  │
│  Receives ONLY actions that PlayerShell didn't handle           │
│  - select_plot_0, select_plot_1, etc.                           │
│  - apply_tool                                                    │
│  - navigate_left, navigate_right                                 │
│                                                                  │
│  Farm-specific: different farms may handle different actions    │
│  If farm doesn't recognize action → ignore (no error)           │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│  FARM SIGNAL CHAIN                                               │
│  ══════════════════                                              │
│                                                                  │
│  farm.apply_tool(plot_index)                                    │
│      → plot.receive_action(tool, ...)                           │
│          → biome.execute_action(...)                            │
│              → quantum_computer.measure/entangle/etc.           │
│                                                                  │
│  Success/failure depends on biome properties                    │
│  Different biomes may reject certain actions                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## Godot Input Map Actions

Define these in **Project → Project Settings → Input Map**:

### Shell Actions (Handled by PlayerShell)
```
toggle_menu          → Escape
toggle_quests        → C
toggle_vocabulary    → V
toggle_network       → N
toggle_keyboard_help → K
toggle_biome_inspect → B
toggle_quantum_cfg   → Shift+Q
```

### Modal Actions (Handled by active modal)
```
modal_confirm        → Enter, Q (context-dependent)
modal_cancel         → Escape
modal_nav_up         → Up Arrow
modal_nav_down       → Down Arrow
slot_0               → U
slot_1               → I
slot_2               → O
slot_3               → P
slot_action_primary  → Q
slot_action_secondary→ E
slot_action_tertiary → R
```

### Farm Actions (Handled by Farm, unhandled by Shell)
```
select_plot_0        → U (same key, different context!)
select_plot_1        → I
select_plot_2        → O
select_plot_3        → P
apply_tool           → Space
navigate_left        → Left Arrow, A
navigate_right       → Right Arrow, D
navigate_up          → Up Arrow, W
navigate_down        → Down Arrow, S
cycle_goal           → Tab, G
```

**Note:** U/I/O/P map to BOTH `slot_X` (modal) and `select_plot_X` (farm). The shell consumes `slot_X` when modal is open, so farm never sees it.

---

## Implementation

### PlayerShell.gd - The Input Router

```gdscript
class_name PlayerShell
extends Control

## Player Shell - The player's persistent interface
## Handles overlays, modals, and routes input to current farm

signal farm_changed(old_farm: Node, new_farm: Node)

# Modal management
var modal_stack: Array[Control] = []  # Stack of open modals

# Current farm (swappable)
var current_farm: Node = null
var farm_container: Control

# Overlay instances
var quest_board: Control
var escape_menu: Control
var vocabulary_overlay: Control
# ... etc

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    process_mode = Node.PROCESS_MODE_ALWAYS  # Handle input even when paused
    
    _create_overlays()
    _setup_farm_container()

func _input(event: InputEvent) -> void:
    # LAYER 1: Modal input (highest priority)
    if not modal_stack.is_empty():
        var active_modal = modal_stack[-1]
        if active_modal.has_method("handle_input"):
            if active_modal.handle_input(event):
                get_viewport().set_input_as_handled()
                return
    
    # LAYER 2: Shell actions (overlay toggles)
    if _handle_shell_action(event):
        get_viewport().set_input_as_handled()
        return
    
    # LAYER 3: Let input fall through to farm
    # (Don't call set_input_as_handled - farm's _unhandled_input will receive it)

func _handle_shell_action(event: InputEvent) -> bool:
    """Handle player shell actions. Returns true if handled."""
    
    if event.is_action_pressed("toggle_menu"):
        # ESC: Special handling
        if not modal_stack.is_empty():
            # Close topmost modal
            _pop_modal()
        else:
            # Open escape menu
            _push_modal(escape_menu)
            escape_menu.show_menu()
        return true
    
    if event.is_action_pressed("toggle_quests"):
        _toggle_overlay(quest_board, "quest_board")
        return true
    
    if event.is_action_pressed("toggle_vocabulary"):
        _toggle_overlay(vocabulary_overlay, "vocabulary")
        return true
    
    if event.is_action_pressed("toggle_network"):
        _toggle_overlay(network_overlay, "network")
        return true
    
    if event.is_action_pressed("toggle_keyboard_help"):
        _toggle_overlay(keyboard_help, "keyboard_help")
        return true
    
    if event.is_action_pressed("toggle_biome_inspect"):
        # B doesn't block - it's a non-modal overlay
        biome_inspector.visible = not biome_inspector.visible
        return true  # Still consume the key
    
    return false  # Not a shell action

func _toggle_overlay(overlay: Control, name: String) -> void:
    """Toggle a modal overlay"""
    if overlay.visible:
        _pop_modal()
        overlay.visible = false
    else:
        overlay.visible = true
        _push_modal(overlay)

# ═══════════════════════════════════════════════════════════════
# MODAL STACK MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func _push_modal(modal: Control) -> void:
    """Push modal onto stack (makes it receive input)"""
    if modal not in modal_stack:
        modal_stack.append(modal)
        print("📋 Modal pushed: %s (stack size: %d)" % [modal.name, modal_stack.size()])

func _pop_modal() -> Control:
    """Pop and return topmost modal"""
    if modal_stack.is_empty():
        return null
    var modal = modal_stack.pop_back()
    print("📋 Modal popped: %s (stack size: %d)" % [modal.name, modal_stack.size()])
    return modal

func is_modal_open() -> bool:
    return not modal_stack.is_empty()

# ═══════════════════════════════════════════════════════════════
# FARM MANAGEMENT
# ═══════════════════════════════════════════════════════════════

func set_farm(farm: Node) -> void:
    """Swap to a different farm"""
    var old_farm = current_farm
    
    # Disconnect old farm
    if old_farm and old_farm.is_inside_tree():
        farm_container.remove_child(old_farm)
    
    # Connect new farm
    current_farm = farm
    if farm:
        farm_container.add_child(farm)
    
    farm_changed.emit(old_farm, farm)
    print("🌾 Farm changed: %s → %s" % [
        old_farm.name if old_farm else "none",
        farm.name if farm else "none"
    ])

func get_current_farm() -> Node:
    return current_farm
```

### Modal Interface (QuestBoard, EscapeMenu, etc.)

```gdscript
# UI/Panels/QuestBoard.gd
class_name QuestBoard
extends Control

## Modal Quest Board
## Receives input from PlayerShell when active

func handle_input(event: InputEvent) -> bool:
    """Handle input routed from PlayerShell.
    Returns true if input was consumed.
    """
    if not visible:
        return false
    
    # Faction browser takes priority if open
    if is_browser_open and faction_browser.visible:
        return faction_browser.handle_input(event)
    
    # Modal cancel (ESC)
    if event.is_action_pressed("modal_cancel"):
        close_board()
        return true
    
    # Slot selection
    if event.is_action_pressed("slot_0"):
        select_slot(0)
        return true
    if event.is_action_pressed("slot_1"):
        select_slot(1)
        return true
    if event.is_action_pressed("slot_2"):
        select_slot(2)
        return true
    if event.is_action_pressed("slot_3"):
        select_slot(3)
        return true
    
    # Slot actions
    if event.is_action_pressed("slot_action_primary"):  # Q
        action_q_on_selected()
        return true
    if event.is_action_pressed("slot_action_secondary"):  # E
        action_e_on_selected()
        return true
    if event.is_action_pressed("slot_action_tertiary"):  # R
        action_r_on_selected()
        return true
    
    # Open faction browser
    if event.is_action_pressed("toggle_quests"):  # C again
        open_faction_browser()
        return true
    
    return false  # Didn't handle this input

func open_board() -> void:
    visible = true
    _refresh_biome_state()
    _refresh_slots()
    # Note: PlayerShell handles pushing to modal stack

func close_board() -> void:
    visible = false
    is_browser_open = false
    if faction_browser:
        faction_browser.visible = false
    board_closed.emit()
    # Note: PlayerShell handles popping from modal stack
```

### Farm Input Handler

```gdscript
# Core/Farm.gd (or UI/FarmInputHandler.gd if separate)
class_name Farm
extends Node

## Farm - A swappable game instance
## Receives unhandled input that PlayerShell didn't consume

func _ready() -> void:
    # Use _unhandled_input, not _input
    set_process_unhandled_input(true)

func _unhandled_input(event: InputEvent) -> void:
    """Handle gameplay input.
    Only runs if PlayerShell didn't consume it.
    """
    
    # Plot selection (same keys as modal slots, but different context)
    if event.is_action_pressed("select_plot_0"):
        select_plot(0)
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("select_plot_1"):
        select_plot(1)
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("select_plot_2"):
        select_plot(2)
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("select_plot_3"):
        select_plot(3)
        get_viewport().set_input_as_handled()
        return
    
    # Tool application
    if event.is_action_pressed("apply_tool"):
        apply_current_tool()
        get_viewport().set_input_as_handled()
        return
    
    # Navigation
    if event.is_action_pressed("navigate_left"):
        move_selection(-1, 0)
        get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed("navigate_right"):
        move_selection(1, 0)
        get_viewport().set_input_as_handled()
        return
    
    # Goal cycling
    if event.is_action_pressed("cycle_goal"):
        cycle_active_goal()
        get_viewport().set_input_as_handled()
        return

func select_plot(index: int) -> void:
    """Select a plot and potentially apply action"""
    if index >= 0 and index < plots.size():
        selected_plot = plots[index]
        plot_selected.emit(index)

func apply_current_tool() -> void:
    """Apply the current tool to the selected plot"""
    if not selected_plot:
        return
    
    # This is where the signal chain begins
    # Farm → Plot → Biome → QuantumComputer
    var result = selected_plot.receive_action(current_tool, tool_params)
    action_completed.emit(current_tool, result)
```

---

## Input Map Configuration

Add to `project.godot` or configure in Project Settings → Input Map:

```ini
[input]

# Shell actions
toggle_menu={
    "events": [Object(InputEventKey, "keycode":4194305)]  # Escape
}
toggle_quests={
    "events": [Object(InputEventKey, "keycode":67)]  # C
}
toggle_vocabulary={
    "events": [Object(InputEventKey, "keycode":86)]  # V
}
toggle_network={
    "events": [Object(InputEventKey, "keycode":78)]  # N
}
toggle_keyboard_help={
    "events": [Object(InputEventKey, "keycode":75)]  # K
}
toggle_biome_inspect={
    "events": [Object(InputEventKey, "keycode":66)]  # B
}

# Modal actions
modal_cancel={
    "events": [Object(InputEventKey, "keycode":4194305)]  # Escape
}
modal_confirm={
    "events": [Object(InputEventKey, "keycode":4194309)]  # Enter
}
modal_nav_up={
    "events": [Object(InputEventKey, "keycode":4194320)]  # Up
}
modal_nav_down={
    "events": [Object(InputEventKey, "keycode":4194322)]  # Down
}
slot_0={
    "events": [Object(InputEventKey, "keycode":85)]  # U
}
slot_1={
    "events": [Object(InputEventKey, "keycode":73)]  # I
}
slot_2={
    "events": [Object(InputEventKey, "keycode":79)]  # O
}
slot_3={
    "events": [Object(InputEventKey, "keycode":80)]  # P
}
slot_action_primary={
    "events": [Object(InputEventKey, "keycode":81)]  # Q
}
slot_action_secondary={
    "events": [Object(InputEventKey, "keycode":69)]  # E
}
slot_action_tertiary={
    "events": [Object(InputEventKey, "keycode":82)]  # R
}

# Farm/Game actions (same keys, different action names)
select_plot_0={
    "events": [Object(InputEventKey, "keycode":85)]  # U
}
select_plot_1={
    "events": [Object(InputEventKey, "keycode":73)]  # I
}
select_plot_2={
    "events": [Object(InputEventKey, "keycode":79)]  # O
}
select_plot_3={
    "events": [Object(InputEventKey, "keycode":80)]  # P
}
apply_tool={
    "events": [Object(InputEventKey, "keycode":32)]  # Space
}
navigate_left={
    "events": [Object(InputEventKey, "keycode":4194319), Object(InputEventKey, "keycode":65)]  # Left, A
}
navigate_right={
    "events": [Object(InputEventKey, "keycode":4194321), Object(InputEventKey, "keycode":68)]  # Right, D
}
navigate_up={
    "events": [Object(InputEventKey, "keycode":4194320), Object(InputEventKey, "keycode":87)]  # Up, W
}
navigate_down={
    "events": [Object(InputEventKey, "keycode":4194322), Object(InputEventKey, "keycode":83)]  # Down, S
}
cycle_goal={
    "events": [Object(InputEventKey, "keycode":4194306), Object(InputEventKey, "keycode":71)]  # Tab, G
}
```

---

## Why This Architecture Works

### 1. Natural Priority Order
- PlayerShell uses `_input()` → runs first
- PlayerShell can consume OR let fall through
- Farm uses `_unhandled_input()` → runs only if shell didn't consume

### 2. Clean Swappability
```gdscript
# Swap farms with one call
player_shell.set_farm(new_farm)

# All input automatically routes to the new farm
# No signal rewiring needed
```

### 3. Action-Based (Rebindable)
```gdscript
# Code reads as intent
if event.is_action_pressed("apply_tool"):

# Not implementation
if event.keycode == KEY_SPACE:
```

### 4. Modal Stack Naturally Works
```
modal_stack = ["escape_menu", "save_load"]
# save_load gets input first (it's on top)
# When closed, escape_menu gets input
# When both closed, farm gets input
```

### 5. Non-Blocking Overlays Supported
```gdscript
# B key for biome inspector - doesn't push to modal stack
if event.is_action_pressed("toggle_biome_inspect"):
    biome_inspector.visible = not biome_inspector.visible
    return true  # Consume key, but don't block other input
```

---

## Migration Path

### Step 1: Define Input Map Actions
Add all actions to Project Settings → Input Map

### Step 2: Refactor PlayerShell
- Move input handling from InputController to PlayerShell
- Implement `_input()` with modal stack check
- Implement `handle_shell_action()`

### Step 3: Update Modals
- Change `_unhandled_key_input()` to `handle_input(event) -> bool`
- Use action names instead of keycodes
- Remove `get_viewport().set_input_as_handled()` (caller does it)

### Step 4: Update Farm
- Move game input from InputController to Farm
- Use `_unhandled_input()` with action names

### Step 5: Delete InputController
- No longer needed - PlayerShell and Farm handle everything

---

## Summary

```
╔═══════════════════════════════════════════════════════════════════════╗
║  PLAYER SHELL owns input routing                                      ║
║  ────────────────────────────────                                     ║
║  • Uses _input() for priority                                         ║
║  • Manages modal stack                                                ║
║  • Handles overlays (ESC, C, V, N, K, B)                             ║
║  • Persists across farm swaps                                         ║
╠═══════════════════════════════════════════════════════════════════════╣
║  FARM receives unhandled input                                        ║
║  ─────────────────────────────                                        ║
║  • Uses _unhandled_input()                                            ║
║  • Handles gameplay (UIOP, arrows, Space, etc.)                       ║
║  • Swappable - different farms can handle different actions           ║
║  • Passes commands down: Plot → Biome → Quantum                       ║
╠═══════════════════════════════════════════════════════════════════════╣
║  USE GODOT ACTIONS, NOT KEYCODES                                      ║
║  ─────────────────────────────────                                    ║
║  • event.is_action_pressed("apply_tool")                              ║
║  • Not event.keycode == KEY_SPACE                                     ║
║  • Rebindable, readable, controller-ready                             ║
╚═══════════════════════════════════════════════════════════════════════╝
```
