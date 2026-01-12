# SpaceWheat Tool Architecture v2.1
## The Quantum Tomography Paradigm

**Version:** 2.1  
**Date:** January 2026  
**Status:** Design Specification  

---

## Executive Summary

This document defines the reorganized tool system for SpaceWheat, shifting from an "agricultural grid" metaphor to a "quantum tomography" paradigm. The core insight: **Plots are probes into a pre-existing quantum soup, not containers for player-created states.**

### Key Changes
- **EXPLORE** replaces **PLANT** as the primary action (probability-weighted discovery)
- **PLANT/INJECT** becomes a high-tier expansion mechanic (adding new qubits to biomes)
- **Plots** are generic terminals (no x,y coordinates) that bind to Registers
- **Bubbles** visualize bound state above Plots in a force graph
- **Tools [1-6]** handle actions in the default viewport
- **Overlays** are full tool contexts with their own QER+F actions and alternate viewports
- **Spacebar** pauses/resumes quantum evolution
- **F-cycling** expands action vocabulary within tools
- **Touch-first design** — no hover states or tooltips

---

## I. Terminology

### Player-Facing Terms (UI/Narrative Layer)

| Term | Definition |
|------|------------|
| **Plot** | A farm slot that can be activated to explore the quantum soup. The player's primary interface. |
| **Bubble** | The visual manifestation of a quantum state above an active Plot. Shows emoji, probability, phase. |
| **Tether** | Glowing connection between Bubbles indicating entanglement or coherence. |
| **Biome** | A distinct quantum ecosystem (Kitchen, Forest, Market, BioticFlux). Each has unique dynamics. |
| **Harvest** | Collecting classical resources from a measured/collapsed Bubble. |

### Technical Terms (Simulation Layer)

| Term | Definition |
|------|------------|
| **Terminal** | The quantum-layer name for a Plot. A generic hardware port that binds to Registers. |
| **Register** | A DualEmojiQubit within an Icon bundle. Has north pole (|0⟩) and south pole (|1⟩) emojis. |
| **Tank** | The quantum-layer name for a Biome. Contains the density matrix ρ and Icon bundles. |
| **Icon** | Hamiltonian personality governing a bundle of Registers. Defines evolution dynamics. |
| **Density Matrix (ρ)** | The mathematical state of the quantum soup. Diagonals = probabilities, off-diagonals = coherence. |

### Mapping

```
Player Layer          Quantum Layer
───────────────────────────────────
Plot            ←→    Terminal
Biome           ←→    Tank
"What's growing" ←→   Register state
Bubble glow     ←→    Probability amplitude
Tether          ←→    Off-diagonal ρ_ij
```

---

## II. Core Mechanics

### The Paradigm Shift

| Old Model | New Model |
|-----------|-----------|
| Plot is empty dirt | Plot is a probe into quantum soup |
| Player plants specific emoji | Player explores to discover what's there |
| State created by player action | State pre-exists; player reveals it |
| Grid positions matter | Plot identity matters (Plot_01, not Plot(3,2)) |
| Harvest = end of growth cycle | Harvest = pop measured bubble, unbind plot |

### 2.1 EXPLORE (Primary Action)

**What happens:**
1. Player activates an unbound Plot
2. System queries the Biome's density matrix for unbound Registers
3. Weighted RNG selection based on diagonal elements (probabilities)
4. Plot binds to the winning Register
5. Bubble spawns above Plot, displaying the bound emoji

**Key constraint: Unique Binding**
- Each Register can only be bound by ONE Plot at a time
- Once Plot_01 binds to the 🌾 Register, no other Plot can find 🌾 until Plot_01 unbinds
- This means progressive exploration reveals the quantum soup
- High-probability states are found first; rare states require more Plots

**Fail states:**
- No unbound Plots available → "All plots in use"
- No unbound Registers available → "Quantum vacuum" (the soup is fully mapped)

### 2.2 MEASURE (Collapse)

