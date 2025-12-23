extends Node

func _ready():
	print("Test started")
	# Try to load the test version
	var TestQubit = preload("res://Core/QuantumSubstrate/DualEmojiQubit_test.gd")
	var qubit = TestQubit.new()
	print("Test qubit loaded successfully")
	print("Qubit theta: %s" % qubit.theta)
