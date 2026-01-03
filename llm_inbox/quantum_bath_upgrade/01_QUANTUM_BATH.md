# Quantum Bath Mechanics
## Technical Specification

---

## Overview

The QuantumBath is the fundamental substrate of each biome. It holds a superposition of all emoji states and evolves according to the combined Hamiltonians and Lindblad operators of the Icons present.

---

## State Representation

### The Ket Vector

```gdscript
# Bath state: array of complex amplitudes
# Index i corresponds to emoji_list[i]
var amplitudes: Array[Complex]  # Length = number of emojis in biome

# Emoji indexing
var emoji_list: Array[String]   # ["⛰", "☀", "🌳", "🐺", ...]
var emoji_to_index: Dictionary  # {"⛰": 0, "☀": 1, ...}
```

**Normalization invariant:**
```
Σᵢ |amplitudes[i]|² = 1.0
```

### Complex Number Representation

```gdscript
class_name Complex

var re: float  # Real part
var im: float  # Imaginary part

func _init(real: float = 0.0, imag: float = 0.0):
    re = real
    im = imag

func abs_sq() -> float:
    return re * re + im * im

func abs() -> float:
    return sqrt(abs_sq())

func arg() -> float:
    return atan2(im, re)

func conjugate() -> Complex:
    return Complex.new(re, -im)

func add(other: Complex) -> Complex:
    return Complex.new(re + other.re, im + other.im)

func sub(other: Complex) -> Complex:
    return Complex.new(re - other.re, im - other.im)

func mul(other: Complex) -> Complex:
    return Complex.new(
        re * other.re - im * other.im,
        re * other.im + im * other.re
    )

func scale(s: float) -> Complex:
    return Complex.new(re * s, im * s)

static func from_polar(r: float, theta: float) -> Complex:
    return Complex.new(r * cos(theta), r * sin(theta))

static func i() -> Complex:
    return Complex.new(0.0, 1.0)
```

---

## Hamiltonian Evolution

### The Hamiltonian Matrix

The total Hamiltonian is a Hermitian matrix constructed from Icon terms:

```gdscript
# H[i][j] = coupling between emoji_i and emoji_j
var hamiltonian: Array[Array]  # N x N matrix of Complex

func build_hamiltonian():
    var N = emoji_list.size()
    hamiltonian = []
    
    for i in range(N):
        hamiltonian.append([])
        for j in range(N):
            hamiltonian[i].append(Complex.new(0.0, 0.0))
    
    # Add contributions from each Icon
    for emoji in emoji_list:
        var icon = IconRegistry.get_icon(emoji)
        if icon == null:
            continue
        
        var i = emoji_to_index[emoji]
        
        # Self-energy (diagonal)
        hamiltonian[i][i] = hamiltonian[i][i].add(
            Complex.new(icon.self_energy, 0.0)
        )
        
        # Off-diagonal couplings
        for target_emoji in icon.hamiltonian_couplings:
            if not emoji_to_index.has(target_emoji):
                continue
            var j = emoji_to_index[target_emoji]
            var coupling = icon.hamiltonian_couplings[target_emoji]
            
            # Add to H[i][j] and H[j][i] (Hermitian)
            hamiltonian[i][j] = hamiltonian[i][j].add(coupling.scale(0.5))
            hamiltonian[j][i] = hamiltonian[j][i].add(coupling.conjugate().scale(0.5))
```

### Time Evolution

Schrödinger equation: d|ψ⟩/dt = -i H |ψ⟩

For small dt, first-order approximation:
```
|ψ(t+dt)⟩ ≈ (I - i H dt) |ψ(t)⟩
```

For better accuracy, use second-order (leapfrog) or Runge-Kutta.

```gdscript
func evolve_hamiltonian(dt: float):
    var N = amplitudes.size()
    var new_amplitudes: Array[Complex] = []
    
    # Initialize
    for i in range(N):
        new_amplitudes.append(Complex.new(0.0, 0.0))
    
    # Apply (I - i H dt)
    for i in range(N):
        # Identity part
        new_amplitudes[i] = amplitudes[i]
        
        # -i H dt part
        for j in range(N):
            # -i * H[i][j] * dt * amplitudes[j]
            var H_ij = hamiltonian[i][j]
            var contrib = Complex.i().scale(-1.0).mul(H_ij).mul(amplitudes[j]).scale(dt)
            new_amplitudes[i] = new_amplitudes[i].add(contrib)
    
    amplitudes = new_amplitudes
    normalize()
```

### Preserving Unitarity

The above first-order method slowly loses normalization. Better approaches:

**Option 1: Normalize after each step**
```gdscript
func normalize():
    var total = 0.0
    for amp in amplitudes:
        total += amp.abs_sq()
    var norm = sqrt(total)
    if norm > 1e-10:
        for i in range(amplitudes.size()):
            amplitudes[i] = amplitudes[i].scale(1.0 / norm)
```

