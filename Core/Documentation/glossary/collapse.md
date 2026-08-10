---
term: collapse
short_def: The projective step of measurement — ρ snaps to one eigenstate.
related: [measurement, population]
since: 2026-07-17
status: canonical
---

**Collapse** is the second of measurement's three steps (see [measurement](measurement.md)
for the full path: Born sample → collapse → surprisal payout). After the Born sample
picks outcome `k`, `_project_qubit` applies `ρ → Pₖ ρ Pₖ / Tr(Pₖ ρ)` — a projective
measurement. In the closed enclave this is pure-in, pure-out (`r = 1` survives), and any
entangled partner collapses with it: measure half a Bell pair and the other half snaps
too, instantly, however far apart the registers are.

Collapse is the game's one deliberately **irreversible** act — every other operation
(gates, Hamiltonian evolution, entangling) is unitary and could in principle be undone.
That asymmetry is what makes [harvest](harvest.md) pay: you are rewarded exactly for the
scar you chose to leave.

Nothing refills a collapsed register but time: the biome's own Hamiltonian rotates the
pinned state back into superposition over the following ticks — "time + H is the pump."
In the open world (Act 2+), repeated collapse of a decaying state instead *pins* it in
place (the quantum Zeno effect) — looking as shelter, not spending; see
`docs/inspiration/OPEN_SYSTEM_ACT2.md`.
