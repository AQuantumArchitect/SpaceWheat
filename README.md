# SpaceWheat - Quantum Farm Conspiracy Simulator

A Godot 4.5+ game blending real quantum mechanics (Bloch sphere, qubits, entanglement) with farming gameplay and conspiracy-themed narrative.

## Project Structure

```
SpaceWheat/
├── Core/                          # Core game systems
│   ├── QuantumSubstrate/         # Quantum mechanics engine
│   ├── GameMechanics/            # Farming & gameplay systems
│   ├── GameState/                # Save/load & state management
│   ├── Visualization/            # Quantum visualization
│   ├── Environment/              # Biomes & world systems
│   └── Tests/                    # Unit tests
├── UI/                            # User interface
│   ├── Panels/                   # UI panels
│   ├── Controllers/              # Input & control logic
│   └── Managers/                 # Layout & management
├── docs/                          # Documentation
│   ├── architecture/             # System design docs
│   ├── design/                   # Design documents
│   ├── sessions/                 # Session summaries
│   └── reference/                # Implementation guides
├── Tests/                         # Test scripts & scenes
│   └── archived/                 # Legacy/disabled tests
├── scripts/                       # Utility scripts (shell/Python)
├── scenes/                        # Godot scene files (.tscn)
├── llm_inbox/                     # Input design documents
├── llm_outbox/                    # Generated design output
├── Scenarios/                     # Game scenario templates
├── project.godot                  # Godot project config
└── .gitignore
```

## Running Tests

### Run All Tests
```bash
cd /path/to/SpaceWheat
./scripts/run_tests.sh
```

### Run Specific Test
```bash
godot --headless --script Tests/test_save_load_runner.gd
```

### Run in Godot Editor
1. Open project in Godot 4.5+
2. Run the main scene: `scenes/FarmView/FarmViewScene.tscn`
3. Or run individual test scenes in `/scenes/`

## Key Systems

### Quantum Substrate
- Real Bloch sphere quantum mechanics
- Multi-qubit entanglement systems
- Energy diffusion and management
- 12-node conspiracy network

### Farming Mechanics
- Wheat plot cultivation with growth phases
- Farm economy and resource management
- Biome systems (Forest, Market, Kitchen, etc.)
- Save/load game state system

### UI & Input
- Touch gesture support
- Keyboard controls (WASD/QERTOP)
- Dynamic UI panels and overlays
- Quantum visualization displays

## Documentation

- **`docs/architecture/`** - System design and architecture documentation
- **`docs/design/`** - Game design and mechanics documentation
- **`docs/sessions/`** - Session summaries and progress reports
- **`docs/reference/`** - Implementation guides and reference materials
- **`llm_inbox/`** - Input design documents and player feedback
- **`llm_outbox/`** - Generated design output and detailed planning

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repo-url>
   cd SpaceWheat
   ```

2. **Open in Godot**
   - Godot 4.5+ is required
   - Open `project.godot` in Godot Editor

3. **Run Tests**
   ```bash
   ./scripts/run_tests.sh
   ```

4. **Play**
   - Run the main FarmView scene to start the game

## Development

- Pure GDScript implementation (no external dependencies)
- Organized by feature: Core systems, UI, Tests, Scripts
- Design documents in LLM inbox/outbox format for AI collaboration

## Architecture Notes

This is a modular Godot project with:
- Core game systems in `/Core/`
- UI framework in `/UI/`
- Comprehensive test suite in `/Tests/`
- Helper scripts in `/scripts/`
- Documentation organized in `/docs/`
