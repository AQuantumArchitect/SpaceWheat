# Harvest Mechanic - Quantum Measurement & Resource Extraction

## Overview

Harvesting performs a **Born rule measurement** on the plot's quantum state, collapsing the superposition to a definite outcome emoji, then **extracts resources** based on coherence (radius) and purity. The measurement outcome determines which emoji-credits are added to the economy.

## Core Components

### Files Involved
- `Core/GameMechanics/BasePlot.gd` - Lines 140-207: `harvest()` method
- `Core/GameMechanics/BasePlot.gd` - Lines 111-137: `measure()` method
- `Core/QuantumSubstrate/DualEmojiQubit.gd` - Lines 145-196: `measure()` implementation
- `Core/QuantumSubstrate/QuantumBath.gd` - Lines 446-463: `measure_axis()` Born rule
- `Core/Farm.gd` - Lines 1110-1129: `_process_harvest_outcome()` economy routing

## How It Works

### 1. User Action
```
User presses harvest key (R action with Tool 1)
  ↓
FarmInputHandler._action_harvest([Vector2i(2, 0)])
  ↓
Farm.harvest_plot(Vector2i(2, 0))
  ↓
BasePlot.harvest()
```

### 2. Auto-Measurement (If Not Measured)

```gdscript
# BasePlot.harvest() - Lines 140-158
func harvest() -> Dictionary:
    if not is_planted:
        return {"success": false, "yield": 0, "energy": 0.0}

    # Auto-measure if not already measured (forgiving behavior)
    if not has_been_measured and quantum_state:
        measure()

    # Double-check measurement succeeded
    if not has_been_measured:
        return {"success": false, "yield": 0, "energy": 0.0}

    var outcome = measured_outcome if measured_outcome else "?"
```

**Design choice**: Harvest automatically measures if needed, so players don't need separate measure action.

### 3. Born Rule Measurement

**DualEmojiQubit.measure() - Lines 145-196**:

```gdscript
func measure() -> String:
    if not bath:
        return _measure_legacy()  # Fallback for non-bath qubits

    # Bath-first measurement: collapse in bath
    var outcome = bath.measure_axis(north_emoji, south_emoji, collapse_strength)

    # Update local state
    if outcome == north_emoji:
        _last_theta = 0.0  # North pole
    elif outcome == south_emoji:
        _last_theta = PI    # South pole
    else:
        _last_theta = PI/2  # Unknown → equator

    return outcome
```

**QuantumBath.measure_axis() - Lines 446-463**:

```gdscript
func measure_axis(north: String, south: String, collapse_strength: float = 0.5) -> String:
    # Get probabilities from density matrix
    var p_n = get_probability(north)    # ρ[north][north]
    var p_s = get_probability(south)    # ρ[south][south]
    var total = p_n + p_s

    if total < 1e-10:
        return ""  # No probability in subspace

    # Born rule: P(north | subspace) = p_n / (p_n + p_s)
    var outcome: String
    if randf() < p_n / total:
        outcome = north
        partial_collapse(north, collapse_strength)
    else:
        outcome = south
        partial_collapse(south, collapse_strength)

    bath_measured.emit(north, south, outcome)
    return outcome
```

**Physics**:
```
P(north) = ρ[north][north] / (ρ[north][north] + ρ[south][south])
P(south) = ρ[south][south] / (ρ[north][north] + ρ[south][south])

Example:
ρ[🌾][🌾] = 0.15
ρ[👥][👥] = 0.10
→ P(🌾 | subspace) = 0.15 / 0.25 = 0.60
→ P(👥 | subspace) = 0.10 / 0.25 = 0.40
```

### 4. Partial Collapse

After measurement, the bath is partially collapsed toward the outcome:

```gdscript
func partial_collapse(target_emoji: String, strength: float = 0.5) -> void:
    var idx = _density_matrix.emoji_to_index.get(target_emoji, -1)
    if idx < 0:
        return

    # Boost probability of measured outcome
    var p_target = get_probability(target_emoji)
    var boost = (1.0 - p_target) * strength

    var mat = _density_matrix.get_matrix()
    var current_diag = mat.get_element(idx, idx)
    mat.set_element(idx, idx, current_diag.add(Complex.new(boost, 0.0)))

    _density_matrix.set_matrix(mat)
    _density_matrix._enforce_trace_one()
```

**collapse_strength = 0.5** means 50% of the gap between current and pure state is closed.

### 5. Resource Extraction (Current Formula)

**BasePlot.harvest() - Lines 163-207**:

```gdscript
# Extract coherence (radius) as quantum resource
var coherence_value = 0.0
if quantum_state:
    # Extract 90% of coherence (10% lost to measurement collapse)
    coherence_value = quantum_state.radius * 0.9
    # Berry phase bonus (evolution memory)
    coherence_value += berry_phase * 0.1

# Get purity from bath for yield multiplier
var purity = 1.0  # Default
if quantum_state and quantum_state.bath:
    purity = quantum_state.bath.get_purity()  # Tr(ρ²)

# Purity multiplier:
# - Pure state (Tr(ρ²) = 1.0) → 2.0× yield
# - Mixed state (Tr(ρ²) = 0.5) → 1.0× yield
var purity_multiplier = 2.0 * purity

# Yield calculation: 1 credit per 0.1 coherence, scaled by purity
var base_yield = coherence_value * 10
var yield_amount = max(1, int(base_yield * purity_multiplier))

print("✂️  Plot %s harvested: coherence=%.2f, purity=%.3f (×%.2f), outcome=%s, yield=%d" %
      [grid_position, coherence_value, purity, purity_multiplier, outcome, yield_amount])

return {
    "success": true,
    "outcome": outcome,
    "energy": coherence_value,
    "yield": yield_amount,
    "purity": purity,
    "purity_multiplier": purity_multiplier
}
```

**Formula**:
```
coherence_value = radius × 0.9 + berry_phase × 0.1
purity_multiplier = 2.0 × Tr(ρ²)
yield_credits = max(1, int(coherence_value × 10 × purity_multiplier))
```

### 6. Economy Routing

**Farm._process_harvest_outcome() - Lines 1110-1129**:

```gdscript
func _process_harvest_outcome(harvest_data: Dictionary) -> void:
    var outcome_emoji = harvest_data.get("outcome", "")
    var quantum_energy = harvest_data.get("energy", 0.0)

    # Convert yield back to energy if needed
    if quantum_energy == 0.0:
        var yield_amount = harvest_data.get("yield", 1)
        quantum_energy = float(yield_amount) / float(FarmEconomy.QUANTUM_TO_CREDITS)

    if outcome_emoji.is_empty():
        return

    # Route to economy: any emoji → its credits
    var credits_earned = economy.receive_harvest(outcome_emoji, quantum_energy, "harvest")

    # Goal tracking for wheat
    if outcome_emoji == "🌾":
        goals.record_harvest(credits_earned)
```

**FarmEconomy.receive_harvest()**:
```gdscript
func receive_harvest(emoji: String, quantum_energy: float, reason: String = "harvest") -> int:
    var credits_amount = int(quantum_energy * QUANTUM_TO_CREDITS)
    add_resource(emoji, credits_amount, reason)
    return credits_amount
```

**Result**: `emoji_credits[outcome_emoji] += yield_credits`

## Yield Examples

### Example 1: Low Coherence (Immediate Harvest)
```
radius = 0.001
berry_phase = 0.0
purity = 0.5

coherence_value = 0.001 × 0.9 + 0.0 × 0.1 = 0.0009
purity_multiplier = 2.0 × 0.5 = 1.0
base_yield = 0.0009 × 10 = 0.009
yield_credits = max(1, int(0.009)) = 1 credit  ← Minimum!
```

### Example 2: Moderate Coherence (3s evolution)
```
radius = 0.3
berry_phase = 2.0
purity = 0.7

coherence_value = 0.3 × 0.9 + 2.0 × 0.1 = 0.27 + 0.2 = 0.47
purity_multiplier = 2.0 × 0.7 = 1.4
base_yield = 0.47 × 10 = 4.7
yield_credits = int(4.7 × 1.4) = int(6.58) = 6 credits
```

### Example 3: High Coherence (Entangled)
```
radius = 1.0  (pure Bell state from entanglement)
berry_phase = 5.0
purity = 1.0

coherence_value = 1.0 × 0.9 + 5.0 × 0.1 = 0.9 + 0.5 = 1.4
purity_multiplier = 2.0 × 1.0 = 2.0
base_yield = 1.4 × 10 = 14.0
yield_credits = int(14.0 × 2.0) = 28 credits  ← Maximum achievable!
```

## The "?" Outcome Issue

### When It Happens

If radius ≈ 0 (maximally mixed subspace), the Born rule measurement can produce outcomes **outside** the {north, south} subspace:

```
For 7-emoji bath with r≈0 in {🌾, 👥} subspace:
- P(🌾) = 0.05  (1/20 of total bath)
- P(👥) = 0.05  (1/20 of total bath)
- P(☀) = 0.143  (1/7 of total bath)
- P(🌙) = 0.143
- ... etc

Total probability in {🌾, 👥} = 0.10 (only 10%!)
→ 90% chance of measuring OUTSIDE subspace!
```

