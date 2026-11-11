# The glyph language, in SpaceWheat

**Status:** live doc. It describes `Core/Story/GlyphLanguage.gd` and
`Core/Story/FactionChatter.gd` as they are now. It is also **SpaceWheat's proposal back
to Semantica** (§11): verbs, scope tags, dark pairs, ties, and a rule for when to speak,
worked out here against a real emoji world for the Semantica team to adopt. The grammar
comes from Luke's glyph language (v0.1 to v0.4, 2026-11-08/09; upstream: The
Broadcast's `docs/GLYPH-LANGUAGE.md` @ `79645fb4cf32`, which Semantica3's
`S3_SCOPED_LANGUAGE.md` points to). Luke's rulings are in §10, and the experiments
behind §8's rules are in `docs/history/2026-11-10_GLYPH_CHATTER_EXPERIMENTS.md`.

The one-line version: **an emoji is a pole of a qubit, a ket is a statement, a bra is
a question, nesting is conditioning, and nothing means anything until a scope has
declared the space.**

SpaceWheat doesn't need an analogy for this. A biome *is* a declared space: a
`QuantumComputer` holding a real density matrix ρ over qubits whose two poles are named
emoji (`icons.json` `pole_0` / `pole_1`). Everywhere else the language has to argue
that its glyphs point at a Bloch sphere. Here the sphere is being simulated.

Rendering a sentence never measures or changes a state. `GlyphLanguage.gd` is pure and
takes its random draws from the caller, so it can't break that rule.

---

## 1. The scope rule: three kinds of scope

| Scope | Example | Its registers |
|---|---|---|
| biome | `spacewheat/Village@7fc7` | the biome's qubits, in qubit order |
| faction | `faction/Swift Herd@9985` | the faction's signature icons, wherever in the world they live |
| product | `spacewheat/BioticFlux⊗StarterForest@408a` | two biomes read together (upstream §19) |

**The `@tag` is the scope's version:** the first four hex digits of SHA-256 over its
ordered pole pairs, written `north/south` and joined by commas, after normalisation (§5).
Village's `🔥/❄,👥/🍞,⚙/💨` hashes to `4ed9`. Add or trim an icon and the tag changes, so
a biome's dialect visibly shifts with its vocabulary. The pytest recomputes tags with
`hashlib`.

Sharing a glyph is not a mapping. Cross-scope juxtaposition is undefined, except in a
product scope, which exists to declare it. A faction scope is a declared bundle of
registers drawn from many biomes, which is what lets a faction's line run across them.
Outside any scope the language is *undefined*: every glyph is written dark.

## 2. Glyphs are poles

```
Solar        ☀ = |0⟩   🌙 = |1⟩
Land         ✊ = |0⟩   🌾 = |1⟩
Antimatter   ⚫ = |0⟩   ✨ = |1⟩      (the verbs null and creation, §7)
```

Saying 👥 inside `spacewheat/Village@7fc7` points at *that* sphere and picks *that*
direction. A register written as its pole pair (`👥🍞`) means the sphere, not a
direction. Darks use the pair form.

## 3. Six sentence forms

| Form | Example | Reading | In SpaceWheat |
|---|---|---|---|
| **ket** | `\|🐺⌢🦅💀⟩` | registers read together, each at a pole; ⌢ = these two not independent | one joint draw per biome |
| **population** | `[.76]👥` ≡ `[.24]🍞` | support along a pole, read off ρ | a qubit marginal, measured |
| **evidence** | `🦅!1`, `🦅!η` | observed 🦅 at efficiency η | a strike: projective (η = 1) in a closed biome, a partial drain at `drain_eta` in an open one (`ProbeActions.action_measure`) |
| **Bloch vector** | `[r,θ,φ]👥🍞` | how sure, which pole, which phase | the Bloch inspector |
| **dark** | `🌾?`, `🐇🦌?` | nothing measures it | a fogged plot; for a faction, an icon you hold nowhere |
| **bra** | `⟨🌾\|` | how much 🌾? | what a speaker wonders about; every quest gate (§9) |

Chatter is not evidence: drawing a line collapses nothing, only a strike does.

