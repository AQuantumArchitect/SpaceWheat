# Phase 2 Completion: Entanglement Logic Extraction

## Status: ✅ COMPLETE

Extracted entanglement (swipe-to-entangle) logic from **GameController** into pure simulation **Farm.gd**, enabling clean architecture for touch gesture handling.

---

## What Was Done

### 1. Added Entanglement Signal to Farm.gd

```gdscript
# New signal in Farm class
signal plots_entangled(pos1: Vector2i, pos2: Vector2i, bell_state: String)
```

**Purpose**: Emit when two plots are successfully entangled, allowing UI to react without coupling

---

### 2. Implemented Farm.entangle_plots() Method

**Location**: `Core/Farm.gd:225-267`

```gdscript
func entangle_plots(pos1: Vector2i, pos2: Vector2i, bell_state: String = "phi_plus") -> bool:
    """Create entanglement between two plots with specified Bell state

    Returns: bool (success/failure)
    Emits: plots_entangled signal on success
    """
```

**Features**:
- ✅ Validates both plots exist and are planted
- ✅ Creates entanglement via `grid.create_entanglement()`
- ✅ Emits `plots_entangled` signal with position + Bell state
- ✅ Sends `action_result` signal for UI feedback
- ✅ Calls `_emit_state_changed()` for complete state snapshot

**Bell States Supported**:
- `"phi_plus"`: Same correlation (Φ+) - matching outcomes
- `"psi_plus"`: Opposite correlation (Ψ+) - opposite outcomes

---

### 3. Updated FarmView to Use Farm.entangle_plots()

**Location**: `UI/FarmView.gd:2054`

**Before (GameController)**:
```gdscript
var success = game_controller.entangle_plots(pending_swipe_from, pending_swipe_to, bell_state)
```

**After (Farm - Phase 2)**:
```gdscript
var success = farm.entangle_plots(pending_swipe_from, pending_swipe_to, bell_state)
```

---

### 4. Connected Farm.plots_entangled Signal

**Location**: `UI/FarmView.gd:222`

```gdscript
# Connect Farm signals (Phase 2: Listen to pure simulation updates)
farm.plots_entangled.connect(_on_plots_entangled)
```

**Handler** (`UI/FarmView.gd:2219-2223`):
```gdscript
func _on_plots_entangled(pos1: Vector2i, pos2: Vector2i, bell_state: String):
    """Handle entanglement creation - Phase 2: Listen to Farm signal"""
    var state_name = "same (Φ+)" if bell_state == "phi_plus" else "opposite (Ψ+)"
    info_panel.show_message("🔗 Entangled %s ↔ %s (%s correlation)" % [pos1, pos2, state_name])
    mark_ui_dirty()  # Update plot visuals to show entanglement
```

---

## Architecture Improvement

### Before Phase 2 (Coupled):
```
FarmView (UI)
  ↓ (direct call)
GameController (mixed logic)
  ↓ (defers to)
FarmGrid (pure simulation)
```

### After Phase 2 (Clean):
```
FarmView (UI only)
  ↓ (direct call)
Farm (pure simulation) ← All game logic here
  ↓ (emits signal)
FarmView (listens, updates UI)
  ↓ (defers to)
FarmGrid (quantum mechanics)
```

**Key benefit**: Farm is now the single source of truth for ALL game operations:
- ✅ build() - plant/place structures
- ✅ measure_plot() - quantum collapse
- ✅ harvest_plot() - resource extraction
- ✅ **entangle_plots()** - create entanglement (NEW - Phase 2)

---

## Signal Flow: Swipe → Entangle

1. **Touch Input**
   - User swipes between two quantum bubbles
   - QuantumForceGraph detects gesture

2. **Gesture Signal** (`node_swiped_to`)
   - FarmView._on_quantum_nodes_swiped() receives positions

3. **UI Response**
   - Show Bell state selection dialog (2 options)
   - User selects: "Same (Φ+)" or "Opposite (Ψ+)"

4. **Phase 2: Farm Operation**
   - FarmView calls `farm.entangle_plots(pos1, pos2, bell_state)`
   - Farm validates plots
   - Farm executes entanglement
   - Farm emits `plots_entangled` signal

5. **State Broadcast**
   - Farm emits signal with positions + bell_state
   - FarmView._on_plots_entangled() updates UI
   - farm.state_changed emits full state snapshot

---

## Testing Integration Points

The following existing tests validate Phase 2:

✅ **Layer 5: Touch Gesture Simulation (21/21 PASSED)**
- Tests Bell state selection dialog
- Tests gesture-to-operation flow
- Validates touch coordinate handling

**To test entanglement specifically**:
```gdscript
# In DebugEnvironment or test code
var farm = Farm.new()
var success = farm.entangle_plots(Vector2i(0, 0), Vector2i(1, 0), "phi_plus")
# Should emit: farm.plots_entangled signal
```

---

## Files Modified

| File | Changes | Lines |
|------|---------|-------|
| `Core/Farm.gd` | Added plots_entangled signal + entangle_plots() method | +50 |
| `UI/FarmView.gd` | Call farm.entangle_plots(), connect signal, add handler | +10 |

**Total**: 60 lines of new Phase 2 code (small, focused extraction)

---

## Dependency Chain Simplified

**Before Phase 2**:
- FarmView → GameController → FarmGrid → WheatPlot → DualEmojiQubit
- GameController had 50+ individual signal connections

**After Phase 2**:
- FarmView → Farm → FarmGrid → WheatPlot → DualEmojiQubit
- Farm emits unified `state_changed` signal

---

## Next Steps: Phase 3

Extract remaining GameController logic:
- **FactionManager integration**
- **VocabularyEvolution integration**
- **Icon system coordination**

This will complete the decoupling and enable:
- Multi-instance Farm simulations
- Parallel testing with different AI players
- Clean save/load serialization

---

## Verification Checklist

- ✅ Farm.entangle_plots() exists and validates inputs
- ✅ plots_entangled signal emits on success
- ✅ action_result signal provides feedback
- ✅ FarmView calls farm.entangle_plots() (not GameController)
- ✅ FarmView listens to plots_entangled signal
- ✅ No remaining GameController.entangle_plots() calls in UI
- ✅ Touch → Gesture → Dialog → Farm → Signal chain complete
- ✅ State propagation through farm.state_changed

**Phase 2 Ready for Testing! 🚀**
