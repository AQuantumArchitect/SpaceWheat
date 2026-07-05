# How to Play SpaceWheat

SpaceWheat is a keyboard-first quantum farming game. Every field is a real
density matrix; planting, measuring, and harvesting are state preparation,
Born-rule collapse, and getting paid for what you learned. This page is the
first ten minutes; the full control grammar lives in
[UI/Core/KEYBOARD_GRAMMAR.md](../UI/Core/KEYBOARD_GRAMMAR.md) and the frame
reference in [docs/ARCHETYPE_FRAMES.md](ARCHETYPE_FRAMES.md).

## The first sixty seconds

You wake in the **StarterForest** wearing the **Ace** hat (the default —
that's the `8` key). A toast names the doors; the Hearth Keepers have left
you a chain of small asks on the quest board.

1. Pick a plot: `G H J K L ;` (left to right).
2. **R** plants — invest energy, jolt the qubit toward a pole.
3. **E** measures — Born's rule picks an answer and the state collapses.
   This is the game's one irreversible act, and it pauses the sim so you
   can look around.
4. **Q** harvests — you are paid the *surprisal* of the outcome,
   −kT·log p. Rare answers pay more, because you learned more.
5. **C** opens the quest board. The tutorial chain lives there — each step
   teaches one mechanic and its progress bar fills as the live state
   approaches the ask. The bar is the teacher.

That's the core loop. Everything else in the game is a deepening of it.

## The verb grammar (QERF)

Four verbs, same directions on every surface:

- **Q** — screw out: less, remove, retreat, harvest, fuse.
- **E** — pause + inspect: read the state, collapse it, or open detail.
  **E is the universal "tell me more"** — press it on plots, offers,
  factions, bridges, anything.
- **R** — screw in: more, add, advance, plant, span.
- **F** — play + flatten: close what E opened, advance time. In the Ace
  hat, **F reaps the season** — time runs forward and the whole biome's
  yield lands at once.

## The seven hats (number row 4–0)

| Key | Hat | What it does |
|-----|-----|--------------|
| 4 | **Spark** | Lindbladian jolt (greyed on closed ground). Mode 2 (🌉): Majorana bridges — never sealed. |
| 5 | **Icon** | Inject dual-emoji qubits; **F tracks** a qubit's walk, **R incorporates** it when ripe. |
| 6 | **Merchant** | Faction contracts: Q exports, E reads the price, R imports. |
| 7 | **Captain** | Biome lifecycle: cull, compass, discover. |
| 8 | **Ace** | The default: plant / measure / harvest / **reap (F)**. |
| 9 | **Operator** | Gate building: Bell, CNOT, CZ, SWAP, GHZ. |
| 0 | **Druid** | Rotations + Hadamard (E); 1/2/3 pick the X/Y/Z axis. |

Re-press the active hat to fall back to Ace. `Tab` cycles hats. `Shift` +
Q/E/R applies the verb to every valid plot.

## The surfaces (letter row)

- **C** — quest board: offers, contracts, the tutorial chain. Press **E**
  on any offer to read the faction's *resonance* with this biome — which
  axiom sings, which grates, and how they sit with who *you* are becoming.
- **V** — vocabulary atlas: the icons you know, and the ones you've seen.
- **B** — biome inspector. **N** — the density matrix itself, as a heatmap.
- **M** — map and meta: the world graph, the eigenstate compass 🧭, and
  **You · Tr(ρ²)** — your own identity, read back as physics.
- **X** — the Guide: an in-game version of all of this, plus the glossary
  (twenty canonical terms) and a list of experiments to try.
- **Z / ESC** — system menu: save, load, new run.
- **F12** — postcard: captures the view with the physics watermark in the
  pixels and a certificate JSON beside it (`user://postcards/`).

## Navigation

`T Y U I O P` — biome slots. `G H J K L ;` — plots. `'` — select all
plots. `W A S D` — spin the selection cylinder (frames / biomes / plots /
surfaces).

## Where it goes from here

Wake the forest and the story takes over: loops that remember (ripeness is
Berry phase), depths that never move (the spectrum), a chain that protects
its ends, braids that care about order — and after the story's door opens,
the **wet country**, where the Bath drinks phase and looking becomes the
only way to keep. Ripe qubits teach you words; words make you somebody
(watch your purity resolve in M → Eigenstate); being somebody changes how
every faction treats you.

If a claim in the game sounds too good to be physics, check
[docs/FOR_PHYSICISTS.md](FOR_PHYSICISTS.md) — every concept is graded
exact / faithful / suggestive, and the tests are one command away.
