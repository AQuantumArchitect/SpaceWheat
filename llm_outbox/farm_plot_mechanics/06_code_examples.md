# Code Examples - Detailed Implementation Walkthrough

## Example 1: Complete Plant-Grow-Harvest Cycle

### Setup

```gdtxt
# Farm.gd
var grid: FarmGrid
var biotic_flux_biome: BioticFluxBiome
var economy: FarmEconomy

func _ready():
    # Create grid
    grid = FarmGrid.new()
    grid.grid_width = 5
    grid.grid_height = 5
    add_child(grid)

    # Create biome
    biotic_flux_biome = BioticFluxBiome.new()
    add_child(biotic_flux_biome)

    # Register biome with grid
    grid.register_biome("BioticFlux", biotic_flux_biome)
    grid.biome = biotic_flux_biome  # Legacy compatibility

    # Assign all plots to BioticFlux
    for y in range(5):
        for x in range(5):
            grid.assign_plot_to_biome(Vector2i(x, y), "BioticFlux")
```

### Step 1: Planting

```gdtxt
# Player presses Grower tool (1), Q (Plant submenu), Q (Wheat)
# FarmInputHandler calls:
func handle_plant_wheat(plot_pos: Vector2i):
    grid.plant(plot_pos, "wheat")

# In FarmGrid.plant():
func plant(position: Vector2i, plant_type: String, quantum_state: Resource = null) -> bool:
    var plot = get_plot(position)
    if plot == null or plot.is_planted:
        return false

    # Set plot type
    var plot_type_map = {
        "wheat": FarmPlot.PlotType.WHEAT,
        "tomato": FarmPlot.PlotType.TOMATO,
        "mushroom": FarmPlot.PlotType.MUSHROOM
    }
    plot.plot_type = plot_type_map[plant_type]

    # Get biome for this plot
    var plot_biome = get_biome_for_plot(position)  # Returns biotic_flux_biome

    # NEW SYSTEM: Biome resource injection
    # Default inputs: 0.08 labor + 0.22 wheat
    plot.plant(0.08, 0.22, plot_biome)

    total_plots_planted += 1

    # Emit signals
    plot_planted.emit(position)
    plot_changed.emit(position, "planted", {"plant_type": plant_type})
    visualization_changed.emit()

    # Auto-entangle from persistent gates
    _auto_entangle_from_infrastructure(position)
    _auto_apply_persistent_gates(position)

    return true

# In BasePlot.plant():
func plant(quantum_state_or_labor = null, wheat_cost: float = 0.0, biome = null) -> void:
    # Resource-based planting: biome creates quantum state
    if biome != null:
        var emojis = get_plot_emojis()  # {"north": "🌾", "south": "👥"}
        quantum_state = DualEmojiQubit.new(emojis["north"], emojis["south"], PI/2)

        # Set initial energy based on resources
        # energy = (wheat_cost * 100.0) + (labor * 50.0)
        quantum_state.energy = (wheat_cost * 100.0) + (quantum_state_or_labor * 50.0)
        # energy = (0.22 * 100) + (0.08 * 50) = 22 + 4 = 26.0

        print("🌱 Plot.plant(): created quantum state %s↔%s at %s" %
              [emojis["north"], emojis["south"], grid_position])

    # Mark as planted
    is_planted = true
    print("   ✅ Plot %s now planted=%s, quantum_state exists=%s" %
          [grid_position, is_planted, quantum_state != null])

# Result:
# - plot.is_planted = true
# - plot.quantum_state = DualEmojiQubit("🌾", "👥", PI/2)
# - plot.quantum_state.energy = 26.0
# - plot.quantum_state.radius = 0.3 (default, will sync to energy during growth)
```

### Step 2: Growing (Automatic Every Frame)

