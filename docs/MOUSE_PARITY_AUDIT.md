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

## Out of scope this pass

Genuine `InputEventScreenTouch`/multi-touch/swipe events — `TouchInputManager`
unifies these with mouse today, but this campaign is testing `InputEventMouseButton`
clicks specifically per the literal request ("only using the mouse, only
clicking"). A touch-specific wave through the same autoload is a natural
follow-up, not built here.
