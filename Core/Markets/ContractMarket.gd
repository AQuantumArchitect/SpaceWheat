class_name ContractMarket
extends RefCounted

## ContractMarket — mythic facade over the native QuantumContractEngine.
##
## The market reads the mythos substrate (faction density, principal mode,
## biome native factions, economy resources) and produces bids. C++ owns the
## math (bid generation, scarcity pricing, overlap kernels, icon payoffs);
## GDScript builds the snapshot from live game state and names the fields
## QuestManager expects.
##
## Responsibilities:
##   - `_init(farm)`                — instantiate the native engine.
##   - `rebuild_snapshot(biome)`    — push fresh state into the engine.
##   - `propose_offers(biome, k)`   — engine bids, shaped as quest dicts.
##   - `quote_vocabulary_option(…)` — single-shot icon option.
##
## Quest lifecycle (accept / active / ready / complete / fail) lives in
## QuestManager. Offer IDs and `offered_at` are stamped by QuestManager after
## `propose_offers` returns.

const NATIVE_CLASS := "QuantumContractEngine"
const FactionAxes = preload("res://Core/Factions/FactionAxes.gd")
const QuestTypes = preload("res://Core/Quests/QuestTypes.gd")
const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")

var _farm = null
var _engine = null  # QuantumContractEngine instance


func _init(farm) -> void:
	_farm = farm
	# Native ships in libquantummatrix.so. If the class is missing the build
	# is broken — refuse to construct rather than spawn a ghost facade.
	assert(ClassDB.class_exists(NATIVE_CLASS),
		"ContractMarket requires native class %s — rebuild native/" % NATIVE_CLASS)
	_engine = ClassDB.instantiate(NATIVE_CLASS)
	assert(_engine != null, "ContractMarket: failed to instantiate %s" % NATIVE_CLASS)


## ========================================
## Snapshot: translate farm state → engine inputs
## ========================================

func rebuild_snapshot(biome = null) -> void:
	_engine.clear()
	_engine.set_time(Time.get_ticks_msec() / 1000.0)
	var biome_bits: Array = _build_biome_bits(biome)
	var native_factions: Array = _native_faction_names(biome)
	_engine.set_biome_bits(biome_bits)
	_engine.set_player_bits(_build_player_bits())
	_engine.set_market_biome_bits(biome_bits, 0.6, 0.5, 0.6)
	_push_spectral_signal()
	var biome_affinity = _build_biome_affinity(biome)
	_push_factions(biome_bits, biome_affinity)
	_push_resources(native_factions)
	_push_icons()


func _native_faction_names(biome) -> Array:
	# Faction signature gate: faction native iff it owns an icon in biome's register.
	const FactionBiomeMap = preload("res://Core/Biomes/FactionBiomeMap.gd")
	if biome == null:
		_verbose("debug", "🪶", "_native_faction_names: no active biome")
		return []
	return FactionBiomeMap.factions_for_biome_by_signature(biome)


func _verbose(level: String, emoji: String, msg: String) -> void:
	# Log via the active farm's VerboseConfig. ContractMarket is a RefCounted,
	# so we can't @onready a logger; resolve at call time through the farm.
	if _farm == null:
		return
	var logger = InstrumentLocator.resolve_verbose_config(_farm)
	if logger == null:
		return
	match level:
		"debug": logger.debug("market", emoji, msg)
		"info": logger.info("market", emoji, msg)
		"warn": logger.warn("market", emoji, msg)
		"error": logger.error("market", emoji, msg)


