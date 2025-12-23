# Data-Driven Visual Design - Zero Waste, Zero Filler

**Principle**: Every visual element must communicate game state information.
**Goal**: Replace all decorative elements with parametric, data-driven effects.

---

## 🎯 Core Design Philosophy

**"Zero Waste, Zero Filler"**

1. **No Decoration**: If it doesn't encode information, remove it
2. **Parametric Everything**: All visual properties driven by game data
3. **Readable Signals**: Players should be able to "read" game state from visuals alone
4. **Information Density**: More game state visible = better design

---

## 📊 Current Systems & Data Sources

### Available Data Streams

**Icon States**:
- Biotic Flux: `activation` (0-1), `temperature` (K)
- Cosmic Chaos: `activation` (0-1), `temperature` (K)
- Imperium: `active_strength` (0-1), `measurement_pressure` (0-1)

**Plot States**:
- Quantum: `theta`, `phi`, `coherence`, `berry_phase`
- Growth: `growth_progress` (0-1), `is_mature`
- Entanglement: `entangled_plots` count, strength
- Variety: `north_emoji`, `south_emoji`

**Farm-Wide**:
- Total coherence: sum of all plot coherences
- Average growth rate
- Entanglement density: edges / possible edges
- Economic pressure: quota vs current

**Vocabulary Evolution**:
- Pool size, spawn rate, cannibalization rate
- Mutation pressure
- Discovery count

---

## 🎨 Visual Element Specifications

### 1. Background Particles (Currently: Random Sparkles)

**BEFORE**: Random stars twinkling for decoration
**AFTER**: Icon Energy Field Visualization

```gdscript
class IconEnergyParticle:
	var position: Vector2
	var velocity: Vector2
	var lifetime: float
	var size: float
	var color: Color
	var icon_source: String  # "biotic", "chaos", "imperium"

func spawn_energy_particle() -> IconEnergyParticle:
	"""Spawn particle based on Icon state"""

	# Determine which Icon to represent (weighted by activation)
	var weights = {
		"biotic": biotic_icon.get_activation(),
		"chaos": chaos_icon.get_activation(),
		"imperium": imperium_icon.active_strength
	}

	var total = weights.biotic + weights.chaos + weights.imperium
	if total < 0.01:
		return null  # No particles when all Icons inactive

	var rand = randf() * total
	var icon_source = ""
	if rand < weights.biotic:
		icon_source = "biotic"
	elif rand < weights.biotic + weights.chaos:
		icon_source = "chaos"
	else:
		icon_source = "imperium"

	# Get Icon data
	var activation = 0.0
	var temperature = 0.0
	var base_color = Color.WHITE

	match icon_source:
		"biotic":
			activation = biotic_icon.get_activation()
			temperature = biotic_icon.get_temperature()
			base_color = Color(0.3, 0.8, 0.4)  # Green
		"chaos":
			activation = chaos_icon.get_activation()
			temperature = chaos_icon.get_temperature()
			base_color = Color(0.9, 0.4, 0.2)  # Orange/red
		"imperium":
			activation = imperium_icon.active_strength
			temperature = 273.0 - imperium_icon.temperature_modifier  # Cooler
			base_color = Color(0.5, 0.5, 0.7)  # Blue/grey

	# Parametric properties
	var particle = IconEnergyParticle.new()

	# Speed: scales with temperature (hot = fast, cold = slow)
	var speed_factor = temperature / 300.0  # Normalize around room temp
	particle.velocity = Vector2(
		randf_range(-50, 50),
		randf_range(-50, 50)
	) * speed_factor

	# Size: scales with activation (high activation = larger particles)
	particle.size = 2.0 + (activation * 8.0)  # 2-10 pixels

	# Color: temperature affects brightness
	var brightness = clamp(temperature / 400.0, 0.3, 1.0)
	particle.color = base_color * brightness
	particle.color.a = activation  # Transparency = activation strength

	# Lifetime: inversely proportional to temperature (hot = short-lived)
	particle.lifetime = 2.0 / speed_factor

	# Position: spawn from Icon direction
	var icon_offset = _get_icon_direction_offset(icon_source)
	particle.position = screen_center + icon_offset * randf_range(50, 150)

	particle.icon_source = icon_source

	return particle
```

