# Quantum Machinery Catalogue

Complete inventory of all quantum features, capabilities, and operations available in SpaceWheat.

---

## 1. STATE MANAGEMENT & REPRESENTATION

| Feature | File | Capability | Parameters |
|---------|------|-----------|------------|
| **State Initialization** | QuantumComputer.gd | Create pure basis states \|\|0⟩ or mixed states | north_emoji, south_emoji |
| **Density Matrix Storage** | DensityMatrix.gd | Store and manage complete quantum state ρ | n×n complex matrix |
| **Pure State Creation** | ComplexMatrix.gd | Create ρ = \|ψ⟩⟨ψ\| from statevector | amplitudes (array) |
| **Mixed State Creation** | ComplexMatrix.gd | Create diagonal mixed state | probabilities (array) |
| **Maximally Mixed State** | DensityMatrix.gd | Create ρ = I/N | dimension (int) |
| **Register Allocation** | QuantumComputer.gd | Create 1-qubit logical registers | register_id, component_id |
| **Component Management** | QuantumComputer.gd | Group entangled registers as 1 quantum system | tensor product structure |
| **RegisterMap Translation** | RegisterMap.gd | Map emojis ↔ (qubit, pole) coordinates | emoji → qubit:pole dict |
| **State Normalization** | ComplexMatrix.gd | Ensure Tr(ρ) = 1 | renormalize_trace() |

---

## 2. QUANTUM DYNAMICS & EVOLUTION

| Feature | File | Operation | Parameters |
|---------|------|-----------|------------|
| **Hamiltonian Evolution** | QuantumEvolver.gd | Unitary evolution dρ/dt = -i[H,ρ] | H (Hamiltonian matrix) |
| **Lindblad Evolution** | QuantumEvolver.gd | Lindblad master equation with dissipation | L_k (jump operators) |
| **Gated Lindblad** | QuantumComputer.gd | Conditional Lindblad: rate = base × P(gate)^power | gate_emoji, power |
| **Integration: Euler** | QuantumEvolver.gd | 1st-order forward Euler integration | dt (timestep) |
| **Integration: Cayley** | QuantumEvolver.gd | Exact unitary via Cayley transform | dt |
| **Integration: Expm** | QuantumEvolver.gd | Full matrix exponential (most accurate) | dt |
| **Integration: RK4** | QuantumEvolver.gd | 4th-order Runge-Kutta (strong dissipation) | dt |
| **Validate Evolution** | QuantumEvolver.gd | Check trace/Hermiticity preserved | before/after states |
| **Population Transfer** | QuantumComputer.gd | Lindblad-driven transition from_emoji → to_emoji | from_emoji, to_emoji, rate |
| **Decay Channel** | QuantumComputer.gd | Spontaneous decay to south pole | qubit_index, rate |
| **Phase-Driven Transfer** | QuantumComputer.gd | Create coherence e^(iφ) between states | from_emoji, to_emoji, phase |

---

## 3. QUANTUM GATES

| Gate | Type | File | Operation | Matrix |
|------|------|------|-----------|--------|
| **Pauli-X (NOT)** | 1-qubit | QuantumGateLibrary.gd | Bit flip: \|0⟩↔\|1⟩ | [[0,1],[1,0]] |
| **Pauli-Y** | 1-qubit | QuantumGateLibrary.gd | Y rotation | [[0,-i],[i,0]] |
| **Pauli-Z** | 1-qubit | QuantumGateLibrary.gd | Phase flip | [[1,0],[0,-1]] |
| **Hadamard (H)** | 1-qubit | QuantumGateLibrary.gd | Superposition | (1/√2)[[1,1],[1,-1]] |
| **S (Phase)** | 1-qubit | QuantumGateLibrary.gd | 90° phase | [[1,0],[0,i]] |
| **T** | 1-qubit | QuantumGateLibrary.gd | 45° phase | [[1,0],[0,e^(iπ/4)]] |
| **CNOT (CX)** | 2-qubit | QuantumGateLibrary.gd | Control-X on target | |00⟩→\|00⟩, \|01⟩→\|01⟩, \|10⟩→\|11⟩, \|11⟩→\|10⟩ |
| **Control-Z (CZ)** | 2-qubit | QuantumGateLibrary.gd | Control-phase | \|11⟩ gets -1 phase |
| **SWAP** | 2-qubit | QuantumGateLibrary.gd | Exchange qubits | \|ij⟩→\|ji⟩ |

**Gate Application Methods:**
- `apply_unitary_1q(comp, register_id, U)` - Embed 1-qubit gate in full space
- `apply_unitary_2q(comp, reg_a, reg_b, U)` - Embed 2-qubit gate in full space
- `_embed_1q_unitary(U, target_idx, num_qubits)` - Helper for embedding
- `_embed_2q_unitary(U, idx_a, idx_b, num_qubits)` - 2Q embedding helper

