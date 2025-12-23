# Force-Directed Graph Responsiveness Analysis

**Date:** 2025-12-14
**Issue:** "the force directed graph feels very unresponsive"
**Status:** Analysis complete, tuning recommendations provided

---

## Current Force Parameters

**File:** `Core/Visualization/QuantumForceGraph.gd`

```gdscript
const TETHER_SPRING_CONSTANT = 0.015  # Very weak - let nodes spread far
const REPULSION_STRENGTH = 7000.0     # Strong - push nodes apart vigorously
const ENTANGLE_ATTRACTION = 3.0       # Very strong - pull entangled partners together
const DAMPING = 0.75                  # Less friction - more dynamic movement
const MIN_DISTANCE = 5.0              # Minimum distance between nodes
const IDEAL_ENTANGLEMENT_DISTANCE = 60.0  # Target distance for entangled nodes
```

---

## Force Analysis

### 1. Repulsion Force (Inverse Square Law)

**Formula:**
```gdscript
F_repulsion = REPULSION_STRENGTH / (distance²)
```

**Example values:**

| Distance (px) | Force Magnitude |
|--------------|----------------|
| 50 | 7000 / 2500 = **2.8** |
| 100 | 7000 / 10000 = **0.7** |
| 200 | 7000 / 40000 = **0.175** |
| 300 | 7000 / 90000 = **0.078** |

**Analysis:** Repulsion is very strong at close range, drops off rapidly with distance.

---

### 2. Entanglement Attraction (Hooke's Law)

**Formula:**
```gdscript
displacement = distance - IDEAL_ENTANGLEMENT_DISTANCE  # e.g., distance - 60
F_attraction = displacement * ENTANGLE_ATTRACTION
```

**Example values:**

| Distance (px) | Displacement | Force Magnitude |
|--------------|-------------|----------------|
| 50 | -10 | -10 * 3.0 = **-30** (pull together) |
| 60 | 0 | 0 * 3.0 = **0** (equilibrium) |
| 100 | 40 | 40 * 3.0 = **120** (pull together) |
| 200 | 140 | 140 * 3.0 = **420** (pull together) |

**Analysis:** Attraction scales linearly with displacement from ideal distance. Very strong when nodes are far apart!

---

### 3. Force Balance Comparison

At various distances between two entangled nodes:

| Distance | Repulsion | Attraction | Net Force | Winner |
|----------|-----------|------------|-----------|--------|
| 50 px | 2.8 | -30 | **-27.2** | **Attraction dominates** ✅ |
| 60 px | 1.94 | 0 | **1.94** | Repulsion (equilibrium nearby) |
| 100 px | 0.7 | 120 | **119.3** | **Attraction dominates** ✅ |
| 200 px | 0.175 | 420 | **419.8** | **Attraction dominates** ✅ |

**Conclusion:** Entanglement attraction is MUCH stronger than repulsion at most distances! This is correct behavior - entangled nodes should cluster together. ✅

---

## Potential Issues Identified

### Issue 1: High Damping ⚠️

**Current value:** `DAMPING = 0.75`

**What this means:**
Every frame, velocity is multiplied by 0.75:
- Frame 1: v = 100
- Frame 2: v = 75
- Frame 3: v = 56.25
- Frame 4: v = 42.19

At 60 FPS, velocity drops to 0.001% of original in just **0.5 seconds**!

**Impact on responsiveness:**
- Nodes slow down very quickly
- Graph feels "sluggish" or "sticky"
- Forces need to be very large to produce visible movement
- Animation feels "dead" or "unresponsive"

**Recommendation:** Reduce damping to **0.85-0.95** for more lively movement

---

### Issue 2: Tether Spring Too Weak ⚠️

**Current value:** `TETHER_SPRING_CONSTANT = 0.015`

**Analysis:**
At distance = 100 pixels from anchor:
- F_tether = 100 * 0.015 = **1.5**

This is comparable to repulsion (0.7 at 100px distance) but MUCH weaker than entanglement attraction (120 at 100px distance).

**Impact:**
- Nodes can drift very far from their classical anchors
- Graph might feel "untethered" from the farm grid
- Hard to visually correlate quantum nodes with farm plots

**Recommendation:** Increase to **0.05-0.1** for better visual correlation

---

### Issue 3: No Interaction Code Found ⚠️

**Observation:** No mouse/touch input handling found in QuantumForceGraph.gd or QuantumNode.gd

