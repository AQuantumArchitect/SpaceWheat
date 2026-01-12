extends SceneTree

## Build Bundled Operator Cache
## This script builds the operator cache and copies it to res://BundledCache/
## for inclusion in exported game builds.
##
## Usage:
##   godot --headless --script tools/BuildBundledCache.gd
##
## This should be run BEFORE exporting your game to ensure players
## get pre-built operators on first boot.

const OperatorCache = preload("res://Core/QuantumSubstrate/OperatorCache.gd")

var user_cache_path: String
var bundled_cache_path: String = "BundledCache/"  # Relative to project root

func _init():
	var separator = "======================================================================"
	print(separator)
	print("BUILDING BUNDLED OPERATOR CACHE")
	print(separator)
	print()

	# Get user data path
	user_cache_path = OS.get_user_data_dir() + "/operator_cache/"
	print("User cache path: %s" % user_cache_path)
	print("Bundled cache path: res://%s" % bundled_cache_path)
	print()

	# Step 1: Clear old bundled cache
	print("[1/5] Clearing old bundled cache...")
	_clear_bundled_cache()

	# Step 2: Clear user cache to force rebuild
	print("[2/5] Clearing user cache to force rebuild...")
	_clear_user_cache()

	# Step 3: Boot game to trigger operator building
	print("[3/5] Booting game to build operators...")
	print("       (This may take 1-2 seconds)")
	print()
	_boot_game()

	# Step 4: Copy user cache to bundled location
	print()
	print("[4/5] Copying cache to bundled location...")
	_copy_cache_to_bundled()

	# Step 5: Verify
	print("[5/5] Verifying bundled cache...")
	_verify_bundled_cache()

	print()
	var separator = "======================================================================"
	print(separator)
	print("✅ BUNDLED CACHE BUILD COMPLETE")
	print(separator)
	print()
	print("Next steps:")
	print("  1. The BundledCache/ folder has been created/updated")
	print("  2. Commit BundledCache/ to your repository")
	print("  3. Export your game - BundledCache/ will be included automatically")
	print()
	print("Players will now load operators instantly on first boot!")
	print()

	quit()

func _boot_game():
	"""Boot game minimally to trigger operator building"""
	# Load autoloads
	var boot_manager = load("res://Core/GameState/BootManager.gd")
	var icon_registry = load("res://Core/GameState/IconRegistry.gd")
	var biome_factory = load("res://Core/Environment/BiomeFactory.gd")

	# Initialize icon registry
	print("  → Loading IconRegistry...")
	var registry = icon_registry.new()
	registry.name = "IconRegistry"
	root.add_child(registry)

	# Wait for icons to load
	await process_frame

	print("  → Building biome operators...")

	# Build each biome to populate cache
	var biomes_to_build = [
		{"name": "BioticFlux", "type": "BioticFluxBiome"},
		{"name": "Market", "type": "MarketBiome"},
		{"name": "Forest", "type": "ForestEcosystem_Biome"},
		{"name": "Kitchen", "type": "QuantumKitchen_Biome"}
	]

	for biome_info in biomes_to_build:
		var biome_script = load("res://Core/Environment/%s.gd" % biome_info.type)
		if biome_script:
			print("     • %s..." % biome_info.name)
			var biome = biome_script.new()
			biome.biome_name = biome_info.name
			# Biome initialization will trigger operator building
			await process_frame
			biome.free()

	print("  ✓ All biomes built")

func _clear_bundled_cache():
	"""Clear old bundled cache directory"""
	var full_path = "res://" + bundled_cache_path
	if DirAccess.dir_exists_absolute(full_path):
		var dir = DirAccess.open(full_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		print("  ✓ Cleared old bundled cache")
	else:
		# Create directory
		DirAccess.make_dir_recursive_absolute(full_path)
		print("  ✓ Created bundled cache directory")

func _clear_user_cache():
	"""Clear user cache to force rebuild"""
	var cache = OperatorCache.get_instance()
	cache.clear_all()
	print("  ✓ Cleared user cache")

func _copy_cache_to_bundled():
	"""Copy user cache to bundled cache location"""
	if not DirAccess.dir_exists_absolute(user_cache_path):
		push_error("User cache not found at: %s" % user_cache_path)
		return

	var user_dir = DirAccess.open(user_cache_path)
	if not user_dir:
		push_error("Failed to open user cache directory")
		return

	var bundled_full_path = "res://" + bundled_cache_path
	if not DirAccess.dir_exists_absolute(bundled_full_path):
		DirAccess.make_dir_recursive_absolute(bundled_full_path)

	# Copy all files
	user_dir.list_dir_begin()
	var file_name = user_dir.get_next()
	var file_count = 0

	while file_name != "":
		if not user_dir.current_is_dir() and file_name.ends_with(".json"):
			var source = user_cache_path + file_name
			var dest = bundled_full_path + file_name

			# Read source
			var file = FileAccess.open(source, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()

				# Write to destination
				var dest_file = FileAccess.open(dest, FileAccess.WRITE)
				if dest_file:
					dest_file.store_string(content)
					dest_file.close()
					file_count += 1
					print("  → Copied %s" % file_name)

		file_name = user_dir.get_next()

	user_dir.list_dir_end()
	print("  ✓ Copied %d cache files" % file_count)

func _verify_bundled_cache():
	"""Verify bundled cache was created correctly"""
	var bundled_full_path = "res://" + bundled_cache_path
	var manifest_path = bundled_full_path + "manifest.json"

	if not FileAccess.file_exists(manifest_path):
		push_error("❌ Bundled manifest not found!")
		return

	var file = FileAccess.open(manifest_path, FileAccess.READ)
	if not file:
		push_error("❌ Failed to open bundled manifest")
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) != OK:
		push_error("❌ Bundled manifest is corrupt!")
		return

	var manifest = json.data
	var biome_count = manifest.size()

	print("  ✓ Found %d biomes in bundled cache:" % biome_count)
	for biome_name in manifest:
		var entry = manifest[biome_name]
		var cache_key = entry.get("cache_key", "unknown")
		var file_name = entry.get("file_name", "unknown")
		print("     • %s (key: %s)" % [biome_name, cache_key.substr(0, 8)])

	if biome_count == 0:
		push_warning("⚠️  No biomes found in cache - build may have failed")
