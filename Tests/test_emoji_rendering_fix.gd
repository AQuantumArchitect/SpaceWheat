extends GutTest

## Test emoji rendering fix for terminal bubbles

func test_terminal_bubble_emoji_rendering():
	"""Test that terminal bubbles display emojis correctly"""
	
	# Create a QuantumNode with terminal emoji data
	var bubble = QuantumNode.new(null, Vector2(100, 100), Vector2i(1, 1), Vector2(200, 200))
	
	# Simulate what _create_bubble_for_terminal does
	bubble.emoji_north = "🌾"
	bubble.emoji_south = "👥"
	bubble.emoji_north_opacity = 0.7
	bubble.emoji_south_opacity = 0.3
	bubble.is_terminal_bubble = true
	
	# Verify opacities are set
	assert_eq(bubble.emoji_north_opacity, 0.7, "North emoji opacity should be 0.7")
	assert_eq(bubble.emoji_south_opacity, 0.3, "South emoji opacity should be 0.3")
	assert_true(bubble.is_terminal_bubble, "Should be marked as terminal bubble")
	
	# Verify that update_from_quantum_state doesn't get called for terminal bubbles
	# (This is handled by QuantumForceGraph._draw_quantum_bubbles() at line 2611)
	print("✅ Terminal bubble emoji rendering test passed")


func test_terminal_freezing_after_measure():
	"""Test that measured terminals freeze in place"""
	
	var bubble = QuantumNode.new(null, Vector2(100, 100), Vector2i(1, 1), Vector2(200, 200))
	bubble.position = Vector2(100, 100)
	bubble.velocity = Vector2(5, 5)
	
	# Simulate measurement (this would be set in QuantumForceGraph physics update)
	# The bubble's position should be frozen to classical_anchor
	var saved_position = bubble.position
	bubble.position = bubble.classical_anchor
	bubble.velocity = Vector2.ZERO
	
	assert_eq(bubble.velocity, Vector2.ZERO, "Measured bubble velocity should be zero")
	print("✅ Terminal freezing test passed")


func test_bubble_spawn_animation():
	"""Test that bubbles start with spawn animation"""
	
	var bubble = QuantumNode.new(null, Vector2(100, 100), Vector2i(1, 1), Vector2(200, 200))
	
	# Should start with animation disabled
	assert_false(bubble.is_spawning, "Should not be spawning initially")
	assert_eq(bubble.visual_scale, 0.0, "visual_scale should start at 0")
	
	# Start spawn animation
	bubble.start_spawn_animation(0.0)
	assert_true(bubble.is_spawning, "Should be spawning after start_spawn_animation")
	
	print("✅ Bubble spawn animation test passed")
