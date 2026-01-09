# Tools (1-6) & Quantum Gates System

**Date**: 2026-01-08
**Status**: Complete implementation with all 6 tools and quantum gate library

## System Overview

The SpaceWheat tool system provides 6 different gameplay modes (Tools 1-6), each with three actions triggered by Q, E, R keys. Tools 5 specifically provides quantum gate operations using a comprehensive quantum gate library.

## Tool Definitions (1-6)

All tools are defined in **GameState.ToolConfig.gd.txt**:

### Tool 1: Grower 🌱
**Core farming** (80% of gameplay)
- **Q**: submenu_plant → Plant crops (Wheat/Mushroom/Tomato or biome-specific)
- **E**: entangle_batch → Create Bell φ+ entangled pairs
- **R**: measure_and_harvest → Measure qubits and harvest results

**Context-aware planting by biome**:
- Kitchen: Fire/Water/Flour ingredients
- Forest: Vegetation/Rabbit/Wolf organisms
- Market: Wheat/Flour/Bread commodities
- BioticFlux: Wheat/Mushroom/Tomato crops

### Tool 2: Quantum ⚛️
**Persistent gate infrastructure** (survives harvest)
- **Q**: cluster → Build multi-qubit gates (2=Bell, 3+=Cluster)
- **E**: measure_trigger → Set measurement triggers
- **R**: measure_batch → Measure entangled clusters

### Tool 3: Industry 🏭
**Economy & automation**
- **Q**: submenu_industry → Build infrastructure (Mill/Market/Kitchen)
- **E**: place_market → Build market structure
- **R**: place_kitchen → Build kitchen structure

### Tool 4: Biome Control ⚡
**Research-grade quantum control**
- **Q**: submenu_energy_tap → Energy taps for driving forces
  - Fire Tap (Kitchen): Drive 🔥 oscillator
  - Water Tap (Forest): Drive 💧 oscillator
  - Flour Tap (Market): Drive 💨 oscillator
- **E**: submenu_pump_reset → Prepare quantum states
  - Pump to Wheat: Build amplitude in wheat
  - Reset Pure: Create pure |0⟩ state
  - Reset Mixed: Create mixed state (equal superposition)
- **R**: tune_decoherence → Adjust decoherence (dissipation rate)

### Tool 5: Gates 🔄
**Quantum gate operations** (Primary tool for quantum circuit construction)

**1-Qubit Gates** (Q):
- Pauli-X (↔️): Flip qubit | X|0⟩=|1⟩, X|1⟩=|0⟩
- Hadamard (🌀): Create superposition | H|0⟩=(|0⟩+|1⟩)/√2
- Pauli-Z (⚡): Apply phase | Z|1⟩=-|1⟩

**2-Qubit Gates** (E):
- CNOT (⊕): Controlled-NOT | Flips target when control is |1⟩
- CZ (⚡): Controlled-Z | Applies phase when both qubits are |1⟩
- SWAP (⇄): Swap two qubits | Exchanges |a⟩|b⟩ ↔ |b⟩|a⟩

**R**: Remove Gates (💔)
- Delete all applied gates from selected plot/cluster

### Tool 6: Biome 🌍
**Ecosystem management**
- **Q**: submenu_biome_assign → Assign biome type
  - BioticFlux, Market, Forest, Kitchen, etc.
- **E**: clear_biome_assignment → Clear biome designation
- **R**: inspect_plot → Inspect plot quantum state

## Quantum Gate Library

**File**: QuantumSubstrate/QuantumGateLibrary.gd.txt

### Single-Qubit Gates

#### Pauli-X (NOT gate)
```
Matrix: [[0, 1], [1, 0]]
Effect: Flip qubit (|0⟩ → |1⟩, |1⟩ → |0⟩)
Use: Boolean NOT operation, state preparation
```

#### Pauli-Y
```
Matrix: [[0, -i], [i, 0]]
Effect: Rotation + flip
Use: Rotation around Y-axis
```

#### Pauli-Z
```
Matrix: [[1, 0], [0, -1]]
Effect: Apply phase shift to |1⟩
Use: Phase correction, Z-basis measurement prep
```

#### Hadamard
```
Matrix: (1/√2) × [[1, 1], [1, -1]]
Effect: Create superposition: H|0⟩ = (|0⟩+|1⟩)/√2
        H|1⟩ = (|0⟩-|1⟩)/√2
Use: Create balanced superposition, basis change
```

#### Phase Gate (S)
```
Matrix: [[1, 0], [0, i]]
Effect: Apply π/2 phase to |1⟩
Use: Quantum state manipulation
```

#### T Gate
```
Matrix: [[1, 0], [0, e^(iπ/4)]]
Effect: Apply π/4 phase to |1⟩
Use: Fine-grained phase control
```

### Two-Qubit Gates

#### CNOT (CX)
```
Control qubit 'A', Target qubit 'B':
If A = |1⟩, flip B (apply X to B)
If A = |0⟩, do nothing to B
Matrix: [[1,0,0,0], [0,1,0,0], [0,0,0,1], [0,0,1,0]]
Use: Entanglement creation, basis state preparation
```

#### CZ (Controlled-Z)
```
Control qubit 'A', Target qubit 'B':
If both A=|1⟩ and B=|1⟩, apply phase
Otherwise, do nothing
Use: Conditional phase application, entanglement
```

