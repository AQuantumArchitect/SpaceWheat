# SpaceWheat Quantum Tools – Physics‑Correct Implementation Directive (Model B)

## Purpose
This document is direction for implementation bots. It fixes physics inconsistencies, answers open clarifications, and specifies the intended plot↔biome dynamic.

Primary intent: **the Biome/QuantumBath is the “quantum computer”** (global state handler). Plots (and later subplots) are **hardware attachments / registers** connected into that computer.

---

## Canonical model (Model B)
### One source of truth
- There is exactly **one canonical quantum state per biome**.
- Plots do **not** carry independent quantum states that can disagree with the biome.
- Any “plot state” is a *view* or *register reference* into the biome’s quantum computer.

### What a plot is, physically
- A **plot corresponds to a logical register** (initially 1 qubit; later may expand to multiple qubits/subplots).
- A plot’s Dual‑Emoji projection is **a UI/semantic labeling of that register’s measurement basis**, not an additional subsystem.

### Scaling reality check
- A literal dense global state over many qubits scales as 2^n. We will remain physics‑correct by using a backend that supports:
  1) **Exact dense simulation** for small connected components.
  2) **Factorized / component simulation** for larger farms (still one “global state” managed by the biome as a product of independent components).
  3) (Optional later) **Stabilizer simulation** for Clifford‑only regimes.

The biome remains the global handler even if internally represented as multiple independent components.

---

## Clarifications answered (for bots)
### 1) Entanglement & 2‑qubit gates: what is being entangled?
- **Entanglement and gates target registers (plot‑IDs), not emoji indices.**
- Multiple plots may share the same emoji labels (e.g., many wheat plots). That does *not* merge them into one subsystem.
- Each plot has its own logical qubit/register inside the biome’s quantum computer.

### 2) Measurement outcome correlation
- Yes: if plots are entangled, measurement outcomes must be correlated per the joint state.
- Batch measurement must respect entanglement connectivity (measure connected components coherently).

### 3) Energy tap integration
- Energy taps are **not measurement** by default.
- They are **dissipative channels** (environment coupling) that transfer amplitude/probability into a sink/ledger.
- Payout should be credited **continuously during evolve** (buffered per tick/time slice), not via a separate harvest step unless a specific gameplay reason is chosen.

### 4) Gate removal semantics
- “Remove Gates” clears **scheduled/registered controls** and UI markers.
- It does **not** attempt to “undo” history (especially under noise/decoherence).
- Optional: keep a non-authoritative UI log (“removed gate X at time t”), but correctness must not depend on logs.

---

## State representation (research‑grade constraints)
Regardless of backend, the quantum layer must preserve:
- Hermiticity: ρ = ρ†
- Positivity: eigenvalues ≥ 0 (within numerical tolerance)
- Trace: Tr(ρ) = 1

### Backend recommendation (minimum viable, physics‑correct)
Represent the biome quantum computer as a set of **connected components** of registers:
- Each component C has:
  - a register list (plot registers, later sub-registers)
  - a state (either statevector |ψ⟩ or density matrix ρ)
  - an operation queue (unitaries / channels)

Component rules:
- Unentangled plots live in 1‑qubit components.
- Entangling two plots merges their components.
- Disentanglement is *not* assumed to occur automatically; components can remain multi‑qubit.

This is still Model B: the biome owns and updates every component as the global state.

---

## Plot ↔ biome interface: Dual‑Emoji as basis labeling
### Plot register
- Each plot has a stable register id (e.g., the grid coordinate), mapped to a logical qubit in the biome.

### Dual‑Emoji axis
- Each plot has `(north_emoji, south_emoji)`.
- This defines a **measurement basis label** for that plot’s logical qubit:
  - computational |0⟩ is “north”
  - computational |1⟩ is “south”

Important:
- Emojis are **labels** for |0⟩ and |1⟩, not basis states in a shared emoji Hilbert space.
- Many plots can use the same emojis without implying shared quantum identity.

### Changing the axis (rotation)
This must be physics‑correct:
- Axis change corresponds to a **local unitary** on that plot’s register.
- If the plot is entangled, apply the local unitary to the *component state* using tensor product semantics:
  - ρ' = (U_A ⊗ I) ρ (U_A† ⊗ I)

