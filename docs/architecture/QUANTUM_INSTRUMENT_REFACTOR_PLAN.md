# Quantum Instrument Headless Refactor Plan

## 🎯 Goal
Extract headless input state from `QuantumInstrumentInput` (UI Node) into `QuantumInstrumentState` (headless RefCounted), making the UI a pure projection layer.

**Pattern**: Following Register→Plot→Terminal architecture
- Register (quantum) → BasePlot (simulation) → Terminal (UI proxy)
- QuantumComputer (headless) → QuantumInstrumentState (headless) → QuantumInstrumentInput (UI)

---

## 📐 Architecture

### **Before (Current)**
```
QuantumInstrumentInput (extends Node - UI-bound)
├── Input state (_current_submenu, _in_submenu, checked_plots)
├── Selection state (current_selection, last_selected_plot_position)
├── Submenu logic (_generate_vocab_injection_submenu)
├── Action execution (execute_tool_action, execute_submenu_action)
├── UI updates (plot_grid_display.set_selected_plot)
└── Keyboard input handling (_unhandled_key_input)

SubmenuManager (extends RefCounted - UNUSED)
└── Dead code, never instantiated
```

### **After (Target)**
```
[Headless Core - extends RefCounted]
QuantumInstrumentState
├── SelectionState (biome, plot_idx, checked_plots)
├── SubmenuState (current, page, in_submenu)
├── ToolState (current_group, mode_indices)
├── handle_action_key(key, context) -> ActionResult
├── enter_submenu(name, context) -> SubmenuData
├── toggle_plot_check(pos) -> CheckResult
└── get_available_actions(context) -> Array[Action]

[UI Projection - extends Node]
QuantumInstrumentInput
├── _state: QuantumInstrumentState (owns headless state)
├── plot_grid_display (UI reference)
├── _unhandled_key_input(event) -> calls _state, updates UI
├── _update_ui_from_state() -> projects state to PlotGridDisplay
└── Signal emissions (for overlays to listen)
```

---

## 📋 Implementation Steps

### **Phase 1: Create Headless State Class**

**File**: `Core/Input/QuantumInstrumentState.gd`

