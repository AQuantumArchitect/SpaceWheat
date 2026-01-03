# Quantum State Properties vs Injection/Extraction Investigation

## Executive Summary

The game's quantum mechanics use **density matrix formalism** with plots as **projection lenses** into a shared **QuantumBath**. The critical insight: **radius (coherence) represents extractable quantum resources**, NOT theta. Theta only rotates between outcomes without adding energy. The current issue is that planting creates **zero-coherence projections** that require time/coupling to develop harvestable resources.

---

## 1. Quantum State Properties Definitions

### DualEmojiQubit (Projection Lens)
**File:** `/home/tehcr33d/ws/SpaceWheat/Core/QuantumSubstrate/DualEmojiQubit.gd`

All properties are **computed from QuantumBath density matrix** - no stored state!

| Property | Type | Range | Physics Meaning | Game Meaning |
|----------|------|-------|-----------------|--------------|
| **theta** | float | [0, π] | Polar angle on Bloch sphere | **Balance between north/south outcomes** |
| **phi** | float | [0, 2π) | Azimuthal angle | Relative phase (visualization only) |
| **radius** | float | [0, 1] | Bloch vector length | **COHERENCE - extractable quantum resource** |
| **purity** | float | [0.5, 1] | Tr(ρ²) of 2×2 subspace | Quantum vs classical mixing |
| **subspace_probability** | float | [0, 1] | P(north) + P(south) | How much bath is in this 2D slice |

**CRITICAL:** There is NO `.energy` property! This was removed during bath-first refactor.

---

## 2. What Represents "Energy" / "Excitation"?

### Answer: Radius (Coherence), NOT Theta

**Theta Confusion:**
```gdscript
# WRONG MENTAL MODEL:
theta = 0      → "high energy north state"  ❌
theta = π      → "high energy south state"  ❌
theta = π/2    → "low energy mixed state"   ❌

# CORRECT MENTAL MODEL:
theta = 0      → "100% probability of north outcome" ✅
theta = π      → "100% probability of south outcome" ✅
theta = π/2    → "50/50 superposition"              ✅
```

**Theta just rotates the Bloch vector - it doesn't change its length!**

**Radius (Coherence) is the True Resource:**
```gdscript
radius = 1.0   → Pure quantum state, maximum extractable resource  ✅
radius = 0.5   → Partially mixed, some quantum resource available  ✅
radius = 0.0   → Maximally mixed, NO extractable quantum resource  ✅
```

**Evidence from Harvest Logic** (`BasePlot.gd:164-189`):
```gdscript
# Yield based on coherence (radius) - higher purity = better extraction efficiency
var coherence_value = quantum_state.radius * 0.9  # Extract 90% of coherence

# Purity multiplier for yield:
# - Pure state (Tr(ρ²) = 1.0) → 2.0× yield
# - Mixed state (Tr(ρ²) = 0.5) → 1.0× yield
var purity_multiplier = 2.0 * purity

# Yield calculation: 1 credit per 0.1 coherence, scaled by purity
var base_yield = coherence_value * 10
var yield_amount = max(1, int(base_yield * purity_multiplier))
```

**Therefore:**
- **Radius (coherence)** = quantum resource amount
- **Purity** = extraction efficiency multiplier
- **Theta** = which outcome you'll get when you extract
- **Expected Energy ⟨H⟩** = Tr(ρH) from Hamiltonian (not used in harvest currently)

---

## 3. Injection Mechanisms (How Resources Enter the Quantum System)

### 3A. Tool 1 (Grower) - Planting
**File:** `BasePlot.gd:75-110`

**What happens when you plant:**
```gdscript
# 1. Create projection from biome bath
quantum_state = biome.create_projection(grid_position, north_emoji, south_emoji)

# 2. Biome injects emojis into bath if missing (BiomeBase.gd:497-523)
if not bath.emoji_to_index.has(north):
    bath.inject_emoji(north, north_icon, Complex.zero())  # ← ZERO AMPLITUDE!

if not bath.emoji_to_index.has(south):
    bath.inject_emoji(south, south_icon, Complex.zero())  # ← ZERO AMPLITUDE!

bath.normalize()  # Redistributes probability across ALL emojis
```

