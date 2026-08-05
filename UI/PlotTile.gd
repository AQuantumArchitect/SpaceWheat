class_name PlotTile
extends Control

# Preload EmojiDisplay to ensure it's available at parse time

## PlotTile - Visual representation of a single farm plot
## Part of the emoji lattice grid
## Decoupled from WheatPlot - uses display snapshots.

signal clicked(grid_position: Vector2i)
signal long_pressed(grid_position: Vector2i)

# Plot data (set by FarmView) - display snapshot dictionary
var grid_position: Vector2i = Vector2i.ZERO
var plot_ui_data = null

# Visual state
var is_selected: bool = false
var is_hovered: bool = false
var is_selected_by_keyboard: bool = false  # Phase 3: Track keyboard vs mouse selection
var is_checkbox_selected: bool = false  # NEW: Multi-select checkbox state
var is_active_ring: bool = false  # WASD cursor is on the plot ring

const ACTIVE_RING_BORDER_COLOR: Color = Color(1.0, 0.75, 0.2, 1.0)  # Amber, matches SelectionButtonRow

# Long press detection
var press_timer: float = 0.0
var is_pressing: bool = false
const LONG_PRESS_TIME = 0.5

# Performance optimization: Dirty flag for event-driven updates
var _visuals_dirty: bool = true  # Start dirty to ensure initial draw

# UI elements (will be created in _ready)
var background: ColorRect
var emoji_label_north: EmojiDisplay  # North pole emoji (quantum superposition) - auto SVG/text fallback
var emoji_label_south: EmojiDisplay  # South pole emoji (quantum superposition) - auto SVG/text fallback
var growth_bar: ProgressBar
var selection_border: ColorRect
var territory_border: ColorRect  # Shows Icon control
var number_label: Label
var checkbox_label: Label  # NEW: Multi-select checkbox (☐/☑)
var lindblad_indicator: Label  # Persistent Lindblad pump/drain indicator
var entanglement_indicator: Control  # Visual ring showing entanglement status
var entanglement_counter: Label  # Shows number of entangled connections

# Colors (backgrounds at 60% transparency = 0.4 alpha, text stays opaque)
const COLOR_EMPTY = Color(0.15, 0.15, 0.15, 0.4)
const COLOR_MEMORY = Color(0.22, 0.2, 0.18, 0.28)
const COLOR_SELECTED = Color(0.3, 0.6, 0.8, 0.5)  # Slightly more visible when selected
const COLOR_HOVER = Color(0.25, 0.25, 0.25, 0.4)
const COLOR_NATURAL = Color(0.2, 0.8, 0.2, 0.4)  # Green (🌾)
const COLOR_LABOR = Color(0.2, 0.4, 0.8, 0.4)    # Blue (👥)
const COLOR_MATURE = Color(0.9, 0.7, 0.2, 0.4)   # Golden

# Icon territory colors
const COLOR_BIOTIC = Color(0.3, 1.0, 0.3, 0.6)     # Green glow
const COLOR_CHAOS = Color(1.0, 0.3, 0.3, 0.6)      # Red chaos
const COLOR_IMPERIUM = Color(0.8, 0.6, 1.0, 0.6)   # Purple/gold
const COLOR_NEUTRAL = Color(0.3, 0.3, 0.3, 0.3)    # Dim gray

# PCB styling colors
const COLOR_PCB_BASE = Color(0.1, 0.12, 0.15)      # Dark PCB base
const COLOR_PCB_COPPER = Color(0.8, 0.5, 0.1)      # Copper traces
const COLOR_PCB_SOLDER = Color(0.6, 0.6, 0.6)      # Solder pads
const COLOR_PCB_EDGE_LIGHT = Color(0.25, 0.25, 0.25)  # Edge highlight
const COLOR_PCB_EDGE_DARK = Color(0.08, 0.08, 0.08)   # Edge shadow

