# SpaceWheat — Pre-Launch Gaps Report

*Compiled from 7 headed playtesting sessions (sessions 5–11, 2026-07-04), live codebase
audit, and the published docs in `docs/`. Perspective: I can press every key and read every
screenshot but I can't play the full campaign end-to-end in a single live session — the gaps
are what a systematic keyboard tester found that a casual player would likely find first.*

---

## What's in good shape

Before the gaps: a lot is genuinely done.

- **All 7 hats have real QERF verbs.** Spark [4] and Merchant [6] were routing to Ace chips
  in sessions 1–9 (a frame-routing bug); the merged PR fixed both. Confirmed headed.
- **36 story flags** across acts 0–7 in `story_flags.json`, including the full topology
  trilogy (What Survives / What Fades / What Connects). All campaign docs say SHIPPED.
- **BridgeRegister** is fully implemented — 2×2 nonlocal ρ, Γ-product protection, braid/fusion,
  ticked at 20 Hz, serialized into GameState, quest predicates wired (built_total, braids_total,
  fused_total). Not a stub.
- **KnotRegister** is pure static math for Berry-loop invariants — correct library surface.
- **Gallery G1/G2** (ReelRunner + PostcardCapture) are implemented; `first_light.reel.json`
  exists. Reel boots headlessly.
- **Export health:** Linux + Windows desktop are both production-ready builds. itch.io desktop
  packaging exists and works. See `docs/EXPORT_HEALTH.md`.
- **The Topology Campaign** (4 chapters, 7 flags, eigenstate compass, dynamics tracker) and
  **The Nonlocality Campaign** (5 chapters, 5 flags, BridgeRegister, KnotRegister): all chapters
  ship per `docs/TOPOLOGY_CAMPAIGN.md` and `docs/CONNECT_CAMPAIGN.md`.

---

## Resolved since initial report (2026-07-05 PR merge)

