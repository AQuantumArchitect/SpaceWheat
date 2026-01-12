# Boot Test Errors - 2026-01-12

## Test Procedure
- Booted game for 15 seconds
- Captured all console output and logs
- Status: **COMPILATION FAILURES - Game Cannot Run**

---

## Critical Errors (3 Found)

### 1. BUILD_CONFIGS Reference in FarmInputHandler ❌ **BLOCKING**

**Location:** `UI/FarmInputHandler.gd:2581`

**Error:**
```
SCRIPT ERROR: Parse Error: Cannot find member "BUILD_CONFIGS" in base "Farm".
          at: GDScript::reload (res://UI/FarmInputHandler.gd:2581)
```

**Root Cause:**
In Phase 6 of the parametric planting system, `Farm.BUILD_CONFIGS` was removed and replaced with:
- `INFRASTRUCTURE_COSTS` - for buildings (mill, market, kitchen, energy_tap)
- `GATHER_ACTIONS` - for gathering actions (forest_harvest)
- Biome capabilities - for plant types (wheat, mushroom, etc.)

However, `FarmInputHandler._can_plant_type()` still references the old `Farm.BUILD_CONFIGS`:

```gdscript
# Line 2581 (BROKEN)
var config = Farm.BUILD_CONFIGS.get(plant_type, {})
```

**Impact:**
- FarmInputHandler fails to compile
- Cascades to FarmUI (depends on FarmInputHandler)
- Entire UI system fails to load
- **Game is unplayable**

**Fix Required:**
Update `_can_plant_type()` to follow the same pattern as `Farm.build()`:
1. Check if plant_type is in `INFRASTRUCTURE_COSTS` → use that cost
2. Check if plant_type is in `GATHER_ACTIONS` → use that cost
3. Otherwise → query biome capabilities for plant cost

---

### 2. FarmInputHandler Cannot Be Instantiated ❌ **CASCADE FAILURE**

**Locations:**
- `UI/FarmUI.gd:108` - `input_handler = FarmInputHandler.new()`
- `Core/Boot/BootManager.gd:172` - `var input_handler = FarmInputHandlerScript.new()`

**Error:**
```
SCRIPT ERROR: Invalid call. Nonexistent function 'new' in base 'GDScript'.
          at: FarmUI.setup_farm (res://UI/FarmUI.gd:108)
```