# Entanglement visualization colors
const COLOR_ENTANGLEMENT_RING = Color(0.0, 1.0, 1.0, 0.8)  # Bright cyan
const COLOR_ENTANGLEMENT_GLOW = Color(0.0, 1.0, 1.0, 0.3)  # Faint cyan glow

# Berry-phase ripeness ring: a register being tracked fills an arc toward 2π;
# when ripe (incorporate-ready) it closes into a bright violet ring + glow.
const COLOR_BERRY_FILL = Color(0.6, 0.4, 1.0, 0.7)    # Violet, accumulating
const COLOR_BERRY_RIPE = Color(0.85, 0.6, 1.0, 0.95)  # Bright violet, ripe
const COLOR_BERRY_GLOW = Color(0.7, 0.45, 1.0, 0.35)  # Faint violet glow

# Reference to territory router (set by FarmView)
var territory_router = null

# Reference to biome for temperature/energy effects (set by FarmView)
var biome = null


func _ready():
	# Setup visual components FIRST (before setting size, which triggers resize notification)
	_create_ui_elements()

	# Don't set grid position number - let set_label_text() provide keyboard labels only
	# Prevent duplicate label overlap when plot key labels are rendered on top.
	number_label.text = ""

	# Now set size properties (this triggers NOTIFICATION_RESIZED, which calls _layout_elements)
	custom_minimum_size = Vector2(80, 80)
	size = Vector2(80, 80)  # Explicit size for input detection
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to quantum bubbles below

	# Explicitly layout elements since NOTIFICATION_RESIZED may not fire in all cases
	_layout_elements()

	# Performance optimization: Start with processing disabled for empty tiles
	# Processing is enabled when plot data is set via set_plot_data()
	set_process(false)
	set_physics_process(true)  # Physics process updates shared glow value
	_visuals_dirty = true  # Ensure first update when data arrives


func set_label_text(label: String) -> void:
	# Set custom label text on the tile (e.g., keyboard shortcut letter)
	if number_label:
		number_label.text = label



func _create_ui_elements():
	# Safety check: if elements already exist, DON'T recreate them
	if background != null:
		VerboseHelper.warn("ui", "tile", "PlotTile._create_ui_elements() called after background already exists")
		return

	# Background
	background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.color = COLOR_EMPTY  # Set initial color so tiles are visible immediately
	add_child(background)

	# Territory border (shows Icon control)
	territory_border = ColorRect.new()
	territory_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	territory_border.color = COLOR_NEUTRAL
	territory_border.z_index = 1  # Above background
	add_child(territory_border)

	# Selection border
	selection_border = ColorRect.new()
	selection_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection_border.color = COLOR_SELECTED
	selection_border.visible = false
	selection_border.z_index = 2  # Above territory border
	add_child(selection_border)

	# Emoji display - DUAL EMOJI DISPLAY for quantum superposition
	# Uses EmojiDisplay component for automatic SVG glyph / emoji text fallback
	# North pole emoji (e.g., 🌾 for wheat)
	emoji_label_north = EmojiDisplay.new()
	emoji_label_north.font_size = 36
	emoji_label_north.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label_north.z_index = 3  # Above selection border
	emoji_label_north.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill parent
	add_child(emoji_label_north)

	# South pole emoji (e.g., 👥 for wheat, 🍂 for mushroom)
	emoji_label_south = EmojiDisplay.new()
	emoji_label_south.font_size = 36
	emoji_label_south.mouse_filter = Control.MOUSE_FILTER_IGNORE
	emoji_label_south.z_index = 3  # Same layer as north (overlaid)
	emoji_label_south.set_anchors_preset(Control.PRESET_FULL_RECT)  # Fill parent
	add_child(emoji_label_south)

	# Growth bar
	growth_bar = ProgressBar.new()
	growth_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	growth_bar.show_percentage = false
	growth_bar.visible = false
	add_child(growth_bar)

	# Number label (shows plot index for navigation - Phase 3: Larger for keyboard visibility)
	number_label = Label.new()
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.add_theme_font_size_override("font_size", 32)  # Phase 3: Increased from 12
	number_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 0.9))  # Phase 3: Bright yellow
	number_label.z_index = 5  # Above all other elements for visibility
	add_child(number_label)

	# Checkbox label (shows multi-select checkbox - NEW)
	checkbox_label = Label.new()
	checkbox_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkbox_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	checkbox_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkbox_label.add_theme_font_size_override("font_size", 32)  # Larger for visibility
	checkbox_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))  # Bright cyan
	checkbox_label.text = "☐"  # Empty checkbox by default
	checkbox_label.z_index = 5  # Above all other elements for visibility
	add_child(checkbox_label)

	# Persistent Lindblad indicator (top-left corner)
	lindblad_indicator = Label.new()
	lindblad_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lindblad_indicator.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	lindblad_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lindblad_indicator.add_theme_font_size_override("font_size", 14)
	lindblad_indicator.text = ""
	lindblad_indicator.z_index = 4
	lindblad_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(lindblad_indicator)

	# Entanglement indicator (glowing ring when plot is entangled)
	entanglement_indicator = Control.new()
	entanglement_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entanglement_indicator.z_index = 2  # Above territory border but below emojis
	entanglement_indicator.custom_minimum_size = size
	entanglement_indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(entanglement_indicator)

	# Entanglement counter (shows number of entangled plots in top-right corner)
	entanglement_counter = Label.new()
	entanglement_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	entanglement_counter.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	entanglement_counter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entanglement_counter.add_theme_font_size_override("font_size", 14)
	entanglement_counter.add_theme_color_override("font_color", COLOR_ENTANGLEMENT_RING)
	entanglement_counter.text = ""
	entanglement_counter.z_index = 4  # Above entanglement indicator
	add_child(entanglement_counter)


