# Architecture Refactoring Assessment

## Current State: Tight Coupling

```
FarmView.gd (2483 lines)
├── SIMULATION LOGIC (should be extracted)
│   ├── Creates: FarmGrid, FarmEconomy, GoalsSystem
│   ├── Creates: GameController, FactionManager
│   ├── Creates: VocabularyEvolution, TomatoConspiracyNetwork
│   ├── Manages: Biome (via FarmGrid.biome)
│   ├── Scenario loading: _load_debug_scenario()
│   └── Connects all inter-system signals
│
└── VIEW/UI LOGIC (should stay)
    ├── UI creation: _create_ui(), _create_plots_row(), etc.
    ├── Input handling: _input(), _on_tile_clicked(), etc.
    ├── Visual updates: _update_ui(), _draw(), _process()
    ├── Panels & overlays: 25+ UI elements
    └── Signal handlers for UI updates
```

## Problem

**FarmView is a God Object** - it:
- Creates and owns ALL game systems
- Handles simulation logic AND UI rendering
- Makes it hard to run multiple independent simulations
- Couples UI rendering to game ticks
- Difficult to unit test
- Hard to serialize/save state cleanly

## Proposed Solution: MVC Architecture

```
Farm.gd (Simulation - pure logic)
├── Owns: FarmGrid, FarmEconomy, GoalsSystem
├── Owns: GameController, FactionManager
├── Owns: VocabularyEvolution, TomatoConspiracyNetwork
├── Manages Biome.gd
├── Pure game state, no UI references
└── Emits signals when state changes

Biome.gd (Simulation - pure logic)
├── Manages: Temperature, phase, energy
├── Manages: Sun/moon cycling
├── No UI references
└── Emits signals on state change

FarmView.gd (UI/Visualization)
├── Receives: Farm instance (injected)
├── Subscribes to: Farm signals
├── Renders: Plot tiles, overlays, panels
├── Handles: Input and sends commands to Farm
└── NO game logic, pure presentation

FarmUI.tscn (Scene structure)
└── Defines: Layout, UI hierarchy, visual elements
```

## Code Smell Indicators

### Currently Found:

1. **Line count**: 2483 lines in one file (hard to navigate)
2. **Responsibility mix**: Lines 126-180 = system creation, Lines 289 = UI creation
3. **Signal count**: 50+ signal connections in one file
4. **Dependencies**: References to 20+ subsystems
5. **Testing**: Can't test Farm logic without FarmView
6. **Serialization**: State mixed with UI state

### Example of Current Coupling:

```gdscript
# Line 142-145: Creating simulation in UI class
farm_grid = FarmGrid.new()
farm_grid.grid_width = GRID_SIZE
farm_grid.grid_height = 1
add_child(farm_grid)

# Line 289: Creating UI after simulation
_create_ui()

# This creates a dependency chain:
# FarmView → FarmGrid → Biome → WheatPlot → DualEmojiQubit
# All of this tied to the visual node hierarchy
```

## Refactoring Effort Assessment

### SCOPE: Medium-Large (Weeks of work)

| Task | Effort | Risk | Priority |
|------|--------|------|----------|
| **Extract Farm.gd** | 3-4 days | Medium | P0 |
| **Extract Biome logic** | 1-2 days | Low | P1 |
| **Decouple GameController** | 2-3 days | Medium | P0 |
| **Rewrite FarmView (UI only)** | 3-4 days | Medium | P0 |
| **Signal/callback refactor** | 2-3 days | High | P0 |
| **Test & debug** | 3-4 days | High | P0 |
| **Documentation** | 1 day | Low | P2 |

**Total: ~2-3 weeks of focused work**

## Key Changes Needed

### 1. Create Farm.gd (Simulation Manager)

```gdscript
class_name Farm
extends Node

# Pure simulation - NO visual elements
var grid: FarmGrid
var economy: FarmEconomy
var goals: GoalsSystem
var controller: GameController
var biome: Biome
var factions: FactionManager
var vocabulary: VocabularyEvolution
var conspiracy: TomatoConspiracyNetwork

signal state_changed(state_data: Dictionary)
signal plot_planted(position: Vector2i)
signal plot_harvested(position: Vector2i, yield_data: Dictionary)

func _ready():
    # Create all systems
    grid = FarmGrid.new()
    economy = FarmEconomy.new()
    # ... etc

    # Wire up systems
    controller.farm_grid = grid
    controller.economy = economy
    # ... etc

func plant_wheat(pos: Vector2i) -> bool:
    if economy.try_spend(5):
        return grid.plant_wheat(pos)
    return false

func _process(delta):
    # Pure game logic tick
    economy.update(delta)
    goals.update(delta)
    biome.update(delta)
    state_changed.emit({...})
```

