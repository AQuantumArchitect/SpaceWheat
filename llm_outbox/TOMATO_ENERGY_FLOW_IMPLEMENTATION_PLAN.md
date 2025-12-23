# Tomato Energy Flow Implementation Plan
**Date**: 2025-12-14
**Priority Order**: Proposal B → Proposal D → (Proposal A)
**Core Philosophy**: "See the energy flows in the force-directed graph"

---

## Phase 1: Energy Flow Visualization (Proposal B)
**Goal**: Make the invisible conspiracy network visible through the base layer visuals
**Effort**: 22-32 hours
**Status**: PRIMARY FOCUS

---

### Part 1A: Conspiracy Network Overlay (8-12 hours)

#### Task 1.1: Network Visualization Node (4-6 hours)

**Create**: `UI/ConspiracyNetworkOverlay.gd`

```gdscript
class_name ConspiracyNetworkOverlay
extends Node2D

## Visualizes the 12-node conspiracy network as a force-directed graph

var conspiracy_network: TomatoConspiracyNetwork
var node_sprites: Dictionary = {}  # node_id -> NetworkNodeSprite
var connection_lines: Array[ConnectionLine] = []

# Force-directed graph simulation
var node_positions: Dictionary = {}  # node_id -> Vector2
var node_velocities: Dictionary = {}  # node_id -> Vector2

# Visual parameters
const BASE_NODE_SIZE = 40.0
const ENERGY_GLOW_SCALE = 3.0
const CONNECTION_BASE_WIDTH = 2.0
const REPULSION_STRENGTH = 1000.0
const ATTRACTION_STRENGTH = 0.1
const DAMPING = 0.9

func _ready():
	# Initialize node positions (circular layout initially)
	_init_node_positions()

	# Create visual elements for each node
	for node_id in conspiracy_network.nodes.keys():
		var node_sprite = NetworkNodeSprite.new()
		node_sprite.node_id = node_id
		node_sprite.position = node_positions[node_id]
		add_child(node_sprite)
		node_sprites[node_id] = node_sprite

	# Create connection lines
	for conn in conspiracy_network.connections:
		var line = ConnectionLine.new()
		line.from_id = conn["from"]
		line.to_id = conn["to"]
		line.strength = conn["strength"]
		add_child(line)
		connection_lines.append(line)

func _process(dt: float):
	# Update force-directed graph positions
	_apply_forces(dt)

	# Update visual states from network data
	for node_id in node_sprites.keys():
		var sprite = node_sprites[node_id]
		var node = conspiracy_network.nodes[node_id]

		# Position
		sprite.position = node_positions[node_id]

		# Size: scales with energy
		var energy_scale = 1.0 + (node.energy / 5.0) * ENERGY_GLOW_SCALE
		sprite.scale = Vector2.ONE * energy_scale

		# Color: temperature mapping (theta-based)
		sprite.modulate = _get_node_color(node)

		# Glow intensity
		sprite.glow_intensity = clamp(node.energy / 3.0, 0.0, 1.0)

		# Particle emission
		sprite.particle_rate = node.energy * 10.0

	# Update connection lines
	for line in connection_lines:
		var from_pos = node_positions[line.from_id]
		var to_pos = node_positions[line.to_id]
		var from_node = conspiracy_network.nodes[line.from_id]
		var to_node = conspiracy_network.nodes[line.to_id]

		# Energy flow direction (high → low)
		var energy_delta = to_node.energy - from_node.energy
		line.flow_direction = sign(energy_delta)
		line.flow_speed = abs(energy_delta) * 0.5

		# Line thickness: connection strength
		line.width = CONNECTION_BASE_WIDTH * line.strength

		# Line color: energy flow intensity
		line.modulate = _get_flow_color(energy_delta)

		line.set_points(from_pos, to_pos)

func _apply_forces(dt: float):
	"""Force-directed graph simulation"""
	# Calculate forces on each node
	var forces: Dictionary = {}
	for node_id in node_positions.keys():
		forces[node_id] = Vector2.ZERO

	# Repulsion between all nodes
	for node_a in node_positions.keys():
		for node_b in node_positions.keys():
			if node_a == node_b:
				continue
			var delta = node_positions[node_a] - node_positions[node_b]
			var dist = delta.length()
			if dist < 1.0:
				dist = 1.0
			var repulsion = delta.normalized() * REPULSION_STRENGTH / (dist * dist)
			forces[node_a] += repulsion

	# Attraction along connections
	for conn in conspiracy_network.connections:
		var from_id = conn["from"]
		var to_id = conn["to"]
		var delta = node_positions[to_id] - node_positions[from_id]
		var dist = delta.length()
		var attraction = delta.normalized() * dist * ATTRACTION_STRENGTH * conn["strength"]
		forces[from_id] += attraction
		forces[to_id] -= attraction

	# Apply forces with velocity integration
	for node_id in node_positions.keys():
		node_velocities[node_id] += forces[node_id] * dt
		node_velocities[node_id] *= DAMPING
		node_positions[node_id] += node_velocities[node_id] * dt

func _get_node_color(node: TomatoNode) -> Color:
	"""Map node theta to temperature color"""
	# theta: 0 (north) to PI (south)
	var normalized = node.theta / PI

	# Color gradient: blue (cold, 0) → white (neutral, 0.5) → red (hot, 1.0)
	if normalized < 0.5:
		# Blue to white
		var t = normalized * 2.0
		return Color(0.4, 0.6, 1.0).lerp(Color(1.0, 1.0, 1.0), t)
	else:
		# White to red
		var t = (normalized - 0.5) * 2.0
		return Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.3, 0.3), t)

func _get_flow_color(energy_delta: float) -> Color:
	"""Color based on energy flow direction and magnitude"""
	if energy_delta > 0:
		# Energy flowing TO this node (blue)
		var intensity = clamp(energy_delta / 2.0, 0.0, 1.0)
		return Color(0.3, 0.5, 1.0, 0.5 + intensity * 0.5)
	else:
		# Energy flowing FROM this node (red)
		var intensity = clamp(abs(energy_delta) / 2.0, 0.0, 1.0)
		return Color(1.0, 0.3, 0.3, 0.5 + intensity * 0.5)

func toggle_visibility():
	visible = !visible
```

