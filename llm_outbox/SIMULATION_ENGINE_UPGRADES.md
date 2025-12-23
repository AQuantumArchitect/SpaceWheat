# Simulation Engine Upgrades - For UI/Game Development Bot

**Date**: 2025-12-14
**Author**: Simulation Engine Bot
**Status**: Complete and Tested
**Target Audience**: UI/Game Development Team

---

## Overview

The simulation engine has been **upgraded** with three major systems that extend (not replace) the existing QAGIS conspiracy network. All changes are backward compatible - the network works exactly as before, with new capabilities layered on top.

### What's New

1. **Icon Hamiltonian System** - Modulates conspiracy network based on gameplay
2. **Berry Phase Tracking** - Geometric phase accumulation on Bloch sphere
3. **DualEmojiQubit** - Semantic quantum states for wheat plots

---

## 1. Icon Hamiltonian System

### What Are Icons?

Icons are **continuous evolution modifiers** that influence the 12-node conspiracy network. Think of them as "force fields" that bias how nodes evolve.

### The Three Icons

#### 🌾 Biotic Flux Icon (Wheat/Growth)
```gdscript
var biotic_icon = BioticFluxIcon.new()
biotic_icon.set_activation(0.8)  # 80% strength
network.add_icon(biotic_icon)
```

**Effects**:
- Enhances: seed, solar, water nodes (promotes growth)
- Suppresses: meta, identity nodes (reduces chaos)
- Creates more predictable, orderly evolution

**When to activate**: Based on number of wheat plots planted

#### 🍅 Chaos Icon (Tomato/Transformation)
```gdscript
var chaos_icon = ChaosIcon.new()
chaos_icon.set_activation(0.6)  # 60% strength
network.add_icon(chaos_icon)
```

**Effects**:
- Enhances: meta, identity, underground nodes (amplifies chaos)
- Suppresses: seed, solar nodes (disrupts order)
- Makes conspiracies more likely to activate

**When to activate**: Based on number of active conspiracies

#### 🏰 Imperium Icon (Authority/Quotas)
```gdscript
var imperium_icon = ImperiumIcon.new()
imperium_icon.set_activation(urgency)  # 0.0 to 1.0
network.add_icon(imperium_icon)
```

**Effects**:
- Enhances: market, ripening nodes (economic pressure)
- Suppresses: meaning, identity nodes (reduces freedom)
- Creates time pressure and urgency

**When to activate**: Based on quota deadline proximity

### How to Use Icons

**Step 1: Create Icons (do this once at startup)**
```gdscript
# In your main game setup
var biotic_icon = BioticFluxIcon.new()
var chaos_icon = ChaosIcon.new()
var imperium_icon = ImperiumIcon.new()

network.add_icon(biotic_icon)
network.add_icon(chaos_icon)
network.add_icon(imperium_icon)
```

**Step 2: Update Icon Activations (do this every frame or when state changes)**
```gdscript
# Update based on game state
func _process(delta):
    # Biotic Icon grows stronger with more wheat
    biotic_icon.calculate_activation_from_wheat(wheat_plot_count, 25)

    # Chaos Icon grows with conspiracies
    chaos_icon.calculate_activation_from_conspiracies(active_conspiracy_count, 12)

    # Imperium Icon grows as deadline approaches
    imperium_icon.calculate_activation_from_deadline(time_remaining, total_time)
```

**That's it!** The network automatically applies Icon modulation during evolution.

### Icon Coupling Reference

Quick reference for which nodes each Icon affects:

```
BIOTIC FLUX 🌾
  Strong: seed(0.8), solar(0.7), water(0.6)
  Weak:   genetic(0.4), ripening(0.3), meaning(0.2)
  Negative: meta(-0.3), identity(-0.2)

CHAOS 🍅
  Strong: meta(1.0), identity(0.9), underground(0.8), observer(0.7)
  Medium: sauce(0.6), ripening(0.5)
  Negative: seed(-0.4), solar(-0.3)

IMPERIUM 🏰
  Strong: market(0.9), ripening(0.7), sauce(0.6)
  Medium: observer(0.5), genetic(0.4)
  Negative: meaning(-0.3), identity(-0.5)
```

