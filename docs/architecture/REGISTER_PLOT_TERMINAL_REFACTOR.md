# Register→Plot→Terminal Architecture Refactor

**Date:** 2026-02-14
**Status:** ✅ Implemented

## Overview

Major architectural refactor to establish clean layer separation:
- **Register** (quantum simulation - headless compatible)
- **BasePlot** (farm mechanics - headless compatible)
- **Terminal** (UI instrument - UI layer only)

## Previous Architecture (Terminal-Driven)

```
Terminal (UI) → Register (Quantum)
     ↓
   Plot (Farm) [just a holder]
```

**Problems:**
- Terminal (UI layer) drove simulation binding
- Plot was passive, just holding a reference
- Couldn't run headless (Terminal required)
- Save/load mixed UI and simulation concerns

## New Architecture (Simulation-Driven)

```
Register (Quantum) → BasePlot (Farm) → Terminal (UI)
         ↓                 ↓
      Biome          Grid Position
```

**Benefits:**
- ✅ **Headless compatible** - BasePlot works without Terminal
- ✅ **Clean layering** - Simulation → Farm → UI
- ✅ **Plot is anchor** - Bubbles tether to plot position naturally
- ✅ **Terminal is ephemeral** - Created/destroyed by UI, not saved
- ✅ **Simpler save/load** - Only save plot state, Terminal reconstructed

## Implementation Changes

### 1. BasePlot Owns Register Binding

**Before:**
```gdscript
class BasePlot:
    var bound_terminal  # Terminal owns state

    func get_register_id():
        return bound_terminal.bound_register_id if bound_terminal else -1
```

**After:**
```gdscript
class BasePlot:
    # Register binding (simulation layer - headless compatible)
    var bound_register_id: int = -1
    var bound_biome_name: String = ""
    var north_emoji: String = ""
    var south_emoji: String = ""
    var is_measured: bool = false
    var measured_outcome: String = ""
    var measured_probability: float = 0.0

    # Terminal reference (UI layer - optional)
    var ui_terminal = null  # Only exists when UI active

    func bind_to_register(register_id, biome_name, emoji_pair):
        # Simulation layer - works in headless mode
```

### 2. Terminal Becomes UI Proxy

Terminal is now a **view** of BasePlot state, not the source of truth:

```gdscript
class Terminal:
    var source_plot: BasePlot  # Delegates to plot

    # All getters delegate
    var bound_register_id:
        get: return source_plot.bound_register_id if source_plot else -1
```

### 3. Save/Load Uses Plot State

**Capture (simplified):**
```gdscript
# NEW: Read from BasePlot directly
if plot.is_active():
    plot_data["register_id"] = plot.bound_register_id
    plot_data["biome_name"] = plot.bound_biome_name
    plot_data["north_emoji"] = plot.north_emoji
    plot_data["south_emoji"] = plot.south_emoji
    if plot.is_measured:
        plot_data["measured_outcome"] = plot.measured_outcome
        plot_data["measured_probability"] = plot.measured_probability
```

**Restore (simplified):**
```gdscript
# NEW: Bind register to plot directly
plot.bind_to_register(saved_register, saved_biome, emoji_pair)

if plot_data.get("has_been_measured"):
    plot.mark_measured(outcome, probability)

# Emit signal - UI creates Terminal in response
farm.terminal_bound.emit(pos, "", emoji_pair)
```

### 4. Selection State Persists

**New feature:** Player selection configurations are saved:

```gdscript
# GameState.gd
@export var selected_plot_positions: Array = []  # Array of Vector2i

# Capture selection
state.selected_plot_positions = input_handler.get_checked_plots()

# Restore selection
input_handler.set_checked_plots(state.selected_plot_positions)
```

**Use case:** Players can save complex multi-select configurations before executing batch operations.

## Migration Strategy

### Backward Compatibility

Added property alias for gradual migration:

```gdscript
# BasePlot.gd
var bound_terminal:  # Backward compatibility alias
    get: return ui_terminal
    set(value): ui_terminal = value
```

This allows existing code to work while transitioning to new architecture.

### Terminal Pool

Terminal pool still exists for now, but its role is changing:
- Currently: Manages binding lifecycle
- Future: Just a UI object pool for reuse
- Eventually: May be replaced with on-demand Terminal creation

## Testing

New test suite in `Tests/SaveLoad/` verifies:

- ✅ Level 1: Basic state (economy, grid, speed)
- 🔍 Level 2: Terminal bindings (register→plot mapping)
- ⏳ Level 3: Quantum state (register infrastructure)

Run tests:
```bash
gut -gdir=res://Tests/SaveLoad/ -gtest=test_terminal_bindings.gd
```

## Future Work

1. **Complete Terminal decoupling** - Make Terminal purely UI
2. **Plot-based actions** - ProbeActions work with BasePlot directly
3. **Headless testing** - Verify simulation runs without UI
4. **Register structures** - Add rendering hooks to BasePlot for register visualization

## Files Modified

- `Core/GameMechanics/BasePlot.gd` - Now owns register binding state
- `Core/GameState/GameState.gd` - Added `selected_plot_positions`
- `Core/GameState/GameStateSerializer.gd` - Uses plot state, saves selection
- `UI/Core/QuantumInstrumentInput.gd` - Added selection getters/setters
- `Tests/SaveLoad/*` - New test suite for verifying persistence

## References

- Architecture discussion: 2026-02-14 user session
- Memory: `~/.claude/projects/.../memory/MEMORY.md`
- Tests: `Tests/SaveLoad/README.md`
