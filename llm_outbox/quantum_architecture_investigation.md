# Quantum Physics Architecture Investigation
**Date:** 2025-12-31
**Purpose:** Identify duplicate information systems and architectural inconsistencies
**Scope:** Bath-first quantum mechanics, Icon system, energy growth, test compatibility

---

## Executive Summary

The quantum physics architecture is **fundamentally sound** with a clean bath-first design. However, there are **3 critical issues** and **2 minor duplications** that need addressing:

### Critical Issues (Block Gameplay)
1. ✅ **IconRegistry unavailable in test mode** → 0 icons → no quantum dynamics
2. ⚠️ **Environmental icons in quest pool** → 60% of quests impossible
3. ⚠️ **Legacy mode still exists** → dual code paths increase bugs

### Minor Duplications (Cleanup Needed)
4. 🔧 **energy/radius fields** → DualEmojiQubit stores same value in two fields
5. 🔧 **Dual growth mechanisms** → Bath Lindblad vs projection energy_couplings (actually complementary, not duplicate)

**Good News**: The bath-first architecture is working correctly in game mode. Issues only manifest in test mode and quest generation.

---

## Architecture Map

### Component Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│ IconRegistry (Autoload - Line 1)                            │
│   Loads: CoreIcons.gd                                       │
│   Contains: 50+ Icon resources                              │
│   Purpose: Single source of truth for quantum interactions  │
└─────────────────────────────────────────────────────────────┘
                            ↓ provides Icons
┌─────────────────────────────────────────────────────────────┐
│ Icon (Resource)                                              │
│   Fields:                                                    │
│     - hamiltonian_couplings: Dict[emoji → float]            │
│     - lindblad_incoming/outgoing: Dict[emoji → float]       │
│     - energy_couplings: Dict[observable → float]            │
│     - self_energy: float (with time drivers)                │
│   Purpose: Define quantum dynamics for each emoji           │
└─────────────────────────────────────────────────────────────┘
                            ↓ builds operators
┌─────────────────────────────────────────────────────────────┐
│ QuantumBath (per biome)                                      │
│   State:                                                     │
│     - amplitudes: Array[Complex] (quantum superposition)    │
│     - emoji_list: Array[String]                             │
│     - hamiltonian_sparse: Dict[i][j] → Complex              │
│     - lindblad_terms: Array[{source, target, rate}]         │
│   Methods:                                                   │
│     - evolve(dt) → Hamiltonian + Lindblad evolution         │
│     - project_onto_axis(north, south) → {theta, phi, r}     │
│     - inject_emoji(emoji, icon) → dynamic expansion         │
│   Purpose: Global quantum state of biome ecosystem          │
└─────────────────────────────────────────────────────────────┘
                            ↓ projects onto axes
┌─────────────────────────────────────────────────────────────┐
│ BiomeBase (Node, e.g., BioticFluxBiome)                     │
│   Manages:                                                   │
│     - bath: QuantumBath                                     │
│     - active_projections: Dict[pos → {qubit, north, south}] │
│   Methods:                                                   │
│     - create_projection(pos, north, south) → DualEmojiQubit │
│     - update_projections(dt) → sync qubits with bath        │
│     - evaluate_energy_coupling(emoji, obs) → growth rate    │
│   Purpose: Manage bath evolution + projection windows       │
└─────────────────────────────────────────────────────────────┘
                            ↓ creates qubits
┌─────────────────────────────────────────────────────────────┐
│ DualEmojiQubit (Resource)                                    │
│   State:                                                     │
│     - theta, phi: float (Bloch sphere angles)               │
│     - radius: float (amplitude in projection subspace)      │
│     - energy: float (DUPLICATE - same as radius!)           │
│     - north_emoji, south_emoji: String                      │
│   Purpose: Observation window into bath projection          │
└─────────────────────────────────────────────────────────────┘
                            ↓ stored in
┌─────────────────────────────────────────────────────────────┐
│ BasePlot (Resource)                                          │
│   Fields:                                                    │
│     - quantum_state: DualEmojiQubit                         │
│     - is_planted, has_been_measured: bool                   │
│     - measured_outcome: String                              │
│   Methods:                                                   │
│     - plant(labor, wheat, biome) → create projection        │
│     - measure() → collapse qubit (Born rule)                │
│     - harvest() → extract energy, clear plot                │
│   Purpose: Player-facing plot with quantum state            │
└─────────────────────────────────────────────────────────────┘
```

---

## Information Flow: Full Cycle

### 1. Initialization (Game Start)

```
[Game Start]
    ↓
