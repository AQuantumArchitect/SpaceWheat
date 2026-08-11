# Playtest sweep, 2026-08-10 — keyboard + mouse, personas + main road

Six agents: four haiku sensor legs (literalist and lost-lamb, on both the
keyboard seat and the new mouse seat, at Act 0 and at the Act-4 fork) and one
sonnet main road that played Act 0 → Act 2 unassisted and sampled Acts 4–7 from
checkpoints, reporting on design rather than only on defects.

Every claim below is marked **VERIFIED** (reproduced by me, live or in source)
or **REFUTED**. Sensor reports are η<1 claims, not rulings — two of the loudest
findings this round were the instrument lying, not the game.

---

## The headline: two personas, one defect, two halves

The keyboard literalist and the keyboard lost-lamb were run independently from a
fresh Act 0 and walled in the same place — the strongest signal in the batch.

Tutorial step 1's mechanic happens in StarterForest, and its hint opened with
"Cross to StarterForest." Once the player *had* crossed, the banner still said
it. The literalist read a standing order it had already obeyed; the lost-lamb,
which re-derives its objective every single turn and holds no memory of having
crossed, correctly reported **LOOPING**.

**VERIFIED, and the root was a split authority.** `objective_target()` already
knew where the player stood — it pulses the biome tab before the verb chip. Only
the *text* was state-blind: `_short_line()` returned the authored string
regardless. Two halves of one guidance system, one of them lying.

**Fixed** (`3ef250b0`): travel now derives from the step's own `biome` field via
`UIProgression._travel_line()`, so both channels read one authority and the line
drops the moment you arrive. Verified live — the banner flips from
`▸ press U to cross to StarterForest — this step happens there` to the Icon-hat
ritual the instant U is pressed.

Freeing the prose of the journey also freed all 70 banner chars for the ritual,
which mattered: the old hint omitted the **~30s ripen wait** entirely. That
omission is why both legs fell back on the explore/strike verbs they already
knew — the one beat of the ritual that isn't a key press was invisible.

### Three more found in the same blast radius

1. **Focusing empty ground was completely silent. VERIFIED.** Act 0 says "Pick a
   plot with G H J K L ; — or just tap it" while the starting biome has exactly
   **one** register (confirmed live: `bubble_state` returns 1 bubble). So H..;
   move the cursor onto register-less ground. Under the 3D renderer that move is
   invisible — no orb exists there, and `PlotGridDisplay` is hidden
   (`visible == false`, `mouse_filter == IGNORE`, rect 0×0, confirmed live), so
   `set_selected_plot()` paints nothing. Real state change (F would now explore
   the *new* plot), byte-identical screen. Now speaks:
   `• H is empty ground — nothing grows here yet`.
2. **Step 5 declared `biome: StarterForest` while instructing "on TheDemos".
   VERIFIED.** The spotlight reads `biome`, so the cue pointed at one country
   while the words named another. Corrected, plus a lint: no hint may name a
   biome other than its own.
3. **Steps 4 and 5 had first sentences of 118 and ~80 chars** against a 70-char
   banner, so both were cut mid-clause — the same class as the earlier step-0
   truncation. Rewritten to lead with a short actionable sentence, and a test now
   pins that invariant for *every* step.

---

## The one my own earlier fix leaked

The literalist dropped at `fork_ready` quoted the new travel line — but it
pointed at **TheDemos**, i.e. a *tutorial* step was still outranking the fork at
Act 4.

**VERIFIED, and it was mine.** The owner's retire-at-act-2 ruling stamped
`retire_predicates` inside `_load_tutorial_arc()`. That reaches only quests
*built by that loader* — a quest **restored from a save** written before the rule
existed carries an empty `retire_predicates` and can never retire. Since any
TUTORIAL entry outranks every arc quest in `_objective_rank`, one stale Act-0
step hijacked the objective banner for the rest of that save's life. Every
existing checkpoint and every pre-existing player save was affected.

**Fixed:** the default is now resolved in `_retire_predicates_for()` at
evaluation time, so it reaches restored saves and freshly-loaded arcs alike, and
the loader no longer keeps a second copy. Verified live on the untouched
`fork_ready` checkpoint: the stale tutorial line is gone and the banner reads
Act 4 · Chapter III.

**Standing lesson:** a rule stamped onto data at construction time only governs
data built after the rule existed. Rules that must hold for saved state belong at
the point of evaluation.

---

## Claims that did not survive checking

