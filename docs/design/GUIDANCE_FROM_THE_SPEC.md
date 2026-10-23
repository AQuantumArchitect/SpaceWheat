# Guidance from the spec: the campaign vs. the hint toast

> Investigation, 2026-10-19. Status: **built** (see "What was built" at the
> end). The proposal sections below are kept as written; the results of
> building it are appended.

## The question

The story now lives in one compiled spec (`Core/Campaign/campaign.json`), and
the validator says every act can be finished. Players and playtest bots still
wall. The owner's suspicion is that the on-screen guidance is the problem, and
that the fix is a change of process, not one more patch.

The guidance has four parts:

- the objective banner (`UIProgression.objective_text()`, drawn by `ActFilament`)
- the hint toasts (`PlayerShell.show_hint`)
- the board cues (`QuestBoard.board_walk_cue` / `fill_shortfall_cue`)
- the key spotlight (`ObjectiveSpotlight`)

## What I measured

`🍄/🧪/banner_follow.py` is a player who trusts the banner completely and
knows nothing else. For each main-campaign beat it does the following:

1. Builds the beat's opening state with the spec fixture (`start_at_beat`).
2. Presses exactly the keys the banner names, in the order it names them.
3. Re-reads the banner and repeats.

A beat counts as **moved** if a story flag fires or the beat's own Arc quest
is claimed within 150 presses. It is not an LLM, and it uses no seams.

