# Core Sweep — 2026-06-17 (overnight)

A 6-subsystem audit of `Core/` (Visualization deliberately skipped — owner flagged it as
load-bearing for force-graph interpolation → batcher → rasterization). Every agent finding
below was **re-verified by hand** (grep across `Core/ UI/ Rig/ scenes/ tests/ tools/` incl.
preload-by-path, autoloads, `.tscn`, and string/`has_method` calls) — agents were wrong often
(two "dead files" were live; "phrame" was flagged as a typo when it's project vocabulary).

## ✅ Already done this pass (committed)
- Emoji fix: `🌊_evap`→`🌫`, `🩸` declared in BureaucraticAbyss (`10b8612`).
- Removed 5 dead vestigial methods from `QuantumNode` (`13473d9`).
- Deleted dead `DensityMatrix.gd` (346 LOC) + `BiomeUtilities.create_qubit/format_debug_info`
  + `QuestRewards._compute_total_resource_budget` & its 3 orphaned helpers (`173e386`).
- Removed Farm.gd's 5 dead economy-facade helpers (`730bbeb`).

## ✅ Items 3–7 + doc wrinkles — RESOLVED (2026-06-17, follow-up)
- **Item 4** (`1c958bc`): measurement now hard-fails honestly when collapse fails (returns
  `collapse_failed` before finalizing/charging) instead of faking success. No live-behavior change.
- **Item 3** (`090a289`): gate-cost `{}`=free made explicit — `gate_costs` is an intentionally
  sparse table (only 9 of ~17 gates priced), so missing=free is by design, not a fallback lie.
  No behavior change. (Owner: price the other gates in default.jsonl if they should cost.)
- **Item 6** (`b2e2a19`): GameState's three hardcoded copies of tuning/economy_variables defaults
  now derive from the single `BalanceConfig` spec. Fixed a latent gap (workbench defaults were
  missing `market_temperature`/`vocab_*`). Runtime source unchanged.
- **Item 5** (`c21ab24`): story-flag firing now uses the SAME soft continuous geometry the Arc
  tab shows (per "soft continuous geometry >>> hard rules"). Deleted the duplicate hard
  predicate path (−110 LOC). Firing = soft `smooth_and` ≥ `FLAG_FIRE_THRESHOLD` (0.85, the dial).
  Nuance: wide-width predicates fire at high confidence (a touch past nominal). story_arc test passes.
- **Item 7 + doc wrinkles** (`c667a34`): documented MusicManager's layered selection authority
  (no refactor — sensitive layer); removed Biome.validate's self-contradictory "(external target
  OK)" warning + documented the warn-vs-error asymmetry; FarmPlot.grow() `-> float`(const 0.0) →
  honest `-> void`. Core/Documentation/ confirmed live.

### Original item descriptions (for reference) below.

---

## 🔴 Verified-dead but DEFERRED for your call (gameplay-critical / large blast radius)

### 1. Dead quest-generation cluster — 5 files, **1487 LOC** (the biggest remaining win)
The old procedural quest generator, fully superseded by the contract-market. Verified as a
**closed dead island** — I built the full `Core/Quests/` reachability graph from the live
roots (`QuestManager` ext=7, `QuestRewards` ext=3) and these 5 files are unreachable:

| file | LOC-ish | why dead |
|------|---------|----------|
| `QuestGenerator.gd` | — | referenced by **nothing** (dead root) |
| `QuestTheming.gd` | 567 | referenced by **nothing**; `apply_theming` only called by its own dead `generate_quest` |
| `BiomeLocations.gd` | — | referenced **only** by `QuestGenerator` |
| `FactionVoices.gd` | — | referenced **only** by `QuestGenerator` |
| `QuestVocabulary.gd` | — | referenced **only** by `QuestGenerator` |

- **Only external mention in the whole repo:** `tests/test_surface_refactor_snapshot.py:283-284`
  lists the class names `"QuestGenerator"`/`"QuestTheming"` in a surface inventory — a test
  snapshot, not live code.
- `QuestTheming.generate_quest` also carries a **latent bug** (would crash if called):
  reads `faction_vocab.cloud` at 6 sites but `FactionDatabase.get_faction_vocabulary()` returns
  `{signature, axial, all}` — no `.cloud` key.
- **NOT part of the cluster (keep):** `FactionStateMatcher`, `QuestEnergy`, `QuestMath`,
  `QuestTypes`, `QuestStateProjectionService` are all reached from the live roots.
