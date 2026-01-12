# Semantic Topology Implementation Roadmap

**Date**: 2026-01-08
**Scope**: Implement features 1, 2, 3, 4, 6 from Semantic Revolution vision
**Excluded**: Cross-biome entanglement (explicitly prevented)

---

## Feature Overview

| # | Feature | Priority | Duration | Dependencies |
|---|---------|----------|----------|--------------|
| 1 | Strange Attractor Analysis | 🔴 HIGH | 3 days | None |
| 2 | Fiber Bundles | 🟡 MEDIUM | 4 days | Feature 1 |
| 3 | Sparks System | 🔴 HIGH | 3 days | None |
| 4 | Semantic Uncertainty | 🟡 MEDIUM | 2 days | Feature 1 |
| 6 | Symplectic Conservation | 🟢 LOW | 2 days | None |
| X | Cross-Biome Prevention | 🔴 HIGH | 1 day | None |

**Total Duration**: ~15 days (3 weeks)

---

## Implementation Order (Dependency-Optimized)

### Week 1: Foundation
- **Day 1-3**: Feature 1 (Strange Attractor) + Feature X (Prevention)
- **Day 4-5**: Feature 3 (Sparks System)

### Week 2: Semantic Layer
- **Day 6-9**: Feature 2 (Fiber Bundles)
- **Day 10**: Feature 4 (Uncertainty Principle)

### Week 3: Polish
- **Day 11-12**: Feature 6 (Symplectic Conservation)
- **Day 13-15**: Integration testing + documentation

---

## Feature 1: Strange Attractor Analysis

### Goal
Record biome phase space trajectories and classify attractor personalities to give each civilization unique topological identity.

### Files to Create
```
Core/QuantumSubstrate/StrangeAttractorAnalyzer.gd         # NEW - Core analyzer
Core/Visualization/AttractorVisualizer3D.gd               # NEW - 3D trajectory plot
UI/Panels/AttractorPersonalityPanel.gd                    # NEW - Shows personality
Tests/test_strange_attractor.gd                           # NEW - Unit tests
```

### Files to Modify
```
Core/Environment/BiomeBase.gd                             # MODIFY - Add attractor_analyzer
Core/QuantumSubstrate/QuantumBath.gd                      # MODIFY - Hook recording
UI/PlayerShell.gd                                         # MODIFY - Add attractor UI
```

### Implementation Details

