# The glyph language, in SpaceWheat

**Status:** live doc. It describes `Core/Story/GlyphLanguage.gd` as it is now, plus the
parts of the language the game does not yet speak (§9 onward lists them). The grammar
comes from Luke's glyph language (v0.1 to v0.4, 2026-11-08/09; source: The Broadcast's
`docs/GLYPH-LANGUAGE.md` @ `79645fb4cf32`, Semantica3's `S3_SCOPED_LANGUAGE.md` points
there). This page ports it to SpaceWheat's vocabulary. Where the two disagree, the
upstream grammar wins and this page gets patched.

The one-line version: **an emoji is a pole of a qubit, a ket is a statement, a bra is
a question, nesting is conditioning, and nothing means anything until a scope has
declared the space.**

SpaceWheat doesn't need an analogy for this. A biome *is* a declared space: a
`QuantumComputer` holding a real density matrix ρ over qubits whose two poles are named
emoji (`icons.json` `pole_0` / `pole_1`). Everywhere else the language has to argue
that its glyphs point at a Bloch sphere. Here the sphere is already being simulated.

Rendering a sentence never measures or changes a state. That rule is carried over
unchanged, and the module is pure so it can't break it.

---

## 1. The scope rule: a biome is a scope

A sentence means nothing on its own. It is read against one scope, written or implied
by context:

```
spacewheat/Village    [.76]👥
```

| Language | SpaceWheat |
|---|---|
| scope | a biome: `spacewheat/<BiomeName>` (`GlyphLanguage.scope_for_biome`) |
| register (qubit) | one icon axis in that biome's `RegisterMap` |
| poles | the icon's north/south atoms (`pole_0` = north = `|0⟩`, `pole_1` = south = `|1⟩`) |
| frame | the engine's computational Pauli x/y/z frame |
| content version | *open:* see §10 |

Two scopes can both use 🔥 (Village's 🔥/❄ register, VolcanicWorlds' 🔥). That doesn't
relate them. Sharing a glyph is not a mapping. Inside one biome, `RegisterMap` gives each
atom one register, so a pole glyph is unambiguous there.

Outside a scope the language is *undefined*, not wrong. A socialite that couldn't measure
any biome falls back to its own glyphs. Its line has no scope, so §8 writes every glyph
dark and asserts nothing.

## 2. Glyphs are poles

A register is one qubit and each pole has a glyph. Examples from `icons.json`:

```
Solar        ☀ = |0⟩   🌙 = |1⟩
Land         ✊ = |0⟩   🌾 = |1⟩
Liberation   👥 = |0⟩   💀 = |1⟩
Predation    🦅 = |0⟩   🩸 = |1⟩
Clearing     🪓 = |0⟩   🔥 = |1⟩
```

The live Village basis in a headless boot (§8) draws from 👥/🍞, 🔥/❄ and ⚙ (paired
with 💨 in `biomes.json`). Saying 👥 inside
`spacewheat/Village` points at *that* sphere and picks *that* direction on it. A
register written as its pole pair (`👥🍞`) means the sphere, not a direction.

## 3. Six sentence forms

| Form | Example | Reading | In SpaceWheat |
|---|---|---|---|
| **ket** (collapsed) | `\|👥🔥⚙⟩` | siblings read jointly, each at a pole | a basis state of the biome, e.g. one chatter draw |
| **population** | `[.76]👥` ≡ `[.24]🍞` | support along a pole, read off ρ; symmetric | a qubit marginal, `viz_cache` `p0`/`p1` |
| **evidence** | `🌾!1` | observed 🌾 at efficiency η, which has a direction and a strength | an R-strike: a projective measurement (η = 1) with back-action |
| **Bloch vector** | `[r,θ,φ]👥🍞` | how sure, which pole, which phase | the Bloch inspector; the engine holds all three |
| **dark** | `🌾?` | nothing has measured it | a fogged, unexplored plot. Dark is not zero and not a half |
| **bra** (question) | `⟨🌾\|` | how much 🌾? | a chatter line's ask; every quest gate (§9) |

