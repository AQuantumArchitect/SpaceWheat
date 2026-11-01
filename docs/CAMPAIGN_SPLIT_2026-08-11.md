# Splitting the campaign — investigation, 2026-08-11

Owner's question: *"what do you think about splitting the campaign into multiple
campaigns? i'm thinking latern cant and most all of the advanced topology should
be split out of the main 'the demos' campaign."*

Produced by a twelve-agent study (five parallel readers over `story_flags.json`,
the scenario machinery, the advanced-physics inventory, the dependency graph and
the prior design docs; three independent split proposals under different
organizing lenses; three adversarial judges; one synthesis). Numbers marked
**[verified here]** were re-derived directly against the repo afterwards and are
not taken on the study's word.

---

## The short answer

**Yes, and the data is already most of the way there — but there is one number
that decides whether it's cheap or expensive, and it is not in the ending.**

---

## 1. The campaign is already four lanes wearing one act counter [verified here]

`Core/Quests/data/story_flags.json` holds 62 beats. Grouping them by their own
`display_name` prefixes gives:

| thread | beats | acts |
|---|---|---|
| spine (First Breath → village paths) | 16 | 0–5 |
| What Survives I–IV | 7 | 1–4 |
| Timber Country (Woodlot) | 5 | 2 |
| Spring Country | 4 | 2 |
| **Lantern Country** | 3 | 3 |
| Village Paths | 5 | 5 |
| **What Connects I–V** (bridges, knots, linking) | 5 | 5–7 |
| **What Turns I–V** (Betti, gauge, compass) | 5 | 5–8 |
| What Fades I–V | 10 | 6–8 |
| ENDING (`empire_imposes`, `island_free`) | 2 | 6 |

Acts 5–8 each hold **four independent threads sharing one number line**. Act 6,
for instance, is `What Fades I–II` + `the_span` + `turned_compass` +
`empire_imposes`/`island_free` — five beats from four unrelated stories.

That is the real finding. The split is less "cut the campaign apart" than "stop
pretending four campaigns are one." Four consecutive lanes were shipped by
interleaving into a single act spine; this reverses that precedent deliberately,
and the justification is that interleaving is exactly what produced a 2288-line
file in which an act-8 beat's completion condition lives inside an act-1 biome.

## 2. The ending survives the removal [verified here]

```
island_free (act 6) =
    story_flag_set  empire_imposes
  ∧ biome_spectral_gap_lte  Village ≤ 0.55
  ∧ atom_diversity_gte  ≥ 18
  ∧ signature_size_gte  ≥ 14

empire_imposes (act 6) =
    story_flag_set  ledger_opens
  ∧ biome_spectral_gap_gte  BloodLedger ≥ 0.6
```

The chain runs `island_free ← empire_imposes ← ledger_opens ← village_identity ←
island_lives ← lumber_flows / spring_connects / mill_wakes`. **Every link is in
the spine.** Zero dependency on Lanternfall, on What Connects, on What Turns, or
on What Fades. Grep confirms `the_span`, `braid_alphabet`, `the_fusion` and the
whole What Turns chain have no external dependents anywhere.

So the cozy game genuinely still ends after the removal. The advanced content is
already optional with respect to the ending.

## 3. The wall is three beats upstream, and it is one atom wide [verified here]

`village_identity` (act 4) requires `atom_diversity_gte: 26`.

The biomes reachable before act 4 — BloodLedger doesn't open until `ledger_opens`
at act 5 — carry these atom sets:

```
TheDemos           2   🌾👥
Village            8   ⚙❄🍞👥💨💰🔥🧺
StarterForest     12   ☀🌙🌱🌲🌿🍂🍄🐇🐺💀🦅🦌
Woodlot            6   🌱🌲🍂🔥🪓🪵
FreshwaterSpring   6   🌊🌿💧🔥🧊🫧
─────────────────────────────────────────
UNION             27
```

Lanternfall's six — 🌉🏁📯🗼🧂🪔 — are **disjoint from all five**, and today
`lantern_door` at act 3 is a *directed* discovery that lands them before the
act-4 gate. Remove Lanternfall and the headroom goes from 33 → **27, against a
threshold of 26.** Margin one.

