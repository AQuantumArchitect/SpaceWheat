class_name ParametricSelector
extends RefCounted

## Parametric Selection System (GDScript Fallback)
##
## This is a REFERENCE IMPLEMENTATION designed to be replaced by a C++ module.
## When porting to C++:
##   - All static methods map 1:1 to C++ static functions
##   - Hot paths marked with [PERF] comments
##   - Algorithm formulas documented for reference
##   - No GDScript-specific patterns used
##
## Systems using this:
##   - MusicManager (Layer 4/5): Cosine similarity, ~1Hz sampling
##   - BiomeAffinityCalculator: Connection strength, on-demand
##   - VocabularyPairing: Logarithmic weight, quest generation
##   - FactionStateMatcher: Gaussian distance, quest parameters

# ============================================================================
# METRIC ENUM (maps to C++ enum class Metric)
# ============================================================================

enum Metric {
	COSINE = 0,       # cos²(v1, v2) - Music Layer 4
	CONNECTION = 1,   # Σ(weight)/count - Biome Affinity
	LOGARITHMIC = 2,  # 1+log(1+x)/3 - Quest South Pole
	GAUSSIAN = 3      # exp(-d²/2σ²) - Faction Matching
}

# ============================================================================
# SIMILARITY METRICS
# ============================================================================

## Compute similarity between two emoji vectors
## [PERF] Hot path: MusicManager samples at 1Hz, processes ~50 biomes
##
## Args:
##   vector1: Dictionary {emoji: float} - current state
##   vector2: Dictionary {emoji: float} - candidate
##   metric: Metric - similarity function to use
##   params: Dictionary - metric-specific parameters (e.g., {"sigma": 0.3})
##
## Returns: float in [0, 1] (higher = more similar)
##
## C++ Port Notes:
##   - Dictionary → std::unordered_map<String, float>
##   - Consider SIMD for dot products if vectors are large
##   - Cache normalized vectors in MusicManager
static func compute_similarity(
	vector1: Dictionary,
	vector2: Dictionary,
	metric: Metric,
	params: Dictionary = {}
) -> float:
	match metric:
		Metric.COSINE:
			return _cosine_similarity(vector1, vector2)
		Metric.CONNECTION:
			# CONNECTION metric requires connection_weights in params
			var connection_weights = params.get("connection_weights", {})
			return _connection_similarity(vector1, vector2, connection_weights)
		Metric.LOGARITHMIC:
			# LOGARITHMIC only uses vector1 (resource amounts)
			return _logarithmic_total_weight(vector1)
		Metric.GAUSSIAN:
			var sigma = float(params.get("sigma", 0.3))
			return _gaussian_similarity(vector1, vector2, sigma)

	push_error("ParametricSelector: Unknown metric %d" % metric)
	return 0.0


# ============================================================================
# INTERNAL: COSINE SIMILARITY
# ============================================================================

## Cosine similarity: cos²(v1, v2)
##
## Formula: (v1 · v2)² / (||v1||² * ||v2||²)
##
## Used by: MusicManager Layer 4 (IconMap → biome track matching)
##
## [PERF] Hot path - called ~50 times per second when Layer 4 active
##
## C++ Port Notes:
##   - Use SSE/AVX for dot product if >16 dimensions
##   - Pre-normalize vectors in caller (MusicManager caches normalized biome vectors)
##   - Consider single-precision float for 2x SIMD throughput
static func _cosine_similarity(vector1: Dictionary, vector2: Dictionary) -> float:
	if vector1.is_empty() or vector2.is_empty():
		return 0.0

	# Compute ||v1||
	var norm1_sq := 0.0
	for emoji in vector1.keys():
		var val := float(vector1[emoji])
		norm1_sq += val * val

	if norm1_sq < 1e-9:  # Epsilon for float comparison
		return 0.0

	# Compute ||v2||
	var norm2_sq := 0.0
	for emoji in vector2.keys():
		var val := float(vector2[emoji])
		norm2_sq += val * val

	if norm2_sq < 1e-9:
		return 0.0

	# Compute v1 · v2
	var dot := 0.0
	for emoji in vector1.keys():
		if vector2.has(emoji):
			dot += float(vector1[emoji]) * float(vector2[emoji])

	# cos²(v1, v2) = (dot / (||v1|| * ||v2||))²
	var cos_theta := dot / (sqrt(norm1_sq) * sqrt(norm2_sq))
	return cos_theta * cos_theta


# ============================================================================
# INTERNAL: CONNECTION STRENGTH
# ============================================================================

