# Quantum Quest System Implementation Plan

## Executive Summary

The **Quantum Quest System** transforms quests from classical resource gathering ("gather 10 wheat") into **quantum state engineering** ("prepare superposition with coherence > 0.8"). Players become quantum engineers manipulating the bath through projection placement, measurement timing, and Hamiltonian evolution.

### Core Innovation
Instead of targeting **classical resources** (🌾 × 10), quests target **quantum observables**:
- Bloch sphere coordinates (θ, φ, r)
- Coherence and entanglement
- Phase relationships
- Amplitude distributions
- Berry phase accumulation
- Interference patterns

---

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    QUANTUM QUEST SYSTEM                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Classical Quest (Current)         Quantum Quest (New)       │
│  ─────────────────────            ───────────────────        │
│  "Harvest 10 🌾"          →       "Prepare θ=π/2 with         │
│                                    coherence > 0.8"          │
│                                                               │
│  "Deliver 5 💧"           →       "Entangle 🌾↔🐺 to          │
│                                    Bell state fidelity>0.9"  │
│                                                               │
│  "Collect 3 🍄"           →       "Accumulate Berry phase     │
│                                    of π through cycle"       │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Core Quantum Types (Week 1-2)

### 1.1 QuantumObservable.gd
**Purpose**: Enum of measurable quantum properties

```gdscript
class_name QuantumObservable
extends Resource

# Single-Qubit Observables (from projection)
static var THETA = "theta"          # Polar angle [0, π]
static var PHI = "phi"              # Azimuthal phase [0, 2π]
static var RADIUS = "radius"        # Amplitude in subspace
static var COHERENCE = "coherence"  # sin(θ) - superposition strength

# Bath-Wide Observables
static var AMPLITUDE = "amplitude"  # |α_i| for specific emoji
static var PHASE = "phase"          # arg(α_i)
static var ENTROPY = "entropy"      # Shannon entropy
static var PURITY = "purity"        # Tr(ρ²)

# Multi-Qubit Observables
static var CORRELATION = "correlation"    # ⟨A⊗B⟩
static var ENTANGLEMENT = "entanglement"  # Bell state fidelity
static var PHASE_DIFFERENCE = "phase_diff"

# Topological Observables
static var BERRY_PHASE = "berry_phase"
static var WINDING_NUMBER = "winding"
```

**Dependencies**: None
**File**: `Core/Quests/QuantumObservable.gd`

### 1.2 QuantumOperation.gd
**Purpose**: Enum of player actions on quantum bath

```gdscript
class_name QuantumOperation
extends Resource

# Projection Operations
static var CREATE_PROJECTION = "create_projection"
static var REMOVE_PROJECTION = "remove_projection"
static var ROTATE_AXIS = "rotate_axis"

# Measurement Operations
static var WEAK_MEASURE = "weak_measure"      # Partial collapse
static var STRONG_MEASURE = "strong_measure"  # Full collapse
static var DELAYED_MEASURE = "delayed_measure"

# Unitary Operations
static var PHASE_SHIFT = "phase_shift"
static var HADAMARD = "hadamard"
static var ROTATION_X = "rotation_x"
static var ROTATION_Y = "rotation_y"
static var ROTATION_Z = "rotation_z"

# Two-Qubit Operations
static var BELL_ENTANGLE = "bell_entangle"
static var SWAP = "swap"

# Bath-Wide Operations
static var INJECT_AMPLITUDE = "inject_amplitude"
static var DRAIN_AMPLITUDE = "drain_amplitude"
static var REDISTRIBUTE = "redistribute"

# Icon Manipulations
static var ACTIVATE_ICON = "activate_icon"
static var MODULATE_ICON = "modulate_icon"

# Temporal Operations
static var EVOLVE = "evolve"
static var FREEZE = "freeze"
```

**Dependencies**: None
**File**: `Core/Quests/QuantumOperation.gd`

---

## Phase 2: Quantum Conditions (Week 2-3)

