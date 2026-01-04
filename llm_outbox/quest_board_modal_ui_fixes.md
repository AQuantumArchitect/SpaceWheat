# Quest Board Modal UI Fixes - Following ESC Menu Pattern

## Issues Fixed

Based on ESC menu implementation (`UI/Panels/EscapeMenu.gd`), fixed the following issues in quest board modal UI:

### 1. ✅ Proper Base Class
**Before**: `extends PanelContainer`
**After**: `extends Control`

**Why**: Control provides proper full-screen modal capabilities with anchor presets.

### 2. ✅ Full-Screen Modal Setup
**Added in `_init()`**:
```gdscript
func _init():
    name = "QuestBoard"  # or "FactionBrowser"

    # Fill entire screen - proper modal design
    set_anchors_preset(Control.PRESET_FULL_RECT)
    layout_mode = 1
    mouse_filter = Control.MOUSE_FILTER_STOP
    process_mode = Node.PROCESS_MODE_ALWAYS
```

**Why**:
- `PRESET_FULL_RECT`: Fills entire screen
- `mouse_filter = STOP`: Blocks clicks behind modal
- `process_mode = ALWAYS`: Works even when game is paused

### 3. ✅ Full-Screen Background
**Added**:
```gdscript
# Background - fill screen to block interaction
background = ColorRect.new()
background.color = Color(0.0, 0.0, 0.0, 0.7)
background.set_anchors_preset(Control.PRESET_FULL_RECT)
background.layout_mode = 1
add_child(background)
```

**Why**: Creates semi-transparent overlay that blocks all interaction with game behind modal.

### 4. ✅ Centered Panel with CenterContainer
**Added**:
```gdscript
# Center container for panel
var center = CenterContainer.new()
center.set_anchors_preset(Control.PRESET_FULL_RECT)
center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
center.size_flags_vertical = Control.SIZE_EXPAND_FILL
center.layout_mode = 1
add_child(center)

# Quest board panel
menu_panel = PanelContainer.new()
menu_panel.custom_minimum_size = Vector2(800 * scale, 700 * scale)
center.add_child(menu_panel)
```

**Why**: Properly centers the panel on screen using Godot's layout system.

### 5. ✅ Unhandled Input Pattern
**Before**: `_input(event)` with manual `get_viewport().set_input_as_handled()`
**After**: `_unhandled_key_input(event)`

```gdscript
func _unhandled_key_input(event: InputEvent) -> void:
    """Modal input handling - hijacks controls when open

    Using _unhandled_key_input() ensures proper input order:
    1. FactionBrowser (child) gets first chance
    2. Then QuestBoard handles unhandled input
    """
    if not visible or not event is InputEventKey or not event.pressed or event.echo:
        return

    # If browser is open, it handles input first
    if is_browser_open and faction_browser and faction_browser.visible:
        return

    _handle_board_input(event)
```

**Why**: `_unhandled_key_input()` respects input priority:
- Children handle input first
- Parent only gets unhandled input
- Prevents input conflicts between nested modals

### 6. ✅ Direct Keycode Matching
**Before**: `event.is_action_pressed("select_plot_u")`
**After**: `match event.keycode: KEY_U:`

```gdscript
func _handle_board_input(event: InputEvent) -> void:
    """Handle quest board controls"""
    match event.keycode:
        KEY_ESCAPE:
            close_board()
            get_viewport().set_input_as_handled()

        KEY_U:
            select_slot(0)
            get_viewport().set_input_as_handled()

        KEY_Q:
            action_q_on_selected()
            get_viewport().set_input_as_handled()

        KEY_C:
            open_faction_browser()
            get_viewport().set_input_as_handled()
```

**Why**: More reliable for modal input handling, matches ESC menu pattern.

### 7. ✅ Proper Input Consumption
**Added**: `get_viewport().set_input_as_handled()` after EVERY keypress

**Why**: Ensures input doesn't leak through to game below modal.

## Files Modified

### `/UI/Panels/QuestBoard.gd`
- Changed base class: `Control` instead of `PanelContainer`
- Added `_init()` with proper modal setup
- Added full-screen background ColorRect
- Added CenterContainer for proper centering
- Changed to `_unhandled_key_input()` pattern
- Changed to `match event.keycode` for input
- Added `get_viewport().set_input_as_handled()` everywhere

