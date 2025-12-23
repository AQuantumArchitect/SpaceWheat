extends SceneTree

## Faction Context System Test Suite
## Tests 32-faction background context and influence system

const FactionContext = preload("res://Core/Context/FactionContext.gd")

var test_count = 0
var passed_count = 0


func _initialize():
	print("\n" + "=".repeat(80))
	print("  FACTION CONTEXT SYSTEM TEST SUITE")
	print("=".repeat(80) + "\n")

	# Run all tests
	test_1_initialization()
	test_2_faction_queries()
	test_3_pattern_distance()
	test_4_pattern_generation()
	test_5_ambient_influences()
	test_6_flavor_generation()
	test_7_color_palettes()
	test_8_faction_similarity()

	# Summary
	print("\n" + "=".repeat(80))
	print("  TEST SUMMARY: %d / %d PASSED" % [passed_count, test_count])
	print("=".repeat(80) + "\n")

	if passed_count == test_count:
		print("✅ ALL TESTS PASSED\n")
		quit(0)
	else:
		print("❌ SOME TESTS FAILED\n")
		quit(1)


func test_1_initialization():
	print("TEST 1: Faction Context Initialization")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Note: Source document has 39 factions despite title saying "32-Faction System"
	assert_true(context.factions.size() == 39, "Should have all factions from source document")

	# Verify categories
	var categories = {}
	for faction in context.factions:
		if not categories.has(faction.category):
			categories[faction.category] = 0
		categories[faction.category] += 1

	print("Faction distribution:")
	for cat in categories:
		print("  %s: %d factions" % [cat, categories[cat]])

	assert_true(categories.size() >= 8, "Should have at least 8 categories")

	# Verify all patterns are 12-bit
	var valid_patterns = true
	for faction in context.factions:
		if faction.pattern.length() != 12:
			valid_patterns = false
			print("  ❌ Invalid pattern for %s: %s" % [faction.name, faction.pattern])

	assert_true(valid_patterns, "All patterns should be 12 bits")

	print()


func test_2_faction_queries():
	print("TEST 2: Faction Query Functions")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Test get_faction_by_name
	var carrion = context.get_faction_by_name("The Carrion Throne")
	assert_true(not carrion.is_empty(), "Should find Carrion Throne by name")
	assert_true(carrion.emoji == "👑💀🏛️", "Should have correct emoji")
	print("Found: %s %s" % [carrion.emoji, carrion.name])

	# Test get_factions_by_category
	var imperial = context.get_factions_by_category("Imperial Power")
	assert_true(imperial.size() == 4, "Should have 4 Imperial Power factions")
	print("Imperial Power factions: %d" % imperial.size())

	# Test get_factions_by_keyword
	var grain_factions = context.get_factions_by_keyword("grain")
	assert_true(grain_factions.size() > 0, "Should find factions with 'grain' keyword")
	print("Factions with 'grain' keyword: %d" % grain_factions.size())
	for faction in grain_factions:
		print("  - %s" % faction.name)

	print()


func test_3_pattern_distance():
	print("TEST 3: Q-Bit Pattern Distance Calculation")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Test identical patterns
	var dist_same = context.calculate_pattern_distance("110111001101", "110111001101")
	assert_true(dist_same == 0, "Identical patterns should have distance 0")
	print("Identical patterns: distance = %d" % dist_same)

	# Test completely different patterns
	var dist_opposite = context.calculate_pattern_distance("000000000000", "111111111111")
	assert_true(dist_opposite == 12, "Opposite patterns should have distance 12")
	print("Opposite patterns: distance = %d" % dist_opposite)

	# Test similar patterns (1 bit different)
	var dist_similar = context.calculate_pattern_distance("110111001101", "110111001100")
	assert_true(dist_similar == 1, "One-bit difference should have distance 1")
	print("One-bit difference: distance = %d" % dist_similar)

	# Find factions closest to Carrion Throne pattern
	var carrion = context.get_faction_by_name("The Carrion Throne")
	var closest = context.get_closest_factions(carrion.pattern, 5)
	print("\nClosest factions to %s:" % carrion.name)
	for i in range(closest.size()):
		var faction = closest[i]
		var dist = context.calculate_pattern_distance(carrion.pattern, faction.pattern)
		print("  %d. %s (distance: %d)" % [i + 1, faction.name, dist])

	print()


func test_4_pattern_generation():
	print("TEST 4: Pattern Generation from Game State")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Test with various game states
	var game_states = [
		{
			"chaos_activation": 0.2,
			"biotic_activation": 0.8,
			"credits": 100,
			"plots_planted": 5,
			"avg_growth_rate": 0.12,
			"entangled_pairs": 2,
			"total_replants": 3,
			"measurements": 10,
			"harvests": 5,
			"plants": 10,
			"vocabulary_discovered": 2,
			"manual_actions": 30,
			"goals_completed": 1
		},
		{
			"chaos_activation": 0.8,
			"biotic_activation": 0.2,
			"credits": 1000,
			"plots_planted": 20,
			"avg_growth_rate": 0.2,
			"entangled_pairs": 10,
			"total_replants": 50,
			"measurements": 100,
			"harvests": 50,
			"plants": 60,
			"vocabulary_discovered": 15,
			"manual_actions": 200,
			"goals_completed": 8
		}
	]

	for i in range(game_states.size()):
		var pattern = context.get_pattern_from_state(game_states[i])
		assert_true(pattern.length() == 12, "Generated pattern should be 12 bits")
		print("State %d pattern: %s" % [i + 1, pattern])

		# Find closest faction
		var closest = context.get_closest_factions(pattern, 1)
		if closest.size() > 0:
			print("  Closest faction: %s %s" % [closest[0].emoji, closest[0].name])

	print()


