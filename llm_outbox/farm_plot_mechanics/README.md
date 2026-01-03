# Farm Plot Mechanics Documentation

## Overview
This package documents the complete farm plot system in SpaceWheat, including plot types, tool interactions, biome integration, and quantum state management.

## Package Contents

### Core Documentation
1. **01_plot_architecture.md** - Plot class hierarchy and core concepts
2. **02_plot_lifecycle.md** - Plant → Grow → Measure → Harvest flow
3. **03_tools_system.md** - 6 tools and their QER actions
4. **04_biome_integration.md** - How plots connect to biomes
5. **05_quantum_gates.md** - Entanglement and gate infrastructure
6. **06_code_examples.md** - Detailed code walkthrough with .gdtxt format

### Quick Reference
- **QUICK_REFERENCE.md** - Fast lookup for plot types, tools, and methods

## Key Concepts

### Plot Types
- **BasePlot** - Foundation class with quantum state
- **FarmPlot** - Player-interactive plots (wheat, mushroom, tomato)
- **BiomePlot** - Biome-managed plots (not player-controlled)

### Tool System
- **6 tools** - Each with 3 actions (Q, E, R keys)
- **Grower (1)**: Plant, Entangle, Harvest
- **Quantum (2)**: Build Gates, Measure Trigger, Remove Gates
- **Industry (3)**: Build Mills/Markets/Kitchens
- **Energy (4)**: Energy Tap management
- **Gates (5)**: 1-qubit and 2-qubit gate operations
- **Future (6)**: Reserved for expansion

### Biome Integration
- **Multi-biome support** - Plots can be assigned to different biomes
- **BioticFlux** - Default farming biome (sun/moon cycle)
- **Forest** - Ecosystem biome (organisms)
- **Market** - Trading biome (sentiment/liquidity)

### Quantum Mechanics
- **DualEmojiQubit** - Every plot has (theta, phi, radius) state
- **Bell pairs** - 2-qubit entanglement
- **Clusters** - N-qubit entanglement
- **Persistent gates** - Infrastructure that survives harvest

## Reading Path

### For Game Designers
1. Start with **01_plot_architecture.md** for concepts
2. Read **02_plot_lifecycle.md** for gameplay flow
3. Review **03_tools_system.md** for player interactions

### For Programmers
1. Read **06_code_examples.md** for implementation details
2. Review **01_plot_architecture.md** for class hierarchy
3. Study **05_quantum_gates.md** for advanced mechanics

### For External Integration
1. **04_biome_integration.md** - How to connect custom biomes
2. **05_quantum_gates.md** - How to work with quantum states
3. **QUICK_REFERENCE.md** - API lookup

## System Flow

```
Player → Tool → FarmGrid → Plot → Biome → Quantum State
   ↑                                  ↓
   └──────────── Harvest ←────────────┘
```

**Key insight:** FarmGrid orchestrates all interactions, routing tool actions to the correct plots and biomes.
