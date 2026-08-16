# Known Issues

A published, honest list of what's open, instead of a growing internal
backlog nobody outside the repo reads. This is the right shape for an
Early-Access-style release: ship with a stated roadmap, not silence.

Sourced from `docs/PLAYTEST_SWEEP_2026-08-10.md`, `docs/MOUSE_PARITY_AUDIT.md`,
`docs/SLOP_PATROL_2026-07-29.md`, `docs/CAMPAIGN_STATE_2026-08-04.md`, and
`docs/performance/PROFILE_2026-08-16.md`. Each item links back to its source
doc for full context.

## Player-facing

- **Unrevealed plots have no mouse click target under the default 3D
  renderer.** The Act-0 hint says "or just tap it," which is true for
  revealed plots but not empty ground. Needs a design call (ghost orbs for
  empty ground, re-show the 2D rack, or reword the hint) —
  `docs/PLAYTEST_SWEEP_2026-08-10.md`.
- **Three action chips read fully silent**: spark.R (act 6), operator.F
  (act 7), druid.F (act 8). Not yet confirmed real vs. a phantom (see the
  project's own precedent for that diagnosis in `docs/PRE_LAUNCH_GAPS.md`) —
  `docs/MOUSE_PARITY_AUDIT.md`, Wave 15.
- **Mouse-vs-keyboard refusal/toast text parity** has never been fully
  confirmed, open since Wave 2 of the mouse-parity audit —
  `docs/MOUSE_PARITY_AUDIT.md`.
- **The Act-7 gate `Tr(ρ²) ≥ 0.54` has no legible player-facing lever** —
  `docs/PLAYTEST_SWEEP_2026-08-10.md`.
- **Arc-offer queueing at the Act-4 fork** buries 4 quest offers behind one
  banner line, 12 pages deep — `docs/PLAYTEST_SWEEP_2026-08-10.md`.
- **Hat-key toggles (number row) have no visual affordance** for which hat
  is currently worn — a deliberate, still-open design question, not a bug —
  `docs/PLAYTEST_SWEEP_2026-08-10.md`.
- **Touch drag selection is unimplemented** (`UI/PlotGridDisplay.gd`) and the
  neighborhood-graph overlay is reachable only via the literal `[` key with
  no button-row slot. Mobile-port-only; not a desktop-blocking gap —
  `docs/SLOP_PATROL_2026-07-29.md` knot #41.

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
  `docs/SLOP_PATROL_2026-07-29.md` knot #38.
- **Standing's "inert" status is repeatedly re-flagged as ambiguous** across
  audit passes even though it already feeds `PriceModel` pricing. This is an
  intentional, owner-accepted half-state; the ambiguity keeps resurfacing
  purely because nothing documents it as deliberate — one-line doc fix, not
  a code fix — `docs/CAMPAIGN_STATE_2026-08-04.md` §5 item 12.
- **`docs/STATE_VECTOR_PLAN.md`** (replacing the closed-system density matrix
  ρ with a pure state `|ψ⟩` behind a `QuantumState` interface) is fully
  scoped, five-stage migration planned, zero code written. No player-facing
  payoff on its own — owner call on whether/when to start it.

## Technical debt (dev-facing, low live risk)

- **`run_executor.py`'s command-builder API is dead** and duplicates (stale)
  what `milk_hunt_batch.py` hand-rolls inline — either delete it or bring it
  to flag parity and switch callers over — `docs/SLOP_PATROL_2026-07-29.md`
  knot #27.
- **Four dead, unreferenced GDScript test harnesses** (`SimplifiedQuestBoardTest.gd`
  and siblings) reimplement the same "quest completion nukes the pool" check.
  Safe to delete once the live-coverage question is confirmed —
  `docs/SLOP_PATROL_2026-07-29.md` knot #31.
- **Two unmerged native-engine proposals in `llm_inbox/`** independently
  redefine the same math (`AxialField`/`FactionField`/`IconEdge`) two
  incompatible ways. Unbuilt, not live — flagged for whoever picks either
  seed up — `docs/SLOP_PATROL_2026-07-29.md` knot #36.
- **`QuantumInstrumentInput._focus_plot` writes selection state directly**
  instead of through `QuantumInstrument.select_plot()` — a parallel-authority
  smell, behavior-identical today — `docs/SLOP_PATROL_2026-07-29.md` knot #39.
- **`QuantumField3D.rig_bubble_state` reports `measured:false` unconditionally**
  (known, noted in-code) — the rig reads authoritative measured state from
  the farm separately — `docs/SLOP_PATROL_2026-07-29.md` knot #40.

## Test-suite gap found during this pass

- **`tests/test_field_shows_the_right_country.py::test_the_endgame_checkpoints_are_not_all_the_same_state`
  fails on any fresh clone**, including CI, because its two required fixtures
  (`🍄/🧪/checkpoints/endrun_act7.json`, `endrun_act8.json`) are gitignored
  (`.gitignore` calls them "minted checkpoint banks; runtime artifacts,
  re-mintable from the drives") and were never committed — even though the
  test's own assertion message calls them "a shipped fixture." The bug this
  test guards against (`#514` — all three endgame checkpoints collapsing to
  one identical 49-flag state, making the Act 7/8 story gates unreachable
  from any shipped save) was fixed per the test's docstring and
  `docs/PLAYTEST_SWEEP_2026-08-10.md`, but the fix was never captured as
  committed test data, so nobody without a local `🍄/🧪/checkpoints/`
  directory can verify it — this sandbox included. Needs one of: (a) a real
  Godot campaign run to Act 7 and Act 8 to regenerate the two fixtures via
  `🍄/🧪/mint_checkpoint.py` (its own hardcoded-path portability bug is now
  fixed, so this is at least runnable on any checkout now), with a
  `.gitignore` exception carved out to actually commit them (mirroring the
  `native/bin/` pattern), or (b) a skip guard on the test for environments
  without the fixtures, matching how the rest of the suite handles a missing
  `godot` binary.
- **Fixed during this pass**: 11 files across `🍄/` hardcoded the original
  developer's absolute machine path (`/home/primearchitect/ws/SpaceWheat/...`)
  instead of deriving it from the script's own location — silently breaking
  `player_seat.py`, `mouse_seat.py`, `mint_checkpoint.py`, and 8 other rig
  scripts for anyone checked out anywhere else. Found because it broke
  `tests/test_mouse_seat_contract.py` in this sandbox; all 11 now resolve
  their root via `Path(__file__).resolve()` (or the bash equivalent). See
  `docs/SLOP_PATROL_2026-07-29.md`, which already flagged this as a known
  portability gap.