**Information Encoded**:
- **Particle color** → Which Icon is active (green/orange/blue)
- **Particle speed** → Icon temperature (fast hot, slow cold)
- **Particle size** → Icon activation strength
- **Particle transparency** → Icon activation (faint = low, bright = high)
- **Particle spawn rate** → Total Icon activity
- **Particle lifetime** → Icon temperature (hot = brief, cold = lingering)

**Player reads**: "Lots of fast small green particles = high-temp, low-activation Biotic"

---

### 2. Plot Visual States

**BEFORE**: Static emoji with some growth indication
**AFTER**: Multi-parameter visual encoding

```gdscript
func update_plot_visuals(plot: WheatPlot, tile: PlotTile):
	"""Update plot visuals based on quantum state"""

	if not plot or not plot.is_planted:
		tile.set_base_color(Color.DARK_GRAY)
		tile.set_glow(0.0)
		tile.set_rotation_speed(0.0)
		return

	var qstate = plot.quantum_state

	# 1. Base color: encodes theta position on Bloch sphere
	var theta_normalized = qstate.theta / PI  # 0 (north) to 1 (south)
	var north_color = Color(0.4, 0.9, 0.4)  # Green (natural 🌾)
	var south_color = Color(0.6, 0.6, 0.9)  # Blue (labor 👥)
	var base_color = north_color.lerp(south_color, theta_normalized)
	tile.set_base_color(base_color)

	# 2. Glow intensity: encodes coherence
	var coherence = qstate.get_coherence()
	tile.set_glow(coherence)  # 0 (classical) to 1 (pure superposition)

	# 3. Rotation speed: encodes phi evolution
	# Faster rotation = higher phi change rate
	tile.set_rotation_speed(abs(qstate.phi) * 0.1)

	# 4. Border thickness: encodes Berry phase (institutional memory)
	var berry = qstate.get_berry_phase_abs()
	var border_thickness = 1.0 + (berry * 3.0)  # 1-4 pixels
	tile.set_border_thickness(border_thickness)

	# 5. Border color: encodes cultural stability
	var stability = qstate.get_cultural_stability()
	var border_color = Color(0.8, 0.6, 0.2) * stability  # Golden when stable
	tile.set_border_color(border_color)

	# 6. Pulsing: encodes growth progress
	if not plot.is_mature:
		var pulse_rate = plot.growth_progress * 2.0  # Faster as it grows
		tile.set_pulse_rate(pulse_rate)
	else:
		tile.set_pulse_rate(0.0)  # Stop pulsing when mature

	# 7. Sparkle count: encodes entanglement count
	var entanglement_count = qstate.entangled_plots.size()
	tile.set_sparkle_count(entanglement_count)
```

**Information Encoded**:
- **Base color** → Theta (green = natural north, blue = labor south)
- **Glow intensity** → Coherence (bright = superposed, dim = classical)
- **Rotation speed** → Phi evolution rate
- **Border thickness** → Berry phase accumulation (history)
- **Border color** → Cultural stability (golden = veteran)
- **Pulse rate** → Growth progress (faster = nearly mature)
- **Sparkle count** → Entanglement degree (0-3 sparkles)

**Player reads**: "Thick golden border + bright glow = veteran wheat in strong superposition"

---

### 3. Entanglement Lines

**BEFORE**: Static white/colored lines
**AFTER**: Parametric connection encoding

