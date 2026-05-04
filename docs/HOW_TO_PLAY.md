# How to Play SpaceWheat

> **OUTDATED — needs full rewrite.** The sections below describe the old 4-tool system
> (Unitary / Lindblad / Measure / Meta, keys 1–4). The game now uses **7 archetype frames**
> on hat row **4–0** with sub-modes **1/2/3**. The Q/E/R/F verbs are preserved but their
> actions vary by frame. See `docs/ARCHETYPE_FRAMES.md` for current key grammar.
>
> The physics narrative (superposition, collapse, entanglement, Hamiltonian evolution) is
> still accurate — that part doesn't need changing. The controls section needs a full rewrite
> once the archetype frame system stabilises.

---

## Notes for future context (appended 2026-05-03, written by Claude during cleanup pass)

These are architectural observations for whichever worker picks this up next. Not prose for players.

**What the game actually is right now:** A quantum farming simulator with a real density-matrix engine (Godot 4.5 + C++ GDExtension via Eigen). The physics is not metaphorical. Lindblad master equation, Born-rule measurement, genuine entanglement via H+CNOT, berry phase tracking, mutual information at 5Hz. The C++ layer is in `native/src/` and the GDScript binding layer is in `Core/QuantumSubstrate/`. `ComplexMatrix` hot path uses `PackedFloat64Array`. StarterForest runs at ~40ms/frame real quantum.

**Key architectural layers:**
- `Core/QuantumSubstrate/` — density matrix, gate library, register map, Lindblad builder, entanglement manager
- `Core/Environment/` — `BiomeBase` owns the quantum computer per biome; `BiomeEvolutionBatcher` drives the Lindblad step; `BiomeDeterministicStepper` handles stride management
- `Core/Biomes/` — data layer; `Biome` (data object), `BiomeRegistry` (loader from biomes.json), `BiomeBuilder` (materialises runtime nodes)
- `Core/Factions/` — `Faction`, `FactionRegistry` (96 factions from factions.json), `FactionAxes` (12 axial dimensions from axes.json), `FactionStanding` (6-channel reputation), `FactionDensityMatrix`
- `Core/Markets/` — `ContractMarket`, `MarketLattice`, `PriceModel` — quantum tensor-product market, faction-biome as permanent market actors
- `Core/Story/` — `StoryEngine`, `StoryGraph`, `StoryNode`, `Socialite/SocialiteCluster` — physics-driven narrative; story beats fire from threshold crossings on manifold state, not scripted text
- `Core/GameState/` — `GameStateManager` (orchestrator), `SessionLifecycle`, `SaveLoadCoordinator`, `PlayerProgress`, `ScenarioLedger`
- `Core/Boot/` — `BootManager` → `SessionLoader` / `WorldBuilder` / `RuntimeMount`; clean stage sequence
- `UI/` — surface system: `Surface.gd` base class, `SurfaceRegistry` for snapshot broadcasting; overlays: `ControlsOverlay` (Z), `BiomeInspectorOverlay` (B), `InspectorOverlay` (N), `MapMetaOverlay` (M), `QuestBoard` (C), `QubitAtlasOverlay` (V); input via `PlayerShell` → `QuantumInstrumentInput` → `QuantumInstrument` → handlers

**Current keyboard grammar (Archetype Frames):**
- Hat row `4 5 6 7 8 9 0` = 7 archetype frames (Icon, Spark, Merchant, Captain, Ace, Operator, Druid)
- Sub-modes `1 / 2 / 3` within each frame
- `Q E R` = verbs (directional action within current frame/mode)
- `F` = advance / play (replaces old "mode cycle" meaning)
- `E` (held or with pause) = inspect / pause
- `Z X C V B N M` = surface keys (character sheet, system, quests/contracts, vocab/icons, story, biome inspector, map)
- `ESC` = back / close
- Full grammar in `UI/Core/KEYBOARD_GRAMMAR.md`