#### Task 1.2: Network Node Sprite (2-3 hours)

**Create**: `UI/NetworkNodeSprite.gd`

```gdscript
class_name NetworkNodeSprite
extends Node2D

var node_id: String = ""
var glow_intensity: float = 0.0
var particle_rate: float = 0.0

@onready var label: Label = $Label
@onready var glow: Sprite2D = $GlowSprite
@onready var particles: CPUParticles2D = $Particles

func _ready():
	# Set label to emoji transform
	var node = get_conspiracy_node()
	if node:
		label.text = node.emoji_transform

	# Configure glow shader
	glow.material = ShaderMaterial.new()
	glow.material.shader = preload("res://Shaders/node_glow.gdshader")

func _process(_dt: float):
	# Update glow
	if glow.material:
		glow.material.set_shader_parameter("intensity", glow_intensity)

	# Update particle emission
	particles.emitting = particle_rate > 5.0
	particles.amount = int(particle_rate)

func get_conspiracy_node() -> TomatoNode:
	# Get from parent overlay
	var overlay = get_parent() as ConspiracyNetworkOverlay
	if overlay and overlay.conspiracy_network:
		return overlay.conspiracy_network.nodes.get(node_id)
	return null
```

#### Task 1.3: Connection Line Renderer (2-3 hours)

**Create**: `UI/ConnectionLine.gd`