Juxtaposition *inside a ket* means product. Whether the joint state factorises is the
field's business: Village's registers can be entangled by the Loom (a Bell pair) and the
ket still reads them jointly. The tie mark `|☀⌢🔥⟩`, which asserts non-separability, is
upstream v0.3. It needs a joint-measurement receipt, and SpaceWheat has the full joint ρ,
so here it is *earned* whenever mutual information is non-zero. The game doesn't write it
yet.

**Chatter is not evidence.** `BiomeMeasurementSampler` draws a basis outcome from
`⟨b|ρ|b⟩` *without* back-action: the biome doesn't collapse when a socialite talks. So a
chatter line is a ket (what the speaker drew) plus populations (what ρ says), not a `!η`
observation. An R-strike is the evidence form.

## 4. Nesting is conditioning: fractal worlds are descent

```
🌲›🦅›🩸        given 🌲, given 🦅 (a register in 🌲's child world), the 🩸 pole
```

`›` is descent, which is a different operator from juxtaposition: `|🌲🦅🩸⟩` is three
siblings in one scope, while `🌲›🦅›🩸` is a path three worlds deep. SpaceWheat already
has the structure. Injecting an icon pair can open a **fractal child world** under a
register (`FractalWorldService.on_inject`, the indigo descend satellite). That child
biome is the child scope, and stepping into it is `›`. Depth is precision: a sentence
one level deep is a cheap, honest, coarse block over everything beneath it. The game
doesn't write `›` sentences yet.

## 5. Normalisation

Two speakers must mean the same sun. The canonical form strips variation selectors
(U+FE0F, U+FE0E) and skin-tone modifiers (U+1F3FB to U+1F3FF) and keeps ZWJ sequences
whole. `GlyphLanguage.canonical` does this. It matters here because the registry already
spells one glyph two ways: `icons.json` *Fitting* is `⚙️`/`🔧` while every other gear is
`⚙`.

## 6. Numbers: measured, forecast or dark (v0.4)

Every number is one of three things, and the mark says which:

| Mark | Meaning | SpaceWheat example |
|---|---|---|
| `x` | measured: read off a receipt, or off ρ | `[.76]👥` marginal, purity, spectral gap now |
| `x~` | forecast: a model's prediction, which a later measurement can grade | the attractor a biome is "trying to become", ripening ETA, a what-if gap (`0.61→0.54~`) |
| `?` | dark | an unexplored plot, or a register with no marginal |

Composition: one `~` input makes the result `~`, and one `?` makes it `?`. Chatter
populations are written straight because they are read off the live ρ. Upstream §29a
asks whether a number *rendered* from a state deserves its own "inference" mark. In
SpaceWheat ρ is the world rather than a model of one, so straight seems right, but that
is Luke's call (§10).

Resolution: the chatter scope declares ε = 0.01. Numbers are written to hundredths with
no leading or trailing zeros, and the ends are bare: `[.8]`, `[.05]`, `[1]`, `[0]`.

## 7. Verbs (v0.2), read as SpaceWheat's verbs

Prefix syntax: `VERB operands`. A verb sentence compiles to an engine operation, and read
aloud it is prose. None of these are written by the game yet. The table shows where each
one would land.

| Glyph | Verb | Reading on the sphere | SpaceWheat operation |
|---|---|---|---|
| ✨ | creation | declare a register, born mixed | Icon hat Add/Incorporate: `expand_quantum_system(north, south)` |
| T | transform | unitary rotation, purity unchanged | closed evolution `ρ ← UρU†`; Druid rot± / Hadamard |
| → | push | time forward, dissipation shortens the vector | Lindblad channels, time skip, `−`/`=` clock dial |
| ∇ | fusion | tensor-join two registers | the Loom (Bell pair), Operator gates, `bridge_fuse` |
| Δ | fission | partial trace, lossy | per-qubit marginals (`viz_cache`) |
| ⤳ / ← | skip / pull | checkpoint / return to a revision | save / load (pull is ledger-only) |
| ∅ | null | the register goes dark | Icon hat Trim; Captain Cull |
| 📏 | observe | measurement at efficiency η | Ace R-strike (`🌾!1`) |
| 👁 | attend | a bra; read without collapse | Inspect, the Bloch inspector, chatter itself |
| 📍 | commit | select a pole as *the* choice | Ace Q gather after a strike (pays the bank) |
| 🔮 | possibility | open a child scope under a pole | fractal child world (§4) |
| 〰 / ⚡ | resonance / tension | fidelity / distance between two states | faction alignment couplings; a bridge's overlap |
| 🧵 | trace | trajectory invariants, holonomy | Berry phase tracking (Icon hat Track) |

