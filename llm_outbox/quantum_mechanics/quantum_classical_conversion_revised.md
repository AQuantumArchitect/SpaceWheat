# Quantum → Classical Conversion: Revised Analysis

## The Dimensionality Problem

**User's critical insight:** "radius tends to be very small because they are sharing a unitary space with upwards of 20 peers"

### Why Radius is Small

For a QuantumBath with N=20 emojis in maximally mixed state:
```
ρ = (1/20) × I₂₀

When projecting onto 2D subspace {🌾, 👥}:
- P(🌾) = 1/20 = 0.05
- P(👥) = 1/20 = 0.05
- P(subspace) = 0.10
- radius ≈ 0 (maximally mixed in this subspace)
```

Even after Hamiltonian evolution that concentrates amplitude:
```
P(🌾) = 0.15
P(👥) = 0.10
P(subspace) = 0.25  ← Only 25% of bath in this subspace!
radius = 0.05  ← Still very small!
```

**The problem:** Using raw radius as resource measure **penalizes high-dimensional baths**!

---

## Alternative Quantum Observables for Resource Extraction

### Option 1: Subspace Population (Not Radius)

**Use total probability in the {north, south} subspace:**

```gdscript
var p_north = quantum_state.bath.get_probability(north_emoji)
var p_south = quantum_state.bath.get_probability(south_emoji)
var subspace_population = p_north + p_south

yield_credits = int(subspace_population × 100)  // Scale up from 0-1 to 0-100
```

**Example (20-emoji bath):**
```
Maximally mixed:
  P(🌾) = 0.05, P(👥) = 0.05
  subspace_population = 0.10
  yield = 10 credits

After evolution:
  P(🌾) = 0.15, P(👥) = 0.12
  subspace_population = 0.27
  yield = 27 credits

Well-evolved:
  P(🌾) = 0.40, P(👥) = 0.25
  subspace_population = 0.65
  yield = 65 credits
```

**Advantages:**
- ✅ Dimension-agnostic (works same for 6-emoji or 20-emoji bath)
- ✅ Measures what matters: "How much bath probability is in harvestable emojis?"
- ✅ Grows naturally with Hamiltonian evolution
- ✅ Intuitive: more population = more resources

**Disadvantages:**
- ❌ Ignores coherence (treats classical mixture same as superposition)
- ❌ Maximum yield varies with bath size (unfair across biomes)

---

### Option 2: Expected Energy ⟨H⟩

**Use Hamiltonian expectation value:**

```gdscript
var expected_energy = quantum_state.bath.get_expected_energy()
var energy_in_subspace = _get_subspace_energy_contribution(north_emoji, south_emoji)

yield_credits = int(energy_in_subspace × scaling_factor)
```

**Physics:**
```
⟨H⟩ = Tr(ρH)

For coupling H[🌾][👥] = 0.25:
⟨H⟩_subspace = P(🌾) × H[🌾🌾] + P(👥) × H[👥👥] + 2×Re(ρ[🌾👥]×H[🌾👥])
```

**Example:**
```
Pure superposition |🌾⟩ + |👥⟩:
  ⟨H⟩ = 0.25 (from off-diagonal coupling)

Thermal mixture:
  ⟨H⟩ = 0.0 (no coherence, no coupling contribution)
```

**Advantages:**
- ✅ Physically meaningful (energy is a conserved quantity)
- ✅ Rewards coherent superpositions (off-diagonal terms contribute)
- ✅ Natural for quantum systems
- ✅ Dimension-agnostic

**Disadvantages:**
- ❌ Complex to calculate per-subspace
- ❌ Depends on Hamiltonian structure (different per biome)
- ❌ May be negative or zero

---

### Option 3: Subspace Purity × Population

**Combine population with coherence quality:**

