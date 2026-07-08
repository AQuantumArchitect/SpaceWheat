class_name BiomeBackground
extends Control

## BiomeBackground — full-screen ZONE with swipe transitions.
##
## Mini-Metro pass (2026-07-07): the photographic PNGs are replaced by drawn
## ZoneBackgroundPanels (flat theme color field + procedural silhouette band +
## live quantum tint). The panel pair + swipe transition + ActiveBiomeManager
## wiring are unchanged from the photo era. Set LEGACY_PHOTO_MODE true to get
## the old Assets/Biomes/*.png path back for one release.
##
## Live tint: this node polls the ACTIVE biome's ambient scalars (spectral gap,
## Var(H)) at 2 Hz via BiomeBase.get_ambient_scalars() — the lazy, dirty-flagged
## accessor — and pushes them to the current panel. Rigid biomes read cold and
## monochrome, plural ones warm and two-toned, restless ones slowly breathe.
##
## Discovery splash: first arrival at a biome this session fades its display
## name in and out — arrival is a moment, not a tab switch. Session-only state.

const LEGACY_PHOTO_MODE := false
const FALLBACK_BIOME_TEXTURE: String = "res://Assets/Biomes/Entropy_Garden.png"

## Transition duration in seconds
@export var transition_duration: float = 0.3

## Current biome being displayed
var current_biome: String = ""

## The two swappable zone views. In legacy mode these are TextureRects;
## in zone mode they are ZoneBackgroundPanels. Both are Controls — the swipe
## animates `position` either way.
var _current_bg: Control
var _incoming_bg: Control

## Active tween for transitions
var _tween: Tween

## Reference to ActiveBiomeManager (set in _ready)
var _biome_router: Node
var _biome_textures: Dictionary = {}
var _biome_registry: BiomeRegistry = null
var _unknown_biome_warned: Dictionary = {}

## Ambient scalar polling (active biome only, 2 Hz).
var _ambient_accum: float = 0.0
const AMBIENT_POLL_S := 0.5

## Discovery splash (session-only).
var _visited_biomes: Dictionary = {}
var _splash_label: Label = null
var _splash_tween: Tween


func _ready() -> void:
	# When added to CanvasLayer, anchors don't work - must set size explicitly
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var viewport_size = get_viewport_rect().size
	size = viewport_size
	position = Vector2.ZERO

	_current_bg = _create_zone_view()
	_current_bg.size = viewport_size
	add_child(_current_bg)

	_incoming_bg = _create_zone_view()
	_incoming_bg.size = viewport_size
	_incoming_bg.visible = false
	add_child(_incoming_bg)

	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_biome_router = get_node_or_null("/root/ActiveBiomeManager")
	if _biome_router:
		if not _biome_router.active_biome_changed.is_connected(_on_active_biome_changed):
			_biome_router.active_biome_changed.connect(_on_active_biome_changed)
		if not _biome_router.biome_transition_requested.is_connected(_on_transition_requested):
			_biome_router.biome_transition_requested.connect(_on_transition_requested)
		call_deferred("_set_initial_biome")
	else:
		push_warning("BiomeBackground: ActiveBiomeManager not found")
		set_biome("StarterForest")


func _process(delta: float) -> void:
	if LEGACY_PHOTO_MODE or current_biome == "":
		return
	_ambient_accum += delta
	if _ambient_accum < AMBIENT_POLL_S:
		return
	_ambient_accum = 0.0
	var biome = _resolve_active_biome_object()
	if biome != null and biome.has_method("get_ambient_scalars") and _current_bg is ZoneBackgroundPanel:
		var scalars: Dictionary = biome.get_ambient_scalars()
		_current_bg.set_ambient_targets(float(scalars.get("gap", 0.0)), float(scalars.get("var_h", 0.0)))


func _resolve_active_biome_object():
	# Read-only resolution of the live BiomeBase for the active biome.
	var gsm = get_node_or_null("/root/GameStateManager")
	var farm = gsm.get_active_farm() if (gsm and gsm.has_method("get_active_farm")) else null
	if farm == null or not is_instance_valid(farm) or farm.grid == null:
		return null
	if not farm.grid.has_method("get_all_biomes"):
		return null
	return farm.grid.get_all_biomes().get(current_biome, null)


func _set_initial_biome() -> void:
	if _biome_router:
		set_biome(_biome_router.get_active_biome())


func _on_viewport_size_changed() -> void:
	var viewport_size = get_viewport_rect().size
	size = viewport_size
	_current_bg.size = viewport_size
	_incoming_bg.size = viewport_size


func _create_zone_view() -> Control:
	if LEGACY_PHOTO_MODE:
		var rect = TextureRect.new()
		rect.position = Vector2.ZERO
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	var panel = ZoneBackgroundPanel.new()
	panel.position = Vector2.ZERO
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _apply_zone(view: Control, biome_name: String) -> void:
	# Point one of the two views at a biome (zone or legacy texture).
	if view is ZoneBackgroundPanel:
		view.set_zone(biome_name)
	elif view is TextureRect:
		var texture = _get_biome_texture(biome_name)
		if texture:
			view.texture = texture


func set_biome(biome_name: String) -> void:
	# Set biome instantly (no transition)
	current_biome = biome_name
	_apply_zone(_current_bg, biome_name)
	_current_bg.position = Vector2.ZERO
	_maybe_play_discovery_splash(biome_name)


