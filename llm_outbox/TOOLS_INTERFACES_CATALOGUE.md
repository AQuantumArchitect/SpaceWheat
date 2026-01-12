# Tools & Interfaces Catalogue

Complete inventory of all in-game tools, submenus, and UI interfaces available to players.

---

## PART 1: GAME TOOLS (ToolConfig.gd)

### Tool 1: GROWER 🌱
**Purpose:** Core farming tool - plant crops and harvest (80% of gameplay)

| Action | Key | Submenu | Details |
|--------|-----|---------|---------|
| **Plant Crops** | Q | plant | Context-aware by biome |
| | | | Kitchen: 🍞🌾 (bread) |
| | | | Forest: 🌿🍃 (plants) |
| | | | Market: 🌾💰 (wheat trade) |
| | | | BioticFlux: 🌾🍄 (biotic interaction) |
| **Entangle Plots** | E | N/A | Bell state φ+: creates correlation |
| | | | Requires 2+ selected plots in same biome |
| | | | Merges components if separate |
| **Measure & Harvest** | R | N/A | Single measurement + collapse |
| | | | Returns north_emoji on |0⟩, south_emoji on |1⟩ |

**Fiber Bundle Integration:**
- Plant action varies by semantic octant (8 region variants)
- Example: In Phoenix → "Plant Phoenix Wheat" (fast-growing)
- Example: In Sage → "Plant Sage Wheat" (high quality)

---

### Tool 2: QUANTUM ⚛️
**Purpose:** Persistent quantum gate infrastructure - create Bell states and measurement triggers

| Action | Key | Submenu | Details |
|--------|-----|---------|---------|
| **Build Cluster** | Q | cluster | 2 plots → Bell state (φ+) |
| | | | 3+ plots → Cluster state (MBC) |
| | | | Creates entanglement graph structure |
| **Set Measurement Trigger** | E | measure | Select trigger plot (observer) |
| | | | On measurement: collapses entire component |
| | | | "Spooky action at a distance" |
| **Batch Measure** | R | N/A | Measure entire entangled component |
| | | | Returns Dict{register_id → outcome} |

---

### Tool 3: INDUSTRY 🏭
**Purpose:** Economy and automation - build markets and kitchens

| Action | Key | Submenu | Details |
|--------|-----|---------|---------|
| **Build Submenu** | Q | build | Choose building type |
| **Build Market** | E | N/A | 🏪 Commerce hub |
| | | | Enables trade with other biomes |
| **Build Kitchen** | R | N/A | 🍳 Processing facility |
| | | | Transforms crops into food/products |

---

### Tool 4: BIOME CONTROL ⚡
**Purpose:** Research-grade quantum control - energy extraction and parameter tuning

| Action | Key | Submenu | Details |
|--------|-----|---------|---------|
| **Energy Tap** | Q | energy_tap | Dynamic submenu (first 3 discovered emojis) |
| | | | Extract real energy from quantum coherence |
| | | Q-E-R in energy_tap | Select target emoji to boost |
| **Pump/Reset** | E | pump_reset | Modify quantum state directly |
| | | | Pump to wheat: push |0⟩ to |1⟩ |
| | | | Reset pure: return to basis state |
| | | | Reset mixed: maximize entropy |
| **Tune Decoherence** | R | N/A | Adjust decoherence rate (γ) |
| | | | Controls coherence_decay modifier |

**Spark Converter Integration:**
- Energy Tap uses SparkConverter.extract_spark()
- Tradeoff: lose coherence (flexibility) to gain population (real energy)
- Efficiency: 80% conversion rate

---

### Tool 5: GATES 🔄
**Purpose:** Quantum gate operations - apply unitary transformations

| Action | Key | Submenu | Details |
|--------|-----|---------|---------|
| **1-Qubit Gates** | Q | 1q_gates | Pauli-X, Hadamard, Pauli-Z |
| | | | Select target plot |
| | | | Gate applies to register at that plot |
| **Pauli-X** | Q→Q | N/A | Bit flip: \\|0⟩↔\\|1⟩ |
| **Hadamard** | Q→E | N/A | Superposition: (\\|0⟩+\\|1⟩)/√2 |
| **Pauli-Z** | Q→R | N/A | Phase flip: \\|1⟩ gets -1 |
| **2-Qubit Gates** | E | 2q_gates | CNOT, CZ, SWAP |
| | | | Requires 2 selected plots |
| **CNOT** | E→Q | N/A | Control-X on target |
| **Control-Z** | E→E | N/A | Control-phase flip |
| **SWAP** | E→R | N/A | Exchange two qubits |
| **Remove Gates** | R | N/A | Delete applied gates from plot |

