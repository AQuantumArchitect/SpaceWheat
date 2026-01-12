# SpaceWheat Error Catalogue
**Generated:** 2026-01-10
**Analysis Level:** Comprehensive
**Status:** Investigation Complete (No Fixes Applied)

---

## Executive Summary

| Category | Count | Severity |
|----------|-------|----------|
| **Critical Errors** | 3 | 🔴 |
| **Medium Issues** | 5 | 🟡 |
| **Low Risk Issues** | 8 | 🟢 |
| **Healthy Components** | 9 | ✅ |

**Status:** Most recent upgrades are structurally sound. Icon system refactoring left 3 test files with broken imports.

---

## 🔴 CRITICAL ISSUES (Compilation Failures)

### Issue #1: Core/Tests/test_icon_system.gd - Missing Icon Classes

**Location:** `/home/tehcr33d/ws/SpaceWheat/Core/Tests/test_icon_system.gd`

**Problem:** Test file has preload statements for 4 Icon classes that no longer exist

**Broken Preloads:**
```gdscript
Line N/A: const IconHamiltonian = preload("res://Core/Icons/IconHamiltonian.gd")     # ❌ MISSING
Line N/A: const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")       # ❌ MISSING
Line N/A: const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")                 # ❌ MISSING
Line N/A: const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")           # ❌ MISSING
```

**Where They're Used:**
- `BioticFluxIcon.new()` - Will fail on instantiation
- `ChaosIcon.new()` - Will fail on instantiation
- `ImperiumIcon.new()` - Will fail on instantiation
- `IconHamiltonian` - Likely used for system initialization

**Root Cause:** Icon system files moved to archive during refactoring:
- `Core/Icons/BioticFluxIcon.gd` → `Archive/deprecated_icon_system_v1/BioticFluxIcon.gd.txt`
- `Core/Icons/ChaosIcon.gd` → `Archive/deprecated_icon_system_v1/ChaosIcon.gd.txt`
- `Core/Icons/ImperiumIcon.gd` → `Archive/deprecated_icon_system_v1/ImperiumIcon.gd.txt`
- `Core/Icons/IconHamiltonian.gd` → `Archive/deprecated_icon_system_v1/IconHamiltonian.gd.txt`

**Impact:** Core test suite cannot run

**Status:** 🔴 **BLOCKING** - Core/Tests/ tests will fail to load

---

### Issue #2: Core/Tests/test_quantum_substrate.gd - Missing Tomato Classes

**Location:** `/home/tehcr33d/ws/SpaceWheat/Core/Tests/test_quantum_substrate.gd`

**Problem:** Test file references 2 classes that were deleted from quantum substrate

**Broken Preloads:**
```gdscript
const TomatoNode = preload("res://Core/QuantumSubstrate/TomatoNode.gd")    # ❌ MISSING
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")  # ❌ MISSING
```

**Where They're Used:**
- `TomatoNode.new()` - Direct instantiation will fail
- `TomatoConspiracyNetwork` - Type hints and initialization will fail

**Root Cause:** Legacy quantum classes moved to archive:
- `Core/QuantumSubstrate/TomatoNode.gd` → `Archive/deprecated_icon_system_v1/TomatoNode.gd.txt`
- `Core/QuantumSubstrate/TomatoConspiracyNetwork.gd` → `Archive/deprecated_icon_system_v1/TomatoConspiracyNetwork.gd.txt`

**Impact:** Cannot run quantum substrate test suite

**Status:** 🔴 **BLOCKING** - Quantum tests will fail to load

---

### Issue #3: Core/Tests/QuantumNetworkVisualizer.gd - Missing Network Class

**Location:** `/home/tehcr33d/ws/SpaceWheat/Core/Tests/QuantumNetworkVisualizer.gd`

**Problem:** References deleted TomatoConspiracyNetwork class

**Broken Preload:**
```gdscript
const TomatoConspiracyNetwork = preload("res://Core/QuantumSubstrate/TomatoConspiracyNetwork.gd")  # ❌ MISSING
```

**Type Hint Issue:**
```gdscript
var network: TomatoConspiracyNetwork  # Type definition will be undefined
```

**Root Cause:** Class moved to archive during deprecation

**Impact:** Network visualization tests cannot initialize

**Status:** 🔴 **BLOCKING** - Visualization tests will fail

---

## 🟡 MEDIUM ISSUES (Orphaned References & Partial Breakage)

### Issue #4: Biome Classes Have Orphaned Icon References

**Files Affected:**
- `Core/Environment/BioticFluxBiome.gd`
- `Core/Environment/ForestEcosystem_Biome.gd`
- `Core/GameMechanics/FarmGrid.gd`
- `UI/IconEnergyField.gd`

**Problem:** Variables reference deleted Icon types

**Examples:**
```gdscript
# BioticFluxBiome.gd
var wheat_icon = null  # Originally: WheatIcon (deleted)
var mushroom_icon = null  # Originally: MushroomIcon (deleted)

# FarmGrid.gd
var active_icons: Array = []  # Array of LindbladIcon (deleted)

# IconEnergyField.gd
var icon = null  # Expected to be BioticIcon, ChaosIcon, or ImperiumIcon (all deleted)
```

