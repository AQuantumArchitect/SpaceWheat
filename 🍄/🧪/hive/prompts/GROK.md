# Coordinator — how to send a grok sensor wave

Humans: `../PERSONAS.md`. This file is for the parent agent that launches legs.

## Catalog (this host, 2026-09-15)

Grok Build `grok models` lists **grok-4.6** (default) and **grok-4.5**. There is no `grok-mini` in the catalog. Sensor class = **grok-4.5**, low effort — the discount/speed stand-in.

No Claude. `send_wave.py` writes spawn packs; the parent launches legs.

## Shape of a wave

1. One live headless Godot per machine. **Sequential seats.** Wave 1 (four parallel boots) all STALE.
2. Default four personas: `literalist`, `earnest`, `lost-lamb`, `masher`.
3. Act 0 from true zero unless the spawn named a checkpoint. Lost-lamb may load an *earned* checkpoint from `promote.py` (they walked that chapter). Intra-session they stay memoryless. `/hive-wave` auto-promotes a **clear** only when `🍄/🧪/checkpoints/<bank>.tres` exists.
4. After each leg: `player_seat.py stop <seat>` before the next `start`.
5. Sensors never edit. Parent may edit between waves (path repairs, not tester patches).

## Launch one leg

Spawn a `general-purpose` subagent, model `grok-4.5`, isolation `none`. Prompt is the pack `send_wave.py` writes (or the template below). Wait for it to finish. Then the next persona.

```
You are a SpaceWheat SENSOR playtester.
Persona: PERSONA
Seat: SEAT
Chapter: CHAPTER
Press budget: N (or the persona's own stop rule, whichever first).
Start from true zero (no --checkpoint). Welcome splash may be up.

BEFORE any press, READ with the Read tool:
  🍄/🧪/hive/prompts/SENSOR.md
  🍄/🧪/hive/prompts/HOST.md
  🍄/🧪/hive/prompts/PERSONA.md
Do not guess the seat CLI. Fetch it.

Then play that persona. Never edit code, data, or saves.
End with the 8-line report in SENSOR.md.
```

UNC repo (Windows Read tool): `\\wsl$\Ubuntu\home\primearchitect\ws\SpaceWheat\`

## Packs on disk

```
python3 🍄/🧪/hive/send_wave.py --dry-run --chapter act0_fresh
```

Writes `🍄/🧪/hive/waves/<stamp>/{manifest.json,prompts.json}`.

## After the wave

Write `🍄/🧪/hive/waves/<stamp>.md` — one table: persona / presses / outcome / one-line note. Humans read that. Raw walls stay in `walls.jsonl`.

Wave 8–9b (2026-09-15, grok-4.5): mill `[C]`, forest-cross ESC, Superpose `[0]` then `[E]`, Bell (Shift+G H, `[R] Gate`, `[Q] Bell`), Reap Shift+F, Arc `[X]` then `[I]` are keyboard-followable. Mill apprentice: `[C]` then Market `[Y]`. Next door: Plant a New Voice (Icon 5, empty plot, R — do not plant for them).

Live toast owns F (`[F] opens …`); the card stays above menus. **tap-lamb** is the mouse-only lost-lamb (`mouse_seat.py`, headed, opt-in). Orchestration: `/hive-wave` (sequential seats, then recap). Legs ~2–4 min. One Godot. umweltd down is OK — local walls.jsonl is record.