func test_5_ambient_influences():
	print("TEST 5: Ambient Influence System")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Initial state (should be equal for all)
	var initial_dominant = context.get_dominant_faction()
	print("Initial dominant: %s" % initial_dominant.name)

	# Update with specific game state
	var game_state = {
		"chaos_activation": 0.1,
		"biotic_activation": 0.9,
		"credits": 50,
		"plots_planted": 3,
		"avg_growth_rate": 0.11,
		"entangled_pairs": 0,
		"total_replants": 1,
		"measurements": 5,
		"harvests": 2,
		"plants": 5,
		"vocabulary_discovered": 0,
		"manual_actions": 10,
		"goals_completed": 0
	}

	context.update_ambient_influences(game_state)

	# Get top factions
	var top_factions = context.get_top_factions(5)
	assert_true(top_factions.size() == 5, "Should return 5 top factions")

	print("\nTop 5 influential factions after update:")
	for i in range(top_factions.size()):
		var faction = top_factions[i]
		print("  %d. %s %s (%.1f%%)" % [i + 1, faction.emoji, faction.name, faction.influence * 100])

	# Verify influences sum to ~1.0
	var total_influence = 0.0
	for faction_name in context.ambient_influences:
		total_influence += context.ambient_influences[faction_name]

	assert_true(abs(total_influence - 1.0) < 0.01, "Total influence should sum to 1.0")
	print("\nTotal influence: %.6f" % total_influence)

	print()


func test_6_flavor_generation():
	print("TEST 6: Flavor Text Generation")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Set a specific dominant faction
	context.ambient_influences = {}
	for faction in context.factions:
		context.ambient_influences[faction.name] = 0.0

	context.ambient_influences["The Carrion Throne"] = 1.0

	# Generate flavor for various contexts
	var contexts = ["harvest", "plant", "measure", "entangle", "goal_complete", "death"]

	for ctx in contexts:
		var flavor = context.generate_flavor_text(ctx)
		assert_true(flavor != "", "Should generate flavor text for %s" % ctx)
		print("%s: \"%s\"" % [ctx, flavor])

	print()


func test_7_color_palettes():
	print("TEST 7: Faction Color Palette Generation")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Test a few factions
	var test_factions = [
		"The Carrion Throne",
		"The Yeast Prophets",
		"The Entropy Shepherds"
	]

	for faction_name in test_factions:
		var palette = context.get_faction_color_palette(faction_name)

		assert_true(palette.has("primary"), "Palette should have primary color")
		assert_true(palette.has("secondary"), "Palette should have secondary color")
		assert_true(palette.has("accent"), "Palette should have accent color")

		print("%s:" % faction_name)
		print("  Primary:   rgb(%.2f, %.2f, %.2f)" % [palette.primary.r, palette.primary.g, palette.primary.b])
		print("  Secondary: rgb(%.2f, %.2f, %.2f)" % [palette.secondary.r, palette.secondary.g, palette.secondary.b])
		print("  Accent:    rgb(%.2f, %.2f, %.2f)" % [palette.accent.r, palette.accent.g, palette.accent.b])

	print()


func test_8_faction_similarity():
	print("TEST 8: Faction Similarity Analysis")
	print("─".repeat(40))

	var context = FactionContext.new()

	# Find factions with exactly the same pattern
	var pattern_groups = {}

	for faction in context.factions:
		if not pattern_groups.has(faction.pattern):
			pattern_groups[faction.pattern] = []
		pattern_groups[faction.pattern].append(faction.name)

	print("Pattern similarity groups:")
	var duplicate_count = 0
	for pattern in pattern_groups:
		if pattern_groups[pattern].size() > 1:
			duplicate_count += 1
			print("  Pattern %s (%d factions):" % [pattern, pattern_groups[pattern].size()])
			for faction_name in pattern_groups[pattern]:
				var faction = context.get_faction_by_name(faction_name)
				print("    - %s %s" % [faction.emoji, faction_name])

	if duplicate_count == 0:
		print("  No duplicate patterns (all 32 factions are unique)")

	# Find most different factions (max Hamming distance)
	var max_distance = 0
	var most_different = []

	for i in range(context.factions.size()):
		for j in range(i + 1, context.factions.size()):
			var dist = context.calculate_pattern_distance(
				context.factions[i].pattern,
				context.factions[j].pattern
			)
			if dist > max_distance:
				max_distance = dist
				most_different = [context.factions[i], context.factions[j]]

	print("\nMost different factions (distance: %d):" % max_distance)
	print("  %s %s" % [most_different[0].emoji, most_different[0].name])
	print("  %s %s" % [most_different[1].emoji, most_different[1].name])
	print("  Pattern A: %s" % most_different[0].pattern)
	print("  Pattern B: %s" % most_different[1].pattern)

	print()


## Assertion helpers

func assert_true(condition: bool, message: String):
	test_count += 1
	if condition:
		passed_count += 1
		print("  ✅ %s" % message)
	else:
		print("  ❌ FAILED: %s" % message)
