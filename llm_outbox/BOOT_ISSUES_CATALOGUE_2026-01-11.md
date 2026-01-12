# Boot Issues Catalogue - 2026-01-11
**Status:** 🔴 CRITICAL COMPILATION ERRORS BLOCKING GAME

---

## 🔴 CRITICAL - Game-Breaking Issues

### Issue #1: QuantumKitchen_Biome.gd - Missing `verbose` Parameter
**Severity:** 🔴 CRITICAL (Blocks compilation)
**File:** `Core/Environment/QuantumKitchen_Biome.gd`
**Lines:** 194, 195, 226, 229, 234, 235

**Error:**
```
SCRIPT ERROR: Parse Error: Identifier "verbose" not declared in the current scope.
          at: GDScript::reload (res://Core/Environment/QuantumKitchen_Biome.gd:194)
```

**Root Cause:**
Function `rebuild_quantum_operators()` at line 185 does not have a `verbose` parameter, but the function body tries to use `verbose` at lines 194, 195, 226, 229, 234, 235.

**Impact:**
- QuantumKitchen_Biome.gd fails to compile
- **Cascading failures:**
  - FarmGrid.gd fails to compile (depends on Kitchen)
  - Farm.gd fails to compile (depends on FarmGrid)
  - FarmView.gd fails to compile (depends on Farm)
- Farm.gd:216 error: `QuantumKitchen_Biome.new()` fails because class is not compiled

**Fix Required:**
```gdscript
# BEFORE (line 185):
func rebuild_quantum_operators() -> void:

# AFTER:
func rebuild_quantum_operators(verbose = null) -> void:
```

**Call Sites to Check:**
- BootManager.gd (Stage 3A) - needs to pass verbose logger
- Any other places calling `rebuild_quantum_operators()`

---

### Issue #2: Farm.grid is Null
**Severity:** 🔴 CRITICAL (Runtime failure)
**File:** `Core/Boot/BootManager.gd:58`

**Error:**
```
SCRIPT ERROR: Assertion failed: Farm.grid is null!
          at: _stage_core_systems (res://Core/Boot/BootManager.gd:58)
```

**Root Cause:**
Farm initialization is incomplete due to QuantumKitchen_Biome compilation failure. The Farm._ready() crashes at line 216 when trying to instantiate Kitchen biome, so Farm.grid never gets created.

**Impact:**
- Boot sequence fails at Stage 3A
- Farm is in broken state
- All farm-dependent systems fail

**Fix Required:**
This will be automatically fixed once Issue #1 is resolved.

---

### Issue #3: BathQuantumViz - No Biomes Registered
**Severity:** 🔴 CRITICAL (Runtime failure)
**File:** `Core/Visualization/BathQuantumVisualizationController.gd:90`

**Error:**
```
ERROR: BathQuantumViz: No biomes registered before initialize()
   at: push_error (core/variant/variant_utility.cpp:1024)
```

