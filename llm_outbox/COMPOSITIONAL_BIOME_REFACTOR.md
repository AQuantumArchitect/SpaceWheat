# Compositional Biome Refactor - Implementation Plan

**Status:** Architecture is 95% there - Just needs emoji closure helpers

---

## Current State: Icons Already Compositional!

### Icons Own All Physics ✅

```gdscript
// Example: Wheat Icon (from CoreIcons.gd)
wheat.emoji = "🌾"
wheat.self_energy = 0.1                                    // Diagonal H
wheat.hamiltonian_couplings = {"☀": 0.5, "💧": 0.4}        // Off-diagonal H
wheat.lindblad_incoming = {"☀": 0.00267, "💧": 0.00167}   // Incoherent transfer IN
wheat.decay_rate = 0.001                                   // Self-decay
wheat.decay_target = "🍂"                                  // Where it decays to
wheat.energy_couplings = {"☀": +0.08, "💧": +0.05}        // Observable coupling
```

**Every emoji has ONE Icon that completely defines its quantum dynamics.**

### Bath Auto-Builds from Icons ✅

```gdscript
// QuantumBath.build_hamiltonian_from_icons(icons: Array)
// For each icon:
//   - H[i,i] = icon.self_energy(time)
//   - H[i,j] = icon.hamiltonian_couplings[emoji_j]
//   - (symmetrize)

// QuantumBath.build_lindblad_from_icons(icons: Array)
// For each icon:
//   - Add outgoing transfer terms
//   - Add incoming transfer terms
//   - Add decay term

// Result: H and L are pure composition of Icon operators!
```

### Dynamic Emoji Injection ✅

```gdscript
// BiomeBase.create_projection() (line 177)
if not bath.emoji_to_index.has(north_emoji):
    var icon = icon_registry.get_icon(north_emoji)
    bath.inject_emoji(north_emoji, icon, Complex.zero())
    // ✓ Full Icon physics injected into bath!
```

**This means cross-biome planting ALREADY works compositionally!**

---

## What's Missing: Emoji Closure Helpers

### Current Problem: Manual Enumeration

Every biome hardcodes its emoji list:

```gdscript
// BioticFluxBiome._initialize_bath()
func _initialize_bath() -> void:
    bath = QuantumBath.new()
    var emojis = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]  // ← HARDCODED
    bath.initialize_with_emojis(emojis)

    // Get icons and build operators
    var icons: Array[Icon] = []
    for emoji in emojis:
        var icon = icon_registry.get_icon(emoji)
        if icon:
            icons.append(icon)

    bath.build_hamiltonian_from_icons(icons)
    bath.build_lindblad_from_icons(icons)
```

**Problem:** Can't easily compose/merge emoji sets.

---

## Solution: Add Three Helpers

### Helper 1: Compute Emoji Closure

**What it does:** Given seed emojis, compute the transitive closure of all coupled emojis.

```gdscript
// BiomeBase (add this method)
static func compute_emoji_closure(seed_emojis: Array[String],
                                   icon_registry = null) -> Array[String]:
    """Compute transitive closure of emojis via Icon coupling graphs

    Example:
        Seeds: ["☀", "🌿"]

        ☀ icon couples to: ["🌾", "💧", "⛰"]
        🌿 icon couples to: ["💧", "⛰", "🐰"]
        🌾 icon couples to: ["☀", "💧"]
        💧 icon couples to: ["⛰"]
        🐰 icon couples to: ["🌿"]
        ⛰ icon couples to: []

        Closure: ["☀", "🌿", "🌾", "💧", "⛰", "🐰"]
    """
    if not icon_registry:
        icon_registry = Engine.get_singleton("IconRegistry")
        if not icon_registry:
            icon_registry = get_node_or_null("/root/IconRegistry")

    var visited: Dictionary = {}
    var to_visit: Array[String] = seed_emojis.duplicate()

    while not to_visit.is_empty():
        var emoji = to_visit.pop_front()

        if emoji in visited:
            continue

        visited[emoji] = true

        # Get icon for this emoji
        var icon = icon_registry.get_icon(emoji)
        if not icon:
            continue

        # Get all emojis this icon couples to
        var coupled = icon.get_coupled_emojis()  // Already exists!

        for coupled_emoji in coupled:
            if not coupled_emoji in visited:
                to_visit.append(coupled_emoji)

    return visited.keys()
```

**Usage:**

```gdscript
// BioticFluxBiome - instead of manual list:
func _initialize_bath() -> void:
    bath = QuantumBath.new()

    // Just provide seeds - closure auto-expands!
    var seed = ["☀", "🌿"]
    var emojis = BiomeBase.compute_emoji_closure(seed)
    // Result: All emojis transitively coupled to sun and vegetation

    bath.initialize_with_emojis(emojis)
    // ... rest stays same
```

---

### Helper 2: Merge Emoji Sets

**What it does:** Combine emoji lists from multiple biomes (union, dedup).

