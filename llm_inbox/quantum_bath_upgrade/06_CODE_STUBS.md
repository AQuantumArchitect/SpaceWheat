# Code Stubs
## GDScript Implementation Reference

---

## File: Core/QuantumSubstrate/Complex.gd

```gdscript
class_name Complex
extends RefCounted

## Complex number representation for quantum amplitudes

var re: float = 0.0
var im: float = 0.0

func _init(real: float = 0.0, imag: float = 0.0):
	re = real
	im = imag

## Magnitude squared: |z|² = re² + im²
func abs_sq() -> float:
	return re * re + im * im

## Magnitude: |z| = √(re² + im²)
func abs() -> float:
	return sqrt(abs_sq())

## Phase angle: arg(z) = atan2(im, re)
func arg() -> float:
	return atan2(im, re)

## Complex conjugate: z* = re - i·im
func conjugate() -> Complex:
	return Complex.new(re, -im)

## Addition: z1 + z2
func add(other: Complex) -> Complex:
	return Complex.new(re + other.re, im + other.im)

## Subtraction: z1 - z2
func sub(other: Complex) -> Complex:
	return Complex.new(re - other.re, im - other.im)

## Multiplication: z1 × z2 = (a+bi)(c+di) = (ac-bd) + (ad+bc)i
func mul(other: Complex) -> Complex:
	return Complex.new(
		re * other.re - im * other.im,
		re * other.im + im * other.re
	)

## Division: z1 / z2
func div(other: Complex) -> Complex:
	var denom = other.abs_sq()
	if denom < 1e-20:
		push_error("Complex division by zero")
		return Complex.new(0, 0)
	var conj = other.conjugate()
	var num = mul(conj)
	return Complex.new(num.re / denom, num.im / denom)

## Scalar multiplication: s × z
func scale(s: float) -> Complex:
	return Complex.new(re * s, im * s)

## Create from polar coordinates: r × e^(iθ) = r(cos θ + i sin θ)
static func from_polar(r: float, theta: float) -> Complex:
	return Complex.new(r * cos(theta), r * sin(theta))

## Imaginary unit: i
static func i() -> Complex:
	return Complex.new(0.0, 1.0)

## Zero
static func zero() -> Complex:
	return Complex.new(0.0, 0.0)

## One
static func one() -> Complex:
	return Complex.new(1.0, 0.0)

## String representation
func _to_string() -> String:
	if abs(im) < 1e-10:
		return "%.4f" % re
	elif abs(re) < 1e-10:
		return "%.4fi" % im
	elif im >= 0:
		return "%.4f+%.4fi" % [re, im]
	else:
		return "%.4f%.4fi" % [re, im]

## Equality check with tolerance
func equals(other: Complex, tolerance: float = 1e-10) -> bool:
	return abs(re - other.re) < tolerance and abs(im - other.im) < tolerance
```

---

## File: Core/QuantumSubstrate/Icon.gd

