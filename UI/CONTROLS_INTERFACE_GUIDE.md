# ControlsInterface Architecture Guide

## Overview

The **ControlsInterface** is an abstract contract that decouples the UI Layout from specific simulation machinery. This allows:

- ✅ **Flexible simulation swapping** - Replace Farm with any simulation that implements the interface
- ✅ **Clean separation** - UI doesn't know about Farm internals
- ✅ **Testable** - Mock the interface for UI testing without running simulation
- ✅ **Extensible** - Add new actions/signals without changing UI code

## Architecture Flow

```
User Input (Keyboard)
         ↓
FarmInputHandler (detects 1-6, Q/E/R, WASD)
         ↓
FarmUIControlsManager (routes to simulation & UI)
         ↓
ControlsInterface (abstract contract)
         ↓
Farm / OtherSimulation (implementation)
         ↓
Simulation State Changes → ControlsInterface Signals → UI Updates
```

## For Simulation Team

### Option 1: Make Farm Implement ControlsInterface (Recommended)

```gdscript
# In Farm.gd
extends ControlsInterface

# Implement required methods:
func select_tool(tool_num: int) -> void:
    current_tool = tool_num
    tool_selected.emit(tool_num)

func select_plot(position: Vector2i) -> void:
    current_selection = position
    plot_selected.emit(position)

func trigger_action(action_key: String, position: Vector2i) -> bool:
    # Execute action, return success/failure
    var success = _execute_action(action_key, position)
    action_executed.emit(action_key, position, success)
    return success

# Implement query methods:
func get_current_tool() -> int:
    return current_tool

func get_current_selection() -> Vector2i:
    return current_selection

func get_credits() -> int:
    return economy.credits

func get_inventory(resource: String) -> int:
    return economy.get_inventory(resource)
```

Then in the game setup:
```gdscript
var farm = Farm.new()
ui_controller.inject_controls(farm)  # Pass as ControlsInterface
```

### Option 2: Use FarmControlsAdapter (Non-invasive)

If you don't want to modify Farm directly:

```gdscript
# In your game setup code
var farm = Farm.new()
var controls = FarmControlsAdapter.new(farm)
controls.bridge_farm_signals()
ui_controller.inject_controls(controls)
```

The adapter wraps Farm and translates method calls.

### Option 3: Create Custom Implementation

Create a new class that implements ControlsInterface:

```gdscript
# CustomSimulation.gd
extends ControlsInterface

func select_tool(tool_num: int) -> void:
    # Your custom logic
    pass

# ... implement other methods ...
```

## Signals You Must Emit

From your simulation, emit these signals to update the UI:

```gdscript
# Tool/action signals
tool_selected.emit(tool_num)
plot_selected.emit(position)
action_executed.emit(action, position, success)

# State change signals
credits_changed.emit(new_amount)
inventory_changed.emit(resource, amount)
plot_state_changed.emit(position)

# Events
plot_planted.emit(position)
plot_harvested.emit(position, yield_amount)
qubit_measured.emit(position, outcome)
plots_entangled.emit(pos1, pos2)
```

## UI Integration Flow

1. **User presses key** (e.g., "1" for Plant tool)
2. **FarmInputHandler** detects it, emits `tool_changed` signal
3. **FarmUIControlsManager** receives signal, calls:
   - `controls.select_tool(1)` → Tells simulation to select tool
   - `ui_controller.on_tool_changed(1, info)` → Updates UI display
4. **Simulation responds** by emitting `tool_selected` signal
5. **FarmUIControlsManager** receives `tool_selected`, routes to UI for confirmation
6. **UI updates** - tool buttons change color, action preview updates

## Key Methods to Implement

```gdscript
# Control actions (UI calls these)
select_tool(tool_num: int)        # User pressed 1-6
select_plot(position: Vector2i)   # User pressed WASD or arrow
trigger_action(action, position)  # User pressed Q/E/R
move_cursor(direction)            # WASD movement
quick_select_location(index)      # Y/U/I/O/P keys

# Query current state (UI calls these)
get_current_tool() -> int
get_current_selection() -> Vector2i
get_credits() -> int
get_inventory(resource: String) -> int
```

## Benefits

| Aspect | Before | After |
|--------|--------|-------|
| **Coupling** | UI tightly bound to Farm | UI only depends on interface |
| **Testing** | Must run full Farm to test UI | Can mock ControlsInterface |
| **Swapping** | Changing simulation = major refactor | Drop-in replacement |
| **Extensibility** | Adding features requires UI changes | Just implement new methods |

## Example: Swapping Simulations

```gdscript
# Old: Farm only
var farm = Farm.new()
ui_controller.inject_farm(farm)

# New: Can swap at runtime!
var original_farm = Farm.new()
var mockup_simulation = MockSimulation.new()

# Just change this line:
ui_controller.inject_controls(original_farm)      # Use real farm
# or
ui_controller.inject_controls(mockup_simulation)  # Use mock

# UI works the same either way!
```

## File Locations

- **ControlsInterface.gd** - The abstract contract/interface
- **FarmControlsAdapter.gd** - Example adapter for wrapping existing Farm
- **FarmUIControlsManager.gd** - Routes input through the interface
- **FarmUIController.gd** - Public API to inject controls/farm

## Questions?

The simulation team should:
1. Choose implementation strategy (Option 1/2/3 above)
2. Implement the ControlsInterface methods
3. Emit the required signals at appropriate times
4. Test by injecting into UI via `inject_controls()` method

The UI team can:
1. Continue using current code
2. No changes needed if simulation implements interface
3. Can add new methods to ControlsInterface as needed (just update the interface definition)
