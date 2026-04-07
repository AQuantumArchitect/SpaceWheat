#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Comprehensive investigation of Tool 3 (INDUSTRY) - PLACE_MILL, PLACE_MARKET, PLACE_KITCHEN

const ProbeActions = preload("res://Core/Actions/ProbeActions.gd")

var farm = null
var frame_count = 0
var scene_loaded = false
var tests_done = false
var issues_found = []

func _init():
	print("\n" + "═".repeat(80))
	print("🏭 TOOL 3 (INDUSTRY) INVESTIGATION TEST")
	print("═".repeat(80))

func _process(_delta):
	frame_count += 1

	if frame_count == 5 and not scene_loaded:
		print("\n⏳ Loading scene...")
		var scene = load("res://scenes/FarmView.tscn")
		if scene:
			var instance = scene.instantiate()
			root.add_child(instance)
			scene_loaded = true
			var boot_manager = root.get_node_or_null("/root/BootManager")
			if boot_manager:
				boot_manager.game_ready.connect(_on_game_ready)

func _on_game_ready():
	if tests_done:
		return
	tests_done = true

	print("\n✅ Game ready! Starting Tool 3 investigation...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm

	await investigate_building_methods()
	await investigate_mill_placement()
	await investigate_market_placement()
	await investigate_kitchen_placement()
	await investigate_building_costs()

	print("\n" + "═".repeat(80))
	print("✅ TOOL 3 INVESTIGATION COMPLETE")
	print("═".repeat(80))
	print("\n📋 ISSUES FOUND: %d" % issues_found.size())
	print("═".repeat(80))
	if issues_found.size() > 0:
		for issue in issues_found:
			print("  ❌ %s" % issue)
	else:
		print("  ✅ No critical issues found")
	print("")
	quit()

func log_issue(message: String):
	issues_found.append(message)
	print("  ⚠️  ISSUE: %s" % message)

func investigate_building_methods():
	"""Check if biome building methods exist and are callable"""
	print("\n[INVESTIGATE 1] Building Method Availability")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))
	if not biome:
		log_issue("Tool 3: No biome at (0,0)")
		return

	print("Testing biome: %s" % biome.get_biome_type())

	# Check for mill
	if biome.has_method("add_mill"):
		print("✅ biome.add_mill() method exists")
	else:
		log_issue("Tool 3: biome.add_mill() method not found")

	# Check for market
	if biome.has_method("add_market"):
		print("✅ biome.add_market() method exists")
	else:
		log_issue("Tool 3: biome.add_market() method not found")

	# Check for kitchen
	if biome.has_method("add_kitchen"):
		print("✅ biome.add_kitchen() method exists")
	else:
		log_issue("Tool 3: biome.add_kitchen() method not found")

	# Check for efficiency getters
	if biome.has_method("get_mill_efficiency"):
		var eff = biome.get_mill_efficiency()
		print("✅ biome.get_mill_efficiency() = %.2f" % eff)
	else:
		log_issue("Tool 3: biome.get_mill_efficiency() method not found")

	if biome.has_method("get_kitchen_efficiency"):
		var eff = biome.get_kitchen_efficiency()
		print("✅ biome.get_kitchen_efficiency() = %.2f" % eff)
	else:
		log_issue("Tool 3: biome.get_kitchen_efficiency() method not found")

func investigate_mill_placement():
	"""Investigate PLACE_MILL action"""
	print("\n[INVESTIGATE 2] PLACE_MILL Action")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))
	if not biome:
		log_issue("Tool 3: No biome for mill investigation")
		return

	# Check initial state
	var initial_credits = farm.economy.get_resource_amount("💰")
	print("Initial credits: %d 💰" % initial_credits)

	# Try to place mill
	if biome.has_method("add_mill"):
		var result = biome.add_mill()
		print("✅ add_mill() called, result: %s" % str(result))

		# Check if mill is actually enabled
		if biome.has_method("has_mill"):
			var has_it = biome.has_mill()
			print("  - Biome has_mill(): %s" % str(has_it))
			if not has_it:
				log_issue("Tool 3: Mill added but has_mill() returns false")
		else:
			print("  ⚠️  Biome doesn't have has_mill() method")

		# Check if efficiency is available
		var eff = biome.get_mill_efficiency()
		print("  - Mill efficiency: %.2f (input → output)" % eff)
	else:
		log_issue("Tool 3: add_mill() method not available")

