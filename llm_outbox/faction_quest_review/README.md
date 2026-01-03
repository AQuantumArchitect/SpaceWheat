# Faction Quest System Review

This folder contains all the faction data and quest generation algorithms for review.

---

## Files Overview

### 1. **FactionDatabase.gd** (18KB)
The complete database of all 32 factions with their 12-bit encodings.

**Current distribution**:
- **12 Material factions (37.5%)**: Physical/mechanical/bureaucratic
- **20 Mystical factions (62.5%)**: Consciousness/ethereal/supernatural

**Structure**:
```gdscript
const FACTION_NAME = {
    "name": "Faction Name",
    "emoji": "🏭⚙️🔧",
    "bits": [1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1],  // 12-bit encoding
    "category": "Category Name",
    "description": "Short description"
}
```

### 2. **FactionStateMatcher.gd** (21KB)
The quantum-native quest generation algorithm.

**Key functions**:
- `calculate_operator_weights(faction_bits)` - Converts faction bits to quest type weights
- `extract_observables(bath)` - Extracts quantum observables from biome state
- `compute_alignment(faction_bits, observables)` - Calculates faction-biome alignment
- `_generate_amplitude_operator()` - Creates amplitude quest operators
- `_generate_coherence_operator()` - Creates coherence quest operators
- `_generate_ratio_operator()` - Creates ratio quest operators

**Core formula** (quantum parametric, NO if/then):
```gdscript
# Material(0) × Direct(0) × Monochrome(0) → amplitude quest
var w_amplitude = (1.0 - material_mystical) * (1.0 - direct_subtle) * (1.0 - mono_prismatic)

# Mystical(1) × Direct(0) × Monochrome(0) → coherence quest
var w_coherence = material_mystical * (1.0 - direct_subtle) * (1.0 - mono_prismatic)

# Subtle(1) × Monochrome(0) → ratio quest
var w_ratio = direct_subtle * (1.0 - mono_prismatic)

# Prismatic(1) × Direct(0) → multi-observable quest
var w_multi = mono_prismatic * (1.0 - direct_subtle)
```

### 3. **QuestTypes.gd** (1.9KB)
Quest type definitions and utility functions.

**Quest types**:
- `DELIVERY` - Classic resource delivery (legacy)
- `SHAPE_ACHIEVE` - Reach target observable once
- `SHAPE_MAINTAIN` - Hold target observable for duration
- `EVOLUTION` - Change observable by delta
- `ENTANGLEMENT` - Create quantum coherence

### 4. **faction_classification_reference.txt** (15KB)
Reference document with all 32 factions decoded.

**Format for each faction**:
```
### Faction Name 🏭⚙️🔧
Description text
**Axiom words**: Deterministic, Material, Common, Cosmic, ...
**Pattern**: `110111000011`
**Bits array**: [1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1]
```

### 5. **faction_encoding_analysis.md** (9.5KB)
Deep analysis of faction bit encodings with examples.

**Includes**:
- Semantic analysis of each bit position
- Example faction encodings with explanations
- Measurement operator formulas
- Quest weight calculations for specific factions

### 6. **quantum_quest_operators_COMPLETE.md** (12KB)
Complete implementation summary and design decisions.

**Covers**:
- Why quantum-native (no if/then conditionals)
- Float-ready architecture (accepts 0.0-1.0, not just 0/1)
- Born rule sampling
- Test results
- Future expansion plans

---

## The 12-Bit Encoding

Each faction has 12 bits encoding preferences:

