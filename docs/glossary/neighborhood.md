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

**The player's neighborhood:** because the player IS a faction ("The Demos"), The
Demos' neighborhood is simply the biomes it has installed itself into — i.e. the
**currently-explored biomes**. A faction's neighborhood grows by the discrete acts of
reaching/incorporating, never by the continuous quantum evolution underneath.

**Membership is stable; only prices are chaotic.** A neighborhood is a *membership*
fact — which factions/biomes are coupled under a governing faction — and it changes
only on discrete events (discovery, incorporation, faction shift), never with the
oscillating unitary state. The market scopes to this stable cluster:
`MarketLattice.best_neighborhood_name(biome)` ranks neighborhood specs by **shared
factions** with the biome's native identity (signature-admitted factions weighted
extra), NOT by live-state tension. The *prices/opportunities* within the neighborhood
ride the raw oscillating tension — that volatility is intentional (an opportunity/timing
surface), but it must live in the deal, never in the door. (Earlier, ranking by live
tension made a biome's neighborhood flip mid-oscillation — e.g. Village
HearthKeepers→VolcanicFoundry — making needed factions unreachable. Fixed 2026-06-24.)

**What neighborhood is NOT:** it is not a graph-theoretic relation between icons.
The phrase "icon neighborhood" (previously used in this codebase) is retired - icon
graph relations are siblings and siblings-via-cloud. See `IconRelations.gd`.
