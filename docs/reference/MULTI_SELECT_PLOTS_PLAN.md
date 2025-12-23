# Multi-Select Batch Plot Operations - Implementation Plan

**Status:** DESIGN PHASE
**Complexity:** Medium-High
**Estimated Scope:** 4-6 files modified/created

---

## Feature Overview

Transform from single-plot selection to multi-select checkbox system where users can:
1. Select multiple plots with T/Y/U/I/O/P keys (toggle checkboxes)
2. Apply batch actions to all selected plots:
   - **Q** = Plant with energy injection (creation operator, 0.2🌾+0.1👥 → 0.3 quantum radius)
   - **E** = Grow (apply evolution to selected)
   - **R** = Harvest/Clip (auto-measure first, then harvest)
3. Manage selection:
   - **[** = Deselect all plots
   - **]** = Restore previous selection state

---

## Architecture Design

### Component 1: PlotSelectionManager.gd (NEW)

**Purpose:** Centralized management of multi-select state

**Public Interface:**
```gdscript
class_name PlotSelectionManager
extends RefCounted

var selected_plots: Array[Vector2i] = []  # Currently selected
var previous_state: Array[Vector2i] = []  # For restoration with ]

func toggle_plot(pos: Vector2i) -> bool
  # Add to selection if not present, remove if present
  # Returns: true if now selected, false if now deselected

func is_selected(pos: Vector2i) -> bool
  # Check if a plot is in current selection

func get_selected() -> Array[Vector2i]
  # Return copy of selected plots

func clear_selection() -> void
  # Deselect all plots

func save_state() -> void
  # Save current selection to previous_state (for ] key)

func restore_state() -> void
  # Restore selection from previous_state

func get_count() -> int
  # Return number of selected plots

func _to_string() -> String
  # Debug output: "3 plots selected"
```

**Implementation Notes:**
- Use Array instead of Set for order preservation
- Store both current and previous state
- Save state whenever selection changes (before action)

---

### Component 2: PlotTile.gd (MODIFIED)

**Changes:**
- Keep existing border visuals, add checkbox indicator
- Show checked/unchecked visual state
- Add method `update_selection(is_selected)`

**Visual Changes:**
```
Current (single select):  [▌Border only when selected]

New (multi-select):       [☐ Checkbox]  OR  [☑ Checked]
                          [Border visible when selected]
```

**Methods to Add:**
```gdscript
func set_selection_checkbox(is_selected: bool) -> void
  # Visual: draw checkbox (□ or ☑)
  # Update border as before
  # Show count of selected if < 5

func get_checkbox_label() -> String
  # Return "☐" or "☑" based on selection state
```

**Implementation Approach:**
- Reuse existing selection_border
- Add Label or TextureRect for checkbox icon
- Update in `_process()` or on signal from SelectionManager

---

### Component 3: PlotGridDisplay.gd (MODIFIED)

**Key Changes:**
- Replace `current_selection: Vector2i` with `selection_manager: PlotSelectionManager`
- Handle checkbox updates for all tiles
- Update visuals when selection changes

**Methods to Modify:**
```gdscript
func _ready() -> void
  # Create SelectionManager instead of tracking current_selection
  selection_manager = PlotSelectionManager.new()

func _on_plot_clicked(pos: Vector2i) -> void
  # NEW: Toggle selection instead of replace
  var was_selected = selection_manager.toggle_plot(pos)
  _update_plot_tile_visuals(pos, was_selected)
  _emit_selection_changed()

func _on_location_key_pressed(location: Vector2i) -> void
  # MODIFIED: T/Y/U/I/O/P now toggle selection
  selection_manager.save_state()  # For ] restoration
  var now_selected = selection_manager.toggle_plot(location)
  _update_plot_tile_visuals(location, now_selected)
  _emit_selection_changed()

func _update_plot_tile_visuals(pos: Vector2i) -> void
  # Update checkbox and border for a single tile

func _emit_selection_changed() -> void
  # Signal that selection changed
  # FarmInputHandler listens and can execute batch actions

signal selection_changed(selected_plots: Array[Vector2i])
```

**Visual Update Flow:**
```
selection_manager.toggle_plot(pos)
  ↓
PlotGridDisplay._on_selection_changed()
  ↓
For each plot in grid:
  plot_tile.set_selection_checkbox(selection_manager.is_selected(plot.pos))
```

---

### Component 4: FarmInputHandler.gd (MODIFIED - Major)

**Current Behavior:**
```
T/Y/U/I/O/P → Select plot → Immediately ready to act
Q/E/R → Act on current_selection
```

**New Behavior:**
```
T/Y/U/I/O/P → Toggle plot selection (checkbox on/off)
[ → Deselect all
] → Restore previous selection
Q/E/R → Act on ALL selected plots

Tool selection (1-3) still works as before
```

