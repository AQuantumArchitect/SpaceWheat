# FarmView Refactoring Plan

**Current State**: FarmView.gd is 1826 lines with 54 functions - a "god object" anti-pattern

**Goal**: Split into smaller, focused components following Godot best practices

---

## Current Responsibilities (Too Many!)

FarmView.gd currently handles:
1. ✅ UI layout creation (top bar, action bar, info panel, goal display)
2. ✅ Resource display updates (credits, wheat, flour, imperium)
3. ✅ Action button state management
4. ✅ Plot selection and navigation
5. ✅ Input handling (keyboard shortcuts, mouse clicks)
6. ✅ Game action execution (plant, harvest, measure, entangle)
7. ✅ Signal routing and coordination
8. ✅ Visual effects triggering
9. ✅ Goal system updates
10. ✅ Icon activation updates
11. ✅ Double-tap detection

---

## Proposed Architecture

### **Principle**: Scene Composition + Signal-Based Communication

Each UI component becomes its own scene (`.tscn` + `.gd`) that:
- Manages its own layout
- Exposes signals for user actions
- Provides public methods to update its state
- Has NO knowledge of other components

```
Main Scene (FarmView)
├── ResourcePanel (credits, wheat, flour, sun/moon)
├── GoalPanel (current objective)
├── ActionPanel (all game action buttons)
├── InfoPanel (status messages)
├── FarmGrid (plot tiles + quantum graph)
└── GameController (coordinates everything)
```

---

## Refactoring Steps

### Phase 1: Extract UI Components (No Behavior Changes)

#### 1.1 Create `ResourcePanel.gd` (150 lines)
**Responsibility**: Display resources (credits, wheat, flour, imperium, sun/moon, tribute timer)

**File**: `UI/ResourcePanel.gd`
```gdscript
class_name ResourcePanel
extends HBoxContainer

signal help_pressed()
signal contracts_pressed()
signal network_pressed()
signal stats_pressed()

var credits_label: Label
var wheat_label: Label
var flour_label: Label
var imperium_label: Label
var sun_moon_label: Label
var tribute_timer_label: Label

func _ready():
    _create_ui()

func update_resources(credits: int, wheat: int, flour: int, imperium: int):
    credits_label.text = str(credits)
    # Compute font size (base 20, +1 per 10 credits, max 40)
    var credits_font_size = clamp(20 + int(credits / 10.0), 20, 40)
    credits_label.add_theme_font_size_override("font_size", credits_font_size)

    wheat_label.text = str(wheat)
    flour_label.text = str(flour)
    imperium_label.text = str(imperium)

func update_sun_moon(is_sun: bool, time_remaining: float):
    if is_sun:
        sun_moon_label.text = "☀️ Sun"
        sun_moon_label.modulate = Color(1.0, 0.9, 0.5)
    else:
        sun_moon_label.text = "🌙 Moon"
        sun_moon_label.modulate = Color(0.7, 0.7, 1.0)

    if sun_moon_label.text.length() < 20:
        sun_moon_label.text += " (%.0fs)" % time_remaining

func update_tribute_timer(seconds: float, warn: bool):
    tribute_timer_label.text = "%.0fs" % seconds
    if warn:
        tribute_timer_label.modulate = Color(1.0, 0.3, 0.3)  # Red warning
    else:
        tribute_timer_label.modulate = Color(1.0, 1.0, 0.7)  # Yellow normal
```

**Lines saved**: ~200 from FarmView.gd

---

#### 1.2 Create `ActionPanel.gd` (250 lines)
**Responsibility**: All action buttons (plant, harvest, measure, build, trade)

