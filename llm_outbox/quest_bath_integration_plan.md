# Quantum Quest System - Bath-First Integration Plan

## Executive Summary

The quantum quest system was implemented assuming the "legacy" per-qubit model where each plot owns its quantum state. SpaceWheat has now upgraded to a **"bath-first" architecture** where:

- **Biomes** own a shared QuantumBath |ψ⟩ = Σ αᵢ|emoji_i⟩
- **Plots** project the bath onto (north, south) axes - they're measurement windows, not state containers
- **Icons** define Hamiltonian and Lindblad terms that drive bath evolution

This document outlines how to integrate the quest system with the new architecture while maintaining backward compatibility during the transition.

---

## Current Status Assessment

### ✅ What's Already Built

**Bath-First Core (Fully Implemented):**
- ✅ `QuantumBath.gd` - Bath state, evolution, projection, measurement
- ✅ `BiomeBase.gd` - Bath mode support with `use_bath_mode` flag
- ✅ `Icon.gd` - Icon system for defining Hamiltonians
- ✅ `IconRegistry.gd` - Singleton registry of all Icons
- ✅ `Complex.gd` - Complex number utilities

**Bath-First Features:**
```gdscript
# In BiomeBase
var use_bath_mode: bool = false  # Toggle for bath-first vs legacy
var bath: QuantumBath = null
var active_projections: Dictionary = {}  # Vector2i → {qubit, north, south}

func create_projection(position, north, south) -> DualEmojiQubit
func update_projections() -> void  # Re-derive from bath each frame
func measure_projection(position) -> String  # Measure with backaction
```

**Quest System (Already Implemented):**
- ✅ 10 core files (Observable, Operation, Condition, Objective, Quest, etc.)
- ✅ 97 tests passing
- ✅ Procedural generation system
- ✅ Real-time evaluation engine

### 🔄 What Needs Integration

**The quest evaluator currently expects:**
1. Individual plot quantum states (legacy model)
2. Direct access to `get_theta()`, `get_phi()`, `get_coherence()` on plots
3. Bath-wide observables from a monolithic BioticFluxBath

**The new architecture provides:**
1. Shared bath state in each biome
2. Projections derived from bath via `bath.project_onto_axis(north, south)`
3. Multiple biomes, each with their own bath

**Gap:** Quest evaluator needs to bridge from projection-based model to observable queries.

---

## Architecture Analysis

### Old Model (What Quest System Was Built For)

```
Plot → owns DualEmojiQubit → has get_theta(), get_coherence()
BioticFluxBath → has get_amplitude(emoji), get_phase(emoji)
```

Quest evaluator reads directly from plots and bath.

### New Model (Bath-First)

```
Biome → owns QuantumBath → evolves |ψ⟩
  ↓
Plot → projects (north, south) → derives DualEmojiQubit
  ↓
Qubit.theta, phi, radius = bath.project_onto_axis(north, south)
```

Quest evaluator needs to:
1. Find which biome a plot belongs to
2. Ask biome for bath
3. Project bath onto plot's axis to get observables

---

## Integration Strategy

### Phase 1: Dual-Mode Support

Support **both** legacy and bath-first modes during transition.

**Design Principles:**
1. ✅ **Backward compatibility** - Quest system works with legacy biomes
2. ✅ **Forward compatibility** - Quest system works with bath-first biomes
3. ✅ **Mode detection** - Automatically detect which mode a biome uses
4. ✅ **Graceful degradation** - Fall back to legacy if bath unavailable

### Phase 2: Observable Reader Abstraction

Create a **unified observable reader interface** that abstracts over legacy vs bath-first.

```gdscript
# Pseudo-interface
class ObservableReader:
    func get_theta(plot) -> float
    func get_phi(plot) -> float
    func get_coherence(plot) -> float
    func get_amplitude(emoji) -> float
    func get_phase(emoji) -> float
    func get_entanglement(plot1, plot2) -> float
```

Two implementations:
- `LegacyObservableReader` - reads from old per-qubit model
- `BathObservableReader` - reads from bath projections

### Phase 3: Plot Registry Enhancement

The quest evaluator needs a **plot registry** to:
- Track which plots project which (north, south) axes
- Map plots → biomes
- Find projections by emoji pair

**Enhancement to existing structure:**

