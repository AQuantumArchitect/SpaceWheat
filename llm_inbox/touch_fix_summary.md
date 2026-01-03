# Touch Control Fix - Manual Testing Needed

## What I Fixed

### 1. Canvas Layer Priority
- Changed QuantumForceGraph CanvasLayer from `layer = 0` to `layer = 1`
- Should render above UI

### 2. Input Method
- Changed `_input()` → `_unhandled_input()` in QuantumForceGraph
- Added input forwarding from FarmView to QuantumForceGraph

### 3. Debug Output Added
- QuantumForceGraph now prints when it receives clicks
- Prints local mouse position and which node was clicked

## The Problem

**Input is NOT reaching QuantumForceGraph** - Debug messages never appear

## Why Test Scene Works But Main Game Doesn't

**Test Scene** (`Tests/bubble_touch_test.gd`):
- Simple hierarchy: Control → CanvasLayer → BathQuantumViz → QuantumForceGraph
- No complex UI systems
- Touch controls WORK

**Main Game** (`UI/FarmView.gd`):
- Complex hierarchy with multiple input handlers
- FarmInputHandler consuming keyboard input
- Multiple UI layers
- Touch controls DON'T WORK

## Next: Manual Testing Required

**Please try this**:

1. **Run the main game**
2. **Click near a quantum bubble**
3. **Watch the console** for this message:
   ```
   🖱️  QuantumForceGraph._unhandled_input: Mouse click at ...
   ```

4. **Report back**:
   - ✅ If you see the message → Input reaches graph, but node detection might be broken
   - ❌ If you don't see it → Something is still consuming input

## If Still No Input

**Try this diagnostic**: Add a print to FarmView._unhandled_input to see if IT receives clicks:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		print("📍 FarmView received mouse click: ", event.position)  # ADD THIS LINE

	if quantum_viz and quantum_viz.graph:
		quantum_viz.graph._unhandled_input(event)
```

If you see "FarmView received mouse click" but NOT "QuantumForceGraph._unhandled_input", then the forwarding isn't working.

## Alternative: Simple Click Test

**Quick bypass test** - Add this to FarmView._unhandled_input:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("🖱️  FarmView: Click at %s" % event.position)

		# Manually check if we clicked a bubble
		if quantum_viz and quantum_viz.graph:
			var local_pos = quantum_viz.graph.get_local_mouse_position()
			var clicked_node = quantum_viz.graph.get_node_at_position(local_pos)

			if clicked_node:
				print("   ✅ FOUND BUBBLE at grid %s!" % clicked_node.grid_position)
				# Manually call the tap handler
				_on_quantum_node_clicked(clicked_node.grid_position, 1)
			else:
				print("   No bubble at click position")
```

This completely bypasses the normal input system and manually checks for bubbles.

## Files Modified

1. **UI/FarmView.gd**
   - Line 60: Changed CanvasLayer to layer=1
   - Line 65: Added set_process_unhandled_input(true)
   - Line 257-265: Added _unhandled_input() method to forward input

2. **Core/Visualization/QuantumForceGraph.gd**
   - Line 122: Changed to set_process_unhandled_input(true)
   - Line 319: Changed _input() to _unhandled_input()
   - Lines 323-327: Added debug output

3. **UI/FarmUI.tscn**
   - Line 44: Added mouse_filter=2 to MainContainer (already done)

## What to Test

1. Click anywhere and check console for "_unhandled_input" messages
2. If messages appear, click directly on a bubble
3. Check if node detection works (should print "Clicked node: ...")
4. Report what you see!

**The test scene works, so touch controls CAN work - just need to fix input routing in main game!**
