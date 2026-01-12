# Boot Performance Optimization Solutions

**Current Issue:** Farm initialization takes >30 seconds
**Root Cause:** Quantum operator building for 4 biomes during Farm._ready()

---

## Bottleneck Analysis

From the boot logs, the slowdown happens during:
```
🔨 Building Hamiltonian: 3 qubits (8D)...
  [30+ coupling calculations per biome]
🔨 Building Lindblad operators: 3 qubits (8D)...
  [20+ Lindblad operator checks per biome]
```

**Cost per biome:**
- Hamiltonian: 8×8 ComplexMatrix construction (~50 coupling checks)
- Lindblad: 2-5 operators × 8×8 matrices (~30 transfer checks)
- RegisterMap: Allocate coordinates for 10-20 emojis

**Total cost:** 4 biomes × ~100 matrix operations each = **~400 operations**

---

## Solution 1: Pre-Built Operator Cache (BEST FOR QUICK WIN)

### Concept
Serialize pre-computed Hamiltonian/Lindblad operators to disk and load them instead of computing.

### Implementation

```gdscript
# Core/Environment/OperatorCache.gd
class_name OperatorCache

const CACHE_DIR = "res://Data/OperatorCache/"

static func save_operators(biome_name: String, hamiltonian: ComplexMatrix, lindblad_ops: Array):
	"""Save pre-computed operators to disk"""
	var cache_file = CACHE_DIR + biome_name + ".tres"
	var data = {
		"hamiltonian": hamiltonian.serialize(),  # Convert to Dictionary
		"lindblad_ops": lindblad_ops.map(func(op): return op.serialize()),
		"version": 1,
		"timestamp": Time.get_unix_time_from_system()
	}
	ResourceSaver.save(cache_file, data)

static func load_operators(biome_name: String) -> Dictionary:
	"""Load pre-computed operators from disk"""
	var cache_file = CACHE_DIR + biome_name + ".tres"
	if not FileAccess.file_exists(cache_file):
		return {}

	var data = ResourceLoader.load(cache_file)
	if data:
		return {
			"hamiltonian": ComplexMatrix.deserialize(data.hamiltonian),
			"lindblad_ops": data.lindblad_ops.map(func(op): return ComplexMatrix.deserialize(op))
		}
	return {}

# In BiomeBase.gd
func _ready():
	# Try to load cached operators
	var cached = OperatorCache.load_operators(biome_name)
	if cached.has("hamiltonian"):
		quantum_computer.hamiltonian = cached.hamiltonian
		quantum_computer.lindblad_operators = cached.lindblad_ops
		print("✓ Loaded cached operators for %s" % biome_name)
	else:
		# Build operators (slow path)
		build_hamiltonian()
		build_lindblad_operators()

		# Save for next boot
		OperatorCache.save_operators(biome_name, quantum_computer.hamiltonian, quantum_computer.lindblad_operators)
```

**Pros:**
- First boot: slow (build + save)
- Every boot after: ~100x faster (just load)
- No code changes to quantum logic
- Easy to invalidate cache (delete files)

**Cons:**
- Cache invalidation: must rebuild when Icon configs change
- Disk space: ~4 × 8×8 matrices × 2 (Hamiltonian + Lindblad) = ~2KB per biome

**Estimated Speedup:** 30s → 0.3s (100x)

---

## Solution 2: Lazy Biome Initialization (BEST FOR FLEXIBILITY)

### Concept
Don't create biomes until they're actually needed (first plant/interaction).

### Implementation

```gdscript
# Core/Farm.gd
func _ready():
	# ... grid setup ...

	# DON'T create biomes yet
	# biotic_flux_biome = BioticFluxBiome.new()  # REMOVE

	# Initialize them lazily
	biotic_flux_biome = null
	market_biome = null
	forest_biome = null
	kitchen_biome = null

	print("✓ Farm ready (biomes will load on demand)")

func get_biome_for_plot(position: Vector2i):
	"""Get or create biome for this plot"""
	var biome_type = _determine_biome_type(position)

	match biome_type:
		"biotic_flux":
			if not biotic_flux_biome:
				print("⏳ Loading BioticFluxBiome...")
				biotic_flux_biome = BioticFluxBiome.new()
				add_child(biotic_flux_biome)
				grid.register_biome(biotic_flux_biome)
			return biotic_flux_biome
		"market":
			if not market_biome:
				print("⏳ Loading MarketBiome...")
				market_biome = MarketBiome.new()
				add_child(market_biome)
				grid.register_biome(market_biome)
			return market_biome
		# ... etc

func plant_plot(position: Vector2i, emoji: String):
	var biome = get_biome_for_plot(position)  # Lazy load
	return grid.plant_plot(position, emoji)
```

**Pros:**
- Instant boot (0.5s)
- Only loads biomes you actually use
- Great for testing (can test single biome)
- Progressive loading (spread cost over gameplay)

**Cons:**
- First interaction with each biome has delay
- Complexity: must track which biomes are loaded
- Need careful synchronization

