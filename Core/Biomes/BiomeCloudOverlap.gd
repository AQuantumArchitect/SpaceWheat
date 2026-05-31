class_name BiomeCloudOverlap
extends RefCounted

## BiomeCloudOverlap — find biomes whose cloud overlaps a given atom set.
##
## Vocabulary (locked):
##   atom    = single emoji
##   cloud   = set of atoms (a biome's cloud = atom_components keys)
##
## The output of these methods is a *list of biomes*, NOT a "neighborhood."
## A neighborhood is a configured (biome, signature) cluster — see
## AuthorityAdapter.compose_neighborhood. This module only computes raw
## cloud-overlap candidates.
##
## Reuses FactionBiomeMap._atoms_of_biome for the atom-extraction so the
## bare-vs-live distinction lives in one place.



## Biomes whose cloud intersects `cloud_atoms`. Sorted by overlap size desc.
## Capped at `max_count` (default 50).
func biomes_in_cloud(cloud_atoms: Dictionary, all_biomes: Array,
		max_count: int = 50) -> Array:
	var rows := biomes_in_cloud_with_overlap(cloud_atoms, all_biomes, max_count)
	var out: Array = []
	for r in rows:
		out.append(r["biome"])
	return out


## Decorated form: each entry is {biome, overlap, shared_atoms}. Sorted desc
## by overlap.
func biomes_in_cloud_with_overlap(cloud_atoms: Dictionary,
		all_biomes: Array, max_count: int = 50) -> Array:
	if cloud_atoms.is_empty() or all_biomes.is_empty():
		return []
	var rows: Array = []
	for biome in all_biomes:
		var atoms: Array = FactionBiomeMap._atoms_of_biome(biome)
		if atoms.is_empty():
			continue
		var shared: Array = []
		for a in atoms:
			if cloud_atoms.has(str(a)):
				shared.append(str(a))
		if shared.is_empty():
			continue
		rows.append({
			"biome":         biome,
			"overlap":       shared.size(),
			"shared_atoms":  shared,
		})
	rows.sort_custom(func(a, b): return int(a["overlap"]) > int(b["overlap"]))
	if max_count > 0 and rows.size() > max_count:
		rows = rows.slice(0, max_count)
	return rows
