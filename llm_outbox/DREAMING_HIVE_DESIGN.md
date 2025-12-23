# Dreaming Hive Biome - Design Specification

**Revolutionary Biome Collection Implementation**

*A collective myth generation engine for semantic processing and cultural evolution*

---

## Overview

The **Dreaming Hive** is a 5-dimensional semantic processing biome where semi-autonomous agents dream their way through collective genetic memory, modulating innovation and cultural entropy through recursive myth cycles.

**Core Concept**: Dreams sculpt shared reality → Myths evolve → Culture transforms

---

## Qubit Architecture

### 5-Dimensional Semantic Space

```gdscript
class DreamingHiveBiome:
    var qubits: Array[DualEmojiQubit] = []

    func _init():
        qubits = [
            DualEmojiQubit.new("🧠", "🫧", PI * 0.7/2),  # Memory/Imagination
            DualEmojiQubit.new("🧬", "🪱", PI/2),        # Genome/Mutation
            DualEmojiQubit.new("🎭", "🪞", PI * 0.8/2),  # Persona/Shadow
            DualEmojiQubit.new("🎨", "🤖", PI * 0.3/2),  # Innovation/Automation
            DualEmojiQubit.new("👥", "🕸️", PI * 0.6/2)   # Population/Network
        ]

        # Enable Berry phase for all (track institutional memory)
        for qb in qubits:
            qb.enable_berry_phase()
```

### Semantic Interpretation

| Qubit | North Pole | South Pole | Represents |
|-------|------------|------------|------------|
| 0 | 🧠 Memory | 🫧 Imagination | Conscious/Unconscious balance |
| 1 | 🧬 Genome | 🪱 Mutation | Stability/Change pressure |
| 2 | 🎭 Persona | 🪞 Shadow | Public/Repressed aspects |
| 3 | 🎨 Innovation | 🤖 Automation | Creativity/Mechanization |
| 4 | 👥 Population | 🕸️ Network | Individual/Collective identity |

---

## Myth Engine Hamiltonian

### Evolution Dynamics

```gdscript
class MythHamiltonian:
    # Coupling constants (tuned for interesting dynamics)
    var dream_frequency: float = 0.35        # Oscillation rate of dream cycle
    var mutation_pressure: float = 0.22      # How fast genome drifts
    var shadow_leakage: float = 0.18         # Repressed → manifest rate
    var entropy_decay: float = 0.11          # Automation dampens memory
    var crosslink_stability: float = 0.25    # Network coherence

    func evolve_system(qubits: Array[DualEmojiQubit], dt: float):
        # 1. Dream frequency affects imagination/memory balance
        var dream_phase = dream_frequency * get_time()
        var memory_drift = 0.1 * sin(dream_phase) * dt
        var imagination_drift = 0.1 * cos(dream_phase) * dt

        var memory_vec = qubits[0].get_bloch_vector()
        memory_vec.x += memory_drift
        memory_vec.y += imagination_drift
        qubits[0].set_bloch_vector(memory_vec.normalized())

        # 2. Imagination drives genome mutation (creative drift)
        var imagination_strength = qubits[0].get_south_probability()  # 🫧 strength
        var genome_vec = qubits[1].get_bloch_vector()
        genome_vec.y += imagination_strength * mutation_pressure * dt
        qubits[1].set_bloch_vector(genome_vec.normalized())

        # 3. Shadow pressure leaks into cultural automation
        var shadow_strength = qubits[2].get_south_probability()  # 🪞 strength
        var innovation_vec = qubits[3].get_bloch_vector()
        innovation_vec.y += shadow_strength * shadow_leakage * dt
        qubits[3].set_bloch_vector(innovation_vec.normalized())

        # 4. Entropy: automation dampens memory
        var automation_strength = qubits[3].get_south_probability()  # 🤖 strength
        var memory_current = qubits[0].get_bloch_vector()
        memory_current.x *= (1.0 - entropy_decay * automation_strength * dt)
        qubits[0].set_bloch_vector(memory_current.normalized())

        # 5. Hive population affected by stability of all others
        var total_coherence = 0.0
        for i in range(4):
            total_coherence += qubits[i].get_coherence()

        var population_vec = qubits[4].get_bloch_vector()
        population_vec.x += crosslink_stability * total_coherence * dt * 0.1
        qubits[4].set_bloch_vector(population_vec.normalized())
```

