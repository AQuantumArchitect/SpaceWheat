class_name OperatorCache
extends RefCounted

## Manages operator cache with automatic invalidation
## Caches quantum operators (Hamiltonian + Lindblad) to disk
## Automatically invalidates when Icon configurations change


## Cache-key schema version. Bump when the cache-key formula changes
## (BiomeQuantumSystemBuilder.build_operators_from_icons computes the key).
## Stored in every manifest at the special key "__schema__"; on load, mismatched
## manifests are treated as empty so stale entries can never be served.
##
## History:
##   1 — initial format (icon poles only).
##   2 — added hash(atom_components) suffix (Round 2, 2026-05-08).
##   3 — folded full icon physics fields into key (Round 7, 2026-05-08).
const SCHEMA_VERSION: int = 3
const SCHEMA_KEY: String = "__schema__"

# User cache (runtime, modifiable)
const CACHE_DIR = "user://operator_cache/"
const MANIFEST_FILE = "user://operator_cache/manifest.json"
const FALLBACK_CACHE_DIR = "/tmp/spacewheat_operator_cache/"

# Bundled cache (shipped with game, read-only)
const BUNDLED_CACHE_DIR = "res://BundledCache/"
const BUNDLED_MANIFEST_FILE = "res://BundledCache/manifest.json"

# Singleton instance
static var _instance: OperatorCache = null

# Cache manifests: biome_name → {cache_key, file_name, timestamp}
var manifest: Dictionary = {}  # User cache
var bundled_manifest: Dictionary = {}  # Bundled cache (read-only)
var _resolved_user_cache_dir: String = ""
var _resolved_user_manifest_path: String = ""

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
	var ops = _try_load_from_dir(biome_name, cache_key, _user_cache_dir_path(), manifest)
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
	# Skip the schema marker — biome_name reserved word should never collide.
	if biome_name == SCHEMA_KEY:
		return {}

	# Check manifest
	if not cache_manifest.has(biome_name):
		return {}

	var entry = cache_manifest[biome_name]
	if not (entry is Dictionary):
		return {}

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
	_ensure_cache_dir()
	var file_name = "%s_%s.json" % [biome_name.to_lower().replace("_biome", ""), cache_key]
	var file_path = _user_cache_entry_path(file_name)

	# Serialize operators
	var data = OperatorSerializer.serialize_operators(hamiltonian, lindblad_ops)

	# Save to file
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to save cache: %s" % file_path)
		return

	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	# Update manifest (always stamp the schema marker).
	manifest[SCHEMA_KEY] = SCHEMA_VERSION
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
		var file_path = _cache_entry_absolute_path(str(entry.file_name))
		if FileAccess.file_exists(ProjectSettings.localize_path(file_path)):
			DirAccess.remove_absolute(file_path)
		manifest.erase(biome_name)
		_save_manifest()

## Invalidate all cached biomes
func invalidate_all():
	var biome_names = manifest.keys()
	for biome_name in biome_names:
		if biome_name == SCHEMA_KEY:
			continue
		invalidate(biome_name)

## Clear entire cache (useful for debugging)
func clear_all():
	var dir = DirAccess.open(_cache_dir_absolute())
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".json") and file_name != "manifest.json":
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	manifest.clear()
	manifest[SCHEMA_KEY] = SCHEMA_VERSION  # restamp so post-clear writes don't trigger spurious mismatch warnings
	_save_manifest()

## Get cache statistics
func get_stats() -> Dictionary:
	# Subtract the __schema__ marker from biome counts.
	var user_biomes = max(0, manifest.size() - (1 if manifest.has(SCHEMA_KEY) else 0))
	var bundled_biomes = max(0, bundled_manifest.size() - (1 if bundled_manifest.has(SCHEMA_KEY) else 0))
	return {
		"cached_biomes": user_biomes,
		"bundled_biomes": bundled_biomes,
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
	var cache_dir_abs = _cache_dir_absolute()
	if not DirAccess.dir_exists_absolute(cache_dir_abs):
		var err = DirAccess.make_dir_recursive_absolute(cache_dir_abs)
		if err != OK:
			push_error("Failed to create operator cache dir: %s (err=%d)" % [cache_dir_abs, err])

## Reject a manifest whose `__schema__` doesn't match SCHEMA_VERSION. Stale
## entries from a prior cache-key formula would never match the new key shape
## anyway; rejecting wholesale also prevents any partial-match weirdness.
func _validated_manifest(raw: Dictionary, source_label: String) -> Dictionary:
	var schema_value = raw.get(SCHEMA_KEY, null)
	if schema_value != null and int(schema_value) == SCHEMA_VERSION:
		return raw
	if not raw.is_empty():
		push_warning("OperatorCache: %s manifest schema mismatch (got %s, want %d) — discarding %d stale entries" % [
			source_label, str(schema_value), SCHEMA_VERSION, max(0, raw.size() - 1)])
	return {SCHEMA_KEY: SCHEMA_VERSION}


func _load_manifest():
	var manifest_path = _user_manifest_path()
	if not FileAccess.file_exists(manifest_path):
		manifest = {SCHEMA_KEY: SCHEMA_VERSION}
		return

	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if not file:
		manifest = {SCHEMA_KEY: SCHEMA_VERSION}
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) == OK:
		manifest = _validated_manifest(json.data, "user")
	else:
		manifest = {SCHEMA_KEY: SCHEMA_VERSION}

