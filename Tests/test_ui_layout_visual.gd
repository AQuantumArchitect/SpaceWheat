#!/usr/bin/env -S godot -s
## Test script for UI layout visual validation
## This tests the parametric layout system at multiple resolutions

extends SceneTree

var test_resolutions = [
	{"name": "800×600 (Minimum)", "size": Vector2(800, 600)},
	{"name": "1920×1080 (Baseline)", "size": Vector2(1920, 1080)},
	{"name": "2560×1440 (QHD)", "size": Vector2(2560, 1440)},
	{"name": "3840×2160 (4K)", "size": Vector2(3840, 2160)},
]

var results = []

func _init():
	print("\n" + "=".repeat(70))
	print("🧪 UI LAYOUT VISUAL VALIDATION TEST")
	print("=".repeat(70))
	print("")

	# Run tests for each resolution
	for res_config in test_resolutions:
		var test_name = res_config["name"]
		var test_size = res_config["size"]

		print("─" * 70)
		print("Testing: %s" % test_name)
		print("─" * 70)

		var layout_manager = UILayoutManager.new()

		# Simulate viewport resize
		layout_manager.viewport_size = test_size
		layout_manager._calculate_scale_factor()
		layout_manager._calculate_layout_dimensions()

		var test_result = {
			"name": test_name,
			"viewport_size": test_size,
			"scale_factor": layout_manager.scale_factor,
			"breakpoint": layout_manager.current_breakpoint,
			"top_bar_height": layout_manager.top_bar_height,
			"bottom_bar_height": layout_manager.bottom_bar_height,
			"play_area": layout_manager.play_area_rect,
			"errors": []
		}

		# Validate layout dimensions
		var top_bar_percent = layout_manager.top_bar_height / test_size.y
		var bottom_bar_percent = layout_manager.bottom_bar_height / test_size.y
		var play_area_percent = layout_manager.play_area_rect.size.y / test_size.y

		print("  Viewport Size: %s" % [test_size])
		print("  Scale Factor: %.2f" % layout_manager.scale_factor)
		print("  Breakpoint: %s" % UILayoutManager.ScaleBreakpoint.keys()[layout_manager.current_breakpoint])
		print("")

		print("  Layout Dimensions:")
		print("    Top bar height: %dpx (%.1f%% of viewport)" % [int(layout_manager.top_bar_height), top_bar_percent * 100])
		print("    Play area height: %dpx (%.1f%% of viewport)" % [int(layout_manager.play_area_rect.size.y), play_area_percent * 100])
		print("    Bottom bar height: %dpx (%.1f%% of viewport)" % [int(layout_manager.bottom_bar_height), bottom_bar_percent * 100])
		print("")

		# Validate percentages are approximately correct
		if abs(top_bar_percent - 0.06) > 0.01:
			test_result["errors"].append("Top bar percentage off: %.1f%% (expected ~6%%)" % [top_bar_percent * 100])
		if abs(play_area_percent - 0.74) > 0.01:
			test_result["errors"].append("Play area percentage off: %.1f%% (expected ~74%%)" % [play_area_percent * 100])
		if abs(bottom_bar_percent - 0.20) > 0.01:
			test_result["errors"].append("Bottom bar percentage off: %.1f%% (expected ~20%%)" % [bottom_bar_percent * 100])

		# Test plot positioning on bottom edge
		print("  Plot Positioning (6 plots):")
		var total_plots = 6
		var plot_positions = []
		var prev_x = -1000.0
		var spacing_samples = []

		for i in range(total_plots):
			var pos = layout_manager._get_bottom_edge_position_test(i, total_plots)
			plot_positions.append(pos)

			if prev_x >= 0:
				spacing_samples.append(pos.x - prev_x)

			var margin_left = layout_manager.play_area_rect.position.x + (layout_manager.play_area_rect.size.x * 0.05)
			var margin_right = layout_manager.play_area_rect.position.x + (layout_manager.play_area_rect.size.x * 0.95)

			var is_in_bounds = pos.x >= margin_left and pos.x <= margin_right
			var bounds_status = "✓ In bounds" if is_in_bounds else "✗ OUT OF BOUNDS"
			print("    Plot %d: x=%.0f %s" % [i, pos.x, bounds_status])

			if not is_in_bounds:
				test_result["errors"].append("Plot %d position out of bounds: x=%.0f" % [i, pos.x])

		if spacing_samples.size() > 0:
			var avg_spacing = spacing_samples.reduce(func(acc, x): return acc + x) / float(spacing_samples.size())
			var max_spacing = spacing_samples.max()
			var min_spacing = spacing_samples.min()
			var spacing_variance = max_spacing - min_spacing
			print("    Spacing: avg=%.0fpx, var=%.0fpx" % [avg_spacing, spacing_variance])

			if spacing_variance > 1.0:
				test_result["errors"].append("Plot spacing variance too high: %.0fpx" % spacing_variance)

		print("")

		# Test font scaling
		print("  Font Scaling:")
		var test_font_sizes = [14, 16, 18, 20, 24]
		for base_size in test_font_sizes:
			var scaled_size = layout_manager.get_scaled_font_size(base_size)
			print("    %dpx → %dpx" % [base_size, scaled_size])

		print("")

		# Test corner anchoring
		print("  Corner Anchoring:")
		var tl = layout_manager.anchor_to_corner("top_left", Vector2(10, 10))
		var br = layout_manager.anchor_to_corner("bottom_right", Vector2(10, 10))
		print("    top_left(10,10): %.0f, %.0f" % [tl.x, tl.y])
		print("    bottom_right(10,10): %.0f, %.0f" % [br.x, br.y])

		print("")

		# Report errors
		if test_result["errors"].size() > 0:
			print("  ✗ ERRORS FOUND:")
			for error in test_result["errors"]:
				print("    • %s" % error)
		else:
			print("  ✓ All checks passed!")

		print("")
		results.append(test_result)

	# Summary
	print("═" * 70)
	print("TEST SUMMARY")
	print("═" * 70)
	print("")

	var total_errors = 0
	for result in results:
		var status = "✓ PASS" if result["errors"].size() == 0 else "✗ FAIL"
		print("%s: %s (%d errors)" % [status, result["name"], result["errors"].size()])
		total_errors += result["errors"].size()

	print("")
	print("Total errors: %d" % total_errors)
	print("═" * 70)

	if total_errors == 0:
		print("✓ All layout tests passed!")
		quit(0)
	else:
		print("✗ Some tests failed. See details above.")
		quit(1)