**What happens:**
1. Player selects a Bubble
2. Wavefunction collapse via Born rule: outcome sampled from P(k) = ⟨k|ρ|k⟩
3. Density matrix projects: ρ → |k⟩⟨k| / P(k)
4. Entanglement breaks: Tethers to this Bubble snap
5. Bubble freezes (stops pulsing, becomes solid)
6. Classical outcome determined but not yet harvested

**Visual feedback:**
- Bubble stops animating
- Tethers play "snap" animation and disappear
- Bubble displays definite emoji (no superposition glow)

### 2.3 POP / HARVEST (Resource Extraction)

**What happens:**
1. Player taps a frozen (measured) Bubble
2. Classical resource added to inventory based on outcome emoji
3. Plot unbinds from Register
4. Bubble disappears
5. Plot becomes available for new EXPLORE action
6. Register becomes available for other Plots to discover

**The Loop:**
```
EXPLORE → [Evolution time passes] → MEASURE → POP → EXPLORE...
```

### 2.4 INJECT / PLANT (Expansion)

**Reframing:** The old "PLANT" action becomes a high-tier expansion mechanic.

**What happens:**
1. Player spends significant resources (Quantum Flux, faction materials)
2. New DualEmojiQubit pair added to Biome's Icon bundle
3. Hilbert space expands: 2^N → 2^(N+1)
4. New basis states become available for EXPLORE discovery

**When to use:**
- Biome lacks desired emoji types
- Player wants to introduce new faction dynamics
- Strategic expansion of quantum vocabulary

**Cost considerations:**
- Should require meaningful resource investment
- May require faction reputation or quest completion
- Introduces new quantum dynamics (not just new emoji)

---

## III. Tool Configuration

### Design Principles

1. **Tools = Actions ONLY** — No analysis, inspection, or information display
2. **Overlays = Information** — Side panel buttons handle all analysis/status
3. **F-cycling** — Expands action vocabulary within a tool without adding tools
4. **Strong separation** — BUILD mode (world configuration) vs PLAY mode (gameplay)

### 3.1 Tool Layout Overview

```
GLOBAL CONTROLS (Always Active)
────────────────────────────────────────────────────────
  [Spacebar]  Pause/Resume quantum evolution
  [Tab]       Toggle BUILD/PLAY mode
  [Escape]    Close overlay / Cancel / Pause menu
────────────────────────────────────────────────────────

DEFAULT VIEWPORT — PLAY MODE
────────────────────────────────────────────────────────
  [1] PROBE      [2] GATES      [3] ENTANGLE   [4] INJECT
      Q: Explore     Q: [F→]        Q: [F→]        Q: Seed
      E: Measure     E: [F→]        E: [F→]        E: Drive
      R: Pop         R: [F→]        R: [F→]        R: Purge

  [F] cycles through action modes within Tools 2 and 3
────────────────────────────────────────────────────────

DEFAULT VIEWPORT — BUILD MODE (Tab to toggle)
────────────────────────────────────────────────────────
  [1] BIOME       [2] ICON       [3] LINDBLAD   [4] SYSTEM
      Q: Paint       Q: Weights     Q: Decay       Q: Integrator
      E: Merge       E: Couplings   E: Transfer    E: Step size
      R: Split       R: Drivers     R: Gated       R: Benchmark
────────────────────────────────────────────────────────

OVERLAY CONTEXT (When overlay is open)
────────────────────────────────────────────────────────
  [1-6] Disabled (or closes overlay)
  [Q][E][R][F] Remapped to overlay-specific actions
  [WASD] Navigate/select within overlay viewport
  [Escape] or [Overlay Button] Close overlay
────────────────────────────────────────────────────────
```

### 3.2 Tool 1: PROBE 🔬
*"Interface with the quantum soup"*

This is 80% of gameplay. The core loop lives here.

| Key | Action | Description |
|-----|--------|-------------|
| **Q** | **EXPLORE** | Bind an empty Plot to a random unbound Register (probability-weighted RNG) |
| **E** | **MEASURE** | Collapse the selected Bubble's wavefunction |
| **R** | **POP** | Harvest the measured Bubble → collect resource → unbind Plot |

