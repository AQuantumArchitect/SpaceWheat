extends SceneTree

## Build Bundled Operator Cache
## Validates the exportable biome registry, rebuilds operator cache through the
## current runtime path, and copies the resulting cache into res://BundledCache/.
##
## Usage:
##   godot --headless --path . --script tools/BuildBundledCache.gd


var _registry: BiomeRegistry = null
var _exportable_biomes: Array[String] = []
var _bundled_cache_path: String = ProjectSettings.globalize_path("res://BundledCache")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_print_header("BUILDING BUNDLED OPERATOR CACHE")

	_registry = BiomeRegistry.new()
	_exportable_biomes = _get_exportable_biome_names()
	if _exportable_biomes.is_empty():
		_fail("No exportable biomes found in registry")
		return

	print("[1/6] Validating exportable biome registry...")
	if not _registry.validate_exportable():
		_fail("Biome registry validation failed; refusing to build bundled cache")
		return
	print("  ✓ %d exportable biomes validated" % _exportable_biomes.size())

	print("[2/6] Clearing runtime cache...")
	var cache = OperatorCache.get_instance()
	cache.clear_all()
	var user_cache_path = cache._cache_dir_absolute()
	print("  ✓ Runtime cache cleared at %s" % user_cache_path)

	print("[3/6] Clearing bundled cache directory...")
	_clear_directory(_bundled_cache_path)
	print("  ✓ Bundled cache directory ready at %s" % _bundled_cache_path)

	print("[4/6] Booting core systems...")
	var boot = get_root().get_node_or_null("/root/BootManager")
	if not boot:
		_fail("BootManager autoload not found")
		return

	# Use the canonical default scenario (new_game_easy), not a hardcoded "default" that
	# maps to res://Scenarios/default.tres — which doesn't exist, so boot_session returned
	# no farm and the cache rebuild always failed. The scenario only needs to yield a valid
	# farm; the exportable biomes are loaded explicitly in step 5.
	var farm = await boot.boot_session({
		"slot": -1,
		"scenario_id": SaveStore.DEFAULT_SCENARIO_ID,
		"headless": true,
	}, null)
	if not farm:
		_fail("boot_session() did not return a farm")
		return
	print("  ✓ Core boot complete")

	print("[5/6] Building operator cache through runtime biome loads...")
	for biome_name in _exportable_biomes:
		var result = boot.load_biome(biome_name, farm)
		if not result.get("success", false):
			_fail("Failed to load biome %s while building cache: %s" % [biome_name, str(result)])
			return
		print("  → %s%s" % [biome_name, " (already loaded)" if result.get("already_loaded", false) else ""])
		await process_frame

	cache = OperatorCache.get_instance()
	var manifest_size = cache.manifest.size()
	print("  ✓ Runtime cache manifest now contains %d biome entries" % manifest_size)

	print("[6/6] Copying cache into BundledCache and verifying coverage...")
	_copy_directory_json_files(user_cache_path, _bundled_cache_path)
	var verification = _verify_bundled_cache()
	if not verification.get("success", false):
		_fail(str(verification.get("message", "Bundled cache verification failed")))
		return

	print()
	print("  ✓ Bundled cache coverage verified")
	print("    Exportable biomes: %d" % _exportable_biomes.size())
	print("    Manifest entries:  %d" % int(verification.get("entry_count", 0)))
	print()
	_print_header("BUNDLED CACHE BUILD COMPLETE", true)
	quit(0)


func _get_exportable_biome_names() -> Array[String]:
	var names: Array[String] = []
	for biome in _registry.get_exportable_biomes():
		names.append(String(biome.name))
	return names


func _clear_directory(dir_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_error("Failed to open directory: %s" % dir_path)
		return
	dir.list_dir_begin()
	var entry = dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _copy_directory_json_files(source_dir: String, dest_dir: String) -> void:
	if not DirAccess.dir_exists_absolute(source_dir):
		push_error("Source cache directory does not exist: %s" % source_dir)
		return
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var source = DirAccess.open(source_dir)
	if source == null:
		push_error("Failed to open source cache directory: %s" % source_dir)
		return

	source.list_dir_begin()
	var entry = source.get_next()
	while entry != "":
		if not source.current_is_dir() and entry.ends_with(".json"):
			var source_path = source_dir.path_join(entry)
			var dest_path = dest_dir.path_join(entry)
			var input = FileAccess.open(source_path, FileAccess.READ)
			if input:
				var output = FileAccess.open(dest_path, FileAccess.WRITE)
				if output:
					output.store_string(input.get_as_text())
					output.close()
				input.close()
		entry = source.get_next()
	source.list_dir_end()


func _verify_bundled_cache() -> Dictionary:
	var manifest_path = _bundled_cache_path.path_join("manifest.json")
	if not FileAccess.file_exists(manifest_path):
		return {"success": false, "message": "Bundled manifest missing at %s" % manifest_path}

	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return {"success": false, "message": "Failed to open bundled manifest"}
	var json = JSON.new()
	var parse_err = json.parse(file.get_as_text())
	file.close()
	if parse_err != OK:
		return {"success": false, "message": "Bundled manifest is not valid JSON"}

	var manifest: Dictionary = json.data if json.data is Dictionary else {}
	var missing: Array[String] = []
	for biome_name in _exportable_biomes:
		if not manifest.has(biome_name):
			missing.append(biome_name)

	var extras: Array[String] = []
	for biome_name in manifest.keys():
		var text := str(biome_name)
		if text.begins_with("__"):
			continue  # meta entries (e.g. __schema__ version marker) — not biomes
		if text not in _exportable_biomes:
			extras.append(text)

	if not missing.is_empty():
		return {"success": false, "message": "Bundled cache missing entries for: %s" % ", ".join(missing)}
	if not extras.is_empty():
		return {"success": false, "message": "Bundled cache contains unexpected entries: %s" % ", ".join(extras)}

	return {
		"success": true,
		"entry_count": manifest.size()
	}


func _print_header(message: String, done := false) -> void:
	var separator = "=".repeat(70)
	print(separator)
	print("%s%s" % ["✅ " if done else "", message])
	print(separator)


func _fail(message: String) -> void:
	push_error(message)
	print()
	_print_header("BUNDLED CACHE BUILD FAILED", false)
	quit(1)
