class_name UIOrnamentation
extends RefCounted

## UIOrnamentation - Centralized SVG ornamentation for menus and overlays
##
## Usage:
##   var corners = UIOrnamentation.create_corner_set()
##   UIOrnamentation.apply_corners_to_panel(my_panel, corners)
##
## All menus and overlays should use these methods for consistent decoration.

# =============================================================================
# SVG ASSET PATHS
# =============================================================================

const CORNER_TOP_PATH = "res://Assets/UI/Chrome/UI Corner Top.svg"
const CORNER_BTM_PATH = "res://Assets/UI/Chrome/Corner Panel BTM.svg"
const WEDGE_TOP_PATH = "res://Assets/UI/Chrome/UITopWedge.svg"
const WEDGE_BTM_PATH = "res://Assets/UI/Chrome/UI Btm Wedge.svg"
const BRACKET_PATH = "res://Assets/UI/Chrome/UIBracket.svg"

# =============================================================================
# CORNER SIZES (adjust based on SVG dimensions)
# =============================================================================

const CORNER_SIZE_SMALL = Vector2(32, 32)
const CORNER_SIZE_MEDIUM = Vector2(48, 48)
const CORNER_SIZE_LARGE = Vector2(64, 64)

# =============================================================================
# ORNAMENTATION STYLES
# =============================================================================

enum Style {
	NONE,           # No ornamentation
	CORNERS_ONLY,   # Just corner pieces
	CORNERS_WEDGES, # Corners + top/bottom wedges
	FULL            # Corners + wedges + brackets
}

# =============================================================================
# TEXTURE CACHING
# =============================================================================

static var _corner_top_texture: Texture2D = null
static var _corner_btm_texture: Texture2D = null
static var _wedge_top_texture: Texture2D = null
static var _wedge_btm_texture: Texture2D = null
static var _bracket_texture: Texture2D = null


static func _load_texture(path: String) -> Texture2D:
	"""Load and cache a texture from path."""
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	push_warning("UIOrnamentation: Could not load texture: %s" % path)
	return null


static func get_corner_top_texture() -> Texture2D:
	if not _corner_top_texture:
		_corner_top_texture = _load_texture(CORNER_TOP_PATH)
	return _corner_top_texture


static func get_corner_btm_texture() -> Texture2D:
	if not _corner_btm_texture:
		_corner_btm_texture = _load_texture(CORNER_BTM_PATH)
	return _corner_btm_texture


static func get_wedge_top_texture() -> Texture2D:
	if not _wedge_top_texture:
		_wedge_top_texture = _load_texture(WEDGE_TOP_PATH)
	return _wedge_top_texture


static func get_wedge_btm_texture() -> Texture2D:
	if not _wedge_btm_texture:
		_wedge_btm_texture = _load_texture(WEDGE_BTM_PATH)
	return _wedge_btm_texture


static func get_bracket_texture() -> Texture2D:
	if not _bracket_texture:
		_bracket_texture = _load_texture(BRACKET_PATH)
	return _bracket_texture


# =============================================================================
# CORNER CREATION
# =============================================================================

static func create_corner(
	texture: Texture2D,
	corner_size: Vector2 = CORNER_SIZE_MEDIUM,
	flip_h: bool = false,
	flip_v: bool = false,
	tint: Color = Color.WHITE
) -> TextureRect:
	"""Create a single corner TextureRect."""
	if not texture:
		return null

	var rect = TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = corner_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.flip_h = flip_h
	rect.flip_v = flip_v
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func create_corner_set(
	corner_size: Vector2 = CORNER_SIZE_MEDIUM,
	tint: Color = Color.WHITE
) -> Dictionary:
	"""Create all 4 corners for a panel.

	Returns Dictionary with keys: top_left, top_right, bottom_left, bottom_right
	"""
	var top_tex = get_corner_top_texture()
	var btm_tex = get_corner_btm_texture()

	return {
		"top_left": create_corner(top_tex, corner_size, false, false, tint),
		"top_right": create_corner(top_tex, corner_size, true, false, tint),
		"bottom_left": create_corner(btm_tex, corner_size, false, false, tint),
		"bottom_right": create_corner(btm_tex, corner_size, true, false, tint)
	}


# =============================================================================
# PANEL APPLICATION
# =============================================================================

