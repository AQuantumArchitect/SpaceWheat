class_name TieredEmojiRegistry
extends RefCounted

## Three-tier emoji texture provider with priority fallback
##
## Priority 1: Hand-crafted SVGs (custom quality, ~29 emojis)
## Priority 2: Twemoji SVGs (downloaded, ~490 emojis)
## Priority 3: Text fallback (system font) with warnings

enum EmojiSource {
	HAND_CRAFTED,    # Priority 1: Custom SVGs from Assets/UI/
	TWEMOJI,         # Priority 2: Downloaded SVGs from Assets/emoji_svg/
	TEXT_FALLBACK    # Priority 3: System font rendering
}

# Caches
var _custom_cache: Dictionary = {}      # emoji → Texture2D
var _twemoji_cache: Dictionary = {}     # emoji → Texture2D
var _twemoji_index: Dictionary = {}     # emoji → codepoint filename

# Mappings
var _custom_mappings: Dictionary = {}   # emoji → res:// path

# Statistics
var _source_stats: Dictionary = {
	EmojiSource.HAND_CRAFTED: 0,
	EmojiSource.TWEMOJI: 0,
	EmojiSource.TEXT_FALLBACK: 0
}

var _warned_emojis: Dictionary = {}  # emoji → bool (avoid duplicate warnings)

func _init():
	_load_custom_mappings()
	_load_twemoji_index()


## PRIORITY 1: Hand-Crafted SVGs
func _load_custom_mappings():
	# Resources (Tier 1)
	_register_custom("💨", "res://Assets/UI/Resources/Flour.svg")
	_register_custom("🌾", "res://Assets/UI/Resources/Wheat.svg")
	_register_custom("🪵", "res://Assets/UI/Resources/Lumber.svg")
	_register_custom("⚡", "res://Assets/UI/Resources/Power.svg")

	# Elements (Tier 1)
	_register_custom("🔥", "res://Assets/UI/Elements/Fire.svg")
	_register_custom("💧", "res://Assets/UI/Elements/Water.svg")
	_register_custom("🌬️", "res://Assets/UI/Elements/Wind.svg")
	_register_custom("🌬", "res://Assets/UI/Elements/Wind.svg")  # Without variation selector

	# Celestial (Tier 1)
	_register_custom("☀", "res://Assets/UI/Celestial/Sun.svg")
	_register_custom("☀️", "res://Assets/UI/Celestial/Sun.svg")  # With variation selector
	_register_custom("🌙", "res://Assets/UI/Celestial/Moon.svg")

	# Nature (Tier 1)
	_register_custom("🌿", "res://Assets/UI/Nature/Vegetation.svg")
	_register_custom("🌱", "res://Assets/UI/Nature/Seedling.svg")
	_register_custom("🍂", "res://Assets/UI/Nature/Decay.svg")
	_register_custom("🌲", "res://Assets/UI/Nature/Forest.svg")

	# Tools (Tier 2)
	_register_custom("🔬", "res://Assets/UI/Tools/Spec.svg")
	_register_custom("🔗", "res://Assets/UI/Tools/Fabric.svg")
	_register_custom("⚙️", "res://Assets/UI/Tools/Efficiency.svg")
	_register_custom("⚙", "res://Assets/UI/Tools/Efficiency.svg")  # Without variation selector
	_register_custom("🏭", "res://Assets/UI/Tools/Station.svg")
	_register_custom("🛠️", "res://Assets/UI/Tools/Tools.svg")
	_register_custom("🛠", "res://Assets/UI/Tools/Tools.svg")  # Without variation selector
	_register_custom("💻", "res://Assets/UI/Tools/Code.svg")

	# Economic (Tier 2)
	_register_custom("💰", "res://Assets/UI/Economic/Wealth.svg")
	_register_custom("📡", "res://Assets/UI/Economic/Signal.svg")
	_register_custom("⚖️", "res://Assets/UI/Economic/Justice.svg")
	_register_custom("⚖", "res://Assets/UI/Economic/Justice.svg")  # Without variation selector
	_register_custom("🗝️", "res://Assets/UI/Economic/Lock.svg")
	_register_custom("🗝", "res://Assets/UI/Economic/Lock.svg")  # Without variation selector
	_register_custom("🔒", "res://Assets/UI/Economic/Lock.svg")
	_register_custom("👥", "res://Assets/UI/Economic/Collective.svg")

	# Math Symbols (NEW - not available in Twemoji)
	_register_custom("≈", "res://Assets/UI/Math/AlmostEqual.svg")
	_register_custom("≠", "res://Assets/UI/Math/NotEqual.svg")

	print("TieredEmojiRegistry: Loaded %d hand-crafted mappings" % _custom_mappings.size())


