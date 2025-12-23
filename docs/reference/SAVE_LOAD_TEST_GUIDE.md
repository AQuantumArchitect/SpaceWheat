# Save/Load System - Manual Test Guide

## ✅ System is Ready!

The Game State Management System has been fully implemented. Here's how to test it:

## Quick Test (In-Game)

1. **Start the game**
   ```bash
   godot --path . scenes/FarmView.tscn
   ```

2. **Make some changes**
   - Plant some wheat (click plot, press P)
   - Spend some credits
   - Complete a goal or two

3. **Open the Escape Menu**
   - Press `ESC`
   - You should see these new buttons:
     - Save Game
     - Load Game
     - Reload Last Save
     - Restart (now uses state reload, not scene reload!)

4. **Test Save**
   - Click "Save Game"
   - You'll see 3 save slots
   - Click a slot (e.g., Slot 1)
   - Should see "Game saved to slot 1" message

5. **Make more changes**
   - Change credits, plant more wheat, etc.

6. **Test Load**
   - Press `ESC` → "Load Game"
   - Click the slot you saved to
   - Game should restore to saved state!

7. **Test Reload Last Save**
   - Make more changes
   - Press `ESC` → "Reload Last Save"
   - Instantly reloads your most recent save

8. **Test Restart**
   - Press `R` or `ESC` → "Restart"
   - Should restart cleanly without bugs
   - (Previously caused conspiracy/color/emoji breakage)

## What Was Fixed

### Before (Buggy):
```gdscript
func _on_restart_requested():
    get_tree().reload_current_scene()  # Breaks signals!
```

### After (Fixed):
```gdscript
func _on_restart_requested():
    GameStateManager.restart_current_scenario()  # State-based reset
```

## Files Created/Modified

### New Files:
- `Core/GameState/GameState.gd` - State container
- `Core/GameState/GameStateManager.gd` - Save/load singleton
- `UI/Panels/SaveLoadMenu.gd` - Save/load UI
- `Scenarios/default.tres` - Default scenario template

### Modified Files:
- `project.godot` - Added GameStateManager autoload
- `UI/Panels/EscapeMenu.gd` - Added save/load buttons
- `UI/FarmView.gd` - Integrated save/load system, fixed restart

## Save File Location

Saves are stored in:
```
user://saves/save_slot_0.tres
user://saves/save_slot_1.tres
user://saves/save_slot_2.tres
```

On Linux: `~/.local/share/godot/app_userdata/SpaceWheat - Quantum Farm/saves/`

## Architecture

```
User presses "Save"
    ↓
SaveLoadMenu shows 3 slots
    ↓
User clicks slot
    ↓
GameStateManager.capture_state_from_game()
    ↓
Captures: credits, plots, goals, icons, contracts, time, vocabulary
    ↓
Saves to: user://saves/save_slot_N.tres
```

```
User presses "Load"
    ↓
SaveLoadMenu shows slots with info (timestamp, credits, goal)
    ↓
User clicks slot
    ↓
GameStateManager.load_and_apply(slot)
    ↓
Loads GameState from file
    ↓
Applies to FarmView: economy, plots, goals, icons, etc.
    ↓
Game restored to saved state
```

## No More Restart Bugs! 🎉

The restart bug (conspiracies break, colors drop, emojis stop) was caused by `reload_current_scene()` breaking signal connections.

Now restart uses `GameStateManager.restart_current_scenario()` which:
1. Loads the default scenario template
2. Applies it to the current game
3. Preserves all signal connections
4. No bugs!
