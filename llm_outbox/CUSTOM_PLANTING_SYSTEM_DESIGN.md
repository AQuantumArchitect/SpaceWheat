# Custom Planting System - Design Specification

**Date**: December 14, 2024
**Status**: 📘 DESIGN PHASE - Ready for Implementation

---

## 📋 Overview

Design for a **Custom Planting System** that allows players to plant discovered emoji pairs from the Vocabulary Evolution system, creating diverse wheat varieties with unique quantum properties. This bridges the gap between procedural discovery and strategic planting choices, adding depth to the core farming loop.

**Core Concept**: Discover vocabulary → Customize wheat → Strategic diversity

---

## 🎯 Design Goals

1. **Reward Vocabulary Discovery**: Make discovered emoji pairs useful and desirable
2. **Strategic Depth**: Different wheat varieties have different properties and use cases
3. **Procedural Variety**: Generate unique wheat types algorithmically from emoji combinations
4. **Quantum Mechanics**: Integrate with existing qubit/Bloch sphere system
5. **Economic Balance**: Custom wheat should have trade-offs vs standard wheat
6. **UI Clarity**: Make custom planting intuitive despite quantum complexity

---

## 🌾 System Architecture

### 1. Wheat Variety Database

Custom wheat varieties generated from discovered vocabulary:

```gdscript
class WheatVariety:
	var north_emoji: String  # e.g., "🧬"
	var south_emoji: String  # e.g., "🌱"
	var berry_phase: float   # Maturity level (from discovery)

	var initial_theta: float   # Starting quantum state
	var growth_rate_modifier: float
	var yield_multiplier: float
	var coherence_decay_rate: float
	var special_properties: Array[String]

	var discovery_time: float
	var times_planted: int
	var total_harvests: int
```

### 2. Property Generation

Emoji pairs determine wheat properties through semantic mapping:

```gdscript
func generate_wheat_properties(north: String, south: String) -> Dictionary:
	"""Generate wheat properties from emoji pair

	Uses emoji category, semantic similarity, and combination uniqueness
	to create procedurally balanced properties.
	"""

	var north_category = EmojiCategories.get_category(north)
	var south_category = EmojiCategories.get_category(south)

	# Calculate semantic distance
	var similarity = SemanticCoupling.calculate_emoji_similarity(north, south)

	# Base properties from categories
	var properties = {
		"growth_rate_mod": _calc_growth_modifier(north_category, south_category),
		"yield_mult": _calc_yield_multiplier(north_category, south_category),
		"coherence_decay": _calc_coherence_decay(similarity),
		"initial_theta": _calc_initial_theta(north_category, south_category),
		"special_props": _generate_special_properties(north, south, similarity)
	}

	return properties
```

### 3. Semantic Property Mapping

**Emoji Categories**:

```gdscript
const EMOJI_CATEGORIES = {
	# Agriculture & Nature
	"🌾": "agriculture",
	"🌱": "growth",
	"🍃": "organic",
	"🌿": "verdant",
	"🌻": "flowering",

	# Labor & Work
	"👥": "collective",
	"💪": "strength",
	"⚙️": "mechanical",
	"🔧": "tools",
	"🏭": "industrial",

	# Cosmic & Mystical
	"🌌": "cosmic",
	"⭐": "stellar",
	"🔮": "mystical",
	"🧬": "genetic",
	"💫": "radiant",

	# Economic & Social
	"💰": "wealth",
	"👑": "elite",
	"🏛️": "institutional",
	"⚖️": "balance",
	"📊": "systematic",

	# Experimental & Innovation
	"🧪": "experimental",
	"🎨": "creative",
	"🔬": "scientific",
	"⚡": "energetic",
	"🌀": "chaotic",

	# Memory & Time
	"📜": "historic",
	"🕰️": "temporal",
	"🧠": "cognitive",
	"💭": "ethereal",
	"🌙": "cyclical"
}
```

**Property Calculation Rules**:

