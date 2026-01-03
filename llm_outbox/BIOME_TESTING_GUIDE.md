# Biome Variations Testing Guide

**Status:** Implementation complete - Manual testing recommended

---

## What Was Created

### Four Test Biomes

1. **MinimalTestBiome.gd** - Hand-crafted minimal (3 emojis: ☀🌾💧)
2. **DualBiome.gd** - 2-way merge (BioticFlux + Market = 12 emojis)
3. **TripleBiome.gd** - 3-way merge (BioticFlux + Market + Kitchen = 15 emojis)
4. **MergedEcosystem_Biome.gd** - Example merge (BioticFlux + Forest = 13 emojis)

### Test Script

**Tests/test_biome_variations.gd** - Comprehensive automated test (headless mode has IconRegistry issues)

---

## Manual Testing (Recommended)

### Test 1: Minimal Biome

```gdscript
# In Godot script console or test scene:

var minimal = MinimalTestBiome.new()
minimal._ready()

print(minimal.bath.emoji_list)
# Expected: ["☀", "🌾", "💧"]

print(minimal.bath.emoji_list.size())
# Expected: 3

# Create projection
var proj = minimal.create_projection(Vector2i(0, 0), "🌾", "💧")
print(proj.theta)  # Should have valid theta

# Verify normalization
var total = 0.0
for emoji in minimal.bath.emoji_list:
    total += minimal.bath.get_probability(emoji)
print(total)  # Should be ~1.0
```

**Expected Results:**
- ✅ Exactly 3 emojis
- ✅ Bath normalized
- ✅ Projection works
- ✅ Hamiltonian + Lindblad built from Icons

---

### Test 2: Hot Drop Emoji

```gdscript
var bioticflux = BioticFluxBiome.new()
bioticflux._ready()

print("Before:", bioticflux.bath.emoji_list.size())
# Expected: 6

bioticflux.hot_drop_emoji("🐺", Complex.new(0.1, 0.0))

print("After:", bioticflux.bath.emoji_list.size())
# Expected: 7

print("🐺" in bioticflux.bath.emoji_list)
# Expected: true

print(bioticflux.bath.get_population("🐺"))
# Expected: > 0

# Create projection with hot-dropped emoji
var proj = bioticflux.create_projection(Vector2i(0, 0), "🐺", "🌾")
print(proj != null)  # Should work

# Verify still normalized
var total = 0.0
for emoji in bioticflux.bath.emoji_list:
    total += bioticflux.bath.get_probability(emoji)
print(total)  # Should be ~1.0
```

**Expected Results:**
- ✅ Emoji count increases by 1
- ✅ Wolf has non-zero population
- ✅ Bath still normalized
- ✅ Can project with hot-dropped emoji
- ✅ Operators rebuilt automatically

---

### Test 3: Dual Biome (2-way Merge)

```gdscript
var dual = DualBiome.new()
dual._ready()

print(dual.bath.emoji_list)
# Expected: 12 emojis (6 BioticFlux + 6 Market)

print("🌾" in dual.bath.emoji_list)  # BioticFlux emoji
# Expected: true

print("🐂" in dual.bath.emoji_list)  # Market emoji
# Expected: true

# Cross-ecosystem projection
var proj = dual.create_projection(Vector2i(0, 0), "🌾", "🐂")
print(proj != null)  # Should work
print(proj.theta)

# Measure
var outcome = proj.measure()
print(outcome)  # Should be either "🌾" or "🐂"

# Verify normalization
var total = 0.0
for emoji in dual.bath.emoji_list:
    total += dual.bath.get_probability(emoji)
print(total)  # Should be ~1.0
```

**Expected Results:**
- ✅ 12 emojis (no overlap between sets)
- ✅ Has emojis from both biomes
- ✅ Cross-ecosystem projection works
- ✅ Measurement works
- ✅ Bath normalized

---

### Test 4: Triple Biome (3-way Merge)

```gdscript
var triple = TripleBiome.new()
triple._ready()

print(triple.bath.emoji_list.size())
# Expected: 15 emojis (6+6+4-1, 🌾 shared)

print("🌾" in triple.bath.emoji_list)  # BioticFlux
# Expected: true

print("🐂" in triple.bath.emoji_list)  # Market
# Expected: true

print("🔥" in triple.bath.emoji_list)  # Kitchen
# Expected: true

# Test all three cross-projections
var p1 = triple.create_projection(Vector2i(0, 0), "🌾", "💰")  # BioticFlux ↔ Market
var p2 = triple.create_projection(Vector2i(1, 0), "🐂", "🔥")  # Market ↔ Kitchen
var p3 = triple.create_projection(Vector2i(2, 0), "🍞", "🍄")  # Kitchen ↔ BioticFlux

print(p1 != null && p2 != null && p3 != null)
# Expected: true (all work)

# Measure and verify collapse
var outcome = p1.measure()
print(outcome)  # "🌾" or "💰"

# Check bath collapsed
var wheat = triple.bath.get_population("🌾")
var money = triple.bath.get_population("💰")
print("🌾:", wheat, "💰:", money)
# One should be ~0

# Verify normalization
var total = 0.0
for emoji in triple.bath.emoji_list:
    total += triple.bath.get_probability(emoji)
print(total)  # Should be ~1.0
```

