# Tool 2: QUANTUM Gates System Design

## Current Status

**Implementation**: ⚠️ Partial - UI complete, backend pending
**UI**: ✅ Complete (gate building UI exists)
**Backend**: ❌ Gate construction logic missing
**Measurement Triggers**: ⚠️ UI ready, wiring incomplete

```
Q: Cluster (Build Gate 2=Bell, 3+=Cluster)
E: Measure Trigger (Set automated measurement)
R: Measure Batch (Measure multiple plots)
```

---

## Current Implementation

### What Works
- Gate definitions exist (2-qubit Bell, N-qubit cluster states)
- UI for gate selection is integrated
- Plot selection mechanism exists
- Bell state entanglement already implemented (in Tool 1)

### What's Missing
- Gate construction logic (selecting plots, building gate)
- Gate persistence mechanism (storing which plots have gates)
- Measurement trigger system (auto-measure at maturity)
- Batch measurement coordination

---

## Questions for Design

### Question 1: GATE PERSISTENCE ACROSS HARVEST

**Should quantum gates survive when a plot is harvested?**

#### Option A: Gates Destroyed on Harvest
- Gates are temporary (exist only until measurement/harvest)
- After harvest, plot resets to fresh state
- Implications:
  - Simple implementation (no cross-harvest state)
  - Gates are tactical (immediate strategy)
  - Player must apply gates before harvest cycle

#### Option B: Gates Persist Across Harvest
- Gates applied to physical plot location, not quantum state
- After harvest, plot regrows with gates still active
- Implications:
  - Gates become strategic infrastructure
  - Player plans long-term gate configuration
  - Requires persistent gate storage mechanism
  - More complex implementation

#### Option C: Hybrid - Gate Decay
- Gates gradually weaken over time
- Each harvest reduces gate strength (lose 20% fidelity)
- After 5 harvests, gate disappears
- Implications:
  - Gates are valuable but temporary
  - Player must periodically reapply gates
  - Interesting economic/gameplay balance

**Recommendation needed**: Should gates be temporary or persistent?

---

### Question 2: MEASUREMENT TRIGGER SYSTEM

**How should automated measurement work?**

#### Option A: Auto-Measure at Maturity
- Setting trigger = "measure this plot at 3-day mark"
- System automatically measures when plant matures
- No player action needed at harvest time
- Implications:
  - Reduces micromanagement
  - Enables planning ahead
  - Plot transitions plant → measured automatically

#### Option B: Manual Trigger Toggle
- Setting trigger = "I'll manually measure when ready"
- Player toggles trigger on/off as needed
- Can measure early or late
- Implications:
  - Player retains control
  - More micromanagement
  - Flexible measurement timing

#### Option C: Threshold-Based Triggers
- Setting: "Measure when purity > 0.5"
- System monitors purity in real-time
- Automatically measures when condition met
- Implications:
  - Condition-based automation
  - More sophisticated system
  - Enables passive optimization strategies

#### Option D: Cost-Based Triggers
- Setting: "Measure when expected yield > X credits"
- System estimates yield from purity
- Measures when profitable
- Implications:
  - Economic automation
  - Requires yield prediction
  - Interesting for "greedy" strategies

**Recommendation needed**: Which trigger model?

---

### Question 3: CLUSTER STATE PRIORITY

**Should we prioritize 2-qubit Bell states or N-qubit clusters?**

#### Option A: 2-Qubit Bell States First
- Implement Bell states initially (CNOT, CZ, SWAP on 2 plots)
- Cluster states (3+ plots) as future enhancement
- Implications:
  - Simpler to implement (2×2 density matrices)
  - Focus on entanglement depth
  - Matches Tool 5 (Gate operations) structure

#### Option B: Full N-Qubit Support
- Implement cluster states for any size (2, 3, 4, ..., N)
- Support arbitrary entanglement patterns
- Implications:
  - More complex implementation (larger density matrices)
  - Higher computational cost (O(N²) complexity)
  - More strategic depth
  - Requires careful Hilbert space management

#### Option C: Restricted Cluster Sizes
- Support clusters up to 3 qubits (2-way, 3-way entanglement)
- Larger clusters forbidden
- Implications:
  - Bounded complexity
  - Limits strategy depth
  - Computational efficiency guaranteed

**Recommendation needed**: Should we support arbitrary-size clusters or restrict to 2-qubit?

---

