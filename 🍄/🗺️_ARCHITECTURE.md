# 🍄 The LLM Playzone — Architecture & Data Flow

*How an LLM actually drives SpaceWheat, headlessly.*

`🍄/` is the **single home** for playing the game from code: the Godot-side listener, its
Python driver, the probes, and these docs all live here. There is **one primary rig** — a
**keyboard rig**: you press the same keys a human presses, and read back the same UI/physics
state a human sees.

---

## 🌐 The Big Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                      🧠 LLM Agent Brain                          │
│              (Claude / Codex / whoever is playing)               │
└─────────────────────────┬───────────────────────────────────────┘
                          │ decides a keypress or a read
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│              🎛️ rig_client.py  ·  class RigClient                │
│   start_listener() · run_turn(turn, action, **params) · stop     │
│   writes one JSON line to  ▶  user://rig/queue.jsonl              │
│   reads the reply back from ◀  user://rig/results.jsonl          │
└─────────────────────────────────────┬───────────────────────────┘
                                      │ 📨 queue.jsonl / 📬 results.jsonl
                                      ▼
┌─────────────────────────────────────────────────────────────────┐
│         🎮 Godot game, headless (or headed for screenshots)      │
│                                                                 │
│   🍄/🎛️/rig_listener.gd   (extends SceneTree, run via --script)  │
│      · boots the REAL game (AppRoot → PlayerShell)               │
│      · polls queue.jsonl, dispatches each action                 │
│      · writes the result + a heartbeat + a bridge_ready sentinel │
│                                                                 │
│   press_key ─► QuantumInstrumentInput ─► the exact same input    │
│               path a human keyboard drives                       │
└─────────────────────────────────────────────────────────────────┘
```

The listener runs the **real** game — no mock. Whatever the rig sees is what a player sees.

---

## 🚀 One Turn, End to End

```python
from rig_client import RigClient          # 🍄/🎛️/ is on sys.path

c = RigClient()
c.clear_rig_files(preserve_live_sentinel=False)
proc = c.start_listener(scenario_id="demos_normal")   # boots 🍄/🎛️/rig_listener.gd headless
c.wait_for_ready(proc, timeout_s=300)

c.run_turn(1, "press_key", key="5", settle_frames=5)  # press '5' → Icon hat, let 5 frames pass
c.run_turn(2, "press_key", key="G", settle_frames=4)  # 'G' → select plot 0
state = c.run_turn(3, "instrument_state")             # read back the cursor/hat/plot state
bloch = c.run_turn(4, "viz_bloch", biome="StarterForest")  # per-qubit live Bloch-z

c.run_turn(99, "stop"); c.terminate_listener(proc)
```

For a **headed** run (real pixels, WSL uses `opengl3`) pass `display_mode="headed"` and use the
`screenshot` action → save a PNG under `user://rig/` and read it back. See
`🍄/🧪/screenshot_probe.py` for the canonical pattern.

---

## 🎮 The Action Vocabulary (keyboard rig — primary)

Every turn is one JSON dict on `queue.jsonl`; the reply is one dict on `results.jsonl`:

```json
{"turn": 3, "action": "press_key", "key": "G", "settle_frames": 4}
{"turn": 3, "ok": true, "current_hat": "icon", "current_plot_idx": 0}
```

**Drive the keyboard** (the whole game is reachable this way — nothing is rig-only):

| Action | What it does |
|---|---|
| `press_key` | 🎹 Press one key (`key`, optional `shift`, `settle_frames`) — hats `4–0`, sub-mode `1/2/3`, biomes `TYUIOP`, plots `GHJKL;`, the **QERF** cross, overlays `ZXCVBNM` |
| `key_sequence` | ⌨️ Press several keys in order |
| `start_from_title` | ▶️ Dismiss the title / welcome and enter play |

**Read the state** (what a human would see on screen):

