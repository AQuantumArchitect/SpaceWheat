# Quick Test Guide - Quantum UI Integration

## Quick Start (5 minutes)

### Phase 1: Verify QuantumHUDPanel (Left Side)
1. **Launch game**: `godot project.godot` or run from editor
2. **Look left side of screen**:
   - Should see "◀ Quantum State" button
   - Below it: 4 panels in a column
   - Panels may show "No quantum state" until farm loads
3. **Click toggle button**: Panel should collapse/expand
4. **Wait for farm to load**: Panels should populate with data

**Expected**: Collapsible panel with 4 quantum meters visible on left side

---

### Phase 7: Verify Mode Indicator (Top Right)
1. **Look top-right corner**
2. **Should see**: "🔍 INSPECTOR | 😌 KID_LIGHT"
3. **Semi-transparent** cyan text on dark background

**Expected**: Small status indicator in top-right showing current quantum modes

---

### Phase 3: Verify Quantum Settings (Pause Menu)
1. **Press ESC**: Pause menu opens
2. **Look for button**: "Quantum Settings [X]" (cyan/blue color)
3. **Press X** or **click button**: Quantum settings panel opens
4. **Verify sections**:
   - Readout Mode (HARDWARE/INSPECTOR)
   - Backaction Mode (KID_LIGHT/LAB_TRUE)
   - Selective Measurement Model
   - Debug Mode (Invariant Checks)
5. **Click different modes**: Buttons should highlight with ✓
6. **Close panel**: Press ESC or click Close button

**Expected**: Full quantum configuration UI accessible from pause menu

---

### Keyboard Hints: Verify Documentation (Press K)
1. **Press K**: Keyboard hints panel opens
2. **Scroll down** to verify new sections:
   - "🔬 QUANTUM UI (Always Visible)"
   - "⚡ ADVANCED TOOL ACTIONS"
3. **Check content**:
   - All 6 tools documented
   - Pause menu shortcuts (ESC→X)
   - Lindblad submenu (Tool 4 E)
   - Peek feature (Tool 2 E)
   - Batch measure (Tool 2 R)
4. **Press K again**: Panel closes

**Expected**: Complete documentation of all quantum features

---

## Quick Functional Tests (10 minutes)

### Test Lindblad Operations (Tool 4)
1. **Plant some crops**: Tool 1 → Q (select plot first)
2. **Switch to Tool 4**: Press `4`
3. **Press E**: Should see "Lindblad ▸" submenu
4. **Press Q**: "Drive (+pop)" - should pump population
5. **Check action message**: Should say "Drive on 1/1 plots | 🌾×1"

**Expected**: Lindblad operations accessible and functional

---

### Test Peek (Tool 2)
1. **Plant crop in superposition**: Tool 1 → Q, then Tool 5 → Q → E (Hadamard)
2. **Switch to Tool 2**: Press `2`
3. **Press E**: "Peek (no collapse)"
4. **Check message**: Should show "🔍 Peek: 🌾: ↑50% ↓50%"
5. **Press E again**: Should show SAME probabilities (no collapse)
6. **Press R** (measure): Should collapse to 100%/0% or 0%/100%

**Expected**: Peek shows probabilities without collapsing state

---

### Test Batch Component Measurement (Tool 2)
1. **Plant 2 crops**: Tool 1 → Q on 2 plots
2. **Entangle them**: Select both, Tool 1 → E
3. **Select just ONE entangled plot**
4. **Press 2** (Tool 2), then **R**
5. **Check message**: Should say "Measured 2 outcomes (1 components)"
6. **Verify**: BOTH plots measured, not just selected one

**Expected**: Measuring one plot measures entire entangled component

---

### Test Biome Inspector (Tool 6)
1. **Select any planted plot**
2. **Press 6** (Tool 6)
3. **Press R**: Inspector overlay should open
4. **Verify shows**:
   - Biome name
   - Quantum state info
   - Register distribution
   - Entanglement status
5. **Press ESC**: Inspector closes

**Expected**: Detailed biome inspector opens for selected plot

---

## Visual Checklist (Quick Scan)

When game is running, quickly verify:
- [ ] **Left side**: Quantum HUD panel visible with 4 meters
- [ ] **Top right**: "🔍 INSPECTOR | 😌 KID_LIGHT" mode indicator
- [ ] **ESC menu**: "Quantum Settings [X]" button present
- [ ] **Tool 4**: Press E shows "Lindblad ▸"
- [ ] **Tool 2**: E shows "Peek (no collapse)", R shows "Measure"
- [ ] **Tool 6**: R shows "Inspect Plot"
- [ ] **Press K**: Keyboard hints include quantum sections

---

## Known Issues to Ignore

These are expected:
- Warning about `_set_size` with anchors - cosmetic Godot warning
- "3 resources still in use at exit" - normal for this codebase
- Panels may show "No quantum state" before farm fully initializes

---

## Critical Bugs to Report

If you encounter:
- ❌ Game crashes on any action
- ❌ UI element completely missing
- ❌ Tool action does nothing (no message)
- ❌ Quantum settings don't save/apply
- ❌ HUD panels never populate with data
- ❌ Measurement corrupts quantum state (errors in log)

Document in QUANTUM_UI_TEST_PLAN.md "Critical Issues Found" section.

---

## Performance Check

While testing, watch for:
- Panel updates should be smooth (no stuttering)
- UI should remain responsive
- Frame rate should stay consistent
- No memory warnings in logs

If any lag or performance issues, note which operation caused it.

---

## Success Indicators

✅ All 7 phases working
✅ No crashes during normal gameplay
✅ All tools accessible and functional
✅ HUD panels update correctly
✅ Keyboard hints complete

If all indicators pass, quantum UI integration is successful!
