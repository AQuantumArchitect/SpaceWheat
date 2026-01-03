# Tools System - 6 Tools with QER Actions

## Overview

SpaceWheat uses a **tool-based interaction system** where the player selects 1 of 6 tools, then uses Q/E/R keys to perform actions on plots.

```
Player Input: [1-6] (select tool) + [Q/E/R] (perform action) + [Click plot]
```

---

## Tool Configuration (ToolConfig.gd)

**Single source of truth for all tool definitions:**

```gdtxt
# Core/GameState/ToolConfig.gd
class_name ToolConfig

const TOOL_ACTIONS = {
    1: {  # GROWER Tool
        "name": "Grower",
        "emoji": "🌱",
        "Q": {"action": "submenu_plant", "label": "Plant ▸", "emoji": "🌾"},
        "E": {"action": "entangle_batch", "label": "Entangle (Bell φ+)", "emoji": "🔗"},
        "R": {"action": "measure_and_harvest", "label": "Measure + Harvest", "emoji": "✂️"},
    },
    2: {  # QUANTUM Tool
        "name": "Quantum",
        "emoji": "⚛️",
        "Q": {"action": "cluster", "label": "Build Gate (2=Bell, 3+=Cluster)", "emoji": "🔗"},
        "E": {"action": "measure_trigger", "label": "Set Measure Trigger", "emoji": "👁️"},
        "R": {"action": "remove_gates", "label": "Remove Gates", "emoji": "💔"},
    },
    3: {  # INDUSTRY Tool
        "name": "Industry",
        "emoji": "🏭",
        "Q": {"action": "submenu_industry", "label": "Build ▸", "emoji": "🏗️"},
        "E": {"action": "place_market", "label": "Build Market", "emoji": "🏪"},
        "R": {"action": "place_kitchen", "label": "Build Kitchen", "emoji": "🍳"},
    },
    4: {  # ENERGY Tool
        "name": "Energy",
        "emoji": "⚡",
        "Q": {"action": "submenu_energy_tap", "label": "Energy Tap ▸", "emoji": "🚰"},
        "E": {"action": "inject_energy", "label": "Inject Energy", "emoji": "⚡"},
        "R": {"action": "drain_energy", "label": "Drain Energy", "emoji": "🔋"},
    },
    5: {  # GATES Tool
        "name": "Gates",
        "emoji": "🔄",
        "Q": {"action": "submenu_single_gates", "label": "1-Qubit ▸", "emoji": "⚛️"},
        "E": {"action": "submenu_two_gates", "label": "2-Qubit ▸", "emoji": "🔗"},
        "R": {"action": "measure_batch", "label": "Measure", "emoji": "👁️"},
    },
    6: {  # Future expansion
        "name": "Future 6",
        "emoji": "6️⃣",
    },
}
```

---

## Tool 1: Grower (Core Farming)

**Purpose:** 80% of gameplay - plant, entangle, harvest

### Q: Plant (Submenu)
```gdtxt
submenu "plant": {
    "Q": plant_wheat → FarmGrid.plant(pos, "wheat")
    "E": plant_mushroom → FarmGrid.plant(pos, "mushroom")
    "R": plant_tomato → FarmGrid.plant(pos, "tomato")
}
```

**Implementation:**
```gdtxt
func plant(position: Vector2i, plant_type: String) -> bool:
    var plot = get_plot(position)
    if plot.is_planted:
        return false

    # Set plot type
    plot.plot_type = {"wheat": WHEAT, "tomato": TOMATO, "mushroom": MUSHROOM}[plant_type]

    # Biome creates quantum state
    plot.plant(0.08, 0.22, biome)  # 0.08 labor + 0.22 wheat

    # Auto-entangle from persistent gates
    _auto_apply_persistent_gates(position)

    return true
```

### E: Entangle Batch (Bell φ+)
```gdtxt
Action: Select 2+ plots → Create Bell pairs between selected plots

Implementation:
func entangle_batch(selected_plots: Array[Vector2i]):
    # Create Bell φ+ pairs between all selected plots
    for i in range(selected_plots.size() - 1):
        var pos_a = selected_plots[i]
        var pos_b = selected_plots[i + 1]
        create_entanglement(pos_a, pos_b, "phi_plus")
```

**Creates EntangledPair:**
```gdtxt
{
    qubit_a: plot_a.quantum_state,
    qubit_b: plot_b.quantum_state,
    density_matrix: [[1,0,0,1], [0,0,0,0], [0,0,0,0], [1,0,0,1]] / sqrt(2),
    bell_type: "phi_plus",
    coherence_time_T1: 100.0
}
```

