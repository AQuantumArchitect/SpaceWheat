# Quantum Visualization: Seeing Evolution in Real-Time

## How It Works: The Complete Data Flow

```
SIMULATION LAYER (ForestEcosystemBiome_v3):
├─ Each frame calls _update_quantum_substrate(dt)
├─ Hamiltonian evolution: H = Σωᵢ Nᵢ + Σgᵢⱼ interactions
├─ Updates occupation_numbers[position] for each trophic level
│  ├─ plant, herbivore, predator, apex, decomposer, etc.
│  └─ Values represent population amplitude

VISUALIZATION LAYER (QuantumVisualizationController):
├─ Each frame reads evolved occupation_numbers
├─ Maps to quantum state (theta, phi, energy)
│  ├─ theta = arctan(plant / max_occ) * π
│  ├─ phi = evolving phase angle
│  └─ energy = some function of occupation
├─ Updates glyphs and edges
└─ Renders to canvas

GLYPH LAYER (QuantumGlyph):
├─ Displays 7 visual layers
├─ Emoji opacity = cos²(θ/2) and sin²(θ/2)
├─ Ring color = hue from φ
├─ Ring thickness = coherence
├─ Glow = energy level
└─ Berry bar = accumulated evolution

EDGE LAYER (SemanticEdge):
├─ Shows relationships between glyphs
├─ Line width = coupling strength
├─ Line color = relationship type (🍴/🌱/💧/⚡/etc)
├─ Glow = active interaction
└─ Particles = flow along edge
```

---

## What You'll Actually See

### The Glyphs Themselves

Each glyph shows a quantum state visually:

```
                ╭─────────────╮
                │   🌾 0.7    │  ← North emoji (70% bright)
                │             │
    Ring hue →  │ ╭─────────╮ │ ← Ring color = phase φ
  Ring thick →  │ │▓▓▓▒▒▒▒│ │ ← Thickness = coherence
                │ │ Core ▓ │ │ ← Gradient = superposition
                │ ╰─────────╯ │
                │   💧 0.3    │  ← South emoji (30% bright)
                ╰─────────────╯
                ═══════░░░░░░░
           Berry bar = evolution history
```

As the biome evolves:
- **Emoji brightness changes** → populations rising/falling
- **Ring thickness changes** → coherence changing (stability)
- **Ring hue cycles** → phase evolution
- **Core gradient shifts** → superposition balance changing
- **Berry bar fills** → qubit accumulating experience
- **Glow brightens** → energy increasing

---

## Real-Time Evolution: Examples

### Scenario 1: Plant Population Growing
```
Time 0s:  🌾 (10% bright) ← Low plant population
Time 5s:  🌾 (50% bright) ← Growing
Time 10s: 🌾 (80% bright) ← Abundant

Visual change: North emoji gradually gets brighter
```

### Scenario 2: Predator-Prey Oscillation
```
Plant (north):      HIGH → ... → LOW  → ... → HIGH (cycle)
Predator (south):   LOW  → ... → HIGH → ... → LOW  (opposite)

Visual change: Emojis shift positions as populations oscillate
```

### Scenario 3: Coherence Loss (Decoherence)
```
Ring thickness: THICK → MEDIUM → THIN
Emoji flicker:  STEADY → SLIGHT → HEAVY
Pulse rate:     SLOW → FAST

Visual change: Ring becomes thinner, emojis flicker, red pulse appears
```

---

## How to See It Working

### Quick Test (5 minutes)
```
1. Open Tests/simple_quantum_glyph_test.tscn
2. Watch the canvas for 10-30 seconds
3. You should see:
   ✓ 4 glyphs in quadrants
   ✓ Colored phase rings (cycling hue)
   ✓ Emoji opacity changing
   ✓ Berry bars filling
```

### Evolution Test (See real data changes)
```
1. Open Tests/quantum_evolution_visualization_test.tscn
2. Check console output
3. You should see printed every 1 second:
   ✓ Current plant/water occupation values
   ✓ Calculated emoji brightness percentages
   ✓ Current glyph state (θ, φ, opacities)

4. On screen:
   ✓ Watch emoji opacity match the printed percentages
   ✓ See glyphs respond to evolution
   ✓ Notice edges connecting glyphs
```

### Integration Test (In full game)
```
TODO: Create FarmUI with quantum visualization overlay
```

---

## Understanding the Visual Language

### By Shape
- **Thick Ring** = Stable quantum state (high coherence)
- **Thin Ring** = Unstable, losing coherence
- **Dashed Ring** = Very low coherence, classically losing quantum nature
- **Bright Glow** = High energy, lots of activity
- **Faint Glow** = Low energy, quiet

