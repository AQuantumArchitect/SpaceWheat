---
term: berry
short_def: Geometric phase farmed as ripeness — the signed solid angle a qubit's Bloch vector encloses.
related: [enclave, icon, atom]
since: 2026-07-04
status: canonical
---

A **berry** is the game's name for accumulated **Berry phase** — the geometric phase
(Michael Berry, 1984) a quantum state picks up from the *path* it travels, not the time
it takes. For a qubit, this is the signed solid angle its Bloch vector encloses on the
sphere. Steer a qubit around a loop and it comes back changed by exactly the area it
enclosed — memory written in geometry. Yes, the pun is intentional: you farm berries; the
berries are Berry phases. Ripeness is curvature.

The sim-side truth lives in `Core/QuantumSubstrate/BerryPhaseRegister.gd`, on each
biome's `QuantumComputer` (headless-visible; the viz cache only mirrors it):

- **Integration** — per evolution slice, the signed solid angle of the spherical
  triangle (ẑ, previous b̂, current b̂), L'Huilier's formula. Closed loops sum to the
  enclosed solid angle exactly.
- **Ripeness** — a tracked qubit is *ripe* at 2π of accumulated solid angle: one full
  hemisphere enclosed (`BERRY_DEFAULT_RIPE_THRESHOLD = TAU`).
- **Decoherence freezes it** — if the Bloch vector's length drops below
  `BERRY_EPSILON`, integration stops: a mixed state has no well-defined path. (In the
  enclave this never triggers — r = 1 always. In the open world, the Bath will be able
  to *rot the berries*.)
- **Neglect decays it** — an untracked qubit's residual phase fades with a ~47 s
  half-life until the entry is dropped. Ripeness must be tended.

The story reads the same register: `first_breath` fires on your first incorporated loop
("signed solid angle in tow"), and `forest_communion` gates on 4π — two full
hemispheres of deliberate steering (`berry_total_phase_gte: 12.566`). The predicates
`berry_consumed_count_gte` / `berry_total_phase_gte` count what harvesting consumes.

Why it's the enclave's perfect crop: dynamical phase can be rushed by cranking energy,
but geometric phase can only be *traveled* — there is no shortcut around the sphere. It
rewards the player the enclave wants to teach: one who steers, closes loops, and comes
back on purpose.
