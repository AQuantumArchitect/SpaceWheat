# Editorial pass — 2026-10-26

A picky read of The Demos from the first banner line to the ending, with a
fresh keys-only run (`banner_follow.py fresh --journey 12 --until woodlot_door`)
to see what the player actually reads. Scope: text, story graph, tutorial.
Post-game campaigns (What Fades, The Loom) are `in_development` and were only
skimmed.

## Fixed in this pass

### Things the player saw that were never written for them
- **The whole lesson body was the Arc row title.** Lessons had no
  `display_name`, so the banner read "The Millwright's Union is buying. This
  lesson is a whole loop: sign it on the Arc, take one of their contracts…
  [G], Accept [R]" — 300 characters, on every Accept and Claim line. Lessons
  now have titles in the spec (The Demos Sleeps · A Kept Contract · Past the
  Hedge · Both Poles at Once · The Loom · Reap the Season), `Guide._title`
  falls back to `IntroVoice.quest_title`, and the lesson title "First Harvest"
  no longer collides with the Act-0 beat of the same name.
- **Designer notes were shown as player text.** `math_note` ("Parallel-dev
  leftover: a ready stall on C…", "Break #2", "the old state_predicates
  asked for…", thresholds that no longer match `params.ladder`) was appended
  to the Arc card (`IntroVoice` "physics") and to the Commitments inspect
  (`QuestBoard`). 23 of 31 notes contain dev tells. They stay in the data for
  authors and tests; they are no longer rendered.
- **Code names in prose and banner.** `StarterForest`, `TheDemos`,
  `FreshwaterSpring`, `BloodLedger` appeared in beats, offers, hints and the
  travel line ("to StarterForest [U]"), while the rail already shows "Starter
  Forest". `Guide.biome_label` spaces CamelCase for the banner; the Demos
  prose now says Starter Forest, Freshwater Spring, Blood Ledger.

### Promises the text made that the objective did not check
- `woodlot_contact` offer said "access clears 0.05"; the gate is
  `$ladder.timber_contact` = 0.16. `spring_contact` said "trust clears 0.42";
  gate is 0.45. Numbers are out of the offers; the bar shows the number.
- `edge_of_the_enclave` said "Sixteen Words"; the gate is
  `$hub.enclave_signature` = 14. Now interpolated.
- `pond_depths` offer asked for "compass gap past 0.35"; no gap predicate
  exists on that beat. Offer now asks what is checked (motion under 0.2 in
  the spring).
- `mill_wakes` offer said "push ⚙ past 8%"; the objective is 💨 ≥ 0.12,
  two Village words, and the ⚙ attractor ≥ 0.4. Offer now lists those three.
- `ledger_opens` hint only covered charting the Ledger; the objective also
  wants two Ledger words. Added.
- `mill_master` had an objective but no offer: a bar the player could fill
  without ever being asked. It now has an offer (nothing `requires` it, so the
  graph is unchanged).
- `first_breath` said "steer one loop"; the player tracks and waits. Now
  "track". (The "~90s" stays: two legs measured ~90s at ×1; the rig only
  looks fast because it fast-forwards.)

### Readability
- Lesson 2 (contracts) body named four surfaces in one sentence (Arc, Market,
  Commitments, Charge) before the player had opened the board. Trimmed to the
  three they will press, in order.
- Lesson 4 (entanglement) silently granted 🍼; the body now says what it is for.
- "Four beats" / "four verbs" — one word now: verbs.
- The "notice what did NOT happen… The enclave holds" paragraph appeared
  verbatim in both `first_harvest` and `first_breath`. Kept once, in
  `first_breath`, where the measurement-scar contrast lands.
- `village_stirs` opened with "the second attractor hasn't formed — the
  Commerce bistability is dormant" in Act 1, before attractors are taught
  (`the_basin`, post-game). Reworded in plain terms; same for `mill_wakes`.
- `forest_evolving` dropped "Anderson transport is live" (never paid off).
- Keys moved out of story beats into hints (`new_voices`).
- "Door" meant both a quest ("Accept [R] takes an unsigned door") and a
  biome entrance ("Timber Country — The Door"). Quests are quests on the Arc
  hint; doors are places.
- Act 2 had two hint registers: Timber in 60-char key lists, Spring in
  300-char paragraphs with "(X → I)" / "C → U" notation. One register now
  (short, `Arc [X] [I] [R]` style); the banner carries the how.
- "What Survives II" (Act 2) came before "What Survives I" (Act 3), and the
  pond called the spectrum "the second invariant" while the loop called shape
  "the first of four". Numerals removed from the Demos titles; both say "one
  of four".

## Second pass (same day): the leftovers, fixed

1. **Survey "clear marks" on a fresh game.** Marks are grid positions and
   survived the crossing from The Demos, so Mass Explore in the forest would
   have explored the Demos mark. `_mass_explore` now ignores marks outside the
   active country; `Guide._survey` asks to clear marks only when one is here.
2. **First banner line "Explore [F]" with nothing focused.** `current_plot_idx`
   starts at 0, so the guide believed plot G was focused while F fast-forwarded.
   `Guide._live_col` now counts a focus only after a plot was picked in this
   country (`last_selected_position`, `current_biome`).
3. **`spiral_breaks` now requires the lesson it preaches.** A strike on a
   register whose axis is incorporated records a `strike_known` gate
   (`ProbeActions.action_measure` → `QuantumInstrument`); the beat's objective
   is the second berry AND one `strike_known`; `Guide._strike_known` walks it.
4. **Tutorial chapter `_doc`** rewritten: lessons are signed and the player
   accepts, does, and claims; step 0 is the exception (live from frame one).
5. **🍼** is now named in the loom and reap lessons and in the Guide book: an
   age of effort, ensouled — the only thing that turns a season; reap spends
   the quantum state and ends the round.
6. **Plant cost** stated one way (🌱×5 + 13 of the south pole, from
   `EconomyConstants`); `five_doors` had the stale "10🌱 + 4×".
7. **Stale keys in in-world copy:** `PredicateGloss` and the reap refusal
   said Shift+F reaps; the Guide book and HOW_TO_PLAY said the bubble "freezes
   cyan" and Q "returns it to live evolution" (pre-banking). All now describe
   banking: R banks and the probe stays, Q pays the bank and the plot sleeps.
8. `forest_listener` no longer re-unlocks the Operator hat.
9. Late hints (Act 3–6) trimmed to one how-line each; the five village paths
   now say how (Icon [5] in the Village: track, ripen, [R] — five words)
   instead of only a mood line.

## Third pass: the walk to the ending

A fresh keys-only run now reaches `island_free` in 452 presses / 6 minutes
with 0 off-surface lines, 0 stale toasts, 0 verb mismatches. Two walls fell:

1. **The Act-5 Forest⇄Village travel loop, diagnosed.** `banner_follow` now
   records the resolver's own trace when it detects a loop. The cause: while
   gathering 🦅 for the Ledger chart, the Forest said "buy 🧺 in the Village"
   (no basket for the gather fee) and the Village said "go to the Forest",
   because `Guide._gather` only checked the fee after arriving. Fees (🧺 for
   gather, 👥 for strike) are now decided before the trip.
2. **A keyless wait.** "🌱's plot is tracking a loop — it opens once the loop
   is taken in" named no key and no "wait", so a keys-only player (and the
   referee) stopped dead. `Guide._take_in_loop` walks it: travel, Icon hat,
   Incorporate when ripe, else hurry the clock.

