---
term: cloud
short_def: A set of atoms. Everything that "touches" a thing.
related: [atom, icon, signature]
since: 2026-05-09
status: canonical
---

A cloud is a set of atoms (emojis). Things have clouds:

- **Biome cloud** — the atoms in `biome.atom_components`. This is the biome's
  physical substrate. The non-sink Lindblad edges over this cloud form its
  [webway](webway.md) (ecological recirculation); edges to `🗑` are sink-decay.
- **Icon cloud** — `pole_0` ∪ `pole_1` ∪ keys of `hamiltonian_couplings` ∪
  keys of `energy_couplings`. The full reach of an icon's physics.
- **Faction cloud** — the union of icon clouds over all icons in the faction's
  signature. "Everything the faction's physics touches."

Clouds are computed in `Core/Factions/IconRelations.gd` (`cloud_of`, `union_of_clouds`).
The cloud is a `Dictionary[atom → true]` for O(1) membership checks.

**Anti-pattern:** do not call `Faction.signature` (the atom-array field on
disk) a cloud — that field is a misnomer. In code, read the faction's cloud as
`IconRelations.union_of_clouds(IconRegistry.get_icons_for_faction(name))`.