```gdscript
func draw_entanglement_line(pos_a: Vector2, pos_b: Vector2, pair: EntangledPair):
	"""Draw entanglement line with parametric properties"""

	# 1. Line thickness: encodes entanglement strength
	var purity = pair.get_purity()  # 0 (mixed) to 1 (pure Bell state)
	var thickness = 1.0 + (purity * 3.0)  # 1-4 pixels

	# 2. Line color: encodes entanglement type
	var color = Color.WHITE
	if pair.is_bell_phi_plus():
		color = Color(0.8, 0.8, 1.0)  # Light blue (correlated)
	elif pair.is_bell_psi_plus():
		color = Color(1.0, 0.8, 0.8)  # Light red (anti-correlated)

	# 3. Line opacity: encodes concurrence (entanglement measure)
	var concurrence = pair.get_concurrence()
	color.a = 0.3 + (concurrence * 0.7)  # 0.3-1.0

	# 4. Animation speed: encodes decoherence rate
	var decoherence = 1.0 - purity  # How fast it's decohering
	var flow_speed = 0.5 + (decoherence * 2.0)  # Faster flow = decohering faster

	# 5. Particle density: encodes entanglement entropy
	var entropy = pair.get_entanglement_entropy()
	var particle_count = int(entropy * 5.0)  # 0-5 particles

	draw_animated_line(pos_a, pos_b, color, thickness, flow_speed, particle_count)
```

**Information Encoded**:
- **Thickness** → Entanglement purity (thick = pure Bell state)
- **Color** → Entanglement type (blue = Φ+, red = Ψ+)
- **Opacity** → Concurrence (faint = weak, bright = strong)
- **Flow speed** → Decoherence rate (fast = decaying)
- **Particle density** → Entanglement entropy

**Player reads**: "Thick bright blue slow-flowing line = strong pure correlated entanglement"

---

### 4. Quantum Force Graph Nodes

**BEFORE**: Colored circles with some movement
**AFTER**: Full quantum state visualization

```gdscript
func update_quantum_node_visuals(node: QuantumNode):
	"""Update node appearance based on quantum state"""

	var qstate = node.plot.quantum_state

	# 1. Position on graph: already encodes theta/phi via Bloch sphere
	# (This is good - maintain current mapping)

	# 2. Node size: encodes radius (amplitude)
	var amplitude = qstate.radius
	node.visual_size = 8.0 * amplitude  # Pure states = radius 1.0 = 8px

	# 3. Node color: encodes semantic blend
	var blend = qstate.get_semantic_blend()
	var north_color = Color(0.4, 0.9, 0.4)
	var south_color = Color(0.6, 0.6, 0.9)
	node.color = north_color.lerp(south_color, blend)

	# 4. Node inner/outer ring: encodes measurement state
	if node.plot.has_been_measured:
		node.show_collapsed_indicator = true
		node.collapse_color = Color(1.0, 0.3, 0.3)  # Red = collapsed
	else:
		node.show_collapsed_indicator = false

	# 5. Node pulsing: encodes growth
	var growth = node.plot.growth_progress
	node.pulse_amplitude = growth * 2.0

	# 6. Node glow: encodes coherence
	var coherence = qstate.get_coherence()
	node.glow_intensity = coherence

	# 7. Orbital particles: encode Berry phase
	var berry = qstate.get_berry_phase_abs()
	node.orbital_count = min(int(berry / 2.0), 5)  # 0-5 orbiting particles
```

**Information Encoded**:
- **Position** → Theta/phi (Bloch sphere)
- **Size** → Amplitude/radius
- **Color** → North/south blend
- **Red ring** → Collapsed/measured state
- **Pulse amplitude** → Growth progress
- **Glow** → Coherence
- **Orbiting particles** → Berry phase accumulation

**Player reads**: "Center position + large + glowing + 3 orbiters = equator superposition with high history"

---

### 5. Icon Visual Indicators

**BEFORE**: Small icons with some activation indicator
**AFTER**: Full state encoding