#### StrangeAttractorAnalyzer.gd
```gdscript
class_name StrangeAttractorAnalyzer
extends RefCounted

## Records phase space trajectory and classifies attractor personality
##
## Architecture:
## - Records Observable Vector3(emoji1, emoji2, emoji3) each evolution step
## - Maintains rolling window of last 1000-2000 points
## - Computes attractor signature every N frames
## - Classifies personality: "stable", "cyclic", "chaotic", "explosive"

# Configuration
var selected_emojis: Array[String] = []  # 3 emojis for phase space axes
var max_trajectory_length: int = 1500
var signature_update_interval: int = 60  # frames

# State
var trajectory: Array[Vector3] = []
var current_signature: Dictionary = {}
var frames_since_update: int = 0

# Cached metrics
var _cached_centroid: Vector3 = Vector3.ZERO
var _cached_spread: float = 0.0
var _cached_periodicity: float = 0.0
var _cached_lyapunov: float = 0.0

## ========================================
## Public API
## ========================================

func initialize(emoji_axes: Array[String]):
    """Set which 3 emojis define the phase space axes"""
    assert(emoji_axes.size() == 3, "Must provide exactly 3 emojis for axes")
    selected_emojis = emoji_axes
    trajectory.clear()
    print("📊 StrangeAttractorAnalyzer: Tracking %s" % str(emoji_axes))

func record_snapshot(observables: Dictionary):
    """Record current state as point in phase space"""
    if selected_emojis.is_empty():
        push_warning("StrangeAttractorAnalyzer: No emojis selected")
        return

    var point = Vector3(
        observables.get(selected_emojis[0], 0.0),
        observables.get(selected_emojis[1], 0.0),
        observables.get(selected_emojis[2], 0.0)
    )

    trajectory.append(point)

    # Maintain rolling window
    if trajectory.size() > max_trajectory_length:
        trajectory.pop_front()

    # Periodically update signature
    frames_since_update += 1
    if frames_since_update >= signature_update_interval:
        frames_since_update = 0
        _update_signature()

func get_signature() -> Dictionary:
    """Get current attractor signature (cached)"""
    return current_signature

func get_personality() -> String:
    """Get classified personality: stable/cyclic/chaotic/explosive"""
    return current_signature.get("personality", "unknown")

func get_trajectory() -> Array[Vector3]:
    """Get raw trajectory data (for visualization)"""
    return trajectory

## ========================================
## Analysis Functions
## ========================================

func _update_signature():
    """Compute attractor signature from trajectory"""
    if trajectory.size() < 100:
        current_signature = {"status": "insufficient_data", "personality": "unknown"}
        return

    # Compute metrics
    _cached_centroid = _compute_centroid()
    _cached_spread = _compute_spread()
    _cached_periodicity = _detect_periodicity()
    _cached_lyapunov = _estimate_lyapunov_exponent()

    # Classify personality
    var personality = _classify_personality()

    current_signature = {
        "personality": personality,
        "centroid": _cached_centroid,
        "spread": _cached_spread,
        "periodicity": _cached_periodicity,
        "lyapunov_exponent": _cached_lyapunov,
        "trajectory_length": trajectory.size()
    }

func _compute_centroid() -> Vector3:
    """Compute center of mass of trajectory"""
    if trajectory.is_empty():
        return Vector3.ZERO

    var sum = Vector3.ZERO
    for point in trajectory:
        sum += point
    return sum / float(trajectory.size())

func _compute_spread() -> float:
    """Compute average distance from centroid (measure of volatility)"""
    if trajectory.size() < 2:
        return 0.0

    var centroid = _cached_centroid
    var sum_dist = 0.0
    for point in trajectory:
        sum_dist += point.distance_to(centroid)
    return sum_dist / float(trajectory.size())

func _detect_periodicity() -> float:
    """Detect periodic patterns via autocorrelation

    Returns: Periodicity score (0.0 = chaotic, 1.0 = perfect cycle)
    """
    if trajectory.size() < 50:
        return 0.0

    # Simple autocorrelation at lag = trajectory.size() / 4
    var lag = int(trajectory.size() / 4.0)
    if lag < 10:
        return 0.0

    var correlation = 0.0
    var count = 0
    for i in range(trajectory.size() - lag):
        var dist = trajectory[i].distance_to(trajectory[i + lag])
        correlation += 1.0 / (1.0 + dist)  # Closer points = higher correlation
        count += 1

    return correlation / float(count)

func _estimate_lyapunov_exponent() -> float:
    """Estimate largest Lyapunov exponent (chaos indicator)

    Returns:
        < 0.0 = stable (fixed point)
        ~ 0.0 = cyclic (limit cycle)
        > 0.0 = chaotic (strange attractor)
    """
    if trajectory.size() < 100:
        return 0.0

    # Simplified estimation: measure average divergence rate
    var divergence_samples: Array[float] = []
    var sample_interval = 10  # Compare points 10 steps apart

    for i in range(50, trajectory.size() - sample_interval):
        var p1 = trajectory[i]
        var p2 = trajectory[i + sample_interval]
        var dist = p1.distance_to(p2)

        if dist > 0.001:  # Avoid log(0)
            divergence_samples.append(log(dist))

    if divergence_samples.is_empty():
        return 0.0

    # Average log divergence
    var sum = 0.0
    for d in divergence_samples:
        sum += d

    return sum / (float(divergence_samples.size()) * sample_interval)

func _classify_personality() -> String:
    """Classify attractor based on metrics"""
    var lyapunov = _cached_lyapunov
    var spread = _cached_spread
    var periodicity = _cached_periodicity

    # Explosive: growing rapidly
    if spread > 2.0 or lyapunov > 0.5:
        return "explosive"

    # Chaotic: positive Lyapunov, low periodicity
    if lyapunov > 0.05 and periodicity < 0.3:
        return "chaotic"

    # Cyclic: high periodicity, low Lyapunov
    if periodicity > 0.6 and lyapunov < 0.05:
        return "cyclic"

    # Stable: negative Lyapunov, converging to fixed point
    if lyapunov < -0.05 or spread < 0.2:
        return "stable"

    # Default
    return "irregular"

## ========================================
## Personality Descriptions
## ========================================

static func get_personality_description(personality: String) -> String:
    """Get human-readable description of personality type"""
    match personality:
        "stable":
            return "Stable equilibrium - converges to fixed state"
        "cyclic":
            return "Rhythmic cycles - predictable oscillations"
        "chaotic":
            return "Strange attractor - complex, sensitive dynamics"
        "explosive":
            return "Explosive growth - rapidly expanding"
        "irregular":
            return "Irregular dynamics - transitional behavior"
        _:
            return "Unknown dynamics"

static func get_personality_color(personality: String) -> Color:
    """Get color coding for personality type"""
    match personality:
        "stable":
            return Color.STEEL_BLUE
        "cyclic":
            return Color.MEDIUM_PURPLE
        "chaotic":
            return Color.ORANGE_RED
        "explosive":
            return Color.RED
        "irregular":
            return Color.YELLOW
        _:
            return Color.WHITE
```