**Estimated Speedup:** 30s → 0.5s boot, 5-7s first interaction per biome

---

## Solution 3: Async/Background Loading (BEST FOR UX)

### Concept
Build biomes in background thread, show progress, allow interaction as soon as first biome ready.

### Implementation

```gdscript
# Core/Boot/BiomeLoader.gd
class_name BiomeLoader

signal biome_loaded(biome_name: String, biome: Node)
signal all_biomes_loaded()

var loading_thread: Thread
var biomes_to_load: Array[Dictionary]
var loaded_biomes: Dictionary = {}

func load_biomes_async(biome_configs: Array):
	"""Load biomes in background thread"""
	biomes_to_load = biome_configs
	loading_thread = Thread.new()
	loading_thread.start(_load_biomes_worker)

func _load_biomes_worker():
	"""Worker thread - builds biomes one by one"""
	for config in biomes_to_load:
		var biome_class = load(config.path)
		var biome = biome_class.new()

		# Signal main thread (deferred)
		call_deferred("_on_biome_loaded", config.name, biome)

		# Small delay to avoid blocking
		OS.delay_msec(100)

	call_deferred("emit_signal", "all_biomes_loaded")

func _on_biome_loaded(biome_name: String, biome: Node):
	loaded_biomes[biome_name] = biome
	biome_loaded.emit(biome_name, biome)

# In Farm.gd
func _ready():
	var loader = BiomeLoader.new()
	add_child(loader)

	loader.biome_loaded.connect(_on_biome_ready)
	loader.all_biomes_loaded.connect(_on_all_biomes_ready)

	loader.load_biomes_async([
		{"name": "biotic_flux", "path": "res://Core/Environment/BioticFluxBiome.gd"},
		{"name": "market", "path": "res://Core/Environment/MarketBiome.gd"},
		{"name": "forest", "path": "res://Core/Environment/ForestEcosystem_Biome.gd"},
		{"name": "kitchen", "path": "res://Core/Environment/QuantumKitchen_Biome.gd"}
	])

	print("✓ Farm ready (biomes loading...)")

func _on_biome_ready(biome_name: String, biome: Node):
	match biome_name:
		"biotic_flux":
			biotic_flux_biome = biome
		"market":
			market_biome = biome
		# ... etc

	print("✓ %s ready" % biome_name)

func _on_all_biomes_ready():
	print("✅ All biomes loaded!")
```

**Pros:**
- Farm interactive immediately
- Smooth UX (can show loading bar)
- Spreads CPU load over time
- Doesn't block main thread

**Cons:**
- Thread safety complexity
- Must handle "biome not ready yet" cases
- GDScript threading limitations

**Estimated Speedup:** 30s → 0.5s boot, 30s background (non-blocking)

---

## Solution 4: Test Mode Flag (BEST FOR TESTING)

### Concept
Add a flag to skip quantum operator building entirely for unit tests.

### Implementation

```gdscript
# Core/Environment/BiomeBase.gd
var skip_quantum_init: bool = false  # Set by tests

func _ready():
	if skip_quantum_init:
		print("⚠️ Skipping quantum initialization (test mode)")
		return

	# Normal initialization
	build_hamiltonian()
	build_lindblad_operators()

# In tests:
func _init():
	var farm = Farm.new()

	# Set test mode on all biomes
	farm.biotic_flux_biome.skip_quantum_init = true
	farm.market_biome.skip_quantum_init = true
	farm.forest_biome.skip_quantum_init = true
	farm.kitchen_biome.skip_quantum_init = true

	root.add_child(farm)
	# Farm ready in 0.5s
```

**Pros:**
- Trivial to implement
- Perfect for unit tests
- No production code impact
- Instant test startup

**Cons:**
- Can't test quantum features
- Two code paths (can cause bugs)
- Not a real solution (just hiding the problem)

**Estimated Speedup:** 30s → 0.5s (tests only)

---

## Solution 5: Operator Templates (HYBRID APPROACH)

### Concept
Pre-compute operator structure, only fill in Icon-specific values at runtime.

### Implementation

```gdscript
# Core/QuantumSubstrate/HamiltonianTemplate.gd
class_name HamiltonianTemplate

# Pre-computed structure (which emojis couple to which)
var structure: Dictionary = {
	"🔥": {"self": 0, "couplings": {"💧": 0, "❄️": 1}},
	"💧": {"self": 1, "couplings": {"🔥": 0, "❄️": 2}},
	# ... etc
}

func apply_icon_data(icon_registry: IconRegistry) -> ComplexMatrix:
	"""Fast: just plug in Icon values, don't recalculate structure"""
	var H = ComplexMatrix.zero(8, 8)

	for emoji in structure:
		var icon = icon_registry.icons[emoji]

		# Self-energy (pre-computed index)
		H.data[structure[emoji].self] = Complex.new(icon.self_energy, 0.0)

		# Couplings (pre-computed indices)
		for target in structure[emoji].couplings:
			var idx = structure[emoji].couplings[target]
			var coupling = icon.hamiltonian_couplings.get(target, 0.0)
			H.data[idx] = Complex.new(coupling, 0.0)

	return H

# Save templates to disk once:
static func generate_template(biome_name: String):
	var template = HamiltonianTemplate.new()
	# Analyze biome structure once
	template.structure = _analyze_biome_structure(biome_name)
	ResourceSaver.save("res://Data/Templates/" + biome_name + "_template.tres", template)
```

