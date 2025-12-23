# Backend Mechanics Complete - Decoherence, Cosmic Chaos, Local Topology

**Date**: 2025-12-14
**Status**: ✅ Implementation Complete & Tested
**Next Step**: UI/Frontend Integration (other bot)

---

## Summary

Successfully implemented all three critical backend mechanics for the quantum-classical divide gameplay:

1. ✅ **Decoherence Mechanics** - Quantum states decay over time
2. ✅ **Cosmic Chaos Icon** - Entropy/void that drives decoherence
3. ✅ **Local Topology Bonuses** - Jones polynomial-based yield multipliers

All systems tested and verified working together.

---

## 1. Decoherence Mechanics

### Implementation: DualEmojiQubit.gd

**New Properties**:
```gdscript
var coherence_time: float = 100.0  # Time constant (seconds)
var decoherence_rate: float = 0.0   # Current rate
```

**New Methods**:
```gdscript
func apply_decoherence(delta: float, environment_rate: float = 0.01) -> void
    # Gradually collapses quantum state toward classical (nearest pole)
    # Call this every frame with environment_rate from Cosmic Chaos Icon

func get_coherence() -> float
    # Returns 0.0 (classical/decoherent) to 1.0 (pure quantum/superposition)
    # Maximized at θ=π/2 (equator), zero at poles

func is_decoherent(threshold: float = 0.2) -> bool
    # Check if coherence below threshold

func set_coherence_time(time: float) -> void
    # Set decay time constant (higher = slower decoherence)
```

**How It Works**:
- Every frame, quantum states drift toward nearest pole (🌾 or 👥)
- Superposition (θ=π/2) gradually becomes definite state (θ→0 or θ→π)
- Creates urgency: harvest before coherence lost
- Coherence acts as yield penalty: `yield *= coherence`

### Test Results:
```
Initial: θ=1.571 (π/2), coherence=1.000
After 10 sec decoherence: θ=1.720, coherence=0.905
✓ PASS - Decoherence working!
```

---

## 2. Cosmic Chaos Icon (🌌)

### Implementation: Core/Icons/CosmicChaosIcon.gd

**New Icon File** extending IconHamiltonian.

**Key Features**:
```gdscript
icon_name = "Cosmic Chaos"
icon_emoji = "🌌"

# Evolution bias: random phase noise + damping
evolution_bias = Vector3(0.0, 0.8, 0.05)
    # theta: no drift (doesn't favor 🌾 or 👥)
    # phi: high noise (random phase kicks)
    # damping: energy dissipation
```

**Activation**:
```gdscript
func calculate_activation_from_void(void_count: int, total_items: int)
    # Always active (min 20% - entropy never stops)
    # Increases with emptiness or void items
    # Range: 0.2 to 1.0
```

**Decoherence Modifier**:
```gdscript
func get_decoherence_modifier() -> float
    # Returns 1.0x to 3.0x multiplier
    # Full activation = 3x decoherence rate
```

**Visual Effect Parameters** (for UI bot):
```gdscript
func get_visual_effect() -> Dictionary:
    return {
        "type": "chaos_void",
        "color": Color(0.1, 0.0, 0.2, 0.8),  # Dark purple/black
        "particle_type": "static",  # Visual noise
        "flow_pattern": "dissolving",
        "sound": "void_whisper",
        "tendril_count": int(active_strength * 20),
        "screen_desaturation": active_strength * 0.3
    }
```

**Node Couplings**:
- Enhances: meta, identity, meaning, underground
- Suppresses: seed, solar, water, ripening

### Test Results:
```
Empty farm: activation=1.00, decoherence modifier=3.00x
With items: activation=0.90, decoherence modifier=2.80x
✓ PASS - Cosmic Chaos Icon working!
```

---

## 3. Local Topology Bonuses

### Implementation: FarmGrid.gd

**New Member**:
```gdscript
var topology_analyzer: TopologyAnalyzer  # Initialized in _ready()
```

**New Methods**:

#### get_local_network(center_plot, radius=2)
```gdscript
# Finds all plots within 'radius' entanglement hops
# Returns Array of WheatPlot
# Uses flood-fill through entanglement network
```

