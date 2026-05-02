# Quantum Evolver

**Source file:** `Core/QuantumSubstrate/QuantumEvolver.gd` (archived — safe to delete)

## The idea
A self-contained numerical integrator for the Lindblad master equation (`dρ/dt = -i[H,ρ] + Σ D[L](ρ)`), supporting four interchangeable methods: Euler, Cayley, matrix exponential (EXPM), and RK4. The method auto-selects based on system size: Cayley for N ≤ 12, Euler for larger.

## What's interesting
- **Cayley form** (`U = (I - iHdt/2)⁻¹(I + iHdt/2)`) is exactly unitary at every step, even for large dt. No accumulated unitarity drift. This is the right default for coherent biome evolution where the Hamiltonian part must stay lossless.
- **RK4 for strong dissipation** — when Lindblad rates dominate, Cayley's split approach loses accuracy; RK4 treating the full `dρ/dt` as a single derivative is markedly better. This matters for biomes with heavy Lindblad decay operators.
- **Sparse path** — the sparse commutator and sparse Lindblad application are the critical optimization. Dense NxN matrix multiplication kills perf at 4+ qubits; sparse paths already existed and were benchmarked.
- **Accumulated simulation time** (`_time`) feeds time-dependent Hamiltonians. The evolver owns the clock, not the caller.
- Built-in `validate_evolution()` runs N steps and reports trace error and positivity — usable as a debug probe without touching production code.

## Implementation notes
- The `_compute_drho_dt` used by RK4 is dense-only; a sparse version would be needed for RK4 on larger systems.
- `evolve_in_place()` does a full duplicate then copy-back — avoids in-place mutation but allocates. For hot-path per-phrame use, the caller should prefer `evolve()` and replace the reference.
- `use_sparse_operations` defaults true but is a simple bool — could become a per-method config if EXPM+sparse is ever needed.
- The dimension threshold (≤ 12 → Cayley) corresponds to 4-qubit systems (16x16 matrices). At 5 qubits (32x32) Cayley is still tractable; the cutoff was conservative.

## Connections
- **BiomeEvolutionBatcher** — the evolver is the heart of the per-biome tick; BatchEvolver calls should funnel through this class rather than reimplementing integration.
- **BiomeDeterministicStepper** — could use EXPM mode for replay-exact deterministic evolution (matrix exponential is reproducible across platforms, Euler is not).
- **QuantumCircuit** — `circuit.evolve(dt)` already dispatches to the QuantumComputer; the QuantumEvolver would sit between QuantumCircuit and QuantumComputer.
- **Biome Lab sweep CLI** — validate_evolution() is a ready-made sweep probe for stability budgets.
