# Tune Decoherence Mechanic - Lindblad Dissipation Control

## Overview

Tune decoherence **reduces Lindblad operator strength** (γ coefficients) in a biome's bath, slowing down the rate of quantum decoherence. This increases purity Tr(ρ²) over time, leading to higher harvest yields.

## Core Components

### Files Involved
- `UI/FarmInputHandler.gd` - Lines 1019-1088: `_action_tune_decoherence()` action handler
- `Core/Environment/BiomeBase.gd` - `tune_lindblad_rates()` method (implementation varies)
- `Core/QuantumSubstrate/QuantumBath.gd` - Lindblad operator storage and application

## How It Works

### 1. User Action

```
User selects plots with Tool 1 (T, Y, U, I, O, P keys)
User presses Tool 4 → E (Tune Decoherence)
  ↓
FarmInputHandler._action_tune_decoherence([Vector2i(2,0)])
  ↓
Check resource cost (10 wheat credits per plot)
  ↓
biome.tune_lindblad_rates(emoji_a, emoji_b, reduction_factor)
  ↓
Biome modifies γ in L(ρ)
```

### 2. Action Implementation

**FarmInputHandler._action_tune_decoherence() - Lines 1019-1088**:

```gdscript
func _action_tune_decoherence(positions: Array[Vector2i]):
    """Tune Lindblad decoherence rates → control purity

    Physics: Modifies γ in Lindblad operators
    Effect: Lower γ → higher purity → better harvest yield
    """
    if not farm or not farm.grid:
        action_performed.emit("tune_decoherence", false, "⚠️  Farm not loaded yet")
        return

    print("🌊 Tuning decoherence rates for %d positions..." % positions.size())

    # Resource cost: 10 wheat credits per plot
    # Maintaining quantum purity requires energy investment!
    var cost_per_plot = 10
    var total_cost = positions.size() * cost_per_plot

    # Check if player can afford
    if not farm.economy or not farm.economy.can_afford_resource("🌾", total_cost):
        var available = 0
        if farm.economy:
            available = farm.economy.get_resource("🌾")
        action_performed.emit("tune_decoherence", false,
            "❌ Need %d 🌾 (have %d)" % [total_cost, available])
        return

    # Deduct cost
    farm.economy.spend_resource("🌾", total_cost, "decoherence_tuning")

    # Apply tuning
    var reduction_factor = 0.5  # Reduce decoherence by 50%
    var success_count = 0

    for pos in positions:
        var plot = farm.grid.get_plot(pos)
        if not plot or not plot.quantum_state:
            continue

        var biome = _get_biome_for_position(pos)
        if not biome:
            continue

        var emoji_a = plot.quantum_state.north_emoji
        var emoji_b = plot.quantum_state.south_emoji

        # Tune Lindblad rates in biome
        if biome.tune_lindblad_rates(emoji_a, emoji_b, reduction_factor):
            success_count += 1

    # Refund unused cost if some plots failed
    var failed_count = positions.size() - success_count
    if failed_count > 0:
        var refund = failed_count * cost_per_plot
        farm.economy.add_resource("🌾", refund, "decoherence_tuning_refund")

    action_performed.emit("tune_decoherence", success_count > 0,
        "✅ Tuned decoherence at %d plots (×%.1f), cost %d 🌾" %
        [success_count, reduction_factor, success_count * cost_per_plot])
```

### 3. Physics: What Gets Modified

**Lindblad Superoperator**:
```
Master equation:
dρ/dt = -i[H, ρ] + L(ρ)

Lindblad term:
L(ρ) = Σ_k γ_k (L_k ρ L_k† - 1/2{L_k†L_k, ρ})

Where:
- L_k = Lindblad jump operators (e.g., emission, absorption)
- γ_k = decoherence rates (tunable!)
```

**Before Tuning**:
```
γ[🌾→👥] = 0.05  (5% decoherence per time unit)
Purity decay: Tr(ρ²) decreases from 1.0 → 0.5 over ~20 time units
```

**After Tuning (×0.5)**:
```
γ[🌾→👥] = 0.025  (2.5% decoherence per time unit)
Purity decay: Tr(ρ²) decreases from 1.0 → 0.5 over ~40 time units
→ 2× longer purity preservation!
```

### 4. Biome Implementation

**BiomeBase.tune_lindblad_rates()**:

```gdscript
func tune_lindblad_rates(emoji_a: String, emoji_b: String, reduction: float = 0.5) -> bool:
    """Reduce Lindblad decoherence rates for specific emoji pair

    Args:
        emoji_a: First emoji (e.g., "🌾")
        emoji_b: Second emoji (e.g., "👥")
        reduction: Multiplicative reduction (0.5 = 50% reduction)

    Returns: true if tuning succeeded
    """
    if not bath:
        return false

    # Find Lindblad operators affecting this emoji pair
    var affected_operators = []
    for icon in bath.active_icons:
        for lindblad_def in icon.lindblad_operators:
            var target = lindblad_def.get("target_emoji", "")
            if target == emoji_a or target == emoji_b:
                affected_operators.append(lindblad_def)

    if affected_operators.is_empty():
        print("⚠️  No Lindblad operators found for (%s, %s)" % [emoji_a, emoji_b])
        return false

    # Reduce coupling strengths
    for op_def in affected_operators:
        var old_strength = op_def["coupling_strength"]
        op_def["coupling_strength"] *= reduction
        var new_strength = op_def["coupling_strength"]

        print("  🌊 Reduced Lindblad γ: %.4f → %.4f (×%.2f)" %
              [old_strength, new_strength, reduction])

    # Rebuild Lindblad operators
    bath.build_lindblad_from_icons(bath.active_icons)
    bath.operators_dirty = false

    return true
```

### 5. Effect on Purity

**Purity Evolution Without Decoherence Control**:
```
t=0s:  Tr(ρ²) = 1.0  (pure state after planting)
t=2s:  Tr(ρ²) = 0.8  (some mixing)
t=5s:  Tr(ρ²) = 0.6  (significant mixing)
t=10s: Tr(ρ²) = 0.5  (maximally mixed for 2-state)

Harvest yield multiplier: 2.0 × 0.5 = 1.0×
```

**Purity Evolution With Decoherence Tuning (×0.5)**:
```
t=0s:  Tr(ρ²) = 1.0
t=2s:  Tr(ρ²) = 0.9  (slower mixing!)
t=5s:  Tr(ρ²) = 0.75 (still quite pure)
t=10s: Tr(ρ²) = 0.62 (better than before)

Harvest yield multiplier: 2.0 × 0.75 = 1.5×
→ 50% better yield!
```

## Use Cases

### Use Case 1: High-Value Crops
```
Goal: Maximize wheat yield from single plot

Strategy:
1. Plant wheat at (2,0)
2. Tune decoherence (cost: 10 🌾)
3. Wait 5s for evolution
4. Harvest with higher purity (1.5× multiplier)
5. Net gain: 28 credits - 10 cost = 18 credits

Without tuning:
- Harvest: 18 credits - 0 cost = 18 credits

Break-even? Only if harvest > 15 credits (break-even at r≈0.4)
```

### Use Case 2: Long Evolution Times
```
Goal: Maintain purity during extended evolution (10+ seconds)

Scenario: Rare emoji pair with weak coupling
- Natural evolution takes 15s to reach r=0.5
- Without tuning: purity decays to 0.45 (yield ×0.9)
- With tuning: purity stays at 0.7 (yield ×1.4)

Result: 55% yield improvement justifies 10 wheat cost!
```

### Use Case 3: Precision Quantum Computing
```
Goal: Achieve near-perfect purity for entanglement experiments

Strategy:
1. Tune decoherence on multiple plots
2. Entangle them (creates pure Bell state)
3. Purity stays near 1.0 (without tuning → decays)
4. Perform multi-qubit gates without degradation

Result: Enables advanced quantum experiments
```

## Cost-Benefit Analysis

### Direct Economics
```
Cost: 10 wheat credits per plot
Benefit: Purity multiplier increase

Example:
Without tuning: r=0.5, purity=0.6 → yield = (0.5×0.9+0) × 10 × 1.2 = 5.4 ≈ 5 credits
With tuning:    r=0.5, purity=0.8 → yield = (0.5×0.9+0) × 10 × 1.6 = 7.2 ≈ 7 credits

Net gain: 7 - 5 = 2 credits
Cost: 10 credits
→ NEGATIVE ROI! (loses 8 credits)
```

**Conclusion**: Tuning is **NOT economically viable** for short evolution times!

