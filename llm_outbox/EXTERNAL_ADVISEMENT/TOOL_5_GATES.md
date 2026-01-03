# Tool 5: GATES Operations Design

## Current Status

**Implementation**: ⚠️ UI Complete, Backend Stubbed
**UI**: ✅ Complete (gate selection menus show all operations)
**Backend**: ❌ Quantum gate application logic missing

```
Q: Single-Qubit Gates (1-Qubit)
├─ Q: Pauli-X (Flip) ↔️
├─ E: Hadamard (H) 🌀
└─ R: Pauli-Z (Phase) ⚡

E: Two-Qubit Gates (2-Qubit)
├─ Q: CNOT (⊕)
├─ E: CZ (Control-Z) ⚡
└─ R: SWAP (⇄)

R: Remove Gates (💔)
```

---

## Questions for Design

### Question 1: GATE APPLICATION MECHANICS

**How should gates be applied to plots?**

#### Option A: Single-Plot Selection
- User selects gate type (e.g., Pauli-X)
- User clicks plot
- Gate applies to that plot immediately
- Implications:
  - 1-qubit gates: Apply directly to plot's qubit
  - 2-qubit gates: ERROR (need 2 plots)
  - Simplest UX (click gate, click plot)

#### Option B: Batch Plot Selection
- User selects gate type
- User selects multiple plots (shift+click or drag)
- User confirms (press ENTER)
- Gate applies to all selected plots
- Implications:
  - Same gate applies to multiple plots simultaneously
  - 2-qubit gates require pairs (select 2, 4, 6... plots)
  - More powerful but complex UX

#### Option C: Plot Pair Selection (2-Qubit Only)
- 1-qubit gates: Single plot selection
- 2-qubit gates: User selects 2 adjacent plots
- System validates adjacency
- Gate applies as controlled operation
- Implications:
  - Different UX for single vs. dual
  - Ensures 2-qubit gates are "entangling" (on adjacent plots)
  - More constraints on strategy

**Recommendation needed**: Which application model?

---

### Question 2: GATE EFFECT ON QUANTUM STATE

**How should gates modify the density matrix?**

#### Option A: True Unitary Operations
- Apply unitary matrix U to density matrix ρ
- ρ_new = U ρ U†
- Pauli-X: Bit-flip (flip |0⟩ ↔ |1⟩)
- Hadamard: Create superposition
- CNOT/CZ: Entangle qubits
- Implications:
  - Quantum mechanically correct
  - Reversible and unitary
  - Preserves probability (Tr(ρ)=1)
  - Most accurate but most complex

#### Option B: Simplified State Modifications
- Pauli-X: Swap north_emoji ↔ south_emoji (bit-flip shortcut)
- Hadamard: Set θ=π/4 (rotate to superposition)
- CNOT: Partial entanglement boost
- Implications:
  - Approximate quantum mechanics
  - Faster computation (no matrix multiplication)
  - Less "pure" but gameplay-focused
  - Easier to understand for players

#### Option C: Probabilistic Gates
- Gates have success probability (90%)
- Failed gate = state unchanged
- Adds risk/reward gameplay
- Implications:
  - Adds uncertainty/strategy
  - More interesting failure modes
  - Adds RNG which some dislike

**Recommendation needed**: Should gates be mathematically exact or gameplay-simplified?

---

### Question 3: GATE RESTRICTIONS & INTERACTION

**Should there be restrictions on which plots can receive gates?**

#### Option A: No Restrictions
- Any gate can apply to any plot
- Can gate measured plots, unmeasured plots, entangled plots
- Can stack multiple gates (Pauli-X then Hadamard)
- Implications:
  - Maximum flexibility
  - Maximum strategy space
  - Risk: Trivializing the game (gates make everything optimal)

#### Option B: No Gates on Measured Plots
- Can only gate unmeasured plots
- Measuring a plot removes gates
- Prevents gate after measurement commitment
- Implications:
  - Gates are pre-harvest tool only
  - Adds timing constraint
  - Prevents gate + measurement combo

