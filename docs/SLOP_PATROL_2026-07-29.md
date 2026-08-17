# Slop patrol — 2026-07-29

> **Historical.** Session log + wish list from 2026-07-29. The four live bugs
> it names were fixed that day. The wish list is not a release blocker.

A 6-way parallel sweep (UI, core gameplay logic, quantum/physics/biome layer,
native C++, Python tooling, misc systems) hunting for duplicated/copy-pasted
code across SpaceWheat. Four findings turned out to be live bugs, not just
style debt, and were fixed same-session (commit follows this doc). Everything
else below is a **wish list for the next fable run** — real duplication,
ranked, with file:line refs, but not urgent enough to fix blind.

## Fixed this session

1. **Three divergent `load_biomes`/`load_factions` loaders** — only
   `tools/biome_audit.py` stripped emoji variation-selectors (`strip_fe0f`);
   `tools/build_icon_lexicon.py` had its own un-normalized copy (6 other
   `tools/*_assay.py` scripts already imported the canonical pair from
   `biome_audit.py` — `build_icon_lexicon.py` was the outlier). Fixed by
   importing the canonical loaders. `scripts/check_biome_images.py` was left
   alone — it never does emoji-keyed lookups (only `name`/`image_path`), so
   its own loader isn't actually at risk.
   **Side discovery (not fixed, out of scope):** `build_icon_lexicon.py` is
   dead in practice — `Core/Biomes/data/biomes.json` no longer carries a
   per-biome `icons[]` field at all (confirmed via direct load: `0` icon
   entries across all 163 biomes). This is unrelated schema drift, not the
   loader bug. The committed `tools/icon_lexicon_proposals.json` (77 orphans)
   is a stale artifact from before the drift. Needs its own investigation:
   either the tool is obsolete and should be deleted, or something upstream
   stopped emitting `icons[]` and that's a real regression.
2. **Cost-formatter sign-order bug** — `UI/Overlays/EscapeMenu.gd:1270`
   (`_format_cost`, the Balance-tab dev inspector) rendered `"🍼−1"`
   (emoji-then-sign) while explicitly claiming in its own comment to match
   "the same badge law as the live bar (d1-03)" — every other signed-cost
   readout in the game (`UI/Core/Submenus/BaseSubmenu.gd:170` `format_cost`,
   `Core/UI/ChipResolverRegistry.gd:96` `_format_cost_inline`,
   `UI/Widgets/ActionPreviewRow.gd`) puts the sign first (`"−1🍼"`/`"−🍼×2"`).
   Fixed: sign now comes first, matching the badge law it already claimed to
   follow.
3. **Doubled no-op line** — `Core/Factions/IconLoadoutInducer.gd:56-59` and
   `Core/Factions/IconFamily.gd:58-61` each pasted the identical
   `if lexicon == null: lexicon = (...)` autoload-fallback line twice in a
   row. Harmless (idempotent) but a tell nobody's re-read this code closely.
   Removed the duplicate line in both files.
4. **`DualEmojiQubit.purity` self-documented approximation** —
   `Core/QuantumSubstrate/DualEmojiQubit.gd:130-144` computed
   `p0²+p1²+2|coherence|²` by hand with a comment admitting *"this should come
   directly from `parent_biome.quantum_computer.get_marginal_purity()`. For
   now, approximate from probabilities."* For the register-first path (the
   common path — `register_id >= 0`), the data backing that formula already
   comes from the real marginal density matrix, so the formula was
   algebraically exact but redundant. Fixed: register-first path now calls
   `get_marginal_purity()` directly, removing the duplicate computation. The
   legacy emoji-only path (no register binding) keeps the hand-rolled
   approximation — there's no emoji-keyed equivalent of `get_marginal_purity`
   on `QuantumComputer`, and that path's `p0`/`p1`/coherence aren't
   guaranteed to come from a genuine trace-1 2×2 matrix, so "approximate" is
   still the honest word there.
   **Also found while fixing:** two *more* `_format_cost` implementations
   exist beyond the two above — `Core/Actions/ProbeActions.gd:1147` (unsigned,
   `"🍼×2"`, used in "Need X to reap" messages) and
   `Core/GameMechanics/FarmEconomy.gd:186` (unsigned, `"2 🍼"`, used in debug
   spend logging). These are a different family (plain diagnostic text, not
   the signed wallet-loss badge law) so left alone — see wishlist below.

Verified via `godot --headless --path . --script tests/test_icon_relations.gd`
(19/19), `tests/escape_menu_run_smoke.gd` (31/31),
`tests/test_closed_system.gd` (12/12, unaffected — the pre-existing
`Nonexistent function 'evolve'` script error there predates this session and
is unrelated to any file touched here), plus a direct `build_icon_lexicon.py`
smoke run.

## Wish list — everything else, ranked

Not fixed. Real duplication, but style/maintenance debt rather than active
bugs — collapsing each is a self-contained refactor task for a future
session. Grouped by theme; file:line refs are from the 2026-07-29 sweep and
may drift.

### Big mechanical wins (large, clean, low-risk to collapse)

- **UI overlay "mini design system" forked 4×.** **PARTIALLY CLOSED
  (consolidation P3, 2026-08-03):** the copy-pasted widget builders
  (`_make_key_chip`/`_make_muted_label`/`_make_kv_row`/`_make_empty_row`/
  `_make_spacer`/`_ratio_bar`) are now one-line delegates into the new
  `UI/Core/OverlayChrome.gd` (parameterized so every overlay keeps its exact
  historical look — see knot #19 below for what deliberately stayed forked:
  tab rows, open/close/input wiring, and BiomeInspectorOverlay's kv/bar
  variants). The bounce/pop tweens and percent-formatting helpers below
  remain open. Original finding: `EscapeMenu.gd`,
  `ControlsOverlay.gd`, `QuestBoard.gd`, `MapMetaOverlay.gd` (+ cousins
  `BiomeInspectorOverlay.gd`/`InspectorOverlay.gd`) all extend `Surface.gd`
  but each reinvented `_make_key_chip`, `_make_muted_label`, `_make_kv_row`,
  `_make_empty_row`, and tab-row scaffolding independently — despite
  `UI/Core/UIStyleFactory.gd:258` already providing an equivalent
  `create_muted_label()` nobody calls. ~200+ duplicated lines. Also: two
  hand-rolled "bounce/pop" tweens (`UI/Widgets/ContractChip.gd:57-61`,
  `UI/Widgets/ResourcePanel.gd:142-146`) and 3 identical
  percent-formatting helpers (`Core/Visualization/BiomeStateViews.gd:454-457`,
  `UI/Overlays/BiomeInspectorOverlay.gd:635-638`).
- **9 quest trackers share identical completion boilerplate.**
  `Core/Quests/QuestManager.gd:1703-1909` — every `_update_*_quest` tracker
  ends with the same 5-line "progress ≥ 0.9 → mark ready" block; 3 of them
  additionally repeat an identical duration-accumulation snippet
  (`:1744-1748`, `:1827-1831`, `:1874-1878`). ~55-65 duplicated lines across
  9 sites. Wants `_finish_progress(quest, progress, reason)` and
  `_accumulate_duration(...)` helpers.
- **6 `tools/*_assay.py` scripts share a ~30-line CLI harness.**
  `clock_assay.py`, `eit_assay.py`, `ssh_assay.py`, `transition_assay.py`,
  `gain_assay.py`, `zeno_assay.py` each copy-paste the same argparse setup +
  load/filter/rank/print loop, varying only the physics formula. A shared
  `tools/assay_cli.py` runner would absorb ~180 lines.
