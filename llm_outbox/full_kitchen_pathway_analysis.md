# Full Kitchen Pathway - Complete Analysis

## 🍳 The Full Kitchen Production Chain

The complete gameplay loop that has never been fully tested end-to-end:

```
1. Plant 🌾 (Wheat)
   ↓ (Grow for ~2-5 seconds)
2. Entangle multiple wheat plots (Bell pair)
   ↓ (Quantum evolution)
3. Measure plots (Projective measurement)
   ↓ (Collapse state)
4. Harvest wheat → Get 🌾 resources
   ↓
5. Mill wheat 🌾 → Flour 💨
   ↓
6. Sell flour 💨 → Credits 💰
   ↓
7. (Optional) Kitchen 🍳: Flour → Bread 🍞
```

---

## ✅ What Works (COMPLETE)

### 1. Plant Wheat
- **Method**: `farm.build(Vector2i, "wheat")`
- **Status**: ✅ WORKING
- **Code**: `Farm.gd:548-553` → `FarmGrid.plant()`
- **Notes**: Creates wheat plot with quantum state in biome

### 2. Grow (Quantum Evolution)
- **Method**: Automatic via `FarmGrid._process(delta)`
- **Status**: ✅ WORKING
- **Code**: `FarmGrid._process()` calls biome evolution
- **Notes**: Lindblad evolution handles decoherence

### 3. Entangle Plots
- **Method**: `farm.entangle_plots(pos_a, pos_b)`
- **Status**: ✅ WORKING
- **Code**: `Farm.gd:683-710`
- **Notes**: Creates Bell pairs with entanglement_graph

### 4. Measure Plots
- **Method**: `farm.measure_plot(pos)`
- **Status**: ✅ WORKING
- **Code**: `Farm.gd:711-748`
- **Notes**: Projective measurement with collapse (Phase 2)

### 5. Harvest Wheat
- **Method**: `farm.harvest_plot(pos)`
- **Status**: ✅ WORKING
- **Code**: `Farm.gd:749-812`
- **Result**: Returns yield as 🌾 (wheat credits)
- **Notes**: Stores in `farm.economy.emoji_credits["🌾"]`

---

## ❌ What's BROKEN (NOT WORKING)

### Issue 1: Mill Process Broken

**Problem**: QuantumMill tries to access `quantum_state` which doesn't exist in Model B

**Location**: `QuantumMill.gd:51-87` - `perform_quantum_measurement()`

**Broken Code**:
```gdscript
for plot in entangled_wheat:
    if not plot or not plot.quantum_state:  # ← BROKEN: quantum_state doesn't exist!
        continue
    plot.quantum_state.couple_to_ancilla(coupling_strength, measurement_interval)
    var outcome = plot.quantum_state.measure_ancilla()
    if outcome == "flour":
        plot.quantum_state.theta = PI  # ← BROKEN: no theta property
```

**Why It's Broken**:
- Model B refactor moved quantum state to BiomeBase.quantum_computer
- Plots now only have `register_id` and basis labels
- QuantumMill still references old Model A architecture

**Missing**: Model B adapter for QuantumMill

### Issue 2: Mill Processing Not Triggered

**Problem**: Mill building is created but never actually processes wheat

**Location**: `FarmGrid.place_mill()` only creates QuantumMill object, never calls processing

**Current Code**:
```gdscript
func place_mill(position: Vector2i) -> bool:
    # ... creates QuantumMill ...
    mill.set_entangled_wheat(adjacent_wheat)
    quantum_mills[position] = mill
    # → But process_mill() is NEVER called!
```

**Missing**:
- No game loop integration for mill processing
- FarmGrid._process() calls `plot.process_mill()` but QuantumMill doesn't expose this
- No API to actually trigger wheat→flour conversion

### Issue 3: No Market Sale Implementation

**Problem**: Market building exists but has no logic to sell flour

**Location**: `FarmGrid.place_market()` - line 799

**Current Code**:
```gdscript
func place_market(position: Vector2i) -> bool:
    plot.plot_type = FarmPlot.PlotType.MARKET
    plot.is_planted = true
    # → That's it. No sale logic.
```

**What Should Exist**:
```gdscript
# Missing process_market() method that would:
# 1. Query farm.economy.get_resource("💨") for flour
# 2. Call farm.economy.sell_flour_at_market(flour_amount)
# 3. Convert flour → credits
```

**Missing**:
- No `process_market()` method
- No integration with FarmEconomy.sell_flour_at_market()
- No UI to trigger sale

### Issue 4: Kitchen Not Implemented

