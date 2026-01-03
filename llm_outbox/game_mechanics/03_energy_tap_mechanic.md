# Energy Tap Mechanic - Continuous Resource Drain

## Overview

Energy taps are **passive resource generators** that continuously drain energy from a target emoji in the biome's bath. Unlike planting crops, taps don't require evolution time - they produce resources continuously based on the target emoji's probability in the bath.

## Core Components

### Files Involved
- `Core/GameMechanics/FarmGrid.gd` - Lines 482-520: `plant_energy_tap()` method
- `UI/FarmInputHandler.gd` - Lines 1139-1167: `_action_place_energy_tap()` generic
- `UI/FarmInputHandler.gd` - Lines 1258-1276: `_action_place_energy_tap_for()` specific emoji
- `Core/GameState/ToolConfig.gd` - Lines 107-180: Dynamic energy_tap submenu generation

## How It Works

### 1. User Action (Dynamic Submenu)

```
User presses Tool 4 → Q (Energy Tap submenu)
  ↓
Submenu shows discovered emojis: Q=🌾, E=👥, R=🍄
  ↓
User presses E (tap 👥)
  ↓
FarmInputHandler._action_place_energy_tap_for([Vector2i(2,0)], "👥")
  ↓
FarmGrid.plant_energy_tap(Vector2i(2,0), "👥")
```

### 2. Dynamic Submenu Generation

**ToolConfig._generate_energy_tap_submenu() - Lines 107-180**:

```gdscript
static func _generate_energy_tap_submenu(base: Dictionary, farm) -> Dictionary:
    var generated = base.duplicate(true)

    # Get discovered emojis from vocabulary system
    var available_emojis = []
    if farm and farm.grid:
        available_emojis = farm.grid.get_available_tap_emojis()

    # Edge case: No discoveries yet
    if available_emojis.is_empty():
        generated["Q"] = {"action": "", "label": "Not Discovered", "emoji": "❓"}
        generated["E"] = {"action": "", "label": "Grow crops!", "emoji": "🌱"}
        generated["R"] = {"action": "", "label": "to unlock", "emoji": "🔒"}
        generated["_disabled"] = true
        return generated

    # Map first 3 discovered emojis to Q/E/R
    var keys = ["Q", "E", "R"]
    for i in range(min(3, available_emojis.size())):
        var emoji = available_emojis[i]
        var key = keys[i]
        var action_name = _emoji_to_action_name(emoji)

        generated[key] = {
            "action": "tap_%s" % action_name,
            "label": "Tap %s" % emoji,
            "emoji": emoji
        }

    # Lock unused buttons if <3 emojis
    for i in range(available_emojis.size(), 3):
        var key = keys[i]
        generated[key] = {
            "action": "",
            "label": "Locked",
            "emoji": "🔒"
        }

    return generated
```

**Vocabulary Discovery**:
- Emojis become "discovered" when harvested from crops
- `FarmGrid.get_available_tap_emojis()` returns list of discovered emojis
- Restricts tap placement to emojis player has encountered

### 3. Tap Placement

**FarmGrid.plant_energy_tap() - Lines 482-520**:

```gdscript
func plant_energy_tap(position: Vector2i, target_emoji: String) -> bool:
    var plot = get_plot(position)
    if plot == null or plot.is_planted:
        return false  # Position invalid or already occupied

    # VALIDATION: Check if emoji is in discovered vocabulary
    var available_emojis = get_available_tap_emojis()
    if not available_emojis.has(target_emoji):
        print("⚠️  Cannot plant tap: %s not in discovered vocabulary" % target_emoji)
        return false

    # Configure as energy tap
    plot.plot_type = FarmPlot.PlotType.ENERGY_TAP
    plot.tap_target_emoji = target_emoji
    plot.tap_theta = 3.0 * PI / 4.0  # Near south pole
    plot.tap_phi = PI / 4.0           # 45° off axis
    plot.tap_accumulated_resource = 0.0
    plot.tap_base_rate = 0.5

    plot.is_planted = true
    total_plots_planted += 1
    plot_planted.emit(position)

    print("⚡ Planted energy tap at %s targeting %s" % [plot.plot_id, target_emoji])
    return true
```

### 4. Tap Configuration

