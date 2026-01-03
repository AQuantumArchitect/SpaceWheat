# Tool 6: Biome Management - Manual Testing Guide

**Status:** Implementation Complete, Ready for Manual Testing
**Date:** 2026-01-02

---

## Why Manual Testing?

Headless testing encounters IconRegistry initialization issues that prevent tests from completing. Tool 6's implementation is complete and compiles successfully - it just needs validation in the Godot editor with full scene tree access.

## Quick Start

1. Open SpaceWheat project in Godot editor
2. Run the main game scene
3. Press **6** to select Tool 6 (Biome)
4. Follow test scenarios below

---

## Test Scenario 1: View Dynamic Biome Submenu

**Goal:** Verify Tool 6's Q submenu shows all registered biomes

**Steps:**
1. Press **6** (Select Tool 6: Biome)
2. Press **Q** (Open "Assign Biome ▸" submenu)

**Expected Result:**
```
Submenu Title: "Assign to Biome 🔄"

Q: 🌾 BioticFlux (assign_to_BioticFlux)
E: 🏪 Market (assign_to_Market)
R: 🌲 Forest (assign_to_Forest)
```

**Notes:**
- Submenu should show first 3 registered biomes from `farm.grid.biomes`
- Emojis pulled from each biome's `producible_emojis[0]`
- If <3 biomes exist, unused buttons show "⬜ Empty"

**✅ Pass Criteria:**
- [ ] Submenu opens successfully
- [ ] Shows 3 biome options (or fewer if <3 registered)
- [ ] Each option has correct emoji and label

---

## Test Scenario 2: Reassign Plot to Different Biome

**Goal:** Verify plot reassignment changes biome while preserving quantum state

**Steps:**
1. Press **1** (Select Tool 1: Grower)
2. Press **T** (Select plot at position 0,0)
3. Press **Q** (Open Plant submenu)
4. Press **Q** (Plant Wheat)
5. Note the plot's original biome (check visualization or console)
6. Press **6** (Select Tool 6: Biome)
7. Press **T** (Ensure plot 0,0 still selected)
8. Press **Q** (Open Assign Biome submenu)
9. Press **E** (Assign to Market biome - or whichever is different from current)

**Expected Console Output:**
```
🌍 Reassigning 1 plot(s) to Market biome...
  • Plot (0, 0): BioticFlux → Market
✅ Reassigned 1 plot(s) to Market
```

**Expected Result:**
- Plot remains planted with wheat
- Quantum state preserved (north/south emojis unchanged)
- Future operations use Market biome's bath
- Biome oval visualization updates (if enabled)

**✅ Pass Criteria:**
- [ ] Reassignment completes without errors
- [ ] Console shows old biome → new biome transition
- [ ] Plot's planted state persists
- [ ] No quantum state errors

---

## Test Scenario 3: Inspect Plot Details

**Goal:** Verify inspection shows comprehensive plot metadata

**Steps:**
1. Select a planted plot (use **T/Y/U/I/O/P**)
2. Press **6** (Select Tool 6: Biome)
3. Press **R** (Inspect Plot)

**Expected Console Output:**
```
🔍 PLOT INSPECTION
──────────────────────────────────────────────────────────────────────

📍 Plot (0, 0):
   🌍 Biome: Market
   🌱 Planted: YES
      Has been measured: NO
      ⚛️  State: 🌾 ↔ 👥 | Energy: 0.785
   🔗 Entangled: NO
   🛁 Bath Projection: Active
      North: 🌾 | South: 👥

──────────────────────────────────────────────────────────────────────
```

**✅ Pass Criteria:**
- [ ] Inspection completes without errors
- [ ] Shows correct biome assignment
- [ ] Shows plant status (YES/NO)
- [ ] Shows quantum state (north, south, energy) if planted
- [ ] Shows entanglement status
- [ ] Shows bath projection details

---

## Test Scenario 4: Clear Biome Assignment

**Goal:** Verify clearing assignment orphans the plot

**Steps:**
1. Select a plot (any plot)
2. Press **6** (Select Tool 6: Biome)
3. Press **E** (Clear Assignment)

