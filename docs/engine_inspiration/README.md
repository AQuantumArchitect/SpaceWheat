# Engine Inspiration — Archived Utility Files

Ideas harvested from QuantumSubstrate and related utility files before deletion.
These are mechanics seeds and engineering patterns — not implemented, not promised.

| File | Source | Core Idea |
|---|---|---|
| [bell_state_detector.md](bell_state_detector.md) | `Core/QuantumSubstrate/BellStateDetector.gd` | Plot spatial arrangement → entanglement class (GHZ/W/Cluster); layout IS the gate |
| [quantum_evolver.md](quantum_evolver.md) | `Core/QuantumSubstrate/QuantumEvolver.gd` | Four-method Lindblad integrator (Euler/Cayley/EXPM/RK4); Cayley is exactly unitary, RK4 for strong dissipation |
| [quantum_circuit.md](quantum_circuit.md) | `Core/QuantumSubstrate/QuantumCircuit.gd` | Chainable declarative gate builder with named mid-circuit snapshots and inline `evolve(dt)` |
| [symplectic_validator.md](symplectic_validator.md) | `Core/QuantumSubstrate/SymplecticValidator.gd` | Drop-in evolution step validator (trace, Hermiticity, positivity, purity); closure-based debug hook |
| [spark_converter.md](spark_converter.md) | `Core/QuantumSubstrate/SparkConverter.gd` | Spend coherence (off-diagonal) to boost a resource population (diagonal); irreversible trade |
| [parametric_selector.md](parametric_selector.md) | `Core/Quantum/ParametricSelector.gd` | Four similarity metrics (cosine/connection/power-law/Gaussian) over emoji-keyed vectors; select_best / select_top_k |
| [quantum_oracle.md](quantum_oracle.md) | `Core/Quantum/QuantumOracle.gd` | Weighted RNG seeded by live quantum populations; biome state IS the luck distribution |
| [player_input_macro_runner.md](player_input_macro_runner.md) | `UI/Core/PlayerInputMacroRunner.gd` | Abstract action dict → real keyboard/UI sequence; dual-backend pattern; canonical action→frame-hat mapping |

## Themes worth revisiting

**Coherence as gameplay resource** — SparkConverter and QuantumOracle both treat off-diagonal density matrix elements as something players implicitly manage. Making this legible in the HUD would unify multiple systems.

**Layout as quantum operation** — BellStateDetector shows that plot arrangement alone can classify entanglement topology. Extending this to Hamiltonian coupling modifiers (GHZ line boosts synchronized harvest; W L-shape gives resilience) would be purely emergent.

**Validation as debug overlay** — SymplecticValidator's closure hook is a zero-cost debug primitive. Worth keeping as a dev tool even if the file is deleted — copy the `create_evolution_validator` pattern.

**Declarative action tapes** — both QuantumCircuit (gate sequences) and PlayerInputMacroRunner (UI action sequences) encode "do this in order" as data. A unified instruction-tape abstraction could serve test rigs, replays, and a future in-game macro system.
