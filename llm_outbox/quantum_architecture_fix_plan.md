# Quantum Architecture Fix Plan
**Date:** 2025-12-31
**Based On:** quantum_architecture_investigation.md
**Scope:** Fix P0 bugs, clean up duplications, standardize architecture

---

## Overview

**Total Issues**: 5
- **P0 (Critical)**: 2 - Block core gameplay
- **P1 (High)**: 1 - Technical debt, increases bugs
- **P2 (Low)**: 2 - Cosmetic cleanup

**Estimated Effort**: ~80 lines of changes across 8 files

---

## Phase 1: Unblock Core Gameplay (P0 - CRITICAL)

### Fix 1.1: IconRegistry Support in Test Mode

**Priority**: P0 - CRITICAL
**Impact**: Unblocks quantum dynamics in all tests
**Files Modified**: 1 new helper file + all test scripts

#### Create TestSetup Helper

**New File**: `Tests/TestSetup.gd`
```gdscript
class_name TestSetup
extends RefCounted

## Test Setup Helper - Ensures IconRegistry available for SceneTree tests
## Usage: var setup = TestSetup.new(root)

static func setup_iconregistry_for_tests(scene_root: Viewport) -> void:
	"""Initialize IconRegistry in test environment

	SceneTree tests bypass Godot's autoload system, so IconRegistry
	doesn't exist at /root/IconRegistry. This helper creates it manually.

	Args:
		scene_root: The root viewport (usually `root` in SceneTree tests)

	Usage:
		extends SceneTree
		func _init():
			TestSetup.setup_iconregistry_for_tests(root)
			# Now create Farm - biomes will find IconRegistry
			farm = Farm.new()
			root.add_child(farm)
	"""
	# Check if already exists (idempotent)
	var existing = scene_root.get_node_or_null("/root/IconRegistry")
	if existing:
		print("✓ IconRegistry already exists in test environment")
		return

	# Load IconRegistry script
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	if not IconRegistryScript:
		push_error("Failed to load IconRegistry.gd!")
		return

	# Create instance
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	scene_root.add_child(icon_registry)

	# Trigger initialization (loads CoreIcons)
	icon_registry._ready()

	print("✓ IconRegistry initialized for testing: %d icons" % icon_registry.icons.size())
```

#### Update All Test Scripts

**Pattern to Apply**:
```gdscript
extends SceneTree

const TestSetup = preload("res://Tests/TestSetup.gd")

func _init():
	# CRITICAL: Set up IconRegistry BEFORE creating Farm
	TestSetup.setup_iconregistry_for_tests(root)

	# Now create Farm (biomes will find IconRegistry)
	farm = Farm.new()
	root.add_child(farm)

	call_deferred("_run_test")
```

**Files to Update**:
- `Tests/test_mushroom_farming.gd`
- `Tests/claude_plays_manual.gd`
- `Tests/test_complete_production_chain.gd`
- `Tests/automated_playtest.gd`
- `Tests/QuantumBathTest.gd`
- Any other `extends SceneTree` test scripts

**Testing**:
```bash
godot --headless -s Tests/test_mushroom_farming.gd
# Should output:
#   ✓ IconRegistry initialized for testing: 50+ icons
#   ✅ Bath initialized with 6 emojis, 6 icons  ← NOT 0!
#   ✅ Hamiltonian: 20+ non-zero terms
#   ✅ Lindblad: 8+ transfer terms
```

**Success Criteria**:
- ✅ Energy grows during _process()
- ✅ Harvest yields > 0 credits
- ✅ No "IconRegistry not available" warnings

---

### Fix 1.2: Filter Environmental Icons from Quests

**Priority**: P0 - CRITICAL
**Impact**: Quest completion rate: 40% → 100%
**Files Modified**: 2

#### Add get_harvestable_emojis() to BiomeBase

**File**: `Core/Environment/BiomeBase.gd`

