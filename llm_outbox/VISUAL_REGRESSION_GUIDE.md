# Visual Regression Check Guide

Quick manual verification checklist for beta release.

## Launch Verification
```bash
godot scenes/FarmView.tscn
```

## Check 1: Boot & Layout
- [ ] Game loads without errors in console
- [ ] 4x3 plot grid visible at bottom
- [ ] Tool selection row (1-6) visible
- [ ] Q/E/R action bar visible
- [ ] Quantum visualization area (bubbles/force graph) visible

## Check 2: Tool Selection (Press 1-6)
- [ ] Tool 1 (Probe): Q=Explore, E=Measure, R=Pop
- [ ] Tool 2 (Gates): Q=Hadamard, E=CNOT, R=X-Gate
- [ ] Tool 3 (Industry): Q=Build, E=Upgrade, R=Demolish
- [ ] Tool 4-6: Each shows different Q/E/R actions

## Check 3: Plot Selection (Press T/Y/U/I/O/P)
- [ ] T selects plot 1 (top-left)
- [ ] Pressing same key again deselects
- [ ] Multiple plots can be selected
- [ ] [ key clears all selections
- [ ] Selected plots highlight visually

## Check 4: EXPLORE/MEASURE/POP Cycle
1. Select a BioticFlux plot (center area)
2. Press 1 for Probe tool
3. Press Q (Explore) - bubble should appear
4. Press E (Measure) - bubble freezes with emoji
5. Press R (Pop) - bubble despawns, resource added

## Check 5: Overlay System
- [ ] C key opens Quest Board
- [ ] V key opens Vocabulary overlay
- [ ] B key opens Biome detail
- [ ] ESC closes any open overlay
- [ ] ESC again opens escape menu

## Check 6: Quantum Visualization
- [ ] Force graph shows nodes for active biomes
- [ ] Nodes have emoji labels
- [ ] Tethers connect entangled nodes (if any)
- [ ] Bubbles spawn at correct biome locations

## Known Acceptable Issues
- Minor anchor warnings at startup (cosmetic)
- RID leak warnings at exit (normal for Godot)

## Test Commands
```bash
# Headless regression test
godot --headless --script Tests/test_regression_beta.gd

# Gameplay autoplay test
godot --headless --script Tests/test_gameplay_autoplay.gd
```

---

## Performance Baseline (2026-01-13)

| Metric | Value |
|--------|-------|
| Full regression test | ~38 seconds |
| Boot + scene load | ~35 seconds |
| EXPLORE/MEASURE/POP cycle | <1 second |
| Native matrix acceleration | Enabled (Eigen) |

Test environment: Linux WSL2, Godot 4.5, headless mode

---
Generated: 2026-01-13
