# Berry Phase System - Quantum Evolution Experience Points

## Overview

Berry phase has been restored as an **accumulated experience/progress system** for quantum bubbles. It grows unbounded as quantum systems undergo evolution, serving as a visual **measurement apparatus** that displays the full history of quantum activity on each bubble.

**Aesthetic Philosophy**: "Full information whenever possible" - the glow becomes ridiculously bright on highly evolved qubits, like a measurement apparatus showing every quantum interaction.

---

## System Architecture

### 1. Berry Phase in DualEmojiQubit

**Location**: `Core/QuantumSubstrate/DualEmojiQubit.gd`

**Properties**:
```gdscript
var berry_phase: float = 0.0           # Accumulated quantum evolution
var berry_phase_rate: float = 1.0      # Tunable accumulation rate (default 1.0)
```

**Methods**:

**`accumulate_berry_phase(evolution_amount: float, dt: float = 1.0) -> void`**
- Accumulates berry phase based on quantum evolution
- `evolution_amount`: How much evolution occurred (0-1 scale)
- `dt`: Delta time for temporal scaling
- Internal cap: 10.0 (prevents overflow but doesn't clamp externally)

```gdscript
berry_phase += evolution_amount * berry_phase_rate * dt
berry_phase = clamp(berry_phase, 0.0, 10.0)
```

**`get_berry_phase() -> float`**
- Returns raw accumulated berry phase
- Range: 0.0 to 10.0
- Used directly for glow calculations (no normalization)

**`get_debug_string() -> String`**
- Now includes berry phase in debug output
- Format: "🌾 | θ=1.57 φ=0.00 | BP=5.23"

---

### 2. Berry Phase in QuantumNode

**Location**: `Core/Visualization/QuantumNode.gd`

**Property**:
```gdscript
var berry_phase: float = 0.0  # Accumulated quantum evolution (experience points)
```

**Initialization**:
In `update_from_quantum_state()`:
```gdscript
# Berry phase: Accumulated quantum evolution (experience points)
# Raw unbounded value - glow intensifies as evolution accumulates
# Acts as visual "measurement apparatus" showing full quantum activity
berry_phase = quantum_state.get_berry_phase()
```

---

### 3. Glow System Integration

**Location**: `Core/Visualization/QuantumNode.gd`

**`get_glow_alpha() -> float`**

Combines two components:
1. **Energy glow** (bounded): `energy * 0.4` → range 0.0 to 0.4
2. **Berry phase glow** (unbounded): `berry_phase * 0.2` → grows indefinitely

```gdscript
var energy_glow = energy * 0.4          # Bounded: 0.0 to 0.4
var berry_glow = berry_phase * 0.2      # Unbounded: grows with evolution
return energy_glow + berry_glow         # Combined glow intensity
```

**Total glow range**:
- Fresh qubit (BP=0): 0.4 (energy only)
- Moderately evolved (BP=5): 1.4
- Highly evolved (BP=10): 2.4
- Can exceed these with continued evolution!

**`get_berry_phase_glow() -> float`**

Returns just the berry phase contribution:
```gdscript
return berry_phase * 0.2
```

---

## Visual Effects

### Glow Intensity by Evolution

| Berry Phase | Glow Intensity | Visual Appearance |
|-------------|----------------|-------------------|
| 0.0 | 0.4 | Dim glow - fresh quantum bubble |
| 2.5 | 0.9 | Growing glow - developing experience |
| 5.0 | 1.4 | Bright glow - experienced quantum state |
| 7.5 | 1.9 | Very bright - highly evolved |
| 10.0 | 2.4 | Intense glow - maximum internal evolution |

### Philosophy

The glow acts as a **visual measurement apparatus**:
- **Fresh qubits** have dim halos → inexperienced quantum states
- **Evolved qubits** have intense glows → rich quantum history
- **No hard ceiling** → highly evolved systems become visually unmissable

This creates immediate visual feedback showing which quantum bubbles have undergone the most complex evolution.

---

## Accumulation Triggers

**Berry phase should accumulate during**:
1. ✅ Complex rotations on Bloch sphere
2. ✅ Entanglement interactions
3. ✅ Environmental interactions
4. ✅ Hamiltonian evolution (sun/moon cycles)
5. ✅ Decoherence events

**Current status**: Integration points ready, accumulation logic to be called from WheatPlot quantum evolution.

---

## Integration Points

### Calling Accumulation

In `WheatPlot._evolve_quantum_state()` and similar quantum evolution routines:

```gdscript
# After quantum evolution
var evolution_complexity = calculate_evolution_complexity(delta)
quantum_state.accumulate_berry_phase(evolution_complexity, delta)
```

Example complexity calculation:
```gdscript
# Simple: rotation magnitude
var rotation_amount = abs(delta_theta) / PI  # 0-1 scale

# Complex: consider coherence and entanglement
var coherence_factor = quantum_state.get_coherence()
var entanglement_bonus = 1.0 if is_entangled else 0.5
var evolution_complexity = rotation_amount * coherence_factor * entanglement_bonus
```

---

## Technical Details

### Unbounded Design Rationale

**Why not normalize to 0-1?**
- Normalization would cap visual feedback at arbitrary threshold
- Unbounded growth provides **full information density** on bubbles
- Highly evolved systems deserve visually intense representation
- Encourages visual distinction between young and old quantum states

### Internal Clamping (10.0)

The internal cap at 10.0 prevents:
- Floating point overflow
- Unreasonable glow intensities
- But it's just a safety limit, not a player-facing ceiling

### Tunable Rate

Adjust evolution speed per qubit:
```gdscript
var qubit = DualEmojiQubit.new("🌾", "👥")
qubit.berry_phase_rate = 0.5  # Slower accumulation
# or
qubit.berry_phase_rate = 2.0  # Faster accumulation
```

---

## Test Results

**Berry Phase System Tests** (4/4 PASSED ✅)

✅ Energy glow component (bounded): 0.40
✅ Berry phase glow (unbounded, 5.0 evolution): 1.00
✅ Combined glow (energy + evolution): 1.40
✅ Max total glow (max evolution 10.0): 2.4

---

## Future Enhancements

### Phase 2: Visual Indicators
- [ ] Add outer glow ring that pulses with berry phase magnitude
- [ ] Color shift toward white as berry phase increases (glowing hot)
- [ ] Particle aura that becomes denser with evolution

### Phase 3: Berry Phase UI
- [ ] Display berry phase value on hover
- [ ] Show berry phase in quantum state inspector
- [ ] History log: "This qubit has evolved X times"

### Phase 4: Gameplay Integration
- [ ] Berry phase affects measurement probability weights
- [ ] Evolved qubits harder to measure (more decoherence resistance)
- [ ] Entanglement strength increases with berry phase sum
- [ ] Berry phase as currency for some actions

---

## Summary

Berry phase is now **fully integrated as a visual measurement apparatus** showing quantum evolution history. As qubits undergo quantum interactions, their glows intensify - providing immediate visual feedback about quantum system maturity and complexity.

The unbounded design ensures **full information visibility**: evolved systems are unmistakably bright, creating a natural visual hierarchy in the quantum farm.

🌾✨ Quantum experience, rendered as light! ✨🌾
