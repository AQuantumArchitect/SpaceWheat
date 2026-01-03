# Quantum Mechanics Documentation

Analysis of SpaceWheat's quantum physics implementation, resource conversion systems, and mathematical formulations.

## Quick Navigation

### Investigation Reports
1. **[Quantum State Properties](quantum_state_properties_investigation.md)** - Deep dive into radius, coherence, theta, purity
2. **[Wheat Farming System Verified](wheat_farming_system_verified_WORKING.md)** - Proof that dual-emoji injection works

### Conversion Analysis
3. **[Quantum→Classical Conversion (Initial)](quantum_classical_conversion_analysis.md)** - First analysis with Berry phase error
4. **[Quantum→Classical Conversion (Revised)](quantum_classical_conversion_revised.md)** - Corrected analysis with dimensionality fix ⭐

⭐ = **Recommended reading** for quantum mechanics review

---

## Document Evolution

### Phase 1: Initial Investigation
**File**: `quantum_state_properties_investigation.md`
**Date**: Early analysis
**Focus**: Understanding quantum state representation

**Key Discoveries**:
- Radius (coherence) is the resource, NOT theta
- `.energy` property removed during bath-first refactor
- Theta controls measurement direction (which emoji)
- Radius controls resource magnitude (how much yield)

**Critical Finding**:
```
Coherence (radius) = Bloch vector length
- Pure state: r = 1
- Mixed state: r < 1
- Maximally mixed: r ≈ 0

This is what we extract during harvest!
```

### Phase 2: System Verification
**File**: `wheat_farming_system_verified_WORKING.md`
**Date**: Post-investigation
**Focus**: Proving emoji injection works

**Test Results**:
```
BEFORE planting:
  Bath: ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]
  👥 present: NO

AFTER planting wheat at (2,0):
  💉 Injected 👥 into BioticFlux bath
  Bath: ["☀", "🌙", "🌾", "🍄", "💀", "🍂", "👥"]
  H[🌾][👥] = 0.250000
  ✅ Hamiltonian coupling EXISTS
```

**Coherence Growth**:
```
t=0.0s:  r=0.000342
t=0.5s:  r=0.007863  (23× increase!)
```

**Conclusion**: System works as designed!

### Phase 3: Conversion Formula Analysis (Flawed)
**File**: `quantum_classical_conversion_analysis.md`
**Date**: Before user correction
**Focus**: Analyzing harvest yield formula

**Current Formula Analyzed**:
```gdscript
coherence_value = radius × 0.9 + berry_phase × 0.1
purity_multiplier = 2.0 × purity
yield = max(1, int(coherence_value × 10 × purity_multiplier))
```

**Issues Identified**:
1. Low yields from realistic coherence (r=0.3 → 3 credits)
2. Purity multiplier double-counts coherence
3. Berry phase underutilized (only adds 0-1.0)
4. "?" outcomes give invisible credits
5. No incentive for high purity (not player-controllable)

**Recommendation Made**: Berry phase bonus multiplier

**CRITICAL ERROR**: Conflated Berry phase with entanglement
> "Berry phase grows faster when entangled"  ← WRONG!

### Phase 4: User Correction & Revision
**User Feedback**:
> "i think your understanding of quantum computing is lacking. what does berry phase and entanglement have to do with one another?"

**Critical Insight**:
> "also keep in mind that the radius tends to be very small because they are sharing a unitary space with upwards of 20 peers"

**File**: `quantum_classical_conversion_revised.md`
**Date**: After correction
**Focus**: Dimension-agnostic conversion formulas

**Berry Phase Corrected**:
- Berry phase = Geometric phase during **cyclic adiabatic evolution**
- NOT related to entanglement
- NOT related to coherence
- IS related to: cyclic paths in parameter space, topological properties

**Dimensionality Problem Explained**:
```
For N=20 emoji bath in maximally mixed state:
  ρ = (1/20) × I₂₀

Projection onto {🌾, 👥} subspace:
  P(🌾) = 1/20 = 0.05
  P(👥) = 1/20 = 0.05
  P(subspace) = 0.10  ← Only 10% of bath!
  radius ≈ 0  (maximally mixed in subspace)

Even after evolution:
  P(🌾) = 0.15, P(👥) = 0.10
  P(subspace) = 0.25  ← Only 25%!
  radius = 0.05  ← Still very small!
```

