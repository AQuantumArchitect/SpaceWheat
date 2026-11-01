# SpaceWheat — Game Codex

> **This is the single canonical entry point for understanding SpaceWheat.**
> Read it top to bottom and you will hold the whole game: its thesis, its physics,
> its controls, its loop, and the honest open questions about its elegance and its
> fun. It is written for a fresh reviewer (human or AI) arriving with no context.
> Every claim points at the file that is the authority for it, so you can verify
> rather than trust.
>
> Provenance: written 2026-07-03 after a long deslopification effort — a
> closed-system physics migration, ~15 dead-code purge rounds, a UI/menu re-org,
> and a nine-item UX bug sweep. The codebase you are reading is deliberately
> smaller and more honest than it was; this doc is the synthesis of that work.
>
> Refreshed 2026-08-03 (doc-truth pass, claims re-verified in code): the default
> renderer is now the 3D cognifold field (§5.6); the M surface tab row updated
> (§5.4); the ending's spectral-gap number corrected in §8; and §5.6 now names
> the Witness organ and the cognifold transparency instrument, which post-date
> the original writing. Everything else stands as written.
>
> Refreshed 2026-08-04 (campaign fable push): §8's fun/legibility questions
> carry per-item status — the gap is legible (live glosses, B campaign marker,
> SpectralPreview what-if), the fork is a persistent choice quest, soft-gate
> scores are on the Arc tab, and Q2's premise correction is recorded (planting
> was never a DELIVER side-effect). Acts are announced + ambient (StoryAtlas);
> planting now PRESERVES the biome's state (owner ruling — the tensor
> extension stands; the ground-state reset is gone).

---

## 1. The one-paragraph pitch

SpaceWheat is a **quantum farming game where the story IS the physics**. Each
plot of your island is a real qubit; each biome is a small quantum computer
evolving under its own Hamiltonian. You grow your "signature" — a personal set of
physics axes — by watching qubits ripen and incorporating them, you trade the
rare measurement outcomes for resources, and you compose biomes by choosing which
emoji-atoms to plant in them. The narrative advances not through dialogue trees
but through **thresholds on live quantum observables**: a story beat fires when a
biome's energy spectrum, your signature's growth, or an ecology's diversity crosses
a soft continuous gate. The campaign's ending is a literal spectral-gap condition —
you win a plural, un-collapsible island not by picking "the good option" but by
composing a Hamiltonian that physically cannot fall into a single dominant mode.

---

## 2. The mental model: "story is the physics"

Hold these five ideas and everything else follows.

1. **A biome is a quantum computer.** Each biome owns exactly one density matrix
   `ρ` (pure state, closed system) evolving under a Hamiltonian `H`. Authority:
   `Core/QuantumSubstrate/QuantumComputer.gd`.

2. **Icons are the physics vocabulary (H).** An *icon* is a two-emoji axis
   (a qubit) with self-energies, a Rabi coupling, and cross-couplings to other
   icons. Planting an icon in a biome adds a qubit and its `H` terms. Authority:
   `Core/Factions/data/icons.json` → `Core/QuantumSubstrate/HamiltonianBuilder.gd`.

3. **Factions are loadouts, biomes are scaffolds.** A biome ships bare (a set of
   emojis + visual slots). A *faction* supplies a *signature* (a set of icons)
   that gets *realized* into the biome at runtime, giving it its live physics.
   Authority: `Core/Factions/data/factions.json`,
   `Core/Biomes/data/biomes.json`, `Core/Environment/Components/BiomeQuantumSystemBuilder.gd`.

4. **Story flags fire from soft thresholds on observables, not from scripts.**
   Every narrative beat is a set of predicates over live quantities (spectral gap,
   Var(H), signature growth, atom diversity, berry phase, faction standing),
   combined with a smooth geometric-mean gate. Authority:
   `Core/Quests/data/story_flags.json` + `Core/Quests/QuestManager.gd` +
   `Core/Quests/QuestMath.gd`.