| Action | Returns |
|---|---|
| `instrument_state` | 🎯 cursor layer, current hat / biome / plot / submenu |
| `hud_snapshot` · `widget_snapshot` · `overlay_snapshot` · `full_snapshot` | 🖼️ rendered HUD / widget / overlay / everything |
| `viz_bloch` · `probability_map` · `berry_state` | 🔬 per-qubit Bloch-z, Born probabilities, Berry phase |
| `story_flags` · `story_offers` · `flag_progress` | 📖 fired/unfired narrative beats + soft-gate progress |
| `board_state` · `board_market` | 📋 quest board + market offers |
| `hamiltonian_stats` · `energy_variance` · `atom_diversity` · `entropy_snapshot` | ⚛️ live physics observables |
| `screenshot` · `set_window_size` · `set_resolution` | 📸 headed capture + window control |

**Lifecycle:** `ping`, `save_game` / `load_game`, `stop`. (The listener dispatches ~90 actions in
all; the above are the ones a fresh driver needs. Grep `🍄/🎛️/rig_listener.gd` for the full set.)

---

## 🗂️ The Handshake Files (`user://rig/`)

The Python side and Godot side rendezvous through four files under the Godot user dir
(`$XDG_DATA_HOME/godot/app_userdata/SpaceWheat - Quantum Farm/rig/`; each rig lane gets a private
`XDG_ROOT` so concurrent bots don't collide — see `🍄/🎛️/milk_hunt_paths.py`):

- `queue.jsonl` — append one line per turn request (RigClient writes, listener reads).
- `results.jsonl` — append one line per reply (listener writes, RigClient reads).
- `bridge_ready` — sentinel with the Godot PID; `wait_for_bridge_sentinel()` blocks on it.
- `heartbeat` — timestamp + idle/poll timings, so a slow turn extends its timeout instead of
  failing (a stale heartbeat = a genuinely dead listener).

---

## 🥛 Secondary: the batch / campaign layer

On top of the keyboard rig sits an optional **semantic** driver for long unattended campaigns and
policy experiments — this is *not* the primary interface, just a convenience layer:

- `🍄/🎛️/milk_hunt_runner.py` — a high-level orchestrator: reads game state through
  `policy_snapshot`-style actions, picks quests/actions by a strategy, drives many turns.
- `🍄/🎛️/policy_graph_runtime.py` + `Core/AI/PolicyGraph.gd` (+ `Core/Config/PolicyGraph/`) — a
  JSONL policy graph the runner and the game share.
- `🍄/🎛️/milk_hunt_batch.py` / `milk_hunt_seed_save.py` / `milk_hunt_scan.py` — seed a save, run a
  batch, scan the outputs.

Reach for this only when you want a scripted campaign; for interactive play and inspection, use the
keyboard rig above.

---

## 🔗 How This Touches the Game

```
🍄/🎛️/rig_client.py              writes/reads jsonl
        │
🍄/🎛️/rig_listener.gd            boots AppRoot, polls the queue, dispatches actions
        │
UI/Core/QuantumInstrumentInput.gd   the real keyboard decoder (press_key lands here)
        │
Core/…                           real actions: measure / harvest / incorporate / reap / market
```

---

## 🛠️ Maintenance

| Task | Command |
|---|---|
| 🟢 Start the rig (headless) | `🍄/🎛️/🟢.sh` |
| ✍️ Send one turn by hand | `🍄/🎛️/✍️.sh '{"turn":1,"action":"instrument_state"}'` |
| 📸 Capture screenshots | `python3 🍄/🧪/screenshot_probe.py` |
| 🧪 Run a probe | `python3 🍄/🧪/<name>_probe.py` |
| 🎨 Sync emoji SVGs | `python3 🍄/🛠️/sync_emoji_pipeline.py` |
| 🔨 Rebuild C++ native lib | `🍄/🔨✖.sh` |

---

## 📦 What's Not Here

- `🍄/📦_emoji_research/` — pre-consolidation emoji design work (gitignored). Live truth is the
  game's `icons.json` / `biomes.json`.
- `🍄/🧪/*_🧬.md` — biome stress-test specs (buffer invalidation, force-graph scaling); run
  independently, see `🍄/🧪/README_🧬.md`.