### Question 4: GATE-MEASUREMENT INTERACTION

**How should gates interact with the measurement system?**

#### Option A: Gates Survive Measurement
- Applying measurement doesn't destroy gates
- Measured plot still has gate applied
- Gate continues to evolve even in measured state
- Implications:
  - Complex quantum mechanics (gate + measurement)
  - Interesting post-measurement behavior
  - High implementation complexity

#### Option B: Measurement Destroys Gates
- Measuring a plot removes any gates
- Player must choose: gate vs. measurement
- Interesting strategic tradeoff
- Implications:
  - Simpler implementation (no post-measurement gates)
  - Clear tradeoff (can't have both)
  - Affects gate timing strategy

#### Option C: Gate-Dependent Measurement
- Gate type determines if measurement preserves it
- Bell gate preserved on measurement
- Cluster gate destroyed on measurement
- Implications:
  - Different gate types have different behaviors
  - More strategic depth
  - More complex to implement

**Recommendation needed**: Should measurement preserve or destroy gates?

---

## Current Quantum System Context

### Existing Entanglement System
- Tool 1 already implements Bell state entanglement (φ+ state)
- Plots can be entangled via `farm.entangle_plots(pos1, pos2)`
- Entanglement survives across measurement cycles
- Entanglement information stored in Farm.grid.entanglements

### Density Matrix Representation
- Each plot has quantum_state (2D projection: 🌾↔👥)
- Biome has quantum_bath (manages all emojis for that biome)
- Hilbert space: 6-22 dimensions depending on biome
- Lindblad evolution running continuously

### Measurement System
- Current: Soft measurement (collapse_strength = 0.5)
- Converts plot from unmeasured → measured state
- Outcome emoji determined by purity
- Yield = base_yield × purity_multiplier

### Gate Operations (Tool 5) - Related
- Pauli-X, Pauli-Z: Single-qubit operations
- Hadamard: Superposition creation
- CNOT, CZ: 2-qubit controlled gates
- SWAP: Qubit exchange
- These gates would be applied *before* measurement via Tool 2

---

## Integration Requirements

### Required Changes

**FarmGrid.gd**:
- Add `gates_registry: Dictionary` (tracks applied gates)
- Add `apply_gate(pos: Vector2i, gate_type: String, params: Dict) -> bool`
- Add `get_gates_on_plot(pos: Vector2i) -> Array`
- Add `clear_gates(pos: Vector2i)`

**BasePlot.gd**:
- Add `applied_gates: Array` (gates on this plot)
- Add `measurement_trigger: Dictionary` (if set, when to measure)
- Add `check_measurement_trigger()` in _process()

**QuantumBath.gd**:
- Add `apply_unitary(gate_matrix: ComplexMatrix, indices: Array[int])`
- Apply gate operation during Lindblad evolution

**Farm.gd**:
- Add `build_gate(gate_type: String, positions: Array[Vector2i])` public method
- Add `set_measurement_trigger(pos: Vector2i, trigger_config: Dict)`

---

## Implementation Sequence (After Design Approval)

1. Design decision: Gate persistence model
2. Design decision: Measurement trigger system
3. Design decision: Cluster size limits
4. Implement gate storage data structures
5. Implement gate application logic in QuantumBath
6. Implement measurement trigger checks
7. Wire Tool 2 actions to gate building
8. Wire Tool 2 E action to trigger system
9. Integration testing with Tool 1 (farming)
10. Integration testing with Tool 5 (gate operations)

**Estimated effort**: 5-7 hours (after design is approved)

---

## Questions for External Review

1. **Mechanical coherence**: Should gates be "true" quantum gates (unitary, reversible) or simplified abstractions?
2. **Strategic depth**: Should gates be powerful (game-changing) or subtle (marginal improvements)?
3. **Accessibility**: Is the gate system too complex for new players, or right-sized?
4. **Phase alignment**: Does this align with Phase 3 (Measurement Refactor) of the manifest?
5. **Visual representation**: Should gates have visual feedback on plots, or stay abstract?

---

## Risk Assessment

**High-complexity features**:
- N-qubit Hilbert space expansion (O(2^N) computational cost)
- Cross-harvest gate persistence (state management)
- Measurement trigger system (real-time monitoring)

**Mitigation**:
- Start with 2-qubit gates only (fixed 4D space)
- Use simplified trigger system (only auto-at-maturity)
- Cache gate states to avoid recomputation

