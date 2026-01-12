# Quantum UI Integration - Testing Plan

## Overview
Systematic testing of all 7 phases of quantum UI integration.

---

## Phase 1: QuantumHUDPanel (Left Side)

### Visual Tests
- [ ] Panel appears on left side of screen at boot
- [ ] Panel positioned at (10, 80) below top bars
- [ ] Panel contains 4 child panels stacked vertically
- [ ] Toggle button visible with text "◀ Quantum State"

### Panel Content Tests
- [ ] **QuantumEnergyMeter** displays:
  - [ ] Real energy bar (orange/gold)
  - [ ] Imaginary energy bar (cyan/blue)
  - [ ] Regime label (crystallized/balanced/fluid)
  - [ ] Extractable energy amount
- [ ] **UncertaintyMeter** displays:
  - [ ] Precision bar (blue)
  - [ ] Flexibility bar (cyan)
  - [ ] Product value (>= 0.25)
  - [ ] Principle status (satisfied/violated)
  - [ ] Current regime with emoji
- [ ] **SemanticContextIndicator** displays:
  - [ ] Current octant emoji and name
  - [ ] Region description
  - [ ] Phase space position (x, y, z)
  - [ ] Active modifiers (growth, yield, decay, extract)
  - [ ] Adjacent regions
- [ ] **AttractorPersonalityPanel** displays:
  - [ ] Title "🌀 Attractor Personalities"
  - [ ] Per-biome personality labels
  - [ ] Personality types (stable/cyclic/chaotic/etc.)

### Functional Tests
- [ ] Click toggle button → panel collapses
- [ ] Click again → panel expands
- [ ] Collapsed: minimum size ~50px height
- [ ] Expanded: minimum size ~450px height
- [ ] All 4 panels update periodically (0.3-1.0s intervals)
- [ ] Panels show "No quantum state" when farm not loaded

### Connection Tests
- [ ] Panel connects to farm on farm_setup_complete
- [ ] Panel receives biome reference (biotic_flux_biome)
- [ ] All child panels receive quantum_computer reference
- [ ] Panels update when quantum state changes

---

## Phase 2: BiomeInspectorOverlay (Tool 6 R)

### Access Tests
- [ ] Select Tool 6 (Biome 🌍)
- [ ] Select a planted plot
- [ ] Press R
- [ ] BiomeInspectorOverlay opens

### Content Tests
- [ ] Overlay shows biome name
- [ ] Shows quantum state information
- [ ] Shows register distribution
- [ ] Shows entanglement status
- [ ] Displays attractor analysis
- [ ] Shows semantic octant

### Functional Tests
- [ ] Can close overlay with ESC or close button
- [ ] Overlay blocks input to farm while open
- [ ] Can inspect multiple plots sequentially
- [ ] Works for plots in different biomes

---

## Phase 3: QuantumRigorConfigUI (Pause Menu)

### Access Tests
- [ ] Press ESC → Pause menu opens
- [ ] "Quantum Settings [X]" button visible
- [ ] Button positioned between "Load Game" and "Reload Last Save"
- [ ] Click button → QuantumRigorConfigUI opens
- [ ] Press X in pause menu → QuantumRigorConfigUI opens

### Content Tests
- [ ] Title: "🔬 Quantum Rigor Configuration"
- [ ] **Readout Mode** section:
  - [ ] HARDWARE button (shot-based sampling)
  - [ ] INSPECTOR button (exact probabilities)
  - [ ] Current mode highlighted with ✓
- [ ] **Backaction Mode** section:
  - [ ] KID_LIGHT button (gentle partial collapse)
  - [ ] LAB_TRUE button (rigorous projective collapse)
  - [ ] Current mode highlighted
- [ ] **Selective Measurement Model** section:
  - [ ] POSTSELECT_COSTED button
  - [ ] CLICK_NOCLICK button
  - [ ] Current mode highlighted
- [ ] **Debug Mode** section:
  - [ ] Invariant checks checkbox
  - [ ] Warning text about performance

### Functional Tests
- [ ] Click HARDWARE → mode changes, button updates
- [ ] Click INSPECTOR → mode changes, button updates
- [ ] Click KID_LIGHT → mode changes
- [ ] Click LAB_TRUE → mode changes
- [ ] Click POSTSELECT_COSTED → mode changes
- [ ] Click CLICK_NOCLICK → mode changes
- [ ] Toggle invariant checks → setting changes
- [ ] Click "Close (ESC)" → UI closes
- [ ] Press ESC → UI closes
- [ ] Changes persist across UI open/close

### Integration Tests
- [ ] QuantumModeStatusIndicator updates when modes change
- [ ] Measurement behavior changes based on settings
- [ ] Pause menu closes when Quantum Settings opens

---

## Phase 4: Lindblad Control Submenu (Tool 4 E)

### Access Tests
- [ ] Select Tool 4 (Biome Control ⚡)
- [ ] Press E → "Lindblad ▸" submenu appears
- [ ] Action preview shows: Q=Drive, E=Decay, R=Transfer

