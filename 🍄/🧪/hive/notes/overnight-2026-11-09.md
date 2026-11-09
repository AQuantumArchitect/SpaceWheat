# Overnight hive run — 2026-11-09 (Windows host)

Runbook + ledger. The coordinator (Claude, this session) re-reads this file at the
top of every loop iteration and appends to it at the bottom. Luke reads it in the
morning. Branch: `overnight/2026-11-09-hive` (one PR, pushed after every fold).

## Owner's orders (2026-11-09, before bed)

- **Scope:** tutorial first, then onward — promote sensors chapter by chapter
  using banked checkpoints.
- **Throughput:** 2–3 Haiku sensor seats in parallel. Builder work by the
  coordinator or a Sonnet/Opus builder agent.
- **Folds allowed:** legibility (hints, banner, refusal toasts, guide routing)
  and **bug hunting — soft-locks especially** ("a player does something slightly
  unexpected and the game soft-locks"). Not allowed: physics, economy numbers,
  the owner's story prose (beyond a hint line naming what the player must do),
  new content. Anything bigger → write it up under "For Luke" below.
- **Git:** commit each fold with its evidence, push the branch, keep one PR.

## The loop (one iteration)

1. **Read** this ledger: current chapter, open walls, last wave.
2. **Fly** a wave: 2–3 Haiku sensors in parallel, each its own seat
   (`w_on_<n>_<persona>`), mixed personas. Always include one of
   **masher / lost-lamb** (soft-lock hunters) alongside earnest/literalist.
   Start from the chapter's checkpoint (`--checkpoint <stem>`) or `--fresh` for act0.
3. **Referee** every wall: load the sensor's banked save in a diag seat and
   reproduce. Classify: `legibility` / `soft-lock` / `bug` / `harness` /
   `tester` (sensor misread something the screen said plainly).
4. **Fold** reproduced legibility/soft-lock/bug walls: smallest fix at the
   path, plus a test or probe that pins it where practical.
5. **Gate** before commit: `banner_follow.py fresh --journey 15 --until first_harvest`
   still reaches the tutorial end (62 presses baseline), campaign
   `build.py --check` + `validate.py` clean when the spec changed, relevant
   pytest file(s) pass. Then commit + push.
6. **Re-fly** the walled chapter with a fresh sensor (test → fold → test).
   A clear banks `<persona>_<chapter>_clear` → promote the next leg past it.
7. **Append** a ledger row; schedule the next iteration.

## Host notes

- Seat CLI: `python3 🍄/🧪/player_seat.py …` from repo root in Git Bash
  (`python3` is a shim; Godot via `GODOT4`). Seat boot ≈ 4 s.
- Wall files: write to `C:/tmp/sw_wall_<seat>.txt` (Python and Git Bash disagree
  about `/tmp`). `hive.py wall` needs `umweltd` (absent here) — ledger walls here.
- Never `pkill`-style match on "rig_listener.gd" from a shell whose own command
  line contains that string (it kills itself). Use `player_seat.py stop <seat>`.
- Each Haiku leg ≈ 150k tokens, ≈ 5 min.

## Chapters

| chapter | entry | status |
|---|---|---|
| act0_fresh (tutorial) | `--fresh` | Loom wall folded (2624078f); re-fly pending |

## Ledger

| # | time | wave | legs (persona → outcome) | walls → class | fold / commit |
|---|---|---|---|---|---|
| 0 | 00:40 | win-w1 | earnest → wall @ The Loom (4/6 lessons, ~68 presses) | cross-biome Bell silent + half-applied H → legibility+bug | 2624078f |

## For Luke (needs a decision, not folded)

- (none yet)