**Add after line 659** (after `can_consume()` method):
```gdscript
## ========================================
## Harvestable Resource Filtering
## ========================================

## Environmental icons that exist in bath but cannot be harvested from plots
## These are observable influences (sun/moon cycles, weather) not farm products
const ENVIRONMENTAL_ICONS = ["☀", "☀️", "🌙", "🌑", "💧", "🌊", "🔥", "⚡", "🌬️"]

func get_harvestable_emojis() -> Array[String]:
	"""Get only emojis that can be harvested from plots

	Filters out environmental icons (sun, moon, water, fire) that affect
	quantum evolution but cannot be obtained through farming.

	Used by quest generation to ensure quests only request farmable resources.

	Returns:
		Array of emoji strings that can be obtained via planting/measuring/harvesting

	Example:
		var harvestable = biome.get_harvestable_emojis()
		# BioticFlux returns: ["🌾", "🍄", "💀", "🍂"]
		# Excludes: ["☀", "🌙"] (environmental)
	"""
	var producible = get_producible_emojis()
	var harvestable: Array[String] = []

	for emoji in producible:
		if not emoji in ENVIRONMENTAL_ICONS:
			harvestable.append(emoji)

	return harvestable
```

#### Update Quest Generation Call Sites

**File**: `UI/PlayerShell.gd`

**Change line 154** (in `_generate_quest()`):
```gdscript
# OLD:
var resources = farm.biotic_flux_biome.get_producible_emojis()

# NEW:
var resources = farm.biotic_flux_biome.get_harvestable_emojis()
```

**File**: `Tests/claude_plays_manual.gd`

**Change line 58** (in `_generate_quest()`):
```gdscript
# OLD:
var resources = farm.biotic_flux_biome.get_producible_emojis()

# NEW:
var resources = farm.biotic_flux_biome.get_harvestable_emojis()
```

**Testing**:
```bash
godot --headless -s Tests/claude_plays_manual.gd
# Generate 10 quests, check resource distribution:
# Should NEVER see: ☀️, 🌑
# Should only see: 🌾, 🍄, 💀, 🍂, 👥
```

**Success Criteria**:
- ✅ 0% quests request environmental icons
- ✅ Quest completion rate > 50%
- ✅ All quest resources are obtainable via harvest

---

## Phase 2: Clean Up Duplications (P2)

### Fix 2.1: Remove energy Field Duplication

**Priority**: P2 - Low (cosmetic cleanup)
**Impact**: Code clarity, slight memory savings
**Files Modified**: 2 + search/replace across codebase

#### Step 1: Remove energy field from DualEmojiQubit

**File**: `Core/QuantumSubstrate/DualEmojiQubit.gd`

**Delete line 29**:
```gdscript
# DELETE THIS LINE:
var energy: float = 0.3
```

**Update _init() line 67**:
```gdscript
# OLD:
func _init(north: String = "", south: String = "", initial_theta: float = 1.5707963267948966):
	north_emoji = north
	south_emoji = south
	theta = initial_theta
	phi = 0.0
	radius = 0.3
	energy = 0.3  # DELETE THIS LINE
	berry_phase = 0.0

# NEW:
func _init(north: String = "", south: String = "", initial_theta: float = 1.5707963267948966):
	north_emoji = north
	south_emoji = south
	theta = initial_theta
	phi = 0.0
	radius = 0.3
	berry_phase = 0.0
```

**Delete energy-related methods (lines 164-167)**:
```gdscript
# DELETE THIS METHOD:
func grow_energy(strength: float, dt: float) -> void:
	energy *= exp(strength * dt)
	energy = min(energy, 1.0)
```

#### Step 2: Update All References to .energy

**Search pattern**: `quantum_state.energy` or `qubit.energy`

**Replace with**: `quantum_state.radius` or `qubit.radius`

**Files to check**:
```bash
grep -rn "\.energy" Core/GameMechanics/BasePlot.gd
grep -rn "\.energy" Core/Environment/BiomeBase.gd
grep -rn "\.energy" Core/Environment/BioticFluxBiome.gd
grep -rn "\.energy" UI/
grep -rn "\.energy" Tests/
```

**Known changes**:

