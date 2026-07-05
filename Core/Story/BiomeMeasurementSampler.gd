extends RefCounted

## BiomeMeasurementSampler — chatter is *measurement* of a biome.
##
## The grammar of dialogue is the basis-state distribution of the biome's QC.
## A 2-qubit biome utters 2-emoji words; a 6-qubit biome utters 6-emoji phrases.
## Length emerges from biome topology, not from a parameter we set.
##
## Per design (NO SPECIAL CASES): the chatter is a substrate measurement,
## not an invented Markov walk.


## Sample one basis state from a biome's QC.
## Returns Array[String] — one emoji per qubit, in qubit-index order.
## Returns [] if the biome can't produce a measurement (no QC, dim too large, etc.).
static func sample_basis(biome) -> Array:
	if biome == null or biome.quantum_computer == null:
		return []
	var qc = biome.quantum_computer
	if not qc.has_method("get_basis_state_probabilities"):
		return []
	var states: Array = qc.get_basis_state_probabilities()
	if states.is_empty():
		return []
	# Weighted draw.
	var total: float = 0.0
	for s in states:
		total += float(s.get("probability", 0.0))
	if total <= 0.0:
		# Degenerate (all zero) — return the first label as a label.
		return _label_to_emojis(str(states[0].get("label", "")))
	var r: float = randf() * total
	var acc: float = 0.0
	for s in states:
		acc += float(s.get("probability", 0.0))
		if r <= acc:
			return _label_to_emojis(str(s.get("label", "")))
	return _label_to_emojis(str(states[states.size() - 1].get("label", "")))


## Sample one basis state AND return per-qubit marginal probabilities at the
## measured pole. The marginals visualize "how confidently was this measured" —
## a sharp pole (≈1.0) is a confident utterance; a hesitant qubit (≈0.5) is
## tentative.
##
## Returns {emojis: Array[String], marginals: Array[float]} — both length-N
## where N is the number of qubits in the biome's QC. Returns empty dicts if
## measurement isn't possible.
static func sample_basis_with_marginals(biome) -> Dictionary:
	var emojis: Array = sample_basis(biome)
	if emojis.is_empty():
		return {"emojis": [], "marginals": []}
	if biome == null or biome.quantum_computer == null:
		return {"emojis": emojis, "marginals": []}
	var qc = biome.quantum_computer
	if qc.register_map == null or biome.viz_cache == null:
		return {"emojis": emojis, "marginals": []}
	var marginals: Array = []
	for qid in range(emojis.size()):
		var emoji := str(emojis[qid])
		# Resolve which pole this emoji is at on its qubit (north=0, south=1).
		var pole: int = 0
		if qc.register_map.has_method("pole"):
			pole = int(qc.register_map.pole(emoji))
		var snap: Dictionary = biome.viz_cache.get_snapshot(qid)
		marginals.append(float(snap.get("p1" if pole == 1 else "p0", 0.0)))
	return {"emojis": emojis, "marginals": marginals}


## Liveliness — Shannon entropy of the biome's measurement distribution,
## normalized to [0, 1]. This IS the diversity of what a biome can say: the
## spread of the exact distribution chatter samples from. A biome collapsed to
## one basis state → 0 (says one thing, quietly); a biome in rich superposition
## → 1 (babbles variously).
##
## NO SPECIAL CASES: we deliberately do NOT use von Neumann entropy or purity —
## those are degenerate (≈constant) in the closed-system default where ρ is pure.
## Measurement entropy stays live even for a pure state, because superposition
## still spreads the basis-state outcomes.
static func measurement_liveliness(biome) -> float:
	if biome == null or biome.quantum_computer == null:
		return 0.0
	var qc = biome.quantum_computer
	if not qc.has_method("get_basis_state_probabilities"):
		return 0.0
	var states: Array = qc.get_basis_state_probabilities()
	if states.size() <= 1:
		return 0.0
	var total: float = 0.0
	for s in states:
		total += float(s.get("probability", 0.0))
	if total <= 0.0:
		return 0.0
	var h: float = 0.0
	for s in states:
		var p: float = float(s.get("probability", 0.0)) / total
		if p > 0.0:
			h -= p * log(p)
	# Normalize by max entropy log(N) → [0, 1]. Robust to whether the QC reports
	# the full 2^n basis or only the non-negligible states.
	var max_h: float = log(float(states.size()))
	if max_h <= 0.0:
		return 0.0
	return clampf(h / max_h, 0.0, 1.0)


## Sample a single qubit's marginal — one emoji (north or south).
static func sample_qubit_marginal(biome, qid: int) -> String:
	if biome == null or biome.quantum_computer == null or qid < 0:
		return ""
	var qc = biome.quantum_computer
	if not qc.has_method("get_emoji_pair_for_qubit") or biome.viz_cache == null:
		return ""
	var snap: Dictionary = biome.viz_cache.get_snapshot(qid)
	var p_north: float = float(snap.get("p0", 0.5))
	var pair: Dictionary = qc.get_emoji_pair_for_qubit(qid)
	if randf() < p_north:
		return str(pair.get("north", ""))
	return str(pair.get("south", ""))


## Find live biomes whose atoms overlap a faction's signature. Returns Array of
## {biome, overlap_count} sorted by overlap descending.
static func biomes_for_faction_signature(farm, signature: Array) -> Array:
	var out: Array = []
	if farm == null or farm.grid == null or signature.is_empty():
		return out
	var biomes: Dictionary = farm.grid.get_all_biomes() if farm.grid.has_method("get_all_biomes") else {}
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if biome == null or biome.quantum_computer == null or biome.quantum_computer.register_map == null:
			continue
		var coords = biome.quantum_computer.register_map.coordinates
		var overlap := 0
		for emoji in signature:
			if coords.has(emoji):
				overlap += 1
		if overlap > 0:
			out.append({"biome": biome, "biome_name": biome_name, "overlap": overlap})
	out.sort_custom(func(a, b): return int(a.overlap) > int(b.overlap))
	return out


## Decompose a basis-state label string into Array[String] of one emoji per
## qubit. The label is built by concatenating emojis (one per qubit), so we
## need a grapheme-aware split. GDScript's `String.length()` counts utf-32
## code points; emoji are usually 1 code point but variation selectors aren't.
static func _label_to_emojis(label: String) -> Array:
	if label == "":
		return []
	var emojis: Array = []
	# Use unicode codepoint iteration: each non-modifier codepoint is its own emoji.
	# This is approximate — variation selectors (U+FE0F) and ZWJ (U+200D) sequences
	# would attach. For the current registry (mostly single-codepoint emojis), this
	# is correct. If a richer registry is added, swap to a grapheme cluster splitter.
	var i := 0
	var n := label.length()
	while i < n:
		var ch := label.substr(i, 1)
		# Skip variation-selector / ZWJ glue: append to previous if present.
		var code: int = ch.unicode_at(0) if ch.length() > 0 else 0
		if (code == 0xFE0F or code == 0x200D) and not emojis.is_empty():
			emojis[emojis.size() - 1] = str(emojis[emojis.size() - 1]) + ch
		else:
			emojis.append(ch)
		i += 1
	return emojis
