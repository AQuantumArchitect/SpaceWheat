extends Node

## Test: Quantum visualization integration with FarmUI
## Creates a Farm, FarmUI, and verifies quantum glyphs appear

const Farm = preload("res://Core/Farm.gd")
const FarmUI = preload("res://UI/FarmUI.gd")
const GridConfig = preload("res://Core/GameState/GridConfig.gd")

var farm: Node = null
var farm_ui: Control = null


func _ready() -> void:
	print("\n======================================================================")
	print("QUANTUM FARMUI TEST - Integration with Farm visualization")
	print("======================================================================\n")

	# Create a simple farm with default configuration
	print("🌾 Creating Farm...")
	farm = Farm.new()
	add_child(farm)
	await get_tree().process_frame  # Wait for farm to initialize

	print("   ✓ Farm created")

	# Create FarmUI with the farm reference
	print("🎮 Creating FarmUI...")
	farm_ui = FarmUI.new(farm)
	farm_ui.size = Vector2(1280, 720)
	farm_ui.position = Vector2.ZERO
	add_child(farm_ui)
	await get_tree().process_frame  # Wait for UI to initialize

	print("   ✓ FarmUI created")

	# Verify quantum visualization exists
	if farm_ui.has_meta("quantum_visualization"):
		print("   ✓ Quantum visualization metadata found")

	if farm_ui.quantum_visualization:
		print("   ✓ Quantum visualization controller exists")
		print("   ✓ Glyphs count: %d" % farm_ui.quantum_visualization.glyphs.size())

		if farm_ui.quantum_visualization.glyphs.size() > 0:
			print("\n✅ SUCCESS: Quantum glyphs integrated into FarmUI!")
			for i in range(farm_ui.quantum_visualization.glyphs.size()):
				var glyph = farm_ui.quantum_visualization.glyphs[i]
				print("   [%d] %s ↔ %s at %s" % [
					i+1,
					glyph.qubit.north_emoji,
					glyph.qubit.south_emoji,
					glyph.position
				])
		else:
			print("\n⚠️  WARNING: Quantum visualization has no glyphs")
	else:
		print("   ✗ Quantum visualization controller not found!")

	print("\n📊 Farm state:")
	if farm and farm.grid and farm.grid.biomes:
		print("   • Biomes: %d" % farm.grid.biomes.size())
		for biome_name in farm.grid.biomes.keys():
			var biome = farm.grid.biomes[biome_name]
			if biome and biome.patches:
				print("   • %s patches: %d" % [biome_name, biome.patches.size()])

	print("\n✨ Test completed - check visual output for quantum glyphs above plot grid\n")


func _process(delta: float) -> void:
	# Auto-quit after 10 seconds for testing
	if get_tree().get_processed_frames() > 600:
		get_tree().quit()
