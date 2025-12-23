# Hybrid Classical-Quantum Layout Design

**Date**: 2025-12-14
**Status**: Design Proposal
**Purpose**: Replace pure grid with hybrid perimeter farm + central force-directed quantum graph

---

## Core Concept: Dual Representation

Every wheat plot exists in **TWO places simultaneously**:

1. **Classical Plot** (Outer Perimeter) - Static square tile
   - Where you INTERACT (plant, harvest, click)
   - Discrete, orderly, grid-based
   - Shows maturity, wheat/tomato type
   - Classical realm (post-measurement)

2. **Quantum Node** (Center Graph) - Dynamic circle
   - Where you VISUALIZE quantum state
   - Flowing, force-directed, entangled
   - Shows color (phi), size (energy), glow (coherence)
   - Quantum realm (pre-measurement)

**Connection**: Permanent tether line between classical plot ↔ quantum node

---

## Visual Layout

```
┌────────────────────────────────────────────────────┐
│                                                     │
│  [🌾] [🌾] [  ] [🍅] [🌾] [🌾] [  ] [🌾]         │  ← Classical Farm
│   │    │    │    │    │    │    │    │             │     (Perimeter)
│  [🌾]  │    │    │    │    │    │    │   [🌾]     │
│   │    ╲    │    │    │    │    │   ╱      │       │
│  [  ]   ╲   │    │    │    │   ╱         [  ]     │  ← Tether Lines
│   │      ╲  │    │    │   ╱             │         │     (Anchors)
│  [🌾]     ⚛️─────⚛️─────⚛️            [🌾]     │
│   │        ╲  ╱  ╲  ╱                  │         │
│  [🍅]       ⚛️────⚛️                  [🍅]     │  ← Quantum Graph
│   │         │ ╲  ╱ │                   │         │     (Center)
│  [🌾]       │  ⚛️  │                  [🌾]     │     Force-Directed
│   │         │  │ ╲ │                   │         │
│  [  ]       ⚛️─────⚛️                  [  ]     │
│   │        ╱         ╲                 │         │
│  [🌾] [  ] [🌾] [🍅] [🌾] [  ] [🌾] [🌾]         │
│                                                     │
└────────────────────────────────────────────────────┘

Legend:
  [🌾] = Classical plot (square, perimeter)
  ⚛️   = Quantum node (circle, center)
  │╲╱  = Tether line (classical ↔ quantum)
  ──   = Entanglement (quantum ↔ quantum)
```

---

## Layout Geometry

### Perimeter Configuration (5×5 grid example)

**Classical plots arranged as hollow square**:
```
Positions (for 5×5 grid):
Top edge:    (0,0) (1,0) (2,0) (3,0) (4,0)
Right edge:  (4,1) (4,2) (4,3) (4,4)
Bottom edge: (3,4) (2,4) (1,4) (0,4)
Left edge:   (0,3) (0,2) (0,1)

Total: 5+5+5+5 - 4 corners = 16 plots (for 5×5)
But we want 25 plots, so we need multiple rings!
```

**Better: Concentric Rings**

For a 5×5 grid (25 plots):
- **Outer ring**: 16 plots (perimeter of 5×5)
- **Inner ring**: 8 plots (perimeter of 3×3, offset inward)
- **Center**: 1 plot (dead center)

Or simpler: **Just arrange all 25 plots around perimeter of larger square**

```
Screen Layout (800×600):

┌─────────────────────────────────────────┐
│ Margin: 50px                             │
│                                           │
│  ┌─────────────────────────────────┐    │
│  │ [P][P][P][P][P][P][P][P][P]     │    │  ← Classical plots
│  │                                  │    │     (25 plots around edge)
│  │ [P]                          [P] │    │
│  │                                  │    │
│  │ [P]       Quantum Graph      [P] │    │  ← Center: Force-directed
│  │           (Force-Directed)       │    │     quantum visualization
│  │ [P]                          [P] │    │
│  │                                  │    │
│  │ [P][P][P][P][P][P][P][P][P]     │    │
│  └─────────────────────────────────┘    │
│                                           │
│ Action Bar + Stats at bottom             │
└─────────────────────────────────────────┘
```