`village_identity` is not colour. It is the hard predicate under `five_doors`,
under `ledger_opens`, under `empire_imposes`, and therefore under the ending. A
failure here presents as a grind wall, not a crash — which is worse. The Demos
also loses one of its eight taught icons (`lantern_teaching`'s 🌉/🪔) against
`signature_size` gates of 15 / 16 / 14.

**This is fixable and the fix is content, not engineering:** the Demos needs a
replacement directed act-3 discovery. Granary Guilds already receive standing and
have never hosted a chapter. Then measure the threshold on a rig run instead of
guessing it.

---

## Recommended shape: three campaigns, staged

**A campaign is a directory named by its `scenario_id`** —
`Core/Quests/data/<scenario_id>/story_flags.json`. Convention, not a manifest.
`scenario_id` already exists (`GameState.gd:21`), already persists, already
surfaces in save info. This is the cheapest formulation that admits a fourth
campaign later without inventing a second authority.

**Leaves for Lanternfall (15 beats):** `lantern_door`, `chain_ends`,
`lantern_teaching`, `lantern_wakes`, `chain_flipped`, and all ten of What Fades
(`the_crossing` … `the_door_stays_open`). Both world-state mutators go with them
— `regime_changes: {Lanternfall: "open"}` and
`physics_changes: {dissipative_dynamics: true}`. After the split The Demos
contains zero regime and zero physics mutations.

**Leaves for The Loom (12 beats):** `braid_order`, `braid_word`, and all of What
Connects and What Turns.

**Stays, deliberately:** `loop_remembers` (Berry phase is the *farming verb*
here, not topology — act 1 is where the game clicks, per the sonnet main-road
read); `pond_depths`/`pond_breathes` (cutting them guts act 2);
`island_stops_asking` (about the Demos as a people, not about topology).

**The Demos becomes** 35 beats, acts 0–6. Do **not** renumber —
`StoryAtlas.current_act` needs a contiguous fired prefix. Act 3 drops from 7
beats to 2, and one of those two (`mill_master`) is the only beat in the file
with `arc_quest: null`. One playable quest in a whole act, sitting exactly where
the last playtest already said *"Act 2 hands over the wheel abruptly"*, is worse
than today. Filling that hole is the work, not a footnote.

### Staging

| phase | what | risk |
|---|---|---|
| 0 | Add `"campaign"` to all 62 beats + partition test. Data only. | none |
| 1 | Campaign-directory resolution, unlocks-on-beats, `"ending": true`. Proven against `demos_normal` alone. | authority change |
| 2 | Lanternfall ships as campaign #2 — **`demos_normal.tres`'s biome pool untouched** | none |
| 3 | Author the Demos' replacement act-3 chapter, then rig-measure `village_identity` and retune. *Only then* trim the pool. | content |
| 4 | The Loom. | physics |

Every proposal wanted to trim the biome pool in the same breath as the split.
Don't — see cost #2 below.

### Smallest first step

Add `"campaign"` to all 62 beats and land `tests/test_campaign_partition.py`
asserting: the partition is total and disjoint over 62; every `story_flag_set`
reference inside a campaign resolves inside that campaign; exactly one
`"ending": true` per campaign; every UIProgression unlock flag lands in the Demos
partition.

Zero runtime change, no save touched, ships on main today. If the split is
rejected the field is inert metadata that costs nothing to leave in.

**What it proves:** run the closure assertion strict and the only failures should
be four cross-campaign predicates needing re-pointing (`the_crossing` ←
`chain_flipped`; `the_span` and `turned_compass` drop `the_crossing`;
`second_loop` ← a new opener). More failures than that means the partition is
wrong, and an afternoon bought that knowledge.

---

## What it costs

**Data** — large diff, near-zero risk. `story_flags.json` and `tutorial_arc.json`
split into per-campaign directories plus a **shared** `chapters/prologue_forest.json`
(three campaigns must not mean three copies of the StarterForest onboarding). No
id deleted or renamed; banked saves hold fired ids.

**Code** — `QuestManager.gd` (data load moves from `_ready()` to
`connect_to_farm()`, which already has the `scenario_id`), `UIProgression.gd`
(four const tables become derived), `StorySeedLoader`/`StoryEngine` (drop
`FLAGS_PATH`), `StoryAtlas` (chapter table moves into campaign data),
`RuntimeMount.gd:422` (`if flag_id != "island_free"` becomes the beat's
`"ending": true`, plus `ScenarioLedger.mark_completed()` which has had zero call
sites since it was written), `EscapeMenu.SCENARIO_LIST` + `SaveStore.gd:15`
(collapse the two-constants-kept-in-sync-by-comment pattern), and
`mint_checkpoint.py` (take `scenario_id` as an argument).

### Three things that are secretly the whole project

1. **UIProgression's tables fail CLOSED.** `_flags()` only fails open when
   `_no_farm()`. A live farm with an empty `story_flags_fired` gets no Captain,
   ever. Get this wrong and a mid-campaign Demos save silently loses
   Operator/Merchant/Captain — the exact anti-gating violation the split exists
   to avoid. Write the guard test *first*: load all 142 checkpoint `.tres` states
   and assert hat/menu/viz visibility is byte-identical before and after.

2. **The biome pool is persisted and scenario-authoritative with no add-back
   path.** `ObservationFrame.gd:191-204`: a curated non-empty pool is
   authoritative; its only writers are `unlock_biome`/`lock_biome`. Anything
   removed from a scenario's pool is gone from every save that scenario ever
   produces. This is what killed the "post-credits continuation" design outright,
   and it is why each campaign needs its own scenario rather than being a
   continuation of a finished Demos save.

3. **Every accumulation threshold is calibrated to the shipped road's supply.**
   `signature_size_gte 18` on `the_door_stays_open` in a campaign starting near
   zero; the `berry_consumed_count` staircases; `village_identity`'s 26. Three
   campaigns is three rig-measured retuning passes. That is measurement work, not
   code, and it is the honest cost line.

---

## What the judges killed

Two of three designs died on the step they called trivial.

**"The Cozy Cut"** (chapters as post-credits continuations of the finished save)
is elegant and needs no save-format change — and cannot work. Its step 8, "drop
the 5 biomes from `demos_normal.tres`," collides with the authoritative-pool rule
above; since every chapter opens with a Captain-hat discovery quest, all three
post-credits chapters become permanently unreachable. It also cited a
`BiomeDiscoveryForecastService.gd:104-105` discovery-bias bug — those lines are
the already-shipped *fix*, not the bug. And its "no behaviour change to
`current_act`" claim is false in effect: filtering the flag set collapses
`current_act` to 0 inside a single-act chapter, which un-retires the Act-0
tutorial (`TUTORIAL_RETIRE_ACT = 2`) and re-locks verbs post-credits.

**"Five Lessons, One Engine"** (split by mechanic taught) rests on "each campaign
already exists in the data" — false for four of five; what exists is the *top* of
five ladders whose lower rungs are Demos beats. It misread `fence_remembers`'
`biome_betti_gte` as the cross-biome NeighborhoodGraph when it is β₁ of that
biome's own coupling graph via `GaugeField.betti_1()`, so its scenario-sizing
rationale solves the wrong problem. It also swapped `pond_depths`' predicate type
while keeping the threshold, risking an unreachable act-2 wall, under "nothing
the player can see changes."

**"Three Countries"** (the winner) survived with real errors: it said 395
checkpoints where there are 395 *files* but 142 `.tres` states; it claimed "no
save-format change," true of the schema but false of the semantics (`scenario_id`
changes meaning from starting-loadout provenance to campaign identity, and
`GameState.gd:21` defaults it to `new_game_easy` while `SaveStore.gd:15` defaults
to `demos_normal`, with nothing validating either at load); and its own smallest
first step ships the stranding bug the proposal itself diagnosed. Its claim that
the ending needs no verification "because the thresholds stay inside the
campaign" is a non-sequitur — the *supply* left. That is §3 above.

