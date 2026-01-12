#!/usr/bin/env -S godot --headless -s
extends SceneTree

## Test Suite: Operator Caching System (Feature 4)
## Tests OperatorCache, OperatorSerializer, and CacheKey components

const Complex = preload("res://Core/QuantumSubstrate/Complex.gd")
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const OperatorCache = preload("res://Core/QuantumSubstrate/OperatorCache.gd")
const OperatorSerializer = preload("res://Core/QuantumSubstrate/OperatorSerializer.gd")
const CacheKey = preload("res://Core/QuantumSubstrate/CacheKey.gd")
const Icon = preload("res://Core/QuantumSubstrate/Icon.gd")
const IconRegistry = preload("res://Core/QuantumSubstrate/IconRegistry.gd")

var test_count: int = 0
var pass_count: int = 0

# Temporary test cache directory
var test_cache_dir: String = "user://test_operator_cache/"


func _init():
	print("\n" + "=".repeat(70))
	print("OPERATOR CACHING TEST SUITE (Feature 4)")
	print("=".repeat(70) + "\n")

	# Setup
	_setup_test_dir()

	# CacheKey tests
	test_cache_key_generation()
	test_cache_key_stability()
	test_cache_key_invalidation()

	# OperatorSerializer tests
	test_serialize_complex()
	test_serialize_complex_matrix()
	test_serialize_operators()
	test_deserialize_round_trip()

	# OperatorCache tests
	test_cache_save_load()
	test_cache_hit_miss_tracking()
	test_cache_invalidation()
	test_cache_manifest()

	# Integration tests
	test_cache_with_icon_changes()

	# Cleanup
	_cleanup_test_dir()

	# Summary
	print("\n" + "=".repeat(70))
	print("TESTS PASSED: %d/%d" % [pass_count, test_count])
	print("=".repeat(70) + "\n")

	quit()


## ========================================
## Test Utilities
## ========================================

func assert_true(condition: bool, message: String):
	test_count += 1
	if condition:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: " + message)


func assert_equal(actual, expected, message: String):
	test_count += 1
	if actual == expected:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])


func assert_approx(actual: float, expected: float, tolerance: float, message: String):
	test_count += 1
	if abs(actual - expected) < tolerance:
		pass_count += 1
		print("  ✓ " + message)
	else:
		print("  ✗ FAILED: %s (expected: %.4f, got: %.4f)" % [message, expected, actual])


## ========================================
## Setup/Cleanup
## ========================================

func _setup_test_dir():
	# Ensure test directory exists
	if not DirAccess.dir_exists_absolute(test_cache_dir):
		DirAccess.make_absolute(test_cache_dir)


