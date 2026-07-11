# Emoji Topology Language — Relationship Graph

> **Status: Core graph API is implemented.** `DualEmojiQubit.gd` has `add_graph_edge()`,
> `get_graph_targets()`, `has_graph_edge()`, `get_all_relationships()`, and the
> `entanglement_graph` dictionary. The full original spec is archived at
> `archive/docs/architecture/EMOJI_TOPOLOGY_LANGUAGE.md` (it predates the
> icon/signature/cloud vocabulary). This doc captures the higher-level
> design vision and the knot-theory future path.

Every entity in the game can carry a pure-emoji relationship graph.
No string labels. No hardcoded relationship types. Just emojis as relationship keys.

## The Idea

```gdscript
# Instead of:
{"hunts": ["rabbit"], "flees_from": ["wolf"]}

# Use:
{"🍴": ["🐇"], "🏃": ["🐺"]}
```

Every relationship type is an emoji. The emoji IS the relationship type.
Universal, readable, reversible (unitary), queryable.

## Relationship Vocabulary

| Emoji | Relationship |
|---|---|
| 🍴 | Predation (hunts) |
| 🏃 | Escape (flees from) |
| 🌱 | Consumption (feeds on) |
| 💧 | Production (creates) |
| 👶 | Reproduction (offspring) |
| 🔄 | Transformation (becomes) |
| ⚡ | Coherence (theta-synchronizes with) |

Extendable: add new relationship types by adding new emojis to the vocabulary.
No code changes required.

## Graph Queries

```gdscript
organism.qubit.get_graph_targets("🍴")      # What do I hunt?
organism.qubit.has_graph_edge("🍴", "🐰")  # Do I hunt rabbits?
organism.qubit.get_graph_neighbors("💧")    # What do I produce?
```

## Topological Analysis

The graph structure enables:
- **Linking numbers:** Two faction loops — are they linked or unlinked?
- **Knot invariants:** Is this ecology knotted? What's the simplest form?
- **Reidemeister moves as optimization:** Unknot the faction graph → maximize throughput
- **Braid groups:** Order-dependent operations on entangled entity sets

## Why This Matters

The faction affinity system and biome coupling system are already graphs.
If both use the same emoji-key format, they become one unified topology.
Cross-biome couplings, faction relationships, and player vocabulary
all live in the same mathematical space — analyzable with the same tools.