### 2.1 ComparisonOp.gd
**Purpose**: Mathematical comparison operators

```gdscript
class_name ComparisonOp
extends Resource

static var EQUALS = "="
static var APPROX = "≈"
static var LESS = "<"
static var GREATER = ">"
static var IN_RANGE = "∈"
static var NEAR = "~"
static var RESONANT = "∿"
static var ENTANGLED = "⊗"
```

### 2.2 QuantumCondition.gd
**Purpose**: Predicate on quantum observables

```gdscript
class_name QuantumCondition
extends Resource

var observable: String  # QuantumObservable constant
var comparison: String  # ComparisonOp constant
var target_value: float
var tolerance: float = 0.1
var emoji_target: String = ""  # For amplitude/phase
var emoji_pair: Array = []     # [north, south] for projection
var second_projection: Array = []  # For correlations

func describe() -> String:
    # "polar angle θ approximately 1.57"
    # "amplitude of 🌾 above 0.7"
    # "entanglement between 🌾↔🐺 near 0.9"
```

**Dependencies**: QuantumObservable, ComparisonOp
**File**: `Core/Quests/QuantumCondition.gd`

---

## Phase 3: Quantum Objectives (Week 3-4)

### 3.1 ObjectiveType.gd
**Purpose**: Categories of quantum objectives

```gdscript
class_name ObjectiveType
extends Resource

# State Preparation
static var PREPARE_STATE = "prepare_state"
static var PREPARE_SUPERPOSITION = "prepare_superposition"
static var PREPARE_EIGENSTATE = "prepare_eigenstate"

# Entanglement Tasks
static var CREATE_BELL_PAIR = "create_bell_pair"
static var MAINTAIN_ENTANGLEMENT = "maintain_entanglement"
static var TELEPORT_STATE = "teleport_state"

# Coherence Challenges
static var MAINTAIN_COHERENCE = "maintain_coherence"
static var DECOHERE = "decohere"
static var COHERENT_OSCILLATION = "coherent_oscillation"

# Phase Objectives
static var ACHIEVE_PHASE = "achieve_phase"
static var PHASE_LOCK = "phase_lock"
static var ACCUMULATE_BERRY = "accumulate_berry"

# Amplitude Engineering
static var CONCENTRATE = "concentrate"
static var SPREAD = "spread"
static var TRANSFER_AMPLITUDE = "transfer_amplitude"

# Interference Objectives
static var CONSTRUCTIVE = "constructive"
static var DESTRUCTIVE = "destructive"
static var INTERFERENCE_PATTERN = "interference_pattern"
```

### 3.2 QuantumObjective.gd
**Purpose**: Single quantum quest objective

```gdscript
class_name QuantumObjective
extends Resource

var objective_type: String  # ObjectiveType constant
var conditions: Array = []  # Array of QuantumCondition
var operations_required: Array = []  # Array of operation strings
var time_limit: float = -1.0  # Seconds to complete
var duration_requirement: float = -1.0  # Must maintain for duration
var emoji_context: Dictionary = {}

func describe() -> String:
    # "Prepare the quantum state such that polar angle θ approximately 1.57"
    # "Create a superposition where coherence above 0.8 (maintain for 30.0s)"
```

**Dependencies**: ObjectiveType, QuantumCondition
**File**: `Core/Quests/QuantumObjective.gd`

---

## Phase 4: Quantum Quest Categories (Week 4-5)

### 4.1 QuestCategory.gd
**Purpose**: High-level quest categories

