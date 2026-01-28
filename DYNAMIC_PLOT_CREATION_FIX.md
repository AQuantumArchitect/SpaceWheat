# Dynamic Plot Creation Fix

## Problem

When the biome exploration system was implemented, the game threw errors for all locked biomes:

```
ERROR: Cannot assign to unregistered biome: BioticFlux
ERROR: Cannot assign to unregistered biome: StellarForges
ERROR: Cannot assign to unregistered biome: FungalNetworks
ERROR: Cannot assign to unregistered biome: VolcanicWorlds
```

## Root Cause

The `_create_grid_config()` function was creating plot configurations for **all 6 biomes**, but only **unlocked biomes** (StarterForest and Village) were registered with the grid during `Farm._ready()`.

This created a mismatch:
- GridConfig had plot assignments for all 6 biomes
- FarmGrid only had 2 biomes registered
- Plots tried to reference unregistered biomes → error

## Solution

### 1. Modified `_create_grid_config()` to Only Create Plots for Unlocked Biomes

**File:** `Core/Farm.gd` (lines 823-881)

**Changes:**
- Query `ObservationFrame.get_unlocked_biomes()` to get current unlocked list
- Only create `PlotConfig` entries for unlocked biomes
- Only add `biome_assignments` for unlocked biomes

**Code:**
```gdscript
func _create_grid_config() -> GridConfig:
    # Get unlocked biomes from ObservationFrame
    var observation_frame = get_node_or_null("/root/ObservationFrame")
    var unlocked_biomes = ["StarterForest", "Village"]  # Default
    if observation_frame:
        unlocked_biomes = observation_frame.get_unlocked_biomes()

    # ... config setup ...

    # Only create plots for UNLOCKED biomes
    for biome_name in unlocked_biomes:
        if not BIOME_ROW_MAP.has(biome_name):
            push_warning("Unknown biome in unlocked list: %s" % biome_name)
            continue

        var biome_row = BIOME_ROW_MAP[biome_name]
        for i in range(4):
            var plot = PlotConfig.new()
            plot.position = Vector2i(i, biome_row)
            plot.biome_name = biome_name
            config.plots.append(plot)
            config.biome_assignments[Vector2i(i, biome_row)] = biome_name
```

### 2. Added `_add_plots_for_biome()` for Dynamic Plot Creation

**File:** `Core/Farm.gd` (lines 1081-1106)

**Purpose:** When a biome is unlocked via exploration, dynamically create plots for it.

**Code:**
```gdscript
func _add_plots_for_biome(biome_name: String, grid_ref) -> void:
    """Add plots for a newly unlocked biome.

    Called when a biome is discovered via exploration.
    Creates 4 plots for the biome and assigns them.
    """
    if not BIOME_ROW_MAP.has(biome_name):
        push_warning("Cannot add plots for unknown biome: %s" % biome_name)
        return

    var biome_row = BIOME_ROW_MAP[biome_name]
    print("🗺️ Adding plots for %s on row %d" % [biome_name, biome_row])

    for i in range(4):
        var pos = Vector2i(i, biome_row)

        # get_plot() auto-creates the plot if it doesn't exist
        var plot = grid_ref.get_plot(pos)
        if plot:
            # Assign plot to biome
            grid_ref.assign_plot_to_biome(pos, biome_name)
            print("  ✅ Added plot %s for %s" % [pos, biome_name])
        else:
            push_warning("  ❌ Failed to create plot at %s" % pos)
```

### 3. Updated `_load_biome_dynamically()` to Add Plots

**File:** `Core/Farm.gd` (lines 1061-1076)

**Changes:** After registering a newly loaded biome, call `_add_plots_for_biome()` to create its plots.

**Code:**
```gdscript
# If newly loaded, register with grid, add plots, and rebuild operators
if not already_loaded:
    _register_biome_if_loaded(biome_name, biome, grid)

    # Add plots for this biome dynamically
    _add_plots_for_biome(biome_name, grid)

    # Add metadata for UI systems
    set_meta(biome_name.to_lower() + "_biome", biome)

    # Rebuild quantum operators
    var icon_registry = get_node_or_null("/root/IconRegistry")
    if icon_registry and biome.has_method("rebuild_quantum_operators"):
        biome.rebuild_quantum_operators()
```