---

## Remaining uncertainties — read these before acting

- **Whether 27 is a ceiling or the live value.** `atom_diversity_now()` counts
  `register_map.coordinates` keys across loaded biomes; nobody verified whether a
  biome's register holds its full atom roster at boot or only *seated* atoms. If
  seated-only, the act-4 margin is worse than 1. **Rig-probe this from the act4
  checkpoint with Lanternfall excluded before Phase 3.** Single most important
  measurement in this document.
- **Whether the re-sited topology predicates fire at all.** `second_loop`,
  `the_knot`, `close_it_upstairs` were tuned against StarterForest (5 plots, 12
  emojis). Whether frozen loops, linking ≥ 2 and β₁ ≥ 1 are reachable in a
  smaller starting world is unverified. This is the one place the split needs
  real physics work rather than data moves.
- **Lanternfall's own gates under a near-zero starting signature** (🪔 ≥ 0.52,
  📯 ≤ 0.25 ∧ 🌉 ≥ 0.35, `signature_size ≥ 18`) are all calibrated to a
  Demos-length lexicon. Unmeasured.
- **Boot ordering** if QuestManager's data load moves out of `_ready()`. Its own
  headless verification step, not a code-review item.
- **`pond_depths` gates on `biome_eigenvalue_gap_gte` against closed
  FreshwaterSpring**, while `QuestManager.gd:412-415` states that predicate is
  degenerate (≡1) in a closed system and "the closed campaign must NOT gate on
  them." Unrelated to the split; worth its own ticket either way.
- **Post-split the Demos hands the player Spark at `edge_of_the_enclave` with no
  wet ground anywhere in the campaign** — `UIProgression`'s own comment calls
  Spark "useless inside the enclave." Keeping the unlock is right for banked
  saves, but the hat becomes a dead affordance and should say so.
- **Two owner-reserved questions this does not answer**
  (`docs/OPEN_CAMPAIGN.md:260-264`): where the wet-country door ships, and
  whether the enclave is inviolable forever. Standalone Lanternfall makes both
  *easier* to answer later; it must not be read as answering either.
