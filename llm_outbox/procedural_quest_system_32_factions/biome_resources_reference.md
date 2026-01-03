# Biome Resources Reference
## Available Emojis in Each SpaceWheat Biome

This document lists the actual emoji resources available in each biome, extracted from the game code. These emojis determine which faction quests can spawn in which biomes.

---

## BioticFlux Biome
**Keyboard Keys**: UIOP
**File**: `Core/Environment/BioticFluxBiome.gd`

### Emoji Pairings (Quantum Superpositions)
```gdscript
register_emoji_pair("🌾", "👥")  # Wheat ↔ People (agrarian/imperium axis)
register_emoji_pair("🍄", "🍂")  # Mushroom ↔ Autumn leaves (moon-influenced)
register_emoji_pair("☀️", "🌑")  # Sun ↔ Moon (celestial oscillator)
```

### Available Resources
- 🌾 **Wheat** (plantable, north pole, day-aligned)
- 👥 **Labor/People** (plantable, south pole, agrarian axis)
- 🍄 **Mushroom** (plantable, moon-aligned, night growth)
- 🍂 **Detritus** (decay, autumn leaves, moon phase)
- ☀️ **Sun** (celestial, immutable, drives cycle)
- 🌑 **Moon** (celestial, immutable, night phase)

### Mechanics
- **Day-Night Cycle**: 20-second sun-moon period
- **Wheat Growth**: Absorbs energy from ☀️ sun (daytime)
- **Mushroom Growth**: Absorbs energy from 🌑 moon (nighttime)
- **Sun Damage**: Mushrooms lose energy during day
- **Temperature**: 300K baseline, peaks at 400K (noon/midnight)

### Faction Matches
- ✅ Millwright's Union (needs 🌾)
- ✅ Void Serfs (wheat farming)
- ✅ Clan of Hidden Root (defensive agriculture)
- ✅ Children of the Ember (revolutionary wheat)
- ✅ Gravedigger's Union (🌑 moon rituals)

---

## Kitchen Biome (Quantum Kitchen)
**Keyboard Keys**: JKL;
**File**: `Core/Environment/QuantumKitchen_Biome.gd`

### Emoji Pairings (Quantum Superpositions)
```gdscript
register_emoji_pair("🔥", "❄️")  # Fire ↔ Ice (thermal duality)
```

### Producible Resources
```gdscript
register_resource("🍞", true, false)  # Bread (producible, not consumable)
```

### Available Resources
- 🔥 **Fire** (heat, fermentation catalyst)
- ❄️ **Ice** (cold, preservation)
- 🍞 **Bread** (produced from 🌾 + 🔥 alchemy)

### Mechanics
- **Fire-Ice Alchemy**: Thermal superposition states
- **Bread Production**: Requires wheat + fire transformation
- **Fermentation**: Time-dependent quantum evolution

### Faction Matches
- ✅ Yeast Prophets (🍞 fermentation mysticism)
- ✅ Sacred Flame Keepers (🔥 eternal fire)
- ✅ Iron Confessors (🔥 machine-soul rites)
- ✅ Granary Guilds (🍞 bread distribution)

---

## Forest Ecosystem Biome
**Keyboard Keys**: 7890
**File**: `Core/Environment/ForestEcosystem_Biome.gd`

### Weather Qubits
```gdscript
weather_qubit: DualEmojiQubit  # (🌬️ wind, 💧 water)
season_qubit: DualEmojiQubit   # (☀️ sun, 🌧️ rain)
```

### Ecological Succession
- 🏜️ **Bare Ground** (ecological state 0)
- 🌱 **Seedling** (ecological state 1)
- 🌿 **Sapling** (ecological state 2)
- 🌲 **Mature Forest** (ecological state 3)
- ☠️ **Dead Forest** (ecological state 4)

