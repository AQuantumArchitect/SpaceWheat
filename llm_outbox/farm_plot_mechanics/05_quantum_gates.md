# Quantum Gates & Entanglement

## Overview

SpaceWheat implements quantum gates through two systems:
1. **Persistent Gate Infrastructure** - Survives harvest/replant
2. **Direct Gate Application** - One-time transformations

---

## Persistent Gates System

### Concept

**Problem:** Quantum states are destroyed on harvest. How to build permanent circuits?

**Solution:** Store gate configuration separately from quantum state. When plot is replanted, automatically re-apply gates.

### Data Structure

```gdtxt
# In BasePlot
var persistent_gates: Array[Dictionary] = []

# Each gate:
{
    "type": String,            # "bell_phi_plus", "cluster", etc.
    "active": bool,            # Is this gate currently active?
    "linked_plots": Array[Vector2i]  # Connected plot positions
}
```

### Example Flow

**Building a Bell Gate:**
```gdtxt
# 1. Player uses Quantum tool (2), presses Q, selects 2 plots
grid.create_entanglement(pos_a, pos_b, "phi_plus")

# 2. FarmGrid creates persistent gates
plot_a.add_persistent_gate("bell_phi_plus", [pos_b])
plot_b.add_persistent_gate("bell_phi_plus", [pos_a])

# 3. FarmGrid creates EntangledPair
var pair = EntangledPair.new(plot_a.quantum_state, plot_b.quantum_state, "phi_plus")
entangled_pairs.append(pair)
```

**Harvesting:**
```gdtxt
# 4. Harvest both plots
grid.harvest(pos_a)  # quantum_state = null, persistent_gates REMAIN
grid.harvest(pos_b)  # quantum_state = null, persistent_gates REMAIN
```

**Replanting:**
```gdtxt
# 5. Replant first plot
grid.plant(pos_a, "wheat")
# → Creates new quantum_state
# → _auto_apply_persistent_gates(pos_a) called
# → Checks plot_b: not planted yet, skip entanglement

# 6. Replant second plot
grid.plant(pos_b, "wheat")
# → Creates new quantum_state
# → _auto_apply_persistent_gates(pos_b) called
# → Checks plot_a: IS planted!
# → Creates new EntangledPair between pos_a and pos_b
```

**Result:** The gate infrastructure persisted, qubits re-entangled automatically.

---

## Auto-Entangle from Infrastructure

```gdtxt
func _auto_apply_persistent_gates(position: Vector2i):
    var plot = get_plot(position)
    if not plot.quantum_state:
        return  # No qubit to entangle

    # Check all persistent gates on this plot
    for gate_config in plot.get_active_gates():
        var gate_type = gate_config.get("type", "")
        var linked_plots = gate_config.get("linked_plots", [])

        match gate_type:
            "bell_phi_plus", "bell_phi_minus", "bell_psi_plus", "bell_psi_minus":
                # 2-qubit Bell gate
                for linked_pos in linked_plots:
                    var linked_plot = get_plot(linked_pos)
                    if linked_plot and linked_plot.is_planted and linked_plot.quantum_state:
                        # Both plots planted → create entanglement
                        _create_quantum_entanglement(position, linked_pos, gate_type)

            "cluster":
                # N-qubit cluster gate
                # Check if all linked plots are planted
                var all_planted = true
                for linked_pos in linked_plots:
                    var linked_plot = get_plot(linked_pos)
                    if not linked_plot or not linked_plot.is_planted:
                        all_planted = false
                        break

                if all_planted:
                    # All plots in cluster planted → create cluster
                    var positions = [position] + linked_plots
                    create_entangled_cluster(positions)
```

**Key Insight:** Infrastructure waits for all participants to be planted before creating entanglement.

---

## Bell States

### Four Bell States

```gdtxt
|Φ+⟩ = (|00⟩ + |11⟩) / √2    # phi_plus (most common)
|Φ−⟩ = (|00⟩ − |11⟩) / √2    # phi_minus
|Ψ+⟩ = (|01⟩ + |10⟩) / √2    # psi_plus
|Ψ−⟩ = (|01⟩ − |10⟩) / √2    # psi_minus
```

### Density Matrix Representation