**Calculation for plot positions**:
```gdscript
# For N plots, distribute around perimeter of square
var total_plots = 25
var perimeter_plots_per_side = ceil(sqrt(total_plots))  # ~5 per side

var plot_spacing = square_size / perimeter_plots_per_side
var current_index = 0

# Top edge
for i in range(perimeter_plots_per_side):
    positions[current_index] = Vector2(i * plot_spacing, 0)
    current_index += 1

# Right edge
for i in range(1, perimeter_plots_per_side):
    positions[current_index] = Vector2(square_size, i * plot_spacing)
    current_index += 1

# Bottom edge (reverse)
for i in range(perimeter_plots_per_side - 1, -1, -1):
    positions[current_index] = Vector2(i * plot_spacing, square_size)
    current_index += 1

# Left edge (reverse)
for i in range(perimeter_plots_per_side - 1, 0, -1):
    positions[current_index] = Vector2(0, i * plot_spacing)
    current_index += 1
```

---

## Force-Directed Graph System

### Quantum Node Forces

Each quantum node experiences:

1. **Tether Spring Force** (toward classical plot position)
   ```gdscript
   var anchor_pos = classical_plot.position
   var tether_vector = anchor_pos - quantum_node.position
   var tether_force = tether_vector * TETHER_SPRING_CONSTANT  # ~0.5
   ```
   - Pulls quantum node toward its classical anchor
   - Prevents graph from flying apart
   - Provides stable reference frame

2. **Repulsion Force** (from other quantum nodes)
   ```gdscript
   for other_node in quantum_nodes:
       var distance = position.distance_to(other_node.position)
       if distance < MIN_DISTANCE:
           var repulsion = (position - other_node.position).normalized()
           repulsion *= REPULSION_STRENGTH / max(distance, 1.0)
           force += repulsion
   ```
   - Prevents nodes from overlapping
   - Creates spacing

3. **Entanglement Attraction** (toward entangled partners)
   ```gdscript
   for entangled_id in quantum_state.entangled_partners:
       var partner_node = quantum_nodes[entangled_id]
       var entangle_vector = partner_node.position - position
       var distance = entangle_vector.length()
       var ideal_distance = 100.0  # Target entanglement distance
       var attraction = entangle_vector.normalized() * (distance - ideal_distance) * ENTANGLE_STRENGTH
       force += attraction
   ```
   - Pulls entangled nodes together
   - Creates visible topology

4. **Damping** (reduce velocity)
   ```gdscript
   velocity *= DAMPING  # ~0.95
   ```
   - Stabilizes graph over time

**Total force integration**:
```gdscript
func _process(delta):
    for quantum_node in quantum_nodes:
        var force = Vector2.ZERO

        # Tether to classical position
        force += calculate_tether_force(quantum_node)

        # Repulsion from all other nodes
        force += calculate_repulsion_forces(quantum_node)

        # Attraction to entangled partners
        force += calculate_entanglement_forces(quantum_node)

        # Update velocity and position
        quantum_node.velocity += force * delta
        quantum_node.velocity *= DAMPING
        quantum_node.position += quantum_node.velocity * delta
```

---

## Visualization Elements

### Classical Plot (Perimeter)

**Visual**:
- Square tile (60×60px)
- Wheat/tomato sprite
- Maturity indicator (growth bar)
- Click target for interactions

**Purpose**:
- Player interaction point
- Shows classical state (planted, mature, empty)
- Discrete, orderly, familiar

### Quantum Node (Center)

**Visual**:
- Circle (radius: 10-40px based on energy)
- Color from phi angle (HSV hue)
- Glow halo (alpha = coherence)
- Emoji label (🌾 or 🍅)

**Properties**:
```gdscript
class QuantumNode:
    var position: Vector2  # In center graph
    var velocity: Vector2
    var quantum_state: DualEmojiQubit
    var energy: float
    var coherence: float
    var color: Color
    var radius: float
```

**Visual Mapping**:
- **Radius**: `10 + energy * 30` (10-40px range)
- **Color Hue**: `(phi + PI) / TAU` (full rainbow)
- **Saturation**: `sin(theta)` (0.3-1.0)
- **Glow Alpha**: `coherence * 0.3` (0-0.3)

### Tether Line

**Visual**:
- Thin line (1-2px)
- Low alpha (0.2-0.3)
- Color: Gray or matching quantum node color
- Always drawn, never animated (static anchor)

**Purpose**:
- Shows correspondence: "this classical plot ↔ this quantum node"
- Provides visual anchor for force-directed graph
- Reinforces quantum-classical divide

### Entanglement Line (Between Quantum Nodes)

**Visual**:
- Thicker line (3px)
- Animated alpha: `0.3 + sin(time) * 0.2`
- Color: Golden/yellow (1.0, 0.8, 0.2)
- Only between quantum nodes (not to classical plots)

