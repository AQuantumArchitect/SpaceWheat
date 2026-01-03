# CRITICAL BUG: Missing class_name Declarations in Quantum Substrate

**Status**: BLOCKING COMPILATION
**Date Found**: 2026-01-02
**Severity**: CRITICAL
**Scope**: Phase 1 & 2 Testing

---

## Executive Summary

Multiple core quantum substrate classes have been refactored to remove their `class_name` declarations, but the code still tries to instantiate and reference them by type name. This causes cascading parse errors that prevent the entire codebase from compiling.

**Affected Classes**:
- `ComplexMatrix`
- `DensityMatrix`
- `Hamiltonian`
- `LindbladSuperoperator` (possibly)
- `QuantumEvolver` (possibly)

---

## Error Symptoms

```
SCRIPT ERROR: Parse Error: Could not find type "ComplexMatrix" in the current scope.
   at: GDScript::reload (res://Core/QuantumSubstrate/DualEmojiQubit.gd:100)

SCRIPT ERROR: Parse Error: Identifier "ComplexMatrix" not declared in the current scope.
   at: GDScript::reload (res://Core/QuantumSubstrate/QuantumBath.gd:210)

SCRIPT ERROR: Compile Error: Failed to compile depended scripts.
   at: GDScript::reload (res://Core/Environment/BiomeBase.gd:0)
```

Cascades to:
- BiomeBase.gd → Compile Error
- BioticFluxBiome.gd → Compile Error
- FarmGrid.gd → Compile Error (depends on BiomeBase)
- All Biome subclasses → Compile Error
- ~20+ dependent files → Compile Errors

---

## Root Cause Analysis

In the quantum substrate classes, comments like this appear:

```gdscript
var _density_matrix  # DensityMatrix (no type hint - class_name removed)
var _hamiltonian  # Hamiltonian (no type hint - class_name removed)
var _lindblad  # LindbladSuperoperator (no type hint - class_name removed)
```

But the code still uses the class names as types:

```gdscript
# QuantumBath.gd:210 - Fails
var new_matrix = ComplexMatrix.new(new_dim)

# DualEmojiQubit.gd:100 - Fails
func get_rho_subspace() -> ComplexMatrix:
    var rho_sub = ComplexMatrix.new(2)
    return rho_sub
```

### Why This Happened

The `class_name` declarations were **INTENTIONALLY REMOVED** to avoid circular references.

Evidence in the code:
```gdscript
# ComplexMatrix.gd line 1:
# class_name ComplexMatrix - removed to avoid circular self-reference

# DensityMatrix.gd line 1:
# class_name DensityMatrix - removed to avoid circular self-reference

# Hamiltonian.gd line 1:
# class_name Hamiltonian - removed to avoid circular reference
```

**However**, the code was NOT updated to handle the missing class_name:
1. Type hints still reference ComplexMatrix, DensityMatrix, etc.
2. Code still calls `ComplexMatrix.new()` expecting it to work
3. No preload imports were added as replacement
4. This appears to be an incomplete refactor/migration

---

## Affected Files (Classes Missing class_name)

These files likely have had their `class_name` removed but need to be restored or properly imported:

1. **Core/QuantumSubstrate/ComplexMatrix.gd**
   - Referenced as return type in multiple files
   - Instantiated with `ComplexMatrix.new()` in ~15+ locations

2. **Core/QuantumSubstrate/DensityMatrix.gd**
   - Referenced in QuantumBath.gd, DualEmojiQubit.gd, BiomeBase.gd
   - No type hints but needs class_name for factory creation

3. **Core/QuantumSubstrate/Hamiltonian.gd**
   - Commented as "removed" in QuantumBath.gd
   - Instantiated internally

4. **Core/QuantumSubstrate/LindbladSuperoperator.gd** (possibly - verify)
   - Check if it has `class_name` declaration

5. **Core/QuantumSubstrate/QuantumEvolver.gd** (possibly - verify)
   - Check if it has `class_name` declaration

