# Campaign State — 2026-08-04 (Fable-Push Briefing)

> **Historical.** Content snapshot from 2026-08-04. Flag counts and act maps
> have moved since. Re-read `Core/Quests/data/story_flags.json` and
> `docs/GAUGE_CAMPAIGN.md` before acting. Canon: `docs/GAME_CODEX.md`.

> **Purpose:** a breadcrumb trail for a "fable push" on the whole campaign
> experience and gameplay loop, so that session doesn't have to re-read
> `story_flags.json`, `tutorial_arc.json`, all of `docs/biomemissions/`, and
> two dozen past-session memory files from scratch. This doc is a **content +
> status snapshot**, not architecture — pair it with `docs/GAME_CODEX.md`
> (the physics/UI/loop reference, which this doc does not repeat).
>
> Built 2026-08-04 via 4 parallel research passes (full-file reads of
> `story_flags.json`, `tutorial_arc.json`, all of `docs/biomemissions/`,
> ~20 memory files, and the test tree). Every claim below is grep/read-level
> verified against the repo at that commit, not inferred. Treat it as a
> snapshot — re-verify anything load-bearing before acting on it if much time
> has passed.

---

## 1. Act-by-act flag map

### Act 0 — `Core/Quests/data/tutorial_arc.json` (linear, `chain_unlocks`)

| Step | Teaches | Hat/verb | Gate |
|---|---|---|---|
| 0 | core_loop | Ace(8): F explore/R strike/Q extract | `gate_sequence_contains{measure,1}` |
| 1 | vocabulary | Icon(5): F track→ripen→R incorporate | `signature_size_gte 3` |
| 2 | reap_season | Ace(8): Shift+F reap | `gate_sequence_contains{reap,1}` |
| 3 | superposition | Druid(0): E Hadamard | `coherence_at_least 0.3`; unlocks `forest_listener` |
| 4 | entanglement | Operator(9): Shift+2 select, R check, Q weave Bell | `gate_sequence_contains{bell,1}` |
| 5 | contracts | DELIVERY 2×🌾 via Ace, claim on Commitments (C→U) | manual accept→claim, no state_predicates — the one non-auto-advancing step |
| 6 | vocab_escape | grow signature 4+ in Village | `signature_size_gte 4`; branches Hearth Keepers vs Millwright's Union on `standing_gte(faction,trust,0.15)`, must clear 0.5 |

### Acts 1–8 — `Core/Quests/data/story_flags.json` (57 flags total)

Format: `id — display_name — predicates — one-clause gist — standing_grants — quest gist`

**Act 1**
- `first_breath` — First Breath — `signature_growth_gte 0.5±0.4` — first icon incorporated in StarterForest — {} — track+ripen+incorporate one word
- `forest_evolving` — pred: `biome_evolving(StarterForest)` + `berry_consumed_count_gte(StarterForest,1)` — HK trust+0.05
- `forest_listener` — 3 signatures — HK trust+0.08
- `forest_communion` — 5 signatures + wide-swing phase (`berry_total_phase_gte 12.566`) — HK trust+0.12/legit+0.05
- `loop_remembers` (What Survives I) — 7 signatures, invariant = loop shape survives — HK trust+0.05
- `village_stirs` — Village evolving + 1 berry — MW trust+0.04 — teaches Mill's 💨/🔨 at 3 berries

**Act 2** (two parallel upstream lanes: Woodlot/Millwright, Spring/Hearth Keepers)
- `new_voices` — plant OR harvest grows signature
- `woodlot_door` → `woodlot_contact` → `lumber_flows` (teaches 🪵/🪓) → `woodlot_wakes` (DELIVER 🪵 into Village) → `timber_rhythm` (teaches 🏭/⚙)
- `spring_door` → `spring_contact` → `spring_connects` (teaches 💧/🌊) → `spring_wakes` (DELIVER 💧 into Village) → `pond_depths` (What Survives II: eigenvalues never move) → `pond_breathes`

