# Touch Control Test - Ready for Interactive Testing

## Status: ✅ BUBBLES APPEARING

The test scene is now working! Bubbles are being created with correct grid positions.

## What Was Fixed

### Issue 1: Wrong Emoji Selection
- **Problem**: Test was requesting emojis not in biome baths (👥, 📉)
- **Fix**: Changed to correct emojis:
  - BioticFlux: 🌾/🍄 (wheat/mushroom)
  - Market: 💰/🐂 (money/bull)

### Issue 2: Wrong Plot Type
- **Problem**: Using `BasePlot` but `QuantumNode` expects `FarmPlot`
- **Fix**: Changed test to create `FarmPlot` instances
- **Why**: `FarmPlot extends BasePlot` - it's the player-interactive version

## Current Test Configuration

**6 plots created**:
- **BioticFlux** (4 plots): grid (0,0), (1,0), (2,0), (3,0)
  - Qubits: 🌾/🍄 in superposition (theta=π/2)
- **Market** (2 plots): grid (4,0), (5,0)
  - Qubits: 💰/🐂 in superposition (theta=π/2)

**12 bubbles total** (2 per plot - north/south emoji)

## Debug Output Confirms Success

```
   🔵 Created north bubble (🌾) at grid (0, 0)
   🔵 Created south bubble (🍄) at grid (0, 0)
   🌾 Planted plot (0, 0) (BioticFlux)
   ... (repeated for all 6 plots)
   ✅ Planted 6 test plots
```

## Touch Controls to Test

**Connected signals**:
- ✅ `node_clicked` → `_on_bubble_tapped(grid_pos, button)`
- ✅ `node_swiped_to` → `_on_bubble_swiped(from_pos, to_pos)`

**Expected behavior**:
1. **TAP unmeasured bubble** → Calls `plot.measure()`
   - Should see: Cyan glow appear on bubble
   - Debug output: "🔬 Measured: (x,y) → [emoji]"

2. **TAP measured bubble** → Calls `plot.harvest()`
   - Should see: Bubble disappears
   - Debug output: "🌾 Harvested: (x,y) → [emoji] (energy: X)"

3. **SWIPE between bubbles** → Creates entanglement
   - Both plots set to Φ+ Bell state (theta=π/2, phi=0)
   - Debug output: "✅ Entangled (x1,y1) ↔ (x2,y2)"

**Keyboard shortcuts**:
- ESC = quit
- R = reload scene
- SPACE = show test state

## Next Steps

1. **Visual verification**: Check if bubbles are visible on screen
2. **Tap test**: Click a bubble, verify cyan glow appears
3. **Harvest test**: Click measured bubble, verify it disappears
4. **Swipe test**: Drag between bubbles to create entanglement

## Files Modified

- `Tests/bubble_touch_test.gd` - Changed `BasePlot` → `FarmPlot`
  - Line 10: Import FarmPlot instead of BasePlot
  - Line 103: Create FarmPlot instances
  - Line 128: Create FarmPlot instances

## Architecture Notes

**Plot-Driven Bubble System** (the "proper fix"):
- `request_plot_bubble(biome, grid_pos, plot)` - creates bubbles for a plot
- Each bubble knows its `grid_position` from the plot
- Touch handlers can look up plot by grid_pos
- Bubbles test full measure/harvest pipeline

**Why FarmPlot?**:
- `QuantumNode.new()` requires `FarmPlot` type
- `FarmPlot extends BasePlot` - adds player interaction features
- Real game uses FarmPlot for all player-interactive plots
