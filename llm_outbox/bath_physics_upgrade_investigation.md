# Bath Physics Upgrade Investigation

## Executive Summary

The QuantumBath has been **completely rewritten with proper quantum mechanics**. The old "energy as stored property" model is **deprecated**. Icons' Lindblad terms and energy couplings need review to align with the new amplitude-based evolution.

**Key Changes:**
1. **Energy is now derived** from theta (excitation level), not stored
2. **Radius is coherence** (quantum purity), separate from energy
3. **Lindblad operates on amplitudes**, not energy
4. **Energy couplings affect radius** (coherence growth/decay), not energy directly

---

## 🆕 New Bath Physics Model

### Core Representation

The bath is now a **proper quantum state vector**:

```
|ψ⟩ = Σᵢ αᵢ |emoji_i⟩
```

Where:
- `αᵢ` = Complex amplitude for emoji i
- `|αᵢ|²` = Probability (population) of emoji i
- `Σ |αᵢ|²` = 1.0 (normalized)

**Storage:**
```gdscript
var amplitudes: Array[Complex] = []  # The quantum state
var emoji_list: Array[String] = []   # Basis labels
```

### Evolution Equation

The bath evolves via **Hamiltonian + Lindblad**:

```
d|ψ⟩/dt = -iH|ψ⟩ + Lindblad[|ψ⟩]
```

**Layer 1: Hamiltonian (Unitary)**
```gdscript
# Apply: |ψ(t+dt)⟩ ≈ (I - iH dt) |ψ(t)⟩
for i in hamiltonian_sparse:
    for j in hamiltonian_sparse[i]:
        var H_ij: Complex = hamiltonian_sparse[i][j]
        var contrib = (-i * H_ij * dt) * amplitudes[j]
        new_amplitudes[i] += contrib
```

**Layer 2: Lindblad (Dissipative)**
```gdscript
# Transfer amplitude from source to target
for term in lindblad_terms:
    var transfer_factor = sqrt(rate * dt)
    var damping_factor = sqrt(1.0 - rate * dt)

    amplitudes[target] += amplitudes[source] * transfer_factor
    amplitudes[source] *= damping_factor
```

**Normalization:**
After each step, `Σ |αᵢ|²` is renormalized to 1.0

---

## 🔄 Energy Model Change

### Old Model (DEPRECATED)

```gdscript
class DualEmojiQubit:
    var energy: float = 0.5  # Stored property
    var radius: float = 0.3  # Coherence

    # Energy and radius were coupled/synchronized
```

**Problem:** Energy and radius are **independent quantum properties**!

### New Model (CURRENT)

```gdscript
class DualEmojiQubit:
    var theta: float  # Bloch sphere polar angle
    var phi: float    # Bloch sphere azimuthal angle
    var radius: float # Coherence (0-1)

    # Energy derived from theta
    var energy: float:
        get: return get_south_probability()  # sin²(θ/2)
        set: theta = 2.0 * asin(sqrt(value)) # Convert back
```

**Separation of concerns:**
- **Energy (excitation)** = How excited the state is (ground vs excited)
  - Derived from `theta`: sin²(θ/2)
  - θ=0 (north pole) = ground state = energy=0
  - θ=π (south pole) = excited state = energy=1
  - θ=π/2 (equator) = superposition = energy=0.5

- **Radius (coherence)** = How quantum vs classical
  - Independent variable (0-1)
  - radius=1 = pure quantum state (fully coherent)
  - radius=0 = completely decohered
  - Grows/decays based on environment

**Physics analogy:**
- Think of a hot atom (excited) that's also pure (coherent)
- Or a cold atom (ground state) that's also mixed (decohered)
- These are orthogonal properties!

---

## 📊 Projection Update Mechanism

### How Projections Work

When a plot is planted as `🌾↔👥`:

1. **Create projection from bath:**
   ```gdscript
   var proj = bath.project_onto_axis("🌾", "👥")
   # Returns: {theta, phi, radius, valid}
   ```