## Connection strength: Σ(connection_weight) / count
##
## Used by: BiomeAffinityCalculator (vocab pair → biome affinity)
##
## [PERF] Medium priority - only called on-demand (vocab injection menu, quest generation)
##
## C++ Port Notes:
##   - connection_weights is nested Dictionary {emoji: {emoji: {weight: float}}}
##   - Could be std::unordered_map<String, std::unordered_map<String, float>>
##   - No hot path, readability > performance
static func _connection_similarity(
	vector1: Dictionary,
	vector2: Dictionary,
	connection_weights: Dictionary
) -> float:
	if vector1.is_empty() or vector2.is_empty():
		return 0.0

	var total_weight := 0.0
	var connection_count := 0

	for emoji1 in vector1.keys():
		var connections = connection_weights.get(emoji1, {})
		if connections.is_empty():
			continue

		for emoji2 in vector2.keys():
			if connections.has(emoji2):
				var conn_data = connections[emoji2]
				var weight := 0.0

				# Handle both Dictionary and direct float
				if conn_data is Dictionary:
					weight = float(conn_data.get("weight", 0.0))
				else:
					weight = float(conn_data)

				total_weight += weight
				connection_count += 1

	return total_weight / float(connection_count) if connection_count > 0 else 0.0


# ============================================================================
# INTERNAL: LOGARITHMIC WEIGHT
# ============================================================================

## Logarithmic weight: 1.0 + log(1.0 + amount) / 3.0
##
## Formula designed to avoid overwhelming probabilities from large resource amounts:
##   amount=0   → weight=1.0  (base)
##   amount=50  → weight≈2.31 (131% boost)
##   amount=500 → weight≈3.07 (207% boost)
##
## Used by: VocabularyPairing (quest south pole selection)
##
## [PERF] Low priority - only called during quest generation (~1-10 calls per quest)
##
## C++ Port Notes:
##   - Use std::log() from <cmath>
##   - No optimization needed, not a hot path
static func _logarithmic_total_weight(vector: Dictionary) -> float:
	var total_weight := 0.0

	for emoji in vector.keys():
		var amount := float(vector[emoji])
		if amount > 0.0:
			# w = 1.0 + log(1.0 + amount) / 3.0
			total_weight += 1.0 + log(1.0 + amount) / 3.0

	return total_weight


## Single value logarithmic weight (convenience function)
##
## Args:
##   amount: float - resource amount (>= 0)
##
## Returns: float - weight in [1.0, ~3.0] for reasonable amounts
static func logarithmic_weight(amount: float) -> float:
	if amount <= 0.0:
		return 1.0
	return 1.0 + log(1.0 + amount) / 3.0


# ============================================================================
# INTERNAL: GAUSSIAN SIMILARITY
# ============================================================================

## Gaussian similarity: exp(-d² / 2σ²)
##
## Formula: exp(-||v1 - v2||² / (2 * sigma²))
##   where d = Euclidean distance between vectors
##
## Used by: FactionStateMatcher (faction preference → biome state alignment)
##
## [PERF] Medium priority - called during quest generation (~10-20 times per quest)
##
## C++ Port Notes:
##   - Use std::exp() from <cmath>
##   - sigma typically in [0.2, 0.5] range
##   - Consider fast exp approximation if profiling shows bottleneck
static func _gaussian_similarity(
	vector1: Dictionary,
	vector2: Dictionary,
	sigma: float
) -> float:
	if vector1.is_empty() or vector2.is_empty():
		return 0.0

	# Collect all keys from both vectors
	var all_keys := {}
	for key in vector1.keys():
		all_keys[key] = true
	for key in vector2.keys():
		all_keys[key] = true

	# Compute squared Euclidean distance
	var dist_sq := 0.0
	for key in all_keys.keys():
		var v1 := float(vector1.get(key, 0.0))
		var v2 := float(vector2.get(key, 0.0))
		var diff := v1 - v2
		dist_sq += diff * diff

	# Gaussian kernel: exp(-d² / 2σ²)
	return exp(-dist_sq / (2.0 * sigma * sigma))


## Gaussian match (1D) - for individual preference dimensions
##
## Used by: FactionStateMatcher._gaussian_match()
##
## Formula: exp(-(preference - actual)² / (2 * sigma²))
##
## Args:
##   preference: float - desired value in [0, 1]
##   actual: float - observed value in [0, 1]
##   sigma: float - standard deviation (default 0.4)
##
## Returns: float in [0, 1] (1.0 = perfect match, decays with distance)
static func gaussian_match_1d(
	preference: float,
	actual: float,
	sigma: float = 0.4
) -> float:
	var diff := preference - actual
	return exp(-(diff * diff) / (2.0 * sigma * sigma))


# ============================================================================
# SELECTION METHODS
# ============================================================================

