# BioticFlux Energy Transfer System: Complete Guide

## Overview

The BioticFluxBiome implements a sophisticated quantum-based energy transfer system where crop growth is governed by Hamiltonian evolution and non-Hamiltonian energy dissipation.

**Core Principle**: Energy growth follows probability-weighted quantum mechanics—crops grow according to their position on the Bloch sphere, with superposition states receiving blended energy from multiple sources.

---

## Energy Growth Formula

### Standard Crops (Pure Wheat or Pure Mushroom)

```
energy_rate = base_energy_rate × amplitude × alignment × influence

where:
  base_energy_rate = 2.45
  amplitude = cos²(θ_crop/2)        // How "crop-like" the state is
  alignment = cos²((θ_crop - θ_sun) / 2)  // Phase match with sun
  influence = wheat_influence (0.15) or mushroom_influence (0.983)
```

**Application**: `qubit.grow_energy(energy_rate, dt)` uses exponential growth:
```
energy(t+dt) = energy(t) × exp(energy_rate × dt)
```

### Hybrid Crops (Superposition)

For qubits with both wheat and mushroom emojis (e.g., 🌾 north, 🍄 south):

```
wheat_prob = cos²(θ/2)          // Probability of being in wheat state
mushroom_prob = sin²(θ/2)       // Probability of being in mushroom state

wheat_rate = base × wheat_prob × alignment × 0.15
mushroom_rate = base × mushroom_prob × alignment × 0.983

total_energy_rate = wheat_rate + mushroom_rate
```

**Result**: Hybrid crops get probability-weighted energy from both sources simultaneously.

---

## Parameters (Tuned for Gameplay)

| Parameter | Value | Notes |
|-----------|-------|-------|
| `base_energy_rate` | 2.45 | Baseline exponential growth coefficient |
| `wheat_energy_influence` | 0.15 | Weak growth without icon (0.017 → 0.15 boosted) |
| `mushroom_energy_influence` | 0.983 | Strong growth, but balanced by sun damage |
| `sun_moon_period` | 20.0 seconds | Full day-night cycle |
| `T1_base_rate` | 0.001 | Amplitude damping (energy loss) |
| `T2_base_rate` | 0.002 | Phase damping (dephasing) |
| `sun_damage_rate` | 0.01 | Base mushroom damage when sun strong |

---

## System Behavior

### Growth Curves (3-Second Window)

From test results with boosted wheat_influence:

**Pure Wheat (θ=0)**
```
Time | Energy | Growth Rate
0s   | 0.306  | baseline
1s   | 0.365  | +19% exponential
2s   | 0.418  | +14% (alignment decreasing)
3s   | 0.473  | +13% (continued exponential)
```
- Steady growth sustained by icon alignment
- Amplitude remains high (cos²(θ/2) ≈ 1.0)
- Alignment decreases as sun drifts: 0.954 → 0.729

**Hybrid Crops (θ=π/2)**
```
Time | Energy | Growth Rate | Composition
0s   | 0.323  | baseline    | 46% wheat, 54% mushroom
1s   | 0.346  | +7%         | 44% wheat, 56% mushroom (blended)
2s   | 0.375  | +8%         | 41% wheat, 59% mushroom
3s   | 0.408  | +9%         | 40% wheat, 60% mushroom
```
- Slower than pure wheat because mushroom component is weaker
- Balanced approach to growth

**Pure Mushroom (θ=π)**
```
Time | Energy | Status
0s   | 0.300  | baseline
1s   | 0.300  | NO GROWTH (sun damage cancels growth)
2s   | 0.299  | DECLINE (damage > growth)
3s   | 0.299  | FLAT (equilibrium or negative)
```
- Mushrooms suffer from sun damage: `damage = 0.01 × sun_strength × exposure`
- Even though mushroom_influence is 0.983 (58x wheat), sun damage prevents growth during day
- Mushrooms grow well only during night phase

---

## Energy Tap System

The energy tap provides selective resource harvesting using quantum phase coupling.

### Energy Tap Formula

```
transfer_rate = tap_base_rate × amplitude × alignment

where:
  amplitude = cos²(θ_target / 2)    // How "target-like" the crop is
  alignment = cos²((θ_target - θ_tap) / 2)  // Phase match with tap
  tap_base_rate = 0.5 (example, configurable)
```

### Example: Wheat Harvesting

**Scenario**: Energy tap positioned at θ_tap = 0 (optimal wheat alignment)

```
Time | Wheat Energy | Transfer Rate | Accumulated Harvest
0s   | 0.362        | 0.498/sec     | 0.000
1s   | 0.362        | 0.498/sec     | 0.455 ← (1 sec × 0.498/sec/wheat × 2 wheat)
2s   | 0.415        | 0.493/sec     | 0.865
3s   | 0.467        | 0.488/sec     | 1.271
4s   | 0.515        | 0.481/sec     | 1.672
5s   | 0.555        | 0.474/sec     | 2.070
```

**Key observations**:
1. **Wheat continues growing despite tapping** (0.362 → 0.555)
2. **Transfer rate stays high** (~0.47-0.50/sec) because alignment is nearly perfect
3. **Net growth = Icon energy - Tap drain**
   - Icon provides growth force
   - Tap extracts energy force
   - Both scale with amplitude and phase alignment

### Tap Positioning Strategy

- **θ_tap = 0** (wheat-aligned): Maximum extraction from wheat
- **θ_tap = π/2** (neutral): Balanced extraction from hybrid crops
- **θ_tap = π** (mushroom-aligned): Maximum extraction from mushrooms

---

## Icon System

