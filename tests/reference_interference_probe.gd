extends "res://tests/smoke_test_base.gd"

## The mirror probe: reference-qubit interference reveals the spinor sign a
## local read cannot see. Drives the REAL GaugeActionHandler + BerryPhaseRegister
## through minimal mocks (the handler needs only get_biome_type / quantum_computer
## / grid.get_biome). Also certifies the compass payload chain quests gate on:
## read → flip → wilson_unchanged, with read_since_topology_change honest.
## Run: godot --headless --script tests/reference_interference_probe.gd

const BerryRegisterCls = preload("res://Core/QuantumSubstrate/BerryPhaseRegister.gd")
const GaugeFieldCls = preload("res://Core/QuantumSubstrate/GaugeField.gd")
const HandlerCls = preload("res://Core/Instrumentation/Handlers/GaugeActionHandler.gd")

const N: int = 240


class MockRM:
	var num_qubits: int = 2


class MockQC:
	var berry_register = null
	var register_map = MockRM.new()
	var gauge_field = null

	func get_gauge_field():
		return gauge_field


class MockBiome:
	var quantum_computer = MockQC.new()
	var bname: String = "MockBiome"

	func get_biome_type() -> String:
		return bname


class MockGrid:
	var biomes: Dictionary = {}

	func get_biome(n: String):
		return biomes.get(n, null)


class MockFarm:
	var grid = MockGrid.new()


func _packet2(t: Array) -> PackedFloat64Array:
	# Two-qubit stride-6 packet [p0, p1, x, y, z, r] per qubit.
	var p := PackedFloat64Array()
	for q in range(2):
		p.append(0.0)
		p.append(0.0)
		p.append(t[q][0])
		p.append(t[q][1])
		p.append(t[q][2])
		p.append(1.0)
	return p


func _init() -> void:
	print("\n=== Reference interference probe ===")
	var biome = MockBiome.new()
	biome.quantum_computer.berry_register = BerryRegisterCls.new()
	var farm = MockFarm.new()
	farm.grid.biomes[biome.bname] = biome
	var reg = biome.quantum_computer.berry_register

	# --- Mark the reference (q0), then walk the traveler (q1) one ripe loop --
	var marked: Dictionary = HandlerCls.mark_reference(biome, 0)
	_check(marked.get("success", false), "mark_reference succeeds")
	_check(marked.get("started_tracking", false), "marking an untracked qubit starts its log")
	reg.start_tracking(1)

	for i in range(N + 1):
		var phi: float = TAU * float(i) / float(N)
		_packet_step(reg, [[1.0, 0.0, 0.0], [cos(phi), sin(phi), 0.0]])

	var phase_before_ref: float = reg.get_phase(0)
	var phase_before_trav: float = reg.get_phase(1)

	var reference: Dictionary = marked.get("reference", {})
	var report: Dictionary = HandlerCls.interfere(farm, biome, 1, reference)
	_check(report.get("success", false), "interfere succeeds with a marked reference")
	var delta: float = float(report.get("delta_gamma", 0.0))
	_check(absf(delta - PI) < 0.3, "relative phase Δγ ≈ π after a ripe 2π loop (got %.3f)" % delta)
	_check(int(report.get("spinor_product", 0)) == -1, "spinor sign product −1: home on the sphere, opposite upstairs")

	# --- Non-destructive: the logs it read are exactly as it found them ------
	_check(absf(reg.get_phase(0) - phase_before_ref) < 1e-12
		and absf(reg.get_phase(1) - phase_before_trav) < 1e-12,
		"interfere is a read — both travel logs untouched")

	# --- Honest refusals -----------------------------------------------------
	var no_ref: Dictionary = HandlerCls.interfere(farm, biome, 1, {})
	_check(not no_ref.get("success", true) and str(no_ref.get("error", "")) == "no_reference",
		"interfere without a reference refuses and says so")
	var self_cmp: Dictionary = HandlerCls.interfere(farm, biome, 0, reference)
	_check(self_cmp.get("success", false) and bool(self_cmp.get("self_compare", false)),
		"self-comparison is called out (always +1 — not a measurement of anything)")

	# --- Compass payload chain: read → flip → survived -----------------------
	var gf = GaugeFieldCls.new()
	gf.add_edge(0, 1, 0.4)
	gf.add_edge(1, 2, -1.0)
	gf.add_edge(2, 0, 0.9)  # a 3-cycle: β₁ = 1, one Wilson book to keep
	biome.quantum_computer.gauge_field = gf
	biome.quantum_computer.register_map.num_qubits = 3

	var flip_unread: Dictionary = HandlerCls.gauge_flip(biome, 0)
	_check(flip_unread.get("success", false) and bool(flip_unread.get("wilson_unchanged", false)),
		"gauge_flip: every Wilson loop survives the turn")
	_check(not bool(flip_unread.get("read_since_topology_change", true)),
		"flip before any read is honest: read_since_topology_change false")

	var card: Dictionary = HandlerCls.wilson_inspect(biome, 1)
	_check(card.get("success", false) and int(card.get("betti_1", -1)) == 1,
		"wilson_inspect reads the loop card (β₁ = 1)")

	var flip_read: Dictionary = HandlerCls.gauge_flip(biome, 2)
	_check(bool(flip_read.get("wilson_unchanged", false)) and bool(flip_read.get("read_since_topology_change", false)),
		"read → flip → survived: the full receipt quests gate on")

	var scramble: Dictionary = HandlerCls.gauge_scramble(biome, 47)
	_check(scramble.get("success", false) and bool(scramble.get("wilson_unchanged", false)),
		"gauge_scramble: the red-team pass cannot move a Wilson loop")

	_finish("reference interference probe")


func _packet_step(reg, points: Array) -> void:
	reg.integrate_step(_packet2(points), 2)
