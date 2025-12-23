# Implementation Plan: Icon Modulation + Decoherence Risk + Mushroom Resources

**Date**: December 19, 2024
**Scope**: Make SpaceWheat a fun, playable quantum farming game with real strategic tension
**Focus**: Wheat-centric gameplay with Icons and decoherence as pressure mechanics

---

## Phase 1: Mushroom Resource System (1-2 hours)

### Why First?
Quick win that fixes an existing system. Enables mushroom farming as an alternative path to wheat.

### Task 1.1: Add Mushroom/Detritus Inventories to FarmEconomy

**File**: `Core/GameMechanics/FarmEconomy.gd`

**Changes**:
```gdscript
# Add after flour_inventory (line ~26)
var mushroom_inventory: int = 0
var detritus_inventory: int = 0

# Add signals
signal mushroom_changed(new_amount: int)
signal detritus_changed(new_amount: int)

# Add methods (lines 51-213, after flour methods)
func add_mushroom(amount: int) -> void:
    mushroom_inventory += amount
    mushroom_changed.emit(mushroom_inventory)
    print("🍄 Gained %d mushroom(s), total: %d" % [amount, mushroom_inventory])

func remove_mushroom(amount: int) -> bool:
    if mushroom_inventory < amount:
        return false
    mushroom_inventory -= amount
    mushroom_changed.emit(mushroom_inventory)
    return true

func add_detritus(amount: int) -> void:
    detritus_inventory += amount
    detritus_changed.emit(detritus_inventory)
    print("🍂 Gained %d detritus, total: %d" % [amount, detritus_inventory])

func remove_detritus(amount: int) -> bool:
    if detritus_inventory < amount:
        return false
    detritus_inventory -= amount
    detritus_changed.emit(detritus_inventory)
    return true

func sell_mushroom(amount: int, price_per_unit: int = 3) -> int:
    """Sell mushroom to market (cheaper than wheat)"""
    if mushroom_inventory < amount:
        return 0
    remove_mushroom(amount)
    var earnings = amount * price_per_unit
    earn_credits(earnings, "mushroom_sale")
    return earnings
```

**Why**: Mushrooms are a separate resource from wheat, requiring different handling.

---

### Task 1.2: Update GameController to Route Mushroom/Detritus Harvests

**File**: `Core/GameController.gd`

**Changes** in `harvest_plot()` method (lines 217-249):
```gdscript
# Replace current outcome handling with:
var outcome = harvest_data.get("outcome", "wheat")
match outcome:
    "wheat":
        economy.record_harvest(harvest_data["yield"])
        goals.record_harvest(harvest_data["yield"])
        action_feedback.emit("✂️ Harvested %d wheat!" % harvest_data["yield"], true)
    "labor":
        economy.add_labor(harvest_data["yield"])
        action_feedback.emit("✂️ Harvested %d labor (👥)!" % harvest_data["yield"], true)
    "mushroom":
        economy.add_mushroom(harvest_data["yield"])
        action_feedback.emit("🍄 Harvested %d mushroom!" % harvest_data["yield"], true)
    "detritus":
        economy.add_detritus(harvest_data["yield"])
        action_feedback.emit("🍂 Harvested %d detritus (compost)!" % harvest_data["yield"], true)
```

**Why**: Mushrooms should add to mushroom_inventory, not wheat_inventory.

---

### Task 1.3: Update ResourcePanel to Display Mushroom/Detritus

**File**: `UI/Panels/ResourcePanel.gd`

