# Projection Mechanics
## How Plots Observe the Bath

---

## The Fundamental Insight

**A plot is not a container. It is a lens.**

The plot doesn't hold a quantum state. It projects the biome's bath onto a chosen measurement axis, making the invisible quantum world visible and harvestable.

```
Bath |ψ⟩ = α₁|☀⟩ + α₂|🌾⟩ + α₃|💀⟩ + α₄|🐺⟩ + ...
                    ↓
            Plot projects onto 🌾/💀 axis
                    ↓
        DualEmojiQubit(🌾, 💀, θ, φ, r)
        
        where:
          r² = |α₂|² + |α₃|²
          θ = 2·arccos(|α₂|/r)
          φ = arg(α₂) - arg(α₃)
```

---

## Projection Mathematics

### The Projection Operator

For a plot measuring along the north/south axis:

```
Π_plot = |north⟩⟨north| + |south⟩⟨south|
```

This projects the full bath state onto the 2D subspace spanned by {|north⟩, |south⟩}.

### Deriving Bloch Coordinates

Given bath amplitudes αₙ = ⟨north|ψ⟩ and αₛ = ⟨south|ψ⟩:

**Radius (total amplitude in subspace):**
```
r = √(|αₙ|² + |αₛ|²)
```
Physical meaning: How much of the bath's "spirit" lives in this axis.

**Theta (polar angle on Bloch sphere):**
```
θ = 2·arccos(|αₙ|/r)

Equivalently:
cos²(θ/2) = |αₙ|²/r²  (probability of north)
sin²(θ/2) = |αₛ|²/r²  (probability of south)
```
Physical meaning: The north/south balance. θ=0 is pure north, θ=π is pure south.

**Phi (azimuthal angle):**
```
φ = arg(αₙ) - arg(αₛ)
```
Physical meaning: The relative quantum phase between north and south. This is genuine quantum information—it affects interference.

### Edge Cases

**Zero amplitude (r ≈ 0):**
```gdscript
if r < 1e-10:
    # No amplitude in this subspace
    return {
        "radius": 0.0,
        "theta": PI / 2.0,  # Maximum uncertainty
        "phi": 0.0,
        "valid": false
    }
```

**One pole dominates:**
```gdscript
if abs(amp_s) < 1e-10:
    theta = 0.0  # Pure north
    phi = 0.0    # Phase undefined but set to 0
elif abs(amp_n) < 1e-10:
    theta = PI   # Pure south
    phi = 0.0
```

---

## Projection Lifecycle

### 1. Plot Creation (Planting)

When player plants a plot:

```gdscript
# In BiomeBase
func create_projection(position: Vector2i, north: String, south: String) -> DualEmojiQubit:
    # Get current projection from bath
    var proj = bath.project_onto_axis(north, south)
    
    # Create the qubit view
    var qubit = DualEmojiQubit.new(north, south, proj.theta)
    qubit.phi = proj.phi
    qubit.radius = proj.radius
    qubit.energy = proj.radius  # Energy = amplitude for now
    
    # Register this projection
    active_projections[position] = {
        "qubit": qubit,
        "north": north,
        "south": south
    }
    
    return qubit
```

### 2. Continuous Update

Each frame, projections are re-derived from the evolving bath:

```gdscript
# In BiomeBase._process(delta)
func update_projections():
    for position in active_projections:
        var proj_data = active_projections[position]
        var qubit = proj_data.qubit
        var north = proj_data.north
        var south = proj_data.south
        
        # Re-project from current bath state
        var proj = bath.project_onto_axis(north, south)
        
        # Update qubit (smooth interpolation optional)
        qubit.theta = proj.theta
        qubit.phi = proj.phi
        qubit.radius = proj.radius
        qubit.energy = proj.radius
```

**Key insight:** The qubit is a VIEW, not independent state. It always reflects the bath.

### 3. Measurement (Harvest)

When player measures:

```gdscript
func measure_projection(position: Vector2i) -> String:
    var proj_data = active_projections[position]
    var north = proj_data.north
    var south = proj_data.south
    
    # Perform measurement on bath
    var outcome = bath.measure_axis(north, south, collapse_strength)
    
    # Update qubit to post-measurement state
    update_projections()
    
    return outcome
```

The measurement collapses the bath, which affects all projections.

### 4. Removal (Harvest Complete)

```gdscript
func remove_projection(position: Vector2i):
    if active_projections.has(position):
        active_projections.erase(position)
    # Bath continues evolving; projection just stops being displayed
```

---

## Multiple Overlapping Projections

### The Scenario

Two plots project overlapping axes:
- Plot A: 🐺/💀 (wolf or dead)
- Plot B: 🐺/🐇 (wolf or rabbit)