### R: Measure + Harvest
```gdtxt
Action: Measure quantum state → Harvest plot → Collect credits

Implementation:
func measure_and_harvest(position: Vector2i):
    var plot = get_plot(position)

    # Measure (collapses quantum state)
    var outcome = plot.measure()

    # Harvest (clears plot, returns energy)
    var result = plot.harvest()

    # Convert energy to credits
    var credits = result["energy"] * 10
    economy.add_resource(outcome, credits)
```

---

## Tool 2: Quantum (Persistent Infrastructure)

**Purpose:** Build permanent quantum circuits

### Q: Cluster (Build Gate)
```gdtxt
Action: Select 2 plots → Bell gate
        Select 3+ plots → N-qubit cluster

Implementation:
func create_entangled_cluster(positions: Array[Vector2i]):
    var cluster = EntangledCluster.new()

    for pos in positions:
        var plot = get_plot(pos)
        cluster.add_qubit(plot.quantum_state, plot.plot_id)

        # Add persistent gate to plot
        plot.add_persistent_gate("cluster", positions)

    entangled_clusters.append(cluster)
```

**Key Feature:** Gates persist after harvest! When you replant, the gate automatically re-entangles.

### E: Measure Trigger
```gdtxt
Action: Set plot to auto-measure when neighbor harvested

Status: Not yet implemented (placeholder for future)
```

### R: Remove Gates
```gdtxt
Action: Clear all persistent gates from selected plot

Implementation:
func remove_gates(position: Vector2i):
    var plot = get_plot(position)
    plot.clear_persistent_gates()
```

---

## Tool 3: Industry (Buildings & Economy)

**Purpose:** Build processing infrastructure

### Q: Build (Submenu)
```gdtxt
submenu "industry": {
    "Q": place_mill → Build Mill (grinds wheat into flour)
    "E": place_market → Build Market (sells flour for credits)
    "R": place_kitchen → Build Kitchen (bakes flour into bread)
}
```

**Mill Example:**
```gdtxt
func place_mill(position: Vector2i):
    var plot = get_plot(position)
    plot.plot_type = FarmPlot.PlotType.MILL

    # Create quantum state for mill
    var emojis = plot.get_plot_emojis()  # {"north": "🏭", "south": "💨"}
    plot.quantum_state = DualEmojiQubit.new("🏭", "💨", PI/2)

    plot.is_planted = true
```

**Processing (Auto-runs each frame):**
```gdtxt
func process_mill(delta, grid, economy, conspiracy_network):
    # Find nearby wheat plots
    var nearby_wheat = _find_adjacent_wheat(grid)

    # Drain wheat energy (non-destructive measurement)
    var flour_gained = 0.0
    for wheat_plot in nearby_wheat:
        var wheat_energy = wheat_plot.quantum_state.radius * 0.1
        flour_gained += wheat_energy

    # Accumulate flour resource
    accumulated_flour += flour_gained
```

### E: Place Market
```gdtxt
Identical to Q submenu → Market
```

### R: Place Kitchen
```gdtxt
Identical to Q submenu → Kitchen
```

---

## Tool 4: Energy (Quantum Energy Management)

**Purpose:** Direct manipulation of quantum energy

### Q: Energy Tap (Submenu)
```gdtxt
submenu "energy_tap": {
    "Q": tap_wheat → Drain wheat emoji energy
    "E": tap_mushroom → Drain mushroom emoji energy
    "R": tap_tomato → Drain tomato emoji energy
}
```

**Implementation:**
```gdtxt
func plant_energy_tap(position: Vector2i, target_emoji: String):
    var plot = get_plot(position)
    plot.plot_type = FarmPlot.PlotType.ENERGY_TAP
    plot.tap_target_emoji = target_emoji
    plot.tap_theta = 3.0 * PI / 4.0
    plot.tap_base_rate = 0.5

    # Create tap quantum state
    plot.quantum_state = DualEmojiQubit.new("🚰", "⚡", plot.tap_theta)
    plot.is_planted = true
```

