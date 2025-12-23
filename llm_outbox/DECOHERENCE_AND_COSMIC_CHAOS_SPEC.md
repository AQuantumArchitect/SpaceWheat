# Decoherence Mechanics & Cosmic Chaos Icon - Technical Specification

**Date**: 2025-12-14
**Status**: Design Specification (Not Yet Implemented)
**For**: Implementation after core game design approval

---

## Overview

This document specifies the **decoherence mechanics** and **Cosmic Chaos Icon** needed to implement the quantum-classical gameplay loop.

**Core Concept**: Quantum states naturally degrade over time (decoherence), creating urgency and strategic timing decisions. The Cosmic Chaos Icon represents the Outer Void - entropy, noise, and the inexorable march toward classicality.

---

## 1. Decoherence Mechanics

### What is Decoherence?

The gradual loss of quantum coherence - superposition states collapse toward classical (definite) states.

**Physically**:
```
Pure superposition: |ψ⟩ = (|🌾⟩ + |👥⟩)/√2  (θ = π/2)
                            ↓ decoherence
Degraded state:     |ψ⟩ → |🌾⟩ or |👥⟩      (θ → 0 or θ → π)
```

**In DualEmojiQubit**:
- θ = π/2: Perfect superposition (quantum)
- θ → 0 or π: Collapsed toward pole (classical)
- Decoherence pushes θ toward nearest pole

### Implementation in DualEmojiQubit.gd

```gdscript
# Add decoherence parameters
var coherence_time: float = 100.0  # Time constant for decoherence
var decoherence_rate: float = 0.0   # Current rate (modulated by environment)

func apply_decoherence(delta: float, environment_rate: float = 0.01):
    """Apply environmental decoherence

    Args:
        delta: Time step
        environment_rate: Base decoherence rate from environment
    """
    # Calculate effective rate
    decoherence_rate = environment_rate / coherence_time

    # Partial collapse toward nearest pole
    var collapse_strength = decoherence_rate * delta
    partial_collapse(collapse_strength)

# Existing partial_collapse method (already implemented)
func partial_collapse(strength: float = 0.5) -> void:
    """Partial measurement/decoherence toward classical states"""
    # Move toward nearest pole
    if theta < PI/2:
        theta *= (1.0 - strength)  # Collapse toward north
    else:
        theta = PI - (PI - theta) * (1.0 - strength)  # Collapse toward south
```

### Global Decoherence Application

In the main game loop (e.g., `FarmGrid.gd` or `GameManager.gd`):

```gdscript
var cosmic_chaos_icon: CosmicChaosIcon
var topology_analyzer: TopologyAnalyzer

func _process(delta):
    # Calculate base environmental decoherence rate
    var base_rate = 0.01  # 1% per second baseline

    # Cosmic Chaos Icon increases decoherence
    var chaos_modifier = 1.0 + (cosmic_chaos_icon.get_activation() * 2.0)
    # e.g., full activation = 3x decoherence rate

    # Current topology provides protection
    var topology = topology_analyzer.get_topology_info()
    var protection = topology.pattern.protection_level  # 0 to 10
    var protection_modifier = 1.0 - (protection / 20.0)
    # e.g., protection=10 → 50% reduction in decoherence

    # Final decoherence rate
    var environment_rate = base_rate * chaos_modifier * protection_modifier

    # Apply to all plots
    for plot in wheat_plots:
        if plot.quantum_state:
            plot.quantum_state.apply_decoherence(delta, environment_rate)

    # Update visuals based on coherence
    update_coherence_visuals()
```

### Coherence Metric

Add a coherence query to DualEmojiQubit:

```gdscript
func get_coherence() -> float:
    """Return coherence (0.0 = classical, 1.0 = pure quantum)

    Coherence is maximized at equator (θ = π/2) and zero at poles.
    """
    # Simple measure: distance from poles
    var dist_from_equator = abs(theta - PI/2)
    var max_dist = PI/2

    return 1.0 - (dist_from_equator / max_dist)

func is_decoherent(threshold: float = 0.2) -> bool:
    """Check if state is significantly decoherent"""
    return get_coherence() < threshold
```

---

## 2. Cosmic Chaos Icon (Outer Void)

### Conceptual Role

The **Cosmic Chaos Icon** represents:
- **Entropy**: Universal tendency toward disorder
- **The Void**: Emptiness, absence, nothingness
- **Decoherence**: Quantum → Classical collapse
- **Noise**: Random perturbations in the quantum field