**File**: `UI/ActionPanel.gd`
```gdscript
class_name ActionPanel
extends PanelContainer

# Signals for each action
signal plant_wheat_pressed()
signal plant_tomato_pressed()
signal plant_mushroom_pressed()
signal place_mill_pressed()
signal place_market_pressed()
signal harvest_pressed()
signal measure_pressed()
signal entangle_pressed()
signal sell_wheat_pressed()
signal vocabulary_pressed()

# Button references
var plant_button: Button
var plant_tomato_button: Button
var plant_mushroom_button: Button
# ... etc

func _ready():
    _create_ui()
    _connect_buttons()

func _create_ui():
    # Create sections: PLANT, QUANTUM, BUILD, TRADE
    # (Move from FarmView._create_action_bar)
    pass

func update_button_states(state: Dictionary):
    """Update all button enabled/disabled states

    state = {
        "can_plant": bool,
        "can_harvest": bool,
        "can_measure": bool,
        "can_entangle": bool,
        "can_sell": bool,
        "has_selection": bool,
        "credits": int
    }
    """
    plant_button.disabled = not state.can_plant
    harvest_button.disabled = not state.can_harvest
    # ... etc

func set_entangle_mode(active: bool):
    if active:
        entangle_button.text = "❌ Cancel [E]"
    else:
        entangle_button.text = "🔗 Entangle [E]"
```

**Lines saved**: ~300 from FarmView.gd

---

#### 1.3 Create `GoalPanel.gd` (100 lines)
**Responsibility**: Display current goal and progress

**File**: `UI/GoalPanel.gd`
```gdscript
class_name GoalPanel
extends PanelContainer

var title_label: Label
var progress_label: Label
var progress_bar: ProgressBar

func _ready():
    _create_ui()

func update_goal(goal: Dictionary):
    """Update displayed goal

    goal = {
        "title": String,
        "description": String,
        "progress": float (0.0 to 1.0),
        "completed": bool
    }
    """
    title_label.text = goal.title
    progress_label.text = goal.description
    progress_bar.value = goal.progress * 100.0

    if goal.completed:
        title_label.modulate = Color(0.3, 1.0, 0.3)  # Green
    else:
        title_label.modulate = Color(1.0, 1.0, 1.0)  # White
```

**Lines saved**: ~100 from FarmView.gd

---

#### 1.4 Create `InfoPanel.gd` (50 lines)
**Responsibility**: Display status messages

**File**: `UI/InfoPanel.gd`
```gdscript
class_name InfoPanel
extends PanelContainer

var info_label: Label

func _ready():
    _create_ui()

func show_message(message: String, duration: float = 0.0):
    info_label.text = message

    if duration > 0:
        await get_tree().create_timer(duration).timeout
        clear()

func clear():
    info_label.text = ""
```

**Lines saved**: ~50 from FarmView.gd

---

#### 1.5 Create `GameController.gd` (400 lines)
**Responsibility**: Coordinate game systems, handle game actions

**File**: `Core/GameController.gd`
```gdscript
class_name GameController
extends Node

# Game systems
var farm_grid: FarmGrid
var economy: FarmEconomy
var goals: GoalsSystem
var faction_manager: FactionManager
var conspiracy_network: TomatoConspiracyNetwork
var biotic_icon: BioticFluxIcon
var chaos_icon: ChaosIcon
var imperium_icon: ImperiumIcon

# Signals
signal resources_changed(credits: int, wheat: int, flour: int, imperium: int)
signal goal_updated(goal: Dictionary)
signal info_message(message: String)
signal action_button_states_changed(state: Dictionary)

func _ready():
    _initialize_systems()
    _connect_signals()

func plant_wheat(position: Vector2i) -> bool:
    """Execute plant wheat action"""
    if not _can_plant(position):
        return false

    var plot = farm_grid.get_plot(position)
    if economy.spend_credits(economy.SEED_COST):
        plot.plant()
        info_message.emit("🌾 Wheat planted!")
        _update_button_states()
        return true
    else:
        info_message.emit("❌ Not enough credits (need %d)" % economy.SEED_COST)
        return false

func harvest_plot(position: Vector2i) -> bool:
    """Execute harvest action"""
    # Move logic from FarmView._on_harvest_pressed
    pass

func measure_plot(position: Vector2i) -> bool:
    """Execute measurement action"""
    # Move logic from FarmView._on_measure_pressed
    pass

# ... etc for all game actions
```

**Lines saved**: ~500 from FarmView.gd

