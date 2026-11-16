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

**An icon is an ORDERED pair** (owner ruling, 2026-11-16). `pole_0` is the north
pole, `pole_1` the south, and **the south pole is what the word provides**:
Commerce `⚖/💰` provides 💰. The inverse orientation may be a different word with
its own name, owner and physics: Levy `💰/⚖` provides ⚖. Seven pole pairs carry
two words this way (Commerce/Levy, Unleash/Processing, Knot/Splice, Labor/Bread,
Pollination/Cultivation, Seedling/Renewal, Humus/EuPhotobloom). When the inverse
orientation is *not* a word of its own, `B/A` is the same word read the other way
round, so lookups, ledgers and old saves still find it. The one test for "same
word" is `IconRegistry.same_word()`; `IconRegistry.has_inverse_word()` says whether
a pair's inverse is a word of its own.

A register holds one qubit with two poles, so one qubit seats one orientation.
A biome's boot loadout never seats both words of a pair (they share both atoms,
and an atom is claimed once per loadout). Planting may seat the other word on a
second qubit: duplicate emojis are legal (degenerate instances), and each qubit
gets the physics of its own word.