#### Option C: No Stacking Gates
- Once plot has a gate, can't apply another
- Can remove and reapply (costs resources)
- One gate per plot maximum
- Implications:
  - Simpler state tracking
  - Strategic choice (which single gate?)
  - Prevents excessive optimization

#### Option D: Biome-Specific Restrictions
- BioticFlux: All gates allowed
- Market: No single-qubit gates (only controlled)
- Forest: No controlled gates (only single-qubit)
- Kitchen: No gates at all
- Implications:
  - Biome-based strategy asymmetry
  - Requires player learning
  - Encourages diverse strategies

**Recommendation needed**: Should we restrict where gates apply?

---

## Current Gate Definitions

### Available Gates (Already Defined)

**Single-Qubit Gates**:
- **Pauli-X** (↔️): Bit-flip - swaps basis states |0⟩ ↔ |1⟩
- **Pauli-Z** (⚡): Phase-flip - adds ± phase to |1⟩
- **Hadamard** (🌀): Creates superposition (|0⟩ + |1⟩)/√2

**Two-Qubit Gates**:
- **CNOT** (⊕): Controlled NOT - flips target if control is |1⟩
- **CZ** (⚡): Controlled Z - applies phase if both qubits are |1⟩
- **SWAP** (⇄): Exchange qubits - swaps basis states

### Mathematical Representation

```
Pauli-X = [[0, 1], [1, 0]]          (bit-flip matrix)
Pauli-Z = [[1, 0], [0, -1]]         (phase matrix)
Hadamard = 1/√2 [[1, 1], [1, -1]]   (superposition)
CNOT = [[1,0,0,0], [0,1,0,0], [0,0,0,1], [0,0,1,0]]
CZ = [[1,0,0,0], [0,1,0,0], [0,0,1,0], [0,0,0,-1]]
```

---

## Integration with Existing Systems

### Requires Coordination With

**Tool 1 (Grower)**:
- Gates should NOT interfere with planting/harvesting
- Verify gates don't break entanglement

**Tool 2 (Quantum)**:
- Tool 2 constructs Bell states (Tool 5 applies gates to them?)
- Or Tool 5 applies gates independently?
- Order of operations: build gates → apply gates → measure?

**Tool 4 (Biome Control)**:
- Pump/reset operations vs. gates (which takes priority?)
- Energy taps draining qubits while gates are applied

**Tool 6 (Biome)**:
- Biome reassignment - do gates persist?
- Gates change if plot reassigned to different biome?

---

## Implementation Sequence (After Design Approval)

1. Design decision: Application mechanics (single/batch/pair)
2. Design decision: Gate mathematics (unitary/simplified/probabilistic)
3. Design decision: Restrictions (none/no-measured/no-stack/biome-specific)
4. Implement gate application functions in QuantumBath
5. Implement plot selection UI
6. Implement gate validation logic
7. Wire Tool 5 actions to gate application
8. Integration testing with quantum evolution
9. Edge case testing (stacked gates, measured plots, etc.)
10. Balancing (test which gates are overpowered)

**Estimated effort**: 4-5 hours (after design is approved)

---

## Questions for External Review

1. **Player complexity**: Is exposing quantum gate mechanics too complex, or appropriate for "quantum engineer" theme?
2. **Balance**: Should gates provide major benefits (game-changing) or minor optimization?
3. **Learning curve**: Should there be gates tutorial/sandbox, or assume players know quantum mechanics?
4. **Reversibility**: Should gates be applied permanently or temporarily (e.g., "boost for 3 days")?
5. **Visual representation**: Should gates show as visual effects on plot? Or just in UI?

---

## Risk & Mitigation

**Risk**: Quantum mathematics incorrectness confuses players
- **Mitigation**: Simplify to "schematic" gates (not exact matrices), focus on observable effects (bit-flip swaps states, Hadamard creates randomness, etc.)

**Risk**: Gates become dominant strategy (trivialize farming)
- **Mitigation**: Restrict gates (no-measured-plots), add costs, limit per-plot

**Risk**: N-qubit gates cause exponential computational blow-up
- **Mitigation**: Restrict to 2-qubit maximum, no arbitrary-size clusters

**Risk**: Gate application UI becomes too complex
- **Mitigation**: Start with simple single-plot application, add batch selection later

