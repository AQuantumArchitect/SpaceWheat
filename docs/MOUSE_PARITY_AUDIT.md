# Mouse-Only Parity Audit

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

## Confirmed gaps — keyboard-only, no mouse path

| Surface | Keyboard mechanism | Why it's a gap |
|---|---|---|
| A/D inner paging (Arc/Self/Story/Guide tabs in `ControlsOverlay`, Balance settings in `EscapeMenu`) | `step_active_layer()` (`UI/Core/QuantumInstrumentInput.gd:1337`) wired to `_on_navigate(Vector2i)` via `_on_unhandled_key` (fixed for keyboard 2026-08-05) | Zero mouse call sites. No on-screen prev/next affordance exists at all — a mouse-only player cannot reach page 2+ of any paginated tab (Arc tab alone has 57 flags at 6/page = 11 pages). |
| QubitAtlasOverlay T/Y/U/I/O frame-tab switching | `_on_unhandled_key:206` | `ClickWire.attach` here (`:438`) only covers card selection *within* a tab, not the tab switch itself. |

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
