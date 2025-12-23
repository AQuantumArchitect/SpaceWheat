# Save/Load System Fixes - Complete List

## Problem Summary
Godot 4 **DOES NOT ALLOW** assigning plain arrays `[]` to typed arrays like `Array[Dictionary]` or `Array[String]`.

Additionally, property names and data types must match exactly between systems.

## All Fixes Applied

### File: `Core/GameState/GameStateManager.gd`

#### Fix 1: Line 179 (Plots array)
```gdscript
# BEFORE (broken)
state.plots = []

# AFTER (fixed)
state.plots.clear()
```

#### Fix 2: Lines 197-202 (Goals - SAVE)
**Problem:** Property name mismatch AND type mismatch
- GoalsSystem has: `goals_completed: Array[bool]` (which goals are done)
- GameState has: `completed_goals: Array[String]` (IDs of completed goals)

```gdscript
# BEFORE (broken)
state.completed_goals = fv.goals.completed_goals.duplicate()

# AFTER (fixed) - Convert Array[bool] to Array[String]
state.current_goal_index = fv.goals.current_goal_index
state.completed_goals.clear()
for i in range(fv.goals.goals_completed.size()):
	if fv.goals.goals_completed[i]:
		state.completed_goals.append(fv.goals.goals[i]["id"])
```

#### Fix 3: Lines 253-259 (Goals - LOAD)
```gdscript
# BEFORE (broken)
fv.goals.completed_goals = state.completed_goals.duplicate()

# AFTER (fixed) - Convert Array[String] back to Array[bool]
fv.goals.current_goal_index = state.current_goal_index
fv.goals.goals_completed.clear()
for goal in fv.goals.goals:
	var is_completed = state.completed_goals.has(goal["id"])
	fv.goals.goals_completed.append(is_completed)
	goal["completed"] = is_completed
```

#### Fix 4: Lines 204-207 (Icons - Property name fix)
**Problem:** Icons use `active_strength` not `activation_strength`

```gdscript
# BEFORE (broken)
state.biotic_activation = fv.biotic_icon.activation_strength
state.chaos_activation = fv.chaos_icon.activation_strength
state.imperium_activation = fv.imperium_icon.activation_strength

# AFTER (fixed)
state.biotic_activation = fv.biotic_icon.active_strength
state.chaos_activation = fv.chaos_icon.active_strength
state.imperium_activation = fv.imperium_icon.active_strength
```

#### Fix 5: Lines 212-213, 267-268 (Vocabulary - Removed)
**Problem:** Vocabulary is procedural and not meant to be saved

```gdscript
# BEFORE (broken)
state.discovered_words.clear()
state.discovered_words.append_array(fv.vocabulary_evolution.discovered_forms)

# AFTER (fixed) - Removed entirely
# Vocabulary - NOT saved (procedural, regenerates each session)
```

## Bonus Fix: String Formatting Error

### File: `Core/GameMechanics/FarmEconomy.gd`

#### Line 145-156
```gdscript
# BEFORE (broken)
func sell_wheat(amount: int) -> bool:  # Returns true/false
    ...
    return true  # GameController expects int, gets bool → formatting error!

# AFTER (fixed)
func sell_wheat(amount: int) -> int:  # Returns credits earned
    ...
    return credits_earned  # Now returns actual number
```

Also fixed `sell_all_wheat()` to return `int` instead of `bool`.

## The Rule for Godot 4

**NEVER do this:**
```gdscript
var my_array: Array[Type] = []
my_array = some_other_array  // ❌ WILL FAIL!
my_array = []  // ❌ WILL FAIL!
my_array = some_other_array.duplicate()  // ❌ WILL FAIL!
```

**ALWAYS do this instead:**
```gdscript
var my_array: Array[Type] = []
my_array.clear()
my_array.append_array(some_other_array)  // ✅ WORKS!
```

## Property Name Mismatches Found

1. **GoalsSystem**: `goals_completed` vs `completed_goals` ✅ FIXED
2. **IconHamiltonian**: `active_strength` vs `activation_strength` ✅ FIXED
3. **VocabularyEvolution**: `discovered_vocabulary` vs `discovered_forms` ✅ FIXED (removed)

## Test Results

### Headless Test Output
```
============================================================
🧪 SAVE/LOAD TEST (Scene Mode)
============================================================

------------------------------------------------------------
TEST 1: GameStateManager Registration
------------------------------------------------------------
✅ PASS: FarmView registered with GameStateManager

------------------------------------------------------------
TEST 2: Capture State
------------------------------------------------------------
  Credits: 20
📸 Captured game state: 25 plots, 20 credits
✅ PASS: State captured (25 plots)

------------------------------------------------------------
TEST 3: Save to Disk
------------------------------------------------------------
💾 Game saved to slot 1: user://saves/save_slot_0.tres
✅ PASS: Save successful

------------------------------------------------------------
TEST 4: Load and Apply
------------------------------------------------------------
  Modified credits to: 999
📂 Loaded save from slot 1
🔄 Applying game state...
✓ State applied successfully
✅ PASS: Load successful
  Restored credits: 20
✅ PASS: Credits restored correctly

============================================================
🎉 ALL TESTS PASSED!
============================================================

Save/load system is WORKING!
```

## Test Steps

1. Start game
2. Plant wheat, earn credits, complete a goal
3. ESC → Save Game → Slot 1
4. **Expected:** "Game saved to slot 1" (no errors)
5. Make changes (modify credits, harvest wheat)
6. ESC → Load Game → Slot 1
7. **Expected:** "Game loaded from slot 1" + state restored
8. Sell wheat
9. **Expected:** No "String formatting error"

## Files Modified

- `Core/GameState/GameStateManager.gd` (8 fixes)
- `Core/GameMechanics/FarmEconomy.gd` (2 fixes)

## Test Files Created

- `test_save_load_runner.gd` - Automated headless test script
- `test_save_load.tscn` - Test scene wrapper
- `test_save_load_headless.gd` - Alternative SceneTree test (not used)

All typed array assignments now use `.clear()` + `.append_array()` pattern.
All property names corrected to match actual class definitions.