```gdscript
class_name QuantumInstrumentState
extends RefCounted

## Headless quantum instrument state machine
## No UI dependencies - can be used for:
## - UI (QuantumInstrumentInput)
## - Headless tests
## - AI players
## - Automation scripts
## - Network server

# ============================================================================
# STATE
# ============================================================================

## Selection state
var current_biome: String = ""
var current_plot_idx: int = -1
var last_selected_position: Vector2i = Vector2i(-1, -1)
var checked_plots: Array[Vector2i] = []  # Multi-select

## Submenu state
var current_submenu_name: String = ""
var current_submenu_data: Dictionary = {}
var submenu_page: int = 0

## Tool state
var current_tool_group: int = 3
var tool_mode_indices: Dictionary = {}  # Per-tool mode tracking

# ============================================================================
# ACTION EXECUTION
# ============================================================================

func handle_action_key(key: String, context: Dictionary) -> Dictionary:
	"""Execute action for key (Q/E/R) in current context.

	Args:
		key: Action key ("Q", "E", "R")
		context: {farm, biome, position, economy, ...}

	Returns:
		{
			"success": bool,
			"action": String,
			"message": String,
			"invalidates_buffer": bool,
			"submenu_changed": bool,
			"selection_changed": bool
		}
	"""
	if is_in_submenu():
		return _execute_submenu_action(key, context)
	else:
		return _execute_tool_action(key, context)

# ============================================================================
# SUBMENU MANAGEMENT
# ============================================================================

func enter_submenu(name: String, context: Dictionary) -> Dictionary:
	"""Enter a submenu, generating its content.

	Args:
		name: Submenu identifier ("vocab_injection", "gate_selection")
		context: {farm, biome, position, selection}

	Returns:
		Submenu data dict with Q/E/R actions
	"""
	submenu_page = 0
	current_submenu_name = name

	# Generate submenu using headless generators
	if name == "vocab_injection":
		var VocabInjectionSubmenu = load("res://UI/Core/Submenus/VocabInjectionSubmenu.gd")
		current_submenu_data = VocabInjectionSubmenu.generate_submenu(
			context.biome, context.farm, submenu_page
		)
	elif name == "gate_selection":
		var GateSelectionSubmenu = load("res://UI/Core/Submenus/GateSelectionSubmenu.gd")
		current_submenu_data = GateSelectionSubmenu.generate_submenu(
			context.biome, context.farm, checked_plots, submenu_page
		)
	else:
		push_error("Unknown submenu: %s" % name)
		return {}

	return current_submenu_data

func exit_submenu() -> void:
	"""Exit current submenu."""
	current_submenu_name = ""
	current_submenu_data = {}
	submenu_page = 0

func cycle_submenu_page(context: Dictionary) -> Dictionary:
	"""Cycle to next page (F key), regenerate submenu."""
	submenu_page += 1
	return enter_submenu(current_submenu_name, context)

func is_in_submenu() -> bool:
	return current_submenu_name != ""

# ============================================================================
# SELECTION MANAGEMENT
# ============================================================================

func select_plot(plot_idx: int, biome_name: String, position: Vector2i) -> Dictionary:
	"""Select a plot, updating state.

	Returns:
		{selection_changed: bool, old_idx, new_idx, old_biome, new_biome}
	"""
	var old_idx = current_plot_idx
	var old_biome = current_biome

	current_plot_idx = plot_idx
	current_biome = biome_name
	last_selected_position = position

	return {
		"selection_changed": old_idx != plot_idx or old_biome != biome_name,
		"old_idx": old_idx,
		"new_idx": plot_idx,
		"old_biome": old_biome,
		"new_biome": biome_name
	}

func toggle_plot_check(position: Vector2i) -> Dictionary:
	"""Toggle multi-select checkbox for plot.

	Returns:
		{is_checked: bool, position: Vector2i}
	"""
	var idx = checked_plots.find(position)
	if idx >= 0:
		checked_plots.remove_at(idx)
		return {"is_checked": false, "position": position}
	else:
		checked_plots.append(position)
		return {"is_checked": true, "position": position}

func clear_checked_plots() -> void:
	"""Clear all checked plots."""
	checked_plots.clear()

# ============================================================================
# TOOL MANAGEMENT
# ============================================================================

func set_tool_group(group: int) -> Dictionary:
	"""Switch to tool group (1-4).

	Returns:
		{group: int, changed: bool}
	"""
	var old_group = current_tool_group
	current_tool_group = group
	return {"group": group, "changed": old_group != group}

func cycle_tool_mode(context: Dictionary) -> Dictionary:
	"""Cycle mode within current tool (F key when not in submenu).

	Returns:
		{group: int, mode_index: int, mode_label: String}
	"""
	var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
	var new_index = ToolConfig.cycle_group_mode(current_tool_group)
	var mode_label = ToolConfig.get_group_mode_label(current_tool_group)

	return {
		"group": current_tool_group,
		"mode_index": new_index,
		"mode_label": mode_label
	}

# ============================================================================
# QUERY INTERFACE (for AI/automation)
# ============================================================================

func get_available_actions(context: Dictionary) -> Array:
	"""Get list of all available actions in current state.

	Used by:
	- AI players (to choose actions)
	- UI (to show enabled/disabled buttons)
	- Tests (to validate state)

	Returns:
		Array of {key: String, action: String, enabled: bool, cost: Dictionary}
	"""
	var actions: Array = []

	if is_in_submenu():
		# Return Q/E/R from submenu
		for key in ["Q", "E", "R"]:
			if current_submenu_data.get("actions", {}).has(key):
				var action_data = current_submenu_data["actions"][key]
				actions.append({
					"key": key,
					"action": action_data.get("action", ""),
					"enabled": action_data.get("enabled", true),
					"cost": action_data.get("cost", {}),
					"label": action_data.get("label", "")
				})
	else:
		# Return tool actions (Q/E/R based on current tool)
		var ToolConfig = load("res://Core/GameState/ToolConfig.gd")
		var tool_group = ToolConfig.get_group(current_tool_group)
		var mode_index = ToolConfig.get_group_mode_index(current_tool_group)
		var tool_actions = tool_group.get("modes", [[]])[mode_index]

		for i in range(min(3, tool_actions.size())):
			var action_key = ["Q", "E", "R"][i]
			var action_name = tool_actions[i]
			actions.append({
				"key": action_key,
				"action": action_name,
				"enabled": true,  # TODO: Check affordability
				"cost": {},       # TODO: Get from EconomyConstants
				"label": action_name
			})

	return actions

func get_state_snapshot() -> Dictionary:
	"""Get complete state for serialization/debugging.

	Returns:
		Dictionary with all state fields
	"""
	return {
		"current_biome": current_biome,
		"current_plot_idx": current_plot_idx,
		"last_selected_position": last_selected_position,
		"checked_plots": checked_plots.duplicate(),
		"current_submenu_name": current_submenu_name,
		"submenu_page": submenu_page,
		"current_tool_group": current_tool_group,
		"tool_mode_indices": tool_mode_indices.duplicate()
	}

func restore_state(snapshot: Dictionary) -> void:
	"""Restore state from snapshot."""
	current_biome = snapshot.get("current_biome", "")
	current_plot_idx = snapshot.get("current_plot_idx", -1)
	last_selected_position = snapshot.get("last_selected_position", Vector2i(-1, -1))
	checked_plots = snapshot.get("checked_plots", []).duplicate()
	current_submenu_name = snapshot.get("current_submenu_name", "")
	submenu_page = snapshot.get("submenu_page", 0)
	current_tool_group = snapshot.get("current_tool_group", 3)
	tool_mode_indices = snapshot.get("tool_mode_indices", {}).duplicate()

# ============================================================================
# PRIVATE HELPERS
# ============================================================================

func _execute_tool_action(key: String, context: Dictionary) -> Dictionary:
	"""Execute tool action (Q/E/R) based on current tool group."""
	# TODO: Implement action execution
	# This will call into existing handlers (GateActionHandler, etc.)
	return {"success": false, "message": "Not implemented"}

func _execute_submenu_action(key: String, context: Dictionary) -> Dictionary:
	"""Execute submenu action (Q/E/R) from current submenu."""
	var actions = current_submenu_data.get("actions", {})
	if not actions.has(key):
		return {"success": false, "message": "No action for key %s" % key}

	var action_data = actions[key]
	var action_name = action_data.get("action", "")

	# TODO: Execute action
	return {"success": false, "message": "Not implemented"}
```

