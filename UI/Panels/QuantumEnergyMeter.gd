extends PanelContainer

## Quantum Energy Meter Panel
## Displays the real (observable) vs imaginary (coherence) energy split
## for the current biome's quantum state.

const SparkConverter = preload("res://Core/QuantumSubstrate/SparkConverter.gd")

# UI components (created dynamically)
var title_label: Label
var real_bar: ProgressBar
var imaginary_bar: ProgressBar
var real_label: Label
var imaginary_label: Label
var regime_label: Label
var extractable_label: Label

# Update frequency
var update_timer: float = 0.0
var update_interval: float = 0.5  # Update every 0.5 seconds

# Farm/biome reference (injected)
var farm = null
var current_biome = null


func _ready():
	# Set panel style
	custom_minimum_size = Vector2(280, 180)

	# Create container
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Title
	title_label = Label.new()
	title_label.text = "⚡ Quantum Energy"
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer)

	# Real energy bar
	var real_row = HBoxContainer.new()
	vbox.add_child(real_row)

	var real_icon = Label.new()
	real_icon.text = "📊"
	real_row.add_child(real_icon)

	real_bar = ProgressBar.new()
	real_bar.custom_minimum_size = Vector2(150, 20)
	real_bar.max_value = 1.0
	real_bar.value = 0.5
	real_bar.show_percentage = false
	real_row.add_child(real_bar)

	real_label = Label.new()
	real_label.text = "0.50"
	real_label.custom_minimum_size = Vector2(45, 0)
	real_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	real_row.add_child(real_label)

	# Imaginary energy bar
	var imag_row = HBoxContainer.new()
	vbox.add_child(imag_row)

	var imag_icon = Label.new()
	imag_icon.text = "✨"
	imag_row.add_child(imag_icon)

	imaginary_bar = ProgressBar.new()
	imaginary_bar.custom_minimum_size = Vector2(150, 20)
	imaginary_bar.max_value = 1.0
	imaginary_bar.value = 0.5
	imaginary_bar.show_percentage = false
	imag_row.add_child(imaginary_bar)

	imaginary_label = Label.new()
	imaginary_label.text = "0.50"
	imaginary_label.custom_minimum_size = Vector2(45, 0)
	imaginary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	imag_row.add_child(imaginary_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(spacer2)

	# Regime indicator
	regime_label = Label.new()
	regime_label.text = "⚖️ Balanced"
	regime_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(regime_label)

	# Extractable energy
	extractable_label = Label.new()
	extractable_label.text = "Extractable: 0.00"
	extractable_label.add_theme_font_size_override("font_size", 11)
	extractable_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(extractable_label)

	# Style the bars
	_style_bars()


func _style_bars():
	"""Apply custom colors to progress bars"""
	# Real energy = orange/gold
	var real_style = StyleBoxFlat.new()
	real_style.bg_color = Color(0.9, 0.6, 0.2, 0.9)
	real_style.corner_radius_top_left = 3
	real_style.corner_radius_top_right = 3
	real_style.corner_radius_bottom_left = 3
	real_style.corner_radius_bottom_right = 3
	real_bar.add_theme_stylebox_override("fill", real_style)

	# Imaginary energy = cyan/blue
	var imag_style = StyleBoxFlat.new()
	imag_style.bg_color = Color(0.2, 0.8, 0.9, 0.9)
	imag_style.corner_radius_top_left = 3
	imag_style.corner_radius_top_right = 3
	imag_style.corner_radius_bottom_left = 3
	imag_style.corner_radius_bottom_right = 3
	imaginary_bar.add_theme_stylebox_override("fill", imag_style)


func set_farm(farm_ref):
	"""Inject farm reference to access biomes"""
	farm = farm_ref


func set_biome(biome_ref):
	"""Directly set which biome to monitor"""
	current_biome = biome_ref


func _process(dt: float):
	"""Update energy display"""
	update_timer += dt

	if update_timer >= update_interval:
		update_timer = 0.0
		_update_display()


func _update_display():
	"""Update energy meter display"""
	# Get current biome
	var biome = _get_current_biome()
	if not biome or not biome.quantum_computer:
		_show_no_state()
		return

	# Get energy status
	var status = SparkConverter.get_energy_status(biome.quantum_computer)

	if status.regime == "no_state":
		_show_no_state()
		return

	# Update title with biome name
	title_label.text = "⚡ %s Energy" % biome.get_biome_type()

	# Update bars
	# Scale bars relative to total (both should sum to ~1.0)
	var total = max(status.total, 0.001)
	real_bar.value = status.real / total
	imaginary_bar.value = status.imaginary / total

	# Update labels
	real_label.text = "%.2f" % status.real
	imaginary_label.text = "%.2f" % status.imaginary

	# Update regime
	regime_label.text = SparkConverter.get_regime_description(status.regime)
	regime_label.modulate = SparkConverter.get_regime_color(status.regime)

	# Update extractable
	extractable_label.text = "Extractable: %.2f ⚡" % status.extractable

	# Tooltip
	tooltip_text = """Real Energy (📊): Observable populations
Imaginary Energy (✨): Quantum coherence

Coherence Ratio: %.1f%%
Extract quantum potential with Tool 4 → Energy Tap""" % (status.coherence_ratio * 100.0)


func _show_no_state():
	"""Show placeholder when no quantum state is available"""
	title_label.text = "⚡ Quantum Energy"
	real_bar.value = 0.0
	imaginary_bar.value = 0.0
	real_label.text = "---"
	imaginary_label.text = "---"
	regime_label.text = "No quantum state"
	regime_label.modulate = Color.GRAY
	extractable_label.text = "Extractable: ---"


func _get_current_biome():
	"""Get the current/active biome"""
	# Direct reference takes priority
	if current_biome:
		return current_biome

	# Try to get from farm
	if not farm:
		return null

	# Check for multi-biome structure
	if "biomes" in farm and farm.biomes and not farm.biomes.is_empty():
		# Get first biome (or could use selected biome)
		for biome_name in farm.biomes:
			var biome = farm.biomes[biome_name]
			if biome:
				return biome

	# Fallback: single biome (legacy)
	if "biome" in farm and farm.biome:
		return farm.biome

	return null
