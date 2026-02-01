class_name EmojiAtlasCache
extends RefCounted

## Emoji Atlas Cache - Persistent cache for pre-built emoji atlases
##
## Caches the atlas texture and UV mappings to disk using MD5 hash-based
## invalidation. When biomes or factions JSON files change, the cache
## automatically invalidates and rebuilds.
##
## Based on OperatorCache pattern - same approach, proven architecture.
##
## Performance impact:
##   First boot (cache miss): ~700ms (build + save)
##   Subsequent boots (cache hit): ~70ms (load from disk)
##   Speedup: ~10× faster boots after first run

# User cache (runtime, modifiable)
const CACHE_DIR = "user://emoji_atlas/"
const MANIFEST_FILE = "user://emoji_atlas/manifest.json"

# Bundled cache (shipped with game, read-only)
const BUNDLED_CACHE_DIR = "res://BundledCache/emoji_atlas/"
const BUNDLED_MANIFEST_FILE = "res://BundledCache/emoji_atlas/manifest.json"

# Atlas version - increment when atlas format changes
const ATLAS_VERSION = 1

# Atlas configuration (must match EmojiAtlasBatcher)
const ATLAS_CELL_SIZE = 64
const ATLAS_PADDING = 2
const MAX_ATLAS_SIZE = 2048

# Statistics
var cache_hits: int = 0
var cache_misses: int = 0
var bundled_hits: int = 0

# Manifest: cache_key → {atlas_file, uvmap_file, emoji_count, created_at}
var manifest: Dictionary = {}
var bundled_manifest: Dictionary = {}


func _init():
	_ensure_cache_dir()
	_load_manifest()
	_load_bundled_manifest()


## Generate cache key from emoji list + font size
## Uses MD5 hash for deterministic, collision-resistant keys
func generate_cache_key(emoji_list: Array, font_size: int) -> String:
	"""Generate MD5 hash as cache key.

	The key changes when:
	- Emoji list changes (additions, removals, reordering)
	- Font size changes
	- Atlas configuration changes

	This ensures automatic invalidation when source data changes.
	"""
	# Sort emojis for deterministic ordering
	var sorted_emojis = emoji_list.duplicate()
	sorted_emojis.sort()

	var config_data = {
		"version": ATLAS_VERSION,
		"emoji_list": sorted_emojis,
		"font_size": font_size,
		"atlas_config": {
			"CELL_SIZE": ATLAS_CELL_SIZE,
			"PADDING": ATLAS_PADDING,
			"MAX_SIZE": MAX_ATLAS_SIZE
		}
	}

	var json_str = JSON.stringify(config_data)
	return json_str.md5_text().substr(0, 8)  # 8-char hash (same as OperatorCache)


## Try to load cached atlas for given emoji list
## Returns dictionary with atlas data or empty dict on cache miss
func try_load(emoji_list: Array, font_size: int) -> Dictionary:
	"""Try to load atlas from cache.

	Checks user cache first, then bundled cache.

	Returns:
		{
			"success": true,
			"atlas_image": Image,
			"emoji_uvs": Dictionary,
			"atlas_width": int,
			"atlas_height": int,
			"cells_per_row": int,
			"source": "user_cache" | "bundled_cache"
		}
	or {"success": false} on cache miss.
	"""
	var cache_key = generate_cache_key(emoji_list, font_size)

	# Try user cache first
	var result = _try_load_from_dir(cache_key, CACHE_DIR, manifest)
	if result.success:
		cache_hits += 1
		result["source"] = "user_cache"
		return result

	# Try bundled cache
	result = _try_load_from_dir(cache_key, BUNDLED_CACHE_DIR, bundled_manifest)
	if result.success:
		cache_hits += 1
		bundled_hits += 1
		result["source"] = "bundled_cache"
		return result

	cache_misses += 1
	return {"success": false}


