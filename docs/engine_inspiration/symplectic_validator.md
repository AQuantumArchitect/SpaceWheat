# Symplectic Validator

**Source file:** `Core/QuantumSubstrate/SymplecticValidator.gd` (archived — safe to delete)

## The idea
A static-method validator that checks whether a density matrix evolution step preserved the four required CPTP invariants: trace = 1, Hermiticity, positivity (diagonals ≥ 0), and purity bounds `1/d ≤ Tr(ρ²) ≤ 1`. Framed explicitly as the quantum analogue of Liouville's theorem — Hamiltonian flow preserving phase space volume.

## What's interesting
- **Callable validator hook** — `create_evolution_validator(qc)` returns a closure that captures the last state and compares before/after each tick. Drop it in anywhere in the evolution pipeline with zero coupling; it fires `push_warning` on violations and is silent otherwise. This is a debug overlay, not a corrector.
- **Purity as a signal, not just a constraint** — the validator tracks purity before and after, so a caller can detect coherence injection (purity increasing unphysically) as well as decoherence. Useful for catching Lindblad bugs that accidentally add coherence.
- **Named tolerance constants** at the top (`TRACE_TOLERANCE = 0.01`, etc.) — tunable without touching logic. The loose-looking tolerance of 1% was deliberate: tighter thresholds caused false positives during normal Euler drift.
- The positivity check is diagonal-only (eigenvalue decomposition is too expensive per-tick). A full check would require Cholesky; the comment is explicit about this shortcut.
- Phase space volume estimation via bounding box (`estimate_phase_space_volume`) — very rough but O(n) on trajectory length. The idea of tracking biome state trajectory bounding boxes as a "spread" metric is novel.

## Implementation notes
- `check_unitarity` and `check_complete_positivity` are stubs with `push_warning`. Don't call them in production paths.
- `_duplicate_matrix` loads Complex and ComplexMatrix at call time (not preloaded) — this was intentional to avoid circular deps in static context, but it's slow if called frequently.
- The purity calculation is `Σ|ρᵢⱼ|²`, which equals `Tr(ρ²)` only for Hermitian ρ. This is correct but relies on the Hermitian check passing first.
- `format_validation_report()` returns a ready-to-print string — useful for one-shot debug dumps.

## Connections
- **QuantumEvolver** — the natural integration point: wrap `evolve()` to call the validator closure after each step in debug builds.
- **BiomeDeterministicStepper** — could gate replay validity on symplectic checks: if a replay step fails the validator, flag it as a diverged trajectory.
- **Biome Lab sweep CLI** — feed validation results into sweep output to surface unstable Hamiltonian configurations automatically.
- **RuntimeProfileProbe** — validator is zero-cost when not installed; useful during profiling runs to confirm the hot-path evolution isn't silently corrupting state.
