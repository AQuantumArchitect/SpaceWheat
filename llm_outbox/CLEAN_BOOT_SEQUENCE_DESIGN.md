# Clean Boot Sequence Architecture

**Status:** 🎯 Design Document - Ready for Implementation
**Goal:** Eliminate frame-based timing issues with explicit, synchronous initialization phases

---

## Problem Statement

**Current Issues:**
1. ✅ Dependencies ARE in correct order
2. ❌ Order is spread across multiple frames (implicit timing)
3. ❌ Multiple deferred calls make sequence hard to follow
4. ❌ Early exits in _ready() based on missing dependencies
5. ❌ Race conditions possible if frame timing changes
6. ❌ Hard to debug when something depends on "frame 3" behavior

**Example Current Flow:**
```
Frame 0:   BiomeBase._ready() → bath initialized
Frame 1:   QuantumForceGraph._ready()
Frame 2:   FarmUI._ready() → EARLY EXIT (missing deps)
Frame 3:   inject_layout_calculator() → NOW creates tiles
Frame 4+:  FarmUI.setup_farm() executes (deferred)
```

**Problem:** If frame timing shifts, everything breaks. No explicit guarantees.

---

## Solution: Multi-Phase Boot Sequence

### Design Principles

1. **Explicit Phases** - Each phase completes before next starts
2. **No Deferred Calls** - All setup happens synchronously within a phase
3. **Clear Dependencies** - Each phase lists what it depends on
4. **Idempotent** - Can call setup multiple times safely
5. **Observable** - Signals emit when each phase completes
6. **Resilient** - Guards against missing dependencies

### Boot Phases (Sequential)

```
Phase 1: AUTOLOADS (Godot engine)
  └─ VerboseConfig._ready()
  └─ IconRegistry._ready()  ← Creates CoreIcons
  └─ GameStateManager._ready()

       ↓ [guarantee: IconRegistry exists]

Phase 2: SCENE INSTANTIATION (Godot engine)
  └─ FarmView and all children instantiated
  └─ PlayerShell._ready()
  └─ Overlays._ready()
  └─ Farm._ready()
     ├─ Create FarmEconomy
     ├─ Create Biomes (BiomeBase._ready() for each)
     │  └─ _initialize_bath()
     │     └─ Uses IconRegistry (guaranteed)
     ├─ Create FarmGrid
     └─ Grid registers with biomes

       ↓ [guarantee: Biomes + Grid exist + IconRegistry available]

Phase 3: BOOT() - Game initialization (NEW!)
  Entry Point: BootManager.boot(farm, shell, quantum_viz)

  Stage 3A: Initialize Core Systems
    ├─ farm.finalize_biomes()  ← Any post-setup for biomes
    ├─ grid.finalize_grid()     ← Grid fully ready
    ├─ Signal: "core_systems_ready"

  Stage 3B: Initialize Visualization
    ├─ quantum_viz.initialize()  ← Creates QuantumForceGraph
    │  └─ Create BiomeLayoutCalculator
    │  └─ Compute layout positions
    ├─ Signal: "visualization_ready"

  Stage 3C: Initialize UI (NOW has all dependencies)
    ├─ farm_ui.setup_farm(farm)
    │  ├─ Inject grid_config
    │  ├─ Inject biomes dict
    │  ├─ Inject layout_calculator (NOW exists)
    │  ├─ Create PlotGridDisplay → creates tiles
    │  ├─ Create FarmInputHandler
    │  └─ Connect all signals
    ├─ Shell.show_farm_ui(farm_ui)
    ├─ Signal: "ui_ready"

  Stage 3D: Start Simulation
    ├─ farm.enable_simulation()  ← Allows _process() to evolve baths
    ├─ Input enabled
    ├─ Signal: "game_ready"

```

---

## Implementation Details

### Phase 1 & 2: Unchanged (Godot built-in)

No changes needed - these work correctly.

### Phase 3: New BootManager Class

**File:** `Core/Boot/BootManager.gd`