```gdscript
class_name QuestCategory
extends Resource

# Single-Qubit Challenges
static var STATE_PREPARATION = "state_preparation"
static var MEASUREMENT_GAME = "measurement_game"
static var COHERENCE_TRIAL = "coherence_trial"

# Two-Qubit Challenges
static var ENTANGLEMENT_FORGE = "entanglement_forge"
static var QUANTUM_RELAY = "quantum_relay"
static var BELL_TEST = "bell_test"

# Bath-Wide Challenges
static var AMPLITUDE_SCULPTING = "amplitude_sculpting"
static var ICON_MASTERY = "icon_mastery"
static var ECOSYSTEM_BALANCE = "ecosystem_balance"

# Time-Based Challenges
static var EVOLUTION_RACE = "evolution_race"
static var COHERENCE_MARATHON = "coherence_marathon"
static var CYCLE_SYNC = "cycle_sync"

# Advanced Challenges
static var QUANTUM_ALGORITHM = "quantum_algorithm"
static var ERROR_CORRECTION = "error_correction"
static var TOPOLOGICAL_QUEST = "topological_quest"

# Interference Challenges
static var DOUBLE_SLIT = "double_slit"
static var WHICH_PATH = "which_path"
static var QUANTUM_ERASER = "quantum_eraser"
```

**Dependencies**: None
**File**: `Core/Quests/QuestCategory.gd`

---

## Phase 5: Quantum Quest Data Structure (Week 5-6)

### 5.1 QuantumQuest.gd
**Purpose**: Complete quantum quest data

```gdscript
class_name QuantumQuest
extends Resource

var title: String
var category: String  # QuestCategory constant
var objectives: Array = []  # Array of QuantumObjective
var required_operations: Array = []  # Operation strings
var emoji_vocabulary: Array = []  # Which emojis involved
var difficulty: float = 1.0

# Generation metadata
var faction_pattern: String = ""  # 12-bit pattern
var biome_context: String = ""

# Quantum-specific
var initial_state_requirements: Dictionary = {}
var forbidden_operations: Array = []
var bonus_conditions: Array = []

# Narrative
var description: String = ""
var success_text: String = ""
var failure_text: String = ""

export var quest_id: int = -1  # For tracking
export var time_limit: float = -1.0

func describe_full() -> String:
    # Generate complete quest description with objectives
```

**Dependencies**: QuestCategory, QuantumObjective
**File**: `Core/Quests/QuantumQuest.gd`

---

## Phase 6: Quantum Vocabulary (Week 6-7)

### 6.1 QuantumQuestVocabulary.gd
**Purpose**: Procedural generation atoms for quantum quests

```gdscript
class_name QuantumQuestVocabulary
extends Resource

# Quantum Action Verbs (30 total)
const QUANTUM_VERBS = {
    "prepare": {"type": "prepare_state", "emoji": "🎯"},
    "superpose": {"type": "prepare_superposition", "emoji": "🌀"},
    "collapse": {"type": "prepare_eigenstate", "emoji": "💥"},
    "measure": {"type": "measure_outcome", "emoji": "👁️"},
    "entangle": {"type": "create_bell_pair", "emoji": "🔗"},
    "cohere": {"type": "maintain_coherence", "emoji": "🌊"},
    "phase-align": {"type": "achieve_phase", "emoji": "🎵"},
    "concentrate": {"type": "concentrate", "emoji": "🎯"},
    "spread": {"type": "spread", "emoji": "💫"},
    "stabilize": {"type": "stabilize", "emoji": "⚓"},
    "interfere": {"type": "interference_pattern", "emoji": "🌈"},
    "synchronize": {"type": "synchronize", "emoji": "⏱️"},
    # ... 18 more
}

# Observable Targets (12 total)
const OBSERVABLE_TARGETS = {
    "the quantum field": "amplitude",
    "the phase alignment": "phi",
    "the probability flow": "probability_north",
    "the coherence web": "coherence",
    "the entanglement threads": "entanglement",
    "the Bloch vector": "theta",
    "the bath entropy": "entropy",
    "the geometric phase": "berry_phase",
    # ... 4 more
}

# Quantum Modifiers (16 total)
const QUANTUM_MODIFIERS = {
    # Precision
    "precisely": {"tolerance": 0.01, "difficulty": 3},
    "approximately": {"tolerance": 0.2, "difficulty": 1},
    "exactly": {"tolerance": 0.001, "difficulty": 5},

    # Speed
    "rapidly": {"time_limit": 5.0, "difficulty": 2},
    "gradually": {"time_limit": 60.0, "difficulty": 0.5},

    # Stability
    "stably": {"duration": 30.0, "difficulty": 2},
    "eternally": {"duration": 120.0, "difficulty": 4},

    # Scope
    "locally": {"scope": "single", "difficulty": 1},
    "globally": {"scope": "all", "difficulty": 3},
    # ... 7 more
}

# Target Values (16 total)
const TARGET_VALUES = {
    "north pole": {"observable": "theta", "value": 0.0, "emoji": "⬆️"},
    "south pole": {"observable": "theta", "value": PI, "emoji": "⬇️"},
    "equator": {"observable": "theta", "value": PI/2, "emoji": "🌐"},
    "dawn phase": {"observable": "phi", "value": 0.0, "emoji": "🌅"},
    "noon phase": {"observable": "phi", "value": PI/2, "emoji": "☀️"},
    "maximum coherence": {"observable": "coherence", "value": 1.0, "emoji": "✨"},
    "Bell state": {"observable": "entanglement", "value": 1.0, "emoji": "🔗"},
    # ... 9 more
}
```