| Code | Beats moved (of 40) | Why the rest stopped |
|---|---|---|
| `main` (`fa37bec`) | **2** (`arc_handover`, `mill_master`) | 33 on "▸ [G] a living plot"; 3 on "▸ [Q] Abandon — you hold 👥 N/N"; 2 with no key ("Strike a sleeping plot.") |
| WSL working tree (snapshot `7570985`, the grok fleet's uncommitted fixes) | **2** (same two) | 35 on "▸ [G] a living plot"; 2 with no key; 1 on "▸ [R] Accept" |

The WSL fixes removed the Abandon stall, and those beats moved to the
"[G] a living plot" stall instead. That is the pattern in one line: each
patch moves the wall rather than removing it.

Two failures explain most of the table:

- **The banner chases the wrong beat.** Starting at `forest_evolving`, four
  Arc offers are open: `spiral_breaks` (optional), `woodlot_wakes`,
  `spring_wakes` and `forest_evolving`. `_banner_quest()` ranks asks by
  *kind* (board > plant > discover > teaching > berry), not by the story. So
  the berry walk for the optional `spiral_breaks` takes the banner, while the
  live door waits unmentioned. The same ladder pulls 33 different beats onto
  the same berry line.
- **The banner names a key whose precondition it never teaches.** "▸ [G] a
  living plot" is printed whether or not a living plot exists. In the
  fixture, every plot is unrevealed. Pressing G focuses a plot, the plot is
  still not living, and the banner repeats forever. The step that is
  actually missing (explore first, `[8] Ace` then `[F]`) is never derived.

**Caveat.** A fixture is not a played save: it does not explore plots for
you. A human arriving at Act 2 by play would usually have revealed plots. The
ranking failure does not depend on that. A banner that cannot recover from
"no living plot" also walls the first player who culls or replants, which is
exactly what the w18–w23 `new_voices` waves recorded.

The scripted honest drive (`🍄/🧪/honest_opening.py`) does reach the opening
of Act 3, so the game is playable. **The game can be played; the guidance
cannot be followed.**

## Why patches stopped working

From the 29 tracked wave reports, the ant repair cards up to wave 50, and the
code itself:

- **About 95 special-case blocks cite a wave, persona or beat id.** 53 are in
  `UIProgression.gd`, 23 in `QuantumInstrumentInput.gd`, and the rest in
  `QuestBoard`, `HintToast`, `PredicateGloss` and a few others.
  `UIProgression` alone has 94 hand-written "▸" lines, 7 `_is_*_ask`
  classifiers and about 25 text/spotlight twin functions. Some branches
  compare against literal beat ids (`"lantern_teaching"`, `"braid_order"`)
  or emoji (`⚙`, `🪔`).
- **Each wall got its own branch, and the branches interact.**
  - The fight over who owns F was patched in w12, w13, w16, w19 and w23.
  - The dual [R] was patched in w7, w15 and `lantern_door`.
  - The X/ESC ping-pong is still being patched in the WSL diff, which
    detects it by searching the banner's own text (`"ESC" in walk`).
- **Several voices speak about the same moment and disagree.**
  - The offer toast always says "▸ [X] then Arc [I]".
  - The banner says something else.
  - The board cue says a third thing.
  - The spec's own `offer.hint` prose is a fourth, written by hand with keys
    in it.
  - There are about 117 toast call sites across 13 files.
- **The bots' structural ideas are stranded.**
  - `SpineRecipe` compiles a beat's walk from its fields, but only a
    checker uses it, not the game.
  - `SurfaceRooms` (Arc = [Y]) and `VerbGrammar` (Reap = Ctrl+Shift+Space)
    contradict the live banner ("Arc [I]", "Shift+F"), and nothing is wired
    in.
  - All three are untracked files in the WSL checkout.

The wall classes, by count of incidents: shortfall with no route or the
wrong route (about 19), a named key that does something else in the current
context (about 18), a verb named with no key (about 15), loops (about 15),
the wrong objective (about 11), and the voices disagreeing (about 11).
Almost all of them are symptoms of one fact: **guidance is written as
strings in many places, instead of being computed once from the spec, the
game state and the key map.**

## The proposal: one resolver, parameterized by the spec

### 1. The spec says *how*, not just *what*

`campaign.json` already says what each beat needs (`objective`, `requires`,
`chart`, `resources`). Add a `guide` block that says how each kind of
objective is done, as data:

```jsonc
"guide": {
  "keymap": {                         // the one place keys are spelled
    "hats":     {"ace": "8", "icon": "5", "captain": "7", "operator": "9", "druid": "0"},
    "surfaces": {"arc": ["X", "I"], "charge": ["X", "U"], "board": ["C"], "market": ["C", "Y"]},
    "verbs":    {"explore": "F", "strike": "R", "gather": "Q", "track": "F", "incorporate": "R",
                 "accept": "R", "claim": "R", "chart": "R", "reap": "shift+F"}
  },
  "steps": {                          // reusable steps, each implemented once in GDScript
    "living_plot": {"needs": "revealed_plot",
                    "else": [{"hat": "ace"}, {"verb": "explore"}]}
  },
  "walks": {                          // one per objective predicate type (33 today)
    "berry_consumed_count_gte": [
      {"travel": "$pred.biome"}, {"hat": "icon"}, {"select": "living_plot"},
      {"verb": "track", "done": "tracking"}, {"wait": "ripe", "say": "the loop ripens"},
      {"verb": "incorporate"}
    ],
    "standing_gte":   [{"deliver_to": "$pred.faction"}],
    "biome_evolving": [{"chart": "$pred.biome"}],
    "gate_order":     [{"hat": "operator"}, {"gates": "$pred.gates"}]
  },
  "door": {                           // every beat's handshake, shared
    "accept": [{"open": "arc"}, {"row": "$beat"}, {"verb": "accept"}],
    "claim":  [{"open": "charge"}, {"row": "$beat"}, {"verb": "claim"}]
  }
}
```

A beat may carry a `guide` override for the rare case a template doesn't
fit. The validator rejects an override that duplicates the template.
`offer.hint` stays as story prose, and a lint rejects `[KEY]` inside it:
keys come only from the keymap.

### 2. One resolver computes the next press

`Core/Campaign/Guide.gd` would be a pure function over a snapshot of the
game and UI:

```
next_step(state) -> {beat, step, key, shift, text, pointer_target, why}
```

1. **Pick the live beat by the story, not by kind.** The critical path comes
   first (an offer some unfired beat requires), then the earliest act. This
   is the ranking `waiting_arc_offer()` already uses, applied to every
   offer. Optional leaves wait.
2. **Expand the beat's walk.** If the beat isn't accepted, take the door
   steps, then the objective walk, then the claim steps.
3. **Return the first step not already satisfied by the current UI state.**
   Each step type has one `done(state)` (overlay open, hat worn, plot
   selected, plot living) and one `render(state)`. This is what kills
   ping-pong. "Open the Arc" is done once the Arc is open, so the resolver
   moves on to the row. Nobody has to search the banner text for "ESC".
4. **Insert a supply walk when a step costs what the wallet lacks.** The
   route comes from `resources` and its trades. That table already exists
   and already works for refusals.
5. **Every step carries both a key and a pointer target.** The text says
   "click the Arc tab or press [I]", which restores the click-first rule
   that walk lines lost after w4.

### 3. Every voice reads the resolver

- **Banner and spotlight** render `next_step()`. Nothing else.
- **Board cues** render the resolver's step when the board is the current
  surface, instead of computing their own.
- **Toasts are events on resolver transitions** (auto-toast):
  - When a new live beat appears, one gold card with its title, routed to
    its door.
  - When a step is refused, one teal card naming the cause and the supply
    route.
  - Never a card that repeats the banner's current step.
  - `IntroVoice.toast_for_offer`/`toast_for_flag` and the guidance-shaped
    `show_hint` calls go away. Ambient toasts (postcards, whispers) stay on
    their own lower channel.
- **Refusals** (`RefusalVoice`, the QII guards) ask the resolver what would
  unblock, instead of carrying their own lines.

### 4. The process change: walls become test cases first

| Layer | What it checks | Runs |
|---|---|---|
| L0, static (`validate.py`) | Every objective type in the spec has a walk. Every hat, surface and verb named resolves in the keymap, and the keymap matches `ToolConfig`/QII bindings. No `[KEY]` appears in hint prose. | CI, every push |
| L1, resolver tables | For each step type, UI state → expected step, generated from the spec | CI, every push |
| L2, `banner_follow.py` | From every beat's fixture, following only the banner moves the story | CI as a ratchet (beats moved may only go up); full sweep nightly or on S3 |
| L3, LLM personas | Can a person *understand* the text? Legibility only. | Waves, after L2 is green for that act |

The rule that ends whack-a-mole: **a persona wall is not fixed until it is a
failing L1 or L2 case.** Only then is the fix made, and the fix goes in the
spec or a step type, never in a new string branch.

### 5. Migration

1. **Done on this branch.** `banner_follow.py` and the baseline: 2 of 40.
2. **Keymap and resolver** covering travel, hat, select (with the
   living-plot fallback), door (accept and claim), and deliveries. The
   banner uses the resolver for beats it fully covers and the legacy line
   otherwise. Fold `SurfaceRooms` and `VerbGrammar` into the keymap here,
   so their [Y]/[I] and Reap disagreements get settled once.
3. **Berry, plant and chart walks.** These cover most of Acts 1–3.
4. **Move toasts to resolver transitions.** Delete the duplicate offer and
   flag toasts.
5. **Delete legacy `objective_text` branches** as the follower confirms each
   act. The target is 40 of 40 demos beats moved, then the post-game
   campaigns.

The follower runs the sweep in about 17 minutes on 2 cores (40 beats at
roughly 25 seconds each). Each step's success is the number going up.

## Reproduce

```bash
python3 🍄/🧪/banner_follow.py --campaign demos --jobs 2 --out follow.json
python3 🍄/🧪/banner_follow.py village_stirs forest_evolving   # a few beats
```

Sources: `🍄/🧪/hive/waves/` (w3–w29), the ant repair cards and late-wave
notes on the owner's machine (`semantica3/scratch/sw-ant-*.md`, waves up to
about 50), and the WSL working-tree snapshot pinned by S3 for verification
(`_wt/spacewheat-s3-current-20261019`, commit `7570985`).