```gdscript
# In QuantumQuestEvaluator
class ProjectionInfo:
    var position: Vector2i
    var north: String
    var south: String
    var biome: BiomeBase
    var plot: BasePlot

var projection_registry: Dictionary = {}  # Vector2i → ProjectionInfo
```

---

## Implementation Details

### 1. Update QuantumQuestEvaluator

**Add bath-mode detection:**

```gdscript
# In QuantumQuestEvaluator.gd

func _read_observable(condition: QuantumCondition) -> Variant:
    """Read observable value from quantum state"""

    # Detect mode
    if _is_bath_mode_enabled():
        return _read_observable_bath_mode(condition)
    else:
        return _read_observable_legacy_mode(condition)

func _is_bath_mode_enabled() -> bool:
    """Check if any biome is using bath mode"""
    # Check if biomes have bath mode enabled
    if biotic_flux_bath and biotic_flux_bath is BiomeBase:
        return biotic_flux_bath.use_bath_mode
    return false
```

**Add bath-mode observable readers:**

```gdscript
func _read_observable_bath_mode(condition: QuantumCondition) -> Variant:
    """Read observable in bath-first mode"""

    var observable = condition.observable

    # Single-qubit observables
    if QuantumObservable.is_single_qubit(observable):
        return _read_single_qubit_bath_mode(condition)

    # Bath-wide observables
    elif QuantumObservable.is_bath_wide(observable):
        return _read_bath_wide_bath_mode(condition)

    # Multi-qubit observables
    elif QuantumObservable.is_multi_qubit(observable):
        return _read_multi_qubit_bath_mode(condition)

    return null

func _read_single_qubit_bath_mode(condition: QuantumCondition) -> Variant:
    """Read single-qubit observable from bath projection"""

    if condition.emoji_pair.size() != 2:
        return null

    # Find biome and projection
    var proj_info = _find_projection(condition.emoji_pair)
    if not proj_info or not proj_info.biome or not proj_info.biome.bath:
        return null

    # Project bath onto this axis
    var north = condition.emoji_pair[0]
    var south = condition.emoji_pair[1]
    var proj = proj_info.biome.bath.project_onto_axis(north, south)

    if not proj.valid:
        return null

    # Extract observable from projection
    match condition.observable:
        QuantumObservable.THETA:
            return proj.theta
        QuantumObservable.PHI:
            return proj.phi
        QuantumObservable.COHERENCE:
            # Coherence = sin(θ) - maximum at equal superposition
            return sin(proj.theta)
        QuantumObservable.RADIUS:
            return proj.radius
        QuantumObservable.PROBABILITY_NORTH:
            # P_north = cos²(θ/2)
            return cos(proj.theta / 2.0) ** 2
        QuantumObservable.PROBABILITY_SOUTH:
            # P_south = sin²(θ/2)
            return sin(proj.theta / 2.0) ** 2

    return null

func _read_bath_wide_bath_mode(condition: QuantumCondition) -> Variant:
    """Read bath-wide observable"""

    var biome = _get_primary_biome()
    if not biome or not biome.bath:
        return null

    match condition.observable:
        QuantumObservable.AMPLITUDE:
            if condition.emoji_target.is_empty():
                return null
            var amp = biome.bath.get_amplitude(condition.emoji_target)
            return amp.abs()  # Return magnitude

        QuantumObservable.PHASE:
            if condition.emoji_target.is_empty():
                return null
            var amp = biome.bath.get_amplitude(condition.emoji_target)
            return amp.arg()  # Return phase angle

        QuantumObservable.ENTROPY:
            return _calculate_shannon_entropy(biome.bath)

        QuantumObservable.PURITY:
            return _calculate_purity(biome.bath)

    return null

func _calculate_shannon_entropy(bath: QuantumBath) -> float:
    """Calculate Shannon entropy of bath probability distribution"""
    var dist = bath.get_probability_distribution()
    var entropy = 0.0

    for emoji in dist:
        var prob = dist[emoji]
        if prob > 1e-10:
            entropy -= prob * log(prob) / log(2.0)

    return entropy

func _calculate_purity(bath: QuantumBath) -> float:
    """Calculate purity Tr(ρ²) of bath state"""
    var dist = bath.get_probability_distribution()
    var purity = 0.0

    for emoji in dist:
        var prob = dist[emoji]
        purity += prob * prob

    return purity
```

### 2. Add Projection Finding

**Helper to find projections by emoji pair:**