**Dependencies**: None
**File**: `Core/Quests/QuantumQuestVocabulary.gd`

---

## Phase 7: Quantum Quest Generator (Week 7-9)

### 7.1 QuantumQuestGenerator.gd
**Purpose**: Generate quantum quests from faction patterns

```gdscript
class_name QuantumQuestGenerator
extends Node

const QuantumQuest = preload("res://Core/Quests/QuantumQuest.gd")
const QuantumObjective = preload("res://Core/Quests/QuantumObjective.gd")
const QuantumCondition = preload("res://Core/Quests/QuantumCondition.gd")
const QuestCategory = preload("res://Core/Quests/QuestCategory.gd")
const QuantumQuestVocabulary = preload("res://Core/Quests/QuantumQuestVocabulary.gd")

var quest_templates: Dictionary = {}

func _ready():
    _build_templates()

func generate_from_pattern(
    pattern: String,  # 12-bit faction pattern
    biome_emojis: Array,
    category: String = ""
) -> QuantumQuest:
    """Generate quantum quest from faction bit pattern"""

    var bits = _pattern_to_bits(pattern)

    # Select category based on bits if not specified
    if category.is_empty():
        category = _select_category_from_bits(bits)

    # Get template
    var template = _get_template(category)

    # Select emojis
    var emoji_pair = _select_emojis_from_bits(bits, biome_emojis)

    # Generate objectives
    var objectives = _generate_objectives(template, bits, emoji_pair, biome_emojis)

    # Calculate difficulty
    var difficulty = _calculate_difficulty(template, bits)

    # Generate title
    var title = _generate_title(template, emoji_pair, bits)

    # Create quest
    var quest = QuantumQuest.new()
    quest.title = title
    quest.category = category
    quest.objectives = objectives
    quest.difficulty = difficulty
    quest.faction_pattern = pattern
    quest.emoji_vocabulary = [emoji_pair[0], emoji_pair[1]] + biome_emojis.slice(0, 3)

    return quest

func _select_category_from_bits(bits: Array) -> String:
    """Map bit pattern to quest category"""
    # bits[1] = material/mystical
    # bits[6] = crystalline/fluid
    # bits[10] = emergent/imposed

    if bits[1] and bits[6]:  # Mystical + Fluid
        return QuestCategory.COHERENCE_TRIAL
    elif bits[1] and not bits[6]:  # Mystical + Crystalline
        return QuestCategory.TOPOLOGICAL_QUEST
    elif bits[0] and bits[10]:  # Deterministic + Imposed
        return QuestCategory.STATE_PREPARATION
    elif not bits[0] and bits[6]:  # Random + Fluid
        return QuestCategory.MEASUREMENT_GAME
    elif bits[9]:  # Prismatic
        return QuestCategory.DOUBLE_SLIT
    else:
        return QuestCategory.STATE_PREPARATION
```

