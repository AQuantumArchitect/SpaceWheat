# Contextual Bubble Clicks + Plot-Based Entanglement

## Summary

Implemented two major gameplay improvements:

1. **Contextual Bubble Clicks (Hybrid Option 7)**: Quantum bubbles now do "the next obvious thing" in the plant → measure → harvest progression
2. **Plot-Based Entanglement Infrastructure**: Entanglement is now plot-level infrastructure that persists across harvest/replant cycles

---

## Feature 1: Contextual Bubble Clicks

### Concept

Restore the satisfying "bubble popping" mechanic where clicking bubbles follows a natural progression, while keeping the tool system for deliberate plot tile actions.

### Implementation

**Two Click Contexts**:
1. **Quantum Bubble Clicks** (center visualization) → Contextual actions
2. **Plot Tile Clicks** (farm squares) → Explicit tool application

### State Machine for Bubble Clicks

```gdscript
When clicking a quantum bubble:
  if plot.is_empty():
    → Plant (using currently selected plant type: wheat/tomato/mushroom)
  elif not plot.has_been_measured:
    → Measure
  elif plot.is_mature:
    → Harvest
  else:
    → Show "not ready" message (X% grown)
```

### Files Modified

**UI/FarmView.gd**:
- `_on_quantum_node_clicked()` → Now calls `_handle_bubble_click()` (contextual)
- `_on_tile_clicked()` → Still calls `_handle_plot_click()` (tool-based)
- NEW: `_handle_bubble_click()` - Implements state machine for contextual actions

### Interaction Examples

```
SCENARIO 1: Bubble Popping Wheat Farm
  1. Select Wheat tool (P key)
  2. Click bubble on empty plot → Plants wheat
  3. Wait for growth
  4. Click bubble again → Measures
  5. Wait for maturity
  6. Click bubble again → Harvests

SCENARIO 2: Mixed Farming
  1. Select Mushroom tool (U key)
  2. Click some bubbles → Plants mushrooms
  3. Select Wheat tool (P key)
  4. Click other bubbles → Plants wheat
  5. Click any mature bubbles → Auto-measures → Auto-harvests

SCENARIO 3: Deliberate Plot Actions
  1. Select Entangle tool (E key)
  2. Click plot TILES (not bubbles) → Explicit entangle mode
  3. Build Mill/Market → Click plot tiles
```

### Benefits

✅ **Satisfying bubble popping**: Click, click, click for measure → harvest
✅ **Tool selection still matters**: Determines what gets planted
✅ **Two distinct interaction zones**: Bubbles = quick, Tiles = deliberate
✅ **Keyboard-friendly**: P key + spam bubbles for wheat farm
✅ **Clear mental model**: "Bubbles advance crops, tiles apply tools"

---

## Feature 2: Plot-Based Entanglement Infrastructure

### Old System (Instance-Based)

```
Entangle Plot A ↔ Plot B:
  - Creates quantum entanglement between CURRENT crops
  - Harvest → Entanglement is destroyed
  - Replant → Must re-entangle manually
```

### New System (Infrastructure-Based)

```
Entangle Plot A ↔ Plot B:
  - Installs "entanglement gate" on PLOTS (persistent)
  - Harvest → Infrastructure remains
  - Replant → Quantum states AUTO-ENTANGLE
  - Feels like building gates/infrastructure
```

### Conceptual Model

Think of entanglement as **quantum gates** built into the farm:
- You build the gates once (entangle empty or planted plots)
- Gates remember their connections
- Anything planted in linked plots automatically entangles
- Like plumbing or wiring in a building

### Implementation

**WheatPlot.gd** (NEW):
```gdscript
# PERSISTENT plot-level entanglement infrastructure
var plot_infrastructure_entanglements: Array[Vector2i] = []

# TEMPORARY quantum state entanglement (cleared on harvest)
var entangled_plots: Dictionary = {}  # plot_id -> strength
```

**FarmGrid.gd** (MODIFIED):

1. **`create_entanglement(pos_a, pos_b)`**:
   - Sets up plot infrastructure FIRST (works even if not planted)
   - If both planted → Also creates quantum entanglement
   - If only one/neither planted → Infrastructure ready, quantum pending

2. **NEW: `_auto_entangle_from_infrastructure(position)`**:
   - Called automatically when planting
   - Checks plot's infrastructure links
   - Auto-entangles quantum states with planted partners

3. **`plant_wheat()`, `plant_tomato()`, `plant_mushroom()`**:
   - All call `_auto_entangle_from_infrastructure()` after planting

4. **NEW: `_create_quantum_entanglement()`** (internal helper):
   - Separated quantum state logic from infrastructure logic
   - Handles Bell states, density matrices, clusters

### Workflow Examples

