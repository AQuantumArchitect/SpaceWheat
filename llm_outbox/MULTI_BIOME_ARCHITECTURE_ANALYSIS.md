# Multi-Biome Architecture - Analysis & Stitching Proposals

**Date:** 2026-01-01
**Status:** Investigation Complete - Ready for Implementation Decisions

---

## Executive Summary

SpaceWheat currently implements **fully isolated biomes** - each with its own quantum bath, independent evolution, and no cross-biome coupling. This document analyzes the current architecture and proposes four approaches for "stitching biomes together," ranging from lightweight icon coupling to full bath merging.

**Key Finding:** The architecture is intentionally modular and supports multiple stitching modes through different mechanisms.

---

## Part 1: How Multi-Biome Works NOW

### Current Architecture: Complete Isolation

```
┌─────────────────────────────────────────────────────────────┐
│  FARM GRID (12 plots across 4 biomes)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Row 0:  [T=Market] [Y=Market] | [U=BioticFlux] [I] [O] [P]│
│  Row 1:  [7=Forest] [8] [9] [0]| [,=Kitchen] [.=Kitchen]   │
│                                                             │
│  Each plot → ONE biome (via plot_biome_assignments)        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
           ↓              ↓               ↓              ↓
    ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐
    │  Market  │   │BioticFlux│   │  Forest  │   │ Kitchen  │
    │  Bath    │   │  Bath    │   │  Bath    │   │  Bath    │
    ├──────────┤   ├──────────┤   ├──────────┤   ├──────────┤
    │ 🐂 🐻 💰 │   │ ☀ 🌙 🌾  │   │ 🌲 🐺 🐰 │   │ 🔥 ❄️ 🍞 │
    │ 📦 🏛️ 🏚️│   │ 🍄 💀 🍂 │   │ (22 total)│   │ 🌾       │
    └──────────┘   └──────────┘   └──────────┘   └──────────┘
        ↑              ↑               ↑              ↑
    Independent    Independent    Independent    Independent
    Evolution      Evolution      Evolution      Evolution
```

**Each biome:**
- Has its own `QuantumBath` with unique emoji list
- Manages its own `active_projections` (plots)
- Evolves independently via `bath.evolve(dt)`
- Collapses independently when measured
- Has no knowledge of other biomes

---

### The Four Biomes

| Biome | File | Emojis (Total) | Quantum Mechanics | Game Purpose |
|-------|------|----------------|-------------------|--------------|
| **BioticFlux** | BioticFluxBiome.gd | 6: ☀ 🌙 🌾 🍄 💀 🍂 | Sun/Moon cycle + Wheat growth | Primary farming biome |
| **Market** | MarketBiome.gd | 6: 🐂 🐻 💰 📦 🏛️ 🏚️ | Bull/Bear sentiment trading | Economic simulation |
| **Forest** | ForestEcosystem_Biome.gd | 22 emojis | Predator-prey Markov dynamics | Complex ecosystem |
| **Kitchen** | QuantumKitchen_Biome.gd | 4: 🔥 ❄️ 🍞 🌾 | Bell state entanglement factory | Quantum cooking |

---

### Plot Assignment System

**Three-Level Architecture (FarmGrid.gd):**

```gdscript
// Level 1: REGISTRY - Store all biome instances
var biomes: Dictionary = {}  // String → BiomeBase
func register_biome(biome_name: String, biome_instance)

// Level 2: ASSIGNMENT - Map each plot position to a biome
var plot_biome_assignments: Dictionary = {}  // Vector2i → String
func assign_plot_to_biome(position: Vector2i, biome_name: String)

// Level 3: LOOKUP - Get biome for a plot
func get_biome_for_plot(position: Vector2i) → BiomeBase
```

**Current Assignments (Farm.gd lines 196-215):**

