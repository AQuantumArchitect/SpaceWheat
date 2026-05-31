class_name BiomeDiscoveryForecastService
extends RefCounted

## Biome discovery weighting — pure substrate overlap.
##
## The player is mechanically a faction: their player_alignment is a running
## mixture of the factions they've dealt with, drifting via the same RY
## rotation that updates faction affinities. A biome's affinity is the
## mixture of its owner factions' affinities.
##
## Discovery weight = overlap(player_alignment, biome_alignment).
##
## No hand-crafted vocab gates, no magic weight scales, no heuristics.
## The graph does the routing. A player who has never touched maritime factions
## has near-zero overlap with SaltRunners — it stays low probability naturally.
## As they cultivate maritime standing, SaltRunners rises. One mechanic.

const BiomeRegistryClass = preload("res://Core/Biomes/BiomeRegistry.gd")
const AlignmentGraphCls = preload("res://Core/Alignment/AlignmentGraph.gd")

## Small floor so every biome remains discoverable at low probability even
## before the player has cultivated any affinity toward it. This preserves
## genuine exploration at session start (uniform superposition → equal overlap).
const FLOOR = 0.05

## Mutable overrides for rig/test configure_discovery.
static var _weights: Dictionary = {}

static func configure(weights: Dictionary) -> void:
	_weights = weights.duplicate()

static func _w(key: String, default: float) -> float:
	return float(_weights[key]) if _weights.has(key) else default


# ---------------------------------------------------------------------------

static func compute_weights(farm, unexplored: Array) -> Array[float]:
	var weights: Array[float] = []
	if not farm:
		return weights

	var player_alignment = farm.player_alignment if "player_alignment" in farm else null
	var w_floor = _w("floor", FLOOR)

	for biome_name in unexplored:
		var biome_alignment = _biome_alignment_from_name(biome_name, farm)
		var alignment := 0.0
		if player_alignment != null and biome_alignment != null:
			alignment = player_alignment.overlap(biome_alignment)
		weights.append(w_floor + alignment)

	return weights


static func _biome_alignment_from_name(biome_name: String, farm) -> Object:
	# Build an AlignmentGraph for an unloaded biome from its icon pair owners.
	# Biome affinity = equal-weight mixture of owner factions' corner states —
	# same formula MarketLattice/_biome_affinity math uses on live biomes.
	var registry := BiomeRegistryClass.new()
	var biome_data = registry.get_by_name(biome_name)
	if biome_data == null:
		return null

	var raw_icons: Array = biome_data.get_neighborhood_icons() if biome_data.has_method("get_neighborhood_icons") else []
	if raw_icons.is_empty():
		return null

	var lex = farm._ensure_icon_atlas() if farm.has_method("_ensure_icon_atlas") else null
	if lex == null:
		return null

	var fdm = farm.faction_density if "faction_density" in farm and farm.faction_density != null else null
	if fdm == null:
		return null
	var faction_registry = fdm.get_registry()
	if faction_registry == null:
		return null

	var owners: Array = []
	for icon in raw_icons:
		if not (icon is Dictionary):
			continue
		var p0 := str(icon.get("pole_0", ""))
		var p1 := str(icon.get("pole_1", ""))
		if p0 == "" or p1 == "":
			continue
		var owner: String = lex.get_primary_faction_for_pair(p0, p1)
		if owner != "":
			owners.append(owner)

	if owners.is_empty():
		return null

	var first_f = faction_registry.get_by_name(owners[0])
	if first_f == null or first_f.alignment == null:
		return null
	var bg = AlignmentGraphCls.from_dict(first_f.alignment.to_dict())
	for i in range(1, owners.size()):
		var f = faction_registry.get_by_name(owners[i])
		if f == null or f.alignment == null:
			continue
		bg.lindblad_jump_toward(f.alignment, 1.0 / float(i + 1))
	return bg


static func weighted_random_pick(items: Array, weights: Array[float]) -> Variant:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return items[randi() % items.size()]
	var roll := randf() * total
	var cumulative := 0.0
	for i in range(items.size()):
		cumulative += weights[i]
		if roll <= cumulative:
			return items[i]
	return items[items.size() - 1]


static func compute_forecast(farm) -> Dictionary:
	if not farm:
		return {}
	var observation_frame = (Engine.get_main_loop().root.get_node_or_null("/root/ObservationFrame") if Engine.get_main_loop() and Engine.get_main_loop().root else null)
	if not observation_frame:
		return {}
	var unexplored: Array = observation_frame.get_unexplored_biomes()
	if unexplored.is_empty():
		return {}
	var weights := compute_weights(farm, unexplored)
	var total := 0.0
	for w in weights:
		total += w
	var forecast: Dictionary = {}
	for i in range(unexplored.size()):
		forecast[unexplored[i]] = {
			"weight": weights[i],
			"probability": weights[i] / total if total > 0.0 else 0.0,
		}
	return forecast
