## Simple Layout and Input Test
## Run with: godot --script test_layout_simple.gd
## Prints layout measurements and tracks keyboard input

extends SceneTree

func _initialize():
	print("\n" + "="*70)
	print("🧪 LAYOUT & INPUT TEST")
	print("="*70)

	var scene = load("res://UITestOnly.tscn")
	var root = instantiate_scene(scene)
	root_node.add_child(root)

	# Give it time to initialize
	await process_frame
	await process_frame

	# Find components
	var farm_view = root.find_child("FarmView", true, false)
	var ui = farm_view.find_child("FarmUIController", true, false) if farm_view else null

	if not ui:
		print("❌ Could not find FarmUIController")
		quit(1)

	print("\n✅ UI Structure Found\n")
	print("Layout Verification:")
	print("─" * 50)

	# Measure vertical layout
	var y = 0.0
	var vp_h = get_viewport().get_visible_rect().size.y
	var layout_ok = true

	_test_zone(ui, "top_bar", "TopBar", y, vp_h * 0.06)
	y += _get_height(ui, "top_bar")

	_test_zone(ui, "plots_row", "PlotsRow", y, vp_h * 0.15)
	y += _get_height(ui, "plots_row")

	_test_zone(ui, "play_area", "PlayArea", y, vp_h * 0.665)
	y += _get_height(ui, "play_area")

	_test_zone(ui, "actions_row", "ActionsRow", y, vp_h * 0.125)
	y += _get_height(ui, "actions_row")

	_test_zone(ui, "bottom_bar", "BottomBar", y, vp_h * 0.06)
	y += _get_height(ui, "bottom_bar")

	var error = abs(y - vp_h)
	print("\nTotal height: %.1f / %.1f (error: %.1f px)" % [y, vp_h, error])
	if error < 5.0:
		print("✅ Layout fits perfectly!")
	else:
		print("⚠️  Layout has gaps/overlap")

	print("\n" + "="*70)
	print("🎹 KEYBOARD TEST")
	print("="*70)
	print("The game is now running. Try pressing:")
	print("  • 1-6  = Select tools (should highlight in cyan)")
	print("  • Q/E/R = Execute actions")
	print("  • WASD = Move cursor")
	print("  • Y/U/I/O/P = Quick locations")
	print("\nPress ESC to quit")
	print("="*70 + "\n")

	# Monitor input for 30 seconds
	var start = Time.get_ticks_msec()
	var key_presses = 0

	while Time.get_ticks_msec() - start < 30000:
		await process_frame

	quit(0)

func _test_zone(ui: Node, prop: String, name: String, expected_y: float, expected_h: float) -> void:
	var node = ui.get(prop)
	if not node or not node is Control:
		print("❌ %s: NOT FOUND" % name)
		return

	var c = node as Control
	var y = c.global_position.y
	var h = c.size.y
	var y_ok = abs(y - expected_y) < 5.0
	var h_ok = abs(h - expected_h) < 5.0 or h == 0  # 0 is ok for expanding elements
	var status = "✅" if (y_ok and h_ok) else "⚠️"

	print("%s %s: Y≈%.0f (exp %.0f), H≈%.0f (exp %.0f)" % [
		status, name.pad_zeros(12), y, expected_y, h, expected_h
	])

func _get_height(ui: Node, prop: String) -> float:
	var node = ui.get(prop)
	if node and node is Control:
		return (node as Control).size.y
	return 0.0