```gdscript
func update_icon_visuals():
	"""Update Icon visual representations"""

	# Biotic Flux
	var biotic_size = 20.0 + (biotic_icon.get_activation() * 30.0)  # 20-50px
	var biotic_glow = biotic_icon.get_activation()
	var biotic_temp_color = _temperature_to_color(biotic_icon.get_temperature())
	var biotic_pulse_rate = biotic_icon.get_coherence_boost() * 2.0

	biotic_visual.size = biotic_size
	biotic_visual.glow = biotic_glow
	biotic_visual.color = biotic_temp_color
	biotic_visual.pulse_rate = biotic_pulse_rate

	# Cosmic Chaos
	var chaos_size = 20.0 + (chaos_icon.get_activation() * 30.0)
	var chaos_glow = chaos_icon.get_activation()
	var chaos_temp_color = _temperature_to_color(chaos_icon.get_temperature())
	var chaos_distortion = chaos_icon.get_dephasing_strength() * 5.0  # Waviness

	chaos_visual.size = chaos_size
	chaos_visual.glow = chaos_glow
	chaos_visual.color = chaos_temp_color
	chaos_visual.distortion = chaos_distortion  # Edge waviness

	# Imperium
	var imperium_size = 20.0 + (imperium_icon.active_strength * 30.0)
	var imperium_glow = imperium_icon.active_strength
	var imperium_pressure = imperium_icon.get_measurement_pressure()
	var imperium_rays = int(imperium_pressure * 8.0)  # 0-8 rays extending

	imperium_visual.size = imperium_size
	imperium_visual.glow = imperium_glow
	imperium_visual.ray_count = imperium_rays
	imperium_visual.color = Color(0.7, 0.7, 0.9)  # Cool blue

func _temperature_to_color(temp_kelvin: float) -> Color:
	"""Map temperature to color (cold = blue, hot = red)"""
	# 200K = blue, 300K = white, 400K = red
	var normalized = (temp_kelvin - 200.0) / 200.0  # 0 (cold) to 1 (hot)
	normalized = clamp(normalized, 0.0, 1.0)

	if normalized < 0.5:
		# Cold to neutral (blue to white)
		return Color(0.5, 0.7, 1.0).lerp(Color(1, 1, 1), normalized * 2.0)
	else:
		# Neutral to hot (white to red)
		return Color(1, 1, 1).lerp(Color(1.0, 0.5, 0.3), (normalized - 0.5) * 2.0)
```

**Information Encoded per Icon**:
- **Size** → Activation strength
- **Glow** → Activation strength
- **Color** → Temperature
- **Pulse rate** (Biotic) → Coherence boost strength
- **Distortion** (Chaos) → Dephasing strength
- **Ray count** (Imperium) → Measurement pressure

**Player reads**: "Large red pulsing Biotic = high-temp high-activation pumping coherence"

---

### 6. Vocabulary Evolution Indicator

**BEFORE**: Button with count
**AFTER**: Live evolution visualization

```gdscript
func update_vocabulary_visuals():
	"""Visualize vocabulary evolution state"""

	var stats = vocabulary_evolution.get_evolution_stats()

	# 1. Bubble count: pool size
	vocabulary_visual.bubble_count = stats.pool_size

	# 2. Bubble spawn rate: spawn rate
	vocabulary_visual.spawn_rate = stats.spawn_rate

	# 3. Bubble color shifting: mutation pressure
	var mutation = stats.mutation_pressure
	vocabulary_visual.color_shift_speed = mutation * 2.0

	# 4. Bubble size distribution: maturity distribution
	# Larger bubbles = more mature concepts (higher Berry phase)
	vocabulary_visual.update_bubble_sizes(vocabulary_evolution.evolving_qubits)

	# 5. Golden flash: discovery event
	if stats.discovered_count > previous_discovered_count:
		vocabulary_visual.trigger_discovery_flash()
		previous_discovered_count = stats.discovered_count

	# 6. Background glow: total evolutionary activity
	var activity = stats.pool_size * stats.mutation_pressure
	vocabulary_visual.background_glow = activity / 25.0  # Normalize
```

**Information Encoded**:
- **Bubble count** → Pool size
- **Spawn rate** → New concept generation
- **Color shift speed** → Mutation pressure
- **Bubble sizes** → Maturity levels
- **Golden flash** → Discovery event
- **Background glow** → Total activity