Energy taps use **Bloch sphere cos² coupling** to determine drain rate:

```gdscript
# Plot configuration
tap_target_emoji: String = "👥"      # Which emoji to drain
tap_theta: float = 3π/4              # Polar angle (near south)
tap_phi: float = π/4                 # Azimuthal angle
tap_base_rate: float = 0.5           # Base drain rate
tap_accumulated_resource: float = 0.0 # Accumulated energy
```

**Physics**:
```
Coupling strength = cos²(angle between tap axis and target emoji state)

For maximally mixed bath:
- Target emoji at arbitrary position on Bloch sphere
- Tap axis defined by (tap_theta, tap_phi)
- Drain rate ∝ cos²(angle) × tap_base_rate × P(target_emoji)
```

### 5. Energy Accumulation (Passive)

Energy taps accumulate resources **every physics frame** during `_process()`:

```gdscript
# Pseudo-code (actual implementation may vary)
func _process(delta: float):
    for plot in energy_tap_plots:
        # Get target emoji probability from bath
        var biome = get_biome_for_plot(plot.position)
        var p_target = biome.bath.get_probability(plot.tap_target_emoji)

        # Calculate drain rate
        var coupling = cos²(angle_between_tap_and_target)
        var drain_rate = plot.tap_base_rate × coupling × p_target

        # Accumulate
        plot.tap_accumulated_resource += drain_rate × delta

        # Update bath (drain probability from target)
        biome.bath.apply_lindblad_like_drain(plot.tap_target_emoji, drain_rate × delta)
```

**Key properties**:
- **Continuous**: Runs every frame, not discrete like harvest
- **Passive**: No user interaction required after placement
- **Proportional**: Drain rate scales with target emoji's bath probability
- **Affects bath**: Slowly reduces target emoji probability over time

### 6. Harvesting Tap

Unlike crops, taps are **permanent** and can be harvested multiple times:

```gdscript
func harvest_energy_tap(position: Vector2i) -> Dictionary:
    var plot = get_plot(position)
    if not plot or plot.plot_type != FarmPlot.PlotType.ENERGY_TAP:
        return {"success": false, "yield": 0}

    # Extract accumulated resource
    var yield_amount = int(plot.tap_accumulated_resource × FarmEconomy.QUANTUM_TO_CREDITS)
    yield_amount = max(1, yield_amount)

    # Reset accumulator (but keep tap active!)
    plot.tap_accumulated_resource = 0.0

    print("⚡ Harvested energy tap at %s: %d credits of %s" %
          [position, yield_amount, plot.tap_target_emoji])

    return {
        "success": true,
        "outcome": plot.tap_target_emoji,
        "yield": yield_amount,
        "tap_remains": true  # Tap NOT destroyed
    }
```

**Difference from crop harvest**:
- Crop harvest → plot cleared, quantum_state destroyed
- Tap harvest → accumulator reset, tap remains active

## Vocabulary Discovery System

### Discovery Mechanism

```gdscript
# FarmGrid tracks discovered emojis
var discovered_vocabulary: Dictionary = {}  # {emoji: discovery_time}

func register_emoji_discovery(emoji: String) -> void:
    if not discovered_vocabulary.has(emoji):
        discovered_vocabulary[emoji] = Time.get_ticks_msec()
        vocabulary_discovered.emit(emoji)
        print("📚 Discovered new emoji for taps: %s" % emoji)

func get_available_tap_emojis() -> Array:
    return discovered_vocabulary.keys()
```

### When Discovery Happens

```gdscript
# Called after successful harvest
func _on_harvest_complete(harvest_data: Dictionary):
    var outcome = harvest_data.get("outcome", "")
    if outcome != "" and outcome != "?":
        farm.grid.register_emoji_discovery(outcome)
```

**Progression**:
- Start: 0 emojis discovered → tap submenu disabled
- Harvest wheat: 🌾 discovered → can tap wheat
- Harvest mushroom: 🍄 discovered → can tap mushroom
- Late game: All biome emojis discovered → full tap menu

## Tap Strategy

### Early Game
```
Limited vocabulary: Only 🌾 and 👥 discovered
→ Place wheat taps to drain excess wheat probability
→ Use harvested wheat to plant more crops
```