**Purpose**:
- Shows quantum entanglement topology
- Animated to show "energy flow"
- Creates beautiful network patterns

---

## Information Density Solution

**Problem**: Too much information to display clearly

**Solution**: Dual representation separates concerns

| Information | Classical Plot | Quantum Node |
|-------------|----------------|--------------|
| Planted? | ✅ Sprite visible | ❌ |
| Wheat/Tomato? | ✅ Emoji | ✅ Emoji label |
| Maturity? | ✅ Growth bar | ❌ |
| Quantum state (θ,φ)? | ❌ | ✅ Color |
| Energy level? | ❌ | ✅ Size |
| Coherence? | ❌ | ✅ Glow intensity |
| Entanglement? | ❌ | ✅ Connection lines |
| Click target? | ✅ | ❌ |

**Each representation shows what it's good at!**

---

## Quantum-Classical Divide Expression

From **CORE_GAME_DESIGN_VISION.md**:

> "SpaceWheat is fundamentally about negotiating the boundary between quantum potentiality and classical actuality."

**How This Layout Expresses It**:

1. **Visual Separation**:
   - Classical: Orderly perimeter (discrete, grid-based)
   - Quantum: Flowing center (continuous, dynamic)
   - Clear spatial divide

2. **Tether Lines = The Bridge**:
   - Measurement is the bridge between realms
   - Tether shows: "this quantum potential → this classical plot"
   - Physically represents the connection

3. **Interaction Flow**:
   ```
   Player clicks classical plot (perimeter)
       ↓
   Action affects quantum state (center)
       ↓
   Quantum graph updates visually
       ↓
   Measurement collapses quantum → classical
       ↓
   Classical plot shows result
   ```

4. **Different Time Scales**:
   - Classical: Discrete events (plant, harvest, measure)
   - Quantum: Continuous evolution (graph moves, energy flows)

---

## Implementation Architecture

### New Components

**`QuantumForceGraph.gd`**:
```gdscript
extends Node2D

var quantum_nodes: Array[QuantumNode] = []
var center_position: Vector2
var graph_radius: float = 300.0

# Force parameters
const TETHER_SPRING = 0.5
const REPULSION_STRENGTH = 1000.0
const ENTANGLE_STRENGTH = 0.3
const DAMPING = 0.95

func _ready():
    center_position = get_viewport_rect().size / 2
    _initialize_quantum_nodes()

func _initialize_quantum_nodes():
    for plot in farm_grid.plots.values():
        var node = QuantumNode.new()
        node.position = center_position  # Start at center
        node.quantum_state = plot.quantum_state
        quantum_nodes.append(node)

func _process(delta):
    _update_node_forces(delta)
    _update_node_visuals()
    queue_redraw()

func _draw():
    # Draw tether lines first (background)
    _draw_tether_lines()

    # Draw entanglement lines
    _draw_entanglement_lines()

    # Draw quantum nodes (foreground)
    _draw_quantum_nodes()
```

**`QuantumNode.gd`**:
```gdscript
class_name QuantumNode

var position: Vector2
var velocity: Vector2 = Vector2.ZERO
var classical_anchor: Vector2  # Position of classical plot
var quantum_state: DualEmojiQubit
var energy: float
var coherence: float
var color: Color
var radius: float

func update_from_quantum_state():
    if not quantum_state:
        return

    # Energy
    energy = quantum_state.get_energy()

    # Coherence
    coherence = quantum_state.get_coherence()

    # Radius from energy (static, not pulsing)
    radius = 10.0 + energy * 30.0  # 10-40px

    # Color from Bloch sphere
    var hue = fmod((quantum_state.phi + PI) / TAU, 1.0)
    var saturation = clamp(sin(quantum_state.theta), 0.3, 1.0)
    var brightness = 0.8
    color = Color.from_hsv(hue, saturation, brightness)
```

### Modified Components

**`FarmView.gd`**:
```gdscript
# Add quantum force graph
var quantum_graph: QuantumForceGraph

func _ready():
    # ... existing setup ...

    # Create quantum force graph
    quantum_graph = QuantumForceGraph.new()
    quantum_graph.farm_grid = farm_grid
    add_child(quantum_graph)

    # Position classical plots around perimeter
    _arrange_plots_on_perimeter()

func _arrange_plots_on_perimeter():
    var viewport_size = get_viewport_rect().size
    var margin = 100
    var square_size = min(viewport_size.x, viewport_size.y) - margin * 2
    var plots_per_side = ceil(sqrt(GRID_SIZE * GRID_SIZE))

    # Calculate perimeter positions for all plots
    # (implementation from earlier)
```

