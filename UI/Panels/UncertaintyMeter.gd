extends PanelContainer

## Uncertainty Meter Panel
##
## Displays the semantic uncertainty principle metrics:
## - Precision: how stable/well-defined meanings are
## - Flexibility: how easily state can change
## - Product: precision × flexibility (must be >= PLANCK_SEMANTIC)
## - Current regime: crystallized/fluid/balanced/etc.

const SemanticUncertainty = preload("res://Core/QuantumSubstrate/SemanticUncertainty.gd")

# UI components
var header_label: Label
var precision_bar: ProgressBar
var precision_label: Label
var flexibility_bar: ProgressBar
var flexibility_label: Label
var product_label: Label
var regime_emoji: Label
var regime_name: Label
var regime_description: Label
var principle_status: Label

# Update timing
var update_timer: float = 0.0
var update_interval: float = 0.3  # Update every 0.3 seconds

# Reference to biome/quantum computer
var quantum_computer = null

# Cached state
var _last_regime: String = ""


func _ready():
	custom_minimum_size = Vector2(280, 200)

	_build_ui()
	_apply_default_styling()


func _build_ui():
	"""Construct the UI hierarchy"""
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Header
	var header_box = HBoxContainer.new()
	vbox.add_child(header_box)

	header_label = Label.new()
	header_label.text = "Semantic Uncertainty"
	header_label.add_theme_font_size_override("font_size", 14)
	header_box.add_child(header_label)

	# Precision row
	var precision_row = HBoxContainer.new()
	vbox.add_child(precision_row)

	var precision_title = Label.new()
	precision_title.text = "Precision:"
	precision_title.custom_minimum_size = Vector2(80, 0)
	precision_title.add_theme_font_size_override("font_size", 11)
	precision_row.add_child(precision_title)

	precision_bar = ProgressBar.new()
	precision_bar.custom_minimum_size = Vector2(100, 16)
	precision_bar.min_value = 0.0
	precision_bar.max_value = 1.0
	precision_bar.show_percentage = false
	precision_row.add_child(precision_bar)

	precision_label = Label.new()
	precision_label.text = "0.50"
	precision_label.custom_minimum_size = Vector2(40, 0)
	precision_label.add_theme_font_size_override("font_size", 10)
	precision_row.add_child(precision_label)

	# Flexibility row
	var flexibility_row = HBoxContainer.new()
	vbox.add_child(flexibility_row)

	var flexibility_title = Label.new()
	flexibility_title.text = "Flexibility:"
	flexibility_title.custom_minimum_size = Vector2(80, 0)
	flexibility_title.add_theme_font_size_override("font_size", 11)
	flexibility_row.add_child(flexibility_title)

	flexibility_bar = ProgressBar.new()
	flexibility_bar.custom_minimum_size = Vector2(100, 16)
	flexibility_bar.min_value = 0.0
	flexibility_bar.max_value = 1.0
	flexibility_bar.show_percentage = false
	flexibility_row.add_child(flexibility_bar)

	flexibility_label = Label.new()
	flexibility_label.text = "0.50"
	flexibility_label.custom_minimum_size = Vector2(40, 0)
	flexibility_label.add_theme_font_size_override("font_size", 10)
	flexibility_row.add_child(flexibility_label)

	# Separator
	vbox.add_child(HSeparator.new())

	# Product (uncertainty principle check)
	var product_row = HBoxContainer.new()
	vbox.add_child(product_row)

	var product_title = Label.new()
	product_title.text = "Product:"
	product_title.custom_minimum_size = Vector2(80, 0)
	product_title.add_theme_font_size_override("font_size", 11)
	product_row.add_child(product_title)

	product_label = Label.new()
	product_label.text = "0.25 >= 0.25"
	product_label.add_theme_font_size_override("font_size", 11)
	product_row.add_child(product_label)

	# Principle status
	principle_status = Label.new()
	principle_status.text = "Principle Satisfied"
	principle_status.add_theme_font_size_override("font_size", 10)
	principle_status.modulate = Color.GREEN
	vbox.add_child(principle_status)

	# Separator
	vbox.add_child(HSeparator.new())

	# Regime display
	var regime_row = HBoxContainer.new()
	vbox.add_child(regime_row)

	regime_emoji = Label.new()
	regime_emoji.text = "⚖️"
	regime_emoji.add_theme_font_size_override("font_size", 24)
	regime_row.add_child(regime_emoji)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(8, 0)
	regime_row.add_child(spacer)

	regime_name = Label.new()
	regime_name.text = "Balanced"
	regime_name.add_theme_font_size_override("font_size", 16)
	regime_row.add_child(regime_name)

	# Regime description
	regime_description = Label.new()
	regime_description.text = "Good mix of stability and adaptability"
	regime_description.add_theme_font_size_override("font_size", 10)
	regime_description.modulate = Color(0.8, 0.8, 0.8)
	regime_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	regime_description.custom_minimum_size = Vector2(260, 30)
	vbox.add_child(regime_description)


