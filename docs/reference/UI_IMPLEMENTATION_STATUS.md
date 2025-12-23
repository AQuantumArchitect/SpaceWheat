# UI Implementation Status

## Current State

The UI system is **partially working** but has architectural issues preventing clean integration with save/load.

---

## What Works ✅

### Escape Menu System
- ESC toggle
- Q quit
- R restart
- S save menu (re-enabled)
- L load menu (re-enabled)
- D reload last save
- K keyboard help
- V/C/N overlays

**Status:** All signals wired, tested at compile-time ✅

### SaveLoadMenu UI
- 3 save slot display
- Save info (timestamp, credits, goals)
- Debug scenario selection
- Signal emissions for slot selection

**Status:** Ready to connect ✅

### Visualization Systems
- QuantumForceGraph initializes with grid + biome
- PlotGridDisplay shows plot layout
- EntanglementLines visualization

**Status:** Can display if biome/grid provided ✅

---

## What's Broken ❌

### Live Farm Integration
**Problem:** When no Farm is provided, many systems fail:
- BioticFluxBiome.gd missing → FarmGrid can't compile
- Farm._ready() line 106 error (FarmGrid.new() fails)
- UI initialization hangs on some code paths

**Status:** Games boots but Farm initialization has errors ❌

### Architecture Issues
1. **UI assumes Farm exists** - Too many hardcoded dependencies
2. **No clear data contract** - UI code scattered across multiple files
3. **Backward compatibility hacks** - Multiple code paths for different scenarios
4. **File duplication** - Export folders had conflicting copies (now fixed)

**Status:** Fragile, hard to maintain ❌

### Missing Adaptors
- No clean way to provide Biome without Farm
- No standardized "UI data packet" structure
- No isolation layer between game logic and UI

**Status:** UI tightly coupled to Farm ❌

---

## Path Forward - Hook to Saves

### Option A: Minimal Integration (Quick)

**What to do:**
1. When SaveLoadMenu slot is selected:
   - Load GameState from file
   - Reconstruct Biome from biome_state
   - Reconstruct Grid from plots
   - Pass to visualizer

**Effort:** Low (2-4 hours)
**Risk:** Medium (untested Biome reconstruction)

**Pseudocode:**
```gdscript
func _on_save_load_slot_selected(slot: int, mode: String) -> void:
  if mode == "load":
    var game_state = GameStateManager.load_game_state(slot)
    if game_state:
      # Reconstruct display data
      var biome = Biome.new()
      biome.load_from_state(game_state.biome_state)

      var grid = FarmGrid.new()
      grid.load_from_state(game_state.plots, ...)

      # Show visualizer with loaded data
      visualizer.initialize(grid, center, radius)
      visualizer.set_biome(biome)
      show_display_panel(game_state)
```

**Issues:**
- Biome.load_from_state() might not exist
- Grid.load_from_state() might not exist
- Reconstruction might fail silently

---

### Option B: Proper Adaptor (Better)

**What to do:**
1. Create `BiomeSnapshot` class - lightweight Biome representation
2. Create `SaveDataAdapter` - converts GameState → UI-compatible format
3. Use adaptor in SaveLoadMenu slot selection

**Effort:** Medium (6-8 hours)
**Risk:** Low (clean interface)

**Files to create:**
- `UI/BiomeSnapshot.gd` - Minimal biome for display
- `UI/SaveDataAdapter.gd` - GameState → display data converter
- Update SaveLoadMenu to use adapter

**Advantage:**
- UI doesn't need to know about GameState internals
- Can test with mock data
- Clear contract between save system and UI

**Example:**
```gdscript
class SaveDataAdapter:
  static func convert(game_state: GameState) -> DisplayData:
    return DisplayData.new(
      grid_data: game_state.plots,
      biome_data: game_state.biome_state,
      economy: game_state.credits,
      goals: game_state.current_goal_index
    )
```

---

### Option C: Full Cleanup (Right Way)

**What to do:**
1. Clean up UI system first
2. Remove Farm dependencies from UI
3. Create clean injection interfaces
4. Add adapter layer
5. Hook to saves

**Effort:** High (2-3 days)
**Risk:** Very low (systematic)

**Steps:**
1. Remove BioticFluxBiome dependency (fix FarmGrid)
2. Fix Farm._ready() errors
3. Create UI data contracts
4. Refactor UI to use contracts, not implementations
5. Create save-to-UI pipeline

