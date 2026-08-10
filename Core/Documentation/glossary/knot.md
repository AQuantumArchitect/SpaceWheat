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
the other. The record's first number for this is **mutual winding** — how
many times one loop turns about the other's area axis. It is an integer,
and honesty demands the warning: integer-valued is not the same as
[invariant](invariant.md). The axis belongs to the partner loop, so smooth
moves that swing the partner's axis can change the count without cutting
anything. An invariant is not something you declare — it is something that
survives every attack the rules allow. Mutual winding is a diagnostic that
*invites* the attack.

The honest surprise: two loops on the Bloch sphere can never link — the
sphere hasn't the room. The linking lives **one floor up**, where the
qubit's full state carries the phase the sphere-shadow forgets, and the
Berry meter was always the accountant of that floor. *Ripeness was the
shadow of a knot all along.* And a second surprise: a loop closed on the
sphere is generally **not closed up there**. Its lift has loose ends,
separated by exactly the holonomy the walk earned (γ = Ω/2). A ripe loop
(Ω = 2π) comes home to the same Bloch point with its spinor's sign
reversed — home downstairs, antipodal upstairs. Walk it again (Ω = 4π) and
the loose ends finally meet; only then is "do these curves link?" a
question the mathematics accepts (`gauss_linking` refuses open lifts).

Up there, the fibers over any two distinct answers a qubit can give are
linked circles (the geometers say: Hopf). Measurement chooses an answer;
the linked circles show how much geometry the Bloch shadow hides. They are
the state space's anatomy, not the mechanism of the choice — that story
belongs to [measurement](measurement.md)'s own Born rule.

The gray breaks the walk (below coherence ε the path has no continuation),
and collapse cuts it — partial loops are forfeit; only completed circles
enter the record. Played as "What Connects" acts 5+
(`docs/CONNECT_CAMPAIGN.md`); machinery in
`Core/QuantumSubstrate/KnotRegister.gd` and the loop records of
`BerryPhaseRegister.gd`.