---

#### 1.6 Create `InputController.gd` (200 lines)
**Responsibility**: Handle all keyboard/mouse input, translate to signals

**File**: `UI/InputController.gd`
```gdscript
class_name InputController
extends Node

# Signals
signal key_plant_pressed()
signal key_harvest_pressed()
signal key_measure_pressed()
signal key_entangle_pressed()
signal key_contracts_toggled()
signal key_network_toggled()
signal navigation_up()
signal navigation_down()
signal navigation_left()
signal navigation_right()

func _input(event):
    if not event is InputEventKey or not event.pressed or event.echo:
        return

    match event.keycode:
        KEY_P:
            key_plant_pressed.emit()
        KEY_H:
            key_harvest_pressed.emit()
        KEY_M:
            key_measure_pressed.emit()
        KEY_E:
            key_entangle_pressed.emit()
        KEY_C:
            key_contracts_toggled.emit()
        KEY_N:
            key_network_toggled.emit()
        KEY_UP, KEY_LEFT:
            navigation_up.emit()  # Counter-clockwise
        KEY_DOWN, KEY_RIGHT:
            navigation_down.emit()  # Clockwise
```

**Lines saved**: ~150 from FarmView.gd

---

#### 1.7 Create `PlotController.gd` (200 lines)
**Responsibility**: Handle plot selection, navigation, double-tap detection

**File**: `UI/PlotController.gd`
```gdscript
class_name PlotController
extends Node

# Signals
signal plot_selected(position: Vector2i)
signal plot_double_tapped(position: Vector2i)

var selected_position: Vector2i = Vector2i(-1, -1)
var last_click_position: Vector2i = Vector2i(-1, -1)
var last_click_time: float = 0.0
const DOUBLE_TAP_TIME = 0.8

func handle_click(position: Vector2i):
    """Handle plot click with double-tap detection"""
    var current_time = Time.get_ticks_msec() / 1000.0
    var time_since_last = current_time - last_click_time
    var is_double_tap = (position == selected_position and time_since_last < DOUBLE_TAP_TIME)

    if is_double_tap:
        plot_double_tapped.emit(position)
    else:
        select(position)
        last_click_position = position
        last_click_time = current_time

func select(position: Vector2i):
    selected_position = position
    plot_selected.emit(position)

func navigate_perimeter(direction: int, total_plots: int):
    """Move selection around perimeter (1=clockwise, -1=counter-clockwise)"""
    # Move from FarmView._move_selection_perimeter
    pass

func get_selected() -> Vector2i:
    return selected_position
```

**Lines saved**: ~200 from FarmView.gd

---

### Phase 2: Refactor FarmView to Orchestrator (300 lines)

**New FarmView.gd** - becomes a thin orchestrator that:
1. Creates child components
2. Connects signals between components
3. Manages layout only

```gdscript
extends Control

# UI Components (scenes)
@onready var resource_panel: ResourcePanel = $ResourcePanel
@onready var goal_panel: GoalPanel = $GoalPanel
@onready var action_panel: ActionPanel = $ActionPanel
@onready var info_panel: InfoPanel = $InfoPanel
@onready var farm_area: Control = $FarmArea

# Controllers
var game_controller: GameController
var input_controller: InputController
var plot_controller: PlotController

func _ready():
    _initialize_controllers()
    _connect_components()

func _initialize_controllers():
    game_controller = GameController.new()
    add_child(game_controller)

    input_controller = InputController.new()
    add_child(input_controller)

    plot_controller = PlotController.new()
    add_child(plot_controller)

func _connect_components():
    # Connect input -> actions
    input_controller.key_plant_pressed.connect(action_panel.plant_wheat_pressed.emit)

    # Connect actions -> game controller
    action_panel.plant_wheat_pressed.connect(_on_plant_wheat)
    action_panel.harvest_pressed.connect(_on_harvest)

    # Connect game controller -> UI updates
    game_controller.resources_changed.connect(resource_panel.update_resources)
    game_controller.goal_updated.connect(goal_panel.update_goal)
    game_controller.info_message.connect(info_panel.show_message)
    game_controller.action_button_states_changed.connect(action_panel.update_button_states)

    # Connect plot controller
    plot_controller.plot_selected.connect(_on_plot_selected)
    plot_controller.plot_double_tapped.connect(_on_plot_double_tapped)

func _on_plant_wheat():
    var pos = plot_controller.get_selected()
    if game_controller.plant_wheat(pos):
        # Success handled by game controller signals
        pass

# ... minimal glue code
```