**Act 3**
- `mill_wakes` — 5-way gate (💨≥0.12, ⚙≥0.05, 2 berries, attractor≥0.35) — Commerce bistability flips — MW trust+0.12, Granary trust+0.08
- `mill_master` — 8 berries + wide phase — **`arc_quest: null`, pure milestone**
- `lantern_door` → `chain_ends` (What Survives III: topological zero-mode is integer) → `lantern_teaching` (teaches 🌉/🪔) → `lantern_wakes` (DELIVER 🌉) → `chain_flipped`

**Act 4** (the hub)
- `island_lives` — 3 upstream flags + 🪵 planted — non-actionable quest (fires the instant its own predicate does)
- `village_identity` — `atom_count_gte(Village,12)` + `atom_diversity_gte(26)` + `signature_size_gte(15)` — flavor-text varies by which atom is present (`conditional_beat`)
- `five_doors` — announces 💧🔨🏭🦅💀 — **flavor-only, not a real gate** (see Anomalies)
- `eagle_overhead` (teaches 🩸/🦅), `serfs_ledger` (teaches 💸/💀) — both gate on `village_identity`
- `island_stops_asking` — purity climbs past 0.5
- `braid_order`/`braid_word` (What Survives IV) — gate-order + MI≥1.0

**Act 5** — three parallel lanes
- Empire spine: `ledger_opens` (BloodLedger spectral gap ≥0.6) → `edge_of_the_enclave` (signature≥16)
- What Connects I/II: `second_loop` → `the_knot`
- **The branch fork** (see §2 below): `village_path_commons/industrial/artisan/watched/cemetery`

