# 🔍 Duplicate Specifications Analysis - SpaceWheat Bug Investigation

## Overview

After iterative development, several values are specified in multiple places, causing bugs when one location is updated but others aren't. This document maps all duplicate specifications for Bugs #10-#12.

---

## Bug #10: Mushroom Day/Night Cycle Not Implemented in Bath Mode

### Problem Summary
Mushrooms grow at identical rate as wheat (0.017) despite being designed to "sprout up in the night and then wither under the sun." Bath-first mode lacks the entire day/night cycle implementation that legacy mode has.

### Triple Specification Found

**SPECIFICATION #1 (Default):**
```
File: Core/Icons/CoreIcons.gd:110
mushroom.lindblad_incoming = {
    "🌙": 0.06,  # Grows from moon influence
    "🍂": 0.12   # Grows from organic matter
}
Status: OVERRIDDEN by Spec #2
```

**SPECIFICATION #2 (Override):**
```
File: Core/Environment/BioticFluxBiome.gd:257
mushroom_icon.lindblad_incoming["🌙"] = 0.40
Comment: "Match existing mushroom growth rate"
Status: SET but IGNORED by Spec #3
```

**SPECIFICATION #3 (Hardcoded - THE BUG):**
```
File: Core/Environment/BiomeBase.gd:236
var growth_rate = 0.017  # HARDCODED!
qubit.radius *= exp(growth_rate * dt)
Status: IGNORES icon's Lindblad rate entirely!
```

### Root Cause
Bath-first mode is missing the entire day/night cycle implementation. `BiomeBase.update_projections()` uses a single hardcoded growth rate (0.017) for all crops, while legacy mode has:
- Day/night sun oscillation (θ: 0→π→0 over 120s cycle)
- Wheat growth during day (`sun_brightness`)
- Mushroom growth during night (`1.0 - sun_brightness`)
- Sun damage to mushrooms during day
- Bloch sphere coupling flexibility

**Current State:** Bath mode (use_bath_mode = true) bypasses all of this (BioticFluxBiome.gd:286-290).

### Expected Behavior (Legacy Mode Works!)
```
1. Sun oscillates: θ = π + π·sin(2πt/120s)
2. Sun brightness = cos²(θ/2): 1.0 (day) → 0.0 (night)
3. Wheat: grows during day (rate * sun_brightness)
4. Mushroom: grows during night (rate * (1.0 - sun_brightness))
5. Mushroom: takes sun damage during day (0.20 * sun_brightness)
6. Result: Mushrooms "sprout up in the night and then wither under the sun"
```

### Actual Behavior (Bath Mode Missing Features!)
```
1. Bath mode enabled (use_bath_mode = true)
2. BioticFluxBiome.advance_simulation() skips all day/night cycle code (line 286-290)
3. BiomeBase.update_projections() uses hardcoded 0.017 for ALL crops (line 236)
4. No sun oscillation, no sun damage, no day/night differentiation
5. Result: Wheat and mushroom grow identically at 0.017/s
```

### Fix Strategy - AWAITING ARCHITECTURAL DECISION

**See:** `/home/tehcr33d/ws/SpaceWheat/llm_outbox/legacy_vs_bath_mode_architecture.md`

**Four Options Identified:**
1. **Port to Bath:** Implement day/night cycle in bath-first mode (HIGH RISK - complex quantum mechanics)
2. **Revert to Legacy:** Disable bath mode, use working legacy system (MEDIUM RISK - may break other biomes)
3. **Hybrid:** Bath for emojis, legacy for crops (MEDIUM-HIGH RISK - two systems running)
4. **Simplify Bath:** Make bath mode read legacy values for growth (LOW-MEDIUM RISK - targeted changes)