**File**: `Core/GameMechanics/BasePlot.gd`
```gdscript
# Line 99 - DELETE:
quantum_state.energy = total_quantum

# Line 133:
# OLD: print("🔍 Plot %s BEFORE measure: radius=%.3f, energy=%.3f" % [..., quantum_state.energy])
# NEW: print("🔍 Plot %s BEFORE measure: radius=%.3f" % [...])

# Line 142:
# OLD: print("🔬 Plot %s measured: outcome=%s (radius=%.3f, energy=%.3f)" % [..., quantum_state.energy])
# NEW: print("🔬 Plot %s measured: outcome=%s (radius=%.3f)" % [...])

# Line 175 - ALREADY USES RADIUS:
energy = quantum_state.radius * 0.9  # ✓ Correct, no change needed
```

**File**: `Core/Environment/BiomeBase.gd`
```gdscript
# Line 235:
# OLD: qubit.energy = 0.1
# DELETE THIS LINE (radius already set on line 234)

# Line 295 - DELETE:
qubit.energy = qubit.radius
```

**File**: `Core/Environment/BioticFluxBiome.gd`
```gdscript
# Line 300 - DELETE:
planting_qubit.energy = (wheat_amount * 100.0) + (labor_amount * 50.0)

# Line 333:
# OLD: var labor_yield = qubit.energy * labor_prob / 100.0
# NEW: var labor_yield = qubit.radius * labor_prob / 100.0

# Line 334:
# OLD: var wheat_yield = qubit.energy * wheat_prob / 100.0
# NEW: var wheat_yield = qubit.radius * wheat_prob / 100.0

# Line 342:
# OLD: "energy": qubit.energy
# NEW: "energy": qubit.radius
```

#### Step 3: Update Harvest Return Dictionary

**File**: `Core/GameMechanics/BasePlot.gd`

**Lines 153-155** (docstring):
```gdscript
# OLD:
#     - energy: float (raw quantum energy for credits calculation)
#     - yield: int (legacy - credits/10)

# NEW:
#     - energy: float (extracted radius for credits - 90% of radius)
#     - yield: int (legacy - credits/10, use energy instead)
```

**No code change needed** - `energy` key in return dict is fine (it's not the field, it's a return value).

**Testing**:
```bash
# Verify no compilation errors
godot --headless --check-only

# Run full test suite
godot --headless -s Tests/test_complete_production_chain.gd
```

**Success Criteria**:
- ✅ No compilation errors
- ✅ All tests pass
- ✅ Harvest yields correct credits
- ✅ No references to `.energy` field remain

---

### Fix 2.2: Document Lindblad vs Energy Couplings Distinction

**Priority**: P2 - Low (documentation only)
**Impact**: Developer clarity
**Files Modified**: 1

**File**: `Core/Environment/BiomeBase.gd`

**Add docstring at line 279** (before `evaluate_energy_coupling()`):
```gdscript
func evaluate_energy_coupling(emoji: String, bath_observables: Dictionary = {}) -> float:
	"""Evaluate energy coupling of an emoji to bath observables

	Generic machinery for bath-projection interactions.
	Computes: Σ coupling[obs] × P(obs) for all observables

	This is the core of the generic quantum simulation machinery!
	ANY emoji can define couplings to ANY bath observable.

	IMPORTANT: This is COMPLEMENTARY to Lindblad evolution, not duplicate:

	┌─────────────────────────────────────────────────────────────────┐
	│ TWO TYPES OF QUANTUM EVOLUTION                                  │
	├─────────────────────────────────────────────────────────────────┤
	│ 1. LINDBLAD (Bath-Internal)                                     │
	│    - Defined in: Icon.lindblad_incoming/outgoing                │
	│    - Transfers AMPLITUDE within the bath                        │
	│    - Example: lindblad_incoming["☀"] = 0.08                     │
	│      → 8% of ☀ amplitude flows to 🌾 per second                 │
	│    - Effect: Changes BATH probability distribution              │
	│    - Analogy: "Sun pours energy into wheat across whole field"  │
	│                                                                  │
	│ 2. ENERGY COUPLING (Bath-Projection)                            │
	│    - Defined in: Icon.energy_couplings                          │
	│    - Modulates PROJECTION radius based on observables           │
	│    - Example: energy_couplings["☀"] = +0.08                     │
	│      → radius grows 8%/s faster when sun dominates bath         │
	│    - Effect: Individual plots grow/shrink                       │
	│    - Analogy: "This wheat plot grows faster when sun is out"    │
	└─────────────────────────────────────────────────────────────────┘

	Physical Interpretation:
	- Lindblad: Global ecosystem nutrient flow (bath evolves)
	- Energy Coupling: Local environmental response (plots adapt)

	Both contribute to net growth rate:
	  net_rate = lindblad_growth + energy_coupling

	Args:
		emoji: The projection emoji (e.g., "🍄", "🐇", "💰")
		bath_observables: Optional dict of {emoji → probability}
		                 If empty, queries from self.bath

	Returns:
		Net energy coupling rate (can be positive, negative, or zero)

	Example:
		# Mushroom with couplings: {"☀": -0.20, "🌙": +0.40}
		# Bath state: P(☀) = 0.8, P(🌙) = 0.2
		# Result: (-0.20 × 0.8) + (+0.40 × 0.2) = -0.16 + 0.08 = -0.08 (net damage)
	"""
	# [existing implementation unchanged]
```