```gdscript
class_name ConnectionLine
extends Line2D

var from_id: String = ""
var to_id: String = ""
var strength: float = 1.0
var flow_direction: float = 0.0  # -1, 0, or 1
var flow_speed: float = 0.0

var flow_particles: CPUParticles2D

func _ready():
	# Configure line appearance
	default_color = Color.WHITE
	width = 2.0
	antialiased = true

	# Create flow particles
	flow_particles = CPUParticles2D.new()
	flow_particles.emitting = true
	flow_particles.one_shot = false
	flow_particles.explosiveness = 0.0
	flow_particles.lifetime = 2.0
	flow_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	add_child(flow_particles)

func set_points(from_pos: Vector2, to_pos: Vector2):
	clear_points()
	add_point(from_pos)
	add_point(to_pos)

	# Update particle path
	if flow_particles:
		var emission_points = PackedVector2Array()
		# Sample 10 points along line
		for i in range(10):
			var t = i / 9.0
			emission_points.append(from_pos.lerp(to_pos, t))
		flow_particles.emission_points = emission_points

		# Set particle direction
		var direction = (to_pos - from_pos).normalized()
		if flow_direction < 0:
			direction = -direction
		flow_particles.direction = Vector3(direction.x, direction.y, 0)
		flow_particles.initial_velocity_min = flow_speed * 20.0
		flow_particles.initial_velocity_max = flow_speed * 40.0
```

---

### Part 1B: Tomato Plot Visual Encoding (6-8 hours)

#### Task 1.4: Parametric Tomato Visuals (4-5 hours)

**Modify**: `UI/PlotTile.gd` (add tomato-specific rendering)

```gdscript
# In PlotTile.gd

func update_tomato_visuals(plot: WheatPlot, conspiracy_network: TomatoConspiracyNetwork):
	"""Update visual state based on conspiracy node data"""
	if plot.plot_type != WheatPlot.PlotType.TOMATO:
		return

	if plot.conspiracy_node_id == "":
		return

	var node = conspiracy_network.get_tomato_node(plot.conspiracy_node_id)
	if not node:
		return

	# 1. Base color: encodes theta position
	var theta_normalized = node.theta / PI
	var cold_color = Color(0.4, 0.6, 1.0)  # Blue (north pole)
	var hot_color = Color(1.0, 0.3, 0.3)   # Red (south pole)
	var base_color = cold_color.lerp(hot_color, theta_normalized)
	sprite.modulate = base_color

	# 2. Glow intensity: encodes energy
	var glow_intensity = clamp(node.energy / 3.0, 0.0, 1.0)
	set_glow(glow_intensity)

	# 3. Pulsing rate: encodes phi evolution speed
	var pulse_rate = abs(node.phi) * 0.2
	set_pulse_rate(pulse_rate)

	# 4. Particle count: encodes active conspiracies
	var active_conspiracy_count = 0
	for conspiracy in node.conspiracies:
		if conspiracy_network.active_conspiracies.get(conspiracy, false):
			active_conspiracy_count += 1
	set_particle_count(active_conspiracy_count * 5)

	# 5. Border thickness: encodes Berry phase
	if node.berry_phase_enabled:
		var berry = abs(node.berry_phase)
		var border_thickness = 1.0 + (berry * 2.0)
		set_border_thickness(border_thickness)

func set_glow(intensity: float):
	# Update shader parameter or visual effect
	if glow_sprite and glow_sprite.material:
		glow_sprite.material.set_shader_parameter("intensity", intensity)

func set_pulse_rate(rate: float):
	# Update animation speed
	if animation_player:
		animation_player.speed_scale = rate

func set_particle_count(count: int):
	# Update particle system
	if particles:
		particles.amount = count

func set_border_thickness(thickness: float):
	# Update border visual
	if border_sprite:
		border_sprite.scale = Vector2.ONE * thickness
```

#### Task 1.5: Energy Flow Particles (2-3 hours)

**Create particle shader for energy visualization**

**Create**: `Shaders/energy_flow.gdshader`

```glsl
shader_type canvas_item;

uniform float flow_speed = 1.0;
uniform vec4 flow_color : source_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float energy_intensity = 1.0;

void fragment() {
	// Animated flow along UV
	float flow = fract(UV.x + TIME * flow_speed);
	float glow = smoothstep(0.4, 0.5, flow) - smoothstep(0.5, 0.6, flow);
	glow *= energy_intensity;

	COLOR = flow_color * glow;
}
```

---

### Part 1C: Icon Energy Field Visualization (4-6 hours)

#### Task 1.6: Background Icon Particle System (3-4 hours)

**Create**: `UI/IconEnergyField.gd`