## How It Works Now

### Initial Boot Sequence
```
1. ObservationFrame initializes with unlocked_biomes = ["StarterForest", "Village"]
2. Farm._create_grid_config() queries unlocked_biomes
3. GridConfig created with ONLY 8 plots (2 biomes × 4 plots)
4. Farm._ready() loads StarterForest and Village biomes
5. Biomes registered with grid
6. Plots assigned to biomes
✅ No errors - only unlocked biomes have plots
```

### Exploration Sequence (Press 4E)
```
1. User presses 4E
2. BiomeHandler.explore_biome() → Farm.explore_biome()
3. Farm.explore_biome():
   a. Picks random unexplored biome (e.g., "BioticFlux")
   b. Calls ObservationFrame.unlock_biome("BioticFlux")
   c. Calls _load_biome_dynamically("BioticFlux")
4. _load_biome_dynamically():
   a. Loads BioticFluxBiome.gd script
   b. Registers biome with grid (_register_biome_if_loaded)
   c. Creates 4 plots for biome (_add_plots_for_biome)
   d. Assigns plots to biome
   e. Rebuilds quantum operators
5. View switches to BioticFlux with slide animation
✅ No errors - biome registered before plots assigned
```

## Key API Used

### FarmGrid API
- `grid.register_biome(biome_name, biome_instance)` - Registers biome with BiomeRoutingManager
- `grid.get_plot(position)` - Auto-creates plot if doesn't exist (from GridPlotManager)
- `grid.assign_plot_to_biome(position, biome_name)` - Assigns plot to biome

### ObservationFrame API
- `get_unlocked_biomes()` - Returns array of currently unlocked biome names
- `unlock_biome(biome_name)` - Adds biome to unlocked list and persists to GameState

## Files Modified

| File | Changes | Lines |
|------|---------|-------|
| `Core/Farm.gd` | Modified `_create_grid_config()` to only create plots for unlocked biomes | 823-881 |
| `Core/Farm.gd` | Added `_add_plots_for_biome()` for dynamic plot creation | 1081-1106 |
| `Core/Farm.gd` | Updated `_load_biome_dynamically()` to call `_add_plots_for_biome()` | 1061-1076 |

## Testing

### Verify Fix
1. Start new game
2. Check console: "GridConfig created with 8 plots for 2 unlocked biomes"
3. No errors about unregistered biomes
4. Press 4E to explore
5. Console shows: "🗺️ Adding plots for BioticFlux on row 0"
6. Console shows: "✅ Added plot Vector2i(0, 0) for BioticFlux" (× 4)
7. View slides to BioticFlux
8. No errors

### Expected Console Output (Initial Boot)
```
GridConfig created with 8 plots for 2 unlocked biomes
Farm: Loaded biome 'StarterForest'
Farm: Loaded biome 'Village'
```

### Expected Console Output (After 4E Press)
```
🗺️ explore_biome() called!
🗺️ Unexplored biomes: ["BioticFlux", "StellarForges", "FungalNetworks", "VolcanicWorlds"]
🗺️ Selected random biome: BioticFlux
🗺️ Unlocking biome: BioticFlux
🗺️ Loading biome dynamically: BioticFlux
Farm: Loaded biome 'BioticFlux'
🗺️ Adding plots for BioticFlux on row 0
  ✅ Added plot Vector2i(0, 0) for BioticFlux
  ✅ Added plot Vector2i(1, 0) for BioticFlux
  ✅ Added plot Vector2i(2, 0) for BioticFlux
  ✅ Added plot Vector2i(3, 0) for BioticFlux
🗺️ Dynamically loaded and registered biome: BioticFlux
```

## Benefits

1. **No errors** - Plots only created for registered biomes
2. **Performance** - Only creates plots as needed (8 at boot, 4 per exploration)
3. **Clean architecture** - Separation between initial config and dynamic expansion
4. **Debuggable** - Clear logging shows when plots are added
5. **Persistent** - Works with save/load (unlocked biomes tracked in GameState)

## Related Documentation

- **BIOME_EXPLORATION_SYSTEM.md** - Full biome exploration architecture
- **BIOME_EXPLORATION_SUMMARY.md** - Quick reference for exploration system
- **BIOME_INITIALIZATION_FIX.md** - Related fix for biome background race condition
