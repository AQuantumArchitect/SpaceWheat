Looking at these two architectural proposals and your current codebase, I can synthesize a concrete implementation plan. Both documents agree on the core principle: **Icons should be pure Hamiltonians, dissipation goes elsewhere, and measurement is the quantum→classical bridge.**

## Synthesis: The Critical Insights

**From Document 1 (Clean Rulebook):**
- Icons = Hermitian operators only (generate unitary evolution)
- Bath = separate decoherence mechanism (Lindblad terms)
- Measurement = discrete irreversible extraction with back-action
- Flow rates = statistics over repeated measurements

**From Document 2 (QPU Model):**
- Farm is literally a quantum computer
- Icons define Hamiltonian matrices (σₓ, σᵧ, σᵧ)
- Temperature grid provides environment coupling
- Mills = measurement apparatus on ancilla qubits

**Against Your Current Code:**
Your `IconHamiltonian.gd` already has the right structure but mixes concerns:
```gdscript
# Current: evolution_bias includes damping
var evolution_bias: Vector3 = Vector3(0.0, 0.0, 0.0)  # theta_rate, phi_rate, damping_rate

# Should separate into:
var hamiltonian_terms: Dictionary  # Pure unitary evolution
var lindblad_operators: Array      # Separate dissipation
```

## Implementation Plan: Four Phases

### **Phase 1: Separate Hamiltonian from Bath** ⚡
*Goal: Make Icons mathematically pure while keeping game playable*

**1.1 Refactor IconHamiltonian base class**

Create clean separation:
```gdscript
# IconHamiltonian.gd - NEW STRUCTURE
class_name IconHamiltonian

# UNITARY EVOLUTION (what Icons control)
var hamiltonian_terms: Dictionary = {
    "sigma_x": 0.0,  # Transverse field strength
    "sigma_y": 0.0,  # Rotating field strength
    "sigma_z": 0.0,  # Longitudinal field strength
}

# Two-qubit coupling terms for entanglement
var coupling_matrix: Dictionary = {}  # (node_a, node_b) -> coupling_strength

# REMOVED: damping_rate (moved to Bath)

func apply_hamiltonian_evolution(qubit: DualEmojiQubit, dt: float):
    # Pure unitary rotation on Bloch sphere
    # Using Pauli operator evolution: ψ(t+dt) = exp(-iHdt) ψ(t)
    var dtheta = hamiltonian_terms.sigma_y * dt
    var dphi = hamiltonian_terms.sigma_z * dt
    qubit.apply_rotation(dtheta, dphi)
```

**1.2 Create EnvironmentBath class**

New singleton handling dissipation:
```gdscript
# EnvironmentBath.gd - NEW FILE
class_name EnvironmentBath

# Temperature field (drives decoherence)
var base_temperature: float = 300.0  # Kelvin
var temperature_grid: Dictionary = {}  # position -> local_temp

# Decoherence rates (from temperature)
func get_T1_rate(position: Vector2) -> float:
    var temp = temperature_grid.get(position, base_temperature)
    return 0.001 * (temp / 300.0)  # Amplitude damping

func get_T2_rate(position: Vector2) -> float:
    var temp = temperature_grid.get(position, base_temperature)
    return 0.002 * (temp / 300.0)  # Dephasing

# Apply Lindblad dissipation (separate from Hamiltonian)
func apply_dissipation(qubit: DualEmojiQubit, position: Vector2, dt: float):
    var T1_rate = get_T1_rate(position)
    var T2_rate = get_T2_rate(position)
    
    # Amplitude damping (energy loss)
    qubit.apply_amplitude_damping(T1_rate * dt)
    
    # Phase damping (coherence loss)
    qubit.apply_phase_damping(T2_rate * dt)
```

**1.3 Update FarmGrid integration**

Modify `_apply_icon_effects()` to use new structure:
```gdscript
# FarmGrid.gd - MODIFIED
func _apply_icon_effects(delta: float):
    for plot in get_all_plots():
        if not plot.is_planted:
            continue
            
        # STEP 1: Apply Icon Hamiltonians (unitary evolution)
        for icon in active_icons:
            icon.apply_hamiltonian_evolution(plot.quantum_state, delta)
        
        # STEP 2: Apply Environment Bath (dissipation)
        EnvironmentBath.apply_dissipation(
            plot.quantum_state, 
            plot.grid_position, 
            delta
        )
```

**Deliverable Phase 1:** Icons are now pure Hamiltonians, dissipation is separate, game still works identically

---

### **Phase 2: Mills as Ancilla Systems** 🏭
*Goal: Implement wheat→flour conversion through quantum measurement*

**2.1 Extend DualEmojiQubit for ancilla modes**

