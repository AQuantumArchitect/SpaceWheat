---
term: knot
short_def: Two closed Berry walks that cannot be pulled apart — winding is why.
related: [berry, invariant, bridge, measurement]
since: 2026-07-04
status: canonical
---

A **knot** is what two [berry](berry.md) loops can make. Track a qubit
around a closed walk and the record now keeps the *path*, not just its
ripeness; two banked loops can be arranged so that neither slides free of
the other. The record's number for this is **mutual winding** — how many
times one loop turns about the other's axis — and it is an
[invariant](invariant.md): an integer, so it cannot drift, only jump.

The honest surprise: two loops on the Bloch sphere can never link — the
sphere hasn't the room. The linking lives **one floor up**, where the
qubit's full state carries the phase the sphere-shadow forgets, and the
Berry meter was always the accountant of that floor. *Ripeness was the
shadow of a knot all along.* Up there, any two answers a qubit can give are
linked circles (the geometers say: Hopf) — which is the geometric reason
[measurement](measurement.md) gets one of them, never both.

The gray breaks the walk (below coherence ε the path has no continuation),
and collapse cuts it — partial loops are forfeit; only completed circles
enter the record. Played as "What Connects" acts 5+
(`docs/CONNECT_CAMPAIGN.md`); machinery in
`Core/QuantumSubstrate/KnotRegister.gd` and the loop records of
`BerryPhaseRegister.gd`.
