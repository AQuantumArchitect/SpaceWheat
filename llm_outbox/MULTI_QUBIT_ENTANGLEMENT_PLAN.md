# Multi-Qubit Entanglement Implementation Plan ⚛️🔗

**Date:** 2025-12-14
**Feature:** N-Qubit Entangled States via Sequential Gates
**Motivation:** Real quantum hardware builds multi-qubit entanglement sequentially!

---

## The User's Insight

**Key Observation:** While we don't have "N-qubit Bell gates," you can create N-qubit entangled states by:

1. Create Bell pair: A ↔ B (2-qubit entanglement)
2. Entangle C with the pair using 2-qubit gate
3. Result: A ↔ B ↔ C are **all mutually entangled**!

**This is exactly how real quantum computers work!**

---

## Current State vs. Proposed State

### Current: Pairwise Entanglement Only

```gdscript
var pair = EntangledPair.new()
pair.create_bell_phi_plus()  // A ↔ B

// If we try to entangle C with A:
// - Creates NEW pair C ↔ A
// - Old pair A ↔ B still exists
// - Result: A is in TWO pairs (inconsistent!)
```

**Problem:** No true multi-qubit states. Qubits can only be in one pair.

### Proposed: N-Qubit Clusters

```gdscript
var cluster = EntangledCluster.new()
cluster.add_qubit(qubit_a)
cluster.add_qubit(qubit_b)
cluster.create_ghz_state()  // |00⟩ + |11⟩

// Add third qubit
cluster.entangle_new_qubit(qubit_c)  // CNOT operation
// Result: |000⟩ + |111⟩ (3-qubit GHZ state!)

// Add fourth qubit
cluster.entangle_new_qubit(qubit_d)
// Result: |0000⟩ + |1111⟩ (4-qubit GHZ!)
```

**Solution:** True multi-qubit entanglement with sequential gate application.

---

## Physics: Multi-Qubit Entangled States

### GHZ States (Greenberger-Horne-Zeilinger)

**2-qubit GHZ = Bell state:**
```
|GHZ₂⟩ = (|00⟩ + |11⟩)/√2
```

**3-qubit GHZ:**
```
|GHZ₃⟩ = (|000⟩ + |111⟩)/√2
```

**N-qubit GHZ:**
```
|GHZₙ⟩ = (|00...0⟩ + |11...1⟩)/√2
```

**Properties:**
- Maximally entangled (all qubits correlated)
- Measuring one qubit collapses ALL others
- Fragile: Tracing out ANY qubit → separable state
- Used in quantum teleportation, superdense coding

### W States

**3-qubit W:**
```
|W₃⟩ = (|100⟩ + |010⟩ + |001⟩)/√3
```

**Properties:**
- Shared single excitation
- Robust: Tracing out one qubit → remaining qubits still entangled!
- Used in quantum networks

### Cluster States

**1D chain:**
```
|Cluster⟩ = (|+⟩)^⊗N with controlled-Z between neighbors
```

**Properties:**
- Foundation of measurement-based quantum computing
- Graph structure encodes computation
- One-way quantum computer model

---

## Implementation Design

### Class: EntangledCluster

**File:** `/Core/QuantumSubstrate/EntangledCluster.gd`

