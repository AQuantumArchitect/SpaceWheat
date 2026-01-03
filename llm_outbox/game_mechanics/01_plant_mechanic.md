# Plant Mechanic - Dual-Emoji Quantum State Creation

## Overview

Planting creates a **quantum superposition** between two emojis, establishing a DualEmojiQubit projection onto the biome's QuantumBath. If either emoji is missing from the bath, the system automatically **injects** it with full Icon physics.

## Core Components

### Files Involved
- `Core/GameMechanics/BasePlot.gd` - Lines 74-109: `plant()` method
- `Core/Environment/BiomeBase.gd` - Lines 468-550: `create_projection()` with injection logic
- `Core/QuantumSubstrate/QuantumBath.gd` - Lines 152-187: `inject_emoji()` expansion
- `Core/GameMechanics/FarmGrid.gd` - Lines 321-393: `plant()` dispatcher

## How It Works

### 1. User Action
```
User presses planting key (U, I, O, P for wheat on BioticFlux plots)
  ↓
FarmInputHandler._action_build_plot([Vector2i(2, 0)], "wheat")
  ↓
Farm.build(Vector2i(2, 0), "wheat")
  ↓
FarmGrid.plant(Vector2i(2, 0), "wheat")
```

### 2. Plot-Specific Emoji Mapping
Each plot type knows its dual-emoji pair:

```gdscript
# BasePlot subclass defines emoji pair
func get_plot_emojis() -> Dictionary:
    # Example: Wheat → {"north": "🌾", "south": "👥"}
    # Example: Mushroom → {"north": "🍄", "south": "🌙"}
```

### 3. Bath-First Planting

```gdscript
# BasePlot.plant() - Lines 86-108
func plant(quantum_state_or_labor = null, wheat_cost: float = 0.0, biome = null) -> void:
    if biome != null:
        var emojis = get_plot_emojis()  # {"north": "🌾", "south": "👥"}

        # Create projection from biome's quantum bath
        if biome.has_method("create_projection"):
            quantum_state = biome.create_projection(
                grid_position,
                emojis["north"],
                emojis["south"]
            )
            print("🛁 Plot.plant(): created BATH PROJECTION %s↔%s at %s" %
                  [emojis["north"], emojis["south"], grid_position])

    is_planted = true
```

### 4. Emoji Injection (Automatic)

**BiomeBase.create_projection() - Lines 468-550**:

```gdscript
func create_projection(position: Vector2i, north: String, south: String) -> Resource:
    # INJECTION PHASE: Ensure both emojis exist in bath
    var icon_registry = get_node_or_null("/root/IconRegistry")
    if icon_registry:
        # Check north emoji
        if not bath.emoji_to_index.has(north):
            var north_icon = icon_registry.get_icon(north)
            if north_icon:
                bath.inject_emoji(north, north_icon, Complex.zero())
                print("  💉 Injected %s into %s bath (amplitude matched)" %
                      [north, get_biome_type()])

        # Check south emoji
        if not bath.emoji_to_index.has(south):
            var south_icon = icon_registry.get_icon(south)
            if south_icon:
                # Match amplitude to north for balanced superposition
                var north_amp = bath.get_amplitude(north)
                bath.inject_emoji(south, south_icon, north_amp)
                print("  💉 Injected %s into %s bath (amplitude matched)" %
                      [south, get_biome_type()])

        bath.normalize()  # Maintain Tr(ρ) = 1

    # PROJECTION PHASE: Create live qubit window
    var qubit = DualEmojiQubit.new(north, south, PI/2.0, bath)
    qubit.plot_position = position

    return qubit
```

### 5. QuantumBath Emoji Injection

**QuantumBath.inject_emoji() - Lines 152-187**:

```gdscript
func inject_emoji(emoji: String, icon: Icon, initial_amplitude: Complex = Complex.zero()) -> bool:
    # Already exists → no-op
    if _density_matrix.emoji_to_index.has(emoji):
        return true

    # Save old state
    var old_emojis = _density_matrix.emoji_list.duplicate()
    var old_probs: Array = []
    for i in range(_density_matrix.dimension()):
        old_probs.append(_density_matrix.get_probability_by_index(i))

    # Add new emoji with initial probability
    old_emojis.append(emoji)
    old_probs.append(initial_amplitude.abs_sq())

    # Renormalize to maintain Tr(ρ) = 1
    var total = 0.0
    for p in old_probs:
        total += p
    if total > 0:
        for i in range(old_probs.size()):
            old_probs[i] = old_probs[i] / total

    # Rebuild density matrix with expanded Hilbert space
    _density_matrix.initialize_with_emojis(old_emojis)  # N → N+1 dimensions
    _density_matrix.set_classical_mixture(old_probs)

    # Add Icon with full physics (Hamiltonian + Lindblad)
    active_icons.append(icon)

    # Rebuild operators with new Icon's couplings
    build_hamiltonian_from_icons(active_icons)
    build_lindblad_from_icons(active_icons)

    return true
```

## Physics Details

### Icon Brings Full Coupling Physics

When 👥 (labor) is injected, its Icon contains:

```gdscript
// IconRegistry contains labor_icon with:
hamiltonian_couplings = {
    "🌾": 0.25,  // Labor couples to wheat
    "🍄": 0.15,  // Labor couples to mushrooms
    // ... etc
}

lindblad_operators = {
    "🌾": {
        "coupling_strength": 0.05,
        "target_emoji": "🌾"
    }
}
```

