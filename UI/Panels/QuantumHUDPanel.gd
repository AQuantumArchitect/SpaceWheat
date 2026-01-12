extends PanelContainer

## Quantum HUD Panel
## Collapsible container for quantum state visualization panels:
## - QuantumEnergyMeter (real vs imaginary energy)
## - UncertaintyMeter (precision/flexibility)
## - SemanticContextIndicator (octant/region)
## - AttractorPersonalityPanel (strange attractor)

const QuantumEnergyMeter = preload("res://UI/Panels/QuantumEnergyMeter.gd")
const UncertaintyMeter = preload("res://UI/Panels/UncertaintyMeter.gd")
const SemanticContextIndicator = preload("res://UI/Panels/SemanticContextIndicator.gd")
const AttractorPersonalityPanel = preload("res://UI/Panels/AttractorPersonalityPanel.gd")

# UI components
var toggle_button: Button
var panels_container: VBoxContainer
var scroll_container: ScrollContainer

# Child panels
var energy_meter: Control
var uncertainty_meter: Control
var semantic_indicator: Control
var attractor_panel: Control

# State
var collapsed: bool = false

# References (injected)
var farm = null
var current_biome = null


func _ready():
	# Panel styling
	custom_minimum_size = Vector2(320, 50)  # Minimum when collapsed

	# Main layout
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# Toggle button (always visible)
	toggle_button = Button.new()
	toggle_button.text = "  Quantum State"
	toggle_button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle_button.custom_minimum_size = Vector2(300, 32)
	toggle_button.pressed.connect(_toggle_collapse)
	main_vbox.add_child(toggle_button)

	# Scroll container for panels (collapsible)
	scroll_container = ScrollContainer.new()
	scroll_container.custom_minimum_size = Vector2(300, 400)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(scroll_container)

	# Panels container inside scroll
	panels_container = VBoxContainer.new()
	panels_container.add_theme_constant_override("separation", 8)
	scroll_container.add_child(panels_container)

	# Create child panels
	_create_panels()

	# Start expanded
	_update_collapse_state()


func _create_panels():
	"""Instantiate all quantum visualization panels"""
	# Energy meter (real vs imaginary)
	energy_meter = QuantumEnergyMeter.new()
	energy_meter.name = "QuantumEnergyMeter"
	panels_container.add_child(energy_meter)

	# Uncertainty meter (precision/flexibility)
	uncertainty_meter = UncertaintyMeter.new()
	uncertainty_meter.name = "UncertaintyMeter"
	panels_container.add_child(uncertainty_meter)

	# Semantic context (octant/region)
	semantic_indicator = SemanticContextIndicator.new()
	semantic_indicator.name = "SemanticContextIndicator"
	panels_container.add_child(semantic_indicator)

	# Attractor personality
	attractor_panel = AttractorPersonalityPanel.new()
	attractor_panel.name = "AttractorPersonalityPanel"
	panels_container.add_child(attractor_panel)


func _toggle_collapse():
	"""Toggle between collapsed and expanded state"""
	collapsed = !collapsed
	_update_collapse_state()


func _update_collapse_state():
	"""Update UI based on collapsed state"""
	scroll_container.visible = !collapsed

	if collapsed:
		toggle_button.text = "  Quantum State"
		custom_minimum_size = Vector2(320, 50)
	else:
		toggle_button.text = "  Quantum State"
		custom_minimum_size = Vector2(320, 450)


## ========================================
## PUBLIC API - Dependency Injection
## ========================================

func set_farm(farm_ref):
	"""Inject farm reference - propagates to all child panels"""
	farm = farm_ref

	if energy_meter and energy_meter.has_method("set_farm"):
		energy_meter.set_farm(farm_ref)

	if semantic_indicator and semantic_indicator.has_method("set_farm"):
		semantic_indicator.set_farm(farm_ref)

	if attractor_panel and attractor_panel.has_method("set_farm"):
		attractor_panel.set_farm(farm_ref)


func set_biome(biome_ref):
	"""Set active biome - propagates to child panels"""
	current_biome = biome_ref

	if energy_meter and energy_meter.has_method("set_biome"):
		energy_meter.set_biome(biome_ref)

	if semantic_indicator and semantic_indicator.has_method("set_biome"):
		semantic_indicator.set_biome(biome_ref)

	# Uncertainty meter needs quantum_computer
	if uncertainty_meter and biome_ref and biome_ref.quantum_computer:
		uncertainty_meter.set_quantum_computer(biome_ref.quantum_computer)


func set_quantum_computer(qc):
	"""Direct quantum computer injection (for panels that need it)"""
	if uncertainty_meter and uncertainty_meter.has_method("set_quantum_computer"):
		uncertainty_meter.set_quantum_computer(qc)


## ========================================
## Convenience Methods
## ========================================

func collapse():
	"""Collapse the panel"""
	if not collapsed:
		collapsed = true
		_update_collapse_state()


func expand():
	"""Expand the panel"""
	if collapsed:
		collapsed = false
		_update_collapse_state()


func is_collapsed() -> bool:
	"""Check if panel is collapsed"""
	return collapsed


func get_energy_meter() -> Control:
	"""Get reference to energy meter panel"""
	return energy_meter


func get_uncertainty_meter() -> Control:
	"""Get reference to uncertainty meter panel"""
	return uncertainty_meter


func get_semantic_indicator() -> Control:
	"""Get reference to semantic context indicator panel"""
	return semantic_indicator


func get_attractor_panel() -> Control:
	"""Get reference to attractor personality panel"""
	return attractor_panel
