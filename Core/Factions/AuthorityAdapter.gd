class_name AuthorityAdapter
extends RefCounted

## AuthorityAdapter — thin glue between game objects (Faction, Biome, hats)
## and the pure-math AuthorityComposer.
##
## All linear algebra goes through AuthorityComposer. This module's job is
## to translate game-shaped data into math-shaped vectors / projections,
## call the composer, and decorate the numeric output with names for display.
##
## Two parametric knobs live here:
##   - BIOME_AXIS_HEURISTICS : how an atom_components-shaped biome character
##     maps to weights on the 12 alignment axes.
##   - HAT_AFFINITY          : per-hat affinity vector over the 12 alignment
##     axes.
## Both are commented as knobs and live in this file so the algorithm and
## the numbers stay in one place while we discover the right shape. Future
## rounds may move them to JSON for design-team sweeps.

const Composer            = preload("res://Core/Quantum/AuthorityComposer.gd")
const ToolConfig          = preload("res://Core/GameState/ToolConfig.gd")

const HAT_INCLUSION_THRESHOLD := 0.45


## ===========================================================================
## PARAMETRIC KNOB #1 — biome-character → 12-axis projection rules
## ===========================================================================
## Each rule names a *biome characteristic* derived from atom_components and
## maps it to a per-axis additive weight. The adapter scans the biome and
## sums contributions to build a 12-vector "biome fingerprint."
##
## Axis order (from data/axes.json):
##   0 random_deterministic, 1 material_mystical, 2 common_elite,
##   3 local_cosmic,         4 instant_eternal,   5 physical_mental,
##   6 crystalline_fluid,    7 direct_subtle,     8 consumptive_providing,
##   9 monochrome_prismatic, 10 emergent_imposed, 11 scattered_focused
const BIOME_AXIS_HEURISTICS: Dictionary = {
	# High mean dissipation rate → instant, consumptive, scattered.
	"high_dissipation":  [0.2, 0.0, 0.0, 0.0, 0.6, 0.0, 0.0, 0.0, 0.5, 0.0, 0.0, 0.4],
	# Heavy decay-to-void → consumptive, monochrome.
	"void_attractor":    [0.0, 0.0, 0.0, 0.3, 0.0, 0.0, 0.0, 0.0, 0.7, 0.6, 0.0, 0.0],
	# Gated/conditional Lindblads → subtle, emergent, deterministic.
	"gated":             [0.5, 0.2, 0.0, 0.0, 0.0, 0.3, 0.0, 0.6, 0.0, 0.0, 0.5, 0.0],
	# Time-modulated drivers → fluid, scattered.
	"drivers":           [0.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.6, 0.0, 0.0, 0.0, 0.0, 0.4],
	# Just being a populated biome → local, physical, common (baseline).
	"baseline":          [0.0, 0.0, 0.3, 0.4, 0.0, 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
	# H-derived: off-diagonal dominance → mystical, mental, fluid, emergent.
	"high_coherence":    [0.0, 0.8, 0.0, 0.0, 0.0, 0.6, 0.7, 0.0, 0.0, 0.0, 0.7, 0.0],
	# H-derived: diagonal dominance → crystalline, focused, imposed.
	"dominant_self":     [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.7, 0.0, 0.0, 0.0, 0.8],
}


## ===========================================================================
## PARAMETRIC KNOB #2 — per-hat affinity over the 12 alignment axes
## ===========================================================================
## Authored from docs/ARCHETYPE_FRAMES.md operator-type + time-scale hints.
## Each row is a per-axis preference for biomes-of-that-character. Higher =
## the hat thrives in biomes that score high on that axis. Cosine-compared
## to biome fingerprint to score (hat × biome) fit.
const HAT_AFFINITY: Dictionary = {
	# Spark (S, Q, P) — Lindblad drive/decay one-shots. Loves dissipative,
	# consumptive, instant biomes. Indifferent to subtlety.
	"spark":    [0.3, 0.0, 0.0, 0.0, 0.9, 0.4, 0.0, 0.0, 0.7, 0.0, 0.0, 0.5],
	# Icon (S, Q, F) — injects faction qubits. Loves emergent, prismatic,
	# fluid biomes (room to grow into).
	"icon":     [0.0, 0.5, 0.0, 0.0, 0.0, 0.0, 0.7, 0.3, 0.0, 0.8, 0.9, 0.0],
	# Merchant (S, C, F) — drain/transfer/pump trade abstractions. Loves
	# consumptive + providing flux, common reach, fluid.
	"merchant": [0.0, 0.0, 0.6, 0.4, 0.3, 0.0, 0.6, 0.0, 0.8, 0.0, 0.0, 0.0],
	# Captain (W, C, F) — biome lifecycle decree. Loves cosmic scale,
	# eternal time, imposed structure.
	"captain":  [0.0, 0.0, 0.5, 0.8, 0.6, 0.0, 0.0, 0.4, 0.0, 0.0, 0.0, 0.6],
	# Ace (S, C, P) — measure/probe/harvest. Loves direct, focused,
	# crystalline (well-defined to measure).
	"ace":      [0.0, 0.3, 0.0, 0.0, 0.0, 0.5, 0.7, 0.8, 0.0, 0.0, 0.0, 0.9],
	# Operator (W, Q, F) — gate topology, 2Q architecture. Loves mystical,
	# mental, crystalline, imposed.
	"operator": [0.0, 0.8, 0.0, 0.0, 0.0, 0.7, 0.6, 0.0, 0.0, 0.0, 0.0, 0.5],
	# Druid (W, Q, P) — unitary rotations, reversible. Loves mystical,
	# eternal, fluid, prismatic.
	"druid":    [0.0, 0.9, 0.0, 0.5, 0.7, 0.0, 0.5, 0.0, 0.0, 0.7, 0.5, 0.0],
}


## ---------------- Game → math conversions ----------------

## Build the 12-axis state vector for a faction, plus its mask.
##   axis_pops[i] = P(axis i is in pole-1) under faction.alignment.
##   mask[i]      = 1 if the faction's bits[i] expressed (i.e. the corner
##                  state was non-default on this axis), else 1 anyway —
##                  a faction "speaks" on every axis it has bits for, which
##                  for our authored factions is all 12.
func _agent_from_faction(faction) -> Dictionary:
	var n := FactionAxes.AXIS_COUNT
	var state := PackedFloat64Array()
	var mask  := PackedByteArray()
	state.resize(n)
	mask.resize(n)
	var alignment = faction.alignment
	var bits = faction.get_axial_bits()
	for i in range(n):
		var p1 := 0.5
		if alignment != null:
			p1 = alignment.axis_marginal(i, 1)
		state[i] = p1
		# Authored factions always speak all 12 axes; if bits weren't built
		# (partial fixture), only the bits we have count.
		mask[i] = 1 if (bits.size() == n) else 0
	return {"state": state, "mask": mask}


## Build a biome fingerprint over the 12 alignment axes by combining
## heuristic rule contributions. Returns {fingerprint: vec, mask: vec}.
##
## h_traits: optional Dictionary from _h_traits_from_qc — adds H-derived
## axes (high_coherence, dominant_self) on top of the L-only baseline.
## When not provided (compose_pair path), only L traits contribute.
func _space_from_biome(biome, h_traits: Dictionary = {}) -> Dictionary:
	var n := FactionAxes.AXIS_COUNT
	var fp := PackedFloat64Array()
	var mask := PackedByteArray()
	fp.resize(n)
	mask.resize(n)
	for i in range(n):
		fp[i] = 0.0
		mask[i] = 0

	var atoms: Dictionary = _read_atom_components(biome)
	var traits := _biome_traits(atoms)
	# Always-on baseline so empty biomes don't return all-zero fingerprints.
	_accumulate(fp, BIOME_AXIS_HEURISTICS["baseline"], 1.0)
	for trait_name in traits.keys():
		var w: float = traits[trait_name]
		var rule = BIOME_AXIS_HEURISTICS.get(trait_name, null)
		if rule != null and w > 0.0:
			_accumulate(fp, rule, w)
	# H-derived traits from a neighborhood QuantumComputer (topology path only).
	for trait_name in h_traits.keys():
		var w: float = float(h_traits[trait_name])
		var rule = BIOME_AXIS_HEURISTICS.get(trait_name, null)
		if rule != null and w > 0.0:
			_accumulate(fp, rule, w)
	# Mark axes the fingerprint actually expresses.
	for i in range(n):
		mask[i] = 1 if fp[i] > 1e-9 else 0
	return {"fingerprint": fp, "mask": mask}


## Read atom_components from either a Biome (RefCounted data class) or a
## BiomeBase (Node). Both expose either atom_components directly or via
## a getter on the active biome data.
func _read_atom_components(biome) -> Dictionary:
	if biome == null:
		return {}
	if biome is Object and "atom_components" in biome:
		var ac = biome.atom_components
		if ac is Dictionary:
			return ac
	if biome.has_method("_get_atom_components"):
		var ac2 = biome._get_atom_components()
		if ac2 is Dictionary:
			return ac2
	return {}


## Compute trait weights from atom_components. Each weight is in [0,1]; the
## fingerprint is the heuristic-rule × weight sum. Pure introspection.
func _biome_traits(atoms: Dictionary) -> Dictionary:
	var out := {
		"high_dissipation": 0.0,
		"void_attractor":   0.0,
		"gated":            0.0,
		"drivers":          0.0,
	}
	if atoms.is_empty():
		return out
	var total_rate := 0.0
	var rate_count := 0
	var void_rate := 0.0
	var has_gated := false
	var has_drivers := false
	for emoji in atoms.keys():
		var entry = atoms[emoji]
		if not (entry is Dictionary):
			continue
		if entry.has("decay") and entry["decay"] is Dictionary:
			var d = entry["decay"]
			var r := float(d.get("rate", 0.0))
			total_rate += r
			rate_count += 1
			if String(d.get("target", "")) == "🗑":
				void_rate += r
		if entry.has("lindblad_outgoing") and entry["lindblad_outgoing"] is Dictionary:
			for tgt in entry["lindblad_outgoing"].keys():
				var r2 := float(entry["lindblad_outgoing"][tgt])
				total_rate += r2
				rate_count += 1
				if String(tgt) == "🗑":
					void_rate += r2
		if entry.has("gated_lindblad_source"):
			has_gated = true
		if entry.has("driver") or entry.has("self_energy_driver"):
			has_drivers = true
	var mean_rate := (total_rate / float(rate_count)) if rate_count > 0 else 0.0
	# Map rate ~[0, 0.5] → [0, 1].
	out["high_dissipation"] = clampf(mean_rate / 0.5, 0.0, 1.0)
	out["void_attractor"]   = clampf(void_rate / max(total_rate, 1e-9), 0.0, 1.0)
	out["gated"]            = 1.0 if has_gated else 0.0
	out["drivers"]          = 1.0 if has_drivers else 0.0
	return out


## Compute H-derived biome traits from a neighborhood QuantumComputer.
## Returns {"high_coherence": float, "dominant_self": float}, each in [0,1].
## Returns {} if qc is null (bare biome path — L-only fingerprint stays).
func _h_traits_from_qc(qc) -> Dictionary:
	if qc == null or not ("hamiltonian" in qc) or qc.hamiltonian == null:
		return {}
	var H = qc.hamiltonian
	var dim: int = H.size() if H.has_method("size") else 0
	if dim == 0:
		return {}
	var off_sq := 0.0
	var diag_sq := 0.0
	for row in range(dim):
		for col in range(dim):
			var c = H.get_element(row, col)
			if c == null:
				continue
			var mag2: float = c.abs_sq()
			if row == col:
				diag_sq += mag2
			else:
				off_sq += mag2
	var total := off_sq + diag_sq
	if total < 1e-12:
		return {}
	var high_coherence: float = clampf(off_sq / total, 0.0, 1.0)
	return {
		"high_coherence": high_coherence,
		"dominant_self":  1.0 - high_coherence,
	}


func _accumulate(target: PackedFloat64Array, src: Array, weight: float) -> void:
	var n: int = min(target.size(), src.size())
	for i in range(n):
		target[i] = target[i] + float(src[i]) * weight


## Build the per-hat affinity vector list, plus aligned name list, in a
## stable order matching ToolConfig.FRAME_IDS.
func _profiles_from_hats(invested_hats: Array) -> Dictionary:
	var profiles: Array = []
	var names: Array = []
	var n := FactionAxes.AXIS_COUNT
	for fid in ToolConfig.FRAME_IDS:
		if not (fid in invested_hats):
			continue
		var raw = HAT_AFFINITY.get(fid, null)
		if raw == null:
			continue
		var v := PackedFloat64Array()
		v.resize(n)
		for i in range(n):
			v[i] = float(raw[i]) if i < raw.size() else 0.0
		profiles.append(v)
		names.append(String(fid))
	return {"profiles": profiles, "names": names}


## ---------------- Top-level decorated composer call ----------------

## Compose the full access-tree entry for one (faction, biome) pair.
## Returns a decorated Dictionary suitable for UI consumption:
##   {
##     "biome":  String,
##     "icons":  Array[String]   # faction.signature ∩ biome emojis,
##     "fit":    float,
##     "hats":   Array[String]   # hat names with score >= threshold,
##     "scores": Dictionary[String hat → float score],
##   }
func compose_pair(faction, biome) -> Dictionary:
	var agent := _agent_from_faction(faction)
	var space := _space_from_biome(biome)
	var hats := _profiles_from_hats(faction.invested_hats if "invested_hats" in faction else [])
	var composer = Composer.new()
	var result: Dictionary = composer.compose_one(
		agent["state"], agent["mask"],
		space["fingerprint"], space["mask"],
		hats["profiles"]
	)
	var scores := {}
	var passing: Array = []
	var profile_scores = result.get("profile_scores", [])
	for k in range(hats["names"].size()):
		var nm = hats["names"][k]
		var sc = float(profile_scores[k]) if k < profile_scores.size() else 0.0
		scores[nm] = sc
		if sc >= HAT_INCLUSION_THRESHOLD:
			passing.append(nm)
	return {
		"biome":  String(biome.name) if "name" in biome else "",
		"icons":  _signature_intersection(faction, biome),
		"fit":    float(result.get("fit", 0.0)),
		"hats":   passing,
		"scores": scores,
	}


## faction.signature ∩ biome emojis (deterministic, order-preserving on signature).
func _signature_intersection(faction, biome) -> Array:
	var out: Array = []
	if faction == null or not ("cloud" in faction):
		return out
	var biome_emojis := _biome_emoji_set(biome)
	for e in faction.cloud:
		if biome_emojis.has(String(e)):
			out.append(String(e))
	return out


func _biome_emoji_set(biome) -> Dictionary:
	var seen := {}
	if biome == null:
		return seen
	var atoms := _read_atom_components(biome)
	for e in atoms.keys():
		seen[String(e)] = true
	return seen


## Compose the faction-driven access tree across multiple (faction, biome)
## pairs. Returns { faction_name → sorted Array[pair-result] }.
func compose_access_tree(factions: Array, biomes: Array) -> Dictionary:
	var tree := {}
	for f in factions:
		var entries: Array = []
		for b in biomes:
			entries.append(compose_pair(f, b))
		entries.sort_custom(func(a, b): return _compare_access_entries(a, b))
		tree[String(f.name)] = entries
	return tree


## ---------------- Neighborhoods + topology ----------------

## Build a faction's owned-neighborhood tree.
##
## A *neighborhood* is a (biome, induced-signature) cluster: the configured
## artifact a faction would install on a bare biome. This method walks every
## bare biome whose cloud intersects the faction's combined cloud, induces a
## signature for each, realizes it, scores hats against it, and returns the
## decorated bundle.
##
## `parent_node` is required because BiomeBuilder.build_neighborhood_loadout
## produces a DynamicBiome Node. Use a throwaway Node and free at end of run.
##
## `edge_threshold` filters hat edges; defaults to HAT_INCLUSION_THRESHOLD.
func compose_neighborhood(faction, all_biomes: Array, parent_node: Node,
		edge_threshold: float = HAT_INCLUSION_THRESHOLD) -> Dictionary:
	if faction == null:
		return {}
	var lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if lexicon == null:
		lexicon = (Engine.get_main_loop().root.get_node_or_null("/root/IconRegistry") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	var faction_name: String = str(faction.name) if "name" in faction else ""

	var relations := IconRelations.new()
	var biome_overlap := BiomeCloudOverlap.new()
	var inducer := IconLoadoutInducer.new()

	# 1. Faction's signature (set of icons) and combined cloud (set of atoms).
	var faction_signature: Array = lexicon.get_icons_for_faction(faction_name)
	var faction_cloud: Dictionary = relations.union_of_clouds(faction_signature)

	# 2. Per-icon relation aggregates relative to the faction's signature.
	var all_icons: Array = lexicon.get_all()
	var sibling_set: Dictionary = {}
	var siblings_via_cloud_set: Dictionary = {}
	for own_icon in faction_signature:
		# Self always counts in the via-cloud aggregate.
		var self_key := "%s|%s" % [str(own_icon.get("pole_0", "")), str(own_icon.get("pole_1", ""))]
		siblings_via_cloud_set[self_key] = own_icon
		for s in relations.siblings_of(own_icon, all_icons):
			var k := "%s|%s" % [str(s.get("pole_0", "")), str(s.get("pole_1", ""))]
			sibling_set[k] = s
		for n in relations.siblings_via_cloud_of(own_icon, all_icons):
			var k2 := "%s|%s" % [str(n.get("pole_0", "")), str(n.get("pole_1", ""))]
			siblings_via_cloud_set[k2] = n

	# 3. Candidate biomes: those whose cloud intersects the faction's cloud.
	var biome_rows: Array = biome_overlap.biomes_in_cloud_with_overlap(
		faction_cloud, all_biomes
	)

	# 4. Per-biome: induce signature, build neighborhood, compose, filter edges.
	var neighborhood_records: Array = []
	var hat_coverage: Dictionary = {}
	var edge_total := 0
	for row in biome_rows:
		var bare_biome = row["biome"]
		var biome_name_str: String = String(bare_biome.name) if "name" in bare_biome else ""
		var authored: Array = _authored_signature(faction, biome_name_str)
		var source_tag: String
		var induced_signature: Array
		if not authored.is_empty():
			induced_signature = authored
			source_tag = "authored"
		else:
			induced_signature = inducer.induce(faction, bare_biome, 8, lexicon)
			source_tag = "induced" if not induced_signature.is_empty() else "empty"
		var neighborhood_result := BiomeBuilder.build_neighborhood_loadout(
			bare_biome, faction_name, parent_node,
			{"neighborhood_icons": induced_signature, "skip_tree_add": true}
		)
		var live_biome = neighborhood_result.get("biome_node", null)
		# H-fingerprint: extract traits from the neighborhood QC if available.
		var h_traits := _h_traits_from_qc(neighborhood_result.get("quantum_computer", null))
		var agent := _agent_from_faction(faction)
		var space := _space_from_biome(bare_biome, h_traits)
		var hats := _profiles_from_hats(faction.invested_hats if "invested_hats" in faction else [])
		var composer = Composer.new()
		var composed_result: Dictionary = composer.compose_one(
			agent["state"], agent["mask"],
			space["fingerprint"], space["mask"],
			hats["profiles"]
		)
		# Decorate the result the same way compose_pair does.
		var pair := {
			"biome":  String(bare_biome.name) if "name" in bare_biome else "",
			"icons":  _signature_intersection(faction, bare_biome),
			"fit":    float(composed_result.get("fit", 0.0)),
			"hats":   [],
			"scores": {},
		}
		var profile_scores = composed_result.get("profile_scores", [])
		for k in range(hats["names"].size()):
			var nm = hats["names"][k]
			var sc = float(profile_scores[k]) if k < profile_scores.size() else 0.0
			(pair["scores"] as Dictionary)[nm] = sc
			if sc >= HAT_INCLUSION_THRESHOLD:
				(pair["hats"] as Array).append(nm)
		var edges: Array = []
		var scores: Dictionary = pair.get("scores", {})
		for hat_name in scores.keys():
			var sc := float(scores[hat_name])
			if sc >= edge_threshold:
				edges.append({"hat": String(hat_name), "score": sc})
				hat_coverage[hat_name] = int(hat_coverage.get(hat_name, 0)) + 1
		edges.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
		edge_total += edges.size()
		neighborhood_records.append({
			"biome":              biome_name_str if biome_name_str != "" else "?",
			"overlap":            int(row["overlap"]),
			"shared_atoms":       row["shared_atoms"],
			"induced_signature":  induced_signature,
			"source":             source_tag,
			"fit":                float(pair.get("fit", 0.0)),
			"edges":              edges,
		})
		# Free transient neighborhood so we don't leak nodes when running headless.
		if live_biome != null and is_instance_valid(live_biome):
			live_biome.queue_free()

	return {
		"faction":             faction_name,
		"faction_cloud":       faction_cloud.keys(),
		"siblings":            sibling_set.values(),
		"siblings_via_cloud":  siblings_via_cloud_set.values(),
		"neighborhoods":       neighborhood_records,
		"stats": {
			"neighborhood_count": neighborhood_records.size(),
			"edge_count":         edge_total,
			"hat_coverage":       hat_coverage,
		},
	}


## Return an authored signature for a specific biome, or [] if none is authored.
func _authored_signature(faction, biome_name: String) -> Array:
	if faction == null or not ("neighborhoods" in faction):
		return []
	var nbhs = faction.neighborhoods
	if not (nbhs is Array):
		return []
	for nbh in nbhs:
		if not (nbh is Dictionary):
			continue
		if str(nbh.get("biome", "")) == biome_name:
			var sig = nbh.get("signature", [])
			return sig if sig is Array else []
	return []


## compose_neighborhood for every faction, keyed by faction name.
func compose_topology(factions: Array, all_biomes: Array,
		parent_node: Node) -> Dictionary:
	var out := {}
	for f in factions:
		if f == null:
			continue
		out[String(f.name)] = compose_neighborhood(f, all_biomes, parent_node)
	return out


func _compare_access_entries(a, b) -> bool:
	var a_fit := float(a.get("fit", 0.0))
	var b_fit := float(b.get("fit", 0.0))
	if abs(a_fit - b_fit) > 1e-9:
		return a_fit > b_fit

	var a_hats := (a.get("hats", []) as Array).size()
	var b_hats := (b.get("hats", []) as Array).size()
	if a_hats != b_hats:
		return a_hats > b_hats

	var a_icons := (a.get("icons", []) as Array).size()
	var b_icons := (b.get("icons", []) as Array).size()
	if a_icons != b_icons:
		return a_icons > b_icons

	return String(a.get("biome", "")) < String(b.get("biome", ""))