---

### **Phase 2: Refactor QuantumInstrumentInput**

**File**: `UI/Core/QuantumInstrumentInput.gd`

```gdscript
class_name QuantumInstrumentInput
extends Node

## UI Projection for QuantumInstrumentState
## Handles keyboard input and updates PlotGridDisplay

# Headless state (owns the logic)
var _state: QuantumInstrumentState

# UI references (projection targets)
var farm
var plot_grid_display

# Signals (for UI overlays)
signal action_performed(action: String, result: Dictionary)
signal selection_changed(plot_idx: int, biome: String)
signal biome_switched(old_biome: String, new_biome: String)
signal tool_group_changed(group: int)
signal mode_cycled(group: int, mode_index: int, mode_label: String)
signal submenu_changed(submenu_name: String, submenu_actions: Dictionary)
signal plot_checked(grid_pos: Vector2i, is_checked: bool)

func _ready() -> void:
	_state = QuantumInstrumentState.new()
	add_to_group("quantum_instrument_input")
	set_process_unhandled_key_input(true)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	# Map keyboard event to action
	var key = _map_event_to_key(event)
	if key == "":
		return

	# Build context from current UI state
	var context = _build_context()

	# Execute action via headless state
	var result: Dictionary

	if key in ["Q", "E", "R"]:
		result = _state.handle_action_key(key, context)
	elif key == "F":
		if _state.is_in_submenu():
			result = _state.cycle_submenu_page(context)
		else:
			result = _state.cycle_tool_mode(context)
	elif key in ["J", "K", "L", ";"]:
		result = _handle_plot_selection(key, event.shift_pressed)
	# ... etc

	# Update UI based on result
	_update_ui_from_result(result)

	# Emit signals for overlays
	_emit_signals_from_result(result)

	get_viewport().set_input_as_handled()

func _update_ui_from_result(result: Dictionary) -> void:
	"""Project state changes to UI."""

	# Update plot grid visual selection
	if result.get("selection_changed", false):
		if plot_grid_display:
			var pos = _state.last_selected_position
			plot_grid_display.set_selected_plot(pos)

	# Update checkboxes
	if result.has("is_checked"):
		if plot_grid_display:
			plot_grid_display.set_plot_checked(
				result.position,
				result.is_checked
			)

	# Invalidate lookahead buffer if needed
	if result.get("invalidates_buffer", false):
		if farm and farm.has_method("invalidate_lookahead_buffer"):
			farm.invalidate_lookahead_buffer()

func _build_context() -> Dictionary:
	"""Build context dict from current UI state."""
	var biome = _get_current_biome()
	var position = _state.last_selected_position

	return {
		"farm": farm,
		"biome": biome,
		"position": position,
		"economy": farm.economy if farm else null,
		"selection": _state.checked_plots
	}

func _map_event_to_key(event: InputEvent) -> String:
	"""Map InputEvent to action key string."""
	# ... existing mapping logic ...
	return ""
```