```
[0]: Random(0) ↔ Deterministic(1)
[1]: Material(0) ↔ Mystical(1) - DIAGONAL VS OFF-DIAGONAL OPERATORS
[2]: Common(0) ↔ Elite(1)
[3]: Local(0) ↔ Cosmic(1)
[4]: Instant(0) ↔ Eternal(1)
[5]: Physical(0) ↔ Mental(1)
[6]: Crystalline(0) ↔ Fluid(1)
[7]: Direct(0) ↔ Subtle(1) - ABSOLUTE VS RATIO QUESTS
[8]: Consumptive(0) ↔ Providing(1)
[9]: Monochrome(0) ↔ Prismatic(1) - SINGLE VS MULTI EMOJI
[10]: Emergent(0) ↔ Imposed(1)
[11]: Scattered(0) ↔ Focused(1) - OPERATOR SELECTIVITY
```

**Critical bits for quest generation**:
- **bit[1]**: Material/Mystical - distinguishes amplitude (diagonal) vs coherence (off-diagonal)
- **bit[7]**: Direct/Subtle - distinguishes absolute vs ratio measurements
- **bit[9]**: Monochrome/Prismatic - distinguishes single vs multi-emoji quests
- **bit[11]**: Scattered/Focused - controls operator selectivity (peaked vs uniform)

---

## Quest Type Examples

### Amplitude Quest (Material + Direct + Monochrome)
**Faction**: Obsidian Will 🏭⚙️🔧
**Bits**: `[1, 0, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1]`
**Quest**: "Cultivate 🌾 to 80% probability"
**Measures**: Diagonal element ρ₀₀ (single emoji population)

### Coherence Quest (Mystical + Direct + Monochrome)
**Faction**: Iron Shepherds 🛡️🐑🚀
**Bits**: `[1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 1, 1]`
**Quest**: "Create entanglement between 🌾 and 🍄"
**Measures**: Off-diagonal element |ρ₀₁|² (quantum coherence)

### Ratio Quest (Material + Subtle)
**Faction**: Granary Guilds 🌾💰⚖️
**Bits**: `[1, 0, 0, 1, 1, 1, 0, 1, 1, 0, 1, 1]`
**Quest**: "Make 🌾 probability twice 🍄 probability"
**Measures**: ρ₀₀/ρ₁₁ = 2.0 (ratio of populations)

### Multi-Observable Quest (Prismatic + Direct)
**Faction**: Symphony Smiths 🎵🔨⚔️
**Bits**: `[1, 1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 1]`
**Quest**: "Balance 🌾, 🍄, and 💨 equally"
**Measures**: Multiple diagonal elements simultaneously

---

## Material vs Mystical Factions

### Material Factions (12 total - 37.5%)

**Imperial Powers** (3):
- 👑💀🏛️ Carrion Throne - Bureaucracy
- 🌾💰⚖️ Granary Guilds - Food control (note: has Subtle bit → ratio quests!)
- 🏢👑🌌 Station Lords - City control

**Working Guilds** (2):
- 🏭⚙️🔧 Obsidian Will - Mechanical purists
- 🔧🛠️🚐 Tinker Team - Repair work

**Merchants** (1):
- 🦴💉🛒 Bone Merchants - Physical surgeries

**Militant Orders** (2):
- ⚔️⚰️⚫️ Brotherhood of Ash - Physical mercenaries
- 🔥✊⚡️ Children of the Ember - Physical revolution

**Scavengers** (2):
- 🚢🦴⚙️ Rust Fleet - Mechanical scavenging
- 🦗🍃💀 Locusts - Physical consumption

**Defensive Communities** (2):
- 🌱🏡🛡️ Clan of the Hidden Root - Physical farming
- 🌿🏠🔒 Terrarium Collective - Physical construction

### Mystical Factions (20 total - 62.5%)

**Imperial Powers** (1):
- 🌹🗡️👑 House of Thorns - Poison/alchemy (Subtle → ratio quests!)

**Working Guilds** (4):
- 🌾⚙️🏭 Millwright's Union - "Know cosmic rhythms through mill vibrations"
- 🪡👘📐 Seamstress Syndicate - Message encoding (subtle patterns)
- ⚰️🪦🌙 Gravedigger's Union - Death ritualists
- 🎵🔨⚔️ Symphony Smiths - "Reality-tuning tools from crystallized sound"

