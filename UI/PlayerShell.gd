## PlayerShell - Player-level UI layer
## Handles:
## - Overlay/menu system (ESC menu, V vocabulary, C contracts, etc)
## - Player inventory/resource panel
## - Keyboard help, settings
## - Farm loading/switching (when implemented)
##
## This layer STAYS when farm changes

class_name PlayerShell
extends Control

const OverlayManager = preload("res://UI/Managers/OverlayManager.gd")

var current_farm_ui = null  # FarmUI instance (from scene)
var overlay_manager: OverlayManager = null
var farm: Node = null
var farm_ui_container: Control = null


func _ready() -> void:
	"""Initialize player shell UI - children defined in scene"""
	print("🎪 PlayerShell initializing...")

	# Get reference to containers from scene
	farm_ui_container = get_node("FarmUIContainer")
	var overlay_layer = get_node("OverlayLayer")

	# Create and initialize UILayoutManager (needs to be in scene tree for _ready())
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	var layout_manager = UILayoutManager.new()
	add_child(layout_manager)
	# _ready() will be called automatically by the engine

	# Create overlay manager and add to overlay layer
	overlay_manager = OverlayManager.new()
	overlay_layer.add_child(overlay_manager)

	# Setup overlay manager with proper dependencies
	overlay_manager.setup(layout_manager, null, null, null)

	# Initialize overlays (C/V/N/K/ESC menus)
	overlay_manager.create_overlays(overlay_layer)

	print("   ✅ Overlay manager created")
	print("✅ PlayerShell ready")

	# CRITICAL FIX: Force PlayerShell to match parent size after layout engine runs
	call_deferred("_ensure_full_size")


func _ensure_full_size() -> void:
	"""CRITICAL: Force PlayerShell and FarmUIContainer to fill their parents"""
	var parent = get_parent()
	if parent:
		size = parent.size
		print("✅ PlayerShell size forced to match parent: %.0f × %.0f" % [size.x, size.y])

	# Also force FarmUIContainer to fill PlayerShell
	if farm_ui_container:
		farm_ui_container.size = size
		print("✅ FarmUIContainer size forced: %.0f × %.0f" % [farm_ui_container.size.x, farm_ui_container.size.y])

	# Debug: Print toolbar sizes AFTER sizing is applied
	call_deferred("_print_toolbar_final_size")


func _print_toolbar_final_size() -> void:
	"""DEBUG: Print final toolbar sizes after all layout forcing is done"""
	print("\n🎯 FINAL TOOLBAR SIZES (after all forcing):")
	if farm_ui_container:
		print("  FarmUIContainer: %.0f × %.0f" % [farm_ui_container.size.x, farm_ui_container.size.y])
	# Get ActionPreviewRow and ToolSelectionRow
	var farm_ui = farm_ui_container.get_child(0) if farm_ui_container and farm_ui_container.get_child_count() > 0 else null
	if farm_ui:
		var main_container = farm_ui.get_node_or_null("MainContainer")
		if main_container:
			for child in main_container.get_children():
				if child.name in ["ActionPreviewRow", "ToolSelectionRow"]:
					print("  %s: %.0f × %.0f (at %.0f, %.0f)" % [child.name, child.size.x, child.size.y, child.position.x, child.position.y])
	print()


func load_farm(farm_ref: Node) -> void:
	"""Load a farm into FarmUIContainer (swappable)"""
	print("📂 Loading farm into PlayerShell...")

	# Clean up old farm UI if it exists
	if current_farm_ui:
		current_farm_ui.queue_free()
		current_farm_ui = null

	# Store farm reference
	farm = farm_ref

	# Load FarmUI as scene and add to container
	var farm_ui_scene = load("res://UI/FarmUI.tscn")
	if farm_ui_scene:
		current_farm_ui = farm_ui_scene.instantiate()
		farm_ui_container.add_child(current_farm_ui)

		# Setup farm immediately (no call_deferred - synchronous!)
		current_farm_ui.setup_farm(farm_ref)
		print("   ✅ FarmUI loaded and configured")
	else:
		print("❌ FarmUI.tscn not found - cannot load farm UI")
		return

	print("✅ Farm loaded into PlayerShell")




## OVERLAY SYSTEM INITIALIZATION

func _initialize_overlay_system() -> void:
	"""Initialize OverlayManager with minimal dependencies"""
	if not overlay_manager:
		return

	# Create a minimal UILayoutManager for compatibility
	# (OverlayManager requires it even if we don't use all features)
	const UILayoutManager = preload("res://UI/Managers/UILayoutManager.gd")
	var layout_mgr = UILayoutManager.new()

	# Get system dependencies from Farm if available
	# (These will be null but OverlayManager handles it gracefully)
	var vocab_sys = null
	var faction_mgr = null
	var conspiracy_net = null

	# Initialize OverlayManager with dependencies
	overlay_manager.setup(layout_mgr, vocab_sys, faction_mgr, conspiracy_net)

	# Create the overlay UI panels
	overlay_manager.create_overlays(self)

	print("🎭 Overlay system initialized")