```gdtxt
# In FarmGrid._process(delta):
func _process(delta):
    if not biome:
        return

    # Build icon network
    var icon_network = _build_icon_network()

    # Grow all planted plots
    for position in plots.keys():
        var plot = plots[position]
        if plot.is_planted:
            var plot_biome = get_biome_for_plot(position)  # biotic_flux_biome
            plot.grow(delta, plot_biome, faction_territory_manager, icon_network, conspiracy_network)

# In FarmPlot.grow():
func grow(delta, biome, territory_manager, icon_network, conspiracy_network) -> float:
    if not is_planted or not quantum_state:
        return 0.0

    # Let biome handle quantum evolution
    if biome and biome.has_method("_evolve_quantum_substrate"):
        biome._evolve_quantum_substrate(delta)

    # Apply phase constraints if any
    if phase_constraint:
        phase_constraint.apply(quantum_state)

    return 0.0

# In BioticFluxBiome._evolve_quantum_substrate(dt):
func _evolve_quantum_substrate(dt: float):
    # Skip all evolution if in static mode
    if is_static:
        return

    # CELESTIAL LAYER: Oscillate sun/moon
    _apply_celestial_oscillation(dt)

    # LAYER 1: Hamiltonian evolution (rotation)
    _apply_hamiltonian_evolution(dt)
    _apply_spring_attraction(dt)

    # LAYER 2: Lindblad evolution (energy)
    _apply_energy_transfer(dt)
    _update_energy_taps(dt)

    # LAYER 3: Per-qubit effects
    for position in quantum_states.keys():
        var qubit = quantum_states[position]
        if not qubit:
            continue

        # Skip celestial objects
        if position in plot_types and plot_types[position] == PlotType.CELESTIAL:
            continue

        # Temperature modulation
        temperature_grid[position] = base_temperature

        # Dissipation (T1 + T2 decoherence)
        apply_dissipation(qubit, position, dt)

        # Icon coherence restoration
        if biotic_flux_icon:
            biotic_flux_icon._apply_coherence_restoration(qubit, dt)

        # Apply phase constraint
        _apply_phase_constraint(qubit, position)

        qubit_evolved.emit(position)

# Energy Transfer (Key Growth Mechanism):
func _apply_energy_transfer(dt: float):
    for position in quantum_states.keys():
        var qubit = quantum_states[position]
        if not qubit:
            continue

        # Skip sun/moon
        if position == Vector2i(-1, -1):
            continue

        # 3D Bloch sphere alignment
        var qubit_vector = _bloch_vector(qubit.theta, qubit.phi)
        var sun_vector = _bloch_vector(sun_qubit.theta, sun_qubit.phi)
        var bloch_angle = _bloch_angle_between(qubit_vector, sun_vector)
        var sun_alignment = pow(cos(bloch_angle), 2)

        # Brightness (Born rule from sun theta)
        var sun_brightness = pow(cos(sun_qubit.theta / 2.0), 2)

        # Energy rate
        var icon_influence = wheat_energy_influence  # 0.034
        var energy_rate = base_energy_rate * sun_alignment * sun_brightness * icon_influence
        # energy_rate ≈ 2.45 * alignment * brightness * 0.034

        # Exponential growth
        qubit.grow_energy(energy_rate, dt)
        qubit.radius = qubit.energy

# In DualEmojiQubit.grow_energy():
func grow_energy(strength: float, dt: float) -> void:
    energy *= exp(strength * dt)
    energy = min(energy, 1.0)  # Cap at 1.0

# Example calculation (optimal alignment at noon):
# dt = 0.016 (60 FPS)
# sun_alignment = 1.0 (perfect)
# sun_brightness = 1.0 (noon)
# energy_rate = 2.45 * 1.0 * 1.0 * 0.034 = 0.0833
# energy *= exp(0.0833 * 0.016) = energy * 1.00133
# After 1 second (60 frames): energy ≈ 26.0 * 1.083 = 28.2

# After 20 seconds (sun-moon cycle):
# energy grows from 26.0 → ~90.0 (with varying alignment)
```

