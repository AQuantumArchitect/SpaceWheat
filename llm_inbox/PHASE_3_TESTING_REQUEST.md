# Phase 3: Measurement Refactor - Testing Request

**Date**: 2026-01-02
**Status**: Implementation Complete → Ready for Testing
**Risk Level**: HIGH (Breaking Change - Harvest Yield Formula)
**Manifest Sections**: 4.3 (Selective Measurement), 4.4 (Harvest)

---

## What Was Implemented

### 1. POSTSELECT_COSTED Measurement (Manifest Section 4.3)

**File**: `Core/QuantumSubstrate/QuantumBath.gd` (lines 594-660)

#### New Methods

**`get_collapse_strength() → float`**
- Returns 1.0 for LAB_TRUE mode (full projective collapse per Born rule)
- Returns 0.5 for KID_LIGHT mode (gentle partial collapse, preserves coherence)
- Reads from QuantumRigorConfig singleton

**`measure_axis_costed(north, south, max_cost) → Dictionary`**
- Implements selective measurement via postselection cost model
- Returns: `{outcome: String, cost: float, p_subspace: float}`
- Cost = 1/P(subspace) where P(subspace) = P(north) + P(south)
- Outcome: Random in {north, south} weighted by conditional probabilities
- Collapse: Applied with get_collapse_strength() value

Example:
```
P(north) = 0.8, P(south) = 0.2 → P(subspace) = 1.0
cost = 1.0 / 1.0 = 1.0 (no penalty)
outcome = north (with 80% probability)

P(north) = 0.1, P(south) = 0.05 → P(subspace) = 0.15
cost = 1.0 / 0.15 ≈ 6.67 (expensive measurement!)
outcome = north (with ~67% probability) or south (~33%)
```

### 2. Harvest Yield Refactor (Manifest Section 4.4)

**File**: `Core/GameMechanics/BasePlot.gd` (lines 141-239)

#### New Yield Formula

```
base_yield = 10.0 (outcome-based, not radius-based)
purity_multiplier = 2.0 * Tr(ρ²)
measurement_cost = measure_axis_costed().cost

yield = floor(base_yield * purity_multiplier / measurement_cost)
```

#### Key Changes

1. **Outcome-Based**: Yield depends on successful measurement, not Bloch sphere radius
2. **Purity Scaling**: Multiplier from `2.0 * Tr(ρ²)`:
   - Pure state (Tr(ρ²) = 1.0) → 2.0× multiplier
   - Mixed state (Tr(ρ²) = 0.5) → 1.0× multiplier
   - Maximally mixed (Tr(ρ²) ≈ 0.17) → 0.34× multiplier

3. **Cost Penalty**: `yield *= (1.0 / measurement_cost)`
   - High subspace probability → low cost → no penalty
   - Low subspace probability → high cost → significant penalty

#### Backward Compatibility

- Default mode: INSPECTOR (cost = 1.0 → no penalty)
- Old behavior preserved when POSTSELECT_COSTED not enabled
- Can be toggled via QuantumRigorConfig

#### Example Yields

| Scenario | Base | Purity | Purity× | Cost | Cost÷ | Final |
|----------|------|--------|---------|------|--------|-------|
| Pure, full subspace | 10 | 1.0 | 2.0× | 1.0 | 1.0× | **20** |
| Pure, 50% subspace | 10 | 1.0 | 2.0× | 2.0 | 0.5× | **10** |
| Pure, 10% subspace | 10 | 1.0 | 2.0× | 10.0 | 0.1× | **2** |
| Mixed, full subspace | 10 | 0.5 | 1.0× | 1.0 | 1.0× | **10** |
| Mixed, 10% subspace | 10 | 0.5 | 1.0× | 10.0 | 0.1× | **1** |

### 3. Vector Harvest Operations (Manifest Section 4.4)

**File**: `Core/Environment/BiomeBase.gd` (lines 1194-1231)

**`harvest_all_plots() → Array`**
- Bulk harvest operation for entire biome
- Iterates through active_projections
- Harvests all planted plots simultaneously
- Returns array of harvest result dictionaries
- Aggregates and reports total yield

---

## Critical Test Cases

### Test Suite 1: Collapse Strength Configuration

**File**: Create `Tests/test_collapse_strength_modes.gd`

```gdscript
## Test that collapse strength responds to QuantumRigorConfig

func test_kid_light_mode_returns_0_5():
    var config = QuantumRigorConfig.new()
    config.backaction_mode = QuantumRigorConfig.BackactionMode.KID_LIGHT
    QuantumRigorConfig.instance = config

    var bath = QuantumBath.new()
    var strength = bath.get_collapse_strength()

    assert_almost_eq(strength, 0.5, 1e-6,
        "KID_LIGHT should return 0.5")

func test_lab_true_mode_returns_1_0():
    var config = QuantumRigorConfig.new()
    config.backaction_mode = QuantumRigorConfig.BackactionMode.LAB_TRUE
    QuantumRigorConfig.instance = config

    var bath = QuantumBath.new()
    var strength = bath.get_collapse_strength()

    assert_almost_eq(strength, 1.0, 1e-6,
        "LAB_TRUE should return 1.0 (full collapse)")
```

