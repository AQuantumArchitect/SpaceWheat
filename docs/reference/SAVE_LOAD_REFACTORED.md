# Save/Load System - Refactored for Farm/Biome/Qubit Architecture

## Overview

The save/load system has been refactored to align with the new game architecture where:
- **Farm** = Pure simulation manager (all gameplay logic)
- **Biome** = Environmental physics (sun/moon, temperature, decoherence)
- **Qubit** (DualEmojiQubit) = Quantum state representation (Bloch sphere coordinates)

## Architecture

```
FarmView (UI Layer)
    ↓
Farm (Pure Simulation)
    ├── economy: FarmEconomy
    ├── grid: FarmGrid
    ├── goals: GoalsSystem
    └── biome: Biome
        └── quantum_states: Dict[Vector2i → DualEmojiQubit]

GameState (Serialized)
    ├── Economy (all inventories)
    ├── Plot Configuration (not Bloch coordinates!)
    ├── Goals Progress
    ├── Icon Activation
    └── Sun/Moon Phase
```

## What Gets Saved

### ✅ PERSISTED (Intentional)

**Economy** - All resource inventories
- `credits` - Game currency
- `wheat_inventory` - Harvested grain
- `labor_inventory` - 👥 resource from measuring
- `flour_inventory` - Mill output
- `flower_inventory` - 🌻 resource
- `mushroom_inventory` - 🍄 lunar harvest
- `detritus_inventory` - 🌱 compost resource
- `imperium_resource` - 🏰 imperial currency
- `tributes_paid` / `tributes_failed` - Tribute tracking

**Plot Configuration** - Infrastructure-level state
- `position` - Grid coordinates (x, y)
- `type` - PlotType (WHEAT, TOMATO, MUSHROOM, MILL, MARKET)
- `is_planted` - Currently has active crop
- `has_been_measured` - Quantum state collapsed to definite value
- `theta_frozen` - Measurement locked the Bloch theta coordinate
- `entangled_with` - Array of entangled plot positions

**Goals** - Quest progress
- `current_goal_index` - Active goal
- `completed_goals` - Array of completed goal IDs (as strings)

**Icons** - Quantum power activation
- `biotic_activation` - 0-1 intensity
- `chaos_activation` - 0-1 intensity
- `imperium_activation` - 0-1 intensity

**Time** - Environmental cycles
- `sun_moon_phase` - 0 to 2π (synced with biome)

**Grid Dimensions** - Farm layout
- `grid_width` - X dimension (e.g., 6)
- `grid_height` - Y dimension (e.g., 1)

### ❌ NOT PERSISTED (Regenerated)

**Quantum State Details** (intentionally NOT saved)
- `theta` - Bloch polar angle
- `phi` - Bloch azimuthal angle
- `radius` - Coherence amplitude
- `energy` - Stored energy
- `berry_phase` - Evolution history

**Reason for Regeneration:**
- Quantum states are **deterministic** given the infrastructure (entanglement gates) and current time (biome phase)
- Serializing Bloch coordinates adds complexity without semantic value
- The "measurement state" is preserved (`has_been_measured`, `theta_frozen`)
- When a plot is planted, its qubit regenerates from the biome environment
- **Result:** Simple, compact save files that remain valid across quantum physics updates

**Vocabulary** (procedurally generated)
- `discovered_words` - Not saved
- Regenerates each session based on seed

**Conspiracy Network** (dynamically created)
- Network topology is regenerated each session
- Only sun/moon phase is persisted

## Save File Format

```gdscript
class GameState extends Resource:
    # Meta
    scenario_id: String            # "default", "debug_wealthy", etc.
    save_timestamp: int            # Unix timestamp
    game_time: float               # Total playtime

    # Grid
    grid_width: int                # 6 (typical farm)
    grid_height: int               # 1 (typical farm)

    # Economy (8 inventories)
    credits: int
    wheat_inventory: int
    labor_inventory: int
    flour_inventory: int
    flower_inventory: int
    mushroom_inventory: int        # NEW
    detritus_inventory: int        # NEW
    imperium_resource: int         # NEW
    tributes_paid: int
    tributes_failed: int

    # Plots (Array of configurations)
    plots: Array[Dictionary]       # [
                                   #   {
                                   #     position: Vector2i(0, 0),
                                   #     type: 0,
                                   #     is_planted: true,
                                   #     has_been_measured: false,
                                   #     theta_frozen: false,
                                   #     entangled_with: [Vector2i(1, 0)]
                                   #   },
                                   #   ...
                                   # ]

    # Goals
    current_goal_index: int
    completed_goals: Array[String] # ["harvest_wheat_1", "measure_01", ...]

    # Icons
    biotic_activation: float       # 0-1
    chaos_activation: float        # 0-1
    imperium_activation: float     # 0-1

    # Time
    sun_moon_phase: float          # 0 to 2π
```

## Save/Load Flow

### Saving (Capture)

```
Game is running
    ↓
User presses ESC → SAVE
    ↓
GameStateManager.save_game(slot)
    ├─ capture_state_from_game()
    │  ├─ Read from Farm.economy (all inventories)
    │  ├─ Read from Farm.grid (plot configuration only)
    │  ├─ Read from Farm.goals (progress)
    │  ├─ Read from Farm.biome (sun_moon_phase)
    │  └─ Read from FarmView (icon activation)
    │
    └─ ResourceSaver.save(state, "user://saves/save_slot_N.tres")
```

### Loading (Apply)

