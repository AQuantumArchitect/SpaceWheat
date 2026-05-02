# Player Input Macro Runner

**Source file:** `UI/Core/PlayerInputMacroRunner.gd` (removed — 0 callers as of 2026-05)

## The idea
A thin orchestration layer that translates abstract "action" dictionaries (`{action: "probe_cycle", params: {...}}`) into real keyboard-and-UI sequences driven through the actual `QuantumInstrumentInput` stack. Keeps key-sequence logic out of test rigs while exercising the real input path — neither a mock nor a direct API call, but genuine headed interaction.

## What's interesting
- **The dual-backend contract.** The runner declares upfront which actions it supports; anything else returns `{ok: false, error: "not_supported_by_player_input"}`. The caller can fall back to a direct-API backend. This is clean capability negotiation — the same decision dict routes to whichever backend can handle it.
- **`_execute_probe_cycle` captures the full measurable/terminal/measured state machine.** It reads the plot state from the host, branches on what state the biome is in (`measured` → R cycle; no measurable → Q first to explore; terminal found → select + E + R). This is a documented state machine for the probe loop that existed nowhere else in a single readable function.
- **Quest board slot resolution strategy is documented in code.** The quest_cycle executor preferentially selects `ready` or `active` slots, falls back to `offered`, falls back to the caller-specified `offer_index`. This priority is the implicit UX contract of the quest board, now written down.
- **Frame hat selection before biome navigation.** Each action selects the correct archetype frame hat (`FRAME_ACE` for probe, `FRAME_MERCHANT` for lindblad drain, `FRAME_CAPTAIN` for discover biome) before navigating. This is the canonical mapping of actions to archetype frames.

## Implementation notes
- All action methods are `async` (use `await`). The host must be an awaitable context — this won't work in headless without async support.
- `host` is duck-typed (no type hint). The host interface requires: `_close_player_overlays_via_input`, `_select_frame_hat`, `_select_biome_via_input`, `_select_plot_via_input`, `_press_key`, `_find_plot_index_for_state`, `_get_resource_map`, `_open_quest_board_via_input`, `_navigate_quest_slot_via_input`, `_resolve_overlay_manager`, `_parse_positions`, `_farm`.
- The `positions` parameter in `_execute_lindblad_drain` is partially parsed but only `positions[0].x` is used as `plot_idx`. Multi-position drain sequences are not implemented.
- `time_skip`, `victory_lap_partial`, and `channel_drain` are explicitly listed as unsupported — they require direct API calls or headless backend.
- `compute_discovery_forecast()` is called on `host._farm` only if the method exists — safe but suggests the forecast was still being wired up.

## Connections
- **QuantumInstrumentInput** — the real input handler that the macro runner drives via `_press_key` and navigation helpers.
- **ToolConfig** — `FRAME_ACE`, `FRAME_MERCHANT`, `FRAME_CAPTAIN` constants define the action → archetype frame mapping.
- **Tests/rig_listener.gd** — the direct consumer; this class was extracted from there to keep the rig clean.
- **QuantumCircuit** — conceptually parallel: QuantumCircuit sequences gate operations; PlayerInputMacroRunner sequences UI actions. Both are instruction tapes that execute against a live runtime.
- **Archetype Frames keymap** (`project_archetype_frames.md`) — the `_select_frame_hat` calls here are the authoritative mapping of which frame each action lives in.
