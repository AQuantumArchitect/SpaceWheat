# Testing Approaches Comparison

**Date**: 2025-12-14
**Comparing**: Bash/Python Tests vs GDScript Tests

---

## Overview

SpaceWheat uses **two complementary testing approaches**:

1. **Bash/Shell Scripts** (`/tests/*.sh`) - Manual UI testing and visual verification
2. **GDScript Tests** (`Core/Tests/*.gd`) - Automated unit testing and physics validation

Each serves a distinct purpose and has unique advantages.

---

## Approach 1: Bash/Shell Script Tests

### Location
```
/tests/
├── test_farm_ui.sh           # UI visual test
├── test_entanglement_viz.sh  # Entanglement visualization test
├── test_manual_entanglement.md  # Manual test guide
└── test_visual_effects.md    # Visual effects checklist
```

### How They Work

**Example** (`test_farm_ui.sh`):
```bash
#!/bin/bash
echo "🎮 Testing Quantum Farm UI..."
timeout 30 godot --path .. scenes/FarmView.tscn 2>&1 &
wait $PID
```

**Characteristics**:
- Launches Godot with a specific scene
- Runs for a timeout period or until closed
- User manually verifies visual elements
- Combines automation (launching) with manual verification

### Advantages

#### ✅ Visual Verification
- **Human judgment**: Can verify aesthetics, feel, animation quality
- **Subjective qualities**: "Does this feel good?" "Is it too chaotic?"
- **Integration**: Tests complete UI flow, not isolated components

**Example**: Testing entanglement line shimmer
```bash
# Script auto-plants wheat and creates entanglements
# Human verifies:
# - Are lines visible?
# - Do they shimmer nicely?
# - Is the animation smooth?
# - Does it look quantum-y?
```

#### ✅ Real User Experience
- Tests actual gameplay flow
- Catches issues with:
  - Input responsiveness
  - UI layout problems
  - Visual glitches
  - Performance on real hardware

#### ✅ Quick Setup for Designers/Artists
- Non-programmers can run tests
- Simple shell scripts, no code knowledge needed
- Clear instructions in markdown guides

#### ✅ Perfect for UI/UX Iteration
```bash
# Make UI change → Run test → See result immediately
./test_farm_ui.sh
# No compilation, no unit test boilerplate
```

### Disadvantages

#### ❌ Not Fully Automated
- Requires human observation
- Can't run in CI/CD pipeline
- Results not automatically validated

#### ❌ Slow
- Each test launches full Godot instance
- Human observation takes time
- Can't run thousands of variations

#### ❌ Inconsistent Results
- Depends on human judgment
- Different testers may evaluate differently
- Hard to quantify "looks good"

#### ❌ No Physics Validation
- Can't verify quantum mechanics correctness
- Can't check energy conservation
- Can't validate Berry phase accumulation math

---

## Approach 2: GDScript Tests

### Location
```
Core/Tests/
├── test_quantum_substrate.gd   # Quantum physics tests (8 tests)
├── test_icon_system.gd          # Icon and Berry phase tests (11 tests)
└── QuantumNetworkVisualizer.gd  # Visual debugging (not automated)
```

### How They Work

**Example** (`test_berry_phase_tracking`):
```gdscript
func test_berry_phase_tracking():
    var node = TomatoNode.new()
    node.enable_berry_phase_tracking()

    # Evolve through a path
    for i in range(100):
        node.theta = float(i) / 100.0 * PI
        node.evolve(0.01)

    # Verify Berry phase accumulated
    assert_true(abs(node.berry_phase) > 0.01, "Berry phase accumulated")
```

**Characteristics**:
- Runs in headless Godot
- Programmatic assertions
- Fast execution (milliseconds per test)
- Deterministic results

### Advantages

#### ✅ Fully Automated
- Runs without human intervention
- Can integrate into CI/CD
- Run on every commit
- Catch regressions immediately

**Example CI workflow**:
```yaml
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: godot --headless --script Core/Tests/test_quantum_substrate.gd
      - run: godot --headless --script Core/Tests/test_icon_system.gd
```

#### ✅ Fast
- 19 tests run in ~2 seconds
- No GUI overhead
- Can run thousands of variations
- Enables property-based testing

**Performance comparison**:
```
Bash test:    30-60 seconds (human observation)
GDScript test: 0.1-0.5 seconds per test
```

