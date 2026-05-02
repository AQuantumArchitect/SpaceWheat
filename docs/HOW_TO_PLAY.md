# How to Play SpaceWheat

> **OUTDATED — needs rewrite.** This doc describes the old 4-tool system (Unitary / Lindblad / Measure / Meta, keys 1–4).
> The game now uses **7 archetype frames** selected with hat row keys **4–0**.
> See `docs/ARCHETYPE_FRAMES.md` for the current key grammar.
> Do not update until after the code cleanup pass.

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