**Option 2: Cayley transform (exactly unitary)**
```
U = (I - i H dt/2)^(-1) (I + i H dt/2)
```
More expensive but exactly unitary. Useful if drift becomes a problem.

**Option 3: Split-operator method**
For separable Hamiltonians, evolve each part separately.

For SpaceWheat, Option 1 (normalize after step) is sufficient.

---

## Lindblad Evolution

### Jump Operators

Each Lindblad term represents a directed transfer:

```gdscript
class LindBladTerm:
    var source_emoji: String
    var target_emoji: String
    var rate: float  # γ in √γ |target⟩⟨source|
```

### Applying Lindblad Terms

The Lindblad equation for a single jump operator L = √γ |t⟩⟨s|:

```
dρ/dt = L ρ L† - ½{L†L, ρ}
```

For a pure state, this becomes a stochastic process. We use the "no-jump" approximation for small dt:

```gdscript
func evolve_lindblad(dt: float):
    for term in lindblad_terms:
        var s = emoji_to_index.get(term.source_emoji, -1)
        var t = emoji_to_index.get(term.target_emoji, -1)
        if s < 0 or t < 0:
            continue
        
        var rate = term.rate
        var transfer_amp = sqrt(rate * dt)
        
        # Transfer amplitude from source to target
        var source_amp = amplitudes[s]
        var transfer = source_amp.scale(transfer_amp)
        
        amplitudes[t] = amplitudes[t].add(transfer)
        amplitudes[s] = amplitudes[s].scale(sqrt(1.0 - rate * dt))
    
    normalize()
```

### Collecting Lindblad Terms from Icons

```gdscript
func build_lindblad_terms():
    lindblad_terms = []
    
    for emoji in emoji_list:
        var icon = IconRegistry.get_icon(emoji)
        if icon == null:
            continue
        
        # Outgoing transfers (this emoji loses amplitude)
        for target_emoji in icon.lindblad_outgoing:
            var rate = icon.lindblad_outgoing[target_emoji]
            lindblad_terms.append(LindBladTerm.new(emoji, target_emoji, rate))
        
        # Self-decay
        if icon.decay_rate > 0.0:
            # Decay to a "vacuum" or "ground" state
            # Or could decay to organic matter, etc.
            var decay_target = icon.decay_target if icon.decay_target else "🍂"
            if emoji_to_index.has(decay_target):
                lindblad_terms.append(LindBladTerm.new(emoji, decay_target, icon.decay_rate))
```

---

## The Evolution Loop

Each frame, the bath evolves through both layers:

```gdscript
func evolve(dt: float):
    # Layer 1: Hamiltonian (unitary mixing)
    evolve_hamiltonian(dt)
    
    # Layer 2: Lindblad (dissipative transfer)
    evolve_lindblad(dt)
    
    # Emit signal for visualization update
    bath_evolved.emit()
```

**Order matters slightly:**
- H first, then L: Coherent evolution, then dissipation
- L first, then H: Dissipation modifies what H acts on

For physical realism, H-then-L is standard. But for small dt, the difference is negligible.

---

## External Driving

Some Icons have time-dependent terms (e.g., day/night cycle):

```gdscript
class Icon:
    # ...
    var self_energy_function: Callable  # func(time) -> float
    
    func get_self_energy(time: float) -> float:
        if self_energy_function:
            return self_energy_function.call(time)
        return self_energy_base
```

The bath tracks global time:

```gdscript
var bath_time: float = 0.0

func evolve(dt: float):
    bath_time += dt
    
    # Rebuild time-dependent Hamiltonian terms
    update_time_dependent_hamiltonian(bath_time)
    
    # Evolve
    evolve_hamiltonian(dt)
    evolve_lindblad(dt)
```

---

## Initialization

### Uniform Superposition

Default initialization—all emojis equally present:

```gdscript
func initialize_uniform():
    var N = emoji_list.size()
    var amp = 1.0 / sqrt(float(N))
    amplitudes = []
    for i in range(N):
        amplitudes.append(Complex.new(amp, 0.0))
```

### Weighted Initialization

Start with known abundances:

```gdscript
func initialize_weighted(weights: Dictionary):
    amplitudes = []
    var total = 0.0
    
    for emoji in emoji_list:
        var w = weights.get(emoji, 0.0)
        amplitudes.append(Complex.new(sqrt(w), 0.0))
        total += w
    
    # Normalize
    var norm = sqrt(total)
    for i in range(amplitudes.size()):
        amplitudes[i] = amplitudes[i].scale(1.0 / norm)
```

### From Markov Stationary Distribution

If biome defined by Markov chain, use its stationary distribution:

```gdscript
func initialize_from_markov(markov_chain: Dictionary):
    # Compute stationary distribution π where πM = π
    var stationary = compute_stationary_distribution(markov_chain)
    initialize_weighted(stationary)
```

---

## Querying the Bath

### Get Amplitude

```gdscript
func get_amplitude(emoji: String) -> Complex:
    var idx = emoji_to_index.get(emoji, -1)
    if idx < 0:
        return Complex.new(0.0, 0.0)
    return amplitudes[idx]

func get_probability(emoji: String) -> float:
    return get_amplitude(emoji).abs_sq()
```

