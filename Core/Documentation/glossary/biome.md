---
term: biome
short_def: A full dissipative scaffold - cloud of atoms + Lindblad physics + its own look.
related: [atom, cloud, signature, neighborhood, faction, webway, enclave]
since: 2026-05-09
status: canonical
---

A biome is the full dissipative substrate of a location in the world. It provides:

- **Cloud** - its set of atoms (`atom_components` keys), the lattice sites the quantum
  computer can occupy.
- **Lindblad operators** - the dissipative (non-unitary) physics per atom. Two layers:
  the **sink-decay** layer (`decay`/edges to `🗑`, which lowers entropy) and the
  **[webway](webway.md)** layer (non-sink inter-atom edges that recirculate population
  and hold entropy up). Plus optional pumps (`lindblad_incoming` from `🗑`). This is
  the biome's "L authority." **In v0 this entire layer is authored data with no
  runtime physics** — the [enclave](enclave.md) seals it (`LindbladBuilder` builds
  zero operators in closed mode); the channels are drawn dark in the graph views.
- **Visual config** - color, label, plot layout.

A biome does NOT carry coherent (Hamiltonian) dynamics of its own, and **a biome does
not know about icons** — it is a cloud of atoms. Pole-pairing (north/south) is a
neighborhood/icon concern, never a biome property; an odd atom count is legal.
Hamiltonians come from the icons a faction installs in the neighborhood signature. A biome paired with
an induced signature is a neighborhood; the runtime can then materialize that neighborhood
as a `DynamicBiome` with a live `QuantumComputer`.

A biome paired with an induced signature forms a **neighborhood** - the configured
cluster the faction governs at that location.

Biomes are crafted artifacts (not random reveals). Their data lives in
`Core/Biomes/data/biomes.json` and is indexed by `BiomeRegistry`.