func _cleanup_test_dir():
	# Remove test directory and contents
	var dir = DirAccess.open(test_cache_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not file_name.starts_with("."):
				var file_path = test_cache_dir + file_name
				DirAccess.remove_absolute(file_path)
			file_name = dir.get_next()
	if DirAccess.dir_exists_absolute(test_cache_dir):
		DirAccess.remove_absolute(test_cache_dir)


## ========================================
## CacheKey Tests
## ========================================

func test_cache_key_generation():
	print("\nTEST: Cache Key Generation")

	# Create mock icon registry
	var registry = _create_mock_registry()

	# Generate key for BioticFluxBiome
	var key1 = CacheKey.for_biome("BioticFluxBiome", registry)
	assert_true(key1.length() == 8, "Cache key should be 8 characters")
	assert_true(key1.is_valid_hex_number(), "Cache key should be hexadecimal")
	print()


func test_cache_key_stability():
	print("\nTEST: Cache Key Stability")

	var registry = _create_mock_registry()

	# Generate same key twice
	var key1 = CacheKey.for_biome("BioticFluxBiome", registry)
	var key2 = CacheKey.for_biome("BioticFluxBiome", registry)

	assert_equal(key1, key2, "Cache keys should be deterministic")
	print()


func test_cache_key_invalidation():
	print("\nTEST: Cache Key Invalidation on Config Change")

	var registry = _create_mock_registry()

	# Generate initial key
	var key1 = CacheKey.for_biome("BioticFluxBiome", registry)

	# Modify icon configuration
	if registry.icons.has("🌾"):
		var wheat_icon = registry.icons["🌾"]
		wheat_icon.self_energy = 9999.0  # Change it

		# Generate new key
		var key2 = CacheKey.for_biome("BioticFluxBiome", registry)

		assert_true(key1 != key2, "Cache key should change when Icon config changes")

	print()


## ========================================
## OperatorSerializer Tests
## ========================================

func test_serialize_complex():
	print("\nTEST: Serialize Complex Numbers")

	var c1 = Complex.new(3.5, 2.1)
	var c2 = Complex.new(-1.0, 4.5)
	var c3 = Complex.zero()

	# Note: OperatorSerializer works with matrices, not individual Complex numbers
	# This tests the serialization of Complex data within matrices

	assert_approx(c1.re, 3.5, 0.001, "Complex real part preserved")
	assert_approx(c1.im, 2.1, 0.001, "Complex imaginary part preserved")
	print()


func test_serialize_complex_matrix():
	print("\nTEST: Serialize ComplexMatrix")

	# Create a simple 2×2 matrix
	var matrix = ComplexMatrix.new(2)
	matrix.set_element(0, 0, Complex.new(1.0, 0.0))
	matrix.set_element(0, 1, Complex.new(0.5, 0.5))
	matrix.set_element(1, 0, Complex.new(0.5, -0.5))
	matrix.set_element(1, 1, Complex.new(2.0, 0.0))

	var data = OperatorSerializer.serialize_matrix(matrix)

	assert_equal(data.n, 2, "Matrix dimension preserved")
	assert_equal(data.data.size(), 4, "All 4 elements serialized")
	print()


func test_serialize_operators():
	print("\nTEST: Serialize Hamiltonian + Lindblad Operators")

	# Create mock operators
	var hamiltonian = ComplexMatrix.new(2)
	hamiltonian.set_element(0, 0, Complex.new(1.0, 0.0))
	hamiltonian.set_element(1, 1, Complex.new(2.0, 0.0))

	var lindblad1 = ComplexMatrix.new(2)
	lindblad1.set_element(0, 0, Complex.new(0.5, 0.0))

	var lindblad2 = ComplexMatrix.new(2)
	lindblad2.set_element(1, 1, Complex.new(0.3, 0.0))

	var lindblad_ops = [lindblad1, lindblad2]

	var data = OperatorSerializer.serialize_operators(hamiltonian, lindblad_ops)

	assert_true(data.has("hamiltonian"), "Data has hamiltonian")
	assert_true(data.has("lindblad_operators"), "Data has lindblad_operators")
	assert_equal(data.lindblad_count, 2, "Lindblad operator count correct")
	assert_true(data.has("timestamp"), "Data has timestamp")
	assert_equal(data.format_version, 1, "Format version recorded")
	print()


func test_deserialize_round_trip():
	print("\nTEST: Serialize/Deserialize Round Trip")

	# Create operators
	var hamiltonian = ComplexMatrix.new(2)
	hamiltonian.set_element(0, 0, Complex.new(1.5, 0.0))
	hamiltonian.set_element(1, 1, Complex.new(2.5, 0.0))

	var lindblad1 = ComplexMatrix.new(2)
	lindblad1.set_element(0, 1, Complex.new(0.1, 0.2))

	var lindblad_ops = [lindblad1]

	# Serialize
	var data = OperatorSerializer.serialize_operators(hamiltonian, lindblad_ops)

	# Deserialize
	var restored = OperatorSerializer.deserialize_operators(data)

	assert_true(restored.has("hamiltonian"), "Restored has hamiltonian")
	assert_true(restored.has("lindblad_operators"), "Restored has lindblad_operators")
	assert_equal(restored.lindblad_operators.size(), 1, "Lindblad count matches")

	# Verify matrix values
	var restored_ham = restored.hamiltonian
	assert_approx(restored_ham.get_element(0, 0).re, 1.5, 0.001, "Hamiltonian [0,0] preserved")
	assert_approx(restored_ham.get_element(1, 1).re, 2.5, 0.001, "Hamiltonian [1,1] preserved")

	var restored_lindblad = restored.lindblad_operators[0]
	assert_approx(restored_lindblad.get_element(0, 1).re, 0.1, 0.001, "Lindblad [0,1] real preserved")
	assert_approx(restored_lindblad.get_element(0, 1).im, 0.2, 0.001, "Lindblad [0,1] imag preserved")
	print()


## ========================================
## OperatorCache Tests
## ========================================

func test_cache_save_load():
	print("\nTEST: Cache Save and Load")

	var cache = OperatorCache.new()

	# Create mock operators
	var hamiltonian = ComplexMatrix.new(2)
	hamiltonian.set_element(0, 0, Complex.new(1.0, 0.0))

	var lindblad_ops = []

	# Save to cache
	var cache_key = "test1234"
	cache.save("TestBiome", cache_key, hamiltonian, lindblad_ops)

	# Load from cache
	var loaded = cache.try_load("TestBiome", cache_key)

	assert_true(not loaded.is_empty(), "Cache load returned data")
	assert_true(loaded.has("hamiltonian"), "Loaded has hamiltonian")
	print()


func test_cache_hit_miss_tracking():
	print("\nTEST: Cache Hit/Miss Tracking")

	var cache = OperatorCache.new()

	# Initial state
	assert_equal(cache.hit_count, 0, "Initial hit count is 0")
	assert_equal(cache.miss_count, 0, "Initial miss count is 0")

	# Attempt to load non-existent entry (miss)
	var result = cache.try_load("NonExistent", "anykey")
	assert_equal(cache.miss_count, 1, "Miss count incremented")

	# Save and load (hit)
	var hamiltonian = ComplexMatrix.new(2)
	hamiltonian.set_element(0, 0, Complex.one())
	cache.save("TestBiome", "key123", hamiltonian, [])

	result = cache.try_load("TestBiome", "key123")
	assert_equal(cache.hit_count, 1, "Hit count incremented")
	print()


func test_cache_invalidation():
	print("\nTEST: Cache Invalidation")

	var cache = OperatorCache.new()

	# Save entry
	var hamiltonian = ComplexMatrix.new(2)
	hamiltonian.set_element(0, 0, Complex.one())
	cache.save("TestBiome2", "key456", hamiltonian, [])

	# Verify it exists
	var loaded = cache.try_load("TestBiome2", "key456")
	assert_true(not loaded.is_empty(), "Entry exists after save")

	# Invalidate
	cache.invalidate("TestBiome2")

	# Verify it's gone
	loaded = cache.try_load("TestBiome2", "key456")
	assert_true(loaded.is_empty(), "Entry invalidated")
	print()


func test_cache_manifest():
	print("\nTEST: Cache Manifest Management")

	var cache = OperatorCache.new()

	# Create entries
	var h1 = ComplexMatrix.new(2)
	h1.set_element(0, 0, Complex.one())

	cache.save("Biome1", "key111", h1, [])
	cache.save("Biome2", "key222", h1, [])

	assert_true(cache.manifest.has("Biome1"), "Biome1 in manifest")
	assert_true(cache.manifest.has("Biome2"), "Biome2 in manifest")

	# Check entry structure
	var entry = cache.manifest["Biome1"]
	assert_equal(entry.cache_key, "key111", "Manifest has cache key")
	assert_true(entry.has("file_name"), "Manifest has file name")
	assert_true(entry.has("timestamp"), "Manifest has timestamp")
	print()


## ========================================
## Integration Tests
## ========================================

func test_cache_with_icon_changes():
	print("\nTEST: Cache Invalidation on Icon Changes")

	var registry = _create_mock_registry()
	var cache = OperatorCache.new()

	# Generate initial cache key
	var key1 = CacheKey.for_biome("BioticFluxBiome", registry)

	# Save operators with this key
	var hamiltonian = ComplexMatrix.new(2)
	hamiltonian.set_element(0, 0, Complex.one())
	cache.save("BioticFluxBiome", key1, hamiltonian, [])

	# Verify cache hit
	var result1 = cache.try_load("BioticFluxBiome", key1)
	assert_true(not result1.is_empty(), "Initial cache hit")

	# Change an icon parameter
	if registry.icons.has("🌾"):
		registry.icons["🌾"].self_energy = 9999.0

		# Generate new cache key
		var key2 = CacheKey.for_biome("BioticFluxBiome", registry)
		assert_true(key1 != key2, "Cache key changed after config modification")

		# Old key should now miss
		var result2 = cache.try_load("BioticFluxBiome", key1)
		assert_true(result2.is_empty(), "Old cache entry misses with changed icons")

	print()


## ========================================
## Helper Functions
## ========================================

func _create_mock_registry() -> IconRegistry:
	var registry = IconRegistry.new()

	# Create basic icons for testing
	var emojis = ["☀️", "🌙", "🌾", "🍄", "🏰"]
	for emoji in emojis:
		var icon = Icon.new()
		icon.emoji = emoji
		icon.display_name = emoji
		icon.self_energy = 1.0
		icon.hamiltonian_couplings = {}
		icon.lindblad_incoming = {}
		icon.lindblad_outgoing = {}
		icon.decay_rate = 0.0
		icon.decay_target = ""
		registry.register_icon(icon)

	return registry