```gdscript
class_name Icon
extends Resource

## Icon: The eternal Hamiltonian attached to an emoji
## Defines how this emoji interacts with others in any biome

## Identity
@export var emoji: String = ""
@export var display_name: String = ""
@export var description: String = ""

## Hamiltonian Terms (Unitary Evolution)
## Self-energy: diagonal term H[i,i] - natural frequency
@export var self_energy: float = 0.0

## Couplings: off-diagonal terms H[i,j]
## Key = target emoji, Value = coupling strength (real, will be symmetrized)
@export var hamiltonian_couplings: Dictionary = {}

## Time-dependent self-energy
@export var self_energy_driver: String = ""  # "cosine", "sine", "pulse", or ""
@export var driver_frequency: float = 0.0    # Hz
@export var driver_phase: float = 0.0        # Radians
@export var driver_amplitude: float = 1.0    # Multiplier

## Lindblad Terms (Dissipative Evolution)
## Outgoing transfers: this emoji loses amplitude to target
## Key = target emoji, Value = transfer rate γ
@export var lindblad_outgoing: Dictionary = {}

## Incoming transfers: this emoji gains amplitude from source
## (Syntactic sugar - will be converted to source's outgoing)
@export var lindblad_incoming: Dictionary = {}

## Self-decay: amplitude leaks to decay_target
@export var decay_rate: float = 0.0
@export var decay_target: String = "🍂"

## Metadata
@export var trophic_level: int = 0  # 0=abiotic, 1=producer, 2=consumer, 3=predator
@export var tags: Array[String] = []

## Special flags
@export var is_driver: bool = false      # External forcing (like sun)
@export var is_adaptive: bool = false    # Dynamically changes (like tomato)
@export var is_eternal: bool = false     # Never decays

## Get effective self-energy at given time
func get_self_energy(time: float) -> float:
	var base = self_energy
	
	match self_energy_driver:
		"cosine":
			return base * driver_amplitude * cos(driver_frequency * time * TAU + driver_phase)
		"sine":
			return base * driver_amplitude * sin(driver_frequency * time * TAU + driver_phase)
		"pulse":
			var phase = fmod(driver_frequency * time + driver_phase / TAU, 1.0)
			return base * driver_amplitude if phase < 0.5 else 0.0
		_:
			return base

## Get all emojis this icon couples to (for building bath)
func get_coupled_emojis() -> Array[String]:
	var result: Array[String] = []
	for e in hamiltonian_couplings.keys():
		if not result.has(e):
			result.append(e)
	for e in lindblad_outgoing.keys():
		if not result.has(e):
			result.append(e)
	for e in lindblad_incoming.keys():
		if not result.has(e):
			result.append(e)
	if decay_rate > 0 and decay_target and not result.has(decay_target):
		result.append(decay_target)
	return result

## Create a simple icon with just couplings
static func create_simple(emoji_str: String, couplings: Dictionary = {}, transfers: Dictionary = {}) -> Icon:
	var icon = Icon.new()
	icon.emoji = emoji_str
	icon.display_name = emoji_str
	icon.hamiltonian_couplings = couplings
	icon.lindblad_outgoing = transfers
	return icon
```

---

## File: Core/QuantumSubstrate/IconRegistry.gd

```gdscript
extends Node

## IconRegistry: Singleton holding all icon definitions
## Autoload as "IconRegistry"

var icons: Dictionary = {}  # emoji → Icon

func _ready():
	_load_builtin_icons()

## Register an icon
func register_icon(icon: Icon) -> void:
	if icon.emoji.is_empty():
		push_error("Cannot register icon with empty emoji")
		return
	icons[icon.emoji] = icon
	print("📜 Registered Icon: %s (%s)" % [icon.emoji, icon.display_name])

## Get icon for emoji (returns null if not found)
func get_icon(emoji: String) -> Icon:
	return icons.get(emoji, null)

## Check if icon exists
func has_icon(emoji: String) -> bool:
	return icons.has(emoji)

## Get all registered emojis
func get_all_emojis() -> Array[String]:
	var result: Array[String] = []
	for e in icons.keys():
		result.append(e)
	return result

## Get icons by tag
func get_icons_by_tag(tag: String) -> Array[Icon]:
	var result: Array[Icon] = []
	for icon in icons.values():
		if icon.tags.has(tag):
			result.append(icon)
	return result

## Clear all icons (for testing)
func clear() -> void:
	icons.clear()

## Load built-in icon definitions
func _load_builtin_icons() -> void:
	# Will be populated with CoreIcons.register_all()
	pass

## Derive icons from a Markov chain
func derive_from_markov(markov: Dictionary, hamiltonian_scale: float = 0.5, lindblad_scale: float = 0.3) -> void:
	for source in markov:
		var icon = Icon.new()
		icon.emoji = source
		icon.display_name = source
		
		var transitions = markov[source]
		
		for target in transitions:
			var prob = transitions[target]
			
			# Check for reverse transition
			var reverse = 0.0
			if markov.has(target) and markov[target].has(source):
				reverse = markov[target][source]
			
			# Symmetric part → Hamiltonian coupling
			var symmetric = (prob + reverse) / 2.0
			if symmetric > 0.01:
				icon.hamiltonian_couplings[target] = symmetric * hamiltonian_scale
			
			# Asymmetric part → Lindblad transfer
			var asymmetric = prob - symmetric
			if asymmetric > 0.01:
				icon.lindblad_outgoing[target] = asymmetric * lindblad_scale
		
		register_icon(icon)
```

---

## File: Core/QuantumSubstrate/QuantumBath.gd

