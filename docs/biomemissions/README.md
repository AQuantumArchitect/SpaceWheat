# docs/biomemissions/ — Campaign Designer Reference

Per-biome design docs for campaign designers and physics engineers. Each file
covers axes, steady-state assay data, player missions, faction landscape, and
cross-biome flows. These are working references, not tutorials.

---

## Biome Index

| Biome | Physics character | Bistability | Campaign role | Doc |
|---|---|---|---|---|
| **FungalNetworks** | AND gate, wet/dry toggle, sun bistability | 0.100 (☀) | Tutorial: first nonlinear gate, first Lindblad injection, moisture latch | [BIOME_FUNGALNETWORKS.md](BIOME_FUNGALNETWORKS.md) |
| **Village** | Autocatalytic phase competition, commerce bistability, mill toggle | 0.186 (💰) | Tutorial: bistability, player-buildable industrial arc, hearth vs cold | [BIOME_VILLAGE.md](BIOME_VILLAGE.md) |
| **StarterForest** | Anderson localization, transport toggle, food chain | 0.114 (🌲) | Tutorial: locked vs flowing ecosystem; sun activates transport; night cycle extension | [BIOME_STARTERFOREST.md](BIOME_STARTERFOREST.md) |
| **Woodlot** | Closed production cycle, gated channel, sustainable extraction | 0.003 | Mid-game: optimize axe pump vs regrowth rate; lumber vs ash tradeoff | [BIOME_WOODLOT.md](BIOME_WOODLOT.md) |
| **PastoralCommons** | LV predation, nonlinear harvest gate, emergent commons | 0.005 (🤲) | Mid-game: wolf/sheep balance; create conditions for the commons to appear | [BIOME_PASTORALCOMMONS.md](BIOME_PASTORALCOMMONS.md) |
| **FreshwaterSpring** | Source-hub topology, watershed mapping, governance injection | 0.003 | Mid-game: follow the water to four downstream biomes; introduce Irrigation Jury | [BIOME_FRESHWATERSPRING.md](BIOME_FRESHWATERSPRING.md) |
| **BioticFlux** | No Lindblad (unitary only), persistent oscillation, first irreversibility | N/A | Tutorial/mid-game: encounter unitarity; add first L term to introduce steady state | [BIOME_BIOTICFLUX.md](BIOME_BIOTICFLUX.md) |
| **BloodLedger** | Autocatalytic authority loop, designed monoculture, empire physics | 0.002 | Late-game: starve the 📜 autocatalysis; cut Village tribute pipeline; audit coupling | [BIOME_BLOODLEDGER.md](BIOME_BLOODLEDGER.md) |

---

## Cross-Biome Design Docs

**[VILLAGE_STORY_PATHS.md](VILLAGE_STORY_PATHS.md)** — covers the full cross-biome
narrative structure: all story paths (A–Q), cross_biome_flow topology, how faction atoms
bridge biomes, and campaign pacing across the starter island and beyond.

**Archived reference: [STARTERFOREST_VILLAGE_CONNECTIONS.md](../../archive/docs/biomemissions/STARTERFOREST_VILLAGE_CONNECTIONS.md)** — historical faction-Hamiltonian bridge note kept only for reference. It describes the old starter-island coupling model and should not be treated as live architecture.

**[STARTER_ISLAND_STORY_FLAGS.md](STARTER_ISLAND_STORY_FLAGS.md)** — the live starter-island
story flags that drive the Arc tab narrative chain. Each flag is a threshold condition on
faction standings + biome state that fires once, records a permanent story log entry, and
gates the next arc beat or arc quest. Covers the live data structure, predicate types,
and the QuestManager / Arc-tab wiring.

---

## Starter Island

The starter island biomes are:

```
StarterForest, Woodlot, PastoralCommons, FreshwaterSpring, Village, BioticFlux
```

BloodLedger and FungalNetworks are accessible from the starter island but are not
part of the default starter set. To restore the starter island configuration:

```
python3 tools/set_starter_island.py
```

---

## Assay Toolkit

Location: `tools/` in the project root.

Key scripts:
- `transition_assay.py` — measures bistability score (empty vs loaded steady state)
- `gain_assay.py` — measures population inversion
- `ssh_assay.py` — measures topological chain transport (SSH model)

Re-run any assay:

```
python3 tools/transition_assay.py --biome <BiomeName>
```

Assay data in this folder reflects the state at the time of the balance pass
documented per-file. Re-run after any L-spec change to verify.

BioticFlux has no Lindblad terms and cannot be profiled by transition_assay —
the solver does not converge. This is intentional.