```gdscript
func _calc_growth_modifier(cat_north, cat_south) -> float:
	"""Calculate growth rate modifier based on categories

	- Agriculture + Organic → Fast growth (1.2x)
	- Industrial + Mechanical → Slow but reliable (0.8x)
	- Cosmic + Mystical → Unpredictable (varies)
	- Genetic + Experimental → Very fast but unstable (1.5x)
	"""

	var combos = {
		["agriculture", "organic"]: 1.2,
		["agriculture", "growth"]: 1.3,
		["industrial", "mechanical"]: 0.8,
		["industrial", "systematic"]: 0.85,
		["cosmic", "mystical"]: 1.0 + randf_range(-0.3, 0.3),  # Variable
		["genetic", "experimental"]: 1.5,
		["collective", "strength"]: 1.1,
		["wealth", "systematic"]: 0.9
	}

	# Check both orderings
	if combos.has([cat_north, cat_south]):
		return combos[[cat_north, cat_south]]
	elif combos.has([cat_south, cat_north]):
		return combos[[cat_south, cat_north]]

	# Default: based on semantic distance
	return 1.0


func _calc_yield_multiplier(cat_north, cat_south) -> float:
	"""Calculate harvest yield multiplier

	- Wealth + Elite → High yield (1.3x) but high cost to plant
	- Agriculture + Nature → Standard yield (1.0x)
	- Experimental + Chaotic → Variable yield (0.5x to 2.0x)
	- Cosmic + Stellar → Low base yield but Berry phase multiplier
	"""

	var rules = {
		["wealth", "elite"]: 1.3,
		["agriculture", "agriculture"]: 1.1,
		["experimental", "chaotic"]: randf_range(0.5, 2.0),  # Gamble
		["cosmic", "stellar"]: 0.8,  # Low base, but scales with Berry phase
		["genetic", "growth"]: 1.2,
		["industrial", "systematic"]: 1.15
	}

	# ... similar combo checking
	return 1.0  # Default


func _calc_coherence_decay(similarity: float) -> float:
	"""Calculate how fast quantum coherence decays

	- High similarity (>0.7) → Stable (0.8 decay rate)
	- Medium similarity (0.3-0.7) → Normal (1.0 decay rate)
	- Low similarity (<0.3) → Unstable (1.3 decay rate)

	Unstable wheat loses superposition faster but has unique properties.
	"""

	if similarity > 0.7:
		return 0.8  # More stable
	elif similarity < 0.3:
		return 1.3  # Less stable
	else:
		return 1.0  # Normal


func _calc_initial_theta(cat_north, cat_south) -> float:
	"""Calculate initial theta (quantum state on Bloch sphere)

	- Agriculture-focused → Start near north pole (θ=0.2)
	- Labor-focused → Start near south pole (θ=2.9)
	- Mystical/Cosmic → Start at equator (θ=π/2) for max superposition
	- Balanced categories → Start at π/2
	"""

	# Map categories to preferred theta
	var north_affinity = {
		"agriculture": 0.2,
		"growth": 0.3,
		"organic": 0.25,
		"verdant": 0.15
	}

	var south_affinity = {
		"collective": 2.9,
		"strength": 2.8,
		"industrial": 2.85,
		"mechanical": 2.7
	}

	var equator_affinity = {
		"cosmic": PI/2,
		"mystical": PI/2,
		"chaotic": PI/2,
		"experimental": PI/2
	}

	# Priority: check affinities, default to balanced
	if north_affinity.has(cat_north) or north_affinity.has(cat_south):
		var avg = 0.0
		var count = 0
		if north_affinity.has(cat_north):
			avg += north_affinity[cat_north]
			count += 1
		if north_affinity.has(cat_south):
			avg += north_affinity[cat_south]
			count += 1
		return avg / count

	# ... similar for south and equator

	return PI / 2.0  # Default: balanced superposition
```

### 4. Special Properties

Some emoji combinations grant unique abilities:

```gdscript
func _generate_special_properties(north: String, south: String, similarity: float) -> Array[String]:
	"""Generate special properties for emoji combination

	Examples:
	- 🧬+🌱 (Genetic Growth) → "Adaptive: Changes theta based on neighbors"
	- 🌌+⭐ (Cosmic Stellar) → "Radiant: Boosts nearby plot growth"
	- 🔮+💭 (Mystical Ethereal) → "Phasing: Ignores some decoherence"
	- 💰+📊 (Wealth Systematic) → "Profitable: +20% credits on harvest"
	- ⚡+🌀 (Energetic Chaotic) → "Volatile: Random quantum jumps"
	"""

	var specials = []
	var combo_key = north + south

	# Unique combinations
	var special_combos = {
		"🧬🌱": "Adaptive: Theta shifts toward neighbors",
		"🌌⭐": "Radiant: +10% growth to adjacent plots",
		"🔮💭": "Phasing: -30% coherence decay",
		"💰📊": "Profitable: +20% credits on harvest",
		"⚡🌀": "Volatile: Random θ jumps ±0.5",
		"🧪🎨": "Innovative: Spawns new vocabulary faster",
		"🏛️👑": "Prestigious: Satisfies quota 1.5x",
		"📜🕰️": "Timeless: Berry phase accumulates 2x",
		"🌊🌀": "Fluid: Theta freely drifts",
		"💠🏗️": "Crystalline: Theta locked after maturity"
	}

	if special_combos.has(combo_key):
		specials.append(special_combos[combo_key])

	# Category-based specials
	var cat_north = EmojiCategories.get_category(north)
	var cat_south = EmojiCategories.get_category(south)

	if cat_north == "cosmic" and cat_south == "cosmic":
		specials.append("Entanglement Affinity: 2x entanglement strength")

	if (cat_north == "experimental" or cat_south == "experimental") and similarity < 0.3:
		specials.append("Unpredictable: Random effects on harvest")

	if cat_north == "temporal" or cat_south == "temporal":
		specials.append("Persistent: Doesn't decay when not planted")

	return specials
```

---

## 🎮 Player Experience Flow

### 1. Discovery

```
Player operates farm normally
  ↓
Vocabulary Evolution discovers new emoji pair (γ ≥ 5.0)
  ↓
Notification: "🧬 NEW VARIETY DISCOVERED: 🧬 ↔ 🌱"
  ↓
Added to custom wheat catalog
```

### 2. Selection

```
Player selects plot
  ↓
Presses [P] to plant
  ↓
Planting menu shows options:
  [1] Standard Wheat (🌾 ↔ 👥)
  [2] Custom Varieties →
      [A] Genetic Growth (🧬 ↔ 🌱) - Fast, adaptive
      [B] Cosmic Radiance (🌌 ↔ ⭐) - Boosts neighbors
      [C] Mystical Phase (🔮 ↔ 💭) - Stable coherence
  ↓
Player selects variety
  ↓
Shows preview:
    "Growth: 1.3x | Yield: 1.2x | Special: Adaptive"
    "Cost: 15 credits"
  ↓
Player confirms
  ↓
Custom wheat planted with unique properties
```

### 3. Cultivation

```
Custom wheat grows with modified properties:
  - Different growth rate
  - Different initial theta
  - Special property activates
  ↓
Player observes differences:
  - Adaptive wheat shifts toward neighbor states
  - Radiant wheat shows golden aura
  - Volatile wheat has shimmering θ indicator
  ↓
Harvest yields different results:
  - Higher/lower yield based on multiplier
  - Special effects trigger (bonus credits, vocabulary spawns, etc.)
```

---

## 🔧 Implementation Details

### Extend WheatPlot Class

