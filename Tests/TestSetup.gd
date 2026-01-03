class_name TestSetup
extends RefCounted

## Test Setup Helper - Ensures IconRegistry available for SceneTree tests
##
## SceneTree tests bypass Godot's autoload system, so IconRegistry doesn't exist
## at /root/IconRegistry. This helper creates it manually.
##
## Usage:
##   extends SceneTree
##   const TestSetup = preload("res://Tests/TestSetup.gd")
##
##   func _init():
##       TestSetup.setup_iconregistry_for_tests(root)
##       farm = Farm.new()
##       root.add_child(farm)

static func setup_iconregistry_for_tests(scene_root: Viewport) -> void:
	"""Initialize IconRegistry in test environment

	Args:
		scene_root: The root viewport (usually `root` in SceneTree tests)
	"""
	# Check if already exists (idempotent)
	var existing = scene_root.get_node_or_null("/root/IconRegistry")
	if existing:
		print("✓ IconRegistry already exists in test environment")
		return

	# Load IconRegistry script
	var IconRegistryScript = load("res://Core/QuantumSubstrate/IconRegistry.gd")
	if not IconRegistryScript:
		push_error("Failed to load IconRegistry.gd!")
		return

	# Create instance
	var icon_registry = IconRegistryScript.new()
	icon_registry.name = "IconRegistry"
	scene_root.add_child(icon_registry)

	# Trigger initialization (loads CoreIcons)
	icon_registry._ready()

	print("✓ IconRegistry initialized for testing: %d icons" % icon_registry.icons.size())
