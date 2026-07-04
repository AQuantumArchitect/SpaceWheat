# SpaceWheat

A quantum farming game where **the story is the physics**. Every plot is a real
qubit; every biome is a small quantum computer evolving under its own Hamiltonian;
every harvest is a projective measurement. The quantum mechanics aren't a
metaphor — they're the engine.

## Start here

> **→ [`docs/GAME_CODEX.md`](docs/GAME_CODEX.md) is the single canonical source of
> truth.** It holds the whole game — mental model, physics, controls, the core
> loop, the campaign, and the honest open questions about elegance and fun — with
> every claim pointing at the file that is the authority for it. Read it first.

This README is only a doorway. The codex is the room.

## The 60-second model

- **Biome = quantum computer.** One pure-state density matrix `ρ` per biome,
  evolving under an exact closed-system unitary `U = exp(−iH·dt)` (purity stays 1).
  The open/Lindblad path exists but is **off by default** (it's DLC).
- **Icons author the Hamiltonian.** An *icon* is a two-emoji qubit axis
  (`Core/Factions/data/icons.json`). Planting icons adds qubits and their `H` terms.
- **Factions are loadouts; biomes are scaffolds.** A faction supplies a *signature*
  (a set of icons) that is *realized* into a bare biome at runtime.
- **Story fires from physics.** Narrative beats trigger when soft continuous gates
  over live observables (spectral gap, Var(H), signature growth, atom diversity,
  berry phase) cross a threshold — not from scripted dialogue.

## The core loop

1. **Measure** a qubit (Ace **E**): Born-sample it; it collapses to one emoji.
2. **Harvest** (Ace **Q**): cash the outcome for resources — reward is the
   surprisal `−kT·log p` (rarer = richer), with a bonus if the icon is in your
   signature.
3. **Track & Incorporate** (Icon **F** then **R**): let a qubit accumulate Berry
   phase until it ripens, then incorporate its icon — your *signature* grows, and
   story beats fire.
4. Compose biomes by planting atoms; **Reap** to fast-forward evolution; trade on
   the market. Win the campaign by composing a Village whose spectral gap stays
   small — a plural island that physically cannot collapse into one shape.

## Controls in one breath

One keyboard algebra: **SELECTION × ACTION**. Hats `4–0` pick a tool
(Icon/Captain/Ace/Operator/Druid — Spark & Merchant are DLC), `1/2/3` pick a
sub-mode, `TYUIOP` pick a biome, `GHJKL;` pick a plot, and the **QERF cross**
(Q/R = extract/commit, E = pause+inspect, F = play+advance) acts on the focus.
Overlays live on `Z X C V B N M`. Full grammar: `UI/Core/KEYBOARD_GRAMMAR.md`.

## Tech stack

- **Engine:** Godot 4.5 · **Language:** GDScript + native C++ GDExtension
- **Quantum backend:** dense density-matrix simulator; closed-system **exact
  unitary** propagator (eigendecomposition), Eigen-accelerated C++ lookahead as a
  derived predictor. Open-system (Lindblad/GKSL) is a DLC path, off by default.
- **Authority data:** `Core/Factions/data/{icons,factions,axes}.json`,
  `Core/Biomes/data/biomes.json`, `Core/Quests/data/story_flags.json`

## Build, run, test

```bash
./launch_game.sh                 # play (Linux, headed)
./editor_launch.sh               # open in the Godot editor
python3 -m pytest tests/ -q      # Python test suite (rig-driven + source contracts)
```
- Native C++ extension: `cd native && scons` (see **[`BUILDING.md`](BUILDING.md)**).
- Headless automation / LLM lane: `🍄/🎛️/🟢.sh` (docs in `🍄/README.txt`).
- Boot-error gate (must print `0`):
  `godot --headless --audio-driver Dummy --path . --quit 2>&1 | grep -cE "SCRIPT ERROR|Parse Error|ERROR: Failed to"`

## Project structure

```
Core/          Engine + game logic (~55k LOC)
  QuantumSubstrate/  QuantumComputer, HamiltonianBuilder, LindbladBuilder, gates
  Factions/data/     icons.json (H), factions.json, axes.json
  Biomes/data/       biomes.json (scaffolds + dormant L)
  Quests/            QuestManager, story_flags.json (the campaign), soft-gate math
  Story/             StoryEngine, socialite chatter (measurement-driven)
  Markets/           EnergyPricing (Boltzmann), MarketLattice (contracts)
  Actions/           Explore / Measure / Pop / Reap verbs
UI/            Thin key-in / projection-out surfaces (~26k LOC)
  Core/              QuantumInstrumentInput (input decoder), Surface, ToolConfig
  Overlays/          EscapeMenu(Z), ControlsOverlay(X), QuestBoard(C), Atlas(V)...
native/        C++ GDExtension (libquantummatrix) — derived predictor
docs/          Documentation — start at GAME_CODEX.md
🍄/            Automation lane (headless runners, rig, test harnesses)
```

## License

All rights reserved. Contact for licensing inquiries.
