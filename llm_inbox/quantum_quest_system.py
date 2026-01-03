#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║           SPACEWHEAT QUANTUM QUEST SYSTEM                                    ║
║           Beyond "Gather X" - Engineering Quantum States                     ║
╚══════════════════════════════════════════════════════════════════════════════╝

Instead of classical resource gathering, quests target QUANTUM OBSERVABLES:
- Bloch sphere coordinates (θ, φ, r)
- Amplitude distributions across bath
- Coherence and entanglement
- Interference patterns
- Phase relationships
- Evolution trajectories

Players become QUANTUM ENGINEERS manipulating the bath through:
- Projection placement (where to look)
- Measurement timing (when to collapse)
- Icon influence (how to evolve)
- Entanglement creation (correlation networks)
"""

import math
import random
from dataclasses import dataclass, field
from typing import List, Dict, Tuple, Optional, Callable, Set
from enum import Enum, auto

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: QUANTUM OBSERVABLES
# What can be measured and targeted in the quantum bath
# ═══════════════════════════════════════════════════════════════════════════════

class QuantumObservable(Enum):
    """Categories of quantum properties that can be quest objectives"""
    
    # Single Qubit Observables (from projection)
    THETA = auto()          # Polar angle on Bloch sphere [0, π]
    PHI = auto()            # Azimuthal phase [0, 2π]
    RADIUS = auto()         # Amplitude in subspace
    COHERENCE = auto()      # sin(θ) - superposition strength
    PROBABILITY_NORTH = auto()  # |α_n|² 
    PROBABILITY_SOUTH = auto()  # |α_s|²
    
    # Bath-Wide Observables
    AMPLITUDE = auto()      # |α_i| for specific emoji
    PHASE = auto()          # arg(α_i) for specific emoji
    ENTROPY = auto()        # Shannon entropy of probability distribution
    PURITY = auto()         # Tr(ρ²) - how pure vs mixed the state is
    
    # Multi-Qubit Observables
    CORRELATION = auto()    # ⟨A⊗B⟩ between two projections
    ENTANGLEMENT = auto()   # Bell state fidelity
    PHASE_DIFFERENCE = auto()  # φ₁ - φ₂ between projections
    
    # Dynamical Observables
    OSCILLATION_FREQUENCY = auto()  # Hamiltonian eigenvalue difference
    DECAY_RATE = auto()     # Lindblad dissipation speed
    STABILITY = auto()      # How long state persists
    
    # Topological Observables
    BERRY_PHASE = auto()    # Accumulated geometric phase
    WINDING_NUMBER = auto() # How many times φ wraps around


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: QUANTUM OPERATIONS
# Actions players can perform on the quantum bath
# ═══════════════════════════════════════════════════════════════════════════════

class QuantumOperation(Enum):
    """Actions that manipulate the quantum state"""
    
    # Projection Operations
    CREATE_PROJECTION = auto()    # Plant a plot, create measurement axis
    REMOVE_PROJECTION = auto()    # Remove plot, stop observing
    ROTATE_AXIS = auto()          # Change projection basis
    
    # Measurement Operations
    WEAK_MEASURE = auto()         # Partial collapse, preserve some coherence
    STRONG_MEASURE = auto()       # Full collapse to eigenstate
    NULL_MEASURE = auto()         # Measure but discard result (still affects bath)
    DELAYED_MEASURE = auto()      # Schedule measurement for future
    
    # Unitary Operations
    PHASE_SHIFT = auto()          # Apply e^(iφ) to amplitude
    HADAMARD = auto()             # Create equal superposition
    ROTATION_X = auto()           # Rotate around X axis
    ROTATION_Y = auto()           # Rotate around Y axis
    ROTATION_Z = auto()           # Rotate around Z axis
    
    # Two-Qubit Operations
    CNOT = auto()                 # Controlled-NOT gate
    BELL_ENTANGLE = auto()        # Create Bell pair
    SWAP = auto()                 # Exchange states
    CONTROLLED_PHASE = auto()     # Controlled phase gate
    
    # Bath-Wide Operations
    INJECT_AMPLITUDE = auto()     # Add amplitude to specific emoji
    DRAIN_AMPLITUDE = auto()      # Remove amplitude from emoji
    REDISTRIBUTE = auto()         # Spread amplitude across emojis
    
    # Icon Manipulations
    ACTIVATE_ICON = auto()        # Turn on Icon's Hamiltonian
    DEACTIVATE_ICON = auto()      # Turn off Icon influence
    MODULATE_ICON = auto()        # Change Icon coupling strength
    
    # Temporal Operations
    EVOLVE = auto()               # Let bath evolve for time t
    FREEZE = auto()               # Pause evolution
    REVERSE = auto()              # Time-reverse (Hermitian conjugate)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: QUANTUM CONDITIONS
# Predicates that evaluate quantum state properties
# ═══════════════════════════════════════════════════════════════════════════════

class ComparisonOp(Enum):
    """Mathematical comparison operators"""
    EQUALS = "="
    APPROX = "≈"
    LESS = "<"
    GREATER = ">"
    LESS_EQ = "≤"
    GREATER_EQ = "≥"
    IN_RANGE = "∈"
    NEAR = "~"      # Within tolerance
    RESONANT = "∿"  # Matching frequency
    ORTHOGONAL = "⊥"
    PARALLEL = "∥"
    ENTANGLED = "⊗"
    CORRELATED = "↔"
    ANTICORRELATED = "↮"


@dataclass
class QuantumCondition:
    """A predicate on quantum observables"""
    observable: QuantumObservable
    comparison: ComparisonOp
    target_value: float
    tolerance: float = 0.1
    emoji_target: Optional[str] = None  # For amplitude/phase observables
    emoji_pair: Optional[Tuple[str, str]] = None  # For projection axis
    second_projection: Optional[Tuple[str, str]] = None  # For correlations
    
    def describe(self) -> str:
        """Human-readable description"""
        obs_names = {
            QuantumObservable.THETA: "polar angle θ",
            QuantumObservable.PHI: "phase φ",
            QuantumObservable.RADIUS: "amplitude radius",
            QuantumObservable.COHERENCE: "coherence",
            QuantumObservable.AMPLITUDE: f"amplitude of {self.emoji_target}",
            QuantumObservable.PHASE: f"phase of {self.emoji_target}",
            QuantumObservable.CORRELATION: "correlation",
            QuantumObservable.ENTANGLEMENT: "entanglement",
            QuantumObservable.BERRY_PHASE: "Berry phase",
            QuantumObservable.ENTROPY: "entropy",
        }
        
        obs_name = obs_names.get(self.observable, self.observable.name)
        
        comp_symbols = {
            ComparisonOp.EQUALS: "exactly",
            ComparisonOp.APPROX: "approximately",
            ComparisonOp.GREATER: "above",
            ComparisonOp.LESS: "below",
            ComparisonOp.IN_RANGE: "between",
            ComparisonOp.NEAR: "near",
            ComparisonOp.RESONANT: "resonant with",
            ComparisonOp.ENTANGLED: "entangled with",
        }
        
        comp = comp_symbols.get(self.comparison, str(self.comparison.value))
        
        if self.comparison == ComparisonOp.IN_RANGE:
            return f"{obs_name} {comp} {self.target_value:.2f} ± {self.tolerance:.2f}"
        else:
            return f"{obs_name} {comp} {self.target_value:.2f}"


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: QUANTUM QUEST OBJECTIVES
# Complex quest goals built from conditions and operations
# ═══════════════════════════════════════════════════════════════════════════════

class ObjectiveType(Enum):
    """Categories of quantum quest objectives"""
    
    # State Preparation
    PREPARE_STATE = auto()        # Get bath to specific state
    PREPARE_SUPERPOSITION = auto() # Create balanced superposition
    PREPARE_EIGENSTATE = auto()   # Collapse to definite state
    
    # Measurement Challenges
    MEASURE_OUTCOME = auto()      # Get specific measurement result
    MEASURE_STATISTICS = auto()   # Achieve probability distribution
    QUANTUM_TOMOGRAPHY = auto()   # Fully characterize state
    
    # Entanglement Tasks
    CREATE_BELL_PAIR = auto()     # Entangle two projections
    MAINTAIN_ENTANGLEMENT = auto() # Keep entanglement above threshold
    TELEPORT_STATE = auto()       # Quantum teleportation protocol
    
    # Coherence Challenges
    MAINTAIN_COHERENCE = auto()   # Keep coherence high for duration
    DECOHERE = auto()             # Drive to classical state
    COHERENT_OSCILLATION = auto() # Maintain stable oscillation
    
    # Phase Objectives
    ACHIEVE_PHASE = auto()        # Specific φ value
    PHASE_LOCK = auto()           # Match phase to reference
    ACCUMULATE_BERRY = auto()     # Gather geometric phase
    
    # Amplitude Engineering
    AMPLITUDE_PATTERN = auto()    # Specific amplitude distribution
    TRANSFER_AMPLITUDE = auto()   # Move amplitude between emojis
    CONCENTRATE = auto()          # Focus amplitude in one emoji
    SPREAD = auto()               # Distribute amplitude evenly
    
    # Dynamical Objectives
    STABILIZE = auto()            # Make state robust to perturbation
    DESTABILIZE = auto()          # Make state sensitive
    RESONANCE = auto()            # Match evolution to external drive
    AVOID_COLLAPSE = auto()       # Don't measure for duration
    
    # Interference Objectives
    CONSTRUCTIVE = auto()         # Create constructive interference
    DESTRUCTIVE = auto()          # Create destructive interference
    INTERFERENCE_PATTERN = auto() # Specific pattern
    
    # Multi-System Objectives
    SYNCHRONIZE = auto()          # Phase-lock multiple projections
    ORCHESTRATE = auto()          # Coordinate multiple bath regions
    CHAIN_REACTION = auto()       # Trigger cascade through entanglement


@dataclass
class QuantumObjective:
    """A single quantum quest objective"""
    objective_type: ObjectiveType
    conditions: List[QuantumCondition]
    operations_required: List[QuantumOperation] = field(default_factory=list)
    time_limit: Optional[float] = None  # Seconds to complete
    duration_requirement: Optional[float] = None  # Must maintain for this long
    emoji_context: Dict[str, str] = field(default_factory=dict)
    
    def describe(self) -> str:
        """Generate description of this objective"""
        type_descriptions = {
            ObjectiveType.PREPARE_STATE: "Prepare the quantum state such that",
            ObjectiveType.PREPARE_SUPERPOSITION: "Create a superposition where",
            ObjectiveType.CREATE_BELL_PAIR: "Entangle projections so that",
            ObjectiveType.MAINTAIN_COHERENCE: "Maintain quantum coherence with",
            ObjectiveType.ACHIEVE_PHASE: "Achieve a phase relationship where",
            ObjectiveType.AMPLITUDE_PATTERN: "Shape the amplitude distribution so",
            ObjectiveType.STABILIZE: "Stabilize the state ensuring",
            ObjectiveType.INTERFERENCE_PATTERN: "Create interference pattern with",
            ObjectiveType.SYNCHRONIZE: "Synchronize multiple plots achieving",
            ObjectiveType.ACCUMULATE_BERRY: "Accumulate geometric phase until",
        }
        
        desc = type_descriptions.get(self.objective_type, f"{self.objective_type.name}:")
        conditions_desc = " AND ".join(c.describe() for c in self.conditions)
        
        result = f"{desc} {conditions_desc}"
        
        if self.duration_requirement:
            result += f" (maintain for {self.duration_requirement:.1f}s)"
        if self.time_limit:
            result += f" [time limit: {self.time_limit:.1f}s]"
            
        return result


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: QUANTUM QUEST VOCABULARY
# Procedural generation atoms for quantum-rich quests
# ═══════════════════════════════════════════════════════════════════════════════

# Quantum Action Verbs (replace classical "gather", "deliver")
QUANTUM_VERBS = {
    # State Preparation
    "prepare": {"type": ObjectiveType.PREPARE_STATE, "emoji": "🎯"},
    "superpose": {"type": ObjectiveType.PREPARE_SUPERPOSITION, "emoji": "🌀"},
    "collapse": {"type": ObjectiveType.PREPARE_EIGENSTATE, "emoji": "💥"},
    
    # Measurement
    "measure": {"type": ObjectiveType.MEASURE_OUTCOME, "emoji": "👁️"},
    "observe": {"type": ObjectiveType.QUANTUM_TOMOGRAPHY, "emoji": "🔬"},
    "divine": {"type": ObjectiveType.MEASURE_STATISTICS, "emoji": "🔮"},
    
    # Entanglement
    "entangle": {"type": ObjectiveType.CREATE_BELL_PAIR, "emoji": "🔗"},
    "correlate": {"type": ObjectiveType.MAINTAIN_ENTANGLEMENT, "emoji": "↔️"},
    "teleport": {"type": ObjectiveType.TELEPORT_STATE, "emoji": "✨"},
    
    # Coherence
    "cohere": {"type": ObjectiveType.MAINTAIN_COHERENCE, "emoji": "🌊"},
    "decohere": {"type": ObjectiveType.DECOHERE, "emoji": "📉"},
    "oscillate": {"type": ObjectiveType.COHERENT_OSCILLATION, "emoji": "〰️"},
    
    # Phase
    "phase-align": {"type": ObjectiveType.ACHIEVE_PHASE, "emoji": "🎵"},
    "phase-lock": {"type": ObjectiveType.PHASE_LOCK, "emoji": "🔐"},
    "accumulate": {"type": ObjectiveType.ACCUMULATE_BERRY, "emoji": "🍇"},
    
    # Amplitude
    "concentrate": {"type": ObjectiveType.CONCENTRATE, "emoji": "🎯"},
    "spread": {"type": ObjectiveType.SPREAD, "emoji": "💫"},
    "transfer": {"type": ObjectiveType.TRANSFER_AMPLITUDE, "emoji": "➡️"},
    "sculpt": {"type": ObjectiveType.AMPLITUDE_PATTERN, "emoji": "🗿"},
    
    # Dynamics
    "stabilize": {"type": ObjectiveType.STABILIZE, "emoji": "⚓"},
    "destabilize": {"type": ObjectiveType.DESTABILIZE, "emoji": "💣"},
    "resonate": {"type": ObjectiveType.RESONANCE, "emoji": "🔔"},
    "protect": {"type": ObjectiveType.AVOID_COLLAPSE, "emoji": "🛡️"},
    
    # Interference
    "interfere": {"type": ObjectiveType.INTERFERENCE_PATTERN, "emoji": "🌈"},
    "amplify": {"type": ObjectiveType.CONSTRUCTIVE, "emoji": "📈"},
    "cancel": {"type": ObjectiveType.DESTRUCTIVE, "emoji": "❌"},
    
    # Multi-System
    "synchronize": {"type": ObjectiveType.SYNCHRONIZE, "emoji": "⏱️"},
    "orchestrate": {"type": ObjectiveType.ORCHESTRATE, "emoji": "🎭"},
    "cascade": {"type": ObjectiveType.CHAIN_REACTION, "emoji": "🌊"},
}

# Observable Targets (what the verb acts upon)
OBSERVABLE_TARGETS = {
    "the quantum field": QuantumObservable.AMPLITUDE,
    "the phase alignment": QuantumObservable.PHI,
    "the probability flow": QuantumObservable.PROBABILITY_NORTH,
    "the coherence web": QuantumObservable.COHERENCE,
    "the entanglement threads": QuantumObservable.ENTANGLEMENT,
    "the Bloch vector": QuantumObservable.THETA,
    "the bath entropy": QuantumObservable.ENTROPY,
    "the geometric phase": QuantumObservable.BERRY_PHASE,
    "the amplitude radius": QuantumObservable.RADIUS,
    "the oscillation frequency": QuantumObservable.OSCILLATION_FREQUENCY,
    "the correlation function": QuantumObservable.CORRELATION,
    "the decay channel": QuantumObservable.DECAY_RATE,
}

# Quantum Modifiers (how the action is performed)
QUANTUM_MODIFIERS = {
    # Precision
    "precisely": {"tolerance": 0.01, "difficulty": 3},
    "approximately": {"tolerance": 0.2, "difficulty": 1},
    "exactly": {"tolerance": 0.001, "difficulty": 5},
    "loosely": {"tolerance": 0.3, "difficulty": 0.5},
    
    # Speed
    "rapidly": {"time_limit": 5.0, "difficulty": 2},
    "gradually": {"time_limit": 60.0, "difficulty": 0.5},
    "instantaneously": {"time_limit": 1.0, "difficulty": 4},
    "patiently": {"time_limit": 120.0, "difficulty": 0.3},
    
    # Stability
    "stably": {"duration": 30.0, "difficulty": 2},
    "briefly": {"duration": 5.0, "difficulty": 0.5},
    "eternally": {"duration": 120.0, "difficulty": 4},
    "fleetingly": {"duration": 2.0, "difficulty": 0.3},
    
    # Scope
    "locally": {"scope": "single", "difficulty": 1},
    "globally": {"scope": "all", "difficulty": 3},
    "pairwise": {"scope": "pair", "difficulty": 2},
    "symmetrically": {"scope": "symmetric", "difficulty": 2.5},
}

# Target Values (specific quantum states to achieve)
TARGET_VALUES = {
    # Angles (multiples of π)
    "north pole": {"observable": "theta", "value": 0.0, "emoji": "⬆️"},
    "south pole": {"observable": "theta", "value": math.pi, "emoji": "⬇️"},
    "equator": {"observable": "theta", "value": math.pi/2, "emoji": "🌐"},
    "45° latitude": {"observable": "theta", "value": math.pi/4, "emoji": "↗️"},
    
    # Phases
    "dawn phase": {"observable": "phi", "value": 0.0, "emoji": "🌅"},
    "noon phase": {"observable": "phi", "value": math.pi/2, "emoji": "☀️"},
    "dusk phase": {"observable": "phi", "value": math.pi, "emoji": "🌆"},
    "midnight phase": {"observable": "phi", "value": 3*math.pi/2, "emoji": "🌙"},
    
    # Coherence levels
    "maximum coherence": {"observable": "coherence", "value": 1.0, "emoji": "✨"},
    "half coherence": {"observable": "coherence", "value": 0.5, "emoji": "🌗"},
    "classical state": {"observable": "coherence", "value": 0.0, "emoji": "🧱"},
    
    # Entanglement
    "Bell state": {"observable": "entanglement", "value": 1.0, "emoji": "🔗"},
    "partial entanglement": {"observable": "entanglement", "value": 0.5, "emoji": "🔗"},
    "separable state": {"observable": "entanglement", "value": 0.0, "emoji": "✂️"},
    
    # Berry phase (in units of π)
    "zero Berry phase": {"observable": "berry", "value": 0.0, "emoji": "⭕"},
    "π Berry phase": {"observable": "berry", "value": math.pi, "emoji": "🔄"},
    "2π Berry phase": {"observable": "berry", "value": 2*math.pi, "emoji": "♾️"},
}

# Quantum Consequences (what happens on success/failure)
QUANTUM_CONSEQUENCES = {
    "success": {
        "coherence boost": "All projections gain +0.2 coherence",
        "phase gift": "Bath receives external phase injection",
        "amplitude rain": "Amplitude spreads to neighboring plots",
        "entanglement web": "Creates automatic correlations",
        "evolution acceleration": "Hamiltonian strength increases",
        "stability blessing": "Decay rates reduced",
    },
    "failure": {
        "decoherence wave": "All projections lose coherence",
        "phase scramble": "Random phase noise injected",
        "amplitude drain": "Bath loses total amplitude",
        "entanglement severance": "All correlations broken",
        "evolution chaos": "Random Hamiltonian perturbation",
        "decay curse": "Decay rates increased",
    }
}


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: QUANTUM QUEST TYPES
# Categories of quantum quests with distinct mechanics
# ═══════════════════════════════════════════════════════════════════════════════

class QuestCategory(Enum):
    """High-level quest categories"""
    
    # Single-Qubit Challenges
    STATE_PREPARATION = auto()     # Get projection to target state
    MEASUREMENT_GAME = auto()      # Measurement outcome challenges
    COHERENCE_TRIAL = auto()       # Maintain or destroy coherence
    
    # Two-Qubit Challenges  
    ENTANGLEMENT_FORGE = auto()    # Create specific correlations
    QUANTUM_RELAY = auto()         # Transfer state between plots
    BELL_TEST = auto()             # Verify entanglement via measurement
    
    # Bath-Wide Challenges
    AMPLITUDE_SCULPTING = auto()   # Shape entire bath distribution
    ICON_MASTERY = auto()          # Manipulate Hamiltonian evolution
    ECOSYSTEM_BALANCE = auto()     # Maintain predator-prey quantum dynamics
    
    # Time-Based Challenges
    EVOLUTION_RACE = auto()        # Complete before bath evolves away
    COHERENCE_MARATHON = auto()    # Maintain state for duration
    CYCLE_SYNC = auto()            # Synchronize with day/night cycle
    
    # Advanced Challenges
    QUANTUM_ALGORITHM = auto()     # Execute specific gate sequence
    ERROR_CORRECTION = auto()      # Protect against decoherence
    TOPOLOGICAL_QUEST = auto()     # Berry phase accumulation
    
    # Interference Challenges
    DOUBLE_SLIT = auto()           # Create interference pattern
    WHICH_PATH = auto()            # Avoid destroying interference
    QUANTUM_ERASER = auto()        # Restore lost coherence


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: QUANTUM QUEST GENERATOR
# Procedurally generates quantum-rich quests
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class QuantumQuest:
    """A complete quantum quest"""
    title: str
    category: QuestCategory
    objectives: List[QuantumObjective]
    required_operations: List[QuantumOperation]
    emoji_vocabulary: List[str]  # Which emojis are involved
    difficulty: float  # 1.0 = baseline
    time_limit: Optional[float] = None
    
    # Generation metadata
    faction_pattern: str = ""  # 12-bit pattern that generated this
    biome_context: str = ""
    
    # Quantum-specific
    initial_state_requirements: Dict[str, float] = field(default_factory=dict)
    forbidden_operations: List[QuantumOperation] = field(default_factory=list)
    bonus_conditions: List[QuantumCondition] = field(default_factory=list)
    
    # Narrative
    description: str = ""
    success_text: str = ""
    failure_text: str = ""
    
    def describe_full(self) -> str:
        """Generate complete quest description"""
        lines = []
        lines.append(f"╔{'═'*70}╗")
        lines.append(f"║  {self.title:^66}  ║")
        lines.append(f"╚{'═'*70}╝")
        lines.append("")
        lines.append(f"Category: {self.category.name}")
        lines.append(f"Difficulty: {'⭐' * int(self.difficulty)}")
        if self.time_limit:
            lines.append(f"Time Limit: {self.time_limit:.0f}s")
        lines.append("")
        lines.append("═══ OBJECTIVES ═══")
        for i, obj in enumerate(self.objectives, 1):
            lines.append(f"  {i}. {obj.describe()}")
        lines.append("")
        if self.description:
            lines.append("═══ LORE ═══")
            lines.append(f"  {self.description}")
            lines.append("")
        if self.required_operations:
            lines.append("═══ REQUIRED OPERATIONS ═══")
            for op in self.required_operations:
                lines.append(f"  • {op.name}")
        if self.forbidden_operations:
            lines.append("")
            lines.append("═══ FORBIDDEN ═══")
            for op in self.forbidden_operations:
                lines.append(f"  ⛔ {op.name}")
        if self.bonus_conditions:
            lines.append("")
            lines.append("═══ BONUS ═══")
            for cond in self.bonus_conditions:
                lines.append(f"  ★ {cond.describe()}")
        return "\n".join(lines)


class QuantumQuestGenerator:
    """Generates quantum-rich quests from faction patterns"""
    
    def __init__(self):
        self.quest_templates = self._build_templates()
    
    def _build_templates(self) -> Dict[QuestCategory, List[dict]]:
        """Build quest templates for each category"""
        return {
            QuestCategory.STATE_PREPARATION: [
                {
                    "title_template": "Prepare the {target} State",
                    "objectives": [
                        {"type": ObjectiveType.PREPARE_STATE, "observable": QuantumObservable.THETA}
                    ],
                    "difficulty_base": 1.0,
                },
                {
                    "title_template": "Superposition of {emoji1} and {emoji2}",
                    "objectives": [
                        {"type": ObjectiveType.PREPARE_SUPERPOSITION, "observable": QuantumObservable.COHERENCE}
                    ],
                    "difficulty_base": 1.5,
                },
            ],
            QuestCategory.ENTANGLEMENT_FORGE: [
                {
                    "title_template": "The Bell Forge: {emoji1}↔{emoji2}",
                    "objectives": [
                        {"type": ObjectiveType.CREATE_BELL_PAIR, "observable": QuantumObservable.ENTANGLEMENT}
                    ],
                    "difficulty_base": 2.0,
                },
                {
                    "title_template": "Entangle the Distant Fields",
                    "objectives": [
                        {"type": ObjectiveType.CREATE_BELL_PAIR, "observable": QuantumObservable.ENTANGLEMENT},
                        {"type": ObjectiveType.MAINTAIN_ENTANGLEMENT, "observable": QuantumObservable.CORRELATION}
                    ],
                    "difficulty_base": 2.5,
                },
            ],
            QuestCategory.COHERENCE_TRIAL: [
                {
                    "title_template": "The Coherence Marathon",
                    "objectives": [
                        {"type": ObjectiveType.MAINTAIN_COHERENCE, "observable": QuantumObservable.COHERENCE}
                    ],
                    "difficulty_base": 1.5,
                    "duration": 30.0,
                },
                {
                    "title_template": "Decoherence Storm Survival",
                    "objectives": [
                        {"type": ObjectiveType.MAINTAIN_COHERENCE, "observable": QuantumObservable.COHERENCE},
                        {"type": ObjectiveType.STABILIZE, "observable": QuantumObservable.RADIUS}
                    ],
                    "difficulty_base": 2.0,
                    "duration": 20.0,
                },
            ],
            QuestCategory.TOPOLOGICAL_QUEST: [
                {
                    "title_template": "Accumulate the Berry Phase",
                    "objectives": [
                        {"type": ObjectiveType.ACCUMULATE_BERRY, "observable": QuantumObservable.BERRY_PHASE}
                    ],
                    "difficulty_base": 3.0,
                },
                {
                    "title_template": "The Geometric Journey",
                    "objectives": [
                        {"type": ObjectiveType.ACHIEVE_PHASE, "observable": QuantumObservable.PHI},
                        {"type": ObjectiveType.ACCUMULATE_BERRY, "observable": QuantumObservable.BERRY_PHASE}
                    ],
                    "difficulty_base": 3.5,
                },
            ],
            QuestCategory.AMPLITUDE_SCULPTING: [
                {
                    "title_template": "Concentrate the {emoji} Essence",
                    "objectives": [
                        {"type": ObjectiveType.CONCENTRATE, "observable": QuantumObservable.AMPLITUDE}
                    ],
                    "difficulty_base": 1.0,
                },
                {
                    "title_template": "The Great Redistribution",
                    "objectives": [
                        {"type": ObjectiveType.SPREAD, "observable": QuantumObservable.ENTROPY}
                    ],
                    "difficulty_base": 1.5,
                },
            ],
            QuestCategory.MEASUREMENT_GAME: [
                {
                    "title_template": "Measure {n} {emoji} in a Row",
                    "objectives": [
                        {"type": ObjectiveType.MEASURE_OUTCOME, "observable": QuantumObservable.PROBABILITY_NORTH}
                    ],
                    "difficulty_base": 1.0,
                },
                {
                    "title_template": "The Statistics Challenge",
                    "objectives": [
                        {"type": ObjectiveType.MEASURE_STATISTICS, "observable": QuantumObservable.ENTROPY}
                    ],
                    "difficulty_base": 2.0,
                },
            ],
            QuestCategory.QUANTUM_RELAY: [
                {
                    "title_template": "Transfer {emoji} Across the Field",
                    "objectives": [
                        {"type": ObjectiveType.TRANSFER_AMPLITUDE, "observable": QuantumObservable.AMPLITUDE}
                    ],
                    "difficulty_base": 2.0,
                },
            ],
            QuestCategory.CYCLE_SYNC: [
                {
                    "title_template": "Resonate with the {cycle}",
                    "objectives": [
                        {"type": ObjectiveType.RESONANCE, "observable": QuantumObservable.OSCILLATION_FREQUENCY}
                    ],
                    "difficulty_base": 2.5,
                },
            ],
            QuestCategory.DOUBLE_SLIT: [
                {
                    "title_template": "Create the Interference Pattern",
                    "objectives": [
                        {"type": ObjectiveType.INTERFERENCE_PATTERN, "observable": QuantumObservable.COHERENCE},
                        {"type": ObjectiveType.CONSTRUCTIVE, "observable": QuantumObservable.AMPLITUDE}
                    ],
                    "difficulty_base": 3.0,
                },
            ],
            QuestCategory.ECOSYSTEM_BALANCE: [
                {
                    "title_template": "Balance the {predator}/{prey} Cycle",
                    "objectives": [
                        {"type": ObjectiveType.STABILIZE, "observable": QuantumObservable.OSCILLATION_FREQUENCY},
                        {"type": ObjectiveType.COHERENT_OSCILLATION, "observable": QuantumObservable.THETA}
                    ],
                    "difficulty_base": 2.5,
                },
            ],
        }
    
    def generate_from_pattern(
        self, 
        pattern: str,  # 12-bit faction pattern
        biome_emojis: List[str],
        category: Optional[QuestCategory] = None
    ) -> QuantumQuest:
        """Generate a quantum quest from faction bit pattern"""
        
        bits = [int(b) for b in pattern]
        
        # Select category based on pattern if not specified
        if category is None:
            category = self._select_category_from_bits(bits)
        
        # Get template
        templates = self.quest_templates.get(category, [])
        if not templates:
            templates = self.quest_templates[QuestCategory.STATE_PREPARATION]
        
        template = random.choice(templates)
        
        # Select emojis based on bit pattern
        emoji1, emoji2 = self._select_emojis_from_bits(bits, biome_emojis)
        
        # Generate objectives
        objectives = self._generate_objectives(
            template, bits, emoji1, emoji2, biome_emojis
        )
        
        # Calculate difficulty
        difficulty = template.get("difficulty_base", 1.0)
        difficulty *= self._difficulty_modifier_from_bits(bits)
        
        # Generate title
        title = self._generate_title(template, emoji1, emoji2, bits)
        
        # Determine required and forbidden operations
        required_ops = self._required_operations_from_bits(bits, category)
        forbidden_ops = self._forbidden_operations_from_bits(bits)
        
        # Generate time limit
        time_limit = template.get("duration", None)
        if bits[4]:  # ⚡ instant bit
            time_limit = (time_limit or 60.0) / 2
        if bits[5]:  # 🕰️ eternal bit
            time_limit = None
        
        # Generate description
        description = self._generate_description(category, emoji1, emoji2, bits)
        
        return QuantumQuest(
            title=title,
            category=category,
            objectives=objectives,
            required_operations=required_ops,
            emoji_vocabulary=[emoji1, emoji2] + biome_emojis[:3],
            difficulty=difficulty,
            time_limit=time_limit,
            faction_pattern=pattern,
            biome_context="generated",
            forbidden_operations=forbidden_ops,
            description=description,
        )
    
    def _select_category_from_bits(self, bits: List[int]) -> QuestCategory:
        """Select quest category based on bit pattern"""
        
        # bits[0] = deterministic/random
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
        elif bits[4]:  # Instant
            return QuestCategory.QUANTUM_RELAY
        elif bits[5]:  # Eternal
            return QuestCategory.COHERENCE_TRIAL
        elif bits[9]:  # Prismatic
            return QuestCategory.DOUBLE_SLIT
        else:
            return random.choice(list(QuestCategory))
    
    def _select_emojis_from_bits(
        self, bits: List[int], biome_emojis: List[str]
    ) -> Tuple[str, str]:
        """Select two emojis based on bit pattern and biome"""
        
        # Use bits to index into emojis
        idx1 = (bits[0] * 4 + bits[1] * 2 + bits[2]) % len(biome_emojis)
        idx2 = (bits[3] * 4 + bits[4] * 2 + bits[5]) % len(biome_emojis)
        
        if idx1 == idx2:
            idx2 = (idx2 + 1) % len(biome_emojis)
        
        return biome_emojis[idx1], biome_emojis[idx2]
    
    def _generate_objectives(
        self, 
        template: dict, 
        bits: List[int],
        emoji1: str,
        emoji2: str,
        biome_emojis: List[str]
    ) -> List[QuantumObjective]:
        """Generate objectives from template"""
        
        objectives = []
        
        for obj_template in template.get("objectives", []):
            obj_type = obj_template["type"]
            observable = obj_template["observable"]
            
            # Generate target value based on bits
            target = self._generate_target_value(observable, bits)
            
            # Generate tolerance based on bits
            if bits[0]:  # Deterministic = tight tolerance
                tolerance = 0.05
            else:  # Random = loose tolerance
                tolerance = 0.2
            
            condition = QuantumCondition(
                observable=observable,
                comparison=ComparisonOp.IN_RANGE,
                target_value=target,
                tolerance=tolerance,
                emoji_pair=(emoji1, emoji2) if observable in [
                    QuantumObservable.THETA, 
                    QuantumObservable.PHI, 
                    QuantumObservable.COHERENCE
                ] else None,
                emoji_target=emoji1 if observable == QuantumObservable.AMPLITUDE else None,
            )
            
            # Duration requirement
            duration = None
            if template.get("duration"):
                duration = template["duration"]
                if bits[5]:  # Eternal = longer
                    duration *= 2
                if bits[4]:  # Instant = shorter
                    duration /= 2
            
            objective = QuantumObjective(
                objective_type=obj_type,
                conditions=[condition],
                duration_requirement=duration,
            )
            
            objectives.append(objective)
        
        return objectives
    
    def _generate_target_value(
        self, observable: QuantumObservable, bits: List[int]
    ) -> float:
        """Generate target value for observable based on bits"""
        
        if observable == QuantumObservable.THETA:
            # Use bits to select angle
            angle_choices = [0, math.pi/4, math.pi/2, 3*math.pi/4, math.pi]
            idx = (bits[6] * 2 + bits[7]) % len(angle_choices)
            return angle_choices[idx]
        
        elif observable == QuantumObservable.PHI:
            # Phase based on bits
            phase_choices = [0, math.pi/2, math.pi, 3*math.pi/2]
            idx = (bits[8] * 2 + bits[9]) % len(phase_choices)
            return phase_choices[idx]
        
        elif observable == QuantumObservable.COHERENCE:
            # Coherence target
            if bits[6]:  # Crystalline = low coherence (classical)
                return 0.2
            else:  # Fluid = high coherence (quantum)
                return 0.8
        
        elif observable == QuantumObservable.ENTANGLEMENT:
            return 0.9 if bits[3] else 0.5  # Cosmic = strong entanglement
        
        elif observable == QuantumObservable.AMPLITUDE:
            return 0.7 if bits[8] else 0.5
        
        elif observable == QuantumObservable.BERRY_PHASE:
            return math.pi * (1 + bits[10])  # π or 2π
        
        elif observable == QuantumObservable.ENTROPY:
            if bits[9]:  # Prismatic = high entropy
                return 0.9
            else:  # Monochrome = low entropy
                return 0.3
        
        else:
            return 0.5
    
    def _difficulty_modifier_from_bits(self, bits: List[int]) -> float:
        """Calculate difficulty modifier from bits"""
        
        modifier = 1.0
        
        # Deterministic = easier (clear goals)
        if bits[0]:
            modifier *= 0.8
        
        # Mystical = harder (unclear mechanics)
        if bits[1]:
            modifier *= 1.2
        
        # Cosmic = harder (larger scale)
        if bits[3]:
            modifier *= 1.3
        
        # Instant = harder (time pressure)
        if bits[4]:
            modifier *= 1.2
        
        # Crystalline = easier (stable)
        if bits[6]:
            modifier *= 0.9
        
        # Focused = easier (clear target)
        if bits[11]:
            modifier *= 0.9
        
        return modifier
    
    def _required_operations_from_bits(
        self, bits: List[int], category: QuestCategory
    ) -> List[QuantumOperation]:
        """Determine required operations"""
        
        ops = []
        
        # Always need projection for most quests
        if category not in [QuestCategory.MEASUREMENT_GAME]:
            ops.append(QuantumOperation.CREATE_PROJECTION)
        
        # Category-specific
        if category == QuestCategory.ENTANGLEMENT_FORGE:
            ops.append(QuantumOperation.BELL_ENTANGLE)
        
        if category == QuestCategory.TOPOLOGICAL_QUEST:
            ops.append(QuantumOperation.ROTATION_Z)
        
        if category == QuestCategory.COHERENCE_TRIAL:
            if bits[6]:  # Crystalline = decohere
                ops.append(QuantumOperation.STRONG_MEASURE)
            else:  # Fluid = maintain
                ops.append(QuantumOperation.WEAK_MEASURE)
        
        if category == QuestCategory.AMPLITUDE_SCULPTING:
            ops.append(QuantumOperation.INJECT_AMPLITUDE)
        
        return ops
    
    def _forbidden_operations_from_bits(self, bits: List[int]) -> List[QuantumOperation]:
        """Determine forbidden operations"""
        
        forbidden = []
        
        # Direct = no subtle operations
        if not bits[7]:
            forbidden.append(QuantumOperation.WEAK_MEASURE)
        
        # Subtle = no direct operations
        if bits[7]:
            forbidden.append(QuantumOperation.STRONG_MEASURE)
        
        # Emergent = no imposed operations
        if not bits[10]:
            forbidden.append(QuantumOperation.INJECT_AMPLITUDE)
        
        return forbidden
    
    def _generate_title(
        self, template: dict, emoji1: str, emoji2: str, bits: List[int]
    ) -> str:
        """Generate quest title"""
        
        title_template = template.get("title_template", "Quantum Quest")
        
        # Substitutions
        title = title_template.replace("{emoji1}", emoji1)
        title = title.replace("{emoji2}", emoji2)
        title = title.replace("{emoji}", emoji1)
        
        # Target based on theta
        targets = ["North Pole", "Equator", "South Pole", "Superposition"]
        target_idx = (bits[6] * 2 + bits[7]) % len(targets)
        title = title.replace("{target}", targets[target_idx])
        
        # Cycle names
        cycles = ["Solar Cycle", "Lunar Rhythm", "Predator Wave", "Market Pulse"]
        cycle_idx = (bits[8] * 2 + bits[9]) % len(cycles)
        title = title.replace("{cycle}", cycles[cycle_idx])
        
        # Predator/prey
        predators = ["🐺", "🦅", "🐍"]
        prey = ["🐇", "🐭", "🦌"]
        title = title.replace("{predator}", random.choice(predators))
        title = title.replace("{prey}", random.choice(prey))
        
        # Count
        n = 2 + (bits[2] * 2 + bits[3])
        title = title.replace("{n}", str(n))
        
        return title
    
    def _generate_description(
        self, category: QuestCategory, emoji1: str, emoji2: str, bits: List[int]
    ) -> str:
        """Generate quest lore description"""
        
        descriptions = {
            QuestCategory.STATE_PREPARATION: [
                f"The quantum field cries out for order. Shape the {emoji1}/{emoji2} axis to align with cosmic harmony.",
                f"The bath trembles between {emoji1} and {emoji2}. Guide it to stability.",
            ],
            QuestCategory.ENTANGLEMENT_FORGE: [
                f"Two distant projections call to each other across the void. Forge the Bell link between {emoji1} and {emoji2}.",
                f"The threads of quantum correlation await weaving. Entangle the {emoji1}/{emoji2} pair.",
            ],
            QuestCategory.COHERENCE_TRIAL: [
                f"The decoherence winds howl across the bath. Protect the fragile superposition of {emoji1} and {emoji2}.",
                f"Entropy seeks to collapse all possibility. Maintain the quantum dance between {emoji1} and {emoji2}.",
            ],
            QuestCategory.TOPOLOGICAL_QUEST: [
                f"Walk the path around the Bloch sphere. Let geometric phase accumulate as {emoji1} transforms into {emoji2} and back.",
                f"The Berry phase remembers every journey. Trace the cycle from {emoji1} through {emoji2}.",
            ],
            QuestCategory.DOUBLE_SLIT: [
                f"Let {emoji1} pass through both paths. Watch the interference fringes emerge where {emoji2} awaits.",
                f"Two possibilities, one outcome. Create the pattern that reveals the quantum nature of {emoji1}.",
            ],
        }
        
        options = descriptions.get(category, [f"Manipulate the quantum bath involving {emoji1} and {emoji2}."])
        return random.choice(options)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: QUANTUM QUEST EVALUATOR
# Checks if quantum conditions are satisfied
# ═══════════════════════════════════════════════════════════════════════════════

class QuantumQuestEvaluator:
    """Evaluates quantum quest conditions against bath state"""
    
    def __init__(self):
        pass
    
    def evaluate_condition(
        self, 
        condition: QuantumCondition, 
        bath_state: Dict,  # Simulated bath state
        projections: Dict[str, Dict]  # Active projections
    ) -> Tuple[bool, float]:
        """
        Evaluate a quantum condition.
        Returns (satisfied, current_value)
        """
        
        observable = condition.observable
        comparison = condition.comparison
        target = condition.target_value
        tolerance = condition.tolerance
        
        # Get current value based on observable type
        current = self._get_observable_value(
            observable, 
            bath_state, 
            projections,
            condition.emoji_target,
            condition.emoji_pair,
            condition.second_projection
        )
        
        if current is None:
            return False, 0.0
        
        # Evaluate comparison
        satisfied = self._compare(current, target, tolerance, comparison)
        
        return satisfied, current
    
    def _get_observable_value(
        self,
        observable: QuantumObservable,
        bath: Dict,
        projections: Dict,
        emoji: Optional[str],
        pair: Optional[Tuple[str, str]],
        second_pair: Optional[Tuple[str, str]]
    ) -> Optional[float]:
        """Extract observable value from state"""
        
        if observable == QuantumObservable.THETA:
            if pair and pair in projections:
                return projections[pair].get("theta", 0.0)
            return None
        
        elif observable == QuantumObservable.PHI:
            if pair and pair in projections:
                return projections[pair].get("phi", 0.0)
            return None
        
        elif observable == QuantumObservable.RADIUS:
            if pair and pair in projections:
                return projections[pair].get("radius", 0.0)
            return None
        
        elif observable == QuantumObservable.COHERENCE:
            if pair and pair in projections:
                theta = projections[pair].get("theta", math.pi/2)
                return math.sin(theta)  # Maximum at equator
            return None
        
        elif observable == QuantumObservable.AMPLITUDE:
            if emoji and emoji in bath.get("amplitudes", {}):
                amp = bath["amplitudes"][emoji]
                return math.sqrt(amp.get("re", 0)**2 + amp.get("im", 0)**2)
            return None
        
        elif observable == QuantumObservable.PHASE:
            if emoji and emoji in bath.get("amplitudes", {}):
                amp = bath["amplitudes"][emoji]
                return math.atan2(amp.get("im", 0), amp.get("re", 0))
            return None
        
        elif observable == QuantumObservable.ENTROPY:
            probs = bath.get("probabilities", {})
            if probs:
                entropy = 0.0
                for p in probs.values():
                    if p > 0:
                        entropy -= p * math.log2(p)
                return entropy
            return None
        
        elif observable == QuantumObservable.ENTANGLEMENT:
            if pair and second_pair:
                # Bell fidelity calculation would go here
                return bath.get("entanglement", {}).get((pair, second_pair), 0.0)
            return None
        
        elif observable == QuantumObservable.CORRELATION:
            if pair and second_pair:
                return bath.get("correlations", {}).get((pair, second_pair), 0.0)
            return None
        
        elif observable == QuantumObservable.BERRY_PHASE:
            if pair and pair in projections:
                return projections[pair].get("accumulated_berry", 0.0)
            return None
        
        else:
            return None
    
    def _compare(
        self, 
        current: float, 
        target: float, 
        tolerance: float, 
        op: ComparisonOp
    ) -> bool:
        """Perform comparison operation"""
        
        if op == ComparisonOp.EQUALS:
            return abs(current - target) < tolerance
        elif op == ComparisonOp.APPROX:
            return abs(current - target) < tolerance * 2
        elif op == ComparisonOp.LESS:
            return current < target
        elif op == ComparisonOp.GREATER:
            return current > target
        elif op == ComparisonOp.LESS_EQ:
            return current <= target + tolerance
        elif op == ComparisonOp.GREATER_EQ:
            return current >= target - tolerance
        elif op == ComparisonOp.IN_RANGE:
            return target - tolerance <= current <= target + tolerance
        elif op == ComparisonOp.NEAR:
            return abs(current - target) < tolerance * 3
        else:
            return False
    
    def evaluate_objective(
        self,
        objective: QuantumObjective,
        bath_state: Dict,
        projections: Dict
    ) -> Tuple[bool, Dict]:
        """Evaluate complete objective"""
        
        results = {}
        all_satisfied = True
        
        for condition in objective.conditions:
            satisfied, value = self.evaluate_condition(
                condition, bath_state, projections
            )
            results[condition.describe()] = {
                "satisfied": satisfied,
                "current_value": value,
                "target": condition.target_value,
            }
            if not satisfied:
                all_satisfied = False
        
        return all_satisfied, results
    
    def evaluate_quest(
        self,
        quest: QuantumQuest,
        bath_state: Dict,
        projections: Dict
    ) -> Tuple[bool, Dict]:
        """Evaluate complete quest"""
        
        results = {}
        all_complete = True
        
        for i, objective in enumerate(quest.objectives):
            satisfied, obj_results = self.evaluate_objective(
                objective, bath_state, projections
            )
            results[f"Objective {i+1}"] = {
                "satisfied": satisfied,
                "details": obj_results
            }
            if not satisfied:
                all_complete = False
        
        return all_complete, results


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 9: QUANTUM QUEST DISPLAY
# Emoji-based visualization of quantum quests
# ═══════════════════════════════════════════════════════════════════════════════

class QuantumQuestDisplay:
    """Generate visual displays for quantum quests"""
    
    # Observable to emoji mapping
    OBSERVABLE_EMOJI = {
        QuantumObservable.THETA: "θ",
        QuantumObservable.PHI: "φ",
        QuantumObservable.RADIUS: "r",
        QuantumObservable.COHERENCE: "🌊",
        QuantumObservable.AMPLITUDE: "|α|",
        QuantumObservable.PHASE: "∠",
        QuantumObservable.ENTROPY: "S",
        QuantumObservable.ENTANGLEMENT: "🔗",
        QuantumObservable.CORRELATION: "↔",
        QuantumObservable.BERRY_PHASE: "🍇",
        QuantumObservable.OSCILLATION_FREQUENCY: "〰",
    }
    
    # Operation to emoji mapping
    OPERATION_EMOJI = {
        QuantumOperation.CREATE_PROJECTION: "👁️",
        QuantumOperation.WEAK_MEASURE: "👀",
        QuantumOperation.STRONG_MEASURE: "💥",
        QuantumOperation.HADAMARD: "H",
        QuantumOperation.BELL_ENTANGLE: "🔗",
        QuantumOperation.PHASE_SHIFT: "🔄",
        QuantumOperation.ROTATION_X: "↻X",
        QuantumOperation.ROTATION_Y: "↻Y",
        QuantumOperation.ROTATION_Z: "↻Z",
        QuantumOperation.EVOLVE: "⏳",
        QuantumOperation.INJECT_AMPLITUDE: "💉",
    }
    
    # Category emoji
    CATEGORY_EMOJI = {
        QuestCategory.STATE_PREPARATION: "🎯",
        QuestCategory.ENTANGLEMENT_FORGE: "🔗",
        QuestCategory.COHERENCE_TRIAL: "🌊",
        QuestCategory.TOPOLOGICAL_QUEST: "🍇",
        QuestCategory.AMPLITUDE_SCULPTING: "🗿",
        QuestCategory.MEASUREMENT_GAME: "🎲",
        QuestCategory.DOUBLE_SLIT: "🌈",
        QuestCategory.ECOSYSTEM_BALANCE: "⚖️",
        QuestCategory.QUANTUM_RELAY: "📡",
        QuestCategory.CYCLE_SYNC: "🔄",
    }
    
    def display_emoji_only(self, quest: QuantumQuest) -> str:
        """Generate pure emoji quest display"""
        
        lines = []
        
        # Category symbol
        cat_emoji = self.CATEGORY_EMOJI.get(quest.category, "⚛️")
        
        # Difficulty stars
        stars = "⭐" * int(quest.difficulty)
        
        # Emoji line 1: Category + Emojis involved
        emoji_line = f"{cat_emoji} "
        emoji_line += " ".join(quest.emoji_vocabulary[:3])
        lines.append(emoji_line)
        
        # Emoji line 2: Operations required
        op_line = "→ "
        for op in quest.required_operations[:4]:
            op_line += self.OPERATION_EMOJI.get(op, "?") + " "
        lines.append(op_line)
        
        # Emoji line 3: Target condition summary
        if quest.objectives:
            obj = quest.objectives[0]
            if obj.conditions:
                cond = obj.conditions[0]
                obs_sym = self.OBSERVABLE_EMOJI.get(cond.observable, "?")
                target_sym = self._value_to_emoji(cond.target_value, cond.observable)
                lines.append(f"◎ {obs_sym} → {target_sym}")
        
        # Emoji line 4: Difficulty + time
        time_emoji = "⏱️" if quest.time_limit else "∞"
        lines.append(f"{stars} {time_emoji}")
        
        return "\n".join(lines)
    
    def _value_to_emoji(self, value: float, observable: QuantumObservable) -> str:
        """Convert target value to emoji representation"""
        
        if observable in [QuantumObservable.THETA]:
            # Angle to arrow
            if value < 0.1:
                return "⬆️"  # North
            elif value > math.pi - 0.1:
                return "⬇️"  # South
            elif abs(value - math.pi/2) < 0.2:
                return "↔️"  # Equator
            else:
                return "↗️"  # In between
        
        elif observable in [QuantumObservable.PHI]:
            # Phase to time-of-day
            phases = ["🌅", "☀️", "🌆", "🌙"]
            idx = int((value / (2 * math.pi)) * 4) % 4
            return phases[idx]
        
        elif observable in [QuantumObservable.COHERENCE]:
            if value > 0.7:
                return "✨"
            elif value > 0.3:
                return "🌗"
            else:
                return "🧱"
        
        elif observable == QuantumObservable.ENTANGLEMENT:
            if value > 0.8:
                return "🔗🔗"
            elif value > 0.5:
                return "🔗"
            else:
                return "✂️"
        
        elif observable == QuantumObservable.BERRY_PHASE:
            cycles = int(value / math.pi)
            return "🔄" * max(1, cycles)
        
        else:
            return f"{value:.1f}"
    
    def display_progress(
        self, 
        quest: QuantumQuest, 
        evaluation_results: Dict
    ) -> str:
        """Display quest with progress indicators"""
        
        lines = []
        lines.append(f"╔{'═'*50}╗")
        lines.append(f"║ {quest.title[:48]:^48} ║")
        lines.append(f"╚{'═'*50}╝")
        
        for obj_name, obj_data in evaluation_results.items():
            status = "✅" if obj_data["satisfied"] else "⏳"
            lines.append(f"{status} {obj_name}")
            
            for cond_name, cond_data in obj_data["details"].items():
                cond_status = "●" if cond_data["satisfied"] else "○"
                current = cond_data["current_value"]
                target = cond_data["target"]
                progress = min(1.0, current / target) if target > 0 else 0
                bar_len = 20
                filled = int(progress * bar_len)
                bar = "█" * filled + "░" * (bar_len - filled)
                lines.append(f"  {cond_status} [{bar}] {current:.2f}/{target:.2f}")
        
        return "\n".join(lines)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10: DEMOS AND EXAMPLES
# ═══════════════════════════════════════════════════════════════════════════════

def demo_quantum_quest_generation():
    """Demonstrate quantum quest generation"""
    
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║          QUANTUM QUEST SYSTEM DEMONSTRATION                      ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print()
    
    generator = QuantumQuestGenerator()
    display = QuantumQuestDisplay()
    
    # Sample biome emojis
    biotic_emojis = ["🌾", "🌿", "🐺", "🐇", "☀️", "💀", "🍄", "🌳"]
    forest_emojis = ["🌲", "🐺", "🦌", "🦅", "🐭", "🌿", "🍂", "☀️"]
    market_emojis = ["📈", "📉", "💰", "📦", "🏪", "🛒", "💎", "🪙"]
    
    # Sample faction patterns
    patterns = [
        ("110111001101", "Carrion Throne", biotic_emojis),
        ("011111111100", "Laughing Court", forest_emojis),
        ("111111111111", "Entropy Shepherds", biotic_emojis),
        ("010111100000", "Rust Fleet", market_emojis),
        ("110100000001", "Millwright's Union", forest_emojis),
    ]
    
    for pattern, faction_name, emojis in patterns:
        print(f"\n{'='*70}")
        print(f"Faction: {faction_name}")
        print(f"Pattern: {pattern}")
        print(f"{'='*70}")
        
        # Generate quest
        quest = generator.generate_from_pattern(pattern, emojis)
        
        # Full description
        print(quest.describe_full())
        
        # Emoji-only version
        print("\n--- EMOJI ONLY ---")
        print(display.display_emoji_only(quest))
    
    print("\n")


def demo_category_showcase():
    """Show quests from each category"""
    
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║          QUEST CATEGORY SHOWCASE                                 ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print()
    
    generator = QuantumQuestGenerator()
    display = QuantumQuestDisplay()
    
    emojis = ["🌾", "🌿", "🐺", "🐇", "☀️", "🌙", "💀", "🍄"]
    
    for category in QuestCategory:
        print(f"\n--- {category.name} ---")
        
        # Random pattern
        pattern = "".join(str(random.randint(0, 1)) for _ in range(12))
        
        quest = generator.generate_from_pattern(pattern, emojis, category)
        
        print(f"Title: {quest.title}")
        print(f"Difficulty: {'⭐' * int(quest.difficulty)}")
        
        for obj in quest.objectives:
            print(f"  → {obj.describe()}")
        
        print(f"Emoji: {display.display_emoji_only(quest)}")


def demo_evaluation():
    """Demonstrate quest evaluation"""
    
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║          QUEST EVALUATION DEMONSTRATION                          ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print()
    
    generator = QuantumQuestGenerator()
    evaluator = QuantumQuestEvaluator()
    display = QuantumQuestDisplay()
    
    # Generate a quest
    emojis = ["🌾", "🐺", "🐇", "☀️"]
    quest = generator.generate_from_pattern("110111001101", emojis)
    
    print(quest.describe_full())
    
    # Simulate bath state
    bath_state = {
        "amplitudes": {
            "🌾": {"re": 0.5, "im": 0.3},
            "🐺": {"re": 0.4, "im": 0.2},
            "🐇": {"re": 0.3, "im": 0.4},
            "☀️": {"re": 0.6, "im": 0.1},
        },
        "probabilities": {
            "🌾": 0.34,
            "🐺": 0.20,
            "🐇": 0.25,
            "☀️": 0.21,
        }
    }
    
    # Simulate projections
    projections = {
        ("🌾", "🐺"): {"theta": 0.8, "phi": 1.2, "radius": 0.7},
        ("🐇", "☀️"): {"theta": 1.5, "phi": 2.1, "radius": 0.5},
    }
    
    # Evaluate
    complete, results = evaluator.evaluate_quest(quest, bath_state, projections)
    
    print("\n--- EVALUATION RESULTS ---")
    print(f"Quest Complete: {complete}")
    print(display.display_progress(quest, results))


def demo_combinatorics():
    """Show combinatoric space of quantum quests"""
    
    print("╔══════════════════════════════════════════════════════════════════╗")
    print("║          QUANTUM QUEST COMBINATORICS                             ║")
    print("╚══════════════════════════════════════════════════════════════════╝")
    print()
    
    # Count atoms
    print("QUANTUM VOCABULARY ATOMS:")
    print(f"  • Quantum Verbs: {len(QUANTUM_VERBS)}")
    print(f"  • Observable Targets: {len(OBSERVABLE_TARGETS)}")
    print(f"  • Quantum Modifiers: {len(QUANTUM_MODIFIERS)}")
    print(f"  • Target Values: {len(TARGET_VALUES)}")
    print(f"  • Quest Categories: {len(QuestCategory)}")
    print(f"  • Observables: {len(QuantumObservable)}")
    print(f"  • Operations: {len(QuantumOperation)}")
    print(f"  • Comparison Operators: {len(ComparisonOp)}")
    
    total_atoms = (
        len(QUANTUM_VERBS) +
        len(OBSERVABLE_TARGETS) +
        len(QUANTUM_MODIFIERS) +
        len(TARGET_VALUES) +
        len(QuestCategory) +
        len(QuantumObservable) +
        len(QuantumOperation) +
        len(ComparisonOp)
    )
    print(f"\n  TOTAL ATOMS: {total_atoms}")
    
    # Quest variations
    print("\nQUANTUM QUEST COMBINATIONS:")
    
    # Simple calculation
    verb_combos = len(QUANTUM_VERBS)
    target_combos = len(OBSERVABLE_TARGETS)
    modifier_combos = len(QUANTUM_MODIFIERS) ** 2  # Pairs
    value_combos = len(TARGET_VALUES)
    category_combos = len(QuestCategory)
    emoji_combos = 8 * 7  # Pairs from 8 emojis
    bit_patterns = 2 ** 12  # 12-bit faction patterns
    
    simple_quests = verb_combos * target_combos * modifier_combos * emoji_combos
    print(f"  • Simple Quests (verb × target × mod² × emoji): {simple_quests:,}")
    
    with_categories = simple_quests * category_combos
    print(f"  • With Categories: {with_categories:,}")
    
    with_bits = with_categories * bit_patterns
    print(f"  • With Faction Patterns: {with_bits:,}")
    
    # Multi-objective quests
    multi_objective = with_bits ** 3  # Up to 3 objectives
    print(f"  • Multi-Objective (up to 3): {multi_objective:.2e}")
    
    # Full combinatoric space
    print("\nFULL COMBINATORIC SPACE:")
    print(f"  ~10^15 unique quantum quests")
    print(f"  From only ~{total_atoms} vocabulary atoms!")


if __name__ == "__main__":
    print("\n" + "="*70)
    print(" SPACEWHEAT QUANTUM QUEST SYSTEM")
    print(" Beyond 'Gather X' - Engineering Quantum States")
    print("="*70 + "\n")
    
    demo_quantum_quest_generation()
    print("\n" + "="*70 + "\n")
    
    demo_category_showcase()
    print("\n" + "="*70 + "\n")
    
    demo_evaluation()
    print("\n" + "="*70 + "\n")
    
    demo_combinatorics()