2. **Project bath amplitudes onto 2D axis:**
   ```gdscript
   # Get amplitudes
   var α_wheat = bath.get_amplitude("🌾")  # Complex
   var α_labor = bath.get_amplitude("👥")  # Complex

   # Total in this subspace
   var total = |α_wheat|² + |α_labor|²
   var radius = sqrt(total)  # "Spirit" in this subspace

   # Theta from north/south balance
   var north_fraction = |α_wheat| / radius
   var theta = 2 * arccos(north_fraction)

   # Phi from relative phase
   var phi = arg(α_wheat) - arg(α_labor)
   ```

3. **Every frame, re-sync projection with bath:**
   ```gdscript
   func update_projections(dt):
       for position in active_projections:
           var proj = bath.project_onto_axis(north, south)
           qubit.theta = proj.theta  # Sync angles
           qubit.phi = proj.phi

           # Radius evolves independently
           var growth = _get_lindblad_growth_rate(north)
           var coupling = evaluate_energy_coupling(north, bath_obs)
           qubit.radius *= exp((growth + coupling) * dt)
   ```

---

## 🔗 Energy Coupling Mechanism

### Definition (Icon.energy_couplings)

```gdscript
# Example: Mushroom Icon
mushroom.energy_couplings = {
    "☀": -0.20,  # Damage from sun (negative = harmful)
    "🌙": +0.40   # Growth from moon (positive = beneficial)
}
```

### Evaluation

For a mushroom projection at position (x, y):

```gdscript
var env_coupling = 0.0

# Query bath state
var P_sun = bath.get_probability("☀")   # e.g., 0.8 (daytime)
var P_moon = bath.get_probability("🌙") # e.g., 0.2 (daytime)

# Compute weighted sum
env_coupling = (-0.20 * 0.8) + (+0.40 * 0.2)
             = -0.16 + 0.08
             = -0.08  # Net damage during day
```

### Application to Radius

```gdscript
# Radius = coherence/purity
qubit.radius *= exp(env_coupling * dt)
```

**If coupling is negative:** radius decays (decoherence)
**If coupling is positive:** radius grows (recoherence)

**Physical interpretation:**
- Sun damages mushrooms → coherence decays → becomes "more classical"
- Moon helps mushrooms → coherence grows → becomes "more quantum"

---

## ⚠️ Icon Lindblad Terms Review

### Current Definitions (CoreIcons.gd)

#### 🌾 Wheat
```gdscript
wheat.lindblad_incoming = {
    "☀": 0.08,  # Grows from sunlight
    "💧": 0.05, # Grows from water
    "⛰": 0.02  # Draws from soil
}
wheat.decay_rate = 0.02
wheat.decay_target = "🍂"
```

#### 🍄 Mushroom
```gdscript
mushroom.lindblad_incoming = {
    "🌙": 0.06,  # Grows from moon influence
    "🍂": 0.12   # Grows from organic matter
}
mushroom.decay_rate = 0.03
mushroom.decay_target = "🍂"
```

### How Lindblad Works in New Bath

**Old interpretation (WRONG):**
"Wheat gains energy from sun at rate 0.08/sec"

**New interpretation (CORRECT):**
"Bath amplitude transfers from ☀ to 🌾 at rate 0.08/sec"

```gdscript
# Evolution step
var source_idx = emoji_to_index["☀"]   # Sun
var target_idx = emoji_to_index["🌾"]  # Wheat
var rate = 0.08

# Transfer amplitude
var transfer_factor = sqrt(rate * dt)
var damping_factor = sqrt(1.0 - rate * dt)

amplitudes[target] += amplitudes[source] * transfer_factor
amplitudes[source] *= damping_factor
```

