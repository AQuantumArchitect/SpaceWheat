#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test emoji registration - verify emojis are discoverable after planting

var farm = null
var frame_count = 0
var scene_loaded = false
var tests_done = false

func _init():
	print("\n" + "═".repeat(80))
	print("🎨 EMOJI REGISTRATION TEST")
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

	print("\n✅ Game ready! Testing emoji registration...\n")

	var fv = root.get_node_or_null("FarmView")
	if not fv or not fv.farm:
		print("❌ Farm not found")
		quit(1)
		return

	farm = fv.farm

	# Bootstrap resources
	farm.economy.add_resource("🌾", 100, "test")

	# Get a biome and plant something
	var target_pos = Vector2i(0, 0)
	var biome = farm.grid.get_biome_for_plot(target_pos)

	if not biome:
		print("❌ No biome at %s" % target_pos)
		quit(1)
		return

	print("✅ Found biome: %s" % biome.get_biome_type())
	print("   Quantum computer: %s" % (biome.quantum_computer if biome.quantum_computer else "NONE"))

	# Build a mill
	print("\nBuilding mill at %s..." % target_pos)
	var success = farm.build(target_pos, "mill")
	print("Build result: %s\n" % success)

	if not success:
		print("❌ Mill build failed")
		quit(1)
		return

	# Now check if emojis are registered
	var qc = biome.quantum_computer
	if not qc:
		print("❌ No quantum computer in biome")
		quit(1)
		return

	print("🔍 Checking RegisterMap for emojis...")
	print("   RegisterMap.num_qubits: %d" % qc.register_map.num_qubits)
	print("   RegisterMap.axes: %s" % qc.register_map.axes)

	# Check if we can find any registered emojis
	var found_emojis = []
	for emoji in qc.register_map.coordinates.keys():
		found_emojis.append(emoji)
		var coords = qc.register_map.coordinates[emoji]
		print("   ✅ Found registered emoji: '%s' → qubit %d, pole %d" % [emoji, coords["qubit"], coords["pole"]])

	if found_emojis.is_empty():
		print("❌ NO EMOJIS REGISTERED IN RegisterMap!")
		print("   This is the bug: emojis aren't being registered during allocate_register()")
		quit(1)
		return

	# Try to get emoji probability
	print("\n🔬 Testing get_emoji_probability()...")
	for emoji in found_emojis:
		var prob = biome.get_emoji_probability(emoji)
		print("   get_emoji_probability('%s') = %.3f" % [emoji, prob])

	print("\n✅ EMOJI REGISTRATION TEST PASSED!")
	print("   Emojis are now discoverable after planting")

	quit()
