# Host bridge — native Windows (Luke's Windows PC, since 2026-11-09)

Use this instead of `HOST.md` when the repo lives at `C:\Users\lukes\Documents\SpaceWheat`.
There is no WSL here. Use the Bash tool (Git Bash) and `cd` to the repo in every command:

```
cd /c/Users/lukes/Documents/SpaceWheat && python3 🍄/🧪/player_seat.py look SEAT --no-graph
cd /c/Users/lukes/Documents/SpaceWheat && python3 🍄/🧪/player_seat.py press SEAT f --shift
```

- `python3` is a shim that also points the seat at Godot 4.6.2. Do not set GODOT4 yourself.
- `start` takes ≈ 5 s here, not minutes. Wait for `{"ok": true}`; then `look` before any press.
- Several seats run at once on this host. Use ONLY your own seat name, never another leg's.
- **Walls:** `hive.py wall` does not work on this host (no umweltd). Write your one-line
  wall to `C:/tmp/sw_wall_SEAT.txt` with printf (that path means the same file to Bash and
  Python; `/tmp/...` does not):
  ```
  printf '%s\n' 'PERSONA: tried ...; saw ...; expected ...' > C:/tmp/sw_wall_SEAT.txt
  ```
- `;` as a key: type `semicolon`.
- Never run `pkill`, `taskkill` or anything that kills processes. `player_seat.py stop SEAT` only.
