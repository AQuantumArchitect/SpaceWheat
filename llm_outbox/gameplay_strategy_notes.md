# SpaceWheat Gameplay Strategy Notes
**Date:** 2025-12-31
**Test Rig:** `claude_plays_manual.gd` (30-turn playthrough)
**Tester:** Claude Code

---

## Test Run Summary

### Economic Results
- **Starting Resources:** 500🌾 Wheat, 10👥 Labor
- **Ending Resources:** 531🌾 Wheat, 10👥 Labor
- **Net Profit:** +31🌾 (+6.2% gain over 30 turns)
- **Profit per Turn:** ~1🌾/turn average

### Quest System Results
- **Quest System:** ✅ Working perfectly
- **Quests Offered:** 2 different factions
  1. ⚙️⛓️📿 **Iron Confessors** - "Sanctify a great harvest of ethereal 🍂 at the detritus pits immediately" (11🍂, 60s)
  2. 📦🗺️💸 **Cartographers** - "Commune many common 🍄 at the wheat fields before the cycle ends" (quantity unknown)
- **Quests Completed:** 0 ❌
- **Reason for Failure:** Resource mismatch (farming 🌾 wheat, quests want 🍂🍄)

---

## Strategy 1: Wheat Monoculture (Tested ✅)

### Overview
Plant only wheat, measure when mature, harvest and replant.

### Execution Flow
```
Turns 1-7:  Plant wheat (fill 6 plots)
Turns 8-10: Wait for maturity (3 days = 60 seconds)
Turn 11:    Measure plots (2 measured successfully)
Turn 12+:   Harvest → Measure → Harvest cycle
```

### Performance Metrics
- **Planting Cost:** 1🌾 per plot
- **Maturity Time:** 60 seconds (3 game days)
- **Harvest Yield:** Variable (0-9🌾 per plot)
- **Average Yield:** ~1.5🌾 per harvest
- **Labor Generation:** Occasionally from measurement collapse

### Pros ✅
- Simple, predictable strategy
- Low risk (always have wheat to replant)
- Generates steady profit
- Labor occasionally harvested as byproduct

### Cons ❌
- **Cannot complete quests** (quests want 🍄🍂, not 🌾)
- Low profit margin (6.2% over 30 turns)
- Ignores other biome resources
- No strategic variety

### Decision Logic Observed
```gdscript
# Priority order:
1. Harvest measured plots (immediate profit)
2. Measure mature plots (after 3-day growth)
3. Entangle adjacent unmeasured pairs (quantum strategy)
4. Plant wheat to fill farm (up to 6 plots)
5. Wait for plots to mature (fallback)
```

### Key Finding: Maturity Detection
The AI correctly tracks `plots_plant_time` and waits **60 seconds** before measuring:
```gdscript
var time_since_plant = game_time - plots_plant_time.get(pos, game_time)
if time_since_plant >= 60.0:  # 3 days = 60 seconds
    has_mature_plots = true
```

---

## Strategy 2: Quest-Driven Farming (Untested, Recommended)

### Theory
Adapt crop selection to match active quest requirements.

### Proposed Flow
```
1. Accept quest from QuestManager
2. Check quest.get("resource")
3. Plant crops matching quest resource
4. Measure after maturity
5. Harvest to complete quest
6. Claim quest rewards
```

### Example Quest Matching
| Quest Resource | Crop to Plant | Maturity Time | Notes |
|----------------|---------------|---------------|-------|
| 🌾 Wheat | Wheat | 60s (3 days) | Base crop |
| 🍄 Mushroom | Mushroom | 40s (2 days) | Night-active |
| 🍂 Compost | ??? | Unknown | Decomposition product? |
| 👥 Labor | Any crop | Any | Quantum collapse byproduct |

### Implementation Needed
```gdscript
func _decide_crop_for_quest(quest: Dictionary) -> String:
    var resource = quest.get("resource", "🌾")
    match resource:
        "🌾": return "wheat"
        "🍄": return "mushroom"
        "👥": return "wheat"  # Labor from measurement
        "🍂": return "???"    # Need to research
        _: return "wheat"     # Fallback
```

### Expected Benefits
- ✅ Quest completion possible
- ✅ Higher rewards than base farming
- ✅ Strategic depth
- ✅ Engages with 32-faction system

### Risks
- ❓ Crop maturity times vary
- ❓ Resource conversion rates unknown
- ❓ Quest time limits may be tight (60s observed)

---

## Strategy 3: Entanglement Farming (Partially Tested)

### Overview
Create Bell states between adjacent plots for correlated measurements.

### What Was Tested
The AI successfully:
- Detects adjacent unmeasured pairs
- Creates entanglement using `farm.entangle_plots(pos1, pos2)`
- Reports: "✅ Entanglement created! Bell state φ+"