---

## Files Using These Classes (Will Fail Compilation)

Direct references:
- `Core/QuantumSubstrate/QuantumBath.gd` - Uses ComplexMatrix, DensityMatrix
- `Core/QuantumSubstrate/DualEmojiQubit.gd` - Uses ComplexMatrix return type
- `Core/QuantumSubstrate/BiomeBase.gd` - Depends on QuantumBath
- `Core/Environment/BioticFluxBiome.gd` - Depends on BiomeBase
- `Core/GameMechanics/FarmGrid.gd` - Depends on BiomeBase
- All 8 Biome implementations - Depend on BiomeBase

Cascade effect:
- ~20+ files cannot compile
- Game cannot boot
- Tests cannot run

---

## Solution Options

### Option A: Restore class_name declarations (RECOMMENDED)

For each affected class, add `class_name` declaration:

```gdscript
# ComplexMatrix.gd - Add this as first line (after any comments)
class_name ComplexMatrix
extends Resource

# DensityMatrix.gd
class_name DensityMatrix
extends Resource

# Hamiltonian.gd
class_name Hamiltonian
extends Resource
```

**Pros**:
- Simplest fix
- No changes needed to dependent code
- Matches GDScript conventions

**Cons**:
- May re-introduce original circular reference issues (need to investigate why they were removed)

### Option B: Use preload imports everywhere

Add preload to each file that uses these classes:

```gdscript
const ComplexMatrix = preload("res://Core/QuantumSubstrate/ComplexMatrix.gd")
const DensityMatrix = preload("res://Core/QuantumSubstrate/DensityMatrix.gd")
```

**Pros**:
- Avoids global namespace pollution
- Explicit dependencies

**Cons**:
- ~15+ files need updating
- More verbose

### Option C: Check why class_name was removed

Investigate git history or comments to understand:
- Were there circular reference issues?
- Was this an incomplete refactor?
- Are there other solutions that were attempted?

---

## Files to Check/Fix

```
Core/QuantumSubstrate/ComplexMatrix.gd ← CHECK FOR class_name
Core/QuantumSubstrate/DensityMatrix.gd ← CHECK FOR class_name
Core/QuantumSubstrate/Hamiltonian.gd ← CHECK FOR class_name
Core/QuantumSubstrate/LindbladSuperoperator.gd ← VERIFY HAS class_name
Core/QuantumSubstrate/QuantumEvolver.gd ← VERIFY HAS class_name
```

---

## Testing After Fix

After restoring class_name declarations:

```bash
# Should pass without "ComplexMatrix not declared" errors
godot --headless --script /tmp/test_phase2_syntax.gd

# Should compile game
godot --editor
```

---

## Related Phase 1-2 Work

This bug is NOT caused by Phase 1-2 implementation. It's a pre-existing architectural issue that was exposed during testing.

**What WAS fixed in Phase 1-2**:
- ✅ Added QuantumRigorConfig import to QuantumBath.gd
- ✅ Added missing FarmPlot properties (tap_drain_rate, tap_last_flux_check)
- ✅ Implemented energy tap drain operators
- ✅ Created comprehensive test suite

**What's BLOCKED by this bug**:
- ❌ Cannot test Phase 1-2 code until ComplexMatrix/DensityMatrix are fixed
- ❌ Game cannot boot
- ❌ Biome system broken
- ❌ Farm grid broken

---

## Priority

**UNBLOCK THIS FIRST** before proceeding with Phase 3 (Measurement Refactor).

This is the single most critical issue preventing game execution.

---

## For the Fix Bot

1. Identify which files had class_name removed
2. Determine why they were removed (circular refs?)
3. Apply Option A (restore class_name) or Option B (add preloads)
4. Test compilation: `godot --headless --script /tmp/test_phase2_syntax.gd`
5. Report back whether this was intentional refactoring or incomplete work
