---
term: icon
short_def: A named two-atom physics record. Provides H to a neighborhood.
related: [atom, cloud, signature, sibling, family, berry]
since: 2026-05-09
status: canonical
---

An icon is a named record with two poles (`pole_0`, `pole_1`) and an associated
Hamiltonian physics block:

```
{ name, pole_0, pole_1, self_energy_0, self_energy_1,
  rabi_coupling, hamiltonian_couplings, energy_couplings, driver, ... }
```

Icons are the source of coherent dynamics. When a biome is paired with an induced
signature, those icons' physics is compiled into the Hamiltonian `H` for that
neighborhood's quantum computer. The biome's `atom_components` supply the Lindblad
operators `L` (dissipation); icons supply `H` (unitary rotation / coupling).

Icons are owned by factions. A faction's *signature* is its set of owned icons.
Icon records live in `icons.json` and are indexed by `IconRegistry`.

Two icons that share a pole atom are *siblings*. All icons that contain a given atom
are that atom's *family*.
