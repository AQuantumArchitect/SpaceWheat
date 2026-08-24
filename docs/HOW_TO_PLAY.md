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
  hat, **F explores** a fresh plot (1🍞) or fast-forwards an explored one;
  **Shift+F reaps the season** — the whole biome's yield lands at once.

## The seven hats (number row 4–0)

| Key | Hat | What it does |
|-----|-----|--------------|
| 4 | **Spark** | One-shot Lindblad jolt — wet country only (chips grey on closed ground); the kick that can *re-purify*. **E** reads the gauge. Mode 2 (🌉): Majorana bridges — never sealed. |
| 5 | **Icon** | The vocabulary hat — **the story runs on it** (see Berries below). Mode **1** is inject: **F tracks** a plot's walk (⌖), **R incorporates** it when ripe. Mode **2** is the mirror 🪞 (see What Turns). R on an empty plot (mode 1) adds an icon, Q trims one. |
| 6 | **Merchant** | Standing contracts with the Bath (wet country only). 1/2/3 picks the channel — thermal / dephase / damp. Q exports, E reads the order book, R imports, **F settles**. |
| 7 | **Captain** | Biome lifecycle: cull, compass, discover. |
| 8 | **Ace** | The default: explore/fast-fwd (F, Shift+F reaps the season) / strike (R) / extract (Q) / pause (E). |
| 9 | **Operator** | Gate building: Bell, CNOT, CZ, SWAP, GHZ. Mode **2** is the compass 🧭 (see What Turns). |
| 0 | **Druid** | Rotations + Hadamard (E); 1/2/3 pick the X/Y/Z axis. |

Re-press the active hat to fall back to Ace. `Tab` cycles hats (not modes).
Keys `1`/`2`/`3` pick a hat's sub-mode. `Shift` + Q/E/R applies the verb to
every valid plot.

## What Turns — the mirror and the compass

A ripe loop comes home on the Bloch sphere with its spinor sign reversed.
Nothing local can see that. **Icon `5`, key `2` (🪞):** pick a traveler, **R**
marks a *different* plot stay-home, key `1` **F** tracks the traveler, wait
until ripe (**do not Incorporate first**), key `2` **E** compares. A ripe
traveler against a stay-home reads **−1**.

**Operator `9`, key `2` (🧭):** **E** reads the loop card (β₁, Wilson
products, frozen lifts), **R** turns a plot's convention (fences flip; every
closed loop holds), **Q** combs the tree flat, **F** scrambles. What a turn
can change was never physics.

## Contracts and teachings — how the early story moves

The early acts advance on **kept contracts**: accept a delivery on the board
(**C**, market tab **Y**), gather fresh, claim it in Commitments (**C → U**).
Every kept contract raises that faction's standing — and standing is the
early game's whole ladder: factions **teach** you their words when they
count you reliable (the claim of a teaching quest IS the lesson), taught
words **plant** (Icon-hat R on an empty plot authors the biome's
Hamiltonian), and a faction that trusts you **pays better** (the ⭐ bonus on
its board rows). The objective portal (top-right) always names the one live
task and the next door behind it; tap it for the Arc.

## Berries — how the mid-game moves

From act 3 (*What the Land Remembers*) the acts advance on **incorporated
berries**, and the loop is short: pick a plot (`G H J K L ;`), put on the
Icon hat (`5`), press **F** to track its walk (⌖). Let time run — Ace-hat F
fast-forwards. When the loop has swept enough sky it **ripens**, and the
Icon-hat **R** chip reads *Incorporate*: press it. One incorporation = one
berry consumed + one new word in your signature — a word no faction taught
you, and the only kind that earns the **×4 harvest bonus**. The Arc tab
(**X → I**) shows exactly how many berries each act asks of which biome.

Three things the impatient learn the hard way: loops only ripen while **time
flows** (E pauses the world; F plays it on — the ⏸/▶ toast tells you which);
you can track **several plots at once** — they ripen together, then R
harvests them one after another; and **`=` doubles the active biome's clock**
(up to 16×, `-` slows it back) — a farmer who speeds the clock ripens a loop
in a few beats instead of a season.

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
  pixels and a certificate JSON beside it. The toast names the real folder path.

## Navigation

`T Y U I O P` — biome slots (or tap a biome's labelled orb on the field's
left rail). `G H J K L ;` — plots. `'` — select all
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
