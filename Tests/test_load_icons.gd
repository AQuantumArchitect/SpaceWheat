#!/usr/bin/env -S godot --headless -s
extends SceneTree

func _ready():
	print("Testing icon loading...")

	print("Attempting to load WheatIcon...")
	var WheatIcon = preload("res://Core/Icons/WheatIcon.gd")
	if WheatIcon:
		print("✓ WheatIcon loaded: ", WheatIcon)
		var w = WheatIcon.new()
		print("✓ WheatIcon instantiated: ", w)

	print("Done")
	quit()