---

## 2. Berry Phase Tracking

### What Is Berry Phase?

Berry phase is the **geometric phase** accumulated when a quantum state follows a closed path on the Bloch sphere. It's a real quantum mechanical phenomenon that we can use for gameplay!

### Gameplay Use Case

**Problem**: Replanting the same plot over and over gets boring
**Solution**: Berry phase gives efficiency bonuses for repeated cycles

```gdscript
# Enable Berry phase for a tomato node (or wheat plot)
var node = network.get_tomato_node("seed")
node.enable_berry_phase_tracking()

# After evolution through cycles...
var efficiency_bonus = 1.0 + node.get_berry_phase() * 0.05
# 0.05 = 5% bonus per unit of accumulated phase

# Apply to growth rate
wheat_growth_rate *= efficiency_bonus
```

### How to Use Berry Phase

**For Tomato Nodes** (conspiracy network):
```gdscript
# Enable on specific nodes that should accumulate memory
var seed_node = network.get_tomato_node("seed")
seed_node.enable_berry_phase_tracking()

# Read accumulated phase
var phase = seed_node.get_berry_phase()
print("Seed has accumulated phase: ", phase)

# Reset after completing a major cycle
seed_node.reset_berry_phase()
```

**For Wheat Plots** (using DualEmojiQubit - see section 3):
```gdscript
var wheat_qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
wheat_qubit.enable_berry_phase()

# Evolve the qubit
wheat_qubit.evolve(delta, evolution_rate)

# Get phase for efficiency calculation
var bonus = 1.0 + wheat_qubit.get_berry_phase() * 0.1
```

### Visual Feedback Ideas

- **Spiral glow** around plots/nodes with high Berry phase
- **Color shift** from green → golden as phase accumulates
- **Particle spiral** showing geometric memory
- **Tooltip** showing "Cycle Memory: +15% efficiency"

---

## 3. DualEmojiQubit - Semantic Quantum States

### What Is It?

`DualEmojiQubit` is a quantum state that encodes **meaning** through position on the Bloch sphere between two emoji poles.

### The Core Concept

```
Bloch Sphere Position → Semantic Meaning

θ = 0 (north):      🌾 Pure natural growth
θ = π/4:            🌾🌾👥 Mostly natural
θ = π/2:            🌾👥 Perfect superposition
θ = 3π/4:           👥👥🌾 Mostly labor
θ = π (south):      👥 Pure labor-intensive
```

### Example: Wheat as Dual-Emoji Qubit

```gdscript
# Create wheat with 🌾/👥 (Natural/Labor) quantum state
var wheat_state = DualEmojiQubit.new("🌾", "👥", PI/2)

# Get semantic representation
print(wheat_state.get_semantic_state())  # "🌾👥" (superposition)

# Get probability amplitudes
var natural_prob = wheat_state.get_north_probability()  # 0.5
var labor_prob = wheat_state.get_south_probability()    # 0.5

# Growth depends on quantum state
var natural_component = wheat_state.get_north_amplitude()  # cos(θ/2)
var labor_component = wheat_state.get_south_amplitude()    # sin(θ/2)

var growth_rate = natural_component * 0.01   # Slow natural growth
growth_rate += labor_component * 0.03        # Fast labor growth
```

### Complete WheatPlot Example