### Organism Definitions
```gdscript
"🐺": Wolf - produces 💧 water, eats [🐰, 🐭]
"🦅": Eagle - produces 🌬️ wind, eats [🐦, 🐰, 🐭]
"🐦": Bird - produces 🥚 eggs, eats [🐛]
"🐱": Cat - eats [🐭, 🐰]
"🐰": Rabbit - produces 🌱, eats [🌱]
"🐛": Caterpillar - eats [🌱]
"🐭": Mouse - eats [🌱]
```

### Available Resources
- 💧 **Water** (harvested from 🐺 wolves)
- 🌬️ **Wind** (harvested from 🦅 eagles)
- 🥚 **Eggs** (harvested from 🐦 birds)
- 🍎 **Apples** (produced by 🌲 mature forest)
- 🐺 **Wolf** (apex predator, water source)
- 🦅 **Eagle** (apex predator, wind source)
- 🐦 **Bird** (carnivore, egg producer)
- 🐱 **Cat** (carnivore)
- 🐰 **Rabbit** (herbivore)
- 🐛 **Caterpillar** (herbivore)
- 🐭 **Mouse** (herbivore)
- 🌲 **Forest** (mature ecosystem state)
- 🌱 **Seedling** (early growth stage)
- 🌿 **Sapling** (mid growth stage)

### Mechanics
- **Markov Chain Succession**: 🏜️ → 🌱 → 🌿 → 🌲 → ☠️
- **Predator-Prey Dynamics**: Wolves eat rabbits, eagles eat birds
- **Weather Influence**: Wind + water affect growth probabilities
- **Quantum Organisms**: Each organism is a QuantumOrganism with behavior graph

### Faction Matches
- ✅ Iron Shepherds (protect 🐰🐦 from predators)
- ✅ Empire Shepherds (herd entire ecosystems)
- ✅ Cartographers (map 🗺️ ecological transitions)
- ✅ Clan of Hidden Root (🌱 forest restoration)
- ✅ Locusts (consume all organic matter)
- ✅ Bone Merchants (trade 🦴 bio-matter)

---

## Market Biome
**Keyboard Keys**: NM,.
**File**: `Core/Environment/MarketBiome.gd`

### Emoji Pairings (Quantum Superpositions)
```gdscript
register_emoji_pair("💰", "📦")  # Money ↔ Goods (economic duality)
register_emoji_pair("🐂", "🐻")  # Bull ↔ Bear (market sentiment)
```

### Available Resources
- 💰 **Money/Credits** (currency, liquid capital)
- 📦 **Goods** (commodities, stored value)
- 🐂 **Bull** (optimistic market, rising prices)
- 🐻 **Bear** (pessimistic market, falling prices)

### Mechanics
- **Market Equilibrium**: Bull ↔ Bear oscillation
- **Price Dynamics**: Theta determines price levels
- **Trade Execution**: Superposition of buying/selling

### Faction Matches
- ✅ Syndicate of Glass (💎 crystal trade)
- ✅ Memory Merchants (🧠💰 consciousness trading)
- ✅ Granary Guilds (🌾💰 grain markets)
- ✅ Bone Merchants (🦴💉 black market)
- ✅ Nexus Wardens (neutral trading zones)

---

## Granary Guilds Market Projection Biome
**Keyboard Keys**: (Projection biome, no direct keyboard access)
**File**: `Core/Environment/GranaryGuilds_MarketProjection_Biome.gd`

### Guild Internal Icons
```gdscript
storage_icon: DualEmojiQubit  # 📦 bread storage ↔ 🍞 bread
flour_icon: DualEmojiQubit    # 🌻 flour satisfaction ↔ 🌾 wheat
wheat_icon: DualEmojiQubit    # 🌾 wheat reserves ↔ 💼 business
water_icon: DualEmojiQubit    # 💧 water reserves ↔ ☀️ sun
```

### Available Resources
- 🌾 **Wheat** (grain sourcing)
- 💨 **Flour** (milled product)
- 🍞 **Bread** (final product, consumption target)
- 💰 **Money** (market stabilization)
- 📦 **Storage** (surplus capacity)
- 🌻 **Flour Balance** (satisfaction indicator)
- 💧 **Water** (ingredient sourcing)