**Possible interpretations of "unresponsive":**
1. Graph doesn't respond to **user input** (clicking/dragging nodes)
2. Graph doesn't respond to **entanglement changes** (force updates)
3. Graph feels **sluggish** (damping too high)

**Recommendation:** If user interaction is desired, add:
- Mouse detection for nodes
- Drag-and-drop functionality
- Click to inspect quantum state

---

## Physics Implementation ✅

**File:** `Core/Visualization/QuantumNode.gd`

```gdscript
func apply_force(force: Vector2, delta: float):
    velocity += force * delta  # F = ma, assuming m=1

func apply_damping(damping_factor: float):
    velocity *= damping_factor  # v' = v * damping

func update_position(delta: float):
    position += velocity * delta  # Euler integration
```

**Analysis:** Physics is correct! Standard Verlet-style integration. ✅

---

## Recommended Tuning

### Option 1: More Responsive (Recommended)

```gdscript
const TETHER_SPRING_CONSTANT = 0.08   # Stronger tether (was 0.015)
const REPULSION_STRENGTH = 7000.0      # Keep same
const ENTANGLE_ATTRACTION = 3.0        # Keep same
const DAMPING = 0.90                   # Less damping (was 0.75)
```

**Effect:**
- Nodes move more dynamically
- Better visual correlation with farm grid
- More "alive" feeling

---

### Option 2: Very Lively (For Testing)

```gdscript
const TETHER_SPRING_CONSTANT = 0.05   # Moderate tether
const REPULSION_STRENGTH = 7000.0      # Keep same
const ENTANGLE_ATTRACTION = 4.0        # Stronger attraction (was 3.0)
const DAMPING = 0.95                   # Minimal damping (was 0.75)
```

**Effect:**
- Highly dynamic, bouncy movement
- Entangled clusters very tight
- May feel "too energetic" for some users

---

### Option 3: Balanced (Conservative)

```gdscript
const TETHER_SPRING_CONSTANT = 0.03   # Slightly stronger (was 0.015)
const REPULSION_STRENGTH = 7000.0      # Keep same
const ENTANGLE_ATTRACTION = 3.0        # Keep same
const DAMPING = 0.85                   # Moderate damping (was 0.75)
```

**Effect:**
- Small improvement in responsiveness
- Safer change (less risk of instability)
- Good starting point for tuning

---

## Testing Recommendations

### Test 1: Visual Responsiveness
1. Plant multiple wheat plots
2. Create entanglements between plots
3. Observe quantum node clustering
4. **Expected:** Entangled nodes should visibly cluster together within 1-2 seconds

### Test 2: Damping Feel
1. Create a single entanglement
2. Observe how quickly nodes settle into equilibrium
3. **Current:** Should settle very quickly (high damping)
4. **After tuning:** Should have more "bounce" and gradual settling

### Test 3: Tether Strength
1. Create entanglements that pull nodes far from anchors
2. Observe maximum drift distance
3. **Expected:** Nodes should stay within ~100-200px of anchors

---

## Other Potential Issues

### Graphics Issue: Entanglement Bonds Not Showing

**Note:** This is a separate issue from force graph responsiveness.

**From test output:**
```
Entanglement data verification:
  Plot (0, 0) (id:plot_0_0): 0 connections
  Plot (1, 0) (id:plot_1_0): 0 connections
```

**Reason:** Test measured/collapsed the cluster, so no entanglements remained.

**To verify bonds are rendering:**
1. Create entanglements in actual game (not headless test)
2. Check that `_draw_entanglement_lines()` is called
3. Enable `DEBUG_MODE = true` in QuantumForceGraph.gd
4. Check console for draw calls

---

## Summary

**Primary Issue:** High damping (0.75) makes graph feel sluggish/unresponsive

**Recommended Fix:**
1. Reduce DAMPING from **0.75** → **0.90** (20% less damping)
2. Increase TETHER_SPRING_CONSTANT from **0.015** → **0.08** (5x stronger tether)

**Expected Result:**
- More dynamic, responsive movement
- Nodes react more visibly to force changes
- Better visual "liveliness"

**Force balance is correct:** Entanglement attraction properly dominates at most distances ✅

**Next Steps:**
1. Apply recommended tuning
2. Test in actual game scene (not headless test)
3. Iterate based on feel

---

**Status:** Analysis complete, awaiting tuning implementation