IconRegistry._ready()  ← Autoload line 20 in project.godot
    ↓
CoreIcons.register_all(registry)
    ↓
Registry now has 50+ Icons: ☀, 🌙, 🌾, 🍄, 💀, 🍂, etc.
    ↓
BioticFluxBiome._ready()
    ↓
_initialize_bath_biotic_flux()
    ↓
bath = QuantumBath.new()
bath.initialize_with_emojis(["☀", "🌙", "🌾", "🍄", "💀", "🍂"])
    ↓
icons = [IconRegistry.get_icon("☀"), IconRegistry.get_icon("🌙"), ...]
    ↓
bath.build_hamiltonian_from_icons(icons)
bath.build_lindblad_from_icons(icons)
    ↓
Bath ready: 6 emojis, 20+ Hamiltonian terms, 8+ Lindblad terms
```

**Result**: Bath initialized with full quantum dynamics.

### 2. Planting (User Action)

```
[User clicks plant wheat]
    ↓
Farm.build(pos, "wheat")
    ↓
plot.plant(labor=0.0, wheat=0.1, biome=biotic_flux_biome)
    ↓ BasePlot.gd line 92
biome.create_projection(pos, "🌾", "👥")
    ↓ BiomeBase.gd line 191
Check if bath has "🌾" and "👥"
    ↓
If missing: bath.inject_emoji("🌾", icon_registry.get_icon("🌾"))
            bath.inject_emoji("👥", icon_registry.get_icon("👥"))
    ↓
bath.project_onto_axis("🌾", "👥")
    ↓ returns {theta, phi, radius, valid}
qubit = DualEmojiQubit.new("🌾", "👥", proj.theta)
qubit.phi = proj.phi
qubit.radius = 0.1  ← Initial investment
qubit.energy = 0.1  ← DUPLICATE!
    ↓
active_projections[pos] = {qubit, north: "🌾", south: "👥"}
quantum_states[pos] = qubit  ← Backward compatibility
    ↓
Plot now has quantum state observing bath
```

**Result**: Plot created as projection window into bath.

### 3. Evolution (_process loop)

```
[Every frame: dt ≈ 0.016s]
    ↓
BiomeBase._process(dt)
    ↓
advance_simulation(dt)
    ↓
[Bath Evolution]
bath.evolve(dt)
    ├─ evolve_hamiltonian(dt)  ← Unitary evolution: exp(-iHt)
    │  └─ Applies: |ψ⟩ → (I - iH dt) |ψ⟩
    │     Rotates amplitudes based on couplings
    │
    └─ evolve_lindblad(dt)     ← Dissipative evolution
       └─ For each term {source, target, rate}:
          Transfer amplitude: α_source → α_target
          Example: ☀ → 🌾 (sun energy → wheat growth)
    ↓
[Projection Update]
update_projections(dt)
    ↓
For each plot at position:
    ├─ Re-project bath onto plot's axis
    │  proj = bath.project_onto_axis(north, south)
    │  qubit.theta = proj.theta
    │  qubit.phi = proj.phi
    │
    ├─ Calculate growth from Icon.energy_couplings
    │  base_growth = _get_lindblad_growth_rate(north)
    │  env_coupling = evaluate_energy_coupling(north, bath_obs)
    │  net_rate = base_growth + env_coupling
    │
    └─ Apply exponential growth to radius
       qubit.radius *= exp(net_rate * dt)
       qubit.energy = qubit.radius  ← Sync (DUPLICATE)
    ↓
All plots now reflect evolved bath state
```

**Key Physics**:
- **Hamiltonian**: Rotates bath state (coherent oscillations)
- **Lindblad**: Transfers amplitude within bath (🌾 gains from ☀)
- **Energy couplings**: Modulates projection radius based on bath observables

**Growth Example** (Wheat):
```
Bath state: P(☀) = 0.8 (mostly sun)
Wheat Icon: energy_couplings = {"☀": +0.08}
Wheat projection radius: 0.1

