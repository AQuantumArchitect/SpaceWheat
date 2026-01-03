extends SceneTree

## Test that IconRegistry loads before biomes need it

func _init():
	print("\n" + "=".repeat(80))
	print("ICONREGISTRY EARLY LOAD TEST")
	print("=".repeat(80))

	# Check if IconRegistry is available
	print("\n1. Checking if IconRegistry is available...")
	var root = get_root()
	var icon_registry = null
	if root:
		icon_registry = root.get_node_or_null("IconRegistry")

	if icon_registry:
		print("✅ IconRegistry found")
		print("   Icons loaded: %d" % icon_registry.icons.size())
	else:
		print("❌ IconRegistry NOT found")

	# Create a Farm and check if biomes have baths
	print("\n2. Creating Farm...")
	var Farm = load("res://Core/Farm.gd")
	var farm = Farm.new()
	farm._ready()

	print("\n3. Checking biome baths...")
	if farm.grid and farm.grid.biomes:
		for biome_name in farm.grid.biomes:
			var biome = farm.grid.biomes[biome_name]
			if biome.bath:
				print("✅ %s has bath with %d emojis" % [biome_name, biome.bath.emoji_list.size()])
			else:
				print("❌ %s has NO BATH" % biome_name)
	else:
		print("❌ No biomes found")

	print("\n" + "=".repeat(80))
	print("TEST COMPLETE")
	print("=".repeat(80))

	quit()
