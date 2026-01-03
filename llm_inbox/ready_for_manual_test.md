# Ready for Manual Testing - Debug Output Active

## Status: Debug Output Added ✅

I've added comprehensive debug output at three levels of the input chain. When you run the game and click, you'll immediately see which parts are working.

---

## Quick Test

**Just run**:
```bash
godot /home/tehcr33d/ws/SpaceWheat
```

**Then click anywhere** and look for these messages in the console:

### Pattern 1: Everything Works ✅
```
🎯 PlotGridDisplay._input: Mouse click at (640, 360)
   Plot at position: (-1, -1)
📍 FarmView._unhandled_input: Mouse click at (640, 360), pressed=true
   quantum_viz exists: true
   quantum_viz.graph exists: true
🖱️  QuantumForceGraph._unhandled_input: Mouse click at (640, 360), pressed=true
   Local mouse pos: (640, 360)
   Clicked node: <QuantumNode> or null
```
**Diagnosis**: Input reaches everywhere! If "Clicked node" is null, bubbles just aren't at that position.

**Fix**: Try clicking directly on visible bubbles. If still null, bubble detection is broken.

---

### Pattern 2: Stops at PlotGridDisplay ⚠️
```
🎯 PlotGridDisplay._input: Mouse click at (640, 360)
   Plot at position: (2, 0)
```
**Diagnosis**: PlotGridDisplay finds a plot and consumes the input!

**Fix Applied Below** - PlotGridDisplay needs to skip non-plot clicks

---

### Pattern 3: Stops at FarmView ⚠️
```
🎯 PlotGridDisplay._input: Mouse click at (640, 360)
   Plot at position: (-1, -1)
📍 FarmView._unhandled_input: Mouse click at (640, 360), pressed=true
   quantum_viz exists: true
   quantum_viz.graph exists: true
```
**Diagnosis**: Input reaches FarmView but forwarding to QuantumForceGraph fails!

**Fix Applied Below** - Direct bubble detection instead of forwarding

---

### Pattern 4: Nothing ❌
```
(silence)
```
**Diagnosis**: Something consuming ALL input before PlotGridDisplay

**Action**: Search for other _input handlers:
```bash
grep -r "func _input" UI/ --include="*.gd"
```

---

## Ready-to-Apply Fixes

### Fix #1: Let Non-Plot Clicks Through

**File**: `UI/PlotGridDisplay.gd` line 673

**Add early return** after checking plot position:

```gdscript
if event.pressed:
    # Start drag if over a plot
    if plot_pos != Vector2i(-1, -1):
        _start_drag(plot_pos)
    else:
        # NOT over a plot - let input pass to quantum bubbles
        return  # ← ADD THIS LINE
```

This ensures PlotGridDisplay only processes clicks that are actually over plot tiles.

---

### Fix #2: Direct Bubble Check

**File**: `UI/FarmView.gd` line 268-270

**Replace the forwarding** with direct bubble detection:

```gdscript
# OLD (forwarding):
if quantum_viz and quantum_viz.graph:
    quantum_viz.graph._unhandled_input(event)

# NEW (direct check):
if quantum_viz and quantum_viz.graph and event.pressed:
    var local_pos = quantum_viz.graph.get_local_mouse_position()
    var clicked_node = quantum_viz.graph.get_node_at_position(local_pos)

    if clicked_node:
        print("   ✅ DIRECT: Found bubble at grid %s!" % clicked_node.grid_position)
        _on_quantum_node_clicked(clicked_node.grid_position, 1)
        get_viewport().set_input_as_handled()  # Consume it so PlotGridDisplay doesn't also process
    else:
        print("   No bubble found at click position")
```

This bypasses the input forwarding and directly checks if a bubble was clicked.

---

## Investigation Complete

### What I Found

✅ **No duplicate systems** - Clean architecture, no "haunting"
✅ **PlotGridDisplay is the blocker** - Its _input() runs before _unhandled_input()
✅ **Test scene works** - Because it has no PlotGridDisplay competing for input

### Root Cause

PlotGridDisplay._input() processes ALL mouse clicks first (for drag selection), preventing QuantumForceGraph._unhandled_input() from receiving them.

Even with `mouse_filter = IGNORE`, the _input() method still runs!

---

## Next Steps

1. **Run the game and click** - Tell me which pattern you see
2. **I'll apply the appropriate fix** based on the pattern
3. **Touch controls will work!**

The test scene proves the touch system WORKS - we just need to fix the input routing in the main game.

---

## Files Ready to Fix

1. `UI/PlotGridDisplay.gd` - Line 673 (Fix #1)
2. `UI/FarmView.gd` - Lines 268-270 (Fix #2)

Both fixes are simple 1-5 line changes. Just need to know which pattern you see!