#### ✅ Physics Validation
- Verifies quantum mechanics math
- Checks energy conservation
- Validates Berry phase calculations
- Tests Bloch sphere operations

**Example**: Energy conservation test
```gdscript
func test_energy_conservation():
    var initial_energy = network.get_total_energy()
    for i in range(1000):
        network.evolve_network(0.01)
    var final_energy = network.get_total_energy()

    var drift_percent = abs(final_energy - initial_energy) / initial_total * 100
    assert_true(drift_percent < 50.0, "Energy conserved")
```

This is **impossible to verify visually** - requires mathematical assertions.

#### ✅ Regression Prevention
- Tests lock in correct behavior
- Future changes can't break physics
- Refactoring confidence

**Example**: If someone accidentally changes the Berry phase formula:
```gdscript
# Before (correct):
berry_phase += solid_angle / 2.0

# After (broken):
berry_phase += solid_angle  # Forgot the /2!
```
The test immediately catches this:
```
❌ FAILED: Berry phase accumulated (got 6.283, expected 3.142)
```

#### ✅ Documentation
- Tests serve as usage examples
- Show how to use APIs correctly
- Living documentation that's always up-to-date

### Disadvantages

#### ❌ No Visual Verification
- Can't test "does it look good?"
- Can't verify animation quality
- Can't check UI layout

#### ❌ Integration Gaps
- Tests isolated components
- May miss issues in component interaction
- UI bugs slip through

**Example**: Icon system works perfectly in tests, but:
```
# Test passes ✓
func test_icon_modulation():
    icon.modulate_node_evolution(node, 0.1)
    assert_true(node.theta changed)

# But in actual game ✗
# - Icon activation is never updated
# - Icons are never added to network
# - Code is correct but not integrated
```

#### ❌ Requires Programming Knowledge
- Need to understand GDScript
- Must write assertions correctly
- Steeper learning curve for non-programmers

#### ❌ False Positives
- Test may pass but game still broken
- Can test the wrong thing
- Requires careful test design

---

## Comparison Matrix

| Aspect | Bash/Shell Tests | GDScript Tests |
|--------|------------------|----------------|
| **Speed** | Slow (30-60s) | Fast (<1s per test) |
| **Automation** | Partial | Full |
| **Visual Verification** | ✓ Excellent | ✗ None |
| **Physics Validation** | ✗ None | ✓ Excellent |
| **CI/CD Integration** | ✗ Difficult | ✓ Easy |
| **User Experience Testing** | ✓ Good | ✗ Poor |
| **Regression Detection** | ✗ Weak | ✓ Strong |
| **Learning Curve** | Easy | Moderate |
| **Iteration Speed** | Fast for UI | Fast for logic |
| **Coverage** | UI/UX | Physics/Logic |

---

## Best Practices: When to Use Each

### Use Bash/Shell Tests For:

✅ **Visual features**
```bash
# Good use cases:
./test_entanglement_viz.sh  # Verify shimmer effect
./test_visual_effects.sh    # Check particle animations
./test_farm_ui.sh           # Verify layout and colors
```

✅ **UX flow testing**
```bash
# Test complete user journeys:
# 1. Plant wheat
# 2. Create entanglement
# 3. Harvest
# 4. Verify credits updated
```

✅ **Performance on target hardware**
```bash
# Run on actual touchscreen device
# Check for:
# - Frame rate
# - Touch responsiveness
# - Battery impact
```

✅ **Designer/artist workflow**
```bash
# Quick visual iteration:
# Edit particle effect → ./test.sh → See result
```

### Use GDScript Tests For:

✅ **Quantum physics correctness**
```gdscript
test_energy_conservation()
test_bloch_sphere_operations()
test_berry_phase_on_circle()
test_icon_modulation()
```

✅ **Regression prevention**
```gdscript
# After fixing a bug, add test:
func test_entanglement_limit():
    # Ensure max 3 entanglements per plot
    # This bug should never return
```

✅ **API contracts**
```gdscript
func test_dual_emoji_creation():
    var qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
    assert_true(qubit.north_emoji == "🌾")
    # Guarantees API won't change unexpectedly
```

✅ **Mathematical validation**
```gdscript
func test_icon_coupling_strengths():
    var biotic = BioticFluxIcon.new()
    assert_approx(biotic.get_coupling("seed"), 0.8)
    # Exact values must be correct
```

