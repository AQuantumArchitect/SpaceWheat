# Plot Force Graph Roadmap

## Overview

This document outlines the future implementation plan for force-directed graph visualization of quantum entanglement in the SpaceWheat farming system. Plot wrappers (FarmPlot, BiomePlot, CelestialPlot) currently exist but don't have active force-directed behavior. This roadmap details how they will be enhanced.

## Current State

### Plot Wrappers (Existing - Minimal)

- **FarmPlot** (QuantumBehavior.FLOATING)
  - Represents plantable crops (wheat, mushroom, tomato)
  - Currently: Minimal wrapper delegating to WheatPlot
  - Status: Ready for force-directed enhancement

- **BiomePlot** (QuantumBehavior.HOVERING)
  - Represents environmental measurement points
  - Currently: Fixed hover over measurement location
  - Status: Could be extended with hover animation

- **CelestialPlot** (QuantumBehavior.FIXED)
  - Represents immutable celestial bodies (sun/moon)
  - Currently: Completely fixed in position
  - Status: Ready for rotation animation

## Future Implementation: Force-Directed Graph

### Phase 1: Force Calculation System

**Objective**: Add physics-based force calculations for entangled qubits

**Components**:
1. **ForceCalculator** (NEW)
   - Calculate spring forces between entangled qubits
   - Calculate repulsion forces between non-entangled qubits
   - Calculate attraction toward center of mass

2. **Force Types**:
   - **Spring Forces**: Connect entangled pairs with spring constant
   - **Repulsion Forces**: Non-entangled qubits repel each other
   - **Gravitational Forces**: Weak attraction toward farm center
   - **Conspiracy Network Forces**: Additional forces from conspiracy relationships

**Pseudocode**:
```gdscript
class_name ForceCalculator

func calculate_total_force(plot: FarmPlot, all_plots: Array) -> Vector2:
    var total_force = Vector2.ZERO

    # Spring forces from entangled connections
    for entangled_pair in plot.entangled_pairs:
        total_force += calculate_spring_force(plot, entangled_pair)

    # Repulsion from non-entangled qubits
    for other_plot in all_plots:
        if not is_entangled_with(plot, other_plot):
            total_force += calculate_repulsion_force(plot, other_plot)

    # Center of mass attraction
    total_force += calculate_center_attraction(plot, all_plots)

    # Conspiracy network forces (if available)
    if has_conspiracy_network():
        total_force += calculate_conspiracy_forces(plot)

    return total_force
```

### Phase 2: Particle Physics Engine

**Objective**: Implement simple particle physics for balloon movement

**Components**:
1. **ParticlePhysicsEngine** (NEW)
   - Update positions based on forces
   - Apply damping/friction
   - Handle collisions between balloons
   - Constrain motion to farm bounds

**Features**:
- Velocity-based motion: position += velocity * dt
- Force-to-acceleration: acceleration = force / mass
- Damping: velocity *= (1 - damping_coefficient)
- Constraint: clamp position within farm bounds

### Phase 3: Visualization Enhancement

**Objective**: Add visual feedback for force-directed behavior

**Visual Elements**:
1. **Connection Lines**: Entanglement edges with visual strength
2. **Force Vectors**: Arrows showing current force direction (debug mode)
3. **Momentum Trails**: Fading trails showing balloon history
4. **Energy Glow**: Brightness based on qubit energy (radius)
5. **Entanglement Sparkles**: Visual effect along entanglement edges

### Phase 4: Animation

**Objective**: Add smooth animation and visual polish

**Animations**:
1. **Floating Animation**: Gentle up/down bobbing motion
2. **Spin Animation**: Slow rotation matching sun/moon cycle (celestial)
3. **Pulse Effect**: Energy-based pulsing for feedback
4. **Entanglement Flash**: Flash when entanglement changes

## Implementation Timeline

### Sprint 1: Force Calculation
- [ ] Design ForceCalculator class
- [ ] Implement spring force between entangled pairs
- [ ] Implement repulsion between non-entangled qubits
- [ ] Unit tests for force calculations

### Sprint 2: Physics Engine
- [ ] Design ParticlePhysicsEngine
- [ ] Implement position/velocity updates
- [ ] Add damping and constraints
- [ ] Integration tests with FarmPlot