- **One-click morning action:** delete the 5 files + their `.uid`s, and update
  `test_surface_refactor_snapshot.py:283-284`. I held off only because nuking a quest
  subsystem while you sleep is the "risky delete" you warned against — but the evidence is
  airtight, so this is ready to go the moment you confirm `QuestGenerator` is old-dead (not
  a planned future path). Git says `QuestTheming` was last touched 2026-05-30 in a checkpoint
  commit, consistent with abandonment.

### 2. 3 now-unused `quest_rewards` tuning keys (config-side of the `173e386` cleanup)
- `resource_reward_min_total`, `resource_reward_max_total`, `resource_reward_base_ratio` are
  no longer read by any code (their only consumers were the helpers I removed) but remain
  **required** by `QuestRewards`' hard-fail manifest + `default.jsonl`. Nothing breaks (they're
  present, validation passes) — but they're vestigial "required" keys.
- **Recommendation:** remove them from `QuestRewards.QUEST_REWARD_TUNING_KEYS` and
  `Core/Config/FarmVariableGraph/default.jsonl` together. I didn't touch the canonical economy
  surface overnight.

---

## 🟠 Silent-fallback / hard-fail candidates (your "earnest, no fallbacks" philosophy)

### 3. `FarmEconomy.get_overridden_gate_cost()` returns `{}` on miss — `FarmEconomy.gd:286-292`
The comment says *"sourced ONLY from the canonical JSONL (no code-default fallback)"* yet it
returns `{}` (= a free gate) when a gate isn't in the JSONL — silently, unlike
`get_economy_variable()` which `push_error()`s. 4 call paths feed off it.
**Decision needed:** is "gate has no cost entry → free" intentional (gate_costs is a sparse
table), or should a missing gate hard-fail like economy_variables? If sparse-is-fine, fix the
misleading comment; if not, make it loud.

### 4. `ProbeActions` ignores quantum-collapse return values — `ProbeActions.gd:272,275,393,397`
`_project_register()` / `_drain_register()` return `bool` (false on null QC / missing method)
but the results are discarded, and the action still returns `"success": true`. Also
`_drain_register` (~line 346) returns `true` unconditionally after calling `drain_qubit()`.
So a failed collapse reports success with a fabricated outcome. In practice a closed-system
biome always has a QC, so this likely never fires today — but it's a latent lie. Consistent
with `_commit_cost` (which DOES early-return `success:false`), these should too.

---

## 🟡 Parallel / duplicate authority (refactor candidates — no breakage)

### 5. `QuestManager._check_flag_predicate` vs `_check_flag_predicate_fire` — 211-312 vs 315-411
~200 LOC of duplicated predicate switch-logic; the two differ only in return semantics
(continuous `soft_gate()` vs hard `>= threshold`). Could collapse to one parameterized fn.

### 6. Duplicated economy defaults in `GameState` — `GameState.gd:79-81` & `405-406`
`quantum_to_credits` (1.0) and `max_biome_qubits` (12) are defined as GameState export-var
defaults AND in `_default_balance_workbench_config` AND in `BalanceConfig.TUNABLES` AND in
`default.jsonl`. Values currently match. Your plan says code-defaults + JSONL-overrides is
sound layering — but these GameState copies specifically may be stale duplicates worth folding.
**Verify whether the export-var copies are even read at runtime before deciding.**

### 7. `MusicManager` has 3+ track-selection paths that can drift
Direct `BIOME_TRACKS` lookup / parametric vector match (Layer 4) / iconmap-similarity, gated by
`iconmap_mode_enabled`. Not a bug, but worth documenting which is authoritative and when.

---

## ⚪ Low-priority notes
- **`MusicManager._global_icon_map_has_data()` (402-428)** conflates "farm not ready at boot"
  with "no terminals" → could set `_layer3_stopped` during early boot. Only fires if a track was
  already playing and dropped, so likely benign; watch at runtime. (Resurrected music layer — sensitive.)