**Pros:**
- Fast runtime (just array lookups)
- Updates when Icons change (uses registry)
- One-time template generation
- Flexible (can regenerate templates)

**Cons:**
- Complex implementation
- Still need to generate templates
- Tight coupling to biome structure

**Estimated Speedup:** 30s → 2-3s

---

## Solution 6: Parallel Biome Initialization

### Concept
Create all 4 biomes in parallel threads instead of sequentially.

### Implementation

```gdscript
# Core/Farm.gd
func _ready():
	# ... grid setup ...

	var threads: Array[Thread] = []
	var biome_results: Array = [null, null, null, null]

	# Spawn 4 threads
	for i in range(4):
		var thread = Thread.new()
		threads.append(thread)
		thread.start(_create_biome_worker.bind(i, biome_results))

	# Wait for all threads
	for i in range(4):
		threads[i].wait_to_finish()

	# Assign results
	biotic_flux_biome = biome_results[0]
	market_biome = biome_results[1]
	forest_biome = biome_results[2]
	kitchen_biome = biome_results[3]

	print("✓ All biomes ready")

func _create_biome_worker(index: int, results: Array):
	match index:
		0:
			results[0] = BioticFluxBiome.new()
		1:
			results[1] = MarketBiome.new()
		2:
			results[2] = ForestEcosystem_Biome.new()
		3:
			results[3] = QuantumKitchen_Biome.new()
```

**Pros:**
- Simple concept
- 4x speedup on multi-core CPUs
- No logic changes

**Cons:**
- Thread safety (must ensure no shared state)
- GDScript threading limitations
- Still slow on single-core

**Estimated Speedup:** 30s → 7-8s (4 cores)

---

## Recommended Approach: Hybrid Solution

Combine **Solution 1 (Pre-Built Cache)** + **Solution 2 (Lazy Init)** + **Solution 4 (Test Mode)**:

### Implementation Plan

1. **Phase 1: Add Test Mode** (5 minutes)
   - Add `skip_quantum_init` flag to BiomeBase
   - Update tests to use it
   - **Immediate benefit:** Tests run fast

2. **Phase 2: Implement Operator Cache** (30 minutes)
   - Create OperatorCache.gd
   - Add serialization to ComplexMatrix
   - Build cache on first boot
   - **Benefit:** Subsequent boots ~100x faster

3. **Phase 3: Add Lazy Loading** (1 hour)
   - Refactor Farm to lazy-load biomes
   - Add biome demand detection
   - **Benefit:** Boot time drops to 0.5s

### Result:
- **Test Mode:** 0.5s boot
- **First Boot:** 30s (build + cache)
- **Subsequent Boots:** 0.5s (load cache)
- **Lazy Mode:** 0.5s + 0.3s per biome on demand

---

## Quick Win (15 Minutes)

If you want the fastest improvement right now:

```gdscript
# Core/Farm.gd - Add at top of _ready()
func _ready():
	# QUICK WIN: Skip biomes in headless mode (tests)
	if DisplayServer.get_name() == "headless":
		print("⚡ Headless mode: Skipping biome initialization")
		_ready_headless()
		return

	# Normal initialization for real game
	_ready_normal()

func _ready_headless():
	"""Fast path for tests"""
	grid = FarmGrid.new()
	economy = FarmEconomy.new()
	# Skip biomes entirely
	print("✓ Farm ready (headless)")

func _ready_normal():
	"""Full initialization for game"""
	# Original _ready() code here
```

**Result:** Tests run in 0.5s, game still works normally!

---

## Performance Targets

| Scenario | Current | Target | Solution |
|----------|---------|--------|----------|
| Unit Tests | 30s | 0.5s | Test Mode Flag |
| First Boot | 30s | 5s | Operator Cache |
| Subsequent Boots | 30s | 0.5s | Load Cache |
| Lazy Load | N/A | 0.5s + 0.3s/biome | Lazy Init |

---

## Implementation Priority

1. **🔥 Quick Win:** Test mode flag (15 min) → Tests fast immediately
2. **⚡ High Impact:** Operator cache (30 min) → Boots 100x faster
3. **✨ Best UX:** Lazy loading (1 hour) → Instant boot, progressive load
4. **🎯 Polish:** Async loading + progress bar (2 hours) → Smooth UX

Choose based on your priorities:
- Need tests working now? → Do #1
- Want fast boot always? → Do #2
- Want instant startup? → Do #3
- Want polished experience? → Do #4
