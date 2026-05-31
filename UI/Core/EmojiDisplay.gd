@tool
extends Control
class_name EmojiDisplay


## EmojiDisplay: Unified emoji/glyph display component
##
## Automatically uses SVG glyph if available via EmojiRegistry,
## falls back to emoji text if no glyph exists.
##
## Usage:
##   var display = EmojiDisplay.new()
##   display.emoji = "🌾"
##   display.font_size = 36
##   add_child(display)
##
## The component handles the 3-tier fallback logic internally:
##   Priority 1: Hand-crafted SVG (Assets/UI/*)
##   Priority 2: Twemoji SVG (Assets/emoji_svg/*)
##   Priority 3: Text fallback (system font)
##
## This keeps emoji strings as source of truth while enabling
## custom glyph support.

@export var emoji: String = "":
	set(value):
		emoji = value
		_update_display()

@export var font_size: int = 36:
	set(value):
		font_size = value
		_update_display()

@export var modulate_color: Color = Color.WHITE:
	set(value):
		modulate_color = value
		_update_display()

# Child nodes (created in _ready)
var texture_rect: TextureRect
var label: Label

# Track initialization state
var _ready_called: bool = false

# Tiered emoji registry (lazy initialization)
var _emoji_registry = null

# Warning flag (to avoid spam)
var _has_warned_fallback: Dictionary = {}  # emoji → bool


func _ready():
	_create_children()
	_ready_called = true
	_update_display()


func _create_children():
	# Create child nodes for texture and text display.
	if texture_rect != null:
		return  # Already created

	# TextureRect for SVG glyphs (primary display)
	texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(texture_rect)

	# Label for emoji text fallback (secondary display)
	label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)


func _update_display():
	# Update display based on current emoji value.
	if not _ready_called or not is_inside_tree():
		return

	# Safety checks for children
	if not texture_rect or not label:
		return

	if emoji.is_empty():
		# No emoji set - hide everything
		texture_rect.visible = false
		label.visible = false
		return

	if not _emoji_registry:
		_emoji_registry = EmojiRegistry.shared()

	# Try to load SVG glyph from tiered registry (Priority 1 & 2)
	var texture: Texture2D = null
	texture = _emoji_registry.get_texture(emoji)

	if texture:
		# Use SVG glyph (Priority 1: Hand-crafted or Priority 2: Twemoji)
		texture_rect.texture = texture
		texture_rect.modulate = modulate_color
		texture_rect.visible = true
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

		label.visible = false
	else:
		# Priority 3: Text fallback
		label.text = emoji
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", modulate_color)
		label.visible = true
		label.set_anchors_preset(Control.PRESET_FULL_RECT)

		texture_rect.visible = false

		# Warn once per emoji
		if not _has_warned_fallback.get(emoji, false):
			push_warning("[EmojiDisplay] ⚠️ Using text fallback for '%s'" % emoji)
			_has_warned_fallback[emoji] = true


func set_opacity(opacity: float) -> void:
	# Set opacity for quantum superposition blending.

	# Used by PlotTile for dual-emoji display with weighted opacity.
	modulate_color = Color(modulate_color.r, modulate_color.g, modulate_color.b, opacity)
	_update_display()
