# Quantum Infrastructure Backup

**Date**: 2026-01-08
**Status**: Complete working system with all 27 factions and 78 icons

This directory contains a complete backup of the quantum computing infrastructure, faction system, and icon registry from SpaceWheat.

## What's Included

### QuantumSubstrate/ (30 files)
Core quantum computing engine:
- **QuantumComputer.gd** - Main quantum simulator (density matrix evolution)
- **QuantumComponent.gd** - Base class for quantum system components
- **QuantumGateLibrary.gd** - Library of quantum gates (Pauli, Hadamard, CNOT, etc.)
- **HamiltonianBuilder.gd** - Constructs Hamiltonian from faction icons
- **LindbladBuilder.gd** - Builds Lindblad operators for dissipative evolution
- **QuantumRegister.gd** - Manages qubits and basis states
- **RegisterMap.gd** - Maps emoji pairs to qubit axes
- **Icon.gd** - Icon class (hamiltonian couplings, lindblad transfers, drivers)
- **IconRegistry.gd** - Registry of all 78 icons built from factions
- **DensityMatrix.gd** - Density matrix representation
- **Complex.gd** - Complex number arithmetic
- Plus 19 more supporting files

### Factions/ (6 files)
Complete faction system with all 27 factions:
- **Faction.gd** - Base faction class (NEW: supports typed arrays, gated lindblad, measurement inversion)
- **CoreFactions.gd** - 10 core ecosystem factions (Celestial, Verdant, Mycelial, Swift Herd, Pack Lords, Market Spirits, Hearth Keepers, Pollinator Guild, Plague Vectors, Wildfire)
- **CivilizationFactions.gd** - 7 civilization factions (Granary Guilds, Millwright's Union, Scavenged Psithurism, Yeast Prophets, Station Lords, Void Serfs, Carrion Throne)
- **Tier2Factions.gd** - 10 tier 2 factions (4 Commerce, 3 Industry, 3 Governance)
- **AllFactions.gd** - Unified access to all 27 factions
- **IconBuilder.gd** - Merges faction contributions to build icons

### Icons/ (12 files)
Individual icon specifications (legacy):
- BioticFluxIcon.gd
- ForestEcosystemIcon.gd
- WheatIcon.gd
- And 9 more custom icons

Note: Most icons are now built dynamically from factions via IconBuilder

### GameMechanics/ (1 file)
- **QuantumMill.gd** - Quantum gate application tool for gameplay

## Key Mechanics Implemented

### 1. Inverted Sine Wave Oscillators (Unified)
All time-dependent drivers use the same mechanic: `sin(ωt)` vs `sin(ωt + π)`
- 🔌 @ 1.0 Hz (AC power grid, 1 sec)
- 🔥❄️ @ 0.067 Hz (Kitchen cycle, 15 sec)
- ☀🌙 @ 0.05 Hz (Celestial clock, 20 sec)
- 🐂🐻 @ 0.033 Hz (Market cycle, 30 sec)

### 2. Measurement Inversion (Quantum Mask)
Emoji 🧤 has inverts=true, so measuring it collapses to the OPPOSITE pole of its axis:
- On axis (🧤, 🗑): measure 🧤 → reveals 🗑
- On axis (🧤, 💀): measure 🧤 → reveals 💀
- Enables "basis state smuggling" in biome design

### 3. Gated Lindblad
Transfers with multiplicative dependencies:
- Normal: `effective_rate = base_rate × P(gate)^power`
- Inverse: `effective_rate = base_rate × (1 - P(gate))^power` (starvation)

### 4. Negative Self-Energy
Debt emoji (💸) with negative energy for annihilation dynamics:
- Wealth and debt in same system cancel each other
- Creates economic constraint gameplay

## System Status

✅ All 27 factions compile and load
✅ IconBuilder creates 78 icons from faction contributions
✅ IconRegistry successfully initializes
✅ Quantum simulator fully operational
✅ All oscillators unified to inverted sine wave mechanic

## File Format

All .gd files are renamed to .gd.txt to prevent Godot from parsing them during game compilation. These are backup files for reference and version control.

## Related Documentation

See llm_outbox/ for:
- FACTION_UPGRADE_STATUS.md - Complete upgrade status
- INVERTED_SINE_OSCILLATORS.md - Unified oscillator mechanic
- FACTION_COMPILATION_FIXED.md - Fixes applied to make system compile
- measurement_inversion_implementation.gd - Reference implementation

## Total Files

- 49 files backed up
- Organized into 4 categories
- Complete working quantum simulation system
