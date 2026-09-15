# Hive prompt packs — fetch map

Humans read `../PERSONAS.md` (the table). Agents fetch only the files named below. Do not paste packs into a spawn.

| You are | Fetch, in order |
|---|---|
| Coordinator (sending a wave) | `GROK.md` then `HOST.md` |
| Any sensor | `SENSOR.md` then `HOST.md` then `<persona>.md` |
| masher / literalist / earnest / lost-lamb | the matching file in this folder |

Optional (only if the spawn named it):

- `../HIVE_PROTOCOL.md` — full constitution
- `../PERSONAS.md` — late-game checkpoint rule, mouse-seat swap

Wave logs: `../waves/<stamp>/`. Walls: `../walls.jsonl` via `hive.py wall --file`.
