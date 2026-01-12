# Operator Build Warnings Muted

**Date:** 2026-01-12  
**Status:** ✅ COMPLETE

---

## Problem

During boot, operator building was flooding the console with "skipped" warnings:

```
  ⚠️ 🔥→☀ skipped (no coordinate)
  ⚠️ 🔥→🌬 skipped (no coordinate)
  ⚠️ 🔥→⛰ skipped (no coordinate)
  ⚠️ 🔥→🍞 skipped (no coordinate)
  ⚠️ 🔥→🍂 skipped (no coordinate)
  ⚠️ L 🍞→🔥 skipped (no coordinate)
  ⚠️ L 🍂→🔥 skipped (no coordinate)
  ⚠️ L 🌬→🔥 skipped (no coordinate)
  ⚠️ L 🌧→💧 skipped (no coordinate)
  ⚠️ Gated L 🌿→🌾 skipped (source 🌿 not in biome)
  ⚠️ Gated L 🌱→🌾 skipped (source 🌱 not in biome)
```

**Why This Happens:** Icons define couplings and Lindblad operators for emojis that may not exist in every biome. For example, the 🔥 (fire) icon might reference ☀ (sun), but the Kitchen biome doesn't have a sun emoji. This is **expected behavior**, not an error.

**Problem:** These warnings were using direct `print()` statements, so they always appeared regardless of verbosity settings.

---

## Solution

Removed the `else: print()` fallback statements from:
1. `Core/QuantumSubstrate/HamiltonianBuilder.gd`
2. `Core/QuantumSubstrate/LindbladBuilder.gd`

**Before:**
```gdscript
if not register_map.has(target_emoji):
    stats.couplings_skipped += 1
    if verbose:
        verbose.debug("quantum-build", "⚠️", "%s→%s skipped" % [source, target])
    else:
        print("  ⚠️ %s→%s skipped" % [source, target])  # ALWAYS PRINTED!
    continue
```

**After:**
```gdscript
if not register_map.has(target_emoji):
    stats.couplings_skipped += 1
    if verbose:
        verbose.debug("quantum-build", "⚠️", "%s→%s skipped" % [source, target])
    continue  # Silent skip - tracked in stats
```

---

## Changes Made

### HamiltonianBuilder.gd
**Line 70-74:** Removed `else: print()` for coupling skip warnings (1 location)

### LindbladBuilder.gd
**Line 66-70:** Removed `else: print()` for outgoing Lindblad skip warnings (1 location)  
**Line 94-98:** Removed `else: print()` for incoming Lindblad skip warnings (1 location)  
**Line 128-132:** Removed `else: print()` for gated Lindblad skip - source (1 location)  
**Line 133-137:** Removed `else: print()` for gated Lindblad skip - gate (1 location)

**Total:** 5 print() statements removed

---

## How to Re-Enable for Debugging

If you need to see these warnings again for debugging, enable verbose logging:

### Option 1: Pass --verbose flag
```bash
godot --path . --verbose
```

### Option 2: In-game Logger Config Panel
1. Press **L** to open Logger Config Panel
2. Enable "quantum-build" category (or "quantum" parent category)
3. Set level to DEBUG or TRACE

### Option 3: Code
```gdscript
VerboseConfig.category_levels["quantum"] = VerboseConfig.LogLevel.DEBUG
VerboseConfig.category_enabled["quantum"] = true
```

---

## Boot Output Comparison

### Before Fix:
```
🔨 Building Hamiltonian: 3 qubits (8D)...
  ⚠️ 🔥→☀ skipped (no coordinate)
  ⚠️ 🔥→🌬 skipped (no coordinate)
  ⚠️ 🔥→⛰ skipped (no coordinate)
  ⚠️ 🔥→❄️ skipped (no coordinate)
  ⚠️ 🔥→🍞 skipped (no coordinate)
  ⚠️ 🔥→🍂 skipped (no coordinate)
  ⚠️ 🔥→🌿 skipped (no coordinate)
  ⚠️ 🔥→🌲 skipped (no coordinate)
🔨 Hamiltonian built: 8x8 (added: 5 self-energies + 8 couplings, skipped: 19)
🔨 Building Lindblad operators: 3 qubits (8D)...
  ⚠️ L 🔥→🍂 skipped (no coordinate)
  ⚠️ L 🍞→🔥 skipped (no coordinate)
  ⚠️ L 🍂→🔥 skipped (no coordinate)
  ⚠️ L 🌬→🔥 skipped (no coordinate)
  ⚠️ L 🌧→💧 skipped (no coordinate)
  ⚠️ L 🍂→🌾 skipped (no coordinate)
  ⚠️ L ☀→🌾 skipped (no coordinate)
  ⚠️ Gated L 🌿→🌾 skipped (source 🌿 not in biome)
  ⚠️ Gated L 🌱→🌾 skipped (source 🌱 not in biome)
🔨 Built 2 Lindblad operators + 0 gated configs (added: 2, skipped: 9)
```

### After Fix:
```
🔨 Building Hamiltonian: 3 qubits (8D)...
🔨 Hamiltonian built: 8x8 (added: 5 self-energies + 8 couplings, skipped: 19)
🔨 Building Lindblad operators: 3 qubits (8D)...
🔨 Built 2 Lindblad operators + 0 gated configs (added: 2, skipped: 9)
```

**Result:** Much cleaner! The summary line still shows skip counts for debugging purposes.

---

## Impact

### ✅ Benefits:
- **Cleaner boot logs** - No spam from expected skips
- **Faster boot** - Less console I/O
- **Still trackable** - Stats show skip counts in summary
- **Still debuggable** - Can enable with verbose logging

### ⚠️ No Negative Impact:
- Warnings still logged when verbose mode enabled
- Statistics still tracked (skipped counts in summary)
- No functional changes to operator building

---

## Related Systems

**Not Affected:**
- Operator building logic (unchanged)
- Hamiltonian/Lindblad construction (unchanged)
- Quantum evolution (unchanged)
- Cache system (unchanged)

**UI/UX Impact:**
- Boot feels snappier (less console spam)
- Easier to spot actual errors

---

## Testing

### Verified:
```bash
godot --path . --headless --quit 2>&1 | grep "skipped (no coordinate)"
```

**Before:** 19+ lines of warnings  
**After:** 0 lines (silent)

### Summary Still Shows Stats:
```
🔨 Hamiltonian built: 8x8 (added: 5 self-energies + 8 couplings, skipped: 19)
🔨 Built 2 Lindblad operators + 0 gated configs (added: 2, skipped: 9)
```

---

## Summary

**Problem:** Boot console flooded with "skipped" warnings  
**Root Cause:** Direct print() statements bypassing verbose logger  
**Solution:** Remove print() fallbacks, rely on verbose.debug()  
**Result:** ✅ Clean boot logs, warnings available via verbose mode

---

**Files Changed:** 2 files, 5 print() statements removed  
**Risk:** None (degrades gracefully, stats still tracked)  
**Status:** ✅ Complete and tested

---

**Implementation:** Claude Code  
**Date:** 2026-01-12  
**Verification:** Boot tested, no warnings in default mode