### Project onto Axis

```gdscript
func project_onto_axis(north: String, south: String) -> Dictionary:
    var amp_n = get_amplitude(north)
    var amp_s = get_amplitude(south)
    
    var prob_n = amp_n.abs_sq()
    var prob_s = amp_s.abs_sq()
    var total = prob_n + prob_s
    
    if total < 1e-10:
        # No amplitude in this subspace
        return {
            "radius": 0.0,
            "theta": PI / 2.0,
            "phi": 0.0,
            "valid": false
        }
    
    var radius = sqrt(total)
    var theta = 2.0 * acos(amp_n.abs() / radius)
    var phi = amp_n.arg() - amp_s.arg()
    
    # Wrap phi to [0, 2π)
    while phi < 0:
        phi += TAU
    while phi >= TAU:
        phi -= TAU
    
    return {
        "radius": radius,
        "theta": theta,
        "phi": phi,
        "valid": true
    }
```

### Get All Probabilities

```gdscript
func get_probability_distribution() -> Dictionary:
    var dist = {}
    for i in range(emoji_list.size()):
        dist[emoji_list[i]] = amplitudes[i].abs_sq()
    return dist
```

---

## Measurement Operations

### Partial Collapse

When a plot is measured, the bath partially collapses:

```gdscript
func partial_collapse(emoji: String, strength: float):
    var idx = emoji_to_index.get(emoji, -1)
    if idx < 0:
        return
    
    # Amplify the measured state
    amplitudes[idx] = amplitudes[idx].scale(1.0 + strength)
    
    # Dampen others slightly (to maintain relative structure)
    var damping = strength * 0.1  # Much weaker than amplification
    for i in range(amplitudes.size()):
        if i != idx:
            amplitudes[i] = amplitudes[i].scale(1.0 - damping)
    
    normalize()
```

### Full Measurement (Collapse to Eigenstate)

For strong measurement (e.g., harvest):

```gdscript
func full_collapse(emoji: String):
    var idx = emoji_to_index.get(emoji, -1)
    if idx < 0:
        return
    
    # Set all amplitudes to zero except measured one
    var measured_amp = amplitudes[idx]
    for i in range(amplitudes.size()):
        if i == idx:
            amplitudes[i] = Complex.new(1.0, 0.0)  # Preserve phase? Or reset?
        else:
            amplitudes[i] = Complex.new(0.0, 0.0)
```

### Axis Measurement

Measure along a north/south axis:

```gdscript
func measure_axis(north: String, south: String, collapse_strength: float = 0.5) -> String:
    var amp_n = get_amplitude(north)
    var amp_s = get_amplitude(south)
    
    var prob_n = amp_n.abs_sq()
    var prob_s = amp_s.abs_sq()
    var total = prob_n + prob_s
    
    if total < 1e-10:
        return ""  # No amplitude to measure
    
    # Born rule
    var outcome: String
    if randf() < prob_n / total:
        outcome = north
        partial_collapse(north, collapse_strength)
    else:
        outcome = south
        partial_collapse(south, collapse_strength)
    
    return outcome
```

---

## Performance Considerations

### Sparse Hamiltonians

Most Icons only couple to a few other emojis. Use sparse representation:

```gdscript
# Instead of full N×N matrix:
var hamiltonian_sparse: Dictionary  # {i: {j: Complex}}

func evolve_hamiltonian_sparse(dt: float):
    var new_amplitudes = amplitudes.duplicate()
    
    for i in hamiltonian_sparse:
        for j in hamiltonian_sparse[i]:
            var H_ij = hamiltonian_sparse[i][j]
            var contrib = Complex.i().scale(-1.0).mul(H_ij).mul(amplitudes[j]).scale(dt)
            new_amplitudes[i] = new_amplitudes[i].add(contrib)
    
    amplitudes = new_amplitudes
    normalize()
```

### Lazy Rebuilding

Only rebuild Hamiltonian when Icons change:

```gdscript
var hamiltonian_dirty: bool = true

func mark_hamiltonian_dirty():
    hamiltonian_dirty = true

func evolve(dt: float):
    if hamiltonian_dirty:
        build_hamiltonian()
        build_lindblad_terms()
        hamiltonian_dirty = false
    
    # ... evolution
```

### Subspace Evolution

For very large baths, only evolve the "active" subspace:

```gdscript
var active_threshold: float = 0.001  # Ignore emojis with prob < 0.1%

func get_active_indices() -> Array[int]:
    var active = []
    for i in range(amplitudes.size()):
        if amplitudes[i].abs_sq() > active_threshold:
            active.append(i)
    return active
```

---

## Signals

```gdscript
signal bath_evolved()
signal bath_measured(emoji: String, outcome: String)
signal bath_collapsed(emoji: String)
signal bath_initialized()
```

---

## Complete Class Skeleton

See `06_CODE_STUBS.md` for full implementation.