**Result:** New projection starts with **radius ≈ 0** (maximally mixed in bath)

**Why this creates the "?" harvest problem:**
- Bath is maximally mixed → all emojis equal probability
- Projection onto north/south axis has NO coherence (r=0)
- Harvest of r=0 state → unknown outcome "?" → minimal credits

---

### 3B. Tool 4 (Biome Control Q) - Energy Tap Injection (DEPRECATED)
**File:** `BiomeBase.gd:306-349` (boost_hamiltonian_coupling)

**OLD SYSTEM (violates unitarity):**
```gdscript
# DEPRECATED: bath.boost_amplitude(emoji, amount)
# Directly modified ρᵢᵢ - violates unitarity!
```

**NEW SYSTEM (physically correct):**
```gdscript
# Modify Hamiltonian coupling strength instead
icon_a.hamiltonian_couplings[emoji_b] = old_coupling * boost_factor
bath.build_hamiltonian_from_icons(bath.active_icons)

# This makes coherent oscillations FASTER, not direct injection
```

**Effect on coherence:**
- Boosted coupling → faster θ rotation between emojis
- Does NOT directly increase radius!
- Must wait for evolution to build coherence through Hamiltonian dynamics

---

### 3C. BiomeBase.hot_drop_emoji() - Dynamic Injection
**File:** `BiomeBase.gd:232-291`

**Purpose:** Inject new emoji into running bath with full Icon physics

```gdscript
bath.inject_emoji(emoji, icon, initial_amplitude)
# Default: initial_amplitude = Complex.zero()

# Then rebuild operators to include new emoji's Hamiltonian/Lindblad
bath.build_hamiltonian_from_icons(all_icons)
bath.build_lindblad_from_icons(all_icons)
```

**Effect:**
- Adds emoji to bath Hilbert space
- Brings its Icon's Hamiltonian couplings and Lindblad operators
- Still needs evolution time to develop coherence

---

### 3D. Hamiltonian Evolution - Natural Injection
**File:** `QuantumBath.gd:368-383`

**How coherence actually builds up:**
```gdscript
func evolve(dt: float) -> void:
    bath_time += dt
    update_time_dependent()  # Update Hamiltonian
    _evolver.evolve_in_place(_density_matrix, dt)  # Master equation
    bath_evolved.emit()
```

**Master equation:** dρ/dt = -i[H, ρ] + L(ρ)
- **Hamiltonian term:** Coherent oscillations (builds coherence via coupling)
- **Lindblad term:** Decoherence/dissipation (reduces coherence)

**For coherence to build:**
- Need H[i,j] ≠ 0 (Hamiltonian coupling between emojis)
- Need time for evolution
- Strong coupling → faster coherence buildup

---

## 4. Extraction Mechanisms (How Resources Leave the Quantum System)

### 4A. Tool 1 (Grower R) - Harvest
**File:** `BasePlot.gd:141-208`

**Two-phase extraction:**

**PHASE 1: Measurement (collapse)**
```gdscript
func measure() -> String:
    # Bath measurement with Born rule
    var outcome = quantum_state.measure()  # Calls bath.measure_axis()

    # Born rule: P(north) = cos²(θ/2), P(south) = sin²(θ/2)
    # Collapse strength: 0.5 (partial collapse, preserves some coherence)

    has_been_measured = true
    measured_outcome = outcome  # Stores "🌾", "👥", or "?"
    return outcome
```

**PHASE 2: Resource extraction (harvest)**
```gdscript
func harvest() -> Dictionary:
    # Auto-measure if needed
    if not has_been_measured:
        measure()

    # Extract coherence (90% efficiency)
    var coherence_value = quantum_state.radius * 0.9
    coherence_value += berry_phase * 0.1  # Entanglement bonus

    # Purity multiplier
    var purity = quantum_state.bath.get_purity()  # Tr(ρ²)
    var purity_multiplier = 2.0 * purity

    # Yield: 1 credit per 0.1 coherence
    var yield_amount = max(1, int(coherence_value * 10 * purity_multiplier))

    return {
        "outcome": measured_outcome,  # Emoji: "🌾", "👥", "?"
        "yield": yield_amount,        # Credits earned
        "energy": coherence_value,    # Legacy key - actually coherence
        "purity": purity
    }
```

