extends PanelContainer

## QuantumModeStatusIndicator - Displays current quantum rigor mode
##
## Shows:
## - Current readout mode (HARDWARE vs INSPECTOR)
## - Current backaction mode (KID_LIGHT vs LAB_TRUE)
## - Selective measure model (POSTSELECT_COSTED)
##
## Placed in top-right corner of FarmUI
## Updates automatically when modes change

const QuantumRigorConfig = preload("res://Core/GameState/QuantumRigorConfig.gd")

var config: QuantumRigorConfig = null
var status_label: Label = null
var update_timer: float = 0.0


func _ready() -> void:
	"""Initialize status indicator"""
	# Get config singleton
	config = QuantumRigorConfig.instance
	if not config:
		print("⚠️  QuantumModeStatusIndicator: No QuantumRigorConfig instance found")
		return

	# Create label for status text
	status_label = Label.new()
	add_child(status_label)
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# Style the panel
	_setup_theme()

	# Initial update
	_update_status()

	print("✅ QuantumModeStatusIndicator initialized")


func _setup_theme() -> void:
	"""Configure visual styling"""
	# Use semi-transparent background
	add_theme_stylebox_override("panel", _create_panel_style())

	# Style the label
	var label_settings = LabelSettings.new()
	label_settings.font_sizes[TextServer.HINTING_NONE] = 11
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0, 0.9))  # Cyan

	# Make panel slightly transparent
	modulate = Color(1, 1, 1, 0.85)


func _create_panel_style() -> StyleBox:
	"""Create semi-transparent panel background"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.7)  # Dark blue-black
	style.set_border_enabled_all(true)
	style.set_border_color_all(Color(0.2, 0.8, 1.0, 0.3))  # Cyan border
	style.set_content_margin_all(8)
	return style


func _process(delta: float) -> void:
	"""Update status periodically (check for mode changes)"""
	update_timer += delta
	if update_timer >= 0.5:  # Update every 0.5 seconds
		_update_status()
		update_timer = 0.0


func _update_status() -> void:
	"""Update the displayed status text"""
	if not config or not status_label:
		return

	# Build mode display string
	var readout = "HARDWARE" if config.readout_mode == QuantumRigorConfig.ReadoutMode.HARDWARE else "INSPECTOR"
	var backaction = "LAB_TRUE" if config.backaction_mode == QuantumRigorConfig.BackactionMode.LAB_TRUE else "KID_LIGHT"
	var measure = "COSTED" if config.selective_measure_model == QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED else "CLICK"

	# Display with emojis for clarity
	var readout_emoji = "📡" if config.readout_mode == QuantumRigorConfig.ReadoutMode.HARDWARE else "🔍"
	var backaction_emoji = "🔬" if config.backaction_mode == QuantumRigorConfig.BackactionMode.LAB_TRUE else "😌"
	var measure_emoji = "💰" if config.selective_measure_model == QuantumRigorConfig.SelectiveMeasureModel.POSTSELECT_COSTED else "✓"

	status_label.text = "%s %s | %s %s" % [
		readout_emoji, readout,
		backaction_emoji, backaction
	]


func get_full_description() -> String:
	"""Get detailed mode description for help text"""
	if not config:
		return "Quantum Rigor Config unavailable"

	return config.get_mode_description()