```gdscript
class_name QuantumBath
extends RefCounted

## QuantumBath: The quantum state of a biome
## A superposition over all emoji states that evolves via Hamiltonian + Lindblad

signal bath_evolved()
signal bath_measured(north: String, south: String, outcome: String)

## State representation
var amplitudes: Array[Complex] = []
var emoji_list: Array[String] = []
var emoji_to_index: Dictionary = {}

## Operators (built from Icons)
var hamiltonian_sparse: Dictionary = {}  # {i: {j: Complex}}
var lindblad_terms: Array[Dictionary] = []  # [{source_idx, target_idx, rate}]

## Time tracking
var bath_time: float = 0.0

## Cached Icons
var active_icons: Array[Icon] = []
var operators_dirty: bool = true

## Initialize with a list of emojis
func initialize_with_emojis(emojis: Array) -> void:
	emoji_list.clear()
	emoji_to_index.clear()
	amplitudes.clear()
	
	for i in range(emojis.size()):
		var emoji = emojis[i]
		emoji_list.append(emoji)
		emoji_to_index[emoji] = i
		amplitudes.append(Complex.zero())
	
	operators_dirty = true

## Initialize with uniform superposition
func initialize_uniform() -> void:
	var n = amplitudes.size()
	if n == 0:
		return
	var amp = 1.0 / sqrt(float(n))
	for i in range(n):
		amplitudes[i] = Complex.new(amp, 0.0)

## Initialize with weighted probabilities
func initialize_weighted(weights: Dictionary) -> void:
	var total = 0.0
	for emoji in emoji_list:
		var w = weights.get(emoji, 0.0)
		total += w
	
	if total < 1e-10:
		initialize_uniform()
		return
	
	for i in range(emoji_list.size()):
		var emoji = emoji_list[i]
		var w = weights.get(emoji, 0.0)
		amplitudes[i] = Complex.new(sqrt(w / total), 0.0)

## Get amplitude for an emoji
func get_amplitude(emoji: String) -> Complex:
	var idx = emoji_to_index.get(emoji, -1)
	if idx < 0:
		return Complex.zero()
	return amplitudes[idx]

## Get probability for an emoji
func get_probability(emoji: String) -> float:
	return get_amplitude(emoji).abs_sq()

## Get total probability (should be 1.0)
func get_total_probability() -> float:
	var total = 0.0
	for amp in amplitudes:
		total += amp.abs_sq()
	return total

## Normalize the bath state
func normalize() -> void:
	var total = get_total_probability()
	if total < 1e-20:
		push_error("Bath has zero amplitude - cannot normalize")
		return
	var scale = 1.0 / sqrt(total)
	for i in range(amplitudes.size()):
		amplitudes[i] = amplitudes[i].scale(scale)

## Build Hamiltonian from Icons
func build_hamiltonian_from_icons(icons: Array) -> void:
	active_icons.clear()
	for icon in icons:
		if icon is Icon:
			active_icons.append(icon)
	
	hamiltonian_sparse.clear()
	var n = emoji_list.size()
	
	for icon in active_icons:
		var i = emoji_to_index.get(icon.emoji, -1)
		if i < 0:
			continue
		
		# Self-energy (diagonal)
		if not hamiltonian_sparse.has(i):
			hamiltonian_sparse[i] = {}
		var self_e = icon.get_self_energy(bath_time)
		if hamiltonian_sparse[i].has(i):
			hamiltonian_sparse[i][i] = hamiltonian_sparse[i][i].add(Complex.new(self_e, 0))
		else:
			hamiltonian_sparse[i][i] = Complex.new(self_e, 0)
		
		# Off-diagonal couplings
		for target_emoji in icon.hamiltonian_couplings:
			var j = emoji_to_index.get(target_emoji, -1)
			if j < 0:
				continue
			
			var coupling = icon.hamiltonian_couplings[target_emoji]
			var c = Complex.new(coupling * 0.5, 0)  # Symmetrize
			
			# H[i][j]
			if not hamiltonian_sparse.has(i):
				hamiltonian_sparse[i] = {}
			if hamiltonian_sparse[i].has(j):
				hamiltonian_sparse[i][j] = hamiltonian_sparse[i][j].add(c)
			else:
				hamiltonian_sparse[i][j] = c
			
			# H[j][i] (Hermitian)
			if not hamiltonian_sparse.has(j):
				hamiltonian_sparse[j] = {}
			if hamiltonian_sparse[j].has(i):
				hamiltonian_sparse[j][i] = hamiltonian_sparse[j][i].add(c.conjugate())
			else:
				hamiltonian_sparse[j][i] = c.conjugate()
	
	operators_dirty = false

## Build Lindblad terms from Icons
func build_lindblad_from_icons(icons: Array) -> void:
	lindblad_terms.clear()
	
	for icon in icons:
		if not icon is Icon:
			continue
		
		var source_idx = emoji_to_index.get(icon.emoji, -1)
		if source_idx < 0:
			continue
		
		# Outgoing transfers
		for target_emoji in icon.lindblad_outgoing:
			var target_idx = emoji_to_index.get(target_emoji, -1)
			if target_idx < 0:
				continue
			var rate = icon.lindblad_outgoing[target_emoji]
			if rate > 0:
				lindblad_terms.append({
					"source": source_idx,
					"target": target_idx,
					"rate": rate
				})
		
		# Decay
		if icon.decay_rate > 0:
			var decay_idx = emoji_to_index.get(icon.decay_target, -1)
			if decay_idx >= 0:
				lindblad_terms.append({
					"source": source_idx,
					"target": decay_idx,
					"rate": icon.decay_rate
				})

## Evolve Hamiltonian (unitary part)
func evolve_hamiltonian(dt: float) -> void:
	var n = amplitudes.size()
	var new_amps: Array[Complex] = []
	
	# Initialize with current amplitudes
	for i in range(n):
		new_amps.append(amplitudes[i])
	
	# Apply -i H dt
	for i in hamiltonian_sparse:
		for j in hamiltonian_sparse[i]:
			var H_ij: Complex = hamiltonian_sparse[i][j]
			# -i * H_ij * dt * psi_j
			var contrib = Complex.i().scale(-1.0).mul(H_ij).mul(amplitudes[j]).scale(dt)
			new_amps[i] = new_amps[i].add(contrib)
	
	amplitudes = new_amps

## Evolve Lindblad (dissipative part)
func evolve_lindblad(dt: float) -> void:
	for term in lindblad_terms:
		var s = term.source
		var t = term.target
		var rate = term.rate
		
		# Transfer: √(γ dt) of source amplitude goes to target
		var transfer_factor = sqrt(rate * dt)
		var decay_factor = sqrt(1.0 - rate * dt)
		
		var transfer = amplitudes[s].scale(transfer_factor)
		amplitudes[t] = amplitudes[t].add(transfer)
		amplitudes[s] = amplitudes[s].scale(decay_factor)

## Update time-dependent Hamiltonian terms
func update_time_dependent() -> void:
	for icon in active_icons:
		if icon.self_energy_driver.is_empty():
			continue
		
		var i = emoji_to_index.get(icon.emoji, -1)
		if i < 0:
			continue
		
		var self_e = icon.get_self_energy(bath_time)
		if not hamiltonian_sparse.has(i):
			hamiltonian_sparse[i] = {}
		hamiltonian_sparse[i][i] = Complex.new(self_e, 0)

## Full evolution step
func evolve(dt: float) -> void:
	bath_time += dt
	
	# Update time-dependent terms
	update_time_dependent()
	
	# Hamiltonian evolution
	evolve_hamiltonian(dt)
	
	# Lindblad evolution
	evolve_lindblad(dt)
	
	# Renormalize
	normalize()
	
	bath_evolved.emit()

## Project onto a two-emoji axis
func project_onto_axis(north: String, south: String) -> Dictionary:
	var amp_n = get_amplitude(north)
	var amp_s = get_amplitude(south)
	
	var prob_n = amp_n.abs_sq()
	var prob_s = amp_s.abs_sq()
	var total = prob_n + prob_s
	
	if total < 1e-10:
		return {
			"radius": 0.0,
			"theta": PI / 2.0,
			"phi": 0.0,
			"valid": false
		}
	
	var radius = sqrt(total)
	var theta = 2.0 * acos(clamp(amp_n.abs() / radius, 0.0, 1.0))
	var phi = amp_n.arg() - amp_s.arg()
	
	# Wrap phi to [0, 2π)
	while phi < 0:
		phi += TAU
	while phi >= TAU:
		phi -= TAU
	
	return {
		"radius": radius,
		"theta": theta,
		"phi": phi,
		"valid": true
	}

## Partial collapse toward an emoji
func partial_collapse(emoji: String, strength: float) -> void:
	var idx = emoji_to_index.get(emoji, -1)
	if idx < 0:
		return
	
	# Amplify measured state
	amplitudes[idx] = amplitudes[idx].scale(1.0 + strength)
	
	# Slightly dampen others
	var damping = strength * 0.1
	for i in range(amplitudes.size()):
		if i != idx:
			amplitudes[i] = amplitudes[i].scale(1.0 - damping)
	
	normalize()

## Measure along an axis (Born rule + partial collapse)
func measure_axis(north: String, south: String, collapse_strength: float = 0.5) -> String:
	var amp_n = get_amplitude(north)
	var amp_s = get_amplitude(south)
	
	var prob_n = amp_n.abs_sq()
	var prob_s = amp_s.abs_sq()
	var total = prob_n + prob_s
	
	if total < 1e-10:
		return ""
	
	var outcome: String
	if randf() < prob_n / total:
		outcome = north
		partial_collapse(north, collapse_strength)
	else:
		outcome = south
		partial_collapse(south, collapse_strength)
	
	bath_measured.emit(north, south, outcome)
	return outcome

## Get full probability distribution
func get_probability_distribution() -> Dictionary:
	var dist = {}
	for i in range(emoji_list.size()):
		dist[emoji_list[i]] = amplitudes[i].abs_sq()
	return dist

## Debug: Print current state
func debug_print() -> void:
	print("=== QuantumBath State ===")
	print("Time: %.2f" % bath_time)
	print("Total probability: %.4f" % get_total_probability())
	for i in range(emoji_list.size()):
		var emoji = emoji_list[i]
		var amp = amplitudes[i]
		var prob = amp.abs_sq()
		if prob > 0.001:
			print("  %s: %s (p=%.3f)" % [emoji, amp, prob])
```

