extends RefCounted

## EmojiSequenceGenerator — Markov walk over an emoji vocabulary.
##
## Inputs: a StoryEngine.compose_socialite_voice() output (a dict with
## `initial` distribution and `transitions` matrix).
## Output: Array[String] of K emojis sampled by Markov walk.
##
## The walk:
##   1. Sample emoji_0 weighted by `initial`
##   2. For each next step, sample from `transitions[emoji_i]` if it exists,
##      else fall back to `initial` (re-seed) — keeps utterance from getting stuck
##   3. Avoid immediate repeats (one-step memory) so 🌳🌳🌳 doesn't dominate
##   4. Stop at length K

const DEFAULT_LEN: int = 4


## Generate an emoji sequence of length `length`.
## Returns Array[String]; may be empty if vocabulary is empty.
static func generate(conv_h: Dictionary, length: int = DEFAULT_LEN) -> Array:
	var initial: Dictionary = conv_h.get("initial", {})
	var transitions: Dictionary = conv_h.get("transitions", {})
	if initial.is_empty():
		return []
	var sequence: Array = []
	var current: String = _weighted_pick(initial, "")
	if current == "":
		return []
	sequence.append(current)
	for _i in range(max(0, length - 1)):
		var row: Dictionary = transitions.get(current, {})
		var next: String = ""
		if not row.is_empty():
			next = _weighted_pick(row, current)
		if next == "":
			# Re-seed from initial (skipping current to avoid stutter)
			next = _weighted_pick(initial, current)
		if next == "":
			break
		sequence.append(next)
		current = next
	return sequence


## Weighted pick from a {key: weight_float} dict, optionally excluding `avoid`.
## Returns "" if dict is empty (or only contains avoid with no other entries).
static func _weighted_pick(weights: Dictionary, avoid: String) -> String:
	var total: float = 0.0
	for k in weights:
		if k == avoid:
			continue
		var w: float = float(weights[k])
		if w > 0.0:
			total += w
	if total <= 0.0:
		# Fallback: include `avoid` if nothing else has weight
		for k in weights:
			var w: float = float(weights[k])
			if w > 0.0:
				return str(k)
		return ""
	var r: float = randf() * total
	var acc: float = 0.0
	for k in weights:
		if k == avoid:
			continue
		var w: float = float(weights[k])
		if w <= 0.0:
			continue
		acc += w
		if r <= acc:
			return str(k)
	# Numeric fallback (last positive entry)
	var last_key: String = ""
	for k in weights:
		if k == avoid:
			continue
		if float(weights[k]) > 0.0:
			last_key = str(k)
	return last_key