### Sprint 3: Visualization
- [ ] Add connection line rendering
- [ ] Add force vector visualization (debug)
- [ ] Add energy-based styling
- [ ] Visual testing and polish

### Sprint 4: Animation & Polish
- [ ] Implement floating animation
- [ ] Add transition effects
- [ ] Performance optimization
- [ ] Final visual review

## Technical Considerations

### Performance
- **Complexity**: O(n²) force calculations (all pairs)
- **Optimization**: Could use spatial partitioning for large farms
- **Update Frequency**: Calculate forces every frame, or every N frames?
- **Damping**: Critical for stability - too low = oscillation, too high = sluggish

### Tuning Parameters
```gdscript
# Spring force: F = -k * x (Hooke's law)
spring_constant: float = 0.5
equilibrium_distance: float = 100.0

# Repulsion force: F = k / r²
repulsion_strength: float = 1000.0
min_repulsion_distance: float = 50.0

# Damping: v_new = v_old * (1 - damping)
damping_coefficient: float = 0.05

# Center attraction: F = -k * (pos - center)
center_attraction_strength: float = 0.01

# Constraints
farm_bounds: Rect2i
max_balloon_speed: float = 200.0
```

### Edge Cases
1. **Single Qubit**: No forces - remains stationary
2. **Two Qubits**: Spring force connects them
3. **Disconnected Components**: Separate clusters should not interact
4. **High Energy States**: Strong qubits might need force damping

## Related Systems

### Entanglement Tracking
- FarmGrid already tracks `entangled_pairs` and `entangled_clusters`
- ForceCalculator will use these relationships
- Need to update on entanglement creation/removal

### Conspiracy Network
- TomatoConspiracyNetwork provides additional forces
- Could add special attraction between conspiracy members
- Future: Use network topology for force weighting

### Biome Integration
- Biome-based forces: sun position could pull qubits
- Temperature effects: hotter areas have more force
- Wind effects: directional forces from biome

## References

### Existing Plot Classes
- `Core/GameMechanics/PlotBase.gd` - Base with QuantumBehavior enum
- `Core/GameMechanics/FarmPlot.gd` - Farm plot wrapper
- `Core/GameMechanics/BiomePlot.gd` - Biome measurement plot
- `Core/GameMechanics/CelestialPlot.gd` - Celestial body plot

### Related Systems
- `Core/QuantumSubstrate/EntangledPair.gd` - Pairwise entanglement
- `Core/QuantumSubstrate/EntangledCluster.gd` - N-qubit clusters
- `Core/QuantumSubstrate/TopologyAnalyzer.gd` - Entanglement topology
- `Core/GameMechanics/FarmGrid.gd` - Plot management

### Visualization
- UI system handles balloon rendering
- Need to add force vector rendering for debug mode
- Connection lines rendered between entangled pairs

## Open Questions

1. **When to calculate forces?**
   - Every frame? (potentially expensive)
   - Every N frames? (could feel jerky)
   - Only when entanglement changes? (misses dynamic updates)

2. **How to handle equilibrium?**
   - Should plots have stable resting positions?
   - Or should they continuously drift?
   - What if farm is too crowded?

3. **Conspiracy network integration?**
   - How strongly should conspiracy affect forces?
   - Should conspiracy force override spring forces?
   - Can conspiracy create permanent bonds?

4. **Biome forces?**
   - Should sun position pull qubits?
   - Should temperature affect movement speed?
   - Should wind have directional effects?

## Success Criteria

- [ ] Force-directed layout improves entanglement visualization
- [ ] Balloons arrange themselves naturally based on entanglement
- [ ] No noticeable performance degradation on 10+ qubit farms
- [ ] Visual feedback clearly shows entanglement relationships
- [ ] Animation is smooth at 60 FPS
- [ ] Can toggle force visualization for debugging

## Future Enhancements

1. **Emergent Behavior**
   - Vortex patterns in high-entanglement areas
   - Clustering of related qubits
   - Migration patterns following conspiracy

2. **Interactive Manipulation**
   - Drag-to-reposition plots (override forces temporarily)
   - Snap-to-grid option
   - Reset/organize button

3. **Performance Optimization**
   - Spatial partitioning (quadtree)
   - GPU-accelerated force calculation
   - Incremental updates instead of full recalculation

4. **Advanced Physics**
   - Momentum conservation
   - Collision resolution
   - Energy dissipation
   - Wave-like propagation
