# Quantum Infrastructure + Tools Backup - COMPLETE

**Date**: 2026-01-08
**Location**: `SpaceWheat/llm_inbox/quantum_infrastructure_backup/`
**Status**: ✅ Complete

## What's Included

### 1. Quantum Simulation Core (30 files)
**Directory**: `QuantumSubstrate/`

Core quantum computing engine with full support for density matrix evolution, quantum gates, and Hamiltonian/Lindblad dynamics.

**Key Files**:
- `QuantumComputer.gd.txt` - Main quantum simulator (Schrödinger + Lindblad evolution)
- `QuantumGateLibrary.gd.txt` - All quantum gates (Pauli, Hadamard, CNOT, CZ, SWAP, Phase, T)
- `QuantumComponent.gd.txt` - Base class for quantum components
- `HamiltonianBuilder.gd.txt` - Constructs Hamiltonian from faction icons
- `LindbladBuilder.gd.txt` - Builds Lindblad operators for dissipative evolution
- `QuantumRegister.gd.txt` - Manages qubits and basis states
- `RegisterMap.gd.txt` - Maps emoji pairs to qubit axes
- `Icon.gd.txt` - Icon class with Hamiltonian couplings, Lindblad transfers, drivers
- `IconRegistry.gd.txt` - Registry of 78 icons built from 27 factions
- `DensityMatrix.gd.txt`, `Complex.gd.txt`, `ComplexMatrix.gd.txt` - Math primitives
- Plus 20 additional supporting files

### 2. Faction System (6 files)
**Directory**: `Factions/`

Complete faction system with 27 factions (10 Core + 7 Civilization + 10 Tier 2) defining quantum dynamics.

**Files**:
- `Faction.gd.txt` - Base faction class (NEW: typed arrays, gated lindblad, measurement inversion)
- `CoreFactions.gd.txt` - 10 core ecosystem factions
- `CivilizationFactions.gd.txt` - 7 civilization factions
- `Tier2Factions.gd.txt` - 10 tier 2 factions (Commerce, Industry, Governance)
- `AllFactions.gd.txt` - Unified access to all 27 factions
- `IconBuilder.gd.txt` - Merges faction contributions to build icons

### 3. Icon Specifications (12 files)
**Directory**: `Icons/`

Individual icon specifications (legacy). Most are now built dynamically from factions.

**Files**:
- BioticFluxIcon.gd.txt
- ForestEcosystemIcon.gd.txt
- WheatIcon.gd.txt
- And 9 more custom icons

### 4. Game Mechanics (1 file)
**Directory**: `GameMechanics/`

- `QuantumMill.gd.txt` - Quantum gate application tool for gameplay

### 5. Tool System & Quantum Gates (5 files)
**Directory**: `UI/` + Root

**Tool Configuration**:
- `GameState.ToolConfig.gd.txt` - Master tool definitions (Tools 1-6) with Q/E/R actions

**Tool UI Components**:
- `UI/FarmInputHandler.gd.txt` - Input handler for all tool actions
- `UI/Managers/ActionBarManager.gd.txt` - Action bar UI management
- `UI/Panels/ToolSelectionRow.gd.txt` - Tool selector UI (1-6)
- `UI/Panels/ActionPreviewRow.gd.txt` - Action preview display

### 6. Documentation (3 files)

**In this backup**:
- `README.md` - Complete system overview
- `TOOLS_AND_GATES.md` - Tools 1-6 and quantum gate library documentation
- `BACKUP_COMPLETE.md` - This file

