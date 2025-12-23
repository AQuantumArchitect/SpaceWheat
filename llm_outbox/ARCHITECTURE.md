# Quantum Farm Prototype - Architecture Analysis

**Date**: 2025-12-13
**Source**: Windows: `/mnt/c/Users/Luke/QuantumFarmGame` & Linux: `../archive_SpaceWheat/QuantumFarmGame`
**Status**: Operational prototype on Windows, archive on Linux (behind in development)

## Executive Summary

The existing Quantum Farm Game is a **working prototype** that successfully combines:
- Python QAGIS quantum kernel (v18-v20) with 16-mode continuous variable quantum simulation
- Godot 4.3+ game engine with 59 GDScript files and 23 scenes
- Emoji-based quantum mechanics using Bloch sphere + Gaussian CV representation
- 12-node "Quantum Tomato Conspiracy" meta-graph system
- Interactive graph-based farming with quantum bath temperature dynamics

## Core Architecture

### Three-Layer System

```
┌─────────────────────────────────────────────────────┐
│  GODOT GAME ENGINE (GDScript)                       │
│  - QuantumGraphGame.gd (main interactive game)      │
│  - DualEmojiQuantum.gd (Bloch sphere semantics)     │
│  - QuantumTomatoImporter.gd (Python integration)    │
│  - 59 total GDScript files                          │
└─────────────────┬───────────────────────────────────┘
                  │ WebSocket (port 9001)
                  │ OR standalone mock kernel
┌─────────────────▼───────────────────────────────────┐
│  PYTHON QUANTUM KERNEL (QAGIS v20)                  │
│  - qagis_kernel_v20.py (16 modes, 5D state)         │
│  - quantum_tomato_meta_graph.py (12 conspiracies)   │
│  - quantum_kernel_bridge.py (WebSocket server)      │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│  QUANTUM STATE REPRESENTATION                       │
│  - Bloch Sphere: (θ, φ) for semantic states         │
│  - Gaussian CV: (q, p) for continuous variables     │
│  - Energy: flows between entangled nodes            │
│  - 12-node conspiracy network (tomatoes)            │
│  - 16-mode semantic axes (base system)              │
└─────────────────────────────────────────────────────┘
```

## Key Components

### 1. QAGIS Kernel v20 (Python)

**File**: `QuantumKernel/qagis_kernel_v20.py`

**Structure**:
- **16 semantic axes** with emoji pairs (🌟🌑, 🔥💧, ⚡🍃, etc.)
- **5D quantum state**: [q, p, θ, φ, r]
  - `q, p`: Gaussian quadratures (position, momentum)
  - `θ, φ`: Bloch sphere angles (polar, azimuthal)
  - `r`: Radius/attention from water clock

**Key Features**:
- `GaussianBlochMode` class: Single quantum mode with full 5D state
- `QuantumState16` class: 16-mode network with entanglement graph
- Symplectic transformations for Gaussian evolution
- Bloch sphere rotations for semantic state changes
- Energy flow dynamics with damping
- NetworkX graph for entanglement topology

**Math**:
```python
# Gaussian energy: E_g = (q² + p²) / 2
# Bloch energy: E_b = r * (1 - cos(θ))
# Total energy: E = E_g + E_b + p_θ²/2
```

### 2. Quantum Tomato Meta-Graph (Python)

**File**: `quantum_tomato_meta_graph.py` & `quantum_tomato_meta_state.json`

**12 Conspiracy Nodes**:

