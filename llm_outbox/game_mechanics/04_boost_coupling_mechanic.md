# Boost Coupling Mechanic - Hamiltonian Strength Amplification

## Overview

Boost coupling **increases the Hamiltonian coupling strength** between two emojis in a biome's bath, causing coherent oscillations to happen faster. This is the "real physics" replacement for the deprecated "inject_energy" action.

## Core Components

### Files Involved
- `UI/FarmInputHandler.gd` - Lines 981-1017: `_action_boost_coupling()` action handler
- `Core/Environment/BiomeBase.gd` - `boost_hamiltonian_coupling()` method (implementation varies per biome)
- `Core/QuantumSubstrate/QuantumBath.gd` - Hamiltonian matrix storage and evolution

## How It Works

### 1. User Action

```
User selects plots with Tool 1 (T, Y, U, I, O, P keys)
User presses Tool 4 → Q (Boost Coupling)
  ↓
FarmInputHandler._action_boost_coupling([Vector2i(2,0), Vector2i(3,0)])
  ↓
For each plot: biome.boost_hamiltonian_coupling(north_emoji, south_emoji, boost_factor)
  ↓
Biome modifies H[north][south] in its bath
```

### 2. Action Implementation

**FarmInputHandler._action_boost_coupling() - Lines 981-1017**:

```gdscript
func _action_boost_coupling(positions: Array[Vector2i]):
    """Boost Hamiltonian coupling between emojis → faster coherent oscillations

    Physics: Increases H[i,j] coupling strength
    Effect: Natural dynamics happen faster (e.g., wheat → bread)
    """
    if not farm or not farm.grid:
        action_performed.emit("boost_coupling", false, "⚠️  Farm not loaded yet")
        return

    print("⚡ Boosting Hamiltonian coupling for %d positions..." % positions.size())

    # Boost factor: 50% faster evolution
    var boost_factor = 1.5

    var success_count = 0
    for pos in positions:
        var plot = farm.grid.get_plot(pos)
        if not plot or not plot.quantum_state:
            continue  # Skip unplanted plots

        # Get biome for this position
        var biome = _get_biome_for_position(pos)
        if not biome:
            print("  ⚠️  No biome at %s" % pos)
            continue

        # Extract emoji pair from plot's quantum state
        var emoji_a = plot.quantum_state.north_emoji
        var emoji_b = plot.quantum_state.south_emoji

        # Boost coupling in biome
        if biome.boost_hamiltonian_coupling(emoji_a, emoji_b, boost_factor):
            success_count += 1

    action_performed.emit("boost_coupling", success_count > 0,
        "✅ Boosted coupling at %d plots (×%.1f)" % [success_count, boost_factor])
```

### 3. Physics: What Gets Modified

**Hamiltonian Matrix**:
```
Before boost:
H[🌾][👥] = 0.25
H[👥][🌾] = 0.25

After boost (×1.5):
H[🌾][👥] = 0.375
H[👥][🌾] = 0.375
```

**Master Equation Evolution**:
```
dρ/dt = -i[H, ρ] + L(ρ)

Coherent term: -i[H, ρ]
→ Oscillation frequency ∝ H[i,j]
→ Stronger coupling = faster oscillations
→ Coherence builds faster
```

### 4. Biome Implementation

**BiomeBase.boost_hamiltonian_coupling()**:

```gdscript
func boost_hamiltonian_coupling(emoji_a: String, emoji_b: String, factor: float = 1.5) -> bool:
    """Increase Hamiltonian coupling strength between two emojis

    Args:
        emoji_a: First emoji (e.g., "🌾")
        emoji_b: Second emoji (e.g., "👥")
        factor: Multiplicative boost (1.5 = 50% increase)

    Returns: true if boost succeeded
    """
    if not bath:
        return false

    # Get emoji indices
    var idx_a = bath.emoji_to_index.get(emoji_a, -1)
    var idx_b = bath.emoji_to_index.get(emoji_b, -1)

    if idx_a < 0 or idx_b < 0:
        print("⚠️  Cannot boost coupling: emoji not in bath (%s, %s)" % [emoji_a, emoji_b])
        return false

    # Modify Hamiltonian matrix
    var H = bath._hamiltonian
    var current_coupling = H.get_element(idx_a, idx_b)

    var new_coupling = current_coupling.mul_scalar(factor)
    H.set_element(idx_a, idx_b, new_coupling)
    H.set_element(idx_b, idx_a, new_coupling.conj())  # Maintain Hermitian

    # Mark operators as dirty (will rebuild on next evolve)
    bath.operators_dirty = true

    print("  ⚡ Boosted H[%s][%s]: %.3f → %.3f (×%.1f)" %
          [emoji_a, emoji_b, current_coupling.abs(), new_coupling.abs(), factor])

    return true
```

### 5. Effect on Evolution

**Before Boost**:
```
H[🌾][👥] = 0.25
Evolution time for r=0.1 → 0.5: ~5 seconds
```

**After Boost (×1.5)**:
```
H[🌾][👥] = 0.375
Evolution time for r=0.1 → 0.5: ~3.3 seconds
```

**Physics reasoning**:
```
Oscillation period: T ∝ 1/H[i,j]

T_before = 1/0.25 = 4.0
T_after = 1/0.375 = 2.67

Speedup: 4.0/2.67 ≈ 1.5× faster
```

## Use Cases

### Use Case 1: Fast Wheat Farming
```
Goal: Minimize time from plant to harvest

Strategy:
1. Plant wheat at (2,0) → 🌾↔👥 projection
2. Immediately boost coupling: H[🌾][👥] × 1.5
3. Wait only ~3s instead of 5s
4. Harvest with same coherence level

Result: 40% time savings!
```