**Root Cause:**
Because FarmInputHandler has compilation errors (Error #1), GDScript cannot instantiate it.

**Impact:**
- FarmUI.setup_farm() fails
- BootManager._stage_ui() fails
- UI never completes initialization

**Fix Required:**
Fix Error #1 first (BUILD_CONFIGS reference). This error will resolve automatically.

---

### 3. FarmUI Compilation Failure ❌ **CASCADE FAILURE**

**Error:**
```
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
          at: GDScript::reload (res://UI/FarmUI.gd:0)

ERROR: Failed to load script "res://UI/FarmUI.gd" with error "Compilation failed".
   at: load (modules/gdscript/gdscript.cpp:3041)
```

**Root Cause:**
FarmUI depends on FarmInputHandler, which has compilation errors.

**Fix Required:**
Fix Error #1 first. This error will resolve automatically.

---

## Warnings (Non-Blocking)

### 1. Anchor Size Warning ⚠️

**Location:** `UI/PlayerShell.gd:186`

**Warning:**
```
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
     at: _set_size (scene/gui/control.cpp:1476)
```

**Impact:** Minor UI layout quirk, not blocking gameplay

---

### 2. PlotGridDisplay Null Grid Config ⚠️

**Location:** `UI/PlotGridDisplay.gd:86`

**Warning:**
```
WARNING: [WARN][UI] ⚠️ PlotGridDisplay: grid_config is null - will be set later
```

**Impact:** Expected behavior during boot sequence, resolved later

---

## Successful Systems (No Errors)

✅ **Quantum Infrastructure:**
- OperatorCache: All biomes hit cache (BioticFlux, Market, Forest, Kitchen)
- ComplexMatrix: Native Eigen acceleration enabled
- QuantumComputer: All 4 biomes initialized correctly (3-5 qubits each)
- StrangeAttractorAnalyzer: Initialized for all biomes

✅ **Boot Sequence:**
- IconRegistry: 78 icons registered (27 factions)
- GameStateManager: Save system ready
- QuantumRigorConfig: Initialized with correct settings
- FarmView: Started successfully
- PlayerShell: All panels created (quest, vocabulary, escape menu, etc.)
- Layout: Parametric positioning working (960×540 viewport)

✅ **Biome Systems:**
- BioticFlux: 3 qubits, 7 Lindblad operators, H=8×8
- Market: 3 qubits, 2 Lindblad operators, H=8×8
- Forest: 5 qubits, 14 Lindblad operators, H=32×32
- Kitchen: 3 qubits, 2 Lindblad operators, H=8×8

✅ **UI Components:**
- ActionBarLayer: 960×540 layout correct
- ToolSelectionRow: 6 tools initialized
- Quest system: All panels created
- Overlay system: All overlays ready
- Touch controls: All signals connected
- BiomeLayoutCalculator: Correct positioning for all 4 biomes

✅ **Grid System:**
- GridConfig: 12/12 plots active
- FarmGrid: 6×2 grid initialized
- Plot assignments: All 12 plots assigned to biomes correctly

---

## Fix Priority

**Priority 1 (BLOCKING):**
1. Fix `FarmInputHandler._can_plant_type()` BUILD_CONFIGS reference
   - Replace with parametric cost lookup (INFRASTRUCTURE_COSTS, GATHER_ACTIONS, or biome capabilities)

**Priority 2 (WILL AUTO-RESOLVE):**
- Errors #2 and #3 will resolve once Error #1 is fixed

**Priority 3 (OPTIONAL):**
- Fix anchor size warning in PlayerShell (cosmetic)

---

## Implementation Plan

### Step 1: Fix _can_plant_type() in FarmInputHandler

**Current Code (BROKEN):**
```gdscript
func _can_plant_type(plant_type: String, plots: Array[Vector2i]) -> bool:
	if not farm or plots.is_empty():
		return false

	var config = Farm.BUILD_CONFIGS.get(plant_type, {})  # ❌ BROKEN
	if config.is_empty():
		return false

	if not farm.economy.can_afford_cost(config.get("cost", {})):
		return false

	# ... rest of method
```

**New Code (PARAMETRIC):**
```gdscript
func _can_plant_type(plant_type: String, plots: Array[Vector2i]) -> bool:
	if not farm or plots.is_empty():
		return false

	# PARAMETRIC: Determine cost based on type
	var cost = {}
	var biome_required = ""

	# Check infrastructure buildings
	if Farm.INFRASTRUCTURE_COSTS.has(plant_type):
		cost = Farm.INFRASTRUCTURE_COSTS[plant_type]

	# Check gather actions
	elif Farm.GATHER_ACTIONS.has(plant_type):
		var gather_config = Farm.GATHER_ACTIONS[plant_type]
		cost = gather_config.get("cost", {})
		biome_required = gather_config.get("biome_required", "")

	# Otherwise, query biome capabilities for plant cost
	else:
		# Check first plot's biome for capability
		var first_pos = plots[0]
		var plot_biome = farm.grid.get_biome_for_plot(first_pos)
		if not plot_biome:
			return false

		# Find capability for this plant type
		var capability = null
		for cap in plot_biome.get_plantable_capabilities():
			if cap.plant_type == plant_type:
				capability = cap
				break

		if not capability:
			return false

		cost = capability.cost
		biome_required = plot_biome.name if capability.requires_biome else ""

	# Check if we can afford it
	if not farm.economy.can_afford_cost(cost):
		return false

	# Check at least one plot is valid
	for pos in plots:
		var plot = farm.grid.get_plot(pos)
		if not plot or plot.is_planted:
			continue

		# Check biome requirement
		if biome_required != "":
			var plot_biome_name = farm.grid.plot_biome_assignments.get(pos, "")
			if plot_biome_name != biome_required:
				continue

		return true  # Found valid plot

	return false
```

### Step 2: Test Game Boot

After fixing _can_plant_type(), re-run boot test:
```bash
timeout 15 godot --path . --headless 2>&1 | tee /tmp/game_boot_log_fixed.txt || true
```

Expected: No compilation errors, UI loads correctly

---

## Related Documents

- **PARAMETRIC_PLANTING_COMPLETE.md** - Phase 6 documentation of BUILD_CONFIGS removal
- **TOOLS_VS_QUANTUM_ANALYSIS.md** - Tool reorganization proposals
- **QUANTUM_MACHINERY_CATALOGUE.md** - Complete quantum infrastructure catalog

---

**Status:** Ready for fix implementation
**Next Step:** Apply BUILD_CONFIGS fix to FarmInputHandler._can_plant_type()
**Test Date:** 2026-01-12
