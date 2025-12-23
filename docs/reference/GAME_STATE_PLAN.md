# Game State Management System - Architecture Plan

## 🎯 Goals
1. **Save/Load** - Persist game state to disk and restore it
2. **Scenarios** - Different starting configurations (tutorial, sandbox, challenge modes)
3. **Checkpoints** - Auto-save at key moments (goal completion, tribute payment)
4. **New Game** - Uses same system as loading (just loads a scenario template)
5. **Fix Restart Bugs** - Proper state reset instead of scene reload

## 🏗️ Architecture

### 1. GameState (Core State Container)
**File:** `Core/GameState.gd`

Serializable resource containing ALL game state:
```gdscript
class_name GameState
extends Resource

# Economy
var credits: int = 20
var wheat_inventory: int = 0
var flour_inventory: int = 0
var tributes_paid: int = 0
var tributes_failed: int = 0

# Plots (array of plot states)
var plots: Array[Dictionary] = []  # Each: {position, type, planted, growth, measured, etc.}

# Goals
var current_goal_index: int = 0
var completed_goals: Array[String] = []

# Vocabulary (PERSISTS across sessions!)
var discovered_words: Array[String] = []
var vocabulary_energy: float = 0.0

# Icons
var biotic_activation: float = 0.0
var chaos_activation: float = 0.0
var imperium_activation: float = 0.0

# Contracts
var active_contracts: Array[Dictionary] = []

# Time
var game_time: float = 0.0
var sun_moon_phase: float = 0.0

# Meta (what scenario is this?)
var scenario_id: String = "default"
var difficulty: String = "normal"
```

### 2. GameStateManager (Singleton)
**File:** `Core/GameStateManager.gd`

Handles save/load operations:
```gdscript
class_name GameStateManager
extends Node

# Save paths
const SAVE_DIR = "user://saves/"
const AUTOSAVE_FILE = "autosave.tres"
const CHECKPOINT_PREFIX = "checkpoint_"

# Current state
var current_state: GameState = null

func new_game(scenario_id: String = "default") -> GameState:
    """Start new game by loading a scenario"""
    return load_scenario(scenario_id)

func load_scenario(scenario_id: String) -> GameState:
    """Load a scenario template (tutorial, sandbox, challenge, etc.)"""
    var scenario_path = "res://Scenarios/%s.tres" % scenario_id
    return ResourceLoader.load(scenario_path)

func save_game(slot_name: String = "autosave"):
    """Save current state to disk"""
    var state = capture_current_state()
    var path = SAVE_DIR + slot_name + ".tres"
    ResourceSaver.save(state, path)

func load_game(slot_name: String) -> GameState:
    """Load state from disk"""
    var path = SAVE_DIR + slot_name + ".tres"
    return ResourceLoader.load(path)

func capture_current_state() -> GameState:
    """Capture current game state from live game"""
    # Queries FarmView, Economy, Goals, etc.
    
func apply_state(state: GameState):
    """Apply loaded state to live game"""
    # Updates FarmView, Economy, Goals, etc.

func create_checkpoint(label: String):
    """Auto-save at key moment"""
    save_game(CHECKPOINT_PREFIX + label)
```

### 3. Scenario System
**File:** `Scenarios/` directory with `.tres` files

Pre-configured GameState resources for different game modes:

**default.tres** - Normal start
- 20 credits, empty farm, first goal active

**tutorial.tres** - Teaching mode  
- 50 credits, some plots pre-planted, simplified goals

**sandbox.tres** - Creative mode
- 999 credits, all mechanics unlocked, no tributes

**challenge_speedrun.tres** - Timed mode
- 10 credits, hard goals, 10 minute timer

**continue_vocabulary.tres** - Persist vocabulary from previous session
- Loads last saved vocabulary state

### 4. Integration Points

**FarmView._ready():**
```gdscript
func _ready():
    # OLD WAY: Initialize everything here
    # NEW WAY: Apply state from GameStateManager
    
    var state = GameStateManager.get_current_state()
    if state:
        apply_state(state)
    else:
        # First time - load default scenario
        var state = GameStateManager.new_game("default")
        apply_state(state)
```

**Restart:**
```gdscript
func restart():
    # OLD: get_tree().reload_current_scene()  # BUGGY
    # NEW: Reload scenario state
    var state = GameStateManager.new_game(current_scenario_id)
    GameStateManager.apply_state(state)
```

**Auto-save triggers:**
- Goal completed
- Tribute paid
- Every 5 minutes (background autosave)
- Game quit

## 📁 File Structure
```
Core/
  GameState.gd                 # State container resource
  GameStateManager.gd          # Save/load singleton
  Serialization/
    PlotSerializer.gd          # Serialize plot state
    ContractSerializer.gd      # Serialize contracts
    VocabularySerializer.gd    # Serialize vocabulary

Scenarios/
  default.tres                 # Normal start
  tutorial.tres                # Tutorial mode
  sandbox.tres                 # Creative mode
  challenge_speedrun.tres      # Speed challenge
  
user://saves/                  # Save game files
  autosave.tres
  manual_save_1.tres
  checkpoint_goal1.tres
```

## 🔄 Implementation Phases

### Phase 1: Core State System
1. Create GameState resource class
2. Create GameStateManager singleton  
3. Implement capture_current_state()
4. Implement apply_state()

### Phase 2: Serialization
1. PlotSerializer - save/load plot states
2. ContractSerializer - save/load contracts
3. VocabularySerializer - save/load discovered words

### Phase 3: Save/Load UI
1. Add save/load to escape menu
2. Create checkpoint system (auto-save)
3. Add scenario selection to main menu

### Phase 4: Scenarios
1. Create default.tres scenario
2. Create tutorial.tres scenario
3. Create sandbox.tres scenario

### Phase 5: Fix Restart
1. Replace reload_current_scene() with state-based restart
2. Test that restart doesn't break anything

## 🎮 Player Experience

**New Game:**
1. Player chooses scenario (Default, Tutorial, Sandbox)
2. Game loads scenario.tres
3. FarmView applies state
4. Game starts with configured initial conditions

**Save Game:**
1. Player presses Save (or auto-save triggers)
2. Current state captured
3. Saved to user://saves/

**Load Game:**
1. Player chooses save file
2. State loaded from disk
3. FarmView applies state
4. Game continues from saved point

**Restart:**
1. Player presses R
2. Current scenario reloaded
3. State applied (fresh start)
4. No bugs! (Proper state reset, not scene reload)

## 💾 Vocabulary Persistence Strategy

Special case: Vocabulary should persist across game sessions!

**Option A: Separate vocabulary save**
- Vocabulary saved independently
- New game loads vocabulary from previous session
- Player keeps discovered words

**Option B: Vocabulary as meta-progression**
- Vocabulary unlocks are permanent
- New scenarios can include/exclude discovered words
- Like achievements/upgrades in roguelikes

Recommend: **Option A** - Vocabulary is player knowledge, should persist

## ❓ Questions to Answer

1. Should vocabulary persist across ALL scenarios, or per-scenario?
2. Do we want multiple save slots (Save 1, Save 2, etc.)?
3. Should checkpoints be manual or auto-only?
4. Do we need a "Load Game" menu, or just autosave/continue?

