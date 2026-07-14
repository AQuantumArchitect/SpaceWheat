class_name Icon
extends Resource

## Icon: A named emoji pair — one qubit axis — that inhabits a biome.
##
## An Icon is the meeting of two poles: pole_0 (active/excited) and pole_1
## (rest/ground). Together they ARE a quantum axis: one two-state system with
## its own energy landscape, driver, and dissipative metabolism.
##
## Icons are hand-crafted. Factions give the emoji web its physics; Icons
## select which two emojis form a living axis and give that axis a name.
## A biome is a habitat — the list of Icons that dwell within it.
##
## The internal Rabi coupling (pole_0 ↔ pole_1) is the heartbeat of the Icon.
## Cross-Icon couplings emerge from the faction web acting on the emoji pairs.

## ========================================
## Identity
## ========================================

## The name of this Icon (e.g. "CelestialCycle", "PackHerd").
@export var name: String = ""
## pole_0: active/excited pole (e.g. "☀" for CelestialCycle)
@export var pole_0: String = ""
## pole_1: rest/ground pole (e.g. "🌙" for CelestialCycle)
@export var pole_1: String = ""

## Primary key for atom objects (single-emoji use). pole_0/pole_1 are used for paired icon axes.
@export var emoji: String = ""
@export var display_name: String = ""
@export var description: String = ""

## ========================================
## Hamiltonian Terms (Unitary Evolution)
## ========================================

## Self-energy: diagonal term H[i,i] - natural frequency
@export var self_energy: float = 0.0
## Pair-axis self-energy for pole_0 (used by icon-cloud biomes and pair atlases).
@export var self_energy_0: float = 0.0
## Pair-axis self-energy for pole_1 (used by icon-cloud biomes and pair atlases).
@export var self_energy_1: float = 0.0

## Internal Rabi coupling: the heartbeat of the Icon.
## Symmetric coupling between pole_0 ↔ pole_1 — the oscillation rate of this
## axis. Distinct from cross-Icon couplings, which live in hamiltonian_couplings
## and emerge from the faction web acting across axes.
@export var rabi_coupling: float = 0.0

## Cross-axis couplings: off-diagonal terms H[i,j] to OTHER Icons' emojis.
## Key = target emoji, Value = coupling strength (real, will be symmetrized)
@export var hamiltonian_couplings: Dictionary = {}
## Alias used by the icon-cloud builder path.
@export var cross_couplings: Dictionary = {}

## Time-dependent self-energy for external driving (e.g., day/night cycle)
@export var self_energy_driver: String = ""  # "cosine", "sine", "pulse", or ""
@export var driver_frequency: float = 0.0    # Hz (cycles per second)
@export var driver_phase: float = 0.0        # Radians
@export var driver_amplitude: float = 1.0    # Multiplier for self_energy

## ========================================
## Bath-Projection Coupling (Environmental Interactions)
## ========================================

## Energy couplings: how projections of this emoji respond to bath observables
## Key = observable emoji in bath, Value = energy coupling strength
## Positive: projection gains energy when observable is present in bath
## Negative: projection loses energy when observable is present in bath
## Zero (or missing): no interaction
##
## Example:
##   mushroom.energy_couplings = {
##       "☀": -0.20,  # Take damage from sun (proximity-based depletion)
##       "🌙": +0.40   # Grow from moon (proximity-based growth)
##   }
##
## Physics: dE/dt = base_growth + Σ_i [coupling_i × P(obs_i)]
@export var energy_couplings: Dictionary = {}

## ========================================
## Metadata
## ========================================

## Trophic level: 0=abiotic, 1=producer, 2=consumer, 3=predator
@export var trophic_level: int = 0

## Tags for organization and querying
@export var tags: Array = []

## Special behavioral flags
@export var is_driver: bool = false      # External forcing (like sun)
@export var is_adaptive: bool = false    # Dynamically changes (like tomato)
@export var is_eternal: bool = false     # Never decays

## ========================================
## Methods
## ========================================

## Get effective self-energy at given time (handles time-dependent drivers)
func get_self_energy(time: float) -> float:
	return get_pole_energy(0, time)


## Get effective self-energy for a given pole at time.
func get_pole_energy(pole: int, time: float) -> float:
	# Pair icons (either pair-axis field nonzero) are authoritative per pole —
	# INCLUDING a legitimate 0.0 (e.g. Burn 🔥/🍂 se0=0.35, se1=0). The old
	# "0.0 means unset" fallback substituted se0 for a zero se1, silently
	# symmetrizing the axis: the σz term vanished, so a Hadamard landed the
	# Bloch vector exactly on the bare-σx eigenaxis and the qubit froze —
	# Berry-phase ripening could never start (frozen-physics sentinel bomb).
	# Legacy single-value icons (both pair fields zero) keep using self_energy.
	var base = self_energy
	if self_energy_0 != 0.0 or self_energy_1 != 0.0:
		base = self_energy_0 if pole == 0 else self_energy_1

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


## Construct a pair-Icon resource from pair physics (icons.json).
## Lindblad/decay come from biome.atom_components, not the Icon.
static func from_pair_physics(
		iname: String, p0: String, p1: String,
		physics: Dictionary,
		standing: float = 1.0) -> Icon:
	var icon = load("res://Core/QuantumSubstrate/Icon.gd").new()
	icon.name = iname
	icon.pole_0 = p0
	icon.pole_1 = p1
	icon.self_energy_0 = float(physics.get("self_energy_0", 0.0)) * standing
	icon.self_energy_1 = float(physics.get("self_energy_1", 0.0)) * standing
	icon.self_energy = icon.self_energy_0
	icon.rabi_coupling = float(physics.get("rabi_coupling", 0.0)) * standing
	icon.hamiltonian_couplings = _scale_dict(physics.get("hamiltonian_couplings", {}), standing)
	icon.cross_couplings = icon.hamiltonian_couplings.duplicate(true)
	var driver: Dictionary = physics.get("driver", {})
	if driver.has("type"):
		icon.self_energy_driver = str(driver.get("type", ""))
		icon.driver_frequency = float(driver.get("freq", 0.0))
		icon.driver_phase = float(driver.get("phase", 0.0))
		icon.driver_amplitude = float(driver.get("amp", 1.0))
	return icon


static func _scale_dict(d: Dictionary, s: float) -> Dictionary:
	var out: Dictionary = {}
	for k in d:
		var v = d[k]
		if v is Array and v.size() == 2:
			out[k] = Vector2(float(v[0]), float(v[1])) * s
		else:
			out[k] = float(v) * s
	return out

## Get all emojis this icon couples to (Hamiltonian only; L lives on biome.atom_components)
func get_coupled_emojis() -> Array:
	var result: Array = []

	for e in hamiltonian_couplings.keys():
		if not result.has(e):
			result.append(e)

	for e in cross_couplings.keys():
		if not result.has(e):
			result.append(e)

	return result