```gdscript
# In WheatPlot.gd
class_name WheatPlot

# Add variety tracking
var variety_north: String = "🌾"  # Default
var variety_south: String = "👥"  # Default
var variety_properties: Dictionary = {}

func plant_custom(north: String, south: String, properties: Dictionary):
	"""Plant custom wheat variety"""

	if is_planted:
		return

	# Store variety info
	variety_north = north
	variety_south = south
	variety_properties = properties

	# Create quantum state with custom emoji
	quantum_state = DualEmojiQubit.new(north, south, properties.initial_theta)
	quantum_state.phi = randf() * TAU
	quantum_state.enable_berry_phase()

	# Apply property modifiers
	is_planted = true
	growth_progress = 0.0
	is_mature = false

	print("🌱 Planted %s ↔ %s wheat at %s" % [north, south, plot_id])


func grow(delta: float, conspiracy_network = null) -> float:
	"""Modified growth with variety bonuses"""

	if not is_planted or is_mature or not quantum_state:
		return 0.0

	# Base growth rate
	var growth_rate = BASE_GROWTH_RATE

	# Apply variety modifier
	if variety_properties.has("growth_rate_mod"):
		growth_rate *= variety_properties.growth_rate_mod

	# Apply special property effects
	if variety_properties.has("special_props"):
		for prop in variety_properties.special_props:
			growth_rate *= _apply_special_property_growth(prop)

	# ... rest of existing growth logic with modifications

	# Apply custom coherence decay
	if variety_properties.has("coherence_decay"):
		quantum_state.apply_decoherence(delta * variety_properties.coherence_decay)

	return growth_rate


func harvest() -> Dictionary:
	"""Modified harvest with variety bonuses"""

	# ... existing harvest logic

	# Apply variety yield multiplier
	if variety_properties.has("yield_mult"):
		final_yield *= variety_properties.yield_mult

	# Apply special property effects
	var bonus_credits = 0
	if variety_properties.has("special_props"):
		for prop in variety_properties.special_props:
			var effect = _apply_special_property_harvest(prop)
			if effect.has("bonus_credits"):
				bonus_credits += effect.bonus_credits

	return {
		"success": true,
		"yield": final_yield,
		"quality": quality_multiplier,
		"bonus_credits": bonus_credits,
		"variety": variety_north + " ↔ " + variety_south
	}


func _apply_special_property_growth(prop: String) -> float:
	"""Apply special property during growth"""

	# Parse property string
	if prop.begins_with("Radiant"):
		# Already boosted by neighbors (handled in FarmGrid)
		return 1.0

	elif prop.begins_with("Volatile"):
		# Random jumps
		if randf() < 0.1:  # 10% chance each frame
			quantum_state.theta += randf_range(-0.5, 0.5)
			quantum_state.theta = clamp(quantum_state.theta, 0.0, PI)
		return 1.0

	elif prop.begins_with("Adaptive"):
		# Handled by special coupling in FarmGrid
		return 1.0

	elif prop.begins_with("Fluid"):
		# Extra theta drift
		quantum_state.theta += randf_range(-0.1, 0.1) * 0.016
		return 1.0

	return 1.0


func _apply_special_property_harvest(prop: String) -> Dictionary:
	"""Apply special property during harvest"""

	if prop.begins_with("Profitable"):
		return {"bonus_credits": 10}

	elif prop.begins_with("Innovative"):
		# Signal to spawn extra vocabulary
		return {"spawn_vocabulary": 1}

	elif prop.begins_with("Prestigious"):
		# Signal to give extra quota credit
		return {"quota_mult": 1.5}

	return {}
```

### Vocabulary Integration

```gdscript
# In VocabularyEvolution.gd
func export_vocabulary_for_planting() -> Array[Dictionary]:
	"""Export discovered vocabulary as plantable varieties"""

	var plantable = []

	for discovery in discovered_vocabulary:
		var properties = _generate_wheat_properties(
			discovery.north,
			discovery.south
		)

		plantable.append({
			"north": discovery.north,
			"south": discovery.south,
			"berry_phase": discovery.berry_phase,
			"discovered_at": discovery.discovery_time,
			"properties": properties,
			"display_name": _generate_variety_name(discovery.north, discovery.south)
		})

	return plantable


func _generate_variety_name(north: String, south: String) -> String:
	"""Generate human-readable variety name"""

	var cat_north = EmojiCategories.get_category(north)
	var cat_south = EmojiCategories.get_category(south)

	# Combine categories into name
	var name_templates = {
		["genetic", "growth"]: "Evolving Strain",
		["cosmic", "stellar"]: "Starlight Grain",
		["mystical", "ethereal"]: "Phantom Wheat",
		["wealth", "systematic"]: "Profit Cultivar",
		["industrial", "mechanical"]: "Engineered Crop"
	}

	# Check templates
	if name_templates.has([cat_north, cat_south]):
		return name_templates[[cat_north, cat_south]]
	elif name_templates.has([cat_south, cat_north]):
		return name_templates[[cat_south, cat_north]]

	# Default: concatenate categories
	return "%s %s" % [cat_north.capitalize(), cat_south.capitalize()]
```

### UI Implementation