**No F-cycling** — These three actions are the fundamental loop.

**Interaction pattern:**
- Q: Click empty Plot → EXPLORE executes → Bubble spawns
- E: Click active Bubble → MEASURE executes → Bubble freezes
- R: Click frozen Bubble → POP executes → Resources collected, Bubble disappears

### 3.3 Tool 2: GATES 🔄
*"Apply unitary transformations to bound Registers"*

Gates operate on Plots (which are bound to Registers). Select target Plot(s), then press Q/E/R.

| Mode | Q | E | R |
|------|---|---|---|
| **Basic** | X (bit flip) | Y (flip + phase) | H (superposition) |
| **Phase** | S (π/2 phase) | T (π/4 phase) | Rφ (custom phase) |
| **Two-Qubit** | CNOT | CZ | SWAP |

**F-cycling:** Basic → Phase → Two-Qubit → Basic...

**Interaction pattern:**
- Single-qubit gates: Select one Bubble, press Q/E/R
- Two-qubit gates: Select two Bubbles (in order: control, target), press Q/E/R

### 3.4 Tool 3: ENTANGLE 🔗
*"Create and manipulate quantum correlations"*

Creates entanglement between bound Registers. Visual feedback via Tethers.

| Mode | Q | E | R |
|------|---|---|---|
| **Bell** | Φ+ (standard) | Φ- (anti-correlated) | Ψ+/Ψ- (flip variants) |
| **Cluster** | GHZ (3+ way) | W (distributed) | Graph state |
| **Manipulate** | Phase shift | Disentangle | Transfer |

**F-cycling:** Bell → Cluster → Manipulate → Bell...

**Interaction pattern:**
- Bell states: Select exactly 2 Bubbles
- Cluster states: Select 3+ Bubbles
- Manipulate: Select target Bubble(s) for modification

**Visual feedback:**
- Tethers appear when entanglement is created
- Tether properties should reflect coherence magnitude and phase relationship
- *Verify: Check existing force graph documentation for Tether visualization specs*

### 3.5 Tool 4: INJECT 💉
*"Expand and shape the quantum soup"*

High-tier actions that modify the Biome's quantum structure. Expensive, rare use.

| Key | Action | Description |
|-----|--------|-------------|
| **Q** | **SEED** | Inject new DualEmojiQubit pair into Biome (expand Hilbert space) |
| **E** | **DRIVE** | Apply Hamiltonian driver to specific emoji type (bias future EXPLORE probabilities) |
| **R** | **PURGE** | Remove a Qubit from simulation (contract Hilbert space, dangerous) |

**No F-cycling** — Each action is distinct and consequential.

**Cost structure (suggested):**
- SEED: Quantum Flux + Faction-specific materials + possible reputation requirement
- DRIVE: Energy resources + temporary effect duration
- PURGE: Confirmation dialog, may have faction reputation consequences

---

## IV. BUILD Mode Tools

BUILD mode handles world configuration separate from gameplay. Accessed via Tab toggle.

### 4.1 Tool 1: BIOME DESIGN
*"Configure biome boundaries and territories"*

| Key | Action | Description |
|-----|--------|-------------|
| **Q** | **Paint** | Assign territory to biome type |
| **E** | **Merge** | Combine adjacent biome regions |
| **R** | **Split** | Divide biome into sub-regions |

### 4.2 Tool 2: ICON TUNING
*"Adjust Hamiltonian parameters"*

| Key | Action | Description |
|-----|--------|-------------|
| **Q** | **Weights** | Adjust faction influence weights |
| **E** | **Couplings** | Modify J_ij coupling strengths |
| **R** | **Drivers** | Configure time-dependent drives |

### 4.3 Tool 3: LINDBLAD CONTROL
*"Configure dissipation and decoherence"*

