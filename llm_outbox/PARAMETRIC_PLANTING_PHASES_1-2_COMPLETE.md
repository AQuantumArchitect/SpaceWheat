# Parametric Planting System - Phases 1-2 Complete
**Date:** 2026-01-12
**Status:** ✅ PHASES 1-2 IMPLEMENTED & TESTED

---

## Summary

Implemented the foundation for a fully parametric planting system where biomes define what can be planted instead of hard-coded plant types. Phases 1-2 add the infrastructure and dynamic tool menus.

---

## Phase 1: Foundation & Capability Registration ✅

### What Was Added

#### 1. PlantingCapability Class (BiomeBase.gd)
```gdscript
class PlantingCapability:
    var emoji_pair: Dictionary  # {"north": "🌾", "south": "👥"}
    var plant_type: String      # "wheat"
    var cost: Dictionary        # {"🌾": 1}
    var display_name: String    # "Wheat"
    var requires_biome: bool    # false
```

#### 2. Registration Methods (BiomeBase.gd)
- `register_planting_capability()` - Add plantable item to biome
- `get_plantable_capabilities()` - Query what can be planted
- `get_planting_cost()` - Get cost for specific plant type
- `supports_plant_type()` - Check if plant type is valid

### Biome Capabilities Registered

#### BioticFluxBiome (3 plants)
- **Wheat**: (🌾, 👥) - Cost: 1 🌾
- **Mushroom**: (🍄, 🍂) - Cost: 10 🍄 + 10 🍂
- **Tomato**: (🍅, 🌌) - Cost: 1 🌾

#### ForestEcosystem_Biome (3 plants - exclusive)
- **Vegetation**: (🌿, 🍂) - Cost: 10 🌿 - **Forest only**
- **Rabbit**: (🐇, 🍂) - Cost: 10 🐇 - **Forest only**
- **Wolf**: (🐺, 🍂) - Cost: 10 🐺 - **Forest only**

#### QuantumKitchen_Biome (3 plants)
- **Fire**: (🔥, ❄️) - Cost: 10 🔥 - **Kitchen only**
- **Water**: (💧, 🏜️) - Cost: 10 💧 - **Kitchen only**
- **Flour**: (💨, 🌾) - Cost: 10 💨

#### MarketBiome (2 plants)
- **Bread**: (🍞, 💨) - Cost: 10 🍞
- **Flour**: (💨, 🌾) - Cost: 10 💨

### Bug Fixed
**FarmPlot.gd:54** - Wheat south emoji was 🍄 (mushroom), now correctly 👥 (labor)

---

## Phase 2: Dynamic Tool Menus ✅

### What Was Changed

**File:** `Core/GameState/ToolConfig.gd`
**Function:** `_generate_plant_submenu()`

**Before (Hard-Coded):**
```gdscript
match biome_name:
    "Kitchen":
        generated["Q"] = {"action": "plant_fire", ...}
        generated["E"] = {"action": "plant_water", ...}
        generated["R"] = {"action": "plant_flour", ...}
    "Forest":
        generated["Q"] = {"action": "plant_vegetation", ...}
        # ... etc
```

**After (Parametric):**
```gdscript
var biome = farm.grid.get_biome_for_plot(current_selection)
var capabilities = biome.get_plantable_capabilities()

# Map first 3 capabilities to Q/E/R
for i in range(min(3, capabilities.size())):
    var cap = capabilities[i]
    generated[keys[i]] = {
        "action": "plant_" + cap.plant_type,
        "label": cap.display_name,
        "emoji": cap.emoji_pair.north
    }
```

### Features

1. **Queries biome dynamically** - No hard-coded plant lists
2. **Maps up to 3 items** to Q/E/R buttons
3. **Handles edge cases:**
   - No biome → Disabled menu ("No Biome")
   - Empty capabilities → Disabled menu ("Nothing Plantable")
   - Fewer than 3 items → Unused slots show "Empty"
