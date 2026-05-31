# The Tomato Conspiracy

A quest arc about learning topology through gardening — then the tomatoes show up.

## The Concept

Tomatoes form a self-organized clique. They start as normal crops.
But at some threshold of cultivation, they develop an internal biome:
a small quantum system that runs INSIDE the tomato faction's collective density matrix.

Then they start adjusting the Hamiltonians of other players' icons.

Slowly. Quietly. The coupling strengths shift. Self-energies drift.
The tomato clique is absorbing all the energy in the system.

## Why This Is Great

It's the most literal possible expression of the game's core physics.
A faction that *grows out of the player's garden* and then uses quantum
mechanics to colonize it. The player taught them how. The player built
the substrate. The tomatoes are just following the math.

This rewards players who understand the system (they can fight back by
reading the Hamiltonian shifts) while surprising players who don't
(their farm slowly gets weird and they don't know why).

## Narrative Arc

1. **Tutorial Phase:** Player cultivates tomatoes alongside wheat. Learns topology.
2. **Threshold Event:** Tomato population reaches critical density. A story flag fires:
   *"Something changed in the garden. The tomatoes are very coordinated."*
3. **Slow Takeover:** Cross-biome Hamiltonian injection begins. Player notices
   yields changing on non-tomato plots. Coupling constants shift in B-surface.
4. **Confrontation:** Three paths to resolution:
   - **Harvest hard:** Decohere the tomato clique before critical mass (Ace frame)
   - **Negotiate:** Offer them their own biome slot; they stop colonizing yours (Merchant frame)
   - **Let them win:** See what the fully tomato-dominated Hamiltonian produces (emergent)
5. **Denouement:** Whatever path — the player now understands entanglement,
   Hamiltonian injection, and cross-biome coupling. The tomatoes taught them.

## Attractor Quest Version

This story also works as an attractor quest:

- **Steer to attractor**: keep the tomato clique in a chosen basin until the garden stabilizes around it.
- **Heal attractor**: deliberately knock the clique off-balance, then restore the same stable basin before the crop line collapses.

That is implementable today with the game’s current runtime signals. The system already exposes per-biome state, attractor summaries, and player actions that change the Hamiltonian. The quest logic only needs to watch whether the live basin matches the target and whether it stays there for long enough.

## Implementation Path (Future)

The Tomato Conspiracy works with current architecture:
- A `TomatoClique` faction neighborhood with `gated_lindblad` couplings pointing INTO other biomes
- Negative self-energies on non-tomato icons (slow drain)
- Activated by a story flag when tomato occupation > THRESHOLD in a biome
- The clique's neighborhood runs its own Hamiltonian, injecting cross-biome terms via
  the existing cross-coupling mechanism in BiomeBase