```gdtxt
# In EntangledPair.gd
class_name EntangledPair

var qubit_a: DualEmojiQubit
var qubit_b: DualEmojiQubit
var density_matrix: Array  # 4x4 complex matrix
var bell_type: String
var coherence_time_T1: float = 100.0

func _init(qa, qb, bell_type_str):
    qubit_a = qa
    qubit_b = qb
    bell_type = bell_type_str

    # Initialize density matrix based on Bell state
    match bell_type:
        "phi_plus":
            # ρ = |Φ+⟩⟨Φ+| = [[1,0,0,1], [0,0,0,0], [0,0,0,0], [1,0,0,1]] / 2
            density_matrix = [
                [0.5, 0.0, 0.0, 0.5],
                [0.0, 0.0, 0.0, 0.0],
                [0.0, 0.0, 0.0, 0.0],
                [0.5, 0.0, 0.0, 0.5]
            ]
```

### Decoherence Application

```gdtxt
func _apply_entangled_pair_decoherence(delta: float):
    for pair in entangled_pairs:
        var temp = base_temperature

        # Apply decoherence via Lindblad equation
        pair.density_matrix = Lindblad.apply_two_qubit_decoherence_4x4(
            pair.density_matrix,
            delta,
            temp,
            pair.coherence_time_T1
        )
```

**Effect:** Density matrix slowly decays toward separable state.

---

## Entangled Clusters (N-Qubit)

### Cluster Structure

```gdtxt
class_name EntangledCluster

var qubit_ids: Array[String]
var qubits: Array[DualEmojiQubit]
var entanglement_strength: float = 0.8

func add_qubit(qubit: DualEmojiQubit, plot_id: String):
    qubits.append(qubit)
    qubit_ids.append(plot_id)

    # Link qubit to cluster
    qubit.entangled_cluster = self
    qubit.cluster_qubit_index = qubits.size() - 1

func get_qubit_count() -> int:
    return qubits.size()
```

### Creation

```gdtxt
func create_entangled_cluster(positions: Array[Vector2i]):
    var cluster = EntangledCluster.new()

    for pos in positions:
        var plot = get_plot(pos)
        if not plot or not plot.quantum_state:
            continue

        cluster.add_qubit(plot.quantum_state, plot.plot_id)

        # Add persistent gate infrastructure
        var other_positions = positions.filter(func(p): return p != pos)
        plot.add_persistent_gate("cluster", other_positions)

    entangled_clusters.append(cluster)
    print("🔗 Created cluster of %d qubits" % cluster.get_qubit_count())
```

**Key Feature:** All qubits in cluster linked bidirectionally.

---

## Single-Qubit Gates

### Pauli-X (Bit Flip)

**Effect:** Flips qubit from north to south or vice versa

```gdtxt
# In DualEmojiQubit
func apply_pauli_x():
    theta = PI - theta
```

**Bloch Sphere:** Rotation of π around X-axis

**Example:**
```gdtxt
Before: theta = 0 (pure |0⟩ = "🌾")
After:  theta = π (pure |1⟩ = "👥")
```

### Hadamard (Superposition Creator)

**Effect:** Creates equal superposition

```gdtxt
func apply_hadamard():
    var axis = Vector3(1, 0, 1).normalized()
    apply_rotation(axis, PI)
```

**Bloch Sphere:** Rotation of π around (1,0,1) axis

**Example:**
```gdtxt
Before: theta = 0 (pure |0⟩)
After:  theta = π/2 (superposition |0⟩ + |1⟩)
```

### Pauli-Z (Phase Flip)

**Effect:** Adds π phase

```gdtxt
func apply_pauli_z():
    apply_rotation(Vector3(0, 0, 1), PI)
```

**Bloch Sphere:** Rotation of π around Z-axis

**Example:**
```gdtxt
Before: phi = 0
After:  phi = π
```

---

## Two-Qubit Gates

### CNOT (Controlled-NOT)

**Effect:** If control qubit is |1⟩, flip target qubit

```gdtxt
func apply_cnot(control_pos: Vector2i, target_pos: Vector2i):
    var control_plot = get_plot(control_pos)
    var target_plot = get_plot(target_pos)

    var control_state = control_plot.quantum_state
    var target_state = target_plot.quantum_state

    # Check control qubit (theta > π/2 means |1⟩ more likely)
    if control_state.theta > PI / 2.0:
        target_state.apply_pauli_x()
```

**Truth Table:**
```
Control | Target Before | Target After
   |0⟩  |      |0⟩     |     |0⟩
   |0⟩  |      |1⟩     |     |1⟩
   |1⟩  |      |0⟩     |     |1⟩       (FLIP)
   |1⟩  |      |1⟩     |     |0⟩       (FLIP)
```

### CZ (Controlled-Z)

**Effect:** If control qubit is |1⟩, apply Z gate to target

