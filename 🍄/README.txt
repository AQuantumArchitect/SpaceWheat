SpaceWheat — The LLM Playzone
=============================

Purpose
-------
This folder (🍄/) is the single home for driving SpaceWheat headlessly from code.
The Godot-side listener, its Python driver, the probes, and the docs all live here.
There is one primary rig: a KEYBOARD rig — you press the same keys a human presses
and read back the same UI/physics state a human sees. It runs the REAL game, not a mock.

Start Here
----------
- 🗺️ Full architecture & data flow: `🍄/🗺️_ARCHITECTURE.md`  ← READ THIS FIRST
- Game mental model / physics / controls: `docs/GAME_CODEX.md`
- Repo-wide operational memory: `MEMORY.md`
- Biome/faction physics work: `BIOME_AGENTS.md`

Quick Start (keyboard rig)
--------------------------
1) Start the live headless listener:
     ./🍄/🎛️/🟢.sh

2) Send one turn by hand (JSON in, JSON out):
     ./🍄/🎛️/✍️.sh '{"turn":1,"action":"instrument_state"}'

3) Or drive it from Python (the normal way):

     from rig_client import RigClient          # 🍄/🎛️/ on sys.path
     c = RigClient()
     c.clear_rig_files(preserve_live_sentinel=False)
     proc = c.start_listener(scenario_id="demos_normal")
     c.wait_for_ready(proc, timeout_s=300)
     c.run_turn(1, "press_key", key="5", settle_frames=5)   # Icon hat
     c.run_turn(2, "instrument_state")                      # read state back
     c.run_turn(99, "stop"); c.terminate_listener(proc)

4) Run a ready-made probe (headed screenshots, UI health, etc.):
     python3 🍄/🧪/screenshot_probe.py
     python3 🍄/🧪/ui_health_probe.py

Core Paths
----------
- Listener (Godot side):   `🍄/🎛️/rig_listener.gd`   (run via --script; boots the real game)
- Python driver:           `🍄/🎛️/rig_client.py`      (class RigClient)
- Path/lane helpers:       `🍄/🎛️/milk_hunt_paths.py`  (private XDG lane per bot)
- Launcher / turn writer:  `🍄/🎛️/🟢.sh` · `🍄/🎛️/✍️.sh`
- Probes:                  `🍄/🧪/`
- Emoji-pipeline tooling:  `🍄/🛠️/`

The Handshake
-------------
RigClient and the listener rendezvous through JSONL files under the Godot user dir
(user://rig/): queue.jsonl (requests), results.jsonl (replies), bridge_ready (PID
sentinel), heartbeat (liveness). Each rig lane claims a private XDG_ROOT so concurrent
bots never share a queue.

Secondary: batch / campaign layer
---------------------------------
For long unattended campaigns or policy experiments there's an optional semantic driver
on top of the keyboard rig — NOT the primary interface:
  - `🍄/🎛️/milk_hunt_runner.py`     high-level orchestrator (strategy-driven turns)
  - `🍄/🎛️/policy_graph_runtime.py`  + `Core/AI/PolicyGraph.gd` (shared JSONL policy graph)
  - `🍄/🎛️/milk_hunt_{batch,seed_save,scan}.py`  seed → batch → scan
Reach for this only when scripting a campaign; for interactive play, use the keyboard rig.

LLM Operating Rules
-------------------
- Prefer the wrappers in `🍄/🎛️/` and existing probes over ad-hoc commands.
- Claim a private rig lane (XDG_ROOT / SW_RIG_LANE) per bot; don't share the default lane.
- Use frame-based waits (settle_frames / time-skip actions), not wall-clock sleeps.
- Always `stop` + terminate the listener when done; `pkill -f rig_listener.gd` clears strays.

Artifact Policy
---------------
Runtime artifacts are gitignored: `🍄/logs/`, `🍄/🎛️/logs/`, `🍄/🎛️/__pycache__/`, `🍄/🎛️/.godot*`.
Commit a representative run artifact only under `🍄/artifacts_whitelist/`. Do not commit bulk
run outputs anywhere else in `🍄`.
