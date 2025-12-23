#!/usr/bin/env -S godot --headless -s
extends SceneTree

func _init():
	print("🔧 STARTUP CHECK: _init called")

func _ready():
	print("🔧 STARTUP CHECK: _ready called - starting timer")
	var timer = Timer.new()
	root.add_child(timer)
	timer.timeout.connect(_run_test)
	timer.start(0.1)

func _run_test():
	print("🔧 TIMER CALLBACK: Running test...")

	var farm_script = load("res://Core/Farm.gd")
	print("Farm script loaded: %s" % (farm_script != null))

	if farm_script:
		var farm = farm_script.new()
		print("Farm instantiated: %s" % (farm != null))

		if farm:
			print("Grid exists: %s" % (farm.grid != null))
			print("Biome exists: %s" % (farm.biome != null))
			if farm.grid and farm.biome:
				print("✅ Farm created successfully!")

	print("Test complete - quitting")
	quit()