| Key | Action | Description |
|-----|--------|-------------|
| **Q** | **Decay** | Set decay rates (T1) |
| **E** | **Transfer** | Configure population transfer operators |
| **R** | **Gated** | Set up gated Lindblad conditions |

### 4.4 Tool 4: SYSTEM CONFIG
*"Simulation parameters"*

| Key | Action | Description |
|-----|--------|-------------|
| **Q** | **Integrator** | Select evolution method (Euler, Cayley, Expm, RK4) |
| **E** | **Step Size** | Adjust dt for evolution |
| **R** | **Benchmark** | Run performance diagnostics |

---

## V. UI Layout Specification

### 5.1 Screen Regions

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOP BAR: Classical Resources                  │
│              [⬡][⬡][⬡][⬡][⬡][⬡][⬡][⬡][⬡][⬡][⬡][⬡]              │
│         (Wheat, Flux, Credits, Crops, etc. - expandable)        │
└─────────────────────────────────────────────────────────────────┘

┌────────┐                                            ┌────────┐
│  LEFT  │                                            │ RIGHT  │
│ OVERLAY│         ┌────────────────────┐            │ OVERLAY│
│ BUTTONS│         │                    │            │ BUTTONS│
│        │         │   MAIN VIEWPORT    │            │        │
│  [⬡]   │         │                    │            │  [⬡]   │
│  [⬡]   │         │   Force Graph      │            │  [⬡]   │
│  [⬡]   │         │   Bubbles          │            │  [⬡]   │
│  [⬡]   │         │   Tethers          │            │  [⬡]   │
│  [⬡]   │         │   Biome Regions    │            │  [⬡]   │
│        │         │                    │            │        │
│ [LED]  │         └────────────────────┘            │ [LED]  │
└────────┘                                            └────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    BOTTOM BAR: Tool Selection                    │
│                                                                  │
│                   [1]  [2]  [3]  [4]  [5]  [6]                  │
│                                                                  │
│                      [Q]    [E]    [R]                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 5.2 Overlay System (Side Hexagons)

**Key concept:** Overlays are not just information panels — they are **full tool contexts** with their own viewport and QER+F action mappings.

When an overlay is open:
- The main viewport switches to the overlay's alternate view
- QER+F keys remap to overlay-specific actions
- Selection methods: WASD navigation, Plot ID input, or touch selection
- Number keys [1-6] are disabled (or close overlay and switch tool)
- Press the overlay button again (or Escape) to close and return to default viewport

#### Overlay Definitions

| Button | Overlay | Alternate Viewport | QER+F Actions |
|--------|---------|-------------------|---------------|
| 📊 | **Inspector** | Density matrix heatmap, state vector display | Q: Select register, E: Show details, R: Compare states, F: Cycle view mode |
| 🧭 | **Semantic Map** | Octant visualization, meaning-space | Q: Navigate octant, E: Zoom region, R: Show attractors, F: Cycle projection |
| 🗺️ | **Macro Map** | Galaxy/world view, biome territories | Q: Select biome, E: Zoom, R: Show connections, F: Cycle layer |
| 📜 | **Quests** | Contract list, faction standings | Q: Select quest, E: View details, R: Accept/Abandon, F: Filter by faction |
| ⌨️ | **Controls** | Hotkey reference, tool guide | Q/E/R: Navigate sections, F: Toggle compact/full |
| 👤 | **Profile** | Player stats, vocabulary, achievements | Q: Select category, E: View details, R: Toggle display, F: Cycle tabs |
| 🔬 | **Biome Detail** | Current biome close-up, Icon info | Q: Select Icon, E: Show parameters, R: Show registers, F: Cycle Icon |

#### Selection Methods Within Overlays

Since overlays have their own viewports with selectable elements:

- **WASD** — Navigate between selectable elements (grid/list navigation)
- **Plot ID / Element ID** — Direct input to jump to specific item (if applicable)
- **Touch** — Direct tap selection on touch devices
- **Arrow Keys** — Alternative to WASD