func _process(delta):
	# Track long press timer
	if is_pressing:
		press_timer += delta
		if press_timer >= LONG_PRESS_TIME:
			# Long press detected
			VerboseHelper.debug("ui", "tile", "PlotTile long press detected at %s" % grid_position)
			long_pressed.emit(grid_position)
			is_pressing = false
			press_timer = 0.0

	# Performance optimization: Only update data-dependent visuals when dirty
	# (quantum state, emojis, probabilities - these change on physics tick)
	if _visuals_dirty:
		_update_visuals()
		_visuals_dirty = false


## REMOVED: _gui_input() was dead code - PlotTile has mouse_filter=IGNORE
## Input is now handled by PlotGridDisplay._input() for plots
## and QuantumForceGraph._unhandled_input() for bubbles


func _update_visuals():
	if plot_ui_data == null:
		_show_empty_state()
		return

	if not plot_ui_data.get("is_planted", false):
		if plot_ui_data.get("memory_visible", false):
			_show_memory_state()
		else:
			_show_empty_state()
	else:
		# Quantum-only mechanics: plants are instant full size
		# Always show mature state when planted
		_show_mature_state()

	# Update territory border based on Icon control
	_update_territory_border()

	# Update entanglement visualization
	_update_entanglement_display()

	# Update Lindblad indicator
	_update_lindblad_indicator()

	# Update selection border
	selection_border.visible = is_selected


func _update_territory_border():
	# Update territory border color based on Icon control
	if not territory_router:
		territory_border.color = COLOR_NEUTRAL
		return

	var controller = territory_router.get_plot_controller(grid_position)

	match controller:
		"biotic":
			territory_border.color = COLOR_BIOTIC
		"chaos":
			territory_border.color = COLOR_CHAOS
		"imperium":
			territory_border.color = COLOR_IMPERIUM
		_:
			territory_border.color = COLOR_NEUTRAL


