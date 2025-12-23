extends Node

## Minimal UI Test Scene
## Loads FarmView without simulation to test UI display
## This allows us to develop/test UI independently from game logic

const FarmView = preload("res://UI/FarmView.gd")

var farm_view: Control


func _ready() -> void:
	var separator = "========================================================================"
	print(separator)
	print("🎮 UI-Only Test Scene")
	print(separator)
	print("Loading FarmView without simulation...")

	# Create FarmView
	farm_view = FarmView.new()
	add_child(farm_view)

	# Note: Farm is NOT injected - UI will display with placeholder data
	# This allows testing UI layout, responsiveness, keyboard input handling

	print("\n✅ FarmView loaded and displaying!")
	print("   Status: Farm system NOT initialized")
	print("   Purpose: Test UI display without simulation")
	print("\nYou can:")
	print("  - Test UI layout (resize window)")
	print("  - Test keyboard input (1-6 for tools, Q/E/R for actions)")
	print("  - Test keyboard hints (K key)")
	print("  - Test overlay toggles (C/V/N/ESC)")
	print("\nWhen ready to add simulation:")
	print("  - Use GameStateManager.load() to inject Farm")
	print(separator + "\n")
