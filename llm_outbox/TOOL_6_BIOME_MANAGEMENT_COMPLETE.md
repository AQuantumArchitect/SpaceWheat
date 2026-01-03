# Tool 6: Biome Management - Implementation Complete

**Status:** ✅ Complete
**Date:** 2026-01-02

---

## Summary

Implemented Tool 6 as a **Biome Management** toolset that enables dynamic plot reassignment to different biomes at runtime. This unlocks experimental biome composition and strategic ecosystem building that was previously impossible (plots were locked to biomes at Farm._ready()).

## What Tool 6 Does

### Primary Features
1. **Q: Assign Biome ▸** - Opens dynamic submenu showing all registered biomes (BioticFlux, Market, Forest, Kitchen, plus any custom biomes)
2. **E: Clear Assignment** - Removes biome assignment from plots, returning them to unassigned state
3. **R: Inspect Plot** - Shows detailed metadata for selected plots (biome, quantum state, entanglement, bath projection)

### Use Cases
- Move plots between different biomes during gameplay
- Experiment with ecosystem composition strategies
- Test how different biomes affect quantum evolution
- Support custom biomes (MinimalTestBiome, DualBiome, TripleBiome, etc.)
- Inspect plot state for debugging and strategic planning

## Implementation Details

### Files Modified

#### 1. `/home/tehcr33d/ws/SpaceWheat/Core/GameState/ToolConfig.gd`

**Tool 6 Definition (Lines 44-50):**
```gdscript
6: {  # BIOME Tool - Ecosystem management
    "name": "Biome",
    "emoji": "🌍",
    "Q": {"action": "submenu_biome_assign", "label": "Assign Biome ▸", "emoji": "🔄", "submenu": "biome_assign"},
    "E": {"action": "clear_biome_assignment", "label": "Clear Assignment", "emoji": "❌"},
    "R": {"action": "inspect_plot", "label": "Inspect Plot", "emoji": "🔍"},
},
```

**Dynamic Submenu Definition (Lines 97-106):**
```gdscript
"biome_assign": {
    "name": "Assign to Biome",
    "emoji": "🔄",
    "parent_tool": 6,
    "dynamic": true,  # Generate from farm.grid.biomes registry
    # Fallback definitions...
},
```

**Dynamic Generator Method (Lines 210-260):**
- `_generate_biome_assign_submenu()` - Maps first 3 registered biomes to Q/E/R
- Handles edge cases (0 biomes, <3 biomes, >3 biomes)
- Gets biome emoji from `producible_emojis` for UI display

#### 2. `/home/tehcr33d/ws/SpaceWheat/UI/FarmInputHandler.gd`

**Action Routing (Lines 367-395):**
- Added cases for `assign_to_*` actions
- Added `clear_biome_assignment` routing
- Added `inspect_plot` routing
- Dynamic fallback for custom biome names

**Action Implementations (Lines 1431-1558):**

1. **`_action_assign_plots_to_biome()`** (Lines 1431-1467)
   - Reassigns plots to new biome
   - Preserves quantum states and entanglement
   - Logs old biome → new biome transition

2. **`_action_clear_biome_assignment()`** (Lines 1470-1490)
   - Removes biome assignment
   - Plots become unassigned (orphaned)
   - Future ops may fail until reassigned

3. **`_action_inspect_plot()`** (Lines 1493-1558)
   - Shows biome assignment
   - Shows quantum state (north, south, energy)
   - Shows entanglement links
   - Shows bath projection status

## Architecture Highlights

### Dynamic Submenu Pattern
Follows the same pattern as `energy_tap` dynamic submenu:
1. Mark submenu with `"dynamic": true`
2. Generate Q/E/R actions at runtime from `farm.grid.biomes.keys()`
3. Support any registered biomes (base biomes + custom biomes)

### Compositional Biome Support
Works seamlessly with the new compositional architecture:
- Base biomes: BioticFlux, Market, Forest, Kitchen
- Test biomes: MinimalTestBiome, DualBiome, TripleBiome
- Merged biomes: MergedEcosystem_Biome
- Any future biomes registered via `farm.grid.register_biome()`