---

### **Phase 3: Delete Dead Code**

**Files to delete:**
- `UI/Core/SubmenuManager.gd` (unused, replaced by QuantumInstrumentState)

**Code to remove from ToolConfig.gd:**
- `SUBMENUS = {}` (line 494)
- `get_submenu()` function (lines 496-498)
- `get_dynamic_submenu()` function (lines 501-503)
- `current_mode` variable (line 409)
- `tool_mode_indices` variable (line 412)

---

### **Phase 4: Update Tests**

**Create headless test:**
```gdscript
# Tests/test_quantum_instrument_headless.gd
extends GutTest

func test_headless_action_execution():
	var state = QuantumInstrumentState.new()

	# Set up context
	var context = {
		"farm": _create_test_farm(),
		"biome": _create_test_biome(),
		"position": Vector2i(0, 0)
	}

	# Execute action
	var result = state.handle_action_key("Q", context)

	assert_true(result.has("success"))
	assert_true(result.has("action"))

func test_submenu_state_machine():
	var state = QuantumInstrumentState.new()
	var context = _create_test_context()

	# Enter submenu
	assert_false(state.is_in_submenu())
	var submenu = state.enter_submenu("vocab_injection", context)
	assert_true(state.is_in_submenu())
	assert_true(submenu.has("actions"))

	# Cycle page
	state.cycle_submenu_page(context)
	assert_eq(state.submenu_page, 1)

	# Exit
	state.exit_submenu()
	assert_false(state.is_in_submenu())

func test_ai_query_interface():
	var state = QuantumInstrumentState.new()
	var context = _create_test_context()

	# Get available actions
	var actions = state.get_available_actions(context)
	assert_gt(actions.size(), 0)

	for action in actions:
		assert_has(action, "key")
		assert_has(action, "action")
		assert_has(action, "enabled")
```

---

## 🔄 Migration Strategy

### **Incremental Approach (Recommended)**

**Step 1**: Create `QuantumInstrumentState` with minimal functionality
- Selection state only
- No action execution yet
- Test with headless unit tests

**Step 2**: Migrate submenu state
- Move `_current_submenu`, `_in_submenu`, `_submenu_page` to state
- Test submenu enter/exit/cycle

**Step 3**: Migrate action execution
- Move `_execute_tool_action`, `_execute_submenu_action` to state
- Keep handlers (GateActionHandler, etc.) as dependencies

**Step 4**: Update QuantumInstrumentInput to use state
- Replace direct state access with `_state.*`
- Add `_update_ui_from_result()` projection

**Step 5**: Delete dead code
- Remove SubmenuManager
- Remove ToolConfig dead functions

**Step 6**: Test with existing tests
- Run all Tests/ to ensure nothing broke
- Run 🍄 milk_hunt scripts

---

## ✅ Acceptance Criteria

1. **Headless tests pass** - Can create QuantumInstrumentState without scene tree
2. **UI tests pass** - All existing Tests/ still work
3. **No logic duplication** - QuantumInstrumentInput is thin wrapper
4. **AI can use it** - `get_available_actions()` returns valid action list
5. **State is serializable** - `get_state_snapshot()` / `restore_state()` work
6. **No UI dependencies in core** - QuantumInstrumentState extends RefCounted, no Node references

---

## 📊 Impact Analysis

**Files changed:**
- New: `Core/Input/QuantumInstrumentState.gd`
- Modified: `UI/Core/QuantumInstrumentInput.gd` (major refactor)
- Deleted: `UI/Core/SubmenuManager.gd`
- Modified: `Core/GameState/ToolConfig.gd` (remove dead code)

**Tests needed:**
- New: `Tests/test_quantum_instrument_headless.gd`
- Update: Any tests that directly instantiate QuantumInstrumentInput
- Existing: All 🍄 milk_hunt scripts should pass

**Breaking changes:**
- None (QuantumInstrumentInput API stays the same)
- Internal refactor only

---

## 🎯 Benefits

1. **DRY** - Input logic written once, used everywhere
2. **Testable** - Headless tests don't need UI/scene tree
3. **AI-ready** - `get_available_actions()` for AI players
4. **Serializable** - Save/restore input state
5. **Consistent** - Follows Register→Plot→Terminal pattern
6. **Maintainable** - Clear separation of concerns (core vs UI)

---

## 📝 Next Steps

1. Review this plan
2. Create Phase 1 branch: `refactor/quantum-instrument-headless`
3. Implement QuantumInstrumentState incrementally
4. Test each phase before proceeding
5. Merge when all tests pass