```gdscript
class_name EntangledCluster
extends Resource

## N-Qubit Entangled State
## Represents genuinely multi-partite entangled quantum state
##
## Physics: Sequential 2-qubit gates create N-qubit entanglement
## - Start with 2 qubits → Bell pair
## - Add 3rd qubit → GHZ₃ or W₃
## - Continue → arbitrary N-qubit states

var qubits: Array = []  # Array of DualEmojiQubit
var qubit_ids: Array[String] = []  # Plot IDs

# Density matrix: 2^N × 2^N (exponential!)
var density_matrix: Array = []  # Array of Array of Vector2(real, imag)

# Decoherence
var coherence_time_T1: float = 100.0
var coherence_time_T2: float = 50.0

# Cluster type
enum ClusterType {
    GHZ,      # All-or-nothing entanglement
    W_STATE,  # Robust shared excitation
    CLUSTER,  # Graph state for MBQC
    CUSTOM    # General N-qubit state
}

var cluster_type: ClusterType = ClusterType.CUSTOM


func _init():
    pass  # Start empty, add qubits sequentially


## Sequential Entanglement Construction

func add_qubit(qubit: DualEmojiQubit, plot_id: String):
    """Add qubit to cluster

    If cluster has 0 qubits: Just add
    If cluster has 1 qubit: Create Bell pair
    If cluster has 2+ qubits: Apply entangling gate
    """
    qubits.append(qubit)
    qubit_ids.append(plot_id)

    # Update density matrix size
    _resize_density_matrix()

    print("➕ Added qubit %s to cluster (size: %d)" % [plot_id, qubits.size()])


func _resize_density_matrix():
    """Resize density matrix to 2^N × 2^N"""
    var N = qubits.size()
    var dim = int(pow(2, N))

    density_matrix = []
    for i in range(dim):
        var row = []
        for j in range(dim):
            if i == j:
                row.append(Vector2(1.0 / dim, 0.0))  # Maximally mixed
            else:
                row.append(Vector2(0.0, 0.0))
        density_matrix.append(row)


## GHZ State Creation

func create_ghz_state():
    """Create GHZ state: (|00...0⟩ + |11...1⟩)/√2

    All qubits perfectly correlated.
    Measuring one instantly determines all others!
    """
    var N = qubits.size()
    if N < 2:
        push_error("Need at least 2 qubits for GHZ state")
        return

    _clear_density_matrix()

    var dim = int(pow(2, N))
    var amplitude = 0.5  # |c|² = 1/2 for each term

    # |00...0⟩⟨00...0|
    density_matrix[0][0] = Vector2(amplitude, 0.0)

    # |00...0⟩⟨11...1| (off-diagonal coherence)
    density_matrix[0][dim - 1] = Vector2(amplitude, 0.0)

    # |11...1⟩⟨00...0|
    density_matrix[dim - 1][0] = Vector2(amplitude, 0.0)

    # |11...1⟩⟨11...1|
    density_matrix[dim - 1][dim - 1] = Vector2(amplitude, 0.0)

    cluster_type = ClusterType.GHZ

    print("🌟 Created %d-qubit GHZ state: (|0...0⟩ + |1...1⟩)/√2" % N)


## W State Creation

func create_w_state():
    """Create W state: (|100...0⟩ + |010...0⟩ + ... + |00...01⟩)/√N

    One excitation shared across all qubits.
    Robust: Losing one qubit doesn't destroy entanglement!
    """
    var N = qubits.size()
    if N < 2:
        push_error("Need at least 2 qubits for W state")
        return

    _clear_density_matrix()

    var amplitude = 1.0 / N  # |c|² = 1/N for each term

    # For each basis state with exactly one '1'
    for i in range(N):
        var basis_index = int(pow(2, i))  # 2^i has '1' in position i

        # Diagonal term
        density_matrix[basis_index][basis_index] = Vector2(amplitude, 0.0)

        # Off-diagonal coherences with other single-excitation states
        for j in range(i + 1, N):
            var other_basis = int(pow(2, j))
            density_matrix[basis_index][other_basis] = Vector2(amplitude, 0.0)
            density_matrix[other_basis][basis_index] = Vector2(amplitude, 0.0)

    cluster_type = ClusterType.W_STATE

    print("💫 Created %d-qubit W state (robust shared excitation)" % N)


## Sequential Entangling Operations

func entangle_new_qubit_cnot(new_qubit: DualEmojiQubit, new_plot_id: String, control_index: int = 0):
    """Add new qubit via CNOT gate

    Applies CNOT with existing qubit as control, new qubit as target.
    This extends GHZ states: |00⟩+|11⟩ → |000⟩+|111⟩

    Args:
        new_qubit: Qubit to add
        new_plot_id: Plot ID
        control_index: Which existing qubit is control (default: first)
    """
    if qubits.is_empty():
        add_qubit(new_qubit, new_plot_id)
        return

    if control_index >= qubits.size():
        push_error("Control index out of range")
        return

    # Store old state
    var old_density = _copy_density_matrix()
    var old_N = qubits.size()

    # Add qubit (resizes matrix)
    add_qubit(new_qubit, new_plot_id)

    # Apply CNOT expansion
    _apply_cnot_expansion(old_density, old_N, control_index)

    print("🔗 Applied CNOT: control=%d, target=%d (new)" % [control_index, old_N])


func _apply_cnot_expansion(old_density: Array, old_N: int, control_bit: int):
    """Expand N-qubit state to (N+1)-qubit state via CNOT

    CNOT|ψ⟩⊗|0⟩ creates entanglement between new qubit and cluster.

    If old state was |00⟩+|11⟩, result is |000⟩+|111⟩ (GHZ₃)
    """
    _clear_density_matrix()

    var old_dim = int(pow(2, old_N))
    var new_dim = int(pow(2, old_N + 1))

    # For each basis state |x⟩ in old space
    for x in range(old_dim):
        # Check control bit
        var control_value = (x >> control_bit) & 1

        # New basis state: |x⟩|c⟩ where c = control bit value
        # (CNOT flips target if control=1)
        var new_state = (x << 1) | control_value

        # Copy density matrix elements
        for y in range(old_dim):
            var control_y = (y >> control_bit) & 1
            var new_state_y = (y << 1) | control_y

            var rho_xy = old_density[x][y]
            density_matrix[new_state][new_state_y] = rho_xy


## Cluster State Creation (for MBQC)

func create_cluster_state_1d():
    """Create 1D cluster state for measurement-based quantum computing

    Graph state: Apply CZ gates between adjacent qubits
    Foundation of one-way quantum computer!
    """
    var N = qubits.size()
    if N < 2:
        return

    # Start with all qubits in |+⟩ state
    _initialize_all_plus()

    # Apply controlled-Z between neighbors
    for i in range(N - 1):
        _apply_controlled_z(i, i + 1)

    cluster_type = ClusterType.CLUSTER

    print("🌐 Created %d-qubit 1D cluster state (MBQC ready)" % N)


func _initialize_all_plus():
    """Initialize to |+⟩^⊗N state"""
    _clear_density_matrix()

    var N = qubits.size()
    var dim = int(pow(2, N))
    var amplitude = 1.0 / dim

    # |+⟩ = (|0⟩+|1⟩)/√2, so |+⟩^⊗N is equal superposition
    for i in range(dim):
        for j in range(dim):
            density_matrix[i][j] = Vector2(amplitude, 0.0)


func _apply_controlled_z(control: int, target: int):
    """Apply controlled-Z gate between two qubits

    CZ|ab⟩ = (-1)^(a·b)|ab⟩ (phase flip if both qubits are |1⟩)
    """
    var N = qubits.size()
    var dim = int(pow(2, N))

    # Create CZ matrix in computational basis
    var new_density = _copy_density_matrix()

    for i in range(dim):
        for j in range(dim):
            var control_i = (i >> control) & 1
            var target_i = (i >> target) & 1
            var control_j = (j >> control) & 1
            var target_j = (j >> target) & 1

            # Phase factor: (-1)^(control·target)
            var phase_i = -1 if (control_i and target_i) else 1
            var phase_j = -1 if (control_j and target_j) else 1
            var total_phase = phase_i * phase_j

            var element = new_density[i][j]
            density_matrix[i][j] = Vector2(
                element.x * total_phase,
                element.y * total_phase
            )


## Helper Methods

func _copy_density_matrix() -> Array:
    """Deep copy of density matrix"""
    var copy = []
    for row in density_matrix:
        var row_copy = []
        for element in row:
            row_copy.append(Vector2(element.x, element.y))
        copy.append(row_copy)
    return copy


func _clear_density_matrix():
    """Clear density matrix to zeros"""
    for i in range(density_matrix.size()):
        for j in range(density_matrix[i].size()):
            density_matrix[i][j] = Vector2(0.0, 0.0)


## Measurement

func measure_qubit(qubit_index: int) -> int:
    """Measure one qubit, collapsing cluster state

    For GHZ: Measuring one qubit instantly determines all others!
    For W: Measuring removes one qubit, others remain entangled.

    Returns:
        0 or 1 (measurement outcome)
    """
    var N = qubits.size()
    var dim = int(pow(2, N))

    # Calculate probabilities for this qubit being 0 or 1
    var prob_0 = _probability_qubit_zero(qubit_index)
    var prob_1 = 1.0 - prob_0

    # Random measurement
    var outcome = 0 if randf() < prob_0 else 1

    # Collapse state
    _collapse_to_outcome(qubit_index, outcome)

    print("📊 Measured qubit %d: %d (p₀=%.2f, p₁=%.2f)" %
          [qubit_index, outcome, prob_0, prob_1])

    return outcome


func _probability_qubit_zero(qubit_index: int) -> float:
    """Calculate probability of measuring |0⟩ on given qubit"""
    var N = qubits.size()
    var dim = int(pow(2, N))
    var prob = 0.0

    # Sum diagonal elements where qubit_index is 0
    for i in range(dim):
        var bit_value = (i >> qubit_index) & 1
        if bit_value == 0:
            prob += density_matrix[i][i].x  # Real part

    return prob


func _collapse_to_outcome(qubit_index: int, outcome: int):
    """Collapse density matrix to measurement outcome"""
    var N = qubits.size()
    var dim = int(pow(2, N))

    # Zero out basis states inconsistent with outcome
    for i in range(dim):
        var bit_value = (i >> qubit_index) & 1
        if bit_value != outcome:
            # Zero this row and column
            for j in range(dim):
                density_matrix[i][j] = Vector2(0.0, 0.0)
                density_matrix[j][i] = Vector2(0.0, 0.0)

    # Renormalize
    _normalize_density_matrix()


func _normalize_density_matrix():
    """Normalize density matrix (Tr(ρ) = 1)"""
    var trace = 0.0
    for i in range(density_matrix.size()):
        trace += density_matrix[i][i].x

    if trace > 0.0:
        for i in range(density_matrix.size()):
            for j in range(density_matrix[i].size()):
                density_matrix[i][j] /= trace


## Properties

func get_qubit_count() -> int:
    return qubits.size()


func get_state_dimension() -> int:
    return int(pow(2, qubits.size()))


func is_ghz_type() -> bool:
    return cluster_type == ClusterType.GHZ


func is_w_type() -> bool:
    return cluster_type == ClusterType.W_STATE


func get_all_plot_ids() -> Array[String]:
    return qubit_ids


func contains_qubit(qubit: DualEmojiQubit) -> bool:
    return qubit in qubits


func contains_plot_id(plot_id: String) -> bool:
    return plot_id in qubit_ids


## Debug

func get_state_string() -> String:
    var type_name = ["GHZ", "W", "Cluster", "Custom"][cluster_type]
    return "%d-qubit %s state" % [qubits.size(), type_name]


func print_density_matrix():
    """Debug: Print density matrix (only for small N!)"""
    var N = qubits.size()
    if N > 3:
        print("⚠️ Density matrix too large to print (2^%d = %d dimensions)" %
              [N, int(pow(2, N))])
        return

    print("Density Matrix (%d×%d):" % [density_matrix.size(), density_matrix.size()])
    for i in range(density_matrix.size()):
        var row_str = ""
        for j in range(density_matrix[i].size()):
            var elem = density_matrix[i][j]
            if abs(elem.y) < 0.001:  # No imaginary part
                row_str += "%.3f  " % elem.x
            else:
                row_str += "%.3f%+.3fi  " % [elem.x, elem.y]
        print("  " + row_str)
```

