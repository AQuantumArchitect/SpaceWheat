# Manual Test Guide for Fixes

## ✅ Fixes Applied

### 1. String Formatting Error (sell_wheat)
**File:** `Core/GameMechanics/FarmEconomy.gd:145`
**Changed:** Return type from `bool` → `int`
**Returns:** Credits earned instead of true/false

### 2. Save Error (plots array)
**File:** `Core/GameState/GameStateManager.gd:179`
**Changed:** `state.plots = []` → `state.plots.clear()`
**Reason:** Can't assign `[]` to typed `Array[Dictionary]` in Godot 4

## 🧪 Manual Test Steps

### Test 1: String Formatting Fix

1. Start the game: `godot scenes/FarmView.tscn`

2. Plant some wheat (P key on a plot)

3. Wait for it to grow mature (or fast forward)

4. Measure it (M key)

5. Harvest it (H key)

6. **Sell wheat:**
   - Click "Trade" or press T
   - Sell wheat

7. **Expected:**
   ```
   💰 Earned 186 credits from wheat sale (total: 295)
   ```

8. **Watch for ERROR:**
   ```
   ERROR: String formatting error: a number is required.
   ```

   ❌ If you see this error → Fix failed
   ✅ If no error → **Fix successful!**

### Test 2: Save/Load Fix

1. **Make some changes:**
   - Plant wheat
   - Change credits
   - Complete a goal

2. **Save the game:**
   - Press ESC
   - Click "Save Game"
   - Click "Slot 1"

3. **Watch for ERROR:**
   ```
   ERROR: Invalid assignment of property or key 'plots'
   ERROR: Can't save empty resource
   ```

   ❌ If you see this error → Fix failed
   ✅ If you see "Game saved to slot 1" → **Fix successful!**

4. **Make more changes:**
   - Modify credits manually (for testing)
   - Harvest wheat

5. **Load the game:**
   - Press ESC
   - Click "Load Game"
   - Click "Slot 1"

6. **Verify:**
   - Credits should match saved value
   - Plots should match saved state
   - Everything restored correctly

   ✅ If state restored → **Save/Load working!**

## 🎯 What to Look For

### ✅ Success Indicators:
- No "String formatting error" when selling wheat
- "Game saved to slot N" message appears
- "Game loaded from slot N" message appears
- State correctly restored after load

### ❌ Failure Indicators:
- `ERROR: String formatting error: a number is required`
- `ERROR: Invalid assignment of property or key 'plots'`
- `ERROR: Can't save empty resource`
- State not restored after load

## 📝 Report Results

After testing, please report:
1. ✅/❌ Wheat sale error fixed?
2. ✅/❌ Save working?
3. ✅/❌ Load working?
4. Any other errors you encounter

---

## 🔍 Technical Details

### Fix 1: sell_wheat() Return Type
**Before:**
```gdscript
func sell_wheat(amount: int) -> bool:  # ❌ Returns true/false
    ...
    return true
```

**After:**
```gdscript
func sell_wheat(amount: int) -> int:  # ✅ Returns credits earned
    ...
    return credits_earned
```

### Fix 2: Typed Array Assignment
**Before:**
```gdscript
state.plots = []  # ❌ Can't assign [] to Array[Dictionary]
```

**After:**
```gdscript
state.plots.clear()  # ✅ Clears typed array properly
```

This is a Godot 4 requirement - typed arrays must use `.clear()` or be created as `Array[Type]()`.