```gdscript
func _find_projection(emoji_pair: Array) -> Dictionary:
    """Find projection info for given emoji pair

    Returns: {position, north, south, biome, plot} or {}
    """

    if not plot_registry:
        return {}

    # Search through registered projections
    for position in projection_registry:
        var info = projection_registry[position]
        if info.north == emoji_pair[0] and info.south == emoji_pair[1]:
            return info
        # Also check reverse order
        if info.north == emoji_pair[1] and info.south == emoji_pair[0]:
            return info

    return {}

func _get_primary_biome() -> BiomeBase:
    """Get the primary biome (for bath-wide observables)

    In multi-biome setups, this would need more sophisticated logic.
    For now, return the first biome with bath mode enabled.
    """

    if biotic_flux_bath and biotic_flux_bath is BiomeBase:
        if biotic_flux_bath.use_bath_mode:
            return biotic_flux_bath

    # Could expand to search through multiple biomes
    return null
```

### 3. Enhanced Plot Registry

**Registration during plot creation:**

```gdscript
# Called by QuestManager or GameController when plot is planted

func register_plot_projection(
    position: Vector2i,
    north: String,
    south: String,
    biome: BiomeBase,
    plot: BasePlot
) -> void:
    """Register a new plot projection for quest tracking"""

    projection_registry[position] = {
        "position": position,
        "north": north,
        "south": south,
        "biome": biome,
        "plot": plot
    }

func unregister_plot_projection(position: Vector2i) -> void:
    """Unregister a plot projection (on harvest/removal)"""

    projection_registry.erase(position)
```

**Integration with BasePlot:**

```gdscript
# In BasePlot.gd - when plot is planted

func plant(north: String, south: String):
    # ... existing planting logic

    # Register with quest evaluator if available
    var quest_evaluator = get_node_or_null("/root/QuestManager/Evaluator")
    if quest_evaluator:
        quest_evaluator.register_plot_projection(
            grid_position,
            north,
            south,
            get_biome(),
            self
        )

    # ... rest of planting

func harvest():
    # ... existing harvest logic

    # Unregister from quest evaluator
    var quest_evaluator = get_node_or_null("/root/QuestManager/Evaluator")
    if quest_evaluator:
        quest_evaluator.unregister_plot_projection(grid_position)

    # ... rest of harvest
```

### 4. Add Observable Readers to BiomeBase

**Convenience methods for quest evaluation:**

```gdscript
# In BiomeBase.gd

# =============================================================================
# QUANTUM OBSERVABLE READERS (for Quest System)
# =============================================================================

func get_observable_theta(north: String, south: String) -> float:
    """Get polar angle θ for projection [0, π]"""
    if use_bath_mode and bath:
        var proj = bath.project_onto_axis(north, south)
        return proj.theta if proj.valid else PI/2
    else:
        # Legacy mode fallback
        var qubit = _find_qubit_with_emojis(north, south)
        return qubit.theta if qubit else PI/2

func get_observable_phi(north: String, south: String) -> float:
    """Get azimuthal phase φ for projection [0, 2π]"""
    if use_bath_mode and bath:
        var proj = bath.project_onto_axis(north, south)
        return proj.phi if proj.valid else 0.0
    else:
        var qubit = _find_qubit_with_emojis(north, south)
        return qubit.phi if qubit else 0.0

func get_observable_coherence(north: String, south: String) -> float:
    """Get coherence (superposition strength) [0, 1]"""
    var theta = get_observable_theta(north, south)
    return abs(sin(theta))

func get_observable_amplitude(emoji: String) -> float:
    """Get amplitude |α| of specific emoji [0, 1]"""
    if use_bath_mode and bath:
        return bath.get_amplitude(emoji).abs()
    else:
        # Legacy: search for qubit containing this emoji
        for qubit in quantum_states.values():
            if qubit.north_pole == emoji:
                return cos(qubit.theta / 2.0) * qubit.radius
            elif qubit.south_pole == emoji:
                return sin(qubit.theta / 2.0) * qubit.radius
        return 0.0

func get_observable_phase(emoji: String) -> float:
    """Get phase arg(α) of specific emoji [-π, π]"""
    if use_bath_mode and bath:
        return bath.get_amplitude(emoji).arg()
    else:
        # Legacy mode: approximate from qubit phase
        for qubit in quantum_states.values():
            if qubit.north_pole == emoji:
                return 0.0  # North phase as reference
            elif qubit.south_pole == emoji:
                return qubit.phi  # Relative to north
        return 0.0

func _find_qubit_with_emojis(north: String, south: String) -> DualEmojiQubit:
    """Find qubit matching emoji pair (legacy mode helper)"""
    for qubit in quantum_states.values():
        if (qubit.north_pole == north and qubit.south_pole == south) or \
           (qubit.north_pole == south and qubit.south_pole == north):
            return qubit
    return null
```

