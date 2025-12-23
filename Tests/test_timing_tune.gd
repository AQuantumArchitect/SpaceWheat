#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Timing Tuning Test
## Find the right base_energy_rate so noon grows 0.3->0.9 in exactly 3 days (60s)

var farm = null
var game_manager = null
var test_complete = false

func _process(delta):
	if not test_complete:
		test_complete = true
		await run_test()

func run_test():
	print("\n" + "=".repeat(80))
	print("TIMING TUNING: Growth from 0.3 to 0.9 in 3 days")
	print("=".repeat(80) + "\n")
	
	const MemoryManager = preload("res://Core/GameState/MemoryManager.gd")
	game_manager = MemoryManager.new()
	root.add_child(game_manager)
	game_manager.new_game("default")
	
	const Farm = preload("res://Core/Farm.gd")
	farm = Farm.new()
	root.add_child(farm)
	await root.get_tree().process_frame
	
	# Setup: just noon imperium
	const PhaseConstraint = preload("res://Core/GameMechanics/PhaseConstraint.gd")
	var pos = Vector2i(0, 0)
	var noon_wheat = farm.biome.create_quantum_state(pos, "🌾", "👥", 0.0)
	noon_wheat.radius = 0.3
	farm.grid.get_plot(pos).plant(noon_wheat)
	farm.grid.get_plot(pos).phase_constraint = PhaseConstraint.new(
		PhaseConstraint.ConstraintType.FROZEN, 0.0, 0.0
	)
	
	print("Setup: Noon Imperium, starting radius 0.3")
	print("Target: Reach 0.9 radius in 60 seconds (3 days)")
	print("Current base_energy_rate in Biome.gd: 0.189")
	print("\n" + "─".repeat(80))
	
	farm.biome.time_elapsed = 0.0
	var snapshots = []
	
	# Run for 60 seconds at 60fps = 3600 frames
	print("Time (s) | Radius  | Growth  | Status")
	print("─".repeat(80))
	
	for frame_num in range(3601):  # 60 seconds at 60fps
		if frame_num > 0:
			farm.biome._process(0.016)
		
		# Capture every 5 seconds (300 frames)
		if frame_num % 300 == 0:
			var time_s = frame_num * 0.016
			var radius = noon_wheat.radius
			var growth = radius - 0.3
			
			var status = ""
			if radius < 0.6:
				status = "early"
			elif radius < 0.8:
				status = "midway"
			elif radius < 0.9:
				status = "approaching target"
			elif radius < 0.95:
				status = "✓ GOOD"
			elif radius < 1.0:
				status = "slightly over"
			else:
				status = "TOO HIGH"
			
			snapshots.append({"time": time_s, "radius": radius})
			print("  %6.1f | %.4f | %.4f | %s" % [time_s, radius, growth, status])
	
	# Find where we cross 0.9
	var cross_time = -1.0
	for i in range(1, snapshots.size()):
		if snapshots[i-1].radius < 0.9 and snapshots[i].radius >= 0.9:
			# Linear interpolation to find exact time
			var r1 = snapshots[i-1].radius
			var r2 = snapshots[i].radius
			var t1 = snapshots[i-1].time
			var t2 = snapshots[i].time
			cross_time = t1 + (0.9 - r1) / (r2 - r1) * (t2 - t1)
			break
	
	print("\n" + "─".repeat(80))
	if cross_time > 0:
		print("RESULT: Reached 0.9 at %.1f seconds (%.2f days)" % [cross_time, cross_time / 20.0])
		if abs(cross_time - 60.0) < 2.0:
			print("✓ PERFECT - Very close to target of 60 seconds!")
		elif cross_time < 60.0:
			print("✗ Too fast - need to reduce base_energy_rate")
		else:
			print("✗ Too slow - need to increase base_energy_rate")
	else:
		var final_radius = snapshots[-1].radius
		print("Did not reach 0.9 in 60 seconds. Final radius: %.4f" % final_radius)
		if final_radius > 0.9:
			print("✗ Grew too fast - reduce base_energy_rate")
		else:
			print("✗ Too slow - increase base_energy_rate")
	
	print("=".repeat(80))
	quit()
