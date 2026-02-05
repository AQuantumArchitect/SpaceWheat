# Codex-Min Rig

This rig lets "Codex-mini" agents play turn-by-turn by reusing the existing Godot boot stack (BootManager + PlayerShell + FarmInstrument). It wraps the headless Godot runners and FarmInstrument helpers so each turn is logged and controllable.

## Tools in place
- `Core/Instrumentation/FarmInstrument.gd` exposes methods to open overlays (quests/vocab), read resources, and accept offers. BootManager automatically creates it and stores it on `PlayerShell.farm_instrument`.
- `Tests/qii_*` scripts (probe, gate, vocab, vocab-sequence) now run through the real game loop, call FarmInstrument/QII actions, and emit token logs via `lib_qii.sh`.
- `🍄/lib_qii.sh` + `🍄/VOCAB_QII.tsv` document the compact command set (e.g., `G3.Q` for explore, `G4.R` for remove vocab) and log timestamps/results for each run.
- `🍄/logs/tokens/` stores `.tok` files that a Codex-mini harness can read to know what happened on each turn; extend them to include outcomes or status codes if needed.

## How to run the rig
1. Choose a script from `🍄/` (e.g., `🎹🧠.sh` for the vocab sequence rig) and run it: `bash 🍄/🎹🧠.sh`. It boots BootManager, the full Farm UI, and runs the scripted turns while logging each action/token.
2. Parse the generated token log (e.g., `🍄/logs/tokens/🎹🧠20260204_171817.tok`) to inspect turn-by-turn codes + timestamps.
3. To add new turns, edit the corresponding `Tests/qii_*.gd` script, call `QuantumInstrumentInput` or `FarmInstrument` helpers as needed, and annotate with new token log entries.

## Orchestrator: `rig/orchestrator.py`

1. `rig/turn_plan.json` lists sample turns (existing scripts such as `🎹⚛️` and `🎹🧠`) with names/descriptions.
2. Launch the rig via `python rig/orchestrator.py --plan rig/turn_plan.json`. Each turn runs the referenced bash script, captures stdout/stderr, and writes a summary JSON (`rig/logs/{turn}_{timestamp}.json`) plus the recorded token logs in `🍄/logs/tokens/`.
3. Inspect turn logs to see timestamps, durations, return codes, and which token files (with `VOCAB_QII` codes) were produced.
4. Use `--dry-run` to print the turn order without executing anything.

## What to extend for Codex-mini (existing tooling)
- Create a lightweight orchestrator (bash or Python) that reads a turn list (JSON/TSV), maps shortcuts via `VOCAB_QII.tsv`, launches the appropriate Godot script, and waits for completion before issuing the next turn.
- Enhance the token log format to include `status|emoji|value` so agents can reason about outcomes (e.g., `turn5  SUCCESS  +Vocab Village` or `turn7  FAIL  Need 🍞`).
- Provide a small helper script that talks to `PlayerShell.farm_instrument` from GDScript so Codex-minis can open overlays (`quests`, `vocabulary`) and poll the HUD between turns.

## Next steps
1. Build the orchestrator (Phase 1 in `RIG_PLAN.md`), likely a Python script that launches `godot --headless` and reads/writes a simple command queue.
2. Add richer instrumentation to FarmInstrument and the QII test scripts so each turn reports resource deltas, quest state, and buffer invalidations.
3. Publish guidelines explaining how to write new turns, decode token logs, and integrate with automation lanes.

Use this rig to have alternate Codex-mini instances experiment with tools/actions in a controlled, turn-by-turn session while keeping logs and documentation in sync. Good luck!
