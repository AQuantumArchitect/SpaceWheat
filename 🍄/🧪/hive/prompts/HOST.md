# Host bridge — how this agent reaches the seat

Two hosts exist. Try the native form first; if it fails, use the Windows wrap. Do not invent a third.

Waves are **Grok Build** (model grok-4.5 for sensors). No Claude. Coordinator: `GROK.md`.

## Native (agent already in WSL, cwd = SpaceWheat repo)

```
python3 🍄/🧪/player_seat.py look <seat>
python3 🍄/🧪/hive/hive.py wall <chapter> "..."
```

This is what `send_wave.py` uses.

## Windows wrap (Grok Build / PowerShell parent)

Every game/hive command is one `wsl bash -lc` string. No `$` in that string (PowerShell eats it). Use `&&`, never `;`.

```
wsl bash -lc "cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/player_seat.py look SEAT"
wsl bash -lc "cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/player_seat.py press SEAT e"
wsl bash -lc "cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/player_seat.py press SEAT f --shift"
wsl bash -lc "cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/mouse_seat.py look SEAT"
wsl bash -lc "cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/mouse_seat.py click SEAT HintToast"
wsl bash -lc "cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/hive/hive.py wall CHAPTER REPORT"
```

Replace SEAT / CHAPTER with the values from your spawn.

**Walls:** do not put the report on the command line (PowerShell/wsl eat spaces and quotes). Write it, then `--file`:

```
wsl bash -lc "printf '%s\n' 'PERSONA: tried ...; saw ...; expected ...' > /tmp/sw_wall_SEAT.txt"
wsl bash -lc "cd /home/primearchitect/ws/SpaceWheat && python3 🍄/🧪/hive/hive.py wall CHAPTER --file /tmp/sw_wall_SEAT.txt"
```

Repo UNC (for the Read tool on Windows):
`\\wsl$\Ubuntu\home\primearchitect\ws\SpaceWheat\`

## Seat boot is slow

`start` can take up to ~4 minutes (wave 4 often landed in ~1–2 min). Wait for the JSON `{"ok": true, ...}`. Then `look` before any press.

`start` is one invocation; `look`/`press` are later invocations. That is the contract — the listener must outlive the `start` process (it is started in a new session). If a `look` after a successful `start` is empty/`STALE`, say so; do not keep pressing.

A healthy `look` has non-empty `screen_text` or a non-empty `field` list. Empty + `STALE`/`timeout` = harness crash. Stop. Do not mash keys at a dead Godot.

If `start` returns `seat_already_running`, continue with `look`/`press` — do not wipe someone else's seat unless your spawn said `--fresh`.

## Concurrency

**One live headless seat per machine** unless a prior wave on this host proved otherwise. Wave 1 (four parallel boots) returned STALE on every leg.