**Key Methods**:
- `_build_templates()`: Create quest templates for each category
- `_generate_objectives()`: Build objectives from template + bits
- `_generate_target_value()`: Map bits to target values (theta, phi, coherence, etc.)
- `_difficulty_modifier_from_bits()`: Scale difficulty based on faction traits
- `_required_operations_from_bits()`: Determine required operations
- `_forbidden_operations_from_bits()`: Determine forbidden operations

**Dependencies**: All quantum types, QuantumQuestVocabulary
**File**: `Core/Quests/QuantumQuestGenerator.gd`

---

## Phase 8: Quantum Quest Evaluator (Week 9-10)

### 8.1 QuantumQuestEvaluator.gd
**Purpose**: Check if quantum conditions are satisfied

```gdscript
class_name QuantumQuestEvaluator
extends Node

func evaluate_condition(
    condition: QuantumCondition,
    bath_state: Dictionary,
    projections: Dictionary
) -> Dictionary:
    """
    Evaluate a quantum condition against current state.
    Returns: {satisfied: bool, current_value: float, progress: float}
    """

    var observable = condition.observable
    var current_value = _get_observable_value(
        observable,
        bath_state,
        projections,
        condition.emoji_target,
        condition.emoji_pair
    )

    if current_value == null:
        return {"satisfied": false, "current_value": 0.0, "progress": 0.0}

    var satisfied = _compare(
        current_value,
        condition.target_value,
        condition.tolerance,
        condition.comparison
    )

    var progress = _calculate_progress(current_value, condition.target_value)

    return {
        "satisfied": satisfied,
        "current_value": current_value,
        "progress": progress
    }

func _get_observable_value(
    observable: String,
    bath: Dictionary,
    projections: Dictionary,
    emoji: String,
    pair: Array
) -> float:
    """Extract observable value from quantum state"""

    match observable:
        QuantumObservable.THETA:
            var proj_key = str(pair)
            if projections.has(proj_key):
                return projections[proj_key].get("theta", 0.0)

        QuantumObservable.PHI:
            var proj_key = str(pair)
            if projections.has(proj_key):
                return projections[proj_key].get("phi", 0.0)

        QuantumObservable.COHERENCE:
            var proj_key = str(pair)
            if projections.has(proj_key):
                var theta = projections[proj_key].get("theta", PI/2)
                return sin(theta)  # Maximum at equator

        QuantumObservable.AMPLITUDE:
            if bath.has("amplitudes") and bath["amplitudes"].has(emoji):
                var amp = bath["amplitudes"][emoji]
                return sqrt(amp.get("re", 0)**2 + amp.get("im", 0)**2)

        QuantumObservable.PHASE:
            if bath.has("amplitudes") and bath["amplitudes"].has(emoji):
                var amp = bath["amplitudes"][emoji]
                return atan2(amp.get("im", 0), amp.get("re", 0))

        QuantumObservable.ENTROPY:
            var probs = bath.get("probabilities", {})
            var entropy = 0.0
            for p in probs.values():
                if p > 0:
                    entropy -= p * log(p) / log(2)
            return entropy

        QuantumObservable.BERRY_PHASE:
            var proj_key = str(pair)
            if projections.has(proj_key):
                return projections[proj_key].get("accumulated_berry", 0.0)

    return null

func evaluate_objective(
    objective: QuantumObjective,
    bath_state: Dictionary,
    projections: Dictionary
) -> Dictionary:
    """Evaluate complete objective"""
    # Check all conditions, track progress

func evaluate_quest(
    quest: QuantumQuest,
    bath_state: Dictionary,
    projections: Dictionary
) -> Dictionary:
    """Evaluate complete quest"""
    # Check all objectives, return completion status
```