- **Partial-trace algorithm implemented 4× in one C++ file.**
  `native/src/quantum_evolution_engine.cpp:519-772` — general
  (`Eigen::MatrixXcd`) and fixed-size fast-path versions of
  `partial_trace_single`/`partial_trace_complement`/`partial_trace_single_2x2`/
  `partial_trace_pair_4x4` all independently re-derive the same bit-index
  reconstruction loop. ~90 of ~110 lines duplicated. Wants one function
  templated on output size.
- **Eigendecompose-and-repack blocks, 4×.** Same file:
  `compute_eigenstates` (`:1058`), `compute_dominant_eigenvector` (`:1112`),
  `compute_eigenvalues` (`:1140`), `compute_batch_eigenstates` (`:1191`,
  repeats the packing loop again inline at `:1246-1260`). ~70-90 duplicated
  lines; wants a private `eigendecompose_and_pack(rho)` helper.
- **Test-fixture bootstrap copy-pasted across 8 `tests/*.py` rig tests**
  (`test_arc_offer_rebirth_on_load.py`, `test_quest_state_roundtrip.py`,
  `test_rig_quest_roundtrip.py`, `test_title_boot_path.py`,
  `test_cost_surface_parity.py`, `test_druid_gate_targets_focused_plot.py`,
  `test_story_arc_boot.py`, `test_submenu_paging.py`) — same
  `PROJECT_ROOT`/`RUNNER_ROOT`/`sys.path.insert`/`RigClient` import block and
  `shutil.which("godot") is None: pytest.skip(...)` guard, 8 times.
  `tests/conftest.py` exists but doesn't carry this fixture — wants a shared
  `rig_client()`/`rig_env()` fixture there.
- **Same bootstrap pattern again across 52 `🍄/🧪/*.py` probes.** The
  duplication itself is still open and still wants a shared
  `🍄/🧪/_bootstrap.py`. **The portability half is fixed (2026-08-16):** the
  hardcoded `/home/primearchitect/ws/SpaceWheat/🍄` absolute path in
  `born_reward_probe.py`, `menu_bleed_lens_probe.py`, `biome_carousel_probe.py`,
  `mint_checkpoint.py`, `poverty_run_probe.py`, `player_seat.py`,
  `ward_quest_probe.py`, `tutorial_stranger_probe.py` — plus `mouse_seat.py`,
  `store_kit_shots.py`, and the unrelated `🍄/🛠️/♻️.sh` — now all compute
  their root from the script's own location instead of one machine's path.
  Found because it broke `tests/test_mouse_seat_contract.py` on any checkout
  that isn't that exact path.
- **~36-site "safe autoload lookup" ternary** spread across `Core/Boot/`,
  `Core/Config/`, `Core/GameState/`, even inside
  `Core/Instrumentation/InstrumentLocator.gd` itself (`:46,63`) — which
  already exists to *be* the shared resolver for exactly this pattern.
  Notable sites: `Core/Boot/WorldBuilder.gd:107,116,137,200,318`,
  `Core/Boot/RuntimeMount.gd:300,399,436,441,454`.

### Two competing math stacks (architectural-level)

- ~~**Two full complex-matrix-math implementations coexist in C++.**~~
  **CLOSED (consolidation pass 2026-08-03, task #421):** `spacewheat::ComplexMatrix`
  deleted; `mythos_graph_core.*` and `hermitian_eigensolver.*` now use
  `Eigen::MatrixXcd` directly. The eigensolver's two O(n²) conversion copy
  loops deleted with it. Verified by facade_parity.gd GDScript-vs-native
  comparison at TOL=1e-9.
- ~~**`SelfAdjointEigenSolver` invoked ad hoc 8+ times**~~
  **CLOSED BY RULING (2026-08-03): not slop.** The 8 sites use the raw solver
  idiomatically on Eigen types — eigenvalues-only reads and unitary
  construction on hot paths. `HermitianEigensolver::solve` exists to serve the
  GDScript-facing `EigenResult` summary and carries no policy of its own;
  routing hot paths through it would add per-call vector/matrix copies while
  deduplicating zero logic. Leave direct.
- ~~**A fully dead duplicate entropy/coherence calculator.**~~
  **CLOSED (2026-08-03):** `BiomeBase._calculate_quantum_entropy`/
  `_calculate_quantum_coherence` deleted (zero callers re-verified at deletion
  time).
- ~~**`BridgeRegister._apply_unitary` hand-rolls a 2×2 complex matrix
  multiply**~~ **CLOSED BY RULING (consolidation P3, 2026-08-03): not slop.**
  `ComplexMatrix.mul()`/`dagger()` now delegate to the native compute kernel,
  so routing this fixed-size sandwich through them would add Array↔Packed
  conversions, 3 object allocations, and a native-lib dependency on the
  save-serialized bridge path while deduplicating zero logic;
  `QuantumGateLibrary` has no packed 2×2 sandwich helper either. Ruling
  documented in a comment at the function.
- **`WitnessBridge` is explicitly commented "cloned from
  `PlayerEventBridge`"** (`Core/Witness/WitnessBridge.gd:1-70`), including a
  verbatim `_connect_once` helper and near-identical farm-ready wiring. An
  intentional fork never pulled into a shared `SignalBridge` base.
- ~~**Three near-identical affinity-scoring methods in one file**~~
  **CLOSED (consolidation P3, 2026-08-03):** all three public entry points
  (`calculate_affinity`, `calculate_affinity_with_populations`,
  `calculate_affinity_by_name`) now delegate to one shared
  `_accumulate_affinity(icon, biome_emojis, populations)` core; the
  population weighting became an optional parameter. Public signatures and
  outputs unchanged.
- **Two independent hand-written Kraus-map loops for the same physics** —
  `Core/QuantumSubstrate/QuantumComputer.gd`: `apply_jump_channel`
  (~1307-1355, cross-qubit) and `_apply_lindblad_1q` (1362-1420, same-qubit)
  both build `K₀`/`K₁` and apply `ρ' = K₀ρK₀† + K₁ρK₁†` — the comment in
  `apply_jump_channel` admits "same guarantees as `_apply_lindblad_1q`"
  without unifying them.

### Smaller / lower-priority

- `SessionLifecycle.reset_runtime_singletons()`
  (`Core/GameState/SessionLifecycle.gd:268-296,310-314`) — 8 copy-pasted
  "get node, check has_method, call reset" blocks; wants a loop over a name
  list.
- `ObservationFrame.gd:134,205,238,277` — 4× repeated
  `get_node_or_null("/root/GameStateManager")` guard in one 315-line file;
  cache it once.
- `SaveLoadCoordinator.gd` — `save_game`/`save_game_to_path` (73-102) and
  `load_game_state`/`load_game_state_by_path` (112-133) are near-identical
  twins differing only in the SaveStore call.
- `UIPerformanceTracker.gd:12,16-17,23,34` hand-rolls its own verbose-logging
  gate instead of using the existing `Core/Config/VerboseHelper.gd`
  wrappers.
- `MusicManager.gd` tween-fade boilerplate repeated 3-4× (`:489-491,
  506-509, 1041-1049, 1070`) — wants a `_fade_player(player, target_db,
  duration)` helper.
- `MarketLattice.propose_neighborhood_offers` (`:230-287`) vs
  `..._scoped` (`:366-437`) — ~50 of 70 lines match; the scoped variant looks
  forked rather than delegating to a shared scorer.
- `Socialite.choose_next_topic` (`Core/Story/Socialite.gd:44-56`)
  reimplements the weighted-random-pick already extracted into
  `BiomeDiscoveryForecastService.weighted_random_pick`
  (`Core/Gameplay/BiomeDiscoveryForecastService.gd:167-177`).
- `trajectory.record({...})` 7-key dict literal repeated 5× —
  `Core/Story/StoryEngine.gd:674-689,731-739,762-770`,
  `Core/Story/TrajectoryLog.gd:34-42,46-54`.
- `Core/Factions/{IconRegistry,FactionAxes,FactionRegistry}.gd` each
  hand-roll the same `FileAccess → JSON.parse → error-check` JSON-loading
  boilerplate (`IconRegistry.gd:292-302`, `FactionAxes.gd:19-27`,
  `FactionRegistry.gd:64-70`).
- `IconRegistry.gd:567-576` (`_merge_nested_couplings`) vs `:577-584`
  (`_merge_row_couplings`) — the row variant does plain `float + float`
  instead of routing through `_add_coupling`, which already handles
  `Vector2`/`Array`/`float`.
- Config path constants (`factions.json`/`biomes.json`) re-declared with
  drifting join styles across 7 Python scripts (`build_icon_lexicon.py`,
  `gen_biome_icon_stubs.py`, `validate_icon_lexicon.py`, `biome_audit.py`,
  `validate_faction_bits.py`, `mutate_starter_island.py`,
  `scripts/mutate_factions_biomes.py`).
- **A fourth `_format_cost` family** (unsigned, diagnostic-only) at
  `Core/Actions/ProbeActions.gd:1147` and `Core/GameMechanics/FarmEconomy.gd:186`
  — see "Fixed this session" §2 for why these were left alone; still worth a
  look since it's a 4-way split of the same concept (signed badge / unsigned
  diagnostic) across the codebase.