**Problem**: Kitchen building exists but does nothing

**Location**: `FarmGrid.place_kitchen()` - line 816

**Current Code**:
```gdscript
func place_kitchen(position: Vector2i) -> bool:
    plot.plot_type = FarmPlot.PlotType.KITCHEN
    plot.is_planted = true
    # → No logic at all
```

**Missing Everything**:
- No flour→bread conversion logic
- No FarmEconomy method for this (would need to add)
- No process_kitchen() method

---

## 📊 What Exists But Isn't Connected

### FarmEconomy Has The Logic!

**Process Wheat to Flour** ✅ Already Implemented:
```gdscript
FarmEconomy.process_wheat_to_flour(wheat_amount) → Dictionary
# 10 wheat → 8 flour + 40 credits
# Location: FarmEconomy.gd:174-206
```

**Sell Flour for Credits** ✅ Already Implemented:
```gdscript
FarmEconomy.sell_flour_at_market(flour_amount) → Dictionary
# 1 flour → 100 credits (80 to farmer, 20 market cut)
# Location: FarmEconomy.gd:209-241
```

**Problem**: These methods exist but are NEVER CALLED from anywhere!

---

## 🔧 What Needs to Be Implemented

### Priority 1: Fix Mill Processing (BLOCKING)

**Task**: Adapt QuantumMill to Model B architecture

**Solution**:
```gdscript
# In QuantumMill.perform_quantum_measurement() - REWRITE to use Model B:
for plot in entangled_wheat:
    if not plot:
        continue

    # Model B: Get probability via biome's quantum_computer
    var biome = plot.get_parent_biome()  # Need this method
    if not biome or not biome.quantum_computer:
        continue

    # Get purity/probability for this plot's register
    var register_id = plot.get_register_id()  # Need this method
    var purity = biome.quantum_computer.get_marginal_purity(...)

    # Quantum measurement outcome based on purity
    var outcome = "flour" if randf() < purity else "nothing"

    if outcome == "flour":
        total_flour += 1
```

**Files to Modify**:
- `Core/GameMechanics/QuantumMill.gd` - rewrite measurement logic

### Priority 2: Wire Mill to Economy (BLOCKING)

**Task**: Automate wheat→flour conversion

**Solution 1** - Integrate into game loop:
```gdscript
# In FarmGrid._process(delta) - add mill processing:
for position in quantum_mills.keys():
    var mill = quantum_mills[position]
    if mill:
        mill.process(delta)  # Let mill accumulate outcomes

        # Periodically flush accumulated flour to economy
        var accumulated_flour = mill.get_and_reset_accumulated_flour()
        if accumulated_flour > 0:
            farm.economy.add_resource("💨", accumulated_flour * QUANTUM_TO_CREDITS, "mill")
```

**Solution 2** - Add manual API:
```gdscript
# Add to Farm.gd:
func process_mill_batch(position: Vector2i, wheat_amount: int = 10) -> Dictionary:
    # Player decides to mill N wheat
    return economy.process_wheat_to_flour(wheat_amount)
```

**Files to Modify**:
- `Core/GameMechanics/FarmGrid.gd` - add mill processing integration
- `Core/GameMechanics/QuantumMill.gd` - add accumulation/flushing
- `Core/Farm.gd` - add mill automation or manual API

### Priority 3: Implement Market Sale (BLOCKING)

**Task**: Create market processing logic

**Solution**:
```gdscript
# In FarmGrid - add new method:
func process_market_sales(position: Vector2i) -> Dictionary:
    """Sell all accumulated flour at market"""
    var plot = get_plot(position)
    if not plot or plot.plot_type != FarmPlot.PlotType.MARKET:
        return {"success": false}

    var flour = farm.economy.get_resource("💨")
    if flour <= 0:
        return {"success": false, "flour_sold": 0}

    # Sell flour for credits
    var flour_units = flour / farm.economy.QUANTUM_TO_CREDITS
    var result = farm.economy.sell_flour_at_market(flour_units)

    return result

# Also in FarmGrid._process():
for position in plots.keys():
    var plot = plots[position]
    if plot.plot_type == FarmPlot.PlotType.MARKET and plot.is_planted:
        process_market_sales(position)  # Auto-sell accumulated flour
```

**Files to Modify**:
- `Core/GameMechanics/FarmGrid.gd` - add market processing

### Priority 4: Implement Kitchen (NICE-TO-HAVE)

**Task**: Flour→Bread conversion

