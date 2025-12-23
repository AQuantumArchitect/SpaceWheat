# GameStateManager ↔ FarmView Integration Guide

## Architecture Overview

The UI is now completely **decoupled from simulation**:

```
┌─────────────────────────────────────────────────────┐
│  MAIN SCENE / Game Entry Point                      │
├─────────────────────────────────────────────────────┤
│                                                     │
│  1. Load: UITestOnly.tscn (FarmView + FarmUIController)
│  2. FarmView displays with placeholder/empty data  │
│  3. GameStateManager loads game from save file     │
│  4. GameStateManager calls: farm_view.inject_farm() │
│  5. FarmUIController reinitializes with farm data  │
│  6. UI becomes fully interactive                   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## UI Loading Flow (Current - Without Simulation)

### FarmView._ready()
```gdscript
ui_controller = FarmUIController.new()
add_child(ui_controller)
# Farm NOT injected yet - UI displays with placeholder data
```

### FarmUIController._ready()
1. Creates UILayoutManager (parametric scaling)
2. Creates UI structure (top_bar, play_area, etc.)
3. Creates managers (OverlayManager for C/V/N/ESC menus)
4. Creates UI components (ResourcePanel, GoalPanel, etc.)
5. Creates visualization systems (QuantumGraph, EntanglementLines)
6. Creates input handlers (FarmInputHandler for keyboard, InputController for overlays)
7. **Skips** farm signal connections (farm is null)
8. Displays empty/placeholder data

### Result
✅ UI loads cleanly without any game simulation
✅ Keyboard input handlers ready (can test input before simulation loads)
✅ Layout system responsive (resize window to test)
✅ Overlays can be toggled (C/V/N/ESC keys)

---

## Simulation Injection Flow (Future - With GameStateManager)

### GameStateManager.load_game(slot: int)
```gdscript
# 1. Load save file
var state = load_save_file(slot)

# 2. Create simulation
var farm = Farm.new()
farm.initialize()
farm.apply_state(state)

# 3. Inject into UI (THIS IS THE KEY STEP)
var farm_view = get_node("FarmView")  # Or find it however your scene structure works
farm_view.inject_farm(farm)

# 4. Resume game
get_tree().paused = false
```

### FarmView.inject_farm(farm_ref)
```gdscript
# Simply delegates to UIController
if ui_controller:
    ui_controller.inject_farm_late(farm_ref)
```

### FarmUIController.inject_farm_late(farm_ref: Farm)
```gdscript
# 1. Store farm reference
farm = farm_ref

# 2. Reinitialize visualization systems with farm data
quantum_graph.initialize(farm.grid, center, radius)
entanglement_lines.initialize(farm.grid, layout_manager)

# 3. Reconnect all farm signals
_connect_farm_signals()

# 4. Update UI displays with farm data
mark_dirty()
_update_ui()
```

### Result
✅ Simulation data flows into UI
✅ All signal connections activated
✅ Farm events trigger UI updates
✅ Game becomes fully playable

---

## Key Integration Points

### 1. FarmView Public API
```gdscript
func inject_farm(farm_ref) -> void
    """Called by GameStateManager after loading save game"""

func show_message(text: String) -> void
func show_error(text: String) -> void
func get_selected_plot() -> Vector2i
```

### 2. FarmUIController Public API
```gdscript
func inject_farm_late(farm_ref: Farm) -> void
    """Inject farm after UI initialized - handles reinitialization"""

func mark_dirty() -> void
    """Mark UI as needing update (batched each frame)"""

