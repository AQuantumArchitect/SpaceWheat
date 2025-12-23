# UI System Requirements & Contracts

## Overview

This document defines what the UI system **actually needs** to function. It describes the contracts and dependencies, enabling the UI to be tested independently or hooked to arbitrary data sources.

---

## Core Concept

The UI is a **display and control layer** that needs:
1. **Data** - State information to display
2. **Controls** - Ways for user to interact with the system
3. **Signals** - Async notifications when state changes

---

## 1. Visualization System Requirements

### QuantumForceGraph (Main Visualizer)

**Location:** `Core/Visualization/QuantumForceGraph.gd`

**Required Initialization:**
```gdscript
func initialize(grid: FarmGrid, center_pos: Vector2, radius: float)
func set_biome(biome_ref)
func create_sun_qubit_node()
```

**Needs from FarmGrid:**
- Grid width and height
- Access to plot positions
- Plot quantum state (theta, phi, radius)
- Entanglement relationships between plots

**Needs from Biome:**
- Sun/moon qubit state (theta, phi for celestial position)
- Environmental parameters (temperature, entropy)
- Quantum evolution state

**Data Source:** Can be pulled from:
- Live Farm instance (real-time updates)
- GameState (loaded from save file)
- Biome snapshot (isolated test data)

---

## 2. Save/Load System Requirements

### GameStateManager (Autoload Singleton)

**Location:** `Core/GameState/GameStateManager.gd`

**Contract - What SaveLoadMenu needs:**

```gdscript
# Check if save exists
func save_exists(slot: int) -> bool

# Get save info for display
func get_save_info(slot: int) -> Dictionary
# Returns: {
#   exists: bool,
#   display_name: String,
#   scenario: String,
#   credits: int,
#   goal_index: int,
#   playtime: float
# }

# Load game state
func load_game_state(slot: int) -> GameState
func load_and_apply(slot: int) -> bool

# Save game state
func save_game(slot: int) -> bool

# Track most recent save
var last_saved_slot: int
```

### GameState (Saveable Data)

**Location:** `Core/GameState/GameState.gd`

**Persisted Data:**
```
Meta:
  - scenario_id: String
  - save_timestamp: int (Unix time)
  - game_time: float (playtime)
  - grid_width, grid_height: int

Economy:
  - credits: int
  - wheat_inventory, labor_inventory, flour_inventory, flower_inventory
  - mushroom_inventory, detritus_inventory, imperium_resource
  - tributes_paid, tributes_failed

Plots:
  - plots: Array[Dictionary]
    Each plot has: position, type, is_planted, has_been_measured,
                   theta_frozen, entangled_with

Goals:
  - current_goal_index: int
  - completed_goals: Array[String]

Icons:
  - biotic_activation, chaos_activation, imperium_activation: float

Quantum State:
  - time_elapsed: float
  - sun_theta, sun_phi: float
  - wheat_icon_theta, mushroom_icon_theta: float
  - biome_state: Dictionary (complete quantum tree)
```

---

## 3. UI Display Panels Requirements

### ResourcePanel

**Needs:** Economy data from GameState
- credits
- wheat_inventory
- flour_inventory
- flower_inventory
- mushroom_inventory

**Source:** GameState → FarmUIController → ResourcePanel

---

### GoalPanel

**Needs:** Goal data from GameState
- current_goal_index
- completed_goals

**Source:** GameState → FarmUIController → GoalPanel

---

### BiomeInfoDisplay

**Needs:** Environment data from Biome
- Base temperature
- Entropy coupling
- Evolution state
- Quantum parameters

**Source:** Biome instance → FarmUIController → BiomeInfoDisplay

---

### PlotGridDisplay

**Needs:** Plot data to visualize
- Grid layout (width, height)
- Plot positions and types
- Plant state (planted/empty)
- Quantum state (theta, phi for visualization)
- Entanglement relationships

**Source:** FarmGrid + Biome → PlotGridDisplay

---

## 4. Control Input Requirements

### InputController

**Needs:** Nothing from game state
- Just maps keyboard input to signals

**Provides:**
- menu_toggled
- quit_requested
- restart_requested
- keyboard_help_requested
- escape_menu (visibility state)

---

### FarmInputHandler

**Needs:** Farm reference to execute commands
- Plant action → farm.plant(position)
- Economy action → farm.process_economy()
- Quantum ops → farm measurement commands

**Source:** User input → Farm simulation

---

## 5. System Architecture - Data Flow