**Gameplay Role**:
- Always present (entropy is universal)
- Activated by "void" items or absence of items
- Counteracted by order (Biotic Flux), topology protection
- Creates urgency: harvest before decoherence destroys value

### File: Core/Icons/CosmicChaosIcon.gd

```gdscript
class_name CosmicChaosIcon
extends IconHamiltonian

## Cosmic Chaos Icon - Entropy, Void, Decoherence
## Represents the inexorable march toward classical collapse

func _init():
    icon_name = "Cosmic Chaos"
    icon_emoji = "🌌"

    # Evolution bias: rapid phase noise, strong damping
    evolution_bias = Vector3(
        0.0,    # No theta drift (doesn't favor 🌾 or 👥)
        0.8,    # High phi noise (random phase kicks)
        0.05    # Moderate damping (energy loss)
    )

    spatial_extent = 1000.0  # Affects entire farm (entropy is everywhere)


func _initialize_couplings():
    # Chaos couples to META nodes (self-reference, paradox)
    node_couplings["meta"] = 1.0
    node_couplings["identity"] = 0.8
    node_couplings["meaning"] = 0.7

    # Suppresses stability nodes
    node_couplings["seed"] = -0.5
    node_couplings["solar"] = -0.4
    node_couplings["water"] = -0.4

    print("🌌 Cosmic Chaos Icon initialized with %d node couplings" % node_couplings.size())


## Calculate activation based on ABSENCE or void items
func calculate_activation_from_void(void_count: int, total_items: int) -> void:
    """Activation increases with emptiness or void items

    void_count: Number of 'void' items explicitly placed
    total_items: Total items on farm
    """
    # Base activation from void items
    var void_strength = float(void_count) / max(1.0, total_items * 0.1)

    # Also activates when farm is EMPTY (nothingness)
    var emptiness_strength = 1.0 - (float(total_items) / 100.0)

    # Chaos is always at least weakly active (entropy never stops)
    var total_strength = clamp(max(void_strength, emptiness_strength), 0.2, 1.0)

    set_activation(total_strength)


## Apply decoherence effect (called by main game loop)
func get_decoherence_modifier() -> float:
    """Return decoherence rate modifier based on activation

    Returns: 1.0 to 3.0 multiplier
    """
    return 1.0 + (active_strength * 2.0)


## Visual effects for Cosmic Chaos
func get_visual_effect() -> Dictionary:
    return {
        "type": "chaos_void",
        "color": Color(0.1, 0.0, 0.2, 0.8),  # Dark purple/black
        "particle_type": "static",  # Visual noise
        "flow_pattern": "dissolving",  # Things fade/break apart
        "sound": "void_whisper"  # Eerie ambient
    }
```

### Activation Mechanics

In game manager:

```gdscript
func update_icon_activations():
    # Biotic Flux: activated by wheat
    var wheat_count = count_items("wheat")
    biotic_flux_icon.calculate_activation_from_wheat(wheat_count, 25)

    # Chaos: activated by tomatoes
    var tomato_count = count_items("tomato")
    chaos_icon.calculate_activation_from_tomatoes(tomato_count, 25)

    # Imperium: activated by market goods
    var market_count = count_items("market_good")
    imperium_icon.calculate_activation_from_market(market_count, 25)

    # Cosmic Chaos: activated by void items OR emptiness
    var void_count = count_items("void_artifact")
    var total_items = wheat_count + tomato_count + market_count
    cosmic_chaos_icon.calculate_activation_from_void(void_count, total_items)
```

**Design Note**: Cosmic Chaos is ALWAYS active (minimum 20%) because entropy never stops. Players can increase it by placing "void artifacts" or having an empty farm.

---

## 3. Visual Feedback for Decoherence

### Plot-Level Visuals

```gdscript
# In WheatPlot.gd or visual effects manager
func update_coherence_visual(plot: WheatPlot):
    var coherence = plot.quantum_state.get_coherence()

    # Glow intensity fades with decoherence
    var glow_intensity = coherence * 1.5
    plot.glow_material.set_param("intensity", glow_intensity)

    # Color desaturates (→ gray)
    var base_color = get_quantum_state_color(plot)
    var desat_color = base_color.lerp(Color.GRAY, 1.0 - coherence)
    plot.glow_material.set_param("color", desat_color)

    # Particle flow slows
    var flow_speed = coherence * 2.0
    plot.particle_system.speed_scale = flow_speed

    # Visual noise increases
    var noise_amount = (1.0 - coherence) * 0.5
    plot.noise_shader.set_param("noise", noise_amount)
```

