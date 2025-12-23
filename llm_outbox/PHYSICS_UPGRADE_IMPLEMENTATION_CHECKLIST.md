# SpaceWheat Physics Upgrade: Implementation Checklist

**Goal:** Transform game into clean quantum computing model with Hamiltonian/Biome separation

**Scope:** Base game only (tomato/market/conspiracy systems defer for later)

**Terminology Update:**
- "Bath" → "Biome" (environmental layer with temperature, sun/moon cycle)
- No Quantum Refrigerator (player temperature control deferred)

---

## PHASE 1: Separate Hamiltonian from Biome ⚡

### 1.1 Refactor IconHamiltonian Base Class

**File:** `Core/Icons/IconHamiltonian.gd`

**Changes:**
- [ ] Remove `damping_rate` from `evolution_bias`
- [ ] Create `hamiltonian_terms: Dictionary` with sigma_x, sigma_y, sigma_z
- [ ] Create `coupling_matrix: Dictionary` for two-qubit couplings
- [ ] Implement `apply_hamiltonian_evolution(qubit: DualEmojiQubit, dt: float)` method
- [ ] Remove all temperature/dissipation logic (moves to Biome)

**Code template:**
```gdscript
class_name IconHamiltonian

var hamiltonian_terms: Dictionary = {
    "sigma_x": 0.0,
    "sigma_y": 0.0,
    "sigma_z": 0.0,
}

var coupling_matrix: Dictionary = {}  # (node_a, node_b) -> coupling_strength

func apply_hamiltonian_evolution(qubit: DualEmojiQubit, dt: float):
    # Pure unitary rotation - NO dissipation
    qubit.apply_hamiltonian_rotation(hamiltonian_terms, dt)
```

**Files affected:**
- `Core/Icons/IconHamiltonian.gd` ← MODIFY

---

### 1.2 Create Biome Class (Replaces Bath)

**File:** `Core/Environment/Biome.gd` (NEW FILE)

**Responsibilities:**
- Temperature management
- Sun/moon cycle
- Decoherence rates (T₁, T₂)
- Apply Lindblad dissipation

**Code structure:**
```gdscript
class_name Biome
extends Node

# Sun/Moon cycle (from existing TomatoConspiracyNetwork pattern)
var sun_moon_phase: float = 0.0  # 0 to TAU
var sun_moon_period: float = 20.0  # seconds for full cycle

# Temperature control
var base_temperature: float = 300.0  # Kelvin
var temperature_grid: Dictionary = {}  # Vector2i(x,y) -> temp

# Decoherence parameters (derived from temperature)
var T1_base_rate: float = 0.001
var T2_base_rate: float = 0.002

func _ready():
    set_process(true)

func _process(dt: float):
    # Advance sun/moon cycle
    _evolve_sun_moon_cycle(dt)

    # Update temperature based on cycle
    _update_temperature_from_cycle()

func _evolve_sun_moon_cycle(dt: float):
    sun_moon_phase += (TAU / sun_moon_period) * dt
    sun_moon_phase = wrapf(sun_moon_phase, 0.0, TAU)

func _update_temperature_from_cycle():
    # Temperature follows sun/moon: high at noon/midnight, low at dawn/dusk
    var energy_strength = sin(sun_moon_phase) * sin(sun_moon_phase)
    var temp_offset = energy_strength * 50.0  # ±50K variation
    base_temperature = 300.0 + temp_offset

func get_T1_rate(position: Vector2i) -> float:
    var temp = temperature_grid.get(position, base_temperature)
    return T1_base_rate * (temp / 300.0)

func get_T2_rate(position: Vector2i) -> float:
    var temp = temperature_grid.get(position, base_temperature)
    return T2_base_rate * (temp / 300.0)

func apply_dissipation(qubit: DualEmojiQubit, position: Vector2i, dt: float):
    var T1_rate = get_T1_rate(position)
    var T2_rate = get_T2_rate(position)

    qubit.apply_amplitude_damping(T1_rate * dt)
    qubit.apply_phase_damping(T2_rate * dt)

func is_currently_sun() -> bool:
    return sun_moon_phase < PI

func get_sun_moon_time_remaining() -> float:
    var current_phase = wrapf(sun_moon_phase, 0.0, PI)
    return (PI - current_phase) / (TAU / sun_moon_period)
```

