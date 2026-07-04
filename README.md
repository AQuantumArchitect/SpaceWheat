# SpaceWheat

A quantum farming simulator built on real physics. Grow crops, measure qubits, harvest probability.

SpaceWheat is a game where every wheat field is a quantum register, every harvest is a projective measurement, and every season is Hamiltonian evolution. The quantum mechanics aren't a metaphor — they're the actual engine. You're playing a quantum computer that happens to look like a farm.

## How It Works

### The Quantum Foundation

Each biome runs a **density matrix simulation** of its quantum state. A biome is a *cloud of atoms* (single emojis) under Lindblad dissipation; its qubit axes form when a faction's **icons** are installed over it (a neighborhood) — each icon pairs two atoms into a north pole (|0>) and a south pole (|1>). A wheat qubit might be sun/moon, a population qubit might be people/fire. Pole-pairing is a neighborhood/faction product, not a property of the biome itself. The state evolves under the induced Hamiltonian with the biome's Lindblad dissipation channels, and when you measure, Born's rule decides what you get.

This isn't approximate. The gate library implements all standard quantum gates with exact matrix definitions:

- **Single-qubit**: X, Y, Z, H, S, T, S-dagger, T-dagger, Rx, Ry, Rz
- **Two-qubit**: CNOT, CZ, SWAP
- **State preparation**: Bell pairs, GHZ states

Every gate is verified against known quantum states (142 physics tests).

### The Four Tools

Player actions are organized into four tool groups by time scale:

| Key | Tool | What it does |
|-----|------|-------------|
| **1** | **Unitary** | Reversible quantum gates. Rotate qubits on the Bloch sphere, create superpositions with Hadamard. F-key cycles through X/Y/Z rotation axes. |
| **2** | **Lindblad** | Dissipative operations. Drain energy out, pump energy in, transfer population between qubits. This is how the environment interacts with your quantum state. |
| **3** | **Measure** | The core gameplay loop. Explore (bind a terminal), Measure (collapse the state), Pop (harvest credits). F-key switches to Gate mode for building entanglement. |
| **4** | **Meta** | System-level operations. Add or remove vocabulary pairs, discover or cull biomes. |

Within each tool, actions follow a consistent direction:
- **Q** = in (bind, drill, navigate back)
- **E** = select (observe, detail, interact with current item)
- **R** = out (extract, advance, navigate forward)
- **F** = cycle (switch mode, page, or view — always)

### The Core Loop

```
EXPLORE (Q=in)  -->  MEASURE (E=select)  -->  POP (R=out)  -->  repeat
      |                    |                       |
  bind terminal       Born sample            harvest credits
  to register         collapse state           free terminal
```

1. **Explore** binds one of your 12 terminals to a quantum register. The system favors high-probability states.
2. **Measure** samples the qubit via Born's rule and collapses it. You see which emoji won and at what probability.
3. **Pop** converts that probability into emoji-credits. Higher measurement probability = bigger payout.

Between cycles, **Reap** runs Hamiltonian evolution across all biomes and does a batch harvest from the accumulated quantum dynamics.

### Visualization

Qubits appear as floating **bubbles** on each biome's oval. Each bubble displays its two emojis with opacity proportional to measurement probability — a 70/30 superposition literally shows one emoji bright and the other dim. Entangled qubits cluster together (driven by mutual information). Quantum phase is encoded as color rotation through RGB primaries.

The inspector overlay (N key) shows the raw density matrix as a heatmap and probability bars per register.

### Biomes

64 biomes, each with a unique Hamiltonian, Lindblad configuration, and emoji palette. StarterForest has a day/night oscillation driving sun/moon populations. FungalNetworks has cross-coupled mushroom ecology. Each biome feels mechanically different because the quantum dynamics actually are different.

Navigate biomes with T-Y-U-I-O-P (6 active slots). Select plots within a biome with J-K-L-;-'-H-G.

