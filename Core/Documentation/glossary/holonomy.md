---
term: holonomy
short_def: What a closed walk carries home that the sphere can't show — the lift's turn.
related: [berry, knot, gauge, measurement]
since: 2026-08-10
status: canonical
---

A tracked qubit walks a closed loop and comes home — on the Bloch sphere.
**Holonomy** is what came home *changed*: one floor up, where the full state
carries the phase the sphere-shadow forgets, the walk turned the hidden dial
by exactly **γ = Ω/2** — half the solid angle it enclosed. A ripe loop
(Ω = 2π) turns the dial to π: the state came back as **minus itself**. Same
point on the sphere, opposite lift. Walk the loop *again* (Ω = 4π) and the
dial completes its turn — only then has the walk truly closed upstairs.

No reading taken at the plot alone can see the sign; hold a second qubit home
and read the pair in the Icon 🪞 mirror, and what is invisible alone is plain
in company. The record keeps the whole ledger per banked loop — holonomy,
closure defect, spinor flip — and `gauss_linking` refuses to answer "do these
curves link?" until the lifts genuinely close: a curve with loose ends is not
a knot question yet.

This is the same idea [gauge](gauge.md) plays on the fences — transport
something around a loop and compare it with what stayed put; the mismatch is
the loop's own property, owned by no point on it. Played as "What Turns" I
and V; machinery in `Core/QuantumSubstrate/KnotRegister.gd` (`lift_holonomy`,
`lift_closure_defect`, `closed_lift_curves`) and the frozen-record fields of
`BerryPhaseRegister.gd`.
