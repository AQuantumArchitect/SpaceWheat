#!/usr/bin/env -S godot --headless -s
extends "res://tests/smoke_test_base.gd"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	print("\n=== ComplexMatrix empty serialization smoke ===")

	var empty := ComplexMatrix.new(0)
	var packed_empty := empty._to_packed_auto()
	_check(packed_empty.get("format", "") == "dense", "Zero-dim matrix serializes as dense")
	_check(int(packed_empty.get("dim", -1)) == 0, "Zero-dim matrix keeps dim 0")
	var empty_payload = packed_empty.get("data", PackedFloat64Array())
	_check(empty_payload.size() == 0, "Zero-dim matrix keeps empty payload")

	var zero_two := ComplexMatrix.new(2)
	zero_two._from_packed_auto({"format": "dense", "dim": 2, "data": PackedFloat64Array()})
	var packed_two := zero_two._to_packed_auto()
	_check(int(packed_two.get("dim", -1)) == 2, "Two-dim matrix keeps dim 2")
	_check(packed_two.has("format"), "Two-dim matrix serializes with a format")

	_finish()