**`PlotTile.gd`**:
```gdscript
# Classical plot remains mostly the same
# Just positioned on perimeter instead of grid

func _draw():
    # Draw square tile
    # Show sprite, growth bar, etc.
    # No quantum visualization here
```

---

## Advantages

### 1. **Educational Clarity**
- Quantum vs Classical visually separated
- Tethers show correspondence
- Students see both representations simultaneously

### 2. **Information Density**
- Classical plots: Gameplay info (planted, mature, clickable)
- Quantum nodes: Physics info (state, energy, entanglement)
- No overlap, no clutter

### 3. **Beautiful Topology**
- Entanglement patterns visible in center graph
- Force-directed layout makes structure clear
- Glowing, flowing energy aesthetic

### 4. **Coherent Structure**
- Tethers prevent chaos
- Graph stays bounded to center
- Classical perimeter provides frame

### 5. **Gameplay Flow**
- Click classical plots (familiar grid interaction)
- Watch quantum graph respond (visual feedback)
- Entanglement topology emerges naturally

---

## Potential Challenges

### 1. **Correspondence Confusion**
**Problem**: Which quantum node corresponds to which classical plot?

**Solution**:
- Tether lines always visible
- Hover over classical plot → highlight quantum node
- Click classical plot → flash corresponding quantum node
- Color-code tethers to match quantum node color

### 2. **Graph Overlap/Chaos**
**Problem**: Quantum nodes overlap or fly around wildly

**Solution**:
- Tether spring force keeps nodes near anchors
- Repulsion prevents overlap
- Damping stabilizes over time
- Adjust force constants for stable equilibrium

### 3. **Performance**
**Problem**: Force calculations every frame for 25 nodes

**Solution**:
- Spatial hashing for repulsion (only check nearby nodes)
- Update at 30 Hz instead of 60 Hz
- GPU shaders for rendering (if needed)

### 4. **Cluttered Tethers**
**Problem**: 25 tether lines crossing everywhere

**Solution**:
- Very thin lines (1px)
- Low alpha (0.15)
- Only draw when quantum node is far from anchor
- Or: draw tethers in separate layer, toggle visibility

---

## Implementation Priority

### Phase 1: Basic Dual Layout (2-3 days)
1. Arrange classical plots on perimeter
2. Create QuantumForceGraph component
3. Initialize quantum nodes at center
4. Draw tether lines (static)
5. Basic force-directed update (tether + repulsion only)

**Deliverable**: See dual representation with tethers

### Phase 2: Quantum Visuals (1-2 days)
1. Color from phi/theta
2. Size from energy (static, no pulsing)
3. Glow halo from coherence
4. Entanglement lines with animated alpha

**Deliverable**: Beautiful glowing quantum graph

### Phase 3: Interaction & Polish (1-2 days)
1. Hover highlights
2. Click flashes
3. Measurement effects
4. Force tuning for stability

**Deliverable**: Fully playable with new layout

---

## Design Validation

**Does this express the quantum-classical divide?** ✅
- Visual separation: perimeter vs center
- Tether lines = the bridge
- Different aesthetics: static grid vs flowing graph

**Does this reduce information density?** ✅
- Classical plots: Gameplay info only
- Quantum nodes: Physics info only
- Clear separation of concerns

**Does this support educational goals?** ✅
- Students see both representations
- Tethers teach correspondence
- Quantum topology becomes visible

**Does this create the "liquid neural net" feel?** ✅
- Force-directed graph flows organically
- Glowing nodes and connections
- Energy and coherence visible

**Can we afford the complexity?** ✅
- Force calculations: O(N²) but N=25 is fine
- Rendering: Standard 2D primitives
- Estimated 60 FPS on modest hardware

---

## Final Recommendation

**Implement the hybrid layout.**

It's:
1. ✅ Pedagogically sound (shows quantum-classical divide)
2. ✅ Visually stunning (force-directed quantum graph)
3. ✅ Information-efficient (separates concerns)
4. ✅ Technically feasible (~5 days implementation)
5. ✅ Perfectly aligned with design vision

The classical perimeter gives players a familiar interaction model (click to plant/harvest), while the quantum center reveals the hidden physics. The tethers make the correspondence explicit.

**This is the "computer chip" aesthetic you described - and it's brilliant.** 🌾⚛️✨
