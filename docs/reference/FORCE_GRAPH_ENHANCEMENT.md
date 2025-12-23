# Force Graph Enhancement: Measured Nodes

## Summary

Measured nodes now pull **20x stronger** toward their classical anchor position, creating a clear visual distinction between quantum (floating) and classical (anchored) states.

## Technical Implementation

### Before (Frozen Behavior)
```gdscript
if node.plot and node.plot.has_been_measured:
    # Freeze velocity for measured nodes (classical = no motion)
    node.velocity = Vector2.ZERO
    continue  # Skip force calculations
```

**Problem:** Measured nodes were completely frozen in place, which made them feel disconnected from the physics system.

### After (Strong Pull Behavior)
```gdscript
if node.plot and node.plot.has_been_measured:
    # STRONG tether force - measured nodes snap to their classical position
    total_force += _calculate_tether_force(node, true)

    # Apply force with strong damping (settle quickly to anchor)
    node.apply_force(total_force, delta)
    node.apply_damping(MEASURED_DAMPING)
    continue  # Skip quantum forces (no repulsion, no entanglement)
```

**Solution:** Measured nodes now experience a very strong spring force pulling them to their classical anchor, combined with high damping to settle them quickly.

## Force Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `TETHER_SPRING_CONSTANT` | 0.015 | Weak tether for unmeasured (quantum) nodes |
| `MEASURED_TETHER_STRENGTH` | 0.3 | **20x stronger** tether for measured nodes |
| `DAMPING` | 0.75 | Normal damping for quantum nodes |
| `MEASURED_DAMPING` | 0.95 | Strong damping for measured nodes (settle quickly) |

## Visual Effect

### Unmeasured (Quantum) Nodes
- Float freely in quantum space
- Weak tether to classical position
- Repelled by other nodes
- Attracted to entangled partners
- Dynamic, flowing motion

### Measured (Classical) Nodes
- **Snap strongly to classical anchor**
- No repulsion forces
- No entanglement forces
- Quick settling with high damping
- Anchored, stable appearance

## Quantum Mechanics Interpretation

This creates a beautiful visual metaphor for wavefunction collapse:

1. **Before Measurement**: Quantum nodes float in superposition space, spread across possible states
2. **Measurement**: Wavefunction collapses - node is **pulled forcefully** back to its classical position
3. **After Measurement**: Node settles at anchor (definite state), no longer participating in quantum dynamics

The **strong pull** visually represents the irreversible nature of measurement - the quantum state "collapses" back into classical reality.

## Benefits

1. **Clear Visual Feedback**: Easy to see which nodes have been measured (anchored vs floating)
2. **Physical Realism**: Matches quantum mechanics - measured states are definite, not probabilistic
3. **Gameplay Clarity**: Players can instantly see the state of their farm
4. **Dynamic Animation**: The snap-to-position creates satisfying visual feedback when measuring

## Testing

Tested successfully - game loads with no errors:
```
✅ FarmView ready!
✅ QuantumForceGraph node_clicked signal connected
⚛️ Created 25 quantum nodes
```

No script errors related to the force calculations. The enhancement is ready for playtesting!