- ~30 sites of `if not sig.is_connected(cb): sig.connect(cb)` guard-connect
  boilerplate across `UI/PlayerShell.gd`, `UI/Core/FarmSurface.gd`, several
  `UI/Widgets/*.gd`, `Core/Visualization/*.gd` — defensive idiom, not a bug,
  but volume suggests a `Utils.connect_once(signal, callable)` helper.
- GDExtension binding boilerplate (trivial one-line setters +
  `ClassDB::bind_method` pairs) spread across ~120 call sites in
  `force_graph_engine.cpp`, `quantum_matrix_native.cpp`,
  `multi_biome_lookahead_engine.cpp`, `quantum_evolution_engine.cpp`,
  `quantum_mythos_engine.cpp` — lower priority, Godot's binding API forces
  some of this regardless.

### What's already clean (don't re-audit)

The core Hamiltonian/Lindblad/gate-construction pipeline
(`HamiltonianBuilder`, `LindbladBuilder`, `QuantumGateLibrary`,
`BiomeQuantumSystemBuilder`, `EvolutionBackend`/`NativeBackend`) is
single-authority with no GDScript shadow-physics fallback — one file even
carries a comment referencing incident #118, where a cached second authority
disagreed with the live builder and was deliberately removed. The historical
"silent twin engine" purge (native-only physics cutover) held for the
physics core. `GateActionHandler.gd`'s per-gate handlers all delegate
cleanly to `_apply_gate_batch`/`_apply_single_qubit_gate`. The duplication
that has regrown since is concentrated in UI chrome, observable/formatting
helpers, and tooling scaffolding — not in the physics engine itself.

One documented, intentional exception: `mythos_graph_core.cpp:327-328`
explicitly mirrors `Core/Factions/FactionDensityMatrix.gd` "line-by-line" as
a Phase-1 shadow (see `register_types.cpp:42`) — worth a status check if
that migration has stalled.

---

## Cycle 2 — 2026-07-29 (workflow sweep)

A second pass, run as a scripted find → triage → consolidate → document
workflow instead of one agent doing it all by hand (9 zone finders — one
per architectural layer — plus 1 cross-cutting finder, then a skeptical
triage pass, then one fix attempt per surviving "easy" item, each required
to search for and run a directly-relevant test or say plainly that none
exists). 46 raw findings → 10 judged safe/mechanical enough to attempt → 8
applied, 2 correctly refused (both required deleting pre-existing files —
out of scope for a broad "hunt and consolidate" mandate; deletion needs a
human to name the exact target). The other 34 raw findings were knots from
the start. All 36 final knots are below, ranked by blast radius crossed
with how critical the path is.

### Fixed this cycle

1. **`EmojiRegistry._norm()`** duplicated `EmojiUtil.normalize()` byte-for-byte
   (same two codepoints stripped, same order). Now delegates.
   `Core/Visualization/EmojiRegistry.gd:77-78`.
2. **`QuestBoard.gd`'s tab row and verb chips** hand-rolled click detection
   instead of using `ClickWire.attach` — the helper built specifically to
   prevent this, already used identically in 4 sibling overlays. Missing the
   pointing-hand cursor every other tab row has was the tell. Migrated;
   deleted the two now-unused gui_input wrapper functions.
   `UI/Overlays/QuestBoard.gd`.
3. **The packed-array→`Eigen::MatrixXcd` unpack loop** was copy-pasted 5×
   inside `quantum_matrix_native.cpp` (`from_packed`, `mul`, `add`, `sub`,
   `commutator`) — the pack direction already had a shared helper, the unpack
   direction didn't. Extracted `unpack_matrix()`; native lib rebuilt clean.
4. **`milk_hunt_world_state.py`'s `get_world_state()`/`list_world_state_names()`**
   were dead — zero callers anywhere in the repo (verified by grep). Deleted
   the functions (not files) and the now-unused `_CONFIG_DIR` constant.
5. **Identical `log`/`success`/`warn`/`error` shell helpers** copy-pasted
   across 12 build/deploy scripts, with drifting formatting between the
   older `scripts/setup.sh` copy and everything else. Extracted to
   `scripts/lib/log.sh`; all 12 now source it. (Cosmetic note: `setup.sh`'s
   output picks up the newer bold/blank-line style as a side effect — same
   messages, slightly different color codes.)
6. **Identical `_read(path)` source-slurp helper** copy-pasted into 8 Python
   "surface hygiene" test files. Moved to `tests/conftest.py` as
   `read_source()`; all 8 now import it. 55/55 tests pass.
7. **Identical 4-line "Scope banner" blockquote** copy-pasted verbatim into
   all 11 `docs/biomemissions/*.md` files. Trimmed 10 of them to a one-line
   pointer back to `docs/biomemissions/README.md`, which keeps the full text.
8. **`MEMORY.md` re-documented the desktop build/package/smoke-test procedure**
   that `docs/release/DESKTOP_RELEASE_WORKFLOW.md` already owns and names as
   canonical. Trimmed `MEMORY.md` to point at it.

**Correctly refused, escalated to knots (Tier 8 below):** the 6 byte-identical
duplicate SVG icon pairs in `Assets/UI/Elements/` vs `Assets/UI/Nature/` +
`Assets/UI/Celestial/`, and the two dead legacy emoji-downloader scripts
(`🍄/🛠️/📥.py`, `📥_retry.py`) — both fixes are pure file deletions, which
this pass's own rule put out of scope. Independently re-verified both
(byte-identical via `md5sum`; zero repo-wide references) before declining —
they're safe to delete, they just need a human to say so.

Spot-checked beyond each fix's own verification: full `godot --headless`
boot completes clean (exit 0, no script/parse errors) with the changed
`EmojiRegistry.gd`/`QuestBoard.gd`/`ClickWire.gd` in the load path; all 12
touched shell scripts pass `bash -n`; `docs/release/DESKTOP_RELEASE_WORKFLOW.md`
confirmed to actually exist and be complete before trimming `MEMORY.md`'s
pointer to it.

