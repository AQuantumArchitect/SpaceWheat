# Cache Invalidation with External Icon Changes

## The Core Question
**"What if Icons change in a database or external file - will the cache detect it?"**

**Short Answer:** ✅ Yes, as long as IconRegistry loads the new data BEFORE biome initialization.

---

## How It Works

### The Flow
```
1. Game starts
2. IconRegistry autoload initializes
   └─> Loads Icons from source (code, JSON, database, etc.)
3. Biomes start initializing
4. BiomeBase._ready() runs:
   a. Generate cache key from IconRegistry (current data)
   b. Check if cache matches
   c. Load cache OR rebuild
```

**Key Point:** The cache key is generated from **IconRegistry's current data**, not from source files.

---

## Scenario Analysis

### ✅ Scenario 1: Icon Changed in Code
```gdscript
// CoreIcons.gd - BEFORE
wheat_icon.self_energy = 0.10

// CoreIcons.gd - AFTER
wheat_icon.self_energy = 0.15
```

**What happens:**
1. Developer saves file with new value
2. Next boot:
   - IconRegistry builds Icons from CoreIcons → sees 0.15
   - CacheKey hashes IconRegistry data → includes 0.15
   - Hash changes: `a4f3c2d1` → `f9d4b3a2`
   - Cache MISS (key doesn't match manifest)
   - Operators rebuild with new energy

**Result:** ✅ Cache automatically invalidates

---

### ✅ Scenario 2: Icon Changed in JSON File
```json
// icons.json - BEFORE
{
  "🌾": {
    "self_energy": 0.10,
    "hamiltonian_couplings": {"🐰": 0.3}
  }
}

// icons.json - AFTER
{
  "🌾": {
    "self_energy": 0.15,  // CHANGED
    "hamiltonian_couplings": {"🐰": 0.3}
  }
}
```

**What happens:**
1. Developer saves JSON with new value
2. Next boot:
   - IconRegistry loads from JSON → sees 0.15
   - CacheKey hashes IconRegistry data → includes 0.15
   - Hash changes → Cache MISS
   - Rebuild

**Result:** ✅ Cache automatically invalidates

---

### ✅ Scenario 3: Icon Changed in Database
```sql
-- BEFORE
UPDATE icons SET self_energy = 0.10 WHERE emoji = '🌾';

-- AFTER
UPDATE icons SET self_energy = 0.15 WHERE emoji = '🌾';
```

**What happens:**
1. Developer updates database
2. Next boot:
   - IconRegistry queries database → sees 0.15
   - CacheKey hashes data → includes 0.15
   - Hash changes → Cache MISS
   - Rebuild

**Result:** ✅ Cache automatically invalidates

---

### ❌ Scenario 4: Icon Changed AFTER Cache Load (Runtime)
```gdscript
# Boot sequence:
func _ready():
    # 1. Cache check happens first
    var cache_key = CacheKey.for_biome("BioticFlux", icon_registry)
    var cached = cache.try_load("BioticFlux", cache_key)  # Cache HIT

    # 2. Operators loaded from cache (based on old Icon data)

    # 3. THEN someone changes Icon at runtime
    icon_registry.icons["🌾"].self_energy = 0.99  # ⚠️ TOO LATE!

# Problem: Operators don't match Icon data anymore!
```

**Result:** ❌ Cache is stale, operators incorrect

**Solution:** Don't allow runtime Icon modifications, OR invalidate cache when Icons change:

```gdscript
# Option A: Lock Icons after cache load
func _ready():
    icon_registry.lock()  # Prevent modifications

# Option B: Invalidate cache on Icon change
signal icon_modified(emoji: String)

func set_icon_energy(emoji: String, energy: float):
    icons[emoji].self_energy = energy
    icon_modified.emit(emoji)
    # Tell biomes to rebuild operators
    OperatorCache.get_instance().invalidate_all()
```

---

## The Critical Requirement

### ⚡ Icons Must Load BEFORE Biomes Initialize

The cache system assumes:
```
IconRegistry._ready()     # MUST run first
  ↓
Load all Icon data
  ↓
BiomeBase._ready()        # Runs second
  ↓
Generate cache key from loaded Icons
```

**If you load Icons from external source:**
```gdscript
# In IconRegistry.gd
func _ready():
    # Load from wherever
    match ICON_SOURCE:
        "code":
            _load_from_code()  # CoreIcons, Factions
        "json":
            _load_from_json("res://Data/icons.json")
        "database":
            _load_from_database("sqlite://icons.db")

    # Icons MUST be fully loaded before this returns
    print("📜 IconRegistry ready: %d icons" % icons.size())
```

As long as IconRegistry is an autoload and loads synchronously, this works!

---

## Edge Case: Async Icon Loading

**What if Icons load asynchronously?**

```gdscript
# IconRegistry.gd
func _ready():
    _load_icons_async()  # Returns immediately
    # ⚠️ Icons not loaded yet!

# BiomeBase._ready() runs BEFORE Icons are loaded
# CacheKey hashes empty IconRegistry
# Cache key is wrong!
```

**Solution:** Wait for Icons before initializing biomes:

```gdscript
# IconRegistry.gd
signal icons_loaded()

func _ready():
    _load_icons_async()

func _on_icons_loaded():
    print("📜 IconRegistry ready: %d icons" % icons.size())
    icons_loaded.emit()

# BiomeBase.gd
func _ready():
    # Wait for Icons if needed
    var icon_registry = get_node("/root/IconRegistry")
    if icon_registry.icons.is_empty():
        await icon_registry.icons_loaded

    # Now safe to generate cache key
    var cache_key = CacheKey.for_biome(biome_name, icon_registry)
```

---

## Improving the Design: Dynamic Emoji Detection

**Current Weakness:** Biome emoji lists are hardcoded in CacheKey.gd:

```gdscript
static func _get_biome_emojis(biome_name: String) -> Array:
    match biome_name:
        "BioticFluxBiome":
            return ["☀️", "🌙", "🌾", "🏰", "🍄", "🐰", "🐺", "🍂"]
        # ⚠️ Must update manually when adding Icons!
```

**Better Approach:** Ask the biome which Icons it uses:

```gdscript
# In each biome class
class_name BioticFluxBiome

# Define which Icons affect this biome's operators
const OPERATOR_EMOJIS = ["☀️", "🌙", "🌾", "🏰", "🍄", "🐰", "🐺", "🍂"]

# Or even better - query from Faction
static func get_operator_emojis() -> Array:
    return AllFactions.get_faction_by_name("Agrarian").icons
```

**Updated CacheKey:**
```gdscript
static func _get_biome_emojis(biome_name: String) -> Array:
    # Load biome class and ask it
    var biome_class = load("res://Core/Environment/%s.gd" % biome_name)

    if biome_class.has("OPERATOR_EMOJIS"):
        return biome_class.OPERATOR_EMOJIS
    elif biome_class.has("get_operator_emojis"):
        return biome_class.get_operator_emojis()
    else:
        push_error("Biome %s doesn't define OPERATOR_EMOJIS!" % biome_name)
        return []
```

---

## Advanced: Dependency Tracking

**Problem:** Currently we hash ALL Icons a biome might use, even if not all are actually referenced.

**Better:** Track which Icons are ACTUALLY used during operator building:

```gdscript
# BiomeBase.gd
var _used_emojis: Array = []  # Track dependencies

func _build_quantum_operators():
    # During Hamiltonian building
    for emoji in emojis:
        var icon = icon_registry.icons[emoji]
        _used_emojis.append(emoji)  # Record dependency

        # Use icon data...
        H.set(i, j, icon.self_energy)

# CacheKey.gd
static func for_biome_precise(biome: BiomeBase, icon_registry) -> String:
    """Generate key from ACTUALLY USED Icons only"""
    var configs = {}

    for emoji in biome._used_emojis:  # Only dependencies
        configs[emoji] = _extract_icon_config(icon_registry.icons[emoji])

    return _hash_config(configs)
```

**Benefit:** If you change an Icon that a biome doesn't use, cache stays valid!

---

## Database-Backed Icon System Example

Here's how it would work with a database:

```gdscript
# Core/QuantumSubstrate/IconRegistry.gd
extends Node

var icons: Dictionary = {}
var db: SQLite  # Database connection

func _ready():
    _connect_to_database()
    _load_icons_from_db()
    print("📜 IconRegistry loaded %d icons from database" % icons.size())

func _load_icons_from_db():
    db.query("SELECT * FROM icons")

    for row in db.query_result:
        var icon = Icon.new()
        icon.emoji = row.emoji
        icon.self_energy = row.self_energy
        icon.display_name = row.display_name

        # Parse JSON fields
        icon.hamiltonian_couplings = JSON.parse_string(row.hamiltonian_couplings)
        icon.lindblad_incoming = JSON.parse_string(row.lindblad_incoming)

        icons[icon.emoji] = icon

# Developer workflow:
# 1. Update database: UPDATE icons SET self_energy = 0.15 WHERE emoji = '🌾'
# 2. Restart game
# 3. IconRegistry loads new value from database
# 4. CacheKey hashes new value → different key
# 5. Cache MISS → rebuild operators
# 6. Everything works!
```

---

## Testing Invalidation

```gdscript
# Test script to verify cache invalidation works
extends SceneTree

func _init():
    print("\n=== CACHE INVALIDATION TEST ===\n")

    # Get initial cache key
    var icon_registry = get_root().get_node("/root/IconRegistry")
    var key_before = CacheKey.for_biome("BioticFluxBiome", icon_registry)
    print("Key before: %s" % key_before)

    # Modify Icon
    var wheat = icon_registry.icons["🌾"]
    var old_energy = wheat.self_energy
    wheat.self_energy = 0.99

    # Generate new cache key
    var key_after = CacheKey.for_biome("BioticFluxBiome", icon_registry)
    print("Key after: %s" % key_after)

    # Verify keys are different
    if key_before != key_after:
        print("✅ Cache key changed - invalidation works!")
    else:
        print("❌ Cache key unchanged - invalidation BROKEN!")

    # Restore
    wheat.self_energy = old_energy

    quit()
```

---

## Summary: When Does Cache Invalidate?

| Scenario | Cache Behavior | Automatic? |
|----------|---------------|------------|
| Icon energy changed in code | ✅ Invalidates | Yes |
| Icon coupling changed in code | ✅ Invalidates | Yes |
| Icon loaded from JSON (changed) | ✅ Invalidates | Yes |
| Icon loaded from database (changed) | ✅ Invalidates | Yes |
| New Icon added to Faction | ✅ Invalidates* | Yes* |
| Icon changed at runtime (after cache load) | ❌ Stale cache | No |
| Biome algorithm changed | ❌ Same cache | No** |
| Non-operator Icon fields changed | ❌ Same cache | Yes*** |

\* If using dynamic emoji detection
\** Need manual version bump in CacheKey
\*** This is correct - don't invalidate for irrelevant changes

---

## Recommendations

### For Your Use Case (Frequent Icon Changes)

1. **Use Dynamic Emoji Detection**
   ```gdscript
   // In each biome
   const OPERATOR_EMOJIS = [...]  // Define dependencies
   ```

2. **Version Your Cache Algorithm**
   ```gdscript
   var config_data = {
       "version": 2,  // Bump when algorithm changes
       "icons": ...
   }
   ```

3. **Add Cache Stats to Debug Menu**
   ```gdscript
   func _on_debug_pressed():
       var cache = OperatorCache.get_instance()
       print("Cache hits: %d" % cache.hit_count)
       print("Cache misses: %d" % cache.miss_count)
   ```

4. **Consider Hybrid Approach**
   ```gdscript
   # For rapid iteration: Skip cache in debug builds
   if OS.is_debug_build():
       # Always rebuild (see changes immediately)
   else:
       # Use cache in production (fast startup)
   ```

---

## The Bottom Line

✅ **Cache invalidates automatically when:**
- Icon data changes (any source: code, JSON, database)
- IconRegistry loads before biomes initialize
- Hash is computed from loaded Icon data

❌ **Cache doesn't invalidate when:**
- Icons change at runtime (after cache loaded)
- Biome algorithm changes (need manual version bump)

**Your workflow will work perfectly as long as:**
1. Icons load before biomes initialize ✅
2. You don't modify Icons at runtime (or you handle it) ⚠️
3. You use dynamic emoji detection (or update manually) ⚠️

The current design handles database-backed Icons correctly! 🎉
