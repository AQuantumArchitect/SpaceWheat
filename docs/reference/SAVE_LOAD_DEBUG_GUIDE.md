# Save/Load & Debug Environment Guide

## Overview

The SpaceWheat save/load system now includes comprehensive debugging and testing capabilities. This guide shows your dev team how to use the tools for efficient testing and state debugging.

## Quick Start

### Load a Pre-Built Test Environment

```gdscript
# In any script with access to active_farm_view
var env = DebugEnvironment.wealthy_farm()
GameStateManager.apply_state_to_game(env)

# Farm now has 5000 credits and full resources!
```

### Create a Custom Test State

```gdscript
# Custom state with specific parameters
var env = DebugEnvironment.custom_state(
    credits=1000,
    wheat=250,
    planted=10,
    measured=5,
    entangled_pairs=2
)
GameStateManager.apply_state_to_game(env)
```

### Save for Later

```gdscript
var env = DebugEnvironment.wealthy_farm()
DebugEnvironment.save_to_slot(env, 0)  # Save to slot 1

# Later, reload it
var loaded = DebugEnvironment.load_from_slot(0)
GameStateManager.apply_state_to_game(loaded)
```

---

## Available Pre-Built Environments

All of these return a `GameState` that can be applied with:
```gdscript
GameStateManager.apply_state_to_game(env)
```

### 1. **minimal_farm()**
- Fresh start with default 20 credits
- No resources
- Empty farm
- **Use for:** Testing basic mechanics, early-game scenarios

### 2. **wealthy_farm()**
- 5000 credits
- 500 wheat, 200 flour, 150 flowers, 100 labor
- Empty farm (plots available)
- **Use for:** Testing without resource constraints, economy systems

### 3. **fully_planted_farm()**
- All 25 plots planted with wheat
- Wealthy resources
- **Use for:** Testing harvest, plot interactions, visual density

### 4. **fully_measured_farm()**
- All 25 plots planted and measured (quantum state collapsed)
- theta_frozen = false (can still be manipulated)
- **Use for:** Testing quantum mechanics, measured state interactions

### 5. **fully_entangled_farm()**
- All plots in a chain of entanglement: (0,0) <-> (1,0) <-> (2,0) ...
- All planted and available
- **Use for:** Testing entanglement visuals, quantum links, chain reactions

### 6. **mixed_quantum_farm()**
- Top-left (2x2): Measured and frozen
- Top-right (2x3): Entangled but unmeasured
- Bottom (2x5): Empty/unmeasured
- Wealthy resources
- **Use for:** Testing realistic quantum state variety, mixed mechanics

### 7. **icons_active_farm()**
- All icon powers partially active:
  - Biotic: 75%
  - Chaos: 50%
  - Imperium: 25%
- Wealthy resources
- **Use for:** Testing icon visualization, power effects

### 8. **mid_game_farm()**
- Simulates mid-game progression
- 200 credits, moderate resources
- 12 plots planted, 8 measured
- 2 tributes paid, 1 failed
- 1 completed goal (harvest_wheat_1)
- **Use for:** Testing goal system, tribute mechanics, progression UI

---

## Advanced Usage: Custom States

### Shorthand Parameters

```gdscript
DebugEnvironment.custom_state(
    credits=1000,        # Starting credits
    wheat=500,           # Wheat inventory
    flour=200,           # Flour inventory
    flowers=150,         # Flower inventory
    labor=50,            # Labor inventory
    planted=15,          # Number of plots to plant (0-25)
    measured=10,         # Number of plots to measure (0-25)
    entangled_pairs=3,   # Entangled plot pairs (0-12)
    icon_activation={    # Icon power levels
        "biotic": 0.5,
        "chaos": 0.75,
        "imperium": 0.25
    }
)
```

### Building Complex Scenarios

```gdscript
# Create wealthy farm, then customize it
var state = DebugEnvironment.wealthy_farm()

# Manually set specific plot types
state.plots[0]["type"] = PlotType.FLOWER  # Custom plot type
state.plots[1]["type"] = PlotType.FLOUR

# Add goals
state.current_goal_index = 3
state.completed_goals.clear()
state.completed_goals.append_array(["goal_1", "goal_2", "goal_3"])

# Apply all changes
GameStateManager.apply_state_to_game(state)
```

---

## Testing Workflows

### Testing a Feature

1. **Create a focused test environment**
   ```gdscript
   # Testing entanglement mechanics
   var env = DebugEnvironment.fully_entangled_farm()
   GameStateManager.apply_state_to_game(env)
   ```

2. **Run your feature**
   - Interact with the entangled plots
   - Verify behavior matches expectations

3. **Save the state if it's useful**
   ```gdscript
   DebugEnvironment.save_to_slot(env, 0)
   ```

### Testing Progression

```gdscript
# Test early game
GameStateManager.apply_state_to_game(DebugEnvironment.minimal_farm())
# ... test early mechanics ...

# Jump to mid-game
GameStateManager.apply_state_to_game(DebugEnvironment.mid_game_farm())
# ... test mid-game mechanics ...

# Jump to late-game (wealthy)
GameStateManager.apply_state_to_game(DebugEnvironment.wealthy_farm())
# ... test end-game mechanics ...
```

### Debugging Issues

```gdscript
# Create a minimal reproducible case
var env = DebugEnvironment.custom_state(
    credits=100,
    planted=5,  # Only 5 plots to simplify
    measured=2
)

GameStateManager.apply_state_to_game(env)

# Print the state for analysis
DebugEnvironment.print_state(env)

# Export as JSON for detailed inspection
var json = DebugEnvironment.export_as_json(env)
print(json)
```

---

## State Inspection

### Print State Summary