**Solution**:
```gdscript
# Add to FarmEconomy:
func process_flour_to_bread(flour_amount: int) -> Dictionary:
    """Convert flour to bread using kitchen
    Kitchen efficiency: 5 flour → 3 bread (60% yield)
    """
    var flour_credits = flour_amount * QUANTUM_TO_CREDITS
    if not can_afford_resource("💨", flour_credits):
        return {"success": false}

    remove_resource("💨", flour_credits, "kitchen_input")

    var bread_gained = int(flour_amount * 0.6)
    add_resource("🍞", bread_gained * QUANTUM_TO_CREDITS, "kitchen_output")

    print("🍳 Baked %d flour → %d bread" % [flour_amount, bread_gained])
    return {"success": true, "bread_produced": bread_gained}

# In FarmGrid:
func process_kitchen(position: Vector2i) -> Dictionary:
    var plot = get_plot(position)
    if not plot or plot.plot_type != FarmPlot.PlotType.KITCHEN:
        return {"success": false}

    var flour_units = farm.economy.get_resource_units("💨")
    if flour_units <= 0:
        return {"success": false}

    return farm.economy.process_flour_to_bread(flour_units)
```

**Files to Modify**:
- `Core/GameMechanics/FarmEconomy.gd` - add process_flour_to_bread()
- `Core/GameMechanics/FarmGrid.gd` - add kitchen processing

---

## 📋 Implementation Checklist

### PHASE 1: Fix Mill (CRITICAL - blocks everything after)
- [ ] Adapt QuantumMill.perform_quantum_measurement() to Model B
  - [ ] Get BiomeBase reference from plot
  - [ ] Use quantum_computer instead of quantum_state
  - [ ] Rewrite purity/probability measurement logic

- [ ] Add QuantumMill.get_accumulated_flour() and reset
- [ ] Integrate mill processing into FarmGrid._process()

### PHASE 2: Wire Mill to Economy
- [ ] Call farm.economy.process_wheat_to_flour() from mill
- [ ] Auto-flush flour to economy each frame or at interval
- [ ] Test: Plant wheat → entangle → measure → harvest → mill → get flour

### PHASE 3: Implement Market
- [ ] Create FarmGrid.process_market_sales()
- [ ] Call farm.economy.sell_flour_at_market()
- [ ] Auto-sell accumulated flour each frame
- [ ] Test: Flour → Credits conversion

### PHASE 4: Implement Kitchen (Optional)
- [ ] Add FarmEconomy.process_flour_to_bread()
- [ ] Create FarmGrid.process_kitchen()
- [ ] Test: Flour → Bread conversion

---

## 🧪 Test Plan

### Test Sequence:
```
1. test_complete_production_chain.gd
   - Run existing comprehensive playtest
   - Should now pass Mill & Market sections
   - Expected: 🌾 → 💨 → 💰 → ✅

2. test_kitchen_triple_entanglement.gd
   - Test with 3 entangled wheat plots
   - Verify batch measurement collapse
   - Check flour production scales with harvest

3. test_economic_biome_full.gd
   - Full economy chain test
   - All 4 biomes integrated
   - Complete 🌾 → 💨 → 💰 → 🍞 flow
```

### Current Test Status:
- ✅ `test_complete_production_chain.gd` - Runs but marks Mill/Market as "not implemented"
- ✅ `claude_comprehensive_playtest.gd` - Kitchen test exists but commented out
- ⚠️ Tests show architecture but implementations are broken

---

## 📊 Effort Estimate

| Task | Complexity | Time | Blocker |
|------|-----------|------|---------|
| Fix QuantumMill to Model B | MEDIUM | 2-3 hrs | YES - blocks all below |
| Wire mill to economy | LOW | 1-2 hrs | NO - can work standalone |
| Implement market sales | LOW | 1-2 hrs | NO - can work standalone |
| Implement kitchen | LOW | 1-2 hrs | NO - nice to have |
| **Total** | **LOW-MEDIUM** | **5-9 hrs** | - |

---

## Summary

The full kitchen pathway exists and is 50% complete:

- ✅ **Quantum Layer** (Plant → Grow → Entangle → Measure → Harvest) - ALL WORKING
- ❌ **Classical Layer** (Mill → Market → Kitchen) - ALL BROKEN
- ✅ **Economy System** (FarmEconomy) - IMPLEMENTED BUT DISCONNECTED
- ❌ **Integration** - NO PLUMBING BETWEEN LAYERS

**Root Cause**: QuantumMill and buildings exist but were written for Model A quantum architecture. Model B refactor broke the connection without updating these components.

**Fix**: 1-2 day effort to adapt mill to Model B and wire buildings to economy systems.