---

## 4. MEASUREMENT & STATE COLLAPSE

| Feature | File | Operation | Returns |
|---------|------|-----------|---------|
| **Single Register Measurement** | QuantumComputer.gd | Projective measurement: collapse to north or south | "north" or "south" |
| **Distribution Inspection** | QuantumComputer.gd | Non-destructive: query Born probabilities | {north: float, south: float} |
| **Component Batch Measure** | QuantumComputer.gd | Measure entire entangled component simultaneously | Dict[register_id → outcome] |
| **Axis Measurement** | QuantumComputer.gd | Measure emoji observable (via qubit-to-emoji map) | measured_emoji (string) |
| **Born Rule Sampling** | QuantumComputer.gd | Sample outcome from probability distribution | outcome_string |
| **State Projection** | QuantumComputer.gd | Apply projector P_k and renormalize | ρ' = P_k ρ P_k† / Tr(...) |

---

## 5. ENTANGLEMENT & CORRELATIONS

| Feature | File | Operation | Parameters |
|---------|------|-----------|------------|
| **Bell State Creation** | QuantumComputer.gd | Apply H + CNOT to create Bell Φ+ | (register_a, register_b) |
| **Bell State Φ+** | EntangledPair.gd | Create (\\|00⟩ + \\|11⟩)/√2 | Maximally entangled, perfect correlation |
| **Bell State Φ-** | EntangledPair.gd | Create (\\|00⟩ - \\|11⟩)/√2 | Relative phase |
| **Bell State Ψ+** | EntangledPair.gd | Create (\\|01⟩ + \\|10⟩)/√2 | Opposite outcomes |
| **Bell State Ψ-** | EntangledPair.gd | Create (\\|01⟩ - \\|10⟩)/√2 | Opposite + phase |
| **GHZ State (3-qubit)** | QuantumComputer.gd | (\\|000⟩ + \\|111⟩)/√2 | Multipartite entanglement |
| **W State (3-qubit)** | BellStateDetector.gd | (\\|001⟩ + \\|010⟩ + \\|100⟩)/√3 | Less entangled than GHZ |
| **Cluster State** | BellStateDetector.gd | Linear + perpendicular topology | Measurement-based computing |
| **Entanglement Graph** | QuantumComputer.gd | Track which registers are correlated | Dict[reg_id → Array[reg_id]] |
| **Component Merging** | QuantumComputer.gd | Merge components via tensor product | New dimension = old1 × old2 |
| **Decoherence: T1** | EntangledPair.gd | Amplitude damping (population decay) | coherence_time_T1 (float) |
| **Decoherence: T2** | EntangledPair.gd | Dephasing (loss of coherence) | coherence_time_T2 (float) |

---

## 6. OPERATOR CONSTRUCTION

### Hamiltonian Operators
| Feature | File | Operation | Filter |
|---------|------|-----------|--------|
| **Self-Energy Terms** | HamiltonianBuilder.gd | Diagonal energy on basis states | Adds ωᵢ to H[i,i] |
| **Single-Qubit Couplings** | HamiltonianBuilder.gd | σ_x rotations (\\|0⟩↔\\|1⟩ on same qubit) | Off-diagonal on same qubit |
| **Two-Qubit Couplings** | HamiltonianBuilder.gd | Conditional transitions (both qubits must match) | Both source poles → both target poles |
| **Hermitian Symmetry** | HamiltonianBuilder.gd | Ensure H = H† | Symmetrize output |
| **Sparse Commutator** | Hamiltonian.gd | Optimized [H, ρ] computation | Fast matrix operations |
| **Cayley Operator** | Hamiltonian.gd | Exact unitary (I-iHdt/2)⁻¹(I+iHdt/2) | Unitary-preserving |
| **Evolution Operator** | Hamiltonian.gd | Matrix exponential exp(-iH dt) | Full time evolution |

### Lindblad Jump Operators
| Feature | File | Operation | Structure |
|---------|------|-----------|-----------|
| **Outgoing Population** | LindbladBuilder.gd | Flow FROM source TO target | L = √γ \\|target⟩⟨source\\| |
| **Incoming Population** | LindbladBuilder.gd | Flow INTO source FROM other | L = √γ \\|source⟩⟨from\\| |
| **Gated Lindblad** | LindbladBuilder.gd | Conditional: rate = base × P(gate)^power | Config: {target, source, gate, power} |
| **Same-Qubit Flip** | LindbladBuilder.gd | Single qubit changes pole | Targets \\|0⟩→\\|1⟩ or vice versa |
| **Cross-Qubit Transfer** | LindbladBuilder.gd | Two qubits flip correlated | Both qubits change together |
| **Dissipative Superoperator** | LindbladSuperoperator.gd | Compute D[L](ρ) = L ρ L† - ½{L†L, ρ} | Lindblad term |