```gdscript
class_name IconEnergyField
extends CPUParticles2D

## Represents Icon influence as background particle field

var icon: IconHamiltonian
var base_color: Color = Color.WHITE

func _ready():
	# Configure particle system
	emitting = true
	amount = 100
	lifetime = 3.0
	explosiveness = 0.0
	randomness = 0.5
	emission_shape = EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(500, 500, 0)

func _process(_dt: float):
	if not icon:
		return

	# Particle properties driven by Icon state
	var activation = icon.get_activation()
	var temperature = icon.get_temperature()

	# Speed: scales with temperature
	var speed_factor = temperature / 300.0
	initial_velocity_min = 20.0 * speed_factor
	initial_velocity_max = 50.0 * speed_factor

	# Size: scales with activation
	scale_amount_min = 1.0 + (activation * 4.0)
	scale_amount_max = 2.0 + (activation * 8.0)

	# Color: Icon-specific
	color = base_color
	color.a = activation  # Transparency = activation

	# Lifetime: inversely proportional to temperature
	lifetime = 2.0 / max(speed_factor, 0.5)

	# Amount: scales with activation
	amount = int(50 + activation * 150)
```

#### Task 1.7: Integrate Icon Fields into FarmView (1-2 hours)

**Modify**: `UI/FarmView.gd`

```gdscript
# In FarmView._ready()

# Create Icon energy fields (background particles)
var biotic_field = IconEnergyField.new()
biotic_field.icon = biotic_icon
biotic_field.base_color = Color(0.5, 0.9, 0.5)  # Green
biotic_field.z_index = -10  # Behind everything
add_child(biotic_field)

var chaos_field = IconEnergyField.new()
chaos_field.icon = chaos_icon
chaos_field.base_color = Color(0.9, 0.3, 0.3)  # Red
chaos_field.z_index = -10
add_child(chaos_field)

var imperium_field = IconEnergyField.new()
imperium_field.icon = imperium_icon
imperium_field.base_color = Color(0.7, 0.5, 0.9)  # Purple
imperium_field.z_index = -10
add_child(imperium_field)

# In FarmView._process()

# Update tomato plot visuals every frame
for tile in plot_tiles:
	var plot = farm_grid.get_plot(tile.grid_position)
	if plot and plot.plot_type == WheatPlot.PlotType.TOMATO:
		tile.update_tomato_visuals(plot, conspiracy_network)
```

---

### Part 1D: Network Toggle & UI Integration (2-4 hours)

#### Task 1.8: Network Overlay Toggle (1-2 hours)

**Modify**: `UI/FarmView.gd`

```gdscript
# Add member variable
var network_overlay: ConspiracyNetworkOverlay

# In _ready()
network_overlay = ConspiracyNetworkOverlay.new()
network_overlay.conspiracy_network = conspiracy_network
network_overlay.visible = false  # Hidden by default
network_overlay.z_index = 100  # Above farm grid
add_child(network_overlay)

# In _input()
func _input(event: InputEvent):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_N:
			# Toggle network overlay
			network_overlay.toggle_visibility()
			print("📊 Network overlay: %s" % ("ON" if network_overlay.visible else "OFF"))
```

#### Task 1.9: Network Info Panel (1-2 hours)

**Create**: `UI/NetworkInfoPanel.gd`

```gdscript
class_name NetworkInfoPanel
extends PanelContainer

## Shows network statistics when overlay is visible

var conspiracy_network: TomatoConspiracyNetwork

@onready var total_energy_label: Label = $VBox/TotalEnergy
@onready var active_conspiracies_label: Label = $VBox/ActiveConspiracies
@onready var hottest_node_label: Label = $VBox/HottestNode

func _process(_dt: float):
	if not conspiracy_network:
		return

	# Total network energy
	var total = conspiracy_network.get_total_energy()
	total_energy_label.text = "Total Energy: %.1f" % total

	# Active conspiracy count
	var active_count = conspiracy_network.active_conspiracies.size()
	active_conspiracies_label.text = "Active Conspiracies: %d" % active_count

	# Find hottest node
	var hottest_id = ""
	var max_energy = 0.0
	for node_id in conspiracy_network.nodes.keys():
		var node = conspiracy_network.nodes[node_id]
		if node.energy > max_energy:
			max_energy = node.energy
			hottest_id = node_id

	if hottest_id != "":
		var node = conspiracy_network.nodes[hottest_id]
		hottest_node_label.text = "Hottest: %s (%.1f)" % [node.emoji_transform, max_energy]
```

