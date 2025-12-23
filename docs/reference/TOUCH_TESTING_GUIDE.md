# Touch Gesture Testing Guide

## Quick Start

### Requirements
- Godot 4.5+ running SpaceWheat
- Mouse (simulates touch) OR actual touch device
- Console open to see debug output

---

## Test Case 1: TAP to MEASURE

### Setup
```
1. Run the game
2. Plant wheat at position (0,0) via UI or keyboard
3. Wait for it to grow (or skip time)
```

### Execute
```
1. Click/tap the wheat bubble in the center quantum graph
2. Observe the plot state changes from "planted" to "measured"
```

### Expected Output
```
🖱️ QuantumForceGraph._input() received LEFT PRESS
🖱️   Local mouse pos: (150, 200)
🖱️   Found quantum node at grid pos: (0, 0)
🖱️   Starting swipe tracking from: (0, 0)

🖱️ QuantumForceGraph._input() received LEFT RELEASE
🖱️   Local mouse pos: (152, 198)
🖱️   Swipe distance: 2.8, time: 0.1s
🖱️   TAP DETECTED (short press) on: (0, 0)
📡 FarmView._on_quantum_node_clicked (BUBBLE) received: (0, 0)
[Plot at (0,0) measured successfully]
```

### Success Criteria
- ✅ Bubble highlighted/selected
- ✅ Quantum state collapses to definite emoji
- ✅ Console shows TAP DETECTED message
- ✅ Plot shows measured indicator on classical tile

---

## Test Case 2: SWIPE to ENTANGLE

### Setup
```
1. Plant wheat at position (0,0) and (1,0)
2. Wait for both to grow (optional)
3. Both plots should be in superposition (unmeasured)
```

### Execute
```
1. Click and hold on bubble at (0,0)
2. Drag to bubble at (1,0) - distance ≥ 50 pixels
3. Complete drag within 1.0 second
4. Release mouse/touch
```

### Expected Output
```
🖱️ QuantumForceGraph._input() received LEFT PRESS
🖱️   Local mouse pos: (100, 150)
🖱️   Found quantum node at grid pos: (0, 0)
🖱️   Starting swipe tracking from: (0, 0)

[User drags...]

🖱️ QuantumForceGraph._input() received LEFT RELEASE
🖱️   Local mouse pos: (170, 145)
🖱️   Swipe distance: 70.4, time: 0.42s
✨ SWIPE DETECTED: (0, 0) → (1, 0)
✨ FarmView._on_quantum_nodes_swiped: (0, 0) → (1, 0)
✅ Entanglement created successfully!
🔗 Entangled (0, 0) ↔ (1, 0) (+20% growth!)
```

### Success Criteria
- ✅ Glowing link appears between bubbles (when implemented)
- ✅ Console shows SWIPE DETECTED message
- ✅ Game logs "Entanglement created successfully"
- ✅ Both plots now have entanglement indicator
- ✅ Energy growth is shared between plots

---

## Test Case 3: SWIPE with NO TARGET

### Setup
```
Plant wheat at (0,0) only (single plot)
```

### Execute
```
1. Click and hold on bubble at (0,0)
2. Drag in empty space (≥50 pixels away)
3. Release mouse/touch
```

### Expected Output
```
✨ SWIPE DETECTED: (0, 0) → ???
🖱️   Swipe but no target node - treating as click
[Plot (0,0) measured]
```

### Success Criteria
- ✅ Swipe not detected as entanglement
- ✅ Falls back to measuring the source bubble
- ✅ No error in console

---

## Test Case 4: DRAG TOO SLOW (>1.0 second)

### Setup
```
Plant wheat at (0,0) and (1,0)
```

### Execute
```
1. Click and hold on bubble at (0,0)
2. Drag slowly to bubble at (1,0)
3. Take more than 1.0 second
4. Release
```

### Expected Output
```
🖱️   Swipe distance: 70.0, time: 1.2s
🖱️   TAP DETECTED (short press) on: (0, 0)
[Only (0,0) measured, NOT entangled]
```