**Key insight:** Harvest extracts **radius × purity**, NOT theta!

**Why "?" outcome happens:**
- If radius = 0 (no coherence), measurement is random across all bath emojis
- Outcome might be emoji NOT in {north, south} projection
- Unknown emoji → "?" → minimal credits

---

### 4B. Tool 2 (Quantum R) - Batch Measurement
**File:** `Farm.gd:705-722`

**Measures all planted plots:**
```gdscript
func measure_all() -> int:
    for each plot:
        if plot.is_planted and not plot.has_been_measured:
            measure_plot(pos)  # Collapses quantum state
```

**Effect on coherence:**
- Partial collapse (strength=0.5) reduces radius slightly
- Dampens off-diagonal coherences in density matrix
- Prepares plot for harvest

---

### 4C. Energy Drain (DEPRECATED)
**File:** `QuantumBath.gd:263-287`

**Old system:**
```gdscript
func drain_amplitude(emoji: String, amount: float) -> float:
    # WARNING: Violates unitarity!
    var new_prob = current_prob - amount
    mat.set_element(idx, idx, Complex.new(new_prob, 0.0))
```

**Why deprecated:**
- Directly modifies ρᵢᵢ without unitary evolution
- Breaks probability conservation
- Should use Lindblad dissipation instead

---

## 5. Theta vs Radius vs Energy: The Complete Picture

### Visual Analogy: Bloch Sphere

```
         North (🌾)
            ↑ θ=0
            |
            |    radius = 1 (pure)
      ┌─────┼─────┐
     /      |      \
    /       |       \    ← Equator: θ=π/2 (50/50)
   |        |        |       radius still = 1 if pure!
    \       |       /
     \      |      /
      └─────┼─────┘
            |
            ↓ θ=π
         South (👥)

Maximally mixed: radius = 0 (point at center, no vector)
```

**Theta controls DIRECTION (which outcome), Radius controls MAGNITUDE (how much resource)**

### Example States:

| State Description | theta | radius | purity | Harvest Outcome | Yield |
|-------------------|-------|--------|--------|-----------------|-------|
| Pure north (100% 🌾) | 0.0 | 1.0 | 1.0 | 🌾 | ~18 credits |
| Pure south (100% 👥) | π | 1.0 | 1.0 | 👥 | ~18 credits |
| Pure superposition | π/2 | 1.0 | 1.0 | 🌾 or 👥 (50/50) | ~18 credits |
| Mixed 50/50 classical | π/2 | 0.0 | 0.5 | ? (random) | ~1 credit |
| Partial coherence | π/2 | 0.5 | 0.75 | 🌾 or 👥 (50/50) | ~6-8 credits |

**Key insight:** Pure superposition (r=1, θ=π/2) gives SAME yield as pure north (r=1, θ=0)!

---

## 6. Why Current Harvest Produces "?" Outcomes

### Root Cause Analysis:

**Step 1: Planting creates zero-coherence projection**
```gdscript
# BiomeBase.create_projection() injects with Complex.zero()
bath.inject_emoji(north, north_icon, Complex.zero())
bath.inject_emoji(south, south_icon, Complex.zero())
bath.normalize()  # Redistributes across all emojis equally
```

**Result:** Projection onto {north, south} has radius ≈ 0

**Step 2: Immediate harvest (no evolution time)**
```gdscript
# User plants and immediately harvests
farm.build(Vector2i(0,0), "wheat")
farm.harvest_plot(Vector2i(0,0))  # Same frame or next frame
```

**Result:** No time for Hamiltonian evolution to build coherence

