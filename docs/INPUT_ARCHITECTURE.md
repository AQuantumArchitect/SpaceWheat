# Input Architecture

This document describes the input handling architecture for SpaceWheat.

## Overview

Input is processed through a **layered architecture** where each layer has a specific responsibility. Events flow from top to bottom, and can be **consumed** (stopping propagation) or **passed through** to the next layer.

## Layer Diagram

```
KEYBOARD INPUT                          MOUSE/TOUCH INPUT
      │                                        │
      ▼                                        ▼
┌─────────────────────┐              ┌─────────────────────┐
│ Layer 0             │              │ (Godot UI System)   │
│ InputController     │              │ _gui_input for      │
│ _input() KEYBOARD   │              │ UI Controls         │
│ Menu: ESC/K/V/N/C   │              │ mouse_filter=STOP   │
│ ════════════════    │              │ ════════════════    │
│ CONSUMES: menu keys │              │ CONSUMES: UI clicks │
│ BLOCKS: when menu   │              │                     │
└─────────────────────┘              └─────────────────────┘
          │                                    │
          ▼                                    │
┌─────────────────────┐                        │
│ Layer 2             │                        │
│ FarmInputHandler    │                        │
│ _input() KEYBOARD   │                        │
│ 1-6/QER/TYUIOP/WASD │                        │
│ ════════════════    │                        │
│ CONSUMES: actions   │                        │
└─────────────────────┘                        │
          │                                    │
          ▼                                    ▼
┌─────────────────────────────────────────────────────────┐
│ Layer 3: PlotGridDisplay._input() - MOUSE DRAG         │
│ Handles: Drag selection across multiple plots          │
│ ═══════════════════════════════════════════════════    │
│ CONSUMES: Only when click IS on a plot tile            │
│ PASSES: All clicks NOT on plot tiles (→ bubbles)       │
└─────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────┐
│ Layer 5: QuantumForceGraph._unhandled_input()           │
│ Handles: Bubble tap (measure/harvest), swipe (entangle)│
│ ═══════════════════════════════════════════════════    │
│ CONSUMES: When gesture detected on quantum bubble      │
│ IGNORES: Everything else                               │
└─────────────────────────────────────────────────────────┘
```

## Handler Contracts

### Layer 0: InputController

**File:** `UI/Controllers/InputController.gd`

| Property | Value |
|----------|-------|
| Phase | `_input()` - First priority |
| Handles | `InputEventKey` only |
| Keys | ESC, K, V, N, C, Q(menu), R(menu), TAB, G, SPACE, ARROWS |
| Consumes | Always for handled keys |
| Blocks | ALL downstream when `menu_visible=true` |
| Emits | `menu_toggled`, `vocabulary_requested`, `keyboard_help_requested`, etc. |

### Layer 2: FarmInputHandler

**File:** `UI/FarmInputHandler.gd`

| Property | Value |
|----------|-------|
| Phase | `_input()` - Runs after InputController |
| Handles | `InputEventKey` via input actions |
| Actions | `tool_1-6`, `action_q/e/r`, `select_plot_*`, `move_*`, `toggle_help` |
| Consumes | Always for handled actions |
| Emits | `tool_changed`, `submenu_changed`, `action_performed` |
| Requires | `GridConfig` injection for plot selection |

### Layer 3: PlotGridDisplay

**File:** `UI/PlotGridDisplay.gd`

| Property | Value |
|----------|-------|
| Phase | `_input()` - Runs after FarmInputHandler |
| Handles | `InputEventMouseButton`, `InputEventMouseMotion`, `InputEventScreenTouch` |
| Purpose | Multi-plot drag selection |
| Consumes | **ONLY** when click/touch IS on a plot tile |
| Passes | All clicks NOT on plot tiles (allows bubble taps) |
| **CRITICAL** | Must NOT block non-plot clicks |

### Layer 5: QuantumForceGraph

**File:** `Core/Visualization/QuantumForceGraph.gd`

