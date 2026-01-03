extends Node

var farm: Node

func _ready():
	print("\n=== SIMPLE HAMILTONIAN TEST ===\n")

	# Wait for boot
	var boot_mgr = get_node_or_null("/root/BootManager")
	if boot_mgr and not boot_mgr.is_ready:
		await boot_mgr.game_ready
	for i in range(5):
		await get_tree().process_frame

	# Find farm
	var farm_view = get_tree().root.find_child("FarmView", true, false)
	farm = farm_view.get_farm() if farm_view else null

	if not farm:
		print("❌ Farm not found")
		get_tree().quit()
		return

	print("✅ Farm found")

	# Get biome
	var biome = farm.biotic_flux_biome
	if not biome or not biome.bath:
		print("❌ No biome or bath")
		get_tree().quit()
		return

	print("✅ Biome found: %s" % biome.get_biome_type())
	print("   Bath emojis: %s" % str(biome.bath.emoji_list))

	# Check Hamiltonian
	var H = biome.bath._hamiltonian
	if not H:
		print("❌ No Hamiltonian")
		get_tree().quit()
		return

	print("✅ Hamiltonian exists: %d×%d" % [H.dimension(), H.dimension()])

	# Check specific coupling
	var wheat_idx = biome.bath.emoji_to_index.get("🌾", -1)
	var labor_idx = biome.bath.emoji_to_index.get("👥", -1)

	if wheat_idx >= 0 and labor_idx >= 0:
		var coupling = H.get_element(wheat_idx, labor_idx)
		print("\n🔗 H[🌾][👥] coupling:")
		print("   Magnitude: %.6f" % coupling.abs())
		if coupling.abs() > 1e-10:
			print("   ✅ Non-zero coupling exists!")
		else:
			print("   ❌ Zero coupling - evolution won't build coherence!")
	else:
		print("❌ Emojis not in bath")

	print("\n=== TEST COMPLETE ===\n")
	get_tree().quit()
