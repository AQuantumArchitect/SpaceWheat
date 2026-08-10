---
term: wilson
short_def: A closed fence-loop's product — the number no convention flip can touch.
related: [gauge, invariant, knot, neighborhood]
since: 2026-08-10
status: canonical
---

Take any closed circuit of fences in a neighborhood's coupling graph and
multiply the signs (or, upgraded, sum the phases) around it:
**W(C) = Π u_ij**. Flip any plot's convention and every fence at that plot
flips — but a closed loop crosses each plot an even number of times, so W(C)
survives every [gauge](gauge.md) turn ever made. It is the first number you
meet that belongs to the *loop* and to no fence or plot on it.

Count the places such numbers can live: comb a treelike patch of the ledger
flat (Operator 🧭 Q) and it erases *entirely* — a tree keeps no books. What
refuses to be combed away collects on the independent cycles, and there are
exactly **β₁ = E − V + C** of them. Topology creates the homes gauge-invariant
information lives in; a loopless world has no memory a re-zeroing can't erase.

The physics is named for Kenneth Wilson, whose loops are how lattice gauge
theory reads its fields. The fences here are the biome's real coherent
couplings (phases seeded from the sign of each authored J); the honest caveat
is that the ledger reads the graph without feeding back into its evolution.
Played as "What Turns III — The Fence Remembers"; machinery in
`Core/QuantumSubstrate/GaugeField.gd` (`wilson_phase`, `gauge_fix_tree`,
`betti_1`).
