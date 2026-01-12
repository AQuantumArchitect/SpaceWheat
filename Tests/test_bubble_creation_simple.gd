extends SceneTree

## Simple test: Verify plot_planted signal fires and bubbles are attempted

func _init():
	print("\n=== TEST: Bubble Creation on Plant ===")
	
	# Load required classes
	var VerboseConfig = load("res://Core/Config/VerboseConfig.gd")
	var verbose = VerboseConfig.new()
	var Farm = load("res://Core/Farm.gd")
	
	# Create farm
	var farm = Farm.new()
	root.add_child(farm)
	
	# Track plot_planted signal
	var signal_received = false
	farm.plot_planted.connect(func(pos, plant_type):
		print("✅ plot_planted signal fired: %s at %s" % [plant_type, pos])
		signal_received = true
	)
	
	# Give resources
	farm.economy.add_resource("🌾", 100)
	
	# Plant wheat
	print("\nPlanting wheat at (2,0)...")
	var success = farm.build(Vector2i(2, 0), "wheat")
	print("Build result: %s" % success)
	
	# Check signal
	if signal_received:
		print("✅ Signal was received")
	else:
		print("❌ Signal was NOT received")
	
	print("\n=== TEST COMPLETE ===")
	quit()