**Effect:**
- Sun amplitude decreases (at rate `sqrt(0.08 * dt)`)
- Wheat amplitude increases (gains from sun)
- After normalization: P(wheat) ↑, P(sun) ↓
- BUT sun is eternal (is_eternal=true) so gets reset each frame

### Eternal Emojis (Drivers)

Icons with `is_eternal = true`:
- ☀ Sun
- 🌙 Moon
- 💧 Water
- ⛰ Soil

**These act as infinite reservoirs:**
- Lindblad can drain from them without depleting
- Effectively: external driving fields

---

## 🎯 Recommended Lindblad Adjustments

### Issue 1: Transfer Rates Too High?

Current rates like `0.08`, `0.12` transfer **8-12% of amplitude per second**.

**In quantum mechanics:**
```
Transfer factor = sqrt(rate * dt)
For rate=0.08, dt=0.016 (60 FPS):
  transfer ≈ sqrt(0.08 * 0.016) ≈ 0.0357 = 3.57% per frame
```

**Over 1 second (60 frames):**
```
Total transfer ≈ 1 - (1 - 0.0357)^60 ≈ 88% of amplitude!
```

**This is VERY fast!** Wheat would reach steady state in ~1 second.

**Recommendation:**
Scale down Lindblad rates by 10-100x:

```gdscript
wheat.lindblad_incoming = {
    "☀": 0.008,  # Was 0.08 → 10x slower
    "💧": 0.005, # Was 0.05
    "⛰": 0.002  # Was 0.02
}
```

### Issue 2: Decay Rates

```gdscript
wheat.decay_rate = 0.02  # 2% amplitude/sec to 🍂
mushroom.decay_rate = 0.03  # 3% amplitude/sec to 🍂
```

**Over 10 seconds:**
```
Wheat: 1 - (1 - sqrt(0.02 * 0.016))^600 ≈ 58% decays
```

**This seems reasonable** for natural decay (plants die over time).

**Recommendation:** Keep decay rates, but clarify they're in amplitude units, not energy.

### Issue 3: Energy Couplings (These are fine!)

```gdscript
wheat.energy_couplings = {
    "☀": +0.08,  # Grows from sun (positive coupling)
    "💧": +0.05  # Grows from water (positive coupling)
}

mushroom.energy_couplings = {
    "☀": -0.20,  # Damage from sun (negative coupling)
    "🌙": +0.40   # Growth from moon (positive coupling)
}
```

**These affect radius (coherence), not amplitude:**
```gdscript
qubit.radius *= exp(coupling * dt)
```

**For mushroom during day:**
```
P(☀) = 0.8, P(🌙) = 0.2
coupling = (-0.20 * 0.8) + (+0.40 * 0.2) = -0.08
radius *= exp(-0.08 * 0.016) ≈ 0.9987  # Slight decay per frame
```

**Over 10 seconds (600 frames):**
```
radius *= 0.9987^600 ≈ 0.45  # Halved coherence
```

**This is good!** Mushrooms get "fuzzy" (decohered) during day, but don't disappear.

**Recommendation:** Keep energy couplings as-is. They're well-balanced.

---

## 📋 Detailed Icon Analysis

### ✅ Working Well

#### Energy Couplings (All Icons)
- **Scale:** 0.05-0.40 range is appropriate
- **Balance:** Sun/moon opposition works correctly
- **Physics:** Affects coherence (radius), not population
- **Verdict:** **NO CHANGES NEEDED**

#### Hamiltonian Couplings
- **Sun ↔ Moon:** 0.8 (strong opposition) ✅
- **Sun → Wheat:** 0.4 (moderate) ✅
- **Moon → Mushroom:** 0.6 (strong) ✅
- **Verdict:** **NO CHANGES NEEDED**

#### Drivers (Time-Dependent Self-Energy)
- **Sun:** cosine, 0.05 Hz, amplitude 1.0 ✅
- **Moon:** sine, 0.05 Hz, amplitude 1.0, phase π ✅
- **Bull/Bear:** 30s oscillation ✅
- **Fire/Cold:** 15s oscillation ✅
- **Verdict:** **NO CHANGES NEEDED**

