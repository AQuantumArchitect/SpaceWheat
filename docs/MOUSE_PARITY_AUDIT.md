# Mouse-Only Parity Audit

## Wave 15 (structural fixes) — closed the last 3 confirmed keyboard-only paging gaps; caught a real off-screen-click bug in the fix itself

Luke's directive: patch the structural issues the "Confirmed gaps" table still
listed, then keep running mouse-only waves. Live re-checking that table
against current code first (not just trusting the doc) found it was partly
stale: `ControlsOverlay`'s Arc tab already had a clickable pager
(`_make_arc_pager`) and `QubitAtlasOverlay`'s T/Y/U/I/O tab switching already
routed clicks and keys through one authority (`_build_frame_tab_row` / slop
knot #17) — neither table entry reflected real, present-day gaps. What
remained real: three other places share the exact same A/D-via-`_on_navigate`
authority Arc used, with zero click affordance of their own —
`ControlsOverlay`'s Self/Story/Guide tabs, `EscapeMenu`'s Balance settings
list, and `QubitAtlasOverlay`'s own Lexicon/Hints inner paging (a gap the
stale table entry never named, found while checking the tab-switch claim).

**Fix**: generalized `ControlsOverlay._make_arc_pager` into a shared
`_make_nav_pager(label_text)` (same two-glyph ClickWire pattern reusing
`_on_navigate`), added the equivalent local helper to `EscapeMenu.gd`, and
factored `QubitAtlasOverlay`'s inline A/D handler into a callable
`_step_page(step)` so its own pager glyphs and its keyboard case share one
authority. Wired into `_build_self_body`, `_build_story_body`,
`_build_guide_body` (ControlsOverlay), `_build_balance_body` (EscapeMenu),
and `_build_lexicon_body`/`_build_hints_body` (QubitAtlasOverlay). Also fixed
a real, pre-existing stale-copy bug found along the way: the Self tab's own
hint text claimed "W/S page" when the actual paging key (confirmed via
`_on_navigate`) is A/D — corrected.

**Live-verified via the rig, not just gate-green — and the live pass caught
a real bug in the first version of the QubitAtlasOverlay fix.** Tapping
Balance's and Guide's pagers genuinely changed the displayed content
(`overlay_text` diffs: Balance's settings rows changed category entirely,
Guide's picker/section text changed); Self correctly showed no pager when
the player's known-icon count fits on one page (mirrors keyboard's own
no-op in that state, not a bug); Story's pager dispatches the same
`_on_navigate` the keyboard uses and correctly no-ops when the graph-crawl
focus node has no edge to move to in that direction — identical to what D
would do on a keyboard in the same state.

QubitAtlasOverlay's Lexicon pager, however, resolved via `control_rect` to
screen position `(644, 746)` against a 720px-tall viewport — **26px past the
bottom edge of the actual window**, a real off-screen, unclickable control,
confirmed by 4 repeated taps producing zero page change ("Page 1/32" every
time). Root cause: the pager was appended *after* the card grid, and
Lexicon's grid (up to `CARDS_PER_PAGE` cards across 32 pages for a 282-icon
catalog) is tall enough to push a trailing row off-screen — keyboard A/D
never had this problem since it doesn't depend on the footer's on-screen
position at all, only a mouse click does. Fixed by moving the page label +
pager to render *before* the card grid in both `_build_lexicon_body` and
`_build_hints_body`, pinning it near the top of the body regardless of how
tall the grid below it grows. Re-verified live: pager center now at
`(644, 309)`, well inside the viewport, and 4 consecutive taps correctly
walked "Page 1/32" → "Page 2/32" → "Page 3/32" → "Page 4/32" with the
visible card set changing each time.

Gate: `godot --headless --check-only` on all 3 touched files clean; 40
smokes green; 216 pytest green (both re-run after the Lexicon off-screen fix,
not just the first pass).

Commit: pager mouse-parity fixes (ControlsOverlay/EscapeMenu/
QubitAtlasOverlay) + this doc entry.

## Wave 15 leg 2 — EscapeMenu save/load slots fully clean; found and fixed 2 severe mouse-only bugs in the destructive Q→F confirm chord; second fork flag fired mouse-only

Three targeted checks, run against real checkpoints, no keyboard involved.