### Lindblad Drive Test (E→Q)
- [ ] Select planted plot
- [ ] Press E → Q
- [ ] Action message: "Drive on N/M plots | 🌾×N"
- [ ] Plot population increases (check with peek or inspect)
- [ ] Multiple plots: all selected plots affected

### Lindblad Decay Test (E→E)
- [ ] Select planted plot
- [ ] Press E → E
- [ ] Action message: "Decay on N/M plots | 🌾×N"
- [ ] Plot population decreases
- [ ] Only affects plots with planted emojis

### Lindblad Transfer Test (E→R)
- [ ] Select exactly 2 planted plots
- [ ] Press E → R
- [ ] Action message: "Transfer: 🌾 → 🍄"
- [ ] Population transfers from plot 1 to plot 2
- [ ] Error message if not exactly 2 plots selected

### Edge Cases
- [ ] No plots selected → error message
- [ ] Unplanted plot → skipped, no error
- [ ] Plot without quantum computer → skipped
- [ ] Cross-biome selection → works per-biome

---

## Phase 5: Non-Destructive Peek (Tool 2 E)

### Access Tests
- [ ] Select Tool 2 (Quantum ⚛️)
- [ ] Press E → "Peek (no collapse)" label visible
- [ ] Icon shows 🔍

### Functional Tests
- [ ] Select planted plot in superposition
- [ ] Press E
- [ ] Action message shows: "🔍 Peek: 🌾: ↑50% ↓50%"
- [ ] State does NOT collapse (verify with second peek)
- [ ] Multiple plots: all probabilities shown
- [ ] Percentages sum to 100%

### Comparison with Measure (Tool 2 R)
- [ ] Peek (E) shows probabilities, no collapse
- [ ] Measure (R) shows outcomes, collapses state
- [ ] After measure, peek shows 100%/0% or 0%/100%

### Edge Cases
- [ ] Pure state |0⟩: shows ↑100% ↓0%
- [ ] Pure state |1⟩: shows ↑0% ↓100%
- [ ] Entangled state: shows marginal probabilities
- [ ] No quantum state: error message

---

## Phase 6: Enhanced Batch Measurement (Tool 2 R)

### Basic Measurement Test
- [ ] Select Tool 2
- [ ] Select planted plot
- [ ] Press R
- [ ] Action message shows outcome: "🌾×1"
- [ ] Plot state collapses

### Entangled Component Test
- [ ] Create Bell state: 2 plots, Tool 1 E (entangle)
- [ ] Select ONE plot from entangled pair
- [ ] Press Tool 2 R
- [ ] Message shows: "Measured N outcomes (1 components)"
- [ ] BOTH plots measured and collapsed
- [ ] Correlation visible (both north or both south)

### Multiple Component Test
- [ ] Create 2 separate Bell states (4 plots, 2 pairs)
- [ ] Select 1 plot from each pair (2 plots total)
- [ ] Press Tool 2 R
- [ ] Message shows: "Measured 4 outcomes (2 components)"
- [ ] All 4 plots measured

### Edge Cases
- [ ] Single unentangled plot: normal measure
- [ ] Component already measured: not measured again
- [ ] Mixed selection (entangled + unentangled): both work
- [ ] No component tracking errors in log

---

## Phase 7: QuantumModeStatusIndicator (Top Right)

### Visual Tests
- [ ] Indicator visible in top-right corner at boot
- [ ] Positioned at (-200, 10) from top-right
- [ ] Semi-transparent background (alpha 0.85)
- [ ] Cyan text color
- [ ] Updates every 0.5 seconds

### Content Tests (Readout Mode)
- [ ] INSPECTOR mode: shows "🔍 INSPECTOR"
- [ ] HARDWARE mode: shows "📡 HARDWARE"

### Content Tests (Backaction Mode)
- [ ] LAB_TRUE mode: shows "🔬 LAB_TRUE"
- [ ] KID_LIGHT mode: shows "😌 KID_LIGHT"

### Display Format
- [ ] Format: "[readout_emoji] [READOUT] | [backaction_emoji] [BACKACTION]"
- [ ] Example: "🔍 INSPECTOR | 😌 KID_LIGHT"
- [ ] Text fits in indicator without overflow

### Integration Tests
- [ ] Change mode in QuantumRigorConfigUI → indicator updates
- [ ] Indicator always visible (not modal)
- [ ] Indicator above most UI (high z-index)
- [ ] Tooltip shows full mode descriptions (if implemented)

---

## Keyboard Hints Menu (K)

### Access Tests
- [ ] Press K → hints panel opens
- [ ] Press K again → hints panel closes
- [ ] Click "[K] Keyboard" button → toggle works

### Content Tests
- [ ] Panel scrollable (600×500 with scroll)
- [ ] All 6 tools documented with emojis
- [ ] "🔬 QUANTUM UI" section present
- [ ] Documents Quantum HUD Panel (left side)
- [ ] Documents Quantum Mode Indicator (top right)
- [ ] "⚡ ADVANCED TOOL ACTIONS" section present
- [ ] Tool 2: Peek and Batch Measure documented
- [ ] Tool 4: Lindblad submenu documented
- [ ] Tool 5: Gates submenu documented
- [ ] Tool 6: Inspect documented
- [ ] Pause menu shortcuts documented (ESC→X for Quantum Settings)

