extends Node

## Super simple harvest test

const Farm = preload("res://Core/Farm.gd")

var frame_count = 0
var farm = null
var state = "init"

func _ready():
	print("\n=== SIMPLE HARVEST TEST ===\n")
	print("Creating farm...")
	farm = Farm.new()
	add_child(farm)  # CRITICAL: Add to scene tree so _ready() is called!
	print("Farm created, waiting for initialization...\n")

func _process(_delta):
	frame_count += 1

	match state:
		"init":
			if frame_count > 20:
				print("Frame %d: Farm should be ready now" % frame_count)
				state = "plant"

		"plant":
			print("Frame %d: Planting..." % frame_count)
			farm.build(Vector2i(0, 0), "wheat")
			var plot = farm.grid.get_plot(Vector2i(0, 0))
			print("   Planted: %s" % plot.is_planted)
			state = "measure"

		"measure":
			if frame_count > 22:
				print("Frame %d: Measuring..." % frame_count)
				var outcome = farm.measure_plot(Vector2i(0, 0))
				print("   Measure outcome: %s" % outcome)
				var plot = farm.grid.get_plot(Vector2i(0, 0))
				print("   Measured: %s" % plot.has_been_measured)
				state = "harvest"

		"harvest":
			if frame_count > 24:
				print("Frame %d: Harvesting..." % frame_count)
				var result = farm.harvest_plot(Vector2i(0, 0))
				print("   Harvest success: %s" % result.get("success", false))
				print("   Outcome: %s" % result.get("outcome", "?"))
				print("   Yield: %d" % result.get("yield", 0))
				state = "done"

		"done":
			if frame_count > 26:
				print("\n=== TEST COMPLETE ===\n")
				get_tree().quit(0)