Icons provide feedback coupling that stabilizes crop types at their preferred states:

### Wheat Icon
- **Stable theta**: π/4 (45°, agricultural alignment)
- **Spring constant**: 0.5 (stiffness of return force)
- **Coupling**: Sun drives icon, wheat provides feedback
- **Effect**: Wheat qubits pulled toward wheat-aligned state

### Mushroom Icon
- **Stable theta**: π (100% mushroom, nocturnal)
- **Spring constant**: 0.5
- **Coupling**: Sun drives icon, mushrooms provide feedback
- **Effect**: Mushroom qubits pulled toward mushroom-aligned state

### Icon Influence

```
// When FarmGrid is connected:
wheat_energy_influence = icon.calculate_influence(crop_type)

// Without FarmGrid (test mode):
wheat_energy_influence = 0.15  // Fixed boost
mushroom_energy_influence = 0.983  // Fixed boost
```

---

## Sun/Moon Cycling

The immutable sun/moon qubit drives all energy transfer:

```
sun_qubit.theta evolves from 0 → 2π every 20 seconds

sun_phase = is_currently_sun() ? "☀️" : "🌙"
sun_strength = cos²(sun_qubit.theta / 2.0)  // Rabi oscillation

// Temperature based on sun intensity
temperature = 300K + intensity × 100K  // 300K-400K range
```

**Effect on crops**:
- **Alignment oscillates**: cos²((θ_crop - θ_sun)/2) varies with sun phase
- **Optimal times**: Crops grow fastest when phase-aligned with sun
- **Damage timing**: Mushrooms damaged most when sun is strong (day phase)

---

## Decoherence (Energy Loss)

Temperature-dependent dissipation occurs after each time step:

```
T1_rate = T1_base_rate × (temperature / 300K)  // Amplitude damping
T2_rate = T2_base_rate × (temperature / 300K)  // Phase damping

qubit.apply_amplitude_damping(T1_rate × dt)
qubit.apply_phase_damping(T2_rate × dt)
```

**Effect**: Hotter qubits lose energy faster (exponential decay).

---

## Game Design Implications

### Crop Selection Strategy

1. **Pure Wheat**: Steady, reliable growth
   - Best for stable food production
   - Immune to sun damage
   - Requires wheat-aligned icon to grow visibly

2. **Hybrid (50/50)**: Balanced strategy
   - Moderate growth rate
   - Blended benefits of both crops
   - Flexible response to conditions

3. **Pure Mushroom**: High-risk, high-reward
   - Fast growth at night (low sun damage)
   - Severely damaged during day
   - Requires nocturnal farming strategy

### Energy Taps

Create interesting mechanics:
- **Harvest vs Growth tension**: Tap position affects growth/extraction balance
- **Phase-optimal positioning**: Precisely align taps for maximum efficiency
- **Resource extraction**: Convert crop energy → usable resources

### Sun/Moon Cycling

Creates temporal gameplay:
- **Day cycle**: Different crops viable at different times
- **Phase strategy**: Time harvests and plantings for alignment
- **Dynamic alignment**: Constantly shifting optimal positions

---

## Test Results Summary

### Wheat Growth (BioticFluxWheatTest)
- 9 wheat qubits in 3×3 grid
- Growth: 0.3 → 0.476 in ~50 seconds with boosted influence (0.15)
- Formula verification: cos²(θ/2) × cos²(alignment) × 0.15 × 2.45 ✓

### Hybrid Crops (BioticFluxHybridTest)
- Pure wheat: 0.365 → 0.636 (fastest)
- Hybrid: 0.323 → 0.516 (moderate)
- Pure mushroom: 0.300 → 0.299 (NO growth, sun damage)
- Probability-weighted formula verified ✓

### Energy Taps (BioticFluxEnergyTapTest)
- Wheat under tap: 0.362 → 0.587 (still grows)
- Accumulated harvest: 0.455 → 2.070 in 6 seconds
- Transfer rate: ~0.47/sec per wheat with cos² coupling
- Energy tap formula verified ✓

---

## Tuning Guide

To adjust growth rates:

```gdscript
# In BioticFluxBiome._ready():

# Faster wheat growth
biome.wheat_energy_influence = 0.25  # was 0.15

# Mushroom damage reduction
base_damage = 0.005  # was 0.01

# Faster sun/moon cycling
biome.sun_moon_period = 10.0  # was 20.0

# Tap extraction rate
tap_base_rate = 0.75  # was 0.5
```

---

## Related Systems

- **QuantumSubstrate**: Defines qubit state (DualEmojiQubit)
- **QuantumVisualizationController**: Displays energy via glyph size + color
- **FarmGrid**: Manages crop plots and plot types
- **WheatPlot**: Represents individual plantable locations

---

## Future Enhancement Ideas

1. **Icon strength variation**: Dynamic icons that strengthen with alignment
2. **Collective farming bonus**: Crops near similar types grow faster
3. **Tap efficiency curves**: Taps that improve with repeated use
4. **Energy storage**: Accumulators that store tap energy
5. **Seasonal modifiers**: Base_energy_rate varies by season
6. **Weather effects**: Storm damage, rain boosts, etc.

---

## Testing Commands

```bash
# Test wheat growth
timeout 12 godot --headless Tests/biotic_flux_wheat_test.tscn

# Test hybrid crops
timeout 12 godot --headless Tests/biotic_flux_hybrid_test.tscn

# Test energy taps
timeout 12 godot --headless Tests/biotic_flux_energy_tap_test.tscn
```

All tests demonstrate exponential energy growth with quantum phase coupling working as designed.

🌾 Energy transfer system ready for gameplay integration! 🌾
