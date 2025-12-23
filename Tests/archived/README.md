# SpaceWheat Tests

This folder contains test scripts and guides for the Quantum Wheat farming game.

## Test Scripts

### `test_farm_ui.sh`
Main UI test runner. Opens the farm view for manual testing.

**Usage:**
```bash
cd tests
./test_farm_ui.sh
```

**What it tests:**
- 5x5 emoji lattice grid
- Top bar (credits, wheat, stats, help)
- Action buttons (plant, harvest, entangle, measure)
- Plot selection and interaction
- Info panel updates

---

### `test_entanglement_viz.sh`
Automated test for entanglement line visualization.

**Usage:**
```bash
cd tests
./test_entanglement_viz.sh
```

**What it tests:**
- Auto-plants wheat in 2x2 grid
- Creates multiple entanglements
- Displays shimmering quantum connection lines
- Verifies visual effects

**Note:** This test has some issues with SceneTree scripting and may not run correctly.

---

## Test Guides

### `test_manual_entanglement.md`
Step-by-step guide for manually testing entanglement features.

**Topics covered:**
- Creating entanglements between plots
- Verifying line visualization
- Testing entanglement limits (max 3 per plot)
- Visual effect specifications

---

### `test_visual_effects.md`
Comprehensive guide for testing all visual effects.

**Topics covered:**
- Plant effect (🌱 green sparkles)
- Harvest effect (✂️ golden burst)
- Entanglement effect (🔗 blue sparkles)
- Measurement effect (👁️ purple quantum collapse)
- Number counter animations
- Growth state visualizations

---

## GDScript Tests

For GDScript unit tests, see:
- `Core/Tests/test_quantum_substrate.gd` - Quantum tomato network tests
- `Core/Tests/test_wheat_system.gd` - Wheat farming mechanics tests
- `Core/Tests/QuantumNetworkVisualizer.gd` - Visual debugger for quantum state

These run through Godot's test runner or scene files.

---

## Quick Start

Run the main UI test:
```bash
cd tests
chmod +x test_farm_ui.sh
./test_farm_ui.sh
```

Then follow the visual effects guide to test all features:
```bash
cat test_visual_effects.md
```
