# Bell State Entanglement System - Usage Guide

**Date**: 2025-12-14
**For**: UI/Game Development Bot
**Status**: Complete and Tested

---

## Overview

The entanglement system implements **genuine quantum entanglement** between `DualEmojiQubit` instances. When two qubits are entangled, measuring one instantly affects the other - Einstein's "spooky action at a distance"!

---

## Quick Start

### Basic Entanglement

```gdscript
# Create two wheat plots with quantum states
var wheat_a = DualEmojiQubit.new("🌾", "👥", PI/2)
var wheat_b = DualEmojiQubit.new("🌾", "👥", PI/2)

# Entangle them (bidirectional)
wheat_a.create_entanglement(wheat_b, 0.8)  # 0.8 = 80% strength

# Check entanglement
print(wheat_a.is_entangled_with(wheat_b))  # true
print(wheat_a.get_entanglement_count())    # 1
```

### Bell Pair (Maximally Entangled)

```gdscript
var wheat_a = DualEmojiQubit.new("🌾", "👥")
var wheat_b = DualEmojiQubit.new("🌾", "👥")

# Create perfect Bell pair
wheat_a.create_bell_pair(wheat_b, "phi_plus")

# Now they're perfectly correlated!
# Measuring one collapses both
```

---

## The Four Bell States

Bell states are maximally entangled two-qubit states:

### |Φ+⟩ = (|00⟩ + |11⟩)/√2  ("phi_plus")
**Both qubits in same state**
```gdscript
wheat_a.create_bell_pair(wheat_b, "phi_plus")
# If A measures 🌾, B will also measure 🌾
# If A measures 👥, B will also measure 👥
```
**Use case**: Perfect synchronization

### |Φ-⟩ = (|00⟩ - |11⟩)/√2  ("phi_minus")
**Both qubits in same state, phase flip**
```gdscript
wheat_a.create_bell_pair(wheat_b, "phi_minus")
# Similar to Φ+ but with opposite phase
```
**Use case**: Anti-synchronized growth

### |Ψ+⟩ = (|01⟩ + |10⟩)/√2  ("psi_plus")
**Qubits in opposite states**
```gdscript
wheat_a.create_bell_pair(wheat_b, "psi_plus")
# If A measures 🌾, B will measure 👥
# If A measures 👥, B will measure 🌾
```
**Use case**: Complementary farming (one natural, one labor)

### |Ψ-⟩ = (|01⟩ - |10⟩)/√2  ("psi_minus")
**Qubits in opposite states, phase flip**
```gdscript
wheat_a.create_bell_pair(wheat_b, "psi_minus")
# Opposite states with phase difference
```
**Use case**: Advanced patterns

---

## Entanglement Limits

**Maximum 3 entanglements per qubit** (matches game design):

```gdscript
var center = DualEmojiQubit.new("🌾", "👥")
var neighbor1 = DualEmojiQubit.new("🌾", "👥")
var neighbor2 = DualEmojiQubit.new("🌾", "👥")
var neighbor3 = DualEmojiQubit.new("🌾", "👥")
var neighbor4 = DualEmojiQubit.new("🌾", "👥")

# Create 3 entanglements (all succeed)
center.create_entanglement(neighbor1)  # ✓
center.create_entanglement(neighbor2)  # ✓
center.create_entanglement(neighbor3)  # ✓

# Try to create 4th (fails)
center.create_entanglement(neighbor4)  # ✗ returns false

print(center.get_entanglement_count())  # 3
```

---

## Measurement Collapse Propagation

**The quantum magic**: When you measure an entangled qubit, its partners collapse too!

```gdscript
# Create Bell pair
var wheat_a = DualEmojiQubit.new("🌾", "👥", PI/2)
var wheat_b = DualEmojiQubit.new("🌾", "👥", PI/2)
wheat_a.create_bell_pair(wheat_b, "phi_plus")

# Both in superposition
print(wheat_a.get_semantic_state())  # "🌾👥"
print(wheat_b.get_semantic_state())  # "🌾👥"

# Measure wheat_a (harvesting)
var result_a = wheat_a.measure()

# Wheat_a collapses to a definite state
print(result_a)  # Either "🌾" or "👥"

# Wheat_b ALSO collapses (instantly!)
print(wheat_b.get_semantic_state())  # Also collapsed!
# This is "spooky action at a distance"
```

