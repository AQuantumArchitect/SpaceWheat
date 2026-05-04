class_name MarketBiasSources
extends RefCounted

## MarketBiasSources — DRY collection of substrate readouts that compose into
## the bias on a contract's gozinda↔gozouta axis. Each source is a static
## function: `func(contract, farm) -> float` returning a rotation angle in
## radians. Compositional: the contract's market qubit starts at maximally
## mixed (|+⟩⟨+|) and applies each source's RY rotation in sequence.
##
## All sources read live substrate (no caching) so contract pricing reflects
## the current world state at the moment of query. Adding a source = appending
## a new static method below + adding it to BIAS_SOURCES.
##
## Each source returns 0.0 when its read fails — graceful degradation. A source
## that needs data not yet wired contributes nothing rather than crashing.

const HamiltonianConfig = preload("res://Core/Config/HamiltonianConfig.gd")

# ---------------- helpers ----------------

static func _signed_around(p: float, midpoint: float = 0.5) -> float:
	# Returns a signed bias in [-1, +1], zero at the natural midpoint.
	# Below midpoint: negative (favors gozinda). Above midpoint: positive (favors gozouta).
	# Linear scaling — saturates at the [0, 1] interval edges.
	if p >= midpoint:
		var span_high: float = 1.0 - midpoint
		if span_high <= 0.0:
			return 1.0
		return clampf((p - midpoint) / span_high, 0.0, 1.0)
	else:
		if midpoint <= 0.0:
			return -1.0
		return -clampf((midpoint - p) / midpoint, 0.0, 1.0)


static func _safe_get_biome(contract, farm):
	if farm == null or contract == null:
		return null
	if "grid" not in farm or farm.grid == null:
		return null
	if not farm.grid.has_biomes():
		return null
	for b in farm.grid.get_all_biomes().values():
		var bname = b.get_biome_type() if b.has_method("get_biome_type") else (b.biome_name if "biome_name" in b else "")
		if str(bname) == contract.biome_name:
			return b
	return null


static func _safe_get_faction(contract, farm):
	if farm == null or contract == null:
		return null
	if "faction_density" not in farm or farm.faction_density == null:
		return null
	var registry = farm.faction_density.get_registry()
	if registry == null:
		return null
	return registry.get_by_name(contract.faction)


# Biome's affinity is computed live from its signature owners (Phase V logic,
# inlined to avoid storing on Biome which is a data record). Returns null when
# the biome has no resolvable signature.
static func _live_biome_affinity(biome, farm):
	if biome == null or farm == null:
		return null
	if not biome.has_method("get_signature_pairs"):
		return null
	var pairs: Array = biome.get_signature_pairs()
	if pairs.is_empty():
		return null
	var lex = null
	if "_ensure_icon_lexicon" in farm or farm.has_method("_ensure_icon_lexicon"):
		lex = farm._ensure_icon_lexicon()
	if lex == null and "icon_lexicon" in farm:
		lex = farm.icon_lexicon
	if lex == null:
		return null
	var registry = null
	if "faction_density" in farm and farm.faction_density != null:
		registry = farm.faction_density.get_registry()
	if registry == null:
		return null
	var owners: Array = []
	for pair in pairs:
		var icon: Dictionary = lex.find_icon_by_pair(pair.pole_0, pair.pole_1)
		var owner: String = str(icon.get("owner_faction", "")) if not icon.is_empty() else ""
		if owner != "":
			owners.append(owner)
	if owners.is_empty():
		return null
	var first_f = registry.get_by_name(owners[0])
	if first_f == null or first_f.affinity == null:
		return null
	var AGCls = load("res://Core/Affinity/AffinityGraph.gd")
	var bg = AGCls.from_dict(first_f.affinity.to_dict())
	for i in range(1, owners.size()):
		var f = registry.get_by_name(owners[i])
		if f != null and f.affinity != null:
			bg.lindblad_jump_toward(f.affinity, 1.0 / float(i + 1))
	return bg


# ---------------- sources ----------------