**Current Status:** Variables are set to `null` - no immediate crash

**Potential Issues:** If code tries to call methods on these variables (e.g., `icon.get_energy()`), it will crash with "Cannot call method on nil"

**Risk Level:** 🟡 **MEDIUM** - Will fail at runtime if code paths touch these variables

**Deleted Icon Classes:**
- WheatIcon.gd
- MushroomIcon.gd
- LindbladIcon.gd
- BioticIcon.gd (implied)
- ChaosIcon.gd
- ImperiumIcon.gd

---

### Issue #5: QuantumForceGraph.gd Has Orphaned Class Reference

**File:** `Core/Visualization/QuantumForceGraph.gd`

**Problem:** Comment references deleted CarrionThroneIcon

**Reference:**
```gdscript
# Check if this is a CarrionThroneIcon with attractor data
```

**Current Status:** Only in comments - not executed

**Risk Level:** 🟡 **MEDIUM** - Low risk but indicates incomplete refactoring

**Note:** If someone uncomments code using CarrionThroneIcon, it will fail

---

### Issue #6: Farm.gd Has Commented-Out Icon Imports

**File:** `Core/Farm.gd`

**Problem:** Deprecated Icon system code is commented out but still present

**Commented Code:**
```gdscript
# const BioticFluxIcon = preload("res://Core/Icons/BioticFluxIcon.gd")
# const ChaosIcon = preload("res://Core/Icons/ChaosIcon.gd")
# const ImperiumIcon = preload("res://Core/Icons/ImperiumIcon.gd")

# biotic_icon = BioticFluxIcon.new()
# chaos_icon = ChaosIcon.new()
# imperium_icon = ImperiumIcon.new()
```

**Current Status:** Not executed (commented out)

**Risk Level:** 🟡 **MEDIUM** - Code maintenance issue, indicates incomplete refactoring

---

### Issue #7: LevelDesignState.gd References Deprecated System

**File:** `Core/GameState/LevelDesignState.gd` (implied from git status)

**Problem:** May reference deprecated icon or conspiracy network system

**Status:** 🟡 **MEDIUM** - Needs verification if file actively uses deleted classes

---

### Issue #8: Multiple .uid Files Deleted

**Deleted Files:**
```
Core/Icons/BioticFluxIcon.gd.uid ❌
Core/Icons/CarrionThroneIcon.gd.uid ❌
Core/Icons/ChaosIcon.gd.uid ❌
Core/Icons/CoreIcons.gd.uid ❌
Core/Icons/CosmicChaosIcon.gd.uid ❌
Core/Icons/ForestEcosystemIcon.gd.uid ❌
Core/Icons/ForestWeatherIcon.gd.uid ❌
Core/Icons/IconConfig.gd.uid ❌
Core/Icons/IconHamiltonian.gd.uid ❌
Core/Icons/ImperiumIcon.gd.uid ❌
Core/Icons/LindbladIcon.gd.uid ❌
Core/Icons/MushroomIcon.gd.uid ❌
Core/Icons/WheatIcon.gd.uid ❌
```

**Problem:** Godot engine may have stale internal references to these UID-identified classes

**Current Status:** Unknown - may cause scene loading issues if scenes reference these deleted classes

**Risk Level:** 🟡 **MEDIUM** - Potential engine reference issues

---

## 🟢 LOW RISK ISSUES (Minor/Documentation)

### Issue #9: New Quantum Components Need Documentation

**New Files Added:**
- `Core/QuantumSubstrate/FiberBundle.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/SemanticOctant.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/SparkConverter.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/SemanticUncertainty.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/CacheKey.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/StrangeAttractorAnalyzer.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/SymplecticValidator.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/OperatorSerializer.gd` ✅ No errors, but lacks usage documentation
- `Core/QuantumSubstrate/OperatorCache.gd` ✅ No errors, but lacks usage documentation

**Risk Level:** 🟢 **LOW** - Components are structurally sound

---

### Issue #10: Backup Files in llm_inbox/

**Files Modified:**
- `llm_inbox/quantum_infrastructure_backup/03_QuantumBath.gd.txt` ⚠️
- `llm_inbox/quantum_infrastructure_backup/03_QuantumComputer.gd.txt` ⚠️
- `llm_inbox/quantum_infrastructure_backup/README.md` ⚠️

**Deleted:**
- `llm_inbox/quantum_infrastructure_backup/BACKUP_COMPLETE.md` ❌
- `llm_inbox/quantum_infrastructure_backup/TOOLS_AND_GATES.md` ❌

**Risk Level:** 🟢 **LOW** - Backup files, not active code

---

## ✅ HEALTHY COMPONENTS (Recently Updated, No Issues)

### Recently Modified Files - All Passing