*Note: No hover states. All information must be accessible via explicit selection actions.*

#### Inspector Overlay (Non-Destructive Inspection)

The Inspector overlay deserves special attention as the primary analysis tool:

**Viewport:** Shows density matrix as heatmap, with Bubbles overlaid showing their Register indices

**Actions:**
| Key | Action | Description |
|-----|--------|-------------|
| **Q** | **Select** | Highlight a Register/Bubble for detailed view |
| **E** | **Details** | Show full state info for selected (amplitude, phase, entropy, purity) |
| **R** | **Compare** | Toggle comparison mode (select two, see correlation) |
| **F** | **Cycle View** | Bloch sphere → Density matrix → Probability bars → Bloch sphere... |

**Selection:** WASD moves highlight between Bubbles/Registers, or tap directly on touch

### 5.3 Main Viewport: Force Graph

The central viewport displays the quantum state visualization:

**Elements:**
- **Biome Regions** — Watercolor-style backgrounds indicating different Tanks
- **Plots** — Floating chip-like objects (the "terminals")
- **Bubbles** — Glowing emoji indicators above bound Plots
- **Tethers** — Lines connecting entangled/coherent Bubbles

**Touch-First Design Principle:**
- No hover states or tooltips anywhere
- All information accessible via explicit selection (tap/click) or Inspector overlay
- Visual state (size, color, pulse, brightness) conveys information at a glance
- Detailed information requires opening Inspector overlay and selecting the element

**Suggested Bubble Properties to Verify:**
- Position driven by phase and semantic similarity in force graph
- Size driven by probability amplitude P(k)
- Brightness/glow driven by coherence level
- Pulse rate driven by evolution speed
- Color driven by emoji category
- Frozen state (post-measure) visually distinct from active state

**Suggested Tether Properties to Verify:**
- Existence threshold based on |ρ_ij| magnitude
- Thickness representing coherence strength
- Animation style representing phase relationship
- Color indicating entanglement type

*Action item: Cross-reference with existing force graph design documentation to ensure consistency.*

### 5.4 Global Controls

Controls that work regardless of current tool or overlay state:

| Key | Action | Description |
|-----|--------|-------------|
| **Spacebar** | **Pause/Resume** | Toggle quantum evolution on/off. Visual indicator should show paused state. |
| **Tab** | **Toggle BUILD/PLAY** | Switch between gameplay mode and world configuration mode |
| **Escape** | **Close/Back** | Close current overlay, cancel current action, or open pause menu |
| **1-6** | **Select Tool** | Switch active tool (only in default viewport, not in overlays) |

**Pause State Behavior:**
- When paused, density matrix evolution halts
- Bubbles stop pulsing/drifting (or pulse very slowly to indicate frozen)
- Player can still EXPLORE, MEASURE, POP (these are instantaneous)
- Player can still apply GATES and ENTANGLE operations
- Tethers freeze in current state
- Clear visual indicator (e.g., pause icon, desaturated colors, or "PAUSED" overlay text)

**Pause Use Cases:**
- Strategic planning before measurement
- Applying gate sequences without evolution interference
- Examining state without time pressure
- Teaching/learning moments

---

## VI. Implementation Notes

### 6.1 Plot/Terminal Pool Architecture

**Key change:** Plots no longer have (x, y) coordinates. They are a pool of generic terminals.

```gdscript
# Suggested structure - verify against existing codebase
class_name PlotPool

var plots: Array[Plot] = []
var binding_table: Dictionary = {}  # plot_id → register_id

func get_unbound_plot() -> Plot:
    for p in plots:
        if not binding_table.has(p.id):
            return p
    return null

func bind_plot(plot: Plot, register: Register):
    binding_table[plot.id] = register.id
    register.bound_plot = plot
    emit_signal("plot_bound", plot, register)

func unbind_plot(plot: Plot):
    var register_id = binding_table.get(plot.id)
    if register_id:
        var register = get_register(register_id)
        register.bound_plot = null
        binding_table.erase(plot.id)
        emit_signal("plot_unbound", plot)
```

