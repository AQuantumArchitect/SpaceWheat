# Forest Ecosystem — Markov Chain Ecology

A biome where organisms transition through lifecycle states
and predator-prey relationships produce harvestable resources as byproducts.

## Lifecycle Markov Chain

Each forest patch is a qubit in one of these states:
`bare → seedling → sapling → mature → dead → bare`

Transition probabilities are Hamiltonian couplings.
Sunlight (☀) speeds growth; shade slows it; fire (🔥) resets to bare.

## Predator-Prey as Quantum Entanglement

| Pair | Relationship | Resource Produced |
|---|---|---|
| 🐺 Wolf / 🦌 Deer | Wolf hunts deer | 💧 water (via biological cycle) |
| 🦅 Eagle / 🐇 Rabbit | Eagle hunts rabbit | 🌬 wind (feather scatter) |
| 🐝 Bee / 🌿 Plant | Bee pollinates | 🌱 seedling (reproduction) |

Predator eats prey → qubit coupling between their registers → harvesting either
gives correlated outcome. Wolf population and deer population are entangled.

## Harvestable Resources

The ecosystem produces emoji-credits as byproducts of natural dynamics:
- 💧 water: Wolf/deer interaction flux
- 🌬 wind: Eagle/rabbit interaction flux
- 🍎 apple: Mature trees at peak theta
- 🥚 egg: Bird population near north pole

No artificial production rates. Ecology IS the production function.

## Why This Is Great

The player manages a quantum ecosystem, not a farm sim.
Hunting wolves to protect deer → wolf qubit decoheres → deer population
explodes → overgrazes → mature trees collapse → apple yield crashes.

Emergent ecological collapse from quantum dynamics. No scripted events needed.

## Implementation Path

A StarterForest biome variant with predator/prey qubit registers coupled
via cross-biome Hamiltonian terms. Lindblad channels encode predation rates.
`get_icon_map()` returns population distributions that map to resource yields.