```
EXAMPLE 1: Pre-build Infrastructure
  1. Select Entangle tool
  2. Click plot (0,0) → click plot (1,0)
     → "🏗️ Plot infrastructure: (0,0) ↔ (1,0) (entanglement gate installed)"
     → "Infrastructure ready. Quantum entanglement will auto-activate when both plots are planted."
  3. Plant wheat in (0,0)
     → "✅ Planted wheat"
  4. Plant wheat in (1,0)
     → "✅ Planted wheat"
     → "⚡ Auto-entangled (0,0) ↔ (1,0) (infrastructure activated)"

EXAMPLE 2: Entangle After Planting
  1. Plant wheat in (2,2) and (3,3)
  2. Select Entangle tool
  3. Click (2,2) → click (3,3)
     → "🏗️ Plot infrastructure: (2,2) ↔ (3,3) (entanglement gate installed)"
     → "🔗 Created Bell pair..." (quantum entanglement happens immediately)

EXAMPLE 3: Persistent Across Harvest
  1. Have entangled plots (0,0) ↔ (1,0) with mature wheat
  2. Harvest both plots
     → Quantum entanglement destroyed (normal behavior)
     → But plot infrastructure REMAINS
  3. Replant wheat in (0,0)
     → Just plants, no entanglement yet
  4. Replant wheat in (1,0)
     → "⚡ Auto-entangled (0,0) ↔ (1,0) (infrastructure activated)"
     → No manual re-entanglement needed!
```

### Benefits

✅ **Feels like infrastructure**: Build gates/wiring once, use forever
✅ **Less tedious**: Don't re-entangle after every harvest
✅ **Strategic planning**: Pre-build entanglement networks before planting
✅ **Still has quantum mechanics**: Measurement still breaks quantum entanglement, but infrastructure persists
✅ **Backwards compatible**: Existing entanglement code still works

---

## Files Modified

### UI/FarmView.gd
- Modified `_on_quantum_node_clicked()` to call contextual handler
- Added `_handle_bubble_click()` for bubble progression logic
- Updated `_handle_plot_click()` comment to clarify it's for plot tiles

### Core/GameMechanics/WheatPlot.gd
- Added `plot_infrastructure_entanglements: Array[Vector2i]` for persistent gates
- Kept `entangled_plots: Dictionary` for temporary quantum entanglement

### Core/GameMechanics/FarmGrid.gd
- Modified `create_entanglement()` to set up infrastructure first
- Added `_auto_entangle_from_infrastructure()` for auto-activation
- Added `_create_quantum_entanglement()` internal helper
- Modified `plant_wheat()`, `plant_tomato()`, `plant_mushroom()` to call auto-entangle

---

## Testing

### Basic Tests

**Bubble Clicks**:
- [ ] Click empty bubble with Wheat selected → Plants wheat
- [ ] Click unmeasured bubble → Measures
- [ ] Click measured+mature bubble → Harvests
- [ ] Click measured+immature bubble → Shows "not ready" message
- [ ] Plot tile clicks still work with tool system

**Plot Entanglement**:
- [ ] Entangle two empty plots → Infrastructure message, no quantum yet
- [ ] Plant in one → No auto-entangle
- [ ] Plant in other → Auto-entangles!
- [ ] Harvest both → Quantum gone, infrastructure remains
- [ ] Replant both → Auto-entangles again

### Advanced Tests

**Bubble Progression**:
- [ ] Select Mushroom, click 5 bubbles → All plant mushrooms
- [ ] Switch to Wheat, click 5 bubbles → All plant wheat
- [ ] Let grow, spam click bubbles → Auto-measures then auto-harvests

**Infrastructure Persistence**:
- [ ] Build 3-plot entanglement chain: A↔B, B↔C
- [ ] Plant all three → All auto-entangle (B in cluster with A and C)
- [ ] Harvest → Infrastructure persists
- [ ] Replant → All auto-entangle again

**Mixed Interactions**:
- [ ] Bubble click to plant → Tile click with Entangle → Bubble click to measure/harvest

---

## Design Philosophy

### Bubble Clicks: "Quick Progression"
- Natural workflow: plant → measure → harvest
- Muscle memory friendly
- Keyboard + mouse combo: P key + spam click

### Plot Tiles: "Deliberate Building"
- Strategic decisions
- Infrastructure placement
- Entanglement network design

### Separation of Concerns
- **Bubbles (quantum visualization)** = Fast iteration on crops
- **Tiles (farm plots)** = Deliberate strategy and building

This creates two interaction "zones" with different mental models, but both feel natural for their purpose.

---

## Known Limitations

1. **Bubble hitboxes**: May need to increase quantum node radius for easier clicking
2. **Visual feedback**: Could add glow/color hints on bubble hover (show next action)
3. **Infrastructure visualization**: Could show persistent entanglement lines differently from quantum entanglement
4. **Tutorial needed**: New players need to learn the two interaction zones

---

## Future Enhancements

**Bubble Interaction**:
- [ ] Add tooltip on hover: "Click to MEASURE" / "Click to HARVEST"
- [ ] Color-code bubbles: Green (unmeasured), Gold (ready to harvest)
- [ ] Sound effects: Different sounds for measure vs harvest

**Infrastructure Visualization**:
- [ ] Dashed lines for infrastructure entanglement
- [ ] Solid lines for active quantum entanglement
- [ ] Glow effect on plots with infrastructure

**Smart Tools**:
- [ ] "Smart Plant" tool: Automatically plants best crop type for entanglement network
- [ ] "Harvest All Mature" hotkey
