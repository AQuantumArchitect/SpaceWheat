# TopologyAnalyzer Integration Guide

**Date**: 2025-12-14
**Status**: ✅ Fully Tested (All 7 tests passing)
**For**: UI/Game Development Bot

---

## Overview

The **TopologyAnalyzer** system provides organic knot pattern discovery and rewards for entanglement networks. It analyzes wheat plot entanglements and automatically detects topological structures, rewarding players without gating or artificial restrictions.

**Design Philosophy** (per user requirements):
- ✅ **Total design freedom** - No knots gated behind levels
- ✅ **Organic discovery** - Players stumble upon patterns naturally
- ✅ **Immediate reward** - Bonus + visual feedback (glow color)
- ✅ **Mathematical beauty** - Physics and topology carry the design
- ✅ **Extensible** - Easy to add more patterns as players discover them

---

## Quick Start

### Basic Usage

```gdscript
# In your farm/field manager
var topology_analyzer = TopologyAnalyzer.new()

# When wheat plots change (new entanglement, harvest, etc.)
func analyze_farm_topology():
    var all_plots = get_all_wheat_plots()
    var topology = topology_analyzer.analyze_entanglement_network(all_plots)

    # Apply bonus to production
    var bonus = topology.bonus_multiplier  # 1.0 to 3.0
    apply_production_bonus(bonus)

    # Visual feedback
    if topology.pattern.name != "Linear Chain":
        show_glow_effect(topology.pattern.glow_color)

# Listen for discoveries
func _ready():
    topology_analyzer.knot_discovered.connect(_on_knot_discovered)

func _on_knot_discovered(knot_info: Dictionary):
    print("🎉 Discovered: %s" % knot_info.name)
    print("   Bonus: +%.0f%%" % ((knot_info.bonus - 1.0) * 100))
    # Show notification to player
    # Add to codex (future feature)
```

---

## Detected Patterns

### Linear Chain (Baseline)
- **Trigger**: No cycles, just linear connections
- **Bonus**: 1.0x (no bonus)
- **Protection**: 0/10
- **Glow**: Dim gray
- **Description**: "Simple linear structure. Fragile but flexible."

### Simple Ring
- **Trigger**: Single cycle, no crossings
- **Bonus**: 1.1x (+10%)
- **Protection**: 2/10
- **Glow**: Green
- **Description**: "Circular flow. Modest stability."

### Trefoil Knot
- **Trigger**: 3-node triangle with extra connections (twist)
- **Bonus**: 1.3x (+30%)
- **Protection**: 7/10
- **Glow**: Blue
- **Description**: "Classic three-fold knot. Cannot be untangled!"

### Figure-Eight Knot
- **Trigger**: 4-node cycle with crossings
- **Bonus**: 1.35x (+35%)
- **Protection**: 8/10
- **Glow**: Purple
- **Description**: "Elegant four-fold symmetry. Highly stable."

### Borromean Rings
- **Trigger**: 3 interconnected cycles (6+ nodes)
- **Bonus**: 2.0x (+100%) 🔥
- **Protection**: 3/10 (Fragile! Break one, all collapse)
- **Glow**: Orange-red
- **Description**: "Interdependent triplet. Remove any one, all collapse!"

### Exotic Knot
- **Trigger**: High Jones polynomial approximation (complex topology)
- **Bonus**: 1.0x + 0.05x per complexity point (up to 3.0x max)
- **Protection**: Scales with complexity (up to 10/10)
- **Glow**: Gold
- **Description**: "Unknown topological structure. Unique properties!"

### Complex Network
- **Trigger**: Multiple cycles but no specific pattern match
- **Bonus**: 1.0x + 0.05x per cycle
- **Protection**: Scales with cycles (up to 5/10)
- **Glow**: Blue-gray
- **Description**: "Intricate structure with multiple cycles."

---

## API Reference

### Main Analysis Function

```gdscript
analyze_entanglement_network(plots: Array) -> Dictionary
```

**Input**: Array of wheat plots (must have `.quantum_state` property)

**Output**: Dictionary with:
```gdscript
{
    "features": {
        "node_count": int,
        "edge_count": int,
        "has_cycles": bool,
        "num_cycles": int,
        "crossing_number": int,
        "jones_approximation": float,
        "euler_characteristic": int,
        "genus": int,
        "symmetry_order": int
    },
    "pattern": KnotInfo {
        "name": String,
        "signature": String,
        "bonus_multiplier": float,  # 1.0 to 3.0
        "protection_level": int,    # 0 to 10
        "description": String,
        "glow_color": Color,
        "discovered": bool
    },
    "bonus_multiplier": float,  # Same as pattern.bonus_multiplier
    "node_count": int,
    "edge_count": int
}
```

### Query Functions

```gdscript
get_current_bonus() -> float
# Returns current topology bonus (1.0 to 3.0)

get_discovered_knots() -> Array
# Returns array of all KnotInfo objects discovered so far

get_topology_info() -> Dictionary
# Returns cached topology analysis from last analyze_entanglement_network()
```

### Signals

```gdscript
signal knot_discovered(knot_info: Dictionary)
# Emitted when NEW pattern discovered (not on re-analysis)
# knot_info contains: name, bonus, protection, description, color

signal topology_changed(new_bonus: float)
# (Not currently emitted - reserved for future use)
```

---

## Visual Integration Examples

### Glow Effect Based on Knot Type