- **"Mouse-only is completely blocked at Act 0 — no clickable plots."
  REFUTED.** The leg clicked bare screen coordinates and missed the affordances.
  The action chips carry the loop: a real click on `ActionBtn_F` cost 1🍞 and
  explored, mouse-only. What it mistook for a plot tile was the ContractChip's
  `Tap to focus TheDemos` *tooltip*.
  **But a real gap sits underneath it:** with the 3D field as default renderer,
  an unrevealed plot has no clickable target at all (`tap` on grid `[1,0]` →
  `no_tap_target`; only `[0,0]` resolves, since orbs exist only for live
  registers and the 2D rack is hidden). A mouse-only player can drive the loop
  but **cannot choose which plot to explore**, and the hint's "or just tap it" is
  false for every unexplored plot. Not fixed — see Open.
- **"The Act-4 fork names no keys — critical defect." REFUTED.** The fork
  quest's own hint does name the ritual: *"Icon hat (5): Q unseats an icon you
  can spare (Q arms, F confirms), then R on the empty plot plants the key."* The
  leg read the Story tab's narrative beat and the Chatter panel, never the
  quest's hint. The real (softer) issue is discovery: four arc offers were queued
  at once behind a single `📜 new offer — X then I (Arc)` line, across 12 pages.
- **"The HUD never shows which hat is active." REFUTED for a human, VERIFIED
  for the harness.** `ToolSelectionRow.set_selected()` highlights the active hat,
  so a player can see it. The *text seat* could not — `overlay_text` returns
  label strings, not selection state. Since hat keys are toggles (re-pressing the
  active hat returns to Ace, deliberate and documented), a leg blind to the
  current hat cannot predict its own next press and reports the misfire as the
  game misbehaving. **This is why the main road hit it 6+ times.**
  **Fixed in the instrument:** both seats' `look` now reports `wearing_hat`.
  Verified live: `ace` → press 5 → `icon` → press 5 → `ace`.
  The underlying *design* question — toggle vs absolute-select — is left to the
  owner; it is a deliberate documented affordance, not a bug.
- **"`endrun_act8` and `endrun_ending` load the same state as `endrun_act7`."
  VERIFIED, and worse than reported.** All three carry an **identical 49-flag
  set**, and `island_free` is already fired in all three — so `endrun_act7` is
  mislabeled too. There is no checkpoint sitting *before* the Act-7/8 gates, and
  `the_span`, `braid_alphabet`, `the_fusion` and `the_island_stops_asking` are
  unfired in all of them, so those gates cannot be exercised from the shipped
  set. (Wave 13b's ending-ceremony verification stands — `island_free` really was
  fired there.) Not fixed: re-minting needs a real campaign run to those points.

---

## Design commentary worth keeping (sonnet main road)

- **Act 0 onboarding works.** One plot, one verb at a time, each with an
  immediate legible payoff.
- **Act 1 is where it clicks.** The accept→gather→claim ceremony is taught
  deliberately, and the payoff prose *describes the number you just watched
  change* (`Ω = -7.64 rad`) rather than decorating it.
- **Act 2 hands over the wheel abruptly** — the objective banner gives way to
  "check the Arc tab yourself" with no beat marking the transition.
- **The writing is the strongest thing in the game, and it is load-bearing.**
  Closed enclave vs "wet country" is a real political metaphor cashed out as a
  measurable quest; Lanternfall is SSH topological protection as story; by Act 7
  you build a Majorana bridge and watch it read `Γ = 0.0250 — gentler than either
  shore alone`, which is a true physics fact delivered as a beat you caused.
- **The late-game cliff:** the Act-7 gate `Tr(ρ²) ≥ 0.54` is the first quest in
  six acts that offers no legible lever — abstract meta-state with no visible
  dial, after six acts of concrete "do X in biome Y". Open.
- **Clock speed (`=`) is undiscoverable** — found only via a toast that scrolls
  away, while step 1 requires a ~30s real-time wait.

---

## The re-verify wave — both keyboard personas now PASS

Same two personas, fresh Act 0, against the fixed build. Both had previously
walled inside ~6 presses.

- **Lost-lamb: "Neither LOOPING nor DRIFT."** Fourteen fresh-look-then-press
  turns carried it from boot to **Act 1**, through the whole Icon ritual — pick,
  explore, strike, cross, hat, track, wait, incorporate. It specifically noted
  that pressing R at 57% ripeness produced a clear refusal naming the state, the
  goal and the remedy, and that "the game does not tell me to 'pick a plot'
  after I've already picked it."
