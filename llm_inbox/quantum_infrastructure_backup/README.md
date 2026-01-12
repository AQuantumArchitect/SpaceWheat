# SpaceWheat Quantum Mechanics - LLM Export

**19 files** showing the complete quantum mechanics flow:
Factions → Icons → Hamiltonians/Lindblads → QuantumComputer simulation

## File Index

### Layer 1: Factions (Define Dynamics)
| File | Purpose |
|------|---------|
| `01_Faction.gd` | Base faction class - defines emoji signatures + Hamiltonian/Lindblad terms |
| `01_CoreFactions.gd` | 10 core factions (Celestial, Verdant, Mycelial, etc.) |
| `01_IconBuilder.gd` | Merges faction contributions → builds Icons |

### Layer 2: Icons (Output of Faction System)
| File | Purpose |
|------|---------|
| `03_Icon.gd` | Icon data structure - holds merged Hamiltonian/Lindblad terms |
| `03_IconRegistry.gd` | Autoload singleton - stores and retrieves icons by emoji |

### Layer 3: Quantum Operators
| File | Purpose |
|------|---------|
| `03_HamiltonianBuilder.gd` | Builds Hamiltonian from Icons |
| `03_Hamiltonian.gd` | Hamiltonian class - unitary evolution terms |
| `03_LindbladBuilder.gd` | Builds Lindblad operators from Icons |
| `03_LindbladSuperoperator.gd` | Lindblad class - dissipation/decoherence terms |

### Layer 4: Simulation Engine
| File | Purpose |
|------|---------|
| `03_QuantumComputer.gd` | Main simulation engine - evolves density matrix |
| `03_QuantumBath.gd` | Bath modes for biome simulation |
| `03_DensityMatrix.gd` | Quantum state representation (ρ matrix) |
| `03_QuantumGateLibrary.gd` | All quantum gates (Pauli-X, Hadamard, CNOT, etc.) |

### Layer 5: Foundation
| File | Purpose |
|------|---------|
| `03_Complex.gd` | Complex number math |
| `03_ComplexMatrix.gd` | Matrix operations |
| `03_DualEmojiQubit.gd` | Qubit representation (emoji poles) |
| `03_RegisterMap.gd` | Maps emojis → qubit indices |

### Layer 6: Game Integration
| File | Purpose |
|------|---------|
| `02_QuantumMill.gd` | Example quantum structure (Mill) |
| `04_ToolConfig.gd` | Tools (1-6) and quantum gate UI |

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    FACTION → ICON PIPELINE                      │
├─────────────────────────────────────────────────────────────────┤
│  CoreFactions.gd                                                │
│    │                                                            │
│    ├─ Celestial Archons: ☀🌙 + day/night Hamiltonian           │
│    ├─ Verdant Pulse: 🌱🌿🌾 + growth Lindblad                   │
│    ├─ Mycelial Web: 🍄💀🌿 + decomposition Lindblad             │
│    └─ ... 7 more factions                                       │
│                                                                 │
│  IconBuilder.build_icons_for_factions(all_factions)             │
│    │                                                            │
│    └─ For each emoji (🌾, 🍄, ☀, ...):                          │
│        └─ Merge all faction contributions → Icon                │
│                                                                 │
│  IconRegistry.register_icon(icon)                               │
│    └─ 78+ icons available for biomes                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ICON → OPERATORS                             │
├─────────────────────────────────────────────────────────────────┤
│  Biome requests icons: icon_registry.get_icon("🌾")             │
│                                                                 │
│  HamiltonianBuilder.build(icons, register_map)                  │
│    └─ Builds rotation terms (population oscillations)           │
│                                                                 │
│  LindbladBuilder.build(icons, register_map)                     │
│    └─ Builds jump operators (irreversible transfers)            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    QUANTUM SIMULATION                           │
├─────────────────────────────────────────────────────────────────┤
│  QuantumComputer.evolve(dt)                                     │
│    │                                                            │
│    ├─ Hamiltonian: dρ/dt = -i[H, ρ]  (unitary rotation)         │
│    │                                                            │
│    └─ Lindblad: Σ(L ρ L† - ½{L†L, ρ}) (dissipation)             │
│                                                                 │
│  Result: Updated DensityMatrix with new populations             │
└─────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Factions
- Define **closed dynamical systems** over 3-7 emojis
- Specify Hamiltonian couplings (reversible oscillations)
- Specify Lindblad transfers (irreversible flows)
- Example: Verdant Pulse defines 🌱→🌿→🌾 growth dynamics

### Icons
- Built by **merging** faction contributions
- One icon per emoji (🌾, 🍄, ☀, etc.)
- Contains combined Hamiltonian + Lindblad terms from all factions

### Gated Lindblad
- Multiplicative dependencies: `rate × P(gate)^power`
- Example: No bees (🐝 = 0) → no grain production
- Inverse gating also supported: `rate × (1 - P(gate))^power`

### Bath Modes
- Oscillating drive terms (inverted sine wave)
- Examples: day/night (☀🌙), seasons, market cycles
- All use **unified oscillator** architecture

## Synced With
- `Core/Factions/` - faction definitions
- `Core/QuantumSubstrate/` - simulation engine
- `Core/GameState/` - tool configuration

Last synced: 2026-01-08