---

### ⚠️ Needs Adjustment

#### Lindblad Incoming Rates

**Current scale:** 0.02-0.12 (too fast for smooth gameplay)

**Recommended scale:** 0.002-0.012 (10x slower)

| Icon | Emoji | Old Rate | New Rate | Reasoning |
|------|-------|----------|----------|-----------|
| Wheat | ☀ → 🌾 | 0.08 | **0.008** | 10x slower growth |
| Wheat | 💧 → 🌾 | 0.05 | **0.005** | 10x slower |
| Wheat | ⛰ → 🌾 | 0.02 | **0.002** | 10x slower |
| Mushroom | 🌙 → 🍄 | 0.06 | **0.006** | 10x slower |
| Mushroom | 🍂 → 🍄 | 0.12 | **0.012** | 10x slower |
| Vegetation | ☀ → 🌿 | 0.10 | **0.010** | 10x slower |
| Vegetation | 💧 → 🌿 | 0.06 | **0.006** | 10x slower |
| Vegetation | 🍂 → 🌿 | 0.04 | **0.004** | 10x slower |
| Wolf | 🐇 → 🐺 | 0.15 | **0.015** | Predation rate |
| Wolf | 🦌 → 🐺 | 0.12 | **0.012** | Predation rate |
| Rabbit | 🌿 → 🐇 | 0.10 | **0.010** | Herbivory rate |
| Deer | 🌿 → 🦌 | 0.08 | **0.008** | Herbivory rate |
| Eagle | 🐇 → 🦅 | 0.10 | **0.010** | Predation rate |
| Seedling | 🌱 → 🌿 | 0.08 | **0.008** | Growth into vegetation |

**Rationale:**
With 10x slower rates:
- Wheat takes ~10 seconds to grow from sun (was ~1 second)
- Mushrooms take ~15 seconds to mature (was ~1.5 seconds)
- Gives player time to observe quantum dynamics
- Matches typical farming game pacing

---

#### Lindblad Outgoing Rates

**Current rates:** Very few Icons have outgoing (most use decay)

| Icon | Transfer | Old Rate | New Rate | Notes |
|------|----------|----------|----------|-------|
| Seedling | 🌱 → 🌿 | 0.08 | **0.008** | Already in incoming |
| Death | 💀 → 🍂 | 0.05 | **0.005** | Slow decay to organic |
| Money | 💰 → 📦 | 0.05 | **0.005** | Trading |
| Goods | 📦 → 💰 | 0.04 | **0.004** | Trading |
| Chaotic | 🏚️ → 🏛️ | 0.03 | **0.003** | Order emerges from chaos |

**Same 10x reduction for consistency.**

---

#### Decay Rates (Keep as-is, but clarify)

| Icon | Emoji | Rate | Target | Verdict |
|------|-------|------|--------|---------|
| Wheat | 🌾 | 0.02 | 🍂 | ✅ OK |
| Mushroom | 🍄 | 0.03 | 🍂 | ✅ OK |
| Vegetation | 🌿 | 0.025 | 🍂 | ✅ OK |
| Seedling | 🌱 | 0.04 | 🍂 | ✅ OK (fragile) |
| Wolf | 🐺 | 0.03 | 💀 | ✅ OK |
| Rabbit | 🐇 | 0.05 | 💀 | ✅ OK (prey dies faster) |

**Note:** Decay rates are in amplitude units, but 0.02-0.05 scale is appropriate.

---

## 🎮 Gameplay Impact Analysis

### Before Adjustment (Current)

**Plant wheat → Maturity:**
- Lindblad incoming: 0.08/sec from ☀
- Over 1 second: ~88% of max amplitude reached
- **Too fast!** Player barely sees growth