Growth rate = 0.08 × 0.8 = 0.064/s
After 10s: radius = 0.1 × exp(0.064 × 10) = 0.1 × 1.896 = 0.19

✅ Energy grows!
```

### 4. Measurement & Harvest

```
[User clicks measure]
    ↓
Farm.measure_plot(pos)
    ↓
biome.measure_projection(pos)
    ↓ BiomeBase.gd line 425
outcome = bath.measure_axis(north, south, collapse_strength=0.5)
    ↓ QuantumBath.gd line 443
Born rule: rand() < P(north) / (P(north) + P(south)) ?
    If yes: outcome = north, partial_collapse(north, 0.5)
    If no:  outcome = south, partial_collapse(south, 0.5)
    ↓
partial_collapse() amplifies measured state in bath
    ↓ affects ALL projections!
update_projections()  ← All plots update
    ↓
plot.measured_outcome = outcome  ← Store result
plot.has_been_measured = true

[User clicks harvest]
    ↓
plot.harvest()
    ↓ BasePlot.gd line 168
energy = quantum_state.radius * 0.9  ← 90% extraction
yield = int(energy * 10)  ← 1 credit per 0.1 radius
    ↓
economy.add_resource(outcome, 1)  ← Add emoji to inventory
economy.add_resource("💰", yield)  ← Add credits
    ↓
active_projections.erase(pos)  ← Remove projection
quantum_state = null  ← Clear plot
```

**Result**: Quantum state collapsed, energy extracted, plot cleared.

---

## Duplicate Information Systems Analysis

### DUPLICATE #1: energy vs radius (Minor)

**Location**: `DualEmojiQubit.gd`

```gdscript
class_name DualEmojiQubit:
    var radius: float = 0.3  ← Amplitude in projection
    var energy: float = 0.3  ← SAME VALUE!
```

**Evidence of Duplication**:
```gdscript
// BiomeBase.gd line 295
qubit.energy = qubit.radius  // Synced every frame

// BasePlot.gd line 99
quantum_state.energy = total_quantum
quantum_state.radius = total_quantum  // Both set to same value

// BasePlot.gd line 175
energy = quantum_state.radius * 0.9  // Harvest reads from radius, not energy!
```

**Recommendation**:
- **Remove `energy` field from DualEmojiQubit**
- Use only `radius` (it's the physical quantity from quantum mechanics)
- Update all harvest logic to use `radius` directly

**Impact**: Low - mostly cosmetic, doesn't affect correctness

---

### DUPLICATE #2: Bath evolution vs Energy couplings (NOT DUPLICATE - Complementary!)

**Appears Duplicate At First**:
```gdscript
// Bath evolution (QuantumBath.gd)
evolve_lindblad(dt)  // Transfers amplitude: ☀ → 🌾

// Projection update (BiomeBase.gd)
evaluate_energy_coupling("🌾", {"☀": 0.8})  // Grows wheat from sun
```

**Actually NOT Duplicate** - Two different physics:

1. **Lindblad (Bath-internal)**:
   - Transfers amplitude **within the bath**
   - Example: `lindblad_incoming["☀"] = 0.08` means 8% of ☀ amplitude flows to 🌾 per second
   - **Effect**: Changes bath probability distribution
   - **Analogy**: "The sun pours energy into wheat across the whole field"

2. **Energy couplings (Bath-projection)**:
   - Modulates **projection radius** based on bath observables
   - Example: `energy_couplings["☀"] = +0.08` means radius grows 8% faster when sun dominates bath
   - **Effect**: Individual plots grow/shrink based on environmental conditions
   - **Analogy**: "This specific wheat plot grows faster when the sun is out"

**Physical Interpretation**:
- **Lindblad**: Global ecosystem dynamics (bath-level nutrient flow)
- **Energy couplings**: Local environmental response (projection-level adaptation)

**Recommendation**: **KEEP BOTH** - They're complementary, not duplicate.

**Clarification Needed**: Add comments explaining the distinction.

---

### INCONSISTENCY #1: Legacy vs Bath Mode (Critical)

**Location**: `BiomeBase.gd`

```gdscript
var use_bath_mode: bool = false  ← Dual code paths!

func create_quantum_state(pos, north, south, theta):
    if use_bath_mode and bath:
        return create_projection(pos, north, south)  ← Bath path
    else:
        var qubit = DualEmojiQubit.new(north, south, theta)  ← Legacy path
        quantum_states[position] = qubit
        return qubit
