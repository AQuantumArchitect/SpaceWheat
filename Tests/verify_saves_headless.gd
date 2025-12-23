## Headless scenario/save verification - just load and validate resources
## Run with: godot --headless -s verify_saves_headless.gd

extends SceneTree

func _initialize():
	print("\n" + "=".repeat(70))
	print("🔍 HEADLESS SAVE/SCENARIO VERIFICATION")
	print("=".repeat(70) + "\n")

	# Test 1: Load scenario
	print("▶ TEST 1: Load Default Scenario")
	print("-".repeat(70))
	_verify_file("res://Scenarios/default.tres", "SCENARIO")

	print("\n▶ TEST 2: Check Format Compatibility")
	print("-".repeat(70))
	_check_format()

	print("\n" + "=".repeat(70))
	print("✅ VERIFICATION COMPLETE")
	print("=".repeat(70) + "\n")
	quit(0)

func _verify_file(path: String, label: String) -> void:
	if not ResourceLoader.exists(path):
		print("❌ File not found: %s" % path)
		return

	print("✓ File exists: %s" % path)

	var resource = ResourceLoader.load(path)
	if not resource:
		print("❌ Could not load resource")
		return

	print("✓ Resource loaded successfully")
	print("  Class: %s" % resource.get_class())

	# Check script
	var script_name = resource.get_script().get_path().get_file()
	print("  Script: %s" % script_name)

	if script_name != "GameState.gd":
		print("  ⚠️  Warning: Expected GameState.gd")

func _check_format() -> void:
	var scenario = ResourceLoader.load("res://Scenarios/default.tres")

	if not scenario:
		print("❌ Cannot load scenario")
		return

	print("Scenario Properties:")

	# Access properties dynamically
	var props = {
		"scenario_id": "string",
		"grid_width": "int",
		"grid_height": "int",
		"credits": "int",
		"plots": "array",
	}

	for prop_name in props.keys():
		var value = scenario.get(prop_name)
		if value == null:
			print("  ❌ %s: MISSING" % prop_name)
		else:
			match prop_name:
				"plots":
					print("  ✓ %s: Array[%d items]" % [prop_name, value.size()])
				_:
					print("  ✓ %s: %s" % [prop_name, value])

	# Validate grid dimensions
	var grid_w = scenario.get("grid_width")
	var grid_h = scenario.get("grid_height")
	var plot_count = scenario.get("plots").size() if scenario.get("plots") else 0

	print("\nGrid Validation:")
	if grid_w == 6 and grid_h == 1:
		print("  ✅ Grid size: %dx%d (correct)" % [grid_w, grid_h])
	else:
		print("  ❌ Grid size: %dx%d (expected 6x1)" % [grid_w, grid_h])

	if plot_count == 6:
		print("  ✅ Plot count: %d (correct)" % plot_count)
	else:
		print("  ❌ Plot count: %d (expected 6)" % plot_count)

	# Check plot format
	print("\nPlot Format Validation:")
	var plots = scenario.get("plots")
	if plots and plots.size() > 0:
		var sample_plot = plots[0]
		var required_keys = ["position", "type", "is_planted", "has_been_measured", "theta_frozen", "entangled_with"]
		var obsolete_keys = ["theta", "phi", "growth_progress", "is_mature"]

		var has_all_required = true
		for key in required_keys:
			if not sample_plot.has(key):
				print("  ❌ Missing: %s" % key)
				has_all_required = false

		if has_all_required:
			print("  ✅ All required fields present")

		var has_obsolete = false
		for key in obsolete_keys:
			if sample_plot.has(key):
				print("  ❌ Obsolete field found: %s" % key)
				has_obsolete = true

		if not has_obsolete:
			print("  ✅ No obsolete fields found")

		print("\nSample Plot (first plot):")
		print("  position: %s" % sample_plot.get("position"))
		print("  type: %d" % sample_plot.get("type"))
		print("  is_planted: %s" % sample_plot.get("is_planted"))
		print("  has_been_measured: %s" % sample_plot.get("has_been_measured"))
		print("  theta_frozen: %s" % sample_plot.get("theta_frozen"))
		print("  entangled_with: %s" % sample_plot.get("entangled_with"))
