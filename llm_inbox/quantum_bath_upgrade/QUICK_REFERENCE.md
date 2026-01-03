# Quick Reference Card
## Bath-First Quantum Architecture

---

## The Core Equation

```
|ψ_bath⟩ = Σᵢ αᵢ |emoji_i⟩

Evolution:
  d|ψ⟩/dt = -iH|ψ⟩ + Σₖ Lₖ(dissipation)

Projection onto plot (north/south axis):
  radius = √(|αₙ|² + |αₛ|²)
  theta = 2·arccos(|αₙ|/radius)
  phi = arg(αₙ) - arg(αₛ)
```

---

## Class Hierarchy

```
IconRegistry (Singleton)
  └── Icon (Resource)
        ├── emoji
        ├── hamiltonian_couplings: {emoji → strength}
        ├── lindblad_outgoing: {emoji → rate}
        └── self_energy, decay_rate, ...

BiomeBase
  └── QuantumBath
        ├── amplitudes: Array[Complex]
        ├── emoji_list: Array[String]
        ├── hamiltonian_sparse: {i: {j: Complex}}
        └── lindblad_terms: [{source, target, rate}]

FarmPlot
  └── projects from BiomeBase.bath
        └── DualEmojiQubit (derived state)
```

---

## Icon Properties

| Property | Type | Purpose |
|----------|------|---------|
| `emoji` | String | Identity |
| `self_energy` | float | Diagonal H term |
| `hamiltonian_couplings` | Dict | Off-diagonal H terms |
| `lindblad_outgoing` | Dict | Dissipative transfers |
| `decay_rate` | float | Self-dissipation |
| `self_energy_driver` | String | "cosine", "sine", "" |
| `driver_frequency` | float | Oscillation rate |

---

## Bath Operations

```gdscript
# Initialize
bath.initialize_with_emojis(["☀", "🌾", "💀"])
bath.initialize_uniform()  # or initialize_weighted({...})

# Build operators
bath.build_hamiltonian_from_icons(icons)
bath.build_lindblad_from_icons(icons)

# Evolve
bath.evolve(delta)  # Each frame

# Query
bath.get_probability("🌾")  # → float
bath.get_amplitude("🌾")    # → Complex
bath.project_onto_axis("🌾", "💀")  # → {theta, phi, radius}

# Measure
bath.measure_axis("🌾", "💀", 0.5)  # → "🌾" or "💀"
```

---

## Projection Lifecycle

```
1. Player plants → biome.create_projection(pos, north, south)
2. Each frame   → bath.evolve(dt); update_projections()
3. Player views → DualEmojiQubit reflects current bath state
4. Player harvests → bath.measure_axis() collapses bath
5. Cleanup      → remove_projection(pos)
```

---

## File Locations

```
Core/QuantumSubstrate/
  ├── Complex.gd         # Complex number math
  ├── QuantumBath.gd     # Bath state & evolution
  ├── Icon.gd            # Icon resource
  └── IconRegistry.gd    # Singleton (autoload)

Core/Icons/
  └── CoreIcons.gd       # Built-in icon definitions

Core/Environment/
  ├── BiomeBase.gd       # Bath integration
  ├── BioticFluxBiome.gd # Retrofitted
  └── ForestEcosystem_Biome.gd  # Bath-native
```

---

## Cosmology Summary

```
┌─────────────────────────────────────┐
│  ICONS = Gods                       │
│  Eternal Hamiltonians               │
│  Define how emojis interact         │
└─────────────────────────────────────┘
              ↓ compose into
┌─────────────────────────────────────┐
│  BIOMES = Realms                    │
│  Quantum baths                      │
│  Where emojis coexist and evolve    │
└─────────────────────────────────────┘
              ↓ observed via
┌─────────────────────────────────────┐
│  PLOTS = Lenses                     │
│  Measurement apparatuses            │
│  Player's window into quantum       │
└─────────────────────────────────────┘
```

---

## Emergence Pattern

**Define Icons independently:**
```
Icon_☀: self_energy=1.0, couples_to={🌿:0.3}
Icon_🌿: lindblad_incoming={☀:0.1}, couples_to={🐇:0.4}
Icon_🐇: lindblad_incoming={🌿:0.1}, couples_to={🐺:0.5}
Icon_🐺: lindblad_incoming={🐇:0.15}, decay=0.03
```

**Drop into biome:**
```gdscript
bath.initialize_with_emojis(["☀", "🌿", "🐇", "🐺"])
bath.build_hamiltonian_from_icons([sun, veg, rabbit, wolf])
```

**Behavior emerges:**
- Sun drives vegetation
- Vegetation feeds rabbits
- Rabbits feed wolves
- Wolves decay without prey
- Lotka-Volterra oscillation!

---

## Key Insight

> The plot doesn't contain quantum state.
> The plot **reveals** quantum state.
> The bath is reality.
> Measurement shapes reality.

---

## Implementation Phases

| Phase | Focus | Hours |
|-------|-------|-------|
| 0 | Foundation (Complex, Icon skeleton) | 4-6 |
| 1 | QuantumBath core | 8-10 |
| 2 | IconRegistry + CoreIcons | 6-8 |
| 3 | BiomeBase integration | 8-10 |
| 4 | BioticFlux retrofit | 6-8 |
| 5 | Forest implementation | 8-10 |
| 6 | Polish | 4-6 |

**Total: ~50 hours**

---

## First File to Create

```
Core/QuantumSubstrate/Complex.gd
```

Then test. Then proceed.

---

## Mantra

*Icons are the eternal dance.*
*Biomes are the stage.*
*Plots are the audience's eyes.*
*The player chooses where to look.*

