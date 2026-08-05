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

## Covered — verified working by click alone

| Surface | Verb/control | Notes |
|---|---|---|
| Plot select+act | 3D bubble tap (`QuantumField3D._gui_input` → `_try_pick` → `handle_bubble_tap`) | fuses select+act, unlike keyboard G/H/J/K/L which is pure select |
| Q/E/R/F action chips | `ActionPreviewRow` → `PlayerShell._route_action_key` → `OverlayBase.handle_action` | |
| Hat row (4-0) | `ToolSelectionRow` (`SelectionButtonRow`) | |
| Biome row (T-P) | `BiomeSelectionRow` (`SelectionButtonRow`) | |
| Top-level menu open/close (Z X C V B N M) | `MenuSelectionRow` (`SelectionButtonRow`) — verified live 2026-08-05: click opens EscapeMenu, second click closes it | was previously untestable by name-based lookup — see fixed bug below |
| Most overlay tab/row clicks | `UI/Core/ClickWire.gd` helper — EscapeMenu tabs+verb chips, ControlsOverlay tabs, InspectorOverlay, QubitAtlasOverlay card selection, MapMetaOverlay, QuestBoard | |

## Confirmed gaps — keyboard-only, no mouse path

| Surface | Keyboard mechanism | Why it's a gap |
|---|---|---|
| A/D inner paging (Arc/Self/Story/Guide tabs in `ControlsOverlay`, Balance settings in `EscapeMenu`) | `step_active_layer()` (`UI/Core/QuantumInstrumentInput.gd:1337`) wired to `_on_navigate(Vector2i)` via `_on_unhandled_key` (fixed for keyboard 2026-08-05) | Zero mouse call sites. No on-screen prev/next affordance exists at all — a mouse-only player cannot reach page 2+ of any paginated tab (Arc tab alone has 57 flags at 6/page = 11 pages). |
| QubitAtlasOverlay T/Y/U/I/O frame-tab switching | `_on_unhandled_key:206` | `ClickWire.attach` here (`:438`) only covers card selection *within* a tab, not the tab switch itself. |

## Unknown — needs live discovery (Phase 2)

- Submenu confirm/cancel flows outside Q/E/R/F (destructive confirms — Cull/Trim/Break Q→F chord)
- Save/load slot buttons in EscapeMenu's KEEP/NEW tabs
- Welcome-splash dismiss — code-confirmed covered (`WelcomeOverlay._input` consumes any `InputEventMouseButton`), not yet live-verified this campaign
- Refusal/toast text parity — does a mouse-triggered refusal reach the same `RefusalVoice` text as a keyboard one? `handle_action` is a separate dispatch path from `handle_input`; unconfirmed whether they share the same refusal call sites.

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

## Out of scope this pass

Genuine `InputEventScreenTouch`/multi-touch/swipe events — `TouchInputManager`
unifies these with mouse today, but this campaign is testing `InputEventMouseButton`
clicks specifically per the literal request ("only using the mouse, only
clicking"). A touch-specific wave through the same autoload is a natural
follow-up, not built here.
