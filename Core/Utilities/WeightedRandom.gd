class_name WeightedRandom
extends RefCounted

## WeightedRandom - Utility for probability-weighted random selection
##
## Implements weighted sampling from a categorical distribution.
## Used by ProbeActions for EXPLORE register selection.
##
## Example:
##   var items = ["🌾", "🍄", "🍅"]
##   var weights = [0.6, 0.3, 0.1]  # 60%, 30%, 10%
##   var selected = WeightedRandom.weighted_choice(items, weights)


## Select index from weighted distribution
##
## Args:
##   weights: Array of non-negative weights (need not sum to 1)
##
## Returns:
##   Selected index (0 to weights.size()-1), or -1 if all weights zero
static func weighted_choice_index(weights: Array) -> int:
	if weights.is_empty():
		return -1

	# Calculate total weight
	var total: float = 0.0
	for w in weights:
		if w < 0:
			push_warning("WeightedRandom: negative weight ignored")
			continue
		total += float(w)

	if total <= 0.0:
		return -1

	# Sample from [0, total)
	var sample = randf() * total

	# Find selected index
	var cumulative: float = 0.0
	for i in range(weights.size()):
		var w = float(weights[i])
		if w < 0:
			continue
		cumulative += w
		if sample < cumulative:
			return i

	# Edge case: return last valid index
	return weights.size() - 1


## Select item from weighted distribution
##
## Args:
##   items: Array of items to select from
##   weights: Array of weights (same length as items)
##
## Returns:
##   Selected item, or null if selection failed
static func weighted_choice(items: Array, weights: Array) -> Variant:
	if items.size() != weights.size():
		push_error("WeightedRandom: items and weights must have same length")
		return null

	var index = weighted_choice_index(weights)
	if index < 0:
		return null

	return items[index]


## Select multiple items without replacement (weighted)
##
## Args:
##   items: Array of items to select from
##   weights: Array of weights
##   count: Number of items to select
##
## Returns:
##   Array of selected items
static func weighted_sample(items: Array, weights: Array, count: int) -> Array:
	if items.size() != weights.size():
		push_error("WeightedRandom: items and weights must have same length")
		return []

	count = mini(count, items.size())
	var result: Array = []
	var remaining_items = items.duplicate()
	var remaining_weights = weights.duplicate()

	for _i in range(count):
		var index = weighted_choice_index(remaining_weights)
		if index < 0:
			break

		result.append(remaining_items[index])
		remaining_items.remove_at(index)
		remaining_weights.remove_at(index)

	return result


## Normalize weights to sum to 1.0
##
## Args:
##   weights: Array of weights
##
## Returns:
##   Array of normalized weights (probabilities)
static func normalize(weights: Array) -> Array[float]:
	var total: float = 0.0
	for w in weights:
		total += maxf(0.0, float(w))

	if total <= 0.0:
		# Return uniform distribution
		var uniform: Array[float] = []
		var p = 1.0 / weights.size() if weights.size() > 0 else 0.0
		for _i in range(weights.size()):
			uniform.append(p)
		return uniform

	var normalized: Array[float] = []
	for w in weights:
		normalized.append(maxf(0.0, float(w)) / total)
	return normalized


## Calculate entropy of a probability distribution
##
## Args:
##   probabilities: Array of probabilities (should sum to 1)
##
## Returns:
##   Shannon entropy in bits
static func entropy(probabilities: Array) -> float:
	var h: float = 0.0
	for p in probabilities:
		var prob = float(p)
		if prob > 0.0:
			h -= prob * log(prob) / log(2.0)
	return h


## Sample from uniform distribution over indices
##
## Args:
##   count: Number of items
##
## Returns:
##   Random index from 0 to count-1
static func uniform_choice(count: int) -> int:
	if count <= 0:
		return -1
	return randi() % count


## Shuffle array in place using Fisher-Yates
##
## Args:
##   arr: Array to shuffle (modified in place)
static func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
