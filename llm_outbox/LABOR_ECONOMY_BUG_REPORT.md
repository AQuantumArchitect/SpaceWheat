# 🐛 Labor Economy Bug Report

## Executive Summary

**Status**: ❌ **ECONOMY BROKEN** - Mushroom farming is unsustainable
**Severity**: CRITICAL - Blocks mushroom gameplay loop
**Root Cause**: Mushrooms cost 👥 (labor) but never return 👥

---

## The Problem

### Current Mushroom Economy Flow

```
1. Plant mushroom → costs 1👥 (labor)
2. Mushroom grows with projection 🍄↔🍂
3. Harvest → collapses to 🍄 or 🍂
4. Receive 🍄-credits OR 🍂-credits
5. ❌ Never get 👥 back → Can't replant!
```

### Test Results

```
Starting labor: 10 credits (1 quantum unit)
Plant mushroom: -1 labor → 9 credits remaining
Wait for growth: radius reaches 1.0
Harvest outcome: 🍂 (detritus)
Harvest reward: +9 🍂-credits

Labor after cycle: 9 credits (same as after planting)
ROI: -100% (lost 1 labor, gained 0 labor back)

VERDICT: UNSUSTAINABLE
```

After ONE mushroom cycle, you've lost 10% of your labor. After 10 cycles, you have ZERO labor and the game is over.

---

## Why Wheat Works But Mushrooms Don't

### Wheat Economy (✅ Sustainable)

```
Cost:       {"🌾": 1}
Projection: 🌾↔👥
Outcomes:
  - 🌾 → Get wheat back → Can replant ✅
  - 👥 → Get labor → Can plant mushrooms ✅

Result: SELF-SUSTAINING + produces labor
```

### Mushroom Economy (❌ Broken)

```
Cost:       {"👥": 1}
Projection: 🍄↔🍂
Outcomes:
  - 🍄 → Get mushroom credits → Can't replant ❌
  - 🍂 → Get detritus → Can't replant ❌

Result: LABOR SINK with no recovery mechanism
```

---

## Root Cause Analysis

**File**: `Core/Farm.gd:957`
**Function**: `_process_harvest_outcome()`

```gdscript
func _process_harvest_outcome(harvest_data: Dictionary) -> void:
    var outcome_emoji = harvest_data.get("outcome", "")
    var quantum_energy = harvest_data.get("energy", 0.0)

    # Generic routing: any emoji → its credits
    var credits_earned = economy.receive_harvest(outcome_emoji, quantum_energy, "harvest")
```

The system gives credits based on the **collapse outcome** (what the quantum state collapses TO), not the **planting cost** (what you paid).

This works fine for wheat because:
- Wheat collapses to 🌾 (can replant with 🌾)
- Wheat collapses to 👥 (universal resource for planting)

But fails for mushrooms because:
- Mushroom collapses to 🍄 (can't replant with 🍄, costs 👥!)
- Mushroom collapses to 🍂 (can't replant with 🍂, costs 👥!)

---

## Proposed Solutions

### Option 1: Change Mushroom Cost (Simplest)

Change mushroom to cost 🍄 instead of 👥:

```gdscript
"mushroom": {
    "cost": {"🍄": 1},  # Changed from {"👥": 1}
    "type": "plant",
    "plant_type": "mushroom",
    "north_emoji": "🍄",
    "south_emoji": "🍂"
}
```

**Pros**:
- Makes mushroom self-sustaining (like wheat)
- Minimal code change
- Preserves quantum projection semantics

**Cons**:
- Bootstrap problem: how do you get the first mushroom?
- Might need starting mushroom credits
- Changes economic balance (mushrooms become independent resource)

---

### Option 2: Change Mushroom Projection

Change mushroom projection from 🍄↔🍂 to 🍄↔👥:

```gdscript
"mushroom": {
    "cost": {"👥": 1},
    "type": "plant",
    "plant_type": "mushroom",
    "north_emoji": "🍄",
    "south_emoji": "👥"  # Changed from "🍂"
}
```

**Pros**:
- Makes mushroom return labor (can replant)
- Preserves cost structure
- Creates wheat→labor→mushroom→labor loop

**Cons**:
- Changes quantum semantics (mushrooms no longer collapse to detritus)
- Might conflict with narrative/theme (why do mushrooms produce labor?)
- Removes 🍂 (detritus) from the game unless another source exists

---

### Option 3: Add Resource Conversion System

Implement a Market or conversion system that allows:
- 🍄 → 👥 (sell mushrooms for labor)
- 🍂 → 👥 (compost detritus into labor)

**Pros**:
- Preserves all current semantics
- Adds strategic depth (when to sell vs stockpile)
- Could be part of Market biome functionality

**Cons**:
- Most complex implementation
- Requires new UI/systems
- Might still need careful balance tuning

---

### Option 4: Hybrid Approach (Recommended)

Combine options for a balanced solution:

1. **Change starting resources**:
   ```gdscript
   🌾: 50  👥: 10  🍄: 10  🍂: 10
   ```
   Give player starting mushroom credits

2. **Change mushroom cost**:
   ```gdscript
   "cost": {"👥": 1, "🍄": 0}  # Costs labor but requires 0 mushrooms
   ```
   OR
   ```gdscript
   "cost": {"🍄": 1}  # Costs mushrooms directly
   ```

3. **Add wheat→mushroom conversion**:
   Make wheat occasionally collapse to 🍄 instead of just 🌾↔👥
   OR
   Add a wheat projection that includes mushroom (🌾↔👥↔🍄 superposition?)

**Pros**:
- Solves bootstrap problem
- Maintains interesting economy
- Both resources self-sustaining

**Cons**:
- More complex than single fix
- Needs careful balance testing

---

## Impact Assessment

**Current State**:
- ❌ Mushroom farming literally impossible after initial labor depleted
- ❌ Quest system can't assign mushroom quests (would be uncompletable)
- ❌ BioticFlux biome partially broken (mushroom mechanics non-functional)
- ❌ Day/night cycle meaningless for mushrooms (can't farm enough to observe)

**After Fix**:
- ✅ Players can maintain mushroom farms
- ✅ Quest system can include mushroom objectives
- ✅ BioticFlux biome fully functional
- ✅ Day/night strategy becomes viable

---

## Test Case

File: `/tmp/test_labor_economy.gd`

Reproduces the bug with:
1. Plant single mushroom (costs 1 labor)
2. Wait for maturity
3. Harvest (gets 🍂 or 🍄, but NOT 👥)
4. Verify labor is gone forever

**Current Result**: ❌ ECONOMY IS BROKEN
**Expected After Fix**: ✅ ECONOMY IS SUSTAINABLE

---

## Recommendation

**Immediate Fix**: Option 1 (Change mushroom cost to `{"🍄": 1}`) + Give starting mushroom credits

**Long-term**: Option 3 (Add Market conversion system) for richer gameplay

**Reasoning**:
- Option 1 is a 2-line fix that unblocks mushroom gameplay immediately
- Starting credits (10 🍄) solve bootstrap problem
- Can add conversion/market later for strategic depth
- Preserves quantum projection semantics (🍄↔🍂 still correct)

---

## Next Steps

1. User approval on solution approach
2. Implement chosen fix
3. Re-run `/tmp/test_labor_economy.gd` to verify
4. Test multi-cycle economy (10+ mushroom cycles)
5. Update quest system to allow mushroom objectives
6. Playtest for balance