---

## Phase 1 Summary Checklist

**Part 1A: Network Overlay** (8-12 hours)
- [ ] Create `ConspiracyNetworkOverlay.gd` with force-directed graph
- [ ] Create `NetworkNodeSprite.gd` for node visualization
- [ ] Create `ConnectionLine.gd` for energy flow lines
- [ ] Implement force-directed layout algorithm
- [ ] Map node energy → visual size/glow
- [ ] Map energy flow → line color/particles

**Part 1B: Tomato Visuals** (6-8 hours)
- [ ] Add `update_tomato_visuals()` to PlotTile
- [ ] Map node theta → tomato color
- [ ] Map node energy → glow intensity
- [ ] Map phi evolution → pulse rate
- [ ] Map conspiracies → particle count
- [ ] Create energy flow shader

**Part 1C: Icon Fields** (4-6 hours)
- [ ] Create `IconEnergyField.gd` particle system
- [ ] Map activation → particle count
- [ ] Map temperature → particle speed
- [ ] Add three Icon fields to FarmView
- [ ] Color code: green (Biotic), red (Chaos), purple (Imperium)

**Part 1D: UI Integration** (2-4 hours)
- [ ] Add KEY_N toggle for network overlay
- [ ] Create NetworkInfoPanel
- [ ] Show total energy, active conspiracies, hottest node
- [ ] Test all visual systems together

**Phase 1 Result:**
Press `N` → See 12-node conspiracy network as force-directed graph with energy flowing between nodes. Tomato plots change color/glow based on their conspiracy node. Background particles show Icon influence. **The invisible becomes visible.**

---

## Phase 2: Simplified Fun Mechanics (Proposal D)
**Goal**: 3 conspiracy archetypes instead of 24, quick strategic decisions
**Effort**: 9-13 hours
**Status**: AFTER PHASE 1

---

### Part 2A: Three Conspiracy Archetypes (4-6 hours)

#### Task 2.1: Conspiracy Type System

**Create**: `Core/QuantumSubstrate/ConspiracyArchetype.gd`

```gdscript
class_name ConspiracyArchetype
extends Resource

enum Type {
	GROWTH,   # Order, predictability, enhancement
	CHAOS,    # Transformation, unpredictability, mutation
	TEMPORAL  # Time-related, optimal windows, timing
}

@export var type: Type
@export var name: String
@export var description: String
@export var activation_threshold: float = 1.0

# Which nodes contribute to this archetype
@export var contributing_nodes: Array[String] = []

func get_total_energy(conspiracy_network: TomatoConspiracyNetwork) -> float:
	"""Sum energy from all contributing nodes"""
	var total = 0.0
	for node_id in contributing_nodes:
		var node = conspiracy_network.get_tomato_node(node_id)
		if node:
			total += node.energy
	return total

func is_active(conspiracy_network: TomatoConspiracyNetwork) -> bool:
	return get_total_energy(conspiracy_network) > activation_threshold

func get_activation_percentage(conspiracy_network: TomatoConspiracyNetwork) -> float:
	return clamp(get_total_energy(conspiracy_network) / activation_threshold, 0.0, 1.0)
```

#### Task 2.2: Define Three Archetypes

**Modify**: `Core/QuantumSubstrate/TomatoConspiracyNetwork.gd`