### Safety & Persistence
When reassigning plots:
- ✅ Quantum states persist (DualEmojiQubit remains)
- ✅ Entanglement links persist (stored in old biome's bell_gates)
- ✅ Measured state remains
- ✅ Future operations (plant, harvest) use new biome's bath

## Usage Examples

### Example 1: Move Plot to Different Biome
```
Player Actions:
1. Press 6 (Tool 6: Biome)
2. Select plot with TYUIOP789.0
3. Press Q (Assign Biome ▸)
4. Press E (Market)

Result:
🌍 Reassigning 1 plot(s) to Market biome...
  • Plot (2, 0): BioticFlux → Market
✅ Reassigned 1 plot(s) to Market
```

Future planting on that plot will use Market biome's bath (with 🐂, 🐻, 💰 emojis).

### Example 2: Inspect Plot Details
```
Player Actions:
1. Press 6 (Tool 6: Biome)
2. Select plot with TYUIOP789.0
3. Press R (Inspect Plot)

Result:
🔍 PLOT INSPECTION
──────────────────────────────────────────────────────────────────────

📍 Plot (2, 0):
   🌍 Biome: BioticFlux
   🌱 Planted: YES
      Has been measured: NO
      ⚛️  State: 🌾 ↔ 👥 | Energy: 0.785
   🔗 Entangled: NO
   🛁 Bath Projection: Active
      North: 🌾 | South: 👥

──────────────────────────────────────────────────────────────────────
```

### Example 3: Clear Assignment
```
Player Actions:
1. Press 6 (Tool 6: Biome)
2. Select plot with TYUIOP789.0
3. Press E (Clear Assignment)

Result:
❌ Clearing biome assignment for 1 plot(s)...
  • Plot (2, 0): BioticFlux → (unassigned)
✅ Cleared 1 plot(s)
```

Plot is now orphaned - future operations will fail until reassigned.

## Testing Checklist

### Basic Functionality
- [x] Tool 6 appears in tool selection UI
- [x] Q submenu shows all registered biomes (BioticFlux, Market, Forest, Kitchen)
- [x] E clears biome assignment
- [x] R inspects plot with detailed metadata

### Dynamic Submenu
- [x] Submenu generates from `farm.grid.biomes.keys()`
- [x] Shows first 3 biomes as Q/E/R
- [x] Custom biomes (MinimalTestBiome, DualBiome) appear if registered
- [x] Handles <3 biomes (locks unused buttons)
- [x] Handles >3 biomes (shows first 3, pagination future enhancement)

### Plot Reassignment
- [x] Reassign empty plot - works
- [x] Reassign planted plot - quantum state persists
- [x] Reassign entangled plot - entanglement persists
- [x] Reassign measured plot - measured state remains
- [x] Future operations use new biome's bath

### Edge Cases
- [x] Reassign to same biome - no-op, harmless
- [x] Reassign to non-existent biome - error message
- [x] Clear assignment of planted plot - works, plot orphaned
- [x] Inspect unassigned plot - shows "(unassigned)"

## Data Flow

### Assign Plot to Biome
```
User: 6-Q-E (Tool 6 → Submenu → Market)
  ↓
FarmInputHandler._enter_submenu("biome_assign")
  ↓
ToolConfig.get_dynamic_submenu("biome_assign", farm)
  ↓
_generate_biome_assign_submenu() reads farm.grid.biomes.keys()
  → ["BioticFlux", "Market", "Forest", "Kitchen"]
  ↓
Generate Q/E/R: Q=BioticFlux, E=Market, R=Forest
  ↓
User presses E
  ↓
_execute_submenu_action("E") → "assign_to_Market"
  ↓
_action_assign_plots_to_biome([Vector2i(2,0)], "Market")
  ↓
farm.grid.assign_plot_to_biome(Vector2i(2,0), "Market")
  ↓
plot_biome_assignments[Vector2i(2,0)] = "Market"
  ↓
Future operations use Market biome's bath
```

## Future Enhancements

1. **Pagination for >3 Biomes**
   - Cycle through pages if >3 biomes registered
   - Use Tab/Shift+Tab or numbered pages

2. **Biome Parameter Controls**
   - E submenu to boost/reduce temperature
   - Control bath amplitude globally
   - Toggle decoherence rates

3. **Runtime Biome Creation**
   - Create DualBiome/TripleBiome at runtime
   - Select constituent biomes from submenu
   - Dynamic ecosystem composition

4. **Visual Biome Boundaries**
   - Toggle oval visibility per-biome
   - Show/hide biome labels
   - Adjust colors/sizes

5. **Batch Operations**
   - Select multiple plots at once
   - Reassign entire row/column to biome
   - Pattern-based assignment (checkerboard, stripes)

## Technical Notes

### Why Quantum States Persist
When a plot is reassigned:
- The `DualEmojiQubit` instance remains in memory
- The plot's `quantum_state` reference unchanged
- Only `plot_biome_assignments[pos]` is updated
- Future operations query the new biome for:
  - Bath reference (for projections)
  - Emoji pairings (for allowed plants)
  - Producible resources (for harvest)

### Why Entanglement Persists
- Bell gates stored in old biome's `bell_gates` array
- Array contains plot positions, not biome references
- Gates remain valid even if plots reassigned
- Measurement triggers still work (they use position lookup)

### Integration with Save/Load
The dynamic save/load system (completed earlier today) already supports this:
- `plot_biome_assignments` dictionary is saved
- Reassigned plots will restore to correct biomes
- Custom biomes (MinimalTestBiome, etc.) supported
- Works seamlessly with compositional architecture

## Summary

**Tool 6 is now complete and ready for gameplay!**

Players can:
- ✅ Dynamically reassign plots to any registered biome
- ✅ Experiment with ecosystem composition strategies
- ✅ Inspect detailed plot metadata
- ✅ Clear assignments and manage plot-biome relationships
- ✅ Work with custom biomes (test biomes, merged biomes)

This completes the compositional biome architecture's interactive layer - players now have full control over plot-biome relationships at runtime! 🌍🎉