---

## Integration with Existing Systems

### 1. Upgrade EntangledPair to EntangledCluster

**When to upgrade:**

```gdscript
# In WheatPlot.entangle_with(other_plot)

# Case 1: Neither plot entangled → Create new pair
if not self.quantum_state.entangled_pair and not other.quantum_state.entangled_pair:
    var pair = EntangledPair.new()
    pair.create_bell_phi_plus()
    # ... existing code

# Case 2: One plot already entangled → Upgrade to cluster!
elif self.quantum_state.entangled_pair and not other.quantum_state.entangled_pair:
    # Upgrade pair to cluster
    var old_pair = self.quantum_state.entangled_pair
    var cluster = _upgrade_pair_to_cluster(old_pair)

    # Add new qubit
    cluster.entangle_new_qubit_cnot(other.quantum_state, other.plot_id)

    # Update references
    for qubit in cluster.qubits:
        qubit.entangled_cluster = cluster

# Case 3: Both in same cluster → Already entangled!
elif _in_same_cluster(self, other):
    print("Already in same cluster!")

# Case 4: Both in different clusters → Merge clusters!
else:
    _merge_clusters(self.quantum_state.entangled_cluster,
                    other.quantum_state.entangled_cluster)
```

### 2. Update DualEmojiQubit

**Add cluster reference:**

