# Quantum ↔ Classical Resource Conversion Analysis

## Current Situation

### Conversion Formula

```gdscript
// BasePlot.harvest() - Lines 164-189
var coherence_value = quantum_state.radius * 0.9  // Extract 90% of coherence
coherence_value += berry_phase * 0.1  // Entanglement bonus

var purity = quantum_state.bath.get_purity()  // Tr(ρ²)
var purity_multiplier = 2.0 * purity  // Pure=2.0×, Mixed=1.0×

var base_yield = coherence_value * 10  // Credits
var yield_amount = max(1, int(base_yield * purity_multiplier))  // Min 1 credit
```

**Final formula:**
```
yield_credits = max(1, (radius × 0.9 + berry_phase × 0.1) × 10 × (2.0 × purity))
```

### Conversion Rate

```gdscript
// FarmEconomy.gd
const QUANTUM_TO_CREDITS = 10

1 quantum energy unit = 10 credits
1 credit = 0.1 quantum energy units
```

### Economy Storage

```gdscript
// FarmEconomy.gd
var emoji_credits: Dictionary = {
    "🌾": 500,  // 50 wheat units
    "👥": 10,   // 1 labor unit
    "🍄": 10,   // 1 mushroom unit
    // ... all emojis stored as credits (10× quantum units)
}
```

### Harvest Flow

```
1. QUANTUM STATE (in bath)
   ├─ radius: 0.5 (coherence)
   ├─ purity: 0.75 (Tr(ρ²))
   └─ theta: π/2 (outcome selector)

2. MEASUREMENT (Born rule)
   ├─ Collapse to outcome emoji (🌾 or 👥)
   └─ Store in plot.measured_outcome

3. EXTRACTION (harvest)
   ├─ coherence_value = 0.5 × 0.9 = 0.45
   ├─ purity_multiplier = 2.0 × 0.75 = 1.5
   ├─ base_yield = 0.45 × 10 = 4.5
   └─ yield_credits = int(4.5 × 1.5) = 6 credits

4. CLASSICAL STORAGE (economy)
   ├─ outcome="🌾" → add to emoji_credits["🌾"]
   └─ emoji_credits["🌾"] += 6 credits
```

---

## Issues with Current System

### 1. **Low Yields from Realistic Coherence**

**Problem:** Typical quantum states have radius 0.1-0.5, producing very low yields.

```
radius=0.1, purity=0.5:
  yield = max(1, (0.1 × 0.9 × 10 × (2.0 × 0.5)))
        = max(1, 0.9)
        = 1 credit  ← Minimum!

radius=0.3, purity=0.7:
  yield = (0.3 × 0.9 × 10 × 1.4)
        = 3.78
        = 3 credits  ← Still very low

radius=1.0, purity=1.0 (pure state):
  yield = (1.0 × 0.9 × 10 × 2.0)
        = 18 credits  ← Maximum possible
```

**Consequence:** Players must wait 5+ seconds for coherence to build, or use entanglement for r=1 states.

---

### 2. **Purity Multiplier is Misleading**

**Problem:** Purity Tr(ρ²) measures quantum vs classical mixing, NOT resource quality.

**Current logic:**
```gdscript
purity_multiplier = 2.0 * purity
```

**What this means:**
- Pure state (Tr(ρ²) = 1.0) → 2.0× multiplier
- Maximally mixed (Tr(ρ²) = 0.5) → 1.0× multiplier

**Why this is problematic:**
- A maximally mixed state (r=0, purity=0.5) should give **zero** yield, not 1×!
- A pure state (r=1, purity=1.0) should give base yield, not 2×
- Purity and radius are **correlated** (both measure coherence), so you're double-counting

**Mathematical relationship:**
```
For 2D subspace projection:
purity ≈ 0.5 + 0.5 × radius²  (approximately)

radius=0 → purity≈0.5 (maximally mixed 2-state)
radius=1 → purity≈1.0 (pure state)
```

So multiplying by both radius AND purity is redundant!

---

### 3. **Berry Phase is Underutilized**

**Current:**
```gdscript
coherence_value += berry_phase * 0.1
```

**Problem:** Berry phase can accumulate to 10.0, but only contributes max 1.0 to coherence.

**Missed opportunity:**
- Berry phase tracks **geometric phase** accumulated during quantum evolution
- Could be used as a **multiplier** for entanglement bonus, not just additive
- Could track **cyclic evolution quality** (how long plot has been entangled/evolved)

---

### 4. **Unknown Emoji "?" Gives Minimal Credits**

**Current behavior:**
```gdscript
if outcome == "?":
    emoji_credits["?"] = (emoji_credits.get("?", 0) + yield_credits)
    // "?" emoji not tracked in main resources
```

**Problem:** Unknown outcome ("?") from low-coherence harvest gives credits that don't show up in resource panel!

**Why this happens:**
- If radius ≈ 0, measurement is random across ALL bath emojis
- Outcome might be emoji not in {north, south} projection
- Economy.receive_harvest() adds to emoji_credits["?"]
- But ResourcePanel only tracks specific emojis (🌾, 👥, 🍄, etc.)

