class_name AuthorityComposer
extends RefCounted

## AuthorityComposer — pure-math composition of agent / space / operator-profile fits.
##
## This module knows ABOUT density matrices, Lindblad operator matrices, and
## abstract feature vectors. It does NOT know about factions, biomes, hats,
## icons, or any other game noun. Adapters translate game objects into the
## math primitives below; the composer is reusable for any analogous problem.
##
## All inputs and outputs are PackedFloat64Array / PackedByteArray / Array of
## ComplexMatrix. No strings flow through.
##
## Conventions
##   - feat_count := number of feature axes (e.g. 12 alignment axes); chosen
##     by the adapter and consistent across one composition.
##   - dim       := Hilbert space dimension of the dissipative system being
##     fingerprinted (e.g. 2^num_qubits for a biome).
##   - mask bits :  1 = axis is "owned"/relevant, 0 = ignore in this comparison.



## Per-basis-state dissipation magnitude.  Returns PackedFloat64Array of
## length `dim`; entry j = Σ_k Σ_i |L_k[i,j]|^2 (column-sum of |L_k|^2,
## summed over operators).  This is the rate at which population escapes
## basis state j under the combined Lindblad dynamics.  Pure linalg.
func dissipation_per_basis(lindblads: Array, dim: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(dim)
	for j in range(dim):
		out[j] = 0.0
	for L in lindblads:
		if L == null:
			continue
		for j in range(dim):
			var col_mass := 0.0
			for i in range(dim):
				var c = L.get_element(i, j)
				if c == null:
					continue
				col_mass += c.abs_sq()
			out[j] += col_mass
	return out


## Project a per-basis-state vector down to a per-feature vector via a sparse
## stochastic projection.  projection[f] is a Dictionary[int basis_index → float
## weight] giving how much basis-state j contributes to feature f.  Returns
## PackedFloat64Array of length `feat_count`.  Pure vector math.
func project(per_basis: PackedFloat64Array, projection: Array,
		feat_count: int) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	out.resize(feat_count)
	for f in range(feat_count):
		out[f] = 0.0
		if f >= projection.size():
			continue
		var p = projection[f]
		if not (p is Dictionary):
			continue
		var acc := 0.0
		for j in p.keys():
			var idx := int(j)
			if idx < 0 or idx >= per_basis.size():
				continue
			acc += per_basis[idx] * float(p[j])
		out[f] = acc
	return out


## Bitwise AND of two byte-masks.  Length = min(a,b).  Pure.
func mask_and(a: PackedByteArray, b: PackedByteArray) -> PackedByteArray:
	var n: int = min(a.size(), b.size())
	var out := PackedByteArray()
	out.resize(n)
	for i in range(n):
		out[i] = 1 if (a[i] != 0 and b[i] != 0) else 0
	return out


## Cosine similarity between two equal-length vectors, restricted to entries
## where mask[i] != 0.  Returns 0.0 if either restricted vector is zero.
## Result clamped to [0, 1] (negative similarities pinned to 0 — we only
## care about positive co-direction for "fit").
func masked_cosine(a: PackedFloat64Array, b: PackedFloat64Array,
		mask: PackedByteArray) -> float:
	var n: int = min(min(a.size(), b.size()), mask.size())
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in range(n):
		if mask[i] == 0:
			continue
		dot += a[i] * b[i]
		na += a[i] * a[i]
		nb += b[i] * b[i]
	if na <= 0.0 or nb <= 0.0:
		return 0.0
	var sim := dot / (sqrt(na) * sqrt(nb))
	if sim < 0.0:
		return 0.0
	if sim > 1.0:
		return 1.0
	return sim


## Compose one (agent, space, profiles) tuple.
##   agent_state : per-feature population vector in [0,1] (e.g. axis marginals).
##   agent_mask  : per-feature byte mask, 1 = relevant.
##   fingerprint : per-feature dissipation-derived character of the space.
##   space_mask  : per-feature byte mask of which features this space expresses.
##   profiles    : Array[PackedFloat64Array], each one an affinity vector over
##                 the same feature axes (one per operator profile).
##
## Returns:
##   {
##     "fit":             float in [0,1],
##     "profile_scores":  Array[float] aligned with `profiles` input,
##     "intersection":    PackedByteArray = agent_mask AND space_mask,
##   }
func compose_one(agent_state: PackedFloat64Array, agent_mask: PackedByteArray,
		fingerprint: PackedFloat64Array, space_mask: PackedByteArray,
		profiles: Array) -> Dictionary:
	var inter := mask_and(agent_mask, space_mask)
	var fit := masked_cosine(agent_state, fingerprint, inter)
	var scores: Array = []
	for p in profiles:
		if p is PackedFloat64Array:
			scores.append(masked_cosine(p, fingerprint, inter))
		else:
			scores.append(0.0)
	return {
		"fit": fit,
		"profile_scores": scores,
		"intersection": inter,
	}