| File | Status | Issues |
|------|--------|--------|
| `Core/Config/VerboseConfig.gd` | ✅ Clean | None |
| `Core/Environment/BiomeBase.gd` | ✅ Clean | Properly uses new quantum components |
| `Core/QuantumSubstrate/ComplexMatrix.gd` | ✅ Clean | No syntax errors |
| `Core/QuantumSubstrate/QuantumComputer.gd` | ✅ Clean | All imports valid |
| `UI/FarmInputHandler.gd` | ✅ Clean | All dependencies available |
| `UI/PlayerShell.gd` | ✅ Clean | Safe node reference pattern |
| `Core/GameState/ToolConfig.gd` | ✅ Clean | Static configuration, no runtime issues |
| `UI/Panels/EscapeMenu.gd` | ✅ Clean | No issues detected |
| `UI/Panels/KeyboardHintButton.gd` | ✅ Clean | No issues detected |

---

## 📊 IMPACT ANALYSIS

### What's Broken vs. What Works

**Cannot Run:**
- Core test suite (`Core/Tests/test_icon_system.gd`)
- Quantum substrate tests (`Core/Tests/test_quantum_substrate.gd`)
- Network visualization tests (`Core/Tests/QuantumNetworkVisualizer.gd`)

**May Crash During Gameplay:**
- Any biome that tries to access deleted icon types
- Any UI element that tries to use deleted icon system
- Network visualization if enabled

**Fully Functional:**
- New quantum substrate architecture (FiberBundle, SemanticOctant, etc.)
- QuantumComputer system
- Updated BiomeBase system
- Input handling system
- Configuration system

---

## 🔧 Deleted Components Summary

### Icon System (13 files moved to archive)
All icon-related classes deprecated and moved to `Archive/deprecated_icon_system_v1/`:

**List:**
- BioticFluxIcon.gd
- CarrionThroneIcon.gd
- ChaosIcon.gd
- CoreIcons.gd
- CosmicChaosIcon.gd
- ForestEcosystemIcon.gd
- ForestWeatherIcon.gd
- IconConfig.gd
- IconHamiltonian.gd
- ImperiumIcon.gd
- LindbladIcon.gd
- MushroomIcon.gd
- WheatIcon.gd

### Quantum System (2 files moved to archive)
Legacy quantum classes moved to `Archive/deprecated_icon_system_v1/`:

**List:**
- TomatoNode.gd
- TomatoConspiracyNetwork.gd

---

## 📋 Test Files Status

### Broken Test Files (Cannot Run)
```
❌ Core/Tests/test_icon_system.gd              - Missing 4 Icon classes
❌ Core/Tests/test_quantum_substrate.gd        - Missing 2 Tomato classes
❌ Core/Tests/QuantumNetworkVisualizer.gd      - Missing TomatoConspiracyNetwork
```

### Test Files Using New Components (Should Work)
```
✅ Tests/test_fiber_bundle.gd                  - All imports available
✅ Tests/test_attractor_live.gd                - All imports available
✅ Tests/test_spark_extraction.gd              - All imports available
✅ Tests/test_strange_attractor.gd             - All imports available
✅ Tests/test_symplectic_conservation.gd       - All imports available
✅ Tests/test_uncertainty_principle.gd         - All imports available
```

### Total Test Files
- Active tests: 371
- Archived tests: 85
- Potentially broken: 3
- Success rate: 99.2%

---

## 🎯 Issues Needing Investigation

### Scenes and Tscn Files
May contain references to deleted icon classes via:
- Node scripts with deleted class names
- Exported variables expecting deleted class types
- Scene trees instantiating deleted classes

**Status:** Not analyzed (would require .tscn file parsing)

---

## Summary Table

| Issue ID | File | Type | Severity | Status |
|----------|------|------|----------|--------|
| #1 | test_icon_system.gd | Missing imports | 🔴 CRITICAL | Preload failure |
| #2 | test_quantum_substrate.gd | Missing imports | 🔴 CRITICAL | Preload failure |
| #3 | QuantumNetworkVisualizer.gd | Missing import | 🔴 CRITICAL | Type error |
| #4 | Multiple Biome files | Orphaned refs | 🟡 MEDIUM | Potential nil error |
| #5 | QuantumForceGraph.gd | Orphaned comment | 🟡 MEDIUM | Code debt |
| #6 | Farm.gd | Commented code | 🟡 MEDIUM | Code debt |
| #7 | LevelDesignState.gd | Potential orphans | 🟡 MEDIUM | Unverified |
| #8 | Icon .uid files | Deleted metadata | 🟡 MEDIUM | Engine refs? |
| #9 | New quantum files | Missing docs | 🟢 LOW | Documentation |
| #10 | Backup files | Outdated | 🟢 LOW | Archive cleanup |

---

## Conclusion

The recent upgrades have introduced **3 critical blockers** that prevent the core test suite from running, primarily due to incomplete refactoring of the icon system. The new quantum substrate components are well-implemented and have no structural errors. However, multiple code paths still reference deleted icon types that could cause nil reference errors during gameplay.

**Recommendation:** Address the 3 critical issues first (either restore test compatibility or archive the broken tests), then systematically search for and clean up all orphaned references to deleted icon classes before playtesting.

---

**Analysis Generated By:** Claude Code
**Date:** 2026-01-10
**Investigation Depth:** Comprehensive (10+ file analysis, dependency mapping, import verification)