**Key Method Changes:**

```gdscript
func _on_selection_changed(selected_plots: Array[Vector2i]) -> void
  # NEW: Called when checkbox selection changes
  # Store selected_plots for batch action execution

func _input(event: InputEvent) -> void
  # MODIFY: Handle new T/Y/U/I/O/P behavior

  if event.is_action_pressed("select_plot_t"):
    _toggle_plot_selection(Vector2i(0, 0))  # T toggles plot 0
  elif event.is_action_pressed("select_plot_y"):
    _toggle_plot_selection(Vector2i(1, 0))  # Y toggles plot 1
  # ... same for U, I, O, P ...

  elif event.is_action_pressed("ui_text_clear_carets"):  # [ key
    _clear_all_selection()
  elif event.is_action_pressed("ui_text_caret_document_end"):  # ] key (or other)
    _restore_previous_selection()

func _execute_tool_action(action: String) -> void
  # MODIFY: Changed to handle batch operations

  if action == "Q":
    if current_tool == PLANT_TOOL:
      _batch_plant_with_energy(selected_plots)  # NEW
    elif current_tool == QUANTUM_OPS_TOOL:
      _batch_entangle_first_pair(selected_plots)  # Rethink for multi
  elif action == "E":
    if current_tool == PLANT_TOOL:
      _batch_grow(selected_plots)  # NEW
    elif current_tool == QUANTUM_OPS_TOOL:
      _batch_measure_all(selected_plots)  # NEW
  elif action == "R":
    if current_tool == PLANT_TOOL:
      _batch_harvest_clip(selected_plots)  # Measure + harvest
    elif current_tool == QUANTUM_OPS_TOOL:
      _batch_entangle_adjacent(selected_plots)  # Rethink
    elif current_tool == ECONOMY_TOOL:
      _process_flour()  # Unchanged

func _toggle_plot_selection(pos: Vector2i) -> void
  # NEW: Toggle selection on click/key
  selection_manager.toggle_plot(pos)
  # Visuals update automatically via signal

func _clear_all_selection() -> void
  # NEW: Clear all selected plots
  selection_manager.clear_selection()
  # Visuals update

func _restore_previous_selection() -> void
  # NEW: Restore from before last action
  selection_manager.restore_state()
  # Visuals update
```

**Signals to Emit:**
```gdscript
signal batch_plant_requested(positions: Array[Vector2i], plant_type: String)
signal batch_grow_requested(positions: Array[Vector2i])
signal batch_harvest_requested(positions: Array[Vector2i])
signal selection_changed(count: int)
```

---

### Component 5: Farm.gd (MODIFIED - Batch Methods)

**New Batch Action Methods:**

```gdscript
func batch_plant_with_energy(positions: Array[Vector2i], cost_wheat: float, cost_labor: float, energy_inject: float) -> Dictionary
  # Plant with energy injection for multiple plots
  # Check: economy has enough resources
  # For each position:
  #   - Deduct cost from economy
  #   - Call grid.plant() with energy_inject
  # Return: {success: bool, planted: int, failed: int, message: String}

func batch_grow(positions: Array[Vector2i]) -> Dictionary
  # Apply growth/evolution to selected plots
  # For each position:
  #   - Apply growth evolution
  # Return: {success: bool, grew: int, failed: int}

func batch_harvest(positions: Array[Vector2i]) -> Dictionary
  # Measure then harvest all selected plots
  # For each position:
  #   - Call measure_plot(pos)
  #   - Call harvest_plot(pos)
  # Return: {success: bool, harvested: int, resources: Dictionary}

func batch_measure(positions: Array[Vector2i]) -> Dictionary
  # Measure quantum state of selected plots
  # For each position:
  #   - Call measure_plot(pos)
  # Return: {success: bool, measured: int}
```

**Implementation Pattern:**
```gdscript
func batch_plant_with_energy(positions: Array[Vector2i], ...) -> Dictionary:
  var results = {
    "success": false,
    "planted": 0,
    "failed": 0,
    "message": ""
  }

  # Check economy has enough for all
  if not economy.can_afford_multiple(positions.size(), cost_wheat, cost_labor):
    results["message"] = "Not enough resources for all plots"
    return results

  # Execute batch
  for pos in positions:
    # Deduct cost once
    if build(pos, "wheat"):
      results["planted"] += 1
    else:
      results["failed"] += 1

  results["success"] = results["planted"] > 0
  results["message"] = "Planted %d/%d plots" % [results["planted"], positions.size()]
  return results
```

---

## Implementation Steps

### Step 1: Create PlotSelectionManager.gd
- Create new file with class definition
- Implement toggle/clear/restore logic
- Write simple unit test logic