### Test Suite 2: POSTSELECT_COSTED Measurement

**File**: Create `Tests/test_postselect_costed_measurement.gd`

```gdscript
## Test measure_axis_costed implementation

func test_costed_measurement_cost_formula():
    # P(north) = 0.2, P(south) = 0.3 → P(sub) = 0.5
    # cost should be 1.0 / 0.5 = 2.0

    var bath = QuantumBath.new()
    bath.initialize_with_emojis(["north", "south", "other"])
    bath.initialize_weighted({"north": 0.2, "south": 0.3, "other": 0.5})

    var result = bath.measure_axis_costed("north", "south", 10.0)

    assert_almost_eq(result.p_subspace, 0.5, 1e-6,
        "Subspace probability wrong")
    assert_almost_eq(result.cost, 2.0, 1e-6,
        "Cost should be 1.0 / 0.5 = 2.0")

func test_costed_outcome_in_subspace():
    var bath = QuantumBath.new()
    bath.initialize_with_emojis(["north", "south", "other"])
    bath.initialize_weighted({"north": 0.6, "south": 0.4, "other": 0.0})

    for i in range(10):
        var result = bath.measure_axis_costed("north", "south", 10.0)
        assert_true(result.outcome in ["north", "south"],
            "Outcome must be in {north, south}, got %s" % result.outcome)

func test_costed_cost_clamping():
    var bath = QuantumBath.new()
    bath.initialize_with_emojis(["north", "south"])
    bath.initialize_weighted({"north": 0.01, "south": 0.99})

    var result = bath.measure_axis_costed("north", "south", 5.0)

    assert_le(result.cost, 5.0,
        "Cost should be clamped at max_cost=5.0")

func test_zero_subspace_probability():
    var bath = QuantumBath.new()
    bath.initialize_with_emojis(["north", "south", "other"])
    bath.initialize_weighted({"north": 0.0, "south": 0.0, "other": 1.0})

    var result = bath.measure_axis_costed("north", "south", 10.0)

    assert_eq(result.outcome, "",
        "Should return empty outcome for zero subspace")
    assert_eq(result.p_subspace, 0.0,
        "Subspace probability should be 0")
```

### Test Suite 3: Harvest Yield Formula

**File**: Create `Tests/test_harvest_yield_formula.gd`

```gdscript
## Test new harvest yield formula with cost penalties

func test_pure_state_full_subspace():
    # Setup: Pure state, measured in full subspace (cost=1.0)
    # Expected: 10 base × 2.0 purity × (1.0/1.0) = 20 yield

    # (Requires integration with actual bath and plot)

    var plot = create_pure_state_plot()
    plot.quantum_state.bath.initialize_weighted({"north": 1.0, "south": 0.0})

    var result = plot.harvest()

    assert_eq(result.yield, 20,
        "Pure state, full subspace should yield 20")

func test_mixed_state_low_subspace():
    # Setup: Mixed state, low subspace probability (cost=10.0)
    # Expected: 10 base × 1.0 purity × (1.0/10.0) = 1 yield

    var plot = create_mixed_state_plot(0.5)  # purity=0.5
    plot.quantum_state.bath.initialize_weighted({
        "north": 0.05,
        "south": 0.05,
        "other": 0.9
    })

    var result = plot.harvest()

    assert_eq(result.yield, 1,
        "Mixed state, 10% subspace should yield ~1")

func test_cost_included_in_result():
    # POSTSELECT_COSTED mode should include measurement_cost
    var config = QuantumRigorConfig.new()
    config.selective_measure_model = QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED
    QuantumRigorConfig.instance = config

    var plot = create_test_plot()
    var result = plot.harvest()

    assert_true(result.has("measurement_cost"),
        "POSTSELECT_COSTED harvest should include measurement_cost")
    assert_gt(result.measurement_cost, 0.0,
        "Measurement cost should be positive")
```

### Test Suite 4: Vector Harvest Operations

**File**: Create `Tests/test_biome_harvest_all.gd`

```gdscript
## Test BiomeBase.harvest_all_plots() vector operation

func test_harvest_all_plots_returns_array():
    var biome = create_test_biome()

    # Plant multiple plots
    biome.grid.plant(Vector2i(0, 0), "wheat")
    biome.grid.plant(Vector2i(1, 0), "wheat")
    biome.grid.plant(Vector2i(0, 1), "mushroom")

    var results = biome.harvest_all_plots()

    assert_is(results, TYPE_ARRAY,
        "harvest_all_plots should return array")
    assert_eq(results.size(), 3,
        "Should have 3 harvest results")

func test_harvest_all_aggregates_yield():
    var biome = create_test_biome()

    # Plant 3 plots (each yields ~10)
    for i in range(3):
        biome.grid.plant(Vector2i(i, 0), "wheat")

    var results = biome.harvest_all_plots()

    var total_yield = 0
    for result in results:
        if result.success:
            total_yield += result.yield

    assert_gt(total_yield, 0,
        "Should aggregate positive total yield")

func test_harvest_all_only_harvests_planted():
    var biome = create_test_biome()

    # Plant 2, leave 2 unplanted
    biome.grid.plant(Vector2i(0, 0), "wheat")
    biome.grid.plant(Vector2i(1, 0), "wheat")
    # (0, 1) and (1, 1) left empty

    var results = biome.harvest_all_plots()

    assert_eq(results.size(), 2,
        "Should only harvest planted plots")
```