```gdscript
# In FarmView.gd
func _on_plant_pressed():
	"""Show planting options menu"""

	if not selected_plot or selected_plot.is_planted:
		return

	# Get available varieties
	var varieties = []

	# 1. Standard wheat
	varieties.append({
		"name": "Standard Wheat",
		"north": "🌾",
		"south": "👥",
		"cost": 5,
		"properties": _get_standard_properties()
	})

	# 2. Custom varieties from vocabulary
	if vocabulary_evolution:
		var custom = vocabulary_evolution.export_vocabulary_for_planting()
		for variety in custom:
			variety["cost"] = _calculate_variety_cost(variety)
			varieties.append(variety)

	# Show selection UI
	_show_variety_selection_menu(varieties)


func _show_variety_selection_menu(varieties: Array):
	"""Display variety selection menu"""

	var menu_text = "SELECT WHEAT VARIETY:\n\n"

	for i in range(varieties.size()):
		var v = varieties[i]
		menu_text += "[%d] %s %s\n" % [i + 1, v.north + " ↔ " + v.south, v.get("display_name", "")]
		menu_text += "    Cost: %d💰 | " % v.cost

		if v.has("properties"):
			var props = v.properties
			menu_text += "Growth: %.1fx | Yield: %.1fx\n" % [
				props.get("growth_rate_mod", 1.0),
				props.get("yield_mult", 1.0)
			]

			if props.has("special_props") and props.special_props.size() > 0:
				menu_text += "    Special: %s\n" % props.special_props[0]

		menu_text += "\n"

	info_label.text = menu_text

	# Wait for player input (1-9 keys)
	awaiting_variety_selection = true
	available_varieties = varieties


func _input(event):
	if awaiting_variety_selection and event is InputEventKey and event.pressed:
		var key = event.as_text()

		# Check if number key pressed
		if key.length() == 1 and key.is_valid_int():
			var index = int(key) - 1

			if index >= 0 and index < available_varieties.size():
				var variety = available_varieties[index]

				# Check if player can afford
				if economy.credits >= variety.cost:
					economy.credits -= variety.cost

					# Plant custom variety
					_plant_custom_variety(variety)

					awaiting_variety_selection = false
					available_varieties = []
				else:
					info_label.text = "Not enough credits!"


func _plant_custom_variety(variety: Dictionary):
	"""Plant the selected custom variety"""

	if variety.has("properties"):
		# Custom wheat
		selected_plot.plant_custom(
			variety.north,
			variety.south,
			variety.properties
		)
	else:
		# Standard wheat
		selected_plot.plant()

	info_label.text = "Planted %s %s" % [variety.north + " ↔ " + variety.south, variety.get("display_name", "")]


func _calculate_variety_cost(variety: Dictionary) -> int:
	"""Calculate planting cost based on variety properties"""

	var base_cost = 5

	if not variety.has("properties"):
		return base_cost

	var props = variety.properties

	# Higher growth → higher cost
	var growth_mod = props.get("growth_rate_mod", 1.0)
	if growth_mod > 1.1:
		base_cost += int((growth_mod - 1.0) * 20)

	# Higher yield → higher cost
	var yield_mod = props.get("yield_mult", 1.0)
	if yield_mod > 1.1:
		base_cost += int((yield_mod - 1.0) * 30)

	# Special properties → higher cost
	if props.has("special_props"):
		base_cost += props.special_props.size() * 10

	return base_cost
```

---

## ⚖️ Balancing Considerations

### Cost vs Reward

```
Standard Wheat:
  Cost: 5 credits
  Growth: 1.0x (10s to mature)
  Yield: 10-15 wheat
  ROI: ~100-200%

Genetic Growth (🧬 ↔ 🌱):
  Cost: 15 credits
  Growth: 1.3x (7.7s to mature)
  Yield: 12-18 wheat (1.2x)
  Special: Adaptive (synergy bonus)
  ROI: ~80-140% (lower base, but scaling with strategy)

Cosmic Radiance (🌌 ↔ ⭐):
  Cost: 20 credits
  Growth: 0.9x (11.1s to mature)
  Yield: 8-12 wheat (0.8x)
  Special: Radiant (+10% to neighbors)
  ROI: 40-80% alone, but multiplies neighbors (strategic)

Profitable Systematic (💰 ↔ 📊):
  Cost: 25 credits
  Growth: 0.9x
  Yield: 13-19 wheat (1.15x)
  Special: Profitable (+20% credits)
  ROI: 100-180% (high cost, high reward)
```

**Design Principle**: Custom wheat should have strategic niches, not just be "better wheat." Players choose based on:

- Farm layout (Radiant wheat in center of clusters)
- Economic state (Profitable wheat when low on credits)
- Goals (Prestigious wheat when facing quotas)
- Experimentation (Volatile/Experimental wheat for fun)

### Unlock Progression

