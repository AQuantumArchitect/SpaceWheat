#!/bin/bash
# Final comprehensive test of rejection visual feedback system

echo "================================================================================"
echo "REJECTION VISUAL FEEDBACK SYSTEM - FINAL TEST"
echo "================================================================================"
echo ""

cat > /tmp/test_rejection_final.gd << 'EOF'
extends SceneTree

var test_results: Array[String] = []

func _init():
	print("\nTEST: Rejection Visual Feedback System")
	print("=".repeat(80))

	# Load classes
	var Farm = load("res://Core/Farm.gd")
	var PlotGridDisplay = load("res://UI/PlotGridDisplay.gd")

	# Create instances
	var farm = Farm.new()
	var plot_grid = PlotGridDisplay.new()
	root.add_child(farm)
	root.add_child(plot_grid)

	# Wait for initialization
	for i in range(10):
		await process_frame

	# Connect signal chain
	if farm.has_signal("action_rejected") and plot_grid.has_method("show_rejection_effect"):
		farm.action_rejected.connect(plot_grid.show_rejection_effect)
		test_results.append("PASS: Signal connection successful")
	else:
		test_results.append("FAIL: Signal connection failed")
		_print_results()
		quit(1)
		return

	# Test 1: Biome incompatibility rejection
	var initial_count = plot_grid.rejection_effects.size()
	var result1 = farm.build(Vector2i(0, 0), "wheat")
	await process_frame

	if not result1 and plot_grid.rejection_effects.size() > initial_count:
		test_results.append("PASS: Test 1 - Biome incompatibility rejection works")
	else:
		test_results.append("FAIL: Test 1 - Biome incompatibility rejection failed")

	# Test 2: Successful planting (no rejection)
	initial_count = plot_grid.rejection_effects.size()
	var result2 = farm.build(Vector2i(2, 0), "wheat")
	await process_frame

	if result2 and plot_grid.rejection_effects.size() == initial_count:
		test_results.append("PASS: Test 2 - Successful planting (no false rejection)")
	else:
		test_results.append("FAIL: Test 2 - Successful planting failed or false rejection")

	# Test 3: Occupied plot rejection
	initial_count = plot_grid.rejection_effects.size()
	var result3 = farm.build(Vector2i(2, 0), "wheat")
	await process_frame

	if not result3 and plot_grid.rejection_effects.size() > initial_count:
		test_results.append("PASS: Test 3 - Occupied plot rejection works")
	else:
		test_results.append("FAIL: Test 3 - Occupied plot rejection failed")

	_print_results()
	quit(0)

func _print_results():
	print("\n" + "=".repeat(80))
	print("TEST RESULTS:")
	print("=".repeat(80))
	for result in test_results:
		print(result)

	var failures = 0
	for result in test_results:
		if result.begins_with("FAIL"):
			failures += 1

	print("")
	if failures == 0:
		print("ALL TESTS PASSED (%d/%d)" % [test_results.size(), test_results.size()])
	else:
		print("%d TESTS FAILED (%d/%d passed)" % [failures, test_results.size() - failures, test_results.size()])
	print("=".repeat(80))
EOF

echo "Running test..."
echo ""

godot --headless -s /tmp/test_rejection_final.gd 2>&1 | grep -E "(TEST:|PASS|FAIL|RESULTS|signal|Test [0-9]|====)"

echo ""
echo "Test complete"