**Expected Console Output:**
```
❌ Clearing biome assignment for 1 plot(s)...
  • Plot (1, 0): BioticFlux → (unassigned)
✅ Cleared 1 plot(s)
```

**Expected Result:**
- Plot no longer has biome assignment
- Future operations (plant, measure) will fail until reassigned

**To Restore:**
1. Press **Q** (Open Assign Biome submenu)
2. Press **Q/E/R** (Select any biome to reassign)

**✅ Pass Criteria:**
- [ ] Clear completes without errors
- [ ] Console shows biome → (unassigned)
- [ ] Plot becomes orphaned (verify with R inspection)
- [ ] Can be reassigned successfully afterward

---

## Test Scenario 5: Reassign Planted Plot with Quantum State

**Goal:** Verify quantum states persist across biome changes

**Steps:**
1. Plant wheat on a plot in BioticFlux biome
2. Wait ~30 seconds for quantum energy to build
3. Press **6**, select plot, **Q**, **E** (Reassign to Market)
4. Press **R** (Inspect plot)
5. Note quantum energy value
6. Press **Q**, **Q** (Reassign back to BioticFlux)
7. Press **R** (Inspect again)
8. Compare energy values

**Expected Result:**
- Quantum energy should be identical before/after reassignment
- North/south emojis unchanged
- Planted status unchanged
- Only biome name changes

**✅ Pass Criteria:**
- [ ] Energy value unchanged after reassignment
- [ ] North/south emojis unchanged
- [ ] No "quantum state lost" errors
- [ ] Plot remains planted throughout

---

## Test Scenario 6: Reassign Entangled Plots

**Goal:** Verify entanglement persists across biome changes

**Steps:**
1. Plant wheat on two adjacent plots in BioticFlux biome
2. Use Tool 1 E (Entangle Bell φ+) to entangle them
3. Verify entanglement created (console message)
4. Press **6**, select one plot, **Q**, **E** (Reassign to Market)
5. Measure one plot (Tool 1 R)
6. Check if other plot collapses (entanglement still active)

**Expected Result:**
- Entanglement link persists even though plots are now in different biomes
- Measuring one plot still affects the other
- Bell gate stored in original biome's `bell_gates` array

**✅ Pass Criteria:**
- [ ] Can reassign entangled plot without breaking entanglement
- [ ] Measurement triggers still work
- [ ] No entanglement errors after reassignment

---

## Test Scenario 7: Multi-Plot Batch Assignment

**Goal:** Verify batch operations work correctly

**Steps:**
1. Press **T**, **Y**, **U** (Select plots 0, 1, 2)
2. Press **6** (Select Tool 6: Biome)
3. Press **Q**, **E** (Assign all 3 plots to Market)

**Expected Console Output:**
```
🌍 Reassigning 3 plot(s) to Market biome...
  • Plot (0, 0): BioticFlux → Market
  • Plot (1, 0): BioticFlux → Market
  • Plot (2, 0): BioticFlux → Market
✅ Reassigned 3 plot(s) to Market
```

**✅ Pass Criteria:**
- [ ] All 3 plots reassigned successfully
- [ ] Console shows each plot's transition
- [ ] No errors with batch operation

---

## Test Scenario 8: Inspect Empty Plot

**Goal:** Verify inspection handles unplanted plots gracefully

**Steps:**
1. Select an empty (unplanted) plot
2. Press **6**, **R** (Inspect)

**Expected Console Output:**
```
🔍 PLOT INSPECTION
──────────────────────────────────────────────────────────────────────

📍 Plot (3, 0):
   🌍 Biome: BioticFlux
   🌱 Planted: NO
   🔗 Entangled: NO

──────────────────────────────────────────────────────────────────────
```

**✅ Pass Criteria:**
- [ ] Shows "Planted: NO"
- [ ] Does not show quantum state (not applicable)
- [ ] No errors or crashes

---

## Edge Case Testing

### EC1: Reassign to Same Biome
**Steps:** Assign plot to its current biome
**Expected:** No-op, harmless, no error
**✅ Pass:** [ ]

