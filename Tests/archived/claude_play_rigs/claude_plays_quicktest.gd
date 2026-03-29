extends Node

const Farm = preload("res://Core/Farm.gd")

var farm: Farm
var completed: bool = false

func _ready():
	print("\n🎮 QUICK PLAY TEST\n")

	farm = Farm.new()
	add_child(farm)

	# Wait for farm init
	await get_tree().create_timer(0.5).timeout

	print("Playing 5 cycles to test strategy...\n")
	for i in range(5):
		print("\n==================================================")
		print("CYCLE %d" % (i + 1))
		print("==================================================")
		await _play_one_cycle()

	_final_results()

func _play_one_cycle():
	var pos = Vector2i(0, 0)

	# Check starting wheat
	var start_wheat = farm.economy.get_resource("🌾")
	print("Start: %d wheat" % start_wheat)

	# 1. Plant
	print("\n1. PLANT")
	farm.build(pos, "wheat")
	print("   Wheat: %d" % farm.economy.get_resource("🌾"))

	# 2. Wait and evolve
	print("\n2. WAIT 3 days (60s)")
	if farm.biotic_flux_biome:
		# Debug: Check bath state before
		if farm.biotic_flux_biome.bath:
			var bath = farm.biotic_flux_biome.bath
			print("   BEFORE bath state:")
			for emoji in bath.emoji_list:
				var amp = bath.get_amplitude(emoji)
				var prob = amp.abs_sq()
				print("      %s: prob=%.4f" % [emoji, prob])
			var before_proj = bath.project_onto_axis("🌾", "👥")
			print("   BEFORE: bath wheat projection energy = %.3f" % before_proj.radius)

		# Subdivide into small timesteps (Lindblad formula breaks with large dt)
		var total_time = 60.0
		var substep = 0.1  # 100ms per step
		var num_steps = int(total_time / substep)
		for step in range(num_steps):
			farm.biotic_flux_biome._process(substep)

		# Debug: Check bath state after
		if farm.biotic_flux_biome.bath:
			var bath = farm.biotic_flux_biome.bath
			print("   AFTER bath state:")
			for emoji in bath.emoji_list:
				var amp = bath.get_amplitude(emoji)
				var prob = amp.abs_sq()
				print("      %s: prob=%.4f" % [emoji, prob])
			var after_proj = bath.project_onto_axis("🌾", "👥")
			print("   AFTER: bath wheat projection energy = %.3f" % after_proj.radius)

		# Debug: Check plot's projection state
		var plot = farm.grid.get_plot(pos)
		if plot and plot.quantum_state:
			print("   Plot qubit energy = %.3f" % plot.quantum_state.energy)

		# Debug: Check if plot is in active_projections
		if farm.biotic_flux_biome:
			print("   Active projections: %d" % farm.biotic_flux_biome.active_projections.size())
			if farm.biotic_flux_biome.active_projections.has(pos):
				print("   ✓ Plot %s IS in active_projections" % pos)
			else:
				print("   ✗ Plot %s NOT in active_projections!" % pos)

	print("   ⚛️  Quantum energy built up!")

	# 3. Measure
	print("\n3. MEASURE")
	var outcome = farm.measure_plot(pos)
	print("   Outcome: %s" % outcome)

	# 4. Harvest
	print("\n4. HARVEST")
	var result = farm.harvest_plot(pos)
	print("   Yield: %d" % result.get("yield", 0))
	print("   Wheat: %d" % farm.economy.get_resource("🌾"))

	var end_wheat = farm.economy.get_resource("🌾")
	var profit = end_wheat - start_wheat
	print("\n📊 RESULT: %+d wheat (started %d, ended %d)" % [profit, start_wheat, end_wheat])

func _final_results():
	print("\n======================================================================")
	print("🏆 FINAL STATISTICS")
	print("======================================================================")

	var final_wheat = farm.economy.get_resource("🌾")
	var final_labor = farm.economy.get_resource("👥")
	var initial_wheat = 500  # Starting amount
	var total_profit = final_wheat - initial_wheat

	print("Final wheat: %d (started with %d)" % [final_wheat, initial_wheat])
	print("Final labor: %d" % final_labor)
	print("Total profit: %+d wheat" % total_profit)
	print("Average per cycle: %+.1f wheat" % (float(total_profit) / 5.0))

	if total_profit > 0:
		print("\n✅ STRATEGY WORKS! Net positive over 5 cycles!")
	elif total_profit == 0:
		print("\n⚖️  Break even - need more cycles for statistical significance")
	else:
		print("\n❌ Net negative - strategy needs adjustment")

	print("\n======================================================================")

	completed = true
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