### 6.2 EXPLORE Action Logic

```gdscript
# Suggested implementation - verify against existing quantum infrastructure
func action_explore():
    var plot = plot_pool.get_unbound_plot()
    if not plot:
        notify_player("All plots in use")
        return
    
    var biome = get_active_biome()
    var available_registers = biome.get_unbound_registers()
    
    if available_registers.is_empty():
        notify_player("Quantum vacuum - nothing to explore")
        return
    
    # Probability-weighted selection from density matrix diagonals
    var weights: Array[float] = []
    for reg in available_registers:
        var prob = biome.density_matrix.get_diagonal(reg.index)
        weights.append(prob)
    
    var selected_register = weighted_random_choice(available_registers, weights)
    
    plot_pool.bind_plot(plot, selected_register)
    spawn_bubble(plot, selected_register)
```

### 6.3 Measurement Action Logic

```gdscript
func action_measure(bubble: Bubble):
    var plot = bubble.plot
    var register = plot.bound_register
    var biome = plot.biome
    
    # Born rule sampling
    var outcome = biome.quantum_computer.measure(register.index)
    
    # Collapse density matrix
    biome.density_matrix.project_to_state(register.index, outcome)
    
    # Break entanglement visually
    for tether in bubble.get_tethers():
        tether.play_snap_animation()
        tether.queue_free()
    
    # Freeze bubble
    bubble.set_frozen(true, outcome)
    
    emit_signal("measurement_complete", register, outcome)
```

### 6.4 F-Cycling Implementation

```gdscript
# Per-tool mode tracking
var tool_modes: Dictionary = {
    2: 0,  # GATES: 0=Basic, 1=Phase, 2=TwoQubit
    3: 0,  # ENTANGLE: 0=Bell, 1=Cluster, 2=Manipulate
}

func handle_f_press():
    var current_tool = get_active_tool()
    if tool_modes.has(current_tool):
        var max_modes = get_max_modes(current_tool)
        tool_modes[current_tool] = (tool_modes[current_tool] + 1) % max_modes
        update_action_labels(current_tool)
        emit_signal("mode_changed", current_tool, tool_modes[current_tool])

func get_action_for_key(tool: int, key: String) -> String:
    var mode = tool_modes.get(tool, 0)
    return ACTION_TABLE[tool][mode][key]

const ACTION_TABLE = {
    2: {  # GATES
        0: {"Q": "gate_x", "E": "gate_y", "R": "gate_h"},      # Basic
        1: {"Q": "gate_s", "E": "gate_t", "R": "gate_rphi"},   # Phase
        2: {"Q": "gate_cnot", "E": "gate_cz", "R": "gate_swap"} # TwoQubit
    },
    3: {  # ENTANGLE
        0: {"Q": "bell_phi_plus", "E": "bell_phi_minus", "R": "bell_psi"},  # Bell
        1: {"Q": "cluster_ghz", "E": "cluster_w", "R": "cluster_graph"},    # Cluster
        2: {"Q": "manip_phase", "E": "manip_disentangle", "R": "manip_transfer"} # Manipulate
    }
}
```

### 6.5 Overlay Context System

