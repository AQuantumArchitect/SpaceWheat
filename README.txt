SpaceWheat - LLM Collaborator README

Purpose
- This repo is in active prototyping for an open beta build.
- Use this as the operational handoff for automated collaborators (LLM agents, headless runners, balance bots).

Source Of Truth
- Gameplay/economy configuration should be treated as save-state data, not loose config files.
- Canonical save schema lives in `Core/GameState/GameState.gd`.
- Save/load orchestration lives in `Core/GameState/GameStateManager.gd` + `Core/GameState/GameStateSerializer.gd` + `Core/GameState/SaveStore.gd`.
- Economy runtime application lives in `Core/GameMechanics/FarmEconomy.gd` and `Core/GameMechanics/BalanceService.gd`.

Current Save-Backed Balance Fields
- `balance_profile_id`
- `balance_workbench_config`
- `farm_variable_graph_path`
- `farm_variable_graph_jsonl`
- `economy_variables`

Economy Variables (serialized)
- `quantum_to_credits`
- `max_biome_qubits`

Quick Start
1. Use emoji scripts in `🍄/` as primary harnesses.
2. Prefer headless scripts for reproducible runs.
3. Keep run artifacts out of git; use whitelisted artifact folders only.

Git Hygiene Rules
- Do not commit local brainstorming or transient LLM conversation dumps.
- `llm_inbox/` and `llm_outbox/` are ignored/untracked.
- Historical archive/bloat directories are removed from source history going forward.
- Keep committed test assets intentional and minimal.

Testing Expectations
- Run targeted headless checks after core gameplay/state changes.
- If you change save schema or economy application paths, validate:
  - New game boot
  - Save -> load roundtrip
  - Farm-variable graph applies after load

What To Avoid
- Re-introducing detached backup/scaffolding files (`*.gd.backup`, `*.old*`).
- Adding nonessential generated logs or run dumps to tracked paths.
- Adding new runtime config sources outside save/load without explicit design approval.

Notes For Balance/Runner Teams
- Tune through save profiles + farm-variable graph + `economy_variables` in save state.
- Keep runner assumptions aligned with in-game state and serialization fields.