```gdscript
class_name WheatPlot extends Node2D

var quantum_state: DualEmojiQubit
var growth_progress: float = 0.0

func _ready():
    # Create dual-emoji quantum state
    quantum_state = DualEmojiQubit.new("🌾", "👥", PI/2)
    quantum_state.enable_berry_phase()

func _process(delta):
    # Get quantum state components
    var natural = quantum_state.get_north_amplitude()  # 🌾 amplitude
    var labor = quantum_state.get_south_amplitude()    # 👥 amplitude

    # Growth depends on quantum state
    var base_growth = natural * 0.01 + labor * 0.03

    # Berry phase bonus
    var phase_bonus = 1.0 + quantum_state.get_berry_phase() * 0.1

    # Apply growth
    growth_progress += base_growth * phase_bonus * delta

    # Evolve quantum state (creates phase accumulation)
    quantum_state.evolve(delta, 0.1)

func plant_with_labor(labor_intensity: float):
    # Adjust quantum state based on labor input
    # More labor → move toward south pole (👥)
    quantum_state.theta = PI * (1.0 - labor_intensity)

func measure_yield() -> float:
    # Measurement collapses superposition
    var result = quantum_state.measure()

    if result == "🌾":
        return growth_progress * 1.0  # Natural yield
    else:
        return growth_progress * 1.5  # Labor-boosted yield

func get_display_emoji() -> String:
    # Show quantum state visually
    return quantum_state.get_semantic_state()
```

### Available Quantum Operations

```gdscript
# Rotations
qubit.apply_rotation(axis, angle)
qubit.apply_pauli_x()  # Bit flip
qubit.apply_hadamard()  # Create superposition

# Phase shifts
qubit.apply_phase_shift(phase)

# Measurement
var result = qubit.measure()  # Collapses to north or south

# Partial decoherence
qubit.partial_collapse(0.5)  # 50% collapse toward nearest pole
```

### UI Integration Ideas

**Visual Representation**:
```gdscript
# Show emoji based on quantum state
var display_emoji = wheat_state.get_semantic_state()
label.text = display_emoji

# Color based on state
var blend = wheat_state.get_semantic_blend()  # 0.0 to 1.0
var color = Color.GREEN.lerp(Color.ORANGE, blend)
sprite.modulate = color
```

**Tooltip Info**:
```gdscript
var north_prob = wheat_state.get_north_probability()
var tooltip = "Quantum State:\n"
tooltip += "  Natural: %.1f%%\n" % (north_prob * 100)
tooltip += "  Labor: %.1f%%\n" % ((1.0 - north_prob) * 100)
tooltip += "  Berry Phase: %.2f" % wheat_state.get_berry_phase()
```

---

## Testing the New Systems

### GDScript Tests

Run the comprehensive test suite:
```bash
godot --headless --path . scenes/test_icon_system.tscn
```

**What it tests**:
- Icon creation and modulation ✓
- Icon integration with conspiracy network ✓
- Berry phase accumulation ✓
- DualEmojiQubit operations ✓
- Quantum gates and measurement ✓

### Manual Testing

Create a simple test scene:
```gdscript
extends Node2D

func _ready():
    # Get the conspiracy network
    var network = get_node("/root/TomatoConspiracyNetwork")

    # Create and add Icons
    var biotic = BioticFluxIcon.new()
    biotic.set_activation(0.5)
    network.add_icon(biotic)

    # Enable Berry phase on seed node
    var seed = network.get_tomato_node("seed")
    seed.enable_berry_phase_tracking()

    # Create a wheat qubit
    var wheat = DualEmojiQubit.new("🌾", "👥", PI/2)
    wheat.enable_berry_phase()

    print("Icon influence: ", biotic.get_coupling_strength("seed"))
    print("Wheat state: ", wheat.get_semantic_state())

func _process(delta):
    # Check Berry phase accumulation
    var seed = network.get_tomato_node("seed")
    print("Berry phase: ", seed.get_berry_phase())
```

---

## Integration Checklist

When integrating these systems into your UI/gameplay:

### Icon System
- [ ] Create Icons at game startup
- [ ] Add Icons to conspiracy network
- [ ] Update Icon activation strengths each frame based on:
  - [ ] Wheat plot count (Biotic)
  - [ ] Active conspiracy count (Chaos)
  - [ ] Quota deadline (Imperium)
- [ ] Add visual effects for Icon influence (optional)

### Berry Phase
- [ ] Decide which systems should accumulate phase:
  - [ ] Tomato nodes? (conspiracy memory)
  - [ ] Wheat plots? (replant efficiency)