Add ancilla qubit coupling:
```gdscript
# DualEmojiQubit.gd - ADD METHODS
class_name DualEmojiQubit

var ancilla_state: Vector2 = Vector2(1, 0)  # |0⟩ by default (unmilled)
var is_coupled_to_ancilla: bool = false

func couple_to_ancilla(coupling_strength: float, dt: float):
    # Hamiltonian: H_mill = g * Z_wheat ⊗ X_mill
    # Rotates ancilla based on wheat state
    var wheat_z_expectation = cos(theta)  # ⟨σ_z⟩
    var ancilla_rotation = coupling_strength * wheat_z_expectation * dt
    
    # Rotate ancilla in X basis
    ancilla_state = ancilla_state.rotated(ancilla_rotation)
    is_coupled_to_ancilla = true

func measure_ancilla() -> String:
    # Measure ancilla in computational basis
    var prob_flour = ancilla_state.x * ancilla_state.x
    var outcome = "flour" if randf() < prob_flour else "nothing"
    
    # Collapse ancilla (but wheat state can remain coherent!)
    ancilla_state = Vector2(1, 0) if outcome == "nothing" else Vector2(0, 1)
    
    return outcome
```

**2.2 Create QuantumMill building class**

New building type that performs quantum transduction:
```gdscript
# QuantumMill.gd - NEW FILE
class_name QuantumMill
extends Building

# Mill configuration
var coupling_strength: float = 0.5  # Upgradeable
var measurement_interval: float = 1.0  # Seconds between measurements
var last_measurement_time: float = 0.0

# Statistics tracking
var total_measurements: int = 0
var flour_outcomes: int = 0
var measurement_history: Array[Dictionary] = []

func _process(delta: float):
    last_measurement_time += delta
    
    if last_measurement_time >= measurement_interval:
        perform_quantum_measurement()
        last_measurement_time = 0.0

func perform_quantum_measurement():
    # Get entangled wheat cluster
    var wheat_plots = get_adjacent_wheat_plots()
    if wheat_plots.is_empty():
        return
    
    # Couple wheat to ancilla
    for plot in wheat_plots:
        plot.quantum_state.couple_to_ancilla(coupling_strength, measurement_interval)
    
    # Measure ancilla (wheat stays coherent)
    var outcome = wheat_plots[0].quantum_state.measure_ancilla()
    
    # Record statistics
    total_measurements += 1
    if outcome == "flour":
        flour_outcomes += 1
        FarmEconomy.add_flour(1)  # Discrete outcome
    
    # Store for flow rate calculation
    measurement_history.append({
        "time": Time.get_ticks_msec(),
        "outcome": outcome,
        "wheat_count": wheat_plots.size()
    })
```

**2.3 Implement flow rate calculator**

Extract flow rate from measurement statistics:
```gdscript
# FlowRateCalculator.gd - NEW FILE
class_name FlowRateCalculator

# Compute flow rate from measurement history
static func compute_flow_rate(
    measurement_history: Array[Dictionary],
    window_size_seconds: float = 60.0
) -> Dictionary:
    
    var current_time = Time.get_ticks_msec()
    var recent_measurements = measurement_history.filter(func(m):
        return (current_time - m.time) / 1000.0 < window_size_seconds
    )
    
    if recent_measurements.is_empty():
        return {"mean": 0.0, "variance": 0.0, "confidence": 0.0}
    
    # Compute statistics
    var success_count = recent_measurements.filter(func(m): return m.outcome == "flour").size()
    var total_count = recent_measurements.size()
    
    var success_rate = float(success_count) / total_count
    var variance = success_rate * (1.0 - success_rate) / total_count
    var std_error = sqrt(variance)
    
    return {
        "mean": success_rate,
        "variance": variance,
        "std_error": std_error,
        "confidence": 1.0 - (2.0 * std_error)  # ~95% confidence interval
    }
```

**Deliverable Phase 2:** Mills work through quantum measurement, flow rates computed from statistics

---

### **Phase 3: Concrete Icon Hamiltonians** 🎭
*Goal: Replace abstract "biases" with physically interpretable Pauli operators*

**3.1 Define Icon Hamiltonian matrices**

Create explicit operator definitions:
```gdscript
# BioticFluxIcon.gd - REFACTORED
extends IconHamiltonian

func _init():
    name = "Biotic Flux"
    
    # Transverse field Hamiltonian (drives superposition)
    hamiltonian_terms = {
        "sigma_x": 0.3,   # Strong X-field (tunneling between states)
        "sigma_y": 0.1,   # Weak Y-field (phase rotation)
        "sigma_z": 0.05,  # Very weak Z-field (slight bias)
    }
    
    # Two-qubit couplings (mycelial bonds)
    coupling_matrix = {
        # Format: (node_a, node_b) -> {XX: strength, ZZ: strength}
        # Creates entanglement through Heisenberg-like interaction
    }

# ImperiumIcon.gd - REFACTORED
extends IconHamiltonian

func _init():
    name = "Imperium"
    
    # Longitudinal field Hamiltonian (pins to specific state)
    hamiltonian_terms = {
        "sigma_x": 0.0,   # No transverse field
        "sigma_y": 0.0,   # No rotation
        "sigma_z": 0.5,   # Strong Z-field (energy gap)
    }
    
    # Imperium uses measurement-like collapse, not entanglement
    coupling_matrix = {}

# ChaosIcon.gd - REFACTORED  
extends IconHamiltonian

func _init():
    name = "Chaos"
    
    # Stochastic Hamiltonian (time-dependent noise)
    hamiltonian_terms = {
        "sigma_x": randf_range(-0.2, 0.2),  # Random each step!
        "sigma_y": randf_range(-0.2, 0.2),
        "sigma_z": randf_range(-0.1, 0.1),
    }
```