**In llm_outbox/**:
- `FACTION_UPGRADE_STATUS.md` - Faction system upgrade status
- `INVERTED_SINE_OSCILLATORS.md` - Unified oscillator mechanics
- `FACTION_COMPILATION_FIXED.md` - Fixes applied to faction system
- `measurement_inversion_implementation.gd` - Reference implementation

## Key Features

### Tools (1-6)

**Tool 1 - Grower** 🌱: Core farming
- Plant crops (context-aware by biome)
- Create Bell φ+ entangled pairs
- Measure and harvest

**Tool 2 - Quantum** ⚛️: Persistent gate infrastructure
- Build multi-qubit gates
- Set measurement triggers
- Measure clusters

**Tool 3 - Industry** 🏭: Economy & automation
- Build mills, markets, kitchens

**Tool 4 - Biome Control** ⚡: Research-grade quantum control
- Energy taps (drive emojis)
- Pump/Reset operations
- Tune decoherence

**Tool 5 - Gates** 🔄: Quantum gate operations
- **1-Qubit**: Pauli-X, Hadamard, Pauli-Z, Phase, T
- **2-Qubit**: CNOT, CZ, SWAP
- **Multi-qubit**: Clusters and Bell states

**Tool 6 - Biome** 🌍: Ecosystem management
- Assign biome types
- Clear assignments
- Inspect plot state

### Quantum Mechanics

**Unified Oscillators**:
- All time-dependent drivers use `sin(ωt)` vs `sin(ωt + π)`
- Different frequencies for different domains (1 Hz, 0.067 Hz, 0.05 Hz, 0.033 Hz)

**Measurement Inversion**:
- Quantum masks that collapse to opposite pole of axis
- Enables "basis state smuggling" in biome design

**Gated Lindblad**:
- Multiplicative dependencies: `rate × P(gate)^power`
- Inverse gating: `rate × (1 - P(gate))^power` (starvation)

**Negative Self-Energy**:
- Debt emoji (💸) annihilates wealth
- Creates economic constraints

### Factions (27 total)

**Core Ecosystem (10)**:
Celestial Archons, Verdant Pulse, Mycelial Web, Swift Herd, Pack Lords, Market Spirits, Hearth Keepers, Pollinator Guild, Plague Vectors, Wildfire

**Civilization (7)**:
Granary Guilds, Millwright's Union, Scavenged Psithurism, Yeast Prophets, Station Lords, Void Serfs, Carrion Throne

**Tier 2 (10)**:
- Commerce: Ledger Bailiffs, Gilded Legacy, Quay Rooks, Bone Merchants
- Industry: Kilowatt Collective, Gearwright Circle, Rocketwright Institute
- Governance: Irrigation Jury, Indelible Precept, House of Thorns

## File Statistics

```
Total Files: 57 (including documentation)
├── QuantumSubstrate: 30 .gd.txt files
├── Factions: 6 .gd.txt files
├── Icons: 12 .gd.txt files
├── GameMechanics: 1 .gd.txt file
├── UI: 5 .gd.txt files (ToolConfig + 4 UI components)
├── Tools & Gates: 1 .gd.txt file (ToolConfig)
└── Documentation: 3 .md files

Total Size: ~2.5 MB
```

## File Format

All `.gd` files are renamed to `.gd.txt` to prevent Godot from parsing them during game compilation. These are backup/reference files for version control and code review.

## System Status

✅ **All 27 factions compile and load**
✅ **IconBuilder creates 78 icons from factions**
✅ **IconRegistry successfully initializes**
✅ **All 6 tools functional with Q/E/R actions**
✅ **Complete quantum gate library implemented**
✅ **All oscillators unified to inverted sine wave mechanic**
✅ **Measurement inversion (quantum masks) implemented**
✅ **Gated Lindblad infrastructure complete**

## Related Locations

**Active Game Files**: `Core/QuantumSubstrate/`, `Core/Factions/`, `UI/`, `Core/GameState/ToolConfig.gd`

**Documentation**: `llm_outbox/`
- FACTION_UPGRADE_STATUS.md
- INVERTED_SINE_OSCILLATORS.md
- FACTION_COMPILATION_FIXED.md

**Tests**: `Tests/` (various test files for tools, gates, factions)

## Quick Reference

### To Understand This System

1. **Start with**: `README.md` (overview)
2. **Tools**: `TOOLS_AND_GATES.md` (tool definitions + gate library)
3. **Factions**: `Factions/*.gd.txt` (faction implementations)
4. **Quantum Core**: `QuantumSubstrate/*.gd.txt` (simulator implementation)
5. **Icon System**: `Icons/*.gd.txt` + `Factions/IconBuilder.gd.txt` (icon building)

### Deployment

To restore from backup:
1. Copy `.gd.txt` files to active locations (rename back to `.gd`)
2. Update preload paths as needed
3. Clear Godot cache and rebuild

## Legacy Notes

This backup was created after fixing compilation issues in:
- Removed typed array annotations (`Array[String]` → `Array`)
- Added Faction preloads to CivilizationFactions and Tier2Factions
- Fixed Icon self-reference in static method

See `FACTION_COMPILATION_FIXED.md` for detailed fixes.

---

**Backup Complete**: Ready for version control, code review, and future reference.
