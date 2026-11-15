# Arcs bundle Charges

*Design for #94 (Luke's pacing direction, 2026-11-14). Phase 1 is built: the
model, the compiler, the validator, the UI, and the Demos Acts 0–1. Phases 2+
(#95–#97) regroup the rest of the campaign, and are a plan only.*

## The model

Before, one Arc quest meant one Charge: every story step was its own Arc row,
its own Accept and its own Claim. That is a lot of handling.

Now an **arc** is a bundle of **1–6 charges**. A charge is an offered beat:
an ask with an objective, claimed on Charge [U].

- **Accept** an arc on the Arc tab (X → Y, row key, **R**). Every one of its
  charges goes on Charge together.
- **Work** them in any order. Each one is claimed on Charge when it reads READY.
- **An arc completes when all of its charges are claimed.** The Arc then
  offers what opens next, and that can be more than one arc. The tutorial
  stays linear, but the model and the UI already support a choice of next arcs.
- **One-charge arcs** are for large events only. The spec marks them
  `large_event`, and the validator refuses a one-charge arc without it.

Milestones (beats with no offer, such as First Harvest or The Milk Runs Out)
are not charges. They fire on the world, as before, and an arc may wait on one.

**Overflow.** Charge shows six rows at a time. When more than six charges are
held, A/D pages them, as every other paged tab does. Nothing refuses a new arc.
That is the simplest choice, and it can be revisited if real play piles up
charges.

## In the spec

An arc lives in its chapter (`Core/Campaign/campaign.json`):

```json
{
  "id": "the_wheel",
  "title": "The Wheel Is Yours",
  "arcs": [{
    "id": "the_wheel",
    "title": "The Wheel Is Yours",
    "body": "The Village hands you the wheel. …",
    "requires": ["first_harvest", "loom_opens"],
    "charges": ["arc_handover", "village_stirs"]
  }],
  "beats": [ … arc_handover, village_stirs … ]
}
```

- The **arc owns `requires`**. A charge does not author its own;
  `spec.apply_arcs` copies the arc's requires onto each charge when the spec
  loads. All of an arc's charges therefore open on the same evaluator pass,
  and accepting the row accepts them all.
- A `requires` entry may name an **arc id**. It stands for every charge of
  that arc, which means "after that arc completes". Any beat may use it:
  Act 2's two doors wait on `voices`.
- Arc ids share no namespace with beat ids. The validator refuses a clash.

`build.py` compiles this into the runtime files:

- Each charge's story flag, and its `arc_quest`, carries `"arc": <id>`.
  Offers are made from the arc_quest, so every quest dict knows its arc.
  Saves from before arcs have no key, and `QuestManager.arc_of` falls back
  to the spec.
- `campaign_runtime.json` gets an `arcs` list:
  `{id, title, body, campaign, act, chapter, charges, requires, after, next, large_event}`.
  `after` and `next` name the arcs it waits on and the arcs that wait on it.

At runtime nothing new decides when a beat opens. The door rule (a child
waits until its parent's quest is claimed) already is "requires = complete".
Since an arc's charges share requires, the next arc opens exactly when the
last charge of the one before is claimed.

## What the validator proves

On top of the per-beat replay (docs/CAMPAIGN.md), `validate.py` checks:

- every arc has 1–6 charges, and a one-charge arc is a `large_event`;
- every charge is an offered beat of the arc's own chapter, and sits in one arc only;
- a chapter that declares arcs leaves no offered beat out of them;
- arc requires resolve to a beat or an arc;
- **the arc loop.** From the roots it opens whatever the requires allow,
  completes each milestone and each open arc (all its charges on one pass),
  and repeats. Every campaign's ending, and every beat, must be reached.
  This runs for the Demos, What Fades and The Loom.

## The UI

- **Arc (X → Y).** An arc is one row: `ARC`, the arc's title, and "2 charges"
  (or "1/2 done" once some are claimed). Under the title, one line per charge:
  `•` is signed by this Accept, `·` is already on Charge, `✓` is claimed.
  Selecting the row shows the arc's body and each charge's hint. **R** is
  "Accept all", **Q** dismisses the whole bundle, and **E** shows each
  charge's body.
- **Charge (X → U).** Held charges sit together under a header with the
  arc's progress: `The Wheel Is Yours · 1/2 done`. A selected charge shows
  its ask and where each end condition stands now, in readable type. The tab
  opens with row G picked, so the first G press only selects it. Only a
  second press on a selected row goes to the work, which keeps "U → G → E"
  on the tab.
- **E on Charge** (Luke, 2026-11-14) opens **"What to do"**: numbered steps
  in the order the gold toast will ask for them, ending with where to claim.
  For Apprentice to the Mill, seen in a headless run:

  ```
  1. On the field (ESC closes this menu), go to Village [Y].
  2. In Village: board [C] → Market [Y] → take a Millwright's Union delivery [R].
  3. Gather what it asks, then Commitments [U] → Deliver [R].
  4. Keep Millwright's Union deliveries until this charge reads READY.
  5. When it reads READY, claim it here on Charge [U]: its row key, then Claim [R].
  ```

  `Guide.preview(q)`
  builds the steps from the same `guide.walks` and keymap that the toast reads,
  so the preview and the toast cannot drift apart. Every later phase keeps
  this rule: a charge's E view previews its upcoming toasts.

Only R accepts (#76), and E gives more (#81).

## Phase 1: the Demos, Acts 0–1

Lesson order and the owner decision of 2026-10-17 (Incorporate is taught
right after the mill apprenticeship) are kept.

| Arc | Charges | Opens after |
|---|---|---|
| The Wheel Is Yours | arc_handover, village_stirs | first_harvest + loom_opens (the end of Act 0) |
| First Breath *(large event)* | first_breath | The Wheel Is Yours |
| New Voices | spiral_breaks, new_voices | First Breath |
| Find the Milk *(large event)* | find_the_milk | milk_runs_out (a world event) + First Breath |

- `arc_handover` is a handshake. It claims itself the moment the arc is
  accepted, so the first arc shows "1/2 done" right away.
- Act 0 (`first_fruits`) holds only milestones and the lesson chain, so it has
  no arcs.
- Both Act 2 doors (`woodlot_door`, `spring_door`) now wait on the whole New
  Voices arc. They used to wait on `new_voices` alone. That makes
  `spiral_breaks` a gate rather than an optional leaf.

Old saves still load. Every new `requires` closure is the old one or looser.
`first_breath` used to wait on `village_stirs`, which waited on `arc_handover`.
Fired flags stay fired, and `legacy_unlocks` is unchanged. A save holding
only part of an arc shows the rest as that arc's row, and Accept signs what
is left.

## Phases 2+ (plan)

Each phase regroups a part of the campaign in the same way. Arcs follow chapter
seams, chains inside a chapter become the order of its arcs, and every charge's
E view previews its toasts. The groupings below are first proposals. The rule
that an arc's charges open together decides each one: a beat that needs
another beat's outcome goes in a later arc.

**#95: Act 2 (Two Countries).** The two countries run side by side, the first
real optionality: New Voices opens both door arcs.
- Timber: *Timber Door* (woodlot_door alone, a large event: the first chart),
  then *Woodlot* (woodlot_contact, lumber_flows), then *Timber Rhythm*
  (woodlot_wakes, timber_rhythm).
- Spring: *Spring Door* (spring_door, a large event), then *Spring*
  (spring_contact, spring_connects), then *The Pond* (spring_wakes,
  pond_depths, pond_breathes). These are chained today, so they need a look
  at which can share an arc.
- `two_tables` stays a milestone.

**#96: Acts 3–4 (What the Land Remembers; The Island & Its People).**
- *The Forest Listens* (forest_evolving, forest_listener), then *Communion*
  (forest_communion, loop_remembers).
- *The Mill Wakes* (mill_wakes, mill_master).
- *The Island Wakes* (village_identity, five_doors), after the island_lives milestone.
- *The Dark Teachers* (eagle_overhead, serfs_ledger, island_stops_asking).
  All three already open together on village_identity, so this is the
  cleanest bundle in the game.

**#97: Acts 5–6 and the post-game.**
- *The Village Chooses*: the five village_path_* beats are trigger
  choices. Decide whether a choice set is an arc of its own kind before
  bundling them.
- *The Blood Ledger* (ledger_opens, edge_of_the_enclave), then *The Empire
  Imposes* (empire_imposes, island_free as a large event: the main ending).
- What Fades and The Loom: one or two arcs per act, along the existing
  chapters (Five Lights, What Fades, Verbs of the Open, The Door Stays
  Open; Braids, The Span, What Holds, Close It Upstairs).
