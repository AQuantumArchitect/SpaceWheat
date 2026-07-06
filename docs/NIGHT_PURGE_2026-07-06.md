# Night shift report — 2026-07-06

Owner mandate: extract the disk-thrash and GDScript-fallback diseases at the root
("if the game doesn't work with the native engine, the game should not work at
all"), then DRY the codebase aggressively — "cut off every piece of this statue
that isn't David."

## 1. The fps bug that started it (evening, commit 151ec86a)

The Windows build's 1–2 fps was **not Windows** — Linux reproduced it exactly.
`QuantumForceGraph` recomputed quantum mutual information (partial traces + three
von Neumann entropies, in GDScript) for every bubble pair every frame: ~610 ms/frame
with 9 bubbles. The C++ engine already computes MI per step and publishes it to
`viz_cache`; the force loop now reads that. 1–2 fps → 40+ on the WSL box (residual
is WSLg overhead). New rig diagnostics made the hunt a 3-step bisection: `perf`,
`toggle_process`, and three probes (`perf_probe`, `perf_bisect_probe`, `perf_stage_probe`).

## 2. Native engine is now the ONLY physics authority (31ab4643)

- **BootManager gate**: missing native class → error dialog + `quit(1)`. No limping.
- **Deleted** the GDScript evolution kernel (`evolve()`, exact-unitary + Euler paths,
  propagator cache, phase-LNN), the MI/entropy recompute stack, the sparse-operator
  layer, the stepper's `run_direct_biome_cycle` fallback, BiomeBase's un-batched
  per-biome evolution loop, ProbeActions' manual fast-forward, and the
  dead-in-practice BiomeDynamicsTracker subsystem. (~900 LOC of shadow physics.)
- The native `QuantumEvolutionEngine` implements both regimes (exact unitary when
  `can_unitary()`, Lindblad Euler otherwise) — every GDScript twin was a silent
  fallback that let a broken build run at seconds-per-frame.

## 3. Disk-thrash can't return

- Audit: zero per-tick writers remain anywhere (GDScript + C++). OperatorCache/
  BundledCache: no code references, no dir.
- VerboseConfig's opt-in file log: hard 50 MB cap. Rig results.jsonl: truncated at
  boot if a stale file exceeds 10 MB.
- **`tests/test_no_thrash_no_fallback.py`** — the ratchet: every FileAccess-WRITE
  file must be in a reviewed whitelist; cache references, GDScript kernel symbols,
  and boot-gate removal all fail the suite.

## 4. DRY / de-slop (9f06a785, a6ad8c59, 5f728b13)

- `Core/Quests/PredicateGloss.gd`: ONE authority for predicate glosses + gate
  glyphs (two drifting copies deleted; QuestBoard now shows real fire targets).
- QuantumRigorConfig system deleted (386 LOC of UI for "NOT IMPLEMENTED" knobs
  that rendered nothing and warned twice per boot).
- Verified dead-method cull: 722 LOC across 8 core files, each with grep evidence
  (incl. rig dynamic dispatch and native/src); survivors documented.
- `Tests/` graveyard (~500 untracked legacy scripts) removed; 265 tracked probe
  screenshots untracked; dead ActionIds constants dropped.
- Total: **~2,200 LOC of slop removed** this night on top of the physics purge.

## 5. Proof (the part that matters)

- Suite: **111/111** (incl. the new ratchets). Boot gate 0. Live farm 40+ fps.
- **Full campaign, one fresh boot, keyboard-only, through the purged engine:
  36/36 flags** — first_breath → the_door_stays_open, including the political
  finale (ledger_opens → empire_imposes → island_free) and the entire wet-country
  chain (crossing/gray/span/watching/verbs/contract/basin/chain-tested/hiding/
  braid/fusion/rite/door). Zero errors. Matches the 2026-07-05 victory run.
- Run 1 of the campaign exposed a **drive** flake (not physics): the vi loop's
  all-sites incorporate ripens nothing on rigid-H biomes → signature pinned at
  the soft-gate center → wet country unreachable. Fixed with a one-site fallback
  (the farm_berries lesson); run 2 was the 36/36.

## 6. Shipped

- All commits pushed to origin (`151ec86a..6e02d800`).
- Fresh Windows build (with the fps fix + purge) deployed to
  `C:\Games\🌾🚀🌌SpaceWheat` — this is the build to playtest.

## Open items

- Owner to report native Windows in-farm fps (expect ≥40, likely 60; the WSL
  measurement floor is WSLg-bound).
- B6 quest-system unification (task #148) remains the one big pending feature.
- itch.io publish still needs the owner's BUTLER_API_KEY.
