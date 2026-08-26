class_name ResourcePanel
extends HBoxContainer

## ResourcePanel - Displays game resources dynamically with sci-fi styling
## Uses universal resource_changed signal from FarmEconomy
## Shows all emoji resources with their quantum unit values
## Supports arbitrary resources via emoji keys - no hardcoding needed!


# Layout manager reference (for dynamic scaling)
var layout_manager: Node  # Will be UILayoutManager instance

# Dynamic resource displays: emoji -> {container, label, units, update_order}
var resource_displays: Dictionary = {}

# Container for all resource displays
var resources_hbox: HBoxContainer

# Economy reference for initialization
var economy_ref: Node = null

# Update counter for tie-breaking (most recently updated wins ties)
var update_counter: int = 0



## Air between the seated panel's free (bottom) edge and the counter glyphs.
const GLYPH_FREE_MARGIN := 8.0


## The strip's band height — the layout manager is the authority; the fallback
## only matters in isolated widget tests that never hand one over.
func _band_height() -> float:
	if layout_manager and layout_manager.has_method("get_resource_bar_height"):
		return float(layout_manager.get_resource_bar_height())
	return size.y if size.y > 0.0 else 40.0


func _ready():
	_create_ui()
	# NO z override any more (docking pass 2026-08-25). This used to punch to
	# z 56, one above ChromeFrame, because the molding was painting over the
	# resource emojis. Under the docking system the bezel is ALWAYS on top —
	# it is the chassis this panel seats into — and the collision is prevented
	# geometrically instead: the counters are laid out below BEZEL_INNER_INSET,
	# so they never enter the molding's band and never need to out-rank it.
	# A docked band spans rail to rail. Without this the HBox sized to its own
	# content, so the seated panel's one drawn edge stopped in mid-air wherever
	# the wallet happened to end — a panel that docks on the left and simply
	# stops on the right is the asymmetry this pass exists to remove.
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Connect to resized signal to redraw background when size changes
	resized.connect(queue_redraw)


func _draw():
	# The strip's casing. This widget's old hand-rolled double-stroke is what
	# UIStyleFactory.draw_casing generalizes, so it now asks for the shared
	# recipe instead of spelling it — one place to swap when the real casing
	# art lands.
	#
	# A DOCKED PANEL. Three of its edges face the screen edge, so they seat into
	# the bezel at BEZEL_INNER_INSET and carry no line of their own — the
	# molding's inner ring IS the strip's top, left and right. Only the bottom
	# edge faces open space, so it is the only one drawn, and every corner goes
	# square because none of them is a free-to-free meeting. That is the owner's
	# "locked system": before this the trim overlapped the frame top and bottom
	# but held a 7px channel on the sides, which told three different stories
	# about one relationship.
	const FREE_EDGE_INSET := 3.0
	var bezel := UIStyleFactory.BEZEL_INNER_INSET
	UIStyleFactory.draw_casing(self,
		Rect2(Vector2(bezel, bezel), size - Vector2(bezel * 2.0, bezel + FREE_EDGE_INSET)),
		UIStyleFactory.CasingTone.STEEL, 2, true, UIStyleFactory.CasingEdge.BOTTOM)


func set_layout_manager(layout_mgr: Node):
	# Set the layout manager reference for dynamic scaling
	layout_manager = layout_mgr


func connect_to_economy(economy: Node) -> void:
	# Connect to economy's universal resource_changed signal

	# This is the ONLY way ResourcePanel gets data - directly from the simulation engine.
	# Graphics layer (ResourcePanel) does NOT store state, only displays it.
	if not economy:
		print("⚠️  ResourcePanel: economy is null, cannot connect signals")
		return

	economy_ref = economy

	# Connect to universal resource_changed signal (check if not already connected)
	if economy.has_signal("resource_changed"):
		if not economy.resource_changed.is_connected(_on_resource_changed):
			economy.resource_changed.connect(_on_resource_changed)
			print("✅ ResourcePanel connected to economy.resource_changed (HUD style)")

	# Initialize displays with current values (only show non-zero resources)
	if economy.has_method("get_resource") and "emoji_credits" in economy:
		for emoji in economy.emoji_credits.keys():
			var credits = economy.get_resource(emoji)
			if credits > 0:  # Only show resources with value > 0
				_ensure_display_exists(emoji)
				_update_display(emoji, credits)

		# Sort displays by priority then amount
		_sort_displays()