```gdscript
// BiomeBase (add this method)
static func merge_emoji_sets(set_a: Array[String],
                              set_b: Array[String]) -> Array[String]:
    """Merge two emoji sets (union with deduplication)

    Example:
        set_a = ["☀", "🌾", "🌿"]  // BioticFlux
        set_b = ["🌿", "🐺", "🐰"]  // Forest

        Result: ["☀", "🌾", "🌿", "🐺", "🐰"]  // Union
    """
    var merged: Dictionary = {}

    for emoji in set_a:
        merged[emoji] = true

    for emoji in set_b:
        merged[emoji] = true

    return merged.keys()
```

---

### Helper 3: Initialize Bath from Emoji Set

**What it does:** Refactor initialization to be data-driven.

```gdscript
// BiomeBase (add this method)
func initialize_bath_from_emojis(emojis: Array[String],
                                   initial_weights: Dictionary = {}) -> void:
    """Initialize bath with emoji set + auto-build operators from Icons

    This is the ONE method that does compositional initialization.
    """
    bath = QuantumBath.new()
    bath.initialize_with_emojis(emojis)

    # Apply initial weights (if provided)
    if not initial_weights.is_empty():
        bath.initialize_weighted(initial_weights)

    # Get Icons from IconRegistry
    var icon_registry = get_node_or_null("/root/IconRegistry")
    if not icon_registry:
        push_error("IconRegistry not found - bath will have no dynamics!")
        return

    var icons: Array[Icon] = []
    for emoji in emojis:
        var icon = icon_registry.get_icon(emoji)
        if icon:
            icons.append(icon)
        else:
            push_warning("No Icon found for emoji: %s" % emoji)

    # Build operators from Icon composition
    if not icons.is_empty():
        bath.active_icons = icons
        bath.build_hamiltonian_from_icons(icons)
        bath.build_lindblad_from_icons(icons)

    print("🛁 Bath initialized: %d emojis, %d icons" % [emojis.size(), icons.size()])
```

---

## New Biome Pattern

### Before (Manual):

```gdscript
# BioticFluxBiome._initialize_bath()
func _initialize_bath() -> void:
    bath = QuantumBath.new()
    var emojis = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]  # Hardcoded!
    bath.initialize_with_emojis(emojis)

    bath.initialize_weighted({
        "☀": 0.25,
        "🌙": 0.15,
        "🌾": 0.20,
        "🍄": 0.20,
        "💀": 0.10,
        "🍂": 0.10
    })

    # Icon lookup + operator building (boilerplate)
    var icon_registry = get_node("/root/IconRegistry")
    var icons: Array[Icon] = []
    for emoji in emojis:
        var icon = icon_registry.get_icon(emoji)
        if icon:
            icons.append(icon)

    bath.active_icons = icons
    bath.build_hamiltonian_from_icons(icons)
    bath.build_lindblad_from_icons(icons)
```

### After (Compositional):

```gdscript
# BioticFluxBiome._initialize_bath()
func _initialize_bath() -> void:
    # Option 1: Manual emoji list (same as before)
    var emojis = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]

    # Option 2: Emoji closure from seeds (auto-expand)
    # var emojis = BiomeBase.compute_emoji_closure(["☀", "🌿"])

    # ONE call does everything
    initialize_bath_from_emojis(emojis, {
        "☀": 0.25,
        "🌙": 0.15,
        "🌾": 0.20,
        "🍄": 0.20,
        "💀": 0.10,
        "🍂": 0.10
    })
```

**Cleaner, more composable, same result!**

---

## Merged Biome Example

### Create BioticFlux + Forest Merged Biome

```gdscript
# New file: Core/Environment/MergedEcosystem_Biome.gd
class_name MergedEcosystem_Biome
extends BiomeBase

func _init():
    biome_name = "MergedEcosystem"
    display_name = "BioticFlux + Forest"

func _initialize_bath() -> void:
    # Get emoji sets from constituent biomes
    var bioticflux_emojis = ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]
    var forest_emojis = ["🌲", "🐺", "🐰", "🦌", "🌿", "💧", "⛰", "🍂"]

    # Merge (union)
    var merged_emojis = BiomeBase.merge_emoji_sets(bioticflux_emojis, forest_emojis)
    # Result: All emojis from both (🍂 shared, no duplicate)

    # Initialize with merged set
    initialize_bath_from_emojis(merged_emojis, {
        # BioticFlux weights
        "☀": 0.15,
        "🌙": 0.10,
        "🌾": 0.15,
        "🍄": 0.15,

        # Forest weights
        "🌲": 0.10,
        "🐺": 0.05,
        "🐰": 0.10,
        "🦌": 0.05,

        # Shared
        "🍂": 0.10,
        "💧": 0.05
    })

    print("🌲🌾 Merged biome: %d emojis" % merged_emojis.size())
```

**Result:** One bath with ALL emojis from both biomes, composite Icon dynamics!

---

## Advanced: Emoji Closure from Seeds

```gdscript
# Example: "Sun-driven ecosystem"
func _initialize_bath() -> void:
    # Start with just sun
    var seed = ["☀"]

    # Compute closure (all emojis sun couples to, recursively)
    var emojis = BiomeBase.compute_emoji_closure(seed)

    # Result might be: ["☀", "🌾", "🌿", "💧", "⛰", "🐰", ...]
    # (Depends on Icon coupling graph)

    initialize_bath_from_emojis(emojis, {
        "☀": 1.0  # Start fully in sun state
    })
```