### Entanglement Strength Effects

```gdscript
# Strong entanglement (> 0.7)
wheat_a.create_entanglement(wheat_b, 0.9)
wheat_a.measure()
# Wheat_b collapses completely (perfect correlation)

# Weak entanglement (< 0.7)
wheat_c.create_entanglement(wheat_d, 0.4)
wheat_c.measure()
# Wheat_d only partially collapses (weak correlation)
```

---

## Synchronized Evolution

Entangled qubits can **evolve together**:

```gdscript
# Create entanglement network
var wheat_a = DualEmojiQubit.new("🌾", "👥", 0.0)   # North
var wheat_b = DualEmojiQubit.new("🌾", "👥", PI)   # South
var wheat_c = DualEmojiQubit.new("🌾", "👥", PI/2) # Middle

wheat_a.create_entanglement(wheat_b)
wheat_b.create_entanglement(wheat_c)
wheat_c.create_entanglement(wheat_a)

# Synchronize each frame
func _process(delta):
    wheat_a.synchronize_with_partners(delta, 0.5)
    wheat_b.synchronize_with_partners(delta, 0.5)
    wheat_c.synchronize_with_partners(delta, 0.5)

    # States gradually converge
    # All wheat plots grow in harmony!
```

**sync_strength** parameter:
- `0.0` = no synchronization
- `0.5` = moderate synchronization (default)
- `1.0` = strong synchronization (rapid convergence)

---

## Gameplay Integration Examples

### Example 1: Synchronized Wheat Growth

```gdscript
class_name WheatPlot extends Node2D

var quantum_state: DualEmojiQubit
var growth_progress: float = 0.0

func create_entanglement(other_plot: WheatPlot) -> bool:
    return quantum_state.create_entanglement(
        other_plot.quantum_state,
        0.8  # Strong entanglement
    )

func _process(delta):
    # Synchronize with entangled partners
    quantum_state.synchronize_with_partners(delta, 0.3)

    # Calculate growth (depends on quantum state)
    var natural = quantum_state.get_north_amplitude()
    var labor = quantum_state.get_south_amplitude()
    var growth_rate = natural * 0.01 + labor * 0.03

    growth_progress += growth_rate * delta

func harvest() -> float:
    # Measurement collapses state AND entangled partners!
    var result = quantum_state.measure()

    # This affects ALL entangled wheat plots
    # (They also partially collapse)

    if result == "🌾":
        return growth_progress * 1.0  # Natural yield
    else:
        return growth_progress * 1.5  # Labor yield
```

### Example 2: Entanglement Network Visualization

```gdscript
func draw_entanglement_lines():
    for wheat_plot in all_wheat_plots:
        var qubit = wheat_plot.quantum_state

        for partner_qubit in qubit.entangled_partners:
            var partner_plot = find_plot_by_qubit(partner_qubit)
            var strength = qubit.entanglement_strength[partner_qubit]

            # Draw line
            var color = Color.CYAN.lerp(Color.MAGENTA, strength)
            draw_line(
                wheat_plot.position,
                partner_plot.position,
                color,
                2.0 * strength
            )

            # Shimmer effect based on correlation
            var shimmer = sin(Time.get_ticks_msec() * 0.005) * 0.3 + 0.7
            color.a = shimmer
```

### Example 3: Entanglement Bonus Calculation

```gdscript
func calculate_growth_bonus(wheat_plot: WheatPlot) -> float:
    var bonus = 1.0
    var qubit = wheat_plot.quantum_state

    # Base entanglement bonus
    var count = qubit.get_entanglement_count()
    bonus += count * 0.2  # +20% per entanglement

    # Strong entanglement extra bonus
    for partner in qubit.entangled_partners:
        var strength = qubit.entanglement_strength[partner]
        if strength > 0.7:
            bonus += 0.1  # +10% for strong links

    return bonus
```

### Example 4: Breaking Entanglements

```gdscript
func remove_wheat_plot(plot: WheatPlot):
    # Break all entanglements before removing
    plot.quantum_state.break_all_entanglements()

    # This ensures partners don't have dangling references
    plot.queue_free()

func break_entanglement_between(plot_a: WheatPlot, plot_b: WheatPlot):
    # Break specific entanglement (bidirectional)
    plot_a.quantum_state.break_entanglement(plot_b.quantum_state)
```

