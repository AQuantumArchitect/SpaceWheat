---
term: atom
short_def: A single emoji. The smallest named unit of matter in the simulation.
related: [cloud, icon, family, webway]
since: 2026-05-09
status: canonical
---

An atom is one emoji. It is the irreducible physical unit: a lattice site the quantum
computer can occupy, evolve, and decay.

In code, atoms appear as:
- Keys of `biome.atom_components` (the biome's dissipative physics lives on atoms).
- The `pole_0` / `pole_1` fields of an icon record.
- Entries in a cloud (a set of atoms).

Atoms do not carry coherent (Hamiltonian) dynamics on their own. Coherent dynamics
come from the *icons* that straddle them. Dissipative (Lindblad) dynamics come from
the biome's `atom_components` entries.

**Anti-pattern:** do not call an atom an "emoji" in design conversation — that
conflates the display glyph with the physics site. Inside the codebase the word
"emoji" is still used heavily in the codebase; prefer "atom" in new prose and
new code.