```gdscript
var env = DebugEnvironment.wealthy_farm()
DebugEnvironment.print_state(env)

# Output:
# ============================================================
# 📊 DEBUG STATE: debug_wealthy
# ============================================================
# Credits: 5000
# Wheat: 500 | Flour: 200 | Flowers: 150
# Labor: 100
# Planted: 0/25 | Measured: 0/25 | Entangled: 0/25
# Tributes: 0 paid, 0 failed
# Icon activation: Biotic=0.00 Chaos=0.00 Imperium=0.00
# ============================================================
```

### Export as JSON

```gdscript
var env = DebugEnvironment.wealthy_farm()
var json_data = DebugEnvironment.export_as_json(env)

# json_data contains:
# {
#     "scenario": "debug_wealthy",
#     "economy": {...},
#     "plots": [...],
#     "goals": {...},
#     "icons": {...}
# }
```

---

## Integration with Existing Save/Load System

The `DebugEnvironment` is fully integrated with `GameStateManager`:

```gdscript
# Save a debug state
var env = DebugEnvironment.wealthy_farm()
DebugEnvironment.save_to_slot(env, 0)

# Load it normally through the menu
# Or programmatically:
GameStateManager.load_and_apply(0)
```

---

## Common Testing Patterns

### Test Quantum Mechanics

```gdscript
var env = DebugEnvironment.mixed_quantum_farm()
GameStateManager.apply_state_to_game(env)
# Top-left plots are measured
# Top-right plots are entangled
# Bottom plots are unmeasured
# Perfect for testing different quantum state interactions
```

### Test Resource Economy

```gdscript
# Start wealthy, consume resources, and verify limits
var env = DebugEnvironment.wealthy_farm()
GameStateManager.apply_state_to_game(env)

# Your economy test here
# Can easily reset to wealthy state:
GameStateManager.apply_state_to_game(DebugEnvironment.wealthy_farm())
```

### Test Icon Powers

```gdscript
var env = DebugEnvironment.icons_active_farm()
GameStateManager.apply_state_to_game(env)
# All icons are active at different levels
# Visual effects should be visible
```

### Test Tributes & Goals

```gdscript
var env = DebugEnvironment.custom_state()
env.tributes_paid = 5
env.tributes_failed = 2
env.current_goal_index = 4
env.completed_goals.append_array(["goal_1", "goal_2"])

GameStateManager.apply_state_to_game(env)
# Test tribute UI, goal progress, completion states
```

---

## Headless Testing

Use the diagnostic test to verify save/load works:

```bash
godot --headless --exit-on-finish -s res://test_save_load_diagnostic.gd
```

This runs 5 comprehensive tests:
1. GameState creation and defaults
2. GameState property export
3. Save directory setup
4. Resource save/load cycle
5. Complex state integrity (arrays & entanglement)

---

## Performance Notes

- Creating a debug environment is extremely fast (~1ms)
- Applying state to game is fast (~2-5ms depending on plot count)
- Saving/loading is limited by disk I/O but typically <50ms
- Good for: frequent testing, resetting states, creating test cases
- Each environment can be reused indefinitely

---

## Common Issues

### "No active game to apply state to!"
- Make sure FarmView is instantiated and has called `_ready()`
- The load function needs `active_farm_view` to be set

### Arrays not updating
- Always use `.clear()` and `.append_array()` for typed arrays
- Direct assignment like `arr = [...]` fails in Godot 4

### State not persisting after load
- Call `mark_ui_dirty()`, `mark_goals_dirty()`, `mark_icons_dirty()` on FarmView
- The apply function does this automatically

---

## API Reference

### DebugEnvironment Static Methods

```gdscript
# Pre-built scenarios (all return GameState)
DebugEnvironment.minimal_farm() -> GameState
DebugEnvironment.wealthy_farm() -> GameState
DebugEnvironment.fully_planted_farm() -> GameState
DebugEnvironment.fully_measured_farm() -> GameState
DebugEnvironment.fully_entangled_farm() -> GameState
DebugEnvironment.mixed_quantum_farm() -> GameState
DebugEnvironment.icons_active_farm() -> GameState
DebugEnvironment.mid_game_farm() -> GameState

# Custom state builder
DebugEnvironment.custom_state(
    credits: int = 20,
    wheat: int = 0,
    flour: int = 0,
    flowers: int = 0,
    labor: int = 0,
    planted: int = 0,
    measured: int = 0,
    entangled_pairs: int = 0,
    icon_activation: Dictionary = {}
) -> GameState

# Save/Load
DebugEnvironment.save_to_slot(state: GameState, slot: int) -> bool
DebugEnvironment.load_from_slot(slot: int) -> GameState

# Inspection
DebugEnvironment.print_state(state: GameState) -> void
DebugEnvironment.export_as_json(state: GameState) -> Dictionary
```

---

## Tips for Your Dev Team

1. **Create a "test utilities" script** that combines common scenarios:
   ```gdscript
   extends Node

   func setup_test_scenario(type: String) -> GameState:
       match type:
           "early_game": return DebugEnvironment.minimal_farm()
           "mid_game": return DebugEnvironment.mid_game_farm()
           "wealthy": return DebugEnvironment.wealthy_farm()
           "quantum_heavy": return DebugEnvironment.mixed_quantum_farm()
   ```

2. **Use slots strategically:**
   - Slot 0: Wealthy test farm
   - Slot 1: Mid-game farm
   - Slot 2: Problem scenario that needs fixing

3. **Combine with existing tests:**
   - Use `DebugEnvironment` with your existing test scripts
   - Create deterministic test scenarios that don't depend on random generation

4. **Profile with reproducible states:**
   - Use `DebugEnvironment.wealthy_farm()` for performance testing
   - Same state every time = same profiling results
