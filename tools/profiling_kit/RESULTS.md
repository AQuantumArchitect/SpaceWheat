# SpaceWheat performance — first hardware-GL measurement

> Fill this in. Leave the raw JSON in `results\` next to it.
> Rule: **no number without its renderer.** If a run's `trustworthy` field is
> `false`, quote the caveat rather than the number.

**Run by:** _(agent / date)_
**Machine:** _(GPU, CPU, display refresh rate — the desktop report prints all three)_

---

## Desktop — `build\SpaceWheat.exe`

Renderer reported: _(`environment.video_adapter`)_

| scenario | fps mean | p50 ms | p95 ms | worst ms | trustworthy |
|---|---|---|---|---|---|
| title capped | | | | | |
| title uncapped | | | | | |
| fresh capped | | | | | |
| fresh uncapped | | | | | |
| **endgame capped** | | | | | |
| **endgame uncapped** | | | | | |

**Where the frame goes at `endgame`** — from the last snapshot in
`results\desktop-endgame-*.json`:

- `process_ms` (rendering + game logic): ___
- `batcher.avg_batch_time_ms` (the quantum physics step): ___
- `batcher.buffer_state`: ___ *(`RECOVERY` means the physics is behind)*
- `draw_calls`: ___
- `node_count`: ___

> These two costs need different fixes. If `process_ms` dominates, it is the
> renderer. If `avg_batch_time_ms` dominates, no GPU will help.

## Browser — `web\`

Renderer reported: _(`gpu.renderer` — **if this says SwiftShader the run is void**)_

| | value |
|---|---|
| boot to live canvas | ___ s |
| settle fps (first 15s) | ___ |
| **steady-state fps mean** | ___ |
| p50 / p95 frame ms | ___ / ___ |
| worst timer stall | ___ ms |
| cross-origin isolated | ___ |
| trustworthy | ___ |

**Against the floor:** `docs/release/WEB_DOOR.md` sets 20 fps. Result: **PASS / FAIL**

---

## The three questions

**1. Does the desktop build hold up at `endgame`?**

_(yes/no, and which of the two costs dominates)_

**2. Does the browser build clear 20 fps on real hardware?**

_(This decides whether the itch.io page's "Play in the browser, or download for
Windows + Linux" line can ship as written.)_

**3. Is the 193 MB web bundle's boot time acceptable?**

_(`boot_seconds`. If it is bad, the resource pack is the lever, not the code.)_

---

## Anything surprising

_(Stutters, hangs, a scenario that behaved differently from its numbers, console
errors, anything the JSON does not capture. A run that failed is worth writing
down — say what it did, not what you think it meant.)_