**Expected Results:**
- ✅ 15 emojis (accounts for overlap)
- ✅ Has emojis from all three biomes
- ✅ All cross-projections work
- ✅ Measurement works
- ✅ Bath normalized after measurement

---

## Visual Testing (With UI)

If you want to see the biomes in the force graph:

```gdscript
# In Farm.gd or test scene:

# Add test biomes to farm
var minimal = MinimalTestBiome.new()
var dual = DualBiome.new()
var triple = TripleBiome.new()

grid.register_biome("Minimal", minimal)
grid.register_biome("Dual", dual)
grid.register_biome("Triple", triple)

# Assign plots
grid.assign_plot_to_biome(Vector2i(0, 0), "Minimal")
grid.assign_plot_to_biome(Vector2i(1, 0), "Dual")
grid.assign_plot_to_biome(Vector2i(2, 0), "Triple")

# Plant and see them in force graph
```

---

## What Each Test Validates

### Minimal Biome Test

**Validates:**
- Hand-crafted emoji lists work
- Small ecosystems (3 emojis) function correctly
- Icon composition works with minimal sets
- Bath initialization is clean

### Hot Drop Test

**Validates:**
- Runtime emoji injection works
- Operators rebuild correctly
- Bath stays normalized after injection
- Hot-dropped emojis fully functional (can project, measure)

### Dual Biome Test

**Validates:**
- `merge_emoji_sets()` works
- 2-way merge produces correct union
- Cross-ecosystem projections work
- Icons from different biomes compose correctly
- No conflicts between disjoint emoji sets

### Triple Biome Test

**Validates:**
- Multi-way merge works (cascade merging)
- Overlap handling (🌾 shared between BioticFlux and Kitchen)
- Complex cross-projections work
- Three distinct ecosystems compose correctly
- Measurement works in highly merged systems

---

## Common Issues & Fixes

### Issue: IconRegistry not found in headless mode

**Solution:** Run tests in editor console or test scene, not headless.

### Issue: Bath not normalized

**Check:**
- Initial weights sum to ~1.0
- No arithmetic errors in weight assignment
- `bath.normalize()` called if needed

### Issue: Projection fails

**Check:**
- Both emojis exist in bath (`emoji in bath.emoji_list`)
- Icons exist in IconRegistry
- Bath initialized before creating projection

### Issue: Hot drop doesn't add emoji

**Check:**
- Emoji not already in bath
- Icon exists in IconRegistry
- IconRegistry accessible

---

## Implementation Files

| File | Purpose |
|------|---------|
| `Core/Environment/BiomeBase.gd` | Added merge + hot drop helpers |
| `Core/Environment/MinimalTestBiome.gd` | 3-emoji minimal test biome |
| `Core/Environment/DualBiome.gd` | 2-way merge (BioticFlux + Market) |
| `Core/Environment/TripleBiome.gd` | 3-way merge (BioticFlux + Market + Kitchen) |
| `Core/Environment/MergedEcosystem_Biome.gd` | Example merge (BioticFlux + Forest) |
| `Tests/test_biome_variations.gd` | Automated test (headless issues) |

---

## Next Steps

### Immediate

1. **Manual testing** in Godot editor (use scripts above)
2. **Visual testing** with force graph
3. **Verify** all test scenarios pass

### Short Term

1. **Add to Farm.gd** - Register test biomes for gameplay
2. **UI testing** - See merged biomes in QuantumForceGraph
3. **Save/load testing** - Verify merged biomes persist

### Long Term

1. **Dynamic merging** - Runtime biome fusion (game mechanic?)
2. **Event-driven hot drops** - Quests, seasons, achievements
3. **Procedural biomes** - Generate from emoji seed sets

---

## Summary

**Created:**
- ✅ 4 test biome variations
- ✅ Comprehensive test script
- ✅ Manual testing procedures

**Validates:**
- ✅ Hand-crafted biomes (minimal emoji sets)
- ✅ Hot drop emoji injection
- ✅ Dual biome merging (2-way)
- ✅ Triple biome merging (3-way)
- ✅ Cross-ecosystem projections
- ✅ Measurement in merged systems

**Status:** Ready for manual testing in Godot editor!

Use the manual test scripts above to verify each biome type works correctly.
