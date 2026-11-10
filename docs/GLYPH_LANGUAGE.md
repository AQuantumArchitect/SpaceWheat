# The glyph language, in SpaceWheat

**Status:** live doc. It describes `Core/Story/GlyphLanguage.gd` and
`Core/Story/FactionChatter.gd` as they are now. It is also **SpaceWheat's proposal back
to Semantica**: the verbs (§7), scope tags (§1), faction scopes and pair-form darks (§8)
and between-lines (§8) were hammered out here against a real emoji world, for the
Semantica team to adopt. The grammar comes from Luke's glyph language (v0.1 to v0.4,
2026-11-08/09; upstream: The Broadcast's `docs/GLYPH-LANGUAGE.md` @ `79645fb4cf32`,
which Semantica3's `S3_SCOPED_LANGUAGE.md` points to). Rulings Luke made while porting
are listed in §10.

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

A sentence means nothing on its own. It is read against one scope:

| Scope | Example | Its registers |
|---|---|---|
| biome | `spacewheat/Village@7fc7` | the biome's qubits, in qubit order |
| faction | `faction/Swift Herd@9985` | the faction's signature icons, wherever in the world they live |
| product | `spacewheat/BioticFlux⊗StarterForest@408a` | two biomes read together (upstream §19) |

**The `@tag` is the scope's version:** the first four hex digits of SHA-256 over its
ordered pole pairs, written `north/south` and joined by commas, after normalisation (§5).
Village's `🔥/❄,👥/🍞,⚙/💨` hashes to `4ed9`. The tag changes when an icon is added or
trimmed, so a biome's dialect visibly shifts when its vocabulary does. Anyone can
recompute it; the pytest does, with `hashlib`.

Two scopes can both use 🔥. That doesn't relate them, because sharing a glyph is not a
mapping. Cross-scope juxtaposition is undefined, except in a product scope, which exists
to declare exactly that. A faction scope is a declared bundle of registers drawn from
many biomes, which is what lets a faction's line run across them.

Outside any scope the language is *undefined*, not wrong: every glyph is written dark
and nothing is asserted.

## 2. Glyphs are poles

A register is one qubit and each pole has a glyph. Examples from `icons.json`:

```
Solar        ☀ = |0⟩   🌙 = |1⟩
Land         ✊ = |0⟩   🌾 = |1⟩
Antimatter   ⚫ = |0⟩   ✨ = |1⟩      (the verbs null and creation, §7)
Predation    🦅 = |0⟩   🩸 = |1⟩
```

Saying 👥 inside `spacewheat/Village@7fc7` points at *that* sphere and picks *that*
direction. Writing a register as its pole pair (`👥🍞`) means the sphere, not a
direction. Darks use the pair form (§3).

## 3. Six sentence forms

| Form | Example | Reading | In SpaceWheat |
|---|---|---|---|
| **ket** | `\|👥🔥⚙⟩` | registers read together, each at a pole | a basis state drawn from a biome (biome chatter), or one draw per register (faction lines) |
| **population** | `[.76]👥` ≡ `[.24]🍞` | support along a pole, read off ρ | a qubit marginal (`viz_cache` `p0`/`p1`), measured |
| **evidence** | `🌾!1` | observed 🌾 at efficiency η | an R-strike: projective (η = 1), with back-action |
| **Bloch vector** | `[r,θ,φ]👥🍞` | how sure, which pole, which phase | the Bloch inspector |
| **dark** | `🌾?`, `🐇🦌?` | nothing measures it | a fogged plot; for a faction, an icon you hold nowhere |
| **bra** | `⟨🌾\|` | how much 🌾? | what a speaker wonders about; every quest gate (§9) |