**Problem**: Using raw radius penalizes high-dimensional baths!

**6 Alternative Formulas Proposed**:
1. Subspace Population: `yield = (P(north) + P(south)) × 100`
2. Expected Energy: `yield = ⟨H⟩_subspace × scaling`
3. Purity × Population: `yield = population × 100 × (0.5 + 0.5×purity)`
4. Relative Radius: `yield = p_subspace × 100 × (r/p_subspace)`
5. Monte Carlo: Simulate 100 measurements, count hits
6. **Hybrid (Recommended)**: Population + Coherence + Evolution bonuses

**Recommended Hybrid Formula**:
```gdscript
# Base yield: Subspace population (dimension-agnostic)
var p_north = bath.get_probability(north_emoji)
var p_south = bath.get_probability(south_emoji)
var population = p_north + p_south
var base_yield = int(population × 100)  // 0-100 credits

# Quantum bonus: Off-diagonal coherence
var coherence_ab = bath.get_coherence(north_emoji, south_emoji)
var quantum_bonus = int(coherence_ab.abs() × 50)  // 0-50 credits

# Evolution bonus: Berry phase (path memory)
var evolution_quality = min(1.0, berry_phase / 5.0)
var evolution_bonus = int(base_yield × evolution_quality × 0.2)  // Up to 20%

# Total
var total_yield = base_yield + quantum_bonus + evolution_bonus
```

**Advantages**:
- ✅ Dimension-agnostic (fair across all biome sizes)
- ✅ Separates classical (population) from quantum (coherence) resources
- ✅ Rewards evolution without double-counting
- ✅ Berry phase used correctly (evolution memory, not entanglement)

**Yield Comparison**:
```
6-emoji bath (BioticFlux):
  Maximally mixed: 28 base → 28 total
  After evolution:  45 base + 7 quantum + 4 evolution = 56 total

20-emoji bath (Forest):
  Maximally mixed: 10 base → 10 total
  After evolution:  27 base + 4 quantum + 2 evolution = 33 total
```

---

## Key Physics Concepts

### Density Matrix (ρ)
```
ρ = quantum state of entire bath
Properties:
- Hermitian: ρ† = ρ
- Positive: all eigenvalues ≥ 0
- Normalized: Tr(ρ) = 1
- Pure state: Tr(ρ²) = 1
- Mixed state: Tr(ρ²) < 1
```

### Bloch Sphere Representation
```
For 2-state system:
ρ = 1/2(I + r⃗·σ⃗)

Where:
- r⃗ = (r sin θ cos φ, r sin θ sin φ, r cos θ)
- r = radius (coherence) [0, 1]
- θ = polar angle [0, π]
- φ = azimuthal angle [0, 2π]
```

### Observables
| Observable | Formula | Meaning | Range |
|------------|---------|---------|-------|
| **Probability** | ρ[i][i] | Diagonal element | [0, 1] |
| **Coherence** | \|ρ[i][j]\| | Off-diagonal magnitude | [0, 0.5] |
| **Purity** | Tr(ρ²) | Quantum vs classical | [1/N, 1] |
| **Entropy** | -Tr(ρ log ρ) | Mixedness | [0, log N] |
| **Expected Energy** | Tr(ρH) | Average Hamiltonian | [-∞, ∞] |

### Evolution Dynamics
```
Master equation:
dρ/dt = -i[H, ρ] + L(ρ)

Hamiltonian term: -i[H, ρ]
- Drives coherent oscillations
- Preserves purity
- Reversible

Lindblad term: L(ρ)
- Drives decoherence
- Reduces purity
- Irreversible

L(ρ) = Σ_k γ_k (L_k ρ L_k† - 1/2{L_k†L_k, ρ})
```

### Berry Phase
```
γ_Berry = i∮ ⟨ψ(R)| ∇_R |ψ(R)⟩ · dR

Properties:
- Geometric phase from cyclic evolution
- Path-dependent (not state-dependent)
- Topological (robust to local perturbations)
- Independent of evolution speed (adiabatic limit)

NOT RELATED TO:
- ❌ Entanglement (separate quantum phenomenon)
- ❌ Coherence (different observable)
- ❌ Purity (separate measure)

RELATED TO:
- ✅ Cyclic paths in parameter space
- ✅ Adiabatic evolution
- ✅ Topological properties of Hilbert space
```

---

## Dimensionality Scaling