5. **The system is closed and unitary by default.** `ρ` stays pure (`Tr(ρ²) = 1`)
   forever; evolution is the exact propagator `U = exp(−iH·dt)`. The dissipative
   (open / Lindblad) path exists but is **off by default** — it is DLC. Authority:
   `Core/GameMechanics/BalanceConfig.gd` (`physics_switches`), `docs/CLOSED_SYSTEM.md`.

The design consequence of #4 + #5: **the player authors narrative by authoring
physics.** They cannot talk their way to an ending; they build a Hamiltonian whose
spectrum has the shape the ending requires.

---

## 3. Locked vocabulary

These terms are **locked** — use them exactly. The authority is `Core/Documentation/glossary/`.

| Term | Meaning (glossary) |
|------|--------------------|
| **atom** | A single emoji. The smallest named unit of matter. |
| **cloud** | A set of atoms — "everything that touches a thing." (A faction's emoji set.) |
| **icon** | A named two-atom physics record; **provides H** to a neighborhood. (= one qubit axis, `pole_0`/`pole_1`.) |
| **sibling** | The two atoms that share one icon's axis (north & south pole of one qubit). |
| **signature** | **A set of icons.** The icon side of a faction or neighborhood. This is the player's growing "vocabulary of physics." |
| **family** | All atoms reachable by (open-system) Lindblad transfers — the weak-coupling graph. |
| **neighborhood** | A configured `(biome, induced signature)` cluster. **Factions own neighborhoods.** |
| **faction** | A named agent = a signature (icons) + a cloud (atoms) + alignment couplings + standing. The player is one: **The Demos** (`👥🌾`). |
| **webway** | See `Core/Documentation/glossary/webway.md` — inter-node coherent edge concept. |

Traps a fresh reviewer will hit:
- *signature ≠ atoms.* A signature is icons; a cloud is atoms. Do not conflate.
- The faction JSON also has a 12-element `bits` array (a faction-space coordinate);
  that is **not** the game-term "signature." When this doc says "signature," it
  means the set of icons.
- "vocabulary" is a **retired** informal synonym for signature; you may still see
  it in a few comments. Prefer "signature."

---

## 4. Physics: H (icons), L (biomes), closed unitary

### 4.1 The substrate
- One `QuantumComputer` per biome owns a dense `ComplexMatrix` density matrix `ρ`
  and a `RegisterMap` (emoji ↔ qubit index). `Core/QuantumSubstrate/QuantumComputer.gd`.
- Closed evolution is **exact**, not integrated: eigendecompose `H = VΛV†`, build
  `U = V·diag(e^{−iλ·dt})·V†`, apply `ρ ← UρU†`. No Euler drift; purity is
  conserved by geometry. GDScript path in `QuantumComputer.gd`; C++ kernel in
  `native/src/quantum_evolution_engine.h`.

### 4.2 Hamiltonian authority — `icons.json`
Each icon is a qubit axis:
```json
{ "name": "Void", "pole_0": "🕳", "pole_1": "🪐",
  "self_energy_0": 0.35, "self_energy_1": 0.1,
  "rabi_coupling": 0.5,
  "hamiltonian_couplings": { "⚫": [1.1, -0.5], "🌀": 1.1 } }
```
`HamiltonianBuilder.gd` assembles: diagonal self-energies (σz), Rabi (σx, same
qubit), cross-icon couplings (ZZ-like), scales by `hamiltonian_coupling_scale`,
then Hermitianizes `H = (H + H†)/2`. Some icons carry a periodic `driver`
(e.g. the sun/moon Solar axis) that modulates `H`'s diagonal each frame.

### 4.3 Dissipative authority — `biomes.json` (DLC / inert by default)
When `dissipative_dynamics = true`, `LindbladBuilder.gd` reads a biome's
`atom_components` (`lindblad_outgoing/incoming`, `decay`, `gated_lindblad_source`)
and builds jump operators `L_k`. **In the shipped closed mode this returns an
empty operator set** — biomes carry L as *primed, dormant* content. Design
guidance (see memory / `docs/CLOSED_SYSTEM.md`): L should be sparse; ecology
belongs in `H` (icon couplings), not in dense dissipators.

### 4.4 Realization — how the three layers compose
A biome boots as a bare scaffold. When a faction icon is planted:
`expand_quantum_system(north, south)` adds a qubit, looks up that pole-pair in
`icons.json`, loads its `H`, activates any primed `L` whose poles now exist,
rebuilds the operators, and re-grounds `ρ`. Authority:
`Core/Environment/Components/BiomeQuantumSystemBuilder.gd`. A `physics_signature`
(hash of all builder inputs) guards against the C++ twin drifting from the source.

### 4.5 Economy — Boltzmann pricing
Value is surprisal: `E = −kT·log p`, where `p` is a measured outcome's marginal
probability. Rarer collapses pay more. `Core/Markets/EnergyPricing.gd`;
market/contracts in `Core/Markets/MarketLattice.gd`.
- **Caveat worth knowing:** per-biome `kT` is derived from the biome's *von-Neumann
  entropy*, which is ≈0 for a pure closed state — so in the shipped mode `kT` is
  effectively constant (`market_temperature`, default 10). Prices still vary,
  but through the per-emoji marginal `p`, not through temperature. (This is the
  same "closed-state degeneracy" family as several retired predicates; see §8.)

### 4.6 Who mutates state / the C++ twin
The GDScript `QuantumComputer.evolve()` is ground truth. The native
`MultiBiomeLookaheadEngine` (`native/src/`) is a **derived predictor**: it batches
all biomes × lookahead steps across one bridge crossing and returns evolved ρ,
Bloch metrics, purity, and mutual information. It trusts the builders' H/L; a gate
injection invalidates its buffer so it recomputes.

---

## 5. UI: surfaces, archetype frames, QERF

The whole interface is **one keyboard algebra**: `SELECTION × ACTION`. Authority:
`UI/Core/KEYBOARD_GRAMMAR.md`, `Core/GameState/ToolConfig.gd`,
`UI/Core/QuantumInstrumentInput.gd`, `UI/PlayerShell.gd`.

### 5.1 The cursor ring (SELECTION)
A four-layer cylinder; the active layer decides what a letter row selects.

| Layer | Ring | Keys | Selects |
|------:|------|------|---------|
| 0 | surface | `Z X C V B N M` | which overlay |
| 1 | frame | `4 5 6 7 8 9 0` | which archetype hat |
| 2 | biome | `T Y U I O P` | which biome |
| 3 | plot | `G H J K L ;` | which plot/qubit |

`W/S` spin the cylinder (change layer); `A/D` step within a layer; the letter rows
are direct-jump. Cursor-layer ownership lives in `QuantumInstrumentInput`
(`set_cursor_layer`), which runs the plot-ring lifecycle (enter → auto-select
plot 0; leave → clear selection). *(Note: leaving the plot ring clears the live
plot cursor but preserves `last_selected_position`, so single-plot actions fall
back to the last-focused qubit — see the #9 fix in git history.)*

### 5.2 The archetype frames (the hats)
Hat row `4–0` selects a tool; `1/2/3` pick a sub-mode; `Q/E/R/F` are the verbs.
Re-pressing the active hat returns to Ace. No hat = **Ace** (default).

| Key | Hat | Q / E / R / F | Notes |
|----:|-----|---------------|-------|
| 4 | **Spark** ⚡ | pole shift (Lindblad jolt) | **DLC-gated** (hidden in closed mode) |
| 5 | **Icon** 📖 | Trim / Inspect / **Add-or-Incorporate** / **Track** (Berry) | the progression tool |
| 6 | **Merchant** 🤝 | import / price / export / tip | **DLC-gated** (hidden in closed mode) |
| 7 | **Captain** ✳ | Cull / Compass / Add Biome / — | biome lifecycle |
| 8 | **Ace** ○ | Gather (🧺) / Pause / **Strike (measure, 👥)** / Explore (🍞) · Fast-Fwd | player vantage; works in every mode |
| 9 | **Operator** ⚙ | Break / Inspect / Build gate / — | entangling gates |
| 0 | **Druid** V | rot− / **Hadamard** / rot+ / — | single-qubit unitary; `1/2/3` = X/Y/Z axis |

**Closed-mode reality:** because Spark(4) and Merchant(6) are DLC
(`_CLOSED_HIDDEN_FRAMES` in `ToolConfig.gd`), the shipped hat set is effectively
**Icon / Captain / Ace / Operator / Druid**. A reviewer testing on the default
build will find 4 and 6 unavailable — that is intended, not a bug.

### 5.3 The QERF cross (ACTION)
```
            F  (time+: play / advance / flatten)
            |
  Q --------●-------- R   (depth: screw out | screw in)
            |
            E  (time−: pause / inspect / snapshot)
```
- **Q** = gather / withdraw. **R** = invest / commit.
- **E** = pause + inspect. **F** = play + advance (also confirms armed destructive
  actions, and closes submenus).
Meaning is contextual: the active **hat** and **surface** decide what Q/E/R/F do.

### 5.4 Surfaces (the ZXCVBNM ring)
All extend `UI/Core/Surface.gd` and emit one snapshot contract the action bar reads.

| Key | Surface | Tabs / purpose |
|----:|---------|----------------|
| *(base)* | **Farm** | live gameplay: plot grid + biome spindle |
| Z | **EscapeMenu** (system) | Now / Save / New / **Balance** / Dev |
| X | **ControlsOverlay** (playthrough) | Self / Story / · / **Arc** / Guide |
| C | **QuestBoard** | Manifold / Market / Commitments |
| V | **Qubit Atlas** | Lexicon / Affinity / Alignment / Coverage / Hints / Subspace |
| B | **Biome Microscope** | single-plot detail; *transparent overlay* (keys pass through) |
| N | **Inspector** | Network / Bridges / Selector / Live / Whole / Matrix |
| M | **MapMeta** (affinity hypercube) | Vectors / Eigenstate / Drift / Bits / Atlas / Graph |

*(The recent menu re-org moved Arc C→X and Balance X→Z; both kept key `I`.)*

### 5.5 Input path (one decoder)
`PlayerShell._input` peeks side-effects (E/F), forwards ring-nav to
`QuantumInstrumentInput`, and routes to an open overlay or the shell. Otherwise it
falls through to `QuantumInstrumentInput._unhandled_key_input`, the single decoder:
hat / sub-mode / biome / plot / subspace / QERF. A QERF press →
`ToolConfig.get_action(frame, key)` → `ChipResolverRegistry.resolve` (contextual
override, e.g. Icon-R "Add" vs "Incorporate") → `_run_action` →
`QuantumInstrument` → a handler. Destructive verbs arm a confirm and wait for `F`.

### 5.6 Renderer, the Witness, and the transparency instrument

- **The default renderer is the 3D cognifold field.** `scenes/GameRoot.gd`
  (`_field3d_enabled`) mounts `Core/Visualization/QuantumField3D.gd` by default;
  the legacy 2D force graph survives one release behind `--classic-2d` /
  `SW_CLASSIC_2D` (an explicit 2D request wins over an explicit 3D one). Same
  tap contract — a node tap in the field dispatches through `handle_bubble_tap`
  exactly like a 2D bubble tap.
- **The Witness organ** (`Core/Witness/WitnessOrgan.gd`, autoload) is an
  advisory belief field: one small density-matrix cluster per discovered biome
  plus a self cluster, relaxing toward uncertainty and moved only by weak
  observations of player-visible events. Advisory *by law* — nothing gates,
  vetoes, or prices off it; it exists to be projected (today mostly to the rig
  and LLM lanes). Topology and rates live in `witness_spec.json`.
- **The cognifold transparency instrument** — SpaceWheat's renderer doubling as
  a reasoning-transparency lens. `scenes/CognifoldTraceView.tscn` runs
  `Core/Visualization/CognifoldForecastField.gd` (a `QuantumField3D` subclass)
  over an umwelt trace or a live daemon (`SW_COGNIFOLD_URL` /
  `SW_COGNIFOLD_TRACE`); extra channels (gauge, Berry-phase odometer, surprise
  flare) light up only when the trace exposes them, so the shipped game is
  unaffected. The channel legend — every visual channel, its data source, and
  its honesty caveat — is `docs/COGNIFOLD_CHANNELS.md`.

---

## 6. The core loop (minute to minute)

**The immediate verb triad (Ace, on a plot):**
1. **F = Explore / bind** — point a terminal at a qubit; a bubble appears showing
   its icon-pair.
2. **R = Measure (Strike)** — Born-sample the qubit; it collapses to one emoji;
   the probability bar shows how rare that outcome was. Closed mode projects
   (purity stays 1).
3. **Q = Gather (`pop`)** — cash the outcome for resources; reward is the
   surprisal `−kT·log p`, times an **incorporation bonus** if that icon is already
   in your signature (closed mode: ~4× flat).

Verbs live in `Core/Actions/ProbeActions.gd`; rewards route through
`Core/Markets/EnergyPricing.gd`.

**The progression verb (Icon hat):** the only way your *signature* grows.
- **F = Track** a qubit: under the live `H` it accumulates Berry phase (solid
  angle) until it **ripens** (phase → 2π). Berry phase is the game's XP;
  `Core/Documentation/glossary/berry.md`.
- **R = Incorporate** a ripe qubit: adds its icon to your signature via
  `farm.discover_icon(north, south)` — *not* a biome injection. Signature grows →
  `signature_growth` predicate rises → story flags fire. (On an *empty* plot, Icon-R
  instead injects a new icon into the biome — that is how you compose a biome.)

**Time:** `Reap` fast-forwards biome evolution (coherences build, populations
shift) and mass-measures for a seasonal payout. Story counters advance on real
harvests, not on Reap.

**Trade:** the **QuestBoard/Market** offers contracts priced off a biome's live
marginals; a biome must have a live `QuantumComputer` (and a neighborhood anchor
faction) to make offers. **Resources come from the market; icons come from
incorporation** — do not confuse the two economies.

**Ambient life:** six faction *socialites* speak by **measuring** a biome they are
native to and emitting the outcome emojis. Cadence and biome-choice are now driven
by the biome's measurement-distribution entropy ("liveliness") — a settled biome
is quiet, a biome in rich superposition babbles. `Core/Story/SocialiteCluster.gd`,
`Core/Story/BiomeMeasurementSampler.gd`.

**The loop closes:** measure/harvest → track/ripen → incorporate → signature grows
→ story beats fire → new quests + standings → compose biomes (plant atoms) →
biome Hamiltonians change → spectral observables move → the ending condition
becomes reachable.

---

## 7. The campaign, and the fun thesis

### 7.1 Story-as-physics, mechanically
`QuestManager` evaluates every unfired flag each physics frame. Each predicate is a
**soft gate** `0.5·(1 + tanh((x − center)/width))`; a flag's predicates combine via
`smooth_and` (geometric mean) and fire at score ≥ **0.85**. The progress you see in
the Arc tab *is* that score, rising continuously — there is no boolean "ding."
Predicate families (`QuestManager.gd`):
- **Actions:** `berry_consumed_count_gte`, `berry_total_phase_gte`,
  `signature_size_gte`, `signature_growth_gte`.
- **Composition/ecology:** `atom_in_biome`, `atom_count_gte`, `atom_diversity_gte`.
- **Quantum observables (composition-intrinsic):** `biome_spectral_gap_gte/_lte`
  (the `H`'s own gap `E₁−E₀` — wide = one rigid attractor, small = many competing
  modes), `biome_energy_variance_gte/_lte` (Var(H), state restlessness).
- **Reputation:** `standing_gte` (6 channels: trust/debt/attention/access/
  legitimacy/entanglement).

### 7.2 The arc (The Demos playthrough, `story_flags.json`)
Reordered 2026-08-17 (`docs/CAMPAIGN_REORDER_2026-08-17.md`): the early game
teaches only enough physics to play — farm verbs and contracts — and raises
the bar per act; every beat also carries a `campaign` tag (the split's
phase-0 partition, `tests/test_campaign_partition.py`).
- **Act 0 — tutorial** (`tutorial_arc.json`): the instant verbs only — the
  explore/strike/gather loop, reap, the contract ceremony, wayfinding (the
  first crossing), superposition, entanglement. No berry ritual here.
- **Acts 1–2 — teachings-first:** kept contracts raise standing; factions teach
  their words at trust (the claim IS the teaching); planting taught words
  couples the countries (Woodlot 🪵, Spring 💧) and the Mill's `⚙` attractor
  forms. Reputation raises market pay (⭐, `quest_rewards.standing_reward_*`).
- **Act 3 — What the Land Remembers:** the berry chapter (`first_breath` + the
  forest staircase): Berry-tracking, incorporation, the first invariant — and
  the **×4 harvest bonus**, which rides `farm.incorporated_icons` (the ritual's
  ledger), never mere teaching.
- **Act 4 — the hub:** all biomes coupled (`island_lives`); `village_identity`
  ("A Character") gates on Village at its 12-atom cap + island diversity + the
  full 15-word island vocabulary; `five_doors` names the five path keys and the
  dark teachers (`eagle_overhead` 🩸/🦅, `serfs_ledger` 💸/💀) open their claims.
- **Act 5 — divergent identity:** which **single atom** you built into the Village
  forks the story — 💧 Commons / 🏭 Manufactory / 🔨 Artisan / 🦅 Watched / 💀 Cemetery.
  Every key has a story teacher; the paths themselves pay standing only.
- **Act 6 — the ending:** the empire (`BloodLedger`) locks a **wide** spectral gap
  (`empire_imposes`); you win **`island_free`** iff `Village` spectral gap stays
  **≤ 0.55** (many coexisting modes), with atom diversity ≥ 18 and signature ≥ 14.
  *You win by composing a biome that physically cannot collapse into one shape.*

### 7.3 What the design claims is elegant
- One keyboard algebra spans ~40 verbs; muscle memory transfers across tools.
- One physics law (`E = −kT·log p`) prices all scarcity.
- One narrative mechanism (soft gates over observables) drives every beat.
- The ending is **agency through composition**: the win condition is a conserved
  property of the Hamiltonian *you* authored, not a flag a designer set.
- Faction chatter is not flavor text — it is literally a measurement of the state.

---

## 8. Open questions for a fresh reviewer (elegance & fun)

The game is **mechanically sound but narratively quiet**. A reviewer who plays with
the Arc tab open, reads biome detail, and tries to win the ending *deliberately*
will see "story is the physics." A reviewer who just clicks will find Acts 1–3
engaging and Acts 4–5 grindy. The most valuable fresh perspective would probe:

**Fun / legibility** *(status refreshed after the 2026-08-04 fable push — see
`docs/CAMPAIGN_STATE_2026-08-04.md`'s addendum for the change list)*
1. **Does the loop scale?** R/E/Q is crisp with 1–2 biomes; by Act 5 there are ~6
   and it turns repetitive. *Partially addressed:* the per-biome `−`/`=` clock
   dial is now taught at first berry-track, and tracked plots show a ripening
   ETA — waiting is legible. Deliberately NOT auto-paced (an untested heuristic
   would be silent hindrance). Still open: whether a macro affordance is wanted.
2. **Is composition felt?** *(The premise here was wrong — planting was never a
   DELIVER side-effect; it has always been the deliberate Icon-hat (5) R verb.
   DELIVER quests teach icons; a learned icon is then planted separately.)*
   *Addressed:* the picker now shows the slot budget ("Village: 4/6 axes"),
   "+N new atoms" per candidate, and the what-if gap ("0.61→0.54 ▼"); the
   Act-5 fork is a persistent "choose one door" quest (`five_doors`).
3. **Is the spectral gap a black box?** *Addressed (owner ruling: full what-if):*
   gap glosses show live now→target, the B microscope carries a campaign-target
   marker row + bar tick, and the icon picker / trim confirm preview the gap a
   composition WOULD produce (`SpectralPreview`, proven bit-identical to live).
4. **Are the soft gates too invisible?** *Largely addressed:* the Arc tab shows
   per-flag `x/0.85` score bars + per-predicate breakdowns with real fire
   points; glosses carry live have/target values (berries, atoms, standing, gap).
5. **Is the chatter readable or noise?** Still open. It carries real state but
   scrolls by (emoji streams, 32-entry ring, no history surface). A different
   push's question.

**Elegance / architecture**
6. **Standing feeds `PriceModel`.** The six channels are not cosmetic: they
   move prices. They are not a closed-campaign win condition. Say that, don't
   say "inert."
7. **The story graph is dormant** — socialites walk it but its density rarely feeds
   back into gameplay. Cut it, or activate it (couple standing ↔ topic density)?
8. **Closed-state degeneracies** — several natural observables (von-Neumann entropy,
   purity, and therefore market `kT`) are constant for a pure state. The campaign
   already retired degenerate predicates in favor of spectral gap / Var(H); is any
   residual degeneracy (e.g. constant market temperature) worth addressing?
9. **One evolution path.** The GDScript integrator was deleted. Native
   `MultiBiomeLookaheadEngine` is the only evolver; BootManager refuses to boot
   without it. `physics_signature` is the drift check between live H/L and the
   C++ copy, not a dual-kernel proof.
10. **The open-system DLC** adds a large conditional surface (Lindblad, drain,
    Spark/Merchant hats) that is off by default and less tested. Keep it primed, or
    is it dead weight on comprehension?

*(Raw material for these: the four internal comprehension maps this codex was
built from; the loop/UI/physics agents' honest reads are distilled here.)*

---

## 9. Repo map, build & run

**Authority data (source of truth for physics/story):**
- `Core/Factions/data/icons.json` — H (icon axes) · `axes.json` — 12-axis space
- `Core/Biomes/data/biomes.json` — biome scaffolds + L (dormant)
- `Core/Factions/data/factions.json` — faction signatures/clouds/standing
- `Core/Quests/data/story_flags.json` — the campaign · `tutorial_arc.json` — Act 0
- `Core/GameMechanics/BalanceConfig.gd` — physics switches + tuning knobs

**Code shape:** `Core/` (166 files, ~55k LOC) = engine/logic; `UI/` (52 files,
~26k LOC) = thin key-in / projection-out surfaces; `native/` = C++ derived
predictor; `scenes/Main.tscn` = entry scene.

**Run / build / test:**
- Play (Linux headed): `./launch_game.sh`  ·  editor: `./editor_launch.sh`
- Headless rig (LLM/automation lane): `🍄/🎛️/🟢.sh`; harness docs in `🍄/README.txt`
- Python tests: `python3 -m pytest tests/ -q` (rig-driven + source-contract)
- GDScript smoke tests: `godot --headless --path . --script tests/<name>_smoke.gd`
- Boot-error gate: `godot --headless --audio-driver Dummy --path . --quit 2>&1 |
  grep -cE "SCRIPT ERROR|Parse Error|ERROR: Failed to"` must print `0`
- Build/deploy: `docs/release/DESKTOP_RELEASE_WORKFLOW.md`, `BUILDING.md`

---

## 10. Canonical docs (what to read next, by concern)

The following are the surviving canonical references (this codex supersedes the
sprawl that was pruned alongside it — see the same commit).

- **Controls:** `UI/Core/KEYBOARD_GRAMMAR.md`, `UI/Core/SURFACE_MANIFEST.md`
- **Archetypes:** `docs/ARCHETYPE_FRAMES.md`, `docs/CHARACTER_ARCHETYPES.md`
- **Physics:** `docs/CLOSED_SYSTEM.md`, `docs/FOR_PHYSICISTS.md`
- **Campaign status snapshot:** `docs/CAMPAIGN_STATE_2026-08-04.md` — act-by-act
  flag map, biome ship-status, known-issues ledger, test-coverage verdict
  (a fable-push briefing; re-verify before trusting if stale).
- **Narrative content:** `docs/biomemissions/` (biome arcs — open-DLC scope;
  see each file's banner), `docs/QUEST_SYSTEM_PLAN.md`
  (The December-2025 `reference/` and `architecture/` docs were archived
  2026-07-11 — see `docs/DOC_ROT_2026-07-11.md`; they predate the
  closed-system migration and the hat/QERF grammar.)
- **Vocabulary:** `Core/Documentation/glossary/`
- **Player-facing:** `docs/HOW_TO_PLAY.md`
- **Build/ops:** `BUILDING.md`, `docs/EXPORT_HEALTH.md`,
  `docs/release/DESKTOP_RELEASE_WORKFLOW.md`, `docs/performance/`
- **Agent onboarding:** `BIOME_AGENTS.md`, `🍄/README.txt`