## 4. Nesting is conditioning: fractal worlds are descent

`🌲›🦅›🩸` means: given 🌲, given 🦅 (a register in 🌲's child world), the 🩸 pole.
Injecting an icon pair can open a fractal child world under a register
(`FractalWorldService.on_inject`). That child biome is the child scope, and stepping into
it is `›` (the verb ⤵). The game doesn't write `›` lines yet.

## 5. Normalisation

The canonical form strips variation selectors and skin-tone modifiers and keeps ZWJ
sequences whole (`GlyphLanguage.canonical`). It applies before hashing: `icons.json`
writes *Fitting* as `⚙️`/`🔧`, and every other gear as `⚙`.

## 6. Numbers: measured, forecast or dark

| Mark | Meaning | SpaceWheat example |
|---|---|---|
| `x` | measured | anything read off the simulated state (Luke's ruling) |
| `x~` | forecast | an attractor target, a ripening ETA, a what-if gap |
| `?` | dark | an unexplored plot; a register no biome holds |

One `~` input makes a result `~`, and one `?` makes it `?`. Resolution is ε = 0.01:
`[.8]`, `[.05]`, `[1]`, `[0]`.

## 7. Verbs

Syntax is prefix: `VERB operands`. The Strand Dance keeps upstream's glyphs, except null.
The other verbs move off glyphs SpaceWheat already uses as content.

**Strand Dance**

| Verb | Glyph | SpaceWheat operation |
|---|---|---|
| creation | ✨ | Icon hat Add/Incorporate (`expand_quantum_system`) |
| null | **⚫** (was ∅) | the register goes dark: Icon hat Trim, Captain Cull |
| transform | T | closed evolution `ρ ← UρU†`; Druid rot± / Hadamard |
| push | → | Lindblad channels, time skip, the clock dial |
| pull | ← | load a save (ledger-only: there is no un-measure) |
| skip | ⤳ | save |
| fusion | ∇ | the Loom (Bell pair), Operator gates, `bridge_fuse` |
| fission | Δ | per-qubit marginals |

✨ and ⚫ are the two poles of the **Antimatter** icon, so creation and annihilation are
a qubit in the world. Those two collisions are deliberate.

**The other verbs**

| Verb | Upstream | SpaceWheat | SpaceWheat operation |
|---|---|---|---|
| observe | 📏 | **❗** | a strike; `❗ 🦅` ≡ `🦅!1` (the `!` mark made a verb) |
| attend | 👁 | **❔** | Inspect; chatter; dark stays the ASCII `?` suffix |
| verify | 🧪 | **🚦** | a gate check: ✅ green, ❌ red, unlit = dark |
| commit | 📍 | **📌** | gather after a strike (pays the bank) |
| possibility | 🔮 | **⤵** | step into a fractal child world |
| resonance | 〰 | **🟰** | two readings agree |
| tension | ⚡ | **⚠** | two readings disagree |
| reflect | 🪞 | **↩** | an outcome grades a forecast |
| trace | 🧵 | **➰** | Berry phase tracking (Icon hat Track) |
| strand / braid | 🪢 / ≋ | **〰 / ➿** | one flow / two flows twisted together |

`GlyphLanguage.VERBS` holds the list. A test checks that every non-Strand verb is off
the atom set and that null/creation are Antimatter's poles.

## 8. Chatter: who speaks, about what, and where

Chatter gives an impression of what is happening. It never appears on the farm. It is
one stream of lines, and each surface filters it:

| Surface | Lines shown |
|---|---|
| **Story room** (O, on X) | every line from a faction you stand well with (`scalar()` > 0) or from your own people (The Demos), plus a standing-weighted draw that gives friends extra air |
| **B** (biome inspector) | the latest line of each faction **connected to this biome**, by the market's rule: it owns an icon matching one of the biome's qubit pairs (`FactionBiomeMap.factions_for_biome_by_signature`, as in `MarketLattice`). Lines lit when they mention the plot's poles |
| **N** (live) | each **biome's** own line (the socialite measurement), plus *Between biomes*: one icon read in two biomes |

A faction speaks its whole vocabulary: every icon in its signature, wherever it lives.
Icons you hold nowhere come out dark, as pole pairs. Lines from a real boot:

```
faction/Pack Lords@3fce  |🐺🦅💀⟩  [.87]🐺 [.87]🦅 [.92]💀  🌾🐑?  ⟨🐺| ⟨🦅|
faction/Millwright's Union@65c5  |👥⟩  [.66]👥  ⚙🏭? 💨🔨? 🪓🪵?
faction/Pack Lords@3fce  |💀⟩  [.2]💀  ⟨💀|
spacewheat/BioticFlux⊗StarterForest@06e0  ⚠ [.84]☀₁ [.1]☀₂
```

The Union keeps mentioning 🏭, 🔨 and 🪵, which you don't have. That's the hint about
which faction to chase for which emoji.

### The rules: three information quantities, one each

| Grammar element | Driven by | Rule |
|---|---|---|
| **what comes up** (and so length and cadence) | **relative entropy** D (nats) of the reading now from what *this faction* last said about the register | comes up with probability **1 − e^(−D)**; a faction speaks when something comes up |
| **what is asked** ⟨g\| | **entropy** h(p) (bits) of the drawn register | asked with probability **h(p)** |
| **what is tied** ⌢ (and what comes along) | **mutual information** (bits) of two registers' pole outcomes, from the biome's basis distribution | a register of the same biome joins one that came up, and adjacent same-biome registers are tied, with probability **MI** |

None of these rules has a tuned parameter. A faction stays quiet about a register about
as often as its last word still covers the truth. A coin wobbling (.5→.6, D ≈ 0.02) is
hardly news; a certainty breaking (.99→.9, D ≈ 0.15; .9→.1, D ≈ 1.8) is. The first time
a faction speaks, everything is news (D = ∞), so a faction introduces itself with its
whole lit vocabulary. Settled registers are stated; undecided ones are asked. A Bell pair
(1 bit) is always tied and always mentioned together; independent registers never are.
Registers in different biomes are separate states and are never tied.

**Poles are drawn jointly** per biome from the biome's basis distribution, so correlated
registers come out correlated. The ⌢ marks come from the same distribution the poles are
drawn from.

**Why relative entropy.** The closed system never stops moving: every marginal
oscillates. Measured by plain motion, the world is always news, and line length showed no
difference between a quiet world and a churned one. Relative entropy weighs change by
how much it would surprise the speaker. The experiments are in the history note.

### Your relationship lifts four of those chances

Each lift is q → q^(1/(1+c)) for a standing channel c: c = 0 leaves q alone, a positive
channel opens the speaker up (√q at c = 1), and a negative one closes them. 0 and 1 are
fixed points, so no channel invents what isn't there. Each channel lifts the grammar
element its own definition names (`FactionStanding.gd`):

| Channel | Its definition | Lifts |
|---|---|---|
| 🤝 trust | positive interactions | **mentions**: a trusted faction tells you more |
| 🧿 attention | "the faction is watching this player" | **asks**: a watching faction asks more (⟨\| *is* attend) |
| 🗝 access | "unlocked services… or hidden information" | **darks**: the icons you hold nowhere |
| 🕸 entanglement | "shared-secret ties… an entanglement edge" | **ties** and partner pull-ins |
| 🩸 debt, ⚖ legitimacy | through `scalar()` | whether a faction is in your Story room, and how loud |

**Darks** come up in proportion to how much of its lit vocabulary the faction brought
up, lifted by 🗝. A faction with nothing lit in your world has no news and stays silent
(§10).

**Between lines** compare one register read in two biomes, in their product scope, when
the gap is news (the same 1 − e^(−D), summed over both sides). ⚠ means the readings lean
to different poles (the biomes would collapse different ways); 🟰 means the same pole.

### Grammar

Pinned by `tests/test_glyph_language.py`, which has its own parser:

```
line      := scope { "  " clause }                    inside a scope
           | dark { " " dark }                         no scope: undefined, all dark
clause    := ket "  " pops | darks | asks              in that order, each at most once
scope     := ("spacewheat" | "faction") "/" Name { "⊗" Name } "@" hex4
ket       := "|" glyph { ["⌢"] glyph } "⟩"             ⌢: these two are not independent
pops      := "[" num "]" glyph { " " … }               spell the ket, glyph for glyph
darks     := glyphs "?" { " " … }                      a pole, or a register's pole pair
asks      := "⟨" glyph "|" { " " … }                   each a glyph the line brought up
num       := "0" | "1" | "." digit [digit]             ε = 0.01, no trailing zero
between   := product-scope "  " ("⚠" | "🟰") " " pop sub " " pop sub   one register, two biomes
```

### Files

- `Core/Story/GlyphLanguage.gd`: pure; the grammar, the three information rules, the lifts.
- `Core/Story/FactionChatter.gd`: the faction voices. Its state is what each faction last
  said of each register, plus a ring of lines.
- `Core/Story/BiomeMeasurementSampler.gd`: `pole_states` and `pair_mutual_information`.
- `Core/Story/SocialiteCluster.gd`: biome lines.
- `Core/Story/StoryEngine.gd`: `story_chatter`, `faction_lines_for_biome`, `between_chatter`.
- `UI/Overlays/ControlsOverlay.gd` (Story room), `BiomeInspectorOverlay.gd` (B) and
  `InspectorOverlay.gd` (N).
- The rig's `story_chatter` action returns biome and faction lines.
- Tests: `tests/glyph_language_smoke.gd` (pure cases, mock voices, a Bell pair, lifts),
  `tests/glyph_chatter_ingame_probe.gd` (a real headless boot; its pytest is skipped under
  `SW_SKIP_LONG=1`), and `tests/test_glyph_language.py`.

Constants: `PLAYER_STORY_WEIGHT` = 0.25 (your own people's extra Story draw) and
`NEWS_CAP` = 20 nats (weighs "never spoken of" against finite news when choosing who
speaks). Nothing else is tuned.

## 9. Does it help the quests? (assessment; proposed, not done)

**Yes for gates and glosses, no for titles.** Most campaign predicates already *are*
lines in this language, written in JSON:

| Predicate (count) | Glyph line it already is |
|---|---|
| `biome_state_gte {Village, 💨, .12}` (8) | `spacewheat/Village@…  ⟨💨\| ≥ [.12]` |
| `biome_attractor_emoji_gte {Village, ⚙, .4}` | `⟨⚙\| ≥ [.4~]`: an attractor is a **forecast** |
| `atom_in_biome {Village, 🪵}` (7) | 🪵 is a pole in the scope (and the `@tag` changes) |
| `icon_incorporated {StarterForest, 🦅, 🐇}` | `✨ 🦅🐇` |
| `biome_explored {StarterForest}` | no register in the scope is `?` any more |
| `gate_sequence_contains measure` (15) | `❗` happened |
| `mutual_information_at_least` | a ⌢ the chatter would now write |
| `berry_*`, `standing_gte`, `contracts_kept_gte` | **no glyph form**: ledger counts, not registers |

**Proposal, cheapest first:**
1. **Render, don't author.** The Arc tab's per-predicate rows could show each state
   predicate as a live line. That is a GDScript renderer, with no change to
   `campaign.json`.
2. **Derive at build time.** `tools/campaign/build.py` could emit the glyph form, with
   `validate.py` parsing it.
3. **Author it.** Not recommended: it would duplicate the predicate.

The chatter could also carry quests: a gate register's news would naturally surface in
the quest-giver's lines. Titles and hints stay prose.

## 10. Rulings, and what's open

**Ruled (Luke, 2026-11-09):**
- Chatter can be whatever serves an impression of what's happening.
- A biome scope's version is the hash of its qubit list.
- Numbers read off the simulated state are measured.
- Collisions happen; language is messy. 🛑 Embargo and 🚧 Sealed stay content.
- Null is ⚫ and creation stays ✨; the other verbs take the SpaceWheat set.
- Factions speak their whole vocabulary, and the darks are hints.
- Chatter appears in the Story room (standing), B (connected factions) and N (in scope),
  never on the farm.
- Stable biomes ask less, chaotic ones more.
- Line length should have high dynamic range.

**Decided overnight (Claude, 2026-11-10; Luke asked for taste, so these are up for
review):**
1. **Line length** follows relative entropy (§8): one rule drives what comes up, how
   much, and how often. The range is heavy-tailed: mostly terse one-register news,
   occasional long lines when something breaks, full introductions.
2. **Joint draws** per biome, with ⌢ ties and partner pull-ins at P = pole MI.
3. **Standing channels** each lift the grammar element their definition names (§8).
4. **For Semantica:** §11.

**Open:**
1. **Dark-only factions stay silent.** A faction that shares nothing with your world
   never has news. Should rumours exist, e.g. a 🗝-gated chance to name what it deals in?
2. **The early Story room is quiet.** Before anyone stands well with you, only your own
   people talk there, and only when their registers move.
3. **The rig's world isn't the player's.** With lookahead off (the rig default) the
   simulation runs 5× faster than the player's lane and never fills the mutual-information
   cache. Chatter tuned against rig runs would be tuned against a different world.
   Found while tuning; see [PR #65](https://github.com/AQuantumArchitect/SpaceWheat/pull/65).
   Which speed is canonical is a design call.

## 11. For Semantica: what SpaceWheat proposes upstream

These came out of speaking the language about a world where every glyph is already
content:

1. **Verbs that stay off the content alphabet.** Of upstream's lexeme glyphs, ✨ 🧪 📍 🔮
   🪞 🧵 🪢 👁 🔍 and ⚡ were all already SpaceWheat atoms. A language spoken *about* an
   emoji world needs function glyphs the world isn't using. Proposed set: observe ❗
   (the `!η` mark as a verb), attend ❔, verify 🚦 (three lights for ✅ / ❌ / dark),
   commit 📌, possibility ⤵, resonance 🟰, tension ⚠, reflect ↩, trace ➰, strand 〰,
   braid ➿. Null as ⚫ is SpaceWheat's (Antimatter); upstream may prefer to keep ∅.
2. **Scope tags as content hashes.** `@` plus SHA-256 over the canonical ordered pole
   pairs (`n/s,n/s`, after §5 normalisation). Four hex digits suit display; use eight or
   more for identity across a hive. The version then *is* the vocabulary, with no
   counter to keep.
3. **A dark register is its pole pair with `?`** (`🐇🦌?`). §2 already lets a pole pair
   name a register; dark is then a property of the register, not of one pole.
4. **The tie ⌢ means "not independent in this basis".** It is earned by a joint receipt:
   here, the mutual information of the pole outcomes in the same distribution the
   statement is drawn from. That is weaker than entanglement: a classically correlated
   mixture is ⌢ but separable. Proposal: keep ⌢ for correlation, which any joint
   receipt can witness, and reserve a separate mark for entanglement proper, which needs
   a witness.
5. **When to speak: one information law per grammar element.** For any agent narrating a
   belief field (an ant, a seat, a faction):
   - write a statement about a register with probability 1 − e^(−D), where D is the
     relative entropy since you last wrote about it;
   - ask (⟨g|) with probability h(p);
   - tie with probability equal to the mutual information.

   These are parameter-free. They keep sentences about news, questions about uncertainty,
   and ties about structure, which matters most in the hive, where volume is cost.
6. **Between readings in a product scope:** for diagonal readings, ⚠ when the two lean to
   different poles and 🟰 when they lean the same way. Upstream's Uhlmann/Bures
   quantities give the magnitude when one is wanted.
7. **Clause order and number form:** scope, ket + populations, darks, asks, separated by
   two spaces; numbers at ε = 0.01 with no leading or trailing zeros.

SpaceWheat-specific, not proposed upstream: the relationship lifts (q^(1/(1+c)) per
standing channel). The pattern might map onto the hive's trust tiers, but that is
Semantica's call.

## Not ported

Left out on purpose: the ledger efficiency tiers and the hive LAW gates behind each verb,
the vouch/override grading, the transmission-chain study, and the mixed-state
resonance/tension formulas. They concern the hive's belief ledger, not a game whose
state is exact.
