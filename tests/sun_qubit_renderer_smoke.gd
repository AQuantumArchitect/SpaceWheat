extends "res://tests/smoke_test_base.gd"


class FakeAtlas extends RefCounted:

	func is_atlas_built() -> bool:
		return false


func _init() -> void:
	print("\n=== Sun qubit renderer smoke ===")

	var biome = BiomeBase.new()
	var graph = QuantumForceGraph.new()
	graph._initialize_components()
	graph.setup({"BioticFlux": biome}, null, null)
	_check(graph.biotic_flux_biome == biome, "BioticFlux biome is recognized by name")

	var node_manager = QuantumNodeManager.new()
	var sun_node = node_manager.create_sun_qubit_node(biome, null)
	_check(sun_node != null, "sun qubit node is created")
	if sun_node != null:
		_check(sun_node.visible, "sun qubit node starts visible")
		_check(sun_node.quantum_behavior == 2, "sun qubit node is fixed/celestial")
		_check(sun_node.emoji_north != "" and sun_node.emoji_south != "", "sun qubit node has fallback emojis")

	var renderer = BatchedBubbleRenderer.new()
	renderer.draw_sun_qubit(Node2D.new(), {
		"sun_qubit_node": sun_node,
		"bubble_atlas_batcher": FakeAtlas.new(),
	})
	_check(true, "sun qubit draw hook returns cleanly")

	_finish()