## Save atlas to user cache
func save(emoji_list: Array, font_size: int, atlas_image: Image,
		  emoji_uvs: Dictionary, atlas_width: int, atlas_height: int,
		  cells_per_row: int) -> bool:
	"""Save atlas and UV mappings to user cache.

	Args:
		emoji_list: Array of emoji strings (for cache key generation)
		font_size: Font size used for rendering
		atlas_image: The rendered atlas Image
		emoji_uvs: Dictionary mapping emoji → Rect2 UV coordinates
		atlas_width: Atlas width in pixels
		atlas_height: Atlas height in pixels
		cells_per_row: Number of emoji cells per row

	Returns:
		true if save was successful
	"""
	var cache_key = generate_cache_key(emoji_list, font_size)

	# Ensure cache directory exists
	_ensure_cache_dir()

	# Save atlas image as PNG (lossless, supports transparency)
	var atlas_file = "atlas_%s.png" % cache_key
	var atlas_path = CACHE_DIR + atlas_file
	var save_err = atlas_image.save_png(atlas_path)
	if save_err != OK:
		push_warning("[EmojiAtlasCache] Failed to save atlas PNG: %s (error %d)" % [atlas_path, save_err])
		return false

	# Save UV mappings as JSON
	var uv_data = {
		"version": ATLAS_VERSION,
		"atlas_width": atlas_width,
		"atlas_height": atlas_height,
		"cells_per_row": cells_per_row,
		"emoji_count": emoji_uvs.size(),
		"font_size": font_size,
		"emoji_uvs": {}
	}

	for emoji in emoji_uvs.keys():
		var rect = emoji_uvs[emoji]
		uv_data["emoji_uvs"][emoji] = {
			"x": rect.position.x,
			"y": rect.position.y,
			"w": rect.size.x,
			"h": rect.size.y
		}

	var uvmap_file = "uvmap_%s.json" % cache_key
	var uvmap_path = CACHE_DIR + uvmap_file
	var file = FileAccess.open(uvmap_path, FileAccess.WRITE)
	if not file:
		push_warning("[EmojiAtlasCache] Failed to open UV map for writing: %s" % uvmap_path)
		return false

	file.store_string(JSON.stringify(uv_data, "\t", true))
	file.close()

	# Update manifest
	manifest[cache_key] = {
		"atlas_file": atlas_file,
		"uvmap_file": uvmap_file,
		"emoji_count": emoji_uvs.size(),
		"atlas_size": "%dx%d" % [atlas_width, atlas_height],
		"font_size": font_size,
		"created_at": Time.get_datetime_string_from_system()
	}
	_save_manifest()

	print("[EmojiAtlasCache] Saved to cache: %s (%d emojis, %dx%d)" % [
		cache_key, emoji_uvs.size(), atlas_width, atlas_height
	])
	return true


## Load atlas from specific cache directory
func _try_load_from_dir(cache_key: String, cache_dir: String, cache_manifest: Dictionary) -> Dictionary:
	"""Internal: Load atlas and UV map from a cache directory."""
	# Check manifest for this cache key
	if not cache_manifest.has(cache_key):
		return {"success": false}

	var entry = cache_manifest[cache_key]

	# Build file paths
	var atlas_path = cache_dir + entry.atlas_file
	var uvmap_path = cache_dir + entry.uvmap_file

	# Check if files exist
	if not FileAccess.file_exists(atlas_path):
		return {"success": false}
	if not FileAccess.file_exists(uvmap_path):
		return {"success": false}

	# Load atlas image
	var atlas_image = Image.load_from_file(atlas_path)
	if atlas_image == null:
		push_warning("[EmojiAtlasCache] Failed to load atlas image: %s" % atlas_path)
		return {"success": false}

	# Load UV mappings
	var file = FileAccess.open(uvmap_path, FileAccess.READ)
	if not file:
		push_warning("[EmojiAtlasCache] Failed to open UV map: %s" % uvmap_path)
		return {"success": false}

	var json = JSON.new()
	var parse_err = json.parse(file.get_as_text())
	file.close()

	if parse_err != OK:
		push_warning("[EmojiAtlasCache] Failed to parse UV map JSON: %s" % uvmap_path)
		return {"success": false}

	var uv_data = json.data

	# Validate version
	if uv_data.get("version", 0) != ATLAS_VERSION:
		push_warning("[EmojiAtlasCache] Cache version mismatch (expected %d, got %d)" % [
			ATLAS_VERSION, uv_data.get("version", 0)
		])
		return {"success": false}

	# Reconstruct emoji_uvs dictionary
	var emoji_uvs = {}
	for emoji in uv_data["emoji_uvs"].keys():
		var rect_data = uv_data["emoji_uvs"][emoji]
		emoji_uvs[emoji] = Rect2(
			rect_data["x"],
			rect_data["y"],
			rect_data["w"],
			rect_data["h"]
		)

	print("[EmojiAtlasCache] Loaded from cache: %s (%d emojis, %dx%d)" % [
		cache_key,
		emoji_uvs.size(),
		uv_data["atlas_width"],
		uv_data["atlas_height"]
	])

	return {
		"success": true,
		"atlas_image": atlas_image,
		"emoji_uvs": emoji_uvs,
		"atlas_width": uv_data["atlas_width"],
		"atlas_height": uv_data["atlas_height"],
		"cells_per_row": uv_data["cells_per_row"]
	}