func _on_resource_changed(emoji: String, credits_amount: int) -> void:
	# Handle universal resource_changed signal from economy
	# Only create display if amount > 0 (hide zero-value resources)
	if credits_amount > 0:
		_ensure_display_exists(emoji)

	# Display credits directly - this matches what's stored in the economy
	# The 10x conversion happens at pop time (quantum → classical)
	_update_display(emoji, credits_amount)

	# Bubble sort this resource to its correct position
	_bubble_sort_resource(emoji)


func _ensure_display_exists(emoji: String) -> void:
	# Ensure a display exists for this emoji resource
	if resource_displays.has(emoji):
		return

	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var icon_font_size = layout_manager.get_scaled_font_size(17) if layout_manager else 17
	var label_font_size = layout_manager.get_scaled_font_size(14) if layout_manager else 14

	# The counters live in the band BELOW the bezel the strip docks into: the
	# panel spans the full band from y=0, but the bezel owns its top
	# BEZEL_INNER_INSET, so a container that centred in the whole band would put
	# glyphs under the molding. Bottom-aligning a container of exactly the free
	# height keeps every counter inside the seated panel, which is what lets the
	# strip drop its z-override and sit under the chassis like a real panel.
	var free_h := maxf(16.0, _band_height() - UIStyleFactory.BEZEL_INNER_INSET)
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)
	container.custom_minimum_size = Vector2(0.0, free_h)
	container.size_flags_vertical = Control.SIZE_SHRINK_END

	var value_label = Label.new()
	value_label.text = "0"
	value_label.add_theme_font_size_override("font_size", label_font_size)
	value_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))  # Slight blue tint
	container.add_child(value_label)

	var icon = EmojiDisplay.new()
	icon.emoji = emoji
	icon.font_size = icon_font_size
	# Sized from the free height the seated panel actually offers, not from the
	# font (a font multiple is blind to the band, so glyphs whose SVG art runs to
	# the edge of its canvas — 🌾, 🪵 — drew straight through the casing while
	# padded ones — 👥, 🍞 — looked fine) and not from the whole band either,
	# since the bezel owns its top.
	var glyph_px := maxf(14.0, free_h - GLYPH_FREE_MARGIN)
	icon.custom_minimum_size = Vector2(glyph_px, glyph_px)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(icon)

	resources_hbox.add_child(container)
	update_counter += 1
	resource_displays[emoji] = {
		"container": container,
		"label": value_label,
		"icon": icon,
		"units": 0,
		"update_order": update_counter
	}


## Global screen position of an emoji's counter (fly-target for the floating
## "+N" reward). Falls back to the panel centre before the slot first exists.
func get_emoji_slot_position(emoji: String) -> Vector2:
	if resource_displays.has(emoji):
		var container = resource_displays[emoji]["container"]
		if is_instance_valid(container) and container.visible:
			return container.get_global_rect().get_center()
	return get_global_rect().get_center()