**Gate Application Methods:**
- `_apply_single_qubit_gate(position, gate_name)`
- `_apply_two_qubit_gate(pos_a, pos_b, gate_name)`

---

### Tool 6: BIOME 🌍
**Purpose:** Ecosystem management - assign plots to biomes

| Action | Key | Submenu | Details |
|--------|-----|---------|---------|
| **Assign to Biome** | Q | biome_assign | Assign plot to first 3 discovered biomes |
| | | | Links plot to biome's quantum computer |
| | | | Enables entanglement within biome |
| **Clear Assignment** | E | N/A | Remove plot from biome |
| | | | Removes from quantum computer |
| **Inspect Plot** | R | N/A | View plot's quantum state |
| | | | Shows register info, entanglement status |

---

## PART 2: UI PANELS & INTERFACES

### Quantum State Visualization

| Panel | File | Updates | Shows |
|-------|------|---------|-------|
| **Quantum Energy Meter** | QuantumEnergyMeter.gd | 0.5s | Real (orange) vs imaginary (cyan) energy bars |
| | | | Regime: crystallized/fluid/balanced |
| | | | Extractable energy amount |
| **Semantic Context Indicator** | SemanticContextIndicator.gd | 0.5s | Current octant (region) |
| | | | Phase space position (x,y,z) |
| | | | Active modifiers (growth, yield, decay, extract) |
| | | | Adjacent regions for navigation |
| **Uncertainty Meter** | UncertaintyMeter.gd | 0.3s | Precision bar (high = stable) |
| | | | Flexibility bar (high = adaptable) |
| | | | Uncertainty product (must ≥ 0.25) |
| | | | Current regime classification |
| | | | Principle violation indicator |
| **Attractor Personality Panel** | AttractorPersonalityPanel.gd | 1.0s | Current attractor personality |
| | | | Personality type (stable/cyclic/chaotic) |
| | | | Trajectory visualization |
| | | | Lyapunov exponent & spread |
| **Quantum Rigor Mode** | QuantumModeStatusIndicator.gd | event | Readout mode (HARDWARE/INSPECTOR) |
| | | | Backaction mode (KID_LIGHT/LAB_TRUE) |
| | | | Selective measure (POSTSELECT_COSTED) |

### Game State Display

| Panel | File | Purpose |
|-------|------|---------|
| **Action Preview Row** | ActionPreviewRow.gd | Show Q/E/R actions for current tool |
| **Tool Selection Row** | ToolSelectionRow.gd | Display tools 1-6 selection |
| **Resource Panel** | ResourcePanel.gd | Show player resources/inventory |
| **Goal Panel** | GoalPanel.gd | Display current objectives |
| **Info Panel** | InfoPanel.gd | General information display |
| **Biome Info Display** | BiomeInfoDisplay.gd | Statistics for active biome |
| **Biome Inspector Overlay** | BiomeInspectorOverlay.gd | Detailed biome inspection |
| **Emoji Grid Display** | EmojiGridDisplay.gd | Grid of emoji states in biome |
| **Network Info Panel** | NetworkInfoPanel.gd | Graph visualization of relationships |

### Configuration & Control

| Panel | File | Purpose |
|-------|------|---------|
| **Quantum Rigor Config UI** | QuantumRigorConfigUI.gd | Configure quantum behavior modes |
| **Logger Config Panel** | LoggerConfigPanel.gd | Configure logging output |
| **Action Panel Mode Select** | ActionPanelModeSelect.gd | Select tool mode |
| **Keyboard Hint Button** | KeyboardHintButton.gd | Show keyboard shortcuts |

### Menus

| Menu | File | Purpose |
|------|------|---------|
| **Escape Menu** | EscapeMenu.gd | Pause/main menu |
| **Save/Load Menu** | SaveLoadMenu.gd | Save and load game state |

### Quest & Faction Systems

| Panel | File | Purpose |
|-------|------|---------|
| **Quest Panel** | QuestPanel.gd | Quest information |
| **Quest Board** | QuestBoard.gd | Browse available quests |
| **Faction Browser** | FactionBrowser.gd | Browse factions |
| **Faction Quest Offers** | FactionQuestOffersPanel.gd | Faction-specific quests |
| **Contract Panel** | ContractPanel.gd | Contract display |

### Visual Components

| Component | File | Purpose |
|-----------|------|---------|
| **Plot Grid Display** | PlotGridDisplay.gd | Grid visualization |
| **Plot Tile** | PlotTile.gd | Individual tile visualization |
| **Entanglement Lines** | EntangledLines.gd | Visual links between entangled plots |
| **Icon Energy Field** | IconEnergyField.gd | Energy field around icons |
| **Celestial Plot** | CelestialPlot.gd | Sun/moon visualization |
| **Sun/Moon Plot** | SunMoonPlot.gd | Celestial body display |
| **Ecosystem Graph Visualizer** | EcosystemGraphVisualizer.gd | Graph of ecosystem connections |
| **Visual Effects** | VisualEffects.gd | Particle effects, animations |