---

## 7. STATE PROPERTIES & ANALYSIS

| Metric | File | Computation | Range |
|--------|------|------------|-------|
| **Purity** | DensityMatrix.gd, SemanticUncertainty.gd | Tr(ρ²) | [1/d, 1.0] |
| **Entropy** | DensityMatrix.gd | Von Neumann: S = -Tr(ρ log ρ) | [0, log(d)] |
| **Trace** | ComplexMatrix.gd | Sum of diagonal elements | = 1.0 (normalized) |
| **Coherence** | ComplexMatrix.gd | Off-diagonal elements \\|ρᵢⱼ\\| | [0, 1.0] |
| **Precision** | SemanticUncertainty.gd | 1 - normalized_entropy | [0, 1.0] |
| **Flexibility** | SemanticUncertainty.gd | normalized_entropy | [0, 1.0] |
| **Uncertainty Product** | SemanticUncertainty.gd | precision × flexibility | ≥ h_semantic (0.25) |
| **Regime** | SemanticUncertainty.gd | Classification: crystallized/fluid/balanced/stable/chaotic/diffuse | String |

---

## 8. QUANTUM ALGORITHMS

| Algorithm | File | Computation | Advantage |
|-----------|------|-----------|-----------|
| **Deutsch-Jozsa** | QuantumAlgorithms.gd | Determine if f:{0,1}→{0,1} is constant or balanced | 1 query vs 2 classical |
| **Grover Search** | QuantumAlgorithms.gd | Find marked item in unsorted database | √N queries vs N classical |
| **Phase Estimation** | QuantumAlgorithms.gd | Estimate eigenvalues of unitary | Template (not full impl) |

**Key Methods:**
- `deutsch_jozza(bath, qubit_a, qubit_b)` → {result, measurement, advantage}
- `grover_search(bath, qubit_a, qubit_b, marked_state)` → {found, iterations, success_prob, advantage}

---

## 9. ENTANGLEMENT PATTERN DETECTION

| Pattern | File | Description | Structure |
|---------|------|-------------|-----------|
| **GHZ Horizontal** | BellStateDetector.gd | Three plots in row (---) | \\|000⟩ + \\|111⟩ (all correlated) |
| **GHZ Vertical** | BellStateDetector.gd | Three plots in column (\|) | Same \\|000⟩ + \\|111⟩ |
| **GHZ Diagonal** | BellStateDetector.gd | Three diagonal (\\\ or /) | Same structure, rotated |
| **W State** | BellStateDetector.gd | L-shape or corner | \\|001⟩ + \\|010⟩ + \\|100⟩ (any 1 differs) |
| **Cluster State** | BellStateDetector.gd | T-shape (linear + perpendicular) | Measurement-based computing |

**Detection Method:**
- `analyze_entanglement_network(plots)` → {features, pattern, bonus_multiplier}

---

## 10. SEMANTIC/TOPOLOGICAL ANALYSIS

### Semantic Octant Detection
| Region | File | Signature | Modifiers |
|--------|------|-----------|-----------|
| **Phoenix** | SemanticOctant.gd | +++ (high energy, growth, wealth) | growth: 1.5x, yield: 1.3x, decay: 1.2x |
| **Sage** | SemanticOctant.gd | -+- (low energy, high growth, low wealth) | growth: 0.8x, yield: 1.0x, decay: 0.6x |
| **Warrior** | SemanticOctant.gd | +-- (high energy/activity only) | growth: 0.9x, yield: 0.8x, decay: 1.5x |
| **Merchant** | SemanticOctant.gd | +-+ (high energy/wealth) | growth: 1.0x, yield: 1.5x, decay: 1.0x |
| **Ascetic** | SemanticOctant.gd | --- (low everything) | growth: 0.6x, yield: 0.7x, decay: 0.5x |
| **Gardener** | SemanticOctant.gd | -++ (low energy, high growth/wealth) | growth: 1.3x, yield: 1.2x, decay: 0.8x |
| **Innovator** | SemanticOctant.gd | ++- (high energy/growth, low wealth) | growth: 1.2x, yield: 0.9x, decay: 1.3x |
| **Guardian** | SemanticOctant.gd | --+ (high wealth only) | growth: 0.7x, yield: 1.1x, decay: 0.7x |