## Scale-bounce an emoji counter when a reward flier lands on it.
func bounce_emoji(emoji: String) -> void:
	if not resource_displays.has(emoji):
		return
	var container = resource_displays[emoji]["container"]
	if not is_instance_valid(container):
		return
	container.pivot_offset = container.size / 2.0
	var tw = create_tween()
	tw.tween_property(container, "scale", Vector2(1.35, 1.35), 0.08)
	tw.tween_property(container, "scale", Vector2.ONE, 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_display(emoji: String, units: int) -> void:
	# Update the display for an emoji resource
	if not resource_displays.has(emoji):
		return

	resource_displays[emoji]["label"].text = str(units)
	resource_displays[emoji]["units"] = units
	update_counter += 1
	resource_displays[emoji]["update_order"] = update_counter

	# Hide resources with 0 credits, show resources with > 0
	var container = resource_displays[emoji]["container"]
	container.visible = (units > 0)


func _sort_displays() -> void:
	# Sort resource displays by units (descending), ties broken by update_order (most recent first)
	if not resources_hbox:
		return

	# Get all emojis and their sort keys
	var sort_data = []
	for emoji in resource_displays.keys():
		var data = resource_displays[emoji]
		sort_data.append({
			"emoji": emoji,
			"units": data["units"],
			"update_order": data["update_order"],
			"container": data["container"]
		})

	# Sort by units (descending), then update_order (descending for most recent)
	sort_data.sort_custom(func(a, b):
		if a["units"] != b["units"]:
			return a["units"] > b["units"]  # Higher units first
		return a["update_order"] > b["update_order"]  # More recent first for ties
	)

	# Reorder children
	for i in range(sort_data.size()):
		var container = sort_data[i]["container"]
		resources_hbox.move_child(container, i)


func _bubble_sort_resource(emoji: String) -> void:
	# Bubble sort a single resource to its correct position.

	# This is more efficient than full sort - only moves the changed item.
	# Sort order: highest units first, ties broken by most recently updated.
	if not resources_hbox or not resource_displays.has(emoji):
		return

	var container = resource_displays[emoji]["container"]
	var my_units = resource_displays[emoji]["units"]
	var my_order = resource_displays[emoji]["update_order"]
	var current_idx = container.get_index()

	# Bubble up: swap with left neighbor while we should be before them
	while current_idx > 0:
		var left_container = resources_hbox.get_child(current_idx - 1)
		var left_emoji = _find_emoji_for_container(left_container)
		if left_emoji == "":
			break

		var left_data = resource_displays[left_emoji]
		var left_units = left_data["units"]
		var left_order = left_data["update_order"]

		# Should we be before the left neighbor?
		var should_swap = false
		if my_units > left_units:
			should_swap = true
		elif my_units == left_units and my_order > left_order:
			should_swap = true  # Same units, but we're more recent

		if should_swap:
			resources_hbox.move_child(container, current_idx - 1)
			current_idx -= 1
		else:
			break

	# Bubble down: swap with right neighbor while they should be before us
	current_idx = container.get_index()
	var total_children = resources_hbox.get_child_count()

	while current_idx < total_children - 1:
		var right_container = resources_hbox.get_child(current_idx + 1)
		var right_emoji = _find_emoji_for_container(right_container)
		if right_emoji == "":
			break

		var right_data = resource_displays[right_emoji]
		var right_units = right_data["units"]
		var right_order = right_data["update_order"]

		# Should the right neighbor be before us?
		var should_swap = false
		if right_units > my_units:
			should_swap = true
		elif right_units == my_units and right_order > my_order:
			should_swap = true  # Same units, but they're more recent

		if should_swap:
			resources_hbox.move_child(container, current_idx + 1)
			current_idx += 1
		else:
			break


func _find_emoji_for_container(container: Node) -> String:
	# Find the emoji key for a given container node
	for emoji in resource_displays.keys():
		if resource_displays[emoji]["container"] == container:
			return emoji
	return ""




func _create_ui():
	# Get scale factor from layout manager (or default to 1.0 if not set)
	var scale_factor = layout_manager.scale_factor if layout_manager else 1.0
	var resource_spacing = int(15 * scale_factor)
	var main_spacing = int(20 * scale_factor)

	add_theme_constant_override("separation", main_spacing)

	# Breathing room between the new left hairline and the first counter —
	# IGNORE like everything in this strip, and invisible to the sorting code
	# (it indexes resources_hbox children, not panel children).
	var lead := Control.new()
	lead.custom_minimum_size = Vector2(int(20 * scale_factor), 0)
	lead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lead)

	# Create container for all resource displays
	resources_hbox = HBoxContainer.new()
	resources_hbox.add_theme_constant_override("separation", resource_spacing)
	add_child(resources_hbox)

	# The mirror of `lead`. A wide-enough wallet used to run its last emoji all
	# the way into the brass molding's inner ring at the right corner (owner
	# screenshot 2026-08-25: an emoji visibly cut by the frame) — the z fix
	# stopped the frame painting OVER the strip, but nothing yet stopped the
	# strip from reaching under it. This does.
	var tail := Control.new()
	tail.custom_minimum_size = Vector2(int(20 * scale_factor), 0)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tail)

	print("🖼️  ResourcePanel initialized with HUD style background")

	# Note: Individual resource displays are created dynamically
	# when connect_to_economy() is called or when resources change


func get_snapshot() -> Dictionary:
	# Return structured snapshot of visible resources.
	var resources: Dictionary = {}
	for emoji in resource_displays.keys():
		var data = resource_displays[emoji]
		if data["units"] > 0:
			resources[emoji] = data["units"]
	return {"resources": resources}