func _show_empty_state():
	emoji_label_north.emoji = ""
	emoji_label_south.emoji = ""
	emoji_label_north.modulate.a = 0.0
	emoji_label_south.modulate.a = 0.0
	growth_bar.visible = false
	background.color = COLOR_EMPTY if not is_selected else COLOR_SELECTED

	if lindblad_indicator:
		lindblad_indicator.text = ""


func _show_memory_state():
	# Mini-Metro pass: the STATION bubble owns all emoji identity — tiles are
	# quiet anchor chips (key letter + selection ring + territory border). A
	# memory ghost here would also leak the axis of an unrevealed plot.
	emoji_label_north.emoji = ""
	emoji_label_south.emoji = ""
	emoji_label_north.modulate.a = 0.0
	emoji_label_south.modulate.a = 0.0
	growth_bar.visible = false
	background.color = COLOR_MEMORY if not is_selected else COLOR_SELECTED.darkened(0.15)

	if lindblad_indicator:
		lindblad_indicator.text = "·"
		lindblad_indicator.modulate = Color(0.8, 0.7, 0.5, 0.55)


func _show_growing_state():
	# Phase 4: PlotUIData doesn't track growth progress
	# Just use _show_mature_state() instead
	_show_mature_state()


func _show_mature_state():
	# Mini-Metro pass: no tile emoji — the station bubble anchored on this tile
	# renders the pole glyphs (soft dual-glyph superposition). Duplicating them
	# at 36pt under the disc read as "a second thing" in playtests.
	growth_bar.visible = false
	emoji_label_north.emoji = ""
	emoji_label_south.emoji = ""
	emoji_label_north.modulate.a = 0.0
	emoji_label_south.modulate.a = 0.0

	# Stable mature crop mark; ambient glow is reserved for state/event channels.
	var base_golden = COLOR_MATURE
	background.color = base_golden.lightened(0.1)

func _get_temperature_color(normalized_theta: float) -> Color:
	# Map theta to temperature color (blue → white → red)
	if normalized_theta < 0.5:
		# Blue to white (cold to neutral)
		var t = normalized_theta * 2.0
		return Color(0.3, 0.4, 0.8).lerp(Color(0.9, 0.9, 0.9), t)
	else:
		# White to red (neutral to hot)
		var t = (normalized_theta - 0.5) * 2.0
		return Color(0.9, 0.9, 0.9).lerp(Color(0.9, 0.3, 0.2), t)


func set_selected(selected: bool, by_keyboard: bool = false):
	# Set selection state with optional keyboard indicator

	# Args:
	# selected: Whether the plot is selected
	# by_keyboard: Whether selection was made by keyboard (shows cyan) vs mouse (shows blue)
	is_selected = selected
	is_selected_by_keyboard = by_keyboard

	if is_selected:
		selection_border.visible = true
		# Phase 3: Different color for keyboard vs mouse selection
		if by_keyboard:
			selection_border.color = Color(0.0, 1.0, 1.0)  # Cyan for keyboard
		else:
			selection_border.color = Color(0.3, 0.6, 0.8)  # Blue for mouse
	else:
		selection_border.visible = false


func set_active_ring(active: bool) -> void:
	if is_active_ring == active:
		return
	is_active_ring = active
	queue_redraw()


func set_checkbox_selected(selected: bool) -> void:
	# Update the multi-select checkbox visual state

	# Args:
	# selected: Whether the plot is in the multi-select group
	is_checkbox_selected = selected
	if checkbox_label:
		checkbox_label.text = "☑" if selected else "☐"
		# Change color intensity when selected
		if selected:
			checkbox_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 1.0))  # Bright cyan
		else:
			checkbox_label.add_theme_color_override("font_color", Color(0.0, 1.0, 1.0, 0.6))  # Dimmed cyan (still visible)


func _notification(what):
	if what == NOTIFICATION_RESIZED:
		_layout_elements()