func _load_bundled_manifest():
	# Load bundled cache manifest (shipped with game, read-only)
	if not FileAccess.file_exists(BUNDLED_MANIFEST_FILE):
		bundled_manifest = {SCHEMA_KEY: SCHEMA_VERSION}
		return

	var file = FileAccess.open(BUNDLED_MANIFEST_FILE, FileAccess.READ)
	if not file:
		bundled_manifest = {SCHEMA_KEY: SCHEMA_VERSION}
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) == OK:
		bundled_manifest = _validated_manifest(json.data, "bundled")
	else:
		bundled_manifest = {SCHEMA_KEY: SCHEMA_VERSION}

func _save_manifest():
	_ensure_cache_dir()
	var file = FileAccess.open(_user_manifest_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	else:
		push_error("Failed to save operator cache manifest: %s" % _user_manifest_path())

func _calculate_cache_size_kb() -> float:
	var total_bytes = 0
	var dir = DirAccess.open(_cache_dir_absolute())
	if dir:
		for entry in manifest.values():
			if not (entry is Dictionary) or not entry.has("file_name"):
				continue  # skip __schema__ marker and any malformed entries
			var file_path = _user_cache_entry_path(str(entry.file_name))
			if FileAccess.file_exists(file_path):
				var file = FileAccess.open(file_path, FileAccess.READ)
				if file:
					total_bytes += file.get_length()
					file.close()
	return total_bytes / 1024.0


func _cache_dir_absolute() -> String:
	if _resolved_user_cache_dir == "":
		_resolve_user_cache_paths()
	return _resolved_user_cache_dir


func _cache_entry_absolute_path(file_name: String) -> String:
	return _cache_dir_absolute().path_join(file_name)


func _user_cache_dir_path() -> String:
	return _cache_dir_absolute()


func _user_cache_entry_path(file_name: String) -> String:
	return _cache_entry_absolute_path(file_name)


func _user_manifest_path() -> String:
	if _resolved_user_manifest_path == "":
		_resolve_user_cache_paths()
	return _resolved_user_manifest_path


func _resolve_user_cache_paths() -> void:
	var primary_dir = ProjectSettings.globalize_path(CACHE_DIR)
	if _can_write_cache_dir(primary_dir):
		_resolved_user_cache_dir = primary_dir
		_resolved_user_manifest_path = _resolved_user_cache_dir.path_join("manifest.json")
		return

	if _can_write_cache_dir(FALLBACK_CACHE_DIR):
		_resolved_user_cache_dir = FALLBACK_CACHE_DIR
		_resolved_user_manifest_path = _resolved_user_cache_dir.path_join("manifest.json")
		push_warning("OperatorCache: user cache dir is not writable, falling back to %s" % _resolved_user_cache_dir)
		return

	_resolved_user_cache_dir = primary_dir
	_resolved_user_manifest_path = _resolved_user_cache_dir.path_join("manifest.json")
	push_error("OperatorCache: no writable cache directory available")


func _can_write_cache_dir(dir_path: String) -> bool:
	var err = DirAccess.make_dir_recursive_absolute(dir_path)
	if err != OK and err != ERR_ALREADY_EXISTS:
		return false

	var probe_path = dir_path.path_join(".write_probe_%d.tmp" % Time.get_ticks_usec())
	var file = FileAccess.open(probe_path, FileAccess.WRITE)
	if not file:
		return false
	file.store_string("ok")
	file.close()
	DirAccess.remove_absolute(probe_path)
	return true