### Problem Statement
**Question**: How should yields scale with bath size?

**Challenge**: Larger baths (more emojis) dilute probability:
```
6-emoji bath:  P(🌾) ≈ 1/6 = 0.167
20-emoji bath: P(🌾) ≈ 1/20 = 0.05

2D projection coherence:
6-emoji:  r ≈ 0.3 (typical after evolution)
20-emoji: r ≈ 0.08 (3.75× smaller!)
```

**Using raw radius → unfair penalty for large baths!**

### Solution: Dimension-Agnostic Measures

#### Option 1: Subspace Population
```
Measure: P(north) + P(south)
- Grows with evolution (bath probability concentrates)
- Independent of bath size (same scaling)
- Intuitive: "How much bath is in harvestable emojis?"

Issue: Ignores coherence quality
```

#### Option 2: Relative Radius
```
Measure: radius / p_subspace
- Normalizes by subspace size
- Accounts for dimensionality
- Bounded [0, 1] always

Issue: Division unstable for small p_subspace
```

#### Option 3: Hybrid (Recommended)
```
Base: Subspace population (dimension-agnostic)
Bonus: Coherence magnitude (quantum advantage)
Evolution: Berry phase (path memory)

Result: Fair yields + quantum incentive + evolution reward
```

---

## Conversion Formula Comparison

| Formula | Max Yield | Dimension-Agnostic? | Quantum Bonus? | Complexity |
|---------|-----------|---------------------|----------------|------------|
| **Current** | 18 credits | ❌ No | ❌ No (purity) | Medium |
| **Population** | 100 credits | ✅ Yes | ❌ No | Low |
| **Hybrid** | ~120 credits | ✅ Yes | ✅ Yes | Medium |

### Current Formula
```gdscript
coherence_value = radius × 0.9 + berry_phase × 0.1
purity_multiplier = 2.0 × purity
yield = max(1, int(coherence_value × 10 × purity_multiplier))
```

**Issues**:
- Radius penalizes large baths
- Purity double-counts coherence (purity ∝ radius²)
- Berry phase misused (added to "coherence")
- Max 18 credits (r=1, purity=1, berry=10)

### Recommended Hybrid Formula
```gdscript
var p_north = bath.get_probability(north_emoji)
var p_south = bath.get_probability(south_emoji)
var population = p_north + p_south
var base_yield = int(population × 100)

var coherence_ab = bath.get_coherence(north_emoji, south_emoji)
var quantum_bonus = int(coherence_ab.abs() × 50)

var evolution_quality = min(1.0, berry_phase / 5.0)
var evolution_bonus = int(base_yield × evolution_quality × 0.2)

var total_yield = base_yield + quantum_bonus + evolution_bonus
```

**Advantages**:
- Population base: dimension-agnostic
- Quantum bonus: rewards superposition
- Evolution bonus: rewards cyclic dynamics
- Max ~120 credits (population=1, coherence=0.5, berry=5)

---

## For External Reviewers

### Physics Validation Checklist
- [x] Density matrix formalism correct
- [x] Master equation evolution correct
- [x] Born rule measurement correct
- [x] Hermitian constraints maintained
- [x] Trace normalization enforced
- [x] Berry phase understood correctly (corrected after user feedback)

### Known Physics Errors (Corrected)
1. ❌ **Berry phase conflated with entanglement** (quantum_classical_conversion_analysis.md)
   - Status: CORRECTED in revised analysis
   - User feedback: "what does berry phase and entanglement have to do with one another?"

2. ❌ **Dimensionality not accounted for** (initial analysis)
   - Status: CORRECTED with population-based formulas
   - User insight: "sharing a unitary space with upwards of 20 peers"

### Remaining Open Questions
1. **Should purity affect yield at all?**
   - Current: Yes (2× multiplier)
   - Revised: Implicit (via coherence bonus)
   - Question: Is purity a player-controllable resource?

2. **How should berry phase scale?**
   - Current: Linear addition (berry × 0.1)
   - Revised: Percentage bonus (berry/5 × 20%)
   - Question: What's realistic berry phase range? [0, 10]? [0, 100]?

3. **Should different biomes have different yields?**
   - Current: Same formula all biomes
   - Proposed: Biome-specific multipliers
   - Question: How to balance biome diversity vs fairness?

---

For game mechanics documentation, see sibling directory's [README.md](../game_mechanics/README.md).