### Step 3: Measurement

```gdtxt
# Player presses Grower tool (1), R (Measure + Harvest)
# OR player presses Gates tool (5), R (Measure)

# In BasePlot.measure():
func measure(icon_network = null) -> String:
    if not quantum_state:
        return ""

    # Call DualEmojiQubit.measure() - Born rule collapse
    var outcome = quantum_state.measure()

    # Mark as measured (locks theta)
    has_been_measured = true
    theta_frozen = true

    print("🔬 Plot %s measured: outcome=%s" % [grid_position, outcome])

    return outcome

# In DualEmojiQubit.measure():
func measure() -> String:
    # Born rule probabilities
    var prob_north = get_north_probability()  # cos²(theta/2)

    if randf() < prob_north:
        theta = 0.0  # Collapse to north pole
        return north_emoji  # "🌾"
    else:
        theta = PI   # Collapse to south pole
        return south_emoji  # "👥"

# Example:
# Before measure: theta = 1.2 radians (68.7°)
# prob_north = cos²(1.2/2) = cos²(0.6) = 0.825²= 0.681 (68.1% chance of wheat)
# prob_south = sin²(1.2/2) = sin²(0.6) = 0.565² = 0.319 (31.9% chance of labor)
# Random roll: 0.45 (< 0.681) → Outcome = "🌾" wheat
# After measure: theta = 0.0 (collapsed to wheat)
```

### Step 4: Harvesting

```gdtxt
# In BasePlot.harvest():
func harvest() -> Dictionary:
    if not is_planted:
        return {"success": false, "yield": 0, "energy": 0.0}

    # Auto-measure if not already measured (forgiving behavior)
    if not has_been_measured and quantum_state:
        measure()

    # Double-check measurement succeeded
    if not has_been_measured:
        return {"success": false, "yield": 0, "energy": 0.0}

    # Get the outcome emoji from the measurement
    var outcome = quantum_state.get_semantic_state()  # "🌾" or "👥"

    # Get raw quantum energy
    var energy = 0.0
    if quantum_state:
        energy = quantum_state.energy  # e.g., 0.85
        # Add Berry phase bonus (entanglement memory)
        energy += berry_phase * 0.1  # e.g., + 0.0 (first harvest)

    # Legacy yield calculation (credits = energy * 10)
    var yield_amount = max(1, int(energy * 10))  # e.g., 8 credits

    # Clear the plot
    is_planted = false
    quantum_state = null
    has_been_measured = false
    theta_frozen = false
    replant_cycles += 1  # Increment memory (0 → 1)

    print("✂️  Plot %s harvested: energy=%.2f, outcome=%s" %
          [grid_position, energy, outcome])

    return {
        "success": true,
        "outcome": outcome,      # "🌾"
        "energy": energy,        # 0.85
        "yield": yield_amount    # 8 credits
    }

# In Farm._on_plot_harvested():
func _on_plot_harvested(position: Vector2i, yield_data: Dictionary):
    if not yield_data["success"]:
        return

    var outcome_emoji = yield_data["outcome"]
    var energy = yield_data["energy"]

    # Calculate credits (1 energy = 10 credits)
    var credits = energy * 10

    # Add to economy
    economy.add_resource(outcome_emoji, credits)

    # Update UI
    print("💰 Harvested %s: +%.1f credits" % [outcome_emoji, credits])
```

---

## Example 2: Building a Persistent Bell Gate

### Step 1: Build Gate Infrastructure