### Farm-Wide Visuals

```gdscript
func update_farm_visual_effects():
    # Cosmic Chaos visual overlay
    var chaos_strength = cosmic_chaos_icon.get_activation()

    # Dark tendrils from edges
    void_tendril_particles.amount = chaos_strength * 100
    void_tendril_particles.emitting = true

    # Screen desaturation
    screen_shader.set_param("desaturation", chaos_strength * 0.3)

    # Static/noise overlay
    static_overlay.modulate.a = chaos_strength * 0.2

    # Eerie ambient sound
    void_ambience.volume_db = -30 + (chaos_strength * 20)  # -30 to -10 dB
```

---

## 4. Production Calculation with Local Topology

### Local Network Definition

```gdscript
func get_local_network(center_plot: WheatPlot, radius: int = 2) -> Array:
    """Get plots within entanglement distance

    Args:
        center_plot: The plot being harvested
        radius: Number of entanglement hops to include

    Returns:
        Array of WheatPlot that form the local network
    """
    var local = [center_plot]
    var visited = {center_plot: true}
    var current_layer = [center_plot]

    for hop in range(radius):
        var next_layer = []
        for plot in current_layer:
            if not plot.quantum_state:
                continue

            # Get entangled partners
            for partner_qubit in plot.quantum_state.entangled_partners:
                var partner_plot = find_plot_by_qubit(partner_qubit)
                if partner_plot and not visited.has(partner_plot):
                    local.append(partner_plot)
                    next_layer.append(partner_plot)
                    visited[partner_plot] = true

        current_layer = next_layer
        if current_layer.is_empty():
            break

    return local
```

### Harvest with Local Topology Bonus

```gdscript
func harvest_plot(plot: WheatPlot) -> Dictionary:
    """Harvest a plot with local topology bonus

    Returns:
        Dictionary with yield, bonus, pattern info, etc.
    """
    # 1. Get local entanglement network
    var local_plots = get_local_network(plot, radius=2)

    # 2. Analyze local topology
    var local_topology = topology_analyzer.analyze_entanglement_network(local_plots)

    # 3. Check coherence (decoherence reduces yield)
    var coherence = plot.quantum_state.get_coherence()
    var coherence_penalty = coherence  # Full yield if coherent, reduced if decoherent

    # 4. Measure quantum state (collapse superposition)
    var measurement_result = plot.quantum_state.measure()

    # 5. Calculate base yield from growth
    var growth_factor = plot.growth_progress  # 0.0 to 1.0
    var base_yield = 10.0 * growth_factor

    # 6. Quantum state modifier
    var state_modifier = 1.5 if measurement_result == "👥" else 1.0

    # 7. Local topology bonus
    var topology_bonus = local_topology.bonus_multiplier  # 1.0x to 3.0x

    # 8. Final yield calculation
    var final_yield = base_yield * state_modifier * topology_bonus * coherence_penalty

    # 9. Break entanglements (measurement destroys quantum state)
    # Note: Partners remain entangled with each other
    plot.quantum_state.break_all_entanglements()

    # 10. Mark network as changed for re-analysis
    entanglement_network_changed = true

    return {
        "yield": final_yield,
        "base": base_yield,
        "state": measurement_result,
        "state_bonus": state_modifier,
        "topology_bonus": topology_bonus,
        "coherence": coherence,
        "pattern_name": local_topology.pattern.name,
        "jones": local_topology.features.jones_approximation
    }
```

### UI Display

```gdscript
# When hovering over plot (before harvest)
func show_harvest_preview(plot: WheatPlot):
    var local_topology = topology_analyzer.analyze_entanglement_network(
        get_local_network(plot, 2)
    )

    var coherence = plot.quantum_state.get_coherence()
    var north_prob = plot.quantum_state.get_north_probability()
    var south_prob = plot.quantum_state.get_south_probability()

    # Expected value calculation
    var expected_yield = (
        north_prob * 10.0 * 1.0 * local_topology.bonus_multiplier +
        south_prob * 10.0 * 1.5 * local_topology.bonus_multiplier
    ) * coherence

    # Display
    preview_ui.set_text("""
        Local Topology: %s
        Jones: %.2f
        Bonus: %.1fx

        Coherence: %.0f%%

        Probabilities:
          🌾 Natural: %.0f%% → %.1f wheat
          👥 Labor:   %.0f%% → %.1f wheat

        Expected Value: %.1f wheat
    """ % [
        local_topology.pattern.name,
        local_topology.features.jones_approximation,
        local_topology.bonus_multiplier,
        coherence * 100,
        north_prob * 100, north_prob * 10 * 1.0 * local_topology.bonus_multiplier * coherence,
        south_prob * 100, south_prob * 10 * 1.5 * local_topology.bonus_multiplier * coherence,
        expected_yield
    ])
```