### Economy

All resources are **emoji-credits** — unified currency per emoji type. Measurements convert quantum probability to credits at 10:1. Completing quests teaches you vocabulary icons, and known icons earn a purity bonus during seasonal reaps.

Quests are procedurally generated from faction data and reference specific emoji deliveries, pushing you to explore diverse biomes and quantum states.

## Tech Stack

- **Engine**: Godot 4.5
- **Language**: GDScript + native C++ GDExtension
- **Quantum backend**: Custom density matrix simulator with Eigen-accelerated native path
- **Evolution**: First-order Euler integration with Lindblad master equation (GKSL form)
- **Gate library**: 14 gates (11 single-qubit + 3 two-qubit) with exact unitary matrices

### Native Acceleration

The `libquantummatrix` C++ extension provides:
- Dense matrix multiplication via Eigen
- Mutual information computation at physics rate (5 Hz)
- Lookahead evolution for the BiomeEvolutionBatcher

Matrix operations and gates fall back to pure GDScript when the native library
is absent (this is how the headless physics tests run), but continuous biome
evolution requires the native extension — prebuilt binaries for Linux and
Windows ship in `native/bin/`.

## Testing

142 quantum physics tests across 4 suites (plus a weak-measurement suite):

| Suite | Tests | Coverage |
|-------|-------|----------|
| Exact Quantum States | 29 | Every gate against exact density-matrix elements (H, X, Y, Z, CNOT, Bell, CZ, SWAP) |
| Advanced Quantum States | 28 | Multi-gate state preparation and verification |
| Gate Application Integration | 22 | Gates applied through the real biome/register pipeline |
| 2-Qubit Gate Embedding | 63 | CNOT/CZ/SWAP embeddings across qubit orderings |
| Weak-Measurement Drain | 18 | Trace preservation, coherence decay (T₂), purity validity, η=0/1 limits |

Run them all:
```bash
bash run_quantum_gate_tests.sh
```

Or through the 🍄 automation lane, with per-suite selection:
```bash
bash 🍄/🧪/🔬.sh
bash 🍄/🧪/🔬.sh --suite gates
bash 🍄/🧪/🔬.sh --suite advanced
bash 🍄/🧪/🔬.sh --suite integration
bash 🍄/🧪/🔬.sh --suite embed
bash 🍄/🧪/🔬.sh --suite drain
```

## Project Structure

```
Core/
  QuantumSubstrate/    Quantum computer, gates, density matrix, circuit builder
  Environment/         Biome implementations, evolution batcher
  Biomes/              Biome registry + data (biomes_merged.json)
  Config/Hamiltonians/ Per-biome Hamiltonian configurations (JSONL)
  Actions/             Explore/Measure/Pop/Reap action handlers
  GameMechanics/       Farm economy, grid, terminal pool
  GameState/           Save/load, tool config, scenario builder
  Instrumentation/     Action dispatch (QuantumInstrument)
  Quests/              Quest generation, faction database
  Visualization/       Bubble rendering, force graph, biome backgrounds
UI/
  Core/                Input handling (QuantumInstrumentInput), action validation
  Overlays/            Controls, inspector, biome inspector
  HUD/                 Performance display, bot status
tests/                 Physics verification suites + integration tests
🍄/                    Automation lane (headless runners, test harnesses, batch tools)
native/                C++ GDExtension (libquantummatrix)
```

## Building

Requires Godot 4.5. Open the project in the WSL-aware editor launcher, or run headless:

```bash
./scripts/launch-linux-editor.sh
```

To save the editor boot log without copy/paste:

```bash
./scripts/launch-linux-editor.sh --log-file /tmp/spacewheat-linux-editor.log
```

Or run headless:

```bash
godot --headless --script tests/test_gate_exact_states.gd
```

For native acceleration, build the C++ extension:
```bash
cd native && scons
```

## License

All rights reserved. Contact for licensing inquiries.