---

## File Size Breakdown (After Refactoring)

| File | Lines | Responsibility |
|------|-------|----------------|
| **FarmView.gd** | ~300 | Scene orchestration, signal routing |
| **ResourcePanel.gd** | ~150 | Resource display |
| **ActionPanel.gd** | ~250 | Action buttons |
| **GoalPanel.gd** | ~100 | Goal display |
| **InfoPanel.gd** | ~50 | Status messages |
| **GameController.gd** | ~400 | Game logic coordination |
| **InputController.gd** | ~200 | Input handling |
| **PlotController.gd** | ~200 | Plot selection/navigation |
| **Total** | ~1650 | (vs 1826 monolith) |

---

## Benefits

✅ **Single Responsibility**: Each component does ONE thing
✅ **Testability**: Can test components in isolation
✅ **Reusability**: ResourcePanel can be used anywhere
✅ **Maintainability**: Easy to find where specific logic lives
✅ **Collaboration**: Multiple devs can work on different panels
✅ **Scene Composition**: Can preview UI components in editor
✅ **Signal-Based**: Loose coupling via signals (Godot best practice)

---

## Migration Strategy (Low Risk)

### Option A: Gradual Extraction (Safer)
1. Create new component files alongside FarmView
2. Move code incrementally, one component at a time
3. Test after each extraction
4. Delete old code only after new works

### Option B: Big Bang Refactor (Faster)
1. Create all new files at once
2. Move all code in one pass
3. Fix compilation errors
4. Comprehensive testing

**Recommendation**: Option A (gradual) - less risky, easier to revert

---

## Next Steps

1. ✅ **Review this plan** - Get user approval
2. 🔨 **Phase 1.1**: Extract ResourcePanel (lowest risk)
3. 🔨 **Phase 1.2**: Extract ActionPanel
4. 🔨 **Phase 1.3**: Extract GoalPanel
5. 🔨 **Phase 1.4**: Extract InfoPanel
6. 🔨 **Phase 1.5**: Create GameController
7. 🔨 **Phase 1.6**: Create InputController
8. 🔨 **Phase 1.7**: Create PlotController
9. 🔨 **Phase 2**: Refactor FarmView to orchestrator

**Estimated Time**: 1-2 hours if done carefully with testing between steps

---

## Questions to Consider

1. **Scenes vs Scripts?**
   - Create `.tscn` scenes for UI components (recommended)
   - Or just `.gd` scripts instantiated in code?

2. **Folder Structure?**
   ```
   UI/
   ├── Panels/
   │   ├── ResourcePanel.tscn
   │   ├── ResourcePanel.gd
   │   ├── ActionPanel.tscn
   │   ├── ActionPanel.gd
   │   ├── GoalPanel.tscn
   │   └── GoalPanel.gd
   ├── Controllers/
   │   ├── GameController.gd
   │   ├── InputController.gd
   │   └── PlotController.gd
   └── FarmView.tscn
   ```

3. **Use Autoload for Controllers?**
   - GameController as singleton?
   - Or keep as instance in FarmView?

---

## Anti-Patterns to Avoid

❌ **Don't**: Have panels directly access game systems
❌ **Don't**: Have game controller directly access UI elements
❌ **Don't**: Use `get_node()` to find siblings
❌ **Don't**: Create circular dependencies

✅ **Do**: Use signals for all communication
✅ **Do**: Pass data through method parameters
✅ **Do**: Keep components independent
✅ **Do**: Let FarmView orchestrate everything

---

**Ready to proceed?** Which phase should we start with?