func show_message(text: String) -> void
func show_error(text: String) -> void
func get_current_selected_plot() -> Vector2i
```

### 3. Signal Flow (Once Farm Injected)

**Farm → UI:**
```
Farm.plots_entangled → _on_plots_entangled() → mark_dirty()
Farm.economy.credits_changed → _on_credits_changed() → mark_dirty()
Farm.goals.active_goal_changed → _on_active_goal_changed() → update display
Biome.phase_changed → _on_biome_phase_changed() → update sun/moon
Biome.temperature_changed → _on_biome_temperature_changed() → update temp
```

**Input → Farm:**
```
FarmInputHandler.tool_changed → _on_tool_changed() → update action buttons
FarmInputHandler.selection_changed → _on_plot_selected() → highlight plot
FarmInputHandler.action_executed → _on_action_executed() → show feedback
```

---

## Testing Checklist

### Before GameStateManager Integration
- [x] UI loads without crashing
- [x] Keyboard input handlers initialize
- [x] Layout scales responsively
- [x] Overlays toggle (C/V/N/ESC keys)
- [x] Placeholder data displays

### After GameStateManager Integration
- [ ] GameStateManager loads save file
- [ ] farm_view.inject_farm(farm) called
- [ ] UI updates with farm data
- [ ] Keyboard input affects simulation
- [ ] Farm events update UI
- [ ] Save/load works end-to-end

---

## Implementation Checklist for GameStateManager

To integrate GameStateManager with the new UI architecture:

1. **Create GameStateManager** (if not already exists)
   - Autoload that manages save/load
   - Has load_game(slot) and save_game(slot) methods

2. **Update main scene**
   - Instantiate FarmView first (UI-only mode)
   - Call GameStateManager.load_game(slot) after scene ready
   - GameStateManager will call farm_view.inject_farm(farm)

3. **Handle initialization order**
   - FarmView._ready() → FarmUIController initializes empty UI
   - GameStateManager.load_game() → creates farm + injects into UI
   - No circular dependencies ✓

4. **Connect save trigger**
   - On pause menu "Save" button → GameStateManager.save_game(slot)
   - Capture farm.get_state() and save to file

5. **Test save/load cycle**
   - Load game → UI displays data ✓
   - Play (change resources/plots) → Farm updates ✓
   - Save game → Farm state serialized ✓
   - Load game again → Same state restored ✓

---

## Files Changed/Created

**New Files:**
- `/home/tehcr33d/ws/SpaceWheat/UI/FarmUIController.gd` - Orchestration layer
- `/home/tehcr33d/ws/SpaceWheat/UITestOnly.tscn` - Minimal test scene

**Modified Files:**
- `/home/tehcr33d/ws/SpaceWheat/UI/FarmView.gd` - Simplified to coordinator
- `/home/tehcr33d/ws/SpaceWheat/Core/Farm.gd` - Fixed .get() syntax
- `/home/tehcr33d/ws/SpaceWheat/UI/Managers/OverlayManager.gd` - Disabled SaveLoadMenu
- Various others for null-farm resilience

---

## Next Steps

1. **Create/Update GameStateManager**
   - Implement save/load functionality
   - Add load_game(slot) method that calls farm_view.inject_farm()

2. **Set up main game scene**
   - Instantiate FarmView (this becomes the main UI container)
   - Connect GameStateManager to trigger after initial load

3. **Test end-to-end**
   - Load game from save file
   - Verify UI displays farm data correctly
   - Verify keyboard input affects simulation
   - Verify save game captures state

4. **Iterate UI improvements** (Phase 5+)
   - Extract PlotTileManager (more componentization)
   - Add animations/transitions
   - Optimize rendering for large farms

---

## Philosophy: Decoupled Architecture

This design follows **separation of concerns**:

- **UI Layer** (FarmView/FarmUIController): Display and input
- **Simulation Layer** (Farm/FarmGrid): Game logic
- **State Layer** (GameStateManager): Save/load/data persistence

Benefits:
✅ UI can be tested without simulation
✅ Simulation can be tested without UI
✅ Easy to swap out UI later (different game modes, etc.)
✅ Clean data flow: State → Simulation ← UI
✅ No circular dependencies

This is a professional, scalable architecture for game development.