**Changes**: ResourcePanel should automatically display new resources (it's already dynamic!)
- But we need to update FarmView to connect the signals:

**File**: `UI/FarmView.gd` (lines 640-660, in `_setup_ui()`)

```gdscript
# Add these connections after existing economy signal connections
economy.mushroom_changed.connect(_on_mushroom_changed)
economy.detritus_changed.connect(_on_detritus_changed)

# Add these signal handlers
func _on_mushroom_changed(amount: int):
    resource_panel.update_resources({"🍄": amount, "💰": economy.credits, "👥": economy.labor_inventory, "🌾": economy.wheat_inventory, "💨": economy.flour_inventory, "🍂": economy.detritus_inventory})

func _on_detritus_changed(amount: int):
    resource_panel.update_resources({"🍄": economy.mushroom_inventory, "💰": economy.credits, "👥": economy.labor_inventory, "🌾": economy.wheat_inventory, "💨": economy.flour_inventory, "🍂": amount})
```

**Why**: Mushroom and detritus resources should be visible in the resource bar.

---

## Phase 2: Simple Decoherence Risk (2-3 hours)

### Why Second?
Creates core strategic tension: "Should I harvest now or wait for more yield?"

### Task 2.1: Create Decoherence Pressure System

**New File**: `Core/GameMechanics/DecoherenceManager.gd`

```gdscript
class_name DecoherenceManager extends Node

## Tracks coherence pressure on the farm
## Higher decoherence = plots more likely to lose quantum state

var base_decoherence_rate: float = 0.02  # Loss per second (tunable for difficulty)
var plot_coherence: Dictionary = {}  # Vector2i -> coherence (0.0 to 1.0)

signal plot_decoherence_critical(position: Vector2i, coherence: float)  # Below 0.3

func _ready():
    print("🌌 DecoherenceManager initialized")

func track_plot(position: Vector2i) -> void:
    """Start tracking coherence for a plot"""
    plot_coherence[position] = 1.0  # Start pure

func update_plot_coherence(position: Vector2i, delta: float) -> float:
    """Apply decoherence decay, return current coherence"""
    if not plot_coherence.has(position):
        return 1.0

    var current = plot_coherence[position]
    var decay = base_decoherence_rate * delta
    var new_coherence = max(0.0, current - decay)

    plot_coherence[position] = new_coherence

    # Emit warning if critical
    if new_coherence < 0.3 and current >= 0.3:
        plot_decoherence_critical.emit(position, new_coherence)

    return new_coherence

func get_coherence(position: Vector2i) -> float:
    """Get current coherence (0.0 to 1.0)"""
    return plot_coherence.get(position, 1.0)

func reset_coherence(position: Vector2i) -> void:
    """Reset coherence when plot is measured/harvested"""
    plot_coherence[position] = 1.0

func clear_plot(position: Vector2i) -> void:
    """Stop tracking when plot is cleared"""
    plot_coherence.erase(position)

func get_farm_average_coherence() -> float:
    """Get average coherence across all tracked plots"""
    if plot_coherence.is_empty():
        return 1.0

    var total = 0.0
    for coherence in plot_coherence.values():
        total += coherence

    return total / plot_coherence.size()

func set_difficulty(rate: float) -> void:
    """Adjust decoherence rate (difficulty scaling)"""
    base_decoherence_rate = rate
    print("🌌 Decoherence rate set to %.3f per second" % rate)
```

**Why**: Simple system that tracks coherence decay without complex quantum calculations.

---

### Task 2.2: Integrate DecoherenceManager into FarmView

**File**: `UI/FarmView.gd`

**Changes**:
```gdscript
# Add to member variables (line ~50)
var decoherence_manager: DecoherenceManager

# In _ready(), create and add decoherence manager (line ~130, after game_controller setup)
decoherence_manager = DecoherenceManager.new()
add_child(decoherence_manager)
decoherence_manager.set_difficulty(0.02)  # Loss 2% per second

# In _process(delta), update decoherence (line ~250, in main loop)
if decoherence_manager:
    # Update coherence for all planted plots
    for pos in farm_grid.plots.keys():
        var plot = farm_grid.get_plot(pos)
        if plot and plot.is_planted and plot.quantum_state:
            decoherence_manager.update_plot_coherence(pos, delta)

# Connect decoherence signals (line ~680, in _setup_ui())
decoherence_manager.plot_decoherence_critical.connect(_on_plot_coherence_critical)

# Add signal handler
func _on_plot_coherence_critical(pos: Vector2i, coherence: float):
    action_feedback.emit("⚠️ Plot at %s is losing coherence! Harvest soon!" % pos, false)
```

**Why**: Decoherence manager runs every frame, applying pressure to unmeasured plots.

---

### Task 2.3: Add Decoherence Decay to Harvest Calculation

**File**: `Core/GameMechanics/WheatPlot.gd`

**Changes** in `harvest()` method (lines 260-334):

```gdscript
# Before calculating yield (line ~295), add coherence penalty
func harvest() -> Dictionary:
    if not is_planted or not quantum_state:
        return {"success": false, "yield": 0, "quality": 0.0, "outcome": ""}

    if not has_been_measured:
        print("⚠️ Cannot harvest unmeasured plot! Measure first to observe quantum state.")
        return {"success": false, "yield": 0, "quality": 0.0, "outcome": ""}

    # Get measurement outcome
    var measured_state = get_dominant_emoji()
    var current_berry = quantum_state.get_berry_phase()
    var emojis = get_plot_emojis()

    # NEW: Get coherence penalty from decoherence manager (if available)
    var coherence_penalty = 1.0
    if get_meta("decoherence_manager"):
        var coherence = get_meta("decoherence_manager").get_coherence(grid_position)
        coherence_penalty = coherence  # 0.0 (no yield) to 1.0 (full yield)

    var final_yield = 0
    var quality_multiplier = 1.0
    var outcome_type = ""

    if measured_state == emojis["north"]:  # North emoji
        outcome_type = "wheat" if plot_type == PlotType.WHEAT else ("mushroom" if plot_type == PlotType.MUSHROOM else "tomato")

        var base_yield = randi_range(10, 15)
        # Quality: 1.0 - observer_penalty + berry_bonus
        quality_multiplier = max(0.3, 1.0 - OBSERVER_PENALTY + (current_berry * 0.1))
        # NEW: Apply coherence penalty
        quality_multiplier *= coherence_penalty
        final_yield = int(base_yield * quality_multiplier)

    else:  # South emoji (labor, detritus, sauce)
        # Secondary outcomes not affected by coherence (already small)
        final_yield = 1
        outcome_type = "labor" if plot_type == PlotType.WHEAT else ("detritus" if plot_type == PlotType.MUSHROOM else "sauce")

    # ... rest of harvest method unchanged
```

**Why**: Coherence loss manifests as reduced yield, creating urgency to harvest.

---

### Task 2.4: Add Decoherence Visual Indicator to PlotTile

**File**: `UI/PlotTile.gd`

**Changes** in `_update_visual_state()` method (around line 200-250):

```gdscript
# Add coherence visualization (line ~250, after color calculation)
# Coherence affects glow/opacity
if wheat_plot.quantum_state:
    var coherence = 1.0
    if wheat_plot.has_meta("decoherence_manager"):
        coherence = wheat_plot.get_meta("decoherence_manager").get_coherence(wheat_plot.grid_position)

    # Low coherence = dim/desaturated glow
    var glow_strength = clamp(coherence, 0.2, 1.0)
    background.self_modulate.a = 0.3 + (0.7 * glow_strength)  # Fade out as decoherent

    # Show warning at 30% coherence
    if coherence < 0.3 and coherence > 0.0:
        background.color = Color.YELLOW.lerp(Color.RED, 1.0 - coherence)
    elif coherence <= 0.0:
        background.color = Color.GRAY  # Fully decoherent - looks classical
```

**Why**: Players see coherence decay visually, building urgency.

---

## Phase 3: Icon Modulation Activation (2-3 hours)

### Why Third?
Activates already-built Icon system to modulate quantum physics based on gameplay.

### Task 3.1: Activate Biotic Flux Icon Based on Wheat Count

**File**: `UI/FarmView.gd`

**Changes** in `_update_icon_activation()` method (lines 1334-1357):

```gdscript
func _update_icon_activation():
    """Update Icon activation based on game state"""
    if not biotic_icon or not chaos_icon or not imperium_icon:
        return

    # BIOTIC FLUX: Activated by wheat plot percentage
    var wheat_count = _count_wheat_plots()
    var total_plots = farm_grid.grid_width * farm_grid.grid_height
    var biotic_activation = float(wheat_count) / float(total_plots)
    biotic_icon.calculate_activation_from_wheat(wheat_count, total_plots)

    # Print for debugging
    print("🌾 Biotic Flux: %.0f%% activation (%d wheat of %d plots)" %
        [biotic_activation * 100, wheat_count, total_plots])

    # CHAOS ICON: Activated by active conspiracies (for now, minimal)
    var chaos_activation = 0.0  # Start at 0 (no conspiracies used yet)
    chaos_icon.set_activation(chaos_activation)

    # IMPERIUM ICON: Not used in simple mode
    imperium_icon.set_activation(0.0)

func _count_wheat_plots() -> int:
    """Count how many wheat plots are currently planted"""
    var count = 0
    for pos in farm_grid.plots.keys():
        var plot = farm_grid.get_plot(pos)
        if plot and plot.is_planted and plot.plot_type == WheatPlot.PlotType.WHEAT:
            count += 1
    return count
```

**Why**: Fills the grid with wheat → Biotic Flux activates → Growth accelerates.

---

### Task 3.2: Make Biotic Flux Growth Modifier Visible in WheatPlot

**File**: `Core/GameMechanics/WheatPlot.gd`

**Changes** in `grow()` method, during theta drift (line ~189):

```gdscript
# In _evolve_quantum_state (line 179-189), apply Icon modifiers

# Theta drift based on entanglement and environment - UNLESS MEASURED (frozen)
if not theta_frozen:
    var target_theta = THETA_ISOLATED_TARGET if entangled_plots.is_empty() else THETA_ENTANGLED_TARGET

    # SPECIAL CASE: Mushrooms during sun phase regress to detritus
    if plot_type == PlotType.MUSHROOM and biome:
        if biome.is_currently_sun():
            target_theta = PI  # Sun regresses mushrooms → detritus

    var drift_rate = THETA_DRIFT_RATE * delta

    # NEW: Apply Icon growth modifiers
    if icon_network:
        if icon_network.has("biotic") and icon_network["biotic"]:
            # Biotic Flux accelerates growth (pulls theta toward 0)
            var biotic_icon = icon_network["biotic"]
            drift_rate *= biotic_icon.get_growth_modifier()  # 1.0x to 2.0x
            print("🌾 %s: Biotic Flux boost %.1fx" % [plot_id, biotic_icon.get_growth_modifier()])

    quantum_state.theta = lerp(quantum_state.theta, target_theta, drift_rate)
```

**Why**: Players see Biotic Flux actually speed up wheat growth - tangible feedback.

---

### Task 3.3: Ensure Icons Are Connected to FarmGrid

**File**: `UI/FarmView.gd`

**Verify** (lines 131-158) that Icons are properly added to farm_grid:

```gdscript
# Should already exist, verify it's there:
farm_grid.add_icon(biotic_icon)
farm_grid.add_icon(chaos_icon)
farm_grid.add_icon(imperium_icon)

# Verify farm_grid has active_icons list
# Should already exist in FarmGrid, but check that it stores the icons
```

**Why**: Icons need to be accessible to FarmGrid for Hamiltonian evolution.

---

### Task 3.4: Connect Decoherence Manager to Plot Tiles

**File**: `UI/FarmView.gd`

**Changes** in `_ready()` after creating plots (around line 250):

```gdscript
# Pass decoherence_manager reference to all plots so they can check coherence
for tile in plot_tiles.values():
    if tile and tile.wheat_plot:
        tile.wheat_plot.set_meta("decoherence_manager", decoherence_manager)
```

**Why**: Plots need to know about decoherence for coherence penalties and visual decay.

---

## Phase 4: Simple UI Feedback (1 hour)

### Task 4.1: Add Decoherence Status Display

**File**: `UI/Panels/ActionPanelModeSelect.gd` or create new panel

Add a simple display showing average farm coherence:

```gdscript
# Display above buttons or in separate panel
var avg_coherence = farm_view.decoherence_manager.get_farm_average_coherence()
var status = "Farm Coherence: %.0f%%" % (avg_coherence * 100)
var status_color = Color.GREEN.lerp(Color.RED, 1.0 - avg_coherence)
```

**Why**: Players see at a glance how much time they have before plots decohere.

---

## Phase 5: Testing & Tuning (1-2 hours)

### Task 5.1: Test Decoherence Gameplay

**Test Scenarios**:
1. Plant wheat, wait without harvesting → see coherence decay → yield reduces
2. Plant wheat, harvest immediately → full yield (high coherence)
3. Fill grid with wheat → Biotic Flux activates → growth accelerates
4. Plant mushrooms → harvest as detritus during sun phase

**Tuning Parameters**:
- `DecoherenceManager.base_decoherence_rate` (0.02 = 2% per second = fully decoherent in ~50 seconds)
- `WheatPlot.THETA_DRIFT_RATE` (0.1 = default, affects growth speed)
- `BioticFluxIcon.get_growth_modifier()` (1.0x to 2.0x based on activation)

**Goal**: Make decoherence pressure noticeable but not punishing.

---

## Implementation Order

### Day 1:
1. Phase 1 (Mushroom resources) - 1.5 hours
2. Phase 2 (Decoherence basics) - 2 hours
3. Testing - 1 hour

### Day 2:
1. Phase 3 (Icon activation) - 2 hours
2. Phase 4 (UI feedback) - 1 hour
3. Phase 5 (Tuning) - 1.5 hours

**Total: ~8 hours of development**

---

## Architecture Summary

```
GAMEPLAY LOOP:
├─ Plant wheat (costs 5💰)
├─ Wheat grows (base 10%, Entanglement +20%, Biotic Flux +50% if active)
├─ Decoherence pressure increases (2% per second)
├─ Player decides: Harvest now (lower yield) or wait (higher yield, decoherence risk)
├─ Measure plot → collapse quantum state → coherence resets
├─ Harvest → gain wheat/labor
├─ Sell wheat (2💰/unit) or process to flour
├─ Use resources to plant more wheat (feedback loop)
└─ As wheat count rises → Biotic Flux activates → growth accelerates (positive feedback)

OPTIONAL BRANCHES:
├─ Plant mushroom (costs 1👥 labor)
│  ├─ During moon phase → measure as 🍄, harvest mushrooms
│  └─ During sun phase → regresses to 🍂 detritus
└─ Different yield paths create strategic choice
```

---

## Success Criteria

**Minimum Viable Gameplay**:
- ✅ Plant wheat and mushrooms
- ✅ Harvest for resources
- ✅ Feel decoherence pressure (plots lose value over time)
- ✅ See Biotic Flux reward (more wheat = faster growth)
- ✅ Make strategic timing decisions

**Does NOT require**:
- ❌ Tomato conspiracies
- ❌ Carrion Throne quotas
- ❌ Complex progression
- ❌ Advanced visual effects

**Result**: A small, focused, fun quantum farming game where physics and strategy matter.