```
┌─────────────────┐
│  GameStateManager  │  (Autoload - always available)
│  + GameState      │
└────────┬──────────┘
         │ Saves/Loads
         │
    ┌────▼────────────┐
    │  SaveLoadMenu    │  (Reads save info for display)
    └─────────────────┘

    ┌────────────────────┐
    │  Visualization     │  (Needs: Grid, Biome data)
    │  - QuantumForceGraph│
    │  - PlotGridDisplay │
    └────┬───────────────┘
         │ Reads from
         │
    ┌────▼──────────────┐
    │  FarmUIController │  (Central orchestrator)
    │  + FarmUILayout   │
    │  + FarmUIControls │
    └────┬──────────────┘
         │ Injected with
         │
    ┌────▼──────────────┐
    │  Game System      │  (Optional - for live play)
    │  - Farm           │
    │  - Grid           │
    │  - Biome          │
    └───────────────────┘
```

---

## 6. Injection Points - How to Wire Data

### For Live Play (Farm Present)

```gdscript
# FarmView._ready()
var farm = Farm.new()
add_child(farm)
ui_controller.inject_farm(farm, faction_mgr, vocab_sys, conspiracy_net)
```

**Result:** UI reads live state from Farm

---

### For Save/Load Play (Biome Snapshot)

```gdscript
# After loading game state
var game_state = GameStateManager.load_game_state(slot)

# Reconstruct biome from saved state
var biome = Biome.new()
biome.load_from_state(game_state.biome_state)

# Reconstruct grid from saved state
var grid = FarmGrid.new()
grid.load_from_state(game_state.plots, game_state.grid_width, game_state.grid_height)

# Create minimal farm-like object for UI
var farm_snapshot = {
  "grid": grid,
  "biome": biome,
  "ui_state": game_state  # Use GameState as UI state
}

ui_controller.inject_farm(farm_snapshot)
```

**Result:** UI displays loaded game state

---

### For Isolated Testing (Biome Only)

```gdscript
# No save/load, just test the visualizer
var biome = Biome.new()
biome.is_static = true
biome._ready()

var grid = FarmGrid.new()
grid.grid_width = 6
grid.grid_height = 1
grid.biome = biome

ui_controller.inject_farm({"grid": grid, "biome": biome})
```

**Result:** UI displays test biome

---

## 7. Critical Contracts

### What SaveLoadMenu REQUIRES

✅ **GameStateManager autoload** (exists)
- Must have: `get_save_info()`, `save_exists()`, `save_game()`, `load_and_apply()`

### What QuantumForceGraph REQUIRES

✅ **FarmGrid with:**
- `grid_width`, `grid_height` properties
- Access to quantum state per plot

✅ **Biome with:**
- `sun_theta`, `sun_phi` (celestial position)
- Quantum state for all emoji qubits

### What FarmUIController REQUIRES

✅ **For backward compatibility:** Farm object with:
- `ui_state` property (FarmUIState)
- Signals: `economy_updated`, `credits_changed`, `flour_changed`

⚠️ **OR:** A dictionary/object with:
- `grid` reference (FarmGrid)
- `biome` reference (Biome)
- `ui_state` reference (GameState or FarmUIState)

---

## 8. Minimal Viable Setup

To run the UI standalone (no Farm):

```gdscript
# Step 1: Create biome
var biome = Biome.new()
biome._ready()

# Step 2: Create grid
var grid = FarmGrid.new()
grid.grid_width = 6
grid.grid_height = 1
grid.biome = biome

# Step 3: Inject into UI
ui_controller.inject_farm({
  "grid": grid,
  "biome": biome
})

# Step 4: UI displays, no game running
```

**No** Farm, **No** simulation, **No** input processing needed.

---

## 9. What the UI Does NOT Need

❌ Farm simulation running
❌ Active gameplay mechanics
❌ Input processing (can be disabled)
❌ Network/conspiracy/faction systems (optional overlays)
❌ Full save/load cycle (can display without loading)

---

## 10. Next Steps for Cleanup

1. **Document injection points** - Make it clear what can be injected
2. **Create BiomeSnapshot class** - Simplified Biome for testing
3. **Create minimal Farm adapter** - Dictionary that satisfies UI's expectations
4. **Remove hardcoded assumptions** - UI should not assume Farm exists
5. **Test with SaveLoadMenu** - Hook visualizer to loaded GameState directly

---

## Summary

**The UI needs:**
- GridData (positions, types, quantum state)
- BiomeData (environment, quantum state)
- StateData (resources, goals, icons)
- SaveData (GameStateManager for save/load)

**The UI does NOT need:**
- Active Farm simulation
- Real-time gameplay
- Complex system coordination

**Design principle:** UI is a **read/display layer** + **input control layer**, not a **system coordinator**.
