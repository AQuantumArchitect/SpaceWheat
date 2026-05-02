# Parametric Selector (Multi-Metric Vector Similarity)

**Source file:** `Core/Quantum/ParametricSelector.gd` (archived — safe to delete)

## The idea
A unified library of four similarity metrics over emoji-keyed float vectors, plus `select_best`, `select_top_k`, and `select_weighted_random` selectors. Designed explicitly as a GDScript reference implementation to be ported 1:1 to C++, with hot-path annotations and C++ port notes throughout. Current users: MusicManager (cosine at ~1Hz), BiomeAffinityCalculator (connection strength), IconPairing (power-law weight), FactionStateMatcher (Gaussian).

## What's interesting
- **Four distinct metrics for distinct semantic needs:**
  - `COSINE` — directional similarity, ignores magnitude; ideal for comparing biome "character" profiles.
  - `CONNECTION` — graph-weighted overlap; biome affinity reads the connection graph, not vector angle.
  - `LOGARITHMIC` — actually power-law `(amount+1)^0.65`; sub-linear growth is Fibonacci-friendly and prevents large stacks from dominating quest south-pole selection.
  - `GAUSSIAN` — Euclidean distance with soft falloff; faction preference matching where proximity matters more than direction.
- **Power-law weight table** in comments (amount=0→1.0, 5→3.4, 21→8.6) is ready-made for balancing quest weighting without touching code.
- `select_top_k` returns a sorted slice — can drive ranked suggestion UIs or priority queues in quest generation.
- The C++ port notes are unusually complete: SIMD hints for dot products, `std::discrete_distribution` for weighted random, partial_sort for top-k. This was written for an eventual GDNative/GDExtension move.

## Implementation notes
- All methods are static — no instance needed, no state. Safe to call from any context.
- `_connection_similarity` handles both `{emoji: {weight: float}}` and `{emoji: float}` as connection weight formats — handles schema drift gracefully.
- The `LOGARITHMIC` metric ignores `vector2` entirely (only `vector1` matters). The enum name is misleading; the actual formula is power-law, not logarithmic. Rename on reinstate.
- `select_weighted_random` returns a name string only; `select_weighted_random_full` returns the full candidate dict. Use the latter everywhere.
- MusicManager was sampling at 1Hz with ~50 biomes — 50 cosine calls on ~10-dimensional vectors per second. This is trivially fast in GDScript; the C++ port is for when biome count scales to hundreds.

## Connections
- **MusicManager** — Layer 4/5 track selection; cosine similarity between current icon map and biome track profiles.
- **BiomeAffinityCalculator** — connection-strength metric for icon → biome affinity scoring.
- **FactionContext** — Gaussian matching for faction preference alignment in quest parameter generation.
- **QuantumOracle** — complementary: QuantumOracle handles sampling, ParametricSelector handles scoring. Together they cover the full "score then sample" pipeline.
- **VOCABULARY_GATING.md inspiration** — gateway emoji detection is essentially a max-connection-strength query; ParametricSelector's CONNECTION metric is the right tool.
