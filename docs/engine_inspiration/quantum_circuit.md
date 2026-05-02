# Quantum Circuit (Declarative Builder)

**Source file:** `Core/QuantumSubstrate/QuantumCircuit.gd` (archived — safe to delete)

## The idea
A chainable, declarative builder that composes a sequence of gate instructions and then executes them in one shot against a live QuantumComputer. The API reads like quantum pseudocode: `circuit.h(0).cnot(0,1).snapshot("bell").measure(0)`. Execution produces a structured result dict with measurement outcomes and named snapshots.

## What's interesting
- **Named snapshots mid-circuit** — `snapshot("label")` captures purity, populations, marginal purities, and basis probabilities at any point. This is a built-in observability primitive; no external probing needed. Good for debugging gate sequences without halting evolution.
- **`evolve(dt)` as a first-class circuit instruction** — Hamiltonian evolution lives on the same tape as discrete gates. A circuit can mix gate-based operations with continuous-time physics ticks, which fits SpaceWheat's hybrid model perfectly.
- **`project()` vs `measure()`** — deterministic post-selection (collapse to specific outcome, no sampling) is its own operation, separate from Born-rule measurement. Useful for testing and for story-flag forcing.
- **`ghz(qubits)` helper** — one-liner GHZ state factory: H + CNOT chain. Directly maps to BellStateDetector's GHZ grid patterns.
- The circuit is a pure data structure (array of instruction dicts); it can be serialized, transmitted, and re-run. Basis for a Quantum Composer UI or recorded player macros.

## Implementation notes
- `run_on(qc)` is synchronous and returns a full result dict. No async; the caller drives timing.
- `basis_probs` is skipped when `dim > 64` (6+ qubits). This threshold is already baked in; keep it if reinstating.
- `measure_all` determines qubit count at execution time from `qc.register_map.num_qubits` — circuit is layout-agnostic.
- `duplicate_circuit()` does deep copy of the instruction array; safe to fork and mutate.
- The `_labels` dict exists but is never written by any current instruction. Was reserved for jump/loop semantics that never landed.

## Connections
- **QuantumGateLibrary** — already imported; all gate dispatch goes through it.
- **QuantumComputer** — `run_on(qc)` is the bridge; the circuit is engine-agnostic as long as the computer exposes `apply_gate`, `project_qubit`, `get_marginal`, `evolve`.
- **Biome Lab sweep CLI** — circuits are ideal as parameterized test fixtures: build once, sweep over theta values.
- **PlayerInputMacroRunner** — the macro runner does the same conceptual job (action sequences) at the gameplay level; QuantumCircuit is its quantum-physics analogue.
- **Gate Architect System** — circuit builder is the natural authoring format for the headless gate injection workflow described in `project_gate_architect.md`.