```gdscript
var p_north = bath.get_probability(north_emoji)
var p_south = bath.get_probability(south_emoji)
var population = p_north + p_south

var projection = bath.project_onto_axis(north_emoji, south_emoji)
var subspace_purity = projection["purity"]  // Tr(ρ_sub²)

var quality_factor = 0.5 + 0.5 × subspace_purity  // 0.5× (mixed) to 1.0× (pure)
yield_credits = int(population × 100 × quality_factor)
```

**Example (20-emoji bath):**
```
Maximally mixed:
  population = 0.10
  purity = 0.5 (mixed 2-state)
  quality = 0.75
  yield = int(0.10 × 100 × 0.75) = 7 credits

Partially evolved:
  population = 0.27
  purity = 0.65
  quality = 0.825
  yield = int(0.27 × 100 × 0.825) = 22 credits

Pure superposition in subspace:
  population = 0.65
  purity = 1.0
  quality = 1.0
  yield = int(0.65 × 100 × 1.0) = 65 credits
```

**Advantages:**
- ✅ Rewards both population growth AND coherence quality
- ✅ Dimension-agnostic
- ✅ Intuitive: "How much pure quantum resource is in this subspace?"

**Disadvantages:**
- ❌ More complex than pure population
- ❌ Purity might be hard for players to understand

---

### Option 4: Relative Radius (Normalized by Subspace)

**Normalize radius by maximum possible in subspace:**

```gdscript
var projection = bath.project_onto_axis(north_emoji, south_emoji)
var radius = projection["radius"]
var p_subspace = projection["p_north"] + projection["p_south"]

var relative_radius = radius / max(0.01, p_subspace)  // Avoid division by zero
relative_radius = min(1.0, relative_radius)  // Cap at 1.0

yield_credits = int(p_subspace × 100 × relative_radius)
```

**Physics interpretation:**
```
radius = r (Bloch vector length in 2D subspace)
p_subspace = total probability in subspace

relative_radius = r / p_subspace
  = coherence per unit probability
  = "purity within subspace"

For pure state: r = p_subspace → relative_radius = 1.0
For mixed state: r < p_subspace → relative_radius < 1.0
```

**Example:**
```
Small subspace, maximally mixed:
  r = 0.001, p = 0.10
  relative_radius = 0.01
  yield = int(0.10 × 100 × 0.01) = 0 credits

Larger subspace, partially coherent:
  r = 0.15, p = 0.27
  relative_radius = 0.56
  yield = int(0.27 × 100 × 0.56) = 15 credits

Large subspace, pure:
  r = 0.65, p = 0.65
  relative_radius = 1.0
  yield = int(0.65 × 100 × 1.0) = 65 credits
```

**Advantages:**
- ✅ Accounts for dimensionality (normalizes by subspace size)
- ✅ Rewards coherence AND population
- ✅ Bounded [0, 1] regardless of bath size

**Disadvantages:**
- ❌ Division can be unstable for small p_subspace
- ❌ Conceptually complex

---

### Option 5: Measurement Statistics (Monte Carlo)

**Simulate multiple measurements to estimate yield:**

```gdscript
func estimate_harvest_yield(north: String, south: String, num_trials: int = 100) -> int:
    var hits = 0
    for i in range(num_trials):
        var outcome = bath.measure_axis(north, south, collapse_strength=0.0)  // No collapse
        if outcome == north or outcome == south:
            hits += 1

    var success_rate = float(hits) / float(num_trials)
    return int(success_rate × 100)
```

**Example:**
```
In 100 virtual measurements:
- 15 → 🌾
- 12 → 👥
- 73 → other emojis

success_rate = 27/100 = 0.27
yield = 27 credits
```

**Advantages:**
- ✅ Physically accurate (this IS what measurement does)
- ✅ Dimension-agnostic
- ✅ Easy to understand: "What would I get if I measured many times?"
- ✅ Naturally handles unknown outcomes

**Disadvantages:**
- ❌ Computationally expensive (100 trials per harvest)
- ❌ Stochastic (different each time)
- ❌ Doesn't account for coherence (treats mixture same as superposition)

---

### Option 6: Hybrid Population + Coherence Bonus