### EC2: Reassign Non-Existent Biome
**Steps:** Try to assign to "FakeBiome" (use console command if needed)
**Expected:** Error message "Biome 'FakeBiome' not registered!"
**✅ Pass:** [ ]

### EC3: No Plots Selected
**Steps:** Press **[** (deselect all), then **6**, **Q**, **E**
**Expected:** Warning "No plots selected for biome assignment"
**✅ Pass:** [ ]

### EC4: >3 Biomes Registered
**Steps:** Register 4+ biomes, open submenu
**Expected:** Shows first 3, others require pagination (future feature)
**✅ Pass:** [ ]

---

## Integration Testing

### I1: Save/Load with Reassigned Plots
**Steps:**
1. Reassign some plots to different biomes
2. Save game
3. Load game
4. Inspect plots

**Expected:** Plot biome assignments restored correctly
**✅ Pass:** [ ]

### I2: Tool 6 + Tool 1 Workflow
**Steps:**
1. Use Tool 6 to reassign plot to Market
2. Use Tool 1 to plant wheat on that plot
3. Verify wheat uses Market biome's bath

**Expected:** Future operations use new biome
**✅ Pass:** [ ]

### I3: Tool 6 + Tool 4 Workflow
**Steps:**
1. Plant wheat in BioticFlux
2. Use Tool 4 to tap wheat energy
3. Reassign plot to Market (Tool 6)
4. Tap again

**Expected:** Tap uses Market biome's vocabulary after reassignment
**✅ Pass:** [ ]

---

## Performance Testing

### P1: Reassign All Plots
**Steps:** Select all 12 plots, reassign to Market
**Expected:** Completes in <1 second, no lag
**✅ Pass:** [ ]

### P2: Rapid Reassignment
**Steps:** Reassign same plot 10 times in quick succession
**Expected:** No memory leaks, no errors
**✅ Pass:** [ ]

---

## Summary Checklist

**Core Functionality:**
- [ ] Tool 6 appears in tool selection UI
- [ ] Q submenu shows all registered biomes
- [ ] E clears biome assignment
- [ ] R inspects plot with detailed metadata

**Quantum State Preservation:**
- [ ] Reassign planted plot - quantum state persists
- [ ] Reassign entangled plot - entanglement persists
- [ ] Reassign measured plot - measured state remains

**Edge Cases:**
- [ ] Reassign to same biome - no-op
- [ ] Reassign to non-existent biome - error message
- [ ] Clear assignment of planted plot - works, plot orphaned
- [ ] Inspect unassigned plot - shows "(unassigned)"

**Integration:**
- [ ] Save/load preserves reassignments
- [ ] Future operations use new biome's bath
- [ ] Batch operations work correctly

---

## Troubleshooting

**Issue:** Tool 6 doesn't appear in UI
**Fix:** Verify ToolConfig.gd lines 44-50 have Tool 6 definition

**Issue:** Submenu shows "No Biomes!"
**Fix:** Check Farm._ready() registers all biomes in grid

**Issue:** Reassignment fails silently
**Fix:** Check FarmInputHandler.gd has action routing for assign_to_*

**Issue:** Quantum state lost after reassignment
**Fix:** This is a bug - quantum states should persist. Check DualEmojiQubit references

---

## Success Criteria

Tool 6 is **fully functional** when:
- ✅ All 8 Test Scenarios pass
- ✅ All Edge Cases handled correctly
- ✅ All Integration tests pass
- ✅ No console errors during normal use
- ✅ Performance is acceptable (<1s for batch operations)

---

## Implementation Complete

**Files Modified:**
- `/home/tehcr33d/ws/SpaceWheat/Core/GameState/ToolConfig.gd` - Tool 6 definition + dynamic submenu
- `/home/tehcr33d/ws/SpaceWheat/UI/FarmInputHandler.gd` - Action handlers (assign, clear, inspect)

**Total Lines Added:** ~200 lines of code

**Ready for:** Manual testing in Godot editor → Production deployment

---

**Next Step:** Run through all test scenarios above in Godot editor to validate Tool 6 works as designed! 🎮
