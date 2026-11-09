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
| act0_fresh (tutorial) | `--fresh` | **CLEARED** wave 2 by earnest (~95 presses) and lost-lamb (65, memoryless) |
| act1_mill (Apprentice to the Mill → First Breath → Spiral Breaks) | `--checkpoint earnest_act0_fresh_clear` | **CLEARED** by earnest, wave 3 (3 beats claimed, ~58 presses) |
| act1_voices (Plant a New Voice →) | `--checkpoint earnest_act1_mill_w3` | wave 4 flying |

## Ledger

| # | time | wave | legs (persona → outcome) | walls → class | fold / commit |
|---|---|---|---|---|---|
| 0 | 00:40 | win-w1 | earnest → wall @ The Loom (4/6 lessons, ~68 presses) | cross-biome Bell silent + half-applied H → legibility+bug | a4d7db78 |
| 1 | 01:05 | on-1 | earnest → wall @ capstone (5/6, 58 presses; **Loom fold held**) · lost-lamb → DRIFT wall after Accept (0/6, 10 presses) · masher→recover → 30 random keys recovered fine, then same capstone wall (5/6) | capstone: chip "⇧ Reap" vs banner CTRL+SHIFT, seat had no Ctrl → legibility+harness (2 legs) · Arc "next door hasn't opened" after Accept → legibility · banner chord keys pressed out of order (Y = Village on the farm) → legibility, deferred | fe5362c8, c6f91c18 |

| 2 | 01:35 | on-2 | earnest → **CLEAR** (6/6, ~95) · lost-lamb → **CLEAR** (65 presses) · masher (mashed mid-lesson-2) → reported soft-lock in Past the Hedge; refereed: NOT a lock — objective was already claimable, old Column-5 spam hid it (that seat booted before 58151a06) | chord banners read as lists (4th sensor) → legibility · Column-5 spam → bug | 58151a06, 2101ddc9 |
| 3 | 02:00 | on-3 | earnest → claimed Apprentice to the Mill, First Breath, The Spiral Breaks; walled at Plant a New Voice "gather 🌱 3/5" (67 presses) · literalist → wall at press 4: [Y] has 3 jobs on one screen · masher→recover (40 keys mid-Apprentice) → reported soft-lock "Apprentice stuck 9%, no Millwright on Market" | literalist: banner X→Y→G→R works when followed → tester-strict (theme: contextual keys → For Luke) · masher: NOT a lock — banner routes to the Village board, Refresh yields a Millwright; the quest hint never named which board → legibility · New Voice: 🌱 is a 15% pole, ≈40-press grind → pacing (For Luke) | d2ace2e2 |

Pytest floor on this host (godot.exe on PATH + PYTHONUTF8 via the python3 shim): **652 passed, 6 failed, 50 skipped** — the 6 are host-path tests (Windows separators, POSIX-only deploy scripts, no HOME), unchanged by every fold.

## For Luke (needs a decision, not folded)

- **Mouse-only reap may be impossible.** A shift-click on the F chip reaches the game as Shift without Ctrl, which is now mass-explore. So the Act 0 capstone may have no mouse path unless "the season button" covers it. Needs a headed `mouse_seat` check; I can't test it headless.
- ~~Chord banners read as unordered lists~~ folded in 2101ddc9 (" → "). Original note: ("board [C], Market [Y]"). Two sensors pressed the later key first. On the farm Y means Village, so the step is lost (the Guide does recover). A separator change (" → " or "then") touches ~10 test files, so I'm deferring it until the Godot-driven tests run on this host.
- **Pytest on this host (fixed via the shim, not the repo):** was 14 failures, mostly Windows text encoding (the tests read files without utf-8), plus 70 skips because `godot` isn't found as an .exe. Harness fixes are queued for the loop.
- **Lesson 1 wording:** the objective says "one Millwright 🌾 contract is guaranteed", but the Market row is "Millwright's Union 👥 × 8 → pays 💨×3 🏭×3 🔨×2". The sensors took it anyway. This is story/spec prose, so I left it for you.
- **Mouse parity, more broadly:** every sensor tonight is keyboard-only and headless. Mouse-only walls are untested.
- **Contextual keys are the #1 friction overall (5 sensors).** Y = Arc tab inside Story, the Village biome on the farm, and the Market inside the Board; U = Charge tab vs StarterForest; R = Accept/Claim/Deliver vs Strike; plain G in the Icon hat both tracks and marks a plot ("marked G (1/2)"). The arrows (2101ddc9) and the route banners help, but the key map itself is a design call.
- **Plant a New Voice pacing:** "gather 🌱 3/5" on Starter Forest's 💀🌱 plot, which is about 85% 💀. With ≈15% per strike, that's ~40 presses of F→R→Q, and nothing on screen offers a better lever. Earnest walled under Law 2 after 8 presses. Is this grind intended, or should the plot or the hint change? (Physics/economy, so not folded.)
- **Saves keep accepted quests' hint text.** A hint fix (e.g. d2ace2e2) reaches quests accepted *after* the fix, not ones already sitting on Charge in an existing save. Consider re-reading hints from the spec on load.
- **First R on a fresh Arc row sometimes only inspects.** Earnest: "the first R showed no toast and the item stayed OPEN"; the second R accepted it. Probably the two-step tap rule (#44) leaking into the keyboard path. Not reproduced yet.