---

## Migration Path

### Step 1: Update QuantumQuestEvaluator (This PR)

- ✅ Add bath-mode detection
- ✅ Add bath-mode observable readers
- ✅ Add projection registry
- ✅ Add fallback to legacy mode

### Step 2: Add Observable Readers to BiomeBase (This PR)

- ✅ Add convenience methods for quest system
- ✅ Support both bath and legacy modes

### Step 3: Update Integration Hooks (This PR)

- ✅ Register/unregister projections in BasePlot
- ✅ Connect quest evaluator to biome bath

### Step 4: Test with Mixed Biomes (Next PR)

- Test quest system with legacy biomes (should work unchanged)
- Test quest system with bath-first biomes
- Test quest system with mixture of both

### Step 5: Enable Bath Mode in Biomes (Gradual)

- Convert one biome at a time to `use_bath_mode = true`
- Verify quests still work
- Migrate all biomes over time

---

## Testing Strategy

### Unit Tests

```gdscript
# test_quest_bath_integration.gd

func test_bath_mode_theta_reading():
    # Create bath-first biome
    var biome = BiomeBase.new()
    biome.use_bath_mode = true
    biome.bath = QuantumBath.new()
    biome.bath.initialize_with_emojis(["🌾", "🐺"])
    biome.bath.initialize_uniform()

    # Create projection
    var proj = biome.create_projection(Vector2i(0,0), "🌾", "🐺")

    # Quest evaluator should read theta
    var evaluator = QuantumQuestEvaluator.new()
    evaluator.register_plot_projection(Vector2i(0,0), "🌾", "🐺", biome, null)

    var condition = QuantumCondition.create_theta_condition("🌾", "🐺", PI/2, 0.1)
    var value = evaluator._read_observable(condition)

    assert(value != null, "Should read theta from bath projection")
    assert(abs(value - PI/2) < 0.2, "Uniform state should be near equator")

func test_legacy_mode_fallback():
    # Create legacy biome
    var biome = BiomeBase.new()
    biome.use_bath_mode = false

    var qubit = biome.create_quantum_state(Vector2i(0,0), "🌾", "🐺", PI/4)

    # Quest evaluator should read from qubit
    var evaluator = QuantumQuestEvaluator.new()
    evaluator.biotic_flux_bath = biome

    var condition = QuantumCondition.create_theta_condition("🌾", "🐺", PI/4, 0.1)
    var value = evaluator._read_observable(condition)

    assert(value != null, "Should read theta from legacy qubit")
    assert(abs(value - PI/4) < 0.01, "Should match qubit theta")
```

### Integration Tests

1. Generate quest in legacy biome → verify works
2. Generate quest in bath-first biome → verify works
3. Generate quest spanning multiple biomes → verify reasonable behavior
4. Measure plot in bath biome → verify all projections update → verify quest progress updates

---

## Files to Modify

| File | Changes | Priority |
|------|---------|----------|
| `Core/Quests/QuantumQuestEvaluator.gd` | Add bath-mode support, projection registry | HIGH |
| `Core/Environment/BiomeBase.gd` | Add observable reader methods | HIGH |
| `Core/GameMechanics/BasePlot.gd` | Register/unregister projections | MEDIUM |
| `Tests/test_quest_bath_integration.gd` | New test file for integration | HIGH |
| `llm_outbox/quantum_quest_system_integration.md` | Update with bath-first instructions | MEDIUM |

---

## Summary

The integration requires:

1. **Dual-mode QuantumQuestEvaluator** that detects and handles both legacy and bath-first
2. **Observable readers in BiomeBase** for convenient quest evaluation
3. **Projection registry** to track plot → biome → bath mapping
4. **Backward compatibility** so quests work during gradual migration

**Effort estimate:** 4-6 hours of careful implementation + 2 hours testing

**Risk level:** Low - fallback to legacy mode provides safety net

**Benefit:** Quest system works seamlessly with the superior bath-first architecture! 🌌⚛️