```gdtxt
func apply_cz(control_pos: Vector2i, target_pos: Vector2i):
    var control_state = get_plot(control_pos).quantum_state
    var target_state = get_plot(target_pos).quantum_state

    if control_state.theta > PI / 2.0:
        target_state.apply_pauli_z()
```

### SWAP

**Effect:** Exchange quantum states of two qubits

```gdtxt
func apply_swap(pos_a: Vector2i, pos_b: Vector2i):
    var plot_a = get_plot(pos_a)
    var plot_b = get_plot(pos_b)

    var temp_state = plot_a.quantum_state
    plot_a.quantum_state = plot_b.quantum_state
    plot_b.quantum_state = temp_state
```

---

## Gate Visualization

### Entanglement Lines

```gdtxt
# In QuantumForceGraph
func _draw_entanglement_lines():
    for pair in grid.entangled_pairs:
        var node_a = _find_node_by_qubit(pair.qubit_a)
        var node_b = _find_node_by_qubit(pair.qubit_b)

        if node_a and node_b:
            var color = Color(0.5, 1.0, 0.8, 0.6)  # Cyan
            draw_line(node_a.position, node_b.position, color, 2.0)
```

### Gate Markers

```gdtxt
# In QuantumNode
func _draw_gate_markers(plot):
    if not plot:
        return

    var gates = plot.get_active_gates()
    for i in range(gates.size()):
        var gate = gates[i]
        var gate_type = gate.get("type", "")

        # Draw gate icon next to bubble
        var offset = Vector2(20, -10 - i * 15)
        var icon = _get_gate_icon(gate_type)
        draw_string(font, position + offset, icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)

func _get_gate_icon(gate_type: String) -> String:
    match gate_type:
        "bell_phi_plus": return "🔗Φ+"
        "bell_phi_minus": return "🔗Φ−"
        "cluster": return "⚛️"
        _: return "🔧"
```

---

## Gate Removal

### Remove All Gates

```gdtxt
func remove_gates(position: Vector2i):
    var plot = get_plot(position)
    plot.clear_persistent_gates()

    # Break entanglements
    for pair in entangled_pairs:
        if pair.qubit_a == plot.quantum_state or pair.qubit_b == plot.quantum_state:
            entangled_pairs.erase(pair)

    for cluster in entangled_clusters:
        if plot.plot_id in cluster.qubit_ids:
            entangled_clusters.erase(cluster)

    visualization_changed.emit()
```

### Automatic Cleanup on Harvest

```gdtxt
# Gates persist, but entanglement objects are removed
func harvest(position: Vector2i):
    var plot = get_plot(position)
    var result = plot.harvest()

    # Remove from entangled pairs
    for pair in entangled_pairs:
        if pair.qubit_a == plot.quantum_state or pair.qubit_b == plot.quantum_state:
            entangled_pairs.erase(pair)

    # persistent_gates NOT removed - infrastructure survives!
```

---

## Advanced: Measurement-Based Gates

### Concept

Use measurement outcomes to apply conditional gates

**Example:** Bell State Measurement
```gdtxt
func measure_bell_pair(pos_a: Vector2i, pos_b: Vector2i):
    var outcome_a = get_plot(pos_a).measure()
    var outcome_b = get_plot(pos_b).measure()

    # Determine Bell state from outcomes
    if outcome_a == "🌾" and outcome_b == "🌾":
        return "phi_plus"   # |Φ+⟩
    elif outcome_a == "🌾" and outcome_b == "👥":
        return "psi_plus"   # |Ψ+⟩
    elif outcome_a == "👥" and outcome_b == "🌾":
        return "psi_minus"  # |Ψ−⟩
    else:
        return "phi_minus"  # |Φ−⟩
```

---

## Key Takeaways

1. **Persistent vs Temporary**
   - Persistent gates: Infrastructure that survives harvest
   - Temporary entanglement: Actual quantum correlations

2. **Auto-Entangle**
   - When plot with gate is replanted, gate auto-applies
   - Waits for all participants to be planted

3. **Bell Pairs**
   - Proper density matrix representation
   - Decoherence applied via Lindblad
   - Four Bell states supported

4. **Clusters**
   - N-qubit entanglement
   - Simplified evolution (per-qubit decoherence)

5. **Gate Visualization**
   - Entanglement lines
   - Gate markers on bubbles
   - Visual feedback for infrastructure

6. **Lifecycle**
   - Build gate → Harvest → Replant → Auto-entangle
   - Infrastructure is permanent, qubits are temporary