**Use case:** "What ecosystem emerges from this seed?"

---

## Implementation Checklist

### Phase 1: Add Helpers to BiomeBase ✅ Ready to implement

1. Add `compute_emoji_closure()` static method
2. Add `merge_emoji_sets()` static method
3. Add `initialize_bath_from_emojis()` instance method

### Phase 2: Refactor Existing Biomes (Optional - for cleanliness)

1. Update BioticFluxBiome to use `initialize_bath_from_emojis()`
2. Update MarketBiome
3. Update QuantumKitchen_Biome
4. Update ForestEcosystem_Biome (if desired)

### Phase 3: Create Merged Biome Example

1. Create MergedEcosystem_Biome.gd
2. Test with BioticFlux + Forest emoji union
3. Verify operators compose correctly

### Phase 4: Test Compositional Properties

1. Verify merged bath has correct Hamiltonian (sum of constituents)
2. Verify Lindblad terms (union of constituent terms)
3. Plant in merged biome, verify cross-ecosystem interactions
4. Save/load merged biome

---

## Icon Coupling Graph Analysis

### Example: BioticFlux Icon Relationships

```
☀ (Sun):
  - hamiltonian_couplings: {"🌾": 0.5, "🌿": 0.4, "💧": 0.3}
  - lindblad_outgoing: {}
  - lindblad_incoming: {}

🌾 (Wheat):
  - hamiltonian_couplings: {"☀": 0.5, "💧": 0.4, "⛰": 0.3}
  - lindblad_incoming: {"☀": 0.00267, "💧": 0.00167}
  - decay_target: "🍂"

🍄 (Mushroom):
  - hamiltonian_couplings: {"🍂": 0.6, "💧": 0.3}
  - lindblad_incoming: {"🍂": 0.005}
  - decay_target: "🍂"

🍂 (Organic Matter):
  - hamiltonian_couplings: {"⛰": 0.4}
  - lindblad_incoming: {"🌾": 0.001, "🍄": 0.002}
  - decay_target: "⛰"
```

**Closure from ["☀"]:**
1. Start: {☀}
2. ☀ couples to: 🌾, 🌿, 💧 → Add to set: {☀, 🌾, 🌿, 💧}
3. 🌾 couples to: ☀ (visited), 💧 (visited), ⛰ → Add: {☀, 🌾, 🌿, 💧, ⛰}
4. 🌿 couples to: ... (expand)
5. 💧 couples to: ⛰ (visited)
6. ⛰ couples to: nothing
7. Fixed point reached!

**Result:** Ecosystem of all emojis reachable from sun through coupling graph.

---

## Validation: Does It Match Your Vision?

### ✅ "Icons define the physics"
- Each emoji's Icon has Hamiltonian + Lindblad → **YES, already implemented**

### ✅ "Bath constructed as composite of Icons"
- Bath.build_hamiltonian/lindblad_from_icons() → **YES, already implemented**

### ✅ "Biome is just an emoji list"
- Biome just calls initialize_bath_from_emojis(list) → **YES, new helper enables this**

### ✅ "Merged biome = union of emoji sets"
- merge_emoji_sets() + initialize_bath_from_emojis() → **YES, new helpers enable this**

### ✅ "BioticFlux + Forest = merged"
```gdscript
var merged = merge_emoji_sets(bioticflux_emojis, forest_emojis)
initialize_bath_from_emojis(merged, combined_weights)
```
**YES, this pattern achieves your vision!**

---

## Benefits of This Refactor

### 1. Emoji Discovery
- Add new emoji to IconRegistry
- Biome automatically picks it up (if coupled)
- No biome code changes needed

### 2. Ecosystem Composition
- Define biomes by emoji seeds
- Closure auto-expands to full ecosystem
- Emergent complexity from Icon graph

### 3. Easy Merging
- Combine any two biomes: `merge_emoji_sets(a, b)`
- Bath operators automatically compose
- No manual operator arithmetic

### 4. Data-Driven Design
- Biomes become data (emoji lists)
- Icons are the physics engine
- Swap out icons = swap out physics

### 5. Save/Load Simplicity
- Save: emoji list + weights
- Load: initialize_bath_from_emojis(saved_list, saved_weights)
- Icons provide operators (no need to serialize H/L matrices)

---

## Next Steps

Ready to implement? Here's what I'll do:

1. **Add the three helpers to BiomeBase.gd**
   - `compute_emoji_closure()`
   - `merge_emoji_sets()`
   - `initialize_bath_from_emojis()`

2. **Create example merged biome**
   - MergedEcosystem_Biome.gd
   - Demonstrates BioticFlux + Forest

3. **Test compositional properties**
   - Verify operators compose correctly
   - Test cross-ecosystem interactions

4. **(Optional) Refactor existing biomes**
   - Update to use new helpers
   - Cleaner, more maintainable code

Should I proceed with implementation?