**Mushroom at night:**
- Lindblad incoming: 0.06/sec from 🌙
- Over 1.5 seconds: ~88% of max amplitude
- **Too fast!** No strategic depth

**Market sentiment:**
- Bull/Bear oscillation: 30s period ✅
- But 💰→📦 transfer at 0.05/sec
- Over 6 seconds: ~88% of money → goods
- **Too fast!** Market feels chaotic

### After Adjustment (10x slower)

**Plant wheat → Maturity:**
- Lindblad incoming: 0.008/sec from ☀
- Over 10 seconds: ~88% of max amplitude
- **Good!** Player sees gradual growth

**Mushroom at night:**
- Lindblad incoming: 0.006/sec from 🌙
- Over 15 seconds: ~88% of max amplitude
- **Good!** Strategic planting timing matters

**Market sentiment:**
- 💰→📦 transfer at 0.005/sec
- Over 60 seconds: ~88% conversion
- **Good!** Predictable, strategic trading

---

## 🔧 Recommended Changes

### Option A: Simple 10x Scale (RECOMMENDED)

Multiply all `lindblad_incoming` and `lindblad_outgoing` rates by 0.1:

```gdscript
# CoreIcons.gd - Wheat
wheat.lindblad_incoming = {
    "☀": 0.008,  # Was 0.08
    "💧": 0.005, # Was 0.05
    "⛰": 0.002  # Was 0.02
}

# CoreIcons.gd - Mushroom
mushroom.lindblad_incoming = {
    "🌙": 0.006,  # Was 0.06
    "🍂": 0.012   # Was 0.12
}

# ... etc for all Icons
```

**Pros:**
- Simple scaling factor
- Preserves relative rates
- Easy to tune further

**Cons:**
- Requires editing every Icon

---

### Option B: Add Global Scale Factor

Add a tunable constant to QuantumBath:

```gdscript
# QuantumBath.gd
const LINDBLAD_SCALE = 0.1  # Global scaling

func build_lindblad_from_icons(icons):
    # ...
    lindblad_terms.append({
        "source": s,
        "target": t,
        "rate": icon.lindblad_incoming[source] * LINDBLAD_SCALE
    })
```

**Pros:**
- Single tuning knob
- Easy to experiment with
- No Icon editing needed

**Cons:**
- Hides actual rates in Icon definitions
- Harder to reason about individual rates

---

### Option C: Time-Dependent Scaling

Scale rates based on gameplay phase:

```gdscript
# BiomeBase.gd
func get_lindblad_scale() -> float:
    # Early game: slow (0.05x)
    # Mid game: medium (0.1x)
    # Late game: fast (0.2x)
    var progression = farm.get_progression_level()
    return lerp(0.05, 0.2, progression)
```

**Pros:**
- Dynamic difficulty scaling
- Matches player skill/impatience

**Cons:**
- Complex to balance
- Harder to debug

---

## 📊 Summary Table

| Component | Status | Action |
|-----------|--------|--------|
| **Hamiltonian** (couplings) | ✅ Good | Keep as-is |
| **Hamiltonian** (self-energy) | ✅ Good | Keep as-is |
| **Hamiltonian** (drivers) | ✅ Good | Keep as-is |
| **Lindblad incoming** | ⚠️ Too fast | **Scale down 10x** |
| **Lindblad outgoing** | ⚠️ Too fast | **Scale down 10x** |
| **Decay rates** | ✅ Good | Keep as-is (clarify units) |
| **Energy couplings** | ✅ Good | Keep as-is |

---

## 🎯 Next Steps

1. **Decide on scaling approach** (A, B, or C)
2. **Implement Lindblad rate adjustment**
3. **Test gameplay pacing** with new rates
4. **Document amplitude vs energy** in Icon.gd comments
5. **Add unit tests** for bath evolution rates
6. **Create visual debug overlay** to show Lindblad flows

Would you like me to implement Option A (direct 10x scaling) or Option B (global scale factor)?
