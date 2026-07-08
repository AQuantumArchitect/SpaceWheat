class_name QuantumRegionRenderer
extends RefCounted

## Quantum Region Renderer
##
## Mini-Metro pass (2026-07-07): the default view draws NO region chrome — the
## flat BiomeBackground zone (color field + silhouette + live quantum tint) is
## the biome's ambient identity. This renderer only forwards to a biome's
## custom rendering callback if one exists. The temperature heatmap and orbit
## trails were deleted with the force-drift layout (stations don't orbit, and
## sink-flux heat belongs in the B microscope).


func draw(graph: Node2D, ctx: Dictionary) -> void:
	_draw_biome_regions(graph, ctx)


func _draw_biome_regions(graph: Node2D, ctx: Dictionary) -> void:
	# Ovals removed long ago (BiomeBackground owns zone identity). Only calls a
	# biome's custom rendering callback if present.
	var biomes = ctx.get("biomes", {})
	var layout_calculator = ctx.get("layout_calculator")
	var active_biome = ctx.get("active_biome", "")
	var center_position = ctx.get("center_position", Vector2.ZERO)

	if not layout_calculator:
		return

	for biome_name in biomes:
		# Skip non-active biomes in single-biome view
		if active_biome != "" and biome_name != active_biome:
			continue

		var biome_obj = biomes[biome_name]

		var oval = layout_calculator.get_biome_oval(biome_name)
		if oval.is_empty():
			continue

		var biome_center = oval.get("center", center_position)
		var semi_a = oval.get("semi_a", 100.0)
		var semi_b = oval.get("semi_b", 60.0)

		var biome_radius = (semi_a + semi_b) / 2.0
		if biome_obj and biome_obj.has_method("render_biome_content"):
			biome_obj.render_biome_content(graph, biome_center, biome_radius)