#### Integration into BiomeBase
```gdscript
# In BiomeBase.gd

var attractor_analyzer: StrangeAttractorAnalyzer = null

func _initialize_attractor_tracking():
    """Initialize strange attractor analysis for this biome"""
    attractor_analyzer = StrangeAttractorAnalyzer.new()

    # Choose 3 key emojis for this biome's phase space
    var key_emojis = _select_key_emojis_for_attractor()
    attractor_analyzer.initialize(key_emojis)

    print("📊 %s: Attractor tracking %s" % [biome_name, str(key_emojis)])

func _select_key_emojis_for_attractor() -> Array[String]:
    """Choose 3 most important emojis for this biome's phase space

    Override in subclasses for biome-specific selection.
    Default: pick first 3 from emoji_list.
    """
    var emojis: Array[String] = []

    if bath and bath.emoji_list.size() >= 3:
        for i in range(3):
            emojis.append(bath.emoji_list[i])

    return emojis

func _physics_process(dt: float):
    # ... existing evolution code ...

    # NEW: Record attractor trajectory
    if attractor_analyzer and bath:
        var observables = bath.get_all_populations()
        attractor_analyzer.record_snapshot(observables)
```

### Success Criteria
- ✅ Can record trajectory for 3+ biomes
- ✅ Different biomes show different personalities
- ✅ Classification matches visual inspection
- ✅ UI shows personality in real-time

---

## Feature X: Cross-Biome Entanglement Prevention

### Goal
**EXPLICITLY PREVENT** entanglement from spanning multiple biomes. Each biome is an isolated quantum system.

### Files to Modify
```
Core/GameMechanics/FarmGrid.gd                            # MODIFY - Validation
Core/QuantumSubstrate/QuantumComputer.gd                  # MODIFY - Assertion
UI/FarmInputHandler.gd                                    # MODIFY - Block entangle action
```

### Implementation

#### Validation in Entanglement Creation
```gdscript
# In FarmGrid.gd

func create_entanglement(plot_a: BasePlot, plot_b: BasePlot, strength: float = 1.0) -> bool:
    """Create entanglement between two plots

    CRITICAL: Both plots MUST be in same biome. Cross-biome entanglement is FORBIDDEN.
    """
    # Validation: Same biome check
    if plot_a.assigned_biome_id != plot_b.assigned_biome_id:
        push_warning("❌ FORBIDDEN: Cannot entangle plots from different biomes!")
        push_warning("   Plot A biome: %s" % plot_a.assigned_biome_id)
        push_warning("   Plot B biome: %s" % plot_b.assigned_biome_id)
        return false

    if plot_a.assigned_biome_id == "":
        push_warning("❌ Cannot entangle plots with no biome assignment")
        return false

    # ... rest of entanglement logic ...
    print("✓ Entanglement created within biome: %s" % plot_a.assigned_biome_id)
    return true

func validate_entanglement_network() -> bool:
    """Verify no cross-biome entanglements exist (assertion check)"""
    for plot_id in plots:
        var plot = plots[plot_id]
        if not plot.has("entangled_plots"):
            continue

        for partner_id in plot.entangled_plots.keys():
            if not plots.has(partner_id):
                continue
            var partner = plots[partner_id]

            # Check biome match
            if plot.assigned_biome_id != partner.assigned_biome_id:
                push_error("🚨 CRITICAL: Cross-biome entanglement detected!")
                push_error("   Plot %s (biome: %s) entangled with Plot %s (biome: %s)" % [
                    plot_id, plot.assigned_biome_id,
                    partner_id, partner.assigned_biome_id
                ])
                return false

    return true
```

#### UI Feedback
```gdscript
# In FarmInputHandler.gd - action_e for Tool 2 (Quantum)

func _handle_entangle_batch():
    """Create entanglement between selected plots"""
    if selected_plots.size() < 2:
        _show_message("Select 2+ plots to entangle")
        return

    # NEW: Check all plots are in same biome
    var first_biome = selected_plots[0].assigned_biome_id
    for plot in selected_plots:
        if plot.assigned_biome_id != first_biome:
            _show_message("❌ Cannot entangle plots from different biomes!")
            _show_message("All plots must be in same biome")
            return

    # Proceed with entanglement...
```

### Testing
```gdscript
# In Tests/test_cross_biome_prevention.gd

func test_cross_biome_entanglement_forbidden():
    print("TEST: Cross-Biome Entanglement Prevention")

    var farm_grid = FarmGrid.new()

    # Create two plots in different biomes
    var plot_a = FarmPlot.new()
    plot_a.assigned_biome_id = "biotic_flux"

    var plot_b = FarmPlot.new()
    plot_b.assigned_biome_id = "market"

    # Attempt to entangle (should fail)
    var success = farm_grid.create_entanglement(plot_a, plot_b)

    assert_false(success, "Cross-biome entanglement should be forbidden")
    print("  ✓ Cross-biome entanglement correctly prevented\n")
```

---

## Feature 2: Fiber Bundles (Context-Aware Actions)

