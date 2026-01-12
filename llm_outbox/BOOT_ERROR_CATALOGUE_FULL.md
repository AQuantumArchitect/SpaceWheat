# Boot Error Catalogue - Complete Analysis
**Date:** 2026-01-11
**Test Duration:** 20 seconds (non-headless)
**Status:** 🔴 CRITICAL ERRORS FOUND

---

## Executive Summary

While the boot sequence **appears** to complete successfully ("BOOT SEQUENCE COMPLETE - GAME READY"), there are **critical script errors** that occur **every frame** after boot, making the game non-functional for gameplay.

**Critical Issues:** 1 (repeating every frame)
**Total Issues:** 4 categories

---

## CRITICAL ERRORS (Runtime - Every Frame)

### Error #1: `farm.has()` Method Calls on Node Object 🔴
**Severity:** CRITICAL - Breaks quantum HUD every frame
**Frequency:** Every frame (60 FPS = 60 errors/second)
**Impact:** Quantum HUD panels completely non-functional

**Error Message:**
```
SCRIPT ERROR: Invalid call. Nonexistent function 'has' in base 'Node (Farm)'.
          at: _get_active_biomes (res://UI/Panels/AttractorPersonalityPanel.gd:127)
```

**Affected Files (3):**

1. **UI/Panels/AttractorPersonalityPanel.gd**
   - Line 127: `if farm.has("biomes"):`
   - Line 134: `elif farm.has("biome") and farm.biome:`
   - Method: `_get_active_biomes()`
   - Called from: `_process()` every frame

2. **UI/Panels/QuantumEnergyMeter.gd**
   - Line 217: `if farm.has("biomes"):`
   - Line 225: `if farm.has("biome") and farm.biome:`
   - Method: `_get_biomes_from_farm()`
   - Called from: `_process()` or update methods

3. **UI/Panels/SemanticContextIndicator.gd**
   - Line 254: `if farm.has("biomes"):`
   - Line 261: `if farm.has("biome") and farm.biome:`
   - Method: Similar pattern
   - Called from: Update methods

**Root Cause:**
- `has()` is a **Dictionary method**, not a Node method
- Farm extends Node, so calling `farm.has("property")` is invalid
- This is the **same error type** we fixed earlier in PlayerShell.gd

**Why It's Critical:**
- Errors occur **every frame** (60+ times per second)
- Floods the console with error messages
- Quantum HUD panels can't update (AttractorPersonalityPanel shows phase space)
- Energy meter can't display quantum energy flows
- Semantic context indicator broken

**Correct Alternatives:**
```gdscript
# WRONG:
if farm.has("biomes"):

# RIGHT (Option 1 - Direct property access):
if "biomes" in farm:

# RIGHT (Option 2 - Safe get):
if farm.get("biomes"):

# RIGHT (Option 3 - Direct check for typed properties):
if farm.biomes:  # If property is typed and guaranteed to exist
```

---

## WARNINGS (Non-Breaking)

### Warning #1: Audio Driver Failure ⚠️
**Severity:** LOW - Expected in WSL/headless environments
**File:** N/A (system level)

**Messages:**
```
libpulse.so.0: cannot open shared object file: No such file or directory
ALSA lib confmisc.c:855:(parse_card) cannot find card '0'
ERROR: Condition "status < 0" is true. Returning: ERR_CANT_OPEN
WARNING: All audio drivers failed, falling back to the dummy driver.
```

**Impact:** None - audio won't work but game logic unaffected
**Expected:** Yes - WSL2 doesn't have sound hardware
**Action Required:** None

---

### Warning #2: V-Sync Not Supported ⚠️
**Severity:** LOW - Graphics driver limitation
**File:** N/A (OpenGL driver)

**Message:**
```
WARNING: Could not set V-Sync mode, as changing V-Sync mode is not supported by the graphics driver.
```

**Impact:** None - game runs without V-Sync
**Expected:** Common in virtualized/remote environments
**Action Required:** None

---

### Warning #3: Node Anchor Override ⚠️
**Severity:** LOW - Common Godot UI warning
**File:** UI/PlayerShell.gd:186

**Message:**
```
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
     at: _set_size (scene/gui/control.cpp:1476)
```

**Impact:** Minimal - UI may have unexpected sizing
**Frequency:** Once at boot
**Action Required:** Optional - adjust anchors or use set_deferred()

---

### Warning #4: PlotGridDisplay Null Config ⚠️
**Severity:** LOW - Handled gracefully
**File:** UI/PlotGridDisplay.gd:86

**Message:**
```
WARNING: [WARN][UI] ⚠️ PlotGridDisplay: grid_config is null - will be set later
```

**Impact:** None - config is set immediately after in boot sequence
**Frequency:** Once at boot
**Action Required:** None - this is intentional (dependency injection pattern)

---

## EXPECTED/INFORMATIONAL MESSAGES

These are **not errors**, just verbose logging:

### ⚠️ Skipped Operators (Expected)
**Count:** ~100+ messages during operator building
**Examples:**
```
⚠️ ☀→🔥 skipped (no coordinate)
⚠️ 🌾→🌱 skipped (no coordinate)
⚠️ Gated L 🌿→🌾 skipped (source 🌿 not in biome)
```

**Explanation:**
- Icons have couplings to emojis not present in specific biomes
- The builder correctly skips these
- This is **normal behavior** - not all icons couple to all other icons
- The warnings are informational, not errors

---

## BOOT SEQUENCE STATUS

### ✅ What Works:
- All 4 boot stages complete successfully
- IconRegistry loads (79 icons)
- All 4 biomes initialize (BioticFlux, Market, Forest, Kitchen)
- Quantum operators build and cache correctly
- QuantumForceGraph visualization initializes
- FarmUI mounts and connects
- Input system enables
- 12 plot tiles created with parametric layout