## What was built (2026-10-19, branch `guidance-resolver`)

The proposal, as implemented:

- **`Core/Campaign/campaign.json` → `guide`**: the keymap (hats, surfaces,
  rows, verbs, boards, reach) and one walk per objective predicate type,
  plus one `lesson:<teaches>` walk per Act 0 lesson. Every objective type in
  the spec has a walk; `validate.py` errors on an unknown step or an
  unwalked Act 0 lesson and warns on an unwalked main-campaign type (now
  zero).
- **`Core/Campaign/Guide.gd`**: the resolver. `live_beat()` ranks Arc quests
  by the story (critical path to every campaign ending first, then act,
  ready beats ahead of everything). `next_step()` takes the door (accept),
  then the first unsatisfied step of each open predicate's walk, then the
  claim. Each step type is one function that checks the UI state first, so
  "open the Arc" is skipped once the Arc is open and a field chord always
  closes an open overlay first. Shortfalls insert a gather walk (Ace:
  explore → strike → gather), falling back to the spec's market trade when
  the land keeps measuring the other pole.
- **Voices**: the banner and the key spotlight ask `Guide.next_step()`
  first and fall back to the legacy lines only when it returns nothing. The
  Arc's NOW row is `Guide.live_beat()`. Story offers no longer each raise a
  card; `PlayerEventBridge` raises one gold card when the live beat changes,
  carrying the resolver's step.
- **Rig**: a read-only `guide_step` verb returns the resolver's step, live
  beat and tutorial step.

Not done yet: board cues and refusals still carry their own lines, and the
legacy `objective_text` branches are not deleted (they are the fallback).

### Iterations

Two measures. The **fixture sweep** starts each of the 40 main-campaign
beats from its spec fixture and counts beats where following the banner
moves the story. The **fresh journey** starts a new game with no fixture
and follows the banner for up to 45 minutes; it stops at the Demos ending
(`--until island_free`), on a two-line loop, or on a wait that never
changes.

| Run | Fixture sweep | Fresh journey |
|---|---|---|
| Baseline (`main`) | 2/40 | — |
| Resolver, first cut | 17/40 | — |
| + Arc NOW row is the live beat, close-first chords | 23/40 | — |
| + `_plot_bound` strike rule, mark clearing, Act 0 lesson walks | 38/40 | 20 beats, walls at `mill_wakes` (no walk for the attractor ask) |
| + steer walk, cross-predicate ranking, trades, probe pool, full ring | 38/40 | 3 of the last 4 fresh games reach `island_free` (the Demos ending), in 5.5–6.3 minutes of play; the other looped in Act 2 and its rule is in (both runs after it reached the ending) |

