# Overnight hive run — 2026-11-09 (Windows host)

Runbook + ledger. The coordinator (Claude, this session) re-reads this file at the
top of every loop iteration and appends to it at the bottom. Luke reads it in the
morning. Branch: `overnight/2026-11-09-hive` (one PR, pushed after every fold).

## Morning summary (as of 08:00)

**Where a brand-new player gets now.**
- A fresh **Haiku earnest** (wave 11, all fixes in) made the **tutorial at press 56, Act 2 at 120, Act 3 at 214** (20 flags, 17 beats claimed), with no wall. At the start of the night a fresh Haiku couldn't finish the tutorial.
- A **memoryless Haiku lost-lamb** from zero (wave 12): **tutorial at press 55, Act 2 at 129** (15 flags). The first lost-lamb of the night walled at lesson 1 after 10 presses.
- A **strict memoryless follower**, which presses only the first key the banner names, beats the **tutorial in 55 presses** from zero. From the tutorial-clear save it reached **Act 4** (24 flags) once the Icon⇄Ace ping-pong was fixed. From **true zero** with every fix in, it now reaches **37 flags** on its own (1,199 presses, no judgement), with the last loop it found (Cull) now fixed too.
- The scripted `banner_follow` tutorial baseline went **62 → 55 presses**, with 0 off-surface / stale / mismatch throughout.
- Sensors that started from earned saves reached **Act 4 "The Island & Its People"**.

**Soft-locks.**
- **One real soft-lock found and fixed:** save/load turned a plot with only measurement memory into "INVALID: measured but no outcome recorded". Every verb on it was dead and its banked strikes were lost (cd786e1d). The fix also repairs existing saves.
- **Seven guide loops** that trapped banner-followers are fixed: selected-row no-op key (ea5d6721), Loom "clear marks" on a lone good mark, the Charge-row no-op (47ba780d), the Icon⇄Ace ping-pong (36497260), ESC cancelling an armed Trim (befa861c) and Cull, and a dead miss counter that kept rare-pole gathers from ever falling back to the trade.
- **No soft-lock from chaos:**
  - mashers in the Icon, Captain and Operator hats (40 random keys each, mid-quest)
  - a burst-masher (96 random keys sprinkled through tutorial + Act 1, every burst recovered in 1–5 presses)
  - a save-scummer (11 reloads at awkward moments)
  - a quitter (abandon a story contract, Refresh spam, back out of doors, spend needed resources)

**Fixes on the PR (16 commits of game/harness code + this ledger).**
- Windows host: rig, seat, static DLL link.
- The Loom: cross-biome refusal.
- Capstone: Ctrl+⇧ chip, plus `--ctrl` for the seat.
- Arc: "accepted, on Charge" line; inspect no longer shows the math_note.
- Mass Explore: register filter.
- Guide arrows (" → ").
- Apprentice hint names the Village board.
- Save/load fix.
- Guide: strike again before gathering; ladder progress % with faction; selected-row key; lone-mark pairing; Icon picker verb; hat ping-pong.
- New probe: `🍄/🧪/strict_follow.py`.

**Gate on every fold:**
- banner_follow fresh → first_harvest, now 55 presses, 0/0/0
- full pytest floor: 655 passed; the same 6 Windows-host failures every time (path separators, POSIX-only deploy scripts)
- live repro from the sensor's own save

**Needs you:** see "For Luke" at the bottom. Top four:
1. Two lessons share the title "The Teaching".
2. Still the Pond's hint doesn't match the Operator chips.
3. Contextual keys (Y/U/R/G/F) are the #1 friction overall.
4. Plant a New Voice's 🌱 pacing.

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
   still reaches the tutorial end (55 presses baseline since the Loom-marks fold; 59 after ea5d6721; 62 at start of night), campaign
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
| act1_voices (Plant a New Voice →) | `--checkpoint earnest_act1_mill_w3` | soft-lock fixed (cd786e1d); 🌱 grind stall fixed in the Guide (12edcbc6); **CLEARED** by lost-lamb, wave 5 |
| act1_late → **act2_two_countries** (Woodlot, Spring, Prove Reliable, Carry Water, The Teaching, Couple the Spring) | `--checkpoint lost_lamb_act1_w5` | wave 6: Carry Water claimed, The Teaching accepted + Hearth Keeper deliveries reach "The Teaching → Claim" (banner-only follower, 15 flags). **CLEARED** by earnest, wave 6 (17 flags, Arc header "Act 2 — Two Countries") |
| act2 → act3 → act4 (Couple the Countries, Gear-Bench, Hold Commerce) | `--checkpoint earnest_act1_w6_end` | **CLEARED** by earnest, wave 7 (Arc heading reached Act 4) |
| act4 (A Character, The Forest Stirs, Master of the Mill, …) | `--checkpoint earnest_act2_w7_end` (it is an Act 4 save despite the name) | wave 8: no clear — both sensors drifted off a working banner. Parked; wave 9 = fresh end-to-end regression |

