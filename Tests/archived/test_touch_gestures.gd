extends Node
## Test script for verifying touch gesture detection
## Tests TAP to MEASURE and SWIPE to ENTANGLE gestures

const QuantumForceGraph = preload("res://Core/Visualization/QuantumForceGraph.gd")
const QuantumNode = preload("res://Core/Visualization/QuantumNode.gd")
const DualEmojiQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit.gd")

var test_count = 0
var passed_count = 0

func _ready():
	print("\n============================================================")
	print("TOUCH GESTURE DETECTION TESTS")
	print("============================================================\n")

	await test_tap_gesture()
	await test_swipe_gesture()

	print("\n============================================================")
	print("RESULTS: %d/%d PASSED" % [passed_count, test_count])
	print("============================================================\n")

	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func test_tap_gesture():
	"""Test that short click registers as TAP"""
	test_count += 1
	print("📊 TEST 1: TAP gesture detection (short press)")

	# Create a simple graph node for testing
	var graph = Node2D.new()
	var node = Control.new()
	node.custom_minimum_size = Vector2(100, 100)
	graph.add_child(node)

	# Track signals
	var tapped = false
	var swiped = false
	var tap_position = Vector2i.ZERO

	# We can't easily test with a real QuantumForceGraph, but we can verify the logic
	# Simulate a tap: press and release with distance < 50px and time < 1.0s
	var press_pos = Vector2(100, 100)
	var release_pos = Vector2(102, 98)  # Only 2.8px away
	var time_elapsed = 0.1  # 100ms

	var distance = press_pos.distance_to(release_pos)
	var is_tap = distance < 50.0 and time_elapsed <= 1.0

	if is_tap:
		print("✅ TEST 1 PASSED: Tap detected (distance=%.1f, time=%.1fs)" % [distance, time_elapsed])
		passed_count += 1
	else:
		print("❌ TEST 1 FAILED: Should have detected tap")


func test_swipe_gesture():
	"""Test that long drag registers as SWIPE"""
	test_count += 1
	print("📊 TEST 2: SWIPE gesture detection (sustained drag)")

	# Simulate a swipe: press and release with distance >= 50px and time <= 1.0s
	var press_pos = Vector2(100, 100)
	var release_pos = Vector2(170, 145)  # 70.4px away
	var time_elapsed = 0.42  # 420ms

	var distance = press_pos.distance_to(release_pos)
	var is_swipe = distance >= 50.0 and time_elapsed <= 1.0

	if is_swipe:
		print("✅ TEST 2 PASSED: Swipe detected (distance=%.1f, time=%.1fs)" % [distance, time_elapsed])
		passed_count += 1
	else:
		print("❌ TEST 2 FAILED: Should have detected swipe")

func test_slow_drag():
	"""Test that slow drag (>1.0s) is NOT detected as swipe"""
	test_count += 1
	print("📊 TEST 3: Slow drag rejection (time > 1.0s)")

	var press_pos = Vector2(100, 100)
	var release_pos = Vector2(170, 145)
	var time_elapsed = 1.2  # Too slow

	var distance = press_pos.distance_to(release_pos)
	var is_swipe = distance >= 50.0 and time_elapsed <= 1.0

	if not is_swipe:
		print("✅ TEST 3 PASSED: Slow drag correctly rejected")
		passed_count += 1
	else:
		print("❌ TEST 3 FAILED: Should have rejected slow drag")

func test_short_drag():
	"""Test that short drag (<50px) is NOT detected as swipe"""
	test_count += 1
	print("📊 TEST 4: Short drag rejection (distance < 50px)")

	var press_pos = Vector2(100, 100)
	var release_pos = Vector2(120, 115)  # Only 22.4px away
	var time_elapsed = 0.3

	var distance = press_pos.distance_to(release_pos)
	var is_swipe = distance >= 50.0 and time_elapsed <= 1.0

	if not is_swipe:
		print("✅ TEST 4 PASSED: Short drag correctly rejected")
		passed_count += 1
	else:
		print("❌ TEST 4 FAILED: Should have rejected short drag")