Also from the walk:
- **Beat prose was read before the deed.** A flag fires when its door
  OPENS, so `beat` is read then; ten beats narrated the deed in the past tense
  (first_breath "You did something", mill_wakes "the village flipped", the
  island_free victory speech) before the player had done it. New optional
  beat field `done` → `arc_quest.done_beat`, logged to the Story tab as
  `<id>:done` and toasted on claim. Those ten beats are split into scene /
  payoff. CAMPAIGN.md documents it.
- **Five Doors said "choose one"** but two paths (Commons, Artisan) fire the
  moment it opens, because 💧 and 🔨 were planted on the road in Acts 2–3;
  `branch_group` only means "act complete when any fires", not exclusivity.
  Luke's call (2026-10-26): it is not a choice — drop the verbiage. Now
  **Five Keys**: every seated key opens its path, take them in any order or
  all at once (a human accepts the lot; a bot may go one at a time).
- Berry counts in prose vs gates: forest_evolving said "once" (gate: 3rd
  forest word), forest_listener said "three" (gate: 4). Fixed.
- "Graph frame" (pond beats) → Operator hat, mode 2; "Chart BloodLedger" in
  the banner → "Chart Blood Ledger".
- **Pacing note:** `edge_of_the_enclave` (14 words) and `empire_imposes` are
  both already satisfied when they open on this road — Acts 5–6 are ten
  presses of Accept/Claim. The reading beats are intentional, but the ending
  arrives faster than the prose around it suggests.