func _layout_elements():
	# Safety check: UI elements must exist
	if not background or not territory_border or not selection_border or not emoji_label_north or not emoji_label_south or not growth_bar or not number_label or not checkbox_label:
		return

	var rect = get_rect()

	# Background fills entire tile
	background.position = Vector2.ZERO
	background.size = rect.size

	# Territory border (colored glow overlay showing Icon control)
	territory_border.position = Vector2.ZERO
	territory_border.size = rect.size

	# Selection border (inset slightly, shows when selected)
	var border_width = 3
	selection_border.position = Vector2(border_width, border_width)
	selection_border.size = rect.size - Vector2(border_width * 2, border_width * 2)

	# Emoji labels centered and overlaid (for quantum superposition)
	# NOTE: emoji labels have PRESET_FULL_RECT anchors, so they automatically
	# fill the parent. Setting position/size would conflict with anchors.
	# The anchors handle sizing - no manual position/size needed.

	# Growth bar at bottom
	var bar_height = 8
	growth_bar.position = Vector2(4, rect.size.y - bar_height - 4)
	growth_bar.size = Vector2(rect.size.x - 8, bar_height)

	# Number label in top-left corner
	number_label.position = Vector2(4, 2)
	number_label.size = Vector2(30, 20)

	# Checkbox label in top-right corner (NEW - multi-select)
	checkbox_label.position = Vector2(rect.size.x - 35, 0)
	checkbox_label.size = Vector2(35, 32)

	queue_redraw()


func _draw():
	# Draw PCB-style borders, solder pads, traces, and entanglement indicators
	var rect = get_rect()
	if rect.size.x <= 0 or rect.size.y <= 0:
		return

	# Amber outer border when WASD cursor is on the plot ring
	if is_active_ring:
		draw_rect(Rect2(Vector2.ZERO, size), ACTIVE_RING_BORDER_COLOR, false, 2.0)

	# Draw PCB-style beveled edge (metallic look)
	_draw_pcb_edges(rect)

	# Draw solder pads at corners
	_draw_solder_pads(rect)

	# Draw subtle circuit traces
	_draw_circuit_traces(rect)

	# Draw entanglement ring if plot is entangled
	if plot_ui_data and plot_ui_data.get("is_planted", false):
		var entangled_count = 0
		if plot_ui_data.has("entangled_plots"):
			entangled_count = plot_ui_data.get("entangled_plots", []).size()
		if entangled_count > 0:
			_draw_entanglement_ring_inline(rect, entangled_count)

	# Berry-phase ripeness ring — the incorporate cue (drawn for any tracked register).
	if plot_ui_data and plot_ui_data.get("berry_tracked", false):
		_draw_berry_ring_inline(rect)


func _draw_pcb_edges(rect: Rect2):
	# Draw beveled metallic edges like a PCB component
	var edge_width = 2

	# Top edge highlight
	draw_line(Vector2(0, 0), Vector2(rect.size.x, 0), COLOR_PCB_EDGE_LIGHT, edge_width)
	draw_line(Vector2(0, 1), Vector2(rect.size.x, 1), COLOR_PCB_EDGE_LIGHT.darkened(0.3), edge_width)

	# Left edge highlight
	draw_line(Vector2(0, 0), Vector2(0, rect.size.y), COLOR_PCB_EDGE_LIGHT, edge_width)
	draw_line(Vector2(1, 0), Vector2(1, rect.size.y), COLOR_PCB_EDGE_LIGHT.darkened(0.3), edge_width)

	# Bottom edge shadow
	draw_line(Vector2(0, rect.size.y - 1), Vector2(rect.size.x, rect.size.y - 1), COLOR_PCB_EDGE_DARK, edge_width)
	draw_line(Vector2(0, rect.size.y - 2), Vector2(rect.size.x, rect.size.y - 2), COLOR_PCB_EDGE_DARK.lightened(0.2), edge_width)

	# Right edge shadow
	draw_line(Vector2(rect.size.x - 1, 0), Vector2(rect.size.x - 1, rect.size.y), COLOR_PCB_EDGE_DARK, edge_width)
	draw_line(Vector2(rect.size.x - 2, 0), Vector2(rect.size.x - 2, rect.size.y), COLOR_PCB_EDGE_DARK.lightened(0.2), edge_width)