**The faction hypercube:** 96 factions placed in a 12-dimensional hypercube (axes from `Core/Factions/data/axes.json`). Each faction has a `sig` (emoji atom set) in `factions.json` for gameplay physics and a `bits` array (explicit 12-dim coordinates) in `Core/Quests/FactionDatabase.ALL_FACTIONS` for lore/posture. The bits were intentionally positioned — clustering at poles is expected and correct at this stage. The two datasets are complementary (not duplicates): factions.json has Hamiltonian physics, FactionDatabase has lore and hypercube coordinates. The posture strip on the Z SELF tab now correctly derives axis bias from live faction standings via atom→axis lookup (replaced stale FactionContext hardcoded list in this pass).

**What's currently in-flight / known unstable:**
- `Core/GameMechanics/FarmPlot` ↔ `Terminal` partial migration — Terminal is the v2 plot architecture but FarmPlot still primary; expect this to resolve when gameplay loop stabilises
- `BiomeStateViews.gd` — Sprint 2 of ZXCVBNM surface refactor, in progress
- `Core/Affinity/AffinityGraph.gd` — new subsystem, single file, not yet fully wired
- `Core/UI/ChipContext` / `ChipResolverRegistry` / `IconChipResolvers` — chip resolver pattern for V surface (icon detail); Berry phase tracking extensible via this pattern
- `Core/GameState/MacroActions` / `SaveLoadCoordinator` / `ScenarioLedger` / `PlayerProgress` — GameStateManager refactor into sub-modules, in progress; `SessionLifecycle` is the coroutine entry point
- `docs/HOW_TO_PLAY.md` (this file) — controls section is wrong; physics description is correct; rewrite controls section when archetype frame system hardens

**What this cleanup pass did (2026-05-03):**
- Deleted 8 dead root scripts, 26 dead test scenes, `LindbladSuperoperator`, `FactionContext`, `PhaseConstraint`, `ScenarioMetadata`
- Removed 25+ stale `FarmView` node lookups, Model-A wheat fields, WheatPlot spring-attraction remnants
- Committed 63 untracked live GDScript files across 8 new subsystems + 26 tests + native C++ source
- Renamed `FactionDatabaseV2` → `FactionDatabase`; deleted AXIAL_SPINE constant (redundant with axes.json)
- Replaced `FactionContext` (stale 39-faction hardcoded list) with live `FactionRegistry` + atom→axis map in posture strip
- Deleted stale docs: `BIOME_SETUP_GUIDE.md`, `INPUT_ARCHITECTURE.md`
- Removed 3 untracked dead tools (`generate_*q_profiles.py`)

**Known remaining debt not yet addressed:**
- `BiomeGateOperations.register_manager` has a misleading "deprecated" comment but is actively used — the plot-based gate path is still alive
- `FactionDatabase.ALL_FACTIONS[*].bits` (12-dim hypercube coords) should eventually be wired into the posture strip or merged into factions.json — currently stored but not read by any runtime path
- `docs/HOW_TO_PLAY.md` controls section needs full rewrite for archetype frames
- `scenes/archived/` contains two Claude play-rig scenes with valid scripts — worth keeping until the rig system is formally replaced
- `tests/` has 42 untracked files (all committed in this pass) + 15 tracked older tests; older tests (Jan–Feb 2026 QuestBoard suite) may be stale relative to current quest architecture

---

You're a quantum farmer. Your fields are quantum registers, your crops are probability amplitudes, and your harvest depends on the laws of physics. No quantum knowledge required — the game teaches you by playing.

## First 60 Seconds

When the game boots, you're looking at a farm grid with floating emoji bubbles. Each bubble is a qubit — a two-sided coin that hasn't been flipped yet. One emoji is bright, the other is dim. That's a superposition.

Your job: flip those coins profitably.

## Controls at a Glance

```
TOOLS          1  2  3  4        Select your tool
ACTIONS        Q  E  R           In / Select / Out
MODE CYCLE     F                 Cycle mode, page, or view
BIOMES         T  Y  U  I  O  P Select which biome to work in
PLOTS          J  K  L  ;  '    Select a plot within the biome
MENUS          ESC  V  C  N  X  Menu, Vocab, Contracts, Inspector, Help
```