**Save/load slot buttons (EscapeMenu KEEP/NEW) — clean.** Armed/cancelled/
confirmed both `SAVE_OVERWRITE` and `LOAD_DISCARD` via mouse alone
(`MenuVerb_Q/E/F`), verified via `overlay_text`/`ui_stack`/`story_flags`
diffs — a slot's timestamp genuinely updated, a load genuinely reset state
and auto-closed the menu, a mid-arm tab switch was correctly blocked
(matches keyboard's own pending-action guard). New-tab scenario start fires
with zero confirmation — reproduces identically for keyboard (`_start_new_scenario()`
has no `PendingAction` branch for `Tab.NEW` at all), a general design gap,
not a mouse-parity bug.

**Real bug found and fixed — the destructive Q→F confirm chord (Cull Biome,
Break, Trim) had two severe, independent mouse-only defects.**

1. *F-confirm chip permanently disabled whenever the active mode defines no
   F verb of its own.* `UIContextController._apply_runtime_state` computed
   the F chip's `disabled` flag purely from whether the CURRENT frame/mode
   defines an explicit F action (`Core/GameState/ToolConfig.gd` — Captain's
   `"biomes"` mode and Operator's `"gate"` mode define none). It had no idea
   a destructive confirm might be armed, so F stayed disabled unconditionally
   — a mouse player could arm Cull Biome or Break via Q, but could never
   complete it. Keyboard never hit this: raw F always reaches
   `QuantumInstrumentInput._dispatch_action_key`, which checks
   `_confirm_pending` FIRST, before any frame-defined F verb, regardless of
   any chip's disabled flag. Fixed by giving `_build_frame_actions` the same
   priority order — when a confirm is pending, F's action_info is now built
   as a synthetic `confirm_destructive` entry (`✔ Confirm <label>`,
   `disabled: false`) instead of falling through to the empty/disabled
   frame-verb path. New getters `has_pending_confirm()`/
   `pending_confirm_label()` expose the previously-private `_confirm_pending`
   state for this purpose.
2. *A non-F chip tap did not cancel a pending confirm — and a later,
   unrelated F tap could silently fire the forgotten destructive action.*
   Keyboard's "any key but F cancels the chord, loudly" rule
   (`_unhandled_key_input`'s own top-level check) never applied to mouse chip
   taps, hat switches, or biome switches — those dispatch through
   `_dispatch_action_key`/`_select_frame_hat`/`confirm_biome_switch`
   directly, none of which knew about `_confirm_pending` at all.
   Live-reproduced: arm Trim Icon (Q on the Icon hat), tap E (Inspect) —
   E's own action fires AND the Trim confirm stays silently armed; a later
   tap on F (meant to toggle Berry tracking, F's normal meaning here)
   instead fires the forgotten `remove_icon`. This is the "actively
   misleading" bug class this campaign treats as most severe — a mouse
   player who thinks they backed out gets a surprise destructive action from
   an unrelated later tap. Fixed by extracting the cancel into one shared
   `_cancel_pending_confirm()` and calling it from every dispatch path that
   isn't the F-confirm itself: `_dispatch_action_key`'s Q/E/R branch (the
   authority mouse chip taps and keyboard both already funnel through),
   `_select_frame_hat` (the single hat-switch entry for both input methods),
   and `confirm_biome_switch` (the shared tail for both TYUIOP and
   BiomeSelectionRow taps). Keyboard's own pre-existing top-level cancel
   check is untouched (now redundant-but-harmless for Q/E/R/F, still the
   only guard for other keys); `try_escape_unwind()`'s own duplicate cancel
   logic was refactored to call the same shared helper instead of
   re-implementing it a third time.

Both fixes live-verified via the rig against the exact reproductions above:
Cull Biome (Captain hat) armed via mouse Q, then F tap correctly confirmed
it (`dispatch_ledger: remove_biome success:true`, `confirm_state.pending`
cleared). Trim Icon (Icon hat) armed via mouse Q, then a mouse E tap
correctly cleared `confirm_state.pending`, and a following F tap correctly
fired F's OWN verb (`toggle_berry_track`) instead of the stale Trim — no
silent destructive action. Gate: `godot --headless --check-only` on both
touched files (`UI/Core/QuantumInstrumentInput.gd`,
`UI/Managers/UIContextController.gd`) clean; 40 smokes green; 216 pytest
green.

**Second fork flag, mouse-only.** Wave 14 proved the inject-icon mechanic
works but couldn't fire a fork flag because that checkpoint's player only
knew the starter icon. Surveying every fork-adjacent checkpoint
(`fork_ready.tres`, `literalist_fable_push_fork.tres`/`_r2.tres`) found each
had a real, distinct prerequisite gap (either the vocabulary or the
`village_identity` flag itself missing) — `p7a_fork.tres` was the one
checkpoint meeting the actual criterion (`village_identity` fired, knows
several fork-trigger icons, a still-unfired `village_path_*` flag with its
prerequisites already met). First inject attempt correctly refused on
Village's real 6/6 register cap (`inject_icon success:false`, matches
keyboard identically); trimmed an icon via the now-fixed Q→F chord to free a
slot, re-entered the Icon hat (clearing focus per the wave-14 fix), and
completed a genuine mouse-only inject: `village_path_watched` fired,
confirmed via a `story_flags` diff. A second of the campaign's 5 fork flags
is now proven reachable end-to-end by mouse alone.

Commit: destructive Q→F confirm-chord fixes, this doc entry.

## Wave 15 leg 3 — Acts 6-8 hat/chip sweep (endrun_act6/7/8), mostly clean

The third leg (originally dispatched as a persona agent, which stalled
twice on a 600s harness watchdog with no reproducible game-side cause —
recorded here as a harness reliability gap, not a finding — and was
finished directly instead) mapped hat row + biome row and tapped every
Q/E/R/F chip on a focused plot across all three late-game checkpoints.
Confirmed 6 biomes unlock by `endrun_act7`/`8` including two never
mouse-exercised before (`ZenoLatch`, `ShrineOfAshes`), and all 7 hats
(Spark, Icon, Merchant, Captain, Ace, Operator, Druid) dispatch or toast
correctly on nearly every chip.

Three chips read as fully silent (`spark.R` on act6, `operator.F` on act7,
`druid.F` on act8 — no ledger entry, no toast). Code-level investigation
found a plausible non-bug explanation for each, not independently
live-confirmed this wave: Spark's shift-mode R (`spark_north`) is a
`CLOSED_BLOCKED_ACTIONS` Lindblad verb, 🔒-locked in the closed system these
late-game checkpoints run in — its `redirect_locked()` toast is
rate-limited (`REDIRECT_COOLDOWN_MS`), so a mechanical sweep tapping many
chips in quick succession can suppress it after an earlier lock in the same
run. Operator's "gate" mode and Druid's X/Y/Z modes define no F verb at
all, so F falls back to the universal Play/Pause toggle — a no-op, silent
by design, when the sim is already running. Flagging as unconfirmed rather
than fixed or dismissed — a future wave should isolate each chip alone
(not mid-sweep) to rule the cooldown/no-op explanations in or out for
certain.

Tracks whether the full keyboard grammar (`UI/PlayerShell.gd:_GAMEPLAY_ACTION_KEYS`)
has a working mouse/click equivalent. Started 2026-08-05 for the mouse-only
playtest campaign — see memory `project_mouse_only_campaign_2026-08-05.md`.

Verification standard: real click, verified live via the rig's `tap` verb
(`🍄/🎛️/rig_listener.gd`) injecting a genuine `InputEventMouseButton`
press+release through `viewport.push_input()`, coordinates resolved fresh
per-call via `control_rect`/`rig_screen_pos_for_grid` — never a hardcoded
or cached screen position. Never use `QuantumField3D.dev_tap_register`'s
direct-`_try_pick()` shortcut in any harness code — it bypasses the real
input pipeline and can reproduce the "click hit whatever it might" bug
class this campaign exists to catch.

## Wave 8 (lost-lamb, from a post-Act-1 checkpoint) — re-confirms Act 1 holds, one harness-only finding

Per Luke's instruction, lost-lamb started from `🍄/🧪/checkpoints/act1_complete.tres`
instead of a fresh boot, so the run's budget would go toward genuinely new
territory instead of re-covering already-proven Act 0-1 ground.

**Harness gap found and root-caused (not a player-facing bug — documented,
not fixed as part of this campaign):** the rig's `load_game_path` verb
(dev/test-only; no in-game UI ever reaches it) loaded the checkpoint's
underlying game STATE correctly (`story_flags`, `known_icons`,
`revealed_plots` all came back exactly right), but the live
`QuantumField3D` kept rendering the stale PRE-load farm — `bubble_state`
showed exactly 1 bubble with TheDemos's own axis (`👥🌾`) no matter which
biome tab was selected. Root cause, confirmed by reading
`Core/GameState/SaveLoadCoordinator.gd`: `load_and_apply(slot)` (the real,
player-reachable slot-load path) explicitly checks for a live `AppRoot`
and routes through `restart_into()` (full app/GameRoot remount) when one
exists; its sibling `load_and_apply_path(save_path)` has NO such check —
it unconditionally takes the lightweight `_attach_state_to_fresh_farm()`
branch, even with a live 3D field already mounted, so nothing ever
re-points `QuantumField3D.farm_ref` at the new farm.
`GameRoot._dev_screenshot()`'s own `SW_LOAD_PATH` handling already works
around this exact gap with a manual `f3d.connect_to_farm(post_farm)` call
— further confirming it's a known, if under-documented, edge of this dev
tool, not a fresh discovery of a live bug. No real player can reach
`load_and_apply_path` (only the rig verb and the dev screenshot path use
it), so this doesn't belong in the mouse-only campaign's fix scope.
**Workaround used to get wave 8 unblocked**: `load_game_path` → immediately
`save_game_path` the (correctly-stated) result into a real slot
(`user://saves/save_slot_0.tres`) → `load_game(slot=0)`, which DOES route
through `restart_into()` and correctly remounted everything.

**Once past that, wave 8 fully re-confirmed Act 1's mechanics hold from a
genuine checkpoint load, not just a fresh boot**: biome-tab switching
(TheDemos/Village/StarterForest, bubble counts correctly 1/3/5 with the
right axes per biome), hat-row switching (6 hats now unlocked at this
checkpoint — icon/merchant/captain/ace/operator/druid, vs. Ace-only at
fresh boot), menu row (8 overlays now unlocked — EscapeMenu,
ControlsOverlay, QuestBoard, atlas, biome_detail, inspector, map_meta, vs.
2 at fresh boot), and all 9 plot orbs across the three biomes — every tap
a genuine `dispatch_ledger: {"action": "explore", "success": true}`. Zero
new bugs surfaced in any of this — a strong signal the defer-to-3D and
drift-removal fixes above didn't regress anything.

**Didn't reach genuinely new Act-2+ content this run**: the checkpoint's
own state has zero active quests and no biomes beyond the three already
known from Act 0-1 — it's Act 1's END state, not itself a launchpad into
new territory. Re-tapping already-`revealed_plots` orbs (which is what
happened here, since the checkpoint's plots were already explored) didn't
fire any new story flag. Reaching real Act 2+ content needs a leg that
specifically works the QuestBoard/Arc-Commitments surface for a fresh
quest offer, or otherwise advances the story from this state — a natural
wave 9 follow-up, not done this round.

## Wave 9 (lost-lamb, patched checkpoint tooling) — first genuine Act-2+ mouse action: accepting a market contract

Owner ruling on wave 8's harness gap: checkpoints must load through the
existing save/load system, not an invented workaround. The path-load →
save-to-slot → slot-load double-hop from wave 8 was itself an ad hoc
system; the real fix is `install_checkpoint` (new rig verb) — a plain file
copy of the checkpoint `.tres` onto a save slot on disk (checkpoints are
already ordinary `GameState` resources, the same format `SaveStore` writes
for slot saves), then the unmodified, already-canonical
`load_game(slot)` → `load_and_apply(slot)` → `restart_into()` verb loads
it — no live-session double-save needed. Live-verified: `install_checkpoint`
+ `load_game(0)` remounts `QuantumField3D` correctly in a single hop
(`bubble_count` varies 1/3/5 across biomes, matching the checkpoint's real
state).

With that in place, wave 9 pushed past wave 8's "didn't reach new content"
edge: opened `QuestBoard` (Menu slot 3), which lands on the Market tab
showing 4 real offers (`pool=4`, confirmed via `overlay_text`). Selected the
first offer (`BoardRow_0`, tap) and tapped the `[R]` Accept verb chip
(`BoardVerb_R`) — a genuine two-tap accept flow, no keyboard involved. The
contract (Millwright's Union, 🍞×19 → ⚙/🏭/💨) landed in `active_quests`
and `quest_ledger` immediately, and switching to the Commitments tab
(`BoardTab_U`, tap) visually confirmed it: `[ACTIVE] Millwright's Union 🍞
582/19 held ⌛ 1:58`. Zero new bugs — the Market → accept → Commitments
loop works end-to-end via mouse alone.

## Wave 10 (lost-lamb, from the patched checkpoint) — first mouse-only quest completion + reward delivery; found and fixed a real load-settle race

First attempt hit a genuine harness-adjacent bug, not a player-facing gap:
reading `story_flags` only once, immediately after `load_game`'s `"loaded:
true"` ack, showed `flags_fired: []` — empty. `UIProgression.is_menu_visible`
gates `QuestBoard`'s menu button on `current_tutorial_step() >= 5`, itself
derived from those flags, so the menu row built with `quests` (and `play`,
`escape_menu`, `controls`) missing, shifting every later `SelectBtn_N` index
and making `QuestBoard` unreachable at the expected slot. Root-caused via a
poll: `flags_fired` went from 0 to 11 entries about a second after the ack,
so `load_game` was answering "loaded" before the load had actually finished
settling.

Traced to the real bug: `SessionLifecycle.restart_into()` called
`AppRoot.restart_from_pending_boot()` **without `await`**, even though that
method is itself a coroutine (frees the old `GameRoot`, awaits two process
frames, then awaits `start_game()`). The bare call kicked off the remount
and returned immediately, so the await chain `load_and_apply()` →
`restart_into()` → the `load_game` rig verb resolved before the remount
finished — not a checkpoint-tooling bug, a pre-existing gap in `load_game`
itself that would affect any caller (Continue, New Game, a fresh rig
script) fast enough to read state right after the ack. Fixed with one
`await` (`Core/GameState/SessionLifecycle.gd`); confirmed via the same poll
(`flags_fired` count is 11 on the very first read, `load_game`'s
`duration_ms` correctly rose from ~100ms to ~700-900ms). Regression test
added (`test_restart_into_awaits_the_approot_remount`,
`tests/test_surface_refactor_snapshot.py`). Full gate green (40 smokes, 215
pytest). Committed `5e3bbe35`, pushed.

With that fixed, wave 10 re-ran clean end-to-end on the first attempt:
`install_checkpoint` + `load_game(0)` → menu slot 3 opens `QuestBoard`
directly → Market tab, `BoardRow_0` tap selects the first offer (Hearth
Keepers, 🍞×19 → 🔥×5 🍞×3 🏜×3) → `BoardVerb_R` tap accepts it
(`active_quests` shows it `active` immediately) → `BoardTab_U` tap opens
Commitments, showing `[ACTIVE] Hearth Keepers 🍞 582/19 held ⌛ 1:58` → tap
the row to select it → `BoardVerb_R` tap (now labelled "Complete" in this
frame, per `_current_verb_labels()`) fires `_complete_selected()` → the
quest moves out of `active_quests` entirely and into `quest_ledger`'s
`completed` array (`status: "completed"`), and the reward icons visibly
land in inventory (🔥 and 🏜 appear as new nonzero counts in the resource
strip). This is the first time the campaign has exercised quest
completion/reward delivery via mouse alone — the full Market → accept →
Commitments → complete → reward loop, zero new bugs.

## Wave 11 (from the act2_complete checkpoint) — silent double-accept found and fixed, failed/expired Commitments path verified clean

First genuinely fresh territory since wave 8: `act2_complete.tres` (21
story flags including `spring_door`/`woodlot_door`/`lumber_flows`/
`pond_depths`, vs. `act1_complete`'s Village-only 11) unlocks 6 biome tabs
(TheDemos, Village, StarterForest, Lanternfall, Woodlot, FreshwaterSpring),
6 hats, and all 8 menu overlays (`EscapeMenu`/`ControlsOverlay`/
`QuestBoard`/`atlas`/`biome_detail`/`inspector`/`map_meta`, menu slots
1–7 respectively — mapped explicitly this wave via a per-slot `ui_stack`
probe, since wave 8's blind substring search for `"Atlas"` had silently
missed the overlay: its live `ui_stack` name is the lowercase
`"atlas"`, a harness-script gap, not a game bug).

**Real bug found and fixed: a single tap on the Market's top offer could
silently accept a contract the player only meant to look at — and a
second, deliberate tap on the `[R] Accept` chip could then silently accept
a SECOND, different contract.** `QuestBoard._selected_index` defaults to
`0`, so row 0 reads as "already selected" the instant the board opens —
before the player has looked at anything. `_on_row_gui_input`'s "first tap
selects, second tap on the selected row fires the verb" convenience keyed
off `idx == _selected_index` alone, which is trivially true for row 0 on
its very first tap. Live-reproduced directly: `install_checkpoint` +
`load_game(0)` → open QuestBoard → a single tap on `BoardRow_0`, nothing
else, produced a real entry in `active_quests`. Worse, the campaign's own
established two-tap script pattern (`BoardRow_0` then `BoardVerb_R` — used
without incident in waves 9 and 10) turned out to have been silently
double-accepting all along: the first "select" tap already committed row
0's offer, and the pool's `_refresh_pool()` (which runs after every
accept) sometimes rotated a *new* offer into row 0 fast enough for the
second, `BoardVerb_R` tap to accept *that* too — reproduced live this wave
(`Wildfire` 🌿×23 from the first tap, `Pollinator Guild` 🌿×18 from the
second). Wave 10 was almost certainly hit by this too; it read as a clean
single accept only because the market pool happened to have nothing left
to refill with in the ~1s window between its two taps.

The keyboard path never has this hazard: `_select()` (driven by GHJKL) never
auto-fires the verb regardless of index match, only an explicit `R`
keypress does — so this was mouse-exclusive. Fixed with a `_row_confirm_armed`
flag (`UI/Overlays/QuestBoard.gd`): `false` by default and everywhere
`_selected_index` resets to its default, `true` only once `_select()` has
actually run (a real tap or keyboard nav). `_on_row_gui_input` now requires
`idx == _selected_index and _row_confirm_armed` before firing the verb —
the dedicated `[R]`/`[E]`/etc. verb-chip taps are untouched and still fire
on a single deliberate tap, matching keyboard `R`. Live-verified post-fix:
tap #1 on row 0 → `active_quests` stays empty; tap #2 (same row) → exactly
one accept. Re-verified in the real wave script too (row-tap-then-verb-tap
now yields exactly one accepted contract, not two). Regression test:
`test_quest_board_row_tap_requires_a_prior_select_before_confirming`
(`tests/test_surface_refactor_snapshot.py`). Full gate green (40 smokes,
216 pytest — 215 baseline + 1 new).

**Also verified, not a bug — closes out wave 10's last open item**: letting
an accepted contract's 120s `time_limit` run out (deliberate, mouse-only —
accept, then just poll and wait) produces a fully legible failed/expired
path. `quest_ledger.failed` gains the entry with `status: "failed"`; the
Commitments Active view correctly clears to "no active or ready contracts";
and a real toast trail appears unprompted: `🤝 Your debt with the Terrarium
Collective grows (+0.06)`, `❌ Terrarium Collective contract (🌿×19) failed
— timeout`, `⌛ a commitment ran out of time — check the C board`. No fix
needed — the path already works correctly and was simply never exercised
by mouse before this wave.

`bubble_state.revealed` read `0` across every biome tab this wave despite
`plot_glance` showing real `revealed: true` entries for the same plots —
this reproduces the already-documented, already-triaged cosmetic quirk
from wave 3/6 (`bubble_state.visible`/`revealed` unreliable, `plot_glance`
is the trustworthy read), not a new regression. Not re-investigated.

Commit: `_row_confirm_armed` fix + regression test, gate results above.

## Wave 14 (fork_ready) — fixed the severe inject-icon gap wave 13 found; verified live with zero keyboard-relying workaround

Direct follow-up to wave 13's headline finding: the Icon-hat's "Add Icon"
default (`IconChipResolvers.resolve_r`) only shows on R when nothing is
focused, but mouse can never tap an empty plot directly — `QuantumField3D`
renders orbs only for populated registers — so once a biome had any
populated register, switching to the Icon hat while an orb happened to be
focused permanently hid Add Icon behind the Track/Ripening/Incorporate
lifecycle chip. This blocked all 5 Act-5 fork flags plus ordinary
vocabulary growth for mouse-only play.

Two fix directions were on the table (see wave 13's writeup): a fixed
6-slot 3D ring layout with ghost markers for empty slots, or a dedicated
always-on affordance decoupled from plot focus. Luke picked the second —
it doesn't couple to the 3D ring's population-dependent layout math,
which matters if biome slot counts ever change.

**First attempt (reverted): swap which chip owns "Incorporate."** The
initial plan moved Incorporate from R to F so R could always mean "Add
Icon" regardless of focus. This looked clean in isolation but broke two
real, pinned regression tests
(`test_title_boot_path.py::test_title_menu_restart_path_reaches_first_breath`,
`test_rig_quest_roundtrip.py::test_learned_icon_survives_path_save_load_roundtrip`)
— both press R expecting Incorporate, confirming that binding is load-bearing
tested keyboard grammar, not something to silently relocate. Caught by the
standard gate (`pytest tests/ -q`) before commit; reverted immediately.

**Actual fix: clear plot focus specifically when switching into the Icon
hat.** `inject_icon` was never plot-scoped in the first place —
`QuantumInstrument.action_inject_icon_pair` only checks biome capacity, and
`_execute_inject_icon` dispatches with `{biome_name, icon}`, no plot
position. The four-state R resolver's "unfocused → Add Icon" branch is the
correct, already-tested behavior; the only real bug was that mouse could
never *reach* unfocused once any orb existed. `_select_frame_hat`
(`UI/Core/QuantumInstrumentInput.gd`) now clears `current_plot_idx` and
`last_selected_position` (same clear-both pattern as the existing full
reset in `_quantum_reset_cycle`) whenever the target frame is
`FRAME_ICON` — reproducing, on purpose, the same "nothing focused yet"
entry state keyboard already got for free by landing an out-of-range plot
key. Tapping a specific orb (or pressing G/H/J/K/L/;) still re-focuses
normally for Track/Ripening/Incorporate. 3 lines of logic, no 3D layout
math touched, no new UI element.

Live-verified via the rig (not just the gate): switched to Village,
deliberately tapped a populated orb first (the exact condition that broke
Add Icon before the fix — mouse can only ever land on populated orbs),
switched to the Icon hat, and tapped R. `plot_glance` confirmed every plot
read `"focused": false` immediately after the hat switch, and R opened the
`icon_injection` submenu on the first tap with zero G/H/J/K/L/; re-focus.
Re-ran the full gate afterward (40 smokes, 216 pytest) — clean.

A follow-up run attempted to actually fire `village_path_commons` (plant
💧 into Village) from `fork_ready.tres` via this newly-mouse-reachable
path. R opened the submenu correctly, but the submenu offered only one
icon (🌾/👥) and paging (F) had nothing to page to. Traced to
`ActionValidator._collect_injectable_icons`: the injection picker only
ever offers the player's *known* icons (their learned vocabulary), and
this checkpoint's player simply hasn't incorporated an icon containing 💧
yet. Not a mouse-parity bug — a genuine vocabulary-progression
prerequisite, same as it would be for a keyboard player at this same
checkpoint state. Reaching a specific fork flag via mouse from a savepoint
that predates learning its trigger icon needs a prior mouse-only
incorporation leg first, not a further code fix.

Commit: `97c20bd6` — `_select_frame_hat` focus-clear fix, this doc entry.

## Wave 13 (fork_ready + endrun_ending) — pushed into the campaign's central narrative choice; found a real, severe mouse-parity gap in the icon-injection ritual, fixed a real tab-vs-orb click bug, confirmed the ending ceremony is fully mouse-clean

Per Luke's steer ("push into the unexplored surfaces... though the central quest
should touch on every aspect of the game"), this wave targeted the Act 5 branch
fork (`docs/CAMPAIGN_STATE_2026-08-04.md` §2 — "the one real narrative choice") and
the `island_free` ending ceremony, rather than another quest-loop variant. The
fork is reached by planting one of 5 candidate atoms (💧/🏭/🔨/🦅/💀) into the
Village register via the Icon-hat's inject-icon ritual — the same mechanic that
underlies ordinary vocabulary growth throughout the whole game, not just the
fork. `fork_ready.tres` (`village_identity` fired, zero `village_path_*` flags
yet) is the checkpoint minted for exactly this moment.

**Real bug found and fixed: a biome-tab (or hat-row, or menu-row) click could
silently defer to a nearby 3D orb pick even when the tab's own rendered content
was fully opaque and nowhere near the orb visually.** `SelectionButtonRow`'s
post-wave-7 "defer to 3D" fix (`_defers_to_field3d`) called
`QuantumField3D.has_pickable_target(screen_pos)`, which uses `_orb_hit_radius()`
(56px, `maxf(56.0, size.y * 0.07)`) — a radius sized for a player aiming
directly at a small orb from a sloppy point, not for deciding whether a 300+px
-wide HUD row should give up a click. Live-reproduced: tapping the Village tab's
own rect-center (a fully opaque button, screenshot-verified with nothing drawn
over it) silently failed to switch biomes whenever a StarterForest orb's
projected position passed within that 56px radius of the click point — in one
capture, an eagle orb (🦅🐇) sat 22px above the tab's own rendered top edge,
comfortably clear of it on screen, and that alone was enough to eat the click.
Broadened further: an initial fix attempt (`has_pickable_target_in_rect`,
checking whether ANY live orb's position fell anywhere inside the ROW's own
rect) made things categorically worse — a 300px×1260px row is large enough that
some orb almost always falls inside it by chance, so EVERY tap on EVERY
Tool/Biome/Menu row slot silently deferred (live-reproduced: all 6 hat-row taps
read back `current_frame: "ace"`, meaning none of them actually switched).
Reverted to a point-based check but with a much tighter radius scoped to the
defer decision specifically (`SelectionButtonRow._DEFER_HIT_RADIUS = 14.0`, via
a new `QuantumField3D.has_pickable_target_near(screen_pos, radius)`) — this
preserves `has_pickable_target()`'s own generous 56px radius for what it's
actually for (a direct field tap), while making the "should this row give up
the click" decision only fire for a genuine near-touch. Gate: `godot
--headless --check-only` on both touched `.gd` files clean.

**Residual, honestly-reported limitation (not fully eliminated, only
narrowed):** because 3D orbs still drift via real correlated-pull force
dynamics (not idle rotation, which was removed earlier in the campaign — see
"Post-wave-7" section below), an orb can still occasionally pass within the
tightened 14px radius of a tab's exact click point, causing a single tap to
miss. A real player would just click again — this wave's own script added a
4-attempt retry-with-reread pattern for biome-tab taps to model that, and it
resolved cleanly on the first attempt in the final run. This is a lower
frequency, lower severity residual than the pre-fix state (which failed on
essentially any tab click near a populated biome), not a claim of a perfect
fix.

**Severe, confirmed, NOT-yet-fixed gap: the Icon-hat's "empty plot: inject
icon" ritual has no reachable mouse path once the target biome has any
populated register — which is true almost everywhere past the earliest game
state, and is the exact mechanic underlying all 5 `village_path_*` fork flags
plus ordinary signature growth via newly-planted icons.** Root cause, traced
precisely across three code paths:
1. `IconChipResolvers.resolve_r()` (`Core/UI/IconChipResolvers.gd`) only lets
   Icon-hat R resolve to the "Add Icon" (inject) action when
   `ChipContext.has_focused_qubit()` is false — i.e. the currently-focused
   register index is `>=` the ACTIVE biome's own `register_map.num_qubits`.
   Keyboard reaches this cleanly: G/H/J/K/L/; are literal index-0..5 picks
   (`Plot-Register Invariant`: `plot_idx ≡ register_id`), so pressing K/L/;
   on a biome with only 3 populated registers directly selects index 3/4/5 —
   genuinely unfocused, correctly landing on "Add Icon".
2. `QuantumField3D` only renders a 3D orb for POPULATED registers (`_bubbles`
   is built from `get_num_qubits()`, live-confirmed via `bubble_state`: Village
   at `fork_ready` shows exactly 3 bubbles for 3 populated registers, none for
   the 3 empty K/L/; slots) — there is no click target at all for an empty
   register slot. `rig_screen_pos_for_grid()` (used by the rig's `tap
   pos:[x,y]` verb) confirms this: `tap pos=[3,1]` (Village's empty K slot)
   returns `no_tap_target`.
3. `PlotGridDisplay` (the fixed 2D rack that COULD tap arbitrary grid
   positions, including empty ones) deliberately gates its own input on
   `visible`, and is hidden whenever the 3D field is the live renderer
   (`_input()`'s own comment: "in 3D mode the rack is hidden but its tiles
   still hold real screen rects... without this gate it kept starting drags
   and consuming releases the 3D field needed") — so even the ONE piece of
   UI built to reach an unpopulated grid slot can't be used while 3D is
   default, which the whole campaign has established it always is now.

A tempting workaround — tap a HIGHER-index orb in a DIFFERENT, more-populated
biome (e.g. StarterForest register 3, which is out of range for Village's 3
registers) hoping `current_plot_idx` stays sticky across a biome-tab switch,
landing on "unfocused" once Village becomes active — does NOT work: live-
verified via `plot_glance`, switching the active biome tab actively
RE-FOCUSES a real, populated register in the new biome (landed on Village's
own register 2, 💰⚙, not the StarterForest index carried over) every time.
There is currently no sequence of genuine mouse taps, however creative, that
reaches the "Add Icon" chip state on a biome with any existing registers —
this was reproduced fresh three separate times against `fork_ready.tres`, with
`[R] Track first (F)` (the disabled "full+untracked" state) showing every
time. Given `_execute_inject_icon()` itself never reads a specific plot
position at all (it dispatches on `biome_name` alone —
`MacroActions.KIND_INJECT_ICON_PAIR`), the fix does not need to solve
"which specific empty slot," only "how does a mouse player ever reach the
unfocused state at all." Two credible directions for a future dedicated pass
(deliberately not attempted this wave — each touches shared 3D layout/render
code and deserves its own careful visual verification, not a rushed change
buried in an already-large wave):
  - Lay out all 6 potential ring slots per biome (not just the populated
    ones) and render a dim/ghost "+" marker for empty slots, extending
    `rig_screen_pos_for_grid`/`_orb_at`-style picking to include them. Real
    risk: `_layout_pos(i, n)` currently rings orbs based on the CURRENT
    populated count `n`, so switching to a fixed `n=6` ring would shift
    every existing orb's on-screen position — needs its own visual pass.
  - Give the Icon hat a small, dedicated "+" affordance (separate from the
    3D field/rack entirely) that always reaches the inject-icon submenu when
    that hat is active, independent of plot focus — sidesteps the ring-layout
    risk entirely but is a new, narrower UI element.

This gap is comparable in severity to the campaign's earlier headline finding
(Reap Season had zero mouse path) — but broader in blast radius, since inject-
icon is the ONLY way to grow a biome's vocabulary/signature at all, mouse or
keyboard convenience aside; keyboard players reach it fine via G/H/J/K/L;,
mouse players currently cannot reach it under any circumstance once a biome
has any content. Flagging for the owner rather than shipping a rushed fix.

**Wave 13b — the `island_free` ending ceremony is fully mouse-clean.**
`EndingOverlay.gd`'s own `_input()` already accepts ANY
`InputEventMouseButton`/`InputEventScreenTouch` press anywhere on screen to
advance each of its 5 stages (Title → Montage/Stats → Credits → Door → close)
— no dedicated button, no keyboard-only path. Since `endrun_ending.tres` (and
every other `endrun_*` checkpoint) ships with `island_free` ALREADY recorded
as fired, and the ceremony only spawns on the live `story_flag_fired` signal
(not a load-time re-check), this wave used the rig's `fire_flag` dev verb
(`🍄/🎛️/rig_listener.gd` — "force-fire a story flag... through the REAL
firing path... lets probes verify flag CONSEQUENCES without driving a full
campaign") against `fork_ready.tres` (where `island_free` had NOT yet fired)
to reach the ceremony — a legitimate SETUP-tier verb, same tier as
`install_checkpoint`, since the mouse-only discipline is about how the
CEREMONY itself is navigated, not how the test reaches that moment. Six
genuine screen-center taps walked the full stage sequence and closed the
ceremony cleanly, confirmed via screenshots (stage 0: "The Demos are free.";
stage 1: "the island, measured / 0 contracts honored"; final: "The door stays
open." toast, sim resumed, Ace action chips live again, `[F] Explore` chip
active). **Harness-only finding, not a game bug**: `ui_stack` never lists
`EndingOverlay` by name even while it's genuinely on screen and consuming
input — a future probe should verify ceremony presence via `overlay_text`/
screenshot, not `ui_stack`, matching this doc's earlier note about `ui_stack`'s
lowercase `"atlas"` miss.

Commit: `SelectionButtonRow`/`QuantumField3D` tab-defer-radius fix, this doc.

## Wave 12 (from the act3_complete checkpoint) — first genuine mouse-only quest delivered end-to-end via gathering, real economy; found and fixed a harness read-verb bug

`act3_complete.tres` (29 story flags, incl. `island_lives`/`mill_master`/
`chain_ends`/`lantern_teaching`) unlocks the same 6 biome tabs/6 hats/8
menu overlays as wave 11's checkpoint — this run's Act-5 economy (per the
Commitments-tab act banner, `Act 5 · Chapter IV — The Empire & The Escape`)
is simply much further along, with wallets in the hundreds for several
resources. Menu-slot map re-confirmed identical to wave 11's
(`atlas` at slot 4, lowercase).

**Closed the gap wave 11 explicitly left open**: instead of letting an
accepted contract expire, this wave gathered the asked resource through
genuine explore→strike→extract taps and drove the contract through real
delivery completion. Flow: opened Market, tapped `[E] Refresh` up to 15
times reading `overlay_text` for a low-quantity ask (none under 13 turned
up in this economy; accepted the first-seen `🍞 × 13` from Hearth Keepers,
scope `Village ⊗ Woodlot`), accepted via the wave-11-verified two-tap
sequence (row-tap-alone left `active_quests` empty — the `_row_confirm_armed`
fix still holds — then `[R] Accept` produced exactly one accept), switched
to the origin biome's tab (a real click on `BiomeSelectionRow`, which routes
through `_active_biome_mgr.set_active_biome()` — the same mechanics-level
switch a biome tab click always does, not a cosmetic-only change), then
tapped each of that biome's plots through the full three-beat
explore→strike→extract cycle (confirmed live via `dispatch_ledger`:
`explore`→`measure`→`pop`, repeating, all `success: true`). Opened
Commitments, tapped the row then `[R] Complete`: `✓ delivered 🍞×13 —
payout is in your stores`, `🤝 Your trust with the Hearth Keepers grows
(+0.05)`, and `quest_ledger.completed` gained the entry (`status:
"completed"`). This is the mouse-only campaign's first full accept→gather→
deliver loop closed end-to-end from a live economy, rather than a checkpoint
pre-loaded with the needed resource or an expiry-only path.

**Real bug found and fixed — not in the game, in the rig harness's own
`resource_snapshot` verb.** While polling wallet progress during the gather
loop, `resource_snapshot`'s `resources` map read `0` for the ask emoji on
every single poll, even after `dispatch_ledger` showed successful `pop`
actions. Root cause (`🍄/🎛️/rig_listener.gd`): `QuantumInstrument.
get_resource_snapshot()` already returns `{"resources": {emoji: count},
"ordered": [...]}`, but the listener's handler assigned that whole dict
wholesale to `result["resources"]` — double-wrapping the flat emoji map one
level too deep (`result["resources"]["resources"]` instead of
`result["resources"]`). Confirmed via an isolated diagnostic
(`diag_resource_snapshot.py`): a fresh `act3_complete` load's
`resource_snapshot` returned a 2-key dict (`"resources"`, `"ordered"`)
instead of the ~23-key flat emoji map; `resources.get("🍞")` returned
`None` even though the same session's Commitments UI (reading the economy
directly) showed 567 held. **This wasn't new** — grepping every consumer of
the verb found ~9 probe scripts (`farm_to_completion.py`, `play_the_game.py`,
`act3_5_drive.py`, `poverty_run_probe.py`, `act2_drive.py`, `mill_drive.py`,
`stranger_arc_ui_probe.py`, `tutorial_stranger_probe.py`,
`ace_strike_extract_probe.py`) reading `.get("resources", {})` with no
compensation — silently broken the same way, for however long this bug
predates this wave — while 3 others (`stranger_mouse_probe.py`,
`tap_to_farm_probe.py`, `export_umwelt_tape.py`) already carried a defensive
`if "resources" in res: res = res["resources"]` unwrap, proving the
double-nesting had been quietly noticed and worked around locally at least
once before, never fixed at the source. Fixed at the source
(`🍄/🎛️/rig_listener.gd`): the handler now flattens
`rs_snap.get("resources", {})` into `result["resources"]` directly. This is
fully backward compatible — the defensive unwraps in the 3 scripts that had
them are now no-ops (harmless), and the other ~9 scripts start reading real
wallet data for free, with no script-side changes needed. Live-verified
post-fix: the same diagnostic against a fresh `act3_complete` load now
returns the full 23-key flat map, `🍞` → `567` directly.
`tests/test_rig_reuse_hardening.py`'s
`test_rig_listener_routes_read_actions_through_policy_snapshot` used to pin
the buggy line verbatim as a source-grep assertion; updated to assert the
corrected line and that the old wholesale-assign form no longer exists.
Gate: `godot --headless --check-only` on the touched `.gd` clean, targeted
pytest green, full gate green (40 smokes, 216 pytest — 215 baseline + 1
test edited, 0 net new since this was a correction not an addition).

No new flags fired this run (all reachable from menu/hat/biome sweep + the
accept/gather/deliver loop were already fired by the checkpoint).

Commit: `resource_snapshot` flatten fix + test correction, gate results
above.

## Post-wave-7: owner ruling closes the biome-tab overlap lead + drift removed

Luke's ruling on the "Open, not yet fixed" biome-tab/field-orb overlap lead
below: **"defer to 3D for all things, 2D is being deprecated."** That
resolves the design fork item 4/the overlap entry itself left open (reshape
3D camera framing vs. teach the 2D HUD to defer) — 3D wins. Implemented in
the shared `SelectionButtonRow` base (covers Tool/Biome/Menu rows
uniformly, not just Biome): before a chip claims a click, it asks the live
`QuantumField3D` (`has_pickable_target(screen_pos)`, found via a new
`quantum_field_3d` group) whether a real 3D target sits at that point; if
so the chip does nothing (no press-flash, no selection) and the tap is
forwarded to the field's own `receive_deferred_tap()` — the exact same
pick geometry a direct field tap runs. Live-verified via the rig: switched
to StarterForest, polled `bubble_state` until an orb's `screen_pos` fell
inside `BiomeSelectionRow`'s own rect (happened on the very first poll),
tapped exactly there, and got `dispatch_ledger: {"action": "explore",
"success": true}` with `active_biome` unchanged — the tap reached the orb,
not the tab. A follow-up check confirmed ordinary (non-overlapping) biome
and hat clicks still work unchanged through the same code path.

Same session, separate owner ask: **removed `QuantumField3D`'s passive
idle-rotation** of the whole field (`_process()`'s
`_pivot.rotate_object_local(...)`, previously always spinning slowly "so
the 3D never freezes"). A playtester read that ambient motion as
meaningful when it wasn't — "all motion and adjustment should have meaning
or be the result of the player." Camera motion is now only the player's
own drag, or honest physics (force dynamics, Bloch-state evolution); the
now-fully-dead `_orbit_hold_until_ms` gate/hold-timer was removed with it.
This directly shrinks the drift surface the defer-to-3D fix above exists
to handle — orbs no longer wander into HUD bands on their own, only via
real correlated-pull force dynamics, which move far less. Live-verified:
orb screen positions were pixel-identical across 6s of real idle time with
no input (previously: continuous drift).

Both changes gate-clean (see repo test suite) and committed together —
`Core/Visualization/QuantumField3D.gd`, `UI/Widgets/SelectionButtonRow.gd`.

## Wave 7 (earnest/literalist/lost-lamb) — furthest reach yet, past entanglement into Act 1

Ran fresh-boot, mouse-only, against every fix through wave 6 plus this
session's biome-tab-miss-toast fix (item 7 below).

- **lost-lamb reached Act 1, tutorial steps 0–6 ALL complete**, plus the
  `village_stirs` story flag and a freshly-accepted post-tutorial quest —
  by a wide margin the furthest any wave has gotten (wave 6's ceiling was
  step 4/entanglement). Confirmed core_loop, vocabulary, reap_season,
  superposition, **entanglement** (Operator hat Bell weave), **contracts**
  (Millwright's Union delivery accepted, fulfilled, completed — Arc tab →
  Commitments tab, all mouse), and vocab_escape, all via `story_flags`/
  `known_icons`/`quest_ledger`. Zero hard blockers hit this run — every
  prior wave's wall held fixed. Found and precisely root-caused three real
  bugs along the way: items 8 and 9 in "Bugs found" below (both fixed),
  and the biome-tab/field-orb overlap misdirection in "Open, not yet
  fixed" (documented, deliberately not blind-patched — see there for why).
- **earnest and literalist both independently stalled at tutorial_step 1**
  (vocabulary), NOT on a mouse-parity bug — every tap dispatched correctly
  (`explore`, `toggle_berry_track` all `success:true`) — but on real
  wall-clock ripening pace. literalist's own live-polled numbers: the
  `[R]` chip's ripening tooltip rose 11%→43%→46% over the session without
  reaching ripe; earnest's Arc-tab "First Breath" flag read 9%
  (0.08/0.85) after ~90s of real tracked time across two plots. This
  reconfirms wave 3/4's prior note (in-game hint claims "about half a
  minute," observed reality is far slower) — a pacing/content question for
  the owner, not a mouse-input bug, since every verb involved already has
  a confirmed working mouse path. lost-lamb's success on the SAME mechanic
  is explained by heavy, repeated Fast-Forward chip use accelerating
  ripening well past what earnest/literalist's more measured pacing
  covered in one session.
- Both literalist and earnest's stalls double as an unplanned, useful
  confirmation: the wave-6 entanglement fix and biome-tab-confirm fix both
  held under a SECOND independent replay, with zero new issues in the
  steps they did reach.

## Wave 6 (earnest/literalist/lost-lamb) — first run against ALL prior fixes combined

Ran after fixing wave 5's Reap Season gap AND the biome-tab silent-switch bug
(mouse click bypassed the keyboard's confirm+repoint tail — see "Bugs found"
below). No prior wave had run against both fixes together.

- **earnest reached tutorial_step 4 (entanglement) — the furthest any wave
  has gotten**, confirming steps 0-3 (core_loop, vocabulary/StarterForest
  redirect, reap_season/shift-tap, superposition/Hadamard) all now work
  cleanly by mouse alone. Found and root-caused the NEW true ceiling:
  **the Operator hat's two-plot multi-select ("hold Shift and tap two plot
  keys... then weave a Bell") had zero mouse path** — `handle_bubble_tap`
  always ran the single-plot Explore/Strike/Extract cycle regardless of
  hat or shift state; only the keyboard's Shift+GHJKL; called
  `toggle_check`. **Fixed** (see "Bugs found" below) and live-verified.
  Also found a lead earnest's own report framed as an "active-biome
  desync" — re-investigated afterward against earnest's REAL rig
  transcript (not a fresh guess): it was NOT a biome-authority divergence
  (zero `focus_biome` dispatches anywhere in the log, `bubble_state`'s
  biome tag always matched what was rendered). The real mechanism and fix
  are in "Bugs found" item 7 below.
- **literalist** independently confirmed core_loop and the StarterForest
  redirect (incl. the biome-confirm fix — clean toast, no silence), then
  stopped at the SAME wall as lost-lamb below (hat-selector legibility).
- **lost-lamb** confirmed the biome-tab-confirm fix holds even when
  DELIBERATELY aiming taps at the StarterForest/HUD overlap zone (4
  taps, all legible — either a distinct "→ Village"/"→ TheDemos" toast or
  clean plot-bubble interaction, zero silent/ambiguous outcomes). Found a
  soft self-sufficiency gap (step-0's hint text doesn't change after the
  first tap, only the F-chip's tooltip does — no hard bug, low priority)
  and a lead worth a follow-up look: the Ace hat's Fast-Forward chip
  logged `success:false` on ~18 consecutive taps while unpaused, with zero
  toast/visible feedback either way.
- **Both literalist and lost-lamb independently hit the same non-bug**
  already documented under wave 5 item 3 above: hat-selector chips
  (`ToolSelectionRow`) are icon-only with no `overlay_text`-visible label,
  discoverable only by hover tooltip or visual glyph recognition — a real
  gap for a strictly-literal-text-only reader, not for a sighted mouse
  player (who can see 2-3 icons and/or hover). Not treated as a bug for
  the same reason as before: reversing an intentional compact-chrome
  design decision needs a design call, not a unilateral patch.

## Session 4 continued — wave 5 findings + the real headline fix

Wave 5 (earnest/literalist/lost-lamb) ran against the Session-4 fixes above,
explicitly pushing for depth past Act 0. Two more real, structural bugs
surfaced and were fixed the same session:

1. **Fixed — the actual headline bug of the whole campaign: Reap Season
   (Shift+F) had NO mouse path at all, for any input, ever.**
   `ActionPreviewRow._on_action_button_input` emitted `action_pressed` as a
   bare `String` with no modifier data; `PlayerShell._route_action_key` →
   `QuantumInstrumentInput.invoke_action` → `_dispatch_action_key` all
   hardcoded `shift=false` for the chip-click path (the keyboard path,
   `_on_unhandled_key`, correctly reads `event.is_shift_pressed()` — mouse
   never did). Since tutorial step 2 (`reap_season`) requires exactly one
   `reap` gate to fire (`gate_sequence_contains`) and the tutorial chain is
   strictly linear, **no mouse-only player, however skilled, could ever
   pass Act-0 step 2** — this was the real ceiling under the Icon-hat fix,
   found live by earnest (repeated `ActionBtn_F` taps on Ace hat only ever
   produced `fast_forward`, never `reap`, in `dispatch_ledger`, matching
   the chip's own tooltip text "[F] ⏩ Fast-Fwd (⇧ Reap Season −1🍼)" that
   named a verb a mouse player could never trigger). Fixed by threading the
   real click event's `shift_pressed` through the whole chain instead of
   discarding it — `action_pressed(action_key, shift)`,
   `_route_action_key(action_key, shift=false)`,
   `invoke_action(action_key, shift=false)`, same
   `_dispatch_action_key(key, shift)` the keyboard already used. A mouse
   player physically holding Shift while clicking F now genuinely reaps.
2. **Fixed — my own Session-4 hint fix broke itself via truncation.**
   literalist confirmed the biome-redirect fix works (correctly found and
   clicked the "Starter Forest [U]" tab by reading its real label) but then
   found the objective banner was byte-identical before and after crossing
   — the hint's second, actionable sentence ("Icon hat (5): F tracks...")
   never rendered at all. Root cause: `UIProgression._short_line()` cuts at
   the last sentence boundary within a ~100-char lookahead
   (`OBJECTIVE_MAX_CHARS=70 + 30`); my two-sentence hint's crossing
   instruction (~83 chars) fell inside that window and the actionable
   half fell outside it, so it was silently dropped. Fixed by shortening
   `tutorial_arc.json` step 1's hint to "Cross to StarterForest. Icon hat
   (5): F tracks, R incorporates." (63 chars) — short enough that
   `_short_line` never truncates it at all; both instructions now always
   render. Regression test pins the length under `OBJECTIVE_MAX_CHARS`.
3. **Investigated, not a bug — hat-row (`ToolSelectionRow`) chips read as
   icon-only with zero `overlay_text`-visible label.** literalist correctly
   flagged this as a wall (nothing on screen names which of 3-4 unlabeled
   glyphs is "Icon hat"), but `ToolSelectionRow._rebuild_buttons` DOES set
   a real tooltip per chip (name + key + description) — same
   Apple-minimal-pass pattern as every sibling row (`compact = true`,
   comment: "icon-only chips... words live in tooltips"). A real mouse
   player who hovers before clicking (ordinary UI behavior) sees the name;
   `overlay_text` simply doesn't capture popup tooltips, and a strictly
   literal reader who never hovers is a real, narrower edge case worth
   naming here but not a case for reversing an intentional compact-chrome
   design decision unilaterally.

## Session 4 (2026-08-06): Icon-hat tutorial dead-end + wave-4's two "cosmetic" items

Luke's ruling on item 3 below: "change the plot to match the mechanics" — the
tutorial's own POINTER was wrong, not the biome data itself (TheDemos's word
correctly stays "already yours"; the deliberate narrative device from
`first_breath`'s own hint text). Root-caused and fixed the pointer:

1. **Fixed — the real root cause of the Icon-hat dead-end**:
   `UIProgression.objective_target()`'s TUTORIAL branch hardcoded
   `{"key": hat_key, "biome": ""}` for every Act-0 step, discarding the
   step's own `"biome"` field from `tutorial_arc.json` (already present on
   the quest dict — `QuestPipeline.from_tutorial_def` copies it verbatim).
   `ObjectiveSpotlight` only pulses the biome tab when `target.biome != ""
   and != active_biome` — with biome always `""`, the spotlight pulsed the
   Icon-hat verb chip alone, on whatever biome the player already stood on.
   Step 1 (vocabulary) is authored `"biome": "StarterForest"`, but a player
   who never learns to cross biomes tries it on TheDemos instead — and
   TheDemos's only axis (`👥🌾`) is refused by construction (`👥` already
   anchors the player's own starting signature word `🌾/👥`), a real dead
   end after a ~100s ripen wait with zero visual cue to leave. Fixed:
   `objective_target()` now passes the step's own `biome` through instead of
   discarding it — steps 0/1/3/4 (the ones with a mapped verb chip) all
   benefit; steps 2/5/6 have no chip mapping and are unaffected either way.
   Also strengthened step 1's own `tutorial_hint` text to lead with "Cross
   to StarterForest first (biome tabs T-P) — your home word is already
   yours," matching the "visual UX pairs with text hints" precedent
   (spotlight pulse + explicit text, not spotlight alone). Verified live:
   with the fix, the objective banner on TheDemos now reads exactly that
   text and the biome tab row shows the StarterForest tab underlined/active
   target. Regression test:
   `test_headed_player_input_surface.py::test_tutorial_objective_spotlight_honors_the_steps_own_biome`.
2. **Investigated, NOT reproduced — `bubble_state.visible`**: ran a live
   headed diagnostic (explore → measure → extract full loop on TheDemos,
   plus a biome switch to Village) comparing `bubble_state.visible` against
   real screenshots at every step. In every case the flag correctly matched
   what was on screen (hidden before explore, visible after, hidden again
   after extract/pop; all three Village plots correctly hidden pre-explore).
   Both screenshots DO show a small wolf emoji (🐺) with a green ring at a
   fixed screen position, identical across biomes and explore-state — this
   is almost certainly what wave 4 read as "a visible bubble": it isn't one
   of `_bubbles` at all (its screen position matches neither TheDemos's nor
   Village's actual bubble `screen_pos` values), most likely a Lindblad-
   drain or cognifold-badge indicator (see `CognifoldForecastField.gd`'s
   `_node_badges`). No code changed — a real bug wasn't found to fix, and
   the "no special cases" law argues against a speculative patch with no
   reproduction.
3. **Investigated, NOT a bug — `MenuSelectionRow`'s `SelectBtn_0`**:
   `MenuRegistry.TOP_LEVEL_MENUS`' first (keyless) entry is `"play"`
   (🌾, "Return to gameplay") — it becomes button index 0 because keyless
   entries render before the ZXCVBNM-keyed ones. Its handler
   (`MenuSelectionRow._on_button_selected`, `menu_group == "play"`) closes
   every registered overlay so FarmView becomes top. Wave 4 clicked it while
   no overlay was open — correctly a no-op, since there was nothing to
   close. Not a gap: the button still visibly presses (shared chip-flash
   feedback), it just has nothing to do in that state.

## Persona wave 4 (earnest/literalist/lost-lamb, mouse-only, post-PlayerShell-fix)

Run after the two fixes in the section below (PlayerShell's own
`mouse_filter`, and `handle_bubble_tap`'s verb resolution). All three
agents confirmed the core loop now genuinely works end to end by mouse:
real welcome-splash dismiss, hat row, biome row, menu row, and the full
Explore→Strike→Extract loop all independently verified working via direct
clicks, with real resource deltas. No agent got past Act 0 / Chapter I —
Vocabulary (no new `story_flags` fired beyond `tutorial_seen`), but for
mechanical reasons now understood, not because clicks don't work:

1. **Fixed**: the Arc tab (`X` → `I`), the mouse path to the game's own
   advertised "Hearth Keepers"/story-flag quest offers, had rows with zero
   click affordance (only the `R`-accept HUD chip worked, so a mouse
   player could never pick WHICH row to accept) and an inert "page N/M ·
   A/D" footer. Both now route through `ClickWire` onto the same
   authorities the keyboard already calls (`_select_arc_row` mirrors
   `GHJKL;` picks; two pager glyphs call the existing `_on_navigate()`).
2. **Fixed**: a locked (progressive-disclosure) Q/E/R/F chip click was a
   total no-op — zero toast, zero press flash, indistinguishable from a
   click that never landed. Now shows the same rate-limited "🔒 not yet —
   now: ..." toast the keyboard's own locked-verb refusal already shows.
3. **Design issue found, NOT a mouse-parity bug (out of scope for this
   campaign, flagging for the owner)**: the Icon hat's tutorial explicitly
   points at TheDemos's one plot (axis `👥🌾`), but incorporating it is
   refused by construction — `👥` already anchors the player's own
   starting faction signature (`QuantumInstrumentInput.gd:774-779`), so
   the literal tutorial instruction dead-ends after a real ~100s berry-
   ripening wait with no hint to try a different biome. Reproduces
   identically for a keyboard player; not something this campaign's fixes
   can address.
4. **Reconfirmed, still open**: `bubble_state.visible` is unreliable —
   `false` for plot bubbles that are actually on-screen and directly
   tappable (screenshot-verified on both TheDemos and Village). Cosmetic/
   render-state bug, not a click-routing one.
5. **Unclassified, minor**: `MenuSelectionRow`'s `SelectBtn_0` produced no
   visible `ui_stack` change when clicked — not yet identified what this
   button is or whether it's a real gap.
6. **Content note, not a bug**: berry-phase ripening after a correctly
   started track accumulated only ~11% of the 2π threshold over 45s idle,
   much slower than the in-game hint's own "about half a minute" claim —
   possibly stale copy, possibly needs a tuning look independent of mouse
   parity.

## Persona wave 3 (earnest/literalist/lost-lamb, mouse-only) — new findings

Three real-boot mouse-only agents run after the two blockers below were
fixed. earnest and literalist independently found and this doc's authors
fixed the sibling-order blocker (next section). lost-lamb, testing the
REAL first-boot path (welcome splash shown+dismissed, not the automation
default of skipping it), found three more issues, since triaged:

1. **Fixed**: hat/biome row pointer input permanently disabled after any
   real overlay (including the one-time welcome splash) opened+closed once
   — see "pointer-bleed guard" section below.
2. **Resolved as a false alarm**: a hat-row click after a real welcome-
   splash dismiss was reported as producing no dispatched action. Live
   re-verification (`current_frame` via the rig's `confirm_state` verb,
   not `dispatch_ledger`) shows the hat click DOES correctly flip the
   active frame end-to-end (`frame_selected → QII._select_frame_hat →
   ToolConfig.select_frame`) — `dispatch_ledger` simply never records hat
   selection at all (it only logs Q/E/R/F verb dispatches), so it was the
   wrong signal to check. No fix needed here.
3. **Fixed (root cause was severe)**: `PlayerShell.gd` (`extends Control`,
   full-rect, `mouse_filter` never set on itself) defaulted to Godot's
   `MOUSE_FILTER_STOP`. The earlier sibling-order fix (below) correctly
   put PlayerShell's HUD widgets above `GameRoot`/`QuantumField3D` for
   picking — but PlayerShell's OWN background, not just its widgets, now
   won every click that didn't land on a specific named child. That
   silently absorbed every tap aimed at empty space over a 3D orb — the
   single most severe remaining mouse blocker, since it meant NO plot tap
   could ever reach the field at all (`hover_probe` at a bubble's exact
   `screen_pos` returned `PlayerShell`, not `QuantumField3D`). Explains
   both the "invisible bubbles" report (a bubble reveals on its first
   successful tap; if no tap ever lands, it never reveals) and the
   Explore→Strike→Extract report below. Fix: `mouse_filter =
   MOUSE_FILTER_IGNORE` on PlayerShell itself in `_ready()`, mirroring the
   same pattern `SelectionButtonRow` already uses for its own root
   ("the row is a full-width invisible strip... must be transparent").
   Verified live: `hover_probe` at a bubble's `screen_pos` now correctly
   resolves to `QuantumField3D`, and HUD hat/action-chip clicks still work
   (PlayerShell's named widget children keep their own explicit `STOP`
   filters, unaffected by the container's own filter).
4. **Fixed**: the Explore→Strike→Extract loop couldn't be completed by
   mouse — re-tapping a bubble only cycled Explore↔Measure. Root cause
   (confirmed live via a temporary debug trace): `Terminal.gd`'s MEASURE
   handler calls `release_register()`, which intentionally sets
   `is_bound=false` while KEEPING `is_measured=true` (the register frees
   for reuse; the terminal keeps its frozen snapshot so it can still be
   popped — a real, documented state, see `Terminal.can_pop()`).
   `handle_bubble_tap`'s verb resolution gated on `terminal.is_bound`
   BEFORE checking `is_measured`, so a freshly-struck (measured but now
   unbound) terminal always fell through to the "explore" default instead
   of resolving to "pop." Fixed by using the terminal's own
   `can_pop()`/`can_measure()` methods instead of hand-rolling the state
   check — the same fix instantly also should explain the dedicated `[Q]
   Extract` chip's separate failure, since that path shares this same
   entry-plot terminal state (not independently re-verified this pass).
   Verified live end-to-end: tap 1 → explore (success), tap 2 → measure
   (success), tap 3 → pop (success) — the full loop, mouse-only, no
   keyboard.

Item #3's fix is the single biggest unblock of the whole campaign — it was
silently absorbing every plot tap, on every boot path, mouse-only or not,
since the sibling-order fix landed. A fresh persona wave should now be
able to progress well past Act 0.

## Severe: fixing the plot-tap blocker exposed a second, bigger blocker (found + fixed)

The root cause of the plot-tap blocker turned out to be `AppRoot`/`GameRoot`/
`PlayerShell`'s whole `Control` tree stuck at `size == (0,0)` (see below).
Fixing it (commit `dde8dcde`) made `QuantumField3D` a real, full-screen,
`MOUSE_FILTER_STOP` Control for the first time — and it turned out to be
sibling-ordered ABOVE `PlayerShell` under `AppRoot` (added later, in
`start_game()`, vs. `PlayerShell` added earlier, in `_ready()`), with no
`CanvasLayer` actually separating them despite a code comment claiming one
did. That full-screen rect silently ate every click meant for the HUD
underneath it — the whole "Covered" table below (menu row, hat row, biome
row, all four Q/E/R/F action chips) was **only ever verified true while the
field was accidentally masked by the OTHER (0,0) bug**; a mouse player could
tap plot bubbles (routed through `QuantumField3D` itself) and nothing else.
Two independent persona-wave agents (earnest, literalist) hit this
independently right after the first fix landed and root-caused it
identically. Fixed by sibling-ordering `GameRoot` below `PlayerShell`
(`AppRoot.start_game()`: `move_child(game_root, 0)` right after
`add_child(game_root)`). Verified live: `MenuSelectionRow`'s `X` button now
opens `EscapeMenu` via click, and `ActionBtn_F` (a real HUD button, not a
bubble tap) now dispatches `explore success=true`. Regression test:
`tests/test_headed_player_input_surface.py::test_game_root_sits_below_player_shell_in_sibling_order`.
The "Covered" table below is now re-verified correct as of this fix.

## Luke's "menu buttons feel dead" report (2026-08-05) — investigated

Swept all 8 `MenuSelectionRow` buttons by click, twice: fresh boot (Z, X
only unlocked) and at `act1_complete.tres` (Z X C V B N M all unlocked —
EscapeMenu/ControlsOverlay/QuestBoard/Atlas/BiomeDetail/Inspector/MapMeta).
**Every button opened its overlay and toggled closed again correctly at
both checkpoints.** No dead menu button found by direct click test.

Working theory: this is a downstream symptom of the plot-tap blocker
above, not a separate menu bug. Most menus are correctly LOCKED/hidden at
fresh boot until story flags unlock them (by design, progressive
disclosure) — a mouse-only player who can never explore the first plot
never triggers any of those unlocks, so almost the whole menu row stays
inert for reasons unrelated to click-handling itself. Once the plot-tap
blocker is actually fixed, re-run this sweep from a genuine fresh boot to
confirm menus unlock and stay clickable through real progress (not just a
loaded checkpoint) — if buttons still feel dead after that, it's a real,
separate bug and this section should be reopened.

## Covered — verified working by click alone

| Surface | Verb/control | Notes |
|---|---|---|
| Q/E/R/F action chips | `ActionPreviewRow` → `PlayerShell._route_action_key` → `OverlayBase.handle_action` | `ActionBtn_Q/E/R/F`, built once at boot (never rebuilt), safe to `control_rect` unscoped |
| Top-level menu row (Z X C V B N M + play) | `MenuSelectionRow` | verified 2x: fresh boot (2 unlocked) and act1_complete (8 unlocked) — every button opens+closes correctly |
| Hat row (4-0) | `ToolSelectionRow` (`SelectionButtonRow`) | |
| Biome row (T-P) | `BiomeSelectionRow` (`SelectionButtonRow`) | |
| Top-level menu open/close (Z X C V B N M) | `MenuSelectionRow` (`SelectionButtonRow`) — verified live 2026-08-05: click opens EscapeMenu, second click closes it | was previously untestable by name-based lookup — see fixed bug below |
| Most overlay tab/row clicks | `UI/Core/ClickWire.gd` helper — EscapeMenu tabs+verb chips, ControlsOverlay tabs, InspectorOverlay, QubitAtlasOverlay card selection, MapMetaOverlay, QuestBoard | |

## Wave 16 (2026-08-10) — the sub-mode gap: the largest keyboard-only hole in the game

**Found by the publishability audit, confirmed by reading every call site, fixed
and live-verified.** `ToolConfig.set_frame_mode` had exactly ONE runtime caller:
the `1/2/3` branch of `QuantumInstrumentInput._unhandled_key_input`. Both
alternative entry points (`QII._cycle_mode`, `QuantumInstrument.cycle_frame_mode`)
were dead code with zero callers. A hat-chip click reaches `_select_frame_hat`,
which never touches mode state.

Consequence: **a mouse-only player was locked to mode 0 of every hat, permanently.**
That is not cosmetic — several hats are two or three tools sharing one glyph:

| Hat | Modes | What mode 0 hides |
|---|---|---|
| Spark ⚡ | `shift` / `bridge` | ALL Majorana bridge verbs — anchor (Span), Braid, Fuse |
| Merchant | `thermal` / `dephase` / `damp` | selling phase, hard pumping |
| Druid | `X` / `Y` / `Z` | rotation about the Y and Z axes |

Spark's bridge verbs are the only source of `bridge_braids_gte` /
`bridge_fused_gte`, which gate the Act-7 "What Connects" flags (`the_span`,
`braid_word`, `braid_alphabet`, `the_fusion`). **No mode switch, no ending.**

**Fix:** a new `UI/Widgets/ModeSelectionRow.gd` renders one chip per mode of the
ACTIVE hat, right-aligned into the hat band (costs no vertical space), hidden
entirely for single-mode hats so no dead chip ever shows. Clicks call the same
`ToolConfig.set_frame_mode` + `QII._on_mode_changed` pair the keys call, and
`_on_frame_mode_changed` re-syncs the highlight — so the row mirrors ToolConfig
and never leads it, which is what stops the two input paths drifting.

Live-verified headed at 1280x720 from `act4_hub`: Ace (one mode) shows nothing;
Spark shows ⚡/🌉 and a real mouse tap on the 🌉 chip flipped the action bar to
`Q Fuse · E Inspect · R Span · F Braid`; Merchant shows three chips and keyboard
`2` moved the same highlight the mouse had set. Chips are named `ModeChip_N` —
during verification a probe searching for the generic `SelectBtn_1` matched the
MENU row's chip three bands away, so the mode chips carry their own prefix.

Also fixed in the same pass: the chips initially drew over the pinned contract
corner (ContractChip + ActFilament). `CONTRACT_CORNER_INSET` is now one shared
constant used by both the biome row and the mode row instead of a bare `-210`.

## Confirmed gaps — keyboard-only, no mouse path

None currently open. The table below is kept for history; see waves 15 and 16.

| Surface | Keyboard mechanism | Status |
|---|---|---|
| A/D inner paging — `ControlsOverlay` Arc tab | `_on_navigate(Vector2i)` via `_on_unhandled_key` | **Fixed pre-wave-15** (`_make_arc_pager`, unknown earlier commit — Arc alone had a clickable pager when this campaign found the other three tabs still lacked one). |
| A/D inner paging — `ControlsOverlay` Self/Story/Guide tabs, `EscapeMenu` Balance settings | Same `_on_navigate()` authority per tab, never given a click affordance | **Fixed wave 15** — generalized `_make_arc_pager` into a shared `_make_nav_pager(label)` helper (ControlsOverlay), added an equivalent local helper to EscapeMenu, both reusing the same `_on_navigate()`/`_step_page()` the keys already call. |
| QubitAtlasOverlay T/Y/U/I/O frame-tab switching | `_on_unhandled_key:206` | **Was already fixed, doc was stale.** `_build_frame_tab_row`/`_switch_frame` (slop knot #17) already routes both keyboard and tab-label clicks through one authority — this table's own claim was wrong by the time wave 15 checked it, most likely fixed by unrelated de-slop work without this doc being updated. Superseded by a real, narrower gap found in its place: QubitAtlasOverlay's own inner Lexicon/Hints A/D paging (`_page_label` footer) had zero click affordance — **fixed wave 15** the same way as the other two overlays. |

## Unknown — needs live discovery (Wave 2)

- Submenu confirm/cancel flows outside Q/E/R/F (destructive confirms — Cull/Trim/Break Q→F chord)
- Save/load slot buttons in EscapeMenu's KEEP/NEW tabs
- Welcome-splash dismiss — confirmed working live 2026-08-05 (`WelcomeOverlay._input` consumes the click, `ui_stack` shows it gone after one tap)
- Refusal/toast text parity — does a mouse-triggered refusal reach the same `RefusalVoice` text as a keyboard one? `handle_action` is a separate dispatch path from `handle_input`; unconfirmed whether they share the same refusal call sites.
- Once explored, does the ALREADY-VISIBLE bubble (now with a real screen position) tap correctly for the second-stage Strike/Extract verbs? Not yet tested — Wave 1 never got past the first plot.

## Bugs found and fixed this campaign (not gaps — genuine defects)

1. **`SelectionButtonRow._clear_buttons()` silently broke every button's
   readable name after the row's first rebuild.** `queue_free()` alone
   defers removal; a same-frame rebuild re-adding a child named
   `"SelectBtn_N"` while the old, not-yet-freed sibling still held that
   name caused Godot to discard the requested name in favor of an
   auto-generated `"@Control@N"`. Fixed: `remove_child()` before
   `queue_free()` (`UI/Widgets/SelectionButtonRow.gd`). This affected the
   Tool/Biome/Menu selection rows — every SelectBtn_N-based screenshot,
   debug, or test tooling lookup silently failed after any menu
   open/close, hat switch, or biome unlock triggered a rebuild.
2. **`control_rect`'s unscoped name search is ambiguous across the three
   `SelectionButtonRow` instances** (Tool/Biome/Menu all name children
   `SelectBtn_N`) — added an optional `{"under": "AncestorName"}` scope to
   `🍄/🎛️/rig_listener.gd`'s `control_rect` verb, plus a new `node_children`
   read-only verb for live child discovery instead of guessing names.
3. **`handle_bubble_tap`'s verb resolution used a bare `terminal != null`
   check** where `Terminal.gd`'s own `can_explore()`/`can_measure()`
   predicates key off `terminal.is_bound` — a terminal object can exist
   but be unbound. Fixed to check `is_bound` too, matching the keyboard
   path's ground truth (`UI/Core/QuantumInstrumentInput.gd`). Real and
   verified-correct by code inspection, but NOT the cause of the "first
   tap does nothing" symptom below — kept because it's a genuine, narrower
   correctness fix (matters once a terminal exists mid-game in an unbound
   state).
4. **THE root cause of "first tap does nothing" — `AppRoot`, `GameRoot`,
   and `PlayerShell` all had `Control.size` permanently stuck at `(0,0)`,
   collapsing the entire app tree's clickable area to nothing.** All three
   called `set_anchors_preset(Control.PRESET_FULL_RECT)` — the bare form,
   which keeps the CURRENT offsets to preserve the visual rect under the
   new anchors. For a freshly created `(0,0)`-sized `Control` added to an
   ALREADY-realized parent (the real root `Window`, sized 1280×720 by the
   time `AppRoot._ready()` runs), that computes offsets of exactly
   `-1280, -720` — which exactly cancels the anchor scaling and
   permanently collapses `.size` back to `(0,0)`, cascading down through
   `GameRoot` into `QuantumField3D` (which itself correctly used
   `set_anchors_and_offsets_preset`, but inherited a zero-size parent
   regardless). With `QuantumField3D.size == (0,0)`, `_gui_input` can
   never fire for ANY click, anywhere on screen — Control's `has_point()`
   test against a zero-size rect is never true — so `_try_pick` never even
   runs, independent of the bubble's own 3D position or visibility. This
   is why the earlier "layout collapse" fix (Wave 2, `_layout_pos`/
   `_rebuild` centroid) was real but insufficient: it fixed the bubble's
   3D position, but the Control receiving the click was already unclickable
   for an unrelated, upstream reason. Root-caused live by adding temporary
   `_dbg_*` fields to `bubble_state`/`control_rect` (since removed, except
   for `local_size`/`anchors`/`offsets` on `control_rect`, kept
   permanently — see rig_listener.gd) that traced `Control.size == 0` up
   the ancestor chain to `AppRoot`'s exact `-1280/-720` offsets. Fixed by
   changing all three call sites to `set_anchors_and_offsets_preset`
   (`scenes/AppRoot.gd`, `scenes/GameRoot.gd`, `UI/PlayerShell.gd`), which
   actually zeroes the offsets instead of preserving them. **Verified
   live: a genuine mouse tap (zero keyboard) on TheDemos's first plot now
   produces `dispatch_ledger: {"action": "explore", "success": true}` and
   flips `plot_glance`'s `revealed` from `false` to `true`.** Regression
   test: `tests/test_headed_player_input_surface.py::
   test_app_boot_chain_zeroes_offsets_not_just_anchors`.

   HUD/menu clicks (`PlayerShell`'s own descendants — `MenuSelectionRow`
   etc.) were unaffected by this bug throughout the campaign despite
   `PlayerShell.size` also reading `(0,0)`: those children are sized by
   their own `Container` layout (content-fit, e.g. an `HBoxContainer`
   sizing a chip to its label), not by anchoring to `PlayerShell`'s own
   `.size`, so their absolute rects were always real. This also confirms
   the "menu buttons dead" report (§ above) was correctly diagnosed as a
   downstream symptom, not a separate bug — the ONE thing actually broken
   was the 3D field's own clickable area.
5. **Mouse biome-tab clicks switched biomes with zero feedback.**
   `BiomeSelectionRow._on_button_selected` called
   `ActiveBiomeManager.set_active_biome()` directly instead of going through
   `QuantumInstrumentInput._select_biome()` (the keyboard TYUIOP path) — the
   only place that repoints the Focus cursor and shows the confirm toast.
   Two divergent code paths for one action; only one carried feedback.
   Fixed by extracting the shared tail into `confirm_biome_switch()` and
   wiring a new `BiomeSelectionRow.biome_confirmed` signal through
   `PlayerShell`, same pattern as `action_pressed`. Live-verified: a mouse
   tap on a biome tab now shows the same "→ Village" toast the keyboard
   gets. Commit `c38fdcb4`.
6. **The Operator hat's two-plot multi-select had zero mouse path —
   the true Act-1 ceiling (wave 6, earnest).** `handle_bubble_tap` always
   ran the single-plot Explore/Strike/Extract cycle regardless of hat or
   shift state; only keyboard's Shift+GHJKL; called `toggle_check`. Fixed
   by threading the real click's `shift_pressed` from
   `QuantumField3D._gui_input` through `_try_pick` → `node_clicked` →
   `FarmView._on_quantum_node_clicked` → `handle_bubble_tap`, which now
   toggles the multi-select checkbox (no focus move, no verb dispatch)
   when shift is held — mirrors the keyboard exactly. Live-verified: two
   real shift-held taps on StarterForest bubbles populate
   `instrument_state.checked_plots` with both grid positions, with zero
   keyboard input. 2D renderer (`QuantumForceGraph`/`TouchInputManager`)
   NOT threaded — out of scope this pass since the 3D field is default and
   what's actually exercised; a known, documented follow-up if 2D is ever
   the live renderer again.
7. **Missed 3D field taps were a silent no-op, misreported by earnest as
   an "active-biome desync"** (wave 6). Investigated against earnest's OWN
   real rig transcript (`queue.jsonl`/`results.jsonl` from its lane) rather
   than reproducing blind. Found: zero `focus_biome` cross-biome dispatches
   anywhere in the log, and `bubble_state`'s per-orb biome tag always
   matched the live-rendered biome — no authority divergence ever
   occurred. The actual mechanism: `QuantumField3D`'s own idle-drift
   rotation (`_process`, "so the 3D never freezes") plus live force
   dynamics continuously move every orb, so a target that's tappable one
   moment can drift past the click point or rotate behind the camera
   later — and `_try_pick` (`Core/Visualization/QuantumField3D.gd`) fell
   all the way through with zero feedback on a genuine miss. A player who
   doesn't notice then presses an action chip, which fires against
   whatever plot is still focused from their LAST successful tap — not the
   one they were just trying to reach, matching earnest's report of a
   "successful" incorporate landing on an already-known plot. Fixed:
   `_try_pick` now toasts `"Nothing there — the field keeps moving, aim
   again"` on a total miss (never fires during a camera-orbit drag —
   `_try_pick` only runs on a real press+release). This ALSO exposed a
   second, pre-existing, unrelated bug caught live: `QuantumField3D._toast()`
   called `show_hint()` with no `importance` argument, defaulting to `1`,
   but `PlayerShell.show_hint()`'s own doc comment says "Importance < 2 is
   logged only; no toast is shown" — so `_toast()` (including the
   pre-existing depth-cap-refusal message, item 6's neighbor in this same
   file) had never actually displayed anything. Fixed by passing
   `importance=2`, matching every other real toast call site in the
   codebase. Live-verified via the rig: a synthetic miss-tap on empty
   field space now produces a genuine new `overlay_text` line reading
   "• Nothing there — the field keeps moving, aim again"; before the
   importance fix it produced none.
8. **Fast-Forward's `dispatch_ledger` entry always logged `success:false`
   despite its own toast always firing correctly** (wave 6 lead, closed by
   wave 7's lost-lamb). Root cause, precisely traced: `Core/Farm.gd`'s
   `time_skip_phrames()` never set a `"success"` key at all. Two different
   read sites in `QuantumInstrumentInput.gd` checked the same absent key
   with OPPOSITE defaults — the toast check (`result.get("success", true)`)
   defaulted true, the ledger writer (`result.get("success", false)`)
   defaulted false — so they silently disagreed on every fast-forward.
   Fixed at the source: `time_skip_phrames()` now sets `success: true` on
   every return path, so both readers agree without relying on defaults.
   Live-verified: two real F-chip taps (explore, then fast-forward once the
   plot was bound) now both show `success: true` in `dispatch_ledger`.
9. **Submenu-routed actions (gate-building, icon injection) never wrote to
   `dispatch_ledger`** (wave 7, lost-lamb). A genuine mouse-only Bell weave
   (Operator hat, shift-tap two plots, gate submenu, tap Bell) succeeded —
   the tutorial advanced — with zero new ledger entry, because
   `_execute_build_gate()`/`_execute_inject_icon()` only ever emitted the
   `action_performed` signal; only `_run_action()` (the direct Q/E/R/F chip
   path) wrote to the ledger. Any rig probe asserting exactly-once dispatch
   via `dispatch_ledger` was blind to every submenu-routed action,
   including the campaign's own entanglement mechanic. Fixed by factoring
   the ledger-append into a shared `_append_dispatch_ledger()` helper and
   calling it from both submenu handlers too.
10. **Biome-tab row could intercept a tap meant for a drifting 3D field
    orb, with confirming (not warning) feedback** (wave 7, lost-lamb — a
    distinct, more severe variant of item 4's original pointer-bleed
    finding; CLOSED post-wave-7, see the section above). Repro: Icon hat,
    StarterForest, a tap resolved fresh via `rig_screen_pos_for_grid` to a
    live orb's screen position instead landed on
    `BiomeSelectionRow/SelectBtn_1` (Village) — confirmed via `hover_probe`
    at that exact point. Unlike a miss (item 7), this didn't fail silently
    — it hit the WRONG thing and showed a legible "→ Village" toast that
    read as a deliberate, successful action, actively misleading rather
    than merely absent. Luke's ruling resolved the design fork item 4 left
    open ("defer to 3D for all things, 2D is being deprecated"): fixed by
    teaching the shared `SelectionButtonRow` base to check
    `QuantumField3D.has_pickable_target()` before claiming a click and
    forward to `receive_deferred_tap()` when a real 3D target is there.
    Live-verified via the rig (see section above for the exact repro).

## Open, not yet fixed

- **Ace hat's Fast-Forward chip logging `success:false` with zero
  feedback** (wave 6 lead) — **CLOSED, was never a real refusal.** See item
  8 above: root-caused and fixed by wave 7's lost-lamb. As a control,
  lost-lamb also verified `reap` (Shift+F) IS a genuine, correctly-toasted
  refusal when nothing's explored yet — a different code path
  (`action_reap`'s own explicit `success: false` branches), not the same
  bug class.

## Out of scope this pass

Genuine `InputEventScreenTouch`/multi-touch/swipe events — `TouchInputManager`
unifies these with mouse today, but this campaign is testing `InputEventMouseButton`
clicks specifically per the literal request ("only using the mouse, only
clicking"). A touch-specific wave through the same autoload is a natural
follow-up, not built here.