### Use Case 2: Multi-Plot Synchronization
```
Goal: Harvest multiple plots simultaneously

Strategy:
1. Plant 4 wheat plots (U, I, O, P)
2. Boost all 4 plots in parallel
3. All plots evolve at same faster rate
4. Harvest all together at t=3s

Result: Synchronized production pipeline
```

### Use Case 3: Overcoming Weak Couplings
```
Goal: Make viable emojis with naturally weak coupling

Example:
- Some biomes have H[emoji_x][emoji_y] = 0.05 (very weak)
- Evolution would take 25+ seconds
- Boost ×1.5 → H = 0.075
- Evolution now only 17 seconds (still slow, but playable)

Result: Unlocks previously impractical emoji pairs
```

## Cost System (Optional)

Currently boost_coupling is **free**. Biomes could implement cost:

```gdscript
func boost_hamiltonian_coupling(emoji_a: String, emoji_b: String, factor: float) -> bool:
    # Check resource cost
    var wheat_cost = 20  # 20 wheat credits per boost
    if not farm.economy.can_afford_resource("🌾", wheat_cost):
        print("⚠️  Cannot afford boost (need %d 🌾)" % wheat_cost)
        return false

    # Deduct cost
    farm.economy.spend_resource("🌾", wheat_cost, "coupling_boost")

    # Apply boost
    # ... (rest of implementation)
```

**Design philosophy**: Energy investment to manipulate quantum dynamics!

## Persistence

**Question**: Do boosts persist across sessions?

**Current behavior**: Boosts modify bath Hamiltonian in-memory, NOT saved to disk
→ Reloading game resets Hamiltonian to default values
→ Boosts are **temporary** per-session

**To make persistent**:
```gdscript
# BiomeBase save/load
func serialize() -> Dictionary:
    return {
        "hamiltonian_boosts": {
            "🌾:👥": 1.5,  # Track boost factors
            "🍄:🌙": 2.0
        }
    }

func deserialize(data: Dictionary):
    var boosts = data.get("hamiltonian_boosts", {})
    for pair in boosts:
        var emojis = pair.split(":")
        boost_hamiltonian_coupling(emojis[0], emojis[1], boosts[pair])
```

## Limits and Balance

### Maximum Boost
```
# Prevent infinite speedup
const MAX_COUPLING_BOOST = 3.0  # Max 3× original strength

func boost_hamiltonian_coupling(...):
    var current_coupling = H.get_element(idx_a, idx_b)
    var original_coupling = get_original_coupling(emoji_a, emoji_b)

    var current_factor = current_coupling.abs() / original_coupling.abs()
    if current_factor >= MAX_COUPLING_BOOST:
        print("⚠️  Coupling already at max boost (%.1f×)" % current_factor)
        return false

    # Apply boost...
```

### Diminishing Returns
```
# Each subsequent boost is less effective
func boost_hamiltonian_coupling(...):
    var effective_factor = factor / (1.0 + current_boost_count * 0.1)
    # First boost: ×1.5
    # Second boost: ×1.36
    # Third boost: ×1.25
    # etc.
```

## Deprecated Alias

**Old action**: `inject_energy`
**New action**: `boost_coupling`

```gdscript
# FarmInputHandler maintains backwards compatibility
func _action_inject_energy(positions: Array[Vector2i]):
    """DEPRECATED: Use boost_coupling instead"""
    push_warning("inject_energy deprecated - use boost_coupling for real physics")
    _action_boost_coupling(positions)
```

**Why rename?**:
- "Inject energy" implied adding resources (fake physics)
- "Boost coupling" correctly describes Hamiltonian modification (real physics)
- Clearer semantics for quantum mechanics

## Visualization

When coupling is boosted:
- Bloch sphere bubble pulses faster (visual speedup)
- Connecting line between emoji icons glows brighter
- Particle effects between emojis intensify
- Text overlay: "+50% coupling speed"

## Debugging

### Check current coupling:
```gdscript
var biome = farm.biotic_flux_biome
var H = biome.bath._hamiltonian
var i = biome.bath.emoji_to_index["🌾"]
var j = biome.bath.emoji_to_index["👥"]
var coupling = H.get_element(i, j)
print("H[🌾][👥] = %.6f" % coupling.abs())
```

### Verify boost applied:
```gdscript
# Before boost
var before = H.get_element(i, j).abs()

# Apply boost
biome.boost_hamiltonian_coupling("🌾", "👥", 1.5)

# After boost
var after = H.get_element(i, j).abs()
var actual_factor = after / before

print("Coupling boosted: %.3f → %.3f (×%.2f)" % [before, after, actual_factor])
```

## Relation to Other Mechanics

### vs Entanglement
- **Entanglement** creates r=1 instantly (Bell state)
- **Boost coupling** speeds up natural evolution to r=1

**Use entanglement when**: Need instant coherence
**Use boost coupling when**: Want to speed up natural dynamics

### vs Energy Tap
- **Energy tap** drains probability from bath
- **Boost coupling** speeds up coherent oscillations

**Can combine**: Tap drains target emoji → changes probability distribution → affects oscillation amplitude

### vs Tune Decoherence
- **Boost coupling** increases coherent term: -i[H, ρ]
- **Tune decoherence** decreases dissipative term: L(ρ)

**Stack both**: Maximum evolution speed + minimum decoherence = fastest path to high purity!

## Summary

1. **Boost coupling** increases Hamiltonian matrix elements
2. **Effect**: Faster coherent oscillations, shorter evolution time
3. **Target**: Specific emoji pairs (from plot quantum states)
4. **Cost**: Free (currently), could add resource cost
5. **Persistence**: Temporary per-session (not saved)
6. **Strategy**: Use to accelerate slow natural couplings

**Key insight**: This is real quantum control - you're literally tuning the interaction Hamiltonian!
