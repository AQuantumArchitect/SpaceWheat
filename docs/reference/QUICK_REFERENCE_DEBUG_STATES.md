# Quick Reference: Debug States

## One-Line Recipes

Copy & paste these into your scripts to instantly set up test scenarios.

### Basic Scenarios
```gdscript
GameStateManager.apply_state_to_game(DebugEnvironment.minimal_farm())           # Start fresh
GameStateManager.apply_state_to_game(DebugEnvironment.wealthy_farm())           # No resource limits
GameStateManager.apply_state_to_game(DebugEnvironment.mid_game_farm())          # Mid-game state
```

### Quantum Testing
```gdscript
GameStateManager.apply_state_to_game(DebugEnvironment.fully_planted_farm())     # All plots planted
GameStateManager.apply_state_to_game(DebugEnvironment.fully_measured_farm())    # All plots measured
GameStateManager.apply_state_to_game(DebugEnvironment.fully_entangled_farm())   # Chain entanglement
GameStateManager.apply_state_to_game(DebugEnvironment.mixed_quantum_farm())     # Mixed quantum states
```

### Visual Testing
```gdscript
GameStateManager.apply_state_to_game(DebugEnvironment.icons_active_farm())      # Icon effects visible
```

### Custom Scenarios
```gdscript
# Just change the numbers
var env = DebugEnvironment.custom_state(
    1000,  # credits
    500,   # wheat
    200,   # flour
    0,     # flowers
    0,     # labor
    15,    # planted plots
    8,     # measured plots
    3,     # entangled pairs
    {}     # icon activation (optional)
)
GameStateManager.apply_state_to_game(env)
```

## Full Preset Reference

| Preset | Credits | Wheat | Flour | Setup | Use For |
|--------|---------|-------|-------|-------|---------|
| `minimal_farm()` | 20 | 0 | 0 | Empty | Early game, basics |
| `wealthy_farm()` | 5000 | 500 | 200 | Empty | No limits, fast testing |
| `fully_planted_farm()` | 5000 | 500 | 200 | 25 planted | Harvest, visuals |
| `fully_measured_farm()` | 5000 | 500 | 200 | 25 measured | Quantum collapse |
| `fully_entangled_farm()` | 5000 | 500 | 200 | Entangled | Entanglement chains |
| `mixed_quantum_farm()` | 5000 | 500 | 200 | Variety | Realistic mix |
| `icons_active_farm()` | 5000 | 500 | 200 | Icons at 75/50/25% | Icon visuals |
| `mid_game_farm()` | 200 | 75 | 30 | 12 planted, some progress | Mid progression |

## Save & Reload

```gdscript
# Save your current state
var state = DebugEnvironment.wealthy_farm()
DebugEnvironment.save_to_slot(state, 0)  # Slot 0, 1, or 2

# Reload it later (even after restart)
GameStateManager.load_and_apply(0)
```

## Inspection

```gdscript
# Print a summary
var state = DebugEnvironment.wealthy_farm()
DebugEnvironment.print_state(state)

# Output:
# 📊 DEBUG STATE: debug_wealthy
# ============================================================
# Credits: 5000
# Wheat: 500 | Flour: 200 | Flowers: 150
# ...
```

## Testing Patterns

### Test Progression
```gdscript
# Jump through game stages
GameStateManager.apply_state_to_game(DebugEnvironment.minimal_farm())      # Test early game
# ... test mechanics ...
GameStateManager.apply_state_to_game(DebugEnvironment.mid_game_farm())     # Jump to mid-game
# ... test mechanics ...
GameStateManager.apply_state_to_game(DebugEnvironment.wealthy_farm())      # Jump to late-game
```

### Test Feature
```gdscript
# Test entanglement without resource constraints
GameStateManager.apply_state_to_game(DebugEnvironment.fully_entangled_farm())
# ... interact with entangled plots ...
```

### Profile Performance
```gdscript
# Deterministic state for consistent profiling
GameStateManager.apply_state_to_game(DebugEnvironment.wealthy_farm())
# ... run profiler, same state every time ...
```

## Custom State Builder

All parameters are optional (shown with defaults):

```gdscript
DebugEnvironment.custom_state(
    20,        # credits (default)
    0,         # wheat inventory
    0,         # flour inventory
    0,         # flower inventory
    0,         # labor inventory
    0,         # planted plots count
    0,         # measured plots count
    0,         # entangled pairs
    {}         # icon_activation dictionary
)
```

Example with icon activation:
```gdscript
var env = DebugEnvironment.custom_state(
    credits=1000,
    wheat=300,
    planted=12,
    measured=6,
    entangled_pairs=2,
    icon_activation={"biotic": 0.5, "chaos": 0.75, "imperium": 0.25}
)
```

## Debugging Tips

1. **State not applying?**
   - Verify FarmView is instantiated
   - Check that `GameStateManager.active_farm_view` is set

2. **Need reproducible issue?**
   - Create specific state with `custom_state()`
   - Save to slot: `DebugEnvironment.save_to_slot(env, 0)`
   - Share slot file with team

3. **Want to inspect state?**
   - Use `DebugEnvironment.print_state(state)`
   - Or `DebugEnvironment.export_as_json(state)`

4. **Reset to clean state?**
   - `GameStateManager.apply_state_to_game(DebugEnvironment.minimal_farm())`
   - No disk I/O, instant reset

---

**More details:** See `SAVE_LOAD_DEBUG_GUIDE.md`

**Run tests:** `godot --headless --exit-on-finish -s res://test_save_load_diagnostic.gd`