#### harvest_with_topology(position, local_radius=2)
```gdscript
# NEW harvest method with full quantum-classical mechanics

Returns:
{
    "success": bool,
    "yield": float,                 # Final yield
    "base_yield": float,            # 10.0 × growth_progress
    "state": String,                # 🌾 or 👥 (measurement result)
    "state_bonus": float,           # 1.0 (🌾) or 1.5 (👥)
    "topology_bonus": float,        # 1.0x to 3.0x from Jones polynomial
    "coherence": float,             # 0.0 to 1.0
    "coherence_penalty": float,     # Same as coherence
    "pattern_name": String,         # e.g. "Intricate Planar 3-Link"
    "jones": float,                 # Jones polynomial value
    "protection": int,              # 0 to 10
    "glow_color": Color             # For visual effects
}
```

**Yield Formula**:
```gdscript
final_yield = base_yield × state_bonus × topology_bonus × coherence

where:
  base_yield = 10.0 × growth_progress
  state_bonus = 1.5 if 👥 else 1.0
  topology_bonus = 1.0x to 3.0x (parametric from Jones polynomial)
  coherence = 0.0 to 1.0 (decoherence penalty)
```

**Example**:
```
Base yield: 10.0 wheat
State: 👥 (1.5x)
Topology: Intricate Planar 3-Link (1.58x, Jones=4.415)
Coherence: 1.0 (perfect)
→ Final yield: 10 × 1.5 × 1.58 × 1.0 = 23.7 wheat

After decoherence (coherence=0.905):
→ Final yield: 10 × 1.5 × 1.58 × 0.905 = 21.5 wheat (9% loss)
```

### Test Results:
```
Triangle topology:
  Pattern: Intricate Planar 3-Link
  Jones: 4.415
  Topology bonus: 1.58x
  Harvest (high coherence): 15.82 wheat
  Harvest (after decoherence): 14.31 wheat (10% reduction)
✓ PASS - Local topology + coherence working!

Complex pattern:
  Pattern: Exotic Planar 14-Link
  Jones: 66.053
  Protection: 2/10
  Topology bonus: 3.00x (capped!)
```

---

## 4. Integration Points for UI Bot

### Decoherence Application (in Game Loop)

```gdscript
# In FarmView._process(delta) or similar

# Get decoherence rate from Cosmic Chaos Icon
var base_decoherence_rate = 0.01  # 1% per second baseline
var chaos_modifier = cosmic_chaos_icon.get_decoherence_modifier()  # 1.0x to 3.0x
var effective_rate = base_decoherence_rate * chaos_modifier

# Apply to all wheat plots
for plot in farm_grid.plots.values():
    if plot.quantum_state:
        plot.quantum_state.apply_decoherence(delta, effective_rate)
```

### Cosmic Chaos Icon Activation

```gdscript
# In FarmView or GameManager

# Update Icon activation (same pattern as existing Icons)
var void_count = 0  # Count void items if we add them
var total_items = wheat_count + tomato_count  # Total plots/items

cosmic_chaos_icon.calculate_activation_from_void(void_count, total_items)

# Add to conspiracy network (same as other Icons)
conspiracy_network.add_icon(cosmic_chaos_icon)
```

### Using New Harvest Method

```gdscript
# Replace old harvest call
# OLD: farm_grid.harvest_wheat(position)

# NEW:
var yield_data = farm_grid.harvest_with_topology(position, local_radius=2)

if yield_data.success:
    print("Harvested %.1f wheat" % yield_data.yield)
    print("  State: %s (%.1fx)" % [yield_data.state, yield_data.state_bonus])
    print("  Topology: %s (%.2fx)" % [yield_data.pattern_name, yield_data.topology_bonus])
    print("  Coherence: %.0f%%" % (yield_data.coherence * 100))
    print("  Jones: %.2f" % yield_data.jones)

    # Use glow_color for visual effects
    # Use protection for UI indicators
```

### Visual Feedback Hooks

**Coherence Visualization**:
```gdscript
# For each plot, show coherence as glow intensity
func update_plot_visual(plot):
    var coherence = plot.quantum_state.get_coherence()

    # Glow intensity fades with decoherence
    plot.glow_shader.set_param("intensity", coherence * 1.5)

    # Color desaturates (→ gray)
    var base_color = get_quantum_color(plot)
    var desat_color = base_color.lerp(Color.GRAY, 1.0 - coherence)
    plot.material.set_param("color", desat_color)

    # Particle flow slows
    plot.particles.speed_scale = coherence * 2.0

    # Visual noise increases
    plot.noise_shader.set_param("noise", (1.0 - coherence) * 0.5)
```