**Mystic Orders** (4):
- 🧘‍♂️⚔️🔇 Keepers of Silence
- 🕯️🔥⛪ Sacred Flame Keepers
- 🤖⛪🔧 Iron Confessors
- 🍞🧪⛪ Yeast Prophets

**Merchants & Traders** (3):
- 💎⚖️🛸 Syndicate of Glass - "Hyperspace artifacts"
- 🧠💰📦 Memory Merchants - Consciousness traders
- 🍺🗝️🕯️ Nexus Wardens - Diplomatic mysticism

**Militant Orders** (2):
- 🛡️🐑🚀 Iron Shepherds - "Living cathedral ships"
- ⚖️🐉🩸 Order of the Crimson Scale - Judicial mysticism

**Scavengers** (1):
- 🗺️🔭🚢 Cartographers - "Explorer-mystics charting hyperspace"

**Horror Cults** (4):
- 🎪💀🌀 Laughing Court
- 🌊⭐️👁️ Cult of the Drowned Star
- 🎶💀🌀 Chorus of Oblivion
- 🧬🏗️👥 Flesh Architects

**Defensive Communities** (2):
- 🌾⛓️🌌 Void Serfs - "Kept docile through religious fervor"
- 🔮👤🌑 Veiled Sisters - Shadow network

**Cosmic Manipulators** (3):
- 💃🎼🌟 Resonance Dancers
- 🐑🎲⚡ Causal Shepherds
- 🐑🌍🤠 Empire Shepherds

**Ultimate Cosmic Entities** (3):
- 🌌💀🌸 Entropy Shepherds
- 👑🌌⚫ Void Emperors
- 🌟💫🥚 Reality Midwives

---

## Key Questions for Review

1. **Material/Mystical balance**: Is 37.5% Material / 62.5% Mystical a good distribution?

2. **Faction encoding accuracy**: Do the bit encodings match faction personalities?
   - Example: Granary Guilds has Subtle bit → ratio quests (food price ratios) - does this make sense?
   - Example: House of Thorns has Mystical + Subtle → ratio quests (poison dosage ratios) - does this make sense?

3. **Quest type variety**: Does each faction category get interesting quest diversity?
   - Imperial Powers: Mix of amplitude + ratio
   - Working Guilds: Mostly amplitude (physical work)
   - Mystic Orders: Coherence + ratio (relationships)
   - Horror Cults: All mystical, varied quest types

4. **Missing factions**: Should any other factions be Material?
   - Syndicate of Glass? (Crystal trade, but "hyperspace artifacts" sounds mystical)
   - Symphony Smiths? (Forging tools, but "reality-tuning" sounds mystical)
   - Iron Shepherds? ("Living cathedral ships" sounds mystical)

5. **Bit semantics**: Are there better interpretations of specific bits?
   - Currently bit[1] Material/Mystical determines diagonal vs off-diagonal operators
   - Currently bit[7] Direct/Subtle determines absolute vs ratio
   - Are these mappings intuitive?

---

## Testing the System

To test quest generation for a specific faction:

```gdscript
# Get faction
var faction = FactionDatabase.OBSIDIAN_WILL

# Calculate operator weights
var weights = FactionStateMatcher.calculate_operator_weights(faction.bits)
print("Amplitude: %.2f" % weights.amplitude)  # 1.00 for Material + Direct + Mono
print("Coherence: %.2f" % weights.coherence)  # 0.00
print("Ratio: %.2f" % weights.ratio)          # 0.00
print("Multi: %.2f" % weights.multi)          # 0.00

# Sample quest structure from probability distribution
var quest_type = FactionStateMatcher.sample_operator_structure(weights)
# Returns: "amplitude" (Born rule sampling from weights)
```

The system is **quantum parametric** - no if/then conditionals, just continuous multiplication of bit preferences!
