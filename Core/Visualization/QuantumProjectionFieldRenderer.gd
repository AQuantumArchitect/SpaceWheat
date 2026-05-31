class_name QuantumProjectionFieldRenderer
extends RefCounted


## Draws semantic projection fields behind relationship edges and bubbles.
##
## This renderer consumes prepared projection records. It should not query the
## quantum computer directly or reinterpret raw cache data.


func draw(graph: Node2D, ctx: Dictionary) -> void:
	var projections: Dictionary = ctx.get("projection_payloads", {})
	if projections.is_empty():
		return

	for biome_name in projections.keys():
		var projection: Dictionary = projections.get(biome_name, {})
		if projection.get("basis", "") == "self_energy":
			_draw_self_energy_projection(graph, projection, ctx)


func _draw_self_energy_projection(graph: Node2D, projection: Dictionary, ctx: Dictionary) -> void:
	var contours: Array = projection.get("contours", [])
	if contours.is_empty():
		return

	var batcher = ctx.get("geometry_batcher")
	var energy_min := float(projection.get("min_energy", 0.0))
	var energy_max := float(projection.get("max_energy", energy_min))
	var energy_span = maxf(absf(energy_max - energy_min), 0.0001)

	for contour in contours:
		var center: Vector2 = contour.get("center", Vector2.ZERO)
		var radius := float(contour.get("radius", 0.0))
		if radius <= 0.5:
			continue

		var band := int(contour.get("band", 0))
		var band_count := maxi(1, int(contour.get("band_count", 1)))
		var density := int(contour.get("density", 1))
		var energy := float(contour.get("energy", 0.0))
		var normalized_energy = clampf((energy - energy_min) / energy_span, 0.0, 1.0)
		var band_t = float(band) / maxf(float(band_count - 1), 1.0)

		var color := _contour_color(normalized_energy, band_t, density)
		var fill := color
		fill.a *= 0.18
		var stroke := color
		stroke.a *= 0.72
		var outer := color
		outer.a *= 0.28

		if batcher:
			batcher.add_circle(center, radius, fill)
			batcher.add_arc(center, radius, 0.0, TAU, _stroke_width(density), stroke)
			batcher.add_arc(center, radius + 6.0, 0.0, TAU, 1.0, outer)
		else:
			graph.draw_circle(center, radius, fill)
			graph.draw_arc(center, radius, 0.0, TAU, 48, stroke, _stroke_width(density), true)
			graph.draw_arc(center, radius + 6.0, 0.0, TAU, 48, outer, 1.0, true)


func _contour_color(normalized_energy: float, band_t: float, density: int) -> Color:
	# Low to high energy uses a restrained cyan -> gold ramp that stays distinct
	# from phi's full hue wheel.
	var low := Color(0.20, 0.72, 0.86, 1.0)
	var high := Color(0.96, 0.76, 0.22, 1.0)
	var color := low.lerp(high, normalized_energy)
	var density_boost = clampf(log(float(maxi(density, 1)) + 1.0) / 3.0, 0.0, 0.35)
	color = color.lightened(density_boost)
	color.a = 0.16 + band_t * 0.08
	return color


func _stroke_width(density: int) -> float:
	return clampf(1.2 + sqrt(float(maxi(density, 1))) * 0.45, 1.5, 4.0)
