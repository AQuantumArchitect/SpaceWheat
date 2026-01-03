# Touch Input Debugging Status

## Changes Applied

### 1. Canvas Layer Priority ✅
**File**: `UI/FarmView.gd` line 60
- Changed from `layer = 0` to `layer = 1`
- Should render QuantumForceGraph above UI

### 2. Input Method Changed ✅
**File**: `Core/Visualization/QuantumForceGraph.gd`
- Changed `_input()` → `_unhandled_input()` (line 319)
- Changed `set_process_input(true)` → `set_process_unhandled_input(true)` (line 122)
- **Why**: Control nodes consume _input events, _unhandled_input reaches us after

### 3. Mouse Filter Settings ✅
**File**: `UI/FarmUI.tscn`
- PlotGridDisplay: `mouse_filter = 2` (IGNORE) - line 27
- MainContainer: `mouse_filter = 2` (IGNORE) - line 44

## Problem: Input Not Reaching QuantumForceGraph

**Debug output shows**: `_unhandled_input()` is NEVER called

**This means**: Something is consuming ALL input before it reaches QuantumForceGraph

## Possible Causes

### 1. Control Nodes Consuming Input
Even with mouse_filter=IGNORE, Control nodes might be consuming events in their own _input handlers

### 2. PlayerShell or FarmUI Consuming Input
Check if PlayerShell or FarmUI have _input() or _gui_input() methods that consume events

### 3. Input Priority Order
CanvasLayer order might not affect input routing the way we expect

### 4. Node2D Input Limitations
Node2D might not receive _unhandled_input the same way Control does

## Recommended Investigation

### Manual Testing

1. **Run the game** and click near bubbles
2. **Watch console** for these debug messages:
   ```
   🖱️  QuantumForceGraph._unhandled_input: Mouse click at ...
      Local mouse pos: ...
      Clicked node: ...
   ```

3. **If you see these messages** → Click detection works, but node lookup fails
4. **If you don't see them** → Input is being consumed somewhere else

### Check Input Consumers

Search for other nodes handling input:

```bash
grep -r "func _input\|func _gui_input\|func _unhandled_input" /home/tehcr33d/ws/SpaceWheat/UI --include="*.gd"
```

Look for anything that might call `get_viewport().set_input_as_handled()`

### Alternative: Use Control Instead of Node2D

**Option**: Make QuantumForceGraph extend Control instead of Node2D

**Pros**:
- Control nodes receive mouse input automatically
- mouse_filter property for fine control
- _gui_input() method specifically for GUI input

**Cons**:
- Might break existing rendering code
- More invasive change

## Current Architecture Issue

```
Input Event Flow:
──────────────────
Mouse Click
  ↓
Viewport receives event
  ↓
_input() methods called (FIRST)
  ├─ PlayerShell? ❓
  ├─ FarmUI? ❓
  ├─ FarmView? ❓
  └─ Other scripts? ❓
  ↓
Control._gui_input() methods called (SECOND)
  ├─ PlotGridDisplay (mouse_filter=IGNORE) ✅
  ├─ MainContainer (mouse_filter=IGNORE) ✅
  └─ Other UI controls? ❓
  ↓
_unhandled_input() methods called (LAST)
  └─ QuantumForceGraph ❌ NEVER REACHED
```

**Something in the "First" or "Second" phase is consuming the input!**

## Quick Test: Try _gui_input on a Control Wrapper

Create a Control node that wraps QuantumForceGraph:

```gdscript
# In BathQuantumVisualizationController.gd, around line 120

var input_catcher = Control.new()
input_catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
input_catcher.mouse_filter = Control.MOUSE_FILTER_PASS  # Let clicks through but receive them
add_child(input_catcher)

input_catcher.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.pressed:
        print("🎯 CONTROL WRAPPER received click at: ", event.position)
        # Forward to graph
        graph._process_click(event.position)
)
```

This Control wrapper will receive clicks via GUI system instead of input system.

## Test Scene Works But Main Game Doesn't?

**Key difference**: Test scene uses simpler hierarchy

Check if test scene has different:
- CanvasLayer setup
- Control node hierarchy
- Input handling scripts

Compare:
- `Tests/bubble_touch_test.gd` vs `UI/FarmView.gd`
- `Tests/bubble_touch_test.tscn` vs `UI/FarmUI.tscn`

## Next Steps

1. **Manual test**: Click bubbles, watch console for debug output
2. **If no output**: Something is definitely consuming input
3. **Find the consumer**: Search for _input methods
4. **Options**:
   - Remove input consumption from offending node
   - Use Control wrapper with _gui_input
   - Make QuantumForceGraph a Control node

**Report back**: Do you see the debug messages when clicking?