**Collision:** several verb glyphs are also SpaceWheat atoms. ⚡ is *Radiance*'s south
pole and the Spark hat, ✨ is a VolcanicWorlds/TidalPools atom, and 📍 is a *Navigation*
pole. The upstream grammar keeps verbs to prefix position. Inside a SpaceWheat scope,
`⚡ ⟨ψ|φ⟩` and the atom `[.4]⚡` can still be told apart by position, but a reader might
not manage it (§10).

## 8. The chatter dialect (implemented)

Socialites already speak by measuring biomes: `SocialiteCluster.tick` draws one basis
state from a biome its faction is native to, and the per-qubit marginal at each drawn
pole comes along with it (`BiomeMeasurementSampler.sample_basis_with_marginals`). The
glyph language gives that measurement a grammar instead of a bare emoji stream (the
codex's open question 5, "is the chatter readable or noise?").

```
spacewheat/Village  |🍞🔥⚙⟩  [.24]🍞 [.67]🔥 [.94]⚙  ⟨🔥|
└─ scope ─────────┘ └ ket ─┘ └ populations ──────┘  └ask┘
```

That line is real, from a headless boot: the Carrion Throne drew 🍞, a 24% outcome
(`[.24]🍞` ≡ `[.76]👥`), and asks about fire, the register Village is least sure of.

**Grammar** (pinned by `tests/test_glyph_language.py`, which has its own reference
parser):

```
sentence  := scope "  " ket "  " pops [ "  " ask ]     inside a scope
           | dark { " " dark }                         no scope: undefined, all dark
scope     := "spacewheat/" BiomeName
ket       := "|" glyph+ "⟩"                            the drawn basis state, qubit order
pops      := pop { " " pop }                           one per ket glyph, same order
pop       := "[" num "]" glyph                         marginal at the drawn pole, straight
           | glyph "?"                                 no marginal: dark
num       := "0" | "1" | "." digit [digit]             ε = 0.01, no trailing zero
ask       := "⟨" glyph "|"                             least-sure register (marginal nearest ½),
                                                       first on a tie; absent if all dark
```

The populations spell the ket glyph for glyph, every glyph is canonical (§5), and the
sentence round-trips through the parser unchanged.

**Where it shows:**
- Each chatter event gains `glyph: {scope, ket, populations, ask, short, sentence}`. The
  old `emojis` and `line` fields are unchanged, so nothing that reads them moves.
- The murmur bubbles (Story, on X) show `short`, the ket and the ask, muted under the
  sized emoji. The inspect panel (E) shows the full `sentence` as a `glyph` row.
- The rig has a read-only `story_chatter` action that returns the recent events with
  their sentences, for playtest drivers.

**Files:** `Core/Story/GlyphLanguage.gd` (pure, static, no state),
`Core/Story/SocialiteCluster.gd` (one field), `UI/Overlays/ControlsOverlay.gd` (two
labels), `tests/glyph_language_smoke.gd`, `tests/glyph_chatter_ingame_probe.gd` (a real
headless boot that prints the chatter; its pytest is skipped under `SW_SKIP_LONG=1`).

**The ask has no threshold.** The bra goes to the register nearest one half by argmin,
so a fully settled biome still asks about its least-settled qubit. That follows the
game's no-special-cases rule. It also means the ask can name either pole of the same
register (`⟨🔥|` or `⟨❄|`), depending on which one was drawn.

## 9. Does it help the quests? (assessment; proposed, not done)

**Short answer: yes for gates and glosses, no for titles.** Most campaign predicates
already *are* sentences in this language, in JSON. Titles and hints are prose for
players and should stay prose.

What the predicates already say (from `Core/Campaign/campaign.json`):

| Predicate (count) | Glyph sentence it already is |
|---|---|
| `biome_state_gte {Village, 💨, .12}` (8) | `spacewheat/Village  ⟨💨\| ≥ [.12]` — a bra with a target population |
| `biome_state_lte {Lanternfall, 📯, .25}` | `spacewheat/Lanternfall  ⟨📯\| ≤ [.25]` |
| `biome_attractor_emoji_gte {Village, ⚙, .4}` | `⟨⚙\| ≥ [.4~]`: the attractor is a **forecast**, so the `~` is earned |
| `atom_in_biome {Village, 🪵}` (7) | 🪵 is a pole in `spacewheat/Village` (declared, not dark) |
| `icon_incorporated {StarterForest, 🦅, 🐇}` | `✨ 🦅🐇` in `spacewheat/StarterForest` |
| `biome_explored {StarterForest}` | no register in the scope is `?` any more |
| `gate_sequence_contains measure` (15) | `📏` happened (an `!η` receipt exists) |
| `purity_at_most`, `coherence_at_least` | conditions on `r` and on the off-diagonal (`φ` is meaningful) |
| `mutual_information_at_least` | the tie mark `⌢` is earned |
| `berry_*`, `standing_gte`, `contracts_kept_gte`, `signature_size_gte` | **no glyph form.** These are ledger counts, not states of a register |

**Proposal, cheapest first:**

1. **Render, don't author.** The Arc tab's per-predicate breakdown (the `x/0.85` rows)
   could show each state predicate as a live glyph sentence: `⟨💨| [.09] → [.12]` in
   Village. That is a GDScript renderer over the predicate dict. **No change to
   `campaign.json`, and no `build.py` / `validate.py` run.** It would be the most useful
   step, because it shows the player the exact register a gate is watching.
2. **Derive at build time.** `tools/campaign/build.py` could emit a `glyph` string per
   predicate into the compiled JSON, with `validate.py` checking that it parses with the
   grammar above. The spec still isn't hand-edited: the glyph is a compiler output.
3. **Author it** as a spec field. Not recommended. It duplicates what the predicate
   already says, and the two would drift.

Titles ("The Demos Sleeps", "Both Poles at Once") and hints ("Explore a plot, strike it,
then gather the harvest.") should stay prose. The hint rule (≤70 chars, the ask stands
alone) is about legibility for a player who hasn't learned a notation. At most a glyph
gloss could sit *beside* a hint for players who have.

## 10. Open questions for Luke

1. **Is a chatter draw a ket?** §8 writes the Born draw as `|…⟩`. Strictly it is one
   sample with no back-action, closer to "the speaker says" than "the world is". The
   alternative is to write only populations plus the ask and drop the ket.
2. **Scope versions.** Upstream writes `scope@version`. A biome's basis changes when
   icons are added or trimmed. Should the version be the register list's hash, the save
   tick, or nothing (implied by the moment)?
3. **Straight or inference** for numbers rendered from ρ (upstream §29a). SpaceWheat's ρ
   is the world, so straight looks right here, but the hive may want one rule
   everywhere.
4. **Verb glyphs that are also atoms** (⚡ ✨ 📍). Accept the positional disambiguation,
   or give SpaceWheat's dialect different verb glyphs?
5. **Should the ask ever be silent?** It always asks today, which fits no-special-cases.
   A settled biome asking about a qubit at `[.99]` reads oddly.
6. **Player-facing or inspector-only?** The bubble shows the compact form today, muted.
   It could go only in the inspect panel, or it could get a prose gloss (`~` read as
   "about", `?` as "unknown"), which upstream §26 expects of a renderer.

## Not ported

From upstream, deliberately left out: the ledger efficiency tiers and the hive LAW gates
behind each verb, the vouch/override grading (§29), the transmission-chain study (§21),
the product scope `s₁⊗s₂` (§19; it would fit SpaceWheat's bridges between biomes, and is
a candidate for later), and the mixed-state resonance/tension formulas (§18). They are
about the hive's belief ledger, not a game whose state is exact.
