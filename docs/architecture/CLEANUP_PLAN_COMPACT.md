# Cleanup Plan - Compact Summary

## 🎯 Phase 1: Infrastructure Fixes (DO THIS NOW)

**File:** `Core/GameMechanics/BasePlot.gd`

**5 functions to fix (remove zombie `bound_terminal` refs):**

1. **`_get_infra_field()`** (line 231-236)
   - Change: `bound_terminal.bound_register_id` → `bound_register_id`

2. **`_set_infra_field()`** (line 239-243)
   - Change: `bound_terminal.bound_register_id` → `bound_register_id`

3. **`get_emoji_pair()`** (line 344-350)
   - Change: `bound_terminal.get_emoji_pair()` → `{"north": north_emoji, "south": south_emoji}`

4. **`harvest()`** (line 500)
   - Change: `bound_terminal = null` → `unbind_register()`

5. **`add_persistent_gate()`** (line 518-521)
   - Change: `bound_terminal.bound_register_id` → `bound_register_id`

**Impact:** Used by theta_frozen, lindblad_*, persistent_gates (hot paths!)

**Risk:** Low (same behavior, internal changes)

**Time:** 30 min

---

## 🔄 Phase 2: Property Migration (LATER)

**Goal:** Replace backward compat properties with direct fields

- `plot.register_id` → `plot.bound_register_id` (count usage first)
- `plot.has_been_measured` → `plot.is_measured` (count usage first)

**Risk:** Medium (could miss edge cases)

**Time:** 2-3 hours

---

## 🧹 Phase 3: Enum Cleanup (OPTIONAL)

**Goal:** Remove deprecated `FarmPlot.PlotType` enum

**Risk:** Low

**Time:** 15 min

---

## Quick Start

```bash
# Scout Phase 1 targets
grep -n "bound_terminal" /home/tehcr33d/ws/SpaceWheat/Core/GameMechanics/BasePlot.gd

# Test after changes
gut -gdir=res://Tests/SaveLoad/ -gtest=test_terminal_bindings.gd
```

**Full plan:** `CLEANUP_PLAN_REGISTER_PLOT_TERMINAL.md`