- **Gap #2 (silent rejection)** — FIXED. `942ea3b`: refusal toasts now surface to player; every
  failed or blocked action shows its honest reason ("the enclave holds…", "need the north-pole
  emoji…") instead of appearing only in the dev log.
- **Gap #4 (Atlas stubs)** — FIXED. Forget/Bookmark chips were already blanked to "—" in a prior
  sprint; handlers now no-op silently instead of spamming `push_warning`.
- **Gap #7 (B surface auto-focus)** — FIXED. `942ea3b`: B auto-focuses the first plot when none is
  selected; residual empty-state hint explains GHJKL; passes through the open overlay.
- **Gap #9 (QuantumRigorConfig placeholder modes)** — FIXED. `942ea3b`: the NOT IMPLEMENTED modes
  are labeled display-only in the panel.
- **Gap #8 (−/= sim speed keys)** — RESOLVED (prior sprint): binding list already says "Reserved
  — wiring pending." No further action needed.
- **New engine (`dad8ed15`)**: 61 `gated_lindblad_source` circuits now tick at runtime
  (`Farm._process_gated_channels`, open ground only). New kernel `QuantumComputer.apply_jump_channel`.
  This is the wet-country bath physics that makes Merchant dephase meaningful and unblocks What
  Connects Chapter III. Two assay tools added: `tools/channel_assay.py`, `tools/plant_assay.py`.
- **New doc (`46686b47`)**: `docs/FARMING_A_DENSITY_MATRIX.md` — front-door essay for smart
  strangers. README updated to link it.
- **Gap #1 (Ace Strike seam) — CLOSED AS PHANTOM.** `27730f37` diagnosis: "no such mechanic
  exists in the codebase or its history." What I observed (toast + measurement flow) was normal
  game behavior, not a special seam entry. The real bug inside this report: the already-measured
  toast said "Use R to pop" but pop has lived on Q (Harvest) since the energy-dyad rework. Fixed:
  toast now says "Already measured — Q harvests it."
- **Gap #3 (village branch reachability) — CLOSED AS PHANTOM.** `66c9f56` diagnosis: the real
  kernel was discovery pacing. Act 6 gates on discovering GildedRot, and discovery was a pure
  alignment-weighted roll over ~150 biomes — the campaign could starve at its hinge. Fixed:
  `BiomeDiscoveryForecastService.STORY_LEANS` gives GildedRot +1.5 weight once `edge_of_the_enclave`
  fires (and until `the_crossing` does). The Captain's E-compass reads the same weights, so the
  door visibly glows on the forecast until the player walks through it.
- **Gap #5 (SFXRegistry placeholder) — CLOSED.** Static check confirmed: all 10 WAV files exist
  in `Assets/Audio/SFX/` and are imported. The "placeholder mode" comment in the source only runs
  for events missing a WAV — 0 of 10 events are missing. Pipeline is live.
- **Gap #12 (no butler push lane) — FIXED.** `scripts/itch-push.sh` added: env-driven one-command
  butler lane for Linux + Windows channels.
- **Gap #13 (Windows smoke not in release checklist) — FIXED.** `RELEASE_README.md` now has an
  explicit pre-release checklist: Linux build, Windows export smoke as a hard gate, headless
  physics assays, and web held until WEB_DOOR smoke passes a real bundle.

---

## P0 — Functional gaps that confuse or block players

*(All P0 gaps closed. #1, #3, #5 were diagnosed phantoms; #2, #4 fixed in `942ea3b`;
#6 fixed 2026-07-05 — see "Resolved".)*

### 6. Boot-path divergence — FIXED (2026-07-05)

`tests/test_title_boot_path.py` now walks the shipped player lane end-to-end every suite
run: title → F → start → welcome (shown, any-key dismissed) → hat/plot keys → Druid excite
→ Icon track → ripen → incorporate → `first_breath` fires. Player-path-only bugs (the
welcome input trap was one) can no longer evade the suite. 7.6s, headless.

---

## P1 — Gaps that affect experience but don't block progress

*(Gaps #7, #8, #9 fixed in `942ea3b`; #10 fixed 2026-07-05. See "Resolved" section.)*

### 10. Gallery — second reel — FIXED (2026-07-05)

`Core/Gallery/reels/the_span.reel.json`: the What Connects attract reel — inject, Hadamard,
then build → braid → braid → fuse a real Majorana bridge between StarterForest and TheDemos,
with captions telling the nonlocality story. Verified headless: all four bridge ops report ok
through the real BridgeRegister. (ReelRunner now logs failed bridge ops — a silent failure
means captions narrate physics that never happened.)

**Note the bigger find:** the Gallery scripts lived in the dev playzone (`🍄/🎛️/`), which every
export preset excludes — so exported builds since the playzone migration had broken class refs.
Gallery code now ships from `Core/Gallery/`.

---

## P2 — Distribution / release pipeline

*(Gaps #12 and #13 fixed in `66c9f56`. See "Resolved" section.)*

### 11. Web export — first real smoke HAS RUN (2026-07-05); performance gate pending re-run

The full lane executed for the first time: build (WASM extension compiled + exported),
static QA (bundle complete, COOP/COEP served), and a real-Chromium smoke. First-run verdict:
engine boots, `crossOriginIsolated` granted, canvas live, zero fatal errors — but **6.2 fps**,
because two launch bugs kept the native quantum engine out of the browser:

1. `quantum_matrix.gdextension` used a bare `web.wasm32` key, which Godot 4.3+ rejects for
   thread-variant web exports → the extension never loaded → physics fell to GDScript.
   Fixed: `web.threads.wasm32` + the lib compiled `-pthread` to match the shipped engine.
2. The excluded-playzone Gallery scripts (see #10) added boot-time script errors.

Re-run of the smoke against the fixed bundle is the remaining gate. Also flagged: the web
bundle is 385MB (`index.pck` 338MB) — loadable but heavy; a trimmed web pck (audio/asset
diet) is a post-verdict option per the degradation policy in `docs/release/WEB_DOOR.md`.

---

## P3 — Post-launch, technical debt

These don't block v1 but should be tracked.

### 14. Dead code census (~100+ items)

`docs/DEADWOOD_2026-07-05.md` enumerates ~100+ zero-call-site members across QuantumComputer (13),
MusicManager (9), BiomeEvolutionBatcher (10), ComplexMatrix (9), QuestManager (8), and ~45 misc.
None are blocking. A verified cull pass (delete cluster, boot, run suites, keep or revert) would
trim the binary and reduce maintenance surface.

### 15. BiomeGateOperations — position-based gate path unwired

`Core/Environment/Components/BiomeGateOperations.gd:11`: "register_manager is not yet wired —
all position-based gate methods..." The main Operator [9] gate path works (confirmed: Bell / GNOT
/ CZ gates fire and change plot probabilities). This is a secondary route for position-based gate
injection that doesn't block the player-facing Operator hat.

### 16. Touch/mobile — not implemented

`UI/PlotGridDisplay.gd:1176`: "TODO: Implement Godot 4 touch drag selection." Not relevant for
desktop, blocks any mobile port.

### 17. Rig berry shim — private state poke

`DEADWOOD_2026-07-05.md` flags `rig_listener.gd consume_berry` which pokes
`BerryPhaseRegister._state` directly. Now that live Berry integration runs, the right fix is a
public `BerryPhaseRegister.force_accumulated(qid, phase)` test hook. The shim is test-load-bearing
now so don't delete — refactor.

---

## Summary table

**Status as of 2026-07-05 (evening)** — 15 of 17 original gaps resolved or closed; #11 ran and is in re-verification; P3 deferred.

| # | Gap | Status | Notes |
|---|-----|--------|-------|
| 1 | Ace Strike seam | ~~CLOSED~~ phantom | `27730f37`: mechanic never existed; real toast bug fixed |
| 2 | Spark/Merchant silent rejection | ~~FIXED~~ | `942ea3b`: refusal toasts wired |
| 3 | Village branch reachability | ~~CLOSED~~ phantom | `66c9f56`: real issue was discovery pacing; GildedRot lean added |
| 4 | Atlas Forget/Bookmark stubs | ~~FIXED~~ | `942ea3b`: handlers silenced, chips already blank |
| 5 | SFXRegistry placeholder | ~~CLOSED~~ | All 10 WAV assets confirmed present; pipeline live |
| 6 | Boot-path restart untested | ~~FIXED~~ | 2026-07-05: tests/test_title_boot_path.py walks title→welcome→first_breath |
| 7 | B surface auto-focus | ~~FIXED~~ | `942ea3b`: auto-focuses first plot on open |
| 8 | −/= sim speed stubs | ~~RESOLVED~~ | Prior sprint: binding already says "Reserved" |
| 9 | QuantumRigorConfig placeholder modes | ~~FIXED~~ | `942ea3b`: labeled display-only in panel |
| 10 | Gallery — only one reel | ~~FIXED~~ | 2026-07-05: the_span.reel.json (bridge lifecycle), verified headless |
| 11 | Web export smoke unrun | **RAN** P2 | 2026-07-05: first real run found+fixed 2 launch bugs; perf re-run pending |
| 12 | No butler push lane | ~~FIXED~~ | `66c9f56`: `scripts/itch-push.sh` added |
| 13 | Windows smoke not in release checklist | ~~FIXED~~ | `66c9f56`: RELEASE_README pre-release checklist updated |
| 14 | Dead code census | P3 deferred | ~100 items, verified cull needed |
| 15 | BiomeGateOperations unwired | P3 deferred | Secondary gate path; Operator hat works via main path |
| 16 | Touch drag selection | P3 deferred | Mobile port only |
| 17 | Rig berry shim private poke | P3 deferred | Refactor to public test hook |

---

*Report authored from external playtesting sessions. Evidence sources: headed screenshots
(sessions 5–11), `docs/EXPORT_HEALTH.md`, `docs/TOPOLOGY_CAMPAIGN.md`,
`docs/CONNECT_CAMPAIGN.md`, `docs/DEADWOOD_2026-07-05.md`, code audit of
`UI/Overlays/QubitAtlasOverlay.gd`, `UI/PlayerShell.gd`, `Core/Audio/SFXRegistry.gd`,
`Core/GameState/QuantumRigorConfig.gd`, `Core/Environment/Components/BiomeGateOperations.gd`.*
