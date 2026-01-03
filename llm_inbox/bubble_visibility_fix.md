# Bubble Visibility Fix - Multiple Issues Resolved

## Status: SHOULD BE VISIBLE NOW ✅

Fixed 3 critical issues preventing bubbles from appearing:

---

## Issue #1: Bubbles Not Added to Graph's Render List

**Problem**: Created bubbles were stored in `basis_bubbles` dictionary but NOT added to `graph.quantum_nodes` array

**Where**: `BathQuantumVisualizationController.request_plot_bubble()`

**Fix Applied** (lines 232-233, 238):
```gdscript
graph.quantum_nodes.append(north_bubble)  # Add to graph for rendering!
graph.quantum_nodes_by_grid_pos[grid_pos] = north_bubble  # Index by grid pos
```

**Result**: Bubbles now appear in graph's node list
- Debug confirms: "Graph has 12 quantum_nodes ready to render"

---

## Issue #2: Graph Not Redrawing After Bubble Creation

**Problem**: Adding nodes to `graph.quantum_nodes` doesn't automatically trigger a redraw

**Where**: `BathQuantumVisualizationController.request_plot_bubble()`

**Fix Applied** (line 243-244):
```gdscript
# Trigger graph redraw to show new bubbles
if north_bubble or south_bubble:
    graph.queue_redraw()
```

**Result**: Graph now redraws when bubbles are added
- Debug confirms: "Frame 30: 12 nodes drawn, 12 planted"

---

## Issue #3: CanvasLayer Rendering Behind UI

**Problem**: CanvasLayer layer=0 renders behind Control children (Background ColorRect)

**Where**: `Tests/bubble_touch_test.gd` line 43

**Fix Applied**:
```gdscript
viz_layer.layer = 1  # Render above UI layer (layer 0)
```

**Why**: CanvasLayers render in order - higher layer numbers appear on top
- Background ColorRect is in layer 0 (default for Control children)
- Quantum bubbles now in layer 1 (above background)

---

## Debug Data Confirms Rendering

**Bubble properties from QuantumForceGraph debug output**:
```
Grid (0, 0): pos=(612.0, 536.3) r=40 opacity=0.50 scale=1.00 [PLANTED]
Grid (0, 0): pos=(672.7, 537.0) r=40 opacity=0.50 scale=1.00 [PLANTED]
Grid (1, 0): pos=(764.7, 390.7) r=40 opacity=0.50 scale=1.00 [PLANTED]
...
```

**All values correct**:
- ✅ Positions on-screen (viewport is 1280×720)
- ✅ Opacity 0.50 (visible)
- ✅ Scale 1.00 (full size)
- ✅ Radius 40px (good bubble size)
- ✅ Planted status: true

**Rendering confirmed**:
- ✅ 12 nodes drawn per frame
- ✅ 12 plots planted
- ✅ All have quantum_state=true

---

## What You Should See Now

**Run**: `godot Tests/bubble_touch_test.tscn`

**Expected visual**:
1. Dark background (Color(0.1, 0.1, 0.15))
2. Info label at top with instructions
3. **Two biome ovals**:
   - BioticFlux (olive/yellow, bottom center) with 4 pairs of bubbles (🌾/🍄)
   - Market (brown, left side) with 2 pairs of bubbles (💰/🐂)
4. **12 emoji bubbles total** orbiting in their ovals
5. Bubbles should have:
   - Dual emojis (north/south superposition)
   - 50% opacity for each emoji
   - Pulsing glow effect
   - Size radius ~40px

**If STILL not visible**, possible remaining issues:
1. Background color might be too dark to see dark bubbles
2. Emoji rendering might be failing (font issue?)
3. CanvasLayer might have other visibility issues

---

## Files Modified

### Core/Visualization/BathQuantumVisualizationController.gd
- Line 232-233: Add bubbles to `graph.quantum_nodes`
- Line 238: Add bubbles to `graph.quantum_nodes`
- Line 243-244: Call `graph.queue_redraw()` after adding bubbles

### Tests/bubble_touch_test.gd
- Line 43: Changed CanvasLayer from layer=0 to layer=1
- Line 144-146: Added debug output to verify graph has nodes

---

## Next Debugging Steps (if still not visible)

1. **Check background opacity**: Try making Background ColorRect semi-transparent
   ```gdscript
   # In bubble_touch_test.tscn
   color = Color(0.1, 0.1, 0.15, 0.5)  # Add alpha channel
   ```

2. **Check if emojis render**: Add simple emoji label to verify font works
   ```gdscript
   var test_label = Label.new()
   test_label.text = "🌾 Test Emoji"
   add_child(test_label)
   ```

3. **Check QuantumForceGraph visibility**: Add debug rect
   ```gdscript
   # In QuantumForceGraph._draw()
   draw_rect(Rect2(0, 0, 100, 100), Color.RED)  # Top-left red square
   ```

4. **Try different CanvasLayer layer**: Change to layer=10 to ensure it's on top

---

## Architecture Notes

**Why this was complex**:
1. BathQuantumViz creates bubbles but doesn't own the rendering
2. QuantumForceGraph does the rendering but doesn't create bubbles
3. Bubbles must be in BOTH `basis_bubbles` (for state tracking) AND `graph.quantum_nodes` (for rendering)
4. Graph won't redraw automatically - needs explicit `queue_redraw()` calls
5. CanvasLayer rendering order matters for visibility

**Proper data flow**:
```
request_plot_bubble()
 ├─ _create_plot_bubble() → Returns QuantumNode
 ├─ Add to basis_bubbles[biome] (state tracking)
 ├─ Add to graph.quantum_nodes (rendering)
 ├─ Add to graph.quantum_nodes_by_grid_pos (touch lookup)
 └─ graph.queue_redraw() (trigger render)
      └─ QuantumForceGraph._draw()
           └─ _draw_quantum_nodes()
                └─ _draw_quantum_bubble(node)
                     └─ Draws emoji at node.position
```