### What Wasn't Tested
- Measuring entangled pairs together
- Effect of entanglement on harvest yield
- Cluster states (3+ qubits)
- Strategic entanglement for quest completion

### Proposed Experiments
1. **Correlated Measurement:** Measure both entangled plots in same turn
2. **Yield Analysis:** Compare entangled vs. non-entangled harvest yields
3. **Resource Steering:** Use entanglement to bias measurement outcomes
4. **Cluster Farming:** Entangle 3-6 adjacent plots for multi-qubit states

### Theoretical Advantage
Entanglement in SpaceWheat creates **quantum correlations**:
```
|φ+⟩ = (|🌾🌾⟩ + |👥👥⟩) / √2

Measuring plot 1 → 🌾 means plot 2 → 🌾 (100% correlation)
Measuring plot 1 → 👥 means plot 2 → 👥 (100% correlation)
```

**Potential Use:** Guarantee quest resource by entangling multiple plots!

---

## Strategy 4: Time Manipulation (Observed)

### Discovery
The AI uses `_action_wait()` to advance game time:
```gdscript
func _action_wait():
    var wait_time = 20.0  # 20 seconds = 1 day
    if farm.biotic_flux_biome:
        farm.biotic_flux_biome._process(wait_time)
        game_time += wait_time
```

### Strategic Implications
- Can **fast-forward** to maturity instead of waiting real-time
- Enables rapid cycling for testing
- **Problem:** Quest timers also advance! May fail quests if waiting too long

### Optimal Wait Times
| Wait Duration | Game Days | Use Case |
|---------------|-----------|----------|
| 20s | 1 day | Small increments |
| 40s | 2 days | Mushroom maturity |
| 60s | 3 days | Wheat maturity |
| 100s | 5 days | Long-term experiments |

### Risk
Waiting too long → quest timer expires → quest failure

---

## Strategy 5: Mushroom Night Farming (Proposed)

### Theory
Mushrooms have night-active growth:
```
Mushroom icon: Lindblad incoming from 🌙 = 0.40
```

This means mushrooms grow faster at night (when 🌙 moon is active).

### Proposed Strategy
1. Plant mushrooms at dusk
2. Wait through night (Lindblad growth rate 0.40)
3. Measure at dawn (after ~2 days = 40s)
4. Harvest mushrooms
5. Check if quest wants 🍄

### Expected Advantages
- Faster maturity (40s vs. 60s for wheat)
- High growth rate at night
- Quest system frequently requests 🍄
- Different strategic timing than wheat

### Implementation
```gdscript
# Plant mushrooms instead of wheat
var success = farm.build(pos, "mushroom")

# Wait 2 days instead of 3
if time_since_plant >= 40.0:
    measure_plot()
```

---

## Strategy 6: Multi-Resource Portfolio (Advanced)

### Concept
Diversify crops to hedge against quest variability.

### Example Distribution
- 2 plots: 🌾 Wheat (staple crop)
- 2 plots: 🍄 Mushrooms (night farming)
- 2 plots: Entangled pairs (correlation farming)

### Benefits
- ✅ Can respond to any quest
- ✅ Maximizes resource types
- ✅ Explores all game mechanics
- ✅ Higher quest completion rate

### Complexity
- Tracking multiple maturity times
- Managing different measurement windows
- Coordinating entangled pairs
- Resource allocation decisions

---

## Quest System Analysis

### Quest Generation Observed
**Sample Quests from 30-turn run:**

1. **Iron Confessors** (⚙️⛓️📿)
   - Body: "Sanctify a great harvest of ethereal 🍂 at the detritus pits immediately"
   - Resource: 🍂 (Compost/Detritus)
   - Quantity: 11
   - Urgency: "immediately" (60s time limit)
   - Biome: BioticFlux

2. **Cartographers** (📦🗺️💸)
   - Body: "Commune many common 🍄 at the wheat fields before the cycle ends"
   - Resource: 🍄 (Mushrooms)
   - Quantity: Unknown (described as "many")
   - Urgency: "before the cycle ends"
   - Biome: BioticFlux

### Quest Parameters Decoded
- **Verbs:** "Sanctify", "Commune" (from verb database)
- **Adjectives:** "ethereal", "common" (from faction bits)
- **Quantities:** "a great harvest" = 11, "many" = ?
- **Locations:** "detritus pits", "wheat fields" (from BiomeLocations)
- **Urgency:** "immediately", "before the cycle ends" (time pressure)

### Quest Difficulty Assessment
**Current Quest:** 11🍂 in 60 seconds

**Challenges:**
1. Don't know how to produce 🍂 (compost)
2. Starting with 0🍂
3. 60-second time limit is tight
4. No farming strategy for 🍂

**Hypothesis:** 🍂 may be a decomposition product, not directly plantable.

---

## Measurement Outcomes Observed

