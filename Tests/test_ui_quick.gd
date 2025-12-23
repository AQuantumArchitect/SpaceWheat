#!/usr/bin/env -S godot --headless --script
extends SceneTree

func _initialize() -> void:
	print("\n=== QUICK UI DIAGNOSTIC ===\n")

	# Load and check the scene
	var scene = load("res://UITestOnly.tscn")
	if not scene:
		print("ERROR: Could not load UITestOnly.tscn")
		quit(1)

	var root = instantiate_scene(scene)
	root_node.add_child(root)

	# Wait one frame for initialization
	await process_frame

	# Find FarmUIController
	var farm_view = root.find_child("FarmView", true, false)
	if not farm_view:
		print("ERROR: FarmView not found")
		quit(1)

	var ui = farm_view.find_child("FarmUIController", true, false)
	if not ui:
		print("ERROR: FarmUIController not found")
		quit(1)

	print("✅ Found FarmUIController\n")
	print("UI Container Measurements:")
	print("─" * 50)

	# Check container sizes
	_check_container(ui, "top_bar", "TopBar")
	_check_container(ui, "plots_row", "PlotsRow")
	_check_container(ui, "play_area", "PlayArea")
	_check_container(ui, "actions_row", "ActionsRow")
	_check_container(ui, "bottom_bar", "BottomBar")

	print("\nViewport size: %s" % get_viewport().get_visible_rect().size)
	print("\nDone!\n")

	quit(0)

func _check_container(ui: Node, prop: String, name: String) -> void:
	var container = ui.get(prop)
	if not container:
		print("❌ %s: NOT FOUND" % name)
		return

	if not container is Control:
		print("❌ %s: NOT A CONTROL" % name)
		return

	var c = container as Control
	var y = c.global_position.y
	var h = c.size.y
	var expand = "EXPAND" if c.size_flags_vertical & Control.SIZE_EXPAND_FILL else "FIXED"

	print("📍 %s: y=%.0f h=%.0f [%s]" % [name, y, h, expand])