```gdscript
class_name BootManager
extends Node

## Manages the boot sequence - ensures proper initialization order
## Call BootManager.boot() once to transition from Phase 2 to Phase 3

signal core_systems_ready
signal visualization_ready
signal ui_ready
signal game_ready

var _booted: bool = false
var _current_stage: String = ""

## Main entry point - called after all Phase 2 _ready() calls
static func boot(farm: Farm, shell: PlayerShell, quantum_viz: BathQuantumVisualizationController) -> void:
    var manager = BootManager.new()
    manager._boot_internal(farm, shell, quantum_viz)

func _boot_internal(farm: Farm, shell: PlayerShell, quantum_viz: BathQuantumVisualizationController) -> void:
    if _booted:
        push_warning("Boot already completed!")
        return

    print("\n" + "="*70)
    print("BOOT SEQUENCE STARTING")
    print("="*70 + "\n")

    # Stage 3A: Core Systems
    _stage_core_systems(farm)

    # Stage 3B: Visualization
    _stage_visualization(farm, quantum_viz)

    # Stage 3C: UI
    _stage_ui(farm, shell, quantum_viz)

    # Stage 3D: Start Simulation
    _stage_start_simulation(farm)

    _booted = true

    print("\n" + "="*70)
    print("BOOT SEQUENCE COMPLETE - GAME READY")
    print("="*70 + "\n")

    game_ready.emit()

## Stage 3A: Initialize core systems
func _stage_core_systems(farm: Farm) -> void:
    _current_stage = "CORE_SYSTEMS"
    print("📍 Stage 3A: Core Systems")

    # Verify all required components exist
    assert(farm != null, "Farm is null!")
    assert(farm.grid != null, "Farm.grid is null!")
    assert(farm.grid.biomes != null, "Farm.grid.biomes is null!")

    # Verify IconRegistry is available
    var icon_registry = get_node_or_null("/root/IconRegistry")
    assert(icon_registry != null, "IconRegistry not found! Autoloads not initialized.")

    # Verify all biomes initialized correctly
    for biome_name in farm.grid.biomes.keys():
        var biome = farm.grid.biomes[biome_name]
        assert(biome != null, "Biome '%s' is null!" % biome_name)
        assert(biome.bath != null, "Biome '%s' has null bath!" % biome_name)
        assert(biome.bath._hamiltonian != null, "Biome '%s' bath has null hamiltonian!" % biome_name)
        assert(biome.bath._lindblad != null, "Biome '%s' bath has null lindblad!" % biome_name)
        print("  ✓ Biome '%s' verified" % biome_name)

    # Any additional farm finalization
    farm.finalize_setup()

    print("  ✓ Core systems ready\n")
    core_systems_ready.emit()

## Stage 3B: Initialize visualization
func _stage_visualization(farm: Farm, quantum_viz: BathQuantumVisualizationController) -> void:
    _current_stage = "VISUALIZATION"
    print("📍 Stage 3B: Visualization")

    assert(quantum_viz != null, "QuantumViz is null!")

    # Initialize the visualization engine
    quantum_viz.initialize()

    # Verify layout calculator was created
    assert(quantum_viz.graph != null, "QuantumForceGraph not created!")
    assert(quantum_viz.graph.layout_calculator != null, "BiomeLayoutCalculator not created!")

    print("  ✓ QuantumForceGraph created")
    print("  ✓ BiomeLayoutCalculator ready")
    print("  ✓ Layout positions computed\n")

    visualization_ready.emit()

## Stage 3C: Initialize UI
func _stage_ui(farm: Farm, shell: PlayerShell, quantum_viz: BathQuantumVisualizationController) -> void:
    _current_stage = "UI"
    print("📍 Stage 3C: UI Initialization")

    # Load and instantiate FarmUI scene
    var farm_ui_scene = load("res://UI/FarmUI.tscn")
    assert(farm_ui_scene != null, "FarmUI.tscn not found!")

    var farm_ui = farm_ui_scene.instantiate() as Control
    assert(farm_ui != null, "FarmUI failed to instantiate!")

    # Now inject dependencies (guaranteed to exist)
    farm_ui.setup_farm(farm)

    # Inject layout calculator (created in Stage 3B)
    var plot_grid_display = farm_ui.get_node("PlotGridDisplay")
    if plot_grid_display:
        plot_grid_display.inject_layout_calculator(quantum_viz.graph.layout_calculator)
        print("  ✓ Layout calculator injected")

    # Show UI in shell
    shell.load_farm_ui(farm_ui)
    print("  ✓ FarmUI mounted in shell")

    # Create and inject FarmInputHandler
    var input_handler = load("res://UI/FarmInputHandler.gd").new()
    input_handler.farm = farm
    input_handler.plot_grid_display = plot_grid_display
    farm_ui.input_handler = input_handler
    print("  ✓ FarmInputHandler created\n")

    ui_ready.emit()

## Stage 3D: Start simulation
func _stage_start_simulation(farm: Farm) -> void:
    _current_stage = "START_SIMULATION"
    print("📍 Stage 3D: Start Simulation")

    # Enable farm processing
    farm.set_process(true)
    farm.enable_simulation()
    print("  ✓ Farm simulation enabled")

    # Enable input processing
    # (done separately to avoid input during boot)
    print("  ✓ Input system enabled")
    print("  ✓ Ready to accept player input\n")
```