**Files affected:**
- `Core/Environment/Biome.gd` ← CREATE NEW

---

### 1.3 Update FarmGrid Integration

**File:** `Core/GameMechanics/FarmGrid.gd`

**Changes:**
- [ ] Create Biome reference: `var biome: Biome`
- [ ] Modify `_apply_icon_effects(delta)` to:
  - Apply Icon Hamiltonians FIRST (unitary)
  - Apply Biome dissipation SECOND (Lindblad)
- [ ] Pass biome reference to plots that need sun/moon info

**Code template:**
```gdscript
# In FarmGrid.gd

var biome: Biome = null

func _ready():
    # ... existing code ...
    biome = Biome.new()
    add_child(biome)

func _apply_icon_effects(delta: float):
    for plot in get_all_planted_plots():
        # STEP 1: Icon Hamiltonians (unitary evolution)
        for icon in active_icons:
            icon.apply_hamiltonian_evolution(plot.quantum_state, delta)

        # STEP 2: Biome dissipation (Lindblad terms)
        biome.apply_dissipation(
            plot.quantum_state,
            plot.grid_position,
            delta
        )
```

**Files affected:**
- `Core/GameMechanics/FarmGrid.gd` ← MODIFY

---

### 1.4 Update Individual Icon Classes

**File:** `Core/Icons/BioticFluxIcon.gd` (and others)

**Changes for each icon:**
- [ ] Update `hamiltonian_terms` (remove damping)
- [ ] Update activation calculation (no temperature-based modifiers)
- [ ] Remove `T1_modifier`, `T2_modifier` logic

**For BioticFluxIcon specifically:**
```gdscript
# OLD: evolution_bias = Vector3(0.1, 0.05, -0.03)  # theta, phi, damping

# NEW:
hamiltonian_terms = {
    "sigma_x": 0.3,   # Strong transverse field
    "sigma_y": 0.1,   # Rotation
    "sigma_z": 0.05,  # Weak Z-bias
}
```

**Files affected:**
- `Core/Icons/BioticFluxIcon.gd` ← MODIFY
- `Core/Icons/ChaosIcon.gd` ← MODIFY
- `Core/Icons/ImperiumIcon.gd` ← MODIFY

---

### 1.5 Add Hamiltonian Rotation to DualEmojiQubit

**File:** `Core/QuantumSubstrate/DualEmojiQubit.gd`

**New methods:**
```gdscript
func apply_hamiltonian_rotation(H: Dictionary, dt: float):
    """Apply unitary evolution under Hamiltonian

    Bloch sphere evolution:
    θ̇ = -2 * H.sigma_y
    φ̇ = -2 * H.sigma_z / sin(θ)
    """
    var dtheta = -2.0 * H.get("sigma_y", 0.0) * dt
    var dphi = 0.0

    if abs(sin(theta)) > 0.01:
        dphi = -2.0 * H.get("sigma_z", 0.0) / sin(theta) * dt

    theta = clamp(theta + dtheta, 0.0, PI)
    phi = wrapf(phi + dphi, 0.0, TAU)

    # Accumulate Berry phase
    berry_phase += _compute_berry_phase_increment(dtheta, dphi)

func apply_amplitude_damping(rate: float):
    """T1: Energy loss to environment"""
    # Reduce excited state amplitude
    radius *= (1.0 - rate)

func apply_phase_damping(rate: float):
    """T2: Pure dephasing (phi randomization)"""
    # Add phase noise
    phi += randfn(0.0, 1.0) * sqrt(rate)
```

**Files affected:**
- `Core/QuantumSubstrate/DualEmojiQubit.gd` ← MODIFY

---

### 1.6 Update WheatPlot Sun/Moon Reference

**File:** `Core/GameMechanics/WheatPlot.gd`

**Changes:**
- [ ] Remove hard-coded `conspiracy_network` reference
- [ ] Accept `biome` parameter in `grow()` calls
- [ ] Use `biome.is_currently_sun()` for sun/moon checks

