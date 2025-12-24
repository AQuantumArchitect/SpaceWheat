extends Control

## Test scene for Hamiltonian Coupling Graph visualization
## Displays the Forest Ecosystem V3 quantum field theory system

@onready var graph = $EcosystemGraphVisualizer
@onready var health_label = $UI/InfoPanel/MarginContainer/VBoxContainer/HealthLabel
@onready var coupling_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CouplingLabel
@onready var energy_label = $UI/InfoPanel/MarginContainer/VBoxContainer/EnergyLabel
@onready var cascade_label = $UI/InfoPanel/MarginContainer/VBoxContainer/CascadeLabel

var update_timer = 0.0


func _ready():
	"""Initialize the test scene"""
	print("✅ Hamiltonian Graph Test Scene initialized")
	print("   🌲 Forest Ecosystem V3 (Quantum Field Theory)")
	print("   9D Hamiltonian system with energy conservation")


func _process(delta):
	"""Update metrics"""
	update_timer += delta
	if update_timer > 0.5:
		update_metrics()
		update_timer = 0.0

	# Close on Q
	if Input.is_key_pressed(KEY_Q):
		get_tree().quit()


func update_metrics():
	"""Update the displayed metrics from the forest"""
	if not graph or not graph.forest:
		return

	var patch_pos = Vector2i(0, 0)

	# Get ecosystem metrics
	var health = graph.forest.get_ecosystem_health(patch_pos)
	health_label.text = "Health: %.1f%%" % (health * 100.0)

	var coupling = graph.forest.get_trophic_cascade_indicator(patch_pos)
	coupling_label.text = "Coupling: %.3f" % coupling

	var energy = graph.forest.get_energy_conservation_check(patch_pos)
	energy_label.text = "Energy: %.2f" % energy

	# Cascade indicator
	var N = graph.forest.get_occupation_numbers(patch_pos)
	var cascade = 0.0
	if N:
		var plant = N.get("plant", 1.0)
		var apex = N.get("apex", 1.0)
		cascade = sqrt(plant * apex)

	cascade_label.text = "Cascade: %.3f" % cascade