### Step 2: Update PlotTile.gd
- Add checkbox visual (Label with ☐/☑)
- Add `set_selection_checkbox()` method
- Keep existing border logic

### Step 3: Update PlotGridDisplay.gd
- Create SelectionManager instance in `_ready()`
- Change selection handling from single to multi-select
- Emit signal when selection changes
- Update tile visuals on changes

### Step 4: Update FarmInputHandler.gd
- Connect to selection_changed signal
- Modify T/Y/U/I/O/P to toggle instead of select
- Add [ and ] key handlers
- Refactor Q/E/R to use batch methods

### Step 5: Add Batch Methods to Farm.gd
- Add batch_plant_with_energy()
- Add batch_grow()
- Add batch_harvest()
- Add batch_measure()

### Step 6: Integration & Testing
- Wire FarmInputHandler signals to Farm batch methods
- Test multi-select with T/Y/U/I/O/P
- Test batch actions Q/E/R
- Test [ ] for deselect/restore

---

## Key Design Decisions

### 1. Selection is Persistent
- Selecting multiple plots persists until user deselects
- Actions apply to whatever is selected
- Allows sequential operations on same batch

### 2. Checkbox vs Border
- Checkbox shows "selected" state visually
- Border can show "hovered" or "focused" state
- Both visible for clarity

### 3. [ and ] Keys
- [ clears immediately
- ] restores previous state (saved before last action)
- Allows quick undo of selection changes

### 4. Batch vs Individual
- All actions apply to all selected plots
- No primary/secondary plot concept
- Simpler UI, clearer intent

### 5. Entanglement Rethinking
- Current entanglement: select 1, press Q, then select 2nd, press again
- Multi-select: needs rethinking (maybe select 2, press Q?)
- Keep for now, address separately

---

## Edge Cases to Handle

1. **Empty Selection** - What if no plots selected and Q/E/R pressed?
   - Should show message "No plots selected"
   - Don't allow action

2. **Partial Success** - What if some plots fail?
   - Harvest: if one fails, continue with others
   - Return count of successful operations
   - Show message: "Harvested 3/4 plots"

3. **Out of Resources** - Can't afford action for all selected?
   - Option A: Check economy before batch, allow all-or-nothing
   - Option B: Execute until resources depleted
   - Recommend: Option A (all-or-nothing is clearer)

4. **Selection Overflow** - Too many plots selected?
   - No limit needed (6x1 grid = max 6 plots)
   - UI can show "6 selected"

---

## Data Flow Diagram

```
User Input (T/Y/U/I/O/P)
    ↓
FarmInputHandler._input()
    ↓
PlotGridDisplay._toggle_plot_selection(pos)
    ↓
PlotSelectionManager.toggle_plot(pos)
    ↓
PlotGridDisplay.selection_changed signal
    ↓
PlotTile.set_selection_checkbox()  (visual update)
    ↓
[Plots display checkboxes]

─────────────────────────

User Action (Q/E/R)
    ↓
FarmInputHandler._execute_tool_action()
    ↓
FarmInputHandler.batch_plant/grow/harvest_requested signal
    ↓
Farm.batch_plant/grow/harvest()
    ↓
Farm updates grid and economy
    ↓
FarmUIState.update_plots() (for each affected plot)
    ↓
PlotTile visual updates (resource counts, plant growth, etc)
```

---

## Success Criteria

✅ Can select multiple plots with T/Y/U/I/O/P
✅ Checkboxes show selected state visually
✅ Q applies plant-with-energy to all selected
✅ E applies grow to all selected
✅ R measures then harvests all selected
✅ [ clears all selection
✅ ] restores previous selection
✅ Actions fail gracefully if no plots selected
✅ Batch operations complete successfully for multi-select
✅ No breaking changes to existing single-plot UI

---

## Open Questions

1. **Quantum Entanglement with Multi-Select:**
   - How should Q work in QUANTUM_OPS tool with multiple plots?
   - Current: click 1, Q, click 2, Q creates entanglement
   - Multi-select: Maybe Q entangles all pairs?
   - **Decision needed:** Entangle all-to-all, or disable in multi-select?

2. **Measure with Multi-Select:**
   - In QUANTUM_OPS, E is currently measure
   - Multi-select E should measure all? (yes, batch_measure)
   - **Confirmation:** Yes, batch measure

3. **Economy Cost:**
   - Plant-with-energy: does each plot cost resources?
   - Yes: 0.2🌾 + 0.1👥 per plot
   - Check: Can we afford for ALL selected, then execute all
   - **Confirmation:** All-or-nothing approach

---

## Ready for Implementation?

**YES** - Plan is complete and ready to code. All components identified, data flow clear, edge cases documented.

**Start with:** PlotSelectionManager.gd (foundation), then update UI components bottom-up.