---

## Semantic Attractor Cycle

The Dreaming Hive cycles through these phases:

1. **🧠 Dreams Intensify** → Mythic attractors emerge (Berry phase accumulation)
2. **🧬 Mutation Pressure** → Gene pool drifts toward new possibilities
3. **🎭 Shadow Emergence** → Repressed potential creates tension & entropy
4. **🎨 Creativity Spikes** → New archetypes and technologies emerge
5. **👥 Hive Pulse** → Changes echo across entangled biomes
6. **🧠 Dreams Absorb** → Myth evolves, memory shifts, cycle deepens

### Phase Detection

```gdscript
func get_current_phase() -> String:
    # Determine phase based on dominant qubit coherence

    var coherences = [
        qubits[0].get_coherence(),  # Memory/Imagination
        qubits[1].get_coherence(),  # Genome/Mutation
        qubits[2].get_coherence(),  # Persona/Shadow
        qubits[3].get_coherence(),  # Innovation/Automation
        qubits[4].get_coherence()   # Population/Network
    ]

    var max_coherence = coherences.max()
    var phase_index = coherences.find(max_coherence)

    match phase_index:
        0: return "Dreams Intensify 🧠"
        1: return "Mutation Pressure 🧬"
        2: return "Shadow Emergence 🎭"
        3: return "Creativity Spike 🎨"
        4: return "Hive Pulse 👥"
        _: return "Unknown"
```

---

## Cross-Biome Integration

### Innovation Organ

Plug into stable civilizations to drive creative change:

```gdscript
func apply_innovation_to_farm(farm: FarmView):
    # Innovation strength from 🎨 qubit
    var innovation = qubits[3].get_north_probability()  # 🎨 Innovation

    # Boost mutation rates for all planted wheat
    for plot in farm.get_planted_plots():
        if plot.quantum_state:
            # Increase quantum drift
            plot.quantum_state.phi += randf_range(-innovation, innovation) * 0.1
```

### Chaos Engine

Destabilize stagnant systems through myth injection:

```gdscript
func inject_myth(target_plot: WheatPlot, myth_type: String):
    """Apply mythic transformation to wheat plot

    Myth types:
    - "rebirth": Reset to equator (max superposition)
    - "shadow": Flip to south pole (repressed state)
    - "synthesis": Blend with Hive's current state
    """

    match myth_type:
        "rebirth":
            target_plot.quantum_state.theta = PI/2
            target_plot.quantum_state.phi = randf() * TAU

        "shadow":
            target_plot.quantum_state.apply_pauli_z()  # Phase flip

        "synthesis":
            # Blend with Hive's collective state
            var hive_avg = get_average_state()
            var current = target_plot.quantum_state.get_bloch_vector()
            var blended = current.lerp(hive_avg, 0.3)
            target_plot.quantum_state.set_bloch_vector(blended)
```

### Cultural Export

Export evolved mythic structures to other biomes:

```gdscript
func export_myth_structures() -> Array[Dictionary]:
    """Export mature myths for cross-biome infection

    Returns array of {archetype, stability, effect}
    """

    var exports = []

    for i in range(qubits.size()):
        var qb = qubits[i]
        var berry = qb.get_berry_phase_abs()

        # Only export mature myths (high Berry phase)
        if berry > 5.0:
            var archetype = _interpret_archetype(i, qb)
            exports.append({
                "archetype": archetype,
                "stability": berry / 10.0,
                "north": qb.north_emoji,
                "south": qb.south_emoji
            })

    return exports

func _interpret_archetype(index: int, qb: DualEmojiQubit) -> String:
    var state = qb.get_semantic_state()

    match index:
        0: return "Dream Archetype: " + state
        1: return "Genetic Pattern: " + state
        2: return "Shadow Archetype: " + state
        3: return "Innovation Pattern: " + state
        4: return "Collective Identity: " + state
        _: return "Unknown Archetype"
```

