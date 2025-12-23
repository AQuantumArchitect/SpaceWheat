# Controls Extraction Guide

## Overview
The input handling and signal routing has been extracted from FarmUIController into a separate **FarmUIControlsManager** module.

**Goal:** Clean separation of concerns
- **FarmUIControlsManager**: All input, events, signals
- **FarmUIController**: Visual layout and rendering only
- **GUI Team Focus**: Work on design without touching simulation

---

## What Was Extracted

### 1. Input Handler Creation
```gdscript
# FROM FarmUIController._create_input_handlers()
# TO FarmUIControlsManager._create_input_handlers()

- FarmInputHandler (keyboard: 1-6, Q/E/R, WASD, arrow keys)
- InputController (overlay: ESC, C, V, N, K toggles)
```

### 2. Signal Connections
All signal routing from:
- Farm (plot_planted, plot_unplanted, qubit_measured, plot_harvested, plots_entangled)
- Economy (credits_changed, inventory_changed)
- InputHandler (tool_changed, plot_selected, action_triggered)
- InputController (toggle_keyboard_help, toggle_debug)

### 3. Event Handlers
All `_on_*()` methods that route to UI updates:
```
_on_plot_planted()
_on_plot_unplanted()
_on_credits_changed()
_on_inventory_changed()
_on_qubit_measured()
_on_plot_harvested()
_on_plots_entangled()
_on_tool_applied()
_on_plot_state_changed()
_on_tool_changed()
_on_plot_selected()
_on_action_triggered()
_on_toggle_keyboard_help()
_on_toggle_debug()
```

---

## Integration Steps

### 1. Create and Initialize FarmUIControlsManager
```gdscript
# In FarmUIController._create_input_handlers() - REMOVE
# In FarmUIController._ready() - ADD:

var controls_manager: FarmUIControlsManager = null

func _ready():
    # ... existing layout code ...

    # Create controls manager
    controls_manager = FarmUIControlsManager.new()
    add_child(controls_manager)
    controls_manager.inject_ui_controller(self)
    print("✅ Controls manager created")
```

### 2. Inject Farm Reference
```gdscript
# When farm is injected, pass it to controls:

func inject_farm(farm_ref):
    farm = farm_ref
    # ... existing code ...

    # Connect controls
    if controls_manager:
        controls_manager.inject_farm(farm)
```

### 3. Remove from FarmUIController
- Delete: `_create_input_handlers()`
- Delete: `_connect_all_signals()` and all `_connect_*_signals()` methods
- Delete: All `_on_*()` event handlers
- Delete: `input_handler` and `input_controller` member variables
- Delete: References to input handlers in other methods

### 4. Implement UI Callbacks (Optional)
FarmUIControlsManager calls these methods on the UI controller if they exist:
```
on_plot_planted(pos)
on_plot_unplanted(pos)
update_credits(amount)
update_inventory(resource, amount)
on_qubit_measured(pos, outcome)
on_plot_harvested(pos, yield)
on_plots_entangled(pos1, pos2)
on_tool_applied(tool, pos, result)
on_plot_state_changed(pos)
on_tool_changed(tool_num, tool_info)
on_plot_selected(pos)
on_action_triggered(action, pos)
toggle_keyboard_help()
toggle_debug()
```

---

## Files

### New
- `UI/FarmUIControlsManager.gd` - All input/event routing

### Modified
- `UI/FarmUIController.gd` - Remove control code, keep layout

---

## Benefits

1. **Clean Separation**: UI layout team doesn't touch input/signals
2. **Testability**: Controls can be tested independently
3. **Reusability**: FarmUIControlsManager can be used with different UI implementations
4. **Maintainability**: Simulation concerns isolated from visual concerns
5. **Easy Review**: Controls and layout changes are in separate files

---

## Architecture Diagram

```
┌─────────────────────────────────────────┐
│  FarmUIController                       │
│  ├─ Layout (Containers, anchors, size) │
│  ├─ Visual components                  │
│  └─ Render updates                     │
└────────┬────────────────────────────────┘
         │ Injects
         ↓
┌──────────────────────────────────────────┐
│  FarmUIControlsManager                   │
│  ├─ FarmInputHandler (keyboard)         │
│  ├─ InputController (overlays)          │
│  ├─ Signal connections                  │
│  └─ Event routing                       │
└────────┬─────────────────────────────────┘
         │ Routes events to
         ↓
        Farm (Simulation)
```

---

## Status

- ✅ Controls extracted to separate file
- ⏳ Integration with FarmUIController (for GUI team)
- ⏳ Testing with actual UI components

Ready for GUI team implementation!
