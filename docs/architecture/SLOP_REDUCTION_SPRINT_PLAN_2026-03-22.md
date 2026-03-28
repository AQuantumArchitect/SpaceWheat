# Slop Reduction Sprint Plan (2026-03-22)

## Goal
Reduce false paths, alternate fallbacks, duplicate registries, stale tests, and compatibility shims so the repo reflects the current game architecture instead of multiple historical layers.

## Non-Goals
- No broad gameplay rebalance in this sprint.
- No speculative subsystem rewrites without a clear caller audit.
- No blind save-breakage: schema cleanup must migrate on load before deprecated writes are removed.

## Current Risk Posture
- The repo is active and multi-writer. Cleanup should prefer small coherent commits.
- The highest-value deletions are in `🍄`, overlay/UI legacy quest paths, and stale tests.
- Core save/schema and grid/plot compatibility cleanup should happen after low-risk surface cleanup.

## Workstreams

### 1. 🍄 Registry Consolidation
Status: ready

Problem:
- `🍄/🎛️/profiles.py`
- `🍄/🎛️/milk_hunt_profiles.py`
- `🍄/🎛️/profile_save_registry.py`

These overlap and still split call sites between old and new loaders.

Actions:
- Move all callers to `🍄/🎛️/profiles.py`
- Fold profile-save registry helpers into `🍄/🎛️/profiles.py`
- Delete `🍄/🎛️/milk_hunt_profiles.py`
- Delete `🍄/🎛️/profile_save_registry.py`
- Update docs and CLIs to use the unified module only

Success criteria:
- One canonical profile/save registry module in `🍄`
- No imports of deleted modules remain

### 2. Quest UI Path Collapse
Status: ready

Problem:
- `UI/Managers/OverlayManager.gd` still creates and tracks:
  - `QuestPanel`
  - `FactionQuestOffersPanel`
  - `QuestBoard`
- The first two are legacy quest surfaces competing with the current modal board.

Actions:
- Audit call sites for `quest_offers` and `QuestPanel`
- Remove `FactionQuestOffersPanel` path entirely if unused in live gameplay
- Remove `quest_offers` overlay state/toggles/signals
- Remove `QuestPanel` if it is no longer part of the current player path
- Keep `QuestBoard` as the only quest UI surface

Success criteria:
- One quest overlay system
- No legacy browse-all quest panel creation in `OverlayManager`

### 3. Honest Player Input Backend
Status: ready

Problem:
- `UI/Core/PlayerInputMacroRunner.gd` still silently falls back to direct execution
- This hides real player-path bugs under the `player_input` label

Actions:
- Remove `_direct_fallback()` for actions that claim player-input support
- For unsupported actions, return explicit `not_supported_by_player_input`
- Keep direct execution as a separate backend only
- Expand headed smoke coverage to ensure real key-driven actions still work

Success criteria:
- `player_input` means real input routing, not hidden direct action execution
- Headed derby/manual smokes expose actual UI path failures

### 4. Stale Test / Play Rig Deletion
Status: ready

Problem:
- `legacy_tests/` contains clearly obsolete tests against dead APIs and classes
- Older play rigs have already started being removed; this needs completion

Actions:
- Delete `legacy_tests/`
- Remove doc references that still point at it
- Keep only live tests that target current `BootManager`, `PlayerShell`, `QuantumInstrumentInput`, `SnapshotService`, and save/load paths

Success criteria:
- No dead tests targeting removed concepts like `WheatPlot` or obsolete input/controller paths

### 5. Core Compatibility Shim Audit
Status: ready

Problem:
- Core still carries compatibility facades from older grid/plot/biome models:
  - `Core/GameMechanics/FarmGrid.gd`
  - `Core/GameMechanics/Grid/BiomeRoutingManager.gd`
  - `Core/GameMechanics/BasePlot.gd`
  - `Core/Farm.gd`

Actions:
- Audit remaining callers of:
  - `legacy_biome`
  - mirrored `current_state` reads
  - direct facade accessors preserved for backward compatibility
  - fallback plot/register fields
- Remove unused shims in smallest safe batches
- Preserve only the minimal headless-compatible path that current code genuinely uses

Success criteria:
- Canonical path is clear: register -> terminal -> plot
- Compatibility fields only remain where they are still required by active callers

### 6. Save Schema Tightening
Status: ready after workstream 5 audit

Problem:
- Save resources still export deprecated or compatibility-only fields:
  - `known_emojis`
  - `quest_slots`
  - old plot enum/load compatibility surfaces

Actions:
- Add/confirm migration-on-load for deprecated save fields
- Bump save version if necessary
- Stop writing deprecated fields into newly saved states once migration is proven

Success criteria:
- New saves reflect current schema only
- Old saves still load through migration

### 7. 🍄 Wrapper Collapse
Status: ready after workstream 1

Problem:
- `run_executor.py` is the correct center, but wrappers still custom-wire around it

Actions:
- Continue collapsing wrappers to `run_executor.py`
- Standardize one result envelope and one summary path
- Remove thin wrappers that add no independent value

Success criteria:
- One orchestration core for seed/run/batch/derby/session-style flows

## Recommended Execution Order
1. 🍄 registry consolidation
2. Quest UI path collapse
3. Honest player-input backend
4. Delete stale tests/play rigs
5. Core compatibility shim audit and removal
6. Save schema tightening
7. 🍄 wrapper collapse follow-through

## Commit Strategy
- Commit 1: `🍄` registry consolidation
- Commit 2: quest UI path collapse
- Commit 3: player-input backend honesty
- Commit 4: stale test deletion
- Commit 5+: core shim cleanup in narrow audited slices
- Commit N: save schema tightening after migration coverage

## Validation Gates
- Focused Python unit tests for `🍄` tooling after workstream 1
- Headed quest keyboard matrix after workstream 2
- Headed derby/manual smokes after workstream 3
- Save/load roundtrip tests after workstreams 5-6
- No fallback/deprecated imports referencing deleted modules

## Compact Handoff Note
At compact, the next execution turn should start at workstream 1 and proceed in order. Avoid mixing the low-risk `🍄`/UI cleanup commits with the later schema/core cleanup commits.
