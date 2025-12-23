# MemoryManager - Clean Architecture Guide

## Overview

`MemoryManager.gd` is the official save/load system for SpaceWheat's clean architecture. It handles game state serialization with **zero UI dependencies**.

## Architecture Pattern

```
┌────────────────────────────────────────────────┐
│ UI LAYER (Optional Observer)                   │
│ - SaveLoadMenu, FarmView                       │
│ - Listens to MemoryManager signals             │
└────────────────────────────────────────────────┘
              ↓ (emit/listen)
┌────────────────────────────────────────────────┐
│ MEMORY MANAGER (Persistence Layer)            │
│ - Pure save/load of GameState objects         │
│ - No FarmView or UI dependencies              │
│ - Emits signals for UI to observe             │
└────────────────────────────────────────────────┘
              ↓ (apply/capture)
┌────────────────────────────────────────────────┐
│ FARM SIMULATION (Game Logic)                   │
│ - apply_game_state(state: GameState)          │
│ - capture_game_state(state: GameState)        │
│ - Pure mechanics, no UI coupling              │
└────────────────────────────────────────────────┘
```

## Key Features

### Single Responsibility
- **Saves GameState to disk** (slots 0-2)
- **Loads GameState from disk**
- **NO FarmView coupling**
- **NO UI logic**

### Signals for UI
```gdscript
signal game_state_created(state: GameState)
signal game_state_saved(state: GameState, slot: int)
signal game_state_loaded(state: GameState, slot: int)
signal game_state_changed(state: GameState)
```

### API

#### Create New Game
```gdscript
var state = MemoryManager.new_game("default")
# Returns: Fresh GameState with default scenario
```

#### Save Game
```gdscript
var success = MemoryManager.save_game(state, 0)
# Args:
#   state: GameState to save
#   slot: 0-2 (which save slot)
# Returns: true if successful
```

#### Load Game
```gdscript
var state = MemoryManager.load_game(0)
# Args:
#   slot: 0-2 (which save slot)
# Returns: GameState or null if slot empty
```

#### Get Save Info
```gdscript
var info = MemoryManager.get_save_info(0)
# Returns: {
#   "exists": bool,
#   "slot": int,
#   "display_name": String,
#   "scenario": String,
#   "credits": int,
#   "playtime": float,
#   "grid_size": String
# }
```

#### Check Save Exists
```gdscript
if MemoryManager.save_exists(0):
    # Slot 0 has a save file
```

#### List All Saves
```gdscript
var all_saves = MemoryManager.get_all_saves()
# Returns: Array[Dictionary] of all 3 slots
```

## Farm Integration

### Apply Saved State
```gdscript
var farm = Farm.new()
root.add_child(farm)
await root.get_tree().process_frame

var state = MemoryManager.load_game(0)
farm.apply_game_state(state)  # Load into simulation
```

### Capture Current State
```gdscript
var current_state = MemoryManager.current_state
var updated = farm.capture_game_state(current_state)
MemoryManager.save_game(updated, 0)
```

## GameState Schema

Each GameState resource contains:
```gdscript
@export var credits: int = 20
@export var wheat_inventory: int = 0
@export var flour_inventory: int = 0
@export var flower_inventory: int = 0
@export var labor_inventory: int = 0

@export var plots: Array[Dictionary] = []  # Per-plot state
@export var sun_moon_phase: float = 0.0   # Environment state

@export var scenario_id: String = "default"
@export var game_time: float = 0.0
@export var save_timestamp: int = 0
```

### Plot State
```gdscript
{
    "position": Vector2i,
    "type": int,
    "is_planted": bool,
    "has_been_measured": bool,
    "theta_frozen": bool,
    "entangled_with": Array
}
```

## Complete Save/Load Cycle

### Phase 1: Boot
```gdscript
var state = MemoryManager.new_game("default")
var farm = Farm.new()
farm.apply_game_state(state)
```

### Phase 2: Play
```gdscript
# Game runs, farm modifies internal state
farm.biome.evolve()
farm.grid.measure_plot(pos)
farm.harvest_plot(pos)
```

### Phase 3: Save
```gdscript
var updated = farm.capture_game_state(state)
MemoryManager.save_game(updated, 0)
```

### Phase 4: Load
```gdscript
var loaded = MemoryManager.load_game(0)
farm.apply_game_state(loaded)
# Continue playing from saved point
```

## File Locations

- **MemoryManager**: `res://Core/GameState/MemoryManager.gd`
- **Save Files**: `user://saves/save_slot_0.tres`, etc.
- **Scenarios**: `res://Scenarios/default.tres`
- **Farm Methods**: `res://Core/Farm.gd` (apply_game_state, capture_game_state)

## Headless Testing

MemoryManager works perfectly in headless mode (no GUI):

```bash
timeout 45 godot --headless -s test_clean_save_load.gd
```

Test validates full cycle:
- Create → Boot → Play → Save → Load → Verify → Continue

## Migration from Old GameStateManager

Old GameStateManager (with FarmView coupling) is superseded.

**Update references:**
- Old: `GameStateManager_Clean` → New: `MemoryManager`
- Old: `GameStateManager` → **DEPRECATED** (had UI coupling)

**UI Integration:**
```gdscript
# Before (tightly coupled)
GameStateManager.capture_state_from_game()

# After (clean architecture)
var state = farm.capture_game_state(current_state)
MemoryManager.save_game(state, slot)
```

## Benefits

✅ **Decoupled**: UI-independent save/load
✅ **Testable**: Full game cycle in headless mode
✅ **Deterministic**: Same GameState → Same simulation
✅ **Replayable**: Load any save at any time
✅ **Modular**: Can swap UI without affecting saves
✅ **Extensible**: GameState schema is flat and exportable

## Testing

Run the comprehensive test:
```bash
timeout 45 godot --headless -s test_clean_save_load.gd 2>&1 | grep "VERIFICATION\|COMPLETE"
```

Expected output:
```
✅ VERIFICATION PASSED
✅ CLEAN ARCHITECTURE TEST COMPLETE
```

---

**Last Updated**: 2025-12-22
**Status**: Production Ready
**Test Coverage**: 9-phase comprehensive test (PASSING)