---

## Advanced: Entanglement Networks

### Star Pattern (Hub and Spokes)
```gdscript
var center = DualEmojiQubit.new("🌾", "👥")
var spokes = [
    DualEmojiQubit.new("🌾", "👥"),
    DualEmojiQubit.new("🌾", "👥"),
    DualEmojiQubit.new("🌾", "👥")
]

for spoke in spokes:
    center.create_entanglement(spoke, 0.9)

# Measuring center affects all spokes
# Measuring any spoke affects center (but not other spokes directly)
```

### Chain Pattern
```gdscript
var chain = [
    DualEmojiQubit.new("🌾", "👥"),
    DualEmojiQubit.new("🌾", "👥"),
    DualEmojiQubit.new("🌾", "👥"),
    DualEmojiQubit.new("🌾", "👥")
]

for i in range(chain.size() - 1):
    chain[i].create_entanglement(chain[i+1], 0.8)

# Measuring one end propagates through chain
# Creates "quantum telephone" effect
```

### Ring Pattern (Closed Loop)
```gdscript
var ring = [
    DualEmojiQubit.new("🌾", "👥"),
    DualEmojiQubit.new("🌾", "👥"),
    DualEmojiQubit.new("🌾", "👥")
]

for i in range(ring.size()):
    var next_i = (i + 1) % ring.size()
    ring[i].create_entanglement(ring[next_i], 0.8)

# Forms closed loop
# Measuring any one affects entire ring
# Creates interesting synchronization dynamics
```

---

## Performance Considerations

### Entanglement Count
- Each qubit stores: `Array` of partners + `Dictionary` of strengths
- 3 entanglements per qubit = ~10 refs in memory
- For 100 wheat plots, max ~300 entanglement links
- Very lightweight!

### Collapse Propagation
- When measuring, propagates to all partners (max 3)
- Linear time: O(num_entanglements)
- Fast even for complex networks

### Synchronization
- Each qubit syncs with partners every frame
- Cost: O(num_partners) per qubit
- Negligible for max 3 partners

---

## Testing

Run comprehensive tests:
```bash
godot --headless --path . scenes/test_icon_system.tscn
```

**Tests cover**:
- ✅ Basic entanglement creation/breaking
- ✅ Entanglement limits (max 3)
- ✅ Bell pair creation (all 4 types)
- ✅ Measurement collapse propagation
- ✅ Synchronized evolution
- ✅ Bidirectional links
- ✅ Network patterns

---

## API Reference

### Creation
```gdscript
create_entanglement(other: DualEmojiQubit, strength: float = 1.0) -> bool
create_bell_pair(other: DualEmojiQubit, bell_type: String = "phi_plus") -> bool
```

### Queries
```gdscript
can_entangle() -> bool
is_entangled_with(other: DualEmojiQubit) -> bool
get_entanglement_count() -> int
```

### Management
```gdscript
break_entanglement(other: DualEmojiQubit) -> void
break_all_entanglements() -> void
```

### Dynamics
```gdscript
propagate_measurement_collapse(measured_result: String) -> void
synchronize_with_partners(dt: float, sync_strength: float = 0.5) -> void
```

### Data
```gdscript
entangled_partners: Array  # All entangled qubits
entanglement_strength: Dictionary  # partner -> strength (0.0 to 1.0)
max_entanglements: int = 3
```

---

## Summary

The entanglement system provides:

✅ **Genuine quantum entanglement** - Measuring one affects others
✅ **Bell pairs** - Four types of maximally entangled states
✅ **Collapse propagation** - Spooky action at a distance
✅ **Synchronized evolution** - Entangled qubits grow together
✅ **Network support** - Complex entanglement topologies
✅ **Gameplay integration** - Bonuses, visualization, mechanics
✅ **Limit enforcement** - Max 3 per qubit (balanced gameplay)
✅ **Bidirectional** - Creating/breaking affects both qubits
✅ **Tested** - Comprehensive test suite passing

This is **real quantum mechanics** powering **real gameplay**! 🌾⚛️🔗