func transition_to_biome(biome_name: String, direction: int) -> void:
	# Transition to a new biome with swipe animation
	#
	# Args:
	# biome_name: Target biome
	# direction: -1 = slide from left, 1 = slide from right
	if biome_name == current_biome:
		return

	# Cancel any existing transition
	if _tween and _tween.is_valid():
		_tween.kill()

	# Notify manager that transition is starting
	if _biome_router and _biome_router.has_method("set_transitioning"):
		_biome_router.set_transitioning(true)

	var viewport_width = get_viewport_rect().size.x

	_apply_zone(_incoming_bg, biome_name)
	_incoming_bg.visible = true

	if direction > 0:
		_incoming_bg.position = Vector2(viewport_width, 0)
	else:
		_incoming_bg.position = Vector2(-viewport_width, 0)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)

	var current_target = Vector2(-viewport_width if direction > 0 else viewport_width, 0)
	_tween.tween_property(_current_bg, "position", current_target, transition_duration)
	_tween.tween_property(_incoming_bg, "position", Vector2.ZERO, transition_duration)
	_tween.chain().tween_callback(_on_transition_complete.bind(biome_name))


func _on_transition_complete(biome_name: String) -> void:
	current_biome = biome_name

	var temp = _current_bg
	_current_bg = _incoming_bg
	_incoming_bg = temp

	_incoming_bg.visible = false
	_incoming_bg.position = Vector2.ZERO
	_current_bg.position = Vector2.ZERO

	if _biome_router and _biome_router.has_method("set_transitioning"):
		_biome_router.set_transitioning(false)

	_maybe_play_discovery_splash(biome_name)


func _on_active_biome_changed(new_biome: String, _old_biome: String) -> void:
	# Handle instant biome change (when direction = 0)
	if not _tween or not _tween.is_valid():
		if new_biome != current_biome:
			set_biome(new_biome)


func _on_transition_requested(_from_biome: String, to_biome: String, direction: int) -> void:
	transition_to_biome(to_biome, direction)


# ============================================================================
# Discovery splash — arrival is a moment (session-only, purely cosmetic)
# ============================================================================

func _maybe_play_discovery_splash(biome_name: String) -> void:
	if LEGACY_PHOTO_MODE or biome_name == "" or _visited_biomes.has(biome_name):
		return
	_visited_biomes[biome_name] = true
	# The very first zone of the session is the starting screen, not a discovery.
	if _visited_biomes.size() == 1:
		return

	if _splash_label == null:
		_splash_label = Label.new()
		_splash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_splash_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_splash_label.add_theme_font_size_override("font_size", 44)
		_splash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_splash_label)

	var theme_dict: Dictionary = BiomeVisualTheme.get_theme(biome_name)
	var paper: Color = theme_dict.get("paper", Color.WHITE)
	_splash_label.text = _display_name_for(biome_name)
	_splash_label.add_theme_color_override("font_color", paper)
	# Below the menu/hat/biome chrome, above the station row.
	_splash_label.position = Vector2(size.x * 0.5 - 300.0, size.y * 0.42)
	_splash_label.size = Vector2(600.0, 60.0)
	_splash_label.modulate.a = 0.0
	_splash_label.visible = true

	if _splash_tween and _splash_tween.is_valid():
		_splash_tween.kill()
	_splash_tween = create_tween()
	_splash_tween.tween_property(_splash_label, "modulate:a", 0.9, 0.4)
	_splash_tween.tween_interval(1.0)
	_splash_tween.tween_property(_splash_label, "modulate:a", 0.0, 0.4)


func _display_name_for(biome_name: String) -> String:
	if _biome_registry == null:
		_biome_registry = BiomeRegistry.get_shared()
	var biome = _biome_registry.get_by_name(biome_name)
	if biome != null and biome.visual_config.get("label", "") != "":
		return str(biome.visual_config["label"])
	return biome_name


# ============================================================================
# Legacy photo path (LEGACY_PHOTO_MODE) — delete after one release
# ============================================================================

func _get_biome_texture(biome_name: String) -> Texture2D:
	if _biome_textures.has(biome_name):
		return _biome_textures[biome_name]
	var path: String = _get_biome_texture_path(biome_name)
	if path == "":
		return null
	var loaded = ResourceLoader.load(path)
	if loaded is Texture2D:
		_biome_textures[biome_name] = loaded
		return loaded
	var image := Image.new()
	var err := image.load(path)
	if err != OK:
		push_warning("BiomeBackground: Failed to load biome image '%s' (err=%s)" % [path, err])
		return null

	var texture := ImageTexture.create_from_image(image)
	_biome_textures[biome_name] = texture
	return texture


func _get_biome_texture_path(biome_name: String) -> String:
	if _biome_registry == null:
		_biome_registry = BiomeRegistry.get_shared()
	var biome = _biome_registry.get_by_name(biome_name)
	if biome and biome.image_path != "":
		return biome.image_path
	if not _unknown_biome_warned.has(biome_name):
		_unknown_biome_warned[biome_name] = true
		push_warning("BiomeBackground: No image path for biome '%s' - using fallback" % biome_name)
	return FALLBACK_BIOME_TEXTURE


func get_current_biome() -> String:
	return current_biome