## Ledger

| # | time | wave | legs (persona → outcome) | walls → class | fold / commit |
|---|---|---|---|---|---|
| 0 | 00:40 | win-w1 | earnest → wall @ The Loom (4/6 lessons, ~68 presses) | cross-biome Bell silent + half-applied H → legibility+bug | a4d7db78 |
| 1 | 01:05 | on-1 | earnest → wall @ capstone (5/6, 58 presses; **Loom fold held**) · lost-lamb → DRIFT wall after Accept (0/6, 10 presses) · masher→recover → 30 random keys recovered fine, then same capstone wall (5/6) | capstone: chip "⇧ Reap" vs banner CTRL+SHIFT, seat had no Ctrl → legibility+harness (2 legs) · Arc "next door hasn't opened" after Accept → legibility · banner chord keys pressed out of order (Y = Village on the farm) → legibility, deferred | fe5362c8, c6f91c18 |

| 2 | 01:35 | on-2 | earnest → **CLEAR** (6/6, ~95) · lost-lamb → **CLEAR** (65 presses) · masher (mashed mid-lesson-2) → reported soft-lock in Past the Hedge; refereed: NOT a lock — objective was already claimable, old Column-5 spam hid it (that seat booted before 58151a06) | chord banners read as lists (4th sensor) → legibility · Column-5 spam → bug | 58151a06, 2101ddc9 |
| 3 | 02:00 | on-3 | earnest → claimed Apprentice to the Mill, First Breath, The Spiral Breaks; walled at Plant a New Voice "gather 🌱 3/5" (67 presses) · literalist → wall at press 4: [Y] has 3 jobs on one screen · masher→recover (40 keys mid-Apprentice) → reported soft-lock "Apprentice stuck 9%, no Millwright on Market" | literalist: banner X→Y→G→R works when followed → tester-strict (theme: contextual keys → For Luke) · masher: NOT a lock — banner routes to the Village board, Refresh yields a Millwright; the quest hint never named which board → legibility · New Voice: 🌱 is a 15% pole, ≈40-press grind → pacing (For Luke) | d2ace2e2 |
| 4 | 02:20 | on-4 | earnest (patient grind) → 0 🌱 in 21 presses, "✗ Terminal in invalid state: INVALID: measured but no outcome recorded" · masher→recover (Icon hat) → same invalid plot, wallet unchanged by 40 random keys · lost-lamb → claimed Wheel, Apprentice, First Breath; DRIFT wall in The Spiral Breaks | **SOFT-LOCK (bug):** a bound plot saved with only measurement memory loaded as "measured, no outcome"; Q/R dead forever, banked 💀 ungatherable (2 legs, reproduced) · Arc inspect showed the designer's math_note (gate formula + code paths) → legibility regression of the 10-26 editorial rule | cd786e1d, 9c077746 |
| 5 | 03:10 | on-5 | earnest (re-fly, patient) → save fix held; 0 🌱 in 25 presses · lost-lamb → **no wall**, ~90 presses: Spiral Breaks, Plant a New Voice, Find the Woodlot, Find the Spring, Prove Reliable claimed, Carry Water delivered · save-scummer → 11 save/reload cycles at awkward moments: wallet, plots, marks, contracts all survive; tracked loop progress does not (see For Luke) | 🌱 grind: the Guide sent Explore→1 Strike→Gather at ~5% odds; 5 banked strikes + 1 Q paid +51 🌱 → Guide routing (legibility) · "Plant [R]" vs Q: refereed, banner correct (R opens the picker, Q picks the word) → tester | 12edcbc6 |
| 6 | 03:55 | on-6 | earnest → **into Act 2 "Two Countries"** (89 presses): Carry Water, The Teaching (Hearth Keepers), Couple the Spring claimed; walled at Still the Pond · lost-lamb → wall at 23 presses: "banner loops Millwright deliveries, never names Hearth Keepers" · masher (Captain hat, 40 keys) → **no damage**: wallet + 5 biome tabs intact, recovered in 12 presses, claimed Carry Water | lost-lamb loop: NOT reproduced — banner-only follower from its save delivers the held Millwright contract, accepts The Teaching, routes to Hearth Keepers 🍞×32/×8, reaches "The Teaching → Claim" → tester (stopped mid-chain) · two "The Teaching" objects (Charge row + Arc offer) and a "signed" 📜 card before Accept → For Luke · 243-👥 contract is abandonable ([Q] Abandon) → not a trap | — |
| 7 | 04:45 | on-7 | earnest → **Act 2 → Act 3 → Act 4 "The Island & Its People"** (~135 presses, 24 flags): The Teaching, Couple the Countries, The Gear-Bench, Hold Commerce claimed; walled at A Character 69% ("faster clock [=]" seemed to do nothing) · lost-lamb → LOOPING wall at 20 presses on Millwright laps · masher (Operator hat + sub-modes, 40 keys) → **no damage**, economy kept paying | Millwright "loop" (3rd sensor): refereed NOT a loop (follower reaches Claim in 3 laps), but laps showed no why/how-far → Guide legibility · A Character: refereed not a lock — follower climbs clock ×2…×16, waits, Incorporates, re-tracks; it is a ripen ladder needing more real time than the sensor gave → pacing | b426c3e1 |
| 8 | 05:35 | on-8 | earnest (Act 4) → A Character stuck 69%, wandered into F/R/Q on unrelated plots · lost-lamb (Act 4) → walled after 5 presses, "no banner" · **quitter** (abandon a story contract, Refresh ×6, back out of doors, spend a needed resource) → **no soft-lock**: abandoned contract re-offered in 1–3 Refreshes, % held, resource routed back via gather | both Act 4 walls refereed as tester: banner present throughout ("[5] Icon then plant 🏭" → "Icon hat [5]" → "loops ripening → faster clock [=]") — at Act 4 depth (4 quests on Charge, slow ripening) Haiku sensors stop trusting the banner · quitter: ESC doesn't cancel an Arc inspect, so a second tap accepts → For Luke | — |
| 9 | 05:55 | on-9 (fresh e2e) | lost-lamb → LOOPING at 20 presses: G ×9 on an already-selected Market row · **burst-masher** (8 bursts × 12 random keys sprinkled through tutorial + Act 1, 96 random presses) → **no soft-lock**: every burst recovered in 1–5 presses, every stray menu closed with one ESC, reached Act 1 (Spiral Breaks claimable) · **earnest (fresh, true zero) → beat the whole tutorial in ~68 presses**, then Apprentice, First Breath, Spiral Breaks (138 presses, 150 s ripening); walled at the Plant a New Voice picker · lost-lamb re-fly on ea5d6721 → past the Market row (fold held), then LOOPING at The Loom: "clear marks [']" named first on a lone valid mark | banner named a no-op row key first → Guide legibility (also waves 5, 7) · picker banner "▸ 🌾/👥 [E]" had no verb → legibility | ea5d6721, f9d4e407, Loom-marks fold |

