# Bugs Found During Exploration
**Date:** 2025-12-31
**Test:** Mushroom farming + Quest system exploration

---

## BUG #1: Mushroom Icon Missing/Duplicate ⚠️

**Severity:** Medium (causes warnings)

**Output:**
```
WARNING: 🛁 Icon not found for emoji: 🍄
  ✅ Bath initialized with 6 emojis, 0 icons
  ✅ Hamiltonian: 0 non-zero terms
  ✅ Lindblad: 0 transfer terms
...
WARNING: IconRegistry: Overwriting existing Icon for 🍄
```

**Issue:**
- BioticFlux biome initializes before IconRegistry has 🍄 icon
- Later, IconRegistry loads and overwrites the icon
- Bath has 0 icons initially (no Hamiltonian/Lindblad terms!)

**Impact:**
- Mushrooms may not have proper growth mechanics initially
- Icon double-registration could cause conflicts

**Fix Needed:** Ensure IconRegistry loads before biomes initialize

---

## BUG #2: Energy Doesn't Grow During _process() ⚠️⚠️⚠️

**Severity:** CRITICAL - Game-breaking

**Test:**
```gdscript
# Plant mushroom at t=0, energy=0.100
farm.biotic_flux_biome._process(40.0)  # Advance 40 seconds
# After 40s: energy=0.100  ❌ NO GROWTH!
```

**Expected:**
- Energy should grow exponentially during _process()
- Growth rate observed in live game: 0.087/s
- After 40s: energy should be ≈ 0.100 * exp(0.087 * 40) ≈ 2.8

**Actual:**
- Energy remains at 0.100 (no change)

**Impact:**
- **Cannot simulate time advancement** - critical for testing
- **Time manipulation strategy broken** - can't fast-forward
- **May affect real-time gameplay** if _process() isn't called correctly

**Root Cause:**
Likely issue with how biome._process() propagates to quantum states.

**Fix Needed:** Investigate BiomeBase._process() and ensure it advances quantum state energy

---

## BUG #3: Mushroom Harvests as 🍂 (Compost), Not 🍄

**Severity:** Medium (unexpected behavior)

**Test:**
```gdscript
farm.build(pos, "mushroom")  # Plant mushroom
# Creates BATH PROJECTION 🍄↔🍂 at (0, 0)
measure_plot()
# outcome=🍂 (compost)  ❌ Expected 🍄
```

**Issue:**
- Mushrooms are planted as quantum superposition: |🍄⟩ + |🍂⟩
- Measurement collapsed to 🍂 (compost) instead of 🍄
- Quantum randomness means 50/50 chance of either outcome

**Impact:**
- Cannot reliably farm mushrooms for quests
- Quest wants 🍄, but farming gives 🍂 half the time
- Makes quest completion unreliable

**Is This a Bug or Feature?**
- **Feature:** Realistic quantum mechanics (measurement uncertainty)
- **Bug:** No way to bias outcome toward desired resource

**Possible Solutions:**
1. Add "bias gates" to shift superposition angle
2. Use entanglement to correlate outcomes
3. Accept 50/50 and plant 2x as many mushrooms

---

## BUG #4: Zero Harvest Yields

**Severity:** High (economic impact)

**Test:**
```gdscript
harvest_plot()
# Yield: 0 credits
# 🍄: 0 → 0 (change: +0)
# 👥: 10 → 10 (change: +0)
```

**Issue:**
- Harvested successfully (outcome=🍂)
- But received **0 credits** for the harvest
- Energy was 0.09 at harvest time (very low)

**Hypothesis:**
- Yield may depend on energy level
- Low energy (0.09) → zero yield
- Need minimum energy threshold for profitable harvest

**Impact:**
- **Cannot make profit** from low-energy harvests
- **Economic viability questionable** if yields are often zero
- **Encourages waiting** for high energy before harvesting

**Test Needed:** Correlation study between energy and yield

---

## BUG #5: Quests Request Non-Harvestable Resources ⚠️⚠️

**Severity:** CRITICAL - Quest system broken

**Test Output:**
```
Quest 1: [Carrion Throne] wants 2 🌾   ✅ Harvestable
Quest 2: [Terrarium Collective] wants 1 🌑   ❌ Moon (environmental)
Quest 3: [Bone Merchants] wants 3 ☀️   ❌ Sun (environmental)
Quest 4: [Causal Shepherds] wants 6 👥   ✅ Harvestable (via measurement)
Quest 5: [Clan of the Hidden Root] wants 4 🌑   ❌ Moon (environmental)
```