### Mid Game
```
Expanded vocabulary: 🌾, 👥, 🍄, 🌙, ☀ discovered
→ Strategic tap placement based on biome composition
→ Tap high-probability emojis for passive income
→ Balance between active farming and passive taps
```

### Late Game
```
Full vocabulary: All biome emojis discovered
→ Optimize tap network across multiple biomes
→ Use taps to control bath probability distribution
→ Maintain desired emoji ratios for specialized production
```

## Tap Economics

### Cost-Benefit Analysis

```
Tap costs:
- Occupies 1 plot (opportunity cost vs active farming)
- Initial placement cost (if implemented)

Tap benefits:
- Passive income (no evolution wait time)
- Continuous resource generation
- Can be harvested multiple times
- Controls bath probability (strategic!)

Break-even:
- Tap produces ~0.5 credits/second (assuming tap_base_rate=0.5, p_target=0.2)
- Crop produces ~5-28 credits per harvest (3-5s evolution + harvest time)
- Tap break-even: ~10-56 seconds of passive accumulation
```

### When to Use Taps

**Prefer taps when**:
- AFK farming (passive income while away)
- High target emoji probability (>20% in bath)
- Limited active play time
- Want to stabilize bath composition

**Prefer active crops when**:
- Actively playing (can monitor evolution)
- Need burst resources (harvest spike)
- Want entanglement bonuses (taps can't entangle)
- Pursuing quantum coherence achievements

## Multiple Taps

You can place multiple taps targeting the SAME emoji:

```
Plot (2,0): Tap → 🌾
Plot (3,0): Tap → 🌾
Plot (4,0): Tap → 🌾

Each tap drains independently:
- Each accumulates separately
- Total drain rate = sum of individual tap rates
- Competes for limited bath probability
```

**Diminishing returns**: As taps drain 🌾 probability, each subsequent tap drains less (p_target decreases).

## Visualization

Energy taps show:
- Target emoji icon (larger than normal)
- Pulsing drain animation (particles flowing toward tap)
- Accumulated resource bar (fills over time)
- Current drain rate (text overlay)

## Debugging

### Check discovered vocabulary:
```gdscript
var discovered = farm.grid.get_available_tap_emojis()
print("Discovered emojis: %s" % discovered)
```

### Check tap configuration:
```gdscript
var plot = farm.grid.get_plot(Vector2i(2, 0))
print("Tap target: %s" % plot.tap_target_emoji)
print("Accumulated: %.3f" % plot.tap_accumulated_resource)
print("Base rate: %.3f" % plot.tap_base_rate)
```

### Check drain rate:
```gdscript
var biome = farm.grid.get_biome_for_plot(Vector2i(2, 0))
var p_target = biome.bath.get_probability(plot.tap_target_emoji)
print("Target probability in bath: %.3f" % p_target)
```

## Known Limitations

1. **No coherence bonus**: Taps don't benefit from quantum superposition
2. **Vocabulary gated**: Can't tap emojis you haven't discovered
3. **Diminishing returns**: Multiple taps compete for same probability
4. **No entanglement**: Taps can't be entangled (no quantum state)
5. **Permanent placement**: Can't move/remove taps after placement (unless reset)

## Comparison to Crops

| Property | Crops | Energy Taps |
|----------|-------|-------------|
| **Setup** | Plant, wait for evolution | Place, immediate drain |
| **Yield** | Burst (5-28 credits/harvest) | Continuous (~0.5 credits/s) |
| **Quantum** | Full quantum state | No quantum state |
| **Reuse** | Destroyed on harvest | Permanent, multi-harvest |
| **Entangle** | Yes | No |
| **Strategy** | Active play, burst income | Passive play, steady income |

## Summary

1. **Energy taps** drain target emoji probability continuously from bath
2. **Vocabulary gating** restricts taps to discovered emojis (progression)
3. **Placement** uses dynamic submenu generated from discovered vocabulary
4. **Accumulation** happens passively every frame (no player interaction)
5. **Harvest** extracts accumulated resources without destroying tap
6. **Strategy** balances opportunity cost vs passive income

**Key insight**: Taps convert spatial resources (plot slots) into temporal resources (passive income over time)!