No “freeze axis while entangled” is required for correctness; freezing may be used as a temporary simplification only.

---

## Gates (Tool 5) – physics‑correct semantics
### Gate targets
- 1‑qubit gates act on the plot’s logical qubit.
- 2‑qubit gates act on the ordered pair (control, target) logical qubits.

### Implementation rule
- Gates must be applied in the correct tensor product space of the component.
- Do **not** emulate 2‑qubit gates by editing a single N×N emoji matrix without an explicit tensor product structure.

### Gate scheduling vs instantaneous
- MVP: instantaneous application + registry entry.
- Later: scheduled controls (registry drives application at specified times).

---

## Entanglement (Tool 1 / Tool 2 Q) – physics‑correct semantics
### What “entangle plots” does
- Allocate/identify the two plot registers.
- Ensure they are in the same component (merge if needed).
- Apply a standard entangling circuit in that component, e.g.:
  - H on A
  - CNOT A→B

This yields Bell Φ+ from |00⟩.

### Cluster state (later)
- Only after 2‑qubit is stable.
- Implement via CZ edges on a chosen graph over registers.

---

## Measurement (Tool 2) – remove “soft collapse”
### Absolute rule: measurement is not “soft” by default
Tool 2 should implement **projective measurement** on a chosen register (or set of registers). No heuristic partial collapse.

### Two distinct operations
1) **MEASURE (physical simulation):**
   - Projective measurement of selected registers.
   - Samples an outcome according to Born probabilities.
   - Updates the component state by projection + renormalization.
   - Only components containing the measured registers are affected.

2) **INSPECT / READOUT (simulator introspection):**
   - Returns probability distribution(s) (marginals) computed from the current state.
   - **Does not** update the state.
   - This is not a physical measurement; it is a “peek” available because we are simulating.

Rename tools/UI accordingly to avoid teaching incorrect physics.

### “Measure all” request
Interpreting “extract p values as if infinite measurements”:
- Implement as **INSPECT ALL**: return relevant marginals / distributions for all registers (or summary stats).
- If you also want a one-shot global collapse, that is a separate action: **MEASURE ALL** (samples one global outcome and collapses state).

---

## Energy taps (Tool 4) – dissipative channels, not measurement
### Default: drain channel
- Implement energy taps as CPTP evolution (e.g., Lindblad) that transfers population into a sink/ledger.
- Credit resources proportional to accumulated sink flux over time.

### Optional: measurement-based taps (advanced)
If later desired, taps can be implemented as continuous measurement (quantum trajectories), but that is explicitly *not* the MVP and requires careful pedagogy.

---

## Practical implementation plan (what bots should build)
### Phase 0: Correctness scaffolding
- Define `RegisterId` per plot.
- Define `Component` structure with register list + state.
- Implement merge/split operations (merge required; split optional).

### Phase 1: Unitary gates
- Implement apply_1q(U, reg) and apply_2q(U, regA, regB) on a component.
- Implement Tool 5 gate actions using these.

### Phase 2: Projective measurement
- Implement MEASURE(reg) (and MEASURE([regs])) on a component.
- Implement INSPECT(reg) / INSPECT_ALL as non-mutating probability queries.
- Update Tool 2 to remove “soft collapse”; replace with MEASURE and INSPECT.

### Phase 3: Entanglement & batch measurement
- Implement entangle_plots(A,B) as H + CNOT.
- Implement batch measurement as “measure connected components in a deterministic safe order”.

### Phase 4: Energy taps
- Implement drain channel + flux ledger + buffered payout.

---

## Validation tests (must-have)
- After any operation: Tr(ρ)=1 within epsilon.
- ρ is Hermitian within epsilon.
- ρ is PSD within epsilon (spot-check with eigenvalues for small components).
- Bell test: entangle(A,B) then MEASURE both in Z basis → outcomes perfectly correlated.
- Gate test: apply H then MEASURE → 50/50.
- INSPECT does not change subsequent MEASURE statistics.

---

## Non-negotiables (physics safety)
- No “soft collapse” heuristics in Tool 2.
- No 2‑qubit gates without explicit tensor product semantics.
- Keep a single canonical state per biome (possibly internally factorized into components).
- Distinguish simulator introspection from physical measurement in naming and UI.