---

## Manifest Compliance Checklist

### Section 4.3: Selective Measurement

- [ ] `measure_axis_costed()` returns Dictionary with outcome/cost/p_subspace
- [ ] Cost = 1/P(subspace) with proper clamping
- [ ] Outcome is random in {north, south} weighted by conditional probabilities
- [ ] Collapse strength respects KID_LIGHT vs LAB_TRUE mode
- [ ] Cost formula matches: cost ∈ [1.0, max_cost]

### Section 4.4: Harvest Gozouta Protocol

- [ ] Harvest uses outcome-based yield (not radius-based)
- [ ] Base yield = 10 credits (constant)
- [ ] Purity multiplier = 2.0 × Tr(ρ²) properly calculated
- [ ] Cost penalty = 1.0 / measurement_cost applied
- [ ] Measurement_cost only included in POSTSELECT_COSTED mode
- [ ] INSPECTOR mode preserves backward compatibility (cost=1.0)
- [ ] Clamping: yield ∈ [1, ∞) with floor

### Section 4.4: Vector Harvest

- [ ] `harvest_all_plots()` returns Array
- [ ] Only harvests planted plots in active_projections
- [ ] Aggregates results and reports total yield
- [ ] No null reference errors if grid is missing

---

## Known Issues & Edge Cases

### 1. Empty Subspace Measurement
**Issue**: What if P(north) + P(south) < 1e-10?
**Current Behavior**: Returns outcome="", cost=max_cost, p_subspace=0.0
**Test**: Verify no crashes when subspace is empty

### 2. Cost Clamping Boundary
**Issue**: Cost = 1/P(sub) can be very large for small P(sub)
**Current Behavior**: Clamped at max_cost=10.0 (default)
**Test**: Verify yield stays reasonable (not infinite)

### 3. Purity = 0 Edge Case
**Issue**: If bath returns purity=0, multiplier=0, yield=0
**Current Behavior**: floor(0) = 0, but yield is clamped to min=1
**Test**: Verify yield never goes below 1

### 4. Mode Configuration Persistence
**Issue**: QuantumRigorConfig is a singleton - modes persist across tests
**Fix Needed**: Clear QuantumRigorConfig.instance between tests
**Recommendation**: Add test cleanup:
```gdscript
func cleanup():
    QuantumRigorConfig.instance = null
```

### 5. Bath Measurement Doesn't De-Couple
**Issue**: After `measure_axis_costed()`, plot remains coupled to bath
**Expected**: Measurement should collapse plot-specific subspace view
**Test**: Verify coherence decreases after measurement

---

## How to Run Tests

### Full Phase 3 Test Suite
```bash
cd /home/tehcr33d/ws/SpaceWheat

# Individual test files
godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_collapse_strength_modes -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_postselect_costed_measurement -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_harvest_yield_formula -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gtest=test_biome_harvest_all -gexit

# All Phase 3 tests
godot --headless -s addons/gut/gut_cmdln.gd -gtest="test_collapse|test_postselect|test_harvest|test_biome_harvest" -gexit
```

### Manual Gameplay Tests
1. Plant wheat in INSPECTOR mode → harvest → verify yield ~20
2. Plant wheat in LAB_TRUE mode → harvest → verify yield formula applied
3. Plant 3 plots → call biome.harvest_all_plots() → verify all harvested
4. Create low-probability subspace → harvest → verify cost penalty applied
5. Test with 50% purity state → harvest → verify purity multiplier = 1.0

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Yield suddenly drops for players | HIGH | Game breaking | Default INSPECTOR mode, A/B test before full rollout |
| Measurement crashes on empty subspace | MEDIUM | Soft crash | Proper null checks & clamping |
| Configuration leaks between tests | HIGH | Test false passes | Add test cleanup hooks |
| Cost formula produces NaN/Inf | LOW | Silent yield corruption | Clamp cost and yield values |
| Mixed state purity calculation wrong | MEDIUM | Incorrect multiplier | Validate Tr(ρ²) calculation matches bath |

---

## Success Criteria

✅ All test cases pass
✅ No crashes in gameplay integration
✅ Yield formula matches manifest specification exactly
✅ Cost penalties scale correctly with subspace probability
✅ INSPECTOR mode yields identical to Phase 2 (backward compatible)
✅ Vector harvest completes without errors
✅ Measurement respects collapse strength mode

---

**Status**: Ready for QA testing
**Next Step**: Phase 4 (Pumping & Reset) or manual gameplay validation
**Estimated Testing Time**: 4-6 hours (automated + manual)