**3.2 Update Bloch sphere evolution**

Implement proper unitary evolution:
```gdscript
# DualEmojiQubit.gd - ENHANCE
func apply_hamiltonian_rotation(H: Dictionary, dt: float):
    # Rotate state on Bloch sphere using Pauli operators
    # Exact formula: θ̇ = -2(h_y), φ̇ = -2(h_z / sin(θ))
    
    var dtheta = -2.0 * H.sigma_y * dt
    var dphi = 0.0
    
    if abs(sin(theta)) > 0.01:  # Avoid singularity at poles
        dphi = -2.0 * H.sigma_z / sin(theta) * dt
    
    theta = clamp(theta + dtheta, 0.0, PI)
    phi = wrapf(phi + dphi, 0.0, TAU)
    
    # Accumulate Berry phase (geometric phase from path)
    berry_phase += compute_berry_phase_increment(dtheta, dphi)
```

**Deliverable Phase 3:** Icons are now interpretable as quantum operators, players can learn actual physics

---

### **Phase 4: Temperature Control & Player Agency** 🌡️
*Goal: Give players control over Bath temperature, making it a strategic resource*

**4.1 Temperature sources**

Make temperature respond to player actions:
```gdscript
# EnvironmentBath.gd - EXTEND
class_name EnvironmentBath

# Temperature modifiers from infrastructure
var cooling_buildings: Dictionary = {}  # position -> cooling_power
var heating_buildings: Dictionary = {}  # position -> heating_power

func update_temperature_grid():
    for pos in temperature_grid.keys():
        var base = base_temperature
        
        # Apply cooling (reduces decoherence)
        if cooling_buildings.has(pos):
            base -= cooling_buildings[pos] * 50.0  # Upgradeable
        
        # Apply heating (increases chaos for specific strategies?)
        if heating_buildings.has(pos):
            base += heating_buildings[pos] * 30.0
        
        temperature_grid[pos] = clamp(base, 1.0, 1000.0)
```

**4.2 New building: Quantum Refrigerator**

Player-built infrastructure to reduce decoherence:
```gdscript
# QuantumRefrigerator.gd - NEW FILE
class_name QuantumRefrigerator
extends Building

var cooling_power: float = 100.0  # Upgradeable
var cooling_radius: float = 2.0   # Affects nearby plots

func _ready():
    # Register with environment
    var affected_positions = get_positions_in_radius(cooling_radius)
    for pos in affected_positions:
        EnvironmentBath.cooling_buildings[pos] = cooling_power

func _exit_tree():
    # Unregister when removed
    for pos in EnvironmentBath.cooling_buildings.keys():
        if EnvironmentBath.cooling_buildings[pos] == cooling_power:
            EnvironmentBath.cooling_buildings.erase(pos)
```

**4.3 Make temperature visible**

Add temperature overlay to UI:
```gdscript
# FarmGrid.gd - ADD VISUALIZATION
func _draw():
    # Draw temperature heatmap
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            var pos = Vector2(x, y)
            var temp = EnvironmentBath.temperature_grid.get(pos, 300.0)
            var color = temperature_to_color(temp)  # Hot=red, Cold=blue
            draw_rect(Rect2(pos * cell_size, cell_size), color, true)
```

**Deliverable Phase 4:** Temperature is now a strategic resource players actively manage

---

## Summary: Clean Architectural Layers

After these four phases, you have:

```
┌─────────────────────────────────────┐
│  Classical Layer (FarmEconomy)      │ ← Discrete resources, costs, UI
├─────────────────────────────────────┤
│  Statistics Layer (FlowRate)        │ ← Aggregated measurement outcomes  
├─────────────────────────────────────┤
│  Measurement Layer (Mills/Markets)  │ ← Quantum→Classical bridge
├─────────────────────────────────────┤
│  Quantum Layer (DualEmojiQubit)     │ ← State vectors, ancilla coupling
├─────────────────────────────────────┤
│  Evolution Layer                    │
│   ├─ Icons (Hamiltonians)           │ ← Unitary operators
│   └─ Bath (Lindblad)                │ ← Dissipation
└─────────────────────────────────────┘
```