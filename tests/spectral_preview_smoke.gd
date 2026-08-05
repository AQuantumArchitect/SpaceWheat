extends "res://tests/smoke_test_base.gd"

## Pin SpectralPreview's parity claim: the what-if gap must be bit-identical
## to the gap the LIVE builder produces for the same axes — preview and live
## share icons_from_axes (one derivation) and gap_of_hamiltonian (one packing
## trick), and this smoke is the compiler for that sharing. A preview that
## drifts from the real builder would be a lying instrument at the exact
## moment of composition (the picker's "gap 0.61→0.54 ▼").
##
## Run: godot --headless --path . --script tests/spectral_preview_smoke.gd

const SpectralPreview := preload("res://Core/QuantumSubstrate/SpectralPreview.gd")
const QC := preload("res://Core/QuantumSubstrate/QuantumComputer.gd")
const Builder := preload("res://Core/Environment/Components/BiomeQuantumSystemBuilder.gd")

# Real icons.json axes (Hearth + Factory + Predation) — self-energies AND a
# rabi term, so the gap is a nontrivial number, not a degenerate 0.
const AXES := [
	{"north": "🔥", "south": "❄"},
	{"north": "⚙", "south": "🏭"},
	{"north": "🦅", "south": "🩸"},
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== SpectralPreview parity smoke ===")

	# --- Live side: real QC through the real builder --------------------------
	var qc = QC.new()
	for i in range(AXES.size()):
		qc.allocate_axis(i, AXES[i]["north"], AXES[i]["south"])
	var builder = Builder.new()
	builder.quantum_computer = qc
	var rebuilt: bool = builder.rebuild_operators_from_register_map()
	_check(rebuilt, "live builder rebuilds from the register map")
	var live: float = qc.get_hamiltonian_spectral_gap()
	_check(live >= 0.0, "live gap is measurable", "got %f" % live)

	# --- Preview side: same axes, pure statics --------------------------------
	var preview: float = SpectralPreview.gap_for_axes(AXES.duplicate(true))
	_check(preview >= 0.0, "preview gap is measurable", "got %f" % preview)
	_check(absf(preview - live) < 1e-9,
			"preview == live (one derivation, one packing trick)",
			"preview %f vs live %f" % [preview, live])

	# Determinism (also exercises nothing-cached vs computed agreement).
	_check(absf(SpectralPreview.gap_for_axes(AXES.duplicate(true)) - preview) < 1e-12,
			"preview is deterministic")

	# Appending an axis == previewing the grown biome directly.
	var grown: Array = AXES.duplicate(true)
	grown.append({"north": "💧", "south": "🌊"})
	var grown_gap: float = SpectralPreview.gap_for_axes(grown)
	_check(grown_gap >= 0.0, "grown-axes preview measurable")
	_check(absf(grown_gap - preview) > 1e-6 or grown_gap != preview,
			"adding an axis changes the spectrum (not a constant function)")

	# Cost guard: past MAX_PREVIEW_DIM the preview says "—", never hitches.
	var huge: Array = []
	for i in range(12):
		huge.append({"north": "🔥", "south": "❄"})
	_check(SpectralPreview.gap_for_axes(huge) == -1.0,
			"dim guard refuses honestly above MAX_PREVIEW_DIM")

	_finish("spectral preview smoke")
