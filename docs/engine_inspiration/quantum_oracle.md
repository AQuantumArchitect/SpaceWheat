# Quantum Oracle (Quantum-Seeded RNG)

**Source file:** `Core/Quantum/QuantumOracle.gd` (archived — safe to delete)

## The idea
A weighted random sampler that uses live quantum state populations as its random seed instead of GDScript's `randf()`. The biome's own density matrix supplies the "random" float; classical RNG is a fallback when no quantum computer is available. Also supports ordered sampling (repeat-until-sorted, sampling without replacement) and multi-sample with or without duplicates.

## What's interesting
- **The biome's quantum state IS the RNG state.** A biome in a highly coherent state will have populations near 0.5 — maximum entropy sampling. A collapsed/measured biome will have populations near 0 or 1 — strongly biased sampling. The farm's physics directly shapes which outcomes are likely. This means the same weighted-random call produces systematically different distributions depending on how the player managed their biome's quantum state.
- **`sample_ordered()`** — measures all options in sequence, removing each after selection. This is quantum measurement with wavefunction collapse re-applied per draw, not just shuffling. The ordering reflects the current state's preferences cascading down.
- **Minimal coupling** — the oracle doesn't need a biome reference if not available; `_classical_sample` is an identical-interface fallback. The same call site works in both headed and headless contexts.
- A "quantum random" float derived from `get_population(first_emoji)` is genuinely correlated with game state, not just a disguised `randf()`. Managing your biome's quantum state is implicitly managing your luck.

## Implementation notes
- `_get_quantum_random` uses only the *first* emoji's population — a single float from a multi-dimensional state. This is a very lossy extraction: it ignores all other marginals. A richer version could fold multiple marginals into a single float (e.g., weighted average, or XOR of quantized values).
- The oracle is static; no instance needed. It reads from the passed `biome.quantum_computer` reference.
- `sample_ordered` mutates a local duplicate of `options` — safe, no side effects.
- If `total_weight <= 0`, fallback is uniform random (not weighted). Check that all options have positive weights before calling.
- The `QuantumComputer` type hint on `_quantum_sample` requires the class to be registered; in headless/test contexts this may need a duck-typed variant.

## Connections
- **BiomeBase / QuantumComputer** — `get_all_populations()` is the bridge; needs to be on the QC interface.
- **Quest generation** — randomized quest content (which resource is the target, which biome is featured) routed through the oracle would make quest variety reflect biome quantum state.
- **ParametricSelector** — scoring (ParametricSelector) + sampling (QuantumOracle) is the full pipeline: score all candidates, then sample from the scored distribution using quantum-weighted randomness.
- **IconPairing / FactionStateMatcher** — quest south-pole and faction parameter selection are current uses of classical weighted random; these are natural candidates for quantum oracle replacement.
- **Story flags** — `first_oracle_divergence` (player notices outcomes shifted after managing coherence) could be a discoverable beat.