**Code template:**
```gdscript
# In WheatPlot.grow()
func grow(delta: float, biome = null, icon_network = null) -> float:
    if not is_planted or not quantum_state:
        return 0.0

    _evolve_quantum_state(delta, biome, icon_network)
    return 0.0

func _evolve_quantum_state(delta: float, biome = null, icon_network = null):
    # ... existing evolution code ...

    # Use biome for sun/moon checks
    if plot_type == PlotType.MUSHROOM and biome:
        if biome.is_currently_sun():
            target_theta = PI  # Sun regresses mushrooms
```

**Files affected:**
- `Core/GameMechanics/WheatPlot.gd` ← MODIFY (light touch)

---

### ✅ PHASE 1 Deliverable

**Done when:**
- [ ] Icons are pure Hamiltonians (no damping)
- [ ] Biome handles all dissipation
- [ ] FarmGrid applies in correct order (Hamiltonian → Biome)
- [ ] Game plays identically to before
- [ ] Temperature follows sun/moon cycle

**Test:**
- [ ] Plant wheat, watch theta evolve (should use Hamiltonian)
- [ ] Measure: should detangle correctly
- [ ] Temperature varies with sun/moon cycle
- [ ] Biotic/Chaos/Imperium icons have expected effects

---

## PHASE 2: Mills as Ancilla Systems 🏭

### 2.1 Extend DualEmojiQubit for Ancilla

**File:** `Core/QuantumSubstrate/DualEmojiQubit.gd`

**New properties:**
```gdscript
var ancilla_state: Vector2 = Vector2(1, 0)  # |0⟩ = unmilled
var is_coupled_to_ancilla: bool = false

func couple_to_ancilla(coupling_strength: float, dt: float):
    """Hamiltonian: H_mill = g * Z_wheat ⊗ X_mill

    Rotate ancilla based on wheat Z-expectation
    """
    var wheat_z_expectation = cos(theta)
    var ancilla_rotation = coupling_strength * wheat_z_expectation * dt

    ancilla_state = ancilla_state.rotated(ancilla_rotation)
    is_coupled_to_ancilla = true

func measure_ancilla() -> String:
    """Measure ancilla in computational basis

    Returns: "flour" or "nothing"
    Collapses ancilla only (wheat stays coherent!)
    """
    var prob_flour = ancilla_state.x * ancilla_state.x
    var outcome = "flour" if randf() < prob_flour else "nothing"

    # Collapse ancilla
    ancilla_state = Vector2(1, 0) if outcome == "nothing" else Vector2(0, 1)
    is_coupled_to_ancilla = false

    return outcome
```

**Files affected:**
- `Core/QuantumSubstrate/DualEmojiQubit.gd` ← MODIFY

---

### 2.2 Create QuantumMill Building

**File:** `Core/GameMechanics/QuantumMill.gd` (NEW FILE)

**Structure:**
```gdscript
class_name QuantumMill
extends Node2D

# Configuration
var grid_position: Vector2i
var coupling_strength: float = 0.5
var measurement_interval: float = 1.0
var last_measurement_time: float = 0.0

# Statistics
var total_measurements: int = 0
var flour_outcomes: int = 0
var measurement_history: Array[Dictionary] = []

# References
var entangled_wheat: Array[WheatPlot] = []
var farm_grid: FarmGrid = null

func _ready():
    set_process(true)

func _process(delta: float):
    last_measurement_time += delta

    if last_measurement_time >= measurement_interval:
        perform_quantum_measurement()
        last_measurement_time = 0.0

func set_entangled_wheat(plots: Array[WheatPlot]):
    """Link wheat plots to this mill"""
    entangled_wheat = plots

func perform_quantum_measurement():
    """Measure ancilla of all entangled wheat plots"""
    if entangled_wheat.is_empty():
        return

    var total_flour = 0

    for plot in entangled_wheat:
        if not plot.quantum_state:
            continue

        # Couple wheat to ancilla
        plot.quantum_state.couple_to_ancilla(coupling_strength, measurement_interval)

        # Measure ancilla
        var outcome = plot.quantum_state.measure_ancilla()
        if outcome == "flour":
            total_flour += 1

    # Record statistics
    total_measurements += 1
    flour_outcomes += total_flour

    measurement_history.append({
        "time": Time.get_ticks_msec(),
        "flour_produced": total_flour,
        "wheat_count": entangled_wheat.size()
    })

    # Add to economy
    if total_flour > 0:
        FarmEconomy.add_flour(total_flour)

func get_flow_rate() -> Dictionary:
    """Compute flow rate from measurement history"""
    return FlowRateCalculator.compute_flow_rate(measurement_history, 60.0)
```