---

## 5. Tuning Parameters

### Decoherence Rates

```gdscript
# Global parameters (adjust for difficulty)
const BASE_DECOHERENCE_RATE = 0.01      # 1% per second
const CHAOS_DECOHERENCE_MULTIPLIER = 2.0 # Full chaos = 3x rate
const PROTECTION_EFFECTIVENESS = 0.5     # Protection=10 → 50% reduction
const COHERENCE_TIME_BASE = 100.0        # Seconds for e^-1 decay
```

### Protection Scaling

Current formula in TopologyAnalyzer:
```gdscript
protection = (genus × 2.0) + (crossings × 1.5) + (cycles × 0.5) - borromean_penalty
```

This gives protection 0-10, which translates to:
- Protection 0: No decoherence reduction
- Protection 5: 25% decoherence reduction
- Protection 10: 50% decoherence reduction

**Design decision**: Protection can't fully eliminate decoherence (entropy always wins), only slow it.

---

## 6. Strategic Implications

### The Decoherence Dilemma

**Wait for better topology**:
- ✅ Higher Jones polynomial (better bonus)
- ✅ More complex knots (up to 3.0x)
- ❌ More decoherence (reduced yield)
- ❌ Risk of total collapse

**Harvest early**:
- ✅ High coherence (full yield)
- ✅ Preserve quantum state
- ❌ Low topology bonus (simple patterns)
- ❌ Less growth progress

**Optimal strategy**: Find the **peak moment** where `topology_bonus × coherence × growth` is maximized.

### Counter-Strategies

**Resist decoherence**:
1. Build high-protection topologies (genus, crossings)
2. Activate Biotic Flux (order counters chaos)
3. Reduce Cosmic Chaos (remove void items)
4. Harvest in batches (preserve network)

**Embrace decoherence**:
1. Let Cosmic Chaos run wild
2. Harvest quickly and often
3. Focus on throughput, not optimization
4. Simpler topologies (faster to rebuild)

---

## 7. Implementation Checklist

### DualEmojiQubit.gd
- [ ] Add `coherence_time` parameter
- [ ] Add `decoherence_rate` tracking
- [ ] Add `apply_decoherence(delta, rate)` method
- [ ] Add `get_coherence()` query
- [ ] Add `is_decoherent(threshold)` check

### CosmicChaosIcon.gd
- [ ] Create file extending IconHamiltonian
- [ ] Implement void/emptiness activation
- [ ] Set evolution bias (high phi noise, damping)
- [ ] Set node couplings (meta, identity, meaning)
- [ ] Add `get_decoherence_modifier()` method

### Game Manager / FarmGrid
- [ ] Add CosmicChaosIcon instance
- [ ] Update `_process()` to apply decoherence
- [ ] Implement `get_local_network(plot, radius)`
- [ ] Update `harvest_plot()` with local topology + coherence
- [ ] Add entanglement network change tracking

### Visual Effects
- [ ] Coherence-based glow intensity
- [ ] Color desaturation on decoherence
- [ ] Particle flow speed scaling
- [ ] Visual noise/static shader
- [ ] Cosmic Chaos tendrils/overlay
- [ ] Screen desaturation effect

### UI
- [ ] Harvest preview tooltip
- [ ] Coherence meter/indicator
- [ ] Expected value calculation display
- [ ] Local topology info panel
- [ ] Decoherence warning (red flash when low)

---

## Summary

This specification adds:

✅ **Decoherence mechanics** - Quantum states decay over time
✅ **Cosmic Chaos Icon** - Entropy as a gameplay element
✅ **Local topology bonuses** - Granular spatial optimization
✅ **Coherence penalty** - Decoherence reduces yield
✅ **Strategic timing** - Find optimal harvest moment
✅ **Visual feedback** - See decoherence happening

The result: **Quantum farming with urgency** - you can't cultivate forever, entropy is always coming. The game becomes about finding the right balance between waiting for better topology and harvesting before decoherence destroys value.

The quantum-classical divide is now a **time-based strategic choice**, not just a binary state. 🌾⚛️🌌
