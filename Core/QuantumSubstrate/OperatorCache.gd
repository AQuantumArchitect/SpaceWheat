class_name OperatorCache
extends RefCounted

## Manages operator cache with automatic invalidation
## Caches quantum operators (Hamiltonian + Lindblad) to disk
## Automatically invalidates when Icon configurations change

const OperatorSerializer = preload("res://Core/QuantumSubstrate/OperatorSerializer.gd")

# User cache (runtime, modifiable)
const CACHE_DIR = "user://operator_cache/"
const MANIFEST_FILE = "user://operator_cache/manifest.json"

# Bundled cache (shipped with game, read-only)
const BUNDLED_CACHE_DIR = "res://BundledCache/"
const BUNDLED_MANIFEST_FILE = "res://BundledCache/manifest.json"

# Singleton instance
static var _instance: OperatorCache = null

# Cache manifests: biome_name → {cache_key, file_name, timestamp}
var manifest: Dictionary = {}  # User cache
var bundled_manifest: Dictionary = {}  # Bundled cache (read-only)

# Statistics
var hit_count: int = 0
var miss_count: int = 0
var bundled_hit_count: int = 0  # Track bundled cache hits separately

## Get singleton instance
static func get_instance():
	if not _instance:
		var script = load("res://Core/QuantumSubstrate/OperatorCache.gd")
		_instance = script.new()
	return _instance

func _init():
	_ensure_cache_dir()
	_load_manifest()
	_load_bundled_manifest()

## Try to load cached operators
## Returns {hamiltonian, lindblad_operators} or {} if cache miss
## Checks user cache first, then bundled cache, then builds from scratch
func try_load(biome_name: String, cache_key: String) -> Dictionary:
	# Try user cache first (supports runtime modifications)
	var ops = _try_load_from_dir(biome_name, cache_key, CACHE_DIR, manifest)
	if not ops.is_empty():
		hit_count += 1
		return ops

	# Fallback to bundled cache (shipped with game)
	ops = _try_load_from_dir(biome_name, cache_key, BUNDLED_CACHE_DIR, bundled_manifest)
	if not ops.is_empty():
		bundled_hit_count += 1
		hit_count += 1  # Count as hit for statistics
		return ops

	# Both caches missed
	miss_count += 1
	return {}

## Internal: Try to load from a specific cache directory
func _try_load_from_dir(biome_name: String, cache_key: String, cache_dir: String, cache_manifest: Dictionary) -> Dictionary:
	# Check manifest
	if not cache_manifest.has(biome_name):
		return {}

	var entry = cache_manifest[biome_name]

	# Check if cache key matches (Icon configs haven't changed)
	if entry.cache_key != cache_key:
		return {}

	# Load cached file
	var file_path = cache_dir + entry.file_name
	if not FileAccess.file_exists(file_path):
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {}

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_str)
	if parse_result != OK:
		push_warning("Cache corrupt: %s" % file_path)
		return {}

	var data = json.data
	var operators = OperatorSerializer.deserialize_operators(data)

	if operators.is_empty():
		return {}

	return operators

## Save operators to cache with new cache key
func save(biome_name: String, cache_key: String, hamiltonian, lindblad_ops: Array):
	var file_name = "%s_%s.json" % [biome_name.to_lower().replace("_biome", ""), cache_key]
	var file_path = CACHE_DIR + file_name

	# Serialize operators
	var data = OperatorSerializer.serialize_operators(hamiltonian, lindblad_ops)

	# Save to file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save cache: %s" % file_path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Update manifest
	manifest[biome_name] = {
		"cache_key": cache_key,
		"file_name": file_name,
		"timestamp": Time.get_unix_time_from_system()
	}
	_save_manifest()

## Manually invalidate cache for a biome
func invalidate(biome_name: String):
	if manifest.has(biome_name):
		var entry = manifest[biome_name]
		var file_path = CACHE_DIR + entry.file_name
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
		manifest.erase(biome_name)
		_save_manifest()

## Invalidate all cached biomes
func invalidate_all():
	var biome_names = manifest.keys()
	for biome_name in biome_names:
		invalidate(biome_name)

## Clear entire cache (useful for debugging)
func clear_all():
	var dir = DirAccess.open(CACHE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and file_name != "manifest.json":
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	manifest.clear()
	_save_manifest()

## Get cache statistics
func get_stats() -> Dictionary:
	return {
		"cached_biomes": manifest.size(),
		"bundled_biomes": bundled_manifest.size(),
		"hit_count": hit_count,
		"bundled_hit_count": bundled_hit_count,
		"miss_count": miss_count,
		"hit_rate": (float(hit_count) / (hit_count + miss_count)) if (hit_count + miss_count) > 0 else 0.0,
		"total_size_kb": _calculate_cache_size_kb()
	}

## Print cache statistics (for debugging)
func print_stats():
	var stats = get_stats()
	print("\n=== OPERATOR CACHE STATS ===")
	print("User cache biomes: %d" % stats.cached_biomes)
	print("Bundled cache biomes: %d" % stats.bundled_biomes)
	print("Cache hits: %d (bundled: %d)" % [stats.hit_count, stats.bundled_hit_count])
	print("Cache misses: %d" % stats.miss_count)
	print("Hit rate: %.1f%%" % (stats.hit_rate * 100.0))
	print("Total size: %.2f KB" % stats.total_size_kb)

func _ensure_cache_dir():
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)

func _load_manifest():
	if not FileAccess.file_exists(MANIFEST_FILE):
		manifest = {}
		return

	var file = FileAccess.open(MANIFEST_FILE, FileAccess.READ)
	if not file:
		manifest = {}
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) == OK:
		manifest = json.data
	else:
		manifest = {}

func _load_bundled_manifest():
	"""Load bundled cache manifest (shipped with game, read-only)"""
	if not FileAccess.file_exists(BUNDLED_MANIFEST_FILE):
		bundled_manifest = {}
		return

	var file = FileAccess.open(BUNDLED_MANIFEST_FILE, FileAccess.READ)
	if not file:
		bundled_manifest = {}
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) == OK:
		bundled_manifest = json.data
	else:
		bundled_manifest = {}

func _save_manifest():
	var file = FileAccess.open(MANIFEST_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()

func _calculate_cache_size_kb() -> float:
	var total_bytes = 0
	var dir = DirAccess.open(CACHE_DIR)
	if dir:
		for entry in manifest.values():
			var file_path = CACHE_DIR + entry.file_name
			if FileAccess.file_exists(file_path):
				var file = FileAccess.open(file_path, FileAccess.READ)
				if file:
					total_bytes += file.get_length()
					file.close()
	return total_bytes / 1024.0
