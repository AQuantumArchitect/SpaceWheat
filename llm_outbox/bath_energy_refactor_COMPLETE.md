# Bath-First Energy Refactor - COMPLETE ✅

**Date:** 2026-01-01
**Status:** All 11 tasks completed, test passing
**Architecture:** Energy now lives ONLY at bath level (zero-sum, quantum accurate)

---

## Summary

Successfully refactored the entire energy system to be **bath-first** and **quantum mechanically correct**:

- **Energy = Population**: Energy is now a property of the bath, not individual qubits
- **Zero-Sum**: All energy operations maintain normalization (Σ|αᵢ|² = 1.0)
- **Quantum Accurate**: Energy = sin²(θ/2) = south probability (excitation level)
- **No Legacy Code**: Removed all backwards compatibility, clean break

---

## What Changed

### 1. Core Infrastructure

#### **DualEmojiQubit.gd** (Lines 27-46)
- Removed `var energy` storage variable
- Added **computed property**:
  - `get`: Returns `get_south_probability()` = sin²(θ/2)
  - `set`: Converts to theta via θ = 2·arcsin(√P)
- Energy is now DERIVED from theta, not stored

#### **QuantumBath.gd** (Lines 180-318)
- Added `get_population(emoji)` - "how much wolf-ness exists?"
- Added `boost_amplitude(emoji, amount)` - inject energy (inject tool)
- Added `drain_amplitude(emoji, amount)` - extract energy (drain tool)
- Added `transfer_amplitude(from, to, amount)` - Lindblad energy flow
- All operations automatically normalize (zero-sum maintained)

#### **BiomeBase.gd**
- **Line 216**: Removed `qubit.energy = 0.1` initialization
- **Line 276**: Removed `qubit.energy = qubit.radius` sync bug
- Energy-radius decoupling: radius = coherence, energy = excitation

---

### 2. Game Systems

#### **FarmInputHandler.gd** (Lines 965-1085)
Rewrote inject/drain to operate on **bath** instead of individual qubits:

**Inject (Tool #8):**
```gdscript
func _action_inject_energy(positions: Array[Vector2i]):
    # Spending wheat (1 wheat → 0.05 probability boost)
    for pos in positions:
        var biome = _get_biome_for_position(pos)
        var target_emoji = plot.quantum_state.south_emoji
        biome.bath.boost_amplitude(target_emoji, 0.05)  # BATH LEVEL
```

**Drain (Tool #9):**
```gdscript
func _action_drain_energy(positions: Array[Vector2i]):
    # Drain 0.1 probability, gain wheat
    for pos in positions:
        var biome = _get_biome_for_position(pos)
        var drain_emoji = # pick dominant between north/south
        var drained = biome.bath.drain_amplitude(drain_emoji, 0.1)  # BATH LEVEL
        economy.add_resource("🌾", drained * 20.0)
```

#### **BasePlot.gd** (Lines 167-199)
Harvest uses **coherence (radius)**, not energy:
```gdscript
func harvest() -> Dictionary:
    var coherence_value = quantum_state.radius * 0.9  # Coherence extraction
    var yield_amount = max(1, int(coherence_value * 10))
    return {
        "outcome": outcome,
        "energy": coherence_value,  # Legacy key, now coherence
        "yield": yield_amount
    }
```

#### **PlotGridDisplay.gd** (Lines 500-508)
UI derives energy from theta:
```gdscript
# Energy is now derived from theta (excitation = south probability)
ui_data["energy_level"] = plot.quantum_state.get_south_probability()
ui_data["coherence"] = plot.quantum_state.radius
```

---

### 3. Save/Load Systems

#### **GameStateManager.gd** (Lines 353-521)
Removed ALL energy serialization:
- Sun qubit: `{theta, phi, radius}` only (energy removed)
- Icon qubits: `{theta, phi, radius}` only
- Quantum states: `{theta, phi, radius}` only
- Energy will be automatically derived on load from theta

#### **SaveDataAdapter.gd** (Lines 88-128)
Removed ALL energy deserialization:
- No `qubit.energy = ...` assignments
- Energy derives from loaded theta values

---

### 4. Biome-Specific Code

Replaced `.energy` with `.radius` for resource storage:

#### **BioticFluxBiome.gd**
- Line 292: `planting_qubit.radius = (wheat * 100 + labor * 50)` (was energy)
- Line 325: `labor_yield = qubit.radius * labor_prob / 100` (was energy)

#### **MarketBiome.gd**
- Lines 123, 129: Removed energy initialization
- Line 286: `qubit.radius += growth_rate` (was energy)
- Line 357: `trader_qubit.radius -= sell_amount` (was energy)
- Line 366: `"goods_remaining": trader_qubit.radius` (was energy)

#### **QuantumKitchen_Biome.gd**
- Line 89: Removed energy initialization
- Line 285: `total_resources += q.radius` (was energy)
- Line 299: `bread_qubit.radius = total_resources * 0.7` (was energy)
- Line 340: `total_bread_produced += bread_qubit.radius` (was energy)
- Line 397: `"bread_resources": bread_qubit.radius` (was energy)

---

### 5. Legacy Code Deletion

#### **Deleted Files:**
- `/home/tehcr33d/ws/SpaceWheat/Core/Environment/Biome.gd` (920 lines, legacy)

#### **Updated Test Files:**
- `Tests/test_gameplay_strategy_3_balanced_hybrid.gd` - Changed import from Biome to BioticFluxBiome
- `Tests/test_energy_tap.gd` - Changed import from Biome to BioticFluxBiome

---

## Test Results ✅

**Test File:** `Tests/test_inject_drain_bath.gd`

```
🧪 BATH-FIRST INJECT/DRAIN TEST

✓ Biome initialized with bath
  Bath has 6 emojis

📊 Initial Bath Populations:
  🌾: 0.2000
  🍄: 0.2000

🔼 TEST 1: INJECT ENERGY (boost 🌾 by 0.1)
  🌾 before: 0.2000
  🌾 after:  0.2727
  Change: 0.0727
  ✅ PASS: Wheat population increased

🔽 TEST 2: DRAIN ENERGY (drain 🌾 by 0.05)
  🌾 before: 0.2727
  🌾 after:  0.2344
  Drained: 0.0500
  Change: -0.0383
  ✅ PASS: Wheat population decreased, energy drained

🔄 TEST 3: VERIFY NORMALIZATION
  Total population: 1.000000
  ✅ PASS: Bath is normalized (sum ≈ 1.0)

📐 TEST 4: ENERGY DERIVED FROM THETA
  Created projection 🌾↔🍄
  Theta: 1.4695
  Computed energy (sin²(θ/2)): 0.4494
  South probability: 0.4494
  ✅ PASS: Energy correctly derived from theta

==================================================
✅ ALL TESTS PASSED
==================================================
```

---

## Quantum Mechanics

### Energy Representation

**OLD (WRONG):**
- Energy stored on each qubit: `qubit.energy = 0.5`
- Synced to radius every frame: `qubit.energy = qubit.radius`
- Overwrote manual injections/drains

**NEW (CORRECT):**
- Energy = excitation level = sin²(θ/2)
- Energy lives in BATH populations
- Qubits are projections, not energy reservoirs

### Physical Interpretation

```
Bath: |ψ⟩ = α₁|🌾⟩ + α₂|🍄⟩ + α₃|👥⟩ + ...

Energy:
  E(🌾) = |α₁|² = P(🌾) = "how much wheat-ness"
  E(🍄) = |α₂|² = P(🍄) = "how much mushroom-ness"
  E(👥) = |α₃|² = P(👥) = "how much labor-ness"

Conservation: Σᵢ|αᵢ|² = 1.0 (normalized)

Projection: qubit = 2D slice (north↔south)
  Energy(qubit) = sin²(θ/2) = south probability
```

### Operations

**Inject (boost_amplitude):**
```
boost_amplitude(🌾, 0.1):
  P_new(🌾) = P_old(🌾) + 0.1
  normalize() → reduces all other emojis proportionally

Like "shining light on plants" - boosts wheat, relatively dampens others
```

**Drain (drain_amplitude):**
```
drain_amplitude(🌾, 0.05):
  P_new(🌾) = P_old(🌾) - 0.05
  normalize() → redistributes to other emojis
  Cannot drain >90% (maintains seed population)

Like "harvesting" - extracts wheat, relatively boosts others
```

**Transfer (Lindblad):**
```
transfer_amplitude(🐺, 🐰, 0.01):
  P(🐺) += 0.01  (predator eats)
  P(🐰) -= 0.01  (prey consumed)

Ecosystem dynamics: wolf hunts rabbit, energy flows
```

---

## Files Modified (13 total)

### Core Infrastructure (3 files)
1. ✅ `Core/QuantumSubstrate/DualEmojiQubit.gd` - Energy → computed property
2. ✅ `Core/QuantumSubstrate/QuantumBath.gd` - Added population methods
3. ✅ `Core/Environment/BiomeBase.gd` - Removed sync bug

### Game Systems (4 files)
4. ✅ `UI/FarmInputHandler.gd` - Inject/drain → bath level
5. ✅ `Core/GameMechanics/BasePlot.gd` - Harvest → coherence
6. ✅ `UI/PlotGridDisplay.gd` - UI derives from theta
7. ✅ `Core/GameMechanics/FarmEconomy.gd` - No changes needed

### Save/Load (2 files)
8. ✅ `Core/GameState/GameStateManager.gd` - Removed energy serialization
9. ✅ `UI/SaveDataAdapter.gd` - Removed energy deserialization

### Biome-Specific (3 files)
10. ✅ `Core/Environment/BioticFluxBiome.gd` - Energy → radius
11. ✅ `Core/Environment/MarketBiome.gd` - Energy → radius
12. ✅ `Core/Environment/QuantumKitchen_Biome.gd` - Energy → radius

### Legacy Deletion (1 file)
13. ✅ `Core/Environment/Biome.gd` - DELETED (920 lines)

---

## Migration Complete

The energy system is now:
- ✅ **Bath-first**: Energy lives in quantum bath populations
- ✅ **Zero-sum**: Total energy conserved via normalization
- ✅ **Quantum accurate**: Energy = sin²(θ/2) = south probability
- ✅ **Ecosystem ready**: Can model "wolf-ness", "wheat-ness", etc.
- ✅ **Storage capable**: Mountain 🏔️, Sun ☀️, Air 💨 can hold energy
- ✅ **Lindblad compatible**: Energy flows between emojis
- ✅ **No legacy code**: Clean break, no backwards compatibility

The system is ready for true ecosystem simulations where energy flows between components (🐺 → 🐰, ☀️ → 🌾, 🍄 → 🍂 → 🏔️).

---

**Next Steps (User's Choice):**
- Build Lindblad evolution for predator/prey dynamics
- Implement seasonal energy flow (summer → winter → mountain)
- Add celestial self-energy (sun/moon modulation)
- Create forest ecosystem demo