static func apply_corners_to_panel(
	panel: Control,
	corner_size: Vector2 = CORNER_SIZE_MEDIUM,
	tint: Color = Color.WHITE,
	margin: int = -4
) -> Dictionary:
	"""Apply corner ornaments to a panel.

	Args:
		panel: The panel to decorate
		corner_size: Size of corner pieces
		tint: Color tint to apply
		margin: Offset from panel edge (negative = overlap)

	Returns Dictionary of created corner controls for later reference.
	"""
	var corners = create_corner_set(corner_size, tint)

	# Top-left corner
	if corners.top_left:
		corners.top_left.set_anchors_preset(Control.PRESET_TOP_LEFT)
		corners.top_left.position = Vector2(margin, margin)
		panel.add_child(corners.top_left)

	# Top-right corner
	if corners.top_right:
		corners.top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		corners.top_right.position = Vector2(-corner_size.x - margin, margin)
		panel.add_child(corners.top_right)

	# Bottom-left corner
	if corners.bottom_left:
		corners.bottom_left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		corners.bottom_left.position = Vector2(margin, -corner_size.y - margin)
		panel.add_child(corners.bottom_left)

	# Bottom-right corner
	if corners.bottom_right:
		corners.bottom_right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		corners.bottom_right.position = Vector2(-corner_size.x - margin, -corner_size.y - margin)
		panel.add_child(corners.bottom_right)

	return corners


static func apply_ornamentation(
	panel: Control,
	style: Style,
	corner_size: Vector2 = CORNER_SIZE_MEDIUM,
	tint: Color = Color.WHITE
) -> Dictionary:
	"""Apply full ornamentation to a panel based on style.

	Args:
		panel: The panel to decorate
		style: Ornamentation style (NONE, CORNERS_ONLY, etc.)
		corner_size: Size of corner pieces
		tint: Color tint to apply

	Returns Dictionary of all created ornament controls.
	"""
	var ornaments = {}

	if style == Style.NONE:
		return ornaments

	# Always add corners for non-NONE styles
	if style >= Style.CORNERS_ONLY:
		ornaments["corners"] = apply_corners_to_panel(panel, corner_size, tint)

	# Add wedges for CORNERS_WEDGES and FULL
	if style >= Style.CORNERS_WEDGES:
		ornaments["wedges"] = _apply_wedges_to_panel(panel, tint)

	# Add brackets for FULL
	if style == Style.FULL:
		ornaments["brackets"] = _apply_brackets_to_panel(panel, tint)

	return ornaments


static func _apply_wedges_to_panel(panel: Control, tint: Color) -> Dictionary:
	"""Apply top and bottom wedge ornaments."""
	var wedges = {}

	var top_tex = get_wedge_top_texture()
	var btm_tex = get_wedge_btm_texture()

	if top_tex:
		var top_wedge = TextureRect.new()
		top_wedge.texture = top_tex
		top_wedge.custom_minimum_size = Vector2(100, 20)
		top_wedge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		top_wedge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top_wedge.modulate = tint
		top_wedge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top_wedge.set_anchors_preset(Control.PRESET_CENTER_TOP)
		top_wedge.position.y = -10
		panel.add_child(top_wedge)
		wedges["top"] = top_wedge

	if btm_tex:
		var btm_wedge = TextureRect.new()
		btm_wedge.texture = btm_tex
		btm_wedge.custom_minimum_size = Vector2(100, 20)
		btm_wedge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		btm_wedge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		btm_wedge.modulate = tint
		btm_wedge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btm_wedge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		btm_wedge.position.y = -10
		panel.add_child(btm_wedge)
		wedges["bottom"] = btm_wedge

	return wedges


static func _apply_brackets_to_panel(panel: Control, tint: Color) -> Dictionary:
	"""Apply left and right bracket ornaments."""
	var brackets = {}

	var bracket_tex = get_bracket_texture()
	if not bracket_tex:
		return brackets

	# Left bracket
	var left_bracket = TextureRect.new()
	left_bracket.texture = bracket_tex
	left_bracket.custom_minimum_size = Vector2(16, 60)
	left_bracket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_bracket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_bracket.modulate = tint
	left_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_bracket.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	left_bracket.position.x = -8
	panel.add_child(left_bracket)
	brackets["left"] = left_bracket

	# Right bracket (flipped)
	var right_bracket = TextureRect.new()
	right_bracket.texture = bracket_tex
	right_bracket.custom_minimum_size = Vector2(16, 60)
	right_bracket.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right_bracket.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right_bracket.flip_h = true
	right_bracket.modulate = tint
	right_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_bracket.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	right_bracket.position.x = -8
	panel.add_child(right_bracket)
	brackets["right"] = right_bracket

	return brackets


# =============================================================================
# TINT PRESETS (Matching overlay border colors)
# =============================================================================

const TINT_DEFAULT = Color(0.8, 0.85, 0.9, 0.9)
const TINT_BLUE = Color(0.6, 0.8, 1.0, 0.9)      # Inspector
const TINT_GOLD = Color(1.0, 0.9, 0.7, 0.9)      # Controls/Escape
const TINT_PURPLE = Color(0.8, 0.7, 1.0, 0.9)    # Semantic Map
const TINT_GREEN = Color(0.7, 1.0, 0.8, 0.9)     # Success states
const TINT_RED = Color(1.0, 0.7, 0.7, 0.9)       # Warning/quit