- **Literalist: "100% literal throughout. No defects found."** Also reached
  **Act 1**, incorporating an icon. It exercised the new empty-ground toast on
  H/J/K, followed both travel lines verbatim ("press T to cross…", "press U to
  cross…"), and reached for `=` when the ripening dragged.

**And the mouse leg got further than any mouse run before it** — explore →
strike → cross biome → Icon hat → track — which is exactly how it found the next
gap. That is the loop working: fix the wall, and the leg walks far enough to hit
the next one.

## The clock gap the re-verify wave exposed

**VERIFIED and fixed.** `_increase_time_controls` / `_decrease_time_controls`
had exactly two call sites, both in `QuantumInstrumentInput._unhandled_key_input`
— the biome clock was keyboard-only, with no chip, no menu item, no gesture.

Same structural shape as wave 16's sub-mode gap, worse consequence: it sits in
Act 0's own step 1. Ripening runs in real time (~6% per 15s at ×1, measured), so
a mouse-only player waits ~90 seconds staring at the first plot in the game —
while the tracking hint says "⏩ = speeds this biome's clock (up to ×32)",
naming a control they cannot reach.

`UI/Widgets/ClockSpeedRow.gd` puts ⏪/⏩ in the biome band's right corner (the hat
band's corner is ModeSelectionRow's; two right-aligned clusters on one row
collide on a narrow window). Clicks route through `QII.step_time_controls(delta)`
into the same two methods the keys call. Verified live, mouse-only:
`⏩ TheDemos clock ×2 — loops ripen faster` → `⏪ TheDemos clock ×1`.

Both legs also proved step 1's authored "Wait ~30s" wrong — it is closer to ~90s
at ×1. A duration that is both incorrect and points at no remedy is worse than
none, so the hint now names the clock: *"Icon hat: press 5. F tracks a plot. ⏩
speeds the clock. R when ripe."*

## Fixed this sweep

| # | Finding | Where |
|---|---|---|
| 1 | Objective text was biome-blind while the spotlight was not | `UIProgression._travel_line()` |
| 2 | Step-1 hint omitted the ripen wait; travel prose ate the banner | `tutorial_arc.json` |
| 3 | Focusing empty ground was silent under the 3D renderer | `QII._focus_plot()` |
| 4 | Step 5's `biome` contradicted its own text | `tutorial_arc.json` |
| 5 | Steps 4/5 first sentences overflowed the 70-char banner | `tutorial_arc.json` |
| 6 | Retire rule never reached quests restored from a save | `QuestManager._retire_predicates_for()` |
| 7 | "ready to claim — C board" sent players to the wrong tab | `PlayerEventBridge` |
| 8 | Seats could not see which hat was worn | `player_seat.py`, `mouse_seat.py` |
| 9 | Seats could not enumerate unrevealed plots | `plot_glance` gains `pos` |
| 10 | No mouse-only seat existed; parity rested on tester honour | `mouse_seat.py` (new) |
| 11 | The biome clock had no pointer path at all | `ClockSpeedRow.gd` (new) |
| 12 | Step 1 claimed "~30s"; both legs measured ~90s at ×1 | `tutorial_arc.json` |

## Open, not fixed

- **Unrevealed plots have no mouse target** under the default 3D renderer, and
  the Act-0 hint promises "or just tap it". Needs a design call: ghost orbs for
  empty ground, re-show the rack in 3D, or reword the hint.
- **`endrun_act7/act8/ending` are the same post-`island_free` state.** The
  Act-7/8 gates are unreachable from the shipped checkpoints; they need
  re-minting from a real run.
- **`Tr(ρ²) ≥ 0.54` has no legible lever** (main road's #2 ranked ask).
- **Arc-offer queueing at the fork:** four offers behind one banner line, 12
  pages deep.
- **Hat keys are toggles with no text affordance** — a design question for the
  owner, not a defect.

---

## The new mouse seat

`🍄/🧪/mouse_seat.py` — same parity contract as `player_seat.py` (welcome splash
on, progressive disclosure on, no injection), but headed and with the keyboard
**removed rather than discouraged**. `press` is refused outright, so "reached X
by mouse alone" is structural rather than resting on the tester choosing not to
cheat, which is what every earlier wave relied on.

`look` gains `buttons` (visible, click-receiving controls with labels, parents
and centres) so a leg never guesses a node name — and `click` **refuses an
ambiguous name**, since `SelectBtn_0` is simultaneously live in the menu row, the
biome row and the hat row. A guessed name that still resolves is precisely the
"hit whatever it might" failure this campaign exists to prevent.

Note for whoever schedules legs: WSLg mounts `/tmp/.X11-unix` **read-only**, so a
private Xvfb per seat is impossible and each mouse seat opens a real window on
the owner's desktop. Taps are injected via `viewport.push_input`, not OS events,
so focus never changes a result — the cost is screen real estate, not accuracy.
