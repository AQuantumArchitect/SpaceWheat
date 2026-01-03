# Touch Control Fixes Applied ✅

## Issues Fixed

### Issue 1: Tapping Not Working ✅

**Problem**: MainContainer VBoxContainer was blocking mouse input to bubbles below

**File**: `UI/FarmUI.tscn` line 44

**Fix**: Added `mouse_filter = 2` (MOUSE_FILTER_IGNORE)

**Result**: Mouse events now pass through to QuantumForceGraph bubbles

### Issue 2: Bubbles Multiplying on Re-plant ✅

**Problem**: Old bubbles weren't removed from `quantum_nodes` array when harvested
- Plant plot (0,0): 1 bubble created
- Harvest: Bubble becomes invisible but stays in array
- Plant again: NEW bubble created, old one still there
- Result: 2 bubbles, 4 bubbles, 6 bubbles...

**Files Fixed**:

1. **BathQuantumVisualizationController.gd** (lines 147-151)
   - Added connection to `plot_harvested` signal
   - Automatically removes bubbles when plots are harvested

2. **BathQuantumVisualizationController.gd** (lines 197-228)
   - Added `_on_plot_harvested()` handler
   - Removes bubble from:
     - `graph.quantum_nodes` array
     - `graph.quantum_nodes_by_grid_pos` index
     - `basis_bubbles[biome_name]` array

3. **BathQuantumVisualizationController.gd** (lines 221-235)
   - Added defensive cleanup in `request_plot_bubble()`
   - Removes old bubble BEFORE creating new one
   - Prevents duplicates even if harvest signal missed

**Result**: One bubble per plot, always

## Test Results

```
✅ Touch: Swipe-to-entangle connected
✅ Touch: Tap-to-measure connected
✅ No parse errors
✅ Main game boots successfully
```

## How Touch Controls Work Now

### Tap Bubble
1. **Unmeasured plot**: Measure → cyan glow appears
2. **Measured plot**: Harvest → bubble disappears
3. **Empty plot**: Plant wheat

### Swipe Between Bubbles
- Creates entanglement (Φ+ Bell state)
- Both plots become quantum-correlated

## Bubble Lifecycle

```
PLANT → request_plot_bubble()
   ├─ Remove old bubble at grid_pos (if exists)
   ├─ Create new QuantumNode
   ├─ Add to graph.quantum_nodes
   ├─ Index in quantum_nodes_by_grid_pos
   └─ Trigger redraw

HARVEST → _on_plot_harvested()
   ├─ Find bubble by grid_pos
   ├─ Remove from graph.quantum_nodes
   ├─ Remove from quantum_nodes_by_grid_pos
   ├─ Remove from basis_bubbles
   └─ Trigger redraw (bubble disappears)
```

## Files Modified

1. **UI/FarmUI.tscn**
   - Line 44: Added `mouse_filter = 2` to MainContainer

2. **Core/Visualization/BathQuantumVisualizationController.gd**
   - Lines 147-151: Connect to plot_harvested signal
   - Lines 197-228: New `_on_plot_harvested()` handler
   - Lines 221-235: Defensive bubble cleanup in request_plot_bubble()

## What To Test

1. **Plant a wheat plot** → Should see ONE bubble appear
2. **Tap the bubble** → Should see cyan glow (measured)
3. **Tap again** → Bubble should disappear (harvested)
4. **Plant same plot again** → Should see ONE new bubble (not 2!)
5. **Swipe between two bubbles** → Creates entanglement

Try planting, harvesting, and re-planting multiple times - bubble count should stay correct!