```gdscript
# Add to TomatoConspiracyNetwork

var archetypes: Dictionary = {}  # Type -> ConspiracyArchetype

func _ready():
	_create_12_nodes()
	_create_15_connections()
	_create_archetypes()
	print("🍅 TomatoConspiracyNetwork initialized")

func _create_archetypes():
	# GROWTH Archetype (Order, Enhancement)
	var growth = ConspiracyArchetype.new()
	growth.type = ConspiracyArchetype.Type.GROWTH
	growth.name = "Growth Conspiracy"
	growth.description = "Nearby wheat grows faster, yields are higher"
	growth.activation_threshold = 8.0
	growth.contributing_nodes = ["seed", "solar", "water", "genetic"]
	archetypes[ConspiracyArchetype.Type.GROWTH] = growth

	# CHAOS Archetype (Transformation, Unpredictability)
	var chaos = ConspiracyArchetype.new()
	chaos.type = ConspiracyArchetype.Type.CHAOS
	chaos.name = "Chaos Conspiracy"
	chaos.description = "Unpredictable yields, high risk, high reward"
	chaos.activation_threshold = 6.0
	chaos.contributing_nodes = ["meta", "identity", "underground", "sauce"]
	archetypes[ConspiracyArchetype.Type.CHAOS] = chaos

	# TEMPORAL Archetype (Time, Windows, Timing)
	var temporal = ConspiracyArchetype.new()
	temporal.type = ConspiracyArchetype.Type.TEMPORAL
	temporal.name = "Temporal Conspiracy"
	temporal.description = "Optimal harvest windows appear, timing matters"
	temporal.activation_threshold = 7.0
	temporal.contributing_nodes = ["ripening", "market", "observer", "meaning"]
	archetypes[ConspiracyArchetype.Type.TEMPORAL] = temporal

func get_archetype(type: ConspiracyArchetype.Type) -> ConspiracyArchetype:
	return archetypes.get(type)
```

---

### Part 2B: Archetype Effects on Gameplay (3-5 hours)

#### Task 2.3: Growth Conspiracy Effect

**Modify**: `Core/GameMechanics/WheatPlot.gd`

```gdscript
func grow(delta: float, conspiracy_network = null) -> float:
	# ... existing growth code ...

	# Growth conspiracy bonus
	if conspiracy_network:
		var growth_archetype = conspiracy_network.get_archetype(ConspiracyArchetype.Type.GROWTH)
		if growth_archetype and growth_archetype.is_active(conspiracy_network):
			# Check if this plot is near a tomato
			if is_near_tomato():
				var bonus = growth_archetype.get_activation_percentage(conspiracy_network)
				growth_rate *= (1.0 + bonus)  # Up to 2x growth

				# Visual feedback
				if int(growth_progress * 100) % 20 == 0:
					print("🌱 Growth conspiracy boosting wheat at %s" % plot_id)

	# ... rest of function ...

func is_near_tomato() -> bool:
	# Check if any tomato within 2 tiles
	# (Implementation depends on grid access)
	return false  # Placeholder
```

#### Task 2.4: Chaos Conspiracy Effect

```gdscript
# In WheatPlot.gd

func harvest(conspiracy_network = null) -> Dictionary:
	# ... existing harvest code ...

	var base_yield = 10.0 * growth_progress
	var final_yield = base_yield

	# Chaos conspiracy effect
	if conspiracy_network:
		var chaos_archetype = conspiracy_network.get_archetype(ConspiracyArchetype.Type.CHAOS)
		if chaos_archetype and chaos_archetype.is_active(conspiracy_network):
			if is_near_tomato():
				# High variance: 0.5x to 2.5x multiplier
				var activation = chaos_archetype.get_activation_percentage(conspiracy_network)
				var variance = activation * 2.0  # 0 to 2.0
				var multiplier = randf_range(1.0 - variance * 0.5, 1.0 + variance * 1.5)
				final_yield *= multiplier

				print("🌀 Chaos conspiracy: %.1fx yield modifier" % multiplier)

	# ... rest of function ...
```

#### Task 2.5: Temporal Conspiracy Effect

```gdscript
# In PlotTile.gd

func _process(_dt: float):
	# ... existing code ...

	# Show optimal harvest window for temporal conspiracy
	if plot and plot.plot_type == WheatPlot.PlotType.WHEAT:
		if conspiracy_network:
			var temporal = conspiracy_network.get_archetype(ConspiracyArchetype.Type.TEMPORAL)
			if temporal and temporal.is_active(conspiracy_network):
				if plot.growth_progress > 0.8 and plot.growth_progress < 0.95:
					# OPTIMAL WINDOW
					show_optimal_indicator()
				else:
					hide_optimal_indicator()

func show_optimal_indicator():
	# Golden ring around plot
	if not has_node("OptimalRing"):
		var ring = Sprite2D.new()
		ring.name = "OptimalRing"
		ring.texture = preload("res://Assets/optimal_ring.png")
		ring.modulate = Color(1.0, 0.9, 0.3)
		add_child(ring)

func hide_optimal_indicator():
	if has_node("OptimalRing"):
		get_node("OptimalRing").queue_free()
```