---

## File: Core/Icons/CoreIcons.gd

```gdscript
class_name CoreIcons

## Core icon definitions for SpaceWheat

static func register_all() -> void:
	_register_celestial()
	_register_flora()
	_register_fauna()
	_register_elements()
	_register_abstract()

static func _register_celestial() -> void:
	# Sun - primary driver
	var sun = Icon.new()
	sun.emoji = "☀"
	sun.display_name = "Sol"
	sun.description = "The eternal light that drives all life"
	sun.self_energy = 1.0
	sun.self_energy_driver = "cosine"
	sun.driver_frequency = 0.05
	sun.driver_amplitude = 1.0
	sun.hamiltonian_couplings = {"🌙": 0.8, "🌿": 0.3, "🌾": 0.4, "🌱": 0.2}
	sun.tags = ["celestial", "driver", "light"]
	sun.is_driver = true
	sun.is_eternal = true
	IconRegistry.register_icon(sun)
	
	# Moon - night driver
	var moon = Icon.new()
	moon.emoji = "🌙"
	moon.display_name = "Luna"
	moon.description = "The silver light that nurtures the hidden"
	moon.self_energy = 0.5
	moon.self_energy_driver = "cosine"
	moon.driver_frequency = 0.05
	moon.driver_phase = PI
	moon.hamiltonian_couplings = {"☀": 0.8, "🍄": 0.5}
	moon.tags = ["celestial", "driver", "night"]
	moon.is_driver = true
	moon.is_eternal = true
	IconRegistry.register_icon(moon)

static func _register_flora() -> void:
	# Wheat
	var wheat = Icon.new()
	wheat.emoji = "🌾"
	wheat.display_name = "Golden Grain"
	wheat.self_energy = 0.1
	wheat.hamiltonian_couplings = {"☀": 0.5, "💧": 0.2}
	wheat.lindblad_incoming = {"☀": 0.15}
	wheat.decay_rate = 0.01
	wheat.decay_target = "💀"
	wheat.trophic_level = 1
	wheat.tags = ["flora", "crop", "producer"]
	IconRegistry.register_icon(wheat)
	
	# Mushroom
	var mushroom = Icon.new()
	mushroom.emoji = "🍄"
	mushroom.display_name = "Moonshroom"
	mushroom.self_energy = 0.05
	mushroom.hamiltonian_couplings = {"🌙": 0.6, "🍂": 0.3}
	mushroom.lindblad_incoming = {"🌙": 0.1, "🍂": 0.08}
	mushroom.decay_rate = 0.02
	mushroom.trophic_level = 1
	mushroom.tags = ["flora", "fungus", "decomposer", "night"]
	IconRegistry.register_icon(mushroom)
	
	# Vegetation
	var vegetation = Icon.new()
	vegetation.emoji = "🌿"
	vegetation.display_name = "Green Growth"
	vegetation.self_energy = 0.08
	vegetation.hamiltonian_couplings = {"☀": 0.4, "💧": 0.3}
	vegetation.lindblad_incoming = {"☀": 0.12, "💧": 0.05}
	vegetation.decay_rate = 0.01
	vegetation.decay_target = "🍂"
	vegetation.trophic_level = 1
	vegetation.tags = ["flora", "producer", "wild"]
	IconRegistry.register_icon(vegetation)
	
	# Seedling
	var seedling = Icon.new()
	seedling.emoji = "🌱"
	seedling.display_name = "Young Sprout"
	seedling.self_energy = 0.05
	seedling.hamiltonian_couplings = {"☀": 0.3, "💧": 0.4}
	seedling.lindblad_incoming = {"☀": 0.08, "💧": 0.06}
	seedling.lindblad_outgoing = {"🌿": 0.05}  # Grows into vegetation
	seedling.trophic_level = 1
	seedling.tags = ["flora", "producer", "young"]
	IconRegistry.register_icon(seedling)

static func _register_fauna() -> void:
	# Wolf
	var wolf = Icon.new()
	wolf.emoji = "🐺"
	wolf.display_name = "Shadow Hunter"
	wolf.self_energy = -0.05
	wolf.hamiltonian_couplings = {"🐇": 0.5, "🦌": 0.4, "🌳": 0.2}
	wolf.lindblad_incoming = {"🐇": 0.15, "🦌": 0.12}
	wolf.decay_rate = 0.03
	wolf.decay_target = "🍂"
	wolf.trophic_level = 3
	wolf.tags = ["fauna", "predator", "carnivore"]
	IconRegistry.register_icon(wolf)
	
	# Rabbit
	var rabbit = Icon.new()
	rabbit.emoji = "🐇"
	rabbit.display_name = "Swift Runner"
	rabbit.self_energy = 0.02
	rabbit.hamiltonian_couplings = {"🌿": 0.4, "🐺": 0.5, "🦅": 0.3}
	rabbit.lindblad_incoming = {"🌿": 0.1}
	rabbit.decay_rate = 0.02
	rabbit.decay_target = "🍂"
	rabbit.trophic_level = 2
	rabbit.tags = ["fauna", "herbivore", "prey"]
	IconRegistry.register_icon(rabbit)
	
	# Deer
	var deer = Icon.new()
	deer.emoji = "🦌"
	deer.display_name = "Forest Walker"
	deer.self_energy = 0.01
	deer.hamiltonian_couplings = {"🌿": 0.5, "🐺": 0.4, "🌳": 0.3}
	deer.lindblad_incoming = {"🌿": 0.08}
	deer.decay_rate = 0.015
	deer.decay_target = "🍂"
	deer.trophic_level = 2
	deer.tags = ["fauna", "herbivore", "prey"]
	IconRegistry.register_icon(deer)
	
	# Eagle
	var eagle = Icon.new()
	eagle.emoji = "🦅"
	eagle.display_name = "Sky Sovereign"
	eagle.self_energy = 0.0
	eagle.hamiltonian_couplings = {"🐇": 0.4, "🐭": 0.5, "💨": 0.3}
	eagle.lindblad_incoming = {"🐇": 0.08, "🐭": 0.1}
	eagle.decay_rate = 0.02
	eagle.trophic_level = 3
	eagle.tags = ["fauna", "predator", "apex", "aerial"]
	IconRegistry.register_icon(eagle)

static func _register_elements() -> void:
	# Water
	var water = Icon.new()
	water.emoji = "💧"
	water.display_name = "Living Water"
	water.self_energy = 0.0
	water.hamiltonian_couplings = {"🌿": 0.3, "🌾": 0.2, "⛰": 0.2}
	water.tags = ["element", "abiotic"]
	water.is_eternal = true
	IconRegistry.register_icon(water)
	
	# Mountain/Soil
	var soil = Icon.new()
	soil.emoji = "⛰"
	soil.display_name = "Ancient Stone"
	soil.self_energy = 0.0
	soil.hamiltonian_couplings = {"💧": 0.2, "🌱": 0.1}
	soil.lindblad_incoming = {"🍂": 0.05}  # Absorbs organic matter
	soil.tags = ["element", "abiotic", "foundation"]
	soil.is_eternal = true
	IconRegistry.register_icon(soil)
	
	# Organic matter
	var organic = Icon.new()
	organic.emoji = "🍂"
	organic.display_name = "Returning Matter"
	organic.self_energy = 0.0
	organic.hamiltonian_couplings = {"⛰": 0.2, "🍄": 0.3}
	organic.lindblad_outgoing = {"⛰": 0.03, "🍄": 0.05}
	organic.tags = ["element", "cycle", "decomposition"]
	IconRegistry.register_icon(organic)

static func _register_abstract() -> void:
	# Labor/Death
	var labor = Icon.new()
	labor.emoji = "💀"
	labor.display_name = "Labor's End"
	labor.self_energy = 0.0
	labor.hamiltonian_couplings = {"🌾": 0.3}
	labor.tags = ["abstract", "terminus"]
	IconRegistry.register_icon(labor)
	
	# Human effort
	var effort = Icon.new()
	effort.emoji = "👥"
	effort.display_name = "Collective Will"
	effort.self_energy = 0.1
	effort.hamiltonian_couplings = {"🌾": 0.4, "💀": 0.2}
	effort.tags = ["abstract", "human"]
	IconRegistry.register_icon(effort)
```