func _draw_solder_pads(rect: Rect2):
	# Draw circular solder pads at corners
	var pad_radius = 2.5
	var pad_offset = 4

	# Corner pads
	var corners = [
		Vector2(pad_offset, pad_offset),                           # Top-left
		Vector2(rect.size.x - pad_offset, pad_offset),            # Top-right
		Vector2(pad_offset, rect.size.y - pad_offset),            # Bottom-left
		Vector2(rect.size.x - pad_offset, rect.size.y - pad_offset) # Bottom-right
	]

	for pad_pos in corners:
		# Outer solder pad (silver)
		draw_circle(pad_pos, pad_radius, COLOR_PCB_SOLDER)
		# Inner copper ring
		draw_circle(pad_pos, pad_radius * 0.6, COLOR_PCB_COPPER)


func _draw_circuit_traces(rect: Rect2):
	# Draw subtle circuit trace patterns
	var trace_color = COLOR_PCB_COPPER.darkened(0.4)
	trace_color.a = 0.3  # Semi-transparent

	# Horizontal trace line near top
	draw_line(Vector2(8, 6), Vector2(rect.size.x - 8, 6), trace_color, 1.0)

	# Vertical trace lines (like vias connecting layers)
	draw_line(Vector2(rect.size.x / 2.0, 6), Vector2(rect.size.x / 2.0, rect.size.y - 6), trace_color, 1.0)

	# Horizontal trace near bottom
	draw_line(Vector2(8, rect.size.y - 6), Vector2(rect.size.x - 8, rect.size.y - 6), trace_color, 1.0)


func _update_entanglement_display():
	# Update entanglement visual indicators (ring + counter)
	if plot_ui_data == null or not plot_ui_data.get("is_planted", false):
		# No entanglement indicators for empty plots
		entanglement_indicator.queue_redraw()
		entanglement_counter.text = ""
		return

	# Count entangled connections (from plot_ui_data if available)
	var entangled_count = 0
	if plot_ui_data.has("entangled_plots"):
		entangled_count = plot_ui_data.get("entangled_plots", []).size()

	# Update counter label
	if entangled_count > 0:
		entanglement_counter.text = "🔗%d" % entangled_count
	else:
		entanglement_counter.text = ""

	# Trigger redraw of entanglement indicator ring
	entanglement_indicator.queue_redraw()


func _update_lindblad_indicator() -> void:
	# Update persistent Lindblad pump/drain indicator.
	# Closed (unitary) system: there are no pump/drain channels, so the indicator is
	# always blank. Re-enabled by the open-quantum DLC.
	if not BalanceConfig.dissipative_enabled():
		lindblad_indicator.text = ""
		return
	if plot_ui_data == null or not plot_ui_data.get("is_planted", false):
		lindblad_indicator.text = ""
		return

	var pump_active = plot_ui_data.get("lindblad_pump_active", false)
	var drain_active = plot_ui_data.get("lindblad_drain_active", false)

	if not pump_active and not drain_active:
		lindblad_indicator.text = ""
		return

	var text = ""
	if pump_active:
		text += "⬆"
	if drain_active:
		text += "⬇"
	lindblad_indicator.text = text

	if pump_active and drain_active:
		lindblad_indicator.modulate = Color(1.0, 0.9, 0.4, 0.95)
	elif pump_active:
		lindblad_indicator.modulate = Color(0.4, 1.0, 0.6, 0.95)
	else:
		lindblad_indicator.modulate = Color(1.0, 0.5, 0.5, 0.95)