The three keys you'll use most: **Q**, **E**, **R**. Q reaches in, E selects, R pulls out. Same direction in every tool and every menu.

## The Core Loop: Q-E-R

Press **3** to select the Measure tool (your starting tool), then:

### Q = Explore (in)
Reach into the quantum state. Bind one of your 12 terminals to a quantum register — staking a claim on a piece of quantum real estate.

### E = Measure (select)
Observe the state. Physics picks a winner (Born's rule — weighted coin flip based on actual probabilities). You see which emoji came up and how likely it was. "Sun at 73%" means physics was 73% sure it'd be sun.

### R = Pop (out)
Pull the credits out. That 73% becomes 73 credits. Terminal goes back to the pool. Do it again.

**The rhythm:** Q reaches in, E selects, R pulls out. Twelve cycles and your terminals are all free. Then **Reap** to advance the season — quantum evolution reshuffles all the probabilities, and you get a batch harvest from the accumulated physics.

## What You're Actually Doing

Every time you Measure, you're performing a real projective measurement on a density matrix. The emojis aren't decoration — they're the computational basis states of actual qubits. When you see a bubble with bright wheat and dim corn, that qubit genuinely has higher probability amplitude in the wheat direction.

This means:
- **Superposition is real**: Before you measure, both outcomes exist. The opacity of each emoji shows you the probability.
- **Collapse is real**: After you measure, the state snaps to one outcome. No going back.
- **Entanglement is real**: If you entangle two qubits and measure one, the other instantly updates. Check it — measure one half of a Bell pair and watch the partner lock in.

## The Four Tools

### Tool 1: Unitary (reversible gates)
Press **1**. Q rotates the qubit down (in), E applies Hadamard (select — creates superposition), R rotates up (out). Press **F** to cycle rotation axis: X, Y, Z.

Use this to set up quantum states before measuring. A Hadamard on a definite state creates maximum uncertainty — which in this game means maximum potential.

### Tool 2: Lindblad (dissipation)
Press **2**. Q drains energy (in — dissipate), E transfers population (select — redistribute), R pumps energy (out — drive). This is how the environment talks to your quantum state — thermodynamics in action.

### Tool 3: Measure (the farming tool)
Press **3**. Q explores (in — bind terminal), E measures (select — collapse state), R pops (out — harvest credits). Press **F** to switch to Gate mode: Q builds entangling gates (in), E inspects (select), R breaks them (out).

### Tool 4: Meta (system management)
Press **4**. Q adds vocabulary or discovers biomes (in), R removes them (out). F cycles between vocabulary and biome mode.

## Biomes

You have 6 active biome slots (T through P keys). Each biome is a different quantum system with its own Hamiltonian — meaning the physics feels different in each one. StarterForest has a day/night cycle. BioticFlux has competing ecological pressures. FungalNetworks has cross-coupled mycorrhizal dynamics.

Switch biomes with T-P. Select plots within a biome with J-L and ;-'.

Each biome has its own set of emoji qubits, its own evolution dynamics, and its own personality. Exploring multiple biomes is how you find diverse resources.

## Economy

Everything you earn is **emoji-credits** — wheat credits, population credits, mushroom credits, etc. You earn them by measuring and popping, and in bulk during seasonal reaps.

**Vocabulary bonus**: When you complete quests, you learn emoji pairs. Known pairs earn a purity bonus during reaps. This is huge — it means the quest system is literally teaching you which quantum states to look for, and rewarding you for paying attention.

## Quests

Press **C** for contracts. Factions offer delivery quests: "Bring us 100 wheat credits by day 3." Complete them to earn rewards and learn new vocabulary.

Quests push you to explore different biomes and quantum configurations. Each faction has a different personality encoded in 12 bits of quantum signature, which influences what they ask for and how they talk.

## Things to Try

Once you've got the Q-E-R rhythm down, try these:

**Make a Bell pair.** Switch to Tool 3, press F for Gate mode, select two plots, press Q to build a gate. Now those two qubits are entangled. Measure one — watch the other collapse instantly to the correlated outcome. That's real entanglement, not a scripted event.

**Hadamard everything.** Switch to Tool 1, select a plot, press E. You just put that qubit into a perfect superposition. Now measure it — physics picks 50/50. Do it 20 times and count the outcomes. You'll see Born's rule in action.

**Rotate then measure.** Tool 1, press Q a few times to rotate a qubit partway. Now measure. The probability you see matches exactly what quantum mechanics predicts for that rotation angle.

**Inspect the density matrix.** Press N to open the inspector. You'll see the actual density matrix rendered as a heatmap — the off-diagonal elements are coherences, the diagonal is populations. Apply a Hadamard and watch off-diagonal terms appear. Measure and watch them vanish. That's decoherence happening in front of you.

**Explore biome differences.** Switch between StarterForest and BioticFlux. Notice how the bubbles move differently, how probabilities drift at different rates, how some emojis dominate in one biome but are rare in another. That's because each biome has a genuinely different Hamiltonian driving the evolution.

**Build a GHZ state.** Entangle qubit A with B, then B with C. Now you have a 3-qubit GHZ state — the quantum state that Einstein called "spooky." Measure any one of them and all three collapse simultaneously. Each qubit alone looks completely random (50/50), but they're perfectly correlated.

**Watch the evolution.** Just wait. Don't touch anything. Watch the bubbles drift on their ovals, watch probabilities slowly shift, watch the colors rotate. That's Hamiltonian evolution — unitary time evolution of the density matrix under the biome's specific Hamiltonian. The physics never stops.

## Keyboard Reference

| Key | Action |
|-----|--------|
| 1-4 | Select tool (Unitary / Lindblad / Measure / Meta) |
| Q | Down action (explore, rotate down, drain, add vocab) |
| E | Neutral action (measure, hadamard, transfer, inspect) |
| R | Up action (pop, rotate up, pump, remove) |
| F | Cycle mode within current tool |
| T Y U I O P | Select biome slot 1-6 |
| J K L ; ' | Select plot 1-5 |
| H G | Select plot 6-7 |
| Shift+Q/E/R | Apply action to ALL valid plots at once |
| ESC | Menu |
| V | Vocabulary (learned emoji pairs) |
| C | Contracts (quests) |
| N | Inspector (density matrix, probabilities) |
| X | Help (keybindings) |

## Tips

- **Start with Tool 3.** Q-E-R is the whole game until you want to go deeper.
- **Reap often.** Seasonal reaps give big batch harvests and advance the quantum evolution.
- **Do your quests.** The vocabulary bonus from quests compounds — learned pairs earn 4x during reaps.
- **Entangle for fun.** It doesn't cost much and it's the most interesting physics in the game.
- **Watch the inspector.** Press N, apply some gates, and watch the density matrix change. You'll learn more about quantum mechanics in 5 minutes than from any textbook.
- **Shift+Q/E/R for bulk.** Hold shift to explore/measure/pop all valid plots at once.
- **Every biome is different.** If one biome feels stale, switch. The Hamiltonians are genuinely different.

## What's Under the Hood

This isn't a quantum-themed game with classical mechanics underneath. The quantum simulation is the actual game engine:

- Density matrices tracked for every biome
- Gates applied as unitary transformations on the density matrix
- Measurement via Born rule sampling + projective collapse
- Entanglement via H+CNOT Bell circuit with adjacency graph tracking
- Hamiltonian evolution via first-order Euler integration of the Lindblad master equation
- Mutual information computed at physics rate to drive bubble clustering
- Native C++ acceleration via Eigen for matrix operations

292 physics tests verify the quantum mechanics are correct. You're not just playing a game about quantum computing — you're using a quantum computer.