```
Game is loaded, player presses ESC → LOAD
    ↓
GameStateManager.load_and_apply(slot)
    ├─ load_game_state(slot)
    │  └─ ResourceLoader.load("user://saves/save_slot_N.tres")
    │
    └─ apply_state_to_game(state)
       ├─ Restore Farm.economy (all inventories)
       ├─ Restore Farm.grid (plot configuration)
       │  └─ Entanglement gates re-establish
       ├─ Restore Farm.goals (progress)
       ├─ Restore Farm.biome (sun/moon phase)
       ├─ Restore FarmView (icon activation)
       │
       └─ Quantum states regenerate from Biome
          (when plots are planted, qubits re-initialize)
```

## Key Design Decisions

### 1. **Don't Serialize Bloch Coordinates**

❌ OLD approach (what we avoided):
```gdscript
# BAD: Serializing quantum state details
{
    "theta": 1.5707963267948966,  # π/2
    "phi": 0.0,
    "radius": 0.8,
    "energy": 0.5,
    "berry_phase": 2.3
}
```

**Problems:**
- Meaningless without Bloch sphere visualization
- Breaks when physics model changes
- Adds 5 floats per qubit
- Complicates save file format

✅ NEW approach (what we do):
```gdscript
# GOOD: Only save infrastructure
{
    "is_planted": true,
    "has_been_measured": true,
    "theta_frozen": true,
    "entangled_with": [Vector2i(1, 0)]
}
```

**Benefits:**
- Infrastructure persists (entanglement gates remain)
- Quantum states regenerate deterministically
- Compact, semantic save format
- Physics updates don't invalidate saves

### 2. **Infrastructure Model**

Entanglement gates persist at the plot level:
- Qubits regenerate when planted
- Gates maintain structure across reload
- Measurement cascade preserved through entanglement topology

```
Save:     entangled_with = [Vector2i(1, 0)]
Load:     Re-establish entanglement gates
Qubit:    Create fresh quantum state in entangled configuration
```

### 3. **Biome Determinism**

Sun/moon phase is persisted, enabling:
- Deterministic qubit regeneration
- Same temperature, decoherence rates
- Reproducible game state

## Implementation Details

### capture_state_from_game()

Reads directly from Farm object (not FarmView):
```gdscript
var farm = active_farm_view.farm  # Access pure simulation

# All from Farm internals
state.grid_width = farm.grid_width
state.grid_height = farm.grid_height
state.credits = farm.economy.credits
state.plots = ... # from farm.grid
state.goals = ... # from farm.goals
state.sun_moon_phase = farm.biome.sun_moon_phase
```

### apply_state_to_game()

Applies to Farm, UI updates through FarmView:
```gdscript
# Apply to simulation layer
farm.economy.credits = state.credits
farm.grid.plots[...] = state.plots
farm.goals.current_index = state.current_goal_index
farm.biome.sun_moon_phase = state.sun_moon_phase

# Quantum states regenerate automatically when:
# - Plots are planted (grid asks biome for new qubit)
# - Time advances (biome evolves qubits)

# UI layer updates
fv.biotic_icon.set_activation(state.biotic_activation)
fv.refresh_all_plot_tiles()
```

## Debug Environments

The DebugEnvironment utility creates test states:

```gdscript
# These now work with new architecture:
var env = DebugEnvironment.wealthy_farm()
GameStateManager.apply_state_to_game(env)

# All 8 scenarios updated for Farm/Biome/Qubit:
- minimal_farm()
- wealthy_farm()
- fully_planted_farm()
- fully_measured_farm()
- fully_entangled_farm()
- mixed_quantum_farm()
- icons_active_farm()
- mid_game_farm()
```

## Testing Save/Load

Run diagnostic tests:
```bash
# Test core serialization
godot --headless --exit-on-finish -s res://test_save_load_diagnostic.gd

# Expected output:
# ✅ Passed: 5/5 tests
# - GameState creation
# - Property export
# - Save directory setup
# - Resource save/load cycle
# - Complex type integrity
```

## Common Issues & Solutions

### Issue: "Farm not found in FarmView"
**Cause:** FarmView doesn't expose `farm` property
**Fix:** Ensure FarmView has `var farm` accessible to GameStateManager

### Issue: "Qubit state lost after load"
**Expected behavior:** Qubits regenerate from biome
**Not a bug:** This is intentional - quantum states are deterministic

### Issue: "Entanglement not restored"
**Cause:** Entanglement gates stored in `entangled_plots` dict
**Fix:** Ensure `entangled_with` array properly saved/restored

## Migration from Old System

If you had old saves (pre-refactor):

1. Old GameState had different structure
2. Run migration script to update saved files
3. Or manually delete old saves (new game starts fresh)

```gdscript
# Migration NOT needed unless you're updating existing saves
# New saves will always be compatible going forward
```

## Future Enhancements

**Potential improvements:**
1. **Snapshot system** - In-memory snapshots for rapid testing
2. **State diffs** - Show what changed in a save
3. **Compression** - Gzip .tres files for smaller saves
4. **Cloud sync** - Sync saves across devices
5. **Rewind system** - Keep save history for rollback

## Summary

The refactored save/load system:
- ✅ Aligns with Farm/Biome/Qubit architecture
- ✅ Saves only what's necessary (infrastructure, not quantum coordinates)
- ✅ Quantum states regenerate deterministically
- ✅ Compact, semantic save format
- ✅ Compatible with physics updates
- ✅ Ready for scaling to larger farms

The key insight: **Persist the configuration, regenerate the quantum dynamics.**