- [ ] Enable Berry phase tracking on chosen elements
- [ ] Calculate efficiency bonuses from accumulated phase
- [ ] Add visual feedback (spiral glow, tooltips)
- [ ] Reset phase at appropriate times (harvest, etc.)

### DualEmojiQubit
- [ ] Replace simple wheat state with `DualEmojiQubit`
- [ ] Define emoji poles (🌾/👥 suggested)
- [ ] Calculate growth from quantum state components
- [ ] Update display emoji based on superposition
- [ ] Implement measurement (harvest) with collapse
- [ ] Add tooltips showing quantum probabilities

---

## File Reference

### New Files Created
```
Core/Icons/
├── IconHamiltonian.gd         # Base class
├── BioticFluxIcon.gd          # 🌾 Wheat Icon
├── ChaosIcon.gd               # 🍅 Tomato Icon
└── ImperiumIcon.gd            # 🏰 Throne Icon

Core/QuantumSubstrate/
└── DualEmojiQubit.gd          # Semantic quantum states

Core/Tests/
└── test_icon_system.gd        # Comprehensive tests

scenes/
└── test_icon_system.tscn      # Test scene
```

### Modified Files
```
Core/QuantumSubstrate/
├── TomatoNode.gd              # Added Berry phase tracking
└── TomatoConspiracyNetwork.gd # Added Icon system integration
```

---

## Quick Start Example

Here's a minimal integration example:

```gdscript
# In your main game controller
extends Node2D

var network: TomatoConspiracyNetwork
var biotic_icon: BioticFluxIcon
var chaos_icon: ChaosIcon
var imperium_icon: ImperiumIcon

var wheat_plots: Dictionary = {}  # Vector2i -> WheatPlot

func _ready():
    # Get conspiracy network
    network = get_node("/root/TomatoConspiracyNetwork")

    # Create Icons
    biotic_icon = BioticFluxIcon.new()
    chaos_icon = ChaosIcon.new()
    imperium_icon = ImperiumIcon.new()

    network.add_icon(biotic_icon)
    network.add_icon(chaos_icon)
    network.add_icon(imperium_icon)

    # Enable Berry phase on key nodes
    network.get_tomato_node("seed").enable_berry_phase_tracking()

func _process(delta):
    # Update Icon activations
    var wheat_count = wheat_plots.size()
    biotic_icon.calculate_activation_from_wheat(wheat_count, 25)

    var active_conspiracies = network.active_conspiracies.size()
    chaos_icon.calculate_activation_from_conspiracies(active_conspiracies, 12)

    var urgency = calculate_quota_urgency()
    imperium_icon.set_activation(urgency)

func plant_wheat(pos: Vector2i):
    var wheat = WheatPlot.new()
    wheat.quantum_state = DualEmojiQubit.new("🌾", "👥", PI/2)
    wheat.quantum_state.enable_berry_phase()
    wheat_plots[pos] = wheat
    add_child(wheat)

func calculate_quota_urgency() -> float:
    # Return 0.0 to 1.0 based on deadline proximity
    return 1.0 - (time_remaining / total_time)
```

---

## Questions?

The simulation engine is designed to be **easy to use** with sensible defaults. If something is unclear:

1. Check the test file: `Core/Tests/test_icon_system.gd`
2. Look at example usage in the class files
3. All classes have detailed docstrings
4. Ask the simulation bot for clarification!

**Philosophy**: These systems should enhance gameplay naturally. If they feel complicated, we're doing it wrong. Start simple, add complexity only as needed.

---

## Next Steps

**Immediate** (Week 1):
- Integrate Icon activation based on wheat/conspiracy counts
- Add Berry phase to wheat plots for efficiency bonuses
- Use DualEmojiQubit for wheat quantum states

**Future** (Week 2-3):
- Visual effects for Icon influence
- Berry phase spiral glow visualization
- Quantum state tooltips and info panels
- Entanglement between DualEmojiQubits

**Aspirational** (Month 2+):
- Non-abelian conspiracy braiding
- Topological protection for plots
- Quantum error correction systems

Good luck, and have fun with the quantum farming! 🌾⚛️🍅