```gdtxt
# Player: Quantum tool (2), Q (Cluster), select pos_a and pos_b

# In FarmInputHandler:
func handle_cluster_gate(selected_plots: Array[Vector2i]):
    if selected_plots.size() == 2:
        # 2 plots → Bell gate
        grid.create_entanglement(selected_plots[0], selected_plots[1], "phi_plus")
    elif selected_plots.size() >= 3:
        # 3+ plots → Cluster
        grid.create_entangled_cluster(selected_plots)

# In FarmGrid.create_entanglement():
func create_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String = "phi_plus") -> bool:
    var plot_a = get_plot(pos_a)
    var plot_b = get_plot(pos_b)

    if not plot_a or not plot_b:
        return false
    if not plot_a.is_planted or not plot_b.is_planted:
        return false
    if not plot_a.quantum_state or not plot_b.quantum_state:
        return false

    # Create quantum entanglement
    _create_quantum_entanglement(pos_a, pos_b, bell_type)

    # Add persistent gate infrastructure
    plot_a.add_persistent_gate(bell_type, [pos_b])
    plot_b.add_persistent_gate(bell_type, [pos_a])

    print("🔗 Created Bell gate (%s) between %s and %s" % [bell_type, pos_a, pos_b])
    return true

# In FarmGrid._create_quantum_entanglement():
func _create_quantum_entanglement(pos_a: Vector2i, pos_b: Vector2i, bell_type: String) -> bool:
    var plot_a = get_plot(pos_a)
    var plot_b = get_plot(pos_b)

    # Create EntangledPair object
    var pair = EntangledPair.new(
        plot_a.quantum_state,
        plot_b.quantum_state,
        bell_type
    )

    entangled_pairs.append(pair)

    # Mark plots as entangled (legacy tracking)
    plot_a.add_entanglement(plot_b.plot_id, 0.8)
    plot_b.add_entanglement(plot_a.plot_id, 0.8)

    # Emit signal
    entanglement_created.emit(pos_a, pos_b)

    return true

# In BasePlot.add_persistent_gate():
func add_persistent_gate(gate_type: String, linked_plots: Array[Vector2i] = []) -> void:
    persistent_gates.append({
        "type": gate_type,
        "active": true,
        "linked_plots": linked_plots.duplicate()
    })
    print("🔧 Added persistent gate '%s' to plot %s (linked: %d plots)" %
          [gate_type, grid_position, linked_plots.size()])

# Result:
# - EntangledPair created with density matrix
# - plot_a.persistent_gates = [{"type": "phi_plus", "active": true, "linked_plots": [pos_b]}]
# - plot_b.persistent_gates = [{"type": "phi_plus", "active": true, "linked_plots": [pos_a]}]
```

### Step 2: Harvest Both Plots

```gdtxt
# Harvest plot A
var result_a = grid.harvest(pos_a)
# → plot_a.quantum_state = null
# → plot_a.is_planted = false
# → plot_a.persistent_gates STILL CONTAINS gate info!
# → EntangledPair removed from entangled_pairs array

# Harvest plot B
var result_b = grid.harvest(pos_b)
# → plot_b.quantum_state = null
# → plot_b.is_planted = false
# → plot_b.persistent_gates STILL CONTAINS gate info!
```

### Step 3: Replant Plot A

```gdtxt
grid.plant(pos_a, "wheat")

# In FarmGrid.plant():
# ... (creates quantum state as before)
# ...
# After planting, calls:
_auto_apply_persistent_gates(pos_a)

# In _auto_apply_persistent_gates():
func _auto_apply_persistent_gates(position: Vector2i):
    var plot = get_plot(position)
    if not plot.quantum_state:
        return

    # Check all persistent gates on this plot
    for gate_config in plot.get_active_gates():
        var gate_type = gate_config.get("type", "")
        var linked_plots = gate_config.get("linked_plots", [])

        # gate_type = "phi_plus"
        # linked_plots = [pos_b]

        match gate_type:
            "phi_plus", "phi_minus", "psi_plus", "psi_minus":
                # Bell gate
                for linked_pos in linked_plots:
                    var linked_plot = get_plot(linked_pos)  # pos_b
                    if linked_plot and linked_plot.is_planted and linked_plot.quantum_state:
                        # Both planted → create entanglement
                        _create_quantum_entanglement(position, linked_pos, gate_type)
                    else:
                        # Linked plot not planted yet, skip
                        print("   ⏸️  Gate %s waiting for linked plot %s to be planted" %
                              [gate_type, linked_pos])

# At this point:
# - pos_a planted, has quantum_state
# - pos_b NOT planted yet
# - No entanglement created (waiting)
```

