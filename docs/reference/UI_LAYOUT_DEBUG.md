# UI Layout Debugging Guide

## Current Layout Structure

```
┌────────────────────────────────────────────────────────────┐
│ MainContainer (anchored FULL_RECT, expands to fill viewport)
├────────────────────────────────────────────────────────────┤
│                                                              │
│ TopBar (60px fixed height, RED border)                     │
│ ├─ ResourcePanel (left, expand) - ORANGE border           │
│ ├─ Spacer (expand)                                         │
│ ├─ GoalPanel (center, 300px min width) - CYAN border      │
│ ├─ Spacer (expand)                                         │
│ └─ KeyboardHintButton (right, 150px min) - varies         │
│                                                              │
├────────────────────────────────────────────────────────────┤
│                                                              │
│ MainArea (expands to fill remaining space)                │
│ ├─ PlotsRow (100px fixed height, GREEN border)            │
│ │  └─ (Will contain plot tiles positioned horizontally)   │
│ │                                                          │
│ ├─ PlayArea (expands to fill, BLUE border)                │
│ │  ├─ QuantumGraph (GOLD border, fills play area)         │
│ │  ├─ EntanglementLines (LIME border, fills play area)    │
│ │  └─ BiomeInfoDisplay (top right corner)                 │
│ │                                                          │
│ └─ ActionsRow (80px fixed height, YELLOW border)          │
│    └─ ActionPreviewRow (LIGHT_MAGENTA border, expands)    │
│                                                              │
├────────────────────────────────────────────────────────────┤
│                                                              │
│ BottomBar (60px fixed height, MAGENTA border)             │
│ └─ ToolSelectionRow (LIGHT_BLUE border, expands)          │
│                                                              │
└────────────────────────────────────────────────────────────┘
```

## Color Guide (Debug Borders)

When you launch the game with debug enabled, each element has a colored border:

| Color | Component | Zone |
|-------|-----------|------|
| 🔴 RED | TopBar container | Top area |
| 🟠 ORANGE | ResourcePanel | Top-left |
| 🟡 YELLOW | ActionsRow container | Middle-bottom |
| 🟢 GREEN | PlotsRow container | Middle-top |
| 🔵 BLUE | PlayArea container | Center |
| 🟣 MAGENTA | BottomBar container | Bottom |
| 🔷 CYAN | GoalPanel | Top-center |
| 🟦 LIGHT BLUE (cyan-blue) | ToolSelectionRow | Bottom |
| 🟪 PINK (light magenta) | ActionPreviewRow | Middle |
| 🟩 LIGHT GREEN | BiomeInfoDisplay | Play area corner |
| 🟨 GOLD/YELLOW-ORANGE | QuantumGraph | Play area center |
| 💚 LIME GREEN | EntanglementLines | Play area center |

## How to Debug

### 1. Launch UITestOnly.tscn
```bash
# In Godot editor, open res://UITestOnly.tscn
# Hit Play or F5
# You'll see colored boxes showing where each element is
```

### 2. What You Should See

**Good Layout:**
- ✅ TOP BAR (RED): Stretches across top at 60px height
- ✅ LEFT side: ORANGE (Resources) label visible
- ✅ CENTER: CYAN (Goals) visible
- ✅ RIGHT: Keyboard Help button
- ✅ MIDDLE: Large BLUE area (PlayArea) filling most of screen
  - GOLD box (QuantumGraph) inside
  - LIME box (EntanglementLines) inside
  - Small LIGHT_GREEN (BiomeInfo) in corner
- ✅ MIDDLE-BOTTOM: YELLOW/LIGHT_MAGENTA (Actions preview)
- ✅ GREEN area: PlotsRow between play area and actions
- ✅ BOTTOM: MAGENTA bar with LIGHT_BLUE (Tool buttons)

**Problems to Look For:**
- ❌ Everything crammed in one corner = anchoring not applied
- ❌ Missing colored boxes = component didn't initialize
- ❌ Overlapping boxes = size_flags not set correctly
- ❌ Boxes too small = custom_minimum_size not applied

### 3. Inspect in Godot Editor

1. Play the scene
2. In the Scene tree (left panel), expand nodes:
   - FarmView → FarmUIController → MainContainer
3. Click each node to see its properties in Inspector
4. Check:
   - **Layout Mode**: Should be "Anchors" for proper positioning
   - **Anchors**: Should be FULL_RECT or preset
   - **Size**: Should show actual dimensions
   - **Custom Min Size**: Should match what we set (60px, 100px, etc.)

### 4. Common Issues & Fixes

**Issue: Everything in corner**
```
Cause: set_anchors_preset() not called
Fix: Make sure FarmUIController calls set_anchors_preset(Control.PRESET_FULL_RECT)
```