This creates Hamiltonian matrix entries:
```
H[🌾][👥] = 0.25
H[👥][🌾] = 0.25  (Hermitian conjugate)
```

### Projection State (Initial)

After injection, the DualEmojiQubit reads from bath:

```
For N-emoji bath in maximally mixed state:
ρ = (1/N) × I_N

Projection onto {🌾, 👥} subspace:
- P(🌾) ≈ 1/N
- P(👥) ≈ 1/N
- Off-diagonal coherences ≈ 0
- Bloch radius ≈ 0  (maximally mixed 2-state)
- Theta ≈ π/2 (equal probabilities)
```

**This is expected!** Coherence builds via Hamiltonian evolution over time.

## Example: Wheat Planting on BioticFlux

### Initial State
```
BioticFlux bath: ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]
Dimension: 6
```

### Planting Wheat at (2,0)
```
1. Get plot emojis: {"north": "🌾", "south": "👥"}
2. Check bath:
   - 🌾 exists ✅
   - 👥 missing ❌
3. Inject 👥:
   - Get labor_icon from IconRegistry
   - Expand bath: 6 → 7 dimensions
   - Add H[🌾][👥] = 0.25 coupling
   - Normalize: Tr(ρ) = 1
4. Create projection:
   - DualEmojiQubit("🌾", "👥", θ=π/2, bath)
   - Initial: r≈0, θ≈π/2, purity≈0.5
5. Mark plot planted
```

### After Injection
```
BioticFlux bath: ["☀", "🌙", "🌾", "🍄", "💀", "🍂", "👥"]
Dimension: 7
H[🌾][👥] = 0.25 ✅
Plot quantum_state.radius ≈ 0.000342 (will grow via evolution)
```

## Evolution After Planting

The Hamiltonian drives coherent oscillations:

```
dρ/dt = -i[H, ρ] + L(ρ)

Coherence growth:
t=0.0s:  radius=0.000342
t=0.5s:  radius=0.007863  (23× increase!)
t=3.0s:  radius≈0.1-0.5   (depends on coupling)
t=5.0s:  radius≈0.3-0.8   (harvestable range)
```

## Cost System (Legacy)

Early implementations used labor/wheat costs. Current bath-first mode uses **free injection** with evolution time as the limiting factor.

```gdscript
# Old cost system (optional, configurable per biome):
plant(labor_cost: float, wheat_cost: float, biome: BiomeBase)
  → economy.spend_resource("👥", labor_cost)
  → economy.spend_resource("🌾", wheat_cost)
  → if affordable → inject and plant
```

## Visualization

Planted plots show:
- Bloch sphere bubble with current radius (coherence)
- Color gradient based on theta (north/south mix)
- Pulsing animation during evolution
- Glow intensity proportional to radius

## Plot-Biome Assignments

**CRITICAL**: Plots must be assigned to the correct biome for injection to work:

```gdscript
// Farm.gd - Lines 197-215
Market biome:      (0,0), (1,0)    - T, Y keys
BioticFlux biome:  (2,0)-(5,0)     - U, I, O, P keys  ← WHEAT HERE
Forest biome:      (0,1)-(3,1)     - 0, 9, 8, 7 keys
Kitchen biome:     (4,1), (5,1)    - comma, period keys
```

Planting wheat on Market plot (0,0) injects 👥 into **Market bath**, not BioticFlux!

## Debugging

### Check if emoji was injected:
```gdscript
var biome = farm.biotic_flux_biome
print(biome.bath.emoji_list)  # Should include 👥 after wheat planting
```

### Check Hamiltonian coupling:
```gdscript
var H = biome.bath._hamiltonian
var i = biome.bath.emoji_to_index["🌾"]
var j = biome.bath.emoji_to_index["👥"]
var coupling = H.get_element(i, j)
print("H[🌾][👥] = %.6f" % coupling.abs())  # Should be 0.250000
```

### Check plot quantum state:
```gdscript
var plot = farm.grid.get_plot(Vector2i(2, 0))
print("North: %s, South: %s" % [plot.quantum_state.north_emoji, plot.quantum_state.south_emoji])
print("Radius: %.6f" % plot.quantum_state.radius)
print("Theta: %.6f" % plot.quantum_state.theta)
```

## Common Issues

### Issue: "?" harvest outcome
**Cause**: Harvesting before coherence builds (r≈0)
**Solution**: Wait 3-5 seconds for evolution, or use entanglement (Tool 1 E)

### Issue: Injection not working
**Cause**: Planting on wrong biome's plots
**Solution**: Ensure wheat planted on BioticFlux plots (U/I/O/P, positions 2-5)

### Issue: No Hamiltonian coupling
**Cause**: Icon not in IconRegistry
**Solution**: Verify IconRegistry has labor_icon with wheat couplings

## Summary

1. **Planting** creates DualEmojiQubit projection onto biome's bath
2. **Missing emojis** are auto-injected with full Icon physics
3. **Injection** expands Hilbert space, rebuilds Hamiltonian with new couplings
4. **Initial coherence** is near-zero (maximally mixed subspace)
5. **Evolution** builds coherence via H[north][south] coupling
6. **Harvest** extracts resources after sufficient evolution time

**Key insight**: Planting is NOT just placing a sprite - it's creating a live quantum projection with dynamic emoji injection and Hamiltonian physics!
