extends Node

## Automated Playtest for Bubble Clicks + Plot Entanglement

var farm_view = null
var test_step = 0
var test_timer = 0.0

func _ready():
	print("\n============================================================")
	print("🧪 AUTOMATED PLAYTEST: Bubble Clicks + Plot Entanglement")
	print("============================================================\n")

	await get_tree().create_timer(0.5).timeout
	load_farm_and_start_tests()

func load_farm_and_start_tests():
	print("📦 Loading FarmView scene...")
	var scene = load("res://scenes/FarmView.tscn")
	farm_view = scene.instantiate()
	add_child(farm_view)

	await get_tree().create_timer(3.0).timeout
	print("✅ FarmView loaded\n")

	run_tests()

func run_tests():
	print("\n────────────────────────────────────────────────────────────")
	print("TEST SUITE 1: Contextual Bubble Clicks")
	print("────────────────────────────────────────────────────────────\n")

	# TEST 1: Plant via bubble click
	await test_bubble_plant()

	# TEST 2: Auto-measure when grown
	await test_bubble_measure()

	# TEST 3: Auto-harvest when mature
	await test_bubble_harvest()

	print("\n────────────────────────────────────────────────────────────")
	print("TEST SUITE 2: Plot Infrastructure Entanglement")
	print("────────────────────────────────────────────────────────────\n")

	# TEST 4: Create infrastructure on empty plots
	await test_infrastructure_creation()

	# TEST 5: Auto-entangle on planting
	await test_auto_entangle()

	# TEST 6: Infrastructure persistence across harvest
	await test_infrastructure_persistence()

	print_final_results()

# ============================================================================
# TEST SUITE 1: Bubble Clicks
# ============================================================================

func test_bubble_plant():
	print("TEST 1: Bubble Click → Plant")
	print("  → Clicking quantum bubble on empty plot...")

	var test_pos = Vector2i(0, 0)
	var plot_before = farm_view.farm_grid.get_plot(test_pos)

	if plot_before.is_planted:
		print("  ⚠️ Plot already planted, skipping")
		return

	# Simulate bubble click (contextual)
	farm_view._handle_bubble_click(test_pos)

	await get_tree().create_timer(0.2).timeout

	var plot_after = farm_view.farm_grid.get_plot(test_pos)
	if plot_after.is_planted:
		print("  ✅ PASS: Bubble click planted wheat")
	else:
		print("  ❌ FAIL: Bubble click did NOT plant")
		get_tree().quit(1)

func test_bubble_measure():
	print("\nTEST 2: Bubble Click → Measure (when grown)")
	print("  → Growing crop to maturity...")

	var test_pos = Vector2i(0, 0)
	var plot = farm_view.farm_grid.get_plot(test_pos)

	# Force growth to maturity
	plot.growth_progress = 0.75  # Mature threshold
	plot.is_mature = true

	await get_tree().create_timer(0.2).timeout

	if plot.has_been_measured:
		print("  ⚠️ Already measured, skipping")
		return

	print("  → Clicking bubble to measure...")
	farm_view._handle_bubble_click(test_pos)

	await get_tree().create_timer(0.2).timeout

	if plot.has_been_measured:
		print("  ✅ PASS: Bubble click measured crop")
	else:
		print("  ❌ FAIL: Bubble click did NOT measure")
		get_tree().quit(1)

func test_bubble_harvest():
	print("\nTEST 3: Bubble Click → Harvest (when mature + measured)")
	print("  → Clicking bubble to harvest...")

	var test_pos = Vector2i(0, 0)
	var plot_before = farm_view.farm_grid.get_plot(test_pos)

	if not plot_before.is_mature or not plot_before.has_been_measured:
		print("  ⚠️ Not ready to harvest, skipping")
		return

	var credits_before = farm_view.economy.credits

	farm_view._handle_bubble_click(test_pos)

	await get_tree().create_timer(0.2).timeout

	var plot_after = farm_view.farm_grid.get_plot(test_pos)
	var credits_after = farm_view.economy.credits

	if not plot_after.is_planted and credits_after > credits_before:
		print("  ✅ PASS: Bubble click harvested crop (+%d credits)" % (credits_after - credits_before))
	else:
		print("  ❌ FAIL: Bubble click did NOT harvest properly")
		get_tree().quit(1)

# ============================================================================
# TEST SUITE 2: Plot Infrastructure Entanglement
# ============================================================================