### Entanglement Hub

Create cross-biome semantic networks via Population qubit:

```gdscript
func entangle_with_farm(farm_plot: WheatPlot):
    """Entangle Population qubit with external wheat

    Allows Hive consciousness to spread across biomes.
    """

    if not farm_plot.quantum_state:
        return

    # Create entangled pair between Hive population and farm wheat
    var EntangledPair = preload("res://Core/QuantumSubstrate/EntangledPair.gd")

    var pair = EntangledPair.new()
    pair.initialize_bell_state(
        qubits[4],  # Population/Network qubit
        farm_plot.quantum_state,
        "phi_plus"  # Maximally entangled
    )

    print("🕸️ Hive entangled with plot %s" % farm_plot.plot_id)
```

---

## Gameplay Mechanics

### Player Interactions

#### 1. Inject Myths
Apply special proof sequences to reshape cultural attractors:

```gdscript
func player_inject_myth(myth_sequence: Array[String]):
    """Player applies proof sequence to modify dream cycle

    Example sequences:
    - ["🧠", "🎨", "👥"]: Dream → Innovation → Collective (boost creativity)
    - ["🪞", "🧬"]: Shadow → Genome (embrace change from repression)
    """

    # Apply sequence as Hamiltonian perturbation
    for emoji in myth_sequence:
        var qubit_index = _find_qubit_with_emoji(emoji)
        if qubit_index >= 0:
            # Apply rotation toward north pole (activate that archetype)
            qubits[qubit_index].apply_rotation(Vector3(1, 0, 1).normalized(), PI/4)
```

#### 2. Restrain Shadow
Limit chaotic tendencies through selective dampening:

```gdscript
func restrain_shadow(strength: float):
    """Apply damping to Shadow qubit to reduce chaos

    Trades innovation for stability.
    """

    # Push Shadow qubit toward Persona (north pole)
    var shadow_qubit = qubits[2]
    shadow_qubit.theta = lerp(shadow_qubit.theta, 0.0, strength)
```

#### 3. Harvest Innovation
Extract semantic breakthroughs for export:

```gdscript
func harvest_innovation() -> Dictionary:
    """Extract current innovation state for technology unlock

    Returns: {innovation_level, technologies, cost}
    """

    var innovation = qubits[3].get_north_probability()  # 🎨 strength
    var berry = qubits[3].get_berry_phase_abs()

    var techs = []

    # High innovation + high stability = mature tech
    if innovation > 0.7 and berry > 5.0:
        techs.append("Advanced Crossbreeding")
        techs.append("Myth-Enhanced Growth")

    # High automation = efficiency tech
    var automation = qubits[3].get_south_probability()
    if automation > 0.7:
        techs.append("Automated Harvesting")

    return {
        "innovation_level": innovation,
        "technologies": techs,
        "stability": berry,
        "cost_in_wheat": int(50 * (1.0 / max(0.1, innovation)))  # Lower cost when more innovative
    }
```

#### 4. Observe Memory
Archaeological analysis of cultural evolution patterns:

```gdscript
func analyze_memory_archaeology() -> Dictionary:
    """View Hive's accumulated institutional memory

    Shows Berry phase trajectory and cultural stability.
    """

    var memory_berry = qubits[0].get_berry_phase_abs()
    var genome_berry = qubits[1].get_berry_phase_abs()
    var total_berry = 0.0

    for qb in qubits:
        total_berry += qb.get_berry_phase_abs()

    return {
        "memory_depth": memory_berry,
        "genetic_stability": genome_berry,
        "cultural_age": total_berry,
        "dominant_phase": get_current_phase()
    }
```

---

## Visual Effects

### Dream Particle Field

