extends "res://tests/smoke_test_base.gd"

## LoopCard gather shape + Berry freeze persist. Headless.
## Run: godot --headless --path . --script tests/loop_card_smoke.gd

const Berry = preload("res://Core/QuantumSubstrate/BerryPhaseRegister.gd")
const LoopCardCls = preload("res://UI/Overlays/LoopCard.gd")
const GaugeFieldCls = preload("res://Core/QuantumSubstrate/GaugeField.gd")


class MockRM:
	var num_qubits: int = 1


class MockQC:
	var berry_register = null
	var register_map = MockRM.new()
	var gauge_field = null
	func get_gauge_field():
		return gauge_field


class MockBiome:
	var quantum_computer = MockQC.new()
	func get_biome_type() -> String:
		return "MockForest"


func _init() -> void:
	print("\n=== LoopCard + berry persist ===")
	var biome = MockBiome.new()
	biome.quantum_computer.berry_register = Berry.new()
	var gf = GaugeFieldCls.new()
	gf.add_edge(0, 1, 0.4)
	gf.add_edge(1, 2, -1.0)
	gf.add_edge(2, 0, 0.9)
	biome.quantum_computer.gauge_field = gf
	biome.quantum_computer.register_map.num_qubits = 3

	var card: Dictionary = LoopCardCls.gather(biome)
	_check(bool(card.get("present", false)), "LoopCard present on a live biome")
	_check(int(card.get("betti_1", -1)) == 1, "LoopCard reports β₁ = 1")
	_check((card.get("cycles", []) as Array).size() == 1, "LoopCard lists the Wilson cycle")
	_check(LoopCardCls.format_text(card).contains("β₁"), "format_text names β₁")

	var reg = biome.quantum_computer.berry_register
	reg.start_tracking(0)
	for i in range(241):
		var phi: float = TAU * float(i) / 240.0
		var p := PackedFloat64Array()
		p.append_array([0.0, 0.0, cos(phi), sin(phi), 0.0, 1.0])
		reg.integrate_step(p, 1)
	_check(reg.frozen_loop_count() == 1, "ripe equator freezes one record")
	_check(bool(reg.last_record_for(0).get("spinor_flip", false)), "ripe freeze is spinor-flipped")

	var frozen: Array = reg.serialize_frozen()
	var tracked: Array = reg.serialize_tracked()
	var clone = Berry.new()
	clone.restore_frozen(frozen)
	clone.restore_tracked(tracked)
	_check(clone.frozen_loop_count() == 1, "restore_frozen keeps the record")
	_check(clone.has_fiber_ledger(0), "restored record is a fiber ledger")
	_check(clone.get_spinor_sign(0) == -1, "restored ripe record still reads −1")

	_finish("loop_card_smoke")