**Root Cause:**
Farm initialization incomplete (due to Issue #1), so biomes are never registered with the visualization system.

**Impact:**
- Quantum visualization system fails to initialize
- QuantumForceGraph not created

**Fix Required:**
This will be automatically fixed once Issue #1 is resolved.

---

### Issue #4: QuantumForceGraph Not Created
**Severity:** 🔴 CRITICAL (Runtime failure)
**File:** `Core/Boot/BootManager.gd:128`

**Error:**
```
SCRIPT ERROR: Assertion failed: QuantumForceGraph not created!
          at: _stage_visualization (res://Core/Boot/BootManager.gd:128)
```

**Root Cause:**
Consequence of Issue #3 - BathQuantumViz fails, so QuantumForceGraph is never created.

**Impact:**
- Visualization system incomplete
- Boot sequence assertion fails

**Fix Required:**
This will be automatically fixed once Issue #1 is resolved.

---

### Issue #5: layout_calculator is Null
**Severity:** 🔴 CRITICAL (Runtime error)
**File:** `Core/Boot/BootManager.gd:167`

**Error:**
```
SCRIPT ERROR: Invalid access to property or key 'layout_calculator' on a base object of type 'Nil'.
          at: _stage_ui (res://Core/Boot/BootManager.gd:167)
```

**Root Cause:**
Some object expected to have a `layout_calculator` property is null. Likely related to cascading failures from Farm initialization issues.

**Impact:**
- Stage 3C (UI Initialization) fails
- UI system may be in broken state

**Fix Required:**
Need to investigate BootManager.gd:167 to see what object is expected and why it's null. Likely auto-fixes once Issue #1 is resolved, but should verify.

---

## ⚠️ WARNINGS - Non-Critical but Should Be Addressed

### Warning #1: PlotGridDisplay - grid_config is Null
**Severity:** ⚠️ WARNING
**File:** `UI/PlotGridDisplay.gd:86`

**Output:**
```
WARNING: [WARN][UI] ⚠️ PlotGridDisplay: grid_config is null - will be set later
```

**Analysis:**
This appears to be **expected behavior** based on the warning message. The grid_config is set later during the boot sequence. However, should verify this is intentional.

**Impact:** Minimal - appears to be handled gracefully.

---

### Warning #2: Control Node Anchor Size Override
**Severity:** ⚠️ WARNING
**File:** `scene/gui/control.cpp:1476` (triggered from `UI/PlayerShell.gd:186`)

**Output:**
```
WARNING: Nodes with non-equal opposite anchors will have their size overridden after _ready().
If you want to set size, change the anchors or consider using set_deferred().
```

**Analysis:**
UI layout warning - a Control node in PlayerShell has conflicting anchor settings. Not game-breaking but indicates potential UI sizing issues.

**Impact:** Minimal - UI may have minor sizing inconsistencies.

---

## 🟡 HARDWARE/PLATFORM WARNINGS - Not Code Issues

### Platform Warning #1: V-Sync Not Supported
**Severity:** 🟡 INFO (WSL2 limitation)

**Output:**
```
WARNING: Could not set V-Sync mode, as changing V-Sync mode is not supported by the graphics driver.
     at: set_use_vsync (platform/linuxbsd/x11/gl_manager_x11.cpp:364)
```

**Analysis:** WSL2 graphics limitation. Not a code issue.

---

### Platform Warning #2: Audio Drivers Failed
**Severity:** 🟡 INFO (WSL2 limitation)

**Output:**
```
libpulse.so.0: cannot open shared object file: No such file or directory
ALSA lib confmisc.c:855:(parse_card) cannot find card '0'
ERROR: Condition "status < 0" is true. Returning: ERR_CANT_OPEN
   at: init_output_device (drivers/alsa/audio_driver_alsa.cpp:90)
WARNING: All audio drivers failed, falling back to the dummy driver.
     at: initialize (servers/audio_server.cpp:244)
```

**Analysis:** WSL2 audio limitation. Game falls back to dummy audio driver successfully. Not a code issue.

---

## 📊 BOOT SEQUENCE STATUS

### Successful Systems ✅
- File logging initialized
- BootManager ready
- IconRegistry: 78 icons from 27 factions loaded
- GameStateManager ready
- QuantumRigorConfig initialized
- VocabularyEvolution initialized
- FarmView started
- PlayerShell initialized
- UI systems created (overlays, panels, menus)
- **BioticFluxBiome:** Loaded successfully from cache [USER CACHE]
- **MarketBiome:** Loaded successfully from cache [USER CACHE]
- **ForestEcosystem_Biome:** Loaded successfully from cache [USER CACHE]

### Failed Systems 🔴
- **QuantumKitchen_Biome:** Failed to compile (missing `verbose` parameter)
- **Farm:** Failed to initialize (Kitchen instantiation failed)
- **Farm.grid:** Null (Farm init incomplete)
- **BathQuantumViz:** Failed (no biomes registered)
- **QuantumForceGraph:** Not created (visualization system failed)
- **layout_calculator:** Null (unknown object reference failed)

---

## 🎯 PRIORITY FIX ORDER

### Priority 1: Fix QuantumKitchen_Biome.gd
**Action:** Add `verbose = null` parameter to `rebuild_quantum_operators()` function signature.

**Expected Cascading Fixes:**
- Issue #2: Farm.grid will initialize
- Issue #3: BathQuantumViz will get biomes
- Issue #4: QuantumForceGraph will be created
- Issue #5: layout_calculator should exist (verify)

### Priority 2: Verify layout_calculator Fix
**Action:** After fixing Priority 1, boot game again and verify Issue #5 is resolved. If not, investigate BootManager.gd:167 specifically.

### Priority 3: Address Warnings (Optional)
- Review PlayerShell.gd:186 anchor settings
- Consider if PlotGridDisplay warning is acceptable

---

## 📋 TESTING CHECKLIST

After fixes:
- [ ] QuantumKitchen_Biome.gd compiles without errors
- [ ] Farm.gd compiles without errors
- [ ] FarmGrid.gd compiles without errors
- [ ] FarmView.gd compiles without errors
- [ ] Farm._ready() completes successfully
- [ ] Farm.grid is not null
- [ ] BathQuantumViz initializes with all 4 biomes
- [ ] QuantumForceGraph is created
- [ ] Boot sequence completes without assertions
- [ ] Game runs without critical errors
- [ ] All 4 biomes (BioticFlux, Market, Forest, Kitchen) are functional

---

## 🔍 SUSPICIOUS PATTERNS (For Investigation)

1. **Cache Success Pattern:** BioticFlux, Market, and Forest all loaded from [USER CACHE] successfully, but Kitchen failed before reaching cache stage. This confirms Issue #1 is the root cause.

2. **Compilation Cascade:** Single missing parameter in QuantumKitchen_Biome.gd caused 4+ files to fail compilation. Should consider adding compilation tests to CI.

3. **Boot Sequence Fragility:** Boot sequence has multiple assertion failures. Consider more graceful error handling for export builds (assertions disabled in release).

---

## 📝 NOTES

**Cache System Status:** ✅ WORKING CORRECTLY
- BioticFlux: Cache HIT [USER CACHE]
- Market: Cache HIT [USER CACHE]
- Forest: Cache HIT [USER CACHE]
- Kitchen: Not tested (compilation failed first)

**Hybrid Cache System:** Working as designed. All 3 tested biomes loaded instantly from user cache.

**Operator Builder Verbosity:** Not tested yet (Kitchen failed before operators could be built from scratch).

---

**Generated:** 2026-01-11
**Test Build:** Non-headless boot with --quit-after 5
**Log File:** /tmp/spacewheat_boot_log.txt
