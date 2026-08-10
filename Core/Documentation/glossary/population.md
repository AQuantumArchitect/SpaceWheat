---
term: population
short_def: An emoji's marginal probability — how much of that state a register holds.
related: [icon, measurement, coherence]
since: 2026-07-17
status: canonical
---

**Population** is the diagonal readout of a register's density matrix: for an emoji
`e` bound to qubit pole `k`, population is the marginal `⟨k|ρ|k⟩` — a number in
`[0, 1]` (duplicate pole labels sum their instances; see `QuantumComputer.get_population`,
`Core/QuantumSubstrate/QuantumComputer.gd`).

Population answers "how much of this stuff is here right now," continuously — not a
count of discrete items. It rises under the Hamiltonian's rotation (H drives probability
between an icon's two poles) and snaps to `0` or `1` the instant that register is
measured (see [measurement](measurement.md)).

Quest predicates read it directly: `biome_state_gte`/`biome_state_lte` gate on a named
atom's population in a named biome (`QuestManager._check_flag_predicate`), and
`SHAPE_ACHIEVE` "amplitude" quests ask a faction's cloud-atom to clear a population
target (`population:<emoji>` in `get_biome_observables`).