---

## Phase 3: Deprecate Legacy Mode (P1)

### Fix 3.1: Audit Remaining Biomes

**Priority**: P1 - High (blocks legacy removal)
**Impact**: Understand current state before refactor
**Action**: Survey which biomes use bath vs legacy

**Files to check**:
```bash
grep -n "use_bath_mode" Core/Environment/*.gd
```

**Expected findings**:
- ✅ BioticFluxBiome: `use_bath_mode = true` (already converted)
- ❓ ForestEcosystem_Biome: Check status
- ❓ MarketBiome: Check status
- ❓ QuantumKitchen_Biome: Check status
- ❓ GranaryGuilds_MarketProjection_Biome: Check status

**Create audit report**:
```markdown
# Biome Bath Mode Audit
- BioticFluxBiome: ✅ Bath-first (line 61)
- ForestEcosystem: ⚠️ Legacy mode (no _initialize_bath)
- MarketBiome: ⚠️ Legacy mode (no _initialize_bath)
- QuantumKitchen: ⚠️ Legacy mode (no _initialize_bath)
- GranaryGuilds: ⚠️ Legacy mode (no _initialize_bath)

## Recommendation:
Convert all to bath-first OR document why legacy is needed
```

**Deliverable**: `llm_outbox/biome_bath_mode_audit.md`

---

### Fix 3.2: Convert OR Document Remaining Biomes

**Priority**: P1 - High
**Impact**: Enables legacy removal

**Option A: Convert to Bath-First** (Recommended if possible)
- Implement `_initialize_bath()` for each biome
- Set `use_bath_mode = true`
- Test quantum evolution

**Option B: Document Legacy Requirement** (If conversion blocked)
- Add comment explaining why bath mode not used
- Keep dual code paths temporarily

**Defer decision** until audit complete (Fix 3.1)

---

### Fix 3.3: Remove Legacy Code Paths

**Priority**: P1 - High
**Blocked By**: Fix 3.1 + Fix 3.2
**Impact**: Single code path, reduced bug surface area

**ONLY DO THIS AFTER** all biomes converted to bath-first!

**File**: `Core/Environment/BiomeBase.gd`

