extends Node

## Test Icon Visual Effects
## Verifies Icon auras and particle fields render correctly

var farm_view: Node
var test_results: Array[String] = []

func _ready():
	print("\n🎨 ===== ICON VISUAL EFFECTS TEST =====\n")

	# Wait for initialization
	await get_tree().process_frame
	await get_tree().process_frame

	# Find FarmView (it's a sibling node)
	farm_view = get_parent().get_node("FarmView")
	if not farm_view:
		print("❌ FAILED: Could not find FarmView")
		get_tree().quit(1)
		return

	print("✅ Found FarmView")

	# Wait for full initialization
	await get_tree().process_frame
	await get_tree().process_frame

	# Run tests
	await _run_tests()

	# Print results
	print("\n🎨 ===== TEST RESULTS =====")
	for result in test_results:
		print(result)

	print("\n🎨 Tests complete! Exiting in 2 seconds...")
	await get_tree().create_timer(2.0).timeout
	get_tree().quit(0)


func _run_tests():
	"""Run Icon visualization tests"""

	# Test 1: Icon references set correctly
	await _test_icon_references()
	await get_tree().create_timer(0.3).timeout

	# Test 2: Plant wheat to activate Biotic Icon
	await _test_biotic_activation()
	await get_tree().create_timer(0.5).timeout

	# Test 3: Check Biotic particles spawning
	await _test_biotic_particles()
	await get_tree().create_timer(0.5).timeout

	# Test 4: Plant tomatoes to activate Chaos Icon
	await _test_chaos_activation()
	await get_tree().create_timer(0.5).timeout

	# Test 5: Check Chaos particles spawning
	await _test_chaos_particles()
	await get_tree().create_timer(0.5).timeout

	# Test 6: Verify Icon auras would render
	await _test_icon_auras()


func _test_icon_references():
	"""Test that Icons are passed to quantum graph"""
	print("\n🔗 Test: Icon References Set")

	var qgraph = farm_view.quantum_graph

	if qgraph.biotic_icon == null:
		test_results.append("❌ FAILED: Biotic Icon not set in quantum graph")
		return

	if qgraph.chaos_icon == null:
		test_results.append("❌ FAILED: Chaos Icon not set in quantum graph")
		return

	if qgraph.imperium_icon == null:
		test_results.append("❌ FAILED: Imperium Icon not set in quantum graph")
		return

	test_results.append("✅ All Icon references set correctly in quantum graph")


func _test_biotic_activation():
	"""Test Biotic Icon activation by planting wheat"""
	print("\n🌾 Test: Biotic Icon Activation")

	# Plant wheat at 10 plots
	var wheat_positions = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(3, 3)
	]

	for pos in wheat_positions:
		farm_view._select_plot(pos)
		farm_view._on_plant_pressed()

	# Wait for Icon update
	await get_tree().process_frame

	var biotic_strength = farm_view.biotic_icon.get_activation()
	print("  Biotic activation: %.1f%%" % (biotic_strength * 100))

	if biotic_strength > 0.2:  # Should be ~40% (10/25)
		test_results.append("✅ Biotic Icon activated: %.0f%%" % (biotic_strength * 100))
	else:
		test_results.append("❌ FAILED: Biotic Icon not activated (%.0f%%)" % (biotic_strength * 100))


func _test_biotic_particles():
	"""Test Biotic particles spawning"""
	print("\n✨ Test: Biotic Particle Spawning")

	var qgraph = farm_view.quantum_graph

	# Wait for particles to spawn
	for i in range(60):  # Wait 1 second
		await get_tree().process_frame

	var particle_count = qgraph.icon_particles.size()
	var biotic_count = 0

	for particle in qgraph.icon_particles:
		if particle.type == "biotic":
			biotic_count += 1

	print("  Total Icon particles: %d" % particle_count)
	print("  Biotic particles: %d" % biotic_count)

	if biotic_count > 0:
		test_results.append("✅ Biotic particles spawning: %d particles" % biotic_count)
	else:
		test_results.append("❌ FAILED: No Biotic particles spawned")


func _test_chaos_activation():
	"""Test Chaos Icon activation by planting tomatoes"""
	print("\n🍅 Test: Chaos Icon Activation")

	# Plant tomatoes at 5 plots
	var tomato_positions = [
		Vector2i(4, 0), Vector2i(4, 1), Vector2i(4, 2),
		Vector2i(4, 3), Vector2i(4, 4)
	]

	for pos in tomato_positions:
		farm_view._select_plot(pos)
		farm_view._on_plant_tomato_pressed()

	# Wait for Icon update
	await get_tree().process_frame

	var chaos_strength = farm_view.chaos_icon.get_activation()
	print("  Chaos activation: %.1f%%" % (chaos_strength * 100))

	if chaos_strength > 0.1:
		test_results.append("✅ Chaos Icon activated: %.0f%%" % (chaos_strength * 100))
	else:
		test_results.append("❌ FAILED: Chaos Icon not activated (%.0f%%)" % (chaos_strength * 100))


func _test_chaos_particles():
	"""Test Chaos particles spawning"""
	print("\n💜 Test: Chaos Particle Spawning")

	var qgraph = farm_view.quantum_graph

	# Wait for particles to spawn
	for i in range(60):  # Wait 1 second
		await get_tree().process_frame

	var chaos_count = 0
	for particle in qgraph.icon_particles:
		if particle.type == "chaos":
			chaos_count += 1

	print("  Chaos particles: %d" % chaos_count)

	if chaos_count > 0:
		test_results.append("✅ Chaos particles spawning: %d particles" % chaos_count)
	else:
		test_results.append("❌ FAILED: No Chaos particles spawned")


func _test_icon_auras():
	"""Test Icon auras render correctly"""
	print("\n🌟 Test: Icon Auras")

	var biotic_strength = farm_view.biotic_icon.get_activation()
	var chaos_strength = farm_view.chaos_icon.get_activation()

	print("  Biotic aura strength: %.1f%%" % (biotic_strength * 100))
	print("  Chaos aura strength: %.1f%%" % (chaos_strength * 100))

	# Auras should render if activation > 5%
	var biotic_will_render = biotic_strength > 0.05
	var chaos_will_render = chaos_strength > 0.05

	if biotic_will_render and chaos_will_render:
		test_results.append("✅ Both Icon auras will render (activation > 5%%)")
	elif biotic_will_render:
		test_results.append("⚠️ Only Biotic aura will render (Chaos too weak)")
	elif chaos_will_render:
		test_results.append("⚠️ Only Chaos aura will render (Biotic too weak)")
	else:
		test_results.append("❌ FAILED: No auras will render (both < 5%%)")
