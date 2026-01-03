extends SceneTree

## Simplified test: Just check biome validation logic directly

const Farm = preload("res://Core/Farm.gd")

var farm: Farm

func _initialize():
	print("\n" + "=".repeat(80))
	print("🧪 TEST: Biome Validation Logic")
	print("=".repeat(80))

	await get_root().ready

	# Setup farm
	farm = Farm.new()
	farm.name = "Farm"
	get_root().add_child(farm)

	# Connect to action_result signal to capture error messages
	farm.action_result.connect(_on_action_result)

	# Get BioticFlux biome
	var biotic_flux = farm.get_node_or_null("BioticFlux")
	if biotic_flux and biotic_flux.bath:
		print("\n📋 BioticFlux bath emojis:")
		for emoji in biotic_flux.bath.emoji_list:
			print("   ✓ %s" % emoji)
	else:
		print("\n⚠️  No BioticFlux biome found")

	# Check which plots belong to BioticFlux
	print("\n📍 Checking plot biomes...")
	for i in range(6):
		for j in range(2):
			var pos = Vector2i(i, j)
			var plot_biome = farm._get_plot_biome(pos)
			if plot_biome:
				print("   Plot %s → %s biome" % [pos, plot_biome.name])
			else:
				print("   Plot %s → No biome assigned" % pos)

	# Try planting
	print("\n🌾 Attempting to plant WHEAT at (0,0)...")
	var wheat_result = farm.build(Vector2i(0, 0), "wheat")
	print("   Result: %s" % ("SUCCESS" if wheat_result else "FAILED"))

	print("\n🍅 Attempting to plant TOMATO at (1,0)...")
	var tomato_result = farm.build(Vector2i(1, 0), "tomato")
	print("   Result: %s" % ("SUCCESS" if tomato_result else "FAILED"))

	print("\n" + "=".repeat(80))
	quit(0)

func _on_action_result(action: String, success: bool, message: String):
	print("   📢 Action result: %s | %s | %s" % [action, "✅" if success else "❌", message])