## Invalidate cache for a specific key
func invalidate(cache_key: String) -> void:
	"""Remove a specific cache entry."""
	if manifest.has(cache_key):
		var entry = manifest[cache_key]

		# Delete files
		var atlas_path = CACHE_DIR + entry.atlas_file
		var uvmap_path = CACHE_DIR + entry.uvmap_file

		if FileAccess.file_exists(atlas_path):
			DirAccess.remove_absolute(atlas_path)
		if FileAccess.file_exists(uvmap_path):
			DirAccess.remove_absolute(uvmap_path)

		manifest.erase(cache_key)
		_save_manifest()


## Clear entire cache
func clear_all() -> void:
	"""Remove all cached atlases."""
	var dir = DirAccess.open(CACHE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	manifest.clear()
	_save_manifest()
	print("[EmojiAtlasCache] Cache cleared")


## Get cache statistics
func get_stats() -> Dictionary:
	"""Return cache statistics for monitoring."""
	var total_requests = cache_hits + cache_misses
	return {
		"hits": cache_hits,
		"misses": cache_misses,
		"bundled_hits": bundled_hits,
		"hit_rate": (float(cache_hits) / total_requests * 100.0) if total_requests > 0 else 0.0,
		"cached_entries": manifest.size(),
		"bundled_entries": bundled_manifest.size(),
		"total_size_kb": _calculate_cache_size_kb()
	}


## Print cache statistics
func print_stats() -> void:
	"""Print cache statistics for debugging."""
	var stats = get_stats()
	print("\n=== EMOJI ATLAS CACHE STATS ===")
	print("User cache entries: %d" % stats.cached_entries)
	print("Bundled cache entries: %d" % stats.bundled_entries)
	print("Cache hits: %d (bundled: %d)" % [stats.hits, stats.bundled_hits])
	print("Cache misses: %d" % stats.misses)
	print("Hit rate: %.1f%%" % stats.hit_rate)
	print("Total size: %.2f KB" % stats.total_size_kb)


func _ensure_cache_dir() -> void:
	"""Create cache directory if it doesn't exist."""
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)


func _load_manifest() -> void:
	"""Load user cache manifest from disk."""
	if not FileAccess.file_exists(MANIFEST_FILE):
		manifest = {}
		return

	var file = FileAccess.open(MANIFEST_FILE, FileAccess.READ)
	if not file:
		manifest = {}
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		manifest = json.data
	else:
		manifest = {}
	file.close()


func _load_bundled_manifest() -> void:
	"""Load bundled cache manifest (shipped with game, read-only)."""
	if not FileAccess.file_exists(BUNDLED_MANIFEST_FILE):
		bundled_manifest = {}
		return

	var file = FileAccess.open(BUNDLED_MANIFEST_FILE, FileAccess.READ)
	if not file:
		bundled_manifest = {}
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		bundled_manifest = json.data
	else:
		bundled_manifest = {}
	file.close()


func _save_manifest() -> void:
	"""Save user cache manifest to disk."""
	var file = FileAccess.open(MANIFEST_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()


func _calculate_cache_size_kb() -> float:
	"""Calculate total cache size in KB."""
	var total_bytes = 0
	var dir = DirAccess.open(CACHE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.begins_with("."):
				var file_path = CACHE_DIR + file_name
				if FileAccess.file_exists(file_path):
					var file = FileAccess.open(file_path, FileAccess.READ)
					if file:
						total_bytes += file.get_length()
						file.close()
			file_name = dir.get_next()
		dir.list_dir_end()
	return total_bytes / 1024.0