---

### Part 2C: Simplified Network Visualization (2-3 hours)

#### Task 2.6: Three Mega-Node Display

**Modify**: `UI/ConspiracyNetworkOverlay.gd`

```gdscript
# Add simplified mode

var simplified_mode: bool = true  # Toggle with Shift+N

func _process(dt: float):
	if simplified_mode:
		_update_simplified_view(dt)
	else:
		_update_full_view(dt)  # Original 12-node view

func _update_simplified_view(dt: float):
	# Show 3 mega-nodes instead of 12
	# Each mega-node represents an archetype cluster

	# Position mega-nodes in triangle
	var center = Vector2(400, 300)
	var radius = 200.0

	var growth_pos = center + Vector2(0, -radius)
	var chaos_pos = center + Vector2(radius * 0.866, radius * 0.5)
	var temporal_pos = center + Vector2(-radius * 0.866, radius * 0.5)

	# Update mega-node visuals
	growth_mega_node.position = growth_pos
	growth_mega_node.update_from_archetype(
		conspiracy_network.get_archetype(ConspiracyArchetype.Type.GROWTH)
	)

	# Similar for chaos and temporal...

	# Draw energy flows between mega-nodes
	# (Energy exchanges between archetype clusters)
```

---

### Part 2D: UI Indicators (2-3 hours)

#### Task 2.7: Archetype Status Panel

**Create**: `UI/ArchetypeStatusPanel.gd`

```gdscript
class_name ArchetypeStatusPanel
extends VBoxContainer

var conspiracy_network: TomatoConspiracyNetwork

func _process(_dt: float):
	if not conspiracy_network:
		return

	# Update three archetype indicators
	var growth = conspiracy_network.get_archetype(ConspiracyArchetype.Type.GROWTH)
	var chaos = conspiracy_network.get_archetype(ConspiracyArchetype.Type.CHAOS)
	var temporal = conspiracy_network.get_archetype(ConspiracyArchetype.Type.TEMPORAL)

	$Growth/Label.text = "🌱 Growth: %d%%" % (growth.get_activation_percentage(conspiracy_network) * 100)
	$Growth/Bar.value = growth.get_activation_percentage(conspiracy_network)
	$Growth/Status.text = "ACTIVE" if growth.is_active(conspiracy_network) else "inactive"

	# Similar for chaos and temporal...
```

---

## Phase 2 Summary Checklist

**Part 2A: Archetypes** (4-6 hours)
- [ ] Create `ConspiracyArchetype.gd` class
- [ ] Define 3 archetypes (Growth, Chaos, Temporal)
- [ ] Map 12 nodes to 3 archetype clusters
- [ ] Calculate archetype activation from node energy

**Part 2B: Effects** (3-5 hours)
- [ ] Growth: 2x wheat growth near tomatoes
- [ ] Chaos: High variance yields (0.5x to 2.5x)
- [ ] Temporal: Optimal harvest windows appear
- [ ] Visual feedback for each effect

**Part 2C: Simplified View** (2-3 hours)
- [ ] 3 mega-nodes instead of 12
- [ ] Triangle layout (readable at a glance)
- [ ] Energy flows between clusters
- [ ] Toggle: N = full view, Shift+N = simplified

**Part 2D: UI** (2-3 hours)
- [ ] Archetype status panel (3 progress bars)
- [ ] Active/inactive indicators
- [ ] Percentage displays

**Phase 2 Result:**
Players see 3 conspiracy types instead of 24. Each has clear, immediate gameplay effects. Simplified network visualization shows archetype clusters. Strategic depth without overwhelming complexity.

---

## Phase 3: Minimal Chaos (Proposal A) - OPTIONAL
**Goal**: Discovery mechanics, collectibles, kid-friendly effects
**Effort**: 8-16 hours
**Status**: ONLY AFTER PHASE 2

This phase would add:
- Conspiracy Codex (achievement system)
- "???" discovery mechanic
- More playful visual effects
- Simpler explanations for kids