**Energy Drain (Auto-runs in biome):**
```gdtxt
# In BioticFluxBiome._update_energy_taps()
for target_qubit in quantum_states.values():
    if target_qubit.north_emoji == tap_target_emoji:
        # Calculate cos² coupling
        var alignment = cos((target_qubit.theta - tap_theta) / 2.0)^2

        # Transfer energy
        var drained = tap_base_rate * alignment * delta
        target_qubit.energy -= drained
        plot.tap_accumulated_resource += drained
```

**Harvest Tap:**
```gdtxt
var result = tap_plot.harvest()
var resource_collected = tap_plot.tap_accumulated_resource
economy.add_resource(tap_target_emoji, resource_collected)
```

### E: Inject Energy
```gdtxt
Action: Add energy to plot quantum state

Implementation:
func inject_energy(position: Vector2i, amount: float):
    var plot = get_plot(position)
    if plot.quantum_state:
        plot.quantum_state.energy += amount
        plot.quantum_state.radius = plot.quantum_state.energy
```

### R: Drain Energy
```gdtxt
Action: Remove energy from plot quantum state

Implementation:
func drain_energy(position: Vector2i, amount: float):
    var plot = get_plot(position)
    if plot.quantum_state:
        plot.quantum_state.energy = max(0.0, plot.quantum_state.energy - amount)
        plot.quantum_state.radius = plot.quantum_state.energy
```

---

## Tool 5: Gates (Quantum Gate Operations)

**Purpose:** Apply quantum gates to qubits

### Q: 1-Qubit Gates (Submenu)
```gdtxt
submenu "single_gates": {
    "Q": apply_pauli_x → Flip qubit (theta → π - theta)
    "E": apply_hadamard → Create superposition
    "R": apply_pauli_z → Phase flip (phi → phi + π)
}
```

**Pauli-X Implementation:**
```gdtxt
func apply_pauli_x(position: Vector2i):
    var plot = get_plot(position)
    if plot.quantum_state:
        plot.quantum_state.apply_pauli_x()
        # In DualEmojiQubit:
        #   theta = PI - theta
```

**Hadamard Implementation:**
```gdtxt
func apply_hadamard(position: Vector2i):
    var plot = get_plot(position)
    if plot.quantum_state:
        plot.quantum_state.apply_hadamard()
        # Rotates around (1,0,1) axis by π
```

### E: 2-Qubit Gates (Submenu)
```gdtxt
submenu "two_gates": {
    "Q": apply_cnot → CNOT gate (control-NOT)
    "E": apply_cz → CZ gate (control-Z)
    "R": apply_swap → SWAP gate
}
```

**CNOT Example:**
```gdtxt
func apply_cnot(control_pos: Vector2i, target_pos: Vector2i):
    var control_plot = get_plot(control_pos)
    var target_plot = get_plot(target_pos)

    var control_state = control_plot.quantum_state
    var target_state = target_plot.quantum_state

    # If control is |1⟩ (theta > π/2), flip target
    if control_state.theta > PI / 2.0:
        target_state.apply_pauli_x()
```

### R: Measure Batch
```gdtxt
Action: Measure all selected plots

Implementation:
func measure_batch(positions: Array[Vector2i]):
    for pos in positions:
        var plot = get_plot(pos)
        plot.measure()
```

---

## Tool 6: Future Expansion

**Reserved for future features**

---

## Submenu System

**How It Works:**
1. Player presses Q/E/R on a tool
2. If action has `"submenu": "name"`, enter submenu mode
3. Q/E/R now map to submenu actions
4. Press tool number again to exit submenu

**Example:**
```
[Press 1] → Select Grower tool
[Press Q] → Enter "plant" submenu
[Press E] → plant_mushroom action executed
[Press 1 again] → Exit submenu
```

---

## Tool Action Routing

**Flow:**
```
Player input → FarmInputHandler → ToolConfig.get_action() → FarmGrid method
```

**Example:**
```gdscript
# In FarmInputHandler.gd
func handle_tool_action(tool_num: int, key: String, plot_pos: Vector2i):
    var action_def = ToolConfig.get_action(tool_num, key)
    var action_name = action_def.get("action", "")

    match action_name:
        "plant_wheat":
            farm.grid.plant(plot_pos, "wheat")
        "entangle_batch":
            farm.grid.entangle_batch(selected_plots)
        "apply_hadamard":
            farm.grid.apply_hadamard(plot_pos)
        # ... etc
```

**Key Insight:** ToolConfig is the single source of truth. Adding a new tool action requires:
1. Add to TOOL_ACTIONS or SUBMENUS
2. Add match case in FarmInputHandler
3. Implement method in FarmGrid
