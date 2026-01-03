# SpaceWheat Quantum Bath Architecture
## Master Design Document

---

## The Cosmology

```
┌─────────────────────────────────────────────────────────────────┐
│                         ICONS                                    │
│         The eternal Hamiltonians. Gods of interaction.          │
│                                                                  │
│    Each emoji may have an Icon attached that defines:           │
│    • H terms (how it rotates other states - unitary)            │
│    • L terms (how it transfers energy - dissipative)            │
│                                                                  │
│    Icons are the VERBS of the universe.                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         BIOMES                                   │
│              Quantum baths. Regions of space.                    │
│                                                                  │
│    Constructed by combining emojis:                              │
│    • Each emoji brings its Icon's H and L terms                 │
│    • H_biome = Σ weight_i × H_icon_i                            │
│    • L_biome = Σ weight_i × L_icon_i                            │
│    • Bath state |ψ⟩ = Σ αᵢ|emoji_i⟩ evolves accordingly        │
│                                                                  │
│    Biomes are the NOUNS of space.                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         PLOTS                                    │
│           Measurement apparatuses. Player interface.             │
│                                                                  │
│    Each plot projects the bath onto a chosen axis:              │
│    • North emoji ↔ South emoji                                  │
│    • DualEmojiQubit = projection of bath onto this axis         │
│    • Measurement collapses bath (backaction)                    │
│                                                                  │
│    Plots are the WINDOWS into the quantum world.                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Mathematical Foundation

### The Quantum Bath

A biome's bath is a state vector over N emoji basis states:

```
|ψ_bath⟩ = Σᵢ αᵢ |emoji_i⟩

where:
  αᵢ ∈ ℂ (complex amplitude)
  Σᵢ |αᵢ|² = 1 (normalization)
```

The bath evolves via the Lindblad master equation:

```
d|ψ⟩/dt = -i H_total |ψ⟩ + Σₖ (Lₖ ρ Lₖ† - ½{Lₖ†Lₖ, ρ})

where:
  H_total = Σ (Icon Hamiltonians)
  Lₖ = Jump operators from Icon Lindblad terms
```

For computational efficiency, we evolve the state vector (not density matrix) with stochastic unraveling when needed.

### Icon Structure

Each Icon defines:

```
Icon_emoji = {
    H: Dictionary[target_emoji → Complex coupling],
    L: Dictionary[target_emoji → Real transfer_rate],
    self_energy: Real (diagonal H term),
    decay_rate: Real (self-dissipation)
}
```

The total Hamiltonian is constructed:

```
H_total[i,j] = Σ_icons (icon.H[emoji_i → emoji_j] + h.c.) / 2
H_total[i,i] = Σ_icons icon.self_energy (for emoji_i)
```

The Lindblad jump operators:

```
L_k = √(rate) |target⟩⟨source|

Applied as:
  α_target += √(rate × dt) × α_source
  α_source *= √(1 - rate × dt)
```

### Projection Mechanics

When a plot with axes (north, south) observes the bath:

```
Let:
  α_n = bath amplitude of north emoji
  α_s = bath amplitude of south emoji

Then:
  radius = √(|α_n|² + |α_s|²)
  θ = 2 × arccos(|α_n| / radius)  if radius > ε else π/2
  φ = arg(α_n) - arg(α_s)
```

The radius tells us how much "spirit" is in this subspace.
The theta tells us the north/south balance.
The phi tells us the relative phase (quantum coherence).

### Measurement Backaction

When player measures a plot:

```
Outcome north (probability = |α_n|² / (|α_n|² + |α_s|²)):
  α_n *= (1 + collapse_strength)
  α_s *= (1 - collapse_strength)
  renormalize bath

Outcome south (probability = |α_s|² / (|α_n|² + |α_s|²)):
  α_s *= (1 + collapse_strength)
  α_n *= (1 - collapse_strength)
  renormalize bath
