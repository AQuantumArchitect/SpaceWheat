# Polish Day — 2026-07-05

*One session, primary-dev autonomous: merge → test → play → publish. Everything below is
on `main` and pushed to origin.*

## The merge (c8116d15)

The two dev streams — 95 commits of UX/boot/playzone/closed-native work and 33 commits of
verbs/basins/trilogy/launch work — are one game now. 30 conflicts resolved semantically
(see the merge commit for the resolution ledger). Suite went from 5 failures to 103/103.
The campaign data merged to 43 flags across acts 0–8: the topology trilogy AND the
political finale (`empire_imposes` → `island_free`) coexist as parallel arcs.

## Bugs found and killed today

1. **Toast grammar ate the first F/E press** — any live toast intercepted F (flatten), so
   Track/confirm silently did nothing ("press F twice"). A toast now yields to any
   frame-declared verb. This was killing the icon-incorporation loop in tests.
2. **`#` is not a ConfigFile comment** — `quantum_matrix.gdextension`'s `#` blocks were
   glued into the next key. The web entry never existed as far as the exporter knew, and
   the primary linux/windows keys have been mangled the whole time (desktop survived only
   via clean `.release.` duplicate lines). Comments are `;` now.
3. **Web GDExtension never loaded** — beyond (2): Godot 4.3+ requires `web.threads.wasm32`
   (bare `web.wasm32` is rejected for thread-support exports), and the WASM must be
   compiled `-pthread`. Also the build's `src/*/*.cpp` glob matched nothing and em++
   failed silently — now `find(1)` and fatal.
4. **Gallery lived in the excluded playzone** — every export preset excludes `🍄/**`, so
   exported builds had broken `ReelRunner`/`PostcardCapture` class refs. Gallery ships
   from `Core/Gallery/` now.
5. **Leaked rig listeners** — terminating the launcher shell orphaned its godot child,
   which ran full physics + 10Hz polling forever. Accumulated zombies were the persistent
   half of the owner's disk-saturation incident (the other half: the pre-merge
   OperatorCache JSON dumps, deleted by the merge). The launcher now `exec`s godot and
   `terminate_listener` reaps dead-sandbox listeners.
6. **act3_5_drive pressed a tab that no longer exists** — Arc offers moved to X in the
   menu re-org; the drive's `C→I` was a no-op. Re-pointed to `X→I`.

7. **THE LAUNCH BUG — the campaign doors were not in the deck.** The captain-hat
   draw is restricted to the scenario's curated `unexplored_biome_pool`, and
   `demos_normal`'s pool predated the trilogy campaign: GildedRot, Lanternfall,
   ZenoLatch, ShrineOfAshes, NullingChamber — the biomes acts 3–8 gate on — were
   not in it. The derived discovery pressure computed correctly and the compass
   glowed, but for doors that could never be drawn. Found the only way it could
   be found: by playing (32 pressured draws, zero landmarks, P ≈ 2e-7). Fixed in
   the scenario (pool 15 → 20) and locked with
   `tests/test_scenario_pool_covers_campaign.py`: every biome any story flag
   references must be unlocked at boot or in the shipped pool.
8. **Rig read a dead farm after loads** — `load_game_path` swaps in a fresh farm
   but the listener kept its boot-time reference, so post-load reads (story
   flags, forecasts) came from the shut-down farm. The game's save/load was
   always correct; the rig now rebinds. (This false-flagged a "loads wipe
   campaign progress" scare during diagnosis — disproven against the real farm.)

## Gaps closed (see docs/PRE_LAUNCH_GAPS.md)

- **#6 (P0)**: `tests/test_title_boot_path.py` — title → welcome (any-key dismiss) →
  Act-0 tutorial offered → gameplay verbs → `first_breath`, every suite run, 8s.
- **#10 (P1)**: `Core/Gallery/reels/the_span.reel.json` — the What Connects attract reel;
  bridge build/braid/braid/fuse verified through the real BridgeRegister.
- **#11 (P2)**: the web smoke RAN for real. Verdict on this GPU-less box: engine boots in
  Chromium, isolation granted, native extension loaded, 0 fatal errors, main thread
  responsive (188ms worst), 10.4 fps on SwiftShader software GL. The fps floor awaits one
  hardware-GL run (`docs/release/WEB_DOOR.md` has the numbers and the remaining gate).

## The playthrough (headed, live C++ engine, keyboard only)

Two legs on the merged build, zero errors, zero walls:

- **Leg 1** (incorporation loop): acts 0–1 plus the trilogy loop flags
  (`loop_remembers`, `second_loop`, `the_knot`).
- **Leg 2** (acts 2–6 drive): `village_stirs` → Mill learned via the X→Arc accept flow →
  `lumber_flows` (0.92) → `spring_connects` (0.98) → `mill_wakes` → `mill_master` →
  `island_lives` (1.00) → `village_identity` (0.98, signature 19, atom diversity 33) →
  `ledger_opens` (1.00) → **`empire_imposes` (1.00) → `island_free` (1.00) — the ending**
  — plus `village_path_artisan`, and organically along the way: `pond_depths`,
  `pond_breathes`, `braid_order`, `braid_word`, `edge_of_the_enclave`.

24 of 43 flags proven by keyboard across the legs. The remainder is the acts 6–8
wet-country endgame (the crossing into GildedRot, What Fades, What Connects III–V),
which needs a purpose-built drive — the predicates and registers behind it are all
suite-covered.

## Still open (nothing blocks desktop launch)

- One hardware-GL web smoke run → final web perf statement.
- Acts 6–8 keyboard drive (endgame proof at the play level).
- P3 backlog: dead-code census cull, position-based gate path, touch, berry shim refactor.
