# Quantum Instrument Refactor - Implementation Status

## 📊 Progress: Phase 2 Complete (40%)

**Date**: 2026-02-14
**Branch**: main
**Goal**: Extract headless core from QuantumInstrumentInput following Register→Plot→Terminal pattern

---

## ✅ Completed

### **Phase 1: Headless State Class** ✅
**File**: `Core/Input/QuantumInstrumentState.gd`

Created fully functional headless state machine:
- ✅ Selection state management (biome, plot, checked_plots)
- ✅ Submenu lifecycle (enter, exit, cycle_page)
- ✅ Tool group management (switch, cycle_mode)
- ✅ Action execution framework (_execute_tool_action, _execute_submenu_action)
- ✅ Query interface for AI (get_available_actions)
- ✅ Serialization (get_state_snapshot, restore_state)
- ✅ **7/7 unit tests passing** (`Tests/test_quantum_instrument_headless.gd`)

**Key Features**:
- `extends RefCounted` - No scene tree dependencies
- Can be used by UI, tests, AI players, automation
- Delegates to existing submenu generators (VocabInjectionSubmenu, GateSelectionSubmenu)

### **Phase 2: Integration** ✅
**File**: `UI/Core/QuantumInstrumentInput.gd`

Integrated headless state into UI layer:
- ✅ Added `_state: QuantumInstrumentState` field
- ✅ Initialized in `_ready()`
- ✅ **Legacy state preserved** (parallel operation)
- ✅ **Integration test passing** (`Tests/test_quantum_instrument_integration.gd`)

**Current Architecture**:
```
QuantumInstrumentInput (Node)
├── _state: QuantumInstrumentState ← Headless core (NEW)
├── Legacy fields (preserved):
│   ├── current_selection
│   ├── last_selected_plot_position
│   ├── checked_plots
│   ├── _current_submenu
│   ├── _in_submenu
│   └── _submenu_page
└── UI references:
    ├── farm
    └── plot_grid_display
```

---

## 🚧 TODO (Phases 3-6)

### **Phase 3: Delegate to Headless State**
Gradually replace direct state access with `_state` delegation:

#### **Step 1: Submenu State**
- [ ] Replace `_in_submenu` checks with `_state.is_in_submenu()`
- [ ] Replace `_current_submenu` with `_state.current_submenu_data`
- [ ] Replace `_submenu_page` with `_state.submenu_page`
- [ ] Update `_open_submenu_for_action()` to call `_state.enter_submenu()`
- [ ] Update `_cycle_submenu_page()` to call `_state.cycle_submenu_page()`

#### **Step 2: Selection State**
- [ ] Replace `current_selection` with `_state.current_plot_idx`, `_state.current_biome`
- [ ] Replace `last_selected_plot_position` with `_state.last_selected_position`
- [ ] Replace `checked_plots` with `_state.checked_plots`
- [ ] Update `_select_plot()` to call `_state.select_plot()`
- [ ] Update `toggle_plot_check()` to call `_state.toggle_plot_check()`

#### **Step 3: Tool State**
- [ ] Move tool group tracking to `_state.current_tool_group`
- [ ] Update `_select_tool_group()` to call `_state.set_tool_group()`
- [ ] Update `_cycle_mode()` to call `_state.cycle_tool_mode()`

#### **Step 4: Action Execution**
- [ ] Update `_perform_action()` to call `_state.handle_action_key()`
- [ ] Keep handlers (GateActionHandler, etc.) as dependencies
- [ ] Project results to UI in `_update_ui_from_result()`

### **Phase 4: Remove Legacy State** ⚠️ **Breaking Changes**
After Phase 3 complete and tested:
- [ ] Delete `current_selection` field
- [ ] Delete `last_selected_plot_position` field
- [ ] Delete `checked_plots` field
- [ ] Delete `_current_submenu` field
- [ ] Delete `_in_submenu` field
- [ ] Delete `_submenu_page` field
- [ ] Update `get_checked_plots()` to return `_state.checked_plots.duplicate()`
- [ ] Update `set_checked_plots()` to call `_state` methods