```
(0,0) → "Market"      (1,0) → "Market"
(2,0) → "BioticFlux"  (3,0) → "BioticFlux"  (4,0) → "BioticFlux"  (5,0) → "BioticFlux"
(0,1) → "Forest"      (1,1) → "Forest"      (2,1) → "Forest"      (3,1) → "Forest"
(4,1) → "Kitchen"     (5,1) → "Kitchen"
```

**Key Property:** Each plot belongs to **exactly one biome**. No overlap, no sharing.

---

### Bath-First Projection Architecture (Per-Biome)

```
BiomeBase (e.g., BioticFlux):
  ├─ bath: QuantumBath
  │   ├─ emoji_list: ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]
  │   ├─ amplitudes: [α₀, α₁, α₂, α₃, α₄, α₅]  (Complex numbers)
  │   └─ |ψ⟩ = α₀|☀⟩ + α₁|🌙⟩ + α₂|🌾⟩ + α₃|🍄⟩ + α₄|💀⟩ + α₅|🍂⟩
  │
  └─ active_projections: Dictionary
      ├─ (2,0) → {qubit: DualEmojiQubit, north: "🌾", south: "👥"}
      ├─ (3,0) → {qubit: DualEmojiQubit, north: "🌾", south: "👥"}
      └─ ...
```

**When you plant wheat at (2,0):**
1. FarmGrid looks up biome: `get_biome_for_plot((2,0))` → BioticFlux
2. Biome creates projection: `create_projection((2,0), "🌾", "👥")`
3. Projection reads from BioticFlux bath: `qubit.bath = biotic_flux.bath`
4. Theta computed live: `θ = f(α₂, α₃)` where α₂=wheat, α₃=labor

**When you measure at (2,0):**
1. Qubit measures: `qubit.measure()` → collapses bath in {🌾, 👥} subspace
2. BioticFlux bath collapses: Sets one emoji to 0, renormalizes others
3. **ALL projections in BioticFlux update automatically** (live coupling!)
4. **But Market, Forest, Kitchen baths are UNAFFECTED**

---

### Entanglement Within Biomes

**Bell Gates (BiomeBase.gd):**

```gdscript
var bell_gates: Array[Array[Vector2i]] = []

func mark_bell_gate(positions: Array):
    # Records entanglement between plots
    bell_gates.append(positions.duplicate())
    bell_gate_created.emit(positions)
```

**Example:** Entangle (2,0) and (3,0) in BioticFlux:
- Both plots project from same BioticFlux bath
- Measuring one affects the other (shared substrate)
- Bell gate recorded in `biotic_flux.bell_gates`

**Problem:** What if we entangle (2,0) BioticFlux with (0,0) Market?
- FarmGrid.create_entanglement() doesn't check biome boundaries
- Gate only marked in first biome
- Measurement cascade doesn't propagate across biomes
- **Cross-biome entanglement is BROKEN currently**

---

### Boundary Conditions

**Adjacent plots in different biomes:**

```
Row 0: [Y=Market] | [U=BioticFlux]
       ↓             ↓
     Market Bath  BioticFlux Bath
       (isolated)   (isolated)
```

**Current behavior:**
- No interaction at boundaries
- No energy flow between biomes
- No measurement cascade across boundary
- No special boundary logic at all

**This is intentional** - biomes are designed to be independent quantum subsystems.

---

### Icon Scoping (The ONE Cross-Biome Feature)

**FarmGrid.gd has icon scoping:**

```gdscript
var icon_scopes: Dictionary = {}  # Icon → Array[String] (biome names)

func add_scoped_icon(icon, biome_names: Array[String]):
    active_icons.append(icon)
    icon_scopes[icon] = biome_names

# During evolution (_apply_icon_effects):
for plot in plots:
    var biome_name = get_biome_name_for_plot(plot.position)
    for icon in active_icons:
        if icon_scopes.has(icon):
            if not icon_scopes[icon].has(biome_name):
                continue  # Skip this icon for this biome
        icon.apply_to(plot)
```

