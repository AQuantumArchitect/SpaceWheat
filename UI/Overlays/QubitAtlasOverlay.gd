extends "res://UI/Core/OverlayBase.gd"

## QubitAtlasOverlay — Live vocabulary display
##
## Shows learned emoji pairs as qubit cards with real-time quantum state.
## Each card displays north/south emojis, live probability bar, source biome,
## and the 4x harvest yield badge. Undiscovered pairs appear as hints.
## Biome coverage section shows vocabulary progress per biome.
##
## Controls:
##   F = Next page / cycle view
##   ESC = Close

const InstrumentLocator = preload("res://Core/Instrumentation/InstrumentLocator.gd")
const BiomeRegistry = preload("res://Core/Biomes/BiomeRegistry.gd")

# Layout constants
const CARDS_PER_PAGE := 9
const CARD_MIN_SIZE := Vector2(160, 130)
const GRID_COLUMNS := 3
const BAR_HEIGHT := 12
const EMOJI_SIZE := 28
const BADGE_SIZE := 11

# Colors
const COLOR_NORTH := Color(0.4, 0.7, 1.0, 0.9)
const COLOR_SOUTH := Color(1.0, 0.5, 0.3, 0.9)
const COLOR_BAR_BG := Color(0.15, 0.15, 0.2, 0.8)
const COLOR_BAR_NORTH := Color(0.3, 0.55, 0.85, 0.9)
const COLOR_BAR_SOUTH := Color(0.85, 0.4, 0.25, 0.9)
const COLOR_YIELD := Color(1.0, 0.85, 0.3, 1.0)
const COLOR_BIOME_TAG := Color(0.5, 0.6, 0.7, 0.8)
const COLOR_CARD_BG := Color(0.12, 0.14, 0.18, 0.9)
const COLOR_CARD_BORDER := Color(0.25, 0.35, 0.45, 0.6)
const COLOR_UNDISCOVERED := Color(0.3, 0.3, 0.35, 0.5)
const COLOR_HINT := Color(0.6, 0.6, 0.5, 0.6)
const COLOR_COVERAGE_BG := Color(0.1, 0.12, 0.16, 0.8)
const COLOR_COVERAGE_FILL := Color(0.3, 0.6, 0.4, 0.8)
const COLOR_GLOW_HIGH := Color(0.4, 0.7, 1.0, 0.3)
const COLOR_GLOW_LOW := Color(0.2, 0.2, 0.3, 0.1)

# State
var _current_page := 0
var _total_pages := 1
var _known_pairs: Array = []
var _all_biome_pairs: Array = []  # [{north, south, biome_name}]
var _biome_registry: BiomeRegistry = null

# UI references
var _header_label: Label
var _page_label: Label
var _cards_grid: GridContainer
var _coverage_container: VBoxContainer
var _card_nodes: Array = []  # Array of card VBoxContainers for live update


func _init():
	overlay_name = "vocabulary"
	overlay_icon = "📖"
	panel_title = "📖 Qubit Atlas"
	panel_size_mode = PanelSizeMode.LARGE
	show_dimmer = true
	dimmer_color = Color(0, 0, 0, 0.75)
	use_scroll_container = true
	action_labels = {
		"Q": "Prev",
		"E": "",
		"R": "Next",
		"F": "Page"
	}


func _build_content(container: Control) -> void:
	_biome_registry = BiomeRegistry.new()

	# Header stats
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 13)
	_header_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_header_label)

	# Cards grid
	_cards_grid = GridContainer.new()
	_cards_grid.columns = GRID_COLUMNS
	_cards_grid.add_theme_constant_override("h_separation", 10)
	_cards_grid.add_theme_constant_override("v_separation", 10)
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(_cards_grid)

	# Page indicator
	_page_label = Label.new()
	_page_label.add_theme_font_size_override("font_size", 12)
	_page_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(_page_label)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 12)
	container.add_child(sep)

	# Coverage section
	var coverage_title = Label.new()
	coverage_title.text = "Biome Coverage"
	coverage_title.add_theme_font_size_override("font_size", 14)
	coverage_title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	container.add_child(coverage_title)

	_coverage_container = VBoxContainer.new()
	_coverage_container.add_theme_constant_override("separation", 4)
	container.add_child(_coverage_container)


func _on_activated() -> void:
	_refresh_data()
	_rebuild_display()


func _on_action_q() -> void:
	var pages = max(_total_pages, 1)
	_current_page = (_current_page - 1 + pages) % pages
	_rebuild_display()

func _on_action_r() -> void:
	_current_page = (_current_page + 1) % max(_total_pages, 1)
	_rebuild_display()