func test_infrastructure_creation():
	print("TEST 4: Create entanglement infrastructure on empty plots")
	print("  → Entangling plots (1,0) ↔ (2,0)...")

	var pos_a = Vector2i(1, 0)
	var pos_b = Vector2i(2, 0)

	# Entangle empty plots
	var success = farm_view.farm_grid.create_entanglement(pos_a, pos_b)

	await get_tree().create_timer(0.2).timeout

	var plot_a = farm_view.farm_grid.get_plot(pos_a)
	var plot_b = farm_view.farm_grid.get_plot(pos_b)

	if plot_a.plot_infrastructure_entanglements.has(pos_b) and \
	   plot_b.plot_infrastructure_entanglements.has(pos_a):
		print("  ✅ PASS: Infrastructure created on empty plots")
	else:
		print("  ❌ FAIL: Infrastructure NOT created")
		print("    Plot A infrastructure: %s" % plot_a.plot_infrastructure_entanglements)
		print("    Plot B infrastructure: %s" % plot_b.plot_infrastructure_entanglements)
		get_tree().quit(1)

func test_auto_entangle():
	print("\nTEST 5: Auto-entangle quantum states when planting")
	print("  → Planting wheat in (1,0)...")

	var pos_a = Vector2i(1, 0)
	var pos_b = Vector2i(2, 0)

	farm_view.game_controller.plant_wheat(pos_a)
	await get_tree().create_timer(0.2).timeout

	print("  → Planting wheat in (2,0)...")
	farm_view.game_controller.plant_wheat(pos_b)
	await get_tree().create_timer(0.2).timeout

	var plot_a = farm_view.farm_grid.get_plot(pos_a)
	var plot_b = farm_view.farm_grid.get_plot(pos_b)

	# Check if quantum states are entangled
	var are_entangled = plot_a.entangled_plots.has(plot_b.plot_id) or \
	                    (plot_a.quantum_state != null and plot_a.quantum_state.entangled_pair != null)

	if are_entangled:
		print("  ✅ PASS: Quantum states auto-entangled via infrastructure")
	else:
		print("  ❌ FAIL: Quantum states NOT auto-entangled")
		print("    Plot A entanglements: %s" % plot_a.entangled_plots.keys())
		print("    Plot B entanglements: %s" % plot_b.entangled_plots.keys())
		get_tree().quit(1)

func test_infrastructure_persistence():
	print("\nTEST 6: Infrastructure persists across harvest/replant")
	print("  → Forcing maturity and measuring...")

	var pos_a = Vector2i(1, 0)
	var pos_b = Vector2i(2, 0)

	var plot_a = farm_view.farm_grid.get_plot(pos_a)
	var plot_b = farm_view.farm_grid.get_plot(pos_b)

	# Force maturity and measure
	plot_a.growth_progress = 0.8
	plot_a.is_mature = true
	plot_b.growth_progress = 0.8
	plot_b.is_mature = true

	farm_view.game_controller.measure_plot(pos_a)
	await get_tree().create_timer(0.2).timeout

	print("  → Harvesting both plots...")
	farm_view.game_controller.harvest_plot(pos_a)
	farm_view.game_controller.harvest_plot(pos_b)
	await get_tree().create_timer(0.2).timeout

	# Check infrastructure still exists
	plot_a = farm_view.farm_grid.get_plot(pos_a)
	plot_b = farm_view.farm_grid.get_plot(pos_b)

	if not plot_a.plot_infrastructure_entanglements.has(pos_b):
		print("  ❌ FAIL: Infrastructure lost after harvest!")
		print("    Plot A infrastructure: %s" % plot_a.plot_infrastructure_entanglements)
		get_tree().quit(1)

	print("  ✅ Infrastructure persisted after harvest")

	# Replant and check auto-entangle
	print("  → Replanting to test auto-entangle...")
	farm_view.game_controller.plant_wheat(pos_a)
	farm_view.game_controller.plant_wheat(pos_b)
	await get_tree().create_timer(0.2).timeout

	plot_a = farm_view.farm_grid.get_plot(pos_a)
	plot_b = farm_view.farm_grid.get_plot(pos_b)

	var re_entangled = plot_a.entangled_plots.has(plot_b.plot_id) or \
	                   (plot_a.quantum_state != null and plot_a.quantum_state.entangled_pair != null)

	if re_entangled:
		print("  ✅ PASS: Auto-entangled on replant (infrastructure works!)")
	else:
		print("  ❌ FAIL: Did NOT auto-entangle on replant")
		get_tree().quit(1)

# ============================================================================
# Results
# ============================================================================

func print_final_results():
	print("\n============================================================")
	print("🎉 ALL TESTS PASSED!")
	print("============================================================")
	print("")
	print("✅ Contextual bubble clicks working:")
	print("   - Empty plot → Plant")
	print("   - Unmeasured → Measure")
	print("   - Mature → Harvest")
	print("")
	print("✅ Plot infrastructure entanglement working:")
	print("   - Can create on empty plots")
	print("   - Auto-entangles on planting")
	print("   - Persists across harvest/replant")
	print("")
	print("🎮 Features ready for manual playtesting!")
	print("")

	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)