**Issue:**
- 3 out of 5 quests request **environmental icons**
- 🌑 (Moon) and ☀️ (Sun) are NOT harvestable resources
- They're environmental parameters (celestial bodies)
- **60% of quests are impossible to complete!**

**Root Cause:**
Quest generation uses `farm.biotic_flux_biome.get_producible_emojis()` which likely returns ALL emojis in the bath, including environmental ones.

**Impact:**
- **Quest completion rate: ~40%** (only 2/5 quests are doable)
- **User frustration** from impossible quests
- **Faction system underutilized** because most quests fail

**Fix Needed:**
Filter `get_producible_emojis()` to exclude environmental icons:
```gdscript
func get_harvestable_emojis() -> Array[String]:
    var harvestable = []
    for emoji in get_producible_emojis():
        if not _is_environmental_icon(emoji):  # Filter ☀️🌑
            harvestable.append(emoji)
    return harvestable
```

---

## BUG #6: Resource Frequency Display Cut Off

**Severity:** Low (display issue)

**Output:**
```
Resource frequency:
=== TEST COMPLETE ===
```

**Issue:**
- Frequency calculation code executed
- But no output printed (empty line)
- Loop likely failed silently

**Cause:**
Dictionary may be empty or print loop has issue

**Fix:** Minor display bug, low priority

---

## FINDINGS (Not Bugs)

### Finding 1: Mushroom Planting Costs 🍄 + 🍂

**Observation:**
```
💸 Spent 1 🍄, 1 🍂 on mushroom
```

**Interpretation:**
- Mushrooms require BOTH 🍄 (mushroom spore) AND 🍂 (compost substrate)
- Makes sense biologically (mushrooms grow on compost)
- Increases farming cost vs. wheat (which only costs 🌾)

**Impact:** Mushroom farming is more expensive than wheat farming

### Finding 2: Mushroom Quantum State is 🍄↔🍂

**Observation:**
```
🛁 Plot.plant(): created BATH PROJECTION 🍄↔🍂 at (0, 0)
```

**Interpretation:**
- Mushrooms exist in superposition of 🍄 (food) and 🍂 (waste)
- Represents decomposition cycle
- Measurement collapses to one or the other

**Implications:**
- **Feature, not bug:** Realistic mushroom lifecycle
- **Strategic consideration:** Need to manage compost as byproduct
- **Quest challenge:** Can't guarantee 🍄 output

### Finding 3: Market Bath Used for Planting

**Observation:**
```
💉 Injected 🍄 into Market bath
💉 Injected 🍂 into Market bath (amplitude matched to 🍄)
✅ Bath now has 8 emojis: ["🐂", "🐻", "💰", "📦", "🏛️", "🏚️", "🍄", "🍂"]
```

**Interpretation:**
- Plots use **Market bath** for quantum state, not BioticFlux
- Market bath is commodities trading system
- Mushrooms are being treated as tradeable commodities

**Question:** Should mushrooms use BioticFlux bath instead?

---

## Summary Statistics

| Metric | Value | Assessment |
|--------|-------|------------|
| **Total Bugs Found** | 6 | 3 critical, 2 medium, 1 low |
| **Quest Success Rate** | 40% | Only 2/5 quests harvestable |
| **Energy Growth** | 0% | BROKEN - no time advancement |
| **Harvest Yield** | 0 credits | Too low energy |
| **Icon Warnings** | 2 | Initialization order issue |

---

## Priority Fixes

### P0 (Critical - Blocks Testing)
1. ✅ **Fix energy growth in _process()** - Cannot test without this
2. ✅ **Filter environmental icons from quests** - 60% quests impossible

### P1 (High - Gameplay Impact)
3. ⚠️ **Investigate zero yields** - Economic viability
4. ⚠️ **Fix icon initialization order** - Prevents warnings

### P2 (Medium - User Experience)
5. 📝 **Document mushroom mechanics** - 🍄↔🍂 superposition
6. 📝 **Add resource bias mechanics** - Let players steer outcomes

### P3 (Low - Polish)
7. 🔧 **Fix frequency display** - Minor UI bug

---

## Next Tests Needed

1. **Energy growth investigation:** Why doesn't _process() advance energy?
2. **Quest filter test:** Verify only harvestable resources in quests
3. **Yield correlation study:** Energy level vs. harvest credits
4. **Wheat vs. mushroom comparison:** Full farming cycle for both
5. **Entanglement yield test:** Do entangled plots give better yields?

---

**Bugs Found By:** Claude Code (exploration mode)
**Test Duration:** ~5 minutes
**Files Affected:** BiomeBase.gd, QuestGenerator.gd, Economy system