func _on_action_f() -> void:
	_current_page = (_current_page + 1) % max(_total_pages, 1)
	_rebuild_display()


func _process(_delta: float) -> void:
	if not visible or not is_active:
		return
	_update_live_bars()


# =============================================================================
# DATA
# =============================================================================

func _refresh_data() -> void:
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if gsm and gsm.has_method("get_player_vocab_pairs"):
		_known_pairs = gsm.get_player_vocab_pairs()
	else:
		_known_pairs = []

	_all_biome_pairs = _collect_all_biome_pairs()

	var total_possible = _all_biome_pairs.size()
	_total_pages = max(1, ceili(float(_get_display_items().size()) / float(CARDS_PER_PAGE)))
	_current_page = clampi(_current_page, 0, _total_pages - 1)

	# Header text
	var bonus_pct = _known_pairs.size() * 300  # Each known pair = 4x = +300% on its emojis
	_header_label.text = "%d / %d pairs learned" % [_known_pairs.size(), total_possible]
	if _known_pairs.size() > 0:
		_header_label.text += "    |    Harvest bonus active on %d pairs" % _known_pairs.size()


func _collect_all_biome_pairs() -> Array:
	"""Get every emoji pair from every exportable biome."""
	var pairs = []
	var seen = {}
	for biome in _biome_registry.get_all():
		if biome.name.begins_with("_"):
			continue
		var emojis = biome.emojis
		for i in range(0, emojis.size() - 1, 2):
			var key = emojis[i] + "|" + emojis[i + 1]
			if not seen.has(key):
				seen[key] = true
				pairs.append({"north": emojis[i], "south": emojis[i + 1], "biome": biome.name})
	return pairs


func _get_display_items() -> Array:
	"""Build ordered display list: known pairs first, then undiscovered hints."""
	var items = []
	var known_set = {}
	for pair in _known_pairs:
		var key = pair.get("north", "") + "|" + pair.get("south", "")
		known_set[key] = true
		items.append({"north": pair.north, "south": pair.south, "known": true,
			"biome": _find_biome_for_pair(pair.north, pair.south)})

	for bp in _all_biome_pairs:
		var key = bp.north + "|" + bp.south
		if not known_set.has(key):
			items.append({"north": bp.north, "south": bp.south, "known": false,
				"biome": bp.biome})
	return items


func _find_biome_for_pair(north: String, south: String) -> String:
	for bp in _all_biome_pairs:
		if bp.north == north and bp.south == south:
			return bp.biome
	return ""


# =============================================================================
# DISPLAY BUILD
# =============================================================================

func _rebuild_display() -> void:
	# Clear cards
	for child in _cards_grid.get_children():
		child.queue_free()
	_card_nodes.clear()

	var items = _get_display_items()
	var start = _current_page * CARDS_PER_PAGE
	var end = mini(start + CARDS_PER_PAGE, items.size())

	for i in range(start, end):
		var card = _build_card(items[i])
		_cards_grid.add_child(card)
		_card_nodes.append({"node": card, "data": items[i]})

	# Page label
	if _total_pages > 1:
		_page_label.text = "Page %d / %d  [F] next page" % [_current_page + 1, _total_pages]
		_page_label.visible = true
	else:
		_page_label.visible = false

	_rebuild_coverage()


