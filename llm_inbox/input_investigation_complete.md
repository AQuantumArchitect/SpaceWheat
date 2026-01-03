# Input Investigation - Complete Analysis

## Investigation Summary

✅ **No duplicate visualization systems found** - Previous "haunting" has been cleaned up
⚠️ **Input routing issue identified** - PlotGridDisplay._input() processes all clicks first

---

## Key Findings

### 1. Clean Architecture ✅

**Only ONE active quantum visualization system**:
```
FarmView.gd creates:
  └─ BathQuantumVisualizationController (quantum_viz)
      └─ QuantumForceGraph (graph)
```

**Archived systems properly isolated**:
- `Core/Visualization/archived_attempts/` - Old systems safely archived
- Ghost `QuantumVisualizationController` removed from FarmUI.tscn
- No duplicate nodes found

### 2. Input Flow Chain Identified

**Current input flow**:
```
Mouse Click
  ↓
PlotGridDisplay._input()           ← PROCESSES FIRST
  - Handles drag/swipe selection
  - Does NOT call set_input_as_handled()
  - Has mouse_filter = IGNORE
  ↓
FarmView._unhandled_input()        ← SHOULD BE CALLED NEXT
  - Forwards to quantum_viz.graph
  - Added debug output to verify
  ↓
QuantumForceGraph._unhandled_input() ← FINAL DESTINATION
  - Checks for clicked bubbles
  - Emits node_clicked signal
```

**Problem**: We don't know which step is failing!

### 3. Debug Output Added

**Three levels of debugging**:

1. **PlotGridDisplay** (line 667-669):
   ```
   🎯 PlotGridDisplay._input: Mouse click at ...
      Plot at position: ...
   ```

2. **FarmView** (line 264-266):
   ```
   📍 FarmView._unhandled_input: Mouse click at ...
      quantum_viz exists: ...
      quantum_viz.graph exists: ...
   ```

3. **QuantumForceGraph** (line 327-331):
   ```
   🖱️  QuantumForceGraph._unhandled_input: Mouse click at ...
      Local mouse pos: ...
      Clicked node: ...
   ```

---

## Test Protocol

### When You Can Test

**Run the game and click anywhere**. You'll see one of these patterns:

### Pattern A: All Three Levels Respond
```
🎯 PlotGridDisplay._input: Mouse click at ...
📍 FarmView._unhandled_input: Mouse click at ...
🖱️  QuantumForceGraph._unhandled_input: Mouse click at ...
```
**Diagnosis**: Input reaches graph! Problem is node detection or signal emission

**Next step**: Check if clicked_node is found, check if signals are emitted

---

### Pattern B: Only PlotGridDisplay Responds
```
🎯 PlotGridDisplay._input: Mouse click at ...
```
**Diagnosis**: Input consumed by PlotGridDisplay before reaching _unhandled_input

**Fix**: Modify PlotGridDisplay._input() to call:
```gdscript
if plot_pos == Vector2i(-1, -1):
    # Not over a plot - don't consume input
    return  # Let it reach _unhandled_input
```

---

### Pattern C: PlotGridDisplay and FarmView Respond
```
🎯 PlotGridDisplay._input: Mouse click at ...
📍 FarmView._unhandled_input: Mouse click at ...
   quantum_viz exists: true
   quantum_viz.graph exists: true
```
**Diagnosis**: Forwarding fails! Input reaches FarmView but not QuantumForceGraph

**Possible causes**:
- CanvasLayer isolation prevents forwarding
- QuantumForceGraph._unhandled_input() not being called when called directly

**Fix**: Instead of forwarding, manually check for bubbles:
```gdscript
# In FarmView._unhandled_input
var local_pos = quantum_viz.graph.get_local_mouse_position()
var clicked_node = quantum_viz.graph.get_node_at_position(local_pos)
if clicked_node:
    _on_quantum_node_clicked(clicked_node.grid_position, 1)
```

