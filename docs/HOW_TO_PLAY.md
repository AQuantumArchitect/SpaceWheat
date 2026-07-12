# How to Play SpaceWheat

SpaceWheat is a keyboard-first quantum farming game. Every field is a real
density matrix; planting, measuring, and harvesting are state preparation,
Born-rule collapse, and getting paid for what you learned. This page is the
first ten minutes; the full control grammar lives in
[UI/Core/KEYBOARD_GRAMMAR.md](../UI/Core/KEYBOARD_GRAMMAR.md) and the frame
reference in [docs/ARCHETYPE_FRAMES.md](ARCHETYPE_FRAMES.md).

## The first sixty seconds

You wake in **The Demos** — your own people, wheat and folk — wearing the **Ace** hat (the default —
that's the `8` key). A toast names the doors; the Hearth Keepers have left
you a chain of small asks on the quest board.

1. Pick a plot: `G H J K L ;` (left to right) — or just tap it.
2. **F** explores — mount an expedition (costs 🍞: breaking bread opens
   doors). The register binds and its bubble wakes. (The first tap on an
   unexplored plot does the same.)
3. **R** strikes — Born's rule picks an answer and the state collapses.
   The game's one irreversible act, a social encounter that costs 👥; the
   bubble freezes cyan with its answer. (Tapping a live bubble does the same.)
4. **Q** extracts, free — you are paid the *surprisal* of the outcome,
   −kT·log p. Rare answers pay more, because you learned more; a certain
   answer pays the floor, so let the state evolve before you strike. The
   bubble returns to live evolution. (Tapping a frozen bubble does the same.)
5. **E** pauses time (and on menu surfaces, E is "tell me more"); **F**
   always plays time on — and on an explored plot F doubles down:
   fast-forward and let the odds spin.
6. **C** opens the quest board: market offers to accept, and your active
   commitments. Early tutorial steps appear among the offers — each teaches
   one mechanic and its progress bar fills as the live state approaches the
   ask. The bar is the teacher.

That's the core loop. Everything else in the game is a deepening of it.

## The verb grammar (QERF)

Four verbs, same directions on every surface:

- **Q** — screw out: less, remove, retreat, extract, fuse.
- **E** — pause + inspect: read the state or open detail.
  **E is the universal "tell me more"** — press it on plots, offers,
  factions, bridges, anything.
- **R** — screw in: more, add, advance, strike, span.
- **F** — play + flatten: close what E opened, advance time. In the Ace
  hat, **F reaps the season** — time runs forward and the whole biome's
  yield lands at once.

## The seven hats (number row 4–0)

| Key | Hat | What it does |
|-----|-----|--------------|
| 4 | **Spark** | One-shot Lindblad jolt — wet country only (chips grey on closed ground); the kick that can *re-purify*. **E** reads the gauge. Mode 2 (🌉): Majorana bridges — never sealed. |
| 5 | **Icon** | Inject dual-emoji qubits; **F tracks** a qubit's walk, **R incorporates** it when ripe. |
| 6 | **Merchant** | Standing contracts with the Bath (wet country only). 1/2/3 picks the channel — thermal / dephase / damp. Q exports, E reads the order book, R imports, **F settles**. |
| 7 | **Captain** | Biome lifecycle: cull, compass, discover. |
| 8 | **Ace** | The default: explore/fast-fwd (F, Shift+F reaps the season) / strike (R) / extract (Q) / pause (E). |
| 9 | **Operator** | Gate building: Bell, CNOT, CZ, SWAP, GHZ. |
| 0 | **Druid** | Rotations + Hadamard (E); 1/2/3 pick the X/Y/Z axis. |

Re-press the active hat to fall back to Ace. `Tab` cycles hats. `Shift` +
Q/E/R applies the verb to every valid plot.

## The surfaces (letter row)

- **C** — quest board: offers, contracts, the tutorial chain. Press **E**
  on any offer to read the faction's *resonance* with this biome — which
  axiom sings, which grates, and how they sit with who *you* are becoming.
- **V** — vocabulary atlas: the icons you know, and the ones you've seen.
- **B** — biome inspector. **N** — the network view: manifold, bridges, and
  (under its P tab) the density matrix itself as a heatmap.
- **M** — the affinity hypercube: the world's factions plotted on their
  alignment axes — where *you* sit among them, read back as physics.
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