**Dependencies**: All quantum types
**File**: `Core/Quests/QuantumQuestEvaluator.gd`

---

## Phase 9: Integration with BasePlot (Week 10-11)

### 9.1 Update BasePlot.gd
**Add quantum state tracking**:

```gdscript
# In BasePlot.gd

var accumulated_berry_phase: float = 0.0
var coherence_history: Array = []
var phase_history: Array = []

func get_quantum_state() -> Dictionary:
    """Export quantum state for quest evaluation"""
    return {
        "theta": quantum_state.get_theta(),
        "phi": quantum_state.get_phi(),
        "radius": quantum_state.energy,
        "accumulated_berry": accumulated_berry_phase,
        "coherence": sin(quantum_state.get_theta()),
    }

func _on_evolution_step(delta: float):
    # Track Berry phase accumulation
    var old_phi = quantum_state.get_phi()
    quantum_state.evolve(delta)
    var new_phi = quantum_state.get_phi()

    # Berry phase = integral of (1-cos(theta)) * dφ
    var theta = quantum_state.get_theta()
    var dphi = new_phi - old_phi
    accumulated_berry_phase += (1 - cos(theta)) * dphi
```

### 9.2 Update FarmEconomy.gd
**Add bath state export**:

```gdscript
# In FarmEconomy.gd

func get_bath_state() -> Dictionary:
    """Export bath state for quest evaluation"""
    var amplitudes = {}
    var probabilities = {}

    for emoji in emoji_credits.keys():
        var credits = emoji_credits[emoji]
        var quantum_units = credits / QUANTUM_TO_CREDITS
        var normalized_prob = quantum_units / _get_total_units()

        probabilities[emoji] = normalized_prob

        # Mock complex amplitudes (would come from actual quantum sim)
        amplitudes[emoji] = {
            "re": sqrt(normalized_prob),
            "im": 0.0
        }

    return {
        "amplitudes": amplitudes,
        "probabilities": probabilities
    }
```

---

## Phase 10: Quantum Quest UI (Week 11-12)

### 10.1 Update QuestPanel.gd
**Add quantum objective display**:

```gdscript
# In QuestPanel.gd / QuestItem

func _create_quantum_objective_display(objective: QuantumObjective) -> VBoxContainer:
    var vbox = VBoxContainer.new()

    # Objective type header
    var header = Label.new()
    header.text = objective.describe()
    vbox.add_child(header)

    # Conditions with progress bars
    for condition in objective.conditions:
        var cond_hbox = HBoxContainer.new()

        # Observable icon/emoji
        var obs_label = Label.new()
        obs_label.text = _get_observable_emoji(condition.observable)
        cond_hbox.add_child(obs_label)

        # Progress bar
        var progress = ProgressBar.new()
        progress.custom_minimum_size = Vector2(200, 20)
        progress.max_value = condition.target_value + condition.tolerance
        progress.value = 0  # Updated by evaluator
        cond_hbox.add_child(progress)

        # Target value
        var target_label = Label.new()
        target_label.text = "→ %.2f" % condition.target_value
        cond_hbox.add_child(target_label)

        vbox.add_child(cond_hbox)

    return vbox

func _get_observable_emoji(observable: String) -> String:
    match observable:
        QuantumObservable.THETA: return "θ"
        QuantumObservable.PHI: return "φ"
        QuantumObservable.COHERENCE: return "🌊"
        QuantumObservable.ENTANGLEMENT: return "🔗"
        QuantumObservable.BERRY_PHASE: return "🍇"
        _: return "⚛️"
```

### 10.2 Create QuantumQuestProgressOverlay.gd
**Real-time quantum state visualization**:

```gdscript
class_name QuantumQuestProgressOverlay
extends Control

# Shows live quantum observables as quest progresses
# - Bloch sphere visualization
# - Phase diagram
# - Coherence meter
# - Entanglement graph
```

---

## Implementation Timeline

