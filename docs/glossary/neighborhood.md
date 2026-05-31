---
term: neighborhood
short_def: A configured (biome, induced signature) cluster. Factions own neighborhoods.
related: [faction, biome, signature, icon, cloud]
since: 2026-05-09
status: canonical
---

A neighborhood is a configured cluster: one biome paired with a specific induced
signature (set of icons) that a faction installs there. It is the unit of faction
presence in the world.

A neighborhood has three layers:
1. **Biome** - the full dissipative scaffold (cloud of atoms, Lindblad physics,
   visual config, plot layout).
2. **Induced signature** - the icons the governing faction installs; this is the H
   side of the neighborhood.
3. **Edges** - the hat-access topology: which archetype frames (hats) are active in
   this neighborhood given the faction's alignment vs. the biome's dissipative character.

Neighborhoods are *fluid and transient*: they are computed on demand from the current
faction × biome pairing and the `IconLoadoutInducer` selection rule. They are not
persisted to disk (future work: persist authored neighborhoods in `factions.json`).

`AuthorityAdapter.compose_neighborhood(faction, biomes, parent_node)` returns the full
list of a faction's computed neighborhoods as a decorated dictionary.

**What neighborhood is NOT:** it is not a graph-theoretic relation between icons.
The phrase "icon neighborhood" (previously used in this codebase) is retired - icon
graph relations are siblings and siblings-via-cloud. See `IconRelations.gd`.