### Visual Tests
- [ ] Positioned below [K] button in top-right
- [ ] Text readable (font size 14)
- [ ] Sections clearly separated
- [ ] Scroll bar appears if content exceeds height
- [ ] "Close [K]" button at bottom

---

## Integration Tests

### Cross-Feature Tests
1. **Quantum HUD + Tool Actions**:
   - [ ] Apply Lindblad drive → Energy meter updates
   - [ ] Transfer population → Semantic context may change
   - [ ] Apply gates → Uncertainty meter updates
   - [ ] Measure → Energy meter shows new state

2. **Mode Changes + Measurement**:
   - [ ] HARDWARE mode → measurements show sampling
   - [ ] INSPECTOR mode → measurements show exact outcomes
   - [ ] KID_LIGHT → state retains some coherence
   - [ ] LAB_TRUE → state fully collapses

3. **Peek vs Measure**:
   - [ ] Peek → HUD panels don't change
   - [ ] Measure → HUD panels update immediately
   - [ ] Peek → can peek multiple times, same result
   - [ ] Measure → subsequent peeks show collapsed state

4. **Biome Inspector + HUD**:
   - [ ] Open inspector → HUD still visible
   - [ ] Inspector shows same values as HUD
   - [ ] Inspector more detailed than HUD
   - [ ] Both update together

---

## Performance Tests

### Panel Update Rates
- [ ] Energy meter updates every 0.5s (not laggy)
- [ ] Uncertainty meter updates every 0.3s
- [ ] Semantic indicator updates every 0.5s
- [ ] Attractor panel updates every 1.0s
- [ ] Mode indicator updates every 0.5s
- [ ] No visible stuttering during updates

### Memory Tests
- [ ] No memory leaks when toggling HUD panel
- [ ] No leaks when opening/closing quantum settings
- [ ] No leaks with repeated peek operations
- [ ] Component measurement doesn't leak

---

## Error Handling Tests

### Graceful Failures
- [ ] Peek with no quantum computer → error message
- [ ] Lindblad with no quantum computer → error message
- [ ] Measure with no plots → error message
- [ ] Transfer with 1 plot → error message "Select exactly 2"
- [ ] Transfer with 3 plots → error message
- [ ] HUD with no biome → shows "No quantum state"

### Recovery Tests
- [ ] Error doesn't crash game
- [ ] Error doesn't leave UI in broken state
- [ ] Can continue using tools after error
- [ ] Error messages clear and helpful

---

## Test Execution Log

### Test Session Date: _____________
### Tester: _____________
### Build/Commit: _____________

| Phase | Test | Status | Notes |
|-------|------|--------|-------|
| 1 | QuantumHUDPanel visible | ⬜ | |
| 1 | 4 panels present | ⬜ | |
| 1 | Toggle works | ⬜ | |
| 1 | Panels update | ⬜ | |
| 2 | Tool 6 R opens inspector | ⬜ | |
| 3 | ESC→X opens settings | ⬜ | |
| 3 | Mode changes work | ⬜ | |
| 4 | Lindblad Drive works | ⬜ | |
| 4 | Lindblad Decay works | ⬜ | |
| 4 | Lindblad Transfer works | ⬜ | |
| 5 | Peek shows probabilities | ⬜ | |
| 5 | Peek doesn't collapse | ⬜ | |
| 6 | Batch measure works | ⬜ | |
| 6 | Component expansion works | ⬜ | |
| 7 | Mode indicator visible | ⬜ | |
| 7 | Mode indicator updates | ⬜ | |
| K | Keyboard hints complete | ⬜ | |

---

## Critical Issues Found

| Issue # | Phase | Description | Severity | Status |
|---------|-------|-------------|----------|--------|
| | | | | |

---

## Success Criteria

All phases must pass:
- ✅ Phase 1: QuantumHUDPanel visible and functional
- ✅ Phase 2: BiomeInspectorOverlay accessible via Tool 6 R
- ✅ Phase 3: Quantum Settings in pause menu
- ✅ Phase 4: Lindblad control submenu (Tool 4 E)
- ✅ Phase 5: Non-destructive peek (Tool 2 E)
- ✅ Phase 6: Enhanced batch measurement (Tool 2 R)
- ✅ Phase 7: Mode indicator visible and updating
- ✅ Keyboard hints document all features
- ✅ No critical bugs or crashes
- ✅ Performance acceptable (no lag)

---

## Notes

Use this checklist to systematically test each feature. Mark ✅ when passing, ❌ when failing, ⚠️ when partially working.

For any failures, document in "Critical Issues Found" section with:
- Clear description
- Steps to reproduce
- Expected vs actual behavior
- Severity (Critical/Major/Minor)