func _build_card(item: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = CARD_MIN_SIZE
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_CARD_BG
	style.border_color = COLOR_YIELD if item.known else COLOR_CARD_BORDER
	style.set_border_width_all(2 if item.known else 1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	if item.known:
		_build_known_card_content(vbox, item)
	else:
		_build_undiscovered_card_content(vbox, item)

	return card


func _build_known_card_content(vbox: VBoxContainer, item: Dictionary) -> void:
	# North emoji
	var north_label = Label.new()
	north_label.text = item.north
	north_label.add_theme_font_size_override("font_size", EMOJI_SIZE)
	north_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(north_label)

	# Probability bar container (will be updated live)
	var bar_container = _create_probability_bar()
	bar_container.name = "ProbBar"
	vbox.add_child(bar_container)

	# South emoji
	var south_label = Label.new()
	south_label.text = item.south
	south_label.add_theme_font_size_override("font_size", EMOJI_SIZE)
	south_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(south_label)

	# Bottom row: biome + yield badge
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 6)
	vbox.add_child(bottom)

	# Biome tag
	var biome_label = Label.new()
	biome_label.text = _short_biome_name(item.biome)
	biome_label.add_theme_font_size_override("font_size", BADGE_SIZE)
	biome_label.add_theme_color_override("font_color", COLOR_BIOME_TAG)
	bottom.add_child(biome_label)

	# Yield badge
	var yield_label = Label.new()
	yield_label.text = "4x"
	yield_label.add_theme_font_size_override("font_size", BADGE_SIZE)
	yield_label.add_theme_color_override("font_color", COLOR_YIELD)
	bottom.add_child(yield_label)


func _build_undiscovered_card_content(vbox: VBoxContainer, item: Dictionary) -> void:
	# Question marks
	var q_label = Label.new()
	q_label.text = "?"
	q_label.add_theme_font_size_override("font_size", EMOJI_SIZE)
	q_label.add_theme_color_override("font_color", COLOR_UNDISCOVERED)
	q_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(q_label)

	# Empty bar placeholder
	var bar = _create_probability_bar()
	bar.name = "ProbBar"
	# Set to empty
	var fill = bar.get_node_or_null("Fill")
	if fill:
		fill.size_flags_stretch_ratio = 0.0
	vbox.add_child(bar)

	# Second question mark
	var q_label2 = Label.new()
	q_label2.text = "?"
	q_label2.add_theme_font_size_override("font_size", EMOJI_SIZE)
	q_label2.add_theme_color_override("font_color", COLOR_UNDISCOVERED)
	q_label2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(q_label2)

	# Hint: biome source
	var hint_label = Label.new()
	hint_label.text = _short_biome_name(item.biome)
	hint_label.add_theme_font_size_override("font_size", BADGE_SIZE)
	hint_label.add_theme_color_override("font_color", COLOR_HINT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint_label)


func _create_probability_bar() -> HBoxContainer:
	"""Create a north/south probability bar."""
	var bar = HBoxContainer.new()
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 0)

	# Background
	var bg = StyleBoxFlat.new()
	bg.bg_color = COLOR_BAR_BG
	bg.set_corner_radius_all(3)

	var bar_panel = PanelContainer.new()
	bar_panel.add_theme_stylebox_override("panel", bg)
	bar_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_panel.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.add_child(bar_panel)

	# Inner HBox for the two fill segments
	var inner = HBoxContainer.new()
	inner.add_theme_constant_override("separation", 1)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bar_panel.add_child(inner)

	var north_fill = ColorRect.new()
	north_fill.name = "NorthFill"
	north_fill.color = COLOR_BAR_NORTH
	north_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	north_fill.size_flags_stretch_ratio = 0.5
	inner.add_child(north_fill)

	var south_fill = ColorRect.new()
	south_fill.name = "SouthFill"
	south_fill.color = COLOR_BAR_SOUTH
	south_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	south_fill.size_flags_stretch_ratio = 0.5
	inner.add_child(south_fill)

	return bar


# =============================================================================
# LIVE UPDATE
# =============================================================================

func _update_live_bars() -> void:
	"""Update probability bars from live quantum state."""
	var gsm = InstrumentLocator.resolve_game_state_manager(self)
	if not gsm:
		return
	var farm = gsm.get_active_farm() if gsm.has_method("get_active_farm") else null
	if not farm:
		return

	for card_info in _card_nodes:
		var data = card_info.data
		if not data.known:
			continue

		var card_node: PanelContainer = card_info.node
		var bar = _find_prob_bar(card_node)
		if not bar:
			continue

		# Aggregate population across all active biomes
		var p_north := 0.0
		var p_south := 0.0
		var count := 0

		var biomes = farm.biomes if "biomes" in farm else {}
		for biome_name in biomes:
			var biome = biomes[biome_name]
			if not biome or not biome.quantum_computer:
				continue
			var qc = biome.quantum_computer
			if qc.has(data.north) and qc.has(data.south):
				p_north += qc.get_population(data.north)
				p_south += qc.get_population(data.south)
				count += 1

		if count > 0:
			p_north /= count
			p_south /= count
		else:
			p_north = 0.5
			p_south = 0.5

		# Clamp to avoid zero-width
		p_north = maxf(p_north, 0.02)
		p_south = maxf(p_south, 0.02)

		var north_fill = bar.get_node_or_null("NorthFill")
		var south_fill = bar.get_node_or_null("SouthFill")
		if not north_fill or not south_fill:
			# Navigate into the panel container
			var panel = bar.get_child(0) if bar.get_child_count() > 0 else null
			var inner = panel.get_child(0) if panel and panel.get_child_count() > 0 else null
			if inner and inner.get_child_count() >= 2:
				north_fill = inner.get_child(0)
				south_fill = inner.get_child(1)

		if north_fill and south_fill:
			north_fill.size_flags_stretch_ratio = p_north
			south_fill.size_flags_stretch_ratio = p_south

		# Purity glow on card border
		_update_card_glow(card_node, data, farm)