## Fourth pass: the hint cap, the last Demos nits, a jaunt into What Fades

Demos, text:
- **Hint cap is now law.** `validate.py check_hints`: the first sentence of
  every main-campaign hint ≤ 70 chars (one offender, `loop_remembers`, trimmed).
  The old "≤70 total" rule was dead — eight hints were over 130 — so the rule
  is what the banner needs: a first sentence that stands alone. CAMPAIGN.md
  and the tutorial `_doc` say so.
- **Numbers out of offers** where the bar shows them: pond_depths (0.2),
  pond_breathes (0.35/0.25), mill_wakes (12%/40%).
- **Counts vs gates:** forest_listener said "two words… two more" at a moment
  the player holds three and needs one. Fixed.
- **Five Keys hint** said "the ring is full: six seats" — village_identity
  needs 10 atoms (5 of the 6 seats), so one seat is usually free. Now: plant
  first; unseat only if the ring is full.
- **Keys out of beats:** pond_depths "(🧭, Operator hat, mode 2)",
  ledger_opens "(X, the SELF card)", empire_imposes' done (which also
  duplicated island_free's ask).
- **Faction tags:** village_path_commons was tagged Mycelial Web while its
  beat credits the Hearth Keepers; the Artisan path was tagged Hearth Keepers
  while its beat names the blacksmith and the Granary Guilds. Tags now match
  the prose (Hearth Keepers / Granary Guilds).
- `new_voices` beat is tense-neutral: it can be true at open when a word was
  planted earlier, and that is fine (accept, claim) — the prose no longer
  insists the deed is ahead.
- mill_wakes' hint now names the two Village words; woodlot_wakes' hint
  states the plant cost like spring_wakes'; first_harvest no longer repeats
  Lesson 5's closing line.

What Fades, Act 1 (Lantern Country) and the first three beats of Act 2:
- Hints rewritten in the Demos register (`Druid [0]`, `Captain [7]`,
  `Icon [5]`) — they had "Druid hat (0)", "Captain frame", "Graph frame",
  "E-inspect card".
- Code names out: GildedRot → the Gilded Rot; Chart the Zeno Latch is now
  asked for (watching_keeps' objective wanted the biome but the text never
  said to find it); the_gray's objective wants a Gilded word — now asked.
- "What Survives III" → "What Survives" (the beat says "the third invariant of
  the four"); the What Fades I–V numerals are left for that campaign's own pass.
- Numbers out of offers (chain_flipped, the_crossing, the_gray, watching_keeps).

The walk (fresh, keys-only) reaches `island_free` at ~365s and now continues
through `chain_ends` and `lantern_teaching`. Two post-game walls fell:
1. **Coast F rules fired off the coast.** With lantern_door on the banner,
   `ace_f_keeps_fast_fwd` kept F as Fast-Fwd *everywhere*, so "gather 🦅,
   Explore [F]" in the Starter Forest fast-forwarded forever. The
   ShrineOfAshes/Lanternfall rules are scoped to the active biome.
2. **An unaffordable key as the ask.** The legacy Village-paths banner asked
   "[Q] plant 🦅" with no 🩸 for its south pole, forever. `_live_atom_plant_line`
   skips keys the wallet cannot pay.

Next wall (left): after `lantern_teaching`, What Fades and The Loom are both
open; the banner alternates "[C] then [R] Claim" (legacy claim line for one
quest) with "close [ESC]" (the Guide's close-first for `loop_came_home`, whose
`spinor_read` objective has no walk). Post-game beats need Guide walks — or
the Guide should not emit a close-first for a beat it cannot walk. Leave until
those campaigns leave `in_development`.

## Still open

- **`new_voices` can be true at open** (counts earlier plants).
- **Post-game text** uses code names and I–V numbering; `ledger_opens`
  fixture journeys end stuck on "▸ [R] plant 🦅" in What Fades. Leave until
  those campaigns leave `in_development`.
- **Market as rescue (Luke, 2026-10-26).** The staples of the economy loop —
  👥 (strike), 🍞 (explore), 🧺 (gather) — now each carry a second Village
  trade priced in 🐇, the forest's commonest harvest, beside the 🌾-priced
  primary, so a player with only forest produce can buy back in; 🍞 gained a
  resources entry. The ring sorts staples first within the urgent and calm
  groups (`QuestBoard.STAPLES`). Not yet done: a smarter auto-sort by what is
  rare *for you*; the low-water "urgent" rule is the only such bias.