---

### 5. **No Incentive for High Purity**

**Current:** Purity gives 2× max multiplier, but most states have purity 0.5-0.7.

**Problem:** Players can't easily control purity - it's determined by bath evolution.

**What players CAN control:**
- Coherence (via evolution time, entanglement, or coupling strength)
- Theta (via Hamiltonian dynamics)
- Berry phase (via entanglement/evolution cycles)

**What players CANNOT control:**
- Purity (determined by bath's global state, not plot-specific)

So why penalize for low purity if it's not player-controllable?

---

## Recommended System

### Option A: Simplified Linear Conversion (Recommended)

**Formula:**
```gdscript
yield_credits = int(radius × QUANTUM_TO_CREDITS × base_multiplier)
```

Where:
- `radius` = coherence (0.0 to 1.0)
- `QUANTUM_TO_CREDITS` = 10 (standard conversion)
- `base_multiplier` = 1.0 (no purity penalty)

**Examples:**
```
radius=0.1:  yield = int(0.1 × 10 × 1) = 1 credit
radius=0.5:  yield = int(0.5 × 10 × 1) = 5 credits
radius=1.0:  yield = int(1.0 × 10 × 1) = 10 credits
```

**Advantages:**
- ✅ Simple and predictable
- ✅ Directly proportional to coherence (the resource players build)
- ✅ No double-counting with purity
- ✅ No minimum yield confusion

**Disadvantages:**
- ❌ Lower yields overall (max 10 instead of 18)
- ❌ No bonus for entanglement (unless via radius)

---

### Option B: Berry Phase Bonus Multiplier

**Formula:**
```gdscript
var coherence_multiplier = 1.0 + (berry_phase / 10.0)  // 1.0× to 2.0×
yield_credits = int(radius × QUANTUM_TO_CREDITS × coherence_multiplier)
```

Where:
- `berry_phase` = 0.0 to 10.0 (accumulated during entanglement/evolution)
- Gives 1.0× (no bonus) to 2.0× (max bonus)

**Examples:**
```
radius=0.5, berry_phase=0:   yield = int(0.5 × 10 × 1.0) = 5 credits
radius=0.5, berry_phase=5:   yield = int(0.5 × 10 × 1.5) = 7 credits
radius=0.5, berry_phase=10:  yield = int(0.5 × 10 × 2.0) = 10 credits
```

**Advantages:**
- ✅ Rewards entanglement (berry phase accumulates faster when entangled)
- ✅ Rewards long evolution (berry phase grows over time)
- ✅ Still simple and predictable

**Disadvantages:**
- ❌ Requires understanding berry phase mechanic
- ❌ May be too generous if berry phase accumulates quickly

---

### Option C: Purity as Quality Multiplier (Current System, but Fixed)

**Formula:**
```gdscript
var quality_multiplier = 0.5 + purity  // 1.0× to 1.5×
yield_credits = int(radius × QUANTUM_TO_CREDITS × quality_multiplier)
```

Where:
- `purity` = 0.5 to 1.0 (Tr(ρ²))
- Gives 1.0× (maximally mixed) to 1.5× (pure state)

**Examples:**
```
radius=0.5, purity=0.5:  yield = int(0.5 × 10 × 1.0) = 5 credits
radius=0.5, purity=0.75: yield = int(0.5 × 10 × 1.25) = 6 credits
radius=0.5, purity=1.0:  yield = int(0.5 × 10 × 1.5) = 7 credits
```

**Advantages:**
- ✅ Rewards pure states (achieved via entanglement or isolation)
- ✅ More modest multiplier (1.5× max instead of 2.0×)

**Disadvantages:**
- ❌ Players still can't easily control purity
- ❌ Purity and radius are correlated (redundant)

---

### Option D: Hybrid System (Berry + Purity)

**Formula:**
```gdscript
var base_yield = radius × QUANTUM_TO_CREDITS
var berry_bonus = base_yield × (berry_phase / 10.0)  // 0% to 100% bonus
var quality_bonus = base_yield × (purity - 0.5)  // 0% to 50% bonus
yield_credits = int(base_yield + berry_bonus + quality_bonus)
```

**Examples:**
```
radius=0.5, berry_phase=0, purity=0.5:
  base = 5
  berry = 0
  quality = 0
  total = 5 credits

radius=0.5, berry_phase=5, purity=0.75:
  base = 5
  berry = 2.5
  quality = 1.25
  total = 8 credits

radius=1.0, berry_phase=10, purity=1.0:
  base = 10
  berry = 10
  quality = 5
  total = 25 credits  ← Max possible
```

**Advantages:**
- ✅ Rewards all dimensions of quantum quality
- ✅ High skill ceiling (max 25 credits vs current 18)
- ✅ Balanced (modest bonuses)

**Disadvantages:**
- ❌ Complex formula
- ❌ Hard to mentally calculate expected yield

---

## Recommendations

### Primary Recommendation: **Option B (Berry Phase Bonus)**

```gdscript
// BasePlot.harvest()
func harvest() -> Dictionary:
    if not is_planted:
        return {"success": false, "yield": 0, "energy": 0.0}

    if not has_been_measured and quantum_state:
        measure()

    if not has_been_measured:
        return {"success": false, "yield": 0, "energy": 0.0}

    var outcome = measured_outcome if measured_outcome else "?"

    # Extract quantum resource (radius = coherence)
    var coherence = 0.0
    if quantum_state:
        coherence = quantum_state.radius

    # Berry phase multiplier (1.0× to 2.0×)
    var berry_multiplier = 1.0 + (berry_phase / 10.0)

    # Yield calculation
    var yield_credits = int(coherence × FarmEconomy.QUANTUM_TO_CREDITS × berry_multiplier)
    yield_credits = max(1, yield_credits)  # Minimum 1 credit

    # Clear plot
    is_planted = false
    quantum_state = null
    has_been_measured = false
    theta_frozen = false
    measured_outcome = ""
    replant_cycles += 1

    print("✂️  Plot %s harvested: coherence=%.2f, berry=%.2f (×%.2f), outcome=%s, yield=%d" % [
        grid_position, coherence, berry_phase, berry_multiplier, outcome, yield_credits])

    return {
        "success": true,
        "outcome": outcome,
        "energy": coherence,  # Legacy key - now represents coherence
        "yield": yield_credits,
        "berry_multiplier": berry_multiplier
    }
```

**Why this is best:**
1. **Simple:** `yield = radius × 10 × (1 + berry/10)`
2. **Predictable:** Players understand coherence (radius) directly converts to yield
3. **Rewards entanglement:** Berry phase grows faster when entangled
4. **Rewards evolution:** Berry phase accumulates over time
5. **Balanced:** Max 2× multiplier (not overpowered)
6. **No double-counting:** Doesn't multiply by correlated purity

---

### Secondary Recommendation: **Fix "?" Outcome Handling**

```gdscript
// Farm._process_harvest_outcome()
func _process_harvest_outcome(harvest_data: Dictionary) -> void:
    var outcome_emoji = harvest_data.get("outcome", "")
    var quantum_energy = harvest_data.get("energy", 0.0)

    if outcome_emoji.is_empty() or outcome_emoji == "?":
        # Unknown outcome - give minimal generic resource (labor)
        outcome_emoji = "👥"  # Default to labor
        quantum_energy = 0.1  # Minimal yield
        print("⚠️  Unknown harvest outcome - defaulting to 1 👥")

    # Route to economy
    economy.receive_harvest(outcome_emoji, quantum_energy, "harvest")

    # Goal tracking for wheat
    if outcome_emoji == "🌾":
        goals.record_harvest(economy.get_resource(outcome_emoji))
```

**Why:**
- Prevents "invisible" resources in emoji_credits["?"]
- Gives player something tangible even from failed harvest
- Encourages waiting for coherence to build

---

### Tertiary Recommendation: **Add Minimum Coherence Threshold**

```gdscript
// BasePlot.harvest()
const MIN_COHERENCE_FOR_MEASUREMENT = 0.05

func harvest() -> Dictionary:
    # ... existing code ...

    var coherence = quantum_state.radius if quantum_state else 0.0

    if coherence < MIN_COHERENCE_FOR_MEASUREMENT:
        print("⚠️  Plot %s: coherence too low (%.3f < %.3f) - harvest failed" % [
            grid_position, coherence, MIN_COHERENCE_FOR_MEASUREMENT])
        return {
            "success": false,
            "yield": 0,
            "energy": 0.0,
            "reason": "Insufficient coherence - wait longer or entangle"
        }

    # ... rest of harvest logic ...
```

**Why:**
- Prevents "?" outcomes from r≈0 states
- Forces players to engage with quantum mechanics (wait/entangle)
- Makes success criteria explicit

---

## Summary Table

| Option | Yield Formula | Max Yield | Complexity | Rewards |
|--------|---------------|-----------|------------|---------|
| **Current** | `r × 0.9 × 10 × (2.0 × p)` | 18 credits | Medium | Purity (misleading) |
| **A: Linear** | `r × 10` | 10 credits | Low | Coherence only |
| **B: Berry Bonus** | `r × 10 × (1 + b/10)` | 20 credits | Low | Coherence + Entanglement |
| **C: Quality** | `r × 10 × (0.5 + p)` | 15 credits | Low | Coherence + Purity |
| **D: Hybrid** | `r × 10 × (1 + b/10 + p-0.5)` | 25 credits | High | All dimensions |

**Recommendation:** **Option B (Berry Phase Bonus)** with "?" outcome fix and minimum coherence threshold.

This creates a clean quantum→classical conversion that rewards:
1. **Coherence** (radius) - the primary quantum resource
2. **Entanglement/Evolution** (berry phase) - the player's strategic choices
3. **Nothing else** - no confusing purity multipliers or double-counting