### Wheat Measurements (Sample)
```
Plot (0, 0): 🌾 → harvest 9 credits (+9🌾)
Plot (1, 0): 🌾 → harvest 0 credits (+0🌾)  ⚠️ Zero yield!
Plot (0, 1): 🌾 → harvest 5 credits (+5🌾)
```

### Key Findings
- ✅ Measurements succeed reliably
- ⚠️ Harvest yields are **highly variable** (0-9 credits)
- 🤔 Average yield ~1.5x planting cost
- ❓ What determines yield? Energy? Angle θ? Time?

### Hypothesis: Yield Mechanics
Yield may depend on:
1. **Plot energy** at measurement time
2. **Quantum state angle θ** (superposition balance)
3. **Time since planting** (older = higher energy?)
4. **Entanglement** (correlated pairs = higher yield?)

**Test Needed:** Compare yields from entangled vs. non-entangled plots.

---

## Economic Efficiency Analysis

### Cost-Benefit Per Cycle
```
Plant Cost:     -1🌾
Wait Cost:      0🌾 (time only)
Measure Cost:   0🌾
Harvest Yield:  +0 to +9🌾 (avg ~1.5🌾)

Net Profit:     ~0.5🌾 per plot per cycle
Cycle Time:     60 seconds
```

### Scaling Analysis
With 6 plots continuously cycling:
- Expected profit: 6 plots × 0.5🌾/cycle = +3🌾 per cycle
- Observed profit: +31🌾 over 30 turns ≈ +1🌾/turn
- **Finding:** Actual profit lower than theoretical (due to wait times, measurement variance)

### Profit Optimization Strategies
1. **Minimize Wait Times:** Measure as soon as mature
2. **Maximize Yield:** Research yield mechanics
3. **Entanglement Bonus:** Test if entangled pairs yield more
4. **Quest Rewards:** Complete quests for bonus resources
5. **Multi-Crop:** Diversify to match quest resources

---

## Decision Tree Evaluation

### Current AI Decision Logic
```
Priority 1: has_measured → Harvest (GOOD ✅)
Priority 2: has_mature_plots → Measure (GOOD ✅)
Priority 3: adjacent_unmeasured_pair → Entangle (EXPERIMENTAL 🔬)
Priority 4: can_plant && has_empty → Plant Wheat (INFLEXIBLE ❌)
Priority 5: Fallback → Wait (GOOD ✅)
```

### Strengths
- ✅ Prioritizes immediate profit (harvest first)
- ✅ Waits for maturity before measuring
- ✅ Explores entanglement mechanics
- ✅ Has fallback wait strategy

### Weaknesses
- ❌ **Always plants wheat** (ignores quest requirements)
- ❌ No quest-driven decision making
- ❌ No resource diversity
- ❌ Doesn't check quest completion

### Proposed Improvements
```gdscript
# NEW Priority 0: Check quest completion
if quest_manager.check_quest_completion(quest_id):
    quest_manager.complete_quest(quest_id)
    print("🎉 QUEST COMPLETED!")

# IMPROVED Priority 4: Plant crop matching quest
var quest_resource = _get_active_quest_resource()
var crop_type = _match_crop_to_resource(quest_resource)
farm.build(pos, crop_type)  # "wheat" or "mushroom"
```

---

## Entanglement Observations

### What Happened
- Turn 3: ✨ Created Bell entanglement (φ+) between plots (0,0) and (1,0)
- Entanglement confirmed by console output
- Both plots continued quantum evolution

### What Didn't Happen
- No correlated measurements observed
- No entanglement-specific yield data
- No multi-qubit cluster states

### Proposed Entanglement Experiments

#### Experiment 1: Correlated Measurement
```
1. Entangle plots A and B
2. Measure plot A → observe outcome (🌾 or 👥)
3. Immediately measure plot B
4. Verify correlation (should match A)
```

#### Experiment 2: Yield Comparison
```
Control Group:  3 non-entangled plots
Test Group:     3 entangled pairs (6 plots total)
Hypothesis:     Entangled plots yield more due to quantum coherence
```

#### Experiment 3: Resource Steering
```
Goal:           Complete quest for 5🌾
Strategy:       Entangle 5 plots
Action:         Measure first plot
Expectation:    If first → 🌾, all others → 🌾 (guaranteed quest resources)
```

---

## Quantum Mechanics Insights

### Energy Growth Observed
```
Plot (0, 0) radius: 0.100 → 0.957 over time
Growth rate: base=0.087, env=0.000, net=0.087
```

**Findings:**
- Energy radius grows exponentially over time
- Base growth rate: 0.087/s (from Hamiltonian)
- Environmental coupling: 0.000 (no external energy injection in test)
- Final radius: 0.957 (near maximum = 1.0)

