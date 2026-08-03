extends "res://tests/smoke_test_base.gd"


class FakeVizCache extends RefCounted:
	func has_metadata() -> bool:
		return true

	func get_self_energies(_time: float = 0.0) -> Dictionary:
		return {"🌾": 0.12, "🌿": 0.37, "🍂": 0.18}

	func get_hamiltonian_couplings(emoji: String) -> Dictionary:
		if emoji == "🌾":
			return {"🌿": 0.21, "🍂": 0.09}
		if emoji == "🌿":
			return {"🌾": 0.21}
		return {}


class FakeBiome extends RefCounted:
	var viz_cache = FakeVizCache.new()

	func get_biome_type() -> String:
		return "TestBiome"


class FakeGeometryBatcher extends RefCounted:
	var circles: int = 0
	var arcs: int = 0

	func add_circle(_center: Vector2, _radius: float, _color: Color) -> void:
		circles += 1

	func add_arc(_center: Vector2, _radius: float, _from_angle: float, _to_angle: float, _width: float, _color: Color) -> void:
		arcs += 1


func _init() -> void:
	print("\n=== Bubble rendering cleanup smoke ===")

	_test_lifeless_nodes_stay_hidden()
	_test_radius_tracks_bloch_not_purity()
	_test_spawn_lane_is_gone()
	_test_projection_field_payload_and_draw()

	_finish()


func _test_lifeless_nodes_stay_hidden() -> void:
	var node = QuantumNode.new()
	node.start_spawn_animation(0.0)
	node.apply_lifeless_visual({"north": "🌾", "south": "🌿"})
	node.update_animation(1.0, 0.016)

	_check(node.is_lifeless, "lifeless state is marked")
	_check(not node.is_spawning, "lifeless state cancels spawn animation")
	_check(_approx(node.visual_scale, 0.0), "lifeless node has zero visual scale")
	_check(_approx(node.visual_alpha, 0.0), "lifeless node has zero alpha")
	_check(_approx(node.emoji_north_opacity, 0.0) and _approx(node.emoji_south_opacity, 0.0), "lifeless node does not render extra emoji")


func _test_radius_tracks_bloch_not_purity() -> void:
	var node = QuantumNode.new()
	var snap_a = {
		"p0": 0.75,
		"p1": 0.25,
		"r_xy": 0.4,
		"phi": 0.1,
		"purity": 0.15,
		"r_bloch": 0.22,
	}
	var snap_b = snap_a.duplicate(true)
	snap_b["purity"] = 0.95
	var snap_c = snap_a.duplicate(true)
	snap_c["r_bloch"] = 0.78

	_check(node.apply_quantum_snapshot(snap_a, false), "snapshot A applies")
	var radius_a = node.radius
	var purity_a = node.purity

	_check(node.apply_quantum_snapshot(snap_b, false), "snapshot B applies")
	var radius_b = node.radius
	var purity_b = node.purity

	_check(node.apply_quantum_snapshot(snap_c, false), "snapshot C applies")
	var radius_c = node.radius

	_check(_approx(radius_a, radius_b, 1e-6), "radius ignores purity changes when r_bloch is fixed")
	_check(not _approx(radius_a, radius_c, 1e-6), "radius changes when Bloch radius changes")
	_check(purity_a < purity_b, "purity is tracked separately from radius")


func _test_projection_field_payload_and_draw() -> void:
	var node = QuantumNode.new()
	node.visible = true
	node.biome_name = "TestBiome"
	node.register_id = 0
	node.emoji_north = "🌾"
	node.emoji_south = "🌿"

	var builder = QuantumProjectionBuilder.new()
	var biome = FakeBiome.new()
	var payload = builder.build_self_energy_projection_from_cache([node], biome.viz_cache, "🌾", 0.0)

	_check(payload.get("basis", "") == "self_energy", "projection builder returns self-energy basis")
	_check(payload.get("contours", []).size() > 0, "projection builder returns contours")
	_check(int(payload.get("contours", [])[0].get("density", 0)) > 0, "projection contour includes density")

	var renderer = QuantumProjectionFieldRenderer.new()
	var batcher = FakeGeometryBatcher.new()
	renderer.draw(Node2D.new(), {
		"projection_payloads": {"TestBiome": payload},
		"geometry_batcher": batcher,
	})

	_check(batcher.circles > 0, "projection field draw emits filled circles")
	_check(batcher.arcs > 0, "projection field draw emits arcs")

	var graph = QuantumForceGraph.new()
	graph._initialize_components()
	graph.biomes = {"TestBiome": biome}
	graph.quantum_nodes = [node]
	graph._update_projection_payloads()
	var ctx = graph._build_context()
	_check(ctx.get("projection_payloads", {}).has("TestBiome"), "force graph context exposes projection payloads")


func _test_spawn_lane_is_gone() -> void:
	var graph = QuantumForceGraph.new()
	_check(not graph.life_cycle_effects.has("spawns"), "spawn lane is removed from graph life cycle effects")
	graph.add_life_cycle_effect("spawns", {"position": Vector2.ZERO, "color": Color.GREEN})
	_check(not graph.life_cycle_effects.has("spawns"), "spawn effect requests are ignored")

	var renderer = QuantumEffectsRenderer.new()
	var batcher = FakeGeometryBatcher.new()
	renderer.draw(Node2D.new(), {
		"life_cycle_effects": {
			"spawns": [{"position": Vector2(10, 10), "time": 0.0, "color": Color.GREEN}],
			"deaths": [],
			"strikes": [],
		},
		"geometry_batcher": batcher,
	})
	_check(batcher.circles == 0 and batcher.arcs == 0, "spawn-only life cycle effects do not draw")


func _approx(a: float, b: float, tol: float = 1e-4) -> bool:
	return absf(a - b) <= tol