**Memoryless milestone (06:45):** a strict first-key-only follower (`C:/tmp/sw_strict.py`: press only the first bracketed key the banner names, no judgement) now beats the tutorial **from true zero in 55 presses, 0 waits**. banner_follow's baseline is also 55 (62 at the start of the night).

| 10 | 07:10 | on-10 (fresh e2e) | **earnest from true zero → Act 2 at press 122** (tutorial at 66; 15 flags; 14 beats), walled at The Teaching · strict follower (no model) from tutorial-clear → 400 presses, 21 flags, then Icon⇄Ace ping-pong | Teaching: two lessons share the title; the banner worked the Millwright one while the sensor did Hearth Keepers → ladder prefix now names the faction · ping-pong: hat:icon ran before berry's reveal → Guide loop | 36497260 |
| 11 | 08:00 | on-11 (fresh e2e) | **earnest from zero → tutorial 56, Act 2 120, Act 3 214, no wall** (20 flags, 283 presses, 240 s waits) · strict follower from zero → 900 presses, stuck at 21 flags in a Trim Q/ESC loop | Trim loop: an armed confirm read as "open", so the chord led with ESC (which cancels) → Guide loop; fixed, strict follower then 21 → 37 flags | Trim-confirm fold |
| 12 | 08:30 | on-12 (fresh e2e) | **lost-lamb from zero → tutorial 55, Act 2 129** (15 flags, 194 presses); wall at "The Teaching (Millwright's Union) 85% → … Refresh [E]", where E paused the game | refereed: no loop — the strict follower from its save claims the Millwright Teaching, accepts the Hearth one, gathers 🔥 and delivers (15 → 16 flags). E = Refresh on the Market but Pause on the field → contextual keys (For Luke) | — |
| 13 | 09:00 | on-13 | earnest from the Act 3 save → Couple the Countries, Couple the Spring, The Gear-Bench claimed; walled at "gather 🪓 0/3" (65 presses) · burst-masher (5 bursts, fresh) → every burst recovered in 2 presses; then a **real stall** at "gather 🦅 17/21" for 30 presses | refereed: no loop — following the banner from its save, Strike → Gather pays 🪓 10, then Trim confirm (befa861c holds), plant, Incorporate, claim Hold Commerce, accept A Character = Act 4 in 16 presses → tester (left the banner) · 🦅 stall: **Guide bug** — misses never counted under the strike-bank model (trace "misses0"), so the MISS_CAP → trade fallback was dead; fixed, strict follower then 10 → 15 flags | miss-counter fold |
| 14 | 09:50 | strict-zero-2 + on-14 | **strict follower from TRUE ZERO, all fixes in → 37 flags** (1199 presses), then a Cull Q/ESC loop · lost-lamb (fresh) → tutorial at 55 again, Act 1 through The Spiral Breaks (8 flags, 116 presses); walled at "gather 🌱 3/5 → Strike again [R]" after ~8 presses | Cull: same armed-confirm/ESC trap as the Trim → Guide loop, fixed; follower then charts a new biome (Lanternfall). A later "Find Lanternfall → Claim [R]" stall did NOT reproduce after reload (R claims in Ace and in Captain), possibly a stale Charge selection index → noted · lost-lamb 🌱 wall: refereed not a loop — the strict follower crossed the same section (laps, then MISS_CAP → 🍞→🌱 trade) → pacing | cull-confirm fold |