```
Early Game (0-5 discoveries):
  - Standard wheat dominant
  - First custom varieties discovered
  - Expensive to plant custom

Mid Game (5-15 discoveries):
  - More varieties available
  - Cost balances out with improved economy
  - Strategic planting begins

Late Game (15+ discoveries):
  - Wide variety catalog
  - Complex farm compositions
  - Synergistic combinations (Radiant + Adaptive clusters)
  - Rare powerful combos discovered
```

---

## 🔮 Advanced Features

### Crossbreeding System

Allow two mature custom wheats to create new vocabulary:

```gdscript
func crossbreed_wheat(plot_a: WheatPlot, plot_b: WheatPlot) -> Dictionary:
	"""Combine two wheat varieties to create new vocabulary

	Takes one emoji from each parent, generates new combination.
	"""

	if not plot_a.is_mature or not plot_b.is_mature:
		return {}

	# Select random emoji from each parent
	var parent_a_emoji = [plot_a.variety_north, plot_a.variety_south][randi() % 2]
	var parent_b_emoji = [plot_b.variety_north, plot_b.variety_south][randi() % 2]

	# Create new qubit in vocabulary evolution
	vocabulary_evolution.spawn_crossbred_concept(parent_a_emoji, parent_b_emoji)

	return {
		"success": true,
		"child_north": parent_a_emoji,
		"child_south": parent_b_emoji
	}
```

### Heirloom Seeds

Save particularly good wheat instances as "seeds":

```gdscript
func save_as_heirloom(plot: WheatPlot) -> HeirloomSeed:
	"""Save mature wheat with accumulated Berry phase as reusable seed"""

	var seed = HeirloomSeed.new()
	seed.variety_north = plot.variety_north
	seed.variety_south = plot.variety_south
	seed.berry_phase = plot.quantum_state.get_berry_phase_abs()
	seed.replant_cycles = plot.replant_cycles

	# Heirloom seeds start with inherited Berry phase
	# More stable, better yields, higher cost
	return seed
```

### Faction-Influenced Varieties

Integrate with Faction Context to create themed varieties:

```gdscript
func generate_faction_variety(faction: Dictionary) -> Dictionary:
	"""Generate wheat variety themed around a faction

	Uses faction keywords to select emoji combinations.
	"""

	var keywords = faction.keywords
	var north_emoji = EmojiCategories.get_emoji_from_keyword(keywords[0])
	var south_emoji = EmojiCategories.get_emoji_from_keyword(keywords[1])

	# Properties influenced by faction pattern
	var properties = generate_wheat_properties(north_emoji, south_emoji)

	# Modulate based on faction q-bits
	properties.growth_rate_mod *= _faction_qbit_modifier(faction, "temporality")
	properties.yield_mult *= _faction_qbit_modifier(faction, "economy")

	return {
		"north": north_emoji,
		"south": south_emoji,
		"properties": properties,
		"faction_origin": faction.name
	}
```

---

## 📊 Implementation Roadmap

### Phase 1: Core Custom Planting (MVP)
- [ ] Extend WheatPlot with variety support
- [ ] Implement property generation system
- [ ] Add emoji category database
- [ ] Create variety selection UI
- [ ] Test basic custom planting

### Phase 2: Special Properties
- [ ] Implement special property effects
- [ ] Add visual indicators for varieties
- [ ] Balance cost/reward ratios
- [ ] Create variety info tooltips

### Phase 3: Strategic Depth
- [ ] Implement neighbor synergies (Radiant, Adaptive)
- [ ] Add variety statistics tracking
- [ ] Create variety comparison UI
- [ ] Balance for late-game variety diversity

### Phase 4: Advanced Features
- [ ] Crossbreeding system
- [ ] Heirloom seeds
- [ ] Faction-influenced varieties
- [ ] Variety catalog with filtering

---

## 🎉 Conclusion

The Custom Planting System transforms vocabulary discovery from a background process into a strategic core mechanic. By connecting procedural emoji pair generation to farmable wheat varieties with unique properties, players gain:

- **Strategic Choices**: Different wheats for different situations
- **Progression System**: Unlocking varieties through play
- **Emergent Complexity**: Synergies between variety combinations
- **Reward for Exploration**: Vocabulary discovery becomes directly useful

**Status**: 📘 DESIGN COMPLETE
**Next Step**: Implement Phase 1 (Core Custom Planting)

The design provides a clear path from discovery to strategic farming, with room for extensive future features while maintaining a simple core mechanic.

---

**Plant variety. Harvest strategy. Evolve the farm. 🌾⚛️🌈**
