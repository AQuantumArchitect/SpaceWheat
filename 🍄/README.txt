SpaceWheat LLM Collaboration Entry Point
=======================================

Purpose
-------
This folder is the automation and test lane for LLM collaborators.
Use it to run headless rig control, milk-hunt runners, and batch scans
without patching core game code first.

Quick Start (2 minutes)
-----------------------
1) Start live headless rig listener:
   ./🍄/🎛️/🟢.sh

2) Send one turn:
   ./🍄/🎛️/✍️.sh '{"turn":1,"action":"resource_snapshot"}'

3) Run one milk-hunt run:
   ./🍄/🎛️/🥛🏃.sh --runs 1 --max-loops 21

4) Scan latest run outputs:
   ./🍄/🎛️/🥛🏃.sh scan results

Core Paths
----------
- Rig launcher: `🍄/🎛️/🟢.sh`
- Turn writer: `🍄/🎛️/✍️.sh`
- Milk hunt entry: `🍄/🎛️/🥛🏃.sh`
- Runner implementation: `🍄/🎛️/milk_hunt_runner.py`
- Runner policy: `🍄/🎛️/milk_hunt_quantum_policy.py`
- Save/profile seeding: `🍄/🎛️/milk_hunt_seed_save.py`
- Shared world-state configs: `🍄/🎛️/config/world_state/`
- Shared strategy configs: `🍄/🎛️/config/strategy/`
- Headless test set: `🍄/🧪/`

How This Connects To Main Game
------------------------------
- Headless actions route through `Tests/rig_listener.gd`.
- Game state ownership remains in the core game save/load systems.
- Profiles/scenarios should be represented as save state inputs, not ad-hoc patches.

Artifact Policy
---------------
Runtime artifacts are ignored by default:
- `🍄/logs/`
- `🍄/🎛️/logs/`
- `🍄/🎛️/🧾/`
- `🍄/🎛️/.godot*`
- `🍄/🎛️/__pycache__/`

If you need to commit a representative run artifact, place it in:
- `🍄/artifacts_whitelist/`

Do not commit bulk run outputs anywhere else in `🍄`.

LLM Operating Rules
-------------------
- Prefer wrappers in `🍄/🎛️/` over direct ad-hoc commands.
- Keep run outputs in existing log/result paths; do not invent new output roots.
- For reproducibility, seed saves via `milk_hunt_seed_save.py` before batch runs.
- Use frame-based waits/time-skip actions (in-game steps), not wall-clock sleep logic.
- Keep config edits in `🍄/🎛️/config/` and avoid hardcoding constants in scripts.

Recommended First Validation Pass
---------------------------------
1) Verify rig boot:
   ./🍄/🎛️/🟢.sh
2) Verify turn round-trip:
   ./🍄/🎛️/✍️.sh '{"turn":2,"action":"known_vocab_pairs"}'
3) Verify one seeded run:
   python3 🍄/🎛️/milk_hunt_seed_save.py --slot 2 --profile granary_scout
   ./🍄/🎛️/🥛🏃.sh --seed-slot 2 --runs 1 --max-loops 21
4) Verify scan:
   ./🍄/🎛️/🥛🏃.sh scan results

If these four checks pass, the lane is ready for larger experiment batches.