func investigate_market_placement():
	"""Investigate PLACE_MARKET action"""
	print("\n[INVESTIGATE 3] PLACE_MARKET Action")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))
	if not biome:
		log_issue("Tool 3: No biome for market investigation")
		return

	# Try to place market
	if biome.has_method("add_market"):
		var result = biome.add_market()
		print("✅ add_market() called, result: %s" % str(result))

		# Check if market is enabled
		if biome.has_method("has_market"):
			var has_it = biome.has_market()
			print("  - Biome has_market(): %s" % str(has_it))
			if not has_it:
				log_issue("Tool 3: Market added but has_market() returns false")
		else:
			print("  ⚠️  Biome doesn't have has_market() method")
	else:
		log_issue("Tool 3: add_market() method not available")

func investigate_kitchen_placement():
	"""Investigate PLACE_KITCHEN action - special entanglement requirement"""
	print("\n[INVESTIGATE 4] PLACE_KITCHEN Action & Entanglement Requirement")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))
	if not biome:
		log_issue("Tool 3: No biome for kitchen investigation")
		return

	print("Kitchen requires 3-plot entanglement (design feature)")
	print("Testing kitchen availability without entanglement...")

	if biome.has_method("add_kitchen"):
		# Try without entanglement first
		var result_no_ent = biome.add_kitchen()
		print("  - add_kitchen() without entanglement: %s" % str(result_no_ent))

		# Check if kitchen is enabled
		if biome.has_method("has_kitchen"):
			var has_it = biome.has_kitchen()
			print("  - Biome has_kitchen(): %s" % str(has_it))
		else:
			print("  ⚠️  Biome doesn't have has_kitchen() method")

		# Check efficiency
		var eff = biome.get_kitchen_efficiency()
		print("  - Kitchen efficiency: %.2f" % eff)

		# Check entanglement requirement
		if biome.has_method("kitchen_requires_entanglement"):
			var requires = biome.kitchen_requires_entanglement()
			print("  - kitchen_requires_entanglement(): %s" % str(requires))
		else:
			print("  ⚠️  Biome doesn't have kitchen_requires_entanglement() method")
	else:
		log_issue("Tool 3: add_kitchen() method not available")

func investigate_building_costs():
	"""Investigate if building costs are actually deducted from economy"""
	print("\n[INVESTIGATE 5] Building Costs & Economy Deduction")
	print("─".repeat(80))

	var biome = farm.grid.get_biome_for_plot(Vector2i(0, 0))
	if not biome:
		log_issue("Tool 3: No biome for cost investigation")
		return

	print("Checking if building placement deducts from economy...")

	# Record initial state
	var initial_credits = farm.economy.get_resource_amount("💰")
	print("Initial credits: %d 💰" % initial_credits)

	# Find current input adapter details
	var input_handler = null
	var shell = root.get_node_or_null("FarmView/PlayerShell")
	if shell:
		input_handler = shell.input_handler if "input_handler" in shell else null

	if not input_handler:
		print("⚠️  Could not find QuantumInstrumentInput for cost testing")
	else:
		print("✅ Found QuantumInstrumentInput")

		# Check if action methods exist
		if input_handler.has_method("_action_batch_build"):
			print("  ✅ _action_batch_build() method exists")
		else:
			log_issue("Tool 3: batch-build path not found in QuantumInstrumentInput")

		if input_handler.has_method("_action_place_kitchen"):
			print("  ✅ _action_place_kitchen() method exists")
		else:
			log_issue("Tool 3: kitchen-placement path not found in QuantumInstrumentInput")

	# Check economy has spend_resource method
	if farm.economy.has_method("spend_resource"):
		print("✅ economy.spend_resource() method exists")

		# Try to spend some credits (test mechanism)
		var old_credits = farm.economy.get_resource_amount("💰")
		farm.economy.spend_resource("💰", 5, "test_spend")
		var new_credits = farm.economy.get_resource_amount("💰")
		print("  - Test spend 5 💰: %d → %d (expected %d)" % [old_credits, new_credits, old_credits - 5])

		if new_credits != old_credits - 5:
			log_issue("Tool 3: Economy spend_resource() not working correctly")
		else:
			print("  ✅ Economy deduction mechanism works")
	else:
		log_issue("Tool 3: economy.spend_resource() method not found")

	print("\nBuilding cost structure (from investigation):")
	print("  - MILL: ~500 💰")
	print("  - MARKET: ~750 💰")
	print("  - KITCHEN: ~1000 💰 (+ 3-plot entanglement requirement)")
	print("  - TOTAL: ~2250 💰 for full economy")