func _apply_default_styling():
	"""Apply initial color styling to bars"""
	# Precision bar: blue tint
	var precision_style = StyleBoxFlat.new()
	precision_style.bg_color = Color(0.2, 0.4, 0.8, 0.8)
	precision_bar.add_theme_stylebox_override("fill", precision_style)

	# Flexibility bar: cyan tint
	var flexibility_style = StyleBoxFlat.new()
	flexibility_style.bg_color = Color(0.2, 0.7, 0.8, 0.8)
	flexibility_bar.add_theme_stylebox_override("fill", flexibility_style)


func set_quantum_computer(qc):
	"""Set quantum computer reference for uncertainty calculation"""
	quantum_computer = qc


func _process(dt: float):
	"""Update display periodically"""
	update_timer += dt

	if update_timer >= update_interval:
		update_timer = 0.0
		_update_display()


func _update_display():
	"""Refresh all UI elements from quantum state"""
	if quantum_computer == null or quantum_computer.density_matrix == null:
		_show_no_data()
		return

	# Compute uncertainty
	var uncertainty = SemanticUncertainty.compute_from_quantum_computer(quantum_computer)

	var precision = uncertainty.get("precision", 0.5)
	var flexibility = uncertainty.get("flexibility", 0.5)
	var product = uncertainty.get("product", 0.25)
	var satisfies = uncertainty.get("satisfies_principle", true)
	var regime = uncertainty.get("regime", "unknown")

	# Update bars
	precision_bar.value = precision
	precision_label.text = "%.2f" % precision

	flexibility_bar.value = flexibility
	flexibility_label.text = "%.2f" % flexibility

	# Update product
	product_label.text = "%.3f >= %.2f" % [product, SemanticUncertainty.PLANCK_SEMANTIC]

	# Update principle status
	if satisfies:
		principle_status.text = "Principle Satisfied"
		principle_status.modulate = Color.GREEN
	else:
		principle_status.text = "PRINCIPLE VIOLATED!"
		principle_status.modulate = Color.RED

	# Update regime
	regime_emoji.text = SemanticUncertainty.get_regime_emoji(regime)
	regime_name.text = regime.capitalize()
	regime_name.modulate = SemanticUncertainty.get_regime_color(regime)

	regime_description.text = SemanticUncertainty.get_regime_description(regime)

	# Update tooltip with full details
	_update_tooltip(uncertainty)


func _show_no_data():
	"""Display when no quantum state available"""
	precision_bar.value = 0.0
	precision_label.text = "---"

	flexibility_bar.value = 0.0
	flexibility_label.text = "---"

	product_label.text = "---"
	principle_status.text = "No quantum state"
	principle_status.modulate = Color.GRAY

	regime_emoji.text = "❓"
	regime_name.text = "Unknown"
	regime_name.modulate = Color.GRAY
	regime_description.text = "No quantum computer connected"


func _update_tooltip(uncertainty: Dictionary):
	"""Build detailed tooltip"""
	tooltip_text = """Semantic Uncertainty Principle

Precision × Flexibility >= %.2f (h_semantic)

Current Values:
  Precision:   %.3f
  Flexibility: %.3f
  Product:     %.4f

Entropy: %.3f nats
Purity:  %.3f

Regime: %s
%s

High precision = stable, hard to change
High flexibility = adaptable, meanings drift
Balance is key for effective gameplay!""" % [
		SemanticUncertainty.PLANCK_SEMANTIC,
		uncertainty.get("precision", 0.0),
		uncertainty.get("flexibility", 0.0),
		uncertainty.get("product", 0.0),
		uncertainty.get("entropy", 0.0),
		uncertainty.get("purity", 0.0),
		uncertainty.get("regime", "unknown"),
		SemanticUncertainty.get_regime_description(uncertainty.get("regime", "unknown"))
	]


## ========================================
## Public API
## ========================================

func get_current_uncertainty() -> Dictionary:
	"""Get the most recent uncertainty calculation"""
	if quantum_computer == null:
		return SemanticUncertainty._empty_result()

	return SemanticUncertainty.compute_from_quantum_computer(quantum_computer)


func get_current_regime() -> String:
	"""Get current regime string"""
	var uncertainty = get_current_uncertainty()
	return uncertainty.get("regime", "unknown")


func get_action_modifiers() -> Dictionary:
	"""Get gameplay modifiers based on current uncertainty"""
	return SemanticUncertainty.get_action_modifier(get_current_uncertainty())
