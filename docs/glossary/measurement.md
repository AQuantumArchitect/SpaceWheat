---
term: measurement
short_def: The only irreversible act in the enclave — Born sample, projective collapse, surprisal payout. Measurement IS the economy.
related: [enclave, berry, webway, atom, icon]
since: 2026-07-04
status: canonical
---

**Measurement** is the game's single point of irreversibility (closed mode) and its
single source of income. Every other operation in the enclave — gates, Hamiltonian
evolution, entangling — is unitary and can in principle be undone. Measurement cannot.
That asymmetry is the entire economy: *you are paid exactly for the scar you choose to
leave.*

The full path, in code:

1. **Born sample** — `QuantumComputer.measure_axis(north, south)` reads the qubit's
   marginals and samples the outcome with probability `p = ⟨k|ρ|k⟩`. The sample is
   **seeded deterministically** (`ProbeActions`: `hash([biome, register, elapsed_ms])`)
   so a save-load replays the same universe.
2. **Projective collapse** — `_project_qubit` applies `ρ → P_k ρ P_k / Tr(P_k ρ)`.
   Pure in, pure out: the enclave's `r = 1` survives the scar. Entangled partners
   collapse with it — measure half a Bell pair and the other half snaps.
3. **Surprisal payout** — the reward is the information content of what you learned:
   `E = −kT·log p` (`EnergyPricing.surprisal_energy`), scaled by faction affinity and
   vocabulary. Improbable outcomes pay more *because you learned more*. The player is
   Maxwell's demon on a payroll (see `docs/inspiration/DEMON_AT_THE_GATE.md`).
4. **Regeneration** — nothing refills the qubit but time: the Hamiltonian rotates the
   pinned state back into superposition over the following ticks. *Time + H is the
   pump.*

**Reap** is measurement at scale: the seasonal pass Born-samples and collapses every
register in every active biome (`ProbeActions._closed_reap_rewards`), a harvest of
scars priced by the same surprisal law.

**Honest failure** is part of the definition: if the collapse cannot actually be
applied, the action reports failure and pays nothing (`ProbeActions`, "a fabricated
'success' with an unchanged state is exactly the lie we forbid").

In the open world (Act 2), measurement gains two more faces: the Bath measures
*constantly and pays nobody* (decoherence), and repeated player measurement pins a
dying state in place (the quantum Zeno effect) — looking as shelter, not spending. See
`docs/inspiration/OPEN_SYSTEM_ACT2.md`.

Verification: `tests/test_gate_exact_states.gd` (Born diagonals),
`tests/test_closed_system.gd` (collapse keeps r = 1), `tests/test_drain_qubit.gd`
(the weak-measurement variant).