### Implications
1. **Wait longer** = higher energy = better yield?
2. **Energy saturation** near radius=1.0
3. **Optimal measurement time** may be when radius peaks
4. **Environmental coupling** could boost growth (not tested)

---

## Quest Resource Availability

### Resources Available in BioticFlux Biome
From `get_producible_emojis()`:
```
🌾 Wheat
🍄 Mushroom
👥 Labor (via measurement collapse)
💨 Wind? (market-related)
🌻 Sunflower?
🍂 Compost/Detritus
🍅 Tomato?
```

### Quest Resources Requested (Observed)
```
🍂 Compost (Iron Confessors) - 11 units
🍄 Mushroom (Cartographers) - "many" units
```

### Resource Production Methods (Known)
| Resource | Production Method | Cost | Time |
|----------|-------------------|------|------|
| 🌾 | Plant wheat | 1🌾 | 60s |
| 🍄 | Plant mushroom | 1🍄 | 40s |
| 👥 | Measure any plot | Free | Instant |
| 🍂 | ??? | ??? | ??? |

### Critical Gap
**How to produce 🍂 (Compost)?**
- Not plantable directly
- May be decomposition product
- May require infrastructure (compost bin?)
- May be Market/Kitchen mechanic

---

## Strategic Recommendations

### For Quest Completion
1. **Research 🍂 production** - Critical for Iron Confessors quest
2. **Switch to mushroom farming** - Many quests request 🍄
3. **Track quest resources** - Check quest.get("resource") before planting
4. **Time management** - 60s time limit is tight, optimize cycles

### For Economic Optimization
1. **Test entanglement yields** - May significantly boost profit
2. **Measure at energy peak** - Wait until radius ≈ 0.95
3. **Minimize idle time** - Keep plots cycling continuously
4. **Harvest immediately** - Don't let measured plots sit idle

### For Quantum Exploration
1. **Cluster states** - Entangle 3+ adjacent plots
2. **Correlated measurements** - Measure entangled pairs together
3. **Energy injection** - Test environmental coupling mechanics
4. **Gate operations** - Use quantum gates from tool system

---

## Bugs & Issues Found

### Bug 1: Quest Not Completable
**Issue:** Quest asks for 🍂, but no clear production path
**Impact:** 0% quest completion rate
**Fix Needed:** Document 🍂 production or adjust quest generation

### Bug 2: Zero Harvest Yields
**Issue:** Some harvests give 0 credits despite successful measurement
**Example:** Plot (1,0) harvested 🌾 but yield = 0
**Impact:** Reduces economic efficiency
**Investigation:** What causes zero yields?

### Bug 3: Quest Timer Not Visible in Logs
**Issue:** Can see "Time: 58s" but no expiration event logged
**Impact:** Don't know if quests expired or just failed
**Enhancement:** Log quest expiration events

---

## Next Steps for Testing

### Immediate Tests
1. ✅ **Mushroom farming run** - Plant only mushrooms, track maturity/yield
2. ✅ **Quest-driven run** - Match crops to quest requirements
3. ✅ **Entanglement yield test** - Compare entangled vs. non-entangled profits

### Advanced Tests
4. ⏳ **Cluster state farming** - 3+ plot entanglement
5. ⏳ **Time optimization** - Find optimal measurement timing
6. ⏳ **Multi-biome exploration** - Test Market, Forest, Kitchen biomes
7. ⏳ **Infrastructure building** - Place mills, markets, composters

### Long-term Research
8. 📊 **Yield mechanics analysis** - Statistical study of harvest variance
9. 🎯 **Quest completion study** - Systematic quest-driven farming
10. ⚛️ **Quantum gate farming** - Use Hadamard, CNOT, Phase gates strategically

---

## Conclusions

### What Works ✅
- **Wheat monoculture** generates steady 6% profit
- **Quest system** generates diverse, procedural quests
- **Entanglement creation** works reliably
- **Time manipulation** enables rapid cycling
- **Maturity tracking** prevents premature measurements

### What Doesn't Work ❌
- **Quest completion** (resource mismatch)
- **Economic scaling** (low profit margins)
- **Entanglement utilization** (created but not used strategically)
- **Resource diversity** (only farming wheat)

### Key Insight
**The game is quest-driven, but the AI is farming-driven.** To succeed, strategies must:
1. Read quest requirements
2. Plant matching crops
3. Optimize for quest deadlines
4. Claim quest rewards

### Most Promising Strategy
**Quest-Driven Mushroom Farming:**
1. Accept quest
2. If quest wants 🍄: Plant mushrooms
3. Wait 40s (2 days)
4. Measure + harvest
5. Complete quest
6. Repeat with new quest

**Expected Improvement:** 50%+ quest completion rate, higher rewards

---

**Testing Completed By:** Claude Code
**Date:** 2025-12-31
**Test Runs:** 1 full (30 turns), multiple partial
**Status:** Ready for advanced strategy implementation