### Step 4: Replant Plot B

```gdtxt
grid.plant(pos_b, "wheat")

# Same flow as above, but now:
# - pos_b gets quantum_state
# - _auto_apply_persistent_gates(pos_b) called
# - Checks gate: {"type": "phi_plus", "linked_plots": [pos_a]}
# - Checks pos_a: IS planted, HAS quantum_state
# - Creates entanglement!

# In _create_quantum_entanglement(pos_b, pos_a, "phi_plus"):
var pair = EntangledPair.new(
    plot_b.quantum_state,
    plot_a.quantum_state,
    "phi_plus"
)
entangled_pairs.append(pair)

print("🔗 Auto-entangled %s ↔ %s (from persistent gate)" % [pos_b, pos_a])

# Result:
# - New EntangledPair created
# - Both qubits linked again
# - Infrastructure worked!
```

---

## Example 3: Energy Tap System

### Building an Energy Tap

```gdtxt
# Player: Energy tool (4), Q (Energy Tap submenu), Q (Tap Wheat)

# In FarmGrid.plant_energy_tap():
func plant_energy_tap(position: Vector2i, target_emoji: String) -> bool:
    var plot = get_plot(position)
    if plot == null or plot.is_planted:
        return false

    # Validation: Check if emoji is in discovered vocabulary
    var available_emojis = get_available_tap_emojis()
    if not available_emojis.has(target_emoji):
        print("⚠️  Cannot plant tap: %s not in discovered vocabulary" % target_emoji)
        return false

    # Configure as energy tap
    plot.plot_type = FarmPlot.PlotType.ENERGY_TAP
    plot.tap_target_emoji = target_emoji  # "🌾"
    plot.tap_theta = 3.0 * PI / 4.0       # Near south pole
    plot.tap_phi = PI / 4.0                # 45° off axis
    plot.tap_base_rate = 0.5               # Drain rate
    plot.tap_accumulated_resource = 0.0

    # Create tap quantum state
    var emojis = plot.get_plot_emojis()  # {"north": "🚰", "south": "⚡"}
    plot.quantum_state = DualEmojiQubit.new(emojis["north"], emojis["south"], plot.tap_theta)
    plot.quantum_state.phi = plot.tap_phi
    plot.quantum_state.radius = 0.5

    plot.is_planted = true

    plot_changed.emit(position, "planted", {"plant_type": "energy_tap"})
    visualization_changed.emit()

    print("🚰 Planted energy tap at %s targeting %s" % [position, target_emoji])
    return true
```

### Energy Draining (Auto-runs in Biome)