**Base yield from population, bonus from coherence:**

```gdscript
var p_north = bath.get_probability(north_emoji)
var p_south = bath.get_probability(south_emoji)
var population = p_north + p_south

var base_yield = int(population × 100)

# Coherence bonus (off-diagonal term)
var coherence_ab = bath.get_coherence(north_emoji, south_emoji)
var coherence_magnitude = coherence_ab.abs()
var coherence_bonus = int(coherence_magnitude × 50)  // Max 50 credit bonus

yield_credits = base_yield + coherence_bonus
```

**Physics:**
```
ρ = [
    [P(🌾)      ρ[🌾👥]]
    [ρ[👥🌾]    P(👥)  ]
]

population = P(🌾) + P(👥)  // Diagonal terms
coherence = |ρ[🌾👥]|      // Off-diagonal magnitude
```

**Example (20-emoji bath):**
```
Classical mixture:
  P(🌾) = 0.15, P(👥) = 0.12
  ρ[🌾👥] = 0.0 (no coherence)
  base = 27, bonus = 0
  yield = 27 credits

Quantum superposition:
  P(🌾) = 0.15, P(👥) = 0.12
  |ρ[🌾👥]| = 0.1 (coherent superposition)
  base = 27, bonus = 5
  yield = 32 credits

Pure Bell state (if achievable):
  P(🌾) = 0.5, P(👥) = 0.5
  |ρ[🌾👥]| = 0.5
  base = 100, bonus = 25
  yield = 125 credits  ← Max possible
```

**Advantages:**
- ✅ Separates classical resource (population) from quantum bonus (coherence)
- ✅ Dimension-agnostic
- ✅ Physically meaningful (diagonal vs off-diagonal)
- ✅ Rewards quantum advantages while giving baseline for classical

**Disadvantages:**
- ❌ Requires understanding density matrix structure
- ❌ Coherence magnitude may be small even for good states

---

## Accounting for Berry Phase (Properly)

**Berry Phase = Geometric phase accumulated during cyclic adiabatic evolution**

**NOT related to:**
- ❌ Entanglement
- ❌ Coherence
- ❌ Purity

**IS related to:**
- ✅ Cyclic evolution in parameter space
- ✅ Path-dependent phase accumulation
- ✅ Topological properties of Hilbert space

**Potential uses:**
1. **Evolution quality indicator** - Large berry phase → system has undergone significant cyclic evolution
2. **Path memory** - Tracks that plot has been "worked" via evolution cycles
3. **Geometric multiplier** - Reward plots that have undergone rich evolution dynamics

**Proposed berry phase bonus:**
```gdscript
var evolution_quality = min(1.0, berry_phase / 5.0)  // 0.0 to 1.0
var evolution_bonus = int(base_yield × evolution_quality × 0.2)  // Up to 20% bonus

yield_credits = base_yield + evolution_bonus
```

**Example:**
```
No evolution (berry_phase=0):
  base = 27
  evolution_quality = 0
  bonus = 0
  yield = 27 credits

Some evolution (berry_phase=2.5):
  base = 27
  evolution_quality = 0.5
  bonus = int(27 × 0.5 × 0.2) = 2
  yield = 29 credits

Full evolution (berry_phase≥5):
  base = 27
  evolution_quality = 1.0
  bonus = int(27 × 1.0 × 0.2) = 5
  yield = 32 credits
```

---

## Recommended Hybrid System

**Combine Option 6 (Population + Coherence) with Berry Phase bonus:**