Both involve 🐺. How do they interact?

### Shared Amplitude

Both plots draw from the same α_🐺 amplitude in the bath:

```
Plot A radius² includes |α_🐺|²
Plot B radius² includes |α_🐺|²
```

This is correct! If 🐺 is strong in the bath, both projections show it.

### Measurement Correlation

If Plot A is measured and collapses toward 🐺:
- Bath α_🐺 increases
- Plot B immediately shows stronger 🐺

If Plot A collapses toward 💀:
- Bath α_🐺 decreases (and α_💀 increases)
- Plot B shows weaker 🐺

**Projections are entangled through the shared bath.**

### Visualization Consideration

When displaying overlapping projections, the visualization should show:
- Each plot as its own bubble
- But indicate the shared axis (maybe connecting lines to same emoji)
- Measurement of one visibly affects the other

---

## Projection Types

### Standard Two-Pole Projection

Most plots use a simple north/south axis:

```gdscript
create_projection(pos, "🌾", "💀")  # Wheat vs labor
create_projection(pos, "🐺", "💀")  # Wolf vs dead
create_projection(pos, "☀", "🌙")  # Day vs night
```

### Multi-Pole Projection (Future)

Could project onto 3+ emojis for richer visualization:

```gdscript
# Triangular projection
create_projection(pos, ["🐺", "🐇", "🌿"])

# Would need different visualization (triangle, not Bloch sphere)
# And different mathematics (qutrit, not qubit)
```

### Subspace Projection (Future)

Project onto a group treated as one pole:

```gdscript
# "Predators" vs "Prey"
north_group = ["🐺", "🦅"]  # All predators
south_group = ["🐇", "🐭", "🦌"]  # All prey

create_grouped_projection(pos, north_group, south_group)
```

---

## Energy and Radius

### Current Model

```
radius = √(|αₙ|² + |αₛ|²)
energy = radius
```

Energy equals the amplitude in the projection subspace.

### Richer Model (Optional)

Separate concepts:
- **Radius** = visualization size
- **Energy** = harvestable resource
- **Coherence** = |⟨north|ψ⟩⟨ψ|south⟩| (off-diagonal term)

```gdscript
var coherence = amp_n.mul(amp_s.conjugate()).abs()
# High coherence = strong quantum superposition
# Low coherence = more classical (near pure north or south)
```

Coherence could affect gameplay:
- High coherence → more uncertain harvest outcome
- Low coherence → predictable outcome

---

## Persistent Gate Integration

### Gates as Correlated Projections

When two plots have a Bell gate:

```gdscript
# Plot A and Plot B are Bell-entangled
persistent_gates[pos_a] = [{"type": "bell_phi_plus", "linked": [pos_b]}]
```

In bath-first model, this means:
- Plots A and B project correlated axes
- Measurement of A affects B's projection via bath
- But also: A and B might project a joint 4D subspace

### Joint Projection for Entangled Plots

```gdscript
func create_entangled_projection(pos_a, pos_b, north_a, south_a, north_b, south_b):
    # Project onto 4D subspace: |n_a⟩⊗|n_b⟩, |n_a⟩⊗|s_b⟩, |s_a⟩⊗|n_b⟩, |s_a⟩⊗|s_b⟩
    # This requires treating bath as tensor product space...
    
    # Simpler approach: project each independently but track correlation
    var proj_a = bath.project_onto_axis(north_a, south_a)
    var proj_b = bath.project_onto_axis(north_b, south_b)
    
    # Correlation coefficient
    var corr = bath.get_correlation(north_a, north_b)
    
    # Store in entangled pair tracker
    entangled_projections.append({
        "pos_a": pos_a,
        "pos_b": pos_b,
        "correlation": corr
    })
```

### Bath Correlation Function

```gdscript
func get_correlation(emoji_a: String, emoji_b: String) -> float:
    # Pearson-like correlation of amplitudes
    var amp_a = get_amplitude(emoji_a)
    var amp_b = get_amplitude(emoji_b)
    
    # Cross term
    var cross = amp_a.mul(amp_b.conjugate()).re
    
    # Normalize
    var norm_a = amp_a.abs()
    var norm_b = amp_b.abs()
    
    if norm_a < 1e-10 or norm_b < 1e-10:
        return 0.0
    
    return cross / (norm_a * norm_b)
```

---

## Plot-Bath Backaction

### Weak Measurement (Continuous Observation)

Having a plot observe an axis creates weak measurement backaction:

```gdscript
# Each frame, projections slightly collapse the bath
func apply_observation_backaction(delta: float):
    var observation_strength = 0.01  # Very weak
    
    for position in active_projections:
        var proj_data = active_projections[position]
        var north = proj_data.north
        var south = proj_data.south
        
        # The act of observation slightly biases toward the current dominant state
        var prob_n = bath.get_probability(north)
        var prob_s = bath.get_probability(south)
        
        if prob_n > prob_s:
            bath.partial_collapse(north, observation_strength * delta)
        else:
            bath.partial_collapse(south, observation_strength * delta)
```

This is optional but creates interesting physics:
- Observed parts of bath evolve differently than unobserved
- "A watched pot never boils" quantum style
- Player attention shapes reality

### Strong Measurement (Harvest)

```gdscript
func harvest_projection(position: Vector2i) -> Dictionary:
    var proj_data = active_projections[position]
    var qubit = proj_data.qubit
    var north = proj_data.north
    var south = proj_data.south
    
    # Measure with strong collapse
    var outcome = bath.measure_axis(north, south, 0.5)  # 50% collapse strength
    
    # Energy extracted
    var energy = qubit.radius
    
    # Remove projection
    remove_projection(position)
    
    return {
        "outcome": outcome,
        "energy": energy,
        "success": true
    }
```

---

## Visualization Mapping

### From Projection to Skating Rink

The DualEmojiQubit derived from projection maps to visualization:

```gdscript
# In QuantumNode (visualization)
func update_from_qubit(qubit: DualEmojiQubit):
    # Position on skating rink perimeter determined by phi
    var angle = qubit.phi
    var perimeter_pos = oval_center + Vector2(
        oval_width * cos(angle) / 2.0,
        oval_height * sin(angle) / 2.0
    )
    
    # Distance from center determined by radius
    var radial_distance = qubit.radius * max_radius
    position = lerp(oval_center, perimeter_pos, radial_distance)
    
    # Bubble size could also scale with radius
    scale = Vector2.ONE * (0.5 + qubit.radius * 0.5)
    
    # Orientation arrow from theta
    var arrow_angle = qubit.theta  # or some mapping
    rotation = arrow_angle
```

### Visual Coherence Indicator

Show quantum coherence (superposition strength):

```gdscript
func get_coherence_indicator(qubit: DualEmojiQubit) -> float:
    # Maximum coherence at θ = π/2 (equal superposition)
    var coherence = sin(qubit.theta)
    return coherence

# Visualize as:
# - Bubble shimmer/glow intensity
# - Outline thickness
# - Particle effect rate
```

---

## Code Integration

### BasePlot Changes

```gdscript
# In BasePlot
class_name BasePlot

# Remove: quantum_state ownership
# Add: projection reference

var projection_active: bool = false
var projection_north: String = ""
var projection_south: String = ""

# quantum_state becomes a getter that asks biome for current projection
var quantum_state: DualEmojiQubit:
    get:
        if not projection_active:
            return null
        var biome = get_biome()
        if not biome:
            return null
        return biome.get_projection_qubit(grid_position)
```

### BiomeBase Changes

```gdscript
# In BiomeBase
class_name BiomeBase

var bath: QuantumBath
var active_projections: Dictionary = {}  # Vector2i → {qubit, north, south}

func _ready():
    bath = QuantumBath.new()
    _initialize_bath()

func _process(delta):
    bath.evolve(delta)
    update_projections()

func create_projection(position: Vector2i, north: String, south: String) -> DualEmojiQubit:
    # ... as shown above

func get_projection_qubit(position: Vector2i) -> DualEmojiQubit:
    if active_projections.has(position):
        return active_projections[position].qubit
    return null
```

### FarmGrid Changes

Minimal changes needed:

```gdscript
# FarmGrid.plant() mostly unchanged
# Just ensure it calls biome.create_projection() not direct qubit creation

func plant(position: Vector2i, plant_type: String) -> bool:
    var plot = get_plot(position)
    var biome = get_biome_for_plot(position)
    
    var emojis = plot.get_plot_emojis()
    
    # Ask biome to create projection (not plot to create qubit)
    var qubit = biome.create_projection(position, emojis.north, emojis.south)
    
    plot.projection_active = true
    plot.projection_north = emojis.north
    plot.projection_south = emojis.south
    plot.is_planted = true
    
    # ... rest unchanged
```

---

## Summary

| Concept | Old Model | Bath-First Model |
|---------|-----------|------------------|
| Qubit ownership | Plot owns qubit | Biome owns bath; plot projects |
| State creation | Plot.plant() creates | Bath exists; projection reveals |
| State evolution | Biome evolves each qubit | Bath evolves; projections derived |
| Measurement | Qubit collapses | Bath collapses; all projections update |
| Entanglement | Separate tracking | Shared bath = natural entanglement |
| Multiple plots | Independent states | Correlated through common bath |

**The plot is a window. The bath is reality.**