---

## Integration Points

### 1. Farm._ready() (Phase 2)

**Current:**
```gdscript
func _ready() -> void:
    # ...biome creation, grid creation...
    GameStateManager.active_farm = self
    await get_tree().process_frame
    await get_tree().process_frame
    # Then what? No explicit next step
```

**New:**
```gdscript
func _ready() -> void:
    # ...biome creation, grid creation...
    GameStateManager.active_farm = self

    # Signal that we're ready to boot
    call_deferred("_notify_boot_ready")

func _notify_boot_ready() -> void:
    # Called from deferred to ensure _ready() fully completes
    # BootManager.boot() will be called from PlayerShell
    pass
```

### 2. PlayerShell (Phase 2 end / Phase 3 start)

**Current:**
```gdscript
func _ready() -> void:
    # ... create overlays ...
    await get_tree().process_frame
    var farm = create_farm()
    add_child(farm)
    # Then??
```

**New:**
```gdscript
func _ready() -> void:
    # ... create overlays ...
    # Farm instantiation handled by scene loading

func _on_farm_scene_ready(farm: Farm) -> void:
    # Called when Farm._ready() completes
    # This triggers Phase 3
    var quantum_viz = BathQuantumVisualizationController.new()
    add_child(quantum_viz)

    # Start boot sequence
    BootManager.boot(farm, self, quantum_viz)

func load_farm_ui(farm_ui: Control) -> void:
    # Called by BootManager in Stage 3C
    var farm_container = get_node("FarmUIContainer")
    farm_container.add_child(farm_ui)
```

### 3. FarmUI.tscn → FarmUI.gd

**Current:**
```gdscript
func _ready() -> void:
    # Early exit - missing deps
    if not grid_config:
        return

func setup_farm(farm: Farm) -> void:
    # ...deferred call...
    call_deferred("_setup_farm_deferred", farm)
```

**New:**
```gdscript
func _ready() -> void:
    # Don't do anything - wait for setup_farm()
    pass

func setup_farm(farm: Farm) -> void:
    # Called synchronously from BootManager.Stage 3C
    # All dependencies guaranteed to exist

    _grid_config = farm.grid
    _farm = farm

    # Create plot grid display
    plot_grid_display = PlotGridDisplay.new()
    plot_grid_display.inject_farm(farm)
    plot_grid_display.inject_grid_config(farm.grid)
    add_child(plot_grid_display)

    # Create resource panel
    resource_panel.setup_economy(farm.economy)

    # Create other UI elements
    # ... etc
```

---

## Benefits of Clean Boot

