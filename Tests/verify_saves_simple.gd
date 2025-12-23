## Simple headless verification
## Run with: godot --headless -s verify_saves_simple.gd

extends SceneTree

func _initialize():
	print("\n" + "=".repeat(70))
	print("✅ SAVE/SCENARIO VERIFICATION (Headless)")
	print("=".repeat(70) + "\n")

	var all_pass = true

	# Test scenario load
	print("▶ Loading: res://Scenarios/default.tres")
	var scenario = ResourceLoader.load("res://Scenarios/default.tres")

	if not scenario:
		print("❌ Failed to load scenario")
		quit(1)
		return

	print("✓ Scenario loaded")

	# Access via dynamic call
	var scenario_id = scenario.scenario_id if scenario.has_method("get_scenario_id") or "scenario_id" in scenario else "UNKNOWN"

	# Try direct property access
	var props = {}
	if scenario is Resource:
		# Print all properties for debugging
		for prop in scenario.get_property_list():
			if prop.name.begins_with("_"):
				continue
			var val = scenario[prop.name] if prop.name in scenario else null
			if val != null:
				props[prop.name] = val

	print("\n▶ Scenario Properties:")
	print("-".repeat(70))

	if props.is_empty():
		print("⚠️  Could not extract properties via property list")
		print("  (This may be a Godot 4.5 limitation with Resource properties)")
	else:
		# Show key properties
		var key_props = ["scenario_id", "grid_width", "grid_height", "credits", "plots"]
		for key in key_props:
			if key in props:
				if key == "plots":
					var plot_count = (props[key] as Array).size()
					print("  ✓ %s: Array[%d items]" % [key, plot_count])
				else:
					print("  ✓ %s: %s" % [key, props[key]])

	# Direct file content check via text parsing
	print("\n▶ File Format Validation:")
	print("-".repeat(70))

	var file_content = _load_file("res://Scenarios/default.tres")
	if file_content.is_empty():
		print("❌ Could not read file")
		all_pass = false
	else:
		var checks = _validate_file_content(file_content)
		for check_name in checks.keys():
			var passed = checks[check_name]
			var symbol = "✓" if passed else "❌"
			print("  %s %s" % [symbol, check_name])
			if not passed:
				all_pass = false

	print("\n" + "=".repeat(70))
	if all_pass:
		print("✅ ALL CHECKS PASSED")
	else:
		print("⚠️  SOME CHECKS FAILED (see above)")
	print("=".repeat(70) + "\n")

	quit(0 if all_pass else 1)

func _load_file(path: String) -> String:
	"""Load file content as text"""
	if not ResourceLoader.exists(path):
		return ""

	# We can't directly read .tres as text through ResourceLoader
	# But we verified the file exists and loaded as Resource
	return "file exists"

func _validate_file_content(content: String) -> Dictionary:
	"""Validate key format requirements"""
	# Read the actual file
	var file_path = ProjectSettings.globalize_path("res://Scenarios/default.tres")
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		return {
			"File readable": false,
			"Has script reference": false,
			"Has grid dimensions": false,
			"Grid is 6x1": false,
			"Has 6 plots": false,
			"No obsolete fields": false,
		}

	var text = file.get_as_text()
	file = null

	var checks = {
		"File readable": text.length() > 0,
		"Has script reference": "GameState.gd" in text,
		"Has grid dimensions": "grid_width" in text and "grid_height" in text,
		"Grid is 6x1": "grid_width = 6" in text and "grid_height = 1" in text,
		"Has 6 plots": text.count('"position": Vector2i') == 6,
		"No obsolete fields": not ("\"theta\":" in text) and not ("\"phi\":" in text),
	}

	return checks
