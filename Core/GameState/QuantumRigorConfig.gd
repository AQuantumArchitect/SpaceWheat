## QuantumRigorConfig - Quantum Mechanics Rigor Mode Configuration
##
## Implements mode flags from Quantum↔Classical Interface Manifest
## (llm_inbox/space_wheat_quantum↔classical_interface_manifest_gozintas_gozoutas.md)
##
## Purpose: Allow players to choose between:
## - KID_LIGHT mode: Gentle quantum mechanics (casual gameplay)
## - LAB_TRUE mode: Full quantum rigor (educational/scientific)
class_name QuantumRigorConfig
extends Resource

## READOUT_MODE: How measurement outcomes are presented
enum ReadoutMode {
	HARDWARE,   ## Shot-faithful: Sample single outcome k ~ p(k), show histogram
	INSPECTOR   ## Simulator privilege: Show exact distribution p(e) from ρ
}

## BACKACTION_MODE: How measurements affect quantum state
enum BackactionMode {
	KID_LIGHT,  ## Gentle: partial_collapse with strength=0.5 (preserves some coherence)
	LAB_TRUE    ## Rigorous: full projective collapse with strength=1.0 (Born rule)
}

## SELECTIVE_MEASURE_MODEL: How selective measurements are handled
enum SelectiveMeasureModel {
	POSTSELECT_COSTED,  ## Charge cost/time ∝ 1/p(subspace) for selective measurement
	CLICK_NOCLICK       ## Repeated measurement instrument (future implementation)
}

## Current readout mode (default: INSPECTOR for smooth gameplay)
@export var readout_mode: ReadoutMode = ReadoutMode.INSPECTOR

## Current backaction mode (default: KID_LIGHT for casual players)
@export var backaction_mode: BackactionMode = BackactionMode.KID_LIGHT

## Selective measurement model (default: POSTSELECT_COSTED)
@export var selective_measure_model: SelectiveMeasureModel = SelectiveMeasureModel.POSTSELECT_COSTED

## Enable per-frame physics invariant checks (debug/lab mode only)
## WARNING: Expensive! Checks Hermitian, Tr(ρ)=1, positive semidefinite every frame
@export var enable_invariant_checks: bool = false

## Global singleton instance
static var instance: QuantumRigorConfig = null

func _init():
	# Initialize singleton if not already set
	if instance == null:
		instance = self

## Get collapse strength for measurement backaction
func get_collapse_strength() -> float:
	match backaction_mode:
		BackactionMode.LAB_TRUE:
			return 1.0  # Full projective collapse
		BackactionMode.KID_LIGHT:
			return 0.5  # Gentle partial collapse
		_:
			return 0.5  # Default to gentle

## Check if Lab Mode is enabled (strict quantum rigor)
func is_lab_mode() -> bool:
	return backaction_mode == BackactionMode.LAB_TRUE

## Check if Hardware Mode is enabled (shot-based readout)
func is_hardware_mode() -> bool:
	return readout_mode == ReadoutMode.HARDWARE

## Serialize configuration for save/load
func serialize() -> Dictionary:
	return {
		"readout_mode": readout_mode,
		"backaction_mode": backaction_mode,
		"selective_measure_model": selective_measure_model,
		"enable_invariant_checks": enable_invariant_checks
	}

## Deserialize configuration from save data
func deserialize(data: Dictionary) -> void:
	readout_mode = data.get("readout_mode", ReadoutMode.INSPECTOR)
	backaction_mode = data.get("backaction_mode", BackactionMode.KID_LIGHT)
	selective_measure_model = data.get("selective_measure_model", SelectiveMeasureModel.POSTSELECT_COSTED)
	enable_invariant_checks = data.get("enable_invariant_checks", false)

## Get user-friendly mode description
func get_mode_description() -> String:
	var readout_desc = "Inspector" if readout_mode == ReadoutMode.INSPECTOR else "Hardware"
	var backaction_desc = "Gentle" if backaction_mode == BackactionMode.KID_LIGHT else "Rigorous"
	var measure_desc = "Costed" if selective_measure_model == SelectiveMeasureModel.POSTSELECT_COSTED else "Click/NoClick"

	return "Readout:%s | Backaction:%s | Measurement:%s | Invariants:%s" % [
		readout_desc, backaction_desc, measure_desc,
		"ON" if enable_invariant_checks else "OFF"
	]
