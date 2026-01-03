#!/bin/bash
# Test bath-first integration with plot planting

echo "🧪 Testing bath-first quantum mechanics integration..."
echo ""
echo "Creating test script..."

cat > /tmp/test_bath_planting.gd << 'EOF'
extends SceneTree

func _init():
	print("\n════════════════════════════════════════════════════════════════")
	print("🧪 BATH-FIRST INTEGRATION TEST")
	print("   Testing plot planting with bath projections")
	print("════════════════════════════════════════════════════════════════\n")

	# Load required classes
	var Farm = load("res://Core/Farm.gd")
	var FarmGrid = load("res://Core/GameMechanics/FarmGrid.gd")

	# Create farm (sets up biomes in bath mode)
	print("1️⃣ Creating farm with bath-mode biomes...")
	var farm = Farm.new()
	root.add_child(farm)

	# Wait for initialization
	await get_tree().process_frame
	await get_tree().process_frame

	# Check biomes are in bath mode
	print("\n2️⃣ Verifying biome bath mode...")
	if farm.biotic_flux_biome and farm.biotic_flux_biome.use_bath_mode:
		print("   ✅ BioticFlux in bath mode: %d basis states" % farm.biotic_flux_biome.bath.emoji_list.size())
	else:
		print("   ❌ BioticFlux NOT in bath mode!")

	if farm.forest_biome and farm.forest_biome.use_bath_mode:
		print("   ✅ Forest in bath mode: %d basis states" % farm.forest_biome.bath.emoji_list.size())
	else:
		print("   ❌ Forest NOT in bath mode!")

	# Test planting in BioticFlux biome (plots U,I,O,P = positions 2-5 in row 0)
	print("\n3️⃣ Testing plot planting with bath projections...")
	var grid = farm.grid

	# Plant wheat at position (2,0) - assigned to BioticFlux
	var pos = Vector2i(2, 0)
	print("\n   🌾 Planting wheat at %s (BioticFlux biome)..." % pos)
	var success = grid.plant(pos, "wheat")

	if success:
		var plot = grid.get_plot(pos)
		if plot and plot.quantum_state:
			print("      ✅ Plot planted successfully")
			print("      📊 Quantum state: %s ↔ %s" % [plot.quantum_state.emoji_north, plot.quantum_state.emoji_south])
			print("      🔢 Theta: %.3f, Phi: %.3f" % [plot.quantum_state.theta, plot.quantum_state.phi])

			# Check if it's a projection (registered in biome's active_projections)
			if farm.biotic_flux_biome.active_projections.has(pos):
				print("      ✅ BATH PROJECTION created (registered in biome)")
				var proj = farm.biotic_flux_biome.active_projections[pos]
				print("         North: %s, South: %s" % [proj.north, proj.south])
			else:
				print("      ⚠️  Standalone qubit (not a bath projection)")
		else:
			print("      ❌ Plot planted but no quantum state!")
	else:
		print("      ❌ Planting failed!")

	# Plant mushroom at position (3,0) - also BioticFlux
	pos = Vector2i(3, 0)
	print("\n   🍄 Planting mushroom at %s (BioticFlux biome)..." % pos)
	success = grid.plant(pos, "mushroom")

	if success and farm.biotic_flux_biome.active_projections.has(pos):
		print("      ✅ BATH PROJECTION created")

	# Test Forest biome plot (positions 0-3 in row 1)
	pos = Vector2i(0, 1)
	print("\n   🌾 Planting wheat at %s (Forest biome)..." % pos)
	success = grid.plant(pos, "wheat")

	if success and farm.forest_biome.active_projections.has(pos):
		print("      ✅ BATH PROJECTION created in Forest")
		print("      📊 Forest now has %d projections" % farm.forest_biome.active_projections.size())

	# Summary
	print("\n4️⃣ Summary:")
	print("   BioticFlux projections: %d" % farm.biotic_flux_biome.active_projections.size())
	print("   Forest projections: %d" % farm.forest_biome.active_projections.size())

	if farm.biotic_flux_biome.active_projections.size() > 0 or farm.forest_biome.active_projections.size() > 0:
		print("\n✅ BATH-FIRST INTEGRATION SUCCESSFUL!")
		print("   Plots are now projections from quantum baths")
	else:
		print("\n❌ INTEGRATION FAILED - No bath projections created")

	print("\n════════════════════════════════════════════════════════════════\n")

	quit(0)
EOF

echo "Running test..."
godot --headless -s /tmp/test_bath_planting.gd 2>&1 | grep -v "^$"
