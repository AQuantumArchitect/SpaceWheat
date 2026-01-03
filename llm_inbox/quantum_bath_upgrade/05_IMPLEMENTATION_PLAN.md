# Implementation Plan
## Phased Upgrade to Bath-First Quantum Mechanics

---

## Overview

This plan upgrades SpaceWheat from "qubit-first" to "bath-first" architecture in 6 phases, each maintaining a working game.

**Total Estimated Effort:** 40-60 hours of focused development

**Risk Level:** Medium - significant architectural change but well-isolated

---

## Phase 0: Foundation (4-6 hours)

### Goals
- Add core math utilities
- Create base classes without breaking existing code
- Set up testing infrastructure

### Tasks

#### 0.1 Complex Number Class
```
File: Core/QuantumSubstrate/Complex.gd
- Implement Complex class with full arithmetic
- Test: unit tests for add, mul, abs, arg, polar
```

#### 0.2 Icon Base Class
```
File: Core/QuantumSubstrate/Icon.gd
- Implement Icon resource class
- Properties: emoji, hamiltonian_couplings, lindblad_terms, etc.
- No registration yet, just the class
```

#### 0.3 QuantumBath Skeleton
```
File: Core/QuantumSubstrate/QuantumBath.gd
- Create empty class extending RefCounted
- Define interface (methods with pass)
- No implementation yet
```

#### 0.4 Test Scene
```
File: Tests/QuantumBathTest.gd
- Create isolated test scene for bath mechanics
- Independent of existing game code
```

### Deliverables
- [ ] Complex.gd with tests
- [ ] Icon.gd skeleton
- [ ] QuantumBath.gd interface
- [ ] Test scene runs without errors

### Verification
```
Run: Tests/QuantumBathTest.tscn
Expected: Blank scene, no crashes
```

---

## Phase 1: Quantum Bath Core (8-10 hours)

### Goals
- Implement full bath evolution
- Test in isolation
- Verify quantum mechanics are correct

### Tasks

#### 1.1 Bath Initialization
```gdscript
# QuantumBath.gd
func initialize_with_emojis(emojis: Array[String])
func initialize_uniform()
func initialize_weighted(weights: Dictionary)
func get_amplitude(emoji: String) -> Complex
func get_probability(emoji: String) -> float
```

#### 1.2 Hamiltonian Evolution
```gdscript
func build_hamiltonian(icons: Array[Icon])
func evolve_hamiltonian(dt: float)
func normalize()
```

#### 1.3 Lindblad Evolution
```gdscript
func build_lindblad_terms(icons: Array[Icon])
func evolve_lindblad(dt: float)
```

#### 1.4 Full Evolution Loop
```gdscript
func evolve(dt: float):
    evolve_hamiltonian(dt)
    evolve_lindblad(dt)
    bath_evolved.emit()
```

#### 1.5 Projection Function
```gdscript
func project_onto_axis(north: String, south: String) -> Dictionary
# Returns {theta, phi, radius, valid}
```

#### 1.6 Measurement Function
```gdscript
func measure_axis(north: String, south: String, collapse_strength: float) -> String
func partial_collapse(emoji: String, strength: float)
```

### Testing

#### Test A: Conservation
```gdscript
# Total probability should stay at 1.0
func test_normalization():
    bath.initialize_uniform()
    for i in range(1000):
        bath.evolve(0.016)
    assert(abs(bath.get_total_probability() - 1.0) < 0.001)
```

#### Test B: Hamiltonian Oscillation
```gdscript
# Two coupled emojis should oscillate
func test_oscillation():
    bath.initialize_with_emojis(["A", "B"])
    bath.amplitudes = [Complex.new(1, 0), Complex.new(0, 0)]  # Start in |A⟩
    
    var icon_a = Icon.new()
    icon_a.emoji = "A"
    icon_a.hamiltonian_couplings = {"B": 0.5}
    
    bath.build_hamiltonian([icon_a])
    
    # Evolve for one oscillation period
    for i in range(100):
        bath.evolve(0.1)
    
    # Should have moved to |B⟩ and back
    var p_a = bath.get_probability("A")
    # Not exactly 1.0 due to discrete evolution, but close
    assert(p_a > 0.9)
```

