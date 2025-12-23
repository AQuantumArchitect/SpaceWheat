# Save/Load System - Refactoring Summary

## What Changed

The save/load system has been **refactored to match the new Farm/Biome/Qubit architecture**. The key architectural shift is:

- **OLD**: Monolithic game state with direct FarmView access
- **NEW**: Layered architecture where Farm is the pure simulation, Biome handles physics, Qubits represent quantum states

## Files Modified

### 1. **Core/GameState/GameState.gd**
**Changes:**
- Added `grid_width` and `grid_height` for variable farm sizes
- Added missing inventories: `mushroom_inventory`, `detritus_inventory`, `imperium_resource`
- **Removed:** `discovered_words`, `vocabulary_energy` (procedurally generated, not persisted)
- Updated documentation to clarify what is/isn't saved
- Added `create_for_grid()` static method for easy test state creation
- Updated plot dictionary comments to explain Bloch coordinates are NOT saved

**Key Design Decision:**
> ✅ **Don't persist quantum state details (theta, phi, radius, energy, berry_phase)**
>
> These regenerate from the Biome environment when plots are planted.
> Saves only the infrastructure: plot type, planting state, measurement state, and entanglement topology.

### 2. **Core/GameState/GameStateManager.gd**

**capture_state_from_game()** - Now reads from Farm object:
```gdscript
var farm = active_farm_view.farm  # Access pure simulation

# Captures from Farm internals:
- farm.grid_width/grid_height
- farm.economy (all inventories)
- farm.grid (plot configuration only, not Bloch coordinates)
- farm.goals (progress)
- farm.biome.sun_moon_phase
- FarmView UI layer (icons)
```

**apply_state_to_game()** - Now applies to Farm object:
```gdscript
var farm = active_farm_view.farm

# Applies to simulation layer:
- farm.economy (all inventories)
- farm.grid (plot configuration, entanglement gates)
- farm.goals (progress)
- farm.biome (sun/moon phase)
- FarmView (icon activation, UI updates)

# Quantum states auto-regenerate when:
# - Plots are planted (grid requests fresh qubits from biome)
# - Time advances (biome evolves all qubits)
```

**Key improvement:**
- Cleaner separation: apply to Farm, not FarmView directly
- Supports variable-sized grids
- Adds support for all 8 resource types
- Qubits regenerate deterministically from persisted state

## What This Means

### For Developers

**Save files now contain:**
✅ Economy state (all 8 inventories)
✅ Plot configuration (position, type, planted, measured, entangled_with)
✅ Goals progress
✅ Icon activation levels
✅ Sun/moon phase

**Save files do NOT contain:**
❌ Quantum state details (theta, phi, radius, energy)
❌ Vocabulary (regenerated)
❌ Conspiracy network (regenerated)
❌ Visual/UI state

**Why?**
- Quantum states are **deterministic** from infrastructure + time
- Serializing Bloch coordinates adds complexity with no benefit
- Keeps save format simple and compatible with future physics updates
- The "measurement infrastructure" is preserved (has_been_measured, theta_frozen, entanglement gates)

### For Testing

The debug environment system works exactly as before:
```gdscript
# Load a test scenario in the LOAD menu
GameStateManager.apply_state_to_game(DebugEnvironment.wealthy_farm())

# All 8 scenarios now use the new architecture:
- minimal_farm()
- wealthy_farm()
- fully_planted_farm()
- fully_measured_farm()
- fully_entangled_farm()
- mixed_quantum_farm()
- icons_active_farm()
- mid_game_farm()
```

## Design Philosophy

**Core Principle: Persist the Configuration, Regenerate the Dynamics**

```
SAVE CONTAINS:          REGENERATES ON LOAD:
├─ Plot positions       ├─ Quantum Bloch coordinates
├─ Plant/measure state  ├─ Coherence/energy values
├─ Entanglement gates   ├─ Berry phase
├─ Economy              ├─ Vocabulary
├─ Goals               ├─ Conspiracy network
├─ Icon levels         └─ Quantum evolution history
└─ Sun/moon phase
```

This approach:
1. **Simplifies save format** - No arbitrary Bloch angles to serialize
2. **Ensures determinism** - Same infrastructure + phase = same quantum states
3. **Enables physics updates** - Can change quantum model without invalidating saves
4. **Maintains semantic meaning** - Saves what matters: the farm configuration

## Backward Compatibility

**Old saves (before refactor):**
- Should be deleted or migrated
- Format changed due to new architecture
- No migration utility provided (game is still in development)

**New saves (from now on):**
- Compatible across quantum physics updates
- Flexible to farm size changes
- Self-documenting format

## Testing

Run the diagnostic test to verify:
```bash
godot --headless --exit-on-finish -s res://test_save_load_diagnostic.gd
```

Expected: ✅ 5/5 tests passing

The tests verify:
- GameState creation with correct defaults
- Property export and serialization
- Save directory setup
- Resource save/load cycle integrity
- Complex type preservation (arrays, Vector2i, dictionaries)

## What's Next

**If you modify the Farm architecture:**

1. Check if new state needs persisting (add to GameState)
2. Update `capture_state_from_game()` to read it
3. Update `apply_state_to_game()` to write it
4. Update DebugEnvironment.gd scenarios if needed
5. Run diagnostic test to verify

**Example: Adding a new economy resource**
```gdscript
// 1. Add to GameState
@export var crystal_inventory: int = 0

// 2. Update capture_state_from_game()
state.crystal_inventory = farm.economy.crystal_inventory

// 3. Update apply_state_to_game()
economy.crystal_inventory = state.crystal_inventory

// 4. Update DebugEnvironment scenarios
state.crystal_inventory = 100  // For wealthy_farm()

// 5. Test
godot --headless --exit-on-finish -s res://test_save_load_diagnostic.gd
```

## Files to Read for Context

- `SAVE_LOAD_REFACTORED.md` - Detailed architectural documentation
- `Core/Farm.gd` - The pure simulation manager
- `Core/Environment/Biome.gd` - Environmental physics
- `Core/GameMechanics/FarmEconomy.gd` - Resource management
- `Core/QuantumSubstrate/DualEmojiQubit.gd` - Quantum state representation