func _update_card_glow(card: PanelContainer, data: Dictionary, farm) -> void:
	"""Modulate card border brightness based on marginal purity."""
	var max_purity := 0.0
	var biomes = farm.biomes if "biomes" in farm else {}
	for biome_name in biomes:
		var biome = biomes[biome_name]
		if not biome or not biome.quantum_computer:
			continue
		var qc = biome.quantum_computer
		if not qc.has(data.north):
			continue
		var q = qc.qubit(data.north)
		if q >= 0:
			var mp = qc.get_marginal_purity(null, q)
			max_purity = maxf(max_purity, mp)

	# Lerp border color: dim when mixed (0.5), bright when pure (1.0)
	var t = clampf((max_purity - 0.5) * 2.0, 0.0, 1.0)
	var glow_color = COLOR_GLOW_LOW.lerp(COLOR_GLOW_HIGH, t)

	var style = card.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var new_style = style.duplicate()
		new_style.border_color = COLOR_YIELD.lerp(COLOR_YIELD.lightened(0.4), t)
		new_style.shadow_color = glow_color
		new_style.shadow_size = int(t * 6)
		card.add_theme_stylebox_override("panel", new_style)


func _find_prob_bar(card: PanelContainer) -> HBoxContainer:
	"""Find the probability bar in a card node tree."""
	var vbox = card.get_child(0) if card.get_child_count() > 0 else null
	if not vbox:
		return null
	for child in vbox.get_children():
		if child is HBoxContainer and child.name == "ProbBar":
			return child
	return null


# =============================================================================
# COVERAGE SECTION
# =============================================================================

func _rebuild_coverage() -> void:
	for child in _coverage_container.get_children():
		child.queue_free()

	var known_set = {}
	for pair in _known_pairs:
		var key = pair.get("north", "") + "|" + pair.get("south", "")
		known_set[key] = true

	# Group pairs by biome
	var biome_pairs: Dictionary = {}  # biome_name → {total, known}
	for bp in _all_biome_pairs:
		var bname = bp.biome
		if not biome_pairs.has(bname):
			biome_pairs[bname] = {"total": 0, "known": 0}
		biome_pairs[bname].total += 1
		var key = bp.north + "|" + bp.south
		if known_set.has(key):
			biome_pairs[bname].known += 1

	# Sort by known count descending
	var sorted_biomes = biome_pairs.keys()
	sorted_biomes.sort_custom(func(a, b): return biome_pairs[b].known < biome_pairs[a].known)

	# Show top biomes (limit to avoid overflow)
	var shown = 0
	for bname in sorted_biomes:
		if shown >= 8:
			break
		var info = biome_pairs[bname]
		if info.total == 0:
			continue

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_coverage_container.add_child(row)

		# Biome name
		var name_label = Label.new()
		name_label.text = _short_biome_name(bname)
		name_label.custom_minimum_size = Vector2(100, 0)
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		row.add_child(name_label)

		# Progress bar
		var bar_bg = PanelContainer.new()
		bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_bg.custom_minimum_size = Vector2(0, 14)
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = COLOR_COVERAGE_BG
		bg_style.set_corner_radius_all(3)
		bar_bg.add_theme_stylebox_override("panel", bg_style)
		row.add_child(bar_bg)

		var fill_ratio = float(info.known) / float(info.total)
		var fill = ColorRect.new()
		fill.color = COLOR_COVERAGE_FILL
		fill.anchor_right = fill_ratio
		fill.anchor_bottom = 1.0
		fill.offset_left = 2
		fill.offset_top = 2
		fill.offset_bottom = -2
		bar_bg.add_child(fill)

		# Count
		var count_label = Label.new()
		count_label.text = "%d/%d" % [info.known, info.total]
		count_label.custom_minimum_size = Vector2(40, 0)
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color",
			COLOR_YIELD if info.known == info.total else Color(0.6, 0.65, 0.7))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(count_label)

		shown += 1


# =============================================================================
# HELPERS
# =============================================================================

func _short_biome_name(biome_name: String) -> String:
	"""Convert CamelCase to spaced: StarterForest → Starter Forest, truncated."""
	if biome_name.is_empty():
		return "?"
	var result = ""
	for i in range(biome_name.length()):
		var c = biome_name[i]
		if i > 0 and c == c.to_upper() and c != c.to_lower():
			result += " "
		result += c
	if result.length() > 14:
		result = result.left(12) + ".."
	return result