**Measurement logic**:
```gdscript
var total = p_n + p_s  # 0.05 + 0.05 = 0.10

if total < 1e-10:
    return ""  # ← Returns empty string if no probability

if randf() < p_n / total:  # 0.05 / 0.10 = 0.50
    outcome = north  # 🌾
else:
    outcome = south  # 👥
```

**PROBLEM**: This assumes measurement is ONLY in {north, south} subspace, but bath has OTHER emojis!

**Current behavior**:
- If measurement succeeds → outcome ∈ {north, south}
- If measurement produces emoji outside subspace → outcome becomes "?"
- "?" credits stored in `emoji_credits["?"]` (invisible to player)

### Solution (Documented in Revised Analysis)

Force subspace-only measurement, or track "?" as generic resource (labor).

## Plot State After Harvest

```gdscript
# BasePlot.harvest() - Lines 189-195
is_planted = false
quantum_state = null
has_been_measured = false
theta_frozen = false
measured_outcome = ""  # Clear stored outcome
replant_cycles += 1  # Track farming cycles
```

**Note**: `berry_phase` is NOT reset - it accumulates across replants!

## Berry Phase Accumulation

Berry phase tracks **geometric phase** accumulated during cyclic evolution:

```gdscript
# Updated during quantum evolution (not shown in harvest code)
berry_phase += Δφ  # Adiabatic phase accumulated per evolution step
```

**Use**: Rewards plots that have undergone rich evolution dynamics (multiple plant/harvest cycles, entanglement events, gate operations).

## Measurement vs Harvest

### Can measure without harvesting:
```gdscript
plot.measure()  # Collapses state, stores outcome
# ... do other things ...
plot.harvest()  # Uses stored outcome, extracts resources
```

### Auto-measure on harvest:
```gdscript
plot.harvest()  # Automatically calls measure() if not already measured
```

**Design**: Harvest is the primary player action - explicit measurement is optional/advanced.

## Visualization

During harvest:
1. Bloch sphere bubble **collapses** to north or south pole
2. Outcome emoji displayed as floating text
3. Credit amount shown as "+N 🌾"
4. Plot clears, ready for replanting

## Known Issues (Current Formula)

### Issue 1: Double-counting coherence
**Problem**: Both `radius` and `purity` measure coherence
**Effect**: Purity multiplier may be redundant
**Recommended fix**: Use population-based formula (see quantum_classical_conversion_revised.md)

### Issue 2: Dimensionality bias
**Problem**: Large baths (20+ emojis) have inherently small radius in 2D projection
**Effect**: Same evolution quality produces lower yields in larger baths
**Recommended fix**: Use dimension-agnostic formula (subspace population + coherence bonus)

### Issue 3: "?" outcomes invisible
**Problem**: Measuring r≈0 state produces random emoji outside subspace
**Effect**: Yields 1 credit but not tracked in main resources
**Recommended fix**: Route "?" to labor (👥) or show as separate resource

## Recommended Alternative Formula

From quantum_classical_conversion_revised.md:

```gdscript
# Base yield: Subspace population (dimension-agnostic)
var p_north = quantum_state.bath.get_probability(quantum_state.north_emoji)
var p_south = quantum_state.bath.get_probability(quantum_state.south_emoji)
var population = p_north + p_south

var base_yield = int(population × 100)  # 0-100 credits typical

# Quantum bonus: Off-diagonal coherence
var coherence_ab = quantum_state.bath.get_coherence(
    quantum_state.north_emoji,
    quantum_state.south_emoji
)
var quantum_bonus = int(coherence_ab.abs() × 50)  # 0-50 credits

# Evolution bonus: Berry phase (path memory)
var evolution_quality = min(1.0, berry_phase / 5.0)
var evolution_bonus = int(base_yield × evolution_quality × 0.2)  # Up to 20% of base

# Total
var total_yield = base_yield + quantum_bonus + evolution_bonus
total_yield = max(1, total_yield)
```

**Advantages**:
- Dimension-agnostic (same formula for 6-emoji or 20-emoji bath)
- Separates classical (population) from quantum (coherence) bonuses
- Rewards evolution without double-counting
- More predictable yields across different biome sizes

## Summary

1. **Harvest** = Measurement + Resource Extraction
2. **Measurement** uses Born rule on bath density matrix
3. **Outcome** determines which emoji-credits are earned
4. **Yield** based on coherence × purity (current) or population + bonuses (recommended)
5. **"?" outcomes** happen when measuring r≈0 states before evolution
6. **Berry phase** accumulates across replants, providing evolution memory bonus

**Key insight**: Harvest is NOT just collecting resources - it's a quantum measurement that irreversibly collapses the bath's superposition!