### 2. Rewrite FarmView.gd (UI Only)

```gdscript
extends Control

# Pure UI - receives injected simulation
var farm: Farm  # Injected dependency
var plot_tiles: Array[PlotTile] = []
var panels: Dictionary = {}

func _ready():
    # No system creation!
    # Just UI setup
    _create_ui()

    # Connect to Farm signals, not to internal systems
    farm.state_changed.connect(_on_state_changed)
    farm.plot_planted.connect(_on_plot_planted)

func _on_state_changed(state):
    # Update visual representation
    _update_economy_display(state.credits)
    _update_plot_displays(state.plots)

func _on_tile_clicked(pos: Vector2i):
    # Send command to simulation
    farm.plant_wheat(pos)  # or farm.controller.plant(pos)
```

### 3. Decouple Biome

```gdscript
class_name Biome
extends Node

# Pure simulation
var temperature: float = 300.0
var phase: float = 0.0
var sun_moon_energy: float = 1.0

signal phase_changed(new_phase: float)
signal temperature_changed(new_temp: float)

func _process(delta):
    phase += delta * PHASE_SPEED
    temperature = calculate_temperature()
    temperature_changed.emit(temperature)

# No references to WheatPlot, FarmView, or UI elements!
```

## Benefits of Refactoring

✅ **Testability**: Test Farm logic without rendering
✅ **Reusability**: Run Farm in SimulationFixture with different views
✅ **Separation**: Can work on simulation and UI independently
✅ **Serialization**: Farm.get_state() → clean snapshot
✅ **Performance**: Simulation ticks decoupled from render ticks
✅ **Multi-screen**: Same Farm runs in multiple views
✅ **Debugging**: Easier to isolate bugs

## Risks

⚠️ **Signal Complexity**: 50+ connections need reworking (HIGH RISK)
⚠️ **Timing Issues**: Simulation and UI ticks currently synchronized
⚠️ **State Sync**: Keeping UI and simulation in sync
⚠️ **Existing Dependencies**: GameController references all subsystems
⚠️ **Testing Coverage**: No unit tests exist for these systems

## Recommended Approach

### Phase 1 (Low Risk)
1. Create empty Farm.gd
2. Move FarmGrid, FarmEconomy creation into Farm
3. Add state_changed signal
4. Connect Farm signals in FarmView
5. Test with SimulationFixture

### Phase 2 (Medium Risk)
1. Extract GameController logic
2. Move Goal/Faction/Vocabulary systems
3. Test signal flow

### Phase 3 (High Risk)
1. Decouple Biome
2. Handle physics/animation ticks
3. Integrate with QuantumForceGraph

### Phase 4 (Polish)
1. Rewrite FarmView.tscn structure
2. Remove all sim references from UI code
3. Write integration tests

## Decision Points

1. **Should Farm.gd be a Node or just a class?**
   - **Node**: Easier integration with Godot signals, auto-freed
   - **Class**: Lighter weight, more testable
   - **Recommendation**: Node for now (easier migration)

2. **Where does QuantumForceGraph live?**
   - Currently in visualization layer
   - Could stay there (just receives Farm state)
   - **Recommendation**: Stays in FarmView (it's pure visualization)

3. **Keep TSCN or move to GD?**
   - FarmUI.tscn can stay as scene file
   - Just separate UI structure from simulation
   - **Recommendation**: Keep TSCN (visual layout is easier in editor)

## Effort vs Impact

```
LOW EFFORT, HIGH IMPACT:
- Extract Farm.gd (gets SimulationFixture working cleanly)
- Add state_changed signal
- Clean up FarmView to just listen

MEDIUM EFFORT, HIGH IMPACT:
- Decouple GameController
- Move all signal connections

HIGH EFFORT, MEDIUM IMPACT:
- Full Biome extraction
- Rewrite all FarmView UI
```

## Recommendation

**Start with Phase 1** - Extract just FarmGrid, FarmEconomy into Farm.gd
- Takes 1-2 days
- Unblocks SimulationFixture multi-instance setup
- Low risk, high visibility
- Can iterate from there

This lets you run in SimulationFixture TODAY while planning Phase 2-4
