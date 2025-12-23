# Migration Guide: Python QAGIS → GDScript Quantum Substrate

**Date**: 2025-12-13
**Purpose**: Translate Python quantum simulation to pure GDScript implementation
**Scope**: Simplify for 12-node tomato network + wheat qubits

## Philosophy of Simplification

### What We're Keeping
- **Bloch sphere representation** (θ, φ angles)
- **Energy flow dynamics** (diffusion between nodes)
- **Entanglement network topology** (12 nodes, 15 connections)
- **Conspiracy activation logic** (threshold-based triggers)
- **Gaussian state tracking** (q, p as simple floats)

### What We're Discarding
- Full symplectic formalism (too complex for kids' game)
- 16-mode QAGIS system (only need 12 for tomatoes)
- NetworkX library (use simple Dictionary + Array)
- Heavy linear algebra (use GDScript Vector math)
- Python-specific quantum libraries (qutip, scipy)

### Core Principle
> "The minimum quantum mechanics needed to make tomatoes feel alive"

## Python → GDScript Translation Patterns

### 1. Bloch Sphere Math

#### Python (QAGIS Kernel)
```python
import numpy as np

class GaussianBlochMode:
    theta: float  # Polar angle [0, π]
    phi: float    # Azimuthal angle [-π, π]
    radius: float # Amplitude

    def apply_bloch_rotation(self, axis: np.ndarray, angle: float):
        # Current Bloch vector
        x = np.sin(self.theta) * np.cos(self.phi)
        y = np.sin(self.theta) * np.sin(self.phi)
        z = np.cos(self.theta)
        v = np.array([x, y, z])

        # Normalize axis
        axis = axis / np.linalg.norm(axis)

        # Rodrigues rotation formula
        v_rot = (v * np.cos(angle) +
                np.cross(axis, v) * np.sin(angle) +
                axis * np.dot(axis, v) * (1 - np.cos(angle)))

        # Convert back to spherical
        self.theta = np.arccos(np.clip(v_rot[2], -1, 1))
        if np.abs(np.sin(self.theta)) > 1e-6:
            self.phi = np.arctan2(v_rot[1], v_rot[0])
```

#### GDScript (Simplified)
```gdscript
class_name QuantumNode
extends Resource

@export var theta: float = 0.0  # [0, PI]
@export var phi: float = 0.0    # [-PI, PI]
@export var radius: float = 1.0

func get_bloch_vector() -> Vector3:
    return Vector3(
        sin(theta) * cos(phi),
        sin(theta) * sin(phi),
        cos(theta)
    )

func apply_bloch_rotation(axis: Vector3, angle: float):
    # Get current Bloch vector
    var v = get_bloch_vector()

    # Normalize axis
    axis = axis.normalized()

    # Rodrigues rotation (simplified)
    var cos_a = cos(angle)
    var sin_a = sin(angle)
    var dot_av = axis.dot(v)

    var v_rot = v * cos_a + axis.cross(v) * sin_a + axis * dot_av * (1.0 - cos_a)

    # Convert back to spherical
    theta = acos(clamp(v_rot.z, -1.0, 1.0))
    if abs(sin(theta)) > 0.001:
        phi = atan2(v_rot.y, v_rot.x)

func simple_evolve(dt: float):
    # Simpler: Just rotate based on energy
    theta += energy * dt * 0.05
    theta = clamp(theta, 0.0, PI)

    phi += dt * energy * 0.1  # Phase precession
    phi = fmod(phi + PI, TAU) - PI  # Keep in [-PI, PI]
```

**Key Changes**:
- Replace `numpy.ndarray` with `Vector3`
- Replace `np.linalg.norm` with `.normalized()`
- Replace `np.arccos` with `acos`
- Add `simple_evolve()` for basic gameplay (skip full rotation if not needed)

---

### 2. Energy Flow & Diffusion

#### Python (QAGIS Kernel)
```python
class QuantumState16:
    def apply_energy_diffusion(self, dt: float = 0.1, coupling: float = 0.1):
        """Energy diffusion through entanglement network"""
        energies = np.array([mode.energy for mode in self.modes])

        # Build Laplacian matrix from entanglement graph
        n = len(self.modes)
        L = np.zeros((n, n))
        for i, j in self.entanglement_graph.edges():
            L[i, j] = -1
            L[j, i] = -1
            L[i, i] += 1
            L[j, j] += 1

        # Diffusion: dE/dt = -L @ E
        energy_flow = -coupling * (L @ energies)
        energies += energy_flow * dt

        # Update modes
        for i, mode in enumerate(self.modes):
            mode.energy = energies[i]
```

#### GDScript (Simplified)
```gdscript
class_name TomatoConspiracyNetwork
extends Node

var nodes: Dictionary = {}  # node_id -> QuantumNode
var connections: Array[Dictionary] = []  # [{from, to, strength}, ...]

func process_energy_diffusion(dt: float):
    # Simple pairwise diffusion (no matrix math)
    for conn in connections:
        var node_a = nodes[conn["from"]]
        var node_b = nodes[conn["to"]]
        var strength = conn["strength"]

        # Energy flows from high to low
        var delta = (node_b.energy - node_a.energy) * strength * dt * 0.1
        node_a.energy += delta
        node_b.energy -= delta
```

**Key Changes**:
- Replace Laplacian matrix with simple pairwise loops
- No numpy array operations
- Direct node-to-node energy transfer
- Connection strength built into each edge

---

### 3. Gaussian State Evolution

#### Python (QAGIS Kernel)
```python
def evolve(self, dt: float = 0.1, omega: float = 1.0):
    """Time evolution with full dynamics"""
    if self.active:
        # Gaussian evolution (quantum harmonic oscillator)
        rotation = np.array([[np.cos(omega * dt), np.sin(omega * dt)],
                            [-np.sin(omega * dt), np.cos(omega * dt)]])
        qp = np.array([self.q, self.p])
        qp_new = rotation @ qp
        self.q, self.p = qp_new * 0.995  # Small damping
```

#### GDScript (Simplified)
```gdscript
func evolve_gaussian(dt: float, omega: float = 1.0):
    # Rotation in phase space
    var cos_w = cos(omega * dt)
    var sin_w = sin(omega * dt)

    var q_new = q * cos_w + p * sin_w
    var p_new = -q * sin_w + p * cos_w

    q = q_new * 0.995  # Damping
    p = p_new * 0.995

    update_energy()

func update_energy():
    # Gaussian energy: harmonic oscillator
    var gaussian_energy = (q * q + p * p) / 2.0

    # Bloch energy: potential on sphere
    var bloch_energy = radius * (1.0 - cos(theta))

    energy = gaussian_energy + bloch_energy
```

**Key Changes**:
- Replace matrix multiplication with direct rotation
- Use scalar math instead of array operations
- Keep damping for stability

---

### 4. Data Structures

#### Python (QAGIS Kernel)
```python
from dataclasses import dataclass
import networkx as nx

@dataclass
class GaussianBlochMode:
    mode_id: int
    q: float
    p: float
    theta: float
    phi: float
    radius: float
    emoji_north: str
    emoji_south: str
    active: bool
    energy: float

class QuantumState16:
    n: int = 16
    modes: List[GaussianBlochMode]
    entanglement_graph: nx.Graph
```

#### GDScript (Resource-based)
```gdscript
class_name QuantumNode
extends Resource

@export var node_id: String = ""
@export var emoji_north: String = ""
@export var emoji_south: String = ""
@export var q: float = 0.0
@export var p: float = 0.0
@export var theta: float = 0.0
@export var phi: float = 0.0
@export var radius: float = 1.0
@export var energy: float = 0.0
@export var active: bool = false

# No networkx - simple data structures
class_name QuantumNetwork
extends Node

var nodes: Dictionary = {}  # String -> QuantumNode
var edges: Array[Dictionary] = []  # [{from: String, to: String, strength: float}]

func add_edge(from_id: String, to_id: String, strength: float):
    edges.append({
        "from": from_id,
        "to": to_id,
        "strength": strength
    })
```

**Key Changes**:
- Replace dataclass with GDScript class
- Replace NetworkX graph with Dictionary + Array
- Use @export for editor visibility
- Extend Resource for serialization

---

### 5. Conspiracy Activation Logic

#### Python (quantum_tomato_meta_graph.py)
```python
def check_conspiracy_activation(self, node_id: str) -> List[str]:
    """Check if any conspiracies activate for this node"""
    node = self.meta_nodes[node_id]
    activated = []

    for conspiracy in node["conspiracies"]:
        threshold = self.conspiracy_thresholds.get(conspiracy, 1.0)
        if node["energy"] > threshold:
            if conspiracy not in self.active_conspiracies:
                activated.append(conspiracy)
                self.active_conspiracies.add(conspiracy)

    return activated
```

#### GDScript (ConspiracyManager)
```gdscript
class_name ConspiracyManager
extends Node

signal conspiracy_activated(conspiracy_name: String)
signal conspiracy_deactivated(conspiracy_name: String)

const CONSPIRACY_THRESHOLDS = {
    "growth_acceleration": 0.8,
    "quantum_germination": 1.0,
    "observer_effect": 0.5,
    "data_harvesting": 1.5,
    "mycelial_internet": 0.6,
    "tomato_hive_mind": 1.2,
    # ... all 24 conspiracies
}

var active_conspiracies: Dictionary = {}  # conspiracy_name -> bool

func check_node_conspiracies(node: QuantumNode):
    for conspiracy in node.conspiracies:
        var threshold = CONSPIRACY_THRESHOLDS.get(conspiracy, 1.0)
        var is_active = node.energy > threshold

        # State change detection
        if is_active and not active_conspiracies.get(conspiracy, false):
            activate_conspiracy(conspiracy)
        elif not is_active and active_conspiracies.get(conspiracy, false):
            deactivate_conspiracy(conspiracy)

func activate_conspiracy(name: String):
    active_conspiracies[name] = true
    conspiracy_activated.emit(name)
    apply_conspiracy_effect(name)

func apply_conspiracy_effect(name: String):
    match name:
        "growth_acceleration":
            apply_growth_boost()
        "observer_effect":
            enable_global_observation()
        "tomato_hive_mind":
            synchronize_tomatoes()
        # ... handle all conspiracies
```

**Key Changes**:
- Replace set with Dictionary (for GDScript)
- Use signals for event propagation
- Match statement for effect dispatch
- Separate activation logic from effects

---

### 6. Loading Data from JSON

#### Python (JSON loading)
```python
import json

with open("quantum_tomato_meta_state.json", "r") as f:
    data = json.load(f)

for node_id, node_data in data["nodes"].items():
    node = QuantumNode()
    node.emoji = node_data["emoji_transformation"]
    node.theta = node_data["bloch_state"]["θ"]
    node.phi = node_data["bloch_state"]["φ"]
    # ...
```

#### GDScript (JSON loading)
```gdscript
func load_tomato_state_from_json(filepath: String):
    var file = FileAccess.open(filepath, FileAccess.READ)
    if not file:
        push_error("Cannot load: " + filepath)
        return

    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var parse_result = json.parse(json_string)
    if parse_result != OK:
        push_error("JSON parse error: " + filepath)
        return

    var data = json.data

    # Load nodes
    for node_id in data["nodes"].keys():
        var node_data = data["nodes"][node_id]
        var node = QuantumNode.new()
        node.node_id = node_id
        node.emoji_transform = node_data["emoji_transformation"]
        node.theta = node_data["bloch_state"]["θ"]
        node.phi = node_data["bloch_state"]["φ"]
        node.q = node_data["gaussian_state"]["q"]
        node.p = node_data["gaussian_state"]["p"]
        node.energy = node_data["energy"]
        node.conspiracies = node_data["active_conspiracies"]
        nodes[node_id] = node

    # Load entanglement network
    for conn_data in data["entanglement_network"]:
        var conn_str = conn_data["connection"]  # "seed ↔ solar"
        var parts = conn_str.split(" ↔ ")
        add_edge(parts[0], parts[1], conn_data["strength"])
```

**Key Changes**:
- Use `FileAccess` instead of Python `open()`
- Use `JSON.parse()` instead of `json.load()`
- Manually parse structure (no automatic dataclass mapping)

---

## Complete GDScript Example: Tomato Node

### Full Implementation
```gdscript
class_name TomatoNode
extends Resource

# Identification
@export var node_id: String = ""
@export var emoji_transform: String = ""
@export var meaning: String = ""
@export var conspiracies: Array[String] = []

# Quantum state
@export var theta: float = 0.0  # Bloch polar [0, PI]
@export var phi: float = 0.0    # Bloch azimuthal [-PI, PI]
@export var q: float = 0.0      # Gaussian position
@export var p: float = 0.0      # Gaussian momentum
@export var radius: float = 1.0 # Amplitude
@export var energy: float = 0.0

# Runtime
var active: bool = false
var connections: Dictionary = {}  # node_id -> strength

func _init():
    update_energy()

# Bloch sphere operations
func get_bloch_vector() -> Vector3:
    return Vector3(
        sin(theta) * cos(phi),
        sin(theta) * sin(phi),
        cos(theta)
    )

func set_bloch_vector(v: Vector3):
    v = v.normalized()
    theta = acos(clamp(v.z, -1.0, 1.0))
    if abs(sin(theta)) > 0.001:
        phi = atan2(v.y, v.x)
    update_energy()

# Energy calculation
func update_energy():
    var gaussian_energy = (q * q + p * p) / 2.0
    var bloch_energy = radius * (1.0 - cos(theta))
    energy = gaussian_energy + bloch_energy
    active = energy > 0.1

# Time evolution
func evolve(dt: float, omega: float = 1.0):
    if not active:
        return

    # Bloch sphere evolution (simple precession)
    theta += energy * dt * 0.05
    theta = clamp(theta, 0.0, PI)

    phi += dt * energy * 0.1
    phi = fmod(phi + PI, TAU) - PI

    # Gaussian evolution (harmonic oscillator)
    var cos_w = cos(omega * dt)
    var sin_w = sin(omega * dt)

    var q_new = q * cos_w + p * sin_w
    var p_new = -q * sin_w + p * cos_w

    q = q_new * 0.995  # Damping
    p = p_new * 0.995

    update_energy()

# Semantic blend (for visualization)
func get_semantic_blend() -> float:
    # Returns value [0, 1]: 0 = full north emoji, 1 = full south emoji
    return (theta / PI)

# State serialization
func to_dict() -> Dictionary:
    return {
        "node_id": node_id,
        "emoji_transform": emoji_transform,
        "meaning": meaning,
        "conspiracies": conspiracies,
        "theta": theta,
        "phi": phi,
        "q": q,
        "p": p,
        "radius": radius,
        "energy": energy
    }

func from_dict(data: Dictionary):
    node_id = data.get("node_id", "")
    emoji_transform = data.get("emoji_transform", "")
    meaning = data.get("meaning", "")
    conspiracies = data.get("conspiracies", [])
    theta = data.get("theta", 0.0)
    phi = data.get("phi", 0.0)
    q = data.get("q", 0.0)
    p = data.get("p", 0.0)
    radius = data.get("radius", 1.0)
    energy = data.get("energy", 0.0)
    update_energy()
```

---

## Performance Considerations

### Python Performance Patterns
```python
# Python: Fast with numpy vectorization
energies = np.array([mode.energy for mode in self.modes])
L = build_laplacian_matrix(self.entanglement_graph)
energy_flow = -coupling * (L @ energies)  # Single matrix operation
```

### GDScript Performance Patterns
```gdscript
# GDScript: Fast with direct iteration (no matrix overhead)
func process_energy_diffusion_optimized(dt: float):
    # Cache frequently accessed values
    var coupling = dt * 0.1

    # Pre-calculate deltas
    var deltas = {}
    for conn in connections:
        var from_id = conn["from"]
        var to_id = conn["to"]
        var node_a = nodes[from_id]
        var node_b = nodes[to_id]

        var delta = (node_b.energy - node_a.energy) * conn["strength"] * coupling

        if not deltas.has(from_id):
            deltas[from_id] = 0.0
        if not deltas.has(to_id):
            deltas[to_id] = 0.0

        deltas[from_id] += delta
        deltas[to_id] -= delta

    # Apply all deltas at once (prevents order dependency)
    for node_id in deltas:
        nodes[node_id].energy += deltas[node_id]
```

**Optimization Tips**:
- Pre-calculate and cache values
- Minimize dictionary lookups
- Use typed GDScript for speed
- Update in batches to prevent order dependencies

---

## Testing Equivalence

### Validation Test
```gdscript
# Test that GDScript produces similar results to Python

func test_energy_conservation():
    # Create simple 2-node system
    var node_a = TomatoNode.new()
    node_a.energy = 2.0

    var node_b = TomatoNode.new()
    node_b.energy = 0.5

    var initial_total = node_a.energy + node_b.energy

    # Simulate energy diffusion
    for i in range(100):
        var delta = (node_b.energy - node_a.energy) * 0.5 * 0.1
        node_a.energy += delta
        node_b.energy -= delta

    var final_total = node_a.energy + node_b.energy

    assert(abs(initial_total - final_total) < 0.001, "Energy should be conserved")
    assert(abs(node_a.energy - node_b.energy) < 0.1, "Should equilibrate")

func test_bloch_sphere_rotation():
    var node = TomatoNode.new()
    node.theta = 0.0
    node.phi = 0.0

    var initial = node.get_bloch_vector()
    assert(initial.is_equal_approx(Vector3(0, 0, 1)), "Should start at north pole")

    node.theta = PI
    var final = node.get_bloch_vector()
    assert(final.is_equal_approx(Vector3(0, 0, -1)), "Should move to south pole")
```

---

## Summary: Python vs GDScript

| Feature | Python (QAGIS) | GDScript (Game) |
|---------|----------------|-----------------|
| **Matrix ops** | NumPy arrays | Direct loops |
| **Graphs** | NetworkX | Dict + Array |
| **Data** | Dataclass | Resource class |
| **Typing** | Type hints | @export + typed vars |
| **Performance** | Vectorization | Cache + batch updates |
| **Complexity** | Full quantum formalism | Minimal viable quantum |

## Next Steps

See `TASK_LIST.md` for implementation priorities.