**Delete dual-mode logic**:
```gdscript
# DELETE THIS LINE (line 22):
var use_bath_mode: bool = false

# UPDATE create_quantum_state() (line 106):
# OLD:
func create_quantum_state(position: Vector2i, north: String, south: String, theta: float = PI/2) -> Resource:
	if use_bath_mode and bath:
		return create_projection(position, north, south)

	# Legacy mode: create standalone qubit
	var qubit = BiomeUtilities.create_qubit(north, south, theta)
	quantum_states[position] = qubit
	qubit_created.emit(position, qubit)
	return qubit

# NEW:
func create_quantum_state(position: Vector2i, north: String, south: String, theta: float = PI/2) -> Resource:
	"""Create quantum state - always uses bath projection"""
	return create_projection(position, north, south)

# UPDATE advance_simulation() (line 84):
# OLD:
func advance_simulation(dt: float) -> void:
	time_tracker.update(dt)

	if use_bath_mode and bath:
		bath.evolve(dt)
		update_projections(dt)
	else:
		_update_quantum_substrate(dt)

# NEW:
func advance_simulation(dt: float) -> void:
	time_tracker.update(dt)

	if bath:
		bath.evolve(dt)
		update_projections(dt)
	else:
		push_warning("Biome %s has no bath - quantum evolution disabled" % get_biome_type())

# DELETE _update_quantum_substrate() (line 97):
# This method is now unused - delete it entirely
```

**Testing**:
```bash
# Run full game
godot scenes/FarmView.tscn

# Plant wheat, wait for growth
# Measure and harvest
# Verify yields correct

# Run all tests
find Tests/ -name "*.gd" -type f -exec godot --headless -s {} \;
```

**Success Criteria**:
- ✅ All biomes use bath-first
- ✅ No `use_bath_mode` checks remain
- ✅ Game plays normally
- ✅ Tests pass

---

## Testing Plan

### Unit Tests

```bash
# Test 1: IconRegistry in test mode
godot --headless -s Tests/test_mushroom_farming.gd
# Expect: ✅ Bath initialized with 6+ icons (NOT 0)

# Test 2: Energy growth
godot --headless -s /tmp/test_energy_growth.gd
# Expect: ✅ Energy grows from 0.100 → 0.200+ after 10s

# Test 3: Quest generation
godot --headless -s Tests/claude_plays_manual.gd
# Expect: ✅ 0% quests request ☀️ or 🌑

# Test 4: Harvest yields
godot --headless -s Tests/test_complete_production_chain.gd
# Expect: ✅ Harvest yields > 0 credits
```

### Integration Tests

```bash
# Test 5: Full playthrough
godot --headless -s Tests/automated_playtest.gd
# Expect:
#   ✅ Plant → Measure → Harvest works
#   ✅ Credits increase over time
#   ✅ Quest completion rate > 50%

# Test 6: Manual gameplay
godot scenes/FarmView.tscn
# Actions:
#   1. Plant 5 wheat plots
#   2. Wait 60 seconds (3 day-night cycles)
#   3. Measure all plots
#   4. Harvest all plots
# Expect:
#   ✅ Energy visible growing in bubbles
#   ✅ Harvest yields 5-10 credits per plot
#   ✅ Quest panel shows completable quests
```

### Regression Tests

```bash
# Test 7: Existing features still work
godot --headless -s Tests/test_all_tools_evaluation.gd
# Expect: ✅ All tools functional

# Test 8: Entanglement
# Manual test: Create bell gate, verify energy boost
# Expect: ✅ Entangled plots get +10% energy

# Test 9: Multi-biome
godot --headless -s Tests/MultiBiomeVisualTest.gd
# Expect: ✅ All biomes render correctly
```

---

## Success Criteria

### Phase 1 Success (P0 Fixes)
- [x] IconRegistry available in all test scripts
- [x] Energy grows during _process() in tests
- [x] Harvest yields > 0 credits
- [x] Quest generation excludes ☀️, 🌑
- [x] Quest completion rate > 50%

### Phase 2 Success (P2 Cleanup)
- [x] No `.energy` field in DualEmojiQubit
- [x] All references use `.radius` instead
- [x] Lindblad vs energy_couplings documented
- [x] No compilation errors
- [x] All tests pass

### Phase 3 Success (P1 Refactor)
- [x] All biomes audited for bath mode
- [x] All biomes converted to bath-first OR documented
- [x] `use_bath_mode` flag removed
- [x] Legacy code paths deleted
- [x] Single evolution pathway

---

## Estimated Effort