```gdscript
# Overlay state management
var active_overlay: String = ""  # Empty = default viewport
var overlay_selection: int = -1  # Current selected element in overlay

# Each overlay defines its own action table
const OVERLAY_ACTIONS = {
    "inspector": {
        "Q": "select_register",
        "E": "show_details", 
        "R": "compare_states",
        "F": "cycle_view_mode"
    },
    "semantic_map": {
        "Q": "navigate_octant",
        "E": "zoom_region",
        "R": "show_attractors",
        "F": "cycle_projection"
    },
    # ... other overlays
}

func handle_input(event: InputEvent):
    # Global controls always work
    if event.is_action_pressed("pause"):  # Spacebar
        toggle_evolution_pause()
        return
    
    if event.is_action_pressed("toggle_mode"):  # Tab
        toggle_build_play_mode()
        return
    
    if event.is_action_pressed("escape"):
        if active_overlay != "":
            close_overlay()
        else:
            open_pause_menu()
        return
    
    # Context-dependent controls
    if active_overlay != "":
        handle_overlay_input(event)
    else:
        handle_default_viewport_input(event)

func handle_overlay_input(event: InputEvent):
    # WASD navigation
    if event.is_action_pressed("ui_up"):
        navigate_overlay_selection(-1, 0)
    elif event.is_action_pressed("ui_down"):
        navigate_overlay_selection(1, 0)
    elif event.is_action_pressed("ui_left"):
        navigate_overlay_selection(0, -1)
    elif event.is_action_pressed("ui_right"):
        navigate_overlay_selection(0, 1)
    
    # QER+F actions remapped to overlay
    elif event.is_action_pressed("action_q"):
        execute_overlay_action(active_overlay, "Q")
    elif event.is_action_pressed("action_e"):
        execute_overlay_action(active_overlay, "E")
    elif event.is_action_pressed("action_r"):
        execute_overlay_action(active_overlay, "R")
    elif event.is_action_pressed("action_f"):
        execute_overlay_action(active_overlay, "F")
    
    # Number keys disabled or close overlay
    elif event.is_action_pressed("tool_1") or event.is_action_pressed("tool_2"):
        # Option A: Ignore
        # Option B: close_overlay() and switch_tool()
        pass

func handle_default_viewport_input(event: InputEvent):
    # Number keys select tool
    if event.is_action_pressed("tool_1"):
        select_tool(1)
    # ... etc
    
    # QER+F execute current tool actions
    elif event.is_action_pressed("action_q"):
        execute_tool_action(current_tool, "Q")
    # ... etc

func toggle_evolution_pause():
    evolution_paused = not evolution_paused
    emit_signal("pause_state_changed", evolution_paused)
    # Visual feedback handled by UI listening to this signal
```

### 6.6 Pause System

```gdscript
var evolution_paused: bool = false

func _physics_process(delta: float):
    if evolution_paused:
        return  # Skip evolution
    
    for biome in active_biomes:
        biome.quantum_computer.evolve(delta)
        biome.update_bubble_visuals()
        biome.update_tether_visuals()

# Instantaneous actions still work while paused
func action_explore():
    # Works regardless of pause state
    # ...

func action_measure(bubble: Bubble):
    # Works regardless of pause state
    # ...

func action_apply_gate(bubble: Bubble, gate: String):
    # Works regardless of pause state
    # ...
```

---

## VII. Migration Checklist

### From Current System

- [ ] Replace Plot(x, y) with Plot_ID system
- [ ] Implement PlotPool with binding table
- [ ] Add EXPLORE action to replace PLANT as primary
- [ ] Move PLANT logic to INJECT/SEED (high-tier)
- [ ] Implement F-cycling for Tools 2 and 3
- [ ] Add BUILD/PLAY mode toggle (Tab)
- [ ] Implement Spacebar pause/resume for evolution
- [ ] Remove all hover states and tooltips
- [ ] Implement overlay context system with QER+F remapping
- [ ] Add WASD navigation for overlay viewports
- [ ] Update UI to match new layout spec

### Overlay System Implementation

- [ ] Define overlay viewport scenes for each overlay type
- [ ] Implement overlay action handlers (OVERLAY_ACTIONS table)
- [ ] Create Inspector overlay with density matrix visualization
- [ ] Create Semantic Map overlay with octant navigation
- [ ] Implement overlay open/close transitions
- [ ] Add selection highlighting for overlay navigation
- [ ] Test touch input for overlay selection

### Verification Tasks

- [ ] Cross-reference force graph design docs for Bubble/Tether properties
- [ ] Verify density matrix query methods exist for EXPLORE probability weights
- [ ] Confirm measurement collapse logic in quantum computer
- [ ] Check existing Icon bundle structure for Register binding compatibility
- [ ] Review faction system for INJECT/SEED cost structures
- [ ] Verify existing modal menu QER remapping can be extended for overlays

