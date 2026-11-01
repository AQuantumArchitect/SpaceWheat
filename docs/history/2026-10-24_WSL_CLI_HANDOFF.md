# SpaceWheat handoff — 2026-10-24 (cloud session → WSL CLI)

> **History.** A snapshot of 2026-10-24; the state below is not current. Canonical dev
> moved to Windows (issue #47, `RELEASE.md`). Kept for the headless-playtest recipe
> and the open-items list.

Cheap load order: read this file (≈2 min), then `AGENTS.md`, then only the doc your task names.
Do not read `docs/history/` or `GAME_CODEX.md` unless the task needs them.

## State
- `main` @ `8b83aaa4` (PR #39 merged). CI green. PRs #34–#37 closed (superseded). v0.3.0-alpha tagged.
- Windows build of this commit is in `C:\Games\SpaceWheat` (WSL: `/mnt/c/Games/SpaceWheat`).
- Headless player bundle (89 MB, godot 4.5 + stripped source): `/mnt/c/Games/SpaceWheat/vm-bundle/spacewheat-headless.tar.gz`,
  sha256 `47434692bc283e3490c5231f7f0c506dff23b5128b42b6b8eb9e2382cd93c757`. Rebuild: `python3 tools/headless_bundle.py --godot <godot>`.
- Tests: `SW_SKIP_LONG=1 python3 -m pytest tests/ -q`. 77 pre-existing failures are listed in
  `tests/known_failures.txt` (non-strict xfail ratchet; they hide old failures, they do not fix them). Only NEW failures should fail CI.
- Campaign is compiled: edit `Core/Campaign/campaign.json`, run `python3 tools/campaign/build.py` then `validate.py`. Never hand-edit the runtime JSONs.

## What changed this session (the "player does it" pass)
- Millwright lesson (contracts) is signed: Accept on Arc → take a contract on the Market (guaranteed `lesson_offer`) → deliver → claim on Charge.
  Code: `QuestBoard._lesson_offers`, `Guide._deliver_to`, `QuestManager` `contracts_kept_gte`, `is_charge_hold`.
- Beats with `state_predicates` are never auto-claimed on Accept (`_handshake_auto_claims`).
- Keys: **Shift+F = mass explore**, **Ctrl+Shift+F = reap**. F explore, R strike (many allowed, banks on the plot), Q gathers the bank and returns the plot to fog.
  Code: `Terminal.bank_strike`, `ProbeActions.action_measure/_pay_bank`, `QuantumInstrumentInput._dispatch_action_key`.
- Forest lessons walk `survey` (mass explore) before the Druid/Operator hats. Guide `_free_terminal(q, protect)` fixed the gate F→R→Q loop.
- Pinned by `tests/test_player_does_it.py`.

## Playtesting headlessly (the quest graph + hint structure live here)
- `python3 "🍄/🧪/banner_follow.py" fresh --journey 25 --until island_free [--jobs N --out FILE]`
  presses only keys the on-screen banner names; flags `off_surface`, `stale_toasts`, `verb_mismatch`.
- Rig: `🍄/🎛️/rig_listener.gd` (+ `RigClient`). Surface graph: `SurfaceGraph` (nodes `field`, `X/<tab>`, `C/<tab>`).
- Each godot instance ≈ 450 MB RAM; run 1–2 at a time.
- Last result: two fresh runs reached `island_free` in 445 / 460 presses with 0 off-surface, 0 stale toasts, 0 verb mismatches.

## Open items (pick one)
1. Intermittent late-Act-5 StarterForest⇄Village travel loop (1 of 4 fresh runs).
2. ~1 "Explore [F]" verb mismatch per earlier run; hint prose in the spec still names keys.
3. Other "done for the player" spots: Act 0 steps besides Millwright auto-accept/auto-claim; Bell step grants 🍼; some objectives already true at open (e.g. `new_voices`).
4. Post-game guidance still uses legacy lines.
5. Run the headless bundle on Semantica 3's VM (`ubuntu-2gb-hil-1`, tailnet only): not done — needs scp by Luke; then an S3 desk idea (Luke's OK first; never write S3 sqlite/ledgers).
6. Luke's local checkout `C:\Users\Luke Spooner\SpaceWheat` is on old main with 8 staged edits: decide stash+pull or leave; ask first.

## Honest-claims rule
Don't call the game "beaten" from flags or rig-unlocked drives; only a keys-only banner_follow run to `island_free` counts.