**Cosmic Chaos Visuals**:
```gdscript
# Use visual effect parameters from Icon
var chaos_fx = cosmic_chaos_icon.get_visual_effect()

# Dark tendrils from edges
void_tendrils.amount = chaos_fx.tendril_count
void_tendrils.color = chaos_fx.color

# Screen desaturation overlay
screen_shader.set_param("desaturation", chaos_fx.screen_desaturation)

# Static/noise particles
static_particles.emitting = true
static_particles.amount = chaos_fx.tendril_count * 5
```

**Harvest Preview Tooltip**:
```gdscript
# When hovering over mature plot
func show_harvest_preview(plot_position):
    var plot = farm_grid.get_plot(plot_position)
    var local_network = farm_grid.get_local_network(plot, 2)
    var topology = topology_analyzer.analyze_entanglement_network(local_network)

    var coherence = plot.quantum_state.get_coherence()
    var north_prob = plot.quantum_state.get_north_probability()
    var south_prob = plot.quantum_state.get_south_probability()

    # Expected value
    var base = 10.0 * plot.growth_progress
    var expected = (
        north_prob * base * 1.0 * topology.bonus_multiplier +
        south_prob * base * 1.5 * topology.bonus_multiplier
    ) * coherence

    tooltip.set_text("""
        Local Topology: %s
        Jones: %.2f | Bonus: %.1fx

        Coherence: %.0f%%
        %s  Low coherence = reduced yield!

        Probabilities:
          🌾 Natural: %.0f%% → %.1f wheat
          👥 Labor:   %.0f%% → %.1f wheat

        Expected Yield: %.1f wheat
    """ % [
        topology.pattern.name,
        topology.features.jones_approximation,
        topology.bonus_multiplier,
        coherence * 100,
        "⚠️" if coherence < 0.5 else "",
        north_prob * 100, north_prob * base * 1.0 * topology.bonus_multiplier * coherence,
        south_prob * 100, south_prob * base * 1.5 * topology.bonus_multiplier * coherence,
        expected
    ])
```

---

## 5. Gameplay Flow with New Mechanics

### The Full Loop

```
1. QUANTUM CULTIVATION (Pre-Measurement)
   ↓
   Plant wheat → Create DualEmojiQubit in superposition
   ↓
   Create entanglements → Build topology
   ↓
   Cosmic Chaos Icon activates → Decoherence begins
   ↓
   Watch coherence decay → Urgency builds
   ↓
   Topology evolves → Jones polynomial increases
   ↓
   STRATEGIC DECISION: When to harvest?

2. MEASUREMENT (The Quantum-Classical Divide)
   ↓
   Player clicks harvest
   ↓
   Analyze local topology → Calculate Jones polynomial
   ↓
   Check coherence → Apply penalty if low
   ↓
   Measure quantum state → Collapse to 🌾 or 👥
   ↓
   Calculate yield: base × state × topology × coherence
   ↓
   Break entanglements → Network degrades

3. CLASSICAL ECONOMY
   ↓
   Receive wheat (classical resource)
   ↓
   Spend on items → Activate Icons
   ↓
   Loop back to step 1
```

### Strategic Depth

**Early Harvest**:
- ✅ High coherence (no penalty)
- ✅ Preserve network
- ❌ Low topology bonus (simple patterns)
- ❌ Low growth progress

**Late Harvest**:
- ✅ High topology bonus (complex knots)
- ✅ Full growth
- ❌ Low coherence (decoherence penalty)
- ❌ Risk total collapse

**Optimal Play**: Find the peak moment where `topology_bonus × coherence × growth` is maximized.

---

## 6. What's NOT Implemented (Frontend Needed)

### Visual Systems
- [ ] Glow intensity based on coherence
- [ ] Color desaturation on decoherence
- [ ] Particle flow speed scaling
- [ ] Visual noise/static shader
- [ ] Cosmic Chaos tendrils/overlay
- [ ] Screen desaturation effect
- [ ] Measurement flash animation

### UI Displays
- [ ] Coherence meter/indicator
- [ ] Harvest preview tooltip
- [ ] Expected value calculation display
- [ ] Local topology info panel
- [ ] Decoherence warning (red flash)
- [ ] Cosmic Chaos Icon in status bar