---

## VIII. Open Questions

### Gameplay Balance
1. How many Plots should a player start with?
2. How are new Plots acquired? (Progression? Purchase? Quest rewards?)
3. What's the resource cost curve for INJECT/SEED?
4. Should EXPLORE have a cooldown or cost?
5. How long should default evolution timestep be? How does pause affect strategy?

### Technical Architecture
1. When Plot binds to Register, does it bind to a specific Icon bundle or the whole Biome?
2. Can Plots bind to Registers across Icon bundle boundaries?
3. How does cross-biome entanglement work with the binding system?
4. Does partial measurement (one Register in an entangled set) collapse the whole set?

### UI/UX
1. How does player select multiple Bubbles for multi-target operations (entanglement, 2-qubit gates)?
2. Should F-cycle mode indicator be visible in the tool button area?
3. How to indicate which Registers are currently unbound (available for EXPLORE)?
4. Visual distinction between bound-but-unmeasured vs measured-but-not-popped Bubbles?
5. What's the visual indicator for paused state?
6. Should number keys [1-6] close the overlay and switch tool, or just be disabled in overlay context?

### Overlay System
1. Can multiple overlays be open simultaneously (split view)?
2. Should overlay state persist when closed and reopened?
3. Do overlays pause evolution automatically, or respect current pause state?
4. How do overlay-specific actions interact with the quantum state? (e.g., can Inspector's "Compare" affect anything, or is it purely read-only?)

---

## IX. Summary

### The Core Loop (80% of Gameplay)

```
[1Q] EXPLORE → Bubble spawns
         ↓
    Time passes, quantum evolution (Spacebar to pause/plan)
         ↓
[1E] MEASURE → Bubble freezes, tethers snap
         ↓
[1R] POP → Resources collected, Plot freed
         ↓
    Return to EXPLORE
```

### The Expansion Loop (20% of Gameplay)

```
Accumulate resources → [4Q] SEED → New emoji types available → EXPLORE finds new states
```

### The Manipulation Layer

```
EXPLORE → Apply GATES [2] → Create ENTANGLE [3] → Strategic MEASURE timing → Optimized harvest
```

### The Analysis Layer

```
Open Inspector Overlay → Navigate to Bubble [WASD] → View Details [E] → Compare States [R] → Close → Act
```

### Control Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GLOBAL CONTROLS                          │
│              [Spacebar] Pause    [Tab] Mode    [Esc] Back       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   DEFAULT VIEWPORT                    OVERLAY VIEWPORT          │
│   ┌─────────────────┐                 ┌─────────────────┐       │
│   │ [1][2][3][4]    │   ←─ toggle ─→  │ [Disabled]      │       │
│   │ Select Tool     │                 │                 │       │
│   │                 │                 │ [WASD] Navigate │       │
│   │ [Q][E][R]       │                 │ [Q][E][R]       │       │
│   │ Tool Actions    │                 │ Overlay Actions │       │
│   │                 │                 │                 │       │
│   │ [F] Cycle Mode  │                 │ [F] Cycle View  │       │
│   └─────────────────┘                 └─────────────────┘       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Design Philosophy

- **The quantum soup exists independently** — Players discover, they don't create
- **Plots are probes** — Dipping into the bath to see what's there
- **Measurement is the game** — When and what to collapse is the core decision
- **Tools are verbs** — Actions only in default viewport
- **Overlays are contexts** — Full tool environments with their own actions and viewports
- **Touch-first** — No hover states, all interaction via explicit selection
- **Pause is strategic** — Spacebar lets players plan without time pressure
- **Physics is real** — The density matrix, entanglement, and collapse are authentic

---

**Document Version:** 2.1  
**Last Updated:** January 2026  
**Next Review:** After implementation of Phase 1 (PlotPool + EXPLORE + Pause)