**Critical Finding:** Legacy mode (use_bath_mode = false) already implements ALL mushroom features perfectly:
- ✅ Day/night cycle (120s period)
- ✅ Mushroom night growth (~0.40 rate when θ=π, sun_brightness=0)
- ✅ Mushroom sun damage (0.20 damage rate when θ=0, sun_brightness=1)
- ✅ Bloch sphere coupling flexibility
- ✅ Hybrid crops (θ=π/2 gets both wheat and mushroom components)

**Recommendation:** User should review architectural analysis and choose direction before any code changes.

---

## Bug #11: Measurement Implementation Duplication

### Problem Summary
Two separate measurement implementations exist - one for qubit-first mode, one for bath-first mode. Mushrooms use bath measurement, which may have different behavior.

### Double Specification Found

**SPECIFICATION #1 (Qubit-first mode):**
```
File: Core/QuantumSubstrate/DualEmojiQubit.gd:144
func measure() -> String:
    if randf() < get_north_probability():
        theta = 0.0
        return north_emoji
    else:
        theta = 3.1415926535897932  # PI
        return south_emoji

Where:
  get_north_probability() = cos²(θ/2)
  get_south_probability() = sin²(θ/2)

At θ=π/2: 50% north, 50% south
```

**SPECIFICATION #2 (Bath-first mode):**
```
File: Core/QuantumSubstrate/QuantumBath.gd:395
func measure_axis(north: String, south: String, collapse_strength: float = 0.5) -> String:
    var amp_n = get_amplitude(north)
    var amp_s = get_amplitude(south)

    var prob_n = amp_n.abs_sq()
    var prob_s = amp_s.abs_sq()
    var total = prob_n + prob_s

    var rand_val = randf()
    if rand_val < prob_n / total:
        outcome = north
        partial_collapse(north, collapse_strength)
    else:
        outcome = south
        partial_collapse(south, collapse_strength)

    return outcome

Where:
  Probabilities based on bath amplitudes (not qubit theta!)
  Influenced by Hamiltonian/Lindblad dynamics
```

### Which Code Path is Used?
```
- Wheat plots: Use DualEmojiQubit.measure() (Spec #1)
- Mushroom plots: Use QuantumBath.measure_axis() (Spec #2)
```

### Analysis
The 4/4 detritus collapse observed for mushrooms is using **Spec #2** (bath measurement). The bath amplitudes may naturally favor 🍂 (detritus/ground state) due to:
- Hamiltonian coupling strengths
- Lindblad decay rates
- Natural equilibrium of the quantum bath

This might be **by design**, not a bug! The bath could be modeling that mushrooms naturally decay to detritus.

### Verification Needed
Run 100+ mushroom measurements to determine if bias is:
1. Statistical fluke (6.25% chance for 4/4 south)
2. Bath equilibrium dynamics (by design)
3. Actual measurement bug (needs fix)

---

## Bug #12: Energy vs Radius Synchronization

### Problem Summary
After quantum evolution, radius grows exponentially but energy stays frozen at initial value.

### Triple Specification Found

**SPECIFICATION #1 (Initial - CORRECT):**
```
File: Core/Environment/BiomeBase.gd:193
qubit.radius = 0.1  # Initial planting radius
qubit.energy = 0.1  # Energy starts at radius ✅

Result: energy = 0.1 (correct!)
```

**SPECIFICATION #2 (Override - WRONG FORMULA):**
```
File: Core/GameMechanics/BasePlot.gd:96
quantum_state.energy = (wheat_cost * 100.0) + (quantum_state_or_labor * 50.0)

Example: 1 wheat + 1 labor
  energy = (1 * 100) + (1 * 50) = 150

Result: Overwrites BiomeBase's correct 0.1 with 150 ❌
```

**SPECIFICATION #3 (Growth - MISSING UPDATE):**
```
File: Core/Environment/BiomeBase.gd:236-237
var growth_rate = 0.017
qubit.radius *= exp(growth_rate * dt)  # Radius grows 0.1 → 0.277
# BUT: qubit.energy is NEVER updated!

Result: Radius grows, energy stays frozen at 150 ❌
```