**Player reads**: "Many fast-shifting bubbles with glow = high evolutionary pressure"

---

### 7. Economic/Goal Pressure Visualization

**BEFORE**: Text labels only
**AFTER**: Visual pressure indicators

```gdscript
func update_pressure_visuals():
	"""Visualize economic and goal pressure"""

	# Economic pressure
	var economic_health = float(economy.credits) / 100.0  # Normalize to expected value
	economic_health = clamp(economic_health, 0.0, 2.0)

	# Color code: red (broke) → yellow (OK) → green (rich)
	var econ_color = Color.RED
	if economic_health < 0.5:
		econ_color = Color.RED.lerp(Color.YELLOW, economic_health * 2.0)
	else:
		econ_color = Color.YELLOW.lerp(Color.GREEN, (economic_health - 0.5) * 2.0)

	credits_label.add_theme_color_override("font_color", econ_color)

	# Goal pressure (quota)
	if goals.current_goal:
		var progress = goals.get_progress()
		var time_remaining = goals.get_time_remaining()
		var time_pressure = 1.0 - (time_remaining / goals.current_goal.time_limit)

		# Visualize as expanding/contracting ring around farm
		pressure_ring.radius = 200.0 + (time_pressure * 100.0)
		pressure_ring.thickness = 2.0 + (time_pressure * 8.0)
		pressure_ring.opacity = time_pressure * 0.5

		# Color: green (ahead) → yellow (on track) → red (behind)
		var pressure_ratio = progress / time_pressure
		var pressure_color = Color.GREEN
		if pressure_ratio < 0.8:
			pressure_color = Color.RED.lerp(Color.YELLOW, pressure_ratio / 0.8)
		elif pressure_ratio < 1.0:
			pressure_color = Color.YELLOW.lerp(Color.GREEN, (pressure_ratio - 0.8) / 0.2)

		pressure_ring.color = pressure_color
	else:
		pressure_ring.opacity = 0.0
```

**Information Encoded**:
- **Credit label color** → Economic health (red = poor, green = rich)
- **Pressure ring radius** → Time pressure
- **Pressure ring thickness** → Time pressure
- **Pressure ring color** → Progress vs time (red = behind, green = ahead)

**Player reads**: "Thick red expanding ring = falling behind on quota"

---

## 🔧 Implementation Priority

### Phase 1: High-Impact Visual Encoding (Next Session)
1. **Background particles** → Icon energy field
2. **Plot base color** → Theta encoding
3. **Plot glow** → Coherence encoding
4. **Entanglement line opacity** → Concurrence

### Phase 2: Deep State Encoding
5. **Plot border** → Berry phase visualization
6. **Icon visuals** → Full parametric encoding
7. **Pressure ring** → Economic/goal visualization

### Phase 3: Advanced Information
8. **Vocabulary bubbles** → Live evolution visualization
9. **Quantum node orbiters** → Berry phase particles
10. **Flow animations** → Decoherence rates

---

## 📐 Visual Design Patterns

### Color Temperature Mapping
```
200K (cold) → Blue (0.5, 0.7, 1.0)
300K (room) → White (1.0, 1.0, 1.0)
400K (hot)  → Red (1.0, 0.5, 0.3)
```

### Size/Intensity Mapping
```
0.0 (none)    → 0px / 0% opacity
0.5 (medium)  → 50% of max
1.0 (full)    → 100% of max
```

### Animation Speed Mapping
```
Low value     → Slow (0.5x)
Medium value  → Normal (1.0x)
High value    → Fast (2.0x)
```

---

## 🎯 Success Criteria

Visual design is successful when:

✅ **Player can estimate game state from visuals alone** (no labels needed)
✅ **Every visual parameter maps 1:1 to a game variable**
✅ **No visual elements exist purely for decoration**
✅ **Information density increases** (more data visible at once)
✅ **Player develops "visual literacy"** (learns to read the patterns)

---

**Zero waste. Zero filler. Maximum information.**