The two fixture beats that still stall (`first_harvest`, `loom_opens`) are
Act 0 states the fixture builds with nothing planted to reap; a fresh game
fires both from the banner within its first 20 seconds.

### What each wall taught the resolver

Each wall below was first a failing journey, then one rule in a step type.
None added a banner string.

| Wall (as the follower saw it) | Rule |
|---|---|
| "▸ [G] a living plot" forever | Berry tracking needs a focused column, not a living plot |
| Accept [R] on an offer past the Arc's six rows | The Arc's NOW row is the resolver's live beat |
| Row keys pressed inside an open Arc | Every field chord closes an open overlay first |
| Ace ⇄ Icon hat, forever | Across a beat's open predicates: an action beats a wait, a wait beats a hat or a trip, and a held collapse ranks last |
| Board ⇄ field ping-pong on a trade | A trade's give is gathered before walking to the board; a trade found missing on the open ring is ruled out for 90 s; the cheapest trade (loaded land, covered give) is tried first |
| Strike lands on the other pole, again and again | After three wrong-pole strikes the spec's standing trade is the route |
| Explore refused, banner repeats | When every probe is out, bring one home first, before the trip |
| Plant with the ring full | Trim a word no open or unfired beat names (Icon Q, confirm F), cost gathered first, decided before the trip |
| Chart refused, slots full | Cull the farm's named target first |
| mill_wakes ⚙ attractor (no walk) | `steer`: strike the qubit until it reads the wanted pole and hold it; a qubit past the ring evolves |

### Known gaps

- The fresh journey is stochastic (measurement outcomes). Some runs still
  loop late in Act 2–3; each loop the follower reports is the next test case.
- Post-game campaigns (Lanternfall, the Loom) use predicates with no walk
  yet (`spinor_read` and others); the validator only requires walks for the
  main campaign and Act 0.
- Board cues and refusals still carry their own lines; the legacy
  `objective_text` branches are still the fallback when the resolver
  returns nothing.

### Reproduce the journey

```bash
python3 🍄/🧪/banner_follow.py fresh fresh --jobs 2 --journey 45 --until island_free --out j.json
```

## The surface graph (2026-10-23, after the first human playtest of v0.1.8)

The owner played v0.1.8-alpha (the remodel on `main`, without the resolver)
and reported three things: the toast's keys often did not match the menu
that was open, accepted Arc beats were mixed into the market's Commitments,
and the Druid, Operator and Icon hats were steered onto unexplored qubits,
so the player acted on grey fog balls and never saw what the verb did.

**Why the toast lied.** A key path ("[X], Arc [I], Accept [R]") is only true
from the surface it was computed on. Toast text was computed once, when the
toast was raised, and gold toasts never fade. Several legacy banner lines also
assumed "a menu is open" meant "the board is open", and the X menu reopens on
its last tab, so "[X] opens the Arc" was true only by luck. Meanwhile
`SurfaceRooms.gd` declared an X layout (Arc on Y, Charge on U) the overlay never
built, so the board printed "[X] then Arc [Y]" while Y opened Story.

**What changed.**

- **The UI is a graph** (`Core/Campaign/SurfaceGraph.gd`). Nodes are the field,
  the Icon and gate submenus, every tab of X and C, and any other overlay.
  Edges are keys, read from `guide.keymap.surfaces` in the campaign spec: a
  menu's open key, its tab keys, and ESC back to the field. `current()` reads
  where the player is from the live UI; `path(target)` is a breadth-first walk
  from there. Guide.gd builds every menu path from it. Nothing spells a menu
  path by hand.
- **X shares C's grammar**: T Self, Y Arc (doors you haven't signed), U Charge
  (beats you have signed — claimed there with R), I Guide, O Story.
  Commitments on C now hold market contracts only.
- **Toasts name places, not keys.** The offer, live-beat and flag toasts say
  what happened and where it lives ("a new door on the Arc", "signed — it's on
  Charge") and are tap targets. Any toast that does name keys collapses when
  the player moves to another surface; its follow cue re-renders for where the
  player is. The banner is the one live voice for keys.
- **With a menu open and nothing from the resolver**, the banner says the way
  back to the field instead of a legacy line written for the field.
- **Hats act on what you can see.** Druid, Operator and Icon steps explore
  their target qubit first (Ace hat, plot, Explore in one chord), then act.
- **The follower checks it.** `banner_follow.py` now records every line whose
  first key isn't valid on the open surface and every visible toast that names
  keys of a surface the player has left. Both should stay at zero.

Superseded: the hive's `room_walk_cue` plan (each overlay spelling its own walk
cue, `tests/test_surface_rooms.py::test_walk_cues_and_dock_share_one_table`)
is replaced by the graph; that test still describes the old plan.