### `/UI/Panels/FactionBrowser.gd`
- Changed base class: `Control` instead of `PanelContainer`
- Added `_init()` with proper modal setup
- Added full-screen background ColorRect (darker: 0.8 alpha)
- Added CenterContainer for proper centering
- Changed to `_unhandled_key_input()` pattern
- Changed to `match event.keycode` for input
- Added `get_viewport().set_input_as_handled()` everywhere
- Removed delegated input handling (handles own input now)

## Visual Hierarchy

```
QuestBoard (Control, fills screen)
├─ background (ColorRect, 70% black)
├─ center (CenterContainer)
│  └─ menu_panel (PanelContainer, 800×700)
│     └─ main_vbox (VBoxContainer)
│        ├─ title_label
│        ├─ controls_label
│        ├─ biome_state_label
│        ├─ slot_container (4 QuestSlots)
│        └─ accessible_factions_label
└─ faction_browser (FactionBrowser, optional)
   ├─ background (ColorRect, 80% black - darker!)
   ├─ center (CenterContainer)
   │  └─ browser_panel (PanelContainer, 700×650)
   │     └─ main_vbox
   │        ├─ title_label
   │        ├─ controls_label
   │        └─ scroll_container
   │           └─ faction_list (VBoxContainer)
   └─ (faction items...)
```

## Input Flow (Fixed)

### Level 1: Quest Board
```
User presses C
    ↓
QuestBoard._unhandled_key_input(KEY_C)
    ↓
QuestBoard opens (visible = true)
    ↓
User presses U
    ↓
QuestBoard._unhandled_key_input(KEY_U)
    ↓
select_slot(0)
    ↓
get_viewport().set_input_as_handled() ← Input consumed!
```

### Level 2: Faction Browser
```
User presses C (while quest board open)
    ↓
QuestBoard._unhandled_key_input(KEY_C)
    ↓
open_faction_browser() → browser.visible = true
    ↓
User presses U
    ↓
FactionBrowser._unhandled_key_input(KEY_U)  ← Browser handles first!
    ↓
move_selection(-1)
    ↓
get_viewport().set_input_as_handled() ← Input consumed!
    ↓
QuestBoard._unhandled_key_input() doesn't run (input already handled)
```

## Key Improvements

1. **Proper modal blocking**: Full-screen background blocks all clicks behind modal
2. **Correct input priority**: Children handle input before parents via `_unhandled_key_input`
3. **No input leaks**: Every keypress calls `get_viewport().set_input_as_handled()`
4. **Proper centering**: CenterContainer ensures panel is centered at all resolutions
5. **Visual feedback**: Darker background for nested modal (faction browser)

## Testing Checklist

Once codebase compiles:
- [ ] Open quest board with C → Should show full-screen overlay
- [ ] Click outside panel → Should NOT close (proper blocking)
- [ ] Press U/I/O/P → Should select slots
- [ ] Press Q/E/R → Should perform actions on selected slot
- [ ] Press C again → Should open faction browser
- [ ] In browser, press U/I/O/P → Should navigate factions
- [ ] In browser, press Q → Should select faction and close browser
- [ ] In browser, press ESC → Should close browser (back to quest board)
- [ ] In quest board, press ESC → Should close quest board (back to game)
- [ ] Press C in game → Should hijack UIOP+QER (game doesn't respond to them)

## Comparison with ESC Menu

| Feature | ESC Menu | Quest Board (Fixed) | Status |
|---------|----------|---------------------|--------|
| Base class | `Control` | `Control` | ✅ |
| Full-screen preset | `PRESET_FULL_RECT` | `PRESET_FULL_RECT` | ✅ |
| Background overlay | ColorRect 70% black | ColorRect 70% black | ✅ |
| CenterContainer | Yes | Yes | ✅ |
| Input method | `_unhandled_key_input` | `_unhandled_key_input` | ✅ |
| Keycode matching | `match event.keycode` | `match event.keycode` | ✅ |
| Input consumption | `set_input_as_handled()` | `set_input_as_handled()` | ✅ |
| process_mode | `ALWAYS` | `ALWAYS` | ✅ |
| mouse_filter | `STOP` | `STOP` | ✅ |

**All patterns match! ✅**

## Status: FIXED ✅

The quest board now follows the same proven pattern as the ESC menu:
- Proper full-screen modal
- Correct input handling with `_unhandled_key_input`
- Proper input consumption
- Full-screen background blocking
- Centered panel layout

Ready for testing once compilation issues are resolved!
