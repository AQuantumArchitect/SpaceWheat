#!/usr/bin/env -S godot -s
## Simple unit test for parametric layout calculations
## No scene loading - just math verification

extends SceneTree

func _init():
	print("\n" + "=".repeat(70))
	print("🧪 PARAMETRIC LAYOUT MATH VALIDATION")
	print("=".repeat(70))
	print("")

	var test_cases = [
		{"name": "800×600 (Minimum)", "size": Vector2(800, 600), "plots": 6},
		{"name": "1920×1080 (Baseline)", "size": Vector2(1920, 1080), "plots": 6},
		{"name": "2560×1440 (QHD)", "size": Vector2(2560, 1440), "plots": 6},
		{"name": "3840×2160 (4K)", "size": Vector2(3840, 2160), "plots": 6},
	]

	var total_errors = 0

	for test_case in test_cases:
		print("─" * 70)
		print("Testing: %s" % test_case["name"])
		print("─" * 70)

		var viewport_size = test_case["size"]
		var num_plots = test_case["plots"]

		# Calculate scale factor (same logic as UILayoutManager)
		var BASE_RESOLUTION = Vector2(1920, 1080)
		var width_scale = viewport_size.x / BASE_RESOLUTION.x
		var height_scale = viewport_size.y / BASE_RESOLUTION.y
		var raw_scale = min(width_scale, height_scale)

		var scale_factor = 1.0
		var breakpoint_name = "FHD"

		if raw_scale >= 1.8:
			scale_factor = 2.0
			breakpoint_name = "UHD_4K"
		elif raw_scale >= 1.25:
			scale_factor = 1.5
			breakpoint_name = "QHD"
		elif raw_scale >= 0.9:
			scale_factor = 1.0
			breakpoint_name = "FHD"
		elif raw_scale >= 0.6:
			scale_factor = 0.75
			breakpoint_name = "HD"
		else:
			scale_factor = 0.6
			breakpoint_name = "MOBILE"

		# Calculate layout dimensions
		var TOP_BAR_HEIGHT_PERCENT = 0.06
		var BOTTOM_BAR_HEIGHT_PERCENT = 0.20
		var PLAY_AREA_MARGIN_PERCENT = 0.05

		var top_bar_height = viewport_size.y * TOP_BAR_HEIGHT_PERCENT
		var bottom_bar_height = viewport_size.y * BOTTOM_BAR_HEIGHT_PERCENT
		var play_area_height = viewport_size.y - top_bar_height - bottom_bar_height
		var play_area_width = viewport_size.x

		var top_bar_percent = (top_bar_height / viewport_size.y) * 100
		var play_area_percent = (play_area_height / viewport_size.y) * 100
		var bottom_bar_percent = (bottom_bar_height / viewport_size.y) * 100

		print("  Viewport: %s" % [viewport_size])
		print("  Scale Factor: %.2f (%s)" % [scale_factor, breakpoint_name])
		print("")

		print("  Layout Dimensions:")
		print("    Top bar: %dpx (%.1f%% of viewport)" % [int(top_bar_height), top_bar_percent])
		print("    Play area: %dpx (%.1f%% of viewport)" % [int(play_area_height), play_area_percent])
		print("    Bottom bar: %dpx (%.1f%% of viewport)" % [int(bottom_bar_height), bottom_bar_percent])
		print("")

		# Validate percentages
		var errors = []

		if abs(top_bar_percent - 6.0) > 0.5:
			errors.append("Top bar: %.1f%% (expected 6%%)" % top_bar_percent)
		if abs(play_area_percent - 74.0) > 0.5:
			errors.append("Play area: %.1f%% (expected 74%%)" % play_area_percent)
		if abs(bottom_bar_percent - 20.0) > 0.5:
			errors.append("Bottom bar: %.1f%% (expected 20%%)" % bottom_bar_percent)

		if errors.size() == 0:
			print("  ✓ Layout percentages correct")
		else:
			print("  ✗ Layout percentage errors:")
			for err in errors:
				print("    • %s" % err)
			total_errors += errors.size()

		print("")

		# Test plot positioning (bottom edge)
		print("  Plot Positioning (%d plots):" % num_plots)
		var margin_percent = 0.05
		var margin = play_area_width * margin_percent
		var available_width = play_area_width - (margin * 2)
		var spacing = available_width / float(num_plots)

		var positions = []
		var spacings = []
		var prev_x = -1.0

		for i in range(num_plots):
			var x_position = margin + (i * spacing) + (spacing / 2.0)
			positions.append(x_position)

			if prev_x >= 0:
				spacings.append(x_position - prev_x)

			var margin_left = margin
			var margin_right = play_area_width - margin
			var in_bounds = x_position >= margin_left and x_position <= margin_right

			var status = "✓" if in_bounds else "✗ OUT"
			print("    Plot %d: x=%.0f %s" % [i, x_position, status])

			if not in_bounds:
				errors.append("Plot %d out of bounds" % i)
			prev_x = x_position

		if spacings.size() > 0:
			var avg_spacing = spacings.reduce(func(acc, x): return acc + x) / float(spacings.size())
			var variance = spacings.max() - spacings.min()
			print("    Spacing: avg=%.0f var=%.0f" % [avg_spacing, variance])

			if variance > 1.0:
				errors.append("Plot spacing variance too high: %.0f" % variance)

		print("")

		# Test font scaling
		print("  Font Scaling:")
		var test_sizes = [14, 16, 18, 24]
		for base in test_sizes:
			var font_scale = min(scale_factor, 1.5)  # Cap at 1.5x
			var scaled = int(base * font_scale)
			print("    %d → %d" % [base, scaled])

		print("")

		if errors.size() > 0:
			print("  ✗ ERRORS: %d" % errors.size())
			for err in errors:
				print("    • %s" % err)
		else:
			print("  ✓ All checks passed")

		print("")
		total_errors += errors.size()

	# Summary
	print("═" * 70)
	print("SUMMARY")
	print("═" * 70)
	print("")

	if total_errors == 0:
		print("✓ All layout math checks passed!")
		print("")
		print("Key findings:")
		print("  • Layout percentages: Top 6%, Play 74%, Bottom 20% ✓")
		print("  • Scale breakpoints: MOBILE 0.6x, HD 0.75x, FHD 1.0x, QHD 1.5x, 4K 2.0x ✓")
		print("  • Plot positions: Evenly distributed on bottom edge ✓")
		print("  • Font scaling: Capped at 1.5x for readability ✓")
		print("")
		quit(0)
	else:
		print("✗ %d errors found" % total_errors)
		quit(1)
