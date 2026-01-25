#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Proper investigation of Tool 3 (INDUSTRY) using correct API
## Building methods are in Farm and FarmGrid, not in biome classes

var farm = null
var frame_count = 0
var scene_loaded = false
var tests_done = false
var issues_found = []

func _init():
	print("\n" + "═".repeat(80))
	print("🏭 TOOL 3 (INDUSTRY) PROPER INVESTIGATION")
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

	print("\n✅ Game ready! Starting Tool 3 proper investigation...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm

	await investigate_build_infrastructure()
	await investigate_mill_building()
	await investigate_market_building()
	await investigate_kitchen_building()
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

func investigate_build_infrastructure():
	"""Check if Farm and FarmGrid have building methods"""
	print("\n[INVESTIGATE 1] Building Infrastructure")
	print("─".repeat(80))

	# Check Farm methods
	if farm.has_method("build"):
		print("✅ farm.build() method exists")
	else:
		log_issue("Tool 3: farm.build() method not found")

	if farm.has_method("batch_build"):
		print("✅ farm.batch_build() method exists")
	else:
		log_issue("Tool 3: farm.batch_build() method not found")

	# Check FarmGrid methods
	if farm.grid.has_method("place_mill"):
		print("✅ farm.grid.place_mill() method exists")
	else:
		log_issue("Tool 3: farm.grid.place_mill() method not found")

	if farm.grid.has_method("place_market"):
		print("✅ farm.grid.place_market() method exists")
	else:
		log_issue("Tool 3: farm.grid.place_market() method not found")

	if farm.grid.has_method("place_kitchen"):
		print("✅ farm.grid.place_kitchen() method exists")
	else:
		log_issue("Tool 3: farm.grid.place_kitchen() method not found")

	if farm.grid.has_method("create_triplet_entanglement"):
		print("✅ farm.grid.create_triplet_entanglement() method exists")
	else:
		log_issue("Tool 3: farm.grid.create_triplet_entanglement() method not found")

func investigate_mill_building():
	"""Investigate PLACE_MILL building"""
	print("\n[INVESTIGATE 2] PLACE_MILL Building")
	print("─".repeat(80))

	# Find an empty plot
	var target_pos = Vector2i(1, 0)  # Try position (1,0)
	var plot = farm.grid.get_plot(target_pos)

	if not plot:
		log_issue("Tool 3: Cannot find plot at %s" % target_pos)
		return

	if plot.is_planted:
		log_issue("Tool 3: Plot at %s is already planted, cannot test mill placement" % target_pos)
		return

	print("Target plot at %s (type: %s)" % [target_pos, plot.plot_type])

	# Check costs
	var mill_cost = farm.INFRASTRUCTURE_COSTS.get("mill", {})
	if mill_cost.is_empty():
		log_issue("Tool 3: No mill cost defined in INFRASTRUCTURE_COSTS")
	else:
		print("✅ Mill cost defined: %s" % str(mill_cost))

	# Bootstrap: Add wheat credits for testing (mill costs 30 🌾)
	farm.economy.add_resource("🌾", 100, "test_bootstrap")
	print("✅ Test bootstrap: Added 100 🌾 credits")

	var initial_wheat = farm.economy.get_resource("🌾")
	print("Initial wheat credits: %d 🌾" % initial_wheat)

	var success = farm.build(target_pos, "mill")
	if success:
		print("✅ farm.build(mill) succeeded")

		# Check if cost was deducted
		var final_wheat = farm.economy.get_resource("🌾")
		if final_wheat < initial_wheat:
			var deducted = initial_wheat - final_wheat
			print("  - Wheat deducted: %d 🌾" % deducted)
		else:
			log_issue("Tool 3: Mill placed but no cost deducted")

		# Check if plot is marked as planted
		var updated_plot = farm.grid.get_plot(target_pos)
		if updated_plot.is_planted:
			print("  - Plot correctly marked as planted")
			print("  - Plot type: %s" % updated_plot.plot_type)
		else:
			log_issue("Tool 3: Mill placed but plot not marked as planted")
	else:
		print("❌ farm.build(mill) failed")
		print("  - Check if plot is in correct biome")
		print("  - Check if we have enough credits")

func investigate_market_building():
	"""Investigate PLACE_MARKET building"""
	print("\n[INVESTIGATE 3] PLACE_MARKET Building")
	print("─".repeat(80))

	# Find an empty plot
	var target_pos = Vector2i(2, 0)
	var plot = farm.grid.get_plot(target_pos)

	if not plot:
		log_issue("Tool 3: Cannot find plot at %s" % target_pos)
		return

	if plot.is_planted:
		log_issue("Tool 3: Plot at %s is already planted, cannot test market placement" % target_pos)
		return

	# Check costs
	var market_cost = farm.INFRASTRUCTURE_COSTS.get("market", {})
	if market_cost.is_empty():
		log_issue("Tool 3: No market cost defined in INFRASTRUCTURE_COSTS")
	else:
		print("✅ Market cost defined: %s" % str(market_cost))

	# Try to place market
	var initial_credits = farm.economy.get_resource("💰")
	var success = farm.build(target_pos, "market")

	if success:
		print("✅ farm.build(market) succeeded")

		var final_credits = farm.economy.get_resource("💰")
		if final_credits < initial_credits:
			var deducted = initial_credits - final_credits
			print("  - Credits deducted: %d 💰" % deducted)
	else:
		print("⚠️  farm.build(market) failed - may be insufficient credits")

func investigate_kitchen_building():
	"""Investigate PLACE_KITCHEN building"""
	print("\n[INVESTIGATE 4] PLACE_KITCHEN Building & Triplet Entanglement")
	print("─".repeat(80))

	# Kitchen requires 3 empty plots for triplet entanglement
	var pos_a = Vector2i(3, 0)
	var pos_b = Vector2i(4, 0)
	var pos_c = Vector2i(5, 0)

	var plot_a = farm.grid.get_plot(pos_a)
	var plot_b = farm.grid.get_plot(pos_b)
	var plot_c = farm.grid.get_plot(pos_c)

	var all_valid = true
	for pos in [pos_a, pos_b, pos_c]:
		var p = farm.grid.get_plot(pos)
		if not p or p.is_planted:
			log_issue("Tool 3: Cannot use plot %s for kitchen (occupied/invalid)" % pos)
			all_valid = false

	if not all_valid:
		return

	# Check cost
	var kitchen_cost = farm.INFRASTRUCTURE_COSTS.get("kitchen", {})
	if kitchen_cost.is_empty():
		log_issue("Tool 3: No kitchen cost defined")
	else:
		print("✅ Kitchen cost defined: %s" % str(kitchen_cost))

	# Bootstrap: Kitchen needs wheat AND flour
	farm.economy.add_resource("🌾", 50, "test_bootstrap")
	farm.economy.add_resource("💨", 20, "test_bootstrap")
	print("✅ Test bootstrap: Added 50 🌾 + 20 💨 for kitchen")

	# Try triplet entanglement
	var initial_wheat = farm.economy.get_resource("🌾")
	var initial_flour = farm.economy.get_resource("💨")

	if farm.grid.has_method("create_triplet_entanglement"):
		var ent_success = farm.grid.create_triplet_entanglement(pos_a, pos_b, pos_c)
		if ent_success:
			print("✅ create_triplet_entanglement() succeeded")
		else:
			print("⚠️  create_triplet_entanglement() failed - may need planted/quantum plots")

	# Try to place kitchen (via build() which calls grid.place_kitchen())
	var kitchen_success = farm.build(pos_a, "kitchen")

	if kitchen_success:
		print("✅ farm.build(kitchen) succeeded")

		var final_wheat = farm.economy.get_resource("🌾")
		var final_flour = farm.economy.get_resource("💨")
		if final_wheat < initial_wheat:
			print("  - Wheat deducted: %d 🌾" % (initial_wheat - final_wheat))
		if final_flour < initial_flour:
			print("  - Flour deducted: %d 💨" % (initial_flour - final_flour))
	else:
		print("⚠️  farm.build(kitchen) failed - may need GHZ entanglement first")

func investigate_building_costs():
	"""Investigate building cost enforcement"""
	print("\n[INVESTIGATE 5] Building Cost Enforcement")
	print("─".repeat(80))

	# Check INFRASTRUCTURE_COSTS constant
	if farm.has_meta("INFRASTRUCTURE_COSTS"):
		var costs = farm.get_meta("INFRASTRUCTURE_COSTS")
		print("✅ INFRASTRUCTURE_COSTS found: %s" % str(costs))
	else:
		# Try accessing as property
		if "INFRASTRUCTURE_COSTS" in farm:
			print("✅ INFRASTRUCTURE_COSTS is accessible")
			var mill_cost = farm.INFRASTRUCTURE_COSTS.get("mill", {})
			var market_cost = farm.INFRASTRUCTURE_COSTS.get("market", {})
			var kitchen_cost = farm.INFRASTRUCTURE_COSTS.get("kitchen", {})

			print("  - Mill cost: %s" % str(mill_cost))
			print("  - Market cost: %s" % str(market_cost))
			print("  - Kitchen cost: %s" % str(kitchen_cost))
		else:
			log_issue("Tool 3: INFRASTRUCTURE_COSTS not accessible")

	# Check economy methods
	if farm.economy.has_method("can_afford_cost"):
		print("✅ economy.can_afford_cost() method exists")
	else:
		log_issue("Tool 3: economy.can_afford_cost() not found")

	if farm.economy.has_method("remove_resource"):
		print("✅ economy.remove_resource() method exists")
	else:
		log_issue("Tool 3: economy.remove_resource() not found")

	print("\nBuilding cost structure (from code):")
	print("  - MILL: Wheat → Flour converter (80% efficiency)")
	print("  - MARKET: Trading hub (converts resources)")
	print("  - KITCHEN: Bread baker (requires 3-qubit entanglement)")
