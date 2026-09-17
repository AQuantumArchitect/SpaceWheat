# Playtester Personas

Five sensor archetypes for grok-4.5 legs. Keyboard four on `player_seat.py`. **tap-lamb** is headed `mouse_seat.py`.

**Humans read this page.** Agents fetch `prompts/` — do not paste packs into a spawn.

| Persona | One line | Fetch |
|---|---|---|
| **masher** | Random keys. The plateau is the signal. | `prompts/masher.md` |
| **literalist** | Do exactly what `screen_text` names. Gaps are walls. | `prompts/literalist.md` |
| **earnest** | Competent newcomer. The control. | `prompts/earnest.md` |
| **lost-lamb** | No short-term memory. LOOPING / DRIFT are the defects. | `prompts/lost-lamb.md` |
| **tap-lamb** | Mouse-only lost-lamb. Keyboard-only doors are walls. | `prompts/tap-lamb.md` |

Every sensor also fetches `prompts/SENSOR.md` (laws, seat CLI) and `prompts/HOST.md` (native WSL vs Windows wrap). Coordinator fetches `prompts/GROK.md`. Index: `prompts/INDEX.md`.

## Send a wave

Grok Build parent, **grok-4.5** sensor class, one seat at a time. No Claude. This host has no `grok-mini`; 4.5 is the discount/speed stand-in.

```
python3 🍄/🧪/hive/send_wave.py --dry-run --chapter act0_fresh
python3 🍄/🧪/hive/send_wave.py --personas literalist,lost-lamb,earnest --chapter act0_fresh --dry-run
```

Packs land in `🍄/🧪/hive/waves/<stamp>/`. Parent launches the legs (see `prompts/GROK.md`), or run `/hive-wave` (sequential sensors + recap + auto-promote). Four parallel Godot boots on this host (2026-09-15) all came back STALE — do not raise `--jobs` without measuring.

**Auto-promote:** `promote.py` records a per-persona chapter. A **clear** advances only when that seat banked a real `🍄/🧪/checkpoints/<name>.tres`. Lost-lamb stays memoryless inside a session; an earned checkpoint is where they stand, not a skip. Open-play band starts at `village_identity` (lost-lamb playing around there is the acceptable-case success). Finale: `edge_of_the_enclave`.

Latest recaps: `waves/20260915T-w8.md` (Bell walk followed; Arc named `[X]` then `[I]`), `waves/20260915T-w9b.md` (mill apprentice `[C]` then Market `[Y]`; next door is Plant a New Voice).

## Laws (three lines)

1. Sensor never holds the hammer — report, don't repair.
2. Precise early surrender is a success — ~8–10 dead presses → bank, wall, stop.
3. Walls fix paths, not testers.

Full constitution: `HIVE_PROTOCOL.md`. Seat: `python3 🍄/🧪/player_seat.py <cmd> <seat> …` from repo root.

## Testing a specific late-game system

Spend the press budget on the diagnostic, not on travel. Resume from a checkpoint sitting **immediately before** the moment under test.

Example: `🍄/🧪/checkpoints/fork_ready.tres` — `village_identity` fired, no `village_path_*` yet. A fork-signpost leg dropped there is testing the fork on turn 1.

Discoverability and legibility are different defects. For a *legibility* leg it is fair to hand the key path to the instrument (e.g. "press 5 for Icon, then b for the biome microscope"). Starving that leg of navigation produces a null result, not a reading.

## Mouse-only

**tap-lamb** is the dedicated mouse lost-lamb (`mouse_seat.py`). Default `--fresh`; an earned campaign checkpoint is legal, same as lost-lamb. `press` is refused; `look` carries `buttons`. Headed — one live Godot on this host (same as keyboard waves). Do not add tap-lamb to a keyboard wave without measuring; it opens a real window.

Other personas can swap the seat the same way for a mouse-only fly. Details in `prompts/SENSOR.md`.