static func bias_from_biome_marginal(contract, farm) -> float:
	# IconMap mass on R, normalized. Natural midpoint = 1/num_qubits (uniform
	# spread across the biome's emojis). High mass relative to that midpoint =
	# biome currently favors gozouta; low mass = favors gozinda.
	var biome = _safe_get_biome(contract, farm)
	if biome == null or not biome.has_method("get_icon_map"):
		return 0.0
	var icon_map: Dictionary = biome.get_icon_map()
	var by_emoji: Dictionary = icon_map.get("by_emoji", {})
	var total: float = float(icon_map.get("total", 0.0))
	if total <= 0.0 or not by_emoji.has(contract.resource):
		return 0.0
	var p: float = clampf(float(by_emoji[contract.resource]) / total, 0.0, 1.0)
	var num_qubits: int = int(icon_map.get("num_qubits", 1))
	var natural_midpoint: float = 1.0 / float(maxi(num_qubits, 1))
	# Pole 1 (gozouta = "north") receives positive bias when mass is high;
	# pole 0 (gozouta = "south") receives the inverse.
	var bias: float = _signed_around(p, natural_midpoint)
	return bias if contract.qubit_pole == 1 else -bias


static func bias_from_world_emoji_mass(contract, farm) -> float:
	# Wild creature: world's spectral mass on R. Natural midpoint = uniform
	# 1/96 (factions) ≈ 0.01. High mass means R is "loud" in the current world
	# — faction is paying out something the world cares about.
	if farm == null or "faction_density" not in farm or farm.faction_density == null:
		return 0.0
	if not farm.faction_density.has_method("affinity_for_emoji"):
		return 0.0
	var p: float = clampf(float(farm.faction_density.affinity_for_emoji(contract.resource)), 0.0, 1.0)
	# World-mass natural midpoint: scale by total factions if known.
	var midpoint: float = 0.05
	if farm.faction_density.has_method("get_size"):
		var sz: int = int(farm.faction_density.get_size())
		if sz > 0:
			midpoint = 5.0 / float(sz)  # ~5 factions speaking is "natural"
	var bias: float = _signed_around(p, midpoint)
	return bias if contract.qubit_pole == 1 else -bias


static func bias_from_fdm_principal_axis(contract, farm) -> float:
	# FDM's dominant eigenvector projected onto 12 axes. Variance from the
	# uniform 0.5 baseline is the "world's mood swing". A high-variance world
	# (eigenvector strongly biased) creates more market opportunity.
	if farm == null or "faction_density" not in farm or farm.faction_density == null:
		return 0.0
	if not farm.faction_density.has_method("get_principal_axis_projection"):
		return 0.0
	var proj: Array = farm.faction_density.get_principal_axis_projection()
	if proj.is_empty():
		return 0.0
	var sum_sq: float = 0.0
	for v in proj:
		sum_sq += (float(v) - 0.5) * (float(v) - 0.5)
	var rms: float = sqrt(sum_sq / float(proj.size()))
	# rms ∈ [0, 0.5]; map to [0, 1] then center on 0.25 for "natural eigenstate spread"
	var rms_normalized: float = clampf(rms * 2.0, 0.0, 1.0)
	return _signed_around(rms_normalized, 0.25) * 0.5  # half-weight


static func bias_from_player_biome_kernel(contract, farm) -> float:
	# Phase V kernel. Natural midpoint = 1/4096 (random overlap on 12-qubit
	# Hilbert space) ≈ 0.00024. Anything noticeably above is meaningful resonance.
	if farm == null or "player_affinity" not in farm or farm.player_affinity == null:
		return 0.0
	var biome = _safe_get_biome(contract, farm)
	if biome == null or not "affinity" in biome or biome.affinity == null:
		return 0.0
	var k: float = clampf(float(farm.player_affinity.overlap(biome.affinity)), 0.0, 1.0)
	# Use a midpoint of 0.01 — meaningful resonance threshold for kernel overlap.
	return _signed_around(k, 0.01)


static func bias_from_faction_biome_kernel(contract, farm) -> float:
	var f = _safe_get_faction(contract, farm)
	if f == null or f.affinity == null:
		return 0.0
	var biome = _safe_get_biome(contract, farm)
	var biome_affinity = _live_biome_affinity(biome, farm)
	if biome_affinity == null:
		return 0.0
	var k: float = clampf(float(f.affinity.overlap(biome_affinity)), 0.0, 1.0)
	# Kernel between two corner-state factions is 0 or 1 (basis-aligned/orthogonal),
	# but mixed biome signatures yield intermediate values.
	return _signed_around(k, 0.01)


