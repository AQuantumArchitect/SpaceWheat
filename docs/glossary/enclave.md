---
term: enclave
short_def: The closed world of v0 — a bubble of perfect coherence where only measurement leaves a scar.
related: [biome, webway, icon, cloud]
since: 2026-07-04
status: canonical
---

The **enclave** is the in-fiction name for the closed quantum system the game ships as
(`docs/CLOSED_SYSTEM.md`). It is a *place*, not a limitation: a region of the world where
every biome's density matrix evolves by pure unitary von-Neumann dynamics — `dρ/dt =
−i[H,ρ]` — with no dissipation of any kind.

The enclave's law, as the story states it at `first_breath`:

> Nothing leaks, nothing fades, nothing is forgotten. The enclave holds. Here, only
> measurement leaves a scar — and the scar is yours.

Physically, each clause is a theorem of the exact unitary kernel
(`QuantumComputer._evolve_unitary`, `ρ → UρU†` with `U = exp(−iH·dt)`):

- **"Nothing leaks"** — trace is conserved: `Tr(ρ) = 1` for all time. No population
  escapes to a sink; there is no sink.
- **"Nothing fades"** — purity is conserved: `Tr(ρ²) = 1` exactly. Every bubble stays
  pure (`r = 1`); the coherence→saturation and purity→radius visual channels never dim.
- **"Nothing is forgotten"** — unitary evolution is invertible. The world's information
  is never destroyed, only rotated.
- **"Only measurement leaves a scar"** — projective collapse
  (`QuantumComputer._project_qubit`) is the single irreversible operation in the enclave.
  Measurement IS the economy: the player is the only source of entropy production, and
  every credit earned is a scar chosen.

The Hamiltonian is the enclave's regeneration: after a collapse, rabi and coupling terms
rotate the pinned qubit back into superposition. *Time + H is the pump.*

Beyond the enclave lies the open world — the **Bath** — where dissipation runs free:
things decay, dephase, and forget on their own. The story plants that door at
`edge_of_the_enclave` (Act 5) and v0 does not open it. See
`docs/inspiration/OPEN_SYSTEM_ACT2.md` for what happens when it opens.

Verification: `tests/test_closed_system.gd` (the enclave's law, as assertions).