### When It's Worth It
```
Long evolution (r=0.8, long wait):
Without tuning: r=0.8, purity=0.5 → yield = (0.8×0.9+0) × 10 × 1.0 = 7.2 ≈ 7 credits
With tuning:    r=0.8, purity=0.85 → yield = (0.8×0.9+0) × 10 × 1.7 = 12.24 ≈ 12 credits

Net gain: 12 - 7 = 5 credits
Cost: 10 credits
→ Still NEGATIVE, but closer to break-even!

Break-even requires:
Δyield ≥ 10 credits
→ Need purity difference to cause 10+ credit swing
→ Only viable for very high-coherence harvests (r>0.9)
```

## Rebalancing Recommendations

### Option 1: Reduce Cost
```
Cost: 10 → 2 wheat credits per plot
Makes tuning viable for mid-range harvests
```

### Option 2: Increase Benefit
```
Reduction factor: 0.5 → 0.2 (80% reduction)
Purity stays higher → larger yield improvements
```

### Option 3: Persistent Effect
```
Make tuning permanent for biome (not per-plot)
Cost: 50 wheat credits (one-time)
Benefit: All future plots in biome benefit
→ Long-term investment like infrastructure upgrade
```

### Option 4: Synergy with Boost Coupling
```
Bundle: Boost coupling + Tune decoherence
Cost: 15 wheat credits
Effect: Faster evolution AND higher purity
→ Multiplicative benefit justifies higher cost
```

## Persistence

Like boost_coupling, decoherence tuning is **temporary** per-session (not saved).

To make persistent:
```gdscript
func serialize() -> Dictionary:
    return {
        "lindblad_reductions": {
            "🌾:👥": 0.5,  # Track reduction factors
            "🍄:🌙": 0.3
        }
    }
```

## Limits and Balance

### Minimum Decoherence
```
# Cannot eliminate decoherence entirely (physical impossibility)
const MIN_LINDBLAD_RATE = 0.01

func tune_lindblad_rates(...):
    var new_strength = old_strength * reduction
    if new_strength < MIN_LINDBLAD_RATE:
        new_strength = MIN_LINDBLAD_RATE
        print("⚠️  Reached minimum decoherence rate (%.3f)" % MIN_LINDBLAD_RATE)
```

### Stacking Limits
```
# Prevent infinite stacking
var tuning_count = plot.get_meta("decoherence_tunings", 0)
const MAX_TUNINGS = 3

if tuning_count >= MAX_TUNINGS:
    print("⚠️  Plot already at max decoherence tuning (%d)" % MAX_TUNINGS)
    return false
```

## Deprecated Alias

**Old action**: `drain_energy`
**New action**: `tune_decoherence`

```gdscript
func _action_drain_energy(positions: Array[Vector2i]):
    """DEPRECATED: Use tune_decoherence instead"""
    push_warning("drain_energy deprecated - use tune_decoherence for real physics")
    _action_tune_decoherence(positions)
```

**Why rename?**:
- "Drain energy" implied removing resources (misleading)
- "Tune decoherence" accurately describes Lindblad rate modification

## Visualization

When decoherence is tuned:
- Bloch sphere bubble becomes more "solid" (less translucent)
- Purity bar shows green highlight
- Reduced particle scattering effects (less noise)
- Text overlay: "-50% decoherence"

## Debugging

### Check current Lindblad rates:
```gdscript
var biome = farm.biotic_flux_biome
for icon in biome.bath.active_icons:
    for lindblad_def in icon.lindblad_operators:
        print("Lindblad: %s → %s, γ=%.4f" %
              [icon.icon_name, lindblad_def["target_emoji"],
               lindblad_def["coupling_strength"]])
```

### Verify tuning applied:
```gdscript
# Before tuning
var before = lindblad_def["coupling_strength"]

# Apply tuning
biome.tune_lindblad_rates("🌾", "👥", 0.5)

# After tuning
var after = lindblad_def["coupling_strength"]
print("Lindblad rate: %.4f → %.4f (×%.2f)" % [before, after, after/before])
```

## Summary

1. **Tune decoherence** reduces Lindblad operator rates (γ)
2. **Effect**: Slower purity decay, higher Tr(ρ²) at harvest
3. **Cost**: 10 wheat credits per plot (may need rebalancing)
4. **Economics**: Currently NOT viable for most scenarios
5. **Best use**: Long evolution times, high-coherence states
6. **Synergy**: Combine with boost_coupling for maximum effect

**Key insight**: You're fighting entropy - maintaining quantum coherence costs energy!