### Root Cause Chain
1. BiomeBase.create_projection() correctly sets `energy = 0.1`
2. BasePlot.plant() **immediately overwrites** it to `energy = 150`
3. BiomeBase.update_projections() grows radius but **never syncs energy**

### Observed Behavior
```
Before evolution:
  radius = 0.100
  energy = 26.000  # (Wait, why 26? Should be 150!)

After 60s evolution:
  radius = 0.277  # ✅ Grew correctly
  energy = 26.000  # ❌ Frozen at initial value
```

*Note: The observed energy=26 suggests there might be yet another specification location not yet found!*

### Fix Strategy

**Option A: Remove energy field entirely (energy = radius)**
```gdscript
# In DualEmojiQubit.gd:
var _internal_energy: float = 0.0  # Hidden

@export var energy: float:
    get: return radius  # Always equals radius
    set(value): pass  # Ignore sets, use radius
```

**Option B: Sync energy during update_projections**
```gdscript
# In BiomeBase.gd update_projections():
qubit.radius *= exp(growth_rate * dt)
qubit.radius = min(qubit.radius, 1.0)
qubit.energy = qubit.radius  # ADD THIS LINE
```

**Option C: Fix BasePlot.plant() formula**
```gdscript
# In BasePlot.gd plant():
# REMOVE THIS:
quantum_state.energy = (wheat_cost * 100.0) + (quantum_state_or_labor * 50.0)

# Energy is already correctly set to 0.1 by BiomeBase!
```

**Recommended: Combination of B + C**
1. Remove the wrong formula in BasePlot (Option C)
2. Add energy sync in update_projections (Option B)

---

## Summary Table

| Bug | Specifications | Files Involved | Root Cause |
|-----|----------------|----------------|------------|
| #10 Mushroom Growth | 3 specs | CoreIcons.gd, BioticFluxBiome.gd, BiomeBase.gd | Hardcoded 0.017 ignores icon Lindblad rates |
| #11 Measurement | 2 specs | DualEmojiQubit.gd, QuantumBath.gd | Two separate implementations (may be intentional) |
| #12 Energy/Radius | 3+ specs | BiomeBase.gd, BasePlot.gd, ??? | Wrong formula overwrites, no sync during growth |

## Impact Assessment

### Bug #10 Impact: **HIGH**
- Mushrooms should grow 23x faster than wheat
- Current: Mushrooms are identical to wheat
- Breaks game balance and mushroom farming strategy
- **FIX PRIORITY: HIGH**

### Bug #11 Impact: **MEDIUM**
- May be by design (bath equilibrium dynamics)
- Needs statistical verification before deciding if fix needed
- Could affect mushroom farming viability
- **FIX PRIORITY: MEDIUM (after verification)**

### Bug #12 Impact: **LOW-MEDIUM**
- Harvest yields use radius (correct) not energy
- Energy is mostly cosmetic (display only)
- But incorrect energy misleads players about quantum state
- **FIX PRIORITY: MEDIUM**

## Testing Strategy

1. **Fix Bug #10** → Re-run mushroom test → Verify exponential growth
2. **Run 100-sample mushroom measurement test** → Statistical analysis → Decide if Bug #11 needs fix
3. **Fix Bug #12** → Verify energy tracks radius during evolution

## Lessons Learned

**Why These Bugs Happened:**
1. **Iterative development** - Values specified early, overridden later
2. **Feature additions** - Bath mode added, qubit mode logic not fully replaced
3. **Lack of centralization** - No single source of truth for growth rates/energy

**Prevention Strategy:**
1. **Single Source of Truth** - One authoritative location for each value
2. **Derived Properties** - Make energy a computed property from radius
3. **Configuration Files** - Move magic numbers to centralized config
4. **Validation Tests** - Automated tests to detect specification conflicts