**Use Case:**
```gdscript
# Create an icon that only affects Forest and BioticFlux
var global_weather = GlobalWeatherIcon.new()
grid.add_scoped_icon(global_weather, ["Forest", "BioticFlux"])
```

**Limitation:** This is just **filtering** - not true quantum coupling. Icons can affect multiple biomes, but biomes' baths don't interact.

---

## Part 2: Stitching Biomes Together - Four Approaches

### Approach A: Cross-Biome Icon Coupling (Lightweight)

**Concept:** Create icons that affect multiple biomes simultaneously.

```
┌────────────────────────────────────────────────┐
│          GlobalWeatherIcon (new)               │
│  Affects: ["BioticFlux", "Forest", "Market"]  │
└────────────────────────────────────────────────┘
              ↓           ↓           ↓
      BioticFlux Bath  Forest Bath  Market Bath
         (☀ grows)    (☀ affects   (☀ affects
                      predators)    sentiment)
```

**Implementation:**

```gdscript
# 1. Create cross-biome icon
class GlobalWeatherIcon extends Icon:
    func compute_hamiltonian_element(emoji_a, emoji_b, biome):
        # Apply sun coupling in all biomes
        if emoji_a == "☀":
            if biome.name == "BioticFlux":
                return boost_wheat(emoji_b)
            elif biome.name == "Forest":
                return boost_herbivores(emoji_b)
            elif biome.name == "Market":
                return boost_sentiment(emoji_b)

# 2. Register with scope
var weather = GlobalWeatherIcon.new()
farm.grid.add_scoped_icon(weather, ["BioticFlux", "Forest", "Market"])
```

**Data Flow:**
```
Icon Evolution:
  → BioticFlux: Couples ☀ → 🌾 (wheat growth)
  → Forest: Couples ☀ → 🐰 (rabbit growth)
  → Market: Couples ☀ → 🐂 (bull sentiment)

Result: All three baths evolve together under icon influence
```

**Pros:**
- ✅ Simple to implement (uses existing infrastructure)
- ✅ No bath merging needed
- ✅ Low computational cost
- ✅ Can model environmental effects (weather, seasons)
- ✅ Non-breaking (biomes stay isolated otherwise)