**Benefit:**
- UI is portable and testable
- Can swap data sources (Farm, SaveFile, Test)
- Easier to debug and maintain

---

## Current Blockers

### 1. BioticFluxBiome.gd Missing
**File:** `res://Core/Environment/BioticFluxBiome.gd` does not exist

**Referenced in:** FarmGrid.gd:14

**Impact:** Can't create FarmGrid without it

**Solution:**
- Option A: Remove the reference
- Option B: Create a stub implementation
- Option C: Create the full implementation

---

### 2. Farm._ready() Failures
**Line 106:** `grid = FarmGrid.new()` fails

**Reason:** FarmGrid can't compile due to BioticFluxBiome

**Solution:** Fix BioticFluxBiome issue first

---

### 3. No Biome Reconstruction Method
**Problem:** GameState has `biome_state` but Biome has no `load_from_state()` method

**Solution:** Add to Biome class:
```gdscript
func load_from_state(state_dict: Dictionary) -> void:
  # Restore quantum state from saved dictionary
  time_elapsed = state_dict.get("time_elapsed", 0.0)
  # ... restore all quantum parameters
```

---

### 4. No Grid Reconstruction Method
**Problem:** GameState has plot array but Grid has no `load_from_state()` method

**Solution:** Add to FarmGrid class:
```gdscript
func load_from_state(plots_array: Array, width: int, height: int) -> void:
  # Restore grid layout and plot states
  grid_width = width
  grid_height = height
  # ... restore all plots
```

---

## Recommended Approach

### Phase 1: Stabilize (1 day)
- [ ] Fix BioticFluxBiome dependency issue
- [ ] Fix Farm initialization errors
- [ ] Get clean boot without errors

### Phase 2: Add Reconstruction (1 day)
- [ ] Add `Biome.load_from_state()`
- [ ] Add `FarmGrid.load_from_state()`
- [ ] Test with sample data

### Phase 3: Hook SaveLoadMenu (1 day)
- [ ] Create SaveDataAdapter
- [ ] Wire SaveLoadMenu slots to adapter
- [ ] Display loaded biome in visualizer

### Phase 4: Polish (as needed)
- [ ] Add error handling
- [ ] Test all edge cases
- [ ] Optimize performance

---

## Testing Plan

Once hooked to saves, test:

1. **Boot game** → No errors ✓
2. **Open save menu** → Shows slots and timestamps ✓
3. **Click slot with save** → Visualizer displays biome ✓
4. **Click empty slot** → Proper error/disabled state ✓
5. **Switch between saves** → Visualizer updates ✓
6. **Reload current scene** → Saved state persists ✓

---

## Minimal Working Example

```gdscript
# In SaveLoadMenu._on_save_load_slot_selected()

if mode == "load":
  var game_state = GameStateManager.load_game_state(slot)
  if not game_state:
    print("ERROR: Could not load save slot %d" % slot)
    return

  # Reconstruct visualization data
  var biome = Biome.new()
  if biome.has_method("load_from_state"):
    biome.load_from_state(game_state.biome_state)
  else:
    # Fallback: create fresh biome
    biome._ready()

  var grid = FarmGrid.new()
  if grid.has_method("load_from_state"):
    grid.load_from_state(game_state.plots, game_state.grid_width, game_state.grid_height)
  else:
    # Fallback: create fresh grid
    grid.grid_width = game_state.grid_width
    grid.grid_height = game_state.grid_height
    grid.biome = biome

  # Display in visualizer
  if layout_manager and layout_manager.quantum_graph:
    var center = Vector2(400, 300)  # Center of screen
    var radius = 150.0
    layout_manager.quantum_graph.initialize(grid, center, radius)
    layout_manager.quantum_graph.set_biome(biome)
    layout_manager.quantum_graph.create_sun_qubit_node()
```

---

## Decision Point

**Question for user:**
Do you want to:
1. **Quick Path (Option A)** - Just hook SaveLoadMenu to visualizer, accept some fragility
2. **Middle Path (Option B)** - Add adaptor layer, cleaner but some work
3. **Right Path (Option C)** - Full cleanup first, then hook saves

**My recommendation:** **Option B**
- Gets saves working quickly
- Creates cleaner interface for future work
- Reduces accumulated technical debt
