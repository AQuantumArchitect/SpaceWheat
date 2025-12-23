#!/usr/bin/env -S godot --headless -s
extends SceneTree

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_test()

func run_test():
	print("\n" + "=".repeat(80))
	print("ENERGY RATE DEBUG: Comparing wheat vs mushroom energy transfer")
	print("=".repeat(80) + "\n")
	
	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")
	
	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame
	
	print("Icon Configuration:")
	var wheat_angle = farm.biome.wheat_icon.theta * 180.0 / PI
	var wheat_influence = pow(cos(farm.biome.wheat_icon.theta / 2.0), 2)
	print("  Wheat icon: %.1f° (influence: %.3f)" % [wheat_angle, wheat_influence])
	
	var mush_angle = farm.biome.mushroom_icon.theta * 180.0 / PI
	var mush_influence = pow(cos(farm.biome.mushroom_icon.theta / 2.0), 2)
	print("  Mushroom icon: %.1f° (influence: %.3f)" % [mush_angle, mush_influence])
	
	print("\nEnergy Rate Formula: base_rate × cos²((θ_qubit - θ_sun)/2) × cos²(θ_icon/2)")
	print("Base rate: 0.15154\n")
	
	# Setup plots
	var wheat_pos = Vector2i(0, 0)
	var wheat_plot = farm.grid.get_plot(wheat_pos)
	var wheat = farm.biome.create_quantum_state(wheat_pos, "🌾", "👥", 0.0)
	wheat.radius = 0.3
	wheat_plot.plant(wheat)
	
	var mush_pos = Vector2i(1, 0)
	var mush_plot = farm.grid.get_plot(mush_pos)
	mush_plot.plot_type = 2  # MUSHROOM
	var mushroom = farm.biome.create_quantum_state(mush_pos, "🍄", "🍂", PI)
	mushroom.radius = 0.3
	mush_plot.plant(mushroom)
	
	# Simulate and check energy rates at different sun phases
	print("Time (s) | Sun θ   | Wheat alignment | Wheat rate | Mush alignment | Mush rate")
	print("         | (phase) | cos²(...)/2)    | /dt        | cos²(...)/2)   | /dt")
	print("─".repeat(80))
	
	farm.biome.time_elapsed = 0.0
	for frame_num in range(0, 3601, 600):  # Every 10 seconds
		if frame_num > 0:
			for i in range(600):
				farm.biome._process(0.016)
		
		var time_s = frame_num * 0.016
		var sun_theta = farm.biome.sun_qubit.theta
		var sun_theta_deg = sun_theta * 180.0 / PI
		
		# Calculate alignment factors
		var wheat_align = pow(cos((wheat.theta - sun_theta) / 2.0), 2)
		var wheat_rate = 0.15154 * wheat_align * wheat_influence
		
		var mush_align = pow(cos((mushroom.theta - sun_theta) / 2.0), 2)
		var mush_rate = 0.15154 * mush_align * mush_influence
		
		var phase_name = "SUN" if sun_theta < PI else "MOON"
		
		print("  %6.1f | %s %3.0f | %.4f | %.5f | %.4f | %.5f" % [
			time_s, phase_name, sun_theta_deg, wheat_align, wheat_rate, mush_align, mush_rate
		])
	
	print("\n" + "─".repeat(80))
	print("Final Radii After 60 seconds (3 days):")
	print("  Wheat: %.4f (expected: minimal growth)" % wheat.radius)
	print("  Mushroom: %.4f (expected: ~0.9 like original wheat)" % mushroom.radius)
	print("=".repeat(80) + "\n")
	
	quit()
