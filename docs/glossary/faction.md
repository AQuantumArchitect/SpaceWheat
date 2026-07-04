---
term: faction
short_def: An authoring entity that owns an icon signature and neighborhoods.
related: [signature, icon, neighborhood, cloud, resonance]
since: 2026-05-09
status: canonical
---

A faction is the primary authoring entity for physics identity. Each faction:

- **Owns a signature** — a set of icons it can install in biomes. This is the
  faction's "name brand": its icons define the coherent dynamics it contributes.
- **Has a cloud** — the union of clouds of its signature icons; the atoms it
  physically touches.
- **Owns neighborhoods** — (biome, induced signature) clusters; the specific configurations
  it has established in the world.
- **Has alignment** — a 12-qubit density matrix in conceptual space
  (random/deterministic, material/mystical, …) that determines faction affinity and
  hat-access topology. The 12 axial bits double as *preferences over quantum
  observables*: matched against a biome's live state they yield the faction's
  [resonance](resonance.md) with that place, and they order its operator taste
  (which flavor of quantum quest it asks).
- **Has a voice** — every faction speaks in one of ten archetype voices
  (`QuestVoice`): 40 assignments are authored, the rest derive from the faction's
  identity (domain/ring/tags), so no faction defaults to flavorless text.

Factions do NOT own atoms directly. Atoms belong to biomes (as `atom_components`).
A faction's cloud is derived from its signature icons; it never directly owns atoms.

The player character is "The Demos," which is a peer faction with the same structure
as all other factions.

Code lives in `Core/Factions/Faction.gd`. JSON data in `Core/Factions/data/factions.json`.
The shared singleton registry is `FactionRegistry.get_shared()`.

**Field names:** `Faction.cloud` (the atom array, on disk as `"cloud"`) and
`IconRegistry.get_icons_for_faction(name)` (the icon signature).