### Weeks 1-2: Foundation
- ✅ QuantumObservable.gd
- ✅ QuantumOperation.gd
- ✅ ComparisonOp.gd
- ✅ QuantumCondition.gd

### Weeks 3-4: Objectives
- ⬜ ObjectiveType.gd
- ⬜ QuantumObjective.gd

### Weeks 5-6: Quest Structure
- ⬜ QuestCategory.gd
- ⬜ QuantumQuest.gd

### Weeks 7-8: Vocabulary & Generation
- ⬜ QuantumQuestVocabulary.gd
- ⬜ QuantumQuestGenerator.gd (Part 1)

### Weeks 9-10: Evaluation
- ⬜ QuantumQuestGenerator.gd (Part 2)
- ⬜ QuantumQuestEvaluator.gd

### Weeks 11-12: Integration & UI
- ⬜ BasePlot quantum state tracking
- ⬜ FarmEconomy bath state export
- ⬜ QuestPanel quantum display
- ⬜ Testing and balancing

---

## Success Metrics

1. **Quest Generation**:
   - Generate 1,000+ unique quantum quests from faction patterns
   - All quest categories represented
   - Difficulty scales properly with faction bits

2. **Quest Evaluation**:
   - Correctly measure all quantum observables
   - Real-time progress tracking
   - Proper completion detection

3. **Player Experience**:
   - Quests teach quantum concepts organically
   - Clear visual feedback on quantum state
   - Progression from simple (state prep) to complex (entanglement)

---

## Example Quests

### STATE_PREPARATION (Simple)
```
🎯 Prepare the Equator State

Objective: Prepare the quantum state such that polar angle θ in range 1.47-1.67

Required Operations:
  • CREATE_PROJECTION

Time Limit: 60s
Difficulty: ⭐
```

### ENTANGLEMENT_FORGE (Medium)
```
🔗 The Bell Forge: 🌾↔🐺

Objective 1: Create a superposition where coherence above 0.80
Objective 2: Entangle projections so that entanglement in range 0.80-1.00

Required Operations:
  • CREATE_PROJECTION
  • BELL_ENTANGLE

Time Limit: 90s
Difficulty: ⭐⭐
```

### TOPOLOGICAL_QUEST (Hard)
```
🍇 The Geometric Journey

Objective 1: Achieve a phase relationship where phase φ in range 1.47-1.67
Objective 2: Accumulate geometric phase until Berry phase in range 3.04-3.24 (maintain for 30.0s)

Required Operations:
  • CREATE_PROJECTION
  • ROTATION_Z

Forbidden Operations:
  ⛔ STRONG_MEASURE

Time Limit: 120s
Difficulty: ⭐⭐⭐⭐
```

---

## Combinatoric Space

**Quantum Quest Atoms**:
- 30 Quantum Verbs
- 12 Observable Targets
- 16 Quantum Modifiers
- 16 Target Values
- 18 Quest Categories
- 24 Quantum Observables
- 41 Quantum Operations
- 14 Comparison Operators

**Total Atoms**: ~171

**Quest Combinations**:
- Simple Quests: 30 × 12 × 16² × (8×7) = ~5.8M
- With Categories: 5.8M × 18 = ~104M
- With Faction Patterns: 104M × 4096 = ~426B
- Multi-Objective (3 objectives): ~426B³ ≈ **10^26 unique quantum quests**

From only ~171 vocabulary atoms!

---

## Next Steps

1. **Create Phase 1 files** (QuantumObservable, QuantumOperation, ComparisonOp, QuantumCondition)
2. **Test basic quest generation** with simple objectives
3. **Implement evaluator** for theta/phi/coherence
4. **Add UI visualization** for quantum observables
5. **Expand to entanglement** and topological quests
6. **Balance difficulty** and playtest

This transforms SpaceWheat from a farming sim into a **quantum engineering game** where players learn actual quantum mechanics through gameplay! 🎯🌊🔗
