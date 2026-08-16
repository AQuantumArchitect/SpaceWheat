# How SpaceWheat is built

SpaceWheat is developed in direct collaboration with AI coding agents — not
as autocomplete on top of hand-written code, but as agents that build,
playtest, and audit the actual running game. That's disclosed here on
purpose, not something to route around: it's a real part of how a
quantum-physics simulator with 55k+ lines of engine code and 164 passing
physics tests gets built and kept correct by a small team.

## The headless rig

`🍄/` (see [`🍄/README.txt`](../🍄/README.txt)) is a keyboard rig: it presses
the same keys a human presses and reads back the same UI and physics state a
human sees, driving the *real* game — not a mock or a simplified harness.
Agents play SpaceWheat the way a playtester would, headlessly, which is how
a lot of the bug reports in this repo's `docs/` folder were actually found —
`docs/PLAYTEST_SWEEP_2026-08-10.md` and `docs/MOUSE_PARITY_AUDIT.md` are both
records of agents walking the game end-to-end and reporting exactly what a
human would hit.

## What that process actually produces

A few things fall out of building this way that are worth knowing if you're
evaluating the codebase:

- **Dated, falsifiable status docs.** `docs/performance/PROFILE_2026-08-*.md`
  are a day-by-day performance log with real measured numbers, not
  after-the-fact summaries — including entries that correct earlier wrong
  conclusions in public (a software-rasterizer framerate that looked bad was
  later found to be 6x low once measured on real hardware; that correction
  is recorded, not quietly overwritten).
- **A doc-hygiene discipline.** `docs/DOC_ROT_2026-07-11.md` is an audit that
  found and archived a cluster of dead docs. Status claims in this repo are
  expected to expire and get checked, not accumulate indefinitely.
- **"Phantom bug" diagnosis.** Several items in `docs/PRE_LAUNCH_GAPS.md` were
  reported as bugs, investigated, and closed as *not actually bugs* once the
  real mechanism was traced — the process is built to catch its own false
  positives, not just rack up fixes.
- **A physics test suite that's the actual bar.** `bash 🍄/🧪/🔬.sh` and
  `python3 -m pytest tests/ -q` are what CI and every contributor — human or
  agent — has to clear. See [`CONTRIBUTING.md`](../CONTRIBUTING.md).

## For agents working on this repo

If you're an AI agent contributing here: `BIOME_AGENTS.md` scopes
biome/faction physics work specifically; `🍄/README.txt` and
`🍄/🗺️_ARCHITECTURE.md` are the full rig architecture and data-flow map for
driving the game headlessly. Read the scoped doc for the area you're
touching before the general one — most of this repo's documentation is
written for exactly that handoff.