## PRIORITY 2: Twemoji SVG Index
func _load_twemoji_index():
	var index_path = "res://Assets/emoji_svg/emoji_index.json"
	if not FileAccess.file_exists(index_path):
		push_warning("TieredEmojiRegistry: Twemoji index not found at %s" % index_path)
		push_warning("  Using hand-crafted SVGs + text fallback only")
		return

	var file = FileAccess.open(index_path, FileAccess.READ)
	if not file:
		push_error("TieredEmojiRegistry: Failed to open twemoji index: %s" % FileAccess.get_open_error())
		return

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		push_error("TieredEmojiRegistry: Failed to parse twemoji index: %s" % json.get_error_message())
		return

	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_error("TieredEmojiRegistry: Twemoji index has invalid format")
		return

	var emojis_data = data.get("emojis", {})
	_twemoji_index = emojis_data

	print("TieredEmojiRegistry: Loaded %d twemoji mappings" % _twemoji_index.size())


## MAIN API: Get texture with 3-tier fallback
func get_texture(emoji: String) -> Texture2D:
	if emoji.is_empty():
		return null

	# Normalize emoji (handle variation selectors)
	var normalized = _normalize_emoji(emoji)

	# Priority 1: Hand-crafted SVG
	if _custom_mappings.has(normalized):
		if _custom_cache.has(normalized):
			return _custom_cache[normalized]

		var path = _custom_mappings[normalized]
		if ResourceLoader.exists(path):
			var texture = load(path) as Texture2D
			if texture:
				_custom_cache[normalized] = texture
				_source_stats[EmojiSource.HAND_CRAFTED] += 1
				return texture
			else:
				push_warning("TieredEmojiRegistry: Failed to load custom SVG: %s" % path)

	# Priority 2: Twemoji SVG
	if _twemoji_index.has(normalized):
		if _twemoji_cache.has(normalized):
			return _twemoji_cache[normalized]

		var filename = _twemoji_index[normalized]
		var path = "res://Assets/emoji_svg/" + filename

		if ResourceLoader.exists(path):
			var texture = load(path) as Texture2D
			if texture:
				_twemoji_cache[normalized] = texture
				_source_stats[EmojiSource.TWEMOJI] += 1
				return texture
			else:
				push_warning("TieredEmojiRegistry: Failed to load twemoji SVG: %s" % path)
		else:
			if not _warned_emojis.has(normalized):
				push_warning("TieredEmojiRegistry: Twemoji SVG missing: '%s' (expected: %s)" % [emoji, path])
				_warned_emojis[normalized] = true

	# Priority 3: Will use text fallback (null return)
	_source_stats[EmojiSource.TEXT_FALLBACK] += 1
	if not _warned_emojis.has(normalized):
		push_warning("⚠️ EMOJI TEXT FALLBACK: '%s' not found in custom or twemoji" % emoji)
		_warned_emojis[normalized] = true

	return null


## Check if emoji has ANY source (no text fallback needed)
func has_texture(emoji: String) -> bool:
	var normalized = _normalize_emoji(emoji)
	return _custom_mappings.has(normalized) or _twemoji_index.has(normalized)


## Get source tier for debugging
func get_source(emoji: String) -> EmojiSource:
	var normalized = _normalize_emoji(emoji)
	if _custom_mappings.has(normalized):
		return EmojiSource.HAND_CRAFTED
	if _twemoji_index.has(normalized):
		return EmojiSource.TWEMOJI
	return EmojiSource.TEXT_FALLBACK


## Emoji normalization (handle variation selectors, ZWJ, etc.)
func _normalize_emoji(emoji: String) -> String:
	# Remove variation selector 16 (FE0F) - visual representation hint
	var normalized = emoji.replace(String.chr(0xFE0F), "")
	# Remove variation selector 15 (FE0E) - text representation hint
	normalized = normalized.replace(String.chr(0xFE0E), "")
	return normalized


## Helper for codepoint conversion (for debugging)
func _emoji_to_codepoint(emoji: String) -> String:
	var codepoints = []
	for i in range(emoji.length()):
		var code = emoji.unicode_at(i)
		codepoints.append("%x" % code)
	return "-".join(codepoints)


## Statistics for debugging
func print_statistics():
	print("=== TieredEmojiRegistry Statistics ===")
	print("  Hand-Crafted: %d uses" % _source_stats[EmojiSource.HAND_CRAFTED])
	print("  Twemoji:      %d uses" % _source_stats[EmojiSource.TWEMOJI])
	print("  Text Fallback: %d uses ⚠️" % _source_stats[EmojiSource.TEXT_FALLBACK])
	print("  Custom cache: %d loaded" % _custom_cache.size())
	print("  Twemoji cache: %d loaded" % _twemoji_cache.size())
	print("=====================================")


## Reset statistics (for testing/profiling)
func reset_statistics():
	_source_stats = {
		EmojiSource.HAND_CRAFTED: 0,
		EmojiSource.TWEMOJI: 0,
		EmojiSource.TEXT_FALLBACK: 0
	}
	_warned_emojis.clear()


func _register_custom(emoji: String, path: String):
	_custom_mappings[emoji] = path