### Integration
- [ ] Call `apply_decoherence()` every frame
- [ ] Activate Cosmic Chaos Icon
- [ ] Switch to `harvest_with_topology()` method
- [ ] Display yield_data in UI

---

## 7. Files Modified/Created

### Created Files
```
Core/Icons/CosmicChaosIcon.gd           # New Icon for entropy/void
llm_outbox/CORE_GAME_DESIGN_VISION.md   # Design philosophy
llm_outbox/DECOHERENCE_AND_COSMIC_CHAOS_SPEC.md  # Technical spec
llm_outbox/PARAMETRIC_TOPOLOGY_SYSTEM.md  # Knot detection redesign
llm_outbox/BACKEND_MECHANICS_COMPLETE.md  # This file
```

### Modified Files
```
Core/QuantumSubstrate/DualEmojiQubit.gd
  + coherence_time, decoherence_rate properties
  + apply_decoherence(), get_coherence(), is_decoherent() methods

Core/QuantumSubstrate/TopologyAnalyzer.gd
  ~ Redesigned to be parametric (Jones polynomial driven)
  + Improved Jones approximation
  + Linking number calculation
  ~ Pattern detection now generates names from properties

Core/GameMechanics/FarmGrid.gd
  + topology_analyzer member variable
  + get_local_network() method
  + harvest_with_topology() method (NEW harvest!)
  + _find_plot_by_qubit() helper
```

---

## 8. Testing

All three mechanics tested together:

```bash
godot --headless --path . --script test_backend_mechanics.gd
```

**Results**:
- ✅ Decoherence: Coherence degrades from 1.0 → 0.905 over 10 sec
- ✅ Cosmic Chaos: Activation working, decoherence modifier 1.0x-3.0x
- ✅ Local Topology: Triangle = 1.58x, Complex = 3.0x (capped)
- ✅ Coherence Penalty: Yield reduced by 10% after decoherence
- ✅ Protection: Higher protection = slower decoherence

---

## 9. Summary: What You Get

### Backend Systems (Complete ✅)

**Decoherence**:
- Quantum states decay naturally
- Coherence metric (0.0 to 1.0)
- Tunable decay rate
- Works with any quantum state

**Cosmic Chaos Icon**:
- Always active (entropy never stops)
- 3x decoherence amplification at full power
- Modulates conspiracy network
- Visual effect parameters ready

**Local Topology Bonuses**:
- Parametric from Jones polynomial
- 1.0x to 3.0x yield multipliers
- Local network analysis (radius-based)
- Full yield calculation with all factors

### Gameplay (Complete ✅)

**The Quantum-Classical Divide**:
- Pre-measurement: Cultivate quantum potential
- Measurement: Strategic timing decision
- Post-measurement: Classical resources

**Urgency**: Can't farm forever (decoherence destroys value)
**Strategy**: Balance complexity vs. decoherence risk
**Depth**: Multiple optimization axes (growth, topology, coherence)

### What Remains (Frontend)

**Visuals**: Make the quantum realm *visible*
**UI**: Show coherence, topology, expected values
**Integration**: Wire up decoherence loop and new harvest

---

## 10. Next Steps for UI Bot

1. **Add Cosmic Chaos Icon to status bar** (🌾 42% 🍅 8% 🏰 0% **🌌 20%**)

2. **Apply decoherence every frame**:
   ```gdscript
   func _process(delta):
       var rate = 0.01 * cosmic_chaos_icon.get_decoherence_modifier()
       for plot in plots:
           plot.quantum_state.apply_decoherence(delta, rate)
   ```

3. **Switch to new harvest method**:
   ```gdscript
   # Replace: farm_grid.harvest_wheat(position)
   # With: farm_grid.harvest_with_topology(position)
   ```

4. **Add visual feedback**:
   - Glow fades with coherence
   - Colors desaturate
   - Particles slow down
   - Cosmic Chaos overlay

5. **Add harvest preview tooltip** (show expected value before harvest)

---

## Final Notes

**The quantum farming game now has URGENCY.**

Players can't cultivate forever - entropy is always coming. The Cosmic Chaos Icon brings the Outer Void into the game, creating pressure to harvest before value decays.

But hasty harvesting loses the topology bonuses. The sweet spot is finding the moment when complexity peaks before decoherence destroys coherence.

**This is the quantum-classical divide made mechanical.**

Potential → Timing → Actuality.

The backend is ready. Time to make it *visible*. 🌾⚛️🌌