#### SWAP
```
Exchange two qubits:
SWAP |ab⟩ = |ba⟩
Use: Qubit reordering, circuit optimization
```

#### iSWAP
```
SWAP with conditional phase
```

### Multi-Qubit Gates (Clusters)

#### Bell States (2-qubit entanglement)
- |Φ+⟩ = (|00⟩ + |11⟩)/√2 - Perfectly correlated
- |Φ-⟩ = (|00⟩ - |11⟩)/√2 - Correlated with phase
- |Ψ+⟩ = (|01⟩ + |10⟩)/√2 - Anti-correlated
- |Ψ-⟩ = (|01⟩ - |10⟩)/√2 - Anti-correlated with phase

**Creation**:
```
H(qubit_0)
CNOT(qubit_0, qubit_1)
Result: Bell |Φ+⟩
```

## Tool UI Components

### GameState.ToolConfig.gd.txt
**Master configuration file** for all 6 tools:
- Tool definitions (1-6) with Q/E/R actions
- Submenu definitions (plant, industry, energy_tap, pump_reset, single_gates, two_gates, biome_assign)
- Dynamic submenu generation logic
- Context-aware menu creation

### UI/FarmInputHandler.gd.txt
**Input handler** for tool actions:
- Reads Q/E/R keyboard input
- Routes actions to appropriate handlers
- Implements all tool actions:
  - Plant operations
  - Gate applications (Pauli-X, Hadamard, Pauli-Z, CNOT, CZ, SWAP)
  - Entanglement creation
  - Measurement operations
  - Biome management
  - Energy taps

### UI/Panels/ToolSelectionRow.gd.txt
**Tool selector UI**:
- Displays 6 tool buttons (1-6)
- Shows tool emoji and name
- Handles tool switching via keyboard (1-6 keys)

### UI/Panels/ActionPreviewRow.gd.txt
**Action preview UI**:
- Shows current Q/E/R actions for selected tool
- Displays action emoji, label, and keybind
- Updates dynamically based on tool selection
- Shows submenu state

### UI/Managers/ActionBarManager.gd.txt
**Action bar manager**:
- Coordinates tool UI display
- Manages action row updates
- Synchronizes tool selection with game state

## Integration Points

### QuantumComputer.gd (Already in backup)
Applies gates via:
```gdscript
func apply_single_qubit_gate(gate_name: String, target_qubit: int)
func apply_two_qubit_gate(gate_name: String, control_qubit: int, target_qubit: int)
```

### BiomeBase.gd (Not in backup)
Manages biome selection and tool context

### FarmGrid.gd (Not in backup)
Stores plot assignments and manages grid state

## Key Mechanics

### 1. Context-Aware Tool Actions
Tool actions change based on:
- Selected plot's biome assignment
- Discovered vocabulary (available emojis)
- Quantum state of selected qubits
- Current game mode

### 2. Hierarchical Actions
- Tool level: 6 main tools
- Submenu level: Q triggers submenu, E/R execute actions within
- Multi-level allows complex workflows without excessive buttons

### 3. Bell Gate Creation (Tool 1, E key)
Creates Bell φ+ entangled pairs:
```
Initial state: |00⟩
Apply Hadamard to qubit 0: (|00⟩ + |10⟩)/√2
Apply CNOT(0→1): (|00⟩ + |11⟩)/√2 = |Φ+⟩
```

### 4. Tool 5: Quantum Circuit Construction
Complete quantum gate library for building arbitrary quantum circuits:
- Single-qubit gates (Pauli-X/Y/Z, Hadamard, Phase, T)
- Two-qubit gates (CNOT, CZ, SWAP)
- Multi-qubit clusters via Tool 2

### 5. Energy Taps (Tool 4, Q)
Drive specific emojis with sinusoidal oscillators:
- Fire Tap: Drives 🔥 oscillator in Kitchen
- Water Tap: Drives 💧 oscillator in Forest
- Flour Tap: Drives 💨 oscillator in Market

## Files Included in Backup

```
llm_inbox/quantum_infrastructure_backup/
├── GameState.ToolConfig.gd.txt          (Tool definitions 1-6)
├── QuantumSubstrate/
│   ├── QuantumGateLibrary.gd.txt        (All quantum gates)
│   ├── QuantumComputer.gd.txt           (Gate application)
│   └── ... (other quantum files)
└── UI/
    ├── FarmInputHandler.gd.txt          (Input + action handling)
    ├── Managers/
    │   └── ActionBarManager.gd.txt      (Action bar UI)
    └── Panels/
        ├── ToolSelectionRow.gd.txt      (Tool selector)
        └── ActionPreviewRow.gd.txt      (Action preview)
```

## Summary

**Tool System Features**:
- 6 complete tools with context-aware Q/E/R actions
- Hierarchical submenu system for complex workflows
- Dynamic menu generation based on game state

**Quantum Gates**:
- Complete single-qubit gate library (Pauli, Hadamard, Phase, T)
- Complete two-qubit gate library (CNOT, CZ, SWAP, iSWAP)
- Bell state preparation and manipulation
- Multi-qubit clustering for advanced circuits

**Integration**:
- Seamless keyboard control (1-6 for tools, Q/E/R for actions)
- Context-aware action menus
- Real-time game state synchronization
- Support for future extensions (more gates, more tools)

This tool system represents the primary user interface for quantum mechanics in SpaceWheat - enabling players to construct and manipulate quantum systems through an intuitive keyboard-driven interface.
