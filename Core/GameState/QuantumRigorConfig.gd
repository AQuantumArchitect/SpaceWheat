class_name QuantumRigorConfig
extends Resource

## Quantum Rigor Configuration
## Controls the mathematical rigor of quantum operations

enum ReadoutMode {
	HARDWARE,   # Simulates real quantum hardware imperfections
	INSPECTOR   # Idealized readout (default, for gameplay)
}

enum SelectiveMeasureModel {
	POSTSELECT_COSTED,  # Measurement cost scales as 1/p_subspace (NOT IMPLEMENTED - UI only)
	CLICK_NOCLICK       # Binary success/failure (NOT IMPLEMENTED - UI only)
}

# Current configuration
@export var readout_mode: ReadoutMode = ReadoutMode.INSPECTOR
@export var selective_measure_model: SelectiveMeasureModel = SelectiveMeasureModel.POSTSELECT_COSTED

# Debug and invariant checking
@export var enable_invariant_checks: bool = false  # Enable per-frame ρ validation (slow)
@export var enable_trace_warnings: bool = true     # Warn on trace violations

# Singleton pattern
static var instance: QuantumRigorConfig = null

func _init(p_readout: ReadoutMode = ReadoutMode.INSPECTOR,
           p_selective: SelectiveMeasureModel = SelectiveMeasureModel.POSTSELECT_COSTED):
	readout_mode = p_readout
	selective_measure_model = p_selective

	if instance == null:
		instance = self


func mode_description() -> String:
	"""Human-readable description of current configuration"""
	var desc = ""
	desc += "Readout: %s\n" % ["HARDWARE", "INSPECTOR"][readout_mode]
	desc += "Selective Measure: %s" % ["POSTSELECT_COSTED", "CLICK_NOCLICK"][selective_measure_model]
	return desc