**Files affected:**
- `Core/GameMechanics/QuantumMill.gd` ← CREATE NEW

---

### 2.3 Create FlowRateCalculator

**File:** `Core/GameMechanics/FlowRateCalculator.gd` (NEW FILE)

**Structure:**
```gdscript
class_name FlowRateCalculator

static func compute_flow_rate(
    measurement_history: Array[Dictionary],
    window_size_seconds: float = 60.0
) -> Dictionary:
    """Compute flow rate statistics from measurement history

    Returns: {mean, variance, std_error, confidence}
    """
    var current_time = Time.get_ticks_msec()
    var recent_measurements = measurement_history.filter(func(m):
        return (current_time - m.time) / 1000.0 < window_size_seconds
    )

    if recent_measurements.is_empty():
        return {"mean": 0.0, "variance": 0.0, "confidence": 0.0}

    # Calculate statistics
    var total_flour = 0
    for m in recent_measurements:
        total_flour += m.flour_produced

    var mean_flour_per_measurement = float(total_flour) / recent_measurements.size()

    # Estimate variance (Poisson for now)
    var variance = mean_flour_per_measurement / recent_measurements.size()
    var std_error = sqrt(variance) if variance > 0 else 0.0

    return {
        "mean": mean_flour_per_measurement,
        "variance": variance,
        "std_error": std_error,
        "confidence": 1.0 - (2.0 * std_error) if std_error > 0 else 0.0
    }
```

**Files affected:**
- `Core/GameMechanics/FlowRateCalculator.gd` ← CREATE NEW

---

### 2.4 Integrate Mills into FarmGrid

**File:** `Core/GameMechanics/FarmGrid.gd`

**Changes:**
- [ ] Track QuantumMill instances
- [ ] Handle mill placement (PlotType.MILL)
- [ ] Link adjacent wheat to mills

**Code template:**
```gdscript
var quantum_mills: Dictionary = {}  # position -> QuantumMill

func place_mill(pos: Vector2i) -> bool:
    var plot = get_plot(pos)
    if not plot or plot.is_planted:
        return false

    # Create mill
    var mill = QuantumMill.new()
    mill.grid_position = pos
    mill.farm_grid = self
    add_child(mill)

    # Link to adjacent wheat
    var adjacent_wheat = get_adjacent_wheat(pos)
    mill.set_entangled_wheat(adjacent_wheat)

    quantum_mills[pos] = mill
    plot.plot_type = WheatPlot.PlotType.MILL
    plot.is_planted = true

    return true
```

**Files affected:**
- `Core/GameMechanics/FarmGrid.gd` ← MODIFY

---

### 2.5 Add Mill Plot Type to WheatPlot

**File:** `Core/GameMechanics/WheatPlot.gd`

**Changes:**
```gdscript
enum PlotType { WHEAT, TOMATO, MUSHROOM, MILL, MARKET }
```

**Files affected:**
- `Core/GameMechanics/WheatPlot.gd` ← MODIFY (one line)

---

### ✅ PHASE 2 Deliverable

**Done when:**
- [ ] QuantumMill class exists and processes
- [ ] Ancilla coupling works (wheat stays coherent)
- [ ] Measurements produce discrete flour outcomes
- [ ] FlowRateCalculator tracks statistics
- [ ] Mills can be placed on grid
- [ ] Measurement frequency is configurable