4. **Biome-specific names** - "BioticFlux Plants", "Forest Plants", etc.

---

## Test Results

### Test Script: test_dynamic_menus.gd

**BioticFlux Biome:**
```
Menu name: BioticFlux Plants
Q: 🌾 [Wheat] → plant_wheat
E: 🍄 [Mushroom] → plant_mushroom
R: 🍅 [Tomato] → plant_tomato
✅ Actions follow parametric pattern (plant_<type>)
```

**ForestEcosystem Biome:**
```
Menu name: ForestEcosystem Plants
Q: 🌿 [Vegetation] → plant_vegetation
E: 🐇 [Rabbit] → plant_rabbit
R: 🐺 [Wolf] → plant_wolf
✅ Actions follow parametric pattern (plant_<type>)
```

**QuantumKitchen Biome:**
```
Menu name: QuantumKitchen Plants
Q: 🔥 [Fire] → plant_fire
E: 💧 [Water] → plant_water
R: 💨 [Flour] → plant_flour
✅ Actions follow parametric pattern (plant_<type>)
```

**Market Biome:**
```
Menu name: Market Plants
Q: 🍞 [Bread] → plant_bread
E: 💨 [Flour] → plant_flour
R: ⬜ [Empty] →
✅ Actions follow parametric pattern (plant_<type>)
```

---

## Files Modified

### Phase 1:
1. **Core/Environment/BiomeBase.gd** - Added PlantingCapability class and methods (~80 lines)
2. **Core/Environment/BioticFluxBiome.gd** - Registered 3 capabilities
3. **Core/Environment/ForestEcosystem_Biome.gd** - Registered 3 exclusive capabilities
4. **Core/Environment/QuantumKitchen_Biome.gd** - Registered 3 capabilities
5. **Core/Environment/MarketBiome.gd** - Registered 2 capabilities
6. **Core/GameMechanics/FarmPlot.gd** - Fixed wheat emoji pair (bug)

### Phase 2:
1. **Core/GameState/ToolConfig.gd** - Replaced `_generate_plant_submenu()` with parametric version (~70 lines)

### Test Files:
1. **Tests/test_dynamic_menus.gd** - Phase 2 verification script (NEW)

---

## System Status

### ✅ Working:
- All biomes register capabilities on boot
- Dynamic menus query biome capabilities
- Menu generation follows parametric pattern
- Game boots with no compilation errors

### 🔄 Still Using Legacy (Non-Breaking):
- BUILD_CONFIGS still exists (not used by new code)
- FarmInputHandler still uses hard-coded plant actions
- FarmGrid.plant() still uses plot_type_map
- PlotType enum still exists

### ⏳ Remaining Phases (3-6):
- **Phase 3**: Update FarmInputHandler planting actions
- **Phase 4**: Update FarmGrid.plant() parametric logic
- **Phase 5**: Deprecate PlotType enum
- **Phase 6**: Remove BUILD_CONFIGS

---

## Benefits So Far

### For Players:
- Menus adapt to biome context
- Forest-exclusive organisms won't show in BioticFlux
- Kitchen ingredients only appear in Kitchen

### For Developers:
- Add new plant type: Edit 1 biome file (not 5+ files)
- Biomes self-contained (capabilities + quantum system)
- Extensible for mods

### For Architecture:
- Biomes are source of truth for plantable items
- No duplication between ToolConfig and BUILD_CONFIGS
- Type-safe capability queries

---

## Next Steps

**Phase 3** (Next): Update FarmInputHandler to use biome capabilities for:
- Cost validation
- Planting actions
- Resource extraction

**Estimated Time**: 2-3 hours for Phases 3-4, then testing

---

**Implementation:** Claude Code
**Test Date:** 2026-01-12
**Status:** ✅ PHASES 1-2 COMPLETE, TESTED, READY FOR PHASE 3