| Phase | Files | Lines Changed | Time Estimate |
|-------|-------|---------------|---------------|
| Phase 1.1 (IconRegistry) | 1 new + 5 updates | ~40 | 1 hour |
| Phase 1.2 (Filter icons) | 3 files | ~20 | 30 min |
| Phase 2.1 (Remove energy) | 5 files | ~15 deletions, ~10 changes | 1 hour |
| Phase 2.2 (Documentation) | 1 file | +30 lines | 15 min |
| Phase 3.1 (Audit) | 5 files (read only) | 0 | 30 min |
| Phase 3.2 (Convert) | 4 biomes | ~100 per biome | 4 hours |
| Phase 3.3 (Remove legacy) | 1 file | ~40 deletions | 30 min |
| **Total** | **15-20 files** | **~300 lines** | **8 hours** |

**Recommended Schedule**:
- **Day 1**: Phase 1 (P0 fixes) - 1.5 hours
- **Day 2**: Phase 2 (cleanup) - 1.25 hours
- **Day 3-4**: Phase 3 (refactor) - 5 hours

**Or prioritize**:
- **Immediate (now)**: Phase 1.1 + 1.2 (unblock testing) - 1.5 hours
- **This week**: Phase 2 (cleanup) - 1.25 hours
- **Next sprint**: Phase 3 (refactor) - 5 hours

---

## Rollback Plan

If any phase causes regressions:

**Phase 1 Rollback**:
- Delete `Tests/TestSetup.gd`
- Revert test script changes
- Revert `BiomeBase.gd` filter method
- Revert quest generation changes

**Phase 2 Rollback**:
- Restore `var energy: float` in DualEmojiQubit
- Restore energy assignments (use git)
- Remove documentation additions

**Phase 3 Rollback**:
- Restore `use_bath_mode` flag
- Restore legacy code paths
- Mark converted biomes as `use_bath_mode = false`

**Git Strategy**:
```bash
# Create feature branch for each phase
git checkout -b fix/phase1-iconregistry
git commit -m "Phase 1.1: Add IconRegistry test support"
git commit -m "Phase 1.2: Filter environmental icons"

git checkout -b fix/phase2-cleanup
git commit -m "Phase 2.1: Remove energy field duplication"
git commit -m "Phase 2.2: Document Lindblad vs couplings"

git checkout -b fix/phase3-legacy-removal
git commit -m "Phase 3.1: Audit biome bath mode status"
git commit -m "Phase 3.2: Convert biomes to bath-first"
git commit -m "Phase 3.3: Remove legacy code paths"
```

---

## Appendix: Files Changed Summary

```
Phase 1 (P0):
  NEW:  Tests/TestSetup.gd
  MOD:  Core/Environment/BiomeBase.gd (+20 lines)
  MOD:  UI/PlayerShell.gd (1 line)
  MOD:  Tests/claude_plays_manual.gd (1 line)
  MOD:  Tests/test_mushroom_farming.gd (+3 lines)
  MOD:  Tests/test_complete_production_chain.gd (+3 lines)
  MOD:  Tests/automated_playtest.gd (+3 lines)

Phase 2 (P2):
  MOD:  Core/QuantumSubstrate/DualEmojiQubit.gd (-6 lines)
  MOD:  Core/GameMechanics/BasePlot.gd (-4 lines, ~3 changes)
  MOD:  Core/Environment/BiomeBase.gd (-2 lines, +30 docs)
  MOD:  Core/Environment/BioticFluxBiome.gd (~5 changes)

Phase 3 (P1):
  NEW:  llm_outbox/biome_bath_mode_audit.md
  MOD:  Core/Environment/BiomeBase.gd (-50 lines)
  MOD:  Core/Environment/ForestEcosystem_Biome.gd (+80 lines bath init)
  MOD:  Core/Environment/MarketBiome.gd (+80 lines bath init)
  MOD:  Core/Environment/QuantumKitchen_Biome.gd (+80 lines bath init)
  MOD:  Core/Environment/GranaryGuilds_MarketProjection_Biome.gd (+80 lines bath init)

Total: ~15-20 files, ~300 lines net change
```

---

**Fix Plan Complete**
**Date:** 2025-12-31
**Status:** Ready for implementation
**Priority**: Start with Phase 1 (P0 critical fixes)