---

## Recommended Workflow

### During Development

**Phase 1: Core Logic** (Use GDScript tests)
```
1. Write failing test
2. Implement feature
3. Test passes ✓
4. Refactor with confidence
```

**Phase 2: UI Integration** (Use Bash tests)
```
1. Integrate logic into UI
2. Run bash test to verify visuals
3. Adjust UI based on feel
4. Iterate until it feels right
```

**Phase 3: Polish** (Use both)
```
GDScript: Ensure physics still correct
Bash: Verify polish didn't break UX
```

### Before Committing

```bash
# Run all automated tests
godot --headless --script Core/Tests/test_quantum_substrate.gd
godot --headless --script Core/Tests/test_icon_system.gd

# If physics tests pass, manually verify UI
cd tests
./test_farm_ui.sh
```

### During Code Review

**Reviewer checklist**:
- [ ] Are there GDScript tests for new physics/logic?
- [ ] Are there bash tests or guides for new UI features?
- [ ] Do existing tests still pass?
- [ ] Is test coverage adequate?

---

## Hybrid Approach: Best of Both Worlds

### Automated Visual Tests (Future)

We could combine both approaches:

```bash
# test_automated_visuals.sh
godot --headless --script test_screenshot_comparison.gd

# test_screenshot_comparison.gd
func _ready():
    var farm = preload("FarmView.tscn").instantiate()
    add_child(farm)

    await get_tree().process_frame

    var screenshot = get_viewport().get_texture().get_image()
    var reference = load("res://tests/reference_images/farm_layout.png")

    var similarity = compare_images(screenshot, reference)
    assert_true(similarity > 0.95, "Visual regression detected")
```

**Advantages**:
- Automated visual regression detection
- Fast feedback
- No human observation needed

**Disadvantages**:
- Fragile (breaks on tiny visual changes)
- Setup complexity
- Hard to maintain reference images

---

## Conclusion

Both testing approaches are **essential and complementary**:

### Bash/Shell Tests
- **Strength**: Visual verification, UX testing, designer-friendly
- **Weakness**: Slow, manual, not automated

### GDScript Tests
- **Strength**: Fast, automated, physics validation, regression prevention
- **Weakness**: No visual verification, integration gaps

### Recommended Strategy

**Use Both**:
1. **GDScript tests** for all physics/logic/math
2. **Bash tests** for visual features and UX flows
3. **Documentation tests** (markdown guides) for manual QA

**Coverage goal**:
- 100% of quantum physics logic → GDScript tests
- 100% of visual features → Bash tests + manual verification
- Critical paths → Both types of tests

This dual approach ensures both **correctness** (GDScript) and **quality** (Bash) without compromise.

---

## Current Test Coverage

### GDScript Tests (19 tests total)
```
test_quantum_substrate.gd:
  ✅ Node creation
  ✅ Bloch sphere operations
  ✅ Energy calculation
  ✅ Node evolution
  ✅ Network initialization
  ✅ Energy diffusion
  ✅ Energy conservation
  ✅ Conspiracy activation

test_icon_system.gd:
  ✅ Icon creation
  ✅ Icon modulation
  ✅ Icon network integration
  ✅ Berry phase tracking
  ✅ Berry phase on circles
  ✅ DualEmojiQubit creation
  ✅ DualEmojiQubit measurement
  ✅ DualEmojiQubit gates
  ✅ DualEmojiQubit Berry phase
```

### Bash Tests (2 scripts + 2 guides)
```
test_farm_ui.sh:
  Manual verification of:
  - 5x5 grid layout
  - Credits/wheat display
  - Action buttons
  - Plot interactions

test_entanglement_viz.sh:
  Automated setup + manual verification:
  - Auto-plants 2x2 wheat grid
  - Creates entanglements
  - Human verifies shimmer effect

test_manual_entanglement.md:
  Step-by-step guide for:
  - Creating entanglements
  - Verifying line visualization
  - Testing limits

test_visual_effects.md:
  Comprehensive visual checklist:
  - Plant effects (🌱)
  - Harvest effects (✂️)
  - Entanglement effects (🔗)
  - Measurement effects (👁️)
```

**Combined Coverage**: Strong foundation for both correctness and quality! 🎯