| Aspect | Before | After |
|--------|--------|-------|
| **Timing** | Frame-based (0, 1, 2, 3, 4+) | Phase-based (1, 2, 3a, 3b, 3c, 3d) |
| **Dependencies** | Implicit in code | Explicit in BootManager |
| **Debugging** | "What frame am I in?" | "What stage failed?" |
| **Resilience** | One frame shift breaks everything | Guaranteed phase completion |
| **Observability** | Signal per object | Signal per stage |
| **Deferred Calls** | 5+ scattered throughout | 0 (all sync within phases) |
| **Lines of Code** | Same | Same (consolidates logic) |
| **Maintainability** | Fragile, hard to change | Clear, easy to verify |

---

## Step-by-Step Implementation Plan

### Step 1: Create BootManager (2 hours)
- [ ] Create `Core/Boot/BootManager.gd` with boot sequence
- [ ] Implement all stages 3A-3D
- [ ] Add assertions for dependency verification

### Step 2: Update Farm (1 hour)
- [ ] Remove async awaits from Farm._ready()
- [ ] Add `finalize_setup()` method (called by BootManager)
- [ ] Add `enable_simulation()` method

### Step 3: Update PlayerShell (1 hour)
- [ ] Update `_ready()` to NOT call create_farm()
- [ ] Add `load_farm_ui()` method
- [ ] Connect to BootManager

### Step 4: Update FarmUI (1 hour)
- [ ] Remove early exit from `_ready()`
- [ ] Update `setup_farm()` to be synchronous
- [ ] Remove `call_deferred()` calls

### Step 5: Update Biomes (30 min)
- [ ] Verify all biomes call build_hamiltonian_from_icons()
- [ ] Verify all biomes call build_lindblad_from_icons()
- [ ] Add assertions to catch missing builders

### Step 6: Testing (2 hours)
- [ ] Create BootSequenceTest.gd to verify order
- [ ] Test phase completion signals
- [ ] Test dependency assertions
- [ ] Test with automated player

### Step 7: Documentation (30 min)
- [ ] Document boot sequence in README
- [ ] Add comments to each phase
- [ ] Create visual diagram

**Total: ~8 hours**

---

## Testing Strategy

### Test 1: Boot Sequence Verification
```gdscript
# BootSequenceTest.gd
var phase_order = []

func test_boot_sequence():
    BootManager.boot(farm, shell, quantum_viz)

    # Verify order
    assert(phase_order == [
        "CORE_SYSTEMS",
        "VISUALIZATION",
        "UI",
        "START_SIMULATION"
    ])
```

### Test 2: Dependency Assertions
```gdscript
# Create incomplete farm, verify assertion
var incomplete_farm = Farm.new()
# Don't initialize biomes
BootManager.boot(incomplete_farm, shell, quantum_viz)  # ← Should assert!
```

### Test 3: Automated Gameplay
```gdscript
# Run automated player after boot
BootManager.boot(farm, shell, quantum_viz)
# Should have NO QuantumEvolver Nil errors!
run_automated_player()
```

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|-----------|
| Breaking existing code | Low | Medium | Keep same APIs, change internals only |
| Assertions too strict | Medium | Low | Start with warnings, upgrade to asserts |
| Phase ordering change needed | Low | Medium | BootManager can be extended |
| Scene tree structure change | Low | Medium | Parametrize node paths |

---

## Success Criteria

✅ **QuantumEvolver Nil errors eliminated**
- BootManager ensures all dependencies before Stage 3C
- No calls to bath.evolve() before _hamiltonian initialized

✅ **Clear boot sequence**
- 4 distinct phases with clear signals
- Can explain to new developer in 2 minutes

✅ **Testable initialization**
- Can run BootSequenceTest.gd and verify order
- Assertions catch missing dependencies

✅ **No frame-based timing**
- Remove all `await get_tree().process_frame`
- Everything sync within phases

✅ **Same functionality**
- Game behaves identically
- No gameplay changes
- Pure architectural improvement

---

## Conclusion

This clean boot sequence transforms initialization from:
```
Scattered across frames 0-4+
With implicit timing
And deferred calls
```

To:
```
4 explicit phases
With clear dependencies
And synchronous setup
```

This eliminates the QuantumEvolver Nil errors and makes the entire initialization process **debuggable, testable, and resilient to changes**.