### Success Criteria
- ✅ Swipe not registered (too slow)
- ✅ Treated as single tap on starting node
- ✅ Time limit enforced

---

## Test Case 5: DRAG TOO SHORT (<50 pixels)

### Setup
```
Plant wheat at (0,0) and (1,0) close together
```

### Execute
```
1. Click and hold on bubble at (0,0)
2. Drag very short distance to bubble at (1,0)
3. Release within 1.0 second
```

### Expected Output
```
🖱️   Swipe distance: 30.0, time: 0.3s
🖱️   TAP DETECTED (short press) on: (0, 0)
[Only (0,0) measured, NOT entangled]
```

### Success Criteria
- ✅ Swipe not registered (too short)
- ✅ Minimum distance threshold enforced
- ✅ Treated as single tap

---

## Gesture Parameters (For Tuning)

Edit `QuantumForceGraph.gd` lines 30-31:

```gdscript
const SWIPE_MIN_DISTANCE: float = 50.0    # ← Change this for distance threshold
const SWIPE_MAX_TIME: float = 1.0         # ← Change this for time threshold
```

### Recommended Values by Input Type

| Device | Distance | Time |
|--------|----------|------|
| Mobile (finger) | 40 px | 1.2 s |
| Tablet (finger) | 50 px | 1.0 s |
| Mouse | 60 px | 0.8 s |
| Touch pen | 70 px | 0.9 s |

### How to Adjust
- **If gestures not registering**: Lower distance/increase time
- **If false positives**: Raise distance/lower time
- **For touch devices**: Use larger distances (finger touches are less precise)

---

## Troubleshooting

### Tap not working
- [ ] Check that QuantumForceGraph has `set_process_input(true)`
- [ ] Verify signal is connected in FarmView (check console for ✅ message)
- [ ] Make sure bubble is within graph bounds
- [ ] Check that `get_node_at_position()` returns valid node

### Swipe not working
- [ ] Increase SWIPE_MIN_DISTANCE to 40-60 pixels
- [ ] Verify drag distance in console output
- [ ] Check that swipe completes within 1.0 second
- [ ] Ensure target bubble exists and is detected

### No console output
- [ ] Open Godot debugger (Window → Toggle Debug)
- [ ] Check "Output" tab for prints
- [ ] Verify `set_process_input(true)` is called in `_ready()`
- [ ] Look for parse errors in script

### Gesture registers but doesn't work
- [ ] Check signal connection status (should see ✅ in console)
- [ ] Verify `_on_quantum_nodes_swiped()` is defined in FarmView
- [ ] Check `game_controller.entangle_plots()` exists
- [ ] Look for error messages in console about plots not being plantable

---

## Automation Tests (Optional)

Test without mouse:

```gdscript
# In _input to test swipe programmatically
var test_swipe = InputEventMouseButton.new()
test_swipe.button_index = MOUSE_BUTTON_LEFT
test_swipe.pressed = true
test_swipe.position = Vector2(100, 150)
get_tree().root.push_unhandled_input(test_swipe)

# Then release
test_swipe.pressed = false
test_swipe.position = Vector2(170, 145)
get_tree().root.push_unhandled_input(test_swipe)
```

---

## Console Emoji Guide

| Emoji | Meaning |
|--------|---------|
| 🖱️ | Mouse/input event |
| ✨ | Swipe gesture |
| 📡 | Signal received |
| ✅ | Success |
| ❌ | Error/failure |
| 🔗 | Entanglement |
| 📊 | Data/state |

---

## Next: Full Integration Test

Once individual gestures work:

1. **Plant** 3 plots in different positions
2. **Measure** one with TAP
3. **Entangle** two with SWIPE
4. **Harvest** entangled pair - should yield correlated emojis
5. Check that entanglement was created correctly

---

**Ready to test? Start with Test Case 1! 🚀**