**Issue: Components disappear**
```
Cause: size_flags_horizontal/vertical not set
Fix: Add size_flags_horizontal = Control.SIZE_EXPAND_FILL
```

**Issue: Bar too big/small**
```
Cause: custom_minimum_size not set correctly
Fix: Check: top_bar.set_custom_minimum_size(Vector2(0, 60))
```

**Issue: Overlapping elements**
```
Cause: Containers not expanding correctly
Fix: Make sure VBoxContainer uses SIZE_EXPAND_FILL for vertical
```

## Debug Output to Check

When game starts, you should see:
```
🎮 FarmUIController initializing...
📐 Layout Manager created
🏗️  UI structure created with proper anchoring
   TopBar: 60px
   PlotsRow: 100px
   PlayArea: Expands to fill
   ActionsRow: 80px
   BottomBar: 60px
📋 OverlayManager initialized
🎨 UI components created and positioned
   TopBar: Resource | Goal | Keyboard Help
   PlayArea: Biome Info (corner)
   ActionsRow: Action Preview
   BottomBar: Tool Selection
✨ Visualization systems created and anchored
🔗 Connecting signals...
⏳ Farm signals: Waiting for farm injection via GameStateManager
⌨️  FarmInputHandler created (Tool Mode System)
🐛 DEBUG MODE: Adding visual borders to all UI elements
✅ FarmUIController ready!
```

If you're missing any of these messages, something failed to initialize.

## Manual Layout Testing

### Test 1: Window Resize
1. Launch game
2. Resize window by dragging edges
3. All colored boxes should resize proportionally
4. TopBar should stay 60px high
5. BottomBar should stay 60px high
6. PlayArea should expand/shrink

### Test 2: Element Positions
Verify each element is in the right spot:
- TopBar elements should be horizontally aligned
- ResourcePanel on LEFT
- GoalPanel in CENTER
- KeyboardButton on RIGHT
- All without overlapping

### Test 3: Z-Ordering
1. Open Escape menu (press ESC)
2. Menu should appear on top of everything
3. Close menu (press ESC again)
4. Layout still correct

### Test 4: Responsiveness
Test that UI adapts to different viewport sizes:
- ✅ 800×600: All elements visible
- ✅ 1920×1080: Elements scale up, layout maintains proportions
- ✅ 3840×2160: 4K resolution works

## Next Steps: Fine-Tuning

Once layout is visible and positioned correctly:

1. **Adjust sizes** based on visual feedback
   - TopBar too tall? Change from 60px to 50px
   - PlayArea too small? Increase PlotsRow/ActionsRow sizes
   - Spacers needed? Add spacing between elements

2. **Add components** to each zone
   - TopBar: Add resource displays, goals, buttons
   - PlotsRow: Add plot tiles (6 for 1×6 grid)
   - PlayArea: Quantum visualization, entanglement lines
   - ActionsRow: Action preview buttons
   - BottomBar: Tool selection buttons

3. **Style elements** with colors, fonts, icons
   - Make ResourcePanel pretty (emoji resources)
   - Style GoalPanel with progress bars
   - Color action buttons (Q=Wheat, E=Mushroom, R=Tomato)
   - Style tool buttons (1-6)

4. **Add animations**
   - Smooth transitions when elements show/hide
   - Pulsing animations for highlighted tools
   - Fade in/out for overlays

## Disabling Debug

When layout is perfect and you want to remove colored borders:

```gdscript
# In FarmUIController._ready(), change:
# _enable_debug_layout()  # Comment this out

# Or create a debug flag:
const DEBUG_UI = false

func _ready():
    if DEBUG_UI:
        _enable_debug_layout()
```

## Troubleshooting Checklist

- [ ] Colored borders visible?
- [ ] TopBar at top?
- [ ] BottomBar at bottom?
- [ ] PlayArea filling center?
- [ ] PlotsRow above PlayArea?
- [ ] ActionsRow below PlayArea?
- [ ] No overlapping elements?
- [ ] Resizes smoothly?
- [ ] All component labels visible?
- [ ] Console shows all "✅" messages?

If any of these fail, check the corresponding section above!

---

## Pro Tips

1. **Use Ctrl+D in editor** to toggle debug canvas - shows layout boxes
2. **Right-click node** → "Align" to see alignment helpers
3. **Use Margins** instead of Position for child elements
4. **Use VBoxContainer/HBoxContainer** for automatic layout
5. **Test at multiple resolutions** - includes phones (375×667), tablets (768×1024), desktop (1920×1080)

---

This debugging approach should reveal exactly where each UI element is and allow you to arrange them perfectly!
