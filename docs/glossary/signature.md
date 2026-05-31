---
term: signature
short_def: A set of icons. The icon side of a faction or neighborhood.
related: [icon, faction, neighborhood, cloud]
since: 2026-05-09
status: canonical
---

A signature is a set of icons. It is NEVER a set of atoms — that is a cloud.

Factions have a signature: the icons they own and can install in biomes. Access via
`IconRegistry.get_icons_for_faction(faction.name)`.

A neighborhood's signature is the induced set of icons the governing faction installs
in that neighborhood's biome. The biome stays the dissipative scaffold; the signature
is the coherent icon side of the neighborhood.

Read a faction's actual signature (set of icons) through
`IconRegistry.get_icons_for_faction(name)`. The `Faction.cloud` field (array of atoms,
stored as `"cloud"` in `factions.json`) is a distinct concept — a cloud, not a signature.