**Decision point:** Only pursue if Phase 1+2 needs more "game feel."

---

## Testing Strategy

### Phase 1 Testing
1. **Visual verification**: Run game, press N, see network
2. **Energy flow**: Plant tomatoes, watch node energy change
3. **Icon fields**: Plant wheat/tomatoes, see background particles
4. **Force-directed graph**: Verify nodes settle into readable layout
5. **Parametric visuals**: Check tomato color matches node theta

### Phase 2 Testing
1. **Growth effect**: Plant tomato + wheat, verify 2x growth
2. **Chaos effect**: Harvest near tomato, verify variable yields
3. **Temporal effect**: Watch for golden ring at optimal window
4. **Archetype UI**: Verify percentages match network state
5. **Simplified view**: Toggle with Shift+N, verify 3 mega-nodes

---

## Implementation Timeline

### Week 1 (Phase 1)
- **Days 1-2**: Part 1A (Network Overlay) - 8-12 hours
- **Days 3-4**: Part 1B (Tomato Visuals) - 6-8 hours
- **Day 5**: Part 1C (Icon Fields) - 4-6 hours
- **Day 6**: Part 1D (UI Integration) - 2-4 hours
- **Day 7**: Testing & polish

**Deliverable**: Press N to see living, breathing conspiracy network with energy flowing through force-directed graph.

### Week 2 (Phase 2)
- **Days 1-2**: Part 2A (Archetypes) - 4-6 hours
- **Days 3-4**: Part 2B (Effects) - 3-5 hours
- **Day 5**: Part 2C (Simplified View) - 2-3 hours
- **Day 6**: Part 2D (UI) - 2-3 hours
- **Day 7**: Testing & balance

**Deliverable**: 3 conspiracy types with clear gameplay effects. Tomatoes finally matter strategically.

### Week 3+ (Phase 3 - Optional)
- Proposal A features if needed
- Polish and refinement
- Additional effects

---

## Success Criteria

### Phase 1 Complete When:
- ✅ Press N → See 12-node network
- ✅ Nodes glow brighter when energy is high
- ✅ Energy flows visible along connection lines
- ✅ Tomato colors change with node theta
- ✅ Background particles show Icon influence
- ✅ Force-directed layout is readable

### Phase 2 Complete When:
- ✅ Growth conspiracy visibly speeds wheat growth
- ✅ Chaos conspiracy creates variable yields (player notices)
- ✅ Temporal conspiracy shows golden harvest rings
- ✅ UI shows 3 archetype percentages accurately
- ✅ Simplified view (Shift+N) shows 3 mega-nodes
- ✅ Player understands: "Tomatoes affect wheat"

---

## Key Implementation Notes

### Force-Directed Graph
- Use repulsion between all nodes (inverse square)
- Use attraction along connections (Hooke's law)
- Damping prevents oscillation
- Stable layout within 2-3 seconds

### Visual Encoding Strategy
- **Color**: Temperature (theta-based)
- **Size**: Energy (node.energy)
- **Glow**: Activation (conspiracy active?)
- **Motion**: Evolution (phi velocity)
- **Particles**: Network activity

### Performance Considerations
- Network overlay only renders when visible (toggle with N)
- Particle systems use CPU particles (lightweight)
- Force-directed updates at 60fps (cheap physics)
- Shader effects for glow (GPU efficient)

---

## What This Achieves

### Proposal B Goals
✅ Energy flows visible through force-directed graph
✅ "Liquid neural net" aesthetic
✅ Makes invisible quantum mechanics tangible
✅ Physics accuracy: 9/10
✅ Visually stunning

### Proposal D Goals
✅ Simplified to 3 archetypes (not overwhelming)
✅ Clear gameplay effects (growth, chaos, timing)
✅ Quick strategic decisions
✅ Fun: 8/10, accessible

### User's Vision
✅ "See energy flows in base layer via force-directed graph" - **PRIMARY FOCUS**
✅ "Get it fun with less first" - **Simplified archetypes**
✅ "Zero waste, zero filler" - **Every visual = data**

---

Let's make the invisible conspiracy network **beautifully visible**. 🍅⚛️📊