- **`Biome.validate()` asymmetry (Biome.gd:212-222)**: atom-not-in-emojis is a *warning* (passes
  validation) while missing icon poles is an *error*. Also the "hamiltonian … (external target OK)"
  warning is self-contradictory (warns, then says it's OK). Decide if external H targets are valid.
- **`BiomeBase._get_atom_components()` (~220)** does `load("…BiomeRegistry.gd").new()` per call
  instead of `BiomeRegistry.get_shared()` — bypasses the shared cache / live `add_atom_pair`
  mutations. Possibly intentional isolation; confirm.
- **`FarmPlot.grow()`** is a no-op returning `0.0` (per-frame hook for future plot logic; return
  unused). Intentional stub — leave or change to `-> void`.
- **`QuantumComputer.get_coherence()`** returns `null` on 3 distinct conditions incl. an explicit
  "for now return null" cross-qubit stub; `QuestManager:1229` calls it `has_method`-guarded but
  may not null-check. Incomplete feature, low impact.
- **`UIPerformanceTracker.print_report()`** is unused by production but IS called by
  `tests/test_headed_runtime_profile.gd` — so NOT safe to delete (would break that test). Leave.

---

## ⚫ Agent claims I checked and DISMISSED (not issues)
- **"Unitary vs Euler dual-path drift"** — that's your *intentional* closed⊥open architecture
  (exact unitary when closed, Euler+renormalize when dissipative), not a bug.
- **HamiltonianBuilder/LindbladBuilder "silent skips"** — those are your intentional **primed
  operators** (waiting on axis allocation; activate on player completion).
- **`Farm.gd` "phrame_index"** — that's your project's vocabulary ("phrame"), not a typo.
- **`get_attractor_state()` / `export_bloch_packet()` returning `{}`/empty** — reasonable
  viz/UI reads when no native engine; not a lie.
- **`EvolutionBackend` abstract stubs** — correct interface pattern (NativeBackend overrides).
- **Faction physics** — confirmed clean: no code reads the deleted `Faction.hamiltonian` /
  `self_energies`; physics comes from `IconRegistry.get_signature_physics`.

---

## 📋 Appendix: dead private functions (0-ref-by-name across the whole repo)

A systematic scan of every `func _name` in Core (excl. Visualization + the dead quest cluster
+ Godot virtuals). These have **zero by-name references anywhere** — and since private functions
can only be called by name, that means dead. Caveat learned this pass: the scan can *under*count
(e.g. Farm.gd's `_get_missing_resources` had a by-name ref that actually resolved to FarmEconomy's
same-named copy — it was dead too), so it's a safe-but-conservative list. **Before removing each,
check (a) it doesn't orphan a field/other private (cascade), and (b) it isn't recent in-dev not
yet wired.** All inert (private + uncalled) so harmless to leave.

Already removed this pass: `_can_afford_cost`, `_spend_resources`, `_refund_resources`,
`_get_plot_biome`, `_get_missing_resources` (Farm.gd).

Still present, verified dead-by-name:
- `Core/Farm.gd`: `_get_loadable_biomes` (calls `_get_explored_biomes` → check that doesn't go dead too)
- `Core/Environment/BiomeEvolutionBatcher.gd`: `_accumulate_sink_flux_from_couplings`, `_biome_has_peeked_terminals`, `_get_engine_id_for_biome`
- `Core/QuantumSubstrate/QuantumComputer.gd`: `_project_component_state`
- `Core/Actions/ProbeActions.gd`: `_looks_like_farm`, `_resolve_terminal_purity`, `_save_density_matrices`
- `Core/GameMechanics/FarmEconomy.gd`: `_print_resources`, `_resource_allowed_by_iconmap`
- `Core/GameMechanics/FarmGrid.gd`: `_find_plot_by_id`
- `Core/Quests/QuestManager.gd`: `_apply_market_projection`
- `Core/Quests/IconPairing.gd`: `_apply_resource_bias`, `_roll_north_pole`, `_roll_south_pole_constrained`
- `Core/Factions/IconRegistry.gd`: `_merge_row_couplings`
- `Core/Biomes/Biome.gd`: `_normalize_icon_poles`
- `Core/Biomes/BiomeBuilder.gd`: `_get_verbose_config`
- `Core/Environment/BiomeBase.gd`: `_project_faction_standings_to_scalars`
- `Core/Alignment/AlignmentGraph.gd`: `_index_to_bits`
- `Core/Instrumentation/Handlers/LindbladHandler.gd`: `_resolve_axis_pair`

Note the `IconPairing` trio (`_roll_north_pole`/`_roll_south_pole_constrained`/`_apply_resource_bias`)
looks like an abandoned RNG-based icon-pairing path — consistent with the project's "no RNG in
exploration; biomes are crafted not random" invariant. Likely a clean sub-cluster to remove together.

### Bottom line
The Core is **cleaner than feared** — no economy-layer lies survived your consolidation, and
the architecture (closed-system, primed operators, faction-signature physics) is internally
consistent. The real slop is **abandoned parallel implementations** (QuestTheming/QuestGenerator
quest-gen vs the live contract-market; DensityMatrix wrapper vs the live ComplexMatrix). #1 is
the biggest remaining win once you confirm it's safe to nuke.