```gdscript
func harvest() -> Dictionary:
    if not is_planted or not has_been_measured:
        # ... measurement logic ...

    var outcome = measured_outcome

    # 1. BASE YIELD: Population in subspace (dimension-agnostic)
    var p_north = quantum_state.bath.get_probability(quantum_state.north_emoji)
    var p_south = quantum_state.bath.get_probability(quantum_state.south_emoji)
    var population = p_north + p_south

    var base_yield = int(population × 100)  // 0-100 credits typical

    # 2. QUANTUM BONUS: Off-diagonal coherence
    var coherence_ab = quantum_state.bath.get_coherence(
        quantum_state.north_emoji,
        quantum_state.south_emoji
    )
    var coherence_magnitude = coherence_ab.abs()
    var quantum_bonus = int(coherence_magnitude × 50)  // 0-50 credits typical

    # 3. EVOLUTION BONUS: Berry phase (path memory)
    var evolution_quality = min(1.0, berry_phase / 5.0)
    var evolution_bonus = int(base_yield × evolution_quality × 0.2)  // Up to 20% of base

    # 4. TOTAL YIELD
    var total_yield = base_yield + quantum_bonus + evolution_bonus
    total_yield = max(1, total_yield)  // Minimum 1 credit

    print("✂️  Plot %s harvested:" % grid_position)
    print("   Population: %.2f → %d credits (base)" % [population, base_yield])
    print("   Coherence: %.3f → %d credits (quantum bonus)" % [coherence_magnitude, quantum_bonus])
    print("   Berry phase: %.2f → %d credits (evolution bonus)" % [berry_phase, evolution_bonus])
    print("   Outcome: %s, Total: %d credits" % [outcome, total_yield])

    # Clear plot
    # ...

    return {
        "success": true,
        "outcome": outcome,
        "yield": total_yield,
        "population": population,
        "coherence": coherence_magnitude,
        "berry_phase": berry_phase
    }
```

---

## Yield Comparison Across Bath Sizes

### 6-Emoji Bath (BioticFlux: ☀🌙🌾🍄💀🍂)

```
Maximally mixed:
  P(🌾) = 1/6 = 0.167
  P(👥) = 0 (not in bath initially)
  After injection: P(🌾) ≈ 0.143, P(👥) ≈ 0.143
  population = 0.286
  coherence ≈ 0
  base = 28, quantum = 0, evolution = 0
  total = 28 credits

After 3s evolution:
  P(🌾) = 0.25, P(👥) = 0.20
  |ρ[🌾👥]| = 0.15
  berry_phase = 2.0
  base = 45, quantum = 7, evolution = 4
  total = 56 credits
```

### 20-Emoji Bath (Forest ecosystem)

```
Maximally mixed:
  P(🌾) ≈ 0.05, P(👥) ≈ 0.05
  population = 0.10
  coherence ≈ 0
  base = 10, quantum = 0, evolution = 0
  total = 10 credits

After 3s evolution:
  P(🌾) = 0.15, P(👥) = 0.12
  |ρ[🌾👥]| = 0.08
  berry_phase = 2.0
  base = 27, quantum = 4, evolution = 2
  total = 33 credits
```

**Key insight:** Larger baths give lower base yields, but quantum/evolution bonuses help compensate!

---

## Summary of Options

| Option | Measures | Dimension-Agnostic? | Quantum Advantage? | Complexity |
|--------|----------|---------------------|-------------------|------------|
| 1. Population | P(north) + P(south) | ✅ Yes | ❌ No | Low |
| 2. Expected Energy | ⟨H⟩ | ✅ Yes | ✅ Yes | High |
| 3. Purity × Population | Both | ✅ Yes | ✅ Modest | Medium |
| 4. Relative Radius | r / p_subspace | ✅ Yes | ✅ Yes | Medium |
| 5. Monte Carlo | Measurement stats | ✅ Yes | ❌ No | High (CPU) |
| **6. Hybrid** | **Population + Coherence** | **✅ Yes** | **✅ Yes** | **Medium** |

**Recommendation:** **Option 6 (Hybrid)** with berry phase evolution bonus.

**Why:**
- Dimension-agnostic (works for any bath size)
- Separates classical resource (population) from quantum bonus (coherence)
- Rewards quantum advantages (superposition, evolution)
- Physically meaningful (uses density matrix structure correctly)
- Scales appropriately (larger baths have lower baseline but same bonus potential)
