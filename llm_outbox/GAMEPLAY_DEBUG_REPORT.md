# Gameplay Debug Report - Script Errors Investigation

**Date:** 2026-01-02
**Status:** 🔍 Investigation Complete - Issues Identified

---

## Summary

Found **2 critical error types** occurring during gameplay when tools are used and biomes evolve quantum states:

1. **UI Parse Error** (Fixed ✅)
2. **Quantum Evolution Nil Object Errors** (Identified, needs investigation)

---

## Error #1: UI Parse Error ✅ FIXED

**Error Message:**
```
SCRIPT ERROR: Parse Error: Could not preload resource script "res://UI/FarmInputHandler.gd".
```

**Root Cause:**
Line 1664 in `FarmInputHandler.gd` used `class_name` as a variable name, which is a reserved keyword in GDScript 4.x.

**Fix Applied:**
Changed `var class_name = current.get_class()` to `var node_class = current.get_class()` at line 1664.

**Status:** ✅ **RESOLVED** - File now parses correctly.

---

## Error #2: Quantum Evolution Nil Object Errors

**Error Messages (Repeating ~50+ times during gameplay):**
```
SCRIPT ERROR: Invalid call. Nonexistent function 'update' in base 'Nil'.
          at: evolve (res://Core/QuantumSubstrate/QuantumEvolver.gd:76)

SCRIPT ERROR: Invalid call. Nonexistent function 'get_matrix' in base 'Nil'.
          at: evolve_in_place (res://Core/QuantumSubstrate/QuantumEvolver.gd:101)
```

**Call Stack:**
```
[0] QuantumEvolver.evolve() @ line 76          ← Calls hamiltonian.update()
[1] QuantumEvolver.evolve_in_place() @ line 100-101  ← Calls evolve() and evolved.get_matrix()
[2] QuantumBath.evolve() @ line 381
[3] BiomeBase.advance_simulation() @ line 86
[4] BiomeBase._process() @ line 77 (called every frame)
```

### Root Cause Analysis

**Line 76 in QuantumEvolver.gd:**
```gdscript
func evolve(rho, dt: float):
    hamiltonian.update(_time)  # ← ERROR: hamiltonian is Nil!
```

**Line 101 in QuantumEvolver.gd:**
```gdscript
func evolve_in_place(rho, dt: float) -> void:
    var evolved = evolve(rho, dt)
    rho.set_matrix(evolved.get_matrix())  # ← ERROR: evolved is Nil when evolve() fails
```

### Why hamiltonian is Nil

**QuantumEvolver initialization chain:**

1. `QuantumBath._init()` (line 103):
   ```gdscript
   _evolver = load("res://Core/QuantumSubstrate/QuantumEvolver.gd").new()
   # At this point: _evolver.hamiltonian is Nil!
   ```

2. `QuantumBath.build_lindblad_from_icons()` (line 354):
   ```gdscript
   _evolver.initialize(_hamiltonian, _lindblad)  # ← Sets hamiltonian member
   ```

**The Problem:**
If `evolve()` is called BEFORE `build_lindblad_from_icons()` is called, the evolver's `hamiltonian` member is still Nil.

### When This Can Happen

Possible scenarios where `evolve()` could be called before `build_lindblad_from_icons()`:

1. **BiomeBase._process() called before _initialize_bath() completes** (frame timing issue)
2. **Bath created without proper initialization** (in test scripts)
3. **Manually calling evolve() on an uninitialized bath**

---

## Current Observation

**Automated Test Results:**
- Running `claude_plays_simple.gd` triggers the errors within the first frame
- Biome initialization appears correct in source code
- Error timing suggests a frame-ordering issue

---

## Investigation Findings

### What Works ✅

1. **Isolated Bath Test:**
   ```
   Creating QuantumBath instance ✓
   Initializing with emojis ✓
   Building Hamiltonian ✓
   Building Lindblad ✓
   Attempting evolution ✓
   === SUCCESS ===
   ```

2. **Biome Initialization Code:**
   - `BioticFluxBiome._initialize_bath()` properly calls:
     - `bath.initialize_with_emojis()`
     - `bath.initialize_weighted()`
     - `bath.build_hamiltonian_from_icons()`
     - `bath.build_lindblad_from_icons()` ← Initializes the evolver!

3. **UI Script Parsing:**
   - After fixing the `class_name` keyword issue, all UI scripts load correctly

### What Doesn't Work ❌

1. **Automated Gameplay:**
   - Errors occur when running full game with automated player
   - Repeating Nil errors on every frame
   - Suggests systematic initialization issue in game context

---

## Recommended Next Steps

### 1. **Add Null Safety Checks (Quick Fix)**

Add guard clauses in `QuantumEvolver.evolve()` to handle Nil hamiltonian:

```gdscript
func evolve(rho, dt: float):
    if not hamiltonian or not lindblad:
        push_error("QuantumEvolver: Not properly initialized! Call initialize(H, L) first.")
        return rho.duplicate_density()

    # Update time-dependent Hamiltonian
    hamiltonian.update(_time)
    # ... rest of method
```

### 2. **Add Verbose Logging**

Add debug output to track evolver initialization:

```gdscript
# In QuantumEvolver.initialize()
func initialize(H: Hamiltonian, L: LindbladSuperoperator) -> void:
    print("QuantumEvolver.initialize() called")
    print("  H: %s" % str(H))
    print("  L: %s" % str(L))
    hamiltonian = H
    lindblad = L
```

### 3. **Ensure Synchronous Initialization**

Verify that `build_lindblad_from_icons()` is **always** called before `_process()` runs:

```gdscript
# In BiomeBase._process()
func _process(dt: float) -> void:
    if not bath:
        push_error("Bath not initialized!")
        return

    if not bath._evolver.hamiltonian:  # Check if evolver is initialized
        push_warning("Bath evolver not initialized - skipping evolution")
        return

    advance_simulation(dt)
```

### 4. **Investigate Test Script Behavior**

The errors only happen in automated tests, not in isolated tests. This suggests:
- Test scripts might be creating multiple biome instances
- Timing of bath initialization vs first frame might be different
- Need to trace exact sequence of calls in `claude_plays_simple.gd`

---

## Files Affected

| File | Issue | Status |
|------|-------|--------|
| `UI/FarmInputHandler.gd` | Parse error (reserved keyword) | ✅ Fixed |
| `Core/QuantumSubstrate/QuantumEvolver.gd` | Nil hamiltonian errors | 🔍 Investigate |
| `Core/QuantumSubstrate/QuantumBath.gd` | Evolver not guaranteed initialized | 🔍 Review |
| `Core/Environment/BiomeBase.gd` | Process called before init? | 🔍 Review |

---

## Test Results

### UI Parse Error Test
```
Load FarmInputHandler...   ✅
Load FarmUI...             ✅
Load ToolConfig...         ✅
All UI scripts loaded      ✅
```

### QuantumBath Isolation Test
```
Create instance...         ✅
Initialize with emojis...  ✅
Build Hamiltonian...       ✅
Build Lindblad...          ✅
Evolution step...          ✅
Success                    ✅
```

### Automated Gameplay Test
```
Start game...              ✅
Biome creation...          ✅
Frame 1 _process...        ❌ (Nil errors)
```

---

## Conclusion

**Short Term (Next Session):**
1. Add null safety checks to QuantumEvolver
2. Add verbose logging to track initialization
3. Test with guard clauses

**Long Term:**
1. Refactor QuantumBath initialization to be more defensive
2. Consider using lazy initialization pattern
3. Add unit tests for bath evolution without scene tree