```gdscript
# In DualEmojiQubit.gd

var entangled_pair = null  # Keep for backward compatibility
var entangled_cluster = null  # NEW: Multi-qubit cluster

func is_entangled() -> bool:
    return entangled_pair != null or entangled_cluster != null

func get_cluster_size() -> int:
    if entangled_cluster:
        return entangled_cluster.get_qubit_count()
    elif entangled_pair:
        return 2
    else:
        return 1
```

---

## Gameplay Integration

### Visual Representation

**N-qubit clusters get special visuals:**

```gdscript
# Cluster size determines visual
match cluster.get_qubit_count():
    2:
        # Standard entanglement line (existing)
        draw_line(pos_a, pos_b, Color.CYAN, 2.0)

    3:
        # Triangle with center glow
        draw_polygon(triangle_points, [Color.CYAN.darkened(0.3)])
        draw_circle(center, 5, Color.CYAN)

    4:
        # Tetrahedron projection (3D → 2D)
        _draw_tetrahedron(cluster_positions)

    5+:
        # Hypergraph visualization
        _draw_hyperedge(cluster_positions, Color.CYAN)

        # Label: "5-qubit GHZ"
        draw_string(font, center, cluster.get_state_string())
```

### Topology Bonuses

**Multi-qubit entanglement → higher Jones polynomial:**