**Step 3: Measurement of zero-coherence state**
```gdscript
# Born rule measurement in bath
var p_north = bath.get_probability("🌾")  # ≈ 1/N (all emojis equal)
var p_south = bath.get_probability("👥")  # ≈ 1/N
var total = p_north + p_south  # ≈ 2/N

# Outcome might be ANY emoji in bath, not just north/south!
if randf() < p_north / total:
    outcome = north  # Unlikely if bath has many emojis
else:
    outcome = south  # Also unlikely
# More likely: measure() returns different emoji → stored as "?"
```

**Result:** "?" outcome with yield = 1 credit (minimum)

---

## 7. How to Fix / Optimize Resource Extraction

### Option A: Wait for Evolution (Current Design Intent)
```gdscript
# Plant
farm.build(Vector2i(0,0), "wheat")

# Wait for quantum evolution
await get_tree().create_timer(5.0).timeout

# Harvest
farm.harvest_plot(Vector2i(0,0))
```

**Requires:**
- Hamiltonian coupling H["🌾"]["👥"] > 0 (Icon physics)
- Time for coherent oscillations to build radius
- Works IF Icons have proper couplings defined

---

### Option B: Boost Hamiltonian Coupling (Tool 4)
```gdscript
# Plant
farm.build(Vector2i(0,0), "wheat")

# Boost coupling between wheat emojis
var biome = farm.grid.get_biome_for_plot(Vector2i(0,0))
biome.boost_hamiltonian_coupling("🌾", "👥", 5.0)  # 5x faster

# Wait shorter time
await get_tree().create_timer(1.0).timeout

# Harvest with better coherence
farm.harvest_plot(Vector2i(0,0))
```

---

### Option C: Entangle First (Tool 1 E)
```gdscript
# Plant two plots
farm.build(Vector2i(0,0), "wheat")
farm.build(Vector2i(1,0), "wheat")

# Entangle them (creates Bell state with r=1 instantly)
farm.entangle_plots(Vector2i(0,0), Vector2i(1,0), "phi_plus")

# Harvest BOTH (entangled pair has coherence)
farm.harvest_plot(Vector2i(0,0))
farm.harvest_plot(Vector2i(1,0))
```

**Why this works:**
- Bell state preparation forces radius → 1
- Instant coherence without waiting for evolution
- Yields will be correlated (both 🌾 or both 👥)

---

### Option D: Inject with Non-Zero Amplitude (Developer Fix)
**File:** `BiomeBase.gd:501, 514`

```gdscript
# CURRENT (creates r=0):
bath.inject_emoji(north, north_icon, Complex.zero())

# PROPOSED FIX (creates r>0 immediately):
var initial_coherence = 0.3  # 30% of max
var amp = sqrt(initial_coherence / bath.emoji_list.size())
bath.inject_emoji(north, north_icon, Complex.new(amp, 0.0))
```

**Trade-off:** Violates "quantum farming" theme where you must cultivate coherence

---

## 8. Tool-by-Tool Injection/Extraction Summary

| Tool | Action | Injection Mechanism | Extraction Mechanism | Effect on Radius | Effect on Theta |
|------|--------|---------------------|----------------------|------------------|-----------------|
| **1 (Grower)** | Q Plant | Create projection (r≈0) | - | Sets r≈0 initially | Sets θ=π/2 |
| **1 (Grower)** | E Entangle | Bell state (r→1) | - | Forces r=1 | Locks θ to Bell correlations |
| **1 (Grower)** | R Harvest | - | Extract r×purity as yield | Sets r=0 (clears plot) | - |
| **2 (Quantum)** | Q Cluster | GHZ state (r→1 for trio) | - | Forces r=1 | Locks θ to GHZ |
| **2 (Quantum)** | R Measure | - | Collapse only (no clear) | Reduces r slightly | Freezes θ |
| **3 (Industry)** | Mill/Market | Transfer between plots | - | Transfers r | Preserves θ |
| **4 (Biome)** | Q Energy Tap | Boost H coupling (faster θ rotation) | - | Builds r over time | Rotates θ faster |
| **4 (Biome)** | E Boost Coupling | Modify Hᵢⱼ | - | Indirect (via evolution) | Faster rotation |
| **5 (Gates)** | Hadamard | Unitary rotation | - | Preserves r | Rotates θ by π/4 |
| **5 (Gates)** | CNOT | Two-qubit entanglement | - | Can increase r via entanglement | Complex θ changes |
| **6 (Biome)** | Assign Biome | Changes which bath plots project from | - | Switches r source | Switches θ source |