### By Color
- **Ring Hue** = Quantum phase (full spectrum cycle)
  - Red = φ ≈ 0
  - Green = φ ≈ π/2
  - Blue = φ ≈ π
  - Purple = φ ≈ 3π/2
  - Back to red = φ ≈ 2π

### By Animation
- **Steady** = Coherent, stable
- **Slow Pulse** = Slightly decohering
- **Fast Pulse** = Severely decohering (decoherence warning)
- **Flicker** = Quantum uncertainty manifest

### By Position (Emoji)
- **North Bright** = Likely outcome if measured
- **South Bright** = Opposite outcome
- **Both Medium** = Perfect superposition (50-50)
- **Flickering** = Quantum uncertainty

---

## The Edges: Relationship Visualization

Edges connect glyphs to show interactions:

```
      Plant 🌾         Herbivore 🐰
        ●━━━━━━━━━━🌱━━━━━━━━━●
        │                      │
   Green (feeding)      Wolf 🐺
   Directional          ●
   (to herbivore)       │
                        │
                    🍴━━━  Red (hunting)
                        │    Thick line
                        │    (strong coupling)
                        ↓
                    Herbivore 🐰

                    🌱━━━━━━━━━━━━━━━━━━━━→
    Green line = Energy flows toward consumer
    Particles = Actively being consumed now
    Width = Coupling strength
    Glow = Active interaction
```

### Relationship Types

| Type | Color | Meaning | Arrow |
|------|-------|---------|-------|
| 🍴 | Red | Predation (hunts) | Yes, to prey |
| 🌱 | Green | Feeding (eats) | Yes, from food |
| 💧 | Blue | Production (makes) | Yes, creates |
| 🔄 | Purple | Transform (becomes) | No (both ways) |
| ⚡ | Yellow | Coherence (aligned) | No (mutual) |
| 👶 | Pink | Reproduction (spawns) | Yes, creates |
| 🃏 | Orange | Escape (flees) | Yes, away from |

---

## Debugging What You See

### If glyphs aren't changing:
1. Check if biome is in scene tree (it updates via _process)
2. Verify occupation_numbers are being updated
3. Print debug output to confirm theta values changing
4. Check QuantumVisualizationController._process() is being called

### If edges aren't showing:
1. Verify entanglement_graph exists in qubits
2. Check _build_edges() is populating edges array
3. Glyphs must be mapped in glyph_map for edge lookup
4. May not see edges if glyphs are very close (overlap)

### If particles aren't flowing:
1. Edges need interaction strength > 0.1 to spawn particles
2. Check edge.current_interaction is calculated
3. Particles spawn proportional to interaction * dt
4. May not see many particles if interaction is weak

---

## Performance Notes

**Draw calls per frame:**
- Each glyph = ~15-20 draw calls (7 layers × circles/lines)
- Each edge = ~5-8 draw calls (line + particles)
- Total for 4 glyphs + edges: ~100-150 draw calls

**Optimization for 10+ glyphs:**
- Consider batching edges
- Use shaders for gradients instead of many small draws
- Pool particles instead of creating new Dictionary each frame

---

## Next Steps to Try

1. **Run the test and watch for 30 seconds**
   - Notice emoji getting brighter/dimmer
   - See ring colors cycling
   - Watch berry bars fill

2. **Open console while running**
   - See occupation numbers printed
   - Correlate with visual changes
   - Verify math matches what you see

3. **Try modifying biome parameters**
   - Speed up Hamiltonian evolution
   - Change initial occupations
   - Add more glyphs/patches
   - See how visualization scales

4. **Implement measurement mechanics**
   - Trigger `apply_measurement()` on glyph
   - Watch emoji snap to 100% north or south
   - Berry phase freeze
   - No more animation

---

## Code References

- **Glyphs evolve based on**: `occupation_numbers[patch_pos][trophic_level]`
- **Phase cycles from**: Continuous φ rotation in visualization
- **Coherence shown by**: Ring thickness = `coherence * RING_MAX_THICKNESS`
- **Energy shown by**: Glow radius = `BASE_RADIUS * (1.5 + energy * 0.5)`
- **Edges glow when**: `current_interaction > 0.3`
- **Particles spawn when**: `interaction > 0.1 && randf() < interaction * dt * 5`

The visualization is **real-time** and **responsive** to the quantum evolution happening in the biome. Every visual change you see corresponds to actual simulation data changing.