Pytest floor on this host (godot.exe on PATH + PYTHONUTF8 via the python3 shim): **655 passed, 6 failed, 50 skipped** (as of cd786e1d; +3 new tests) — the 6 are host-path tests (Windows separators, POSIX-only deploy scripts, no HOME), unchanged by every fold.

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
- **Tests ignore rule:** `.gitignore`'s `Tests/` matches `tests/` on Windows (case-insensitive), so new test files need `git add -f`. Consider anchoring it (`/Tests/`) or dropping it.
- **Banner flips between looks with no input** (lost-lamb, Spiral Breaks): "plot [G] → Track [F]", then "clear marks ['] → plot [H] → Track [F]". Probably real-time ripening changing the Guide's pick. Not reproduced; worth a look.
- **Tracked loops after a reload (corrected):** they *are* saved and restored (`berry_tracked`). But the hat resets to Ace and nothing on screen shows a loop is still ripening, so the save-scummer pressed F (which toggles tracking off) and killed its own loop. That's the old "F destroys the loop" trap (fleet #4), made worse because the reload hides the loop. Original report: (save-scummer, scum_6 and scum_11). Saved at "Ripening 8%". After reload, F printed "tracking stopped — the loop is lost. F re-tracks.", and re-tracking showed "Incorporate [R]" *immediately*, i.e. ripe on arrival. Not a lock (incorporate worked), but it could be a free-ripening exploit via save/reload. Saves: `🍄/🧪/checkpoints/scum_6.tres`, `scum_11.tres`.
- **Hats and overlays reset on reload** (always back to Ace, menus closed). Consistent; probably intended.
- **The F chip changes job while a 📜 story card is up**: it reads "[F] 📋 Charge" instead of Explore/Fast-Fwd, so a player pressing F for Explore opens Charge. The banner never names F at those moments, but sensors trip on it.
- **Banner "Plant [R]" vs the chip "Add Icon"**: same action, two names.
- **Stale banners right after Accept** (lost-lamb): "▸ Arc [Y] → Carry Water [G] → Accept [R]" was still shown after Carry Water was accepted. Not reproduced yet.
- **Two quests both called "The Teaching".** In late Act 1, Charge shows a claimable row titled "The Teaching" while the Arc still offers "OPEN · The Teaching · [R] Accept". The 📜 card already says "The Teaching — signed, it's on Charge" *before* Accept (PlayerEventBridge._announce_live_beat names whatever Guide.live_beat returns). Two sensors misread it; the masher believed it had accepted. The path still works when followed. Repro saves: `mash_act1_w6_end`, `lost_lamb_act1_w6`. This touches the campaign's handshake objects, so it's your call.
- **Still the Pond (Act 2) has no keyboard path I could confirm.** The hint says "In the spring: Operator [9], mode 2, [E] reads the compass 🧭. Strike to deepen the gap; the surface stills near an eigenstate." In Operator mode 2 the chips are "[R] 🧭 Turn" ("Turned the compass at q0 — 1 fence flipped; every closed loop held"), and the banner keeps saying "▸ to Village [Y]" instead of guiding this door. The Spring's plots also start unexplored. Earnest walled here after 10 presses. I didn't rewrite the hint because I can't verify the mechanic. Repro save: `earnest_act1_w6_end`.
- **The Guide guides one live beat, not the one you chose.** With several quests on Charge, the banner routes to the Guide's pick (Millwright deliveries → "Couple the Countries") even when the player has just accepted another door (Still the Pond). That door then gets no banner help.
- **Two lessons share the title "The Teaching"** (Millwright's windmill lesson and the Hearth Keepers' water lesson). Together with the early "signed" 📜 card, this is what confused three sensors in waves 5–6. A distinct title per faction would remove most of it.
- **ESC doesn't cancel an Arc inspect** (quitter): after G-inspect, ESC then X → Y → G re-taps the same row, and the second tap *accepts* ("tap a row to inspect, again to accept"). A player backing out can accept by accident.
- **Commitments scope hides held contracts** (quitter): with scope on StarterForest, Commitments showed "no past contracts yet" while a Village contract was held; it only appeared after switching scope to Village (Y).
- **Haiku at Act 4 depth:** sensors reach Act 4 but then drift off the banner (4 quests on Charge, multi-minute ripening). For Act 4+ coverage, consider Sonnet-class sensors or a stronger "trust the banner" line in the persona packs.
- **' (clear marks) also opens the Memoir panel in the Icon hat** (burst-masher): the banner says "clear marks ['] → plot [H] → Track [F]". The marks do clear, but a Memoir panel opens and needs an ESC. Small key overlap.
- **Enter opens the PAUSED overlay, and Q there quits** (burst-masher, didn't press it). A masher one key away from quitting the game is worth a confirm, if there isn't one.
- **E is Refresh on the Market and Pause on the field.** A memoryless sensor pressed the banner's "Refresh [E]" after the board had closed and paused the game ("⏸ time paused — F plays on"). This is one more instance of the contextual-keys item above.
- **"✗ 👥 already anchors one of your words — 👥/🍞 cannot join your signature (berry still counted)"** shows on Incorporate even when the quest still progresses (the claim right after works). A ✗ on a step that succeeded made earnest think it was stuck. Consider a neutral glyph or wording when the berry still counts.
- **Unreproduced: "▸ Find Lanternfall → Claim [R]" repeated ×10 in a live strict run** (save `dg_cull_end`). After a reload, X → U → R claims in both Ace and Captain. Possibly `_charge_selected_idx` going stale when Charge rows shrink, so the Guide drops the [G] for a row that isn't actually selected. Worth a look if it shows up again.
- **Strike-again laps feel like loops to a memoryless player.** A lap is Explore → Strike → Strike again ×5 → Gather, about 8 presses with nothing visible, and the trade fallback comes after 3 missed laps (≈24 presses). A lost-lamb walls before that. Options: show a lap counter in the banner ("strike 3/6"), or lower STRIKE_TRIES (6) / MISS_CAP (3) so the trade comes sooner. That's tuning, so I left it for you.