func _draw_entanglement_ring_inline(rect: Rect2, entangled_count: int):
	# Draw the entanglement glow ring inside the plot tile
	if entangled_count == 0:
		return

	var center = rect.get_center()
	var ring_radius = min(rect.size.x, rect.size.y) / 2.0 - 2

	# Draw outer glow (faint)
	draw_circle(center, ring_radius + 2, COLOR_ENTANGLEMENT_GLOW)

	var bright_color = COLOR_ENTANGLEMENT_RING.lerp(COLOR_ENTANGLEMENT_GLOW, 0.35)
	draw_arc(center, ring_radius, 0, TAU, 16, bright_color, 2.0)


func _draw_berry_ring_inline(rect: Rect2):
	# Berry-phase ripeness cue: an arc that fills from the top (−π/2) clockwise in
	# proportion to |accumulated phase| / ripe threshold. While accumulating it's a
	# violet fill; once ripe it closes to a full bright ring + glow ("incorporate now").
	var phase: float = absf(float(plot_ui_data.get("berry_phase", 0.0)))
	var threshold: float = float(plot_ui_data.get("berry_threshold", TAU))
	if threshold <= 0.0:
		threshold = TAU
	var ripe: bool = bool(plot_ui_data.get("berry_ripe", false))
	var frac: float = clampf(phase / threshold, 0.0, 1.0)

	var center = rect.get_center()
	var ring_radius = min(rect.size.x, rect.size.y) / 2.0 - 4
	var start_angle := -PI / 2.0  # 12 o'clock

	if ripe:
		# Closed, bright, with a glow halo — unmissable "ready to incorporate".
		draw_circle(center, ring_radius + 2, COLOR_BERRY_GLOW)
		draw_arc(center, ring_radius, 0, TAU, 32, COLOR_BERRY_RIPE, 3.0)
	elif frac > 0.0:
		# Faint full track + bright partial fill showing progress toward 2π.
		draw_arc(center, ring_radius, 0, TAU, 32, COLOR_BERRY_GLOW, 1.0)
		draw_arc(center, ring_radius, start_angle, start_angle + TAU * frac, 32, COLOR_BERRY_FILL, 2.5)
		# ETA under the arc: the ring shows position, this shows VELOCITY —
		# ripening rates vary ~20× between registers (and a rabi-0 axis barely
		# moves at all); "~40s" vs "∅" is the difference between waiting and
		# realizing you should couple or re-track elsewhere.
		var eta: float = float(plot_ui_data.get("berry_eta_s", -1.0))
		var rate: float = float(plot_ui_data.get("berry_rate", 0.0))
		var eta_text := ""
		if eta > 0.0 and eta < 3600.0:
			eta_text = "~%ds" % int(ceil(eta))
		elif rate <= 1e-4 and frac > 0.01:
			eta_text = "∅"
		if eta_text != "":
			var font := get_theme_default_font()
			if font != null:
				draw_string(font, Vector2(center.x - 12, rect.position.y + rect.size.y - 2),
						eta_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, COLOR_BERRY_FILL)


## Public API

func set_plot_data(plot_data, pos: Vector2i, index: int = -1):
	# Set the plot UI data for this tile (Phase 4: PlotUIData instead of WheatPlot)
	plot_ui_data = plot_data
	grid_position = pos

	# Set number label if index provided (check if label exists first)
	if index >= 0 and number_label:
		number_label.text = str(index)

	# Performance optimization: Mark visuals as dirty for next frame update
	_visuals_dirty = true

	# Performance optimization: Only enable _process for planted tiles
	# Empty tiles don't need per-frame updates
	var is_planted = plot_data != null and plot_data.get("is_planted", false)
	set_process(is_planted)

	# Immediate visual update for responsiveness on state change
	_update_visuals()
	queue_redraw()


func get_debug_info() -> String:
	if plot_ui_data == null or not plot_ui_data.get("is_planted", false):
		return "Empty"
	return "Planted: %s" % plot_ui_data.get("type_name", "unknown")