---

### Pattern D: No Debug Output At All
```
(silence)
```
**Diagnosis**: Input consumed by something BEFORE PlotGridDisplay

**Possible culprits**:
- FarmInputHandler (but it only handles keyboard)
- FarmUI._input (but it only handles F3)
- Some other Control node

**Fix**: Search for hidden input handlers:
```bash
grep -r "func _input\|func _gui_input" UI/ --include="*.gd"
```

---

## Quick Fixes Ready

### Fix 1: Skip Non-Plot Clicks in PlotGridDisplay

**File**: `UI/PlotGridDisplay.gd` line 670

```gdscript
if event.pressed:
    # Start drag if over a plot
    if plot_pos != Vector2i(-1, -1):
        _start_drag(plot_pos)
    else:
        # NOT over a plot - don't consume, let bubbles handle
        return  # ← ADD THIS LINE
```

This ensures PlotGridDisplay only processes clicks that are actually over plots.

### Fix 2: Direct Bubble Check (Bypass Forwarding)

**File**: `UI/FarmView.gd` line 268

**Replace**:
```gdscript
if quantum_viz and quantum_viz.graph:
    quantum_viz.graph._unhandled_input(event)
```

**With**:
```gdscript
if quantum_viz and quantum_viz.graph and event.pressed:
    var local_pos = quantum_viz.graph.get_local_mouse_position()
    var clicked_node = quantum_viz.graph.get_node_at_position(local_pos)

    if clicked_node:
        print("   ✅ FOUND BUBBLE at grid %s!" % clicked_node.grid_position)
        _on_quantum_node_clicked(clicked_node.grid_position, 1)
    else:
        print("   No bubble at click position")
```

This bypasses the forwarding mechanism entirely and directly checks for bubbles.

---

## Files Modified (Debug Only)

1. **UI/PlotGridDisplay.gd** - Lines 667-669 (debug output)
2. **UI/FarmView.gd** - Lines 264-266 (debug output)
3. **Core/Visualization/QuantumForceGraph.gd** - Lines 323-327 (debug output - already added)

**These are diagnostic only** - no behavior changes yet

---

## Expected Next Steps

1. **User runs game** with debug output
2. **User clicks near bubbles** and reports which debug pattern they see
3. **Apply appropriate fix** based on the pattern

---

## Why Test Scene Works vs Main Game

**Test Scene** (bubble_touch_test.gd):
- Simple hierarchy: Control → CanvasLayer → QuantumForceGraph
- **NO PlotGridDisplay** consuming input first
- QuantumForceGraph._unhandled_input() works directly

**Main Game** (FarmView.gd):
- Complex hierarchy with UI layers
- **PlotGridDisplay._input()** processes ALL mouse clicks first
- Input may be consumed before reaching _unhandled_input

**Key difference**: PlotGridDisplay's _input() method!

---

## Architectural Notes

**Current design issue**:
- PlotGridDisplay handles drag selection via _input()
- QuantumForceGraph handles bubble clicks via _unhandled_input()
- Both want to handle mouse clicks, but _input() runs FIRST

**Proper solution**:
- PlotGridDisplay should only consume clicks that are actually over plots
- Non-plot clicks should pass through to _unhandled_input handlers
- This is what Fix #1 above implements

---

## No Duplicates Found ✅

**Confirmed clean**:
- Only one BathQuantumVisualizationController instance
- Only one QuantumForceGraph instance
- Old systems properly archived in `Core/Visualization/archived_attempts/`
- Ghost nodes removed from FarmUI.tscn

**No "haunting" issues** - the input problem is architectural, not duplicate systems.

---

## Files Requiring Attention (If Pattern B or C)

**Critical**:
1. `UI/PlotGridDisplay.gd` - Add early return for non-plot clicks
2. `UI/FarmView.gd` - Replace forwarding with direct bubble check

**Optional cleanup**:
3. Remove debug output after issue is resolved