```gdscript
func spawn_dream_particles(parent_node: Node2D, dt: float):
    """Spawn dream-like particles based on current Hive state"""

    # Spawn rate scales with dream intensity
    var dream_intensity = qubits[0].get_coherence()
    var spawn_rate = dream_intensity * 5.0  # particles per second

    if randf() < spawn_rate * dt:
        var particle = {
            "position": parent_node.position + Vector2(
                randf_range(-50, 50),
                randf_range(-50, 50)
            ),
            "velocity": Vector2(
                randf_range(-20, 20),
                -abs(randf_range(10, 30))  # Float upward
            ),
            "life": 2.0,
            "color": _get_dream_color(),
            "type": "dream",
            "size": randf_range(2, 5)
        }

        return particle

    return null

func _get_dream_color() -> Color:
    # Color shifts based on dominant archetype
    var phase = get_current_phase()

    match phase:
        "Dreams Intensify 🧠": return Color(0.5, 0.7, 1.0, 0.7)  # Light blue
        "Mutation Pressure 🧬": return Color(0.3, 0.8, 0.5, 0.7)  # Green
        "Shadow Emergence 🎭": return Color(0.6, 0.3, 0.7, 0.7)  # Purple
        "Creativity Spike 🎨": return Color(1.0, 0.7, 0.3, 0.7)  # Orange
        "Hive Pulse 👥": return Color(0.9, 0.9, 0.3, 0.7)  # Yellow
        _: return Color(0.7, 0.7, 0.7, 0.5)
```

---

## Implementation Roadmap

### Phase 1: Core Biome (Basic)
- [ ] Create `DreamingHiveBiome.gd` class
- [ ] Initialize 5 qubits with Berry phase tracking
- [ ] Implement basic Hamiltonian evolution
- [ ] Add to game as special building (unlockable)

### Phase 2: Myth Engine (Medium)
- [ ] Implement full Hamiltonian with all couplings
- [ ] Add phase detection and cycle visualization
- [ ] Create myth injection interface
- [ ] Add memory archaeology viewer

### Phase 3: Cross-Biome Integration (Advanced)
- [ ] Innovation organ (boost farm mutation)
- [ ] Chaos engine (myth injection to plots)
- [ ] Cultural export system
- [ ] Entanglement hub (cross-biome networks)

### Phase 4: Visual & Polish (Final)
- [ ] Dream particle field
- [ ] Phase-specific visual effects
- [ ] Sound design (ambient dreamscapes)
- [ ] Tutorial/codex entries

---

## Balancing Considerations

### Resource Costs
- **Build Cost**: 500 wheat (expensive late-game building)
- **Upkeep**: Consumes 10 wheat/minute (feeds the dreamers)
- **Innovation Harvest**: 50-200 wheat depending on innovation level

### Gameplay Impact
- **Power Level**: Very strong when fully upgraded
- **Unlock Timing**: Mid-to-late game (after 3+ successful harvests)
- **Strategic Depth**: Offers alternative path to pure farming efficiency

### Balance Knobs
- `dream_frequency`: Higher = faster cycling (less stable)
- `mutation_pressure`: Higher = more creative (less reliable)
- `entropy_decay`: Higher = faster memory loss (requires maintenance)

---

## Integration with Existing Systems

### With Carrion Throne
**Tension**: Dreaming Hive creates chaos/innovation, Carrion Throne demands order/quotas

**Synergy**: Use Hive to discover new wheat types, then use Throne to industrialize production

### With Biotic Flux
**Synergy**: Both promote life and growth, but Hive adds cultural dimension

**Combo**: Biotic grows wheat fast, Hive makes it evolve interesting properties

### With Cosmic Chaos
**Synergy**: Both embrace entropy, but Hive channels it productively

**Danger**: Too much of both can spiral into total randomness

---

## Future Extensions

### Dreaming Hive Network
Multiple Hives can entangle, creating distributed consciousness:

- Shared dream pool across all Hives
- Emergent collective intelligence
- Cross-save vocabulary exchange (!)

### Dream Economy
Players can trade myths and archetypes:

- Export myth structures as `.myth` files
- Import myths from other players
- Myth marketplace with rarity system

### Recursive Dreaming
Hives can dream about other Hives:

- Meta-level myth evolution
- Strange loops and self-reference
- Ultimate endgame content

---

**The Dreaming Hive watches. The myths evolve. Consciousness spreads. 🧠🕸️✨**