**Cons:**
- ❌ Unidirectional influence only (icon → biomes, not biome ↔ biome)
- ❌ No true quantum coupling (baths don't share amplitudes)
- ❌ Limited to Icon-level effects (can't do cross-biome entanglement)

**When to Use:**
- Environmental effects (global weather, day/night)
- Economic effects (market sentiment affecting production)
- Difficulty modifiers (global chaos icon)

---

### Approach B: Boundary Weak Coupling (Medium)

**Concept:** Create special boundary qubits that couple adjacent biomes.

```
     Market Bath              BioticFlux Bath
        |                           |
    (0,0) Market Plot          (2,0) BioticFlux Plot
        ↓                           ↓
    ┌───────────────────────────────────────┐
    │   Boundary Qubit (virtual)            │
    │   Couples: Market Bath ↔ BioticFlux   │
    │   Strength: 0.1 (weak)                │
    └───────────────────────────────────────┘
```

**Implementation:**

```gdscript
class BoundaryQubit extends DualEmojiQubit:
    var north_biome: BiomeBase  # e.g., Market
    var south_biome: BiomeBase  # e.g., BioticFlux
    var coupling_strength: float = 0.1

    func _compute_theta_from_baths() -> float:
        # Sample from BOTH baths
        var p_north = north_biome.bath.get_population(north_emoji)
        var p_south = south_biome.bath.get_population(south_emoji)

        # Weighted average
        var total = p_north + p_south
        return 2.0 * acos(sqrt(p_north / total))

    func measure() -> String:
        var outcome = super.measure()

        # Feed energy back to BOTH baths
        if outcome == north_emoji:
            north_biome.bath.boost_amplitude(north_emoji, coupling_strength)
            south_biome.bath.drain_amplitude(south_emoji, coupling_strength)
        else:
            south_biome.bath.boost_amplitude(south_emoji, coupling_strength)
            north_biome.bath.drain_amplitude(north_emoji, coupling_strength)

        return outcome
```

**Usage:**

```gdscript
# Detect boundary plots
func create_boundary_couplings():
    for pos in grid.get_all_positions():
        var biome_a = get_biome_for_plot(pos)

        # Check adjacent plots
        for neighbor in [pos + Vector2i(1,0), pos + Vector2i(0,1)]:
            var biome_b = get_biome_for_plot(neighbor)

            if biome_a != biome_b:
                # Found boundary!
                var boundary_qubit = BoundaryQubit.new()
                boundary_qubit.north_biome = biome_a
                boundary_qubit.south_biome = biome_b
                boundary_qubits.append(boundary_qubit)
```

**Data Flow:**
```
Market (0,0) ← BoundaryQubit → BioticFlux (2,0)
     |                                |
  💰 flows  ←───── coupling ─────→ 🌾 flows
     |                                |
  Market Bath                   BioticFlux Bath
```

**Pros:**
- ✅ True quantum coupling between biomes
- ✅ Energy/amplitude flow at boundaries
- ✅ Can model ecosystem flows (detritus → mushrooms)
- ✅ Preserves biome independence for interior plots
- ✅ Weak coupling (doesn't dominate evolution)

**Cons:**
- ❌ Complex state representation (qubit sees two baths)
- ❌ Need new measurement rules
- ❌ Computational overhead (more qubits to track)
- ❌ Doesn't support cross-biome entanglement (still local)

**When to Use:**
- Ecosystem modeling (Forest detritus → BioticFlux mushrooms)
- Resource transfer (Market wealth → Kitchen ingredients)
- Border effects (Market sentiment affecting nearby farms)

---

### Approach C: Shared Global Bath (Deep Stitching)

**Concept:** Merge all biome baths into a single global bath.

```
Before (4 independent baths):
  Market: [🐂 🐻 💰 📦 🏛️ 🏚️]
  BioticFlux: [☀ 🌙 🌾 🍄 💀 🍂]
  Forest: [22 emojis]
  Kitchen: [🔥 ❄️ 🍞 🌾]

After (1 global bath):
  Global: [☀ 🌙 🌾 🍄 💀 🍂 🐂 🐻 💰 📦 🏛️ 🏚️ 🔥 ❄️ 🍞 + Forest 22]
           ↑────────────────────────────────────────────────────────────────↑
                        38 emojis total (merging duplicates)
```

**Implementation:**

```gdscript
# Farm._ready():
func _initialize_global_bath():
    # Collect all unique emojis
    var all_emojis = []
    var emoji_set = {}

    for biome in [biotic_flux, market, forest, kitchen]:
        for emoji in biome.bath.emoji_list:
            if not emoji_set.has(emoji):
                all_emojis.append(emoji)
                emoji_set[emoji] = true

    # Create global bath
    global_bath = QuantumBath.new()
    global_bath.initialize_with_emojis(all_emojis)

    # Override all biome baths
    for biome in biomes.values():
        biome.bath = global_bath  # All share same bath!

    print("🌐 Global bath created: %d emojis" % all_emojis.size())
```

**Data Flow:**
```
All plots read from SAME bath:

Plot (0,0) Market → Projects {🐂, 🐻} ───┐
Plot (2,0) BioticFlux → Projects {🌾, 👥} ├──→ Global Bath (38 emojis)
Plot (0,1) Forest → Projects {🐺, 🐰} ────┤
Plot (4,1) Kitchen → Projects {🔥, ❄️} ───┘

Measure any plot → Collapses global bath → ALL plots affected!
```

**Pros:**
- ✅ True quantum entanglement across ALL biomes
- ✅ Any measurement cascades globally
- ✅ Natural emoji sharing (one copy of each emoji)
- ✅ Most physically realistic
- ✅ Simplest measurement logic (all plots see same bath)

**Cons:**
- ❌ Largest computational cost (38×38 Hamiltonian matrix)
- ❌ Loss of biome independence (measuring one biome affects all)
- ❌ All biomes must use compatible emoji spaces
- ❌ Breaking change (different evolution dynamics)
- ❌ Harder to save/load (one giant bath vs. 4 small ones)

**When to Use:**
- "Fully connected quantum world" game mode
- Small farms (computational cost manageable)
- Educational/demonstration mode (show global entanglement)

---

### Approach D: Emoji Router (Hybrid)

**Concept:** Keep biome baths separate but route resources through a shared dispatcher.

```
┌──────────────────────────────────────────────────┐
│            EmojiRouter (new system)              │
│  Routes: Forest 🍂 → BioticFlux 🍄               │
│          Market 💰 → Kitchen 🍞                   │
└──────────────────────────────────────────────────┘
         ↓                      ↓
   Forest Bath            BioticFlux Bath
   (🍂 drains)            (🍄 grows)
```

**Implementation:**

```gdscript
class EmojiRouter:
    var routes: Array[Dictionary] = []  # {from_biome, to_biome, emoji, rate}

    func add_route(from: String, to: String, emoji: String, rate: float):
        routes.append({
            "from_biome": from,
            "to_biome": to,
            "emoji": emoji,
            "transfer_rate": rate
        })

    func process_transfers(dt: float, biomes: Dictionary):
        for route in routes:
            var from_biome = biomes[route.from_biome]
            var to_biome = biomes[route.to_biome]
            var emoji = route.emoji
            var amount = route.transfer_rate * dt

            # Transfer amplitude
            if from_biome.bath.has_emoji(emoji) and to_biome.bath.has_emoji(emoji):
                var drained = from_biome.bath.drain_amplitude(emoji, amount)
                to_biome.bath.boost_amplitude(emoji, drained)

# Usage:
var router = EmojiRouter.new()
router.add_route("Forest", "BioticFlux", "🍂", 0.05)  # Detritus feeds mushrooms
router.add_route("Market", "Kitchen", "💰", 0.02)     # Wealth buys ingredients
router.add_route("BioticFlux", "Market", "🌾", 0.03)  # Wheat sold to market

# In _process:
router.process_transfers(delta, farm.biomes)
```

**Data Flow:**
```
Forest Bath (🍂 = 0.30)
    ↓ drain 0.05 * dt
EmojiRouter
    ↓ boost 0.05 * dt
BioticFlux Bath (🍄 grows from 🍂 input)
```

**Pros:**
- ✅ Keeps biome baths separate (performance)
- ✅ Allows resource flow between biomes
- ✅ Can model ecosystem flows (predator-prey across biomes)
- ✅ Natural fit for cross-biome resource transfers
- ✅ Easy to configure (add routes as needed)
- ✅ Can be saved/loaded (route config is simple)

**Cons:**
- ❌ No true quantum entanglement across biomes
- ❌ Limited to amplitude transfer (no phase coherence)
- ❌ Need to define routing rules manually
- ❌ Not physically realistic (classical routing)

**When to Use:**
- Economic simulation (trade between biomes)
- Ecosystem flows (Forest → Farm → Market → Kitchen)
- Resource conversion chains
- Gradual biome coupling (start simple, add routes)

---

## Part 3: Comparison Matrix

| Feature | Icon Coupling | Boundary Coupling | Global Bath | Emoji Router |
|---------|--------------|-------------------|-------------|--------------|
| **Complexity** | Low | Medium | High | Medium |
| **Performance** | Fast | Medium | Slow | Fast |
| **Quantum Coupling** | None | Weak | Full | None |
| **Entanglement** | ❌ | Boundary only | ✅ Global | ❌ |
| **Biome Independence** | ✅ | ✅ | ❌ | ✅ |
| **Resource Flow** | ❌ | ✅ | ✅ | ✅ |
| **Breaking Changes** | None | Few | Many | Few |
| **Save/Load Impact** | None | Minor | Major | Minor |
| **Scalability** | Excellent | Good | Poor (O(N²)) | Excellent |

---

## Part 4: Recommended Implementation Path

### Phase 1: Icon Coupling (Immediate - Non-Breaking)

**Implement now:**
1. Create `GlobalWeatherIcon` affecting BioticFlux + Forest
2. Create `MarketSentimentIcon` affecting Market + BioticFlux
3. Test with existing icon scoping system

**Benefits:**
- Zero breaking changes
- Uses existing infrastructure
- Adds cross-biome flavor immediately
- Reversible (can remove icons)

### Phase 2: Emoji Router (Short Term - Low Risk)

**Add after Phase 1:**
1. Implement `EmojiRouter` class
2. Add routes: Forest 🍂 → BioticFlux 🍄
3. Add routes: Market 💰 → Kitchen 🍞
4. Add to save/load system

**Benefits:**
- Resource flow between biomes
- Ecosystem modeling
- Easy to configure
- Minimal performance impact

### Phase 3: Boundary Coupling (Medium Term - Experimental)

**Prototype separately:**
1. Create `BoundaryQubit` class
2. Test on one boundary (Market/BioticFlux)
3. Measure performance impact
4. Add to visualization

**Benefits:**
- True quantum coupling at boundaries
- Energy flow
- Testable independently

### Phase 4: Global Bath (Long Term - Optional)

**Only if needed for game design:**
1. Add "global mode" toggle
2. Implement bath merging
3. Test with small farms first
4. Profile performance carefully

**Warning:** This is a major refactor. Only do if game design requires full global entanglement.

---

## Part 5: Technical Implementation Details

### Adding Cross-Biome Icon Coupling

**Step 1: Create GlobalWeatherIcon**

```gdscript
# Core/Icons/GlobalWeatherIcon.gd
class_name GlobalWeatherIcon
extends Icon

func _init():
    icon_name = "GlobalWeather"
    icon_emoji = "🌦️"
    activation_cost = {"💰": 5.0}

func compute_hamiltonian_element(emoji_a: String, emoji_b: String, context) -> Complex:
    var biome = context.get("biome", null)
    if not biome:
        return Complex.zero()

    # Sun → Wheat in BioticFlux
    if biome.get("name") == "BioticFlux":
        if emoji_a == "☀" and emoji_b == "🌾":
            return Complex.new(0.2 * active_strength, 0.0)

    # Sun → Herbivores in Forest
    elif biome.get("name") == "Forest":
        if emoji_a == "☀" and emoji_b == "🐰":
            return Complex.new(0.15 * active_strength, 0.0)

    # Sun → Bull sentiment in Market
    elif biome.get("name") == "Market":
        if emoji_a == "☀" and emoji_b == "🐂":
            return Complex.new(0.1 * active_strength, 0.0)

    return Complex.zero()
```

**Step 2: Register with Farm**

```gdscript
# Farm._ready():
var global_weather = GlobalWeatherIcon.new()
global_weather.set_activation(1.0)  # Always active
grid.add_scoped_icon(global_weather, ["BioticFlux", "Forest", "Market"])
```

**Result:** Sun now affects wheat, rabbits, and sentiment across three biomes!

---

### Adding Emoji Router

**Step 1: Create Router Class**

```gdscript
# Core/GameMechanics/EmojiRouter.gd
class_name EmojiRouter
extends RefCounted

var routes: Array[Dictionary] = []

func add_route(config: Dictionary):
    # config = {from_biome, to_biome, emoji, rate, [condition]}
    routes.append(config)

func process_transfers(dt: float, biomes: Dictionary):
    for route in routes:
        # Check condition (optional)
        if route.has("condition"):
            if not route.condition.call():
                continue

        var from_biome = biomes.get(route.from_biome)
        var to_biome = biomes.get(route.to_biome)

        if not from_biome or not to_biome:
            continue

        var emoji = route.emoji
        var amount = route.rate * dt

        # Check if both biomes have this emoji
        if not from_biome.bath.has_emoji(emoji):
            continue
        if not to_biome.bath.has_emoji(emoji):
            # Optional: inject emoji into target bath
            to_biome.bath.inject_emoji(emoji, null, Complex.zero())

        # Transfer amplitude
        var from_pop = from_biome.bath.get_population(emoji)
        var actual_drain = min(amount, from_pop * 0.5)  # Max 50% per frame

        from_biome.bath.drain_amplitude(emoji, actual_drain)
        to_biome.bath.boost_amplitude(emoji, actual_drain)
```

**Step 2: Add to Farm**

```gdscript
# Farm.gd:
var emoji_router: EmojiRouter

func _ready():
    # ... existing setup ...

    # Create router
    emoji_router = EmojiRouter.new()

    # Add routes
    emoji_router.add_route({
        "from_biome": "Forest",
        "to_biome": "BioticFlux",
        "emoji": "🍂",  # Detritus
        "rate": 0.05
    })

    emoji_router.add_route({
        "from_biome": "BioticFlux",
        "to_biome": "Market",
        "emoji": "🌾",  # Wheat
        "rate": 0.03,
        "condition": func(): return economy.get_resource("🌾") > 10  # Only if surplus
    })

func _process(delta):
    # ... existing evolution ...

    # Process transfers
    emoji_router.process_transfers(delta, {
        "BioticFlux": biotic_flux_biome,
        "Market": market_biome,
        "Forest": forest_biome,
        "Kitchen": kitchen_biome
    })
```

---

## Part 6: Visualization Implications

### Current: Biomes Render Separately

```
QuantumForceGraph:
  ├─ BioticFlux nodes (oval)
  ├─ Market nodes (oval)
  ├─ Forest nodes (oval)
  └─ Kitchen nodes (oval)
     (No connections between ovals)
```

### With Icon Coupling: Add Icon Nodes

```
QuantumForceGraph:
  ├─ BioticFlux nodes ─┐
  ├─ Market nodes ─────┼──→ GlobalWeather Icon (star)
  └─ Forest nodes ─────┘
```

### With Emoji Router: Add Flow Edges

```
QuantumForceGraph:
  Forest (🍂) ───flow arrow──→ BioticFlux (🍄)
  BioticFlux (🌾) ───flow arrow──→ Market (💰)
```

### With Boundary Coupling: Add Boundary Nodes

```
QuantumForceGraph:
  Market oval ← [Boundary Qubit] → BioticFlux oval
```

---

## Conclusion

**Current State:** Biomes are completely isolated quantum systems - intentional design for modularity and performance.

**Recommended Path:**
1. **Start with Icon Coupling** - Add cross-biome icons (GlobalWeather, MarketSentiment)
2. **Add Emoji Router** - Model resource flows (Forest → Farm → Market)
3. **Experiment with Boundary Coupling** - Test weak quantum coupling
4. **Consider Global Bath** - Only if game design requires full entanglement

**Key Insight:** The architecture supports multiple stitching modes through different mechanisms. Choose based on game design needs, not technical constraints.

---

## Next Steps

What type of biome stitching would you like to implement first?

- **A) Icon Coupling** - Simplest, adds flavor, non-breaking
- **B) Emoji Router** - Resource flows, ecosystem modeling
- **C) Boundary Coupling** - Quantum coupling at edges
- **D) Global Bath** - Full entanglement (major refactor)

Or continue exploring the architecture to understand implications better?