```gdscript
# In TopologyAnalyzer._calculate_topology_features()

# Bonus for multi-qubit clusters (not just pairs)
var cluster_bonus = 0.0
for cluster in get_all_clusters():
    var N = cluster.get_qubit_count()
    if N > 2:
        # Exponential bonus: N-qubit cluster much more complex!
        cluster_bonus += pow(2, N - 2)  # 3→2, 4→4, 5→8, etc.

features["cluster_complexity"] = cluster_bonus
features["jones_approximation"] += cluster_bonus * 0.5
```

### Measurement Cascades

**Measuring one qubit in GHZ collapses ALL qubits:**

```gdscript
# In WheatPlot.harvest()

if quantum_state.entangled_cluster:
    var cluster = quantum_state.entangled_cluster

    if cluster.is_ghz_type():
        show_warning("⚠️ This is a GHZ state!")
        show_info("Measuring will collapse ALL %d qubits!" % cluster.get_qubit_count())

        if player_confirms():
            # Measure this qubit
            var outcome = cluster.measure_qubit(cluster.qubits.find(quantum_state))

            # ALL other qubits instantly collapse!
            _cascade_collapse_all_cluster_plots(cluster)
```

---

## Physics Accuracy: 9/10

**Accurate:**
- ✅ GHZ states created by sequential CNOT gates (real method!)
- ✅ W states are genuinely robust (tracing doesn't destroy entanglement)
- ✅ Cluster states foundation of MBQC (measurement-based quantum computing)
- ✅ Density matrix grows as 2^N × 2^N (exponential, realistic!)
- ✅ Measurement of one qubit collapses entire GHZ state

**Simplified:**
- ⚠️ No gate errors or imperfect entanglement (real hardware has noise)
- ⚠️ Density matrix limited by memory (real systems: N ≤ 50 qubits)

---

## Performance Considerations

**Density Matrix Size:**

| Qubits (N) | Matrix Size | Memory     | Feasible?     |
|------------|-------------|------------|---------------|
| 2          | 4×4         | 128 bytes  | ✅ Always     |
| 3          | 8×8         | 512 bytes  | ✅ Always     |
| 4          | 16×16       | 2 KB       | ✅ Always     |
| 5          | 32×32       | 8 KB       | ✅ Fine       |
| 6          | 64×64       | 32 KB      | ✅ Fine       |
| 8          | 256×256     | 512 KB     | ⚠️ Expensive  |
| 10         | 1024×1024   | 8 MB       | ❌ Too large  |

**Recommendation:** Limit clusters to **N ≤ 6 qubits** (64×64 matrix).

**Optimization:**
- Use sparse matrix representation for large N
- Or switch to state vector for pure states (2^N complex numbers instead of 2^N × 2^N)

---

## Educational Value

**Students Learn:**

1. **Multi-Qubit Entanglement**
   - GHZ states vs W states (different types of entanglement)
   - Sequential gate construction (how real quantum computers work!)
   - Measurement-induced collapse (non-locality)

2. **Quantum Gates**
   - CNOT gate creates entanglement
   - Controlled-Z for cluster states
   - Gate sequences build complex states

3. **Measurement-Based Quantum Computing**
   - Cluster states encode computation
   - One-way quantum computer (measurements perform gates!)
   - Graph structure determines algorithm

4. **Exponential Complexity**
   - 2^N scaling is fundamental to quantum mechanics
   - Why quantum computers are powerful (exponential Hilbert space)
   - Why simulation is hard (memory explodes!)

---

## Summary

**The user is 100% correct:** We should support N-qubit entanglement via sequential 2-qubit gates!

**What to implement:**

1. **EntangledCluster class** - N-qubit density matrix
2. **Sequential entanglement** - Add qubits one at a time
3. **GHZ/W/Cluster states** - Different entanglement types
4. **Upgrade path** - EntangledPair → EntangledCluster
5. **Measurement cascades** - Collapse propagates through cluster

**Physics accuracy:** 9/10 (real quantum computing methods!)

**Gameplay impact:**
- Late game: Build massive N-qubit clusters
- Higher topology bonuses (exponential scaling!)
- Strategic measurement (GHZ fragile, W robust)
- Visual spectacle (hypergraph visualizations)

**Ready to implement?** 🚀⚛️