#### Test C: Lindblad Transfer
```gdscript
func test_transfer():
    bath.initialize_with_emojis(["source", "target"])
    bath.amplitudes = [Complex.new(1, 0), Complex.new(0, 0)]
    
    var icon = Icon.new()
    icon.emoji = "source"
    icon.lindblad_outgoing = {"target": 0.1}
    
    bath.build_lindblad_terms([icon])
    
    for i in range(100):
        bath.evolve(0.016)
    
    var p_target = bath.get_probability("target")
    assert(p_target > 0.3)  # Significant transfer occurred
```

### Deliverables
- [ ] QuantumBath.gd fully implemented
- [ ] All three core tests pass
- [ ] Test scene shows bath evolution visually

### Verification
```
Run: Tests/QuantumBathTest.tscn
Expected: 
- Two emojis oscillating (H test)
- Amplitude transferring (L test)
- Probability conserved (normalization test)
```

---

## Phase 2: Icon System (6-8 hours)

### Goals
- Implement IconRegistry singleton
- Define core Icons
- Test Icon composition

### Tasks

#### 2.1 IconRegistry Singleton
```
File: Core/QuantumSubstrate/IconRegistry.gd
- Autoload singleton
- register_icon(), get_icon(), has_icon()
- Load from definitions
```

#### 2.2 Core Icon Definitions
```
File: Core/Icons/CoreIcons.gd
- Define ~20 essential Icons
- Celestial: ☀, 🌙
- Flora: 🌾, 🍄, 🌿, 🌱
- Fauna: 🐺, 🐇, 🦌
- Elements: 💧, ⛰, 🍂
- Abstract: 💀, 👥
```

#### 2.3 Markov-to-Icon Converter
```gdscript
func derive_icons_from_markov(markov: Dictionary) -> Array[Icon]
```

#### 2.4 Icon Composition Test
```gdscript
func test_icon_composition():
    # Create bath with multiple Icons
    # Verify emergent behavior matches expectations
```

### Icon Definition Template

```gdscript
# CoreIcons.gd
static func register_all():
    # Sun
    var sun = Icon.new()
    sun.emoji = "☀"
    sun.display_name = "Sol"
    sun.self_energy = 0.5
    sun.self_energy_driver = "cosine"
    sun.driver_frequency = 0.05
    sun.hamiltonian_couplings = {"🌙": 0.8, "🌿": 0.3, "🌾": 0.4}
    sun.tags = ["celestial", "driver"]
    IconRegistry.register_icon(sun)
    
    # ... 19 more Icons
```

### Deliverables
- [ ] IconRegistry.gd singleton
- [ ] CoreIcons.gd with 20 Icons
- [ ] Markov converter function
- [ ] Composition test passes

### Verification
```
Run: Tests/IconCompositionTest.tscn
Expected:
- Icons load correctly
- Bath built from Icons evolves
- Predator-prey oscillation visible
```

---

## Phase 3: BiomeBase Integration (8-10 hours)

### Goals
- Add bath to BiomeBase
- Implement projection mechanics
- Keep existing biomes working (hybrid mode)

### Tasks

#### 3.1 BiomeBase Bath Integration
```gdscript
# BiomeBase.gd additions
var bath: QuantumBath = null
var use_bath_mode: bool = false  # Toggle for gradual migration
var active_projections: Dictionary = {}

func _ready():
    if use_bath_mode:
        _initialize_bath()
```

#### 3.2 Projection Management
```gdscript
func create_projection(position: Vector2i, north: String, south: String) -> DualEmojiQubit
func update_projections()
func remove_projection(position: Vector2i)
func get_projection_qubit(position: Vector2i) -> DualEmojiQubit
```

#### 3.3 Hybrid Evolution
```gdscript
func _process(delta):
    if use_bath_mode:
        bath.evolve(delta)
        update_projections()
    else:
        # Existing evolution code
        _update_quantum_substrate(delta)
```

#### 3.4 Measurement with Backaction
```gdscript
func measure_projection(position: Vector2i) -> String:
    if use_bath_mode:
        var proj = active_projections[position]
        return bath.measure_axis(proj.north, proj.south, 0.5)
    else:
        # Existing measurement
        return quantum_states[position].measure()
```

### Testing