```gdtxt
# In BioticFluxBiome._update_energy_taps(dt):
func _update_energy_taps(dt: float) -> void:
    if not grid:
        return

    # Iterate through all plots in grid
    for plot in grid.plots.values():
        # Skip non-energy-tap plots
        if not plot or plot.plot_type != FarmPlot.PlotType.ENERGY_TAP:
            continue

        # Skip if no target configured
        if not plot.tap_target_emoji or plot.tap_target_emoji == "":
            continue

        var target_emoji = plot.tap_target_emoji  # "🌾"
        var tap_theta = plot.tap_theta
        var tap_base_rate = plot.tap_base_rate

        # Find all qubits with matching target emoji and drain them
        for position in quantum_states.keys():
            var target_qubit = quantum_states[position]
            if not target_qubit:
                continue

            # Skip celestial objects
            if position in plot_types and plot_types[position] == PlotType.CELESTIAL:
                continue

            # Check if this qubit produces/represents the target emoji
            if target_qubit.north_emoji != target_emoji and target_qubit.south_emoji != target_emoji:
                continue

            # Calculate cos² coupling (phase alignment)
            var alignment = pow(cos((target_qubit.theta - tap_theta) / 2.0), 2)

            # Amplitude (how target-like the qubit is)
            var amplitude = pow(cos(target_qubit.theta / 2.0), 2)

            # Total transfer rate
            var transfer_rate = tap_base_rate * amplitude * alignment

            # Apply energy transfer (drain from target, accumulate in tap)
            if target_qubit.energy > 0.01:
                # Max 10% drain per tick to avoid overshooting
                var drained = min(transfer_rate * dt, target_qubit.energy * 0.1)
                target_qubit.grow_energy(-drained, dt)  # Negative = drain
                target_qubit.radius = target_qubit.energy  # Sync radius

                # Accumulate in tap plot
                plot.tap_accumulated_resource += drained

# Example calculation:
# dt = 0.016 (60 FPS)
# target_qubit: theta = 0.5 (more wheat than labor)
# tap_theta = 3*PI/4 = 2.356
# alignment = cos²((0.5 - 2.356)/2) = cos²(-0.928) = 0.603² = 0.364
# amplitude = cos²(0.5/2) = cos²(0.25) = 0.969² = 0.939
# transfer_rate = 0.5 * 0.939 * 0.364 = 0.171
# drained = min(0.171 * 0.016, target_qubit.energy * 0.1)
#         = min(0.00274, 0.085) = 0.00274
# target_qubit.energy -= 0.00274
# plot.tap_accumulated_resource += 0.00274

# After 10 seconds (600 frames):
# tap_accumulated_resource ≈ 1.64 wheat units drained
```

### Harvesting the Tap

```gdtxt
# Player harvests the energy tap
var result = grid.harvest(tap_position)

# In BasePlot.harvest() for energy tap:
# (same as normal harvest, but accumulated_resource has value)

# In Farm._on_plot_harvested():
func _on_plot_harvested(position: Vector2i, yield_data: Dictionary):
    var plot = grid.get_plot(position)

    if plot.plot_type == FarmPlot.PlotType.ENERGY_TAP:
        var resource_collected = plot.tap_accumulated_resource
        var target_emoji = plot.tap_target_emoji

        # Add tapped resource to economy
        economy.add_resource(target_emoji, resource_collected)

        print("🚰 Harvested energy tap: +%.2f %s" % [resource_collected, target_emoji])
```

---

## Key Code Patterns

### Pattern 1: Biome-Driven Evolution

```gdtxt
Plot stores state → Biome evolves state → Visualization displays state

FarmPlot.grow() → Biome._evolve_quantum_substrate() → DualEmojiQubit changes
```

### Pattern 2: Signal-Driven Updates

```gdtxt
FarmGrid emits signal → Farm listens → Economy/UI updates

grid.plot_harvested.emit(pos, data)
→ farm._on_plot_harvested(pos, data)
→ economy.add_resource(emoji, energy * 10)
→ ui.update_credits_display()
```

### Pattern 3: Persistent Infrastructure

```gdtxt
Gate built → Harvest destroys qubit → Infrastructure persists → Replant triggers auto-entangle

plot.add_persistent_gate("bell_phi_plus", [other_pos])
→ harvest() clears quantum_state
→ plant() creates new quantum_state
→ _auto_apply_persistent_gates() re-entangles
```

### Pattern 4: Multi-Biome Routing

```gdtxt
Plot assigned to biome → Growth routed to correct biome → Different evolution

grid.assign_plot_to_biome(pos, "Forest")
→ plot.grow() calls get_biome_for_plot(pos)
→ returns ForestEcosystem_Biome
→ ForestEcosystem_Biome._evolve_quantum_substrate()
```
