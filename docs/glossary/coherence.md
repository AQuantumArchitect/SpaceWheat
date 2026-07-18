---
term: coherence
short_def: Superposition strength — the normalized weight sitting off the diagonal of ρ.
related: [population, measurement, biome]
since: 2026-07-17
status: canonical
---

**Coherence** measures how much of a biome's state is superposition rather than a
settled mixture: `Σ_{i≠j} |ρᵢⱼ|²`, the squared magnitude of every off-diagonal density-matrix
element, normalized to `[0, 1]` (`FactionStateMatcher._calculate_coherence`,
`Core/QuantumSubstrate/FactionStateMatcher.gd`). Zero coherence means the register has
collapsed onto one basis state (or a classical mixture of them) — no shimmer, no
interference. High coherence means the qubits are spread across both poles at once.

A Hadamard (Druid hat, `E`) raises coherence by construction; a Bell/CNOT weave (Operator
hat) raises it via entanglement's own off-diagonal terms; [measurement](measurement.md)
destroys it on the qubit it touches, in closed mode down to exactly the collapsed
eigenstate.

Story predicates read it as `coherence_at_least`/`coherence_fell` — a plain
[soft gate](soft_gate.md) on this scalar, default width 0.05 unless a step overrides it
(`QuestStateProjectionService.evaluate_predicate`).