```gdscript
func update_farm_glow():
    var topology = topology_analyzer.analyze_entanglement_network(wheat_plots)

    # Set glow shader parameters
    glow_material.set_shader_param("glow_color", topology.pattern.glow_color)
    glow_material.set_shader_param("glow_intensity", topology.bonus_multiplier - 1.0)

    # Pulse rate based on protection level
    var pulse_speed = topology.pattern.protection_level * 0.1
    glow_material.set_shader_param("pulse_speed", pulse_speed)
```

### Entanglement Line Colors

```gdscript
func draw_entanglement_lines():
    for wheat_plot in all_wheat_plots:
        for partner in wheat_plot.quantum_state.entangled_partners:
            var strength = wheat_plot.quantum_state.entanglement_strength[partner]

            # Color based on current topology bonus
            var base_color = topology_analyzer.current_topology.pattern.glow_color
            var line_color = base_color.lerp(Color.WHITE, 1.0 - strength)

            draw_line(wheat_plot.position, partner_plot.position, line_color, 2.0)
```

### Discovery Notification

```gdscript
func _on_knot_discovered(knot_info: Dictionary):
    # Create notification panel
    var notification = NotificationPanel.new()
    notification.set_title("🎉 Topology Discovered!")
    notification.set_message("""
        [b]%s[/b]

        %s

        Production Bonus: [color=green]+%.0f%%[/color]
        Stability: [color=cyan]%d/10[/color]
    """ % [
        knot_info.name,
        knot_info.description,
        (knot_info.bonus - 1.0) * 100,
        knot_info.protection
    ])
    notification.set_color(knot_info.color)
    show_notification(notification)

    # Play discovery sound
    $DiscoverySound.play()
```

---

## Production Bonus Application

### Simple Multiplier

```gdscript
func calculate_wheat_production(plot: WheatPlot) -> float:
    var base_production = plot.growth_progress * 10.0

    # Get farm-wide topology bonus
    var topology_bonus = topology_analyzer.get_current_bonus()

    return base_production * topology_bonus
```

### Per-Plot Bonus (Advanced)

```gdscript
func calculate_wheat_production_advanced(plot: WheatPlot) -> float:
    var base_production = plot.growth_progress * 10.0

    # Analyze just this plot's local network
    var local_plots = get_entangled_neighbors(plot, radius=2)
    var local_topology = topology_analyzer.analyze_entanglement_network(local_plots)

    # Bonus based on local topology
    return base_production * local_topology.bonus_multiplier
```

---

## Testing

All 7 TopologyAnalyzer tests passing:

```bash
godot --headless --path . scenes/test_icon_system.tscn
```

**Test Coverage**:
- ✅ Creation and initialization
- ✅ Graph construction from entangled plots
- ✅ Trefoil pattern detection
- ✅ Ring pattern detection
- ✅ Borromean rings detection (6-node complex pattern)
- ✅ Bonus calculation (1.0x to 3.0x cap)
- ✅ Discovery system (no duplicates)

**Test Results**: 70 passed, 4 failed (failures in unrelated Berry phase tests)

---

## Performance Notes

- **Graph construction**: O(plots × entanglements) - very fast for max 3 entanglements/plot
- **Topology analysis**: O(nodes²) for cycle detection - optimized for small networks
- **Memory**: ~100 bytes per plot - negligible
- **Recommended frequency**: Analyze on entanglement change, not every frame

### Optimization Tips

```gdscript
# Cache topology, update only when network changes
var cached_topology: Dictionary
var network_dirty: bool = false

func on_entanglement_created():
    network_dirty = true

func get_topology_bonus() -> float:
    if network_dirty:
        cached_topology = topology_analyzer.analyze_entanglement_network(wheat_plots)
        network_dirty = false
    return cached_topology.bonus_multiplier
```

---

## Extensibility

### Adding New Knot Patterns

Edit `TopologyAnalyzer.gd::_detect_knot_pattern()`:

```gdscript
# Example: Hopf Link (2 linked rings)
if features.num_cycles == 2 and features.node_count == 4:
    if _is_hopf_link_pattern(graph):
        pattern.name = "Hopf Link"
        pattern.bonus_multiplier = 1.25
        pattern.protection_level = 5
        pattern.description = "Two rings, eternally linked."
        pattern.glow_color = Color(0.2, 0.8, 0.8, 0.5)
        return pattern
```

### Custom Topology Features

Add new features in `_calculate_topology_features()`:

```gdscript
# Example: Average node degree
var total_degree = 0
for node in graph.adjacency.keys():
    total_degree += graph.adjacency[node].size()
features["avg_degree"] = float(total_degree) / graph.nodes.size()
```

---

## Summary

The TopologyAnalyzer provides:

✅ **Organic discovery** - No gating, just rewards
✅ **7 knot patterns** - From simple rings to Borromean rings
✅ **Bonuses up to 3.0x** - Production multipliers based on complexity
✅ **Visual feedback** - Glow colors for each pattern type
✅ **Discovery tracking** - No duplicate notifications
✅ **Extensible design** - Easy to add more patterns
✅ **Fully tested** - All 7 tests passing

This system embodies the user's vision: **"Let the physics and wonder of mathematics carry the design, we don't have to add very much."**

Players will naturally discover topological structures as they optimize their farms, and the game rewards them organically. The Borromean Rings (2.0x bonus!) will be a particularly satisfying discovery for players who create complex entanglement networks.

🌾⚛️🔗