---

## File: Integration Snippet for BiomeBase

```gdscript
# Add to BiomeBase.gd

## Bath-first mode
var bath: QuantumBath = null
var use_bath_mode: bool = true
var active_projections: Dictionary = {}  # Vector2i → {qubit, north, south}

## Initialize bath for this biome
func _initialize_bath() -> void:
	bath = QuantumBath.new()
	# Override in subclasses to set up specific bath

## Create a projection from the bath
func create_projection(position: Vector2i, north: String, south: String) -> DualEmojiQubit:
	if not use_bath_mode or not bath:
		# Fallback to legacy mode
		return _create_legacy_qubit(north, south)
	
	var proj = bath.project_onto_axis(north, south)
	
	var qubit = DualEmojiQubit.new(north, south, proj.theta)
	qubit.phi = proj.phi
	qubit.radius = proj.radius
	qubit.energy = proj.radius
	
	active_projections[position] = {
		"qubit": qubit,
		"north": north,
		"south": south
	}
	
	quantum_states[position] = qubit
	qubit_created.emit(position, qubit)
	
	return qubit

## Update all projections from bath
func update_projections() -> void:
	for position in active_projections:
		var data = active_projections[position]
		var qubit = data.qubit
		var proj = bath.project_onto_axis(data.north, data.south)
		
		qubit.theta = proj.theta
		qubit.phi = proj.phi
		qubit.radius = proj.radius
		qubit.energy = proj.radius
		
		qubit_evolved.emit(position)

## Measure a projection
func measure_projection(position: Vector2i) -> String:
	if not active_projections.has(position):
		return ""
	
	var data = active_projections[position]
	var outcome = bath.measure_axis(data.north, data.south, 0.5)
	
	update_projections()
	qubit_measured.emit(position, outcome)
	
	return outcome

## Remove a projection
func remove_projection(position: Vector2i) -> void:
	if active_projections.has(position):
		active_projections.erase(position)
	if quantum_states.has(position):
		quantum_states.erase(position)

## Override _process for bath evolution
func _process(delta: float) -> void:
	if use_bath_mode and bath:
		bath.evolve(delta)
		update_projections()
	else:
		_update_quantum_substrate(delta)
```

---

## Summary

These stubs provide:

1. **Complex.gd** - Full complex number arithmetic
2. **Icon.gd** - Icon resource with all properties
3. **IconRegistry.gd** - Singleton for icon management
4. **QuantumBath.gd** - Complete bath evolution
5. **CoreIcons.gd** - 20 starter icons
6. **BiomeBase integration** - Snippet for retrofit

Copy these into your project and begin Phase 0!