static func bias_from_player_faction_kernel(contract, farm) -> float:
	if farm == null or "player_affinity" not in farm or farm.player_affinity == null:
		return 0.0
	var f = _safe_get_faction(contract, farm)
	if f == null or f.affinity == null:
		return 0.0
	var k: float = clampf(float(farm.player_affinity.overlap(f.affinity)), 0.0, 1.0)
	return _signed_around(k, 0.01)


static func bias_from_faction_loudness(contract, farm) -> float:
	# Wild creature: how loud is this faction right now? Natural midpoint =
	# uniform 1/F (each faction holds equal mass); above = currently energized.
	if farm == null or "faction_density" not in farm or farm.faction_density == null:
		return 0.0
	if not farm.faction_density.has_method("get_weight"):
		return 0.0
	var w: float = clampf(float(farm.faction_density.get_weight(contract.faction)), 0.0, 1.0)
	var midpoint: float = 0.01
	if farm.faction_density.has_method("get_size"):
		var sz: int = int(farm.faction_density.get_size())
		if sz > 0:
			midpoint = 1.0 / float(sz)
	return _signed_around(w, midpoint)


static func bias_from_standings(contract, farm) -> float:
	# Player's per-faction reputation channels — legitimacy − debt as soft-clip.
	# tanh maps unbounded standings to [-1, 1]. Naturally zero at neutral.
	if farm == null or "faction_standings" not in farm:
		return 0.0
	var standings: Dictionary = farm.faction_standings
	if not standings.has(contract.faction):
		return 0.0
	var s = standings[contract.faction]
	if s == null:
		return 0.0
	var net: float = float(s.legitimacy) - float(s.debt)
	# tanh-style soft clip — fast saturation outside [-2, 2].
	return atan(net) / (PI * 0.5)


# ---------------- registry ----------------

static func get_sources() -> Array[Callable]:
	# Order doesn't matter for composition (RY rotations on the same axis
	# commute), but listed roughly biome → world → kernel → standings.
	return [
		Callable(MarketBiasSources, "bias_from_biome_marginal"),
		Callable(MarketBiasSources, "bias_from_world_emoji_mass"),
		Callable(MarketBiasSources, "bias_from_fdm_principal_axis"),
		Callable(MarketBiasSources, "bias_from_player_biome_kernel"),
		Callable(MarketBiasSources, "bias_from_faction_biome_kernel"),
		Callable(MarketBiasSources, "bias_from_player_faction_kernel"),
		Callable(MarketBiasSources, "bias_from_faction_loudness"),
		Callable(MarketBiasSources, "bias_from_standings"),
	]


# ---------------- composition ----------------

static func compose_market_qubit(contract, farm) -> Dictionary:
	# Each source returns a SIGNED bias in [-1, +1], zero at its natural
	# midpoint. We sum, average over count (so total ∈ [-1, +1] no matter how
	# many sources), then map to angle θ ∈ [-π, π] via π·avg. Final marginal
	# uses sin² which is single-valued on this domain.
	#
	# This composition is monotone (more positive bias → higher P_gozouta),
	# bounded (no aliasing), and adding/removing a source changes the angle
	# by at most π/N. It's the right shape for a quantum derivative pricing.
	var sum_bias: float = 0.0
	var count: int = 0
	for src in get_sources():
		var b: float = float(src.call(contract, farm))
		sum_bias += clampf(b, -1.0, 1.0)
		count += 1
	if count == 0:
		return {
			"p_gozinda": 0.5, "p_gozouta": 0.5,
			"off_re": 0.0, "off_im": 0.0, "theta_total": 0.0,
		}
	var avg_bias: float = sum_bias / float(count)
	var theta_total: float = avg_bias * PI                  # [-π, π]
	# Marginal: ρ_11 = sin²(θ/2 + π/4); at θ=0 → 0.5; θ=π → 1; θ=-π → 0.
	var s = sin(theta_total * 0.5 + PI * 0.25)
	var p_gozouta: float = clampf(s * s, 0.0, 1.0)
	var p_gozinda: float = 1.0 - p_gozouta
	# Coherence (real off-diagonal): |⟨0|ρ|1⟩| = |sin(θ)|/2.
	var off_re: float = 0.5 * sin(theta_total)
	return {
		"p_gozinda": p_gozinda,
		"p_gozouta": p_gozouta,
		"off_re": off_re,
		"off_im": 0.0,
		"theta_total": theta_total,
		"avg_bias": avg_bias,
	}