| Node | Emoji | Meaning | Conspiracies |
|------|-------|---------|--------------|
| seed | 🌱→🍅 | potential_to_fruit | growth_acceleration, quantum_germination |
| observer | 👁️→📊 | measurement_collapse | observer_effect, data_harvesting |
| underground | 🕳️→🌐 | root_network_communications | mycelial_internet, tomato_hive_mind |
| genetic | 🧬→📝 | information_transcription | RNA_memory, genetic_quantum_computation |
| ripening | ⏰→🔴 | time_color_entanglement | retroactive_ripening, temporal_freshness |
| market | 💰→📈 | value_superposition | tomato_standard, ketchup_economy |
| sauce | 🍅→🍝 | state_transformation | umami_quantum, flavor_entanglement |
| identity | 🤔→❓ | categorical_superposition | fruit_vegetable_duality, botanical_legal_paradox |
| solar | ☀️→⚡ | light_energy_conversion | solar_panel_tomatoes, photon_harvesting |
| water | 💧→🌊 | fluid_information_storage | water_memory, irrigation_intelligence |
| meaning | 📖→💭 | semantic_field_generator | tomato_wisdom, agricultural_enlightenment |
| meta | 🔄→☯️ | self_referential_loop | tomato_simulating_tomatoes, recursive_agriculture |

**15 Entanglement Connections**:
- seed ↔ solar (0.9): photosynthetic_growth
- seed ↔ water (0.85): hydration_activation
- observer ↔ ripening (0.7): watched_pot_syndrome
- underground ↔ genetic (0.95): root_RNA_network
- genetic ↔ meaning (0.8): semantic_encoding
- ripening ↔ market (0.75): value_timing
- sauce ↔ identity (0.9): culinary_transformation
- solar ↔ meta (0.6): energy_recursion
- water ↔ underground (0.88): irrigation_network
- market ↔ sauce (0.82): economic_transformation
- identity ↔ meta (1.0): paradox_loop
- meaning ↔ observer (0.77): semantic_collapse
- seed ↔ sauce (0.66): lifecycle_completion
- genetic ↔ identity (0.91): essence_encoding
- meta ↔ seed (0.99): eternal_return

### 3. Godot Game Implementation

**Main Game**: `GodotProject/scripts/QuantumGraphGame.gd`

**Features**:
- Interactive graph visualization with click-to-add qubits
- Quantum bath temperature system (0.0 = ground state, 1.0 = max chaos)
- Bubble popping resource harvesting system
- Emoji relationship synergies and anti-synergies
- Parametric quantum scaling for large graphs
- Physics simulation with force-directed layout

**Quantum Mechanics**:
```gdscript
class DualEmojiState:
    var north: String  # Bloch north pole
    var south: String  # Bloch south pole
    var theta: float   # Polar angle (0 to PI)
    var phi: float     # Azimuthal angle (0 to 2*PI)
    var radius: float  # Attention/amplitude (0 to 1)
```

**Key GDScript Components**:
- `DualEmojiQuantum.gd`: Bloch sphere emoji quantum states
- `EntanglementManager.gd`: Manages qubit entanglement network
- `QuantumTomatoImporter.gd`: Imports tomato states from Python
- `QuantumBubbleVisualizer.gd`: Visual representation of quantum modes
- `KernelBridgeInterface.gd`: WebSocket communication with Python
- `MockQuantumKernel.gd`: Standalone operation without Python

## Data Flow

### Quantum Evolution Cycle

```
1. USER INTERACTION (click, drag)
   ├→ Add qubit with emoji pair
   ├→ Create entanglement between qubits
   └→ Apply quantum gates (rotations)
        ↓
2. GODOT QUANTUM UPDATE (_process)
   ├→ Update dual emoji states (theta, phi evolution)
   ├→ Apply bath temperature fluctuations
   ├→ Calculate energy flows
   └→ Update entanglement network
        ↓
3. PYTHON KERNEL (if connected)
   ├→ Receive state from Godot via WebSocket
   ├→ Apply QAGIS transformations
   ├→ Evolve Gaussian + Bloch components
   ├→ Calculate conspiracy activations
   └→ Send updated state back to Godot
        ↓
4. VISUALIZATION
   ├→ Render qubit bubbles with emoji
   ├→ Draw entanglement lines
   ├→ Show energy flows (particle effects)
   └→ Display conspiracy status
        ↓
5. RESOURCE HARVESTING
   ├→ Pop bubbles when energy threshold reached
   ├→ Extract emoji-specific resources
   ├→ Update graph metrics (coherence, entanglement)
   └→ Trigger conspiracy effects
```

### File System Organization