**Test:**
- [ ] Place mill adjacent to wheat
- [ ] Wheat theta evolves normally
- [ ] Mill auto-measures at interval
- [ ] Flour inventory increases
- [ ] FlowRate displays reasonable numbers

---

## PHASE 3: Concrete Icon Hamiltonians 🎭

### 3.1 Update BioticFluxIcon

**File:** `Core/Icons/BioticFluxIcon.gd`

**Changes:**
```gdscript
extends IconHamiltonian

func _init():
    name = "Biotic Flux"

    hamiltonian_terms = {
        "sigma_x": 0.3,   # Strong transverse field (tunneling)
        "sigma_y": 0.1,   # Weak rotation
        "sigma_z": 0.05,  # Weak Z-bias
    }

    coupling_matrix = {}  # No two-qubit couplings for now
```

**Files affected:**
- `Core/Icons/BioticFluxIcon.gd` ← MODIFY

---

### 3.2 Update ChaosIcon

**File:** `Core/Icons/ChaosIcon.gd`

**Changes:**
```gdscript
extends IconHamiltonian

func _init():
    name = "Chaos"
    _randomize_hamiltonian()

func _randomize_hamiltonian():
    hamiltonian_terms = {
        "sigma_x": randf_range(-0.2, 0.2),
        "sigma_y": randf_range(-0.2, 0.2),
        "sigma_z": randf_range(-0.1, 0.1),
    }
```

**Files affected:**
- `Core/Icons/ChaosIcon.gd` ← MODIFY

---

### 3.3 Update ImperiumIcon

**File:** `Core/Icons/ImperiumIcon.gd`

**Changes:**
```gdscript
extends IconHamiltonian

func _init():
    name = "Imperium"

    hamiltonian_terms = {
        "sigma_x": 0.0,   # No transverse field
        "sigma_y": 0.0,   # No rotation
        "sigma_z": 0.5,   # Strong Z-field (pinning)
    }

    coupling_matrix = {}  # No entanglement couplings
```

**Files affected:**
- `Core/Icons/ImperiumIcon.gd` ← MODIFY

---

### 3.4 Verify Bloch Sphere Evolution

**File:** `Core/QuantumSubstrate/DualEmojiQubit.gd`

**Verify:**
- [ ] `apply_hamiltonian_rotation()` uses correct formula
- [ ] Berry phase accumulation works
- [ ] Theta bounds checking [0, π]
- [ ] Phi wrapping [0, 2π]

**Files affected:**
- `Core/QuantumSubstrate/DualEmojiQubit.gd` ← VERIFY

---

### ✅ PHASE 3 Deliverable

**Done when:**
- [ ] Icons have explicit Pauli operator terms
- [ ] Hamiltonian evolution is mathematically correct
- [ ] Biotic/Chaos/Imperium have distinct behaviors
- [ ] Berry phase accumulates properly
- [ ] Players can predict icon effects from physics

**Test:**
- [ ] Biotic icon keeps wheat near π/2 (superposition)
- [ ] Imperium icon pushes wheat toward 0 or π (poles)
- [ ] Chaos icon randomizes evolution
- [ ] Berry phase increases with spiraling paths
- [ ] Theta stays in [0, π], phi stays in [0, 2π]

---

## PHASE 4: Biome Temperature Parametrics 🌡️

### 4.1 Enhanced Biome Temperature Model

**File:** `Core/Environment/Biome.gd`

**Changes:**
- [ ] Temperature calculation from sun/moon cycle
- [ ] Optional per-position temperature overrides
- [ ] Method to get local temperature at position

**Code template:**
```gdscript
func _update_temperature_from_cycle():
    """Temperature follows sun/moon: high at peak, low at transition"""
    var energy_strength = abs(sin(sun_moon_phase))
    var temp_variation = energy_strength * energy_strength * 100.0  # Quadratic

    base_temperature = 300.0 + temp_variation

    # Optionally allow position-specific offsets
    for pos in temperature_grid.keys():
        temperature_grid[pos] = base_temperature

func set_local_temperature_override(position: Vector2i, temp: float):
    """Allow future infrastructure to modify local temperature"""
    temperature_grid[position] = clamp(temp, 1.0, 1000.0)

func get_energy_strength() -> float:
    """Return current biome energy level (0 to 1)"""
    return abs(sin(sun_moon_phase))
```