Juxtaposition inside a ket means product. Whether the joint state factorises is the
field's business. Chatter is not evidence: sampling a line doesn't collapse anything,
because only a strike does. Faction kets are drawn one register at a time, so they carry
marginals, not correlations (upstream's "a marginal never reconstructs a joint", §6).

## 4. Nesting is conditioning: fractal worlds are descent

```
🌲›🦅›🩸        given 🌲, given 🦅 (a register in 🌲's child world), the 🩸 pole
```

Injecting an icon pair can open a **fractal child world** under a register
(`FractalWorldService.on_inject`). That child biome is the child scope, and stepping into
it is `›` (the verb ⤵, §7). The game doesn't write `›` lines yet.

## 5. Normalisation

The canonical form strips variation selectors (U+FE0F, U+FE0E) and skin-tone modifiers
and keeps ZWJ sequences whole (`GlyphLanguage.canonical`). It applies before hashing,
which matters because `icons.json` writes *Fitting* as `⚙️`/`🔧` while every other gear
is `⚙`. Both spellings declare the same scope tag.

## 6. Numbers: measured, forecast or dark

| Mark | Meaning | SpaceWheat example |
|---|---|---|
| `x` | measured | anything read off the simulated state: marginals, purity, the gap now |
| `x~` | forecast | an attractor target, a ripening ETA, a what-if gap |
| `?` | dark | an unexplored plot; a register no biome holds |

**Ruled (Luke):** a number read off the simulated state counts as measured. In
SpaceWheat ρ is the world, not a model of it. One `~` input makes a result `~`, and one
`?` makes it `?`. Resolution is ε = 0.01: `[.8]`, `[.05]`, `[1]`, `[0]`.

## 7. Verbs: SpaceWheat's proposal

Syntax is prefix: `VERB operands`. **The Strand Dance keeps upstream's glyphs, except null.**
**The other verbs move off glyphs that SpaceWheat already uses as content.**

**Why move them:** checked against the game's ~230 atoms, nine of upstream's lexeme
glyphs were already content: ✨ 🧪 📍 🔮 🪞 🧵 🪢 👁, plus 🔍. ⚡ is also an atom (and
the Spark hat). A language that will be spoken *about* an emoji world needs verbs the
world isn't using. Collisions aren't forbidden (language is messy, and 🛑 Embargo and 🚧
Sealed stay content), but the verbs should avoid the content where they can.

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
| observe | 📏 | **❗** | Ace R-strike; `❗ 🌾` ≡ `🌾!1` (the `!` mark made a verb) |
| attend | 👁 | **❔** | Inspect, the Bloch inspector, chatter; dark stays the ASCII `?` suffix |
| verify | 🧪 | **🚦** | a gate check: ✅ green, ❌ red, unlit = dark |
| commit | 📍 | **📌** | Ace Q gather after a strike (pays the bank) |
| possibility | 🔮 | **⤵** | step into a fractal child world |
| resonance | 〰 | **🟰** | two readings agree |
| tension | ⚡ | **⚠** | two readings disagree |
| reflect | 🪞 | **↩** | an outcome grades a forecast |
| trace | 🧵 | **➰** | Berry phase tracking (Icon hat Track) |
| strand / braid | 🪢 / ≋ | **〰 / ➿** | one flow / two flows twisted together |

The list lives in code as `GlyphLanguage.VERBS`. A test checks that every non-Strand verb
is off the atom set and that null/creation are Antimatter's poles.

## 8. Chatter: who speaks, about what, and where

Chatter gives an impression of what is happening. It never appears on the farm. It
lives in three places, each with its own speakers:

| Surface | Who speaks | What you see |
|---|---|---|
| **Story room** (O, on X) | factions weighted by your **standing** with them, plus your own people (The Demos) | the bubbles; inspect (E) shows the full line |
| **B** (biome inspector) | factions **connected to this biome**, by the market's rule: they own an icon matching one of its qubit pairs (`FactionBiomeMap.factions_for_biome_by_signature`, as in `MarketLattice`) | a *Voices* block: each faction's latest line, lit when it mentions this plot's poles |
| **N** (live) | each **biome** speaking its own scope, plus factions comparing one icon **between biomes** | each biome's latest line under its row; a *Between biomes* block |

**A faction speaks its whole vocabulary:** every icon in its signature, wherever it
lives. Icons the player holds nowhere come out dark, as pole pairs. A line from a real
boot:

```
faction/Millwright's Union@65c5  |👥⟩  [.74]👥  ⚙🏭? 💨🔨? 🪓🪵?  ⟨👥|
```

The Union is reading the Village's people, and it keeps mentioning 🏭, 🔨 and 🪵, which
you don't have. Dark registers are how the chatter hints at which faction to chase for
which emoji.

**The physics drives everything, with no thresholds:**

- **Who speaks, and how often.** Each faction weighs `0.05 + motion`, where motion is how
  far its registers' marginals moved since it last spoke of them. Whether anyone speaks
  this tick follows the same news. A still world speaks about once every 20 ticks, a
  churned one every tick. The Story room's draw is further weighted by standing.
- **Line length** (dynamic range). Each register comes up with probability
  `1 − exp(−motion / 0.05)`, so a quiet world mutters one glyph and a world you're
  working runs on. The first time a faction speaks, everything is news.
- **Questions.** Each register in the line gets a ⟨bra| with probability equal to its
  binary entropy h(p). A stable biome states, a chaotic one asks.
- **Dark registers** come up as often as the speaker is talkative: in proportion to the
  share of its lit registers it brought up.
- **Between biomes.** When a mentioned register lives in two biomes, the faction
  compares the two readings in their product scope, but only when the gap has moved
  since it last compared them. The verb is ⚠ if the readings lean to different poles
  (the biomes would collapse different ways) and 🟰 if they lean the same way:

  ```
  spacewheat/BioticFlux⊗StarterForest@06e0  ⚠ [.84]☀₁ [.1]☀₂
  ```

**Biome lines** (N) come from the existing socialite measurement: one joint basis-state
draw, every qubit, with asks by entropy:

```
spacewheat/Village@7fc7  |🍞❄💰⟩  [.36]🍞 [.37]❄ [.27]💰  ⟨🍞| ⟨❄| ⟨💰|
```

**Grammar**, pinned by `tests/test_glyph_language.py`, which has its own parser:

```
line      := scope { "  " clause }                    inside a scope
           | dark { " " dark }                         no scope: undefined, all dark
clause    := ket "  " pops | darks | asks              in that order, each at most once
scope     := ("spacewheat" | "faction") "/" Name { "⊗" Name } "@" hex4
ket       := "|" glyph+ "⟩"
pops      := "[" num "]" glyph { " " … }               spell the ket, glyph for glyph
darks     := glyphs "?" { " " … }                      a pole, or a register's pole pair
asks      := "⟨" glyph "|" { " " … }                   each a glyph the line brought up
num       := "0" | "1" | "." digit [digit]             ε = 0.01, no trailing zero
between   := product-scope "  " ("⚠" | "🟰") " " pop sub " " pop sub   one register, two biomes
```

**Files:** `Core/Story/GlyphLanguage.gd` (pure), `Core/Story/FactionChatter.gd` (the
faction voices; its state is the marginals each faction last spoke of, plus a ring of
lines), `Core/Story/SocialiteCluster.gd` (biome lines), `Core/Story/StoryEngine.gd`
(`story_chatter`, `faction_lines_for_biome`, `between_chatter`),
`UI/Overlays/ControlsOverlay.gd` (Story room), `UI/Overlays/BiomeInspectorOverlay.gd`
(B), `UI/Overlays/InspectorOverlay.gd` (N). The rig's `story_chatter` action returns
recent biome lines. Tests: `tests/glyph_language_smoke.gd`,
`tests/glyph_chatter_ingame_probe.gd` (a real headless boot; skipped under
`SW_SKIP_LONG=1`), and `tests/test_glyph_language.py`.

**Tuning knobs** (`FactionChatter.gd`): `MOTION_TAU` = 0.05, the marginal motion that
makes a mention about 63% likely. `SPEAK_FLOOR` = 0.05, how often a still faction
speaks. `PLAYER_STORY_WEIGHT` = 0.25, how often your own people talk to you before you
have standing with anyone.

## 9. Does it help the quests? (assessment; proposed, not done)

**Yes for gates and glosses, no for titles.** Most campaign predicates already *are*
sentences in this language, written in JSON:

| Predicate (count) | Glyph line it already is |
|---|---|
| `biome_state_gte {Village, 💨, .12}` (8) | `spacewheat/Village@…  ⟨💨\| ≥ [.12]`: a bra with a target |
| `biome_attractor_emoji_gte {Village, ⚙, .4}` | `⟨⚙\| ≥ [.4~]`: an attractor is a **forecast** |
| `atom_in_biome {Village, 🪵}` (7) | 🪵 is a pole in the scope; also a change of the scope's `@tag` |
| `icon_incorporated {StarterForest, 🦅, 🐇}` | `✨ 🦅🐇` |
| `biome_explored {StarterForest}` | no register in the scope is `?` any more |
| `gate_sequence_contains measure` (15) | `❗` happened |
| `purity_at_most`, `coherence_at_least`, `mutual_information_at_least` | conditions on `r`, on the off-diagonal, on the tie mark `⌢` |
| `berry_*`, `standing_gte`, `contracts_kept_gte` | **no glyph form**: ledger counts, not registers |

**Proposal, cheapest first:**
1. **Render, don't author.** The Arc tab's per-predicate rows could show each state
   predicate as a live line (`⟨💨| [.09] → [.12]`). That is a GDScript renderer, with no
   change to `campaign.json`.
2. **Derive at build time.** `tools/campaign/build.py` could emit the glyph form, with
   `validate.py` parsing it. It is compiler output, not hand-edited spec.
3. **Author it.** Not recommended: it duplicates the predicate, and the two would drift.

There's also a natural link to the chatter: a quest's faction could voice the gate
register in the Story room. Titles and hints stay prose.

## 10. Rulings, and what's still open

**Ruled (Luke, 2026-11-09):**
- Chatter can be whatever serves an impression of what's happening; the grammar is a
  vehicle, not a constraint.
- A biome scope's version is the hash of its qubit list (§1).
- Numbers read off the simulated state are measured (§6).
- Collisions happen; language is messy. 🛑 Embargo and 🚧 Sealed stay content.
- Null is ⚫ and creation stays ✨: annihilation and creation live in the world (§7). The
  other verbs take the SpaceWheat set.
- Factions speak their whole vocabulary, which doubles as a hint about whom to pursue
  (§8).
- Chatter appears in the Story room (by standing), B (connected factions) and N (in
  scope), never on the farm.
- Stable biomes ask less, and chaotic biomes ask more.

**Open:**
1. **What should drive line length?** It's motion now (§8). You wanted high dynamic
   range but weren't sure what should drive it. Alternatives: standing (closer friends
   say more), or the speaker's share of the world.
2. **Joint draws for factions.** Faction kets draw each register separately, which
   loses correlations within a biome. They could draw jointly per biome.
3. **Standing per channel.** The Story room weights by `scalar()` (trust − debt +
   access + legitimacy). Should debt or attention make a faction talk *more*?
4. **For Semantica:** pair-form darks (`🐇🦌?`), pole-lean ⚠/🟰 for diagonal readings
   (upstream defines them by Uhlmann fidelity and Bures distance), and the 4-hex SHA-256
   scope tag are all new here and need adopting or amending upstream.

## Not ported

Left out on purpose: the ledger efficiency tiers and the hive LAW gates behind each verb,
the vouch/override grading, the transmission-chain study, and the mixed-state
resonance/tension formulas. They concern the hive's belief ledger, not a game whose
state is exact.