---

## 9. Key Findings for Game Design

### 🎯 **Radius (coherence) IS the resource, NOT theta**

**Implications:**
- Players should farm coherence, not specific theta values
- High-coherence pure states (r=1) give max yield regardless of θ
- Low-coherence mixed states (r≈0) give "?" outcomes and minimal yield

### ⚠️ **Current planting creates r≈0 (no resources to harvest)**

**Why:**
- `bath.inject_emoji()` uses `Complex.zero()` amplitude
- Bath normalizes to maximally mixed state
- Projection onto any 2D axis has no coherence

**Fix options:**
1. Wait for Hamiltonian evolution (intended gameplay)
2. Boost coupling strength (Tool 4)
3. Entangle immediately (Tool 1 E, Tool 2 Q)
4. Change injection to start with non-zero amplitude

### 🔬 **Entanglement is the fastest way to build coherence**

**Evidence:**
- Bell state preparation forces r→1 instantly
- No waiting for evolution required
- Tool 1 E and Tool 2 Q provide this

### 🌊 **Bath-first architecture requires Hamiltonian coupling to work**

**Current issue:**
- If Icons don't define Hamiltonian couplings between emojis
- Evolution won't build coherence (bath stays maximally mixed)
- Need to verify Icon definitions have proper H[🌾][👥] > 0

---

## 10. Recommended Test to Verify Hamiltonian Coupling

```gdscript
extends SceneTree

func _ready():
    # Boot
    var boot_mgr = get_node_or_null("/root/BootManager")
    if boot_mgr and not boot_mgr.is_ready:
        await boot_mgr.game_ready
    for i in range(5):
        await process_frame

    # Get farm
    var farm_view = root.find_child("FarmView", true, false)
    var farm = farm_view.get_farm()

    # Check Hamiltonian coupling for wheat
    var biome = farm.biotic_flux_biome
    if biome and biome.bath:
        print("=== HAMILTONIAN COUPLING TEST ===")
        print("Bath emojis: %s" % str(biome.bath.emoji_list))

        # Check if 🌾↔👥 coupling exists
        var H = biome.bath._hamiltonian
        var wheat_idx = biome.bath.emoji_to_index.get("🌾", -1)
        var labor_idx = biome.bath.emoji_to_index.get("👥", -1)

        if wheat_idx >= 0 and labor_idx >= 0:
            var coupling = H.get_element(wheat_idx, labor_idx)
            print("H[🌾][👥] = %s (magnitude: %.6f)" % [coupling, coupling.abs()])

            if coupling.abs() < 1e-10:
                print("❌ NO COUPLING! Evolution won't build coherence!")
            else:
                print("✅ Coupling exists - evolution will build coherence")
        else:
            print("❌ Emojis not in bath!")

    quit()
```

---

## Conclusion

**The quantum state properties serve distinct roles:**
- **Radius** = quantum resource amount (coherence)
- **Theta** = outcome selector (which emoji when measured)
- **Purity** = extraction efficiency multiplier
- **"Energy"** = DOES NOT EXIST (use radius as proxy, or compute ⟨H⟩)

**The injection/extraction flow:**
1. **Plant** → Create projection (r≈0, θ=π/2)
2. **Evolve** → Hamiltonian builds coherence (r increases over time)
3. **Measure** → Collapse to outcome (theta determines which emoji)
4. **Harvest** → Extract yield (radius × purity)

**The current "?" harvest issue is EXPECTED BEHAVIOR** when harvesting immediately after planting without giving time for quantum evolution to build coherence!