## Select best candidate by similarity score
##
## [PERF] Hot path if many candidates - consider top-k heap in C++
##
## Args:
##   vector: Dictionary - current state
##   candidates: Array[Dictionary] - [{name: String, vector: Dictionary, ...}, ...]
##   metric: Metric - similarity function
##   params: Dictionary - metric parameters (e.g., connection_weights, sigma)
##
## Returns: Dictionary - best candidate with added "similarity" field
##
## C++ Port Notes:
##   - If candidates.size() > 100, use max-heap instead of sorting
##   - Consider parallel evaluation if candidates.size() > 1000
static func select_best(
	vector: Dictionary,
	candidates: Array,
	metric: Metric,
	params: Dictionary = {}
) -> Dictionary:
	if candidates.is_empty():
		return {}

	var best_candidate = null
	var best_similarity := -INF

	for candidate in candidates:
		var candidate_vector = candidate.get("vector", {})
		var similarity := compute_similarity(vector, candidate_vector, metric, params)

		if similarity > best_similarity:
			best_similarity = similarity
			best_candidate = candidate.duplicate()

	if best_candidate:
		best_candidate["similarity"] = best_similarity
		return best_candidate

	return {}


## Select top K candidates by similarity score
##
## Args:
##   vector: Dictionary
##   candidates: Array[Dictionary]
##   metric: Metric
##   k: int - number of results (0 = all, sorted)
##   params: Dictionary
##
## Returns: Array[Dictionary] - sorted by similarity (descending)
##
## C++ Port Notes:
##   - Use partial_sort if k << candidates.size()
##   - std::priority_queue for top-k heap
static func select_top_k(
	vector: Dictionary,
	candidates: Array,
	metric: Metric,
	k: int = 0,
	params: Dictionary = {}
) -> Array:
	if candidates.is_empty():
		return []

	var results := []

	# Compute similarity for all candidates
	for candidate in candidates:
		var candidate_vector = candidate.get("vector", {})
		var similarity := compute_similarity(vector, candidate_vector, metric, params)

		var result = candidate.duplicate()
		result["similarity"] = similarity
		results.append(result)

	# Sort by similarity (descending)
	results.sort_custom(func(a, b): return a["similarity"] > b["similarity"])

	# Return top K
	if k > 0 and k < results.size():
		return results.slice(0, k)

	return results


## Weighted random selection
##
## [PERF] Low priority - only used for quest generation (~once per quest)
##
## Args:
##   candidates: Array[Dictionary] - [{name: String, weight: float, ...}, ...]
##
## Returns: String - selected candidate name (or "" if failed)
##
## C++ Port Notes:
##   - Use std::discrete_distribution<> for weighted sampling
##   - Simple linear search is fine (typically <100 candidates)
static func select_weighted_random(candidates: Array) -> String:
	if candidates.is_empty():
		return ""

	# Compute total weight
	var total_weight := 0.0
	for candidate in candidates:
		total_weight += float(candidate.get("weight", 0.0))

	if total_weight < 1e-9:
		return ""

	# Weighted roll
	var roll := randf() * total_weight
	var cumulative := 0.0

	for candidate in candidates:
		cumulative += float(candidate.get("weight", 0.0))
		if roll <= cumulative:
			return candidate.get("name", "")

	# Fallback (shouldn't happen due to float precision)
	return candidates[-1].get("name", "")


## Weighted random selection (full result)
##
## Args:
##   candidates: Array[Dictionary]
##
## Returns: Dictionary - selected candidate (all fields)
static func select_weighted_random_full(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}

	var total_weight := 0.0
	for candidate in candidates:
		total_weight += float(candidate.get("weight", 0.0))

	if total_weight < 1e-9:
		return {}

	var roll := randf() * total_weight
	var cumulative := 0.0

	for candidate in candidates:
		cumulative += float(candidate.get("weight", 0.0))
		if roll <= cumulative:
			return candidate.duplicate()

	return candidates[-1].duplicate()


# ============================================================================
# HELPER FUNCTIONS (for testing and debugging)
# ============================================================================

## Normalize vector to unit length (L2 norm)
##
## C++ Port Notes:
##   - Consider in-place normalization to avoid allocations
static func normalize(vector: Dictionary) -> Dictionary:
	if vector.is_empty():
		return {}

	# Compute L2 norm
	var norm_sq := 0.0
	for emoji in vector.keys():
		var val := float(vector[emoji])
		norm_sq += val * val

	var norm := sqrt(norm_sq)
	if norm < 1e-9:
		return {}

	# Normalize
	var normalized := {}
	for emoji in vector.keys():
		normalized[emoji] = float(vector[emoji]) / norm

	return normalized


## Compute L2 magnitude of vector
static func magnitude(vector: Dictionary) -> float:
	if vector.is_empty():
		return 0.0

	var sum_sq := 0.0
	for emoji in vector.keys():
		var val := float(vector[emoji])
		sum_sq += val * val

	return sqrt(sum_sq)


## Compute dot product of two vectors
static func dot_product(vector1: Dictionary, vector2: Dictionary) -> float:
	if vector1.is_empty() or vector2.is_empty():
		return 0.0

	var dot := 0.0
	for emoji in vector1.keys():
		if vector2.has(emoji):
			dot += float(vector1[emoji]) * float(vector2[emoji])

	return dot
