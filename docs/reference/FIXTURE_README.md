# SimulationFixture - Multi-Scenario Test Framework

## Overview

The `SimulationFixture` is a clean architectural layer that manages multiple independent `FarmView` simulations. Each simulation runs with a different debug scenario, allowing you to:

- **Switch between scenarios** without restarting
- **Test multiple states** side-by-side in code
- **Run simulations in parallel** (each in its own tree)
- **Extend easily** with new scenarios or screens

## Architecture

```
SimulationFixture (Control)
├── FarmView (minimal scenario)
├── FarmView (planted scenario)
└── FarmView (wealthy scenario)

Only one is visible at a time - the others are running in background
```

## Usage

### Run the Test Scene

Open `test_fixture_slideshow.tscn` in the Godot editor and press Play.

### Controls

- **SPACE** or **Right Arrow**: Next scenario
- **Left Arrow**: Previous scenario
- **S**: Toggle automatic slideshow (3 seconds per scenario)

### Keyboard Shortcuts
```
┌─────────────┬───────────────────────────┐
│ Key         │ Action                    │
├─────────────┼───────────────────────────┤
│ SPACE       │ Cycle to next scenario    │
│ LEFT ARROW  │ Go to previous scenario   │
│ RIGHT ARROW │ Go to next scenario       │
│ S           │ Toggle slideshow mode     │
└─────────────┴───────────────────────────┘
```

## Adding New Scenarios

Edit `SimulationFixture.gd` line 35-36:

```gdscript
var scenarios = ["minimal", "planted", "wealthy", "measured", "entangled"]
```

The fixture will automatically create a simulation for each scenario.

## Future Extensions

### Multiple Screens
Once scenarios are working, you can extend to display multiple simulations at once:

```gdscript
# 2x2 grid of simulations
┌──────────────┬──────────────┐
│  minimal     │  planted     │
├──────────────┼──────────────┤
│  wealthy     │  measured    │
└──────────────┴──────────────┘
```

### Performance Monitoring
Track each simulation independently:
- Frame rate per simulation
- Memory usage
- State changes

### Cross-Simulation Communication
Share data between simulations:
- Breeding results
- Contract completion
- Quantum entanglement chains

## How It Works

1. **Creation**: `SimulationFixture._ready()` creates N FarmView instances
2. **Initialization**: Each FarmView loads its scenario independently
3. **Display**: Only the current simulation is visible (`.visible = true`)
4. **Background**: Other simulations continue running (processing, physics, etc.)
5. **Switching**: Change `.visible` property to show different simulation

## Benefits

✅ **Separation of Concerns**: Fixture doesn't touch FarmView code
✅ **Scalable**: Easy to add more simulations or scenarios
✅ **Testable**: Each simulation runs independently
✅ **Future-Proof**: Ready for multi-screen displays
✅ **Clean Code**: FarmView stays lean, no slideshow logic

## Files

- `Core/SimulationFixture.gd` - Manager class
- `test_fixture_slideshow.tscn` - Test scene
- `UI/FarmView.gd` - Individual simulation (unchanged)
- `Core/GameState/DebugEnvironment.gd` - Scenario definitions