### Wish list — Cycle 2 knots (36)

A fresh duplication sweep of the repo turned up 36 "knots": places where the same logic, state, or convention has been reimplemented in two or more spots and has often already begun to diverge — but where collapsing them safely requires a human architectural call (schema ownership, behavior parity, hot-path safety, or explicit sign-off to delete a file) rather than a mechanical merge. None of these were auto-fixed this cycle. Ranked below by impact/reach: blast radius (how many files/call sites) crossed with how critical the path is (physics/save-load/render vs. docs/dead code).

#### Tier 1 — Native engine & physics correctness (highest stakes: hot path, crash/precision risk)

**All 5 Tier 1 knots below are CLOSED.** Doc-hygiene correction (scout pass, 2026-08-03): every
one of these was already fixed by commit `d8126c22` ("Slop patrol Tier 1 + fractal portals P1-P5
+ legibility channel codex") — the same commit this doc's Cycle-2 section was originally written
in — but this Tier 1 list itself was never struck through to match. Verified against current
source, not assumption:

~~**1. Lindblad master-equation RHS (and the exact-unitary fast path) implemented twice**~~
**CLOSED (d8126c22).** `quantum_evolution_engine.cpp:327` (`evolve_step`) now carries the comment
"ONE INTEGRATOR... evolve_step() used to carry its own hand-written copy... So evolve_step IS
evolve with max_dt = dt. No second authority." — `evolve_step` now delegates to `evolve()`.

~~**2. QuantumMatrixNative and QuantumEvolutionEngine reinvent the same packed-array↔dense-matrix convention with divergent validation**~~
**CLOSED (d8126c22).** `unpack_dense()` (`quantum_evolution_engine.cpp:458-483`) now centralizes
the size check with a documented history comment: "it used to be checked at 2 of ~9 call
sites... An undersized buffer is a heap overread... Both are refused, loudly." Every caller
(`compute_purity_from_packed`, `compute_bloch_metrics_from_packed`, etc.) routes through this
one guarded function.

~~**3. Degenerate/zero-trace density-matrix trace-and-rebuild loop duplicated 3×**~~
**CLOSED.** All 3 call sites (`BiomeDeterministicStepper.gd:380`,
`BiomeEvolutionBatcher.gd:1263,2975`) now delegate to a shared `DegenerateRho.is_degenerate`/
`maximally_mixed_packed` utility instead of hand-rolling the trace-and-rebuild loop independently.

~~**4. Hand-rolled `spacewheat::ComplexMatrix` duplicates Eigen::MatrixXcd, which the same files already require**~~
**CLOSED by #421** (consolidation pass, 2026-08-03) — see "Two competing math stacks" below;
cross-referenced here so this list doesn't read as still-open.

~~**5. HermitianEigensolver's Jacobi fallback is a dead, mathematically wrong duplicate of the Eigen path**~~
**CLOSED (d8126c22).** `native/src/hermitian_eigensolver.cpp` is now 31 lines total — pure Eigen
`SelfAdjointEigenSolver` path only, `solve_real_jacobi_projection` and its dispatch gone entirely.

#### Tier 2 — Wide-reach infrastructure duplication (12-28 files each)

~~**6. Ad-hoc pass/fail test-harness boilerplate reimplemented in ~28 GDScript SceneTree scripts**~~
**CLOSED (consolidation pass 2026-08-03, P2b):** `tests/smoke_test_base.gd` now owns the
passed/failed counters, `_check(cond, label[, detail])`, `_fail`, and the summary-print/quit
tail; 28 tests migrated mechanically via `extends "res://tests/smoke_test_base.gd"` (path
extends, no class_name — the class cache never needs an `--import` pass). The
`test_icon_relations.gd` arg-order footgun fixed: all its call sites flipped to the canonical
`(cond, label)` order, along with the three label-first files
(`test_evolve_parity.gd`, `test_degenerate_rho.gd`, `test_hermitian_eigen_path.gd`).
Per-file pass/fail counts verified identical before/after for every migrated test, including
the pre-existing red ones (`bare_biome_realization_smoke` 6P/2F,
`bubble_rendering_cleanup_smoke` 19P/1F, `save_floor_smoke` 10P/2F). NOT migrated:
`test_cn_handoff_runtime.gd`/`test_m_surface_runtime.gd`/`test_v_surface_runtime.gd`
(pre-existing parse error — `"visible"` undeclared — makes behavior-preservation unverifiable),
`test_surface_headless_smoke.gd` (pre-existing headless hang), and
`facade_parity.gd`/`principal_mode.gd` (fail-fast `quit(1)` style, not this counter pattern).
Bonus: `scripts/run_tests.sh` was invoking a scene that no longer exists
(`scenes/test_quantum_substrate.tscn`); it is now a real runner wiring all 27 green smoke
tests (incl. the three resurrected in 68ebd80e) so they can't rot outside a runner again.

~~**7. JSON load-parse-error boilerplate hand-rolled independently across ~20 GDScript loaders**~~
**CLOSED (fable push 2026-08-03, ce92faa0 + b5c0d278):** `Core/Config/JsonFileLoader.gd` is the one authority ({ok,data,error,missing} envelope, required-vs-optional + root checks). 4 strict registries + 12 lax sites migrated, each preserving its semantics; malformed-but-existing files are now LOUD everywhere (line-numbered). Correctly not migrated: PolicyGraph/FarmVariableGraph (JSONL per-line), Frontmatter (YAML-in-Markdown), CognifoldTraceView's HTTP body, SaveStore's .tres-substring parse.
`Core/Biomes/BiomeRegistry.gd:104-122`, `Core/Factions/FactionRegistry.gd:64-79`, `Core/Factions/IconRegistry.gd:293-303`, `Core/Factions/FactionAxes.gd:19-31` (full open/parse/error-report/close idiom); laxer `JSON.parse_string` variant in `Core/GameMechanics/BalanceConfig.gd:206-209`, `Core/Story/StorySeedLoader.gd:26-30`, `Core/Quests/QuestManager.gd:233-237,259-263`, `Core/GameState/ScenarioLedger.gd:47-50`, `Core/GameMechanics/FarmVariableGraph.gd:28-45`, `Core/Gallery/ReelRunner.gd:61`, plus ~10 more (`SaveStore.gd`, `EmojiRegistry.gd`, `MusicManager.gd`, `QuantumField3D.gd`, `UmweltVizCache.gd`, `CognifoldTraceView.gd`, `QuantumInstrument.gd`, `Frontmatter.gd`, `PolicyGraph.gd`, `BiomeCharacteristics.gd`, `EscapeMenu.gd`).
Knot: callers differ on required-vs-optional files and diagnostics; a shared `JsonFileLoader.gd` needs a signature that accommodates that before ~20 sites can move.

~~**8. ~27 probe/drive scripts hand-roll an identical turn-driver DSL instead of sharing one helper**~~
**CLOSED (fable push 2026-08-03, 854f7ce8):** `🍄/🧪/turn_driver.py` (TurnDriver + go/press factories, both timeout idioms). 28/30 migrated by exact-literal replacement; per-script timeouts stay explicit constants (90 vs 120 NOT unified, per this knot's own warning). demos_campaign_run + visual_playthrough left — genuinely divergent DSLs.
`🍄/🧪/mill_probe.py`, `c3_probe.py`, `b_probe.py`, `dynamic_probe.py`, `screenshot_probe.py`, `welcome_probe.py`, `ring6_probe.py`, `plot_idx_probe.py`, `act2_drive.py`, `act3_5_drive.py`, `village_arc_drive.py`, `mill_drive.py`, and ~15 more — `grep -l "_turn[0] += 1"` → 29 files, `def go(a, **k):` → 27 files, `def press(seq` → 23 files, with divergent hardcoded timeouts (90 vs 120).
Knot: consolidating requires picking canonical default timeouts/settle-frame counts across ~27 independently-evolved diagnostic scripts.

~~**9. No shared biome/faction data-IO module: path constants + read-mutate-write boilerplate duplicated across 12+ tools/scripts files, with drifting read idioms and a hidden normalization trap**~~
**CLOSED (fable push 2026-08-03):** `tools/biome_io.py` is the ONE json-read/write implementation (paths, load/save, ensure_ascii=False law); FE0F-stripping is an EXPLICIT normalize= opt-in, default off — biome_audit keeps it on, mutate scripts stay raw, exactly per this knot's trap warning. Read-only tools byte-identical across 37 fixture invocations; mutate-script idioms proven byte-equivalent without execution. Follow-up candidates flagged, not touched: 6 more tools/ files with their own path constants that were outside this knot's named list.
`tools/build_icon_lexicon.py`, `tools/gen_biome_icon_stubs.py`, `tools/validate_icon_lexicon.py`, `tools/biome_audit.py`, `tools/validate_faction_bits.py`, `tools/mutate_starter_island.py`, `tools/set_starter_island.py`, `scripts/mutate_factions_biomes.py`, `tools/mutate_fungalnetworks_and_gate.py`, `tools/mutate_diversity_pass.py`, `tools/mutate_fungalnetworks.py`, `tools/mutate_biome_repair.py`. A verified byte-identical subset (`mutate_fungalnetworks_and_gate.py`, `mutate_diversity_pass.py`, `mutate_fungalnetworks.py`, `mutate_biome_repair.py`, `set_starter_island.py`) uses `json.load(path.open())`; others use `json.loads(path.read_text())` or `with open(path) as f:`. `tools/biome_audit.py`'s `load_biomes()`/`load_factions()` (already shared by 6 assay tools) strip FE0F variation selectors — the mutate scripts don't.
Knot: any shared helper must not silently import FE0F-normalization behavior into scripts that never opted into it.

~~**10. Six `tools/*_assay.py` scripts share a copy-pasted CLI harness, with one confirmed behavioral difference**~~
**CLOSED (fable push 2026-08-03):** `tools/assay_cli.py:run_assay(...)` owns the harness; the orphan-biome filter is an explicit per-caller flag (clock/transition/gain=True, eit/ssh/zeno=False — each file's pre-existing behavior preserved, the doc's stated requirement). All six delegate; outputs byte-identical incl. error branches and exit codes.
`tools/clock_assay.py`, `tools/eit_assay.py`, `tools/ssh_assay.py`, `tools/transition_assay.py`, `tools/gain_assay.py`, `tools/zeno_assay.py` — identical argparse + biome-detail branch + rank/print loop around `tools/biome_audit.py`'s shared loaders. `clock_assay.py:230-231` filters out `_orphan_lindblads` biomes; `ssh_assay.py` does not.
Knot: a shared `tools/assay_cli.py:run_assay(...)` must preserve the orphan-biome filter as an explicit opt-in, not silently unify it away.

#### Tier 3 — Core game-state, save-load & economy correctness

**11. ~~BIOME_ORDER duplicated as independent mutable state across ObservationFrame and ActiveBiomeManager~~**
**CLOSED (consolidation P3, 2026-08-03): ObservationFrame designated single owner.** ObservationFrame gained `set_biome_order()` + a `biome_order_changed` signal (also emitted from `unlock_biome`/`lock_biome`/`reset`/`_load_unlocked_biomes`); ActiveBiomeManager's `BIOME_ORDER` is now a signal-driven mirror — its `set_biome_order()` applies locally (headless fallback) then routes divergence back through the authority, and its internal `_apply_biome_order()` never writes back. The two dual-write routines (`GameStateSerializer._restore_biome_progression_state`, `WorldBuilder.sync_biome_progression_autoloads`) no longer poke `BIOME_ORDER` fields directly. Serialization format untouched (still `state.unlocked_biomes`). The verbatim index/count method copies remain but now read a guaranteed-synced mirror.

~~**12. Both scenario `.tres` files bake an identical, schema-stale default `plots` array instead of sharing GameState's factory**~~
**CLOSED (fable push 2026-08-03, 7ff7c3f7): factory owns defaults.** Both `.tres` plots arrays regenerated to `create_for_grid`'s schema; the serializer shim stays one release for genuinely old SAVES (comment says when to retire). NEW rot found in passing: audit_saves_text.sh + repair_saves.py still target the long-gone Scenarios/default.tres.
`Scenarios/demos_normal.tres:33`, `Scenarios/new_game_easy.tres:47` — pre-migration schema (bare `type` int). `Core/GameState/GameState.gd:314-338` (`create_for_grid`) builds the current richer schema. `Core/GameState/GameStateSerializer.gd:452-461` carries a legacy-format shim that exists solely to translate the stale `.tres` files.
Knot: needs an owner decision on whether "default plot" lives in data or factory before the schema drift can be closed.

~~**13. Cost-dictionary-to-display-string formatter reimplemented 5× with three drifting conventions**~~
**CLOSED (fable push 2026-08-03, ce92faa0):** `Core/UI/CostFormat.gd` is the one formatter; all five sites are one-line delegates pinning their exact convention — parity-probed byte-identical (incl. chip's round-vs-truncate float divergence, preserved). The EscapeMenu↔ChipResolverRegistry hand-sync comment is dead.
`Core/Actions/ProbeActions.gd:1147` (`_format_cost`, unsigned, sorted), `Core/GameMechanics/FarmEconomy.gd:186` (`_format_cost`, unsigned, unsorted, comma-joined — visibly older), `Core/UI/ChipResolverRegistry.gd:96` (`_format_cost_inline`, signed, sorted), `UI/Core/Submenus/BaseSubmenu.gd:170` (`format_cost`, signed), `UI/Overlays/EscapeMenu.gd:1270` (`_format_cost`, signed, sorted — its own comment cites `ChipResolverRegistry._format_cost_inline` as the convention it's manually kept in sync with).
Knot: developers are already hand-syncing two of these via comments instead of shared code — proof the duplication is a recognized liability; folding requires auditing every caller's expected string shape.

~~**14. Save-file schema knowledge (obsolete vs. current plot fields) hardcoded independently in bash and python**~~
**CLOSED (fable push 2026-08-03, ce92faa0):** repair_saves.py owns OBSOLETE_PLOT_FIELDS/REQUIRED_PLOT_FIELDS and emits them via `--emit-schema`; audit_saves_text.sh loops over that output instead of re-deriving. Fixture-proven.
`scripts/audit_saves_text.sh:57-67` (flags `theta`/`phi`/`growth_progress`/`is_mature` as OBSOLETE, checks for `theta_frozen` at 70-73) vs `scripts/repair_saves.py:7-9,152-153` (same rule re-derived in a different language).
Knot: no mechanical cross-language merge is possible; needs a shared manifest format decision.

#### Tier 4 — UI/overlay & render-path duplication

**15. ~~EmojiAtlasBatcher's `_normalize_emoji()` diverges from canonical `EmojiUtil.normalize()` on the atlas/render lookup path~~**
**CLOSED (consolidation P3, 2026-08-03): unified onto `EmojiUtil.normalize`, probe-verified.** A probe over the full emoji universe (every string in biomes.json + factions.json + icons.json, 254 candidates) plus a repo-wide grep of GDScript sources found **zero** ZWJ (U+200D) and **zero** FE0E carriers — the two schemes produce byte-identical atlas keys over the entire actual domain, so the delegation is behavior-preserving, not a blind swap. `_normalize_emoji` now delegates, with the history + probe documented in a comment at the function. *(Evidence note, 2026-08-04: the "zero ZWJ" claim is stale against today's registry — `Assets/emoji_registry.json` carries two ZWJ keys (🏋‍♀, 👨‍💻) plus keycap sequences. Both schemes still agree on them, so the CONCLUSION stands; only the stated probe scope aged.)*

~~**16. BubbleAtlasBatcher and EmojiAtlasBatcher independently implement the same textured-quad batching, already diverged in optimization**~~
**CLOSED-SCOPED (fable push 2026-08-03, ff14826f):** the flush divergence (the real defect) is unified — EmojiAtlasBatcher adopts the pre-allocated identity-indices strategy, killing the per-frame N-int fill loop. The per-quad append bodies stay DELIBERATELY forked (documented in-code): a shared per-quad call adds GDScript call overhead on the hottest render path for cosmetic dedup.
`Core/Visualization/BubbleAtlasBatcher.gd:464-489` vs `Core/Visualization/EmojiAtlasBatcher.gd:535-570` (quad/UV/triangle push); flush() diverges: `BubbleAtlasBatcher.gd:657-677` pre-allocates the index array, `EmojiAtlasBatcher.gd:618-640` still builds one with a GDScript loop every flush.
Knot: hot per-frame render path — needs a shared base/helper decision, not a copy-paste port.

~~**17. Six Surface overlays each hand-roll their own tab-row builder/refresher**~~
**CLOSED for the frame-keyed four (fable push 2026-08-03, ff14826f):** Surface._build_frame_tab_row/_refresh_frame_tab_row; QuestBoard/Inspector/QubitAtlas/MapMeta delegate with pinned styling; QuestBoard's hand-rolled click handler retired for ClickWire. ControlsOverlay/EscapeMenu key off LOCAL ENUMS — their enum→frame_id reconcile is a real refactor, deliberately left (documented in the helper).
`UI/Overlays/QuestBoard.gd:184-197,580-593`, `InspectorOverlay.gd:151-180`, `ControlsOverlay.gd:210-222,267-291`, `EscapeMenu.gd:191-206,326-341`, `MapMetaOverlay.gd:188-199,552-566`, `QubitAtlasOverlay.gd:174-186,206-221` against base `UI/Core/Surface.gd`. Four key off `frame_id`; ControlsOverlay/EscapeMenu key off a separate local `tab` enum.
Knot: migrating the frame-keyed four is mostly mechanical; ControlsOverlay/EscapeMenu's local enum needs reconciling with `frame_id` first.

~~**18. EscapeMenu hand-rolls ClickWire-equivalent click detection for its tab row, entangled with a pending-confirmation guard**~~
**CLOSED (fable push 2026-08-03, e3b51de5):** migrated to ClickWire.attach with the pending-confirm guard inside the callback. The ordering question is RESOLVED: ClickWire consumes the release before the callback, so a mid-confirm click dies at the guard instead of leaking to viewport unhandled-input — strictly tighter modality (same direction as the #231 tap-pierce fixes).
`UI/Overlays/EscapeMenu.gd:191-206` (manual mouse_filter/connect instead of `UI/Core/ClickWire.gd:22-27`'s `ClickWire.attach`), `_on_tab_label_gui_input` (209-214) checks `_pending_action != PendingAction.NONE` *before* the event filter and before `accept_event()`; `_show_tab()` (1286) never re-checks the guard.
Knot: `ClickWire.attach` always calls `accept_event()` before invoking its callback — a naive migration changes whether clicks propagate while a confirm modal is showing; needs verification of whether that ordering is load-bearing.

**19. ~~Small overlay-chrome helpers copy-pasted across 4-5 overlay files instead of extending UIStyleFactory~~**
**CLOSED (consolidation P3, 2026-08-03): extracted to `UI/Core/OverlayChrome.gd`.** One static builder family (`key_chip`/`muted_label`/`spacer`/`ratio_bar`/`empty_row`/`kv_row`), parameterized so every overlay keeps its EXACT historical styling; each overlay's local `_make_*` became a one-line delegate pinning its params (QuestBoard chip 14px/28w with selected/empty colors; MapMeta chip on its local axis palette + its 0.9-alpha muted; EscapeMenu's no-autowrap kv value; QuestBoard's no-autowrap muted; `_comfort_bar` = `ratio_bar(absf(c))`). Also folded `InspectorOverlay._map_make_spacer`. **Deliberately NOT migrated** (ruled load-bearing forks, documented in OverlayChrome's header): tab-row builders (knot #17 — ControlsOverlay/EscapeMenu key off local enums), EscapeMenu tab click handling (knot #18 — pending-confirm guard ordering), overlay open/close/input-swallow wiring (per-overlay, z-order/input regression history #197/#243), and BiomeInspectorOverlay's genuinely-variant `_make_kv_row`/`_make_ratio_bar` (different geometry/fallbacks). Knots #17/#18/#20 remain open.

~~**20. Overlay-instantiation boilerplate repeated ~9× in OverlayManager**~~
**CLOSED-SCOPED (fable push 2026-08-03, e3b51de5):** the six UNIFORM sites route through _spawn_registered_overlay (exact historical order pinned; welcome opts out of visibility processing). The three sites with interleaved signal wiring (quest_board/escape_menu/biome_inspector) stay verbatim on purpose — connect-vs-add_child order is load-bearing (#197/#243). IconDetailPanel's site was deleted with the panel (knot #22).
`UI/Managers/OverlayManager.gd` — quest_board (151-165), escape_menu (170-181), biome_inspector (186-191), icon_detail_panel (194-199), inspector_overlay (270-276), controls_overlay (279-285), welcome_overlay (288-293), atlas_overlay (296-302), map_meta_overlay (313-318), neighborhood_graph_overlay (323-328).
Knot: each site interleaves unique extra signal wiring mid-sequence — a blind extract-method risks reordering signal connections relative to add_child/registration.

~~**21. BroadGraphView and NeighborhoodGraphView duplicate GraphEdit setup, node-clearing safety dance, and ring-layout math**~~
**CLOSED (fable push 2026-08-03, e3b51de5):** `UI/Overlays/GraphViewCommon.gd` static composition helpers (setup, the GraphNode-only clear dance with its connection_layer/remove-before-free safety comments now in ONE place, ring layout, shared COLOR_ENTANGLE); both views delegate, per-view geometry pinned as args.
`UI/Overlays/BroadGraphView.gd` — `_init()`, `populate()` (45-54), `_layout_pos` (163-169) — vs `UI/Overlays/NeighborhoodGraphView.gd` — `populate()` (59-69), `_layout_pos` (203-209); both independently declare `COLOR_ENTANGLE := Color(1.0, 0.84, 0.25)`.
Knot: both are on the render path for live overlays (M · Graph, 🕸 NeighborhoodGraphOverlay); extraction needs a class-hierarchy decision.

~~**22. IconDetailPanel is fully wired into boot but its only content entry point is unreachable**~~
**CLOSED (fable push 2026-08-03, e7a0b796): deleted** (owner-approved). Scene grep confirmed no .tscn/dynamic reference; panel + OverlayManager wiring + .uid removed; class cache re-imported clean.
`UI/Managers/OverlayManager.gd:194-199` instantiates it every boot; `UI/Widgets/IconDetailPanel.gd:99` (`show_icon()`) has zero call sites anywhere in the repo — the live flow runs through `IconCard.gather()` instead.
Knot: confirm no `.tscn`-level dynamic wiring reaches it before deleting the class and its OverlayManager wiring.

~~**23. `_log(level, category, emoji, message)` VerboseHelper wrapper copy-pasted 5×, with a 6th copy silently diverging**~~
**CLOSED (fable push 2026-08-03, ce92faa0):** GameStateSerializer's diverging copy routed through VerboseHelper (its silent no-op-if-unset is gone — save/load diagnostics now fall back loud); GameStateManager's set_verbose plumbing removed. The five 2-line wrappers already delegate to the single authority — they ARE the post-dedup state, left as-is.
`Core/QuantumSubstrate/QuantumComputer.gd:19-20`, `Core/Instrumentation/QuantumInstrument.gd:2264-2265`, `Core/Actions/ProbeActions.gd:1235-1236`, `Core/GameMechanics/BasePlot.gd:20-21`, `Core/Environment/BiomeEvolutionBatcher.gd:13-14` all delegate to `Core/Config/VerboseHelper.gd`. `Core/GameState/GameStateSerializer.gd:16-18` instead does `if _verbose and _verbose.has_method(...)`, silently no-op'ing if `set_verbose()` was never called.
Knot: fixing the 5 copies is mechanical; changing GameStateSerializer's behavior touches observable diagnostics on the save/load path and needs sign-off.

#### Tier 5 — Tooling & build scripts

~~**24. Godot-binary resolution reimplemented independently in at least 5 places**~~
**CLOSED (consolidation pass 2026-08-03, P2b):** every script that locates a godot binary now
sources `scripts/lib/godot_runtime_env.sh` and resolves through `sw_godot_bin()` —
`run_tests.sh` (finally honors `GODOT_BIN`; legacy `godot4` fallback kept),
`run_save_load_tests.sh` (`GODOT_PATH` still wins for back-compat),
`build-web-local.sh`, `build-desktop-local.sh`, `install-godot-export-templates.sh`
(`--godot-bin` CLI flag still overrides), `setup.sh`, `setup-vm-cross-compile.sh`, and the
three cognifold launchers (`cognifold.sh`, `cognifold-meerkat.sh`, `cognifold-bar.sh`).
Since `sw_godot_bin()` defaults to `SW_GODOT_BIN` → `GODOT_BIN` → `godot`, each caller's prior
env-override semantics are preserved exactly; all touched scripts pass `bash -n`.

~~**25. `milk_hunt_args.make_base_parser()` is a documented shared argparse base, but two consumers hand-duplicate the same flags with drift**~~
**CLOSED (fable push 2026-08-03, 854f7ce8):** runner + seed_save build on make_base_parser via only=/overrides= hooks; every local divergence kept (--strategy stays Path; seed_save's missing counterpart flag stays missing per this knot's text). Parser-surface dump byte-identical before/after.
`🍄/🎛️/milk_hunt_args.py:14-118` (`make_base_parser`, only used by `milk_hunt_batch.py`) vs `🍄/🎛️/milk_hunt_runner.py:1070-1256+` (`_build_parser`, e.g. `--strategy` typed `Path` vs `str` in the shared parser) and `🍄/🎛️/milk_hunt_seed_save.py:66-144` (`_build_parser`, missing the `--no-reuse-listener` counterpart flag).
Knot: migrating requires reconciling type/default/counterpart-flag mismatches per divergence, not a blind swap.

~~**26. `constants.py`'s policy-mode/timeout constants bypassed almost everywhere; two live modules compute divergent timeout formulas**~~
**CLOSED (fable push 2026-08-03, 854f7ce8):** policy strings import from constants everywhere; the divergent timeout FORMULAS live in constants as NAMED per-caller variants (zero behavior change, one home); constants for long-deleted files removed with zero consumers verified.
`🍄/🎛️/constants.py:12-33` (`run_timeout`, references files that no longer exist); policy-mode strings hardcoded independently at `milk_hunt_args.py:70`, `milk_hunt_seed_save.py:74`, `milk_hunt_runner.py:1122,1685,2057`; timeout formulas diverge — `milk_hunt_runner.py:1613` hardcodes `max_loops=140` and never imports constants, `milk_hunt_batch.py:417` computes `max(120, max_loops*15+120)` inline vs constants' `max(300, max_cycles*30*runs)`.
Knot: the policy-string swap is low-risk, but picking one real timeout formula (15s vs 30s/loop, 120s vs 300s floor) changes subprocess timeout behavior on the batch-run hot path.

**27. `run_executor.py`'s command-builder API is dead, and duplicates (stale) what `milk_hunt_batch.py` hand-rolls inline**
`🍄/🎛️/run_executor.py:122-289` (`build_seed_cmd`/`build_runner_cmd`/`build_batch_cmd`/`run_seed`/`run_batch`/`run_runner`, zero call sites repo-wide) vs `🍄/🎛️/milk_hunt_batch.py:359-417` (`_run_trial`, ~25 conditional `cmd.extend()`/`append()` calls covering flags the builders don't know about).
Knot: either delete the unused surface or bring it to full flag parity with `_run_trial` and switch callers over — the latter touches the hot batch-run path.

**28. ~~Icon-lexicon tooling trio operates on a biome-level `icons[]` field that no longer exists in the data~~**
**PARTIALLY CLOSED (consolidation P3, 2026-08-03): verdict OBSOLETE, not regression — tool + artifact deleted.** Git archaeology: per-biome `icons[]` left biomes.json in commit `2b72ac19` (2026-05-30, "de-iconed biomes") — a *deliberate* migration that in the same commit created the faction-side icon authority (`Core/Factions/data/icons.json` 367 entries, `IconRegistry`/`IconFamily`/`IconLoadoutInducer`, cutover smoke tests) and grew biomes 60→162 all authored bare; all 102 factions now carry `icons`. `build_icon_lexicon.py` + `gen_biome_icon_stubs.py` + `validate_icon_lexicon.py` + `icon_lexicon_proposals.json` were all *added by that same commit* as its one-shot migration scaffolding (the tool's own docstring: cross-reference biome icons[] to seed factions.json), never invoked by CI/scripts, never meaningfully touched since. Deleted this pass: `tools/build_icon_lexicon.py` and the frozen artifact `tools/icon_lexicon_proposals.json` (the two explicitly named for removal). Still present, same-verdict, awaiting explicit naming: `tools/gen_biome_icon_stubs.py`, `tools/validate_icon_lexicon.py`. Stale-comment note: `tests/test_architecture_hygiene.py:45` mentions build_icon_lexicon.py in a comment ("which exists, outside the scan roots") — comment-only, no assertion depends on it, left untouched (tests/ owned by a concurrent pass).

#### Tier 6 — Test infrastructure

~~**29. RigClient boot/teardown harness hand-rolled in 7 pytest integration tests**~~
**CLOSED (consolidation pass 2026-08-03, P2b):** `tests/conftest.py` now carries a `rig_boot`
factory fixture — godot-on-PATH skip, tempdir, `start_listener(**kwargs)`, sentinel wait, and
guaranteed `terminate_listener` + `rmtree` teardown (pass or fail) for every listener booted
through it. Parameter surface: `prefix`, `sentinel_timeout_s`, and everything else passed
straight to `start_listener`, so per-test scenario/env divergence stays in the test. All 7
files migrated (both import styles deleted); full suite 182 passed / 0 failed after migration.

~~**30. Byte-identical `setup_test_environment()` bootstrap duplicated across 2 of 4 gate/quantum-state tests**~~
**CLOSED (fable push 2026-08-03, ff14826f):** SubstrateFixtures.build_test_biome (static coroutine — the feared pattern works; the trap was class_name resolution under -s harness timing, solved by the fixtures file's own preload-by-path rule). The two genuine variants stay local as prescribed.
`tests/test_advanced_quantum_states.gd:46-66` and `tests/test_gate_exact_states.gd:45-65` are byte-identical (`BiomeBuilder.build_from_registry("StarterForest", ...)` → `await self.process_frame` → density-matrix check). `tests/test_gate_application_integration.gd:42-75` and `tests/test_closed_system.gd:48-75` are genuine variants (different biome names, extra closed-system precheck) — not duplicates.
Knot: extracting even the safe 2-file subset requires a new async static-coroutine test-fixture pattern with no existing precedent in `tests/substrate_fixtures.gd` — needs a run-and-verify pass in Godot, not a text move.

**31. Four dead, unreferenced GDScript test harnesses reimplement the same "quest completion nukes the pool" check**
`tests/SimplifiedQuestBoardTest.gd`, `tests/QuestBoardTestDriver.gd`, `tests/QuestBoardRealTest.gd`, `tests/AutoQuestBoardTest.gd`, `tests/MockQuestManager.gd` + 4 matching `.tscn` scenes — added together in commit `f20998fa` (2026-01-28), untouched since, referenced by no test runner.
Knot: safe action depends on whether the underlying invariant is covered live elsewhere; if not, `QuestBoardRealTest.gd`'s assertions need porting into the maintained suite before the rest can be deleted.

#### Tier 7 — Documentation drift

**32. ~~README.md's core-loop key bindings contradict the game's own canonical Ace-hat table~~**
**CLOSED (consolidation P3, 2026-08-03): README rewritten to match reality.** Verified against `UI/Core/KEYBOARD_GRAMMAR.md:160-162,298` (live grammar: R=Strike/measure costs 👥, Q=Extract free cash-out, E=Pause, F=Explore/Fast-Fwd), which agrees with GAME_CODEX/HOW_TO_PLAY/ARCHETYPE_FRAMES. README's core-loop steps 1-2 now read Strike (Ace R, with F=Explore noted) and Extract (Ace Q, free); README:80's hat table was already correct.

~~**33. Three docs maintain separate, partially-diverging Linux build prerequisites**~~
**CLOSED (fable push 2026-08-03, ce92faa0): no merge — cross-linked owners.** BUILDING.md owns the scons/godot-cpp path, docs/build/BUILD_LINUX.md owns the prebuilt-Godot Makefile path; each names the other and says the package-list divergence is intent, not drift.
`BUILDING.md:16,44` and `docs/release/RELEASE_README.md:106` agree (`build-essential git python3 python3-pip scons`); `docs/build/BUILD_LINUX.md:11` genuinely differs (`git g++ make wget unzip`, no python3/scons) because it documents a different build path (prebuilt Godot + native/ Makefile-only).
Knot: the two package lists serve two legitimately different build paths — needs a canonical-owner-per-path decision plus cross-links, not a merge into one list.

#### Tier 8 — Dead code / unmerged proposals (lowest live risk; blocked on explicit human deletion approval)

~~**34. Assets/UI/Elements/ holds six SVG icons that are byte-identical, unreferenced duplicates**~~
**CLOSED (`710fef51`, "Slop patrol tier 8: delete confirmed dead/duplicate files").** Doc-hygiene
correction (scout pass, 2026-08-03): re-verified on disk — the 12 files
(`Assets/UI/Elements/{Decay,Forest,Seedling,Vegetation,Moon,Sun}.svg` + `.svg.import`) are gone;
`Elements/Fire.svg`, `Water.svg`, `Wind.svg`, `Wolf.svg`, `Rabbit.svg` remain, untouched. This
was already done before this doc's Tier 8 section was last read as still-open — never struck
through.

~~**35. `🍄/🛠️/📥.py` and `📥_retry.py` are dead legacy emoji-SVG downloaders fully superseded by `sync_emoji_pipeline.py`**~~
**CLOSED (`710fef51`).** Re-verified: neither file exists in the working tree; the only
remaining hits are inside two now-pruned `.claude/worktrees/agent-*` copies (unrelated to this
repo's history) and this doc's own text.

**36. Two sibling native-engine proposals in the same handoff bundle independently redefine AxialField/FactionField/IconEdge with incompatible math**
`llm_inbox/spacewheat_quantum_graph_handoff_bundle/spacewheat_native_quantum_graph_seed/src/axial_manifold.cpp:117-129` (`blend`, circular-mean phase via cos/sin) vs `.../spacewheat_contract_market_native_seed/src/axial_field.cpp` (`blend_fields`, plain weighted linear sum of phase); both bundles' own `QUANTUM_GRAPH_UNIFICATION_NOTE.md` and `README.md` call for these to become one engine.
Knot: unbuilt inbox proposal material, never merged into the live engine — flagged for the umwelt/quantum-graph owner to resolve the math disagreement if either seed is picked up, not an active risk today.
---

## 3D mode (post-668fe7a4) — polish pass 2026-08-04 residue

The 3D cognifold field became the default renderer AFTER this doc's sweep; the 2026-08-04
polish pass fixed the acute defects (selection truth, honest gate refusals, play-area
centring, emoji glyph pipeline, B/pause contract restoration — commits c290cb74…f1368940)
and leaves these documented, deliberately-deferred items:

**37. Emoji atlas is never built in 3D mode, and never rebuilt when a fractal child biome registers**
`Core/Boot/RuntimeMount.gd` early-returns before `build_atlas_cached` when quantum_viz is
null (3D). Harmless today — no 3D consumer reads the atlas — but `--classic-2d` and 3D take
fully divergent glyph paths, and in 2D mode a descend into a fractal child whose poles
weren't in the boot universe falls to `_draw_text_box` (bordered tofu). Related ceiling:
`EmojiAtlasBatcher` caps at 961 glyphs (2048² / 66²) then warns + skips. All latent, 2D-only.

**38. The gate-pricing seam exists but nothing calls it**
`FarmEconomy.preflight_gate`/`commit_gate` (and `EconomyConstants` twins) have ZERO gameplay
callers — the Druid path charges via `action_costs`. The lying `gate_costs` price rows were
deleted from `default.jsonl` (P2, gates are now HONESTLY free); wiring the seam into gate
dispatch — i.e. whether gates should cost anything — is an owner balance decision.

**39. QII writes selection state past QuantumInstrument.select_plot()**
`QuantumInstrumentInput._focus_plot` writes `_instrument.current_plot_idx` and friends
directly while `QuantumInstrument.select_plot()` sits unused — a parallel-authority smell,
behavior-identical today. Route the write through the API when next in that seam.

**40. rig_bubble_state reports measured:false unconditionally**
`QuantumField3D.rig_bubble_state` doesn't track terminal-measured state (known follow-up,
noted in-code); the rig reads authoritative measured state from the farm separately.

**41. PlotGridDisplay touch-drag TODO + orphaned `[` overlay**
Godot-4 touch drag selection is still a stub (`PlotGridDisplay._input` TODO), and the
neighborhood-graph overlay is reachable only by the literal `[` key — no button-row slot.