### Goal
Make tool actions context-dependent based on semantic position (which "octant" of phase space you're in).

### Files to Create
```
Core/QuantumSubstrate/FiberBundle.gd                      # NEW - Bundle system
Core/QuantumSubstrate/SemanticOctant.gd                   # NEW - Octant detector
UI/Panels/SemanticContextIndicator.gd                     # NEW - Shows current octant
Tests/test_fiber_bundle.gd                                # NEW - Unit tests
```

### Files to Modify
```
Core/GameState/ToolConfig.gd                              # MODIFY - Add fiber bundles
UI/FarmInputHandler.gd                                    # MODIFY - Context-aware actions
UI/Panels/ActionPreviewRow.gd                             # MODIFY - Show context variants
```

### Implementation

#### SemanticOctant.gd
```gdscript
class_name SemanticOctant
extends RefCounted

## Semantic Octant Detector
## Divides 3D phase space into named semantic regions

enum Region {
    PHOENIX,    # High energy, high growth, high wealth
    SAGE,       # Low energy, stable growth, wisdom focus
    WARRIOR,    # High conflict, high movement
    MERCHANT,   # High wealth, high trade
    ASCETIC,    # Low everything, minimalist
    GARDENER,   # Balanced growth, harmony
    INNOVATOR,  # High chaos, experimentation
    GUARDIAN    # Defensive, protective
}

static func detect_region(position: Vector3) -> Region:
    """Detect which semantic octant position is in

    Args:
        position: Point in phase space (normalized 0-1 on each axis)

    Returns:
        Region enum
    """
    # Simple octant division based on axes
    # Axis 0 = Energy/Activity
    # Axis 1 = Growth/Stability
    # Axis 2 = Wealth/Resources

    var high_energy = position.x > 0.5
    var high_growth = position.y > 0.5
    var high_wealth = position.z > 0.5

    # 8 octants mapped to semantic regions
    if high_energy and high_growth and high_wealth:
        return Region.PHOENIX
    elif not high_energy and high_growth and not high_wealth:
        return Region.SAGE
    elif high_energy and not high_growth and high_wealth:
        return Region.MERCHANT
    elif high_energy and not high_growth and not high_wealth:
        return Region.WARRIOR
    elif not high_energy and not high_growth and not high_wealth:
        return Region.ASCETIC
    elif not high_energy and high_growth and high_wealth:
        return Region.GARDENER
    elif high_energy and high_growth and not high_wealth:
        return Region.INNOVATOR
    else:  # not high_energy and not high_growth and high_wealth
        return Region.GUARDIAN

static func get_region_name(region: Region) -> String:
    match region:
        Region.PHOENIX: return "Phoenix"
        Region.SAGE: return "Sage"
        Region.WARRIOR: return "Warrior"
        Region.MERCHANT: return "Merchant"
        Region.ASCETIC: return "Ascetic"
        Region.GARDENER: return "Gardener"
        Region.INNOVATOR: return "Innovator"
        Region.GUARDIAN: return "Guardian"
        _: return "Unknown"

static func get_region_description(region: Region) -> String:
    match region:
        Region.PHOENIX:
            return "High energy, rapid growth, abundant resources"
        Region.SAGE:
            return "Calm wisdom, patient growth, spiritual focus"
        Region.WARRIOR:
            return "High conflict, aggressive expansion"
        Region.MERCHANT:
            return "Trade focus, wealth accumulation"
        Region.ASCETIC:
            return "Minimalist, conservative, preservation"
        Region.GARDENER:
            return "Balanced cultivation, harmony"
        Region.INNOVATOR:
            return "Experimental, chaotic creativity"
        Region.GUARDIAN:
            return "Defensive, protective, resource hoarding"
        _:
            return ""

static func get_region_color(region: Region) -> Color:
    match region:
        Region.PHOENIX: return Color.ORANGE_RED
        Region.SAGE: return Color.STEEL_BLUE
        Region.WARRIOR: return Color.DARK_RED
        Region.MERCHANT: return Color.GOLD
        Region.ASCETIC: return Color.GRAY
        Region.GARDENER: return Color.FOREST_GREEN
        Region.INNOVATOR: return Color.PURPLE
        Region.GUARDIAN: return Color.DARK_SLATE_BLUE
        _: return Color.WHITE
```

#### FiberBundle.gd
```gdscript
class_name FiberBundle
extends RefCounted

## Fiber Bundle: Context-dependent action variants
## Each tool has a fiber bundle defining different behaviors per semantic region

var tool_id: int = -1
var base_actions: Dictionary = {}  # From ToolConfig
var context_variants: Dictionary = {}  # Region -> action_overrides

func _init(tid: int):
    tool_id = tid

func add_variant(region: SemanticOctant.Region, action_key: String, override: Dictionary):
    """Add context-specific variant for an action

    Args:
        region: Semantic region where this variant applies
        action_key: "Q", "E", or "R"
        override: Dictionary with keys to override (label, emoji, description, etc.)
    """
    if not context_variants.has(region):
        context_variants[region] = {}

    context_variants[region][action_key] = override

func get_action(action_key: String, current_region: SemanticOctant.Region) -> Dictionary:
    """Get action definition for current context

    Returns merged base action + context override
    """
    var action = base_actions.get(action_key, {}).duplicate(true)

    # Apply context override if exists
    if context_variants.has(current_region):
        var overrides = context_variants[current_region]
        if overrides.has(action_key):
            # Merge override into base
            for key in overrides[action_key]:
                action[key] = overrides[action_key][key]

    return action
```

#### Integration Example: Tool 1 (Grower) Context Variants
```gdscript
# In ToolConfig.gd or FarmInputHandler initialization

func _setup_grower_fiber_bundle() -> FiberBundle:
    """Setup context-aware plant actions for Tool 1 (Grower)"""
    var bundle = FiberBundle.new(1)
    bundle.base_actions = ToolConfig.TOOL_ACTIONS[1]

    # Phoenix region: Fire-resistant crops
    bundle.add_variant(SemanticOctant.Region.PHOENIX, "Q", {
        "label": "Plant (Phoenix Wheat)",
        "description": "Fire-resistant, fast-growing wheat",
        "emoji": "🔥🌾"
    })

    # Sage region: Wisdom crops
    bundle.add_variant(SemanticOctant.Region.SAGE, "Q", {
        "label": "Plant (Sage Wheat)",
        "description": "Slow-growing, high-quality spiritual wheat",
        "emoji": "📿🌾"
    })

    # Merchant region: Trade crops
    bundle.add_variant(SemanticOctant.Region.MERCHANT, "Q", {
        "label": "Plant (Trade Wheat)",
        "description": "High-value wheat optimized for trade",
        "emoji": "💰🌾"
    })

    return bundle
```

### Success Criteria
- ✅ Can detect semantic octant from phase space position
- ✅ Tool actions show different labels/effects in different octants
- ✅ UI indicates current semantic region
- ✅ Transitions between regions are smooth

---

## Feature 3: Sparks System (Energy Extraction)

### Goal
Add imaginary/real energy split and extraction mechanic - convert quantum potential into usable resources.

### Files to Create
```
Core/QuantumSubstrate/SparkConverter.gd                   # NEW - Extraction logic
UI/Panels/QuantumEnergyMeter.gd                           # NEW - Shows imaginary energy
Tests/test_spark_extraction.gd                            # NEW - Unit tests
```

### Files to Modify
```
Core/QuantumSubstrate/DensityMatrix.gd                    # MODIFY - Add imaginary energy
Core/GameState/ToolConfig.gd                              # MODIFY - Add Spark action to Tool 4
UI/FarmInputHandler.gd                                    # MODIFY - Handle spark extraction
```

### Implementation

#### Energy Split in DensityMatrix
```gdscript
# In DensityMatrix.gd

func compute_energy_split() -> Dictionary:
    """Split total energy into Real (diagonal) + Imaginary (off-diagonal)

    Real energy = observable populations (diagonal elements)
    Imaginary energy = quantum coherence (off-diagonal elements)

    Returns:
        {
            "real": float,      # Sum of diagonal probabilities
            "imaginary": float, # Sum of |off-diagonal| coherences
            "total": float,     # real + imaginary
            "coherence_ratio": float  # imaginary / total
        }
    """
    var real_energy = 0.0
    var imaginary_energy = 0.0

    var dim = dimension()

    # Real: sum of diagonal (populations)
    for i in range(dim):
        real_energy += get_element(i, i).re

    # Imaginary: sum of |off-diagonal| (coherences)
    for i in range(dim):
        for j in range(i + 1, dim):  # Upper triangle only
            var coherence = get_element(i, j)
            imaginary_energy += coherence.abs() * 2.0  # *2 for symmetry

    var total = real_energy + imaginary_energy
    var ratio = imaginary_energy / total if total > 0.0 else 0.0

    return {
        "real": real_energy,
        "imaginary": imaginary_energy,
        "total": total,
        "coherence_ratio": ratio
    }
```

#### SparkConverter
```gdscript
class_name SparkConverter
extends RefCounted

## Spark Converter: Extract energy from quantum potential
## Converts imaginary (coherence) energy into real (observable) energy
## Cost: Reduces quantum coherence (decoherence)

static func extract_spark(quantum_computer, target_emoji: String, extraction_fraction: float = 0.1) -> Dictionary:
    """Extract quantum potential as real observable

    Args:
        quantum_computer: QuantumComputer to extract from
        target_emoji: Which observable to boost
        extraction_fraction: How much imaginary to convert (0.0-1.0)

    Returns:
        {
            "success": bool,
            "extracted_amount": float,
            "new_population": float,
            "coherence_lost": float
        }
    """
    # Get current energy split
    var energy = quantum_computer.density_matrix.compute_energy_split()

    if energy.imaginary < 0.01:
        return {
            "success": false,
            "message": "Insufficient quantum potential to extract"
        }

    # Calculate extraction
    var extract_amount = energy.imaginary * extraction_fraction

    # Apply partial decoherence + population boost
    var result = _apply_extraction(quantum_computer, target_emoji, extract_amount)

    return {
        "success": true,
        "extracted_amount": extract_amount,
        "new_population": result.new_pop,
        "coherence_lost": result.coherence_lost
    }

static func _apply_extraction(qc, target_emoji: String, amount: float) -> Dictionary:
    """Internal: Apply extraction via partial measurement + re-injection"""

    # Step 1: Get target emoji index
    var emoji_list = qc.density_matrix.emoji_list
    var target_idx = emoji_list.find(target_emoji)
    if target_idx < 0:
        return {"new_pop": 0.0, "coherence_lost": 0.0}

    # Step 2: Apply dephasing to reduce coherences
    var dephasing_rate = amount * 2.0  # Convert to decoherence rate
    _apply_dephasing(qc.density_matrix, dephasing_rate)

    # Step 3: Inject population into target
    _inject_population(qc.density_matrix, target_idx, amount)

    var new_pop = qc.density_matrix.get_probability_by_index(target_idx)

    return {
        "new_pop": new_pop,
        "coherence_lost": amount
    }

static func _apply_dephasing(density_matrix, rate: float):
    """Reduce off-diagonal elements (decohere)"""
    var dim = density_matrix.dimension()
    var decay = exp(-rate)

    for i in range(dim):
        for j in range(i + 1, dim):
            var coherence = density_matrix.get_element(i, j)
            density_matrix.set_element(i, j, coherence.mul(decay))
            density_matrix.set_element(j, i, coherence.conjugate().mul(decay))

static func _inject_population(density_matrix, target_idx: int, amount: float):
    """Boost diagonal population element"""
    var current = density_matrix.get_element(target_idx, target_idx).re
    var new_val = min(1.0, current + amount)  # Cap at 1.0

    # Renormalize
    var total = 0.0
    var dim = density_matrix.dimension()
    for i in range(dim):
        total += density_matrix.get_element(i, i).re

    if total > 1.0:
        # Scale down all populations
        var scale = 1.0 / total
        for i in range(dim):
            var p = density_matrix.get_element(i, i).re * scale
            density_matrix.set_element(i, i, Complex.new(p, 0.0))
```

#### Tool 4 Integration: Energy Tap Action
```gdscript
# In ToolConfig.gd - Tool 4 (Biome Control)

# Add new Q-submenu action for spark extraction
const SUBMENUS = {
    # ... existing submenus ...

    "energy_tap": {
        "name": "Energy Tap",
        "emoji": "⚡",
        "parent_tool": 4,
        "actions": {
            "Q": {
                "action": "spark_extract",
                "label": "Extract Quantum Potential",
                "emoji": "⚡→💎",
                "target": "dynamic"  # Choose emoji to boost
            },
            "E": {
                "action": "spark_inspect",
                "label": "Inspect Energy Split",
                "emoji": "📊"
            },
            "R": {
                "action": "cancel_submenu",
                "label": "Cancel",
                "emoji": "❌"
            }
        }
    }
}
```

### Success Criteria
- ✅ Can measure imaginary vs real energy
- ✅ Extraction tool increases target observable
- ✅ Extraction reduces coherence (visible tradeoff)
- ✅ UI shows energy meter with real/imaginary split

---

## Feature 4: Semantic Uncertainty Principle

### Goal
Implement tradeoff: `precision × flexibility ≥ ℏ_semantic` - strategic choice between stable meanings and adaptive potential.

### Files to Create
```
Core/QuantumSubstrate/SemanticUncertainty.gd             # NEW - Uncertainty calculator
UI/Panels/UncertaintyMeter.gd                            # NEW - Shows precision/flexibility
Tests/test_uncertainty_principle.gd                      # NEW - Unit tests
```

### Files to Modify
```
Core/Environment/BiomeBase.gd                             # MODIFY - Track uncertainty
UI/PlayerShell.gd                                         # MODIFY - Add uncertainty UI
```

### Implementation

#### SemanticUncertainty.gd
```gdscript
class_name SemanticUncertainty
extends RefCounted

## Semantic Uncertainty Principle
## precision × flexibility ≥ ℏ_semantic
##
## Precision = How stable meanings are (low entropy)
## Flexibility = How easily state can change (high entropy)
##
## This creates strategic tension:
## - High precision → stable but rigid (hard to change)
## - High flexibility → adaptable but chaotic (meanings drift)

const PLANCK_SEMANTIC: float = 0.25  # Minimum uncertainty product

static func compute_uncertainty(density_matrix) -> Dictionary:
    """Calculate semantic uncertainty metrics

    Returns:
        {
            "precision": float,      # 1.0 - entropy (high = stable)
            "flexibility": float,    # entropy (high = adaptable)
            "product": float,        # precision × flexibility
            "satisfies_principle": bool  # product >= PLANCK_SEMANTIC
        }
    """
    # Precision = inverse of entropy (how "pure" the state is)
    var entropy = _compute_von_neumann_entropy(density_matrix)
    var max_entropy = log(density_matrix.dimension())

    var normalized_entropy = entropy / max_entropy if max_entropy > 0.0 else 0.0

    var precision = 1.0 - normalized_entropy  # High when entropy is low
    var flexibility = normalized_entropy      # High when entropy is high

    var product = precision * flexibility
    var satisfies = product >= PLANCK_SEMANTIC

    return {
        "precision": precision,
        "flexibility": flexibility,
        "product": product,
        "satisfies_principle": satisfies,
        "entropy": entropy
    }

static func _compute_von_neumann_entropy(density_matrix) -> float:
    """Compute Von Neumann entropy: S = -Tr(ρ log ρ)"""
    # Simplified: use diagonal approximation (population entropy)
    var entropy = 0.0
    var dim = density_matrix.dimension()

    for i in range(dim):
        var p = density_matrix.get_probability_by_index(i)
        if p > 1e-10:
            entropy -= p * log(p)

    return entropy

static func get_regime_description(precision: float, flexibility: float) -> String:
    """Describe current uncertainty regime"""
    if precision > 0.7:
        return "Crystallized (stable, rigid)"
    elif flexibility > 0.7:
        return "Fluid (chaotic, adaptable)"
    elif precision > 0.5 and flexibility > 0.5:
        return "Balanced (moderate stability + adaptability)"
    elif precision < 0.3:
        return "Diffuse (meaning drift)"
    else:
        return "Transitional"
```

### Success Criteria
- ✅ Can compute precision and flexibility from density matrix
- ✅ Product satisfies uncertainty principle
- ✅ UI shows current regime (crystallized/fluid/balanced)
- ✅ Player understands tradeoff

---

## Feature 6: Symplectic Conservation (Phase Space Area)

### Goal
Validate that Hamiltonian evolution preserves phase space area (symplectic geometry check).

### Files to Create
```
Core/QuantumSubstrate/SymplecticValidator.gd             # NEW - Area conservation check
Tests/test_symplectic_conservation.gd                    # NEW - Unit tests
```

### Files to Modify
```
Core/QuantumSubstrate/QuantumComputer.gd                 # MODIFY - Add validation hook
```

### Implementation

#### SymplecticValidator.gd
```gdscript
class_name SymplecticValidator
extends RefCounted

## Symplectic Geometry Validator
## Checks that Hamiltonian evolution preserves phase space volume
##
## Physics: Liouville's theorem states that Hamiltonian flow preserves
## phase space volume. This is a fundamental conservation law.
##
## For density matrices: Tr(ρ) = 1 is always preserved
## For pure states: ||ψ||² = 1 is always preserved
##
## This validator checks more subtle area conservation in reduced subspaces.

static func validate_evolution_step(density_before, density_after) -> Dictionary:
    """Check that evolution preserves required invariants

    Checks:
    1. Trace conservation: Tr(ρ) = 1
    2. Hermiticity: ρ = ρ†
    3. Positivity: all eigenvalues ≥ 0
    4. Phase space area (approximate)

    Returns:
        {
            "valid": bool,
            "trace_before": float,
            "trace_after": float,
            "trace_error": float,
            "hermitian": bool,
            "positive": bool
        }
    """
    var result = {
        "valid": true,
        "errors": []
    }

    # 1. Trace conservation
    var trace_before = _compute_trace(density_before)
    var trace_after = _compute_trace(density_after)
    var trace_error = abs(trace_after - trace_before)

    result["trace_before"] = trace_before
    result["trace_after"] = trace_after
    result["trace_error"] = trace_error

    if trace_error > 0.01:
        result.valid = false
        result.errors.append("Trace not conserved: %.4f → %.4f" % [trace_before, trace_after])

    # 2. Hermiticity check (after should still be Hermitian)
    var hermitian = _check_hermitian(density_after)
    result["hermitian"] = hermitian
    if not hermitian:
        result.valid = false
        result.errors.append("Density matrix not Hermitian after evolution")

    # 3. Positivity (eigenvalues ≥ 0)
    var positive = _check_positive(density_after)
    result["positive"] = positive
    if not positive:
        result.valid = false
        result.errors.append("Density matrix has negative eigenvalues")

    return result

static func _compute_trace(density_matrix) -> float:
    """Compute Tr(ρ)"""
    var trace = 0.0
    var dim = density_matrix.dimension()
    for i in range(dim):
        trace += density_matrix.get_element(i, i).re
    return trace

static func _check_hermitian(density_matrix) -> bool:
    """Check if ρ = ρ†"""
    var dim = density_matrix.dimension()
    for i in range(dim):
        for j in range(i + 1, dim):
            var ij = density_matrix.get_element(i, j)
            var ji = density_matrix.get_element(j, i)

            var diff = (ij.re - ji.re) ** 2 + (ij.im + ji.im) ** 2
            if diff > 0.001:
                return false
    return true

static func _check_positive(density_matrix) -> bool:
    """Check diagonal is non-negative (simplified positivity check)"""
    var dim = density_matrix.dimension()
    for i in range(dim):
        var p = density_matrix.get_element(i, i).re
        if p < -0.001:  # Small tolerance
            return false
    return true
```

#### Integration into QuantumComputer
```gdscript
# In QuantumComputer.gd

var enable_symplectic_validation: bool = false  # Toggle for performance

func evolve(dt: float):
    """Evolve quantum state by time step dt"""

    # Store pre-evolution state for validation
    var density_before = null
    if enable_symplectic_validation:
        density_before = density_matrix.duplicate()

    # ... existing evolution code ...

    # Validate after evolution
    if enable_symplectic_validation and density_before:
        var validation = SymplecticValidator.validate_evolution_step(
            density_before,
            density_matrix
        )

        if not validation.valid:
            push_warning("⚠️ Symplectic conservation violated:")
            for error in validation.errors:
                push_warning("  - %s" % error)
```

### Success Criteria
- ✅ Trace conserved within 1% tolerance
- ✅ Hermiticity preserved
- ✅ No negative eigenvalues
- ✅ Can toggle validation on/off for performance

---

## Integration Testing Plan

### Test 1: Full Pipeline Test
```gdscript
# In Tests/test_semantic_topology_integration.gd

func test_full_semantic_pipeline():
    """Test all 5 features working together"""

    # 1. Create biome with attractor tracking
    var biome = BioticFluxBiome.new()
    biome._initialize_attractor_tracking()

    # 2. Evolve for 10 seconds, record trajectory
    for i in range(600):  # 10 sec at 60fps
        biome._physics_process(1.0/60.0)

    # 3. Check attractor personality
    var signature = biome.attractor_analyzer.get_signature()
    assert_true(signature.has("personality"), "Should have personality")
    print("Biome personality: %s" % signature.personality)

    # 4. Detect semantic octant
    var observables = biome.bath.get_all_populations()
    var position = Vector3(
        observables.get("🌾", 0.0),
        observables.get("🍄", 0.0),
        observables.get("💰", 0.0)
    )
    var octant = SemanticOctant.detect_region(position)
    print("Current octant: %s" % SemanticOctant.get_region_name(octant))

    # 5. Check uncertainty principle
    var uncertainty = SemanticUncertainty.compute_uncertainty(biome.quantum_computer.density_matrix)
    assert_true(uncertainty.satisfies_principle, "Should satisfy uncertainty principle")
    print("Uncertainty: precision=%.2f, flexibility=%.2f" % [
        uncertainty.precision,
        uncertainty.flexibility
    ])

    # 6. Extract spark
    var spark_result = SparkConverter.extract_spark(
        biome.quantum_computer,
        "🌾",
        0.1
    )
    assert_true(spark_result.success, "Spark extraction should succeed")
    print("Extracted: %.3f quantum potential" % spark_result.extracted_amount)

    print("✅ Full semantic pipeline working!")
```

### Test 2: Cross-Biome Prevention
```gdscript
func test_cross_biome_entanglement_blocked():
    """Verify cross-biome entanglement is blocked"""

    var farm_grid = FarmGrid.new()

    var plot_a = FarmPlot.new()
    plot_a.assigned_biome_id = "biotic_flux"

    var plot_b = FarmPlot.new()
    plot_b.assigned_biome_id = "market"

    var success = farm_grid.create_entanglement(plot_a, plot_b)

    assert_false(success, "Cross-biome entanglement must be blocked")
    print("✅ Cross-biome prevention working!")
```

---

## Timeline Summary

| Week | Days | Features | Milestone |
|------|------|----------|-----------|
| 1 | 1-3 | Feature 1 + X | Attractor tracking + cross-biome prevention |
| 1 | 4-5 | Feature 3 | Spark extraction working |
| 2 | 6-9 | Feature 2 | Context-aware actions |
| 2 | 10 | Feature 4 | Uncertainty principle |
| 3 | 11-12 | Feature 6 | Symplectic validation |
| 3 | 13-15 | Integration | Full pipeline + docs |

**Total: 15 working days (3 weeks)**

---

## Success Metrics

### Technical
- ✅ All 5 features implemented and tested
- ✅ Cross-biome entanglement explicitly prevented
- ✅ Integration tests pass
- ✅ No performance regression

### Gameplay
- ✅ Players can see attractor personalities
- ✅ Context-aware actions feel meaningful
- ✅ Spark extraction creates interesting tradeoffs
- ✅ Uncertainty principle is understandable

### Vision Alignment
- ✅ Semantic topology is tangible and navigable
- ✅ Foundation ready for AI training
- ✅ Code is clean and extensible