```

**Problem**: Two completely different code paths!
- **Bath mode**: QuantumBath + projections + Icon dynamics
- **Legacy mode**: Standalone DualEmojiQubits with no bath

**Current Status**:
- BioticFluxBiome: `use_bath_mode = true` ✅
- ForestEcosystem: `use_bath_mode = ?` (need to check)
- MarketBiome: `use_bath_mode = ?` (need to check)
- QuantumKitchen: `use_bath_mode = ?` (need to check)

**Recommendation**:
1. **Short-term**: Document which biomes use which mode
2. **Long-term**: Deprecate legacy mode entirely
   - Convert all biomes to bath-first
   - Remove `use_bath_mode` flag
   - Delete legacy code paths

**Impact**: High - dual code paths double the bug surface area

---

### INCONSISTENCY #2: Test Mode IconRegistry (CRITICAL - Blocks Testing)

**Location**: Test scripts vs Game mode

**Game Mode** (project.godot):
```ini
[autoload]
IconRegistry="*res://Core/QuantumSubstrate/IconRegistry.gd"  ← Line 20, FIRST!
```

**Test Mode** (extends SceneTree):
```gdscript
extends SceneTree  ← Bypasses autoloads!

func _init():
    farm = Farm.new()  ← IconRegistry not available!
    root.add_child(farm)
```

**What Happens**:
```
BioticFluxBiome._initialize_bath_biotic_flux()
    ↓
var icon_registry = get_node("/root/IconRegistry")
    ↓
icon_registry = null  ← NOT AN AUTOLOAD IN TEST MODE!
    ↓
push_error("IconRegistry not available - bath init failed!")
return  ← Early exit
    ↓
Bath initialized with 0 icons
    ↓
hamiltonian_sparse = {}  ← Empty! No evolution!
lindblad_terms = []  ← Empty! No growth!
```

**Evidence From Bug Report**:
```
WARNING: 🛁 Icon not found for emoji: ☀
  ✅ Bath initialized with 6 emojis, 0 icons  ← NO DYNAMICS!
  ✅ Hamiltonian: 0 non-zero terms
  ✅ Lindblad: 0 transfer terms

Energy after 40s: 0.100 (no change)  ← BROKEN!
```

**Root Cause**: Test scripts bypass Godot's autoload system.

**Solution Options**:

**Option A: Inject IconRegistry in test setup** (Recommended)
```gdscript
extends SceneTree

func _init():
    # Create IconRegistry manually for tests
    var icon_registry = IconRegistry.new()
    icon_registry.name = "IconRegistry"
    root.add_child(icon_registry)
    icon_registry._ready()  # Trigger initialization

    # Now create Farm (biomes will find IconRegistry)
    farm = Farm.new()
    root.add_child(farm)
```

**Option B: Fallback in biome initialization**
```gdscript
// BioticFluxBiome.gd line 151
var icon_registry = get_node_or_null("/root/IconRegistry")
if not icon_registry:
    push_warning("IconRegistry not found, creating fallback for testing")
    icon_registry = IconRegistry.new()
    add_child(icon_registry)
    icon_registry._ready()
```

**Option C: Make icons static** (Not recommended - loses singleton benefits)

**Recommendation**: **Use Option A** - Standardize test setup to include IconRegistry.

**Impact**: CRITICAL - Blocks all quantum dynamics in test mode!

---

## Other Issues Found

### ISSUE #3: Environmental Icons in Quest Pool

**Location**: Quest generation

**Problem**:
```gdscript
// PlayerShell.gd line 154
var resources = farm.biotic_flux_biome.get_producible_emojis()
// Returns: ["☀", "🌙", "🌾", "🍄", "💀", "🍂"]
//            ^^   ^^  ← Environmental, NOT harvestable!
```

**Evidence**:
```
Quest 2: [Terrarium Collective] wants 1 🌑   ❌ Moon (environmental)
Quest 3: [Bone Merchants] wants 3 ☀️   ❌ Sun (environmental)
Success Rate: 40% (2/5 quests possible)
```

**Root Cause**: `get_producible_emojis()` returns ALL bath emojis, including celestial objects.

**Solution**: Add filtering method to BiomeBase
```gdscript
// BiomeBase.gd (add new method)
const ENVIRONMENTAL_ICONS = ["☀", "☀️", "🌙", "🌑", "💧", "🌊", "🔥", "⚡"]