| Property | Value |
|----------|-------|
| Phase | `_unhandled_input()` - Lowest priority |
| Handles | `InputEventMouseButton`, `InputEventScreenTouch` |
| Purpose | Bubble tap (measure/harvest) and swipe (entangle) gestures |
| Consumes | When gesture detected on quantum node |
| Emits | `node_clicked`, `node_swiped_to` |
| **Touch Support** | Full - handles both mouse and touch identically |

## Godot Input Processing Order

Godot processes input in this exact order:

1. **`_input()` phase** - Custom input handlers run first
   - InputController
   - FarmInputHandler
   - PlotGridDisplay

2. **`_gui_input()` phase** - Control nodes receive events
   - UI Buttons, panels, etc.
   - Only if event not consumed in phase 1

3. **`_unhandled_input()` phase** - Unhandled events reach here
   - QuantumForceGraph (bubble gestures)
   - Only if event not consumed in phases 1 or 2

## Event Consumption Rules

**An event stops propagating when:**
- Any handler calls `get_viewport().set_input_as_handled()`
- A Control node with `mouse_filter = STOP` receives it via `_gui_input()`

**An event continues propagating when:**
- Handler processes event WITHOUT calling `set_input_as_handled()`
- A Control node with `mouse_filter = IGNORE` lets it pass through

## Input Flow Examples

### Example 1: ESC Key Press

```
Key Press (ESC)
    ↓
InputController._input()
    ↓ "Is menu key? YES"
    ↓ emit(menu_toggled)
    ↓ get_viewport().set_input_as_handled()
    ✗ Event consumed, stops here
```

### Example 2: Q Key (Plant Action)

```
Key Press (Q)
    ↓
InputController._input()
    ↓ "Is menu visible? NO"
    ↓ "Is menu key (ESC/K/V)? NO"
    ↓ (does not consume)
    ↓
FarmInputHandler._input()
    ↓ "Is action_q pressed? YES"
    ↓ execute_tool_action("q")
    ↓ get_viewport().set_input_as_handled()
    ✗ Event consumed, stops here
```

### Example 3: Mouse Click on Bubble

```
Mouse Click on bubble (not on plot)
    ↓
PlotGridDisplay._input()
    ↓ "Is click on a plot tile? NO"
    ↓ (does NOT consume - allows pass-through)
    ↓
QuantumForceGraph._unhandled_input()
    ↓ "Is click on a quantum node? YES"
    ↓ emit(node_clicked)
    ↓ Handle measure/harvest action
    ✗ Event consumed, action performed
```

### Example 4: Mouse Click on Plot Tile

```
Mouse Click on plot tile
    ↓
PlotGridDisplay._input()
    ↓ "Is click on a plot tile? YES"
    ↓ _start_drag(plot_pos)
    ↓ get_viewport().set_input_as_handled()
    ✗ Event consumed, stops here
```

## Troubleshooting

### Bubble taps not working

1. Check if PlotGridDisplay._input() is consuming the event
2. Look for "✅ Consumed by PlotGridDisplay" in console
3. If consumed, the click hit a plot tile, not a bubble
4. Verify QuantumForceGraph receives event: look for "_unhandled_input" logs

### Keyboard actions not working

1. Check if InputController is blocking (menu_visible=true)
2. Look for "blocking game input" in console
3. Verify FarmInputHandler has valid GridConfig injection

### UI buttons not responding

1. Check `mouse_filter` property (should be `STOP` for clickable buttons)
2. Verify no other handler consumed the event first
3. Check z-index ordering in scene tree

## Best Practices

1. **Explicit consumption**: Always call `get_viewport().set_input_as_handled()` when you handle an event
2. **Pass-through default**: If you don't handle it, don't consume it
3. **Single responsibility**: Each handler should handle one type of input
4. **Document contracts**: Update this file when adding new handlers

## Files Reference

| File | Layer | Purpose |
|------|-------|---------|
| `UI/Controllers/InputController.gd` | 0 | Global menu control |
| `UI/FarmInputHandler.gd` | 2 | Tool/action system |
| `UI/PlotGridDisplay.gd` | 3 | Mouse drag selection |
| `Core/Visualization/QuantumForceGraph.gd` | 5 | Bubble touch gestures |