```

Partial collapse allows quantum mechanics to persist while still having measurement effects.

---

## Key Design Decisions

### 1. Unitarity of Hamiltonian Evolution

The Hamiltonian part is strictly unitary. This means:
- H must be Hermitian: H = H†
- Evolution preserves total probability
- Biomes can be composed by summing Hamiltonians
- Time evolution is reversible (in the H part)

### 2. Lindblad for Directed Flow

Energy/amplitude transfer is handled by Lindblad operators:
- Predation: L = √γ |predator⟩⟨prey|
- Growth: L = √γ |grown⟩⟨seed|
- Decay: L = √γ |dead⟩⟨alive|

This separates "how things mix" (H) from "where energy flows" (L).

### 3. Icons as Atomic Design Units

Each Icon is self-contained. To add a new emoji to the universe:
1. Define its Icon (H terms, L terms)
2. Add to IconRegistry
3. Include emoji in biomes
4. Behavior emerges automatically

### 4. Biomes as Icon Compositions

A biome is defined by:
- Which emojis are present
- What weights/abundances each has
- Environmental parameters (temperature, etc.)

The physics emerges from the combined Icons.

### 5. Plots as Projections, Not Storage

Plots don't own quantum states. They project from the bath.
Multiple plots can project overlapping axes.
Measurement on one plot affects all projections from same bath.

---

## Emergence Examples

### Predator-Prey from Icons

Given Icons:
```
Icon_🐺 = {
    H: {🐇: 0.3, 🦌: 0.2},      // Wolf couples to prey
    L: {🐺: 0.1 from 🐇},       // Wolf gains from rabbit
    self_energy: -0.1           // Slight decay without food
}

Icon_🐇 = {
    H: {🌿: 0.5, 🐺: 0.3},      // Rabbit couples to food and predator
    L: {🐇: 0.2 from 🌿},       // Rabbit gains from vegetation
    decay_rate: 0.05            // Natural death
}

Icon_🌿 = {
    H: {☀: 0.7},               // Vegetation couples to sun
    L: {🌿: 0.3 from ☀},       // Vegetation grows from sunlight
    self_energy: 0.0
}
```

Emergent behavior:
1. ☀ drives 🌿 growth (L term)
2. 🌿 amplitude increases
3. 🐇 gains from 🌿 (L term)
4. 🐇 amplitude increases
5. 🐺 gains from 🐇 (L term)
6. 🐺 amplitude increases, 🐇 decreases
7. Less 🐇 means 🐺 decays
8. Less 🐺 means 🐇 recovers
9. Lotka-Volterra oscillation emerges!

No hand-coded differential equations. Just Icons.

### Day/Night Cycle from Icons

```
Icon_☀ = {
    H: {🌙: 0.1},              // Sun couples to moon (drives oscillation)
    L: {},                      // No dissipation (eternal)
    self_energy: cos(ωt)        // External driving
}

Icon_🌾 = {
    H: {☀: 0.5},               // Wheat couples to sun
    L: {🌾: 0.2 from ☀},       // Wheat gains from sun alignment
}
```

The external driving of ☀ self_energy creates the day/night cycle.
Wheat's L term makes it grow when aligned with sun.

---

## File Structure

```
Core/
├── QuantumSubstrate/
│   ├── QuantumBath.gd         # Bath state and evolution
│   ├── Icon.gd                # Single Icon definition
│   ├── IconRegistry.gd        # Singleton registry of all Icons
│   ├── Complex.gd             # Complex number utilities
│   └── DualEmojiQubit.gd      # (existing, now derived from bath)
│
├── Environment/
│   ├── BiomeBase.gd           # (upgraded with bath)
│   ├── BioticFluxBiome.gd     # (retrofitted)
│   ├── ForestEcosystem_Biome.gd # (rebuilt with Icons)
│   └── MarketBiome.gd         # (future)
│
├── GameMechanics/
│   ├── BasePlot.gd            # (upgraded for projection)
│   ├── FarmPlot.gd            # (upgraded for projection)
│   └── FarmGrid.gd            # (minimal changes)
│
└── Icons/
    ├── CelestialIcons.gd      # ☀, 🌙
    ├── FloraIcons.gd          # 🌾, 🍄, 🌿, 🌱, 🌳, 🌲
    ├── FaunaIcons.gd          # 🐺, 🐇, 🦌, 🐦, 🦅, 🐭
    ├── ElementalIcons.gd      # 💧, ⛰, 💨, ☔
    └── EconomicIcons.gd       # 💰, 📦, 🏪
```

---

## Next Documents

1. **01_QUANTUM_BATH.md** - Detailed bath mechanics and evolution
2. **02_ICON_SYSTEM.md** - Icon structure, composition, registry
3. **03_PROJECTION_MECHANICS.md** - How plots project from bath
4. **04_BIOME_CONSTRUCTION.md** - Building biomes from Icons
5. **05_IMPLEMENTATION_PLAN.md** - Phased development approach
6. **06_CODE_STUBS.md** - GDScript class stubs

