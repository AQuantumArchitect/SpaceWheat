# SpaceWheat

A quantum farming simulator built on real physics. Grow crops, measure qubits, harvest probability.

SpaceWheat is a game where every wheat field is a quantum register, every harvest is a projective measurement, and every season is Hamiltonian evolution. The quantum mechanics aren't a metaphor — they're the actual engine. You're playing a quantum computer that happens to look like a farm.

**v0 ships as a closed quantum system** — in-fiction, *the enclave*: a world of pure
unitary evolution where nothing decays, nothing leaks, and the player's measurements are
the only irreversible acts. "Measurement IS the economy." The full dissipative machinery
(Lindblad channels, decoherence, the open-systems curriculum) is authored, sealed behind
a single flag, and reserved for the open-world expansion (`docs/CLOSED_SYSTEM.md`,
`docs/inspiration/OPEN_SYSTEM_ACT2.md`).

## How It Works

### The Quantum Foundation

Each biome runs a **density matrix simulation** of its quantum state. A biome is a *cloud of atoms* (single emojis); its qubit axes form when a faction's **icons** are installed over it (a neighborhood) — each icon pairs two atoms into a north pole (|0>) and a south pole (|1>). A wheat qubit might be sun/moon, a population qubit might be people/fire. Pole-pairing is a neighborhood/faction product, not a property of the biome itself. The state evolves under the induced Hamiltonian — exactly, via the unitary propagator U = exp(−iH·dt), purity conserved to machine precision — and when you measure, Born's rule decides what you get. Each biome also authors a Lindblad flow-graph (its *webway*, the food web); in v0 those channels are drawn in the graph views but sealed: zero dissipators are built while the enclave holds.

This isn't approximate. The gate library implements all standard quantum gates with exact matrix definitions:

- **Single-qubit**: X, Y, Z, H, S, T, S-dagger, T-dagger, Rx, Ry, Rz
- **Two-qubit**: CNOT, CZ, SWAP
- **State preparation**: Bell pairs, GHZ states

Every gate is verified against known quantum states (142 physics tests).

### The Seven Frames

Player actions live in seven archetype frames on the number row (4–0), each a hat the
player wears:

| Key | Frame | What it does |
|-----|-------|-------------|
| **4** | **Spark** | Lindbladian jolt — *sealed while the enclave holds* (v0); opens with the expansion. |
| **5** | **Icon** | Inject a dual-emoji qubit from the neighborhood's installed signature. |
| **6** | **Merchant** | Faction contracts: sell, read price, buy. Price = −kT·log p. |
| **7** | **Captain** | Biome lifecycle: cull, discover. |
| **8** | **Ace** | The default toolkit — the plant/measure/harvest energy dyad. |
| **9** | **Operator** | Gate building: Bell, CNOT, CZ, SWAP, GHZ, cluster. |
| **0** | **Druid** | Unitary rotations + Hadamard (X/Y/Z axes on 1/2/3). |

Every frame speaks the same four-verb grammar (QERF — designed for touch as much as
keyboard, with **E as the universal "inspect / more information"**):
- **Q** = screw out — less, remove, retreat, harvest
- **E** = pause + inspect — read the state, collapse it, or open detail
- **R** = screw in — more, add, advance, plant
- **F** = play + flatten — close what E opened

### The Core Loop

```
PLANT (R)  -->  MEASURE (E)  -->  HARVEST (Q)  -->  repeat
    |               |                  |
 invest energy   Born sample       surprisal payout
                collapse state     E = −kT·log p
```

1. **Plant** invests energy — jolt population toward the pole you want.
2. **Measure** samples the qubit via Born's rule and collapses it — the game's single
   irreversible act, seeded deterministically so a save-load replays the same universe.
3. **Harvest** pays the *surprisal* of what you learned: improbable outcomes pay more
   because you learned more. The player is Maxwell's demon on a payroll
   (`docs/inspiration/DEMON_AT_THE_GATE.md`).

Selecting a plot auto-binds its terminal. Time + Hamiltonian is the pump: after a
collapse, the couplings rotate the pinned qubit back into superposition — nothing else
refills it, because nothing else needs to.

### The Story Is the Physics

The narrative layer is computed from the quantum state, not bolted on:

- **Factions carry twelve axioms** — preferences over quantum observables (purity,
  entropy, coherence, distribution, scale, dynamics). Matching them against a biome's
  live state yields the faction's **resonance** with that place, spoken as mood: *"this
  place sings to them"*, *"restless — the biome grates on their axioms"*. Press E on any
  offer to read it.
- **Quests are personality-typed.** The most resonant faction voices the physics quest,
  and its operator taste picks the ask: material factions ask you to grow a population,
  mystics to superpose, subtle ones to commit a contested pair, prismatic ones to hold
  two threads at once. Completion is soft-gated on live observables — the progress bar
  is the teacher.
- **Ten archetype voices** (with phrase banks) cover all ~99 factions — 40 authored, the
  rest derived from faction identity. The world **whispers at irreversible moments**:
  close a Berry loop and the native faction marks the incorporation; collapse an
  improbable outcome and someone witnesses the scar.
- **You are a quantum system too.** The player's identity is a density matrix over
  12-qubit faction concept-space, decaying toward the mixed state (τ = 300 s) unless
  choices keep renewing it — the one open system inside the enclave's walls. The M
  overlay reads it back: `You · Tr(ρ²) = 0.85 — resolved`.
- **A canonical glossary** (`docs/glossary/`) defines the world's physics vocabulary —
  enclave, measurement, berry, webway, resonance — and is projected live into the
  in-game Guide.

### Visualization

Qubits appear as floating **bubbles** on each biome's oval. Each bubble displays its two emojis with opacity proportional to measurement probability — a 70/30 superposition literally shows one emoji bright and the other dim. Entangled qubits cluster together (driven by mutual information). Quantum phase is encoded as color rotation through RGB primaries.

The inspector overlay (N key) shows the raw density matrix as a heatmap and probability bars per register. The map overlay (M → Graph) renders each biome's cluster as a live graph: purple Hamiltonian couplings, the sealed webway in dark orange, and **gold entanglement edges pulled from the live mutual-information cache** — the loom the player actually wove, glowing in proportion to bits.

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
- **Evolution**: Closed system (default) uses the exact unitary propagator U = exp(−iH·dt) — eigendecomposition in C++, Padé scaling-and-squaring in the GDScript fallback — purity-conserving to machine precision. The GKSL (Lindblad) integrator remains behind the open-system flag.
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
| Closed-System Gate | 4 | Closed → zero Lindblad operators; open override rebuilds them; purity/trace ≡ 1 through evolution and projective collapse |

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
bash 🍄/🧪/🔬.sh --suite closed
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