### 🔴 What's Broken:
- **AttractorPersonalityPanel** - Can't get biomes, shows no phase space data
- **QuantumEnergyMeter** - Can't get biomes, shows no energy flows
- **SemanticContextIndicator** - Can't get biomes, shows no semantic context
- Console floods with 60+ errors per second from these three panels

---

## IMPACT ANALYSIS

### User-Visible Issues:
1. **Quantum HUD completely broken** - No phase space visualization
2. **Energy meter blank** - Can't see quantum energy distribution
3. **Semantic indicators not working** - No octant information displayed
4. **Console spam** - Makes debugging other issues impossible

### Game Functionality:
- Core gameplay (planting, measuring, harvesting) likely still works
- Input system functional
- Plot grid should be interactive
- Biome quantum evolution running
- But **no feedback** from quantum HUD panels

---

## COMPARISON: Headless vs Non-Headless

### Headless Mode (--headless flag):
- ✅ Boot completes successfully
- ✅ No script errors visible
- ⚠️ Quantum HUD panels don't render (no display)
- ⚠️ Errors may be suppressed or not logged

### Non-Headless Mode (normal boot):
- ✅ Boot completes successfully
- 🔴 Script errors appear immediately after boot
- 🔴 Quantum HUD panels try to render but fail
- 🔴 Errors repeat every frame

**Why you were seeing different results:**
- Headless mode doesn't render UI panels
- Panels' `_process()` methods may not execute without rendering
- Errors only manifest when panels actually try to update

---

## FIX PRIORITY

### 🔴 Priority 1 (CRITICAL - Fix Immediately):
**UI Panels using `farm.has()`** - 3 files, 6 lines total

1. UI/Panels/AttractorPersonalityPanel.gd
   - Line 127: Change `if farm.has("biomes"):` → `if "biomes" in farm:`
   - Line 134: Change `elif farm.has("biome") and farm.biome:` → `elif "biome" in farm and farm.biome:`

2. UI/Panels/QuantumEnergyMeter.gd
   - Line 217: Change `if farm.has("biomes"):` → `if "biomes" in farm:`
   - Line 225: Change `if farm.has("biome") and farm.biome:` → `elif "biome" in farm and farm.biome:`

3. UI/Panels/SemanticContextIndicator.gd
   - Line 254: Change `if farm.has("biomes"):` → `if "biomes" in farm:`
   - Line 261: Change `if farm.has("biome") and farm.biome:` → `elif "biome" in farm and farm.biome:`

**Alternative Fix (Simpler):**
Since farm.biomes is a typed Dictionary property that always exists:
```gdscript
# Instead of checking if property exists, just check if dict is empty:
if farm.biomes and not farm.biomes.is_empty():
    # Multi-biome mode
    for biome_name in farm.biomes:
        # ...
elif farm.biome:  # Legacy fallback
    # Single biome mode
```

### ⚠️ Priority 2 (Optional - Improve Code Quality):
- Fix UI anchor warning (UI/PlayerShell.gd:186)
- Reduce operator builder verbosity (optional)

### ✅ Priority 3 (No Action Needed):
- Audio driver warnings (expected in WSL)
- V-Sync warning (driver limitation)
- PlotGridDisplay null config (intentional)

---

## ROOT CAUSE ANALYSIS

**Why This Happened:**

1. **Incomplete Refactoring:** When migrating from single-biome to multi-biome architecture:
   - Fixed FarmGrid checks (in previous session)
   - Fixed PlayerShell quantum HUD connection (in previous session)
   - **Missed** three UI panel files that also check for biomes

2. **Same Pattern, Different Locations:** All three files use identical code:
   ```gdscript
   if farm.has("biomes"):  # ← Wrong
       # Multi-biome logic
   elif farm.has("biome"):  # ← Wrong
       # Legacy single-biome logic
   ```

3. **Headless Testing Masked Issue:**
   - Headless mode doesn't render UI panels
   - Errors don't manifest without panel updates
   - Issue only visible when actually running with display

---

## VERIFICATION STEPS

After fixing, verify:

1. **Run non-headless for 20+ seconds:**
   ```bash
   timeout 20 godot -s 2>&1 | grep "SCRIPT ERROR"
   ```
   Should return **no results**

2. **Check console during gameplay:**
   - No spam of repeated errors
   - Quantum HUD panels update smoothly

3. **Visual verification:**
   - Open game with display
   - Check AttractorPersonalityPanel shows phase space
   - Check QuantumEnergyMeter shows energy values
   - Check SemanticContextIndicator shows octant data

---

## FILES REQUIRING CHANGES

### Critical (Must Fix):
1. `UI/Panels/AttractorPersonalityPanel.gd` (2 lines)
2. `UI/Panels/QuantumEnergyMeter.gd` (2 lines)
3. `UI/Panels/SemanticContextIndicator.gd` (2 lines)

**Total:** 3 files, 6 lines to change

---

## ESTIMATED FIX TIME

- **Code changes:** 2-3 minutes (simple find/replace)
- **Testing:** 5 minutes (run game, verify no errors)
- **Total:** ~10 minutes

---

## CONCLUSION

The boot sequence **technically completes**, but **critical runtime errors** make the quantum HUD system non-functional. This is a **simple fix** - identical to the PlayerShell fix we did earlier, just in three more locations.

The errors were **hidden in headless mode** because UI panels don't update without rendering, explaining why initial testing appeared clean.

**Next Action:** Fix the 6 lines using `farm.has()` in the three UI panel files.

---

**Investigated by:** Claude Code
**Date:** 2026-01-11
**Test Method:** 20-second non-headless boot
**Log Lines Analyzed:** 584
**Critical Errors Found:** 1 (repeating)
**Files Affected:** 3