### **Phase 5: Delete Dead Code**
- [ ] Delete `UI/Core/SubmenuManager.gd` (orphaned, never used)
- [ ] Remove from `Core/GameState/ToolConfig.gd`:
  - [ ] `SUBMENUS = {}` (line 494)
  - [ ] `get_submenu()` function (lines 496-498)
  - [ ] `get_dynamic_submenu()` function (lines 501-503)
  - [ ] `current_mode` variable (line 409)
  - [ ] `tool_mode_indices` variable (line 412)
  - [ ] `TOOL_ACTIONS`, `PLAY_TOOLS`, `BUILD_TOOLS` constants (lines 415-417)
  - [ ] Remove import from `UI/Panels/ActionPreviewRow.gd:15`
- [ ] Remove from `Core/GameMechanics/EconomyConstants.gd`:
  - [ ] `MIDWIFE_ACTION_COST` (line 22)
  - [ ] `VOCAB_INJECTION_BASE_COST` (line 84)
- [ ] Remove from `Core/GameState/GameStateManager.gd`:
  - [ ] `active_farm_view` variable (line 29)

### **Phase 6: Final Testing**
- [ ] Run all existing tests (Tests/*)
- [ ] Run 🍄 milk_hunt scripts
- [ ] Verify save/load still works
- [ ] Test UI responsiveness
- [ ] Create AI player demo using `_state.get_available_actions()`

---

## 🎯 Benefits Achieved So Far

1. **DRY Foundation** ✅ - Core logic now in one place (QuantumInstrumentState)
2. **Testable** ✅ - Headless tests pass without UI/scene tree
3. **AI-Ready** ✅ - `get_available_actions()` interface exists
4. **Serializable** ✅ - `get_state_snapshot()`/`restore_state()` work
5. **Pattern Consistent** ✅ - Follows Register→Plot→Terminal architecture

---

## 📂 Files Modified

### Created:
- `Core/Input/QuantumInstrumentState.gd` (365 lines)
- `Tests/test_quantum_instrument_headless.gd` (233 lines)
- `Tests/test_quantum_instrument_integration.gd` (69 lines)
- `docs/architecture/QUANTUM_INSTRUMENT_REFACTOR_PLAN.md`
- `docs/architecture/QUANTUM_INSTRUMENT_REFACTOR_STATUS.md`

### Modified:
- `UI/Core/QuantumInstrumentInput.gd` (added _state field, initialized in _ready)

### To Delete (Phase 5):
- `UI/Core/SubmenuManager.gd`
- Dead code in ToolConfig.gd, EconomyConstants.gd, GameStateManager.gd

---

## 🚀 Next Steps

**Immediate** (Phase 3, Step 1):
```gdscript
// Replace in QuantumInstrumentInput.gd
- if _in_submenu:
+ if _state.is_in_submenu():

- _current_submenu = _generate_vocab_injection_submenu()
+ _state.enter_submenu("vocab_injection", context)

- _in_submenu = false
+ _state.exit_submenu()
```

**Testing**:
1. Run `Tests/test_quantum_instrument_headless.gd` - should still pass
2. Run `Tests/test_quantum_instrument_integration.gd` - should still pass
3. Run a 🍄 milk_hunt script - should work normally

**Timeline**:
- Phase 3: ~2-3 hours (gradual delegation)
- Phase 4: ~30 minutes (remove legacy state)
- Phase 5: ~30 minutes (delete dead code)
- Phase 6: ~1 hour (comprehensive testing)

**Total remaining**: ~4-5 hours

---

## ⚠️ Risks

1. **Backward Compatibility**: Old saves might reference legacy state fields
   - **Mitigation**: Keep migration logic, test with old saves

2. **UI Timing**: Projection updates might lag behind state changes
   - **Mitigation**: Test thoroughly with visual feedback

3. **Performance**: Extra indirection through `_state`
   - **Impact**: Negligible (single pointer dereference)

---

## 📝 Notes

- Legacy state preserved in parallel for safety
- All existing functionality still works
- No breaking changes yet
- Can stop here if needed - system is stable with both old and new

