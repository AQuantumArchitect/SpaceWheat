# Starter Island Story Flags

This is the live starter-island arc map.

The current quest surface is the `QuestBoard` Arc tab (`C → Arc`), and the rig exposes the same data through the `story_flags` read action:

- `flags_fired`: `{flag_id: phrame}`
- `story_log`: `[{id, act, display_name, arc_beat, fired_at}]`

Story flags fire once when their predicates are satisfied. The Arc tab shows a soft progress projection, but the actual fire check is threshold-based. The story log records the beat the moment a flag fires.

## Live Arc Order

| Flag | Act | Trigger | Player-facing beat |
|---|---:|---|---|
| `first_breath` | 0 | `signature_size_gte: 2` | The first wheel. Fires as soon as the starter signature exists. |
| `forest_evolving` | 1 | `StarterForest` evolving + `berry_consumed_count_gte: 1` | The forest wakes. |
| `forest_listener` | 1 | `forest_evolving` + `berry_consumed_count_gte: 3` | The forest listens back. |
| `forest_communion` | 1 | `forest_listener` + `berry_consumed_count_gte: 5` + `berry_total_phase_gte: 12.566` | The druid loop closes. The forest is now fully listened to; no quest follows. |
| `village_stirs` | 1 | `forest_listener` + `Village` evolving + `berry_consumed_count_gte: 1` | The village starts to wake. |
| `lumber_flows` | 2 | `forest_evolving` + `Woodlot` evolving + `berry_consumed_count_gte: 1` + `Millwright's Union` access `>= 0.2` | Upstream wakes - woodlot. Offers a `DELIVER` arc quest to add `🪵` to `Village`. |
| `spring_connects` | 2 | `Hearth Keepers` trust `>= 0.25` + `FreshwaterSpring` evolving + `berry_consumed_count_gte: 1` | Upstream wakes - spring. Offers a `DELIVER` arc quest to add `💧` to `Village`. |
| `mill_wakes` | 3 | `Village` evolving + `💨` and `⚙` state thresholds + `berry_consumed_count_gte: 2` + `biome_attractor_emoji_gte: ⚙` | Commerce flips on. Offers a `MAINTAIN_COHERENCE` arc quest. |
| `mill_master` | 3 | `mill_wakes` + `berry_consumed_count_gte: 5` + `berry_total_phase_gte: 18.85` | The mill is now owned, not just running. |
| `island_lives` | 4 | `lumber_flows` + `spring_connects` + `mill_wakes` + `atom_in_biome: Village / 🪵` | The island behaves like one system. |
| `village_identity` | 4 | `island_lives` + `atom_count_gte: 12` + `signature_size_gte: 14` + `biome_eigenvalue_gap_gte: 0.12` | The village takes a character. |
| `ledger_opens` | 5 | `village_identity` + `BloodLedger` evolving + `berry_consumed_count_gte: 2` | The ledger opens. Offers a `DELIVER` arc quest to starve the tribute pipeline. |

## What I Observed In The Live Rig

- On a fresh `new_game_easy` boot, `first_breath` fires immediately once the listener starts evaluating the farm.
- `consume_berry` in `StarterForest` is the action that advances the early forest arc.
- One berry in `StarterForest` fires `forest_evolving`.
- Three berries in `StarterForest` fire both `forest_evolving` and `forest_listener`.
- `probe_cycle` does not advance the forest story by itself. It explores/measures/pops resources, but the story beat comes from berry consumption.

## Mechanics Notes

- The Arc tab is not a separate lore system. It is a projection of live predicates and fired flags.
- `forest_communion` is the end of the starter forest beat. It is a story flag only; no quest follows it.
- The current live story graph is defined in `Core/Quests/data/story_flags.json`.
- If the live arc and this document diverge, the live `story_flags` output is the source of truth.
