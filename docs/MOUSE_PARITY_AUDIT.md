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
| **Plot select+act on an UNEXPLORED plot (the core loop's first move)** | 3D bubble tap should route `_gui_input → _try_pick → handle_bubble_tap`, but `bubble_state` shows the pre-explore register has `visible: false` and a degenerate `screen_pos` near the viewport origin — `_try_pick`'s pixel-radius hit-test can never find it. A raw-pixel sweep of the ENTIRE play area (66 points) after confirmed welcome-dismiss found ZERO clickable targets. Keyboard G/H/J/K/L selects by index, no visibility needed. | **Severe — this is the very first thing "or just tap it" tells a fresh player to try, and it silently does nothing.** `PlotGridDisplay` is documented (task #408, "2D plot tiles as fixed rack in 3D mode") as the intended pre-explore click surface, but its screen rect/tile geometry hasn't been confirmed live yet — first item for Wave 2. |
| A/D inner paging (Arc/Self/Story/Guide tabs in `ControlsOverlay`, Balance settings in `EscapeMenu`) | `step_active_layer()` (`UI/Core/QuantumInstrumentInput.gd:1337`) wired to `_on_navigate(Vector2i)` via `_on_unhandled_key` (fixed for keyboard 2026-08-05) | Zero mouse call sites. No on-screen prev/next affordance exists at all — a mouse-only player cannot reach page 2+ of any paginated tab (Arc tab alone has 57 flags at 6/page = 11 pages). |
| QubitAtlasOverlay T/Y/U/I/O frame-tab switching | `_on_unhandled_key:206` | `ClickWire.attach` here (`:438`) only covers card selection *within* a tab, not the tab switch itself. |

## Unknown — needs live discovery (Wave 2)

- **Start here**: does `PlotGridDisplay`'s fixed-rack overlay actually give an unexplored plot a real, visible, clickable Control? Get its live screen rect (`control_rect`/`node_children` under `PlotGridDisplay`) and tap that instead of the 3D field's `rig_screen_pos_for_grid`. If it also fails to dispatch, this is the real, severe, launch-blocking bug — the intended "or just tap it" path for a brand-new player is broken.
- Whether the `tap` rig verb's `pos=` resolution should be extended to also check `PlotGridDisplay` (a third node kind alongside `quantum_nodes_by_grid_pos`/`rig_screen_pos_for_grid`) — currently it can't test the pre-explore click path at all.
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
   tap does nothing" symptom below — that traces to the bubble being
   invisible/unpickable pre-explore, not verb misresolution. Kept because
   it's a genuine, narrower correctness fix (matters once a terminal
   exists mid-game in an unbound state).

## Out of scope this pass

Genuine `InputEventScreenTouch`/multi-touch/swipe events — `TouchInputManager`
unifies these with mouse today, but this campaign is testing `InputEventMouseButton`
clicks specifically per the literal request ("only using the mouse, only
clicking"). A touch-specific wave through the same autoload is a natural
follow-up, not built here.