```
QuantumFarmGame/
├── QuantumKernel/
│   ├── qagis_kernel_v20.py         # Main quantum simulation
│   └── qagis_kernel_v18.py         # Older version
├── quantum_tomato_meta_state.json  # 12-node conspiracy data
├── quantum_tomato_meta_graph.py    # Tomato graph generator
├── quantum_kernel_bridge.py        # WebSocket server
├── PythonMembrane/
│   └── RNA_Experiments/            # Tomato growth experiments
│       └── QRNA-AGCU-TOMATO-*/     # Experiment runs
├── GodotProject/
│   ├── project.godot
│   ├── scripts/
│   │   ├── QuantumGraphGame.gd     # Main game (most recent)
│   │   ├── DualEmojiQuantum.gd     # Emoji Bloch states
│   │   ├── QuantumTomatoImporter.gd
│   │   ├── EntanglementManager.gd
│   │   ├── QuantumBubbleVisualizer.gd
│   │   └── 50+ other scripts
│   └── scenes/
│       └── 23 .tscn files
└── EnvironmentVisualizerV44/       # External visualization tool
```

## What Makes Tomatoes "Alive"?

Based on code analysis, the quantum tomatoes feel alive through:

1. **Energy Flow Dynamics**: Energy diffuses through the 15 entanglement connections creating organic-feeling movement
2. **Conspiracy Activation**: Different combinations trigger emergent behaviors (e.g., "tomato_hive_mind" + "mycelial_internet")
3. **Observer Effects**: Measuring/clicking tomatoes causes quantum collapse with visible state changes
4. **Self-Reference Loop**: The "meta" node creates recursive feedback (tomatoes simulating tomatoes)
5. **Temporal Effects**: "retroactive_ripening" lets past states influence present (berry phase accumulation)
6. **Bath Temperature**: Fluctuations create unpredictable behavior at high temperatures

## Working Visualizations

**Successful UI patterns found**:
- Bubble representation of quantum modes (size = energy, color = phase)
- Animated lines for entanglement (thickness = strength)
- Particle systems for energy transfer
- Emoji transformations showing state evolution (🌱→🍅)
- Graph metrics panel (coherence, entanglement, connectivity)

## Minimum Viable Quantum Substrate

The QAGIS kernel can be simplified for GDScript by:

1. **Dropping full symplectic formalism**: Use simple rotation matrices instead
2. **12 nodes instead of 16**: Focus on tomato conspiracy network
3. **Sparse updates**: Only evolve active/entangled nodes
4. **Simplified energy**: Linear diffusion instead of full Hamiltonian evolution
5. **Lookup tables**: Pre-compute Bloch sphere conversions

**Math needed in GDScript**:
```gdscript
# Bloch to Cartesian
func bloch_to_cart(theta: float, phi: float) -> Vector3:
    return Vector3(
        sin(theta) * cos(phi),
        sin(theta) * sin(phi),
        cos(theta)
    )

# Energy diffusion
func energy_flow(node_a, node_b, strength: float, dt: float) -> float:
    return (node_b.energy - node_a.energy) * strength * dt

# Simple evolution
func evolve(dt: float):
    theta += momentum_theta * dt
    phi += energy * dt * 0.1  # Energy-dependent precession
```

## Technical Debt & Slop Identified

**Old/Experimental Files** (can likely discard):
- Multiple test files (SimpleTest.gd, IntensiveTest.gd, ExperimentalTest.gd)
- Overlord/Battlemaster/GodMode scripts (experimental control systems)
- QuantumChaosEngine.gd (superseded by QuantumGraphGame)
- qagis_kernel_v18.py (superseded by v20)
- Multiple test data providers and mock systems

**Keep & Salvage**:
- QuantumGraphGame.gd (most recent, main game)
- DualEmojiQuantum.gd (clean emoji-quantum bridge)
- quantum_tomato_meta_state.json (core conspiracy data)
- qagis_kernel_v20.py (extract patterns only, rewrite in GDScript)
- QuantumTomatoImporter.gd (shows Python-Godot bridge pattern)

## Next Steps

See `TASK_LIST.md` for prioritized 7-day implementation roadmap.
