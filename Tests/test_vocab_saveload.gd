extends SceneTree

## Test vocabulary persistence across save/load

const GameState = preload("res://Core/GameState/GameState.gd")
const GameStateManager = preload("res://Core/GameState/GameStateManager.gd")

func _init():
	print("\n" + "═".repeat(70))
	print("VOCABULARY SAVE/LOAD TEST")
	print("═".repeat(70) + "\n")

	# Create test state with expanded vocabulary
	var state = GameState.new()
	state.known_pairs = [
		{"north": "🍞", "south": "👥"},
		{"north": "🌱", "south": "💰"},
		{"north": "🧺", "south": "⚙"},
		{"north": "🏭", "south": "🌾"},
	]
	var original_emojis = state.get_known_emojis()

	print("Original vocabulary: %s (%d emojis)\n" % ["".join(original_emojis), original_emojis.size()])

	# Serialize to dictionary
	var save_data = {
		"known_pairs": state.known_pairs.duplicate(true)
	}

	print("Serialized data:")
	print("  known_pairs: %s\n" % str(save_data.known_pairs))

	# Simulate save/load by creating new state and restoring
	var loaded_state = GameState.new()
	loaded_state.known_pairs = save_data.known_pairs.duplicate(true)
	var loaded_emojis = loaded_state.get_known_emojis()

	print("Loaded vocabulary: %s (%d emojis)\n" % ["".join(loaded_emojis), loaded_emojis.size()])

	# Verify
	if loaded_emojis.size() == original_emojis.size():
		print("✅ PASS: Vocabulary size preserved")
	else:
		print("❌ FAIL: Vocabulary size mismatch!")

	var all_match = true
	for i in range(original_emojis.size()):
		if original_emojis[i] != loaded_emojis[i]:
			all_match = false
			break

	if all_match:
		print("✅ PASS: Vocabulary content preserved")
	else:
		print("❌ FAIL: Vocabulary content mismatch!")

	print("\n" + "═".repeat(70))
	print("TEST COMPLETE")
	print("═".repeat(70) + "\n")

	quit()