### Attractor Analysis
| Personality | File | Description | Metrics |
|-----------|------|-----------|---------|
| **Stable** | StrangeAttractorAnalyzer.gd | Fixed point attractor | Lyapunov < -0.05, spread < 0.2 |
| **Cyclic** | StrangeAttractorAnalyzer.gd | Periodic limit cycle | Periodicity > 0.6, Lyapunov < 0.05 |
| **Chaotic** | StrangeAttractorAnalyzer.gd | Strange attractor | Lyapunov > 0.05, Periodicity < 0.3 |
| **Explosive** | StrangeAttractorAnalyzer.gd | Unbounded growth | Spread > 2.0 or Lyapunov > 0.5 |
| **Irregular** | StrangeAttractorAnalyzer.gd | Transitional behavior | Else |

### Topological Analysis
| Feature | File | Operation | Output |
|---------|------|-----------|--------|
| **Entanglement Network** | TopologyAnalyzer.gd | Analyze plot graph structure | Knot/topology info |
| **Topological Bonus** | TopologyAnalyzer.gd | Compute gameplay bonus from topology | bonus_multiplier (float) |
| **Pattern Recognition** | TopologyAnalyzer.gd | Fingerprint detection of known knots | pattern (KnotInfo) |

---

## 11. CONSERVATION & VALIDATION

| Property | File | Check | Tolerance |
|----------|------|-------|-----------|
| **Trace Conservation** | SymplecticValidator.gd | Tr(ρ) = 1 before and after | 0.01 |
| **Hermiticity** | SymplecticValidator.gd | ρ = ρ† (real eigenvalues) | 0.001 |
| **Positivity** | SymplecticValidator.gd | All eigenvalues ≥ 0 | 0.001 |
| **Purity Bounds** | SymplecticValidator.gd | 1/d ≤ Tr(ρ²) ≤ 1 | 0.01 |
| **Volume Conservation** | SymplecticValidator.gd | Phase space volume preserved | 10% (configurable) |
| **CPTP Property** | SymplecticValidator.gd | Completely positive trace-preserving | Validation hook |

---

## 12. OBSERVABLE EXTRACTION

| Method | File | Output | Constraints |
|--------|------|--------|------------|
| **Get Population** | QuantumComputer.gd | Probability for emoji ρ[i,i] | RegisterMap must have emoji |
| **Get All Populations** | QuantumComputer.gd | Dict{emoji → float} for all registered | Complete coverage |
| **Get Purity** | QuantumComputer.gd | Tr(ρ²) as single float | [1/d, 1.0] |
| **Get Coherence** | ComplexMatrix.gd | Off-diagonal element \\|ρᵢⱼ\\| | Any i≠j |
| **Expectation Value** | (not directly exposed) | ⟨A⟩ = Tr(Aρ) | Would require observable matrix |

---

## 13. SPARK SYSTEM (Energy Extraction)

| Feature | File | Operation | Effect |
|---------|------|-----------|--------|
| **Energy Split** | ComplexMatrix.gd | Compute real (diagonal) vs imaginary (off-diagonal) | {real, imaginary, total, ratio} |
| **Spark Extraction** | SparkConverter.gd | Convert imaginary → real energy | Reduces coherence, increases population |
| **Extraction Efficiency** | SparkConverter.gd | constant = 0.8 | Conversion rate |
| **Decoherence Rate** | SparkConverter.gd | constant = 2.0 | Coupling strength |
| **Regime: High Coherence** | SparkConverter.gd | Mostly quantum (> 0.7 ratio) | Many operations available |
| **Regime: Balanced** | SparkConverter.gd | Mixed (0.3-0.7 ratio) | Normal gameplay |
| **Regime: Mostly Classical** | SparkConverter.gd | Mostly classical (< 0.3 ratio) | Limited quantum operations |

---

## SUMMARY STATISTICS

| Category | Count |
|----------|-------|
| **Total Quantum Files** | 35+ |
| **Quantum Gates** | 9 (6 single-qubit, 3 two-qubit) |
| **Evolution Methods** | 4 (Euler, Cayley, Expm, RK4) |
| **Measurement Types** | 3 (single, batch, axis) |
| **Entanglement Patterns** | 5 (GHZ-H, GHZ-V, GHZ-D, W, Cluster) |
| **Semantic Regions** | 8 (Phoenix, Sage, Warrior, Merchant, Ascetic, Gardener, Innovator, Guardian) |
| **Attractor Types** | 5 (stable, cyclic, chaotic, explosive, irregular) |
| **Conservation Properties** | 6 (trace, Hermiticity, positivity, purity, volume, CPTP) |
| **Analysis Tools** | 5 major (uncertainty, topology, dynamics, attractor, symplectic) |
| **Quantum Algorithms** | 3 (Deutsch-Jozsa, Grover, Phase Estimation) |