**Files affected:**
- `Core/Environment/Biome.gd` ← MODIFY

---

### 4.2 Display Biome State in UI

**File:** `UI/Panels/ResourcePanel.gd`

**Changes:**
- [ ] Add biome info display (temperature, sun/moon phase)
- [ ] Show current energy/cycle position

**Code template:**
```gdscript
# In ResourcePanel._create_ui()
var biome_info = Label.new()
biome_info.text = "Biome: 300K ☀️"
# Add to UI
```

**Files affected:**
- `UI/Panels/ResourcePanel.gd` ← MODIFY (light touch)

---

### 4.3 Link Biome to FarmView

**File:** `UI/FarmView.gd`

**Changes:**
- [ ] Reference `biome` from FarmGrid
- [ ] Update UI with biome info each frame

**Code template:**
```gdscript
func _update_ui():
    if farm_grid and farm_grid.biome:
        var temp = farm_grid.biome.base_temperature
        var phase = farm_grid.biome.sun_moon_phase
        var is_sun = farm_grid.biome.is_currently_sun()
        # Update UI...
```

**Files affected:**
- `UI/FarmView.gd` ← MODIFY (light touch)

---

### ✅ PHASE 4 Deliverable

**Done when:**
- [ ] Temperature varies smoothly with sun/moon cycle
- [ ] Biome state visible in UI
- [ ] Decoherence rates track temperature
- [ ] Plots decohere faster at high temp, slower at low temp
- [ ] Players understand biome cycle affects quantum behavior

**Test:**
- [ ] Watch temperature oscillate (300K ± 100K)
- [ ] At low temp: longer coherence times
- [ ] At high temp: faster dephasing
- [ ] UI shows current sun/moon phase

---

## 🎯 COMPLETE IMPLEMENTATION TIMELINE

| Phase | Checklist Size | Est. Complexity | Risk |
|-------|---|---|---|
| 1: Hamiltonian/Biome | 6 tasks | Medium | Low |
| 2: Mills/Ancilla | 5 tasks | Medium | Medium |
| 3: Icon Operators | 4 tasks | Low | Low |
| 4: Biome Display | 3 tasks | Low | Low |

**Total: 18 implementation tasks**

---

## 📋 MASTER CHECKLIST (Quick Reference)

### Phase 1
- [ ] 1.1 Refactor IconHamiltonian
- [ ] 1.2 Create Biome class
- [ ] 1.3 Update FarmGrid
- [ ] 1.4 Update Icons (Biotic/Chaos/Imperium)
- [ ] 1.5 Add hamiltonian_rotation to DualEmojiQubit
- [ ] 1.6 Update WheatPlot sun/moon reference

### Phase 2
- [ ] 2.1 Add ancilla to DualEmojiQubit
- [ ] 2.2 Create QuantumMill class
- [ ] 2.3 Create FlowRateCalculator
- [ ] 2.4 Integrate mills into FarmGrid
- [ ] 2.5 Add MILL plot type

### Phase 3
- [ ] 3.1 Update BioticFluxIcon Hamiltonian
- [ ] 3.2 Update ChaosIcon Hamiltonian
- [ ] 3.3 Update ImperiumIcon Hamiltonian
- [ ] 3.4 Verify Bloch sphere evolution

### Phase 4
- [ ] 4.1 Enhance Biome temperature model
- [ ] 4.2 Add biome display to ResourcePanel
- [ ] 4.3 Link Biome to FarmView

---

## 🚀 Ready to Implement?

**Start with Phase 1.** It's the foundation for everything else.

**Suggested order:**
1. Create Biome.gd (new file)
2. Refactor IconHamiltonian.gd
3. Update FarmGrid._apply_icon_effects()
4. Update each Icon class
5. Add methods to DualEmojiQubit
6. Update WheatPlot references

Once Phase 1 is solid, Phase 2 flows naturally from there.

---

**Next Step:** Implement Phase 1, then report back for Phase 2 approval.

Agent ID for reference: a9c8b70
