# Working Example: BioticFlux Biome

## Overview
The BioticFlux biome models a farming ecosystem with celestial cycles and crop growth. This is a **working, successful implementation** that demonstrates the quantum biome pattern.

---

## Key Entities

### 1. Sun/Moon Qubit (Celestial Driver)
```gdscript
sun_qubit = DualEmojiQubit.new("☀️", "🌑", PI/2)
```

**Evolution:**
- Oscillates around Bloch sphere equator with tilted axis
- `theta` cycles smoothly: 0 (noon) → π (midnight) → 0
- Drives all other qubits via coupling

**Brightness calculation:**
```gdscript
sun_brightness = cos²(sun_qubit.theta / 2)    # Peaks at noon (θ=0)
moon_brightness = sin²(sun_qubit.theta / 2)   # Peaks at midnight (θ=π)
```

### 2. Wheat Icon (Environmental Modifier)
```gdscript
wheat_icon = {
    "preferred_theta": PI/4,         # Morning position (45°)
    "preferred_phi": 3*PI/2,         # Fall quadrant
    "spring_constant": 0.5,          # Attraction to sun
    "icon_spring_constant": 1.0      # Attraction to rest point
}
```

The icon has its own internal qubit that follows the sun but drifts toward a preferred rest location.

### 3. Wheat Crops (Farm Plots)
```gdscript
wheat_qubit = DualEmojiQubit.new("🌾", "👥", PI/2)
```

Each planted wheat crop is a separate qubit influenced by:
- Sun position (celestial coupling)
- Wheat icon (environmental modifier)
- Spring forces pulling toward targets

---

## Evolution Mechanics

### Step 1: Celestial Oscillation
```gdscript
func _apply_celestial_oscillation(dt: float):
    var phase = (time / sun_moon_period) * TAU
    sun_qubit.theta = PI * sin(phase / 2.0)
    sun_qubit.phi = phi  # Continuous rotation
```

### Step 2: Spring Attraction
```gdscript
func _apply_spring_attraction(dt: float):
    # Wheat follows sun's current position
    var sun_target = _bloch_vector(sun_qubit.theta, sun_qubit.phi)
    var spring_force = wheat_icon["spring_constant"]
    _apply_bloch_torque(wheat_qubit, sun_target, spring_force, dt)

    # Also weak pull toward icon's preferred rest
    var pref_target = _bloch_vector(wheat_icon["preferred_theta"], wheat_icon["preferred_phi"])
    _apply_bloch_torque(wheat_qubit, pref_target, wheat_icon["icon_spring_constant"], dt)
```

**Bloch torque** uses cross product to rotate qubit toward target:
```gdscript
func _apply_bloch_torque(qubit, target_v: Vector3, k: float, dt: float):
    var v = _bloch_vector(qubit.theta, qubit.phi)
    var torque_vec = target_v.cross(v) * -k
    # Apply infinitesimal rotation
    qubit.theta, qubit.phi = rotated(v, torque_vec, dt)
```

### Step 3: Energy Transfer (Non-Hamiltonian)
```gdscript
func _apply_energy_transfer(dt: float):
    # Alignment: 3D angle between crop and sun
    var alignment = cos²(angle_between(wheat_vector, sun_vector))

    # Energy rate based on alignment + brightness
    var energy_rate = base_rate * alignment * sun_brightness * wheat_influence

    # Exponential growth
    wheat_qubit.energy *= exp(energy_rate * dt)
    wheat_qubit.radius = wheat_qubit.energy  # Sync visual size
```

**Key insight:** Energy grows when crop is **aligned** with sun and sun is **bright**.

---

## Visualization Mapping

In the force graph:
1. **Sun qubit** orbits the BioticFlux oval perimeter (phi evolution)
2. **Wheat qubits** chase the sun position with spring forces
3. **Skating rink forces** pull bubbles to their phi-angle positions
4. **Radial forces** push high-energy bubbles outward

**Result:** A swirling, dynamic ecosystem where crops visibly follow the sun/moon cycle!

---

## Why This Works

✅ **One celestial qubit** drives the entire system
✅ **Multiple crop qubits** each independently follow physics
✅ **Clear separation** between Hamiltonian (rotation) and Lindblad (energy)
✅ **Scalable:** Adding more crops just adds more spring-coupled qubits
✅ **Conceptual clarity:** "The sun makes crops grow" maps directly to quantum coupling

---

## Player Interaction

**Planting:**
```gdscript
plant_wheat(position):
    wheat_qubit = create_qubit("🌾", "👥", PI/2)
    wheat_qubit.energy = 0.3  # Start small
    quantum_states[position] = wheat_qubit
```

**Harvesting:**
```gdscript
harvest_wheat(position):
    qubit = quantum_states[position]
    outcome = qubit.measure()  # Collapses based on theta
    if outcome == "🌾":
        return qubit.energy * 1.0  # Wheat yield
    else:
        return qubit.energy * 0.5  # Labor yield
```

The player sees qubits grow visually (radius increases) and can harvest at any time for varying yields.