#### Test: Hybrid Mode Switch
```gdscript
func test_hybrid():
    biome.use_bath_mode = false
    # Plant, grow, harvest - should work as before
    
    biome.use_bath_mode = true
    # Plant, grow, harvest - should work with bath
```

### Deliverables
- [ ] BiomeBase.gd updated with bath support
- [ ] Hybrid mode toggle works
- [ ] Projections update correctly
- [ ] Existing biomes still work with use_bath_mode = false

### Verification
```
Run: Existing game with use_bath_mode = false
Expected: No behavior change

Run: Existing game with use_bath_mode = true  
Expected: Similar behavior, bath-driven
```

---

## Phase 4: BioticFlux Retrofit (6-8 hours)

### Goals
- Convert BioticFlux to bath-first
- Verify behavior matches original
- Remove legacy code paths

### Tasks

#### 4.1 BioticFlux Icons
```gdscript
# BioticFluxBiome.gd
func _register_biotic_flux_icons():
    # Sun, Moon, Wheat, Labor, Mushroom, Detritus Icons
    # Tuned to match existing behavior
```

#### 4.2 Bath Initialization
```gdscript
func _initialize_bath():
    var emojis = ["☀", "🌙", "🌾", "💀", "🍄", "🍂"]
    bath = QuantumBath.new()
    bath.initialize_with_emojis(emojis)
    bath.initialize_weighted({...})
    use_bath_mode = true
```

#### 4.3 Remove Legacy Evolution
```gdscript
# Comment out or remove:
# - _apply_celestial_oscillation (replaced by Icon self_energy_driver)
# - _apply_spring_attraction (replaced by H couplings)
# - _apply_energy_transfer (replaced by L terms)
```

#### 4.4 Behavior Verification
- Day/night cycle works
- Wheat grows during day
- Mushroom grows at night
- Harvest yields match

### Testing

#### A/B Comparison
```gdscript
func test_biotic_flux_equivalence():
    var legacy = BioticFluxBiome.new()
    legacy.use_bath_mode = false
    
    var bath_mode = BioticFluxBiome.new()
    bath_mode.use_bath_mode = true
    
    # Run both for 60 seconds
    # Compare final states
    # Should be similar (not identical due to different evolution)
```

### Deliverables
- [ ] BioticFlux fully bath-driven
- [ ] Legacy code removed or commented
- [ ] Behavior matches original ±10%
- [ ] All existing tests pass

### Verification
```
Run: Full game with BioticFlux
Expected: Same gameplay feel, bath-driven internals
```

---

## Phase 5: Forest Implementation (8-10 hours)

### Goals
- Implement ForestEcosystem with bath
- Derive Icons from Markov chain
- Demonstrate emergent predator-prey

### Tasks

#### 5.1 Forest Icons from Markov
```gdscript
func _ready():
    # Load forest_emoji_simulation_v11
    var icons = derive_icons_from_markov(FOREST_MARKOV)
    for icon in icons:
        IconRegistry.register_icon(icon)
```

#### 5.2 Icon Tuning
```gdscript
func _tune_forest_icons():
    # Adjust predator-prey balance
    # Ensure oscillation occurs
```

#### 5.3 Forest Bath
```gdscript
func _initialize_bath():
    var emojis = FOREST_MARKOV.keys()
    bath = QuantumBath.new()
    bath.initialize_with_emojis(emojis)
    # Stationary distribution or custom weights
```

#### 5.4 Remove Organism Spawning
```gdscript
# Delete or disable:
# - QuantumOrganism class usage
# - Reproduction logic
# - Individual instance tracking
```

#### 5.5 Forest Projections
```gdscript
# Player can plant:
# - 🐺/💀 (wolf observation)
# - 🐇/💀 (rabbit observation)
# - 🌿/🍂 (vegetation observation)
```

### Testing

#### Lotka-Volterra Emergence
```gdscript
func test_predator_prey():
    # Initialize with abundant prey
    bath.initialize_weighted({"🐇": 0.3, "🐺": 0.05, "🌿": 0.3, ...})
    
    # Run for 60 seconds
    var prey_history = []
    var pred_history = []
    for i in range(600):
        bath.evolve(0.1)
        prey_history.append(bath.get_probability("🐇"))
        pred_history.append(bath.get_probability("🐺"))
    
    # Check for oscillation
    var prey_peaks = count_peaks(prey_history)
    var pred_peaks = count_peaks(pred_history)
    assert(prey_peaks >= 2)  # At least 2 oscillations
    assert(pred_peaks >= 2)
```

