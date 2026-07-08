class_name BiomeVisualTheme
extends RefCounted

## BiomeVisualTheme — single palette authority for the Mini-Metro visual pass.
##
## Pure composer: (name, tags, optional authored seed color) → theme dict. Data
## lives in Core/Biomes/data/visual_themes.json (ordered tag rules); every biome
## resolves emergently — authored visual_config.color seeds the hue when present,
## else the first matching tag rule, else a deterministic name-hash. No biome is
## ever special-cased in code.
##
## Theme dict vocabulary (all consumers read exactly these keys):
##   base          Color — flat zone field (dark)
##   ink           Color — silhouette band / outlines / dots (near-black)
##   paper         Color — station disc fill (light)
##   warm          Color — plural-tint target (background lerps toward this
##                          as the biome's H spectral gap closes)
##   accent        Color — GLOBAL ripeness/value gold (same in every biome:
##                          one color = one meaning, like a metro line)
##   line_palette  Array[Color] — GLOBAL metro-line colors for H couplings
##   silhouette_id String — which band SVG the zone background tiles

const THEME_RULES_PATH := "res://Core/Biomes/data/visual_themes.json"

## Fallbacks if visual_themes.json is missing/corrupt (boot must not die on art).
const FALLBACK_ACCENT := Color(1.0, 0.8, 0.3)
const FALLBACK_LINE_PALETTE: Array = [
	Color(0.90, 0.22, 0.27), Color(0.96, 0.64, 0.38), Color(0.91, 0.77, 0.42),
	Color(0.16, 0.62, 0.56), Color(0.27, 0.48, 0.62), Color(0.62, 0.31, 0.87),
]

static var _rules: Array = []
static var _accent: Color = FALLBACK_ACCENT
static var _line_palette: Array = FALLBACK_LINE_PALETTE
static var _rules_loaded: bool = false
static var _theme_cache: Dictionary = {}  # biome name -> theme dict


## Adapter: resolve a biome's theme from the registry (cached; themes are
## immutable per run). Safe from any renderer — read-only w.r.t. mechanics.
static func get_theme(biome_name: String) -> Dictionary:
	if _theme_cache.has(biome_name):
		return _theme_cache[biome_name]
	var tags: Array = []
	var seed_color := Color.TRANSPARENT
	var biome = BiomeRegistry.get_shared().get_by_name(biome_name)
	if biome != null:
		tags = biome.tags
		var vc: Dictionary = biome.visual_config
		var col = vc.get("color", null)
		if col is Array and col.size() >= 3:
			seed_color = Color(float(col[0]), float(col[1]), float(col[2]))
	var theme := compose(biome_name, tags, seed_color)
	_theme_cache[biome_name] = theme
	return theme


## Pure composer. seed_color = Color.TRANSPARENT means "no authored seed".
static func compose(biome_name: String, tags: Array, seed_color: Color = Color.TRANSPARENT) -> Dictionary:
	_ensure_rules()
	var silhouette_id := "horizon"
	var hue := fmod(float(hash(biome_name) & 0xFFFF) * 0.61803, 1.0)
	for rule in _rules:
		if not (rule is Dictionary):
			continue
		if _tags_match(tags, rule.get("match_tags", [])):
			silhouette_id = str(rule.get("silhouette", "horizon"))
			hue = float(rule.get("hue", hue))
			break
	if seed_color != Color.TRANSPARENT:
		hue = seed_color.h
	return {
		"base": Color.from_hsv(hue, 0.30, 0.14),
		"ink": Color.from_hsv(hue, 0.40, 0.05),
		"paper": Color.from_hsv(hue, 0.08, 0.96),
		"warm": Color.from_hsv(_toward_warm(hue), 0.48, 0.22),
		"accent": _accent,
		"line_palette": _line_palette,
		"silhouette_id": silhouette_id,
	}


## Drop caches (save-slot transitions / tests that reload biomes.json).
static func reset() -> void:
	_theme_cache.clear()
	_rules_loaded = false


static func _tags_match(biome_tags: Array, match_tags: Array) -> bool:
	if not (match_tags is Array) or match_tags.is_empty():
		return false
	for t in match_tags:
		if biome_tags.has(str(t)):
			return true
	return false


## Pull a hue halfway toward the warm band (~0.07) along the short way around
## the wheel — the "plural" tint target stays kin to the zone's own hue.
static func _toward_warm(hue: float) -> float:
	var delta := fposmod(0.07 - hue + 0.5, 1.0) - 0.5
	return fposmod(hue + 0.5 * delta, 1.0)


static func _ensure_rules() -> void:
	if _rules_loaded:
		return
	_rules_loaded = true
	_rules = []
	if not FileAccess.file_exists(THEME_RULES_PATH):
		push_warning("BiomeVisualTheme: %s missing — name-hash palettes only" % THEME_RULES_PATH)
		return
	var file := FileAccess.open(THEME_RULES_PATH, FileAccess.READ)
	if file == null:
		push_warning("BiomeVisualTheme: cannot open %s" % THEME_RULES_PATH)
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("BiomeVisualTheme: parse error in %s line %d: %s"
				% [THEME_RULES_PATH, json.get_error_line(), json.get_error_message()])
		return
	var data = json.data
	if not (data is Dictionary):
		return
	_rules = data.get("rules", [])
	var defaults: Dictionary = data.get("defaults", {})
	_accent = _color_from(defaults.get("accent", null), FALLBACK_ACCENT)
	var pal = defaults.get("line_palette", null)
	if pal is Array and not pal.is_empty():
		var colors: Array = []
		for entry in pal:
			colors.append(_color_from(entry, Color.WHITE))
		_line_palette = colors


static func _color_from(arr, fallback: Color) -> Color:
	if arr is Array and arr.size() >= 3:
		var a := 1.0 if arr.size() < 4 else float(arr[3])
		return Color(float(arr[0]), float(arr[1]), float(arr[2]), a)
	return fallback
