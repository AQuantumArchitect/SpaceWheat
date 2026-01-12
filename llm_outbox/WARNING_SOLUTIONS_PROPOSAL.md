# Warning Solutions Proposal
**Date:** 2026-01-11
**Status:** Awaiting User Decision
**Context:** Non-critical warnings identified during boot sequence testing

---

## Issue #1: Operator Builder Verbosity (~100 warnings)

### Current Behavior:
During boot, the Hamiltonian and Lindblad builders generate ~100 informational warnings like:
```
⚠️ ☀→🔥 skipped (no coordinate)
⚠️ 🌾→🌱 skipped (no coordinate)
⚠️ Gated L 🌿→🌾 skipped (source 🌿 not in biome)
```

### Why This Happens:
- Icons have couplings defined to emojis that aren't present in every biome
- The builders correctly skip these couplings
- This is **expected behavior** - not all icons couple to all other icons
- These are informational messages, not errors

### Code Locations:
- `Core/QuantumSubstrate/HamiltonianBuilder.gd:56`
- `Core/QuantumSubstrate/LindbladBuilder.gd:103, 106`

### Impact:
- **Functionality:** None - operators build correctly
- **User Experience:** Console cluttered during boot
- **Debugging:** Makes it harder to spot actual problems

### Proposed Solutions:

#### Option A: Remove Print Statements (Recommended)
**What:** Delete the print() calls entirely
**Pros:** Cleanest solution, these are normal operations that don't need reporting
**Cons:** Lose visibility into which couplings were skipped (rarely useful)
**Implementation:** 3 lines to delete

```gdscript
# Before:
if not register_map.has(target_emoji):
    print("  ⚠️ %s→%s skipped (no coordinate)" % [source_emoji, target_emoji])
    continue

# After:
if not register_map.has(target_emoji):
    # Skip couplings to emojis not in this biome (expected)
    continue
```

#### Option B: Add Verbosity Control
**What:** Gate these prints behind a verbosity flag
**Pros:** Keeps information available for debugging, clean by default
**Cons:** Adds configuration complexity
**Implementation:** Add verbosity flag to builders, check before printing

```gdscript
# Add to builder initialization:
var verbose_skips: bool = false  # Set to true for debugging

# In the check:
if not register_map.has(target_emoji):
    if verbose_skips:
        print("  ⚠️ %s→%s skipped (no coordinate)" % [source_emoji, target_emoji])
    continue
```

#### Option C: Use Debug-Level Logging
**What:** Route through VerboseConfig at DEBUG level (currently INFO)
**Pros:** Uses existing logging infrastructure
**Cons:** Still generates log entries even if not displayed
**Implementation:** Replace print() with _verbose.debug()

```gdscript
# Instead of print():
_verbose.debug("quantum", "⚠️", "%s→%s skipped (no coordinate)" % [source_emoji, target_emoji])
```

### Recommendation:
**Option A** - These are normal operations that don't need reporting. The builders successfully skip invalid couplings as designed.

---

## Issue #2: PlotGridDisplay Null Config Warning

### Current Behavior:
During boot, PlotGridDisplay logs:
```
WARNING: [WARN][UI] ⚠️ PlotGridDisplay: grid_config is null - will be set later
```

### Why This Happens:
- PlotGridDisplay._ready() checks if `grid_config` is injected
- Code comment claims: "Dependencies injected BEFORE add_child(), so they're available now"
- But warning suggests `grid_config` is sometimes null during _ready()
- Config is successfully set immediately after in the boot sequence

### Code Location:
- `UI/PlotGridDisplay.gd:85-87`

### Impact:
- **Functionality:** None - config is set correctly before use
- **User Experience:** Confusing warning about expected behavior
- **Debugging:** Creates noise in logs

### Proposed Solutions:

#### Option A: Remove Warning (If Truly Intentional)
**What:** Delete the warning if null config at _ready() is acceptable
**Pros:** Simplest solution, avoids false alarm
**Cons:** Lose safety check if config injection pattern changes
**Implementation:** Remove the null check and warning

```gdscript
# Before:
if grid_config == null:
    _verbose.warn("ui", "⚠️", "PlotGridDisplay: grid_config is null - will be set later")
    return

# After:
# Dependencies injected via set_grid_config() immediately after _ready()
```

#### Option B: Change to Debug Level
**What:** Keep the check but log at DEBUG instead of WARN level
**Pros:** Maintains safety check, reduces log noise
**Cons:** Still checks on every boot unnecessarily
**Implementation:** Change _verbose.warn() to _verbose.debug()

```gdscript
# Before:
_verbose.warn("ui", "⚠️", "PlotGridDisplay: grid_config is null - will be set later")

# After:
_verbose.debug("ui", "ℹ️", "PlotGridDisplay: grid_config will be injected after _ready()")
```

#### Option C: Investigate Root Cause
**What:** Fix dependency injection to happen before _ready() as comment claims
**Pros:** Most correct architecturally, eliminates the race condition
**Cons:** May require refactoring FarmView/PlayerShell initialization order
**Implementation:** Requires investigation of boot sequence

```gdscript
# In FarmView.gd or wherever PlotGridDisplay is created:
# Current pattern:
var plot_display = PlotGridDisplay.new()
add_child(plot_display)  # ← _ready() fires here
plot_display.set_grid_config(config)  # ← Too late!

# Fixed pattern:
var plot_display = PlotGridDisplay.new()
plot_display.set_grid_config(config)  # ← Before adding to tree
add_child(plot_display)  # ← Now _ready() sees the config
```

#### Option D: Defer Tile Creation
**What:** Accept that config is null at _ready(), use call_deferred or next frame
**Pros:** Works with current initialization pattern
**Cons:** Adds frame delay to tile creation (negligible)
**Implementation:** Defer tile creation to next frame

```gdscript
func _ready():
    # Dependencies will be injected after _ready(), so defer tile creation
    call_deferred("_create_tiles_if_ready")

func _create_tiles_if_ready():
    if grid_config == null or biomes.is_empty():
        return  # Not ready yet
    _create_tiles()
```

### Recommendation:
**Option B** or **Option C** depending on architectural preference:
- **Option B** if this pattern is intentional and works reliably
- **Option C** if we want cleaner dependency injection (set config before adding to tree)

---

## Summary Table

| Issue | Severity | Recommended Fix | Time to Implement |
|-------|----------|----------------|-------------------|
| Operator builder verbosity | LOW | Remove print statements (Option A) | 2 minutes |
| PlotGridDisplay null config | LOW | Change to debug level (Option B) or Fix injection order (Option C) | 2 min (B) / 15 min (C) |

---

## Questions for User:

1. **Operator Builder Verbosity:**
   - Do you ever need to see which icon couplings were skipped?
   - Prefer clean logs (Option A) or configurable verbosity (Option B)?

2. **PlotGridDisplay Null Config:**
   - Is the current pattern (inject after _ready) intentional?
   - Prefer quick fix (Option B) or architectural improvement (Option C)?

---

**Next Steps:** Awaiting user decision on which solutions to implement.

---

**Prepared by:** Claude Code
**Test Results:** All critical script errors fixed ✅
**Boot Status:** Game fully functional 🎮