### Deliverables
- [ ] ForestEcosystem_Biome fully bath-driven
- [ ] No organism spawning
- [ ] Predator-prey oscillation emerges
- [ ] 4-6 projection types available

### Verification
```
Run: Forest biome test
Expected:
- 4-6 bubbles (not 100+)
- Bubble sizes oscillate (Lotka-Volterra)
- Measurement affects other bubbles (bath correlation)
```

---

## Phase 6: Polish & Integration (4-6 hours)

### Goals
- Clean up hybrid mode (remove legacy paths)
- Optimize performance
- Document everything

### Tasks

#### 6.1 Remove Legacy Code
- Delete `use_bath_mode` toggles
- Remove old evolution methods
- Clean up QuantumOrganism if unused

#### 6.2 Performance Optimization
- Sparse Hamiltonian for large baths
- Lazy rebuilding
- Profile and optimize hot paths

#### 6.3 Visualization Updates
- Show bath state in UI (optional)
- Energy flow arrows (optional)
- Coherence indicators (optional)

#### 6.4 Documentation
- Update all existing docs
- Add bath architecture to README
- Document Icon definitions

#### 6.5 Final Testing
- Full game playthrough
- All biomes work
- No regressions

### Deliverables
- [ ] Clean codebase (no legacy paths)
- [ ] Performance acceptable (60 FPS)
- [ ] Documentation updated
- [ ] All tests pass

### Verification
```
Run: Full game, extended play session
Expected: Smooth gameplay, emergent dynamics, no crashes
```

---

## Risk Mitigation

### Risk 1: Performance
**Problem:** Large baths (22+ emojis) may be slow

**Mitigation:**
- Use sparse matrices
- Profile early (Phase 1)
- Consider subspace approximation

### Risk 2: Behavior Mismatch
**Problem:** Retrofitted biomes behave differently

**Mitigation:**
- A/B testing in Phase 4
- Tune Icons to match
- Accept some difference (bath is more correct)

### Risk 3: Breaking Changes
**Problem:** Existing game features break

**Mitigation:**
- Hybrid mode in Phase 3
- Gradual migration
- Rollback capability

### Risk 4: Complexity
**Problem:** System becomes too complex to reason about

**Mitigation:**
- Icons are simple units
- Bath math is standard QM
- Extensive documentation

---

## Success Criteria

### Phase 0 Complete When:
- [x] Complex.gd tests pass
- [x] Icon.gd skeleton exists
- [x] Test scene runs

### Phase 1 Complete When:
- [ ] Bath evolution conserves probability
- [ ] Two-emoji oscillation works
- [ ] Lindblad transfer works

### Phase 2 Complete When:
- [ ] IconRegistry loads all Icons
- [ ] 20 core Icons defined
- [ ] Markov converter works

### Phase 3 Complete When:
- [ ] BiomeBase has bath support
- [ ] Hybrid mode toggle works
- [ ] Existing game unchanged

### Phase 4 Complete When:
- [ ] BioticFlux fully bath-driven
- [ ] Behavior matches ±10%
- [ ] Legacy code removed

### Phase 5 Complete When:
- [ ] Forest has no spawning
- [ ] Lotka-Volterra emerges
- [ ] Projections work

### Phase 6 Complete When:
- [ ] Clean codebase
- [ ] 60 FPS performance
- [ ] Documentation complete

---

## Timeline

| Phase | Duration | Dependencies |
|-------|----------|--------------|
| 0 | 1-2 days | None |
| 1 | 2-3 days | Phase 0 |
| 2 | 2 days | Phase 1 |
| 3 | 2-3 days | Phase 1, 2 |
| 4 | 2 days | Phase 3 |
| 5 | 2-3 days | Phase 3, 4 |
| 6 | 1-2 days | All |

**Total: 12-18 days** (assuming focused effort, 3-4 hours/day)

---

## Getting Started

1. Create branch: `feature/bath-first-quantum`
2. Implement Phase 0
3. Test thoroughly before proceeding
4. Commit after each sub-phase
5. Merge after Phase 6 complete

**First file to create:** `Core/QuantumSubstrate/Complex.gd`

Let's build the quantum universe!