**Act 6** — three lanes
- What Fades I/II: `the_crossing` → `the_gray` (quest completed by **losing** coherence) → `watching_keeps`
- Ending spine: `empire_imposes` (Carrion Throne debt+0.2/legit−0.1, only negative grant in the corpus) → **`island_free`** (`biome_spectral_gap_lte(Village,0.55)` + diversity≥18 + signature≥14)
- What Connects III: `the_span` — gates on `the_crossing`, **not** `the_knot** (see Anomalies)

**Act 7** — two lanes
- What Fades III/IV: `the_verbs_come_home` (unlocks Spark/Merchant hats) → `the_first_contract` → `the_basin` → `the_chain_tested` (flips Lanternfall `regime_changes` to open) → `hiding_in_the_light`
- What Connects IV/V: `braid_alphabet` → `the_fusion`

**Act 8** — convergence
- `the_rite` (What Fades V) → `the_door_stays_open` — **only flag with `physics_changes`**: sets `dissipative_dynamics: true` (opens 64 open biomes; island stays closed by choice)

Full per-flag predicate/reward detail (verbatim-ish) is in the research transcript this doc was built from — re-derive from `Core/Quests/data/story_flags.json` directly if you need more than the gist above; the file is only 2108 lines and well-structured.

---

## 2. Act 5 branch fork (the one real narrative choice)

All 5 `village_path_*` flags require `village_identity` + one atom seated in the Village register. Non-exclusive — multiple can fire in one run.

| Flag | Extra prereq | Atom | Faction tilt | `VILLAGE_STORY_PATHS.md` origin |
|---|---|---|---|---|
| `village_path_commons` | none | 💧 | Hearth Keepers | Path A "The Water Mill" |
| `village_path_industrial` | `timber_rhythm` | 🏭 | Millwright + Void Serfs (darkest) | Path B "The Factory" |
| `village_path_artisan` | none | 🔨 | Granary + Millwright | Path C "The Artisan Guild" |
| `village_path_watched` | `eagle_overhead` | 🦅 | Carrion Throne | Path K "Under the Eagle" |
| `village_path_cemetery` | `serfs_ledger` | 💀 | Void Serfs | Path D/O (doc doesn't disambiguate which) |

`industrial`/`watched`/`cemetery` need an extra teaching-flag prereq the other two don't. **No in-game hint currently points at "plant this atom to fork this way"** — this is the entire narrative payoff of the mid-game and it's undiscoverable except by accident (see §4).

`VILLAGE_STORY_PATHS.md` catalogs 17 candidate paths (A–Q); only these 5 shipped. Path I ("Timber Village," 🪵|🌾, the doc's own recommended default) never shipped — live Village data still shows only the original 8 emojis.

---

## 3. Biome ship-status (live vs. DLC-dormant)

Every `docs/biomemissions/*.md` file carries an identical "DLC/wet-country only" banner. What that means per-biome, cross-checked against `Core/Biomes/data/biomes.json` and `story_flags.json`:

| Biome | Doc's physics content | Ship status |
|---|---|---|
| StarterForest 🌲 | sun-pump toggle, bistable food chain, night-cycle | **DLC-dormant physics**; biome *name/state* is live (Acts 0-1 gate on it) |
| Village 🏘️ | Commerce X-gate flip, autocatalytic pumps, "Dormant Gizmos" table | **DLC-dormant physics**; biome is the live hub for Acts 1,3-5. Dormant-Gizmos table is design provenance for the 5 fork atoms that DID ship |
| Woodlot 🪓 | 6-atom production cycle, axe-pump tuning | DLC-dormant; `lumber_flows` reads generic "evolving" state only |
| FreshwaterSpring 💧 | source-hub flow to 4 downstream biomes, Irrigation Jury | DLC-dormant; `spring_connects` reads generic state only |
| FungalNetworks 🍄 | AND-gate bloom, moisture latch | DLC-dormant **and off the default starter-island map** (doubly inert) |
| PastoralCommons 🐑 | Lotka-Volterra predation | DLC-dormant, not in live flag table |
| BioticFlux ☀️🌙 | zero-Lindblad teaching biome | DLC-dormant; **its whole premise (unitary=special) may be overtaken by the closed-system migration**, since the entire shipped game is now unitary-only |
| BloodLedger 📜⚜ | autocatalytic 📜→⚜ loop | DLC-dormant physics; biome *state* gates the live Act 5-6 ending (`ledger_opens`/`empire_imposes`/`island_free`) |

All 8 biome ids are real (`biomes.json`), no phantom references either direction.

---

## 4. Known issues — confirmed fixed (do not re-investigate)

Grouped loosely; full detail + memory-file source in the research transcript. Headline items:
- Boot-race/silent-toast family: false first-boot story toast, story-offer toasts always importance-1 (dead `is_arc`/`from_story_flag` check), lying incorporate toast, F-eaten-by-hint-toast confirm bug, disabled-submenu silent fire, E-pauses-time-under-submenu — **all fixed**, but see the recurring-pattern note below.
- Physics-blocking: whole-campaign H≡0 (poisoned cache), Berry-phase register never wired, Ace Extract reward computed from post-collapse probability (~1 always), full-size bubbles stuck at MIN_RADIUS — **all fixed**.
- Economy/gates: `village_identity`'s unsatisfiable atom-count-12 (reframed), market-neighborhood oscillation, quest/contract state evaporating on save/load, trim-then-replant false capacity block, IconCard duplicate-emoji mislabeling, action_remove_icon defaulting to wrong qubit — **all fixed**.
- Menu/onboarding: Act-0 verb funnel, menu-ring shrink (C locked to step 5, Z's New/Balance/Dev locked to Act-0-complete), ObjectiveSpotlight visual pulse — **all fixed** (this session's prior work, [[project_arc0_spotlight_pass_2026-08-04]]).

---

## 5. Known issues — still open (candidate fable-push targets)

Ranked roughly by leverage, not by memory-file order:

1. **Masher persona has never been re-tested against the menu-ring shrink.** The shrink (arc0_spotlight pass) was built specifically to fix masher-viability, but even the fresh-boot *baseline* number is unmeasured (the one prior report may have resumed from a checkpoint). **Cheapest, highest-value first move for any fable push** — get a real before/after number before doing anything else.
2. **Structural silent-refusal bug family.** 5+ independent fixes across sessions all violated the same anti-gating law in different code paths. Worth a single confirm/refusal-toast authority instead of continuing whack-a-mole.
3. **`village_path_*` branch fork is undiscoverable.** No in-game hint points at "plant this atom into the Village to choose this path" — the game's one real narrative choice is effectively hidden. `industrial`/`watched`/`cemetery` additionally require a teaching-flag prereq the player has no reason to know about.
4. **Fractal descent has zero keyboard entry point** — only reachable via 3D mouse-click, which headless mode can't build and `player_seat.py` can't drive. The recent v7 cost/gate work (First-arc polish, Part B) has never been live-verified by an agent actually playing it.
5. **EscapeMenu Save-tab R (save)/Q (load) fire with zero confirmation** — same family as #2, explicitly flagged not fixed. `UI/Overlays/EscapeMenu.gd` `Tab.KEEP` handlers.
6. **GAME_CODEX §8's 5 fun/legibility questions, none resolved:** does R/E/Q scale past 2 biomes (Act 5 has ~6)? Is composition (planting an atom, which forks Act 5) felt as deliberate rather than a DELIVER-quest side-effect? Is the Village spectral gap a black box (nothing teaches "🏭 widens it, 💧 narrows it")? Are soft gates too invisible (quests say "3 berries," fire at ~3.5)? Is faction chatter readable or scrolling noise? — **these are literally "the whole campaign experience and gameplay loop"** in the terms the user asked about; read `docs/GAME_CODEX.md` §8 directly for the full framing.
7. **Berry-ripening rate varies ~20× between registers with zero on-screen signal of which is faster.**
8. **Campaign-layer test coverage has no runtime pass/fail gate.** `act3_5_drive.py` (the closest thing to a full end-to-end campaign play) is diagnostic-only (zero asserts, not in CI). `test_story_flags_lint.py`/`test_scenario_pool_covers_campaign.py` give strong static coverage; only Acts 0-1 + save/load have real behavioral pytest assertions. A fable push that wants to verify its own campaign-content changes cheaply should either wire `act3_5_drive.py` into a real assert-based gate or lean on the `hive.py leg` checkpoint-sweep pattern.
9. **Doc-rot, cheap fixes:** `STARTER_ISLAND_STORY_FLAGS.md`'s flag table lists 11 flags, live JSON has 57 (self-aware footer says live JSON wins, but the gap is large); the DLC-only banner is misapplied to that same file (its content is actually live closed-system reference, not DLC); `VILLAGE_STORY_PATHS.md` never maps its Path-letter names to the shipped fork names (💧 Commons etc.) — no doc states the mapping (§2 above is the first place it's written down).
10. **`five_doors` flag doesn't actually gate anything** — none of the 5 branch flags check it; it's flavor-only despite reading as a structural gate. Confirm intentional or wire it in.
11. ~~**`the_span` (Act 6) gates on `the_crossing` rather than `the_knot`**~~ — **correction, 2026-08-16: not current.** Live `Core/Quests/data/story_flags.json` has `the_span`'s predicates requiring `the_crossing` **and** `the_knot` **and** `bridge_built_gte 1` — What Connects' own continuity (`the_knot`) is already required, alongside the cross-lane `the_crossing` gate this item flagged. Whether that cross-lane coupling to What Fades is still worth a design confirm is open, but the specific "breaks internal continuity" claim no longer holds against the live data.
12. **Standing keeps getting re-flagged as "inert" across multiple passes** even though it does feed `PriceModel` pricing — an intentional owner-accepted half-state that keeps resurfacing as a question purely because nothing documents the ambiguity is deliberate. One-line doc fix, not a code fix.

---

## 6. Recurring patterns (fix the pattern, not just the instance)

- **Post-load state loss is a bug family.** Quest ledger, berry credit, teaching-offer regeneration, `realization_debug` empty emojis, biome-switch-after-load — distinct bugs, same root shape. Treat "load a mid-campaign save and re-verify everything" as a standing test category.
- **Silent-refusal/silent-toast bugs recur across unrelated subsystems** (see §5.2) — same anti-gating-law violation, independently reintroduced each time. A single authority would close this permanently.
- **Masher/button-mash viability measured repeatedly with no clean trend line** (§5.1) — the single cheapest, most-repeated loose thread.
- **Fleet doctrine (sonnet-mains-the-road, haiku-proves-each-leg, `🍄/🧪/player_seat.py` + `PERSONAS.md`) is well-established and finds real bugs cheaply** — default to reusing it rather than re-deriving a testing approach.

---

## 7. Anomalies worth a design confirm (not necessarily bugs)

- `mill_master` (Act 3) has `arc_quest: null` — pure milestone, no player-facing quest. Confirm intentional.
- `island_lives`/`empire_imposes` have arc_quests whose `state_predicates` exactly duplicate the flag's own firing predicate — non-actionable busywork quests that complete the instant the flag fires.
- Two bare predicate-type families are fully wired in `QuestManager.gd`/`QuestMath.gd` but used by **zero** story flags: the un-prefixed `purity_at_least`/`entropy_at_most`/`frozen_loops_gte`/etc. (superseded by `biome_`-prefixed siblings) and `biome_energy_variance_gte/_lte`/`biome_purity_trending` (comment confirms: "kept for the open DLC, not on the spine"). Not bugs, just unused-by-design vocabulary — useful to know before assuming a predicate type is dead versus intentionally reserved.
- Village's `atom_count_gte(Village,12)` threshold vs. live Village data showing only 8 emojis — likely scopes over something other than the local emoji list (island-wide?), not confirmed which.

---

## 8. Where to look next (pointers, not re-reads)

- Architecture/physics/UI/loop: `docs/GAME_CODEX.md` (this doc's companion, don't duplicate).
- Full flag detail beyond the gists above: `Core/Quests/data/story_flags.json` (2108 lines, well-structured, read directly).
- Branch/fork narrative detail: `docs/biomemissions/VILLAGE_STORY_PATHS.md` (564 lines) — remember it uses Path-letter names, not the shipped fork names; §2 above has the mapping.
- Test/verification shape: `🍄/🧪/hive/P7_SWEEP_PLAN.md` (the chapter-leg-sweep protocol), `🍄/🧪/act3_5_drive.py` (closest thing to a full campaign play, diagnostic-only), `PERSONAS.md` (the persona-swarm doctrine).
- This session's most recent shipped work: `[[project_arc0_spotlight_pass_2026-08-04]]` and `[[project_first_arc_polish_2026-08-04]]` in memory — both are prerequisite context for items 1 and 4 above.

---

## 9. ADDENDUM — the fable push executed same-day (2026-08-04, local commits)

The push this doc briefed ran the same day. Status of §5's ranked list:

1. **Masher baseline: MEASURED.** Fresh-boot, 3 seeds × 100 presses via a rig
   lane reading `dispatch_ledger`: productive-dispatch rate mean **0.007**
   (range 0.000–0.020). The funnel is masher-safe but still not
   masher-productive. NEW FINDING: seed 47 drove the game unresponsive at
   press ~57 (heartbeat stale, 16s+/turn after) — deterministically
   reproducible (`random.Random(47)` over the seat key set); suspect the
   `−`/`=` stride dial compounding. Un-diagnosed, filed for follow-up.
2. **Silent-refusal family: STRUCTURAL FIX.** `UI/Core/RefusalVoice.gd` is the
   one voice for the guard band (per-message dedupe, two shapes); ~10 cataloged
   silent sites covered; OverlayBase keyboard-F takes the chip-honesty gate.
3. **Fork discoverability: FIXED (owner ruling: full signpost).** `five_doors`
   is a persistent "choose one door" quest (new `story_flag_any` predicate),
   its body lists all five doors + prereqs, `atom_in_biome` glosses teach the
   plant verb, the picker shows the Village slot budget + "+N new atoms".
4. **Fractal descent keyboard entry: NOT TOUCHED** (still mouse-only).
5. **KEEP-tab R/Q: FIXED.** SAVE_OVERWRITE/LOAD_DISCARD confirms via the
   existing scaffolding; load deactivates only after success; empty/
   incompatible slots speak.
6. **GAME_CODEX §8: 4 of 5 addressed** (see the codex's per-item status);
   chatter (Q5) deliberately left for a future push.
7. **Berry rate: VISIBLE.** Tracked plots show a ripening ETA ("~40s" / "∅");
   an un-ripenable axis (no transverse H term) warns at track time.
8. **Campaign test gate: BUILT.** `tests/test_campaign_checkpoints.py` asserts
   the minted spine checkpoints load + all banked flags survive, plus a
   `fire_flag` consequence test. Green in ~45s.
9. **Doc-rot:** GAME_CODEX refreshed; this addendum. STARTER_ISLAND banner
   fix still owed.
10. **`five_doors`: WIRED** (see 3).
11. **`the_span` lane continuity: superseded, 2026-08-16** — see the correction on item 11 in §5; the live predicate already requires `the_knot`, so there's no continuity break to confirm design intent on anymore.
12. **Standing doc note: NOT TOUCHED.**

Beyond the list, the push's largest finds (none were in this doc's §5):
- **The acts-4-8 blackout** — `objective_text()`/`objective_target_key()`
  early-returned "" once `island_lives` (act 4!) fired; banner + spotlight
  were dark for half the campaign. Deleted; smoke-pinned.
- **Acts are now felt**: `Core/Story/StoryAtlas.gd` (contiguous-prefix current
  act, any-one-of branch groups, lane parsing) drives an act-entry toast, an
  ambient "Act N · Chapter" line on the banner, honest act postcards (act 5
  was unreachable), a de-inflated chapter header, and Arc-tab lane tags +
  A/D paging over all 57 flags.
- **Arc hints survive acceptance** (QuestBoard read only `tutorial_hint`; all
  56 arc quests author `hint`) and beat toasts cut at sentence boundaries
  (was `.left(80)` mid-word).
- **Reap was corrupting Berry phase** (projective collapse without reseed —
  fake solid angle every Shift+F). The collapse→reseed law now lives at the
  one authority (`QuantumComputer._project_qubit`), probe-pinned.
- **A gap-solver failure satisfied the win condition** (returned 0.0, and
  0.0 ≤ 0.55). Failure sentinel −1.0; failure is never satisfaction.
- **Planting preserves state** (owner ruling E1): the ground-state reset on
  every plant is gone; the already-computed tensor extension stands; only the
  new qubit gets the dawn kick. Probe-pinned (marginal continuity, purity,
  Berry-walk survival).

---

## 10. ADDENDUM — publishability sweep (2026-08-10)

Closing two items this doc left open, and correcting one.

**§9.1's seed-47 hang: NOT REPRODUCIBLE — hypothesis refuted.** The recorded
suspicion was "the −/= stride dial compounding." Tested directly rather than
by replay: every dial pinned to its worst corner *simultaneously* —
`max_evolution_dt` driven to its 1e-4 floor (Shift+− ×12), `observation_stride`
to 256 and `quantum_time_scale` to 16 (`=` ×12) — then 20 ordinary gameplay
presses. Result: **0/20 slow presses, all ≈0.2s**, and `dispatch_ledger` /
`grid_snapshot` both answered in under 0.15s. A separate 90-press random-key
run over the full seat key set produced zero turns above 1.0s. The dials are
individually clamped and their product is not expensive, because stride only
skips a precomputed buffer cursor and a finer dt does not add substeps per
phrame — it shortens the sim-time each buffered slice covers. **Caveat:** the
original masher script was never committed, so the exact `random.Random(47)`
draw sequence could not be replayed bit-for-bit; this is a behavioural
refutation of the mechanism, not of the observation. If it resurfaces, commit
the probe first.

**§9.4's fractal-descent keyboard entry: FIXED.** `]` descends into the focused
register's icon world, `Shift+]` ascends. Both route through the same
`QuantumInstrument.action_enter_icon` / `action_ascend_fractal` the 3D portal
satellites call, so cost, incorporation gate and depth cap stay one authority,
and server-side refusals speak through `RefusalVoice` rather than no-opping.
The key was claimed from `KEYBOARD_GRAMMAR.md`'s reserved set, per that doc's
own rule.

**New find, not in §5 — 337.8 MB of dead art shipped in every build.**
`BiomeBackground.LEGACY_PHOTO_MODE` is a `false` const, so `_apply_zone` never
builds its `TextureRect` branch, so `_get_biome_texture` is unreachable and no
`Assets/Biomes/**.png` loads at runtime (`biomes.json`'s `image_path` fields
are dead data on this path too). With `export_filter="all_resources"` those
imports were 337.8 MB of the shipped `.pck` — about two-thirds of all imported
resources. All three presets now exclude `Assets/Biomes/**`; the art stays in
the repo. Re-enabling `LEGACY_PHOTO_MODE` means removing that exclusion first.