### Input & Management

| System | File | Purpose |
|--------|------|---------|
| **Farm Input Handler** | FarmInputHandler.gd | Keyboard-driven actions |
| **Controls Interface** | ControlsInterface.gd | Unified input interface |
| **Farm UI** | FarmUI.gd | Main UI coordinator |
| **UI Layout Manager** | UILayoutManager.gd | Layout coordination |
| **Overlay Manager** | OverlayManager.gd | Overlay management |
| **Action Bar Manager** | ActionBarManager.gd | Action bar coordination |
| **Touch Input Manager** | TouchInputManager.gd | Mobile touch handling |
| **Farm View** | FarmView.gd | Main visual display |
| **Parametric Plot Positioner** | ParametricPlotPositioner.gd | Plot positioning |

---

## PART 3: KEYBOARD INPUT MAPPING

| Key | Action | Context |
|-----|--------|---------|
| **1-6** | Select tool | Any |
| | Tool 1: Grower 🌱 | |
| | Tool 2: Quantum ⚛️ | |
| | Tool 3: Industry 🏭 | |
| | Tool 4: Biome Control ⚡ | |
| | Tool 5: Gates 🔄 | |
| | Tool 6: Biome 🌍 | |
| **Q** | Primary action | Context-sensitive per tool |
| **E** | Secondary action | Context-sensitive per tool |
| **R** | Tertiary action | Context-sensitive per tool |
| **WASD** | Movement/cursor control | Farm view |
| **T-Y-U-I-O-P** | Quick-access locations | Farm navigation |
| **ESC** | Pause menu | Any |
| **SPACE** | Confirm selection | Various |

---

## PART 4: SUBMENU SYSTEM

### Plant Submenu (Tool 1, Q action)
**Context-Aware - Changes by Active Biome:**

| Biome | Q | E | R |
|-------|---|---|---|
| **Kitchen** | Plant bread | Plant alternative | Clear |
| **Forest** | Plant woodland | Plant mushroom | Clear |
| **Market** | Plant wheat | Plant trade crop | Clear |
| **BioticFlux** | Plant biotic | Plant symbiotic | Clear |

**Generated by:** `get_dynamic_submenu("plant", farm, selection)`

### Energy Tap Submenu (Tool 4, Q action)
**Dynamic - First 3 Discovered Emojis:**

| Submenu | Q | E | R |
|---------|---|---|---|
| energy_tap | Tap emoji 1 | Tap emoji 2 | Tap emoji 3 |

**Generated by:** `get_dynamic_submenu("energy_tap", farm, selection)`

### Pump/Reset Submenu (Tool 4, E action)
**Static Options:**

| Submenu | Q | E | R |
|---------|---|---|---|
| pump_reset | Pump to wheat | Reset pure | Reset mixed |

### Biome Assign Submenu (Tool 6, Q action)
**Dynamic - First 3 Discovered Biomes:**

| Submenu | Q | E | R |
|---------|---|---|---|
| biome_assign | Assign biome 1 | Assign biome 2 | Assign biome 3 |

### 1-Qubit Gates Submenu (Tool 5, Q action)
**Static Gate Selection:**

| Submenu | Q | E | R |
|---------|---|---|---|
| 1q_gates | Pauli-X | Hadamard | Pauli-Z |

### 2-Qubit Gates Submenu (Tool 5, E action)
**Static Gate Selection:**

| Submenu | Q | E | R |
|---------|---|---|---|
| 2q_gates | CNOT | CZ | SWAP |

---

## SUMMARY STATISTICS

| Category | Count |
|----------|-------|
| **Total Tools** | 6 |
| **Total Submenus** | 8 |
| **Total UI Panels** | 35+ |
| **Visualization Components** | 10+ |
| **Keyboard Shortcuts** | 16+ |
| **Management Systems** | 4 |

---

## KEY SYSTEMS

### Input Flow
**FarmInputHandler.gd** → Tool selection (1-6) → Action selection (Q/E/R) → Submenu selection (if needed) → Execution

### UI Hierarchy
- **Main Screen:** FarmUI (coordinator)
  - FarmView (main display)
  - ActionBar (tools + actions)
  - InfoPanels (dynamic panels on sides)

### State Dependencies
- **Tool availability** depends on biome initialization
- **Submenu content** generated from game state (discovered biomes, emojis)
- **UI updates** tied to quantum evolution callbacks
- **Visualization** follows QuantumComputer state changes