func _build_biome_bits(biome) -> Array:
	# Project a biome onto the 12-axis manifold via its **signature** (the
	# icons that inhabit it). Each icon resolves to an owner faction (via the
	# IconLexicon); the biome's axial position is the mean of owner factions'
	# axial bits across its signature.

	# If the biome has no resolvable signature (data gap), we fall back to the
	# computed faction roster (atoms ∩ signature) — the loud-not-silent fallback.
	# A biome with neither is a hard data-authoring gap (warned, neutral bits).
	if biome == null:
		return _neutral_bits()
	var bname: String = str(biome.name) if "name" in biome else "<unnamed>"
	var registry = _farm.faction_density.get_registry()

	# Path 1 (canonical): project from biome.signature (icon pairs → owner factions).
	var signature_bits: Array = _build_biome_axial_from_signature(biome, registry)
	if not signature_bits.is_empty():
		return signature_bits

	# Path 2 (fallback): computed faction roster average.
	var native: Array = _native_faction_names(biome)
	if native.is_empty():
		push_warning("ContractMarket: biome '%s' has no signature icons or computed factions; market will see neutral axial position" % bname)
		return _neutral_bits()
	var axis_sums: Array = []
	for i in range(FactionAxes.AXIS_COUNT):
		axis_sums.append(0.0)
	var counted: int = 0
	for fname in native:
		var f = registry.get_by_name(str(fname))
		if f == null:
			continue
		for i in range(FactionAxes.AXIS_COUNT):
			if i < f.get_axial_bits().size():
				axis_sums[i] += float(f.get_axial_bits()[i])
		counted += 1
	if counted == 0:
		push_warning("ContractMarket: biome '%s' computed factions resolved to 0 known factions" % bname)
		return _neutral_bits()
	var bits: Array = []
	for i in range(FactionAxes.AXIS_COUNT):
		bits.append(axis_sums[i] / float(counted))
	return bits


