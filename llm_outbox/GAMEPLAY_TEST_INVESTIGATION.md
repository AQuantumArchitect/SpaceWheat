# Gameplay Investigation - Tools & Overlays Status

**Test Date:** 2026-01-12
**Status:** 🔴 NEEDS MANUAL TESTING

## Boot Sequence ✅ PASSING

Game boots successfully with **NO critical errors**. Only warnings:
- Anchor configuration warnings (non-critical)
- RID leaks at exit (expected in Godot)

All systems initialize:
- ✅ 5 v2 overlays registered (inspector, controls, semantic_map, quests, biome_detail)
- ✅ All biome quantum computers ready
- ✅ Farm grid initialized (12 plots)
- ✅ Input system ready
- ✅ Quest system ready

---

## OVERLAYS STATUS

### 1. Inspector (📊) - Code Complete
- ✅ Implementation: 455 lines, created
- ✅ Registered in OverlayManager
- ✅ Methods: activate, deactivate, handle_input, QER+F actions
- ⏳ **NEEDS TEST:** Data binding (no quantum computer set)

### 2. Controls (⌨️) - Code Complete
- ✅ Implementation: 428 lines, created
- ✅ Registered in OverlayManager
- ✅ 6 keyboard reference sections working
- ⏳ **NEEDS TEST:** All UI display

### 3. Semantic Map (🧭) - Code Complete
- ✅ Implementation: 440 lines, created
- ✅ Registered in OverlayManager
- ✅ 8 octants displayed
- ❌ **TODO:** Vocabulary loading not implemented (placeholder)
- ❌ **TODO:** Octant emoji mapping not implemented

### 4. Quests (📜) - Adapted to v2
- ✅ v2 methods added (WASD nav, F key, action labels)
- ✅ Registered in OverlayManager
- ⏳ **NEEDS TEST:** Quest data actually loads
- ⏳ **NEEDS TEST:** WASD navigation works
- ⚠️ **REPORTED:** "Seems old" - might have stale references

### 5. Biome Detail (🔬) - Adapted to v2
- ✅ v2 methods added (handle_input, QER+F)
- ✅ Registered in OverlayManager
- ✅ Input handler implemented
- ⏳ **NEEDS TEST:** All functionality

---

## TOOLS STATUS (1-6)

All 6 tools are implemented through:
- **Input:** `UI/FarmInputHandler.gd`
- **Config:** `Core/GameState/ToolConfig.gd`
- **Actions:** `Core/Actions/ProbeActions.gd`
- **Manager:** `UI/Managers/ActionBarManager.gd`

### Tool 1: Grower (🌱)
- Q = Plant, E = Entangle, R = Measure+Harvest
- ⏳ **NEEDS TEST**

### Tool 2: Quantum (⚛️)
- Q = Cluster, E = Peek, R = Measure
- ⏳ **NEEDS TEST**

### Tool 3: Industry (🏭)
- Q = Build Market, E = Build Kitchen, R = Unknown
- ⏳ **NEEDS TEST**

### Tool 4: Biome Control (⚡)
- Q = Energy Tap, E = Lindblad, R = Pump/Reset
- ⏳ **NEEDS TEST**

### Tool 5: Gates (🔄)
- Q = 1-Qubit, E = 2-Qubit, R = Remove
- ⏳ **NEEDS TEST**

### Tool 6: Biome (🌍)
- Q = Assign, E = Clear, R = Inspect
- ⏳ **NEEDS TEST**

---

## WHAT NEEDS INVESTIGATION

### Critical (Today)
1. **Do tools work at all?**
   - Select tool 1-6 (press number keys)
   - Do action labels appear?
   - Do Q/E/R/F keys trigger actions or fail silently?

2. **Does quest board work?**
   - Press C to open
   - Are quests populated or empty?
   - Do WASD navigate or freeze?
   - Does F open faction browser?

3. **Do overlays capture input?**
   - Open quest board with C
   - Press Q - should trigger quest action, not tool action
   - Press ESC - should close overlay
   - Test input isolation

### Important (This week)
4. **Data binding**
   - Does inspector show quantum data?
   - Does semantic map show vocabulary?
   - Does biome detail show biome data?

5. **User reported "all tools broken"**
   - Are Q/E/R actions silently failing?
   - Are there missing dependencies?
   - Are there runtime errors (check game log)?

---

## CHART: What Works vs Broken

| Component | Status | Notes |
|-----------|--------|-------|
| **Boot** | ✅ Working | Clean startup, all systems ready |
| **v2 Overlay System** | ✅ Working | All 5 overlays register and open |
| **Inspector Overlay** | ⏳ Unknown | Code done, needs data + test |
| **Controls Overlay** | ⏳ Unknown | Code done, needs UI test |
| **Semantic Map Overlay** | ⚠️ Partial | Code done, vocab loading TODO |
| **Quest Board v2** | ⚠️ Unknown | v2 adapted, needs quest data test |
| **Biome Detail v2** | ✅ Likely | Input handler working |
| **Tool 1 - Grower** | ⏳ Unknown | Action handler exists, needs test |
| **Tool 2 - Quantum** | ⏳ Unknown | Action handler exists, needs test |
| **Tool 3 - Industry** | ⏳ Unknown | Action handler exists, needs test |
| **Tool 4 - Biome Ctrl** | ⏳ Unknown | Submenus exist, needs test |
| **Tool 5 - Gates** | ⏳ Unknown | Submenus exist, needs test |
| **Tool 6 - Biome** | ✅ Likely | Inspect opens overlay |
| **Input Routing** | ✅ Working | v2 overlays checked first |
| **Action Bar Display** | ✅ Working | Appears and updates |
| **Quest System** | ✅ Working | System initialized at boot |

---

## RECOMMENDED TESTING ORDER

1. **Quick Test (5 min)**
   - Launch game
   - Try pressing 1-6
   - Try pressing C
   - Report if anything shows

2. **Detailed Tool Test (15 min)**
   - For each tool:
     - Select with 1-6
     - Click a plot
     - Try Q/E/R keys
     - Note any errors

3. **Overlay Test (10 min)**
   - Open each overlay
   - Try WASD
   - Try QER+F
   - Try ESC to close

4. **Integration Test (20 min)**
   - Open quest board
   - Check quest list population
   - Test slot navigation
   - Test quest actions

---

## HOW TO REPORT RESULTS

When testing, look for:
- **Visual:** Do things appear? Do they respond?
- **Functional:** Do buttons work? Do keys trigger actions?
- **Error:** Check console for error messages
- **Data:** Are quest lists populated? Is status shown?

Example report format:
```
Tool 1 (Grower):
  ✅ Tool selectable with '1'
  ✅ Action bar shows Q/E/R labels
  ✅ Q key triggers plant action
  ❌ Plant fails with "plot_pool is null"

Quest Board:
  ✅ Opens with C
  ⚠️ No quests shown in slots
  ✅ WASD navigation works
  ❌ F key does nothing
```

---

## NEXT STEPS

1. **Run tests** - Execute test_all_tools_overlays.gd or manual testing
2. **Capture errors** - Check godot console and user://logs/
3. **Document issues** - Create detailed issue list with exact errors
4. **Fix in priority order** - Critical tools first, then overlays
5. **Re-test** - Verify fixes work
