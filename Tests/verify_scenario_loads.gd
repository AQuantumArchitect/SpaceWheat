## Verify that the repaired scenario loads correctly
## Run with: godot -s verify_scenario_loads.gd

extends SceneTree

func _init():
	print("\n" + "=".repeat(70))
	print("✅ SCENARIO FORMAT VERIFICATION")
	print("=".repeat(70) + "\n")

func _initialize():
	print("▶ Loading scenario file...")
	print("-".repeat(70))

	# Try to load the default scenario
	var scenario_path = "res://Scenarios/default.tres"
	var scenario = ResourceLoader.load(scenario_path)

	if not scenario:
		_fail("Could not load scenario from %s" % scenario_path)
		return

	print("✓ Scenario loaded successfully")
	print("  Path: %s" % scenario_path)
	print("  Type: %s" % scenario.get_class())

	# Verify key properties
	print("\n▶ Verifying scenario properties...")
	print("-".repeat(70))

	var checks = []

	# Check scenario_id
	if scenario.has_meta("scenario_id") or scenario.get("scenario_id") != null:
		print("✓ scenario_id: %s" % scenario.get("scenario_id"))
		checks.append(true)
	else:
		print("❌ scenario_id missing")
		checks.append(false)

	# Check grid dimensions
	var grid_w = scenario.get("grid_width")
	var grid_h = scenario.get("grid_height")
	if grid_w == 6 and grid_h == 1:
		print("✓ grid_width: %d (correct)" % grid_w)
		print("✓ grid_height: %d (correct)" % grid_h)
		checks.append(true)
		checks.append(true)
	else:
		print("❌ grid_width: %d (expected 6)" % grid_w)
		print("❌ grid_height: %d (expected 1)" % grid_h)
		checks.append(false)
		checks.append(false)

	# Check plots array
	var plots = scenario.get("plots")
	if plots and plots.size() == 6:
		print("✓ plots array: %d items (correct)" % plots.size())
		checks.append(true)

		# Verify plot format
		var all_plots_valid = true
		for plot_idx in range(plots.size()):
			var plot = plots[plot_idx]
			var is_valid = (
				plot.has("position") and
				plot.has("type") and
				plot.has("is_planted") and
				plot.has("has_been_measured") and
				plot.has("theta_frozen") and
				plot.has("entangled_with")
			)

			if not is_valid:
				print("  ❌ Plot %d: missing required fields" % plot_idx)
				all_plots_valid = false
			elif plot.has("theta") or plot.has("phi") or plot.has("growth_progress"):
				print("  ❌ Plot %d: has obsolete fields" % plot_idx)
				all_plots_valid = false

		if all_plots_valid:
			print("  ✓ All %d plots have correct format" % plots.size())
			checks.append(true)
		else:
			checks.append(false)
	else:
		print("❌ plots array: expected 6, got %d" % (plots.size() if plots else 0))
		checks.append(false)

	# Check economy
	var credits = scenario.get("credits")
	if credits == 20:
		print("✓ credits: %d (default)" % credits)
		checks.append(true)
	else:
		print("⚠️  credits: %d (non-default)" % credits)
		checks.append(true)  # Not a failure

	# Check required fields exist
	print("\n▶ Checking required GameState fields...")
	print("-".repeat(70))

	var required_fields = [
		"scenario_id", "save_timestamp", "game_time",
		"grid_width", "grid_height",
		"credits", "wheat_inventory", "flour_inventory",
		"labor_inventory", "flower_inventory",
		"mushroom_inventory", "detritus_inventory",
		"imperium_resource",
		"tributes_paid", "tributes_failed",
		"plots",
		"current_goal_index", "completed_goals",
		"biotic_activation", "chaos_activation", "imperium_activation",
		"active_contracts",
		"sun_moon_phase"
	]

	var missing_fields = []
	for field in required_fields:
		if scenario.get(field) == null and field != "completed_goals" and field != "active_contracts":
			# These can be empty but must exist
			if not ("completed_goals" in scenario or "active_contracts" in scenario):
				missing_fields.append(field)

	if missing_fields.is_empty():
		print("✓ All %d required fields present" % required_fields.size())
		checks.append(true)
	else:
		print("❌ Missing %d fields: %s" % [missing_fields.size(), missing_fields])
		checks.append(false)

	# Check for obsolete fields
	print("\n▶ Checking for obsolete fields...")
	print("-".repeat(70))

	var obsolete_fields = ["theta", "phi", "growth_progress", "is_mature"]
	var found_obsolete = false

	for plot in plots:
		for obsolete_field in obsolete_fields:
			if plot.has(obsolete_field):
				print("❌ Found obsolete field '%s' in plot data" % obsolete_field)
				found_obsolete = true
				checks.append(false)

	if not found_obsolete:
		print("✓ No obsolete fields found")
		checks.append(true)

	# Summary
	print("\n" + "=".repeat(70))
	var passed = checks.filter(func(x): return x).size()
	var total = checks.size()

	if passed == total:
		print("✅ SCENARIO VERIFICATION PASSED (%d/%d checks)" % [passed, total])
		print("=".repeat(70))
		print("\n📋 Scenario Summary:")
		print("  ID: %s" % scenario.get("scenario_id"))
		print("  Grid: %dx%d" % [scenario.get("grid_width"), scenario.get("grid_height")])
		print("  Plots: %d" % scenario.get("plots").size())
		print("  Starting credits: %d" % scenario.get("credits"))
		print("  Format: COMPATIBLE ✅")
		print("")
		quit(0)
	else:
		print("❌ SCENARIO VERIFICATION FAILED (%d/%d checks)" % [passed, total])
		print("=".repeat(70))
		quit(1)

func _fail(message: String) -> void:
	print("\n❌ FAILED: " + message)
	quit(1)