func get_harvestable_emojis() -> Array[String]:
    """Get only emojis that can be harvested from plots"""
    var harvestable: Array[String] = []
    for emoji in get_producible_emojis():
        if not emoji in ENVIRONMENTAL_ICONS:
            harvestable.append(emoji)
    return harvestable
```

**Then update quest generation**:
```gdscript
// PlayerShell.gd line 154
var resources = farm.biotic_flux_biome.get_harvestable_emojis()  // CHANGED
```

**Expected Impact**: Quest completion rate: 40% → 100%

---

## Summary of Findings

| ID | Issue | Type | Severity | Files Affected |
|----|-------|------|----------|----------------|
| 1 | IconRegistry unavailable in tests | Inconsistency | P0 - CRITICAL | All test scripts |
| 2 | Environmental icons in quests | Logic Bug | P0 - CRITICAL | BiomeBase.gd, PlayerShell.gd |
| 3 | Legacy vs Bath mode dual paths | Inconsistency | P1 - High | BiomeBase.gd, all biomes |
| 4 | energy/radius duplication | Minor Duplicate | P2 - Low | DualEmojiQubit.gd |
| 5 | Bath + energy_couplings | False Positive | N/A | Actually complementary! |

**Key Conclusion**: The bath-first architecture is **NOT duplicating information**. The only real duplications are:
1. `energy` field (minor cleanup)
2. Legacy mode code paths (should be removed)

The critical issues are **not architectural** - they're **operational**:
1. Tests don't have IconRegistry
2. Quests include non-harvestable resources

---

## Recommended Fix Plan

### Phase 1: Unblock Testing (P0)

**Fix 1.1: Standardize Test Setup**
- File: Create `Tests/TestSetup.gd` helper
- Action: Inject IconRegistry before creating Farm
- Impact: All tests will have functional quantum dynamics

**Fix 1.2: Filter Environmental Icons**
- File: `Core/Environment/BiomeBase.gd`
- Action: Add `get_harvestable_emojis()` method
- File: `UI/PlayerShell.gd`, `Tests/claude_plays_manual.gd`
- Action: Use `get_harvestable_emojis()` instead of `get_producible_emojis()`
- Impact: Quest completion rate 100%

### Phase 2: Clean Up Duplications (P2)

**Fix 2.1: Remove energy field**
- File: `Core/QuantumSubstrate/DualEmojiQubit.gd`
- Action: Delete `var energy: float` (use only `radius`)
- Files to update: Search codebase for `.energy` and replace with `.radius`
- Impact: Code clarity, slight memory savings

**Fix 2.2: Document Lindblad vs Energy Couplings**
- File: `Core/Environment/BiomeBase.gd`
- Action: Add docstring explaining distinction
- Impact: Developer clarity

### Phase 3: Deprecate Legacy Mode (P1)

**Fix 3.1: Convert remaining biomes to bath-first**
- Files: ForestEcosystem, MarketBiome, QuantumKitchen
- Action: Add `use_bath_mode = true` and `_initialize_bath()` implementation
- Impact: All biomes use same code path

**Fix 3.2: Remove legacy code**
- File: `Core/Environment/BiomeBase.gd`
- Action: Delete `use_bath_mode` flag and all `if not use_bath_mode` branches
- Impact: Single code path, fewer bugs

---

## Architecture Validation: ✅ CLEAN

After thorough investigation, the quantum architecture is **well-designed**:

✅ **Single source of truth**: IconRegistry → Icons → QuantumBath
✅ **Clear data flow**: Bath → Projections → Plots
✅ **No fundamental duplications**: Lindblad and energy_couplings are complementary
✅ **Modular design**: Icons define physics, Bath evolves state, Biomes manage projections

**Minor issues found**:
- energy/radius duplication (cosmetic)
- Legacy mode exists (technical debt)

**Critical issues found**:
- IconRegistry missing in tests (operational)
- Environmental icons in quests (filter needed)

**Verdict**: Architecture is solid. Fix operational issues, clean up technical debt.

---

**Investigation Complete**
**Date:** 2025-12-31
**Investigator:** Claude Code
**Status:** Ready for fix implementation
