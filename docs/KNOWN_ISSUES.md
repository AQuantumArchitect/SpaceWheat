# Known Issues

A published, honest list of what's open, instead of a growing internal
backlog nobody outside the repo reads. This is the right shape for an
Early-Access-style release: ship with a stated roadmap, not silence.

Sourced from `docs/history/2026-08-10_PLAYTEST_SWEEP.md`, `docs/design/MOUSE_PARITY_AUDIT.md`,
`docs/history/2026-07-29_SLOP_PATROL.md`, `docs/history/2026-08-04_CAMPAIGN_STATE.md`, and
`docs/performance/PROFILE_2026-08-16.md`. Each item links back to its source
doc for full context.

## Player-facing

- **The post-game is unfinished.** *What Fades* and *The Loom* open after the
  Demos ending and are playable in part; expect rough edges and acts that do
  not close yet. The game says so at the ending and in the campaign headers.

- **Unrevealed plots have no mouse click target under the default 3D
  renderer.** The Act-0 hint says "or just tap it," which is true for
  revealed plots but not empty ground. Needs a design call (ghost orbs for
  empty ground, re-show the 2D rack, or reword the hint) —
  `docs/history/2026-08-10_PLAYTEST_SWEEP.md`.
- **Three action chips read fully silent**: spark.R (act 6), operator.F
  (act 7), druid.F (act 8). Not yet confirmed real vs. a phantom (see the
  project's own precedent for that diagnosis in `docs/design/PRE_LAUNCH_GAPS.md`) —
  `docs/design/MOUSE_PARITY_AUDIT.md`, Wave 15.
- **Mouse-vs-keyboard refusal/toast text parity** has never been fully
  confirmed, open since Wave 2 of the mouse-parity audit —
  `docs/design/MOUSE_PARITY_AUDIT.md`.
- **The Act-7 gate `Tr(ρ²) ≥ 0.54` has no legible player-facing lever** —
  `docs/history/2026-08-10_PLAYTEST_SWEEP.md`.
- **Arc-offer queueing at the Act-4 fork** buries 4 quest offers behind one
  banner line, 12 pages deep — `docs/history/2026-08-10_PLAYTEST_SWEEP.md`.
- **Hat-key toggles (number row) have no visual affordance** for which hat
  is currently worn — a deliberate, still-open design question, not a bug —
  `docs/history/2026-08-10_PLAYTEST_SWEEP.md`.
- **Touch drag selection is unimplemented** (`UI/PlotGridDisplay.gd`) and the
  neighborhood-graph overlay is reachable only via the literal `[` key with
  no button-row slot. Mobile-port-only; not a desktop-blocking gap —
  `docs/history/2026-07-29_SLOP_PATROL.md` knot #41.

## Performance

- **The A2 frame-time target is not yet met.** p95 is 38.5ms against a
  <33ms target (worst-frame 63ms and 1%-low 22.4fps already clear their
  targets). Most of the remaining hitch time is still uninstrumented —
  this needs deeper profiling attribution before another fix attempt, not
  guessing. Don't advertise a specific late-game frame rate until this
  closes — `docs/performance/PROFILE_2026-08-16.md`.

## Web export

- **One rebuild-and-gate cycle is owed against current HEAD.** The two
  2026-08-14/15 web blockers (isolation-loader silence, Emscripten toolchain
  mismatch) are fixed and were verified twice in real Chromium, but a later
  same-day commit (`a8986d0`) touched native C++ again ("Web stays sync" per
  its own message — the change is desktop-only) without rebuilding the
  committed wasm. CI now runs `build-all-platforms.sh --web-only --clean` on
  every push touching `native/**`, so this should self-heal going forward —
  see `docs/release/WEB_DOOR.md` for full detail.

## Design questions (not bugs, need an owner decision)

- **`FarmEconomy.preflight_gate`/`commit_gate`** (and their `EconomyConstants`
  twins) have zero gameplay callers — gates are currently honestly free.
  Whether they should cost anything is a balance decision, not a bug —
  `docs/history/2026-07-29_SLOP_PATROL.md` knot #38.
- **Standing's "inert" status is repeatedly re-flagged as ambiguous** across
  audit passes even though it already feeds `PriceModel` pricing. This is an
  intentional, owner-accepted half-state; the ambiguity keeps resurfacing
  purely because nothing documents it as deliberate — one-line doc fix, not
  a code fix — `docs/history/2026-08-04_CAMPAIGN_STATE.md` §5 item 12.
- **`docs/design/STATE_VECTOR_PLAN.md`** (replacing the closed-system density matrix
  ρ with a pure state `|ψ⟩` behind a `QuantumState` interface) is fully
  scoped, five-stage migration planned, zero code written. No player-facing
  payoff on its own — owner call on whether/when to start it.

## Technical debt (dev-facing, low live risk)

- **`run_executor.py`'s command-builder API is dead** and duplicates (stale)
  what `milk_hunt_batch.py` hand-rolls inline — either delete it or bring it
  to flag parity and switch callers over — `docs/history/2026-07-29_SLOP_PATROL.md`
  knot #27.
- **Four dead, unreferenced GDScript test harnesses** (`SimplifiedQuestBoardTest.gd`
  and siblings) reimplement the same "quest completion nukes the pool" check.
  Safe to delete once the live-coverage question is confirmed —
  `docs/history/2026-07-29_SLOP_PATROL.md` knot #31.
- **Two unmerged native-engine proposals in `llm_inbox/`** independently
  redefine the same math (`AxialField`/`FactionField`/`IconEdge`) two
  incompatible ways. Unbuilt, not live — flagged for whoever picks either
  seed up — `docs/history/2026-07-29_SLOP_PATROL.md` knot #36.
- **`QuantumInstrumentInput._focus_plot` writes selection state directly**
  instead of through `QuantumInstrument.select_plot()` — a parallel-authority
  smell, behavior-identical today — `docs/history/2026-07-29_SLOP_PATROL.md` knot #39.
- **`QuantumField3D.rig_bubble_state` reports `measured:false` unconditionally**
  (known, noted in-code) — the rig reads authoritative measured state from
  the farm separately — `docs/history/2026-07-29_SLOP_PATROL.md` knot #40.

## Test-suite gap found during this pass

- ~~**`tests/test_field_shows_the_right_country.py::test_the_endgame_checkpoints_are_not_all_the_same_state`
  fails on any fresh clone**, including CI, because its two required fixtures
  (`🍄/🧪/checkpoints/endrun_act7.json`, `endrun_act8.json`) are gitignored
  ... Needs one of: (a) a real Godot campaign run to Act 7 and Act 8 to
  regenerate the two fixtures ..., or (b) a skip guard on the test.~~
  **Superseded 2026-10-17 — the claim below no longer stands.** That
  "real headless campaign" ran `act3_5_drive.py` with `RIG_UNLOCK_ALL=1`
  (progressive disclosure bypassed) and resource injection ON, on the
  pre-restructure story graph; it proved the flags could be reached by a
  driver that skipped the economy, not that the campaign plays. The banked
  `endrun_act7/act8/ending` saves are deleted. Late-game states now come from
  spec-built `start_at_beat` fixtures (`Core/Campaign/CampaignFixture.gd`,
  `tests/test_campaign_fixtures.py`, `tests/test_campaign_checkpoints.py`),
  and the honest, player-parity drive of the opening
  (`🍄/🧪/honest_opening.py`, `tests/test_honest_opening.py`) records exactly
  how far the real economy carries a fresh run: on 2026-10-17 it played
  Act 0, Act 1 and Act 2's contact/teaching beats by keys alone and stopped
  by design at `forest_listener` offered (Act 3), with `woodlot_wakes` not
  attempted. No end-to-end playthrough at player parity exists yet.
  ~~**Fixed 2026-08-16**: (a) happened. `🍄/🧪/act3_5_drive.py`'s `ACT35_ENDGAME=1`
  block drives a real headless campaign from a fresh boot through
  `the_door_stays_open`; two bugs blocked it from ever reaching Act 8 before
  this pass — `discover_target()` always retried the same un-cullable biome
  (`TheDemos`) instead of trying the next candidate, permanently starving
  ShrineOfAshes/NullingChamber discovery (and everything chained behind
  them: `the_basin` → `the_chain_tested` → `hiding_in_the_light` →
  `the_rite` → `the_door_stays_open`); and no code path banked the fixtures
  at all. Both fixed (commit `7e09958`); the driver now banks
  `endrun_act7`/`endrun_act8` itself the moment each one's required flags go
  live. The two fixtures are minted from that real run and committed
  (commit `f43a4f0`), with a `.gitignore` exception carved out for just
  those two files, mirroring the `native/bin/` pattern — everything else
  under `🍄/🧪/checkpoints/` stays ignored as re-mintable runtime output.
  `python3 -m pytest tests/ -q` now reads 298 passed, 0 failed, 17 skipped.~~
- **Fixed during this pass**: 11 files across `🍄/` hardcoded the original
  developer's absolute machine path (`/home/primearchitect/ws/SpaceWheat/...`)
  instead of deriving it from the script's own location — silently breaking
  `player_seat.py`, `mouse_seat.py`, `mint_checkpoint.py`, and 8 other rig
  scripts for anyone checked out anywhere else. Found because it broke
  `tests/test_mouse_seat_contract.py` in this sandbox; all 11 now resolve
  their root via `Path(__file__).resolve()` (or the bash equivalent). See
  `docs/history/2026-07-29_SLOP_PATROL.md`, which already flagged this as a known
  portability gap.