func _build_biome_axial_from_signature(biome, registry) -> Array:
	# Project biome.signature (icon pairs) onto 12 axes via owner factions.
	# Returns [] if the biome has no signature or no resolvable owners — caller
	# then falls back to native_factions.
	var pairs: Array = _biome_signature_pairs(biome)
	if pairs.is_empty() or _farm == null:
		return []
	var lex = _farm._ensure_icon_lexicon() if _farm.has_method("_ensure_icon_lexicon") else null
	if lex == null:
		return []
	var axis_sums: Array = []
	for i in range(FactionAxes.AXIS_COUNT):
		axis_sums.append(0.0)
	var counted: int = 0
	for pair in pairs:
		var p0: String = str(pair.get("pole_0", ""))
		var p1: String = str(pair.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var icon: Dictionary = lex.find_icon_by_pair(p0, p1)
		var owner: String = str(icon.get("owner_faction", "")) if not icon.is_empty() else ""
		if owner == "":
			continue
		var f = registry.get_by_name(owner)
		if f == null:
			continue
		for i in range(FactionAxes.AXIS_COUNT):
			if i < f.get_axial_bits().size():
				axis_sums[i] += float(f.get_axial_bits()[i])
		counted += 1
	if counted == 0:
		return []
	var bits: Array = []
	for i in range(FactionAxes.AXIS_COUNT):
		bits.append(axis_sums[i] / float(counted))
	return bits


static func _biome_signature_pairs(biome) -> Array:
	# Read biome.signature (icon pairs) tolerant of both wrapper shapes:
	# live BiomeBase exposes `icons`/`get_signature_pairs`; data Biome stores
	# dicts in `_biome_data.icons`.
	if biome == null:
		return []
	if biome.has_method("get_signature_pairs"):
		return biome.get_signature_pairs()
	var out: Array = []
	# Preferred: live biome exposes qubit axes via register_map
	if "quantum_computer" in biome and biome.quantum_computer:
		var qc = biome.quantum_computer
		if qc and "register_map" in qc and qc.register_map:
			var axes = qc.register_map.axes
			if axes is Dictionary:
				for _idx in axes:
					var ax = axes[_idx]
					if ax is Dictionary:
						var p0 = str(ax.get("north", ""))
						var p1 = str(ax.get("south", ""))
						if p0 != "" and p1 != "":
							out.append({"pole_0": p0, "pole_1": p1})
				return out
	# Fallback: data Biome stores pairs in _biome_data.icons as Array
	var raw_icons = null
	if "_biome_data" in biome and biome._biome_data:
		raw_icons = biome._biome_data.get("icons", [])
	if not (raw_icons is Array):
		return out
	for icon in raw_icons:
		if not (icon is Dictionary):
			continue
		var p0: String = str(icon.get("pole_0", ""))
		var p1: String = str(icon.get("pole_1", ""))
		if p0 != "" and p1 != "":
			out.append({"pole_0": p0, "pole_1": p1})
	return out




static func _neutral_bits() -> Array:
	var b: Array = []
	for i in range(FactionAxes.AXIS_COUNT):
		b.append(0.5)
	return b


func _build_player_bits() -> Array:
	# Read the player's axial position directly from `farm.player_affinity`
	# (a 12-qubit AffinityGraph, see Core/Affinity/AffinityGraph.gd). Each axis
	# yields a value in [0, 1] = P(bit=1) under the marginal of the player's ρ.
	# Player starts at |+⟩^⊗12 → all 0.5; drifts under icon learns and
	# settlements. The market reads it as the canonical stance; no proxy.
	if _farm == null or not ("player_affinity" in _farm) or _farm.player_affinity == null:
		_verbose("debug", "🪶", "_build_player_bits: no farm/player_affinity yet — neutral bits")
		var neutral: Array = []
		for i in range(FactionAxes.AXIS_COUNT):
			neutral.append(0.5)
		return neutral
	var pa = _farm.player_affinity
	var result: Array = []
	for i in range(FactionAxes.AXIS_COUNT):
		var pt: Dictionary = pa.partial_trace_axis(i)
		var p1: float = float(pt.get("p1", 0.5))
		result.append(clampf(p1, 0.0, 1.0))
	return result


func _push_spectral_signal() -> void:
	# Feed the market a real spectral signal derived from the mythos engine's
	# Hamiltonian eigensolve. This is what makes 'the market listens to the
	# tape' literal — the tape is the Hamiltonian the factions are writing.
	var dominant: float = 1.0
	var gap: float = 0.25
	var volatility: float = 0.2
	var confidence: float = 0.5
	# True direction bits: dominant eigenvector of ρ_factions projected onto the
	# 12 axial dimensions. This is the market's read of "where the mythos is
	# currently leaning" — not a proxy, the actual principal mode axis footprint.
	var direction_bits: Array = _build_player_bits()

	if _farm and "faction_density" in _farm and _farm.faction_density != null:
		var fdm = _farm.faction_density
		if fdm.has_method("get_hamiltonian_eigen_summary"):
			var summary: Dictionary = fdm.get_hamiltonian_eigen_summary(12)
			var eigenvalues = summary.get("eigenvalues", null)
			if eigenvalues != null and eigenvalues.size() > 0:
				dominant = absf(float(eigenvalues[0]))
				if eigenvalues.size() >= 2:
					gap = absf(float(eigenvalues[0]) - float(eigenvalues[1]))
				volatility = _eigenvalue_volatility(eigenvalues)
				# Residual is solver quality; invert for "confidence"
				var residual: float = float(summary.get("residual", 1.0))
				confidence = clampf(1.0 - residual, 0.0, 1.0)
		if fdm.has_method("get_principal_axis_projection"):
			var proj: Array = fdm.get_principal_axis_projection()
			if proj.size() >= FactionAxes.AXIS_COUNT:
				direction_bits = proj

	_engine.set_spectral_signal(dominant, gap, volatility, confidence, direction_bits)


func _eigenvalue_volatility(eigenvalues) -> float:
	var n = eigenvalues.size() if eigenvalues else 0
	if n < 2:
		return 0.0
	var sum: float = 0.0
	var sum_sq: float = 0.0
	for v in eigenvalues:
		var m: float = absf(float(v))
		sum += m
		sum_sq += m * m
	var mean: float = sum / float(n)
	var variance: float = maxf((sum_sq / float(n)) - mean * mean, 0.0)
	return sqrt(variance)


func _push_factions(biome_bits: Array, biome_affinity = null) -> void:
	# Push every faction into the market engine. Attention is derived from
	# the substrate via the kernel:

	# attention = density(f) + Tr(ρ_f · ρ_biome)

	# where ρ_f is the faction's AffinityGraph and ρ_biome is an equal-weight
	# mixture of the affinities of the factions that own the biome's signature
	# icons. Identical states → overlap 1.0; orthogonal corners → 0. This is
	# the same Hilbert-space inner product the player ↔ faction kernel uses;
	# one math, one path.

	# If `biome_affinity` is null (biome with no resolvable signature owners),
	# we fall back to the 12-vec axial-overlap on `biome_bits` so the engine
	# still gets a relative attention signal.

	# density(f) = ρ[f,f] from the faction-density facade; sum is in [0, 1+1/F];
	# the market engine uses it as a relative-attention weight. Standing modifier
	# is the player's per-faction reputation scalar.
	var density = _farm.faction_density
	var registry = density.get_registry()
	var standings: Dictionary = _farm.faction_standings
	for f in registry.get_all():
		var bits: Array = []
		for b in f.get_axial_bits():
			bits.append(float(b))
		var overlap: float
		if biome_affinity != null and f.affinity != null:
			overlap = f.affinity.overlap(biome_affinity)
		else:
			overlap = _axial_overlap(bits, biome_bits)
		var attention: float = density.get_weight(f.name) + overlap
		var standing: float = 0.0
		if standings.has(f.name):
			standing = standings[f.name].scalar()
		_engine.add_faction(str(f.name), bits, attention, standing)
		_engine.set_faction_hamiltonian_drive(str(f.name), density.get_weight(f.name))


func _build_biome_affinity(biome):
	# Build the biome's ρ on the 12-axis Hilbert space as an equal-weight
	# mixture of its signature icons' owner factions' affinities. Returns null
	# if no signature pairs resolve to known owner factions (caller falls back
	# to the bit-vec overlap path).

	# This is a low-rank ρ — at most one ket per signature icon, often fewer
	# since multiple icons may share an owner. The kernel Tr(ρ_f · ρ_biome)
	# then collapses to a weighted sum of |⟨f|owner⟩|² inner products.
	if biome == null or _farm == null:
		return null
	var pairs: Array = _biome_signature_pairs(biome)
	if pairs.is_empty():
		return null
	var lex = _farm._ensure_icon_lexicon() if _farm.has_method("_ensure_icon_lexicon") else null
	if lex == null:
		return null
	var registry = _farm.faction_density.get_registry()
	var owners: Array = []  # owner faction names, with duplicates → weight
	for pair in pairs:
		var p0: String = str(pair.get("pole_0", ""))
		var p1: String = str(pair.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var icon: Dictionary = lex.find_icon_by_pair(p0, p1)
		if icon.is_empty():
			continue
		var owner: String = str(icon.get("owner_faction", ""))
		if owner == "":
			continue
		owners.append(owner)
	if owners.is_empty():
		return null
	# Build the mixture by repeated lindblad_jump_toward — each owner contributes
	# an equal share. This handles duplicate owners correctly (their kets merge).
	var AffinityGraphCls = load("res://Core/Affinity/AffinityGraph.gd")
	var bg = AffinityGraphCls.from_uniform_superposition()
	# Replace uniform with the first owner, then mix in the rest equally.
	var first_owner: String = owners[0]
	var first_f = registry.get_by_name(first_owner)
	if first_f == null or first_f.affinity == null:
		return null
	bg = AffinityGraphCls.from_dict(first_f.affinity.to_dict())
	for i in range(1, owners.size()):
		var f = registry.get_by_name(owners[i])
		if f == null or f.affinity == null:
			continue
		# Equal-weight running mix: at step i, new owner gets weight 1/(i+1)
		bg.lindblad_jump_toward(f.affinity, 1.0 / float(i + 1))
	return bg


static func _axial_overlap(faction_bits: Array, biome_bits: Array) -> float:
	# Mean axial agreement between a faction's bit vector and a biome's
	# axial position. Both arrays are length AXIS_COUNT; faction bits are 0/1
	# (stored as float), biome bits are continuous in [0,1]. Returns 1 - mean(|Δ|)
	# per axis, in [0,1]. No tuning constants — this IS the alignment measurement.
	var n: int = min(faction_bits.size(), biome_bits.size())
	if n == 0:
		return 0.0
	var diff_sum: float = 0.0
	for i in range(n):
		diff_sum += absf(float(faction_bits[i]) - float(biome_bits[i]))
	return 1.0 - (diff_sum / float(n))


func _push_resources(native_factions: Array) -> void:
	# Push the resource ledger to the engine.

	# Supply  = current credits in the player's economy.
	# Demand  = local mythos echo: count of biome-native factions whose signature
	# contains the emoji. An emoji spoken by many of THIS BIOME's
	# factions is in-demand here; one no native speaks is not bid on
	# here. No global demand multiplier — the count IS the demand.
	# Velocity/volatility = 0 (no temporal tracker upstream).

	# When a biome has no native_factions (rare, data gap), demand collapses to
	# 0 across the board and no bids are generated for that biome — correct
	# behavior since the market has no axial position to anchor to.
	var resources: Dictionary = _farm.economy.get_all_resources()
	var demand_map: Dictionary = _build_demand_from_natives(native_factions)
	for emoji in resources:
		var supply: float = float(resources[emoji])
		var demand: float = float(demand_map.get(emoji, 0.0))
		_engine.set_resource(str(emoji), supply, demand, 0.0, 0.0)


func _build_demand_from_natives(native_factions: Array) -> Dictionary:
	# Demand[emoji] = count of biome-native factions whose sig contains emoji.
	# The biome's own residents are who's asking for things in their own market.
	var out: Dictionary = {}
	if native_factions.is_empty():
		return out
	var registry = _farm.faction_density.get_registry()
	for fname in native_factions:
		var f = registry.get_by_name(str(fname))
		if f == null:
			continue
		for emoji in f.signature:
			var key := str(emoji)
			out[key] = float(out.get(key, 0.0)) + 1.0
	return out


func _push_icons() -> void:
	if _farm == null:
		return
	var lex = _farm.icon_lexicon if "icon_lexicon" in _farm else null
	if lex == null and _farm.has_method("_ensure_icon_lexicon"):
		lex = _farm._ensure_icon_lexicon()
	if lex == null:
		return
	# Cache the registry once; lookups are O(1) but we repeat for every icon.
	var registry = null
	if _farm and "faction_density" in _farm and _farm.faction_density != null:
		registry = _farm.faction_density.get_registry()

	for icon in lex.get_all_world_built():
		var p0: String = str(icon.get("pole_0", ""))
		var p1: String = str(icon.get("pole_1", ""))
		var name: String = str(icon.get("name", ""))
		var faction: String = str(icon.get("owner_faction", ""))
		if p0 == "" or p1 == "":
			continue
		# Icon bits: use owner faction's bits (concrete axial position) when
		# available. Orphan/axial/anonymous icons fall back to neutral 0.5s.
		var bits: Array = []
		if faction != "" and registry != null:
			var f = registry.get_by_name(faction)
			if f != null:
				for i in range(FactionAxes.AXIS_COUNT):
					if i < f.get_axial_bits().size():
						bits.append(float(f.get_axial_bits()[i]))
					else:
						bits.append(0.5)
		if bits.is_empty():
			for i in range(FactionAxes.AXIS_COUNT):
				bits.append(0.5)
		_engine.add_icon(name, p0, p1, faction, bits)


## ========================================
## Offers
## ========================================

func propose_offers(biome, max_per_faction: int = 2) -> Array:
	# Rebuild snapshot, ask the engine for bids, adapt to quest dicts.
	# Returns [] when the farm has no economy resources — the market only
	# bids on emojis that actually exist in the world.
	rebuild_snapshot(biome)
	var resources: Array = []
	for emoji in _farm.economy.get_all_resources():
		resources.append(str(emoji))
	if resources.is_empty():
		_verbose("debug", "🪶", "propose_offers: economy has no resources yet — no bids")
		return []
	var raw: Array = _engine.generate_resource_bids(resources, max_per_faction)
	var adapted: Array = []
	for offer in raw:
		if offer is Dictionary:
			adapted.append(_offer_to_quest_dict(offer, biome))
	return adapted


## ========================================
## Adapter: native offer → QuestManager quest dict
## ========================================

func _fix_c_str_mojibake(s: String) -> String:
	# C++ contract_to_dict uses String(c_str()) which treats UTF-8 bytes as Latin-1.
	# Fix: treat each char's code point (0-255) as a raw byte, re-decode as UTF-8.
	if s.is_empty():
		return s
	var bytes := PackedByteArray()
	for i in s.length():
		var cp: int = s.unicode_at(i)
		if cp > 255:
			return s  # already valid Unicode, not mojibake
		bytes.append(cp)
	var fixed: String = bytes.get_string_from_utf8()
	return fixed if not fixed.is_empty() else s


func _offer_to_quest_dict(offer: Dictionary, biome) -> Dictionary:
	var faction_name: String = str(offer.get("faction", "Unknown"))
	var resource: String = _fix_c_str_mojibake(str(offer.get("resource", "")))
	var quantity: int = int(ceil(float(offer.get("quantity", 0.0))))
	var biome_name: String = str(biome.name) if biome and "name" in biome else ""

	# Faction metadata (for display) — pull from registry
	var faction_dict: Dictionary = _faction_metadata(faction_name)

	var quest: Dictionary = {
		# status/id are stamped by QuestManager after adapter returns
		"status": "offered",
		"biome": biome_name,
		"biome_name": biome_name,
		"faction": faction_name,
		"faction_emoji": _signature_prefix(faction_dict, 3),
		"faction_signature": faction_dict.get("signature", []),
		"faction_vocabulary": faction_dict.get("signature", []),
		"motto": faction_dict.get("motto"),
		"domain": faction_dict.get("domain", ""),
		"ring": faction_dict.get("ring", "center"),
		"description": faction_dict.get("description", ""),
		"banner_path": "",
		"type": QuestTypes.Type.DELIVERY,
		"time_limit": float(offer.get("expiry_seconds", 300.0)),
		"resource": resource,
		"quantity": quantity,
		"reward_multiplier": clampf(float(offer.get("market_score", 1.0)), 1.0, 5.0),
		"reward_resources": {resource: quantity},
		"available_emojis": faction_dict.get("signature", []),
		"is_biome_native": false,
		"biome_new": false,
		"market_projection": {
			"resource": resource,
			"base_cost": quantity,
			"effective_cost": quantity,
			"multiplier": 1.0,
			"market_score": float(offer.get("market_score", 0.0)),
			"directional_edge": float(offer.get("directional_edge", 0.0)),
			"scarcity": float(offer.get("scarcity", 0.0)),
			"alignment": float(offer.get("alignment", 0.0)),
		},
		"bits": faction_dict.get("bits", []),
		"_alignment": float(offer.get("alignment", 0.0)),
		"_intensity": float(offer.get("market_score", 0.0)),
		"_complexity": float(offer.get("scarcity", 0.0)),
		"_urgency": float(offer.get("directional_edge", 0.0)),
		"_variety": 0.5,
		"_preferences": "",
		"_observables": "",
		# Display text (QuestTheming would normally produce this; we synthesize)
		"body": "%s: deliver %d %s" % [faction_name, quantity, resource],
		"full_text": "",  # QuestManager finalizes this
		# Market provenance marker — helps telemetry distinguish sources
		"source": "contract_market",
		"market_offer_id": int(offer.get("id", -1)),
		"market_explanation": offer.get("explanation", []),
	}
	quest["full_text"] = quest["body"]
	return quest


func _faction_metadata(name: String) -> Dictionary:
	# Adapter helper: enrich an offer with faction display metadata.
	# The native engine just emitted this name — failure to resolve it is a
	# registry/engine sync bug, not a 'not ready yet' state.
	assert(_farm != null and "faction_density" in _farm and _farm.faction_density != null,
		"ContractMarket: _faction_metadata called without farm/density — invariant broken")
	var registry = _farm.faction_density.get_registry()
	assert(registry != null, "ContractMarket: faction_density returned null registry")
	var f = registry.get_by_name(name)
	if f == null:
		push_warning("ContractMarket: native engine emitted unknown faction '%s' — registry/engine out of sync" % name)
		return {}
	var bits_arr: Array = []
	for b in f.get_axial_bits():
		bits_arr.append(int(b))
	return {
		"signature": f.signature.duplicate(),
		"motto": f.get("motto") if "motto" in f else null,
		"domain": f.get("domain") if "domain" in f else "",
		"ring": f.ring if "ring" in f else "center",
		"description": f.description if "description" in f else "",
		"bits": bits_arr,
	}


func _signature_prefix(faction_dict: Dictionary, n: int) -> String:
	var sig: Array = faction_dict.get("signature", [])
	var out := ""
	for i in range(min(n, sig.size())):
		out += str(sig[i])
	return out