### Mechanics
- **Bread Consumption**: Guilds constantly drain 🍞 energy
- **Market Pressure**: Push/pull on market theta to stabilize
- **Supply Stabilization**: Buy/sell to maintain equilibrium
- **Storage Management**: Fill/empty based on supply levels

### Faction Matches
- ✅ Granary Guilds (home biome)
- ✅ Yeast Prophets (🍞 bread mysticism)
- ✅ Millwright's Union (🌾 → 💨 processing)
- ✅ Carrion Throne (imperial grain quotas)

---

## Cross-Biome Resources

Some emojis appear in multiple biomes:

### 🌾 Wheat
- **BioticFlux**: Plantable crop (primary source)
- **GranaryGuilds**: Traded commodity

### 💰 Money/Credits
- **Market**: Trading currency
- **GranaryGuilds**: Market stabilization
- **Universal**: All biomes use for transactions

### 💧 Water
- **Forest**: Harvested from wolves
- **GranaryGuilds**: Ingredient sourcing

### 🍞 Bread
- **Kitchen**: Produced via alchemy
- **GranaryGuilds**: Consumption target

---

## Emoji Compatibility Matrix

| Faction | BioticFlux | Kitchen | Forest | Market | GranaryGuilds |
|---------|-----------|---------|--------|--------|---------------|
| Millwright's Union (🌾⚙️🏭) | ✅ | ❌ | ❌ | ❌ | ✅ |
| Yeast Prophets (🍞🧪⛪) | ❌ | ✅ | ❌ | ❌ | ✅ |
| Iron Shepherds (🛡️🐑🚀) | ✅ | ❌ | ✅ | ❌ | ❌ |
| Granary Guilds (🌾💰⚖️) | ✅ | ✅ | ❌ | ✅ | ✅ |
| Sacred Flame Keepers (🕯️🔥⛪) | ❌ | ✅ | ❌ | ❌ | ❌ |
| Syndicate of Glass (💎⚖️🛸) | ❌ | ❌ | ❌ | ✅ | ✅ |
| Cartographers (🗺️🔭🚢) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Locusts (🦗🍃💀) | ✅ | ❌ | ✅ | ❌ | ❌ |
| Entropy Shepherds (🌌💀🌸) | ✅ | ✅ | ✅ | ✅ | ✅ |

**Legend**:
- ✅ = Faction's emoji themes match biome resources
- ❌ = No emoji overlap, quests shouldn't spawn here

---

## Notes on Emoji Discovery

### Current Implementation
Biomes register emojis via `BiomeBase.register_emoji_pair()`:
```gdscript
func register_emoji_pair(north: String, south: String) -> void:
    emoji_pairings[north] = south
    emoji_pairings[south] = north
    register_resource(north, true, false)
    register_resource(south, true, false)
```

### Quest System Integration
```gdscript
# Quest generator can query available emojis:
var available_emojis = biome.get_producible_emojis()
var quest_emojis = faction.filter_matching_emojis(available_emojis)

if quest_emojis.is_empty():
    # Don't spawn this faction's quest in this biome
    return null
```

This ensures quests only spawn where their required resources exist.

---

## Future Biome Expansion

Potential new biomes and their emoji resources:

### Void Station (Space Trading Hub)
- 🚀 **Spacecraft** (transport)
- 🛸 **UFO** (alien traders)
- 💎 **Crystals** (hyperspace artifacts)
- ⭐ **Stars** (navigation points)

### Dreaming Hive (Consciousness Network)
- 🧠 **Minds** (consciousness units)
- 💭 **Dreams** (thought-forms)
- 🕸️ **Web** (neural connections)
- 👁️ **Eyes** (observation nodes)

### Crimson Wastes (Apocalyptic Desert)
- ☠️ **Death** (decay)
- 🩸 **Blood** (life essence)
- ⚡ **Lightning** (forbidden energy)
- 🏜️ **Desert** (barren land)

Each new biome would automatically generate compatible quests for factions whose emoji themes match.
