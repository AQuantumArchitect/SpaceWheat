# The Campaign — how the story is built, ordered and tested

*Owner of record: Luke. Restructured 2026-10-17 (campaign spec + validator).*

The story lives in ONE file: **`Core/Campaign/campaign.json`**. Everything the
game reads about the story is generated from it:

| Generated file | Read by |
|---|---|
| `Core/Quests/data/story_flags.json` | QuestManager (flags), StoryEngine (beats, offers), hive tools |
| `Core/Quests/data/tutorial_arc.json` | QuestManager (the Act-0 lesson chain) |
| `Core/Quests/data/campaign_runtime.json` | `CampaignRuntime.gd`: act/chapter titles, hat/menu/overlay unlocks, Captain chart targets and cost, the resource table |

Never hand-edit the generated files. Edit the spec, then:

```
python3 tools/campaign/build.py       # regenerate
python3 tools/campaign/validate.py    # prove every campaign can be played through
python3 -m pytest tests/test_campaign_spec.py -q
```

CI runs `build.py --check` and `validate.py` on every push.

## The model

**Campaign › Act › Chapter › Beat.** Three campaigns:

- **The Demos** — the main story, Acts 0–6, ends at `island_free`.
- **What Fades** (Lanternfall) and **The Loom** — post-game campaigns. Both open
  after `island_free`, and neither feeds the main story.

A **beat** is one story step:

- It **opens** when every beat in `requires` is complete. Choice beats, such as
  the five village paths, also carry a `trigger`: the world condition that picks
  that path.
- An **offered** beat (one with `offer`) appears on the Arc tab and waits for the
  player to **Accept** it; it completes when its **`objective`** holds and is
  claimed. Accepting stays manual so alternative routes can be added later.
- A beat with no `offer` is a milestone. It completes the moment it opens and its
  objective holds.
- **`on_open`** effects apply when the beat opens: `standing` grants, `unlock`
  (`hats`, `menus`, `viz`), `regime_changes`, `physics_changes`.
- `offer.teaches: [north, south]` is the word the claim teaches.
- `chart: <Biome>` marks a **door**. While it is open, the Captain can chart that
  biome deliberately (not a random pull) for `chart_cost`.

Each beat asks for **one thing**. A beat opens on its requires alone. The old
pattern, where a flag's predicates, its arc quest and the next flag's predicates
all re-checked the same condition, is gone.

### Parameters

Every threshold is a named parameter (`params.ladder`, `params.berry`,
`params.hub`), written `"$hub.signature"` in a predicate. Text can quote one as
`{$hub.signature}`, so a hint never states a stale number.

### Resources: plots, trades, rescue

The `resources` table lists every resource a story step spends. For each
resource it gives:

- `plots`: biomes whose registers yield it.
- `trades`: standing contracts that always sit on that biome's board.
  - The market is how south poles are earned: 🪓 at the Woodlot, 🌊 at the
    Spring, 🔨 and 🧺 in the Village.
  - Every resource also has a Village trade that a broke player can afford.
    That is the rescue: an empty wallet is never a dead end.
- `low_water`: the objective banner switches to the supply walk before a spend
  would take you below it.

## What the validator proves

`tools/campaign/validate.py` replays each campaign beat by beat with a supply
model built from the repo's own data: the scenario start, biome, faction and
icon registries, plus the spec's teachings, plants, charts, grants and unlocks.
It fails when any of these is true:

- a beat requires an unknown or later-act beat, or there is a cycle
- a post-game beat doesn't wait on the main ending
- an objective needs a hat that isn't unlocked yet
- an objective names a biome that isn't loaded, or a story biome has no chart beat
- a planted word isn't known, or its 🌱 or south-pole cost has no plot or trade
  by then
- berries are counted before Incorporate is taught (`first_breath`, Act 1)
- a signature, diversity or Village-ring gate is above what's reachable at that
  beat (with margin)
- a standing ladder needs more than `params.ladder.max_deliveries` kept
  deliveries beyond what the story already grants. It warns when a ladder asks
  for none.
- a resource has no Village rescue trade, or a trade asks for something no
  nearby plot yields

`tests/test_campaign_spec.py` also checks that the validator catches the classic
walls.

## Current structure

### The Demos — ending: `island_free`

| Act | Chapter | Beats |
|---|---|---|
| 0 The Loop | Six Lessons | 6 tutorial steps |
| 0 The Loop | First Fruits | first_harvest, loom_opens |
| 1 The Village | The Wheel Is Yours | arc_handover |
| 1 The Village | Apprentice to the Mill | village_stirs |
| 1 The Village | First Breath | first_breath (Incorporate), spiral_breaks |
| 1 The Village | New Voices | new_voices |
| 2 Two Countries | Timber Country | woodlot_door, woodlot_contact, lumber_flows, woodlot_wakes, timber_rhythm |
| 2 Two Countries | Spring Country | spring_door, spring_contact, spring_connects, spring_wakes, pond_depths, pond_breathes |
| 2 Two Countries | Two Tables | two_tables |
| 3 What the Land Remembers | The Forest Listens | forest_evolving, forest_listener, forest_communion, loop_remembers |
| 3 What the Land Remembers | The Mill Wakes | mill_wakes, mill_master |
| 4 The Island & Its People | The Island Wakes | island_lives, village_identity, five_doors |
| 4 The Island & Its People | The Dark Teachers | eagle_overhead, serfs_ledger, island_stops_asking |
| 5 Five Doors | The Village Chooses | village_path_* (choose one or more) |
| 5 Five Doors | The Blood Ledger | ledger_opens, edge_of_the_enclave |
| 6 The Empire | The Empire Imposes | empire_imposes, island_free |

### What Fades — post-game, opens after `island_free`, ending: `the_door_stays_open`

| Act | Chapter | Beats |
|---|---|---|
| 1 Lantern Country | Five Lights | lantern_door, chain_ends, lantern_teaching, lantern_wakes, chain_flipped |
| 2 The Wet Country | What Fades | the_crossing, the_gray, watching_keeps |
| 3 Open Water | Verbs of the Open | the_verbs_come_home, the_first_contract, the_basin, the_chain_tested, hiding_in_the_light |
| 4 The Door | The Door Stays Open | the_rite, the_door_stays_open |

### The Loom — post-game, opens after `island_free`, ending: `close_it_upstairs`

| Act | Chapter | Beats |
|---|---|---|
| 1 Braids | Words You Were Never Given | braid_order, braid_word, second_loop, the_knot, loop_came_home |
| 2 Bridges & Compass | The Span | the_span, turned_compass |
| 3 What Holds | What Holds | braid_alphabet, the_fusion, fence_remembers, the_number_lied |
| 4 Upstairs | Close It Upstairs | close_it_upstairs |

## Testing and jumping to a beat

<!-- filled in with the fixtures work -->