class UILayoutManager:
	extends Node

	const BASE_RESOLUTION = Vector2(1920, 1080)
	const TOP_BAR_HEIGHT_PERCENT = 0.06
	const BOTTOM_BAR_HEIGHT_PERCENT = 0.20
	const PLAY_AREA_PERCENT = 0.74
	const PLAY_AREA_MARGIN_PERCENT = 0.05

	enum ScaleBreakpoint { MOBILE, HD, FHD, QHD, UHD_4K }

	var viewport_size: Vector2
	var scale_factor: float = 1.0
	var current_breakpoint: int = ScaleBreakpoint.FHD
	var top_bar_height: float
	var bottom_bar_height: float
	var play_area_rect: Rect2
	var play_area_inner_rect: Rect2

	func _calculate_scale_factor():
		var width_scale = viewport_size.x / BASE_RESOLUTION.x
		var height_scale = viewport_size.y / BASE_RESOLUTION.y
		var raw_scale = min(width_scale, height_scale)

		if raw_scale >= 1.8:
			scale_factor = 2.0
			current_breakpoint = ScaleBreakpoint.UHD_4K
		elif raw_scale >= 1.25:
			scale_factor = 1.5
			current_breakpoint = ScaleBreakpoint.QHD
		elif raw_scale >= 0.9:
			scale_factor = 1.0
			current_breakpoint = ScaleBreakpoint.FHD
		elif raw_scale >= 0.6:
			scale_factor = 0.75
			current_breakpoint = ScaleBreakpoint.HD
		else:
			scale_factor = 0.6
			current_breakpoint = ScaleBreakpoint.MOBILE

	func _calculate_layout_dimensions():
		top_bar_height = viewport_size.y * TOP_BAR_HEIGHT_PERCENT
		bottom_bar_height = viewport_size.y * BOTTOM_BAR_HEIGHT_PERCENT

		var play_area_y = top_bar_height
		var play_area_height = viewport_size.y - top_bar_height - bottom_bar_height
		play_area_rect = Rect2(0, play_area_y, viewport_size.x, play_area_height)

		var margin = play_area_rect.size.length() * PLAY_AREA_MARGIN_PERCENT
		play_area_inner_rect = Rect2(
			play_area_rect.position + Vector2(margin, margin),
			play_area_rect.size - Vector2(margin * 2, margin * 2)
		)

	func _get_bottom_edge_position_test(index: int, total: int) -> Vector2:
		"""Calculate position for plot tile on bottom edge of play area"""
		var play_area_size = play_area_rect.size
		var margin = play_area_size.x * 0.05

		var available_width = play_area_size.x - (margin * 2)
		var spacing = available_width / float(total)
		var x_position = margin + (index * spacing) + (spacing / 2.0)

		var y_position = play_area_size.y - 80

		return Vector2(x_position, y_position)

	func get_scaled_font_size(base_size: int) -> int:
		var font_scale = min(scale_factor, 1.5)
		return int(base_size * font_scale)

	func anchor_to_corner(corner: String, offset: Vector2) -> Vector2:
		var scaled_offset = offset * scale_factor
		match corner:
			"top_left":
				return scaled_offset
			"top_right":
				return Vector2(viewport_size.x - scaled_offset.x, scaled_offset.y)
			"bottom_left":
				return Vector2(scaled_offset.x, viewport_size.y - scaled_offset.y)
			"bottom_right":
				return viewport_size - scaled_offset
			_:
				return Vector2.ZERO
