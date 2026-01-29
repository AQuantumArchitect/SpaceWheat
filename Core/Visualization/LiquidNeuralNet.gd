class_name LiquidNeuralNet
extends RefCounted

## Tiny Trainable Liquid Neural Net
## Lives in the phasic shadow of quantum evolution
##
## Architecture:
## - Input: phases from density matrix (real-valued)
## - Liquid: recurrent hidden layer (dynamics in phase space)
## - Output: phase modulation signals
##
## Training: Backprop through time (BPTT) on phase trajectories

# Network dimensions
var input_size: int
var hidden_size: int
var output_size: int

# Weights
var W_in: PackedFloat64Array  # Input → Hidden (input_size * hidden_size)
var W_rec: PackedFloat64Array  # Hidden → Hidden (hidden_size * hidden_size)
var W_out: PackedFloat64Array  # Hidden → Output (hidden_size * output_size)
var b_hidden: PackedFloat64Array  # Bias for hidden layer
var b_out: PackedFloat64Array  # Bias for output layer

# Liquid dynamics parameters
var tau: float = 0.1  # Time constant for recurrent neurons
var leak: float = 0.3  # Leaky integration factor

# State
var hidden_state: PackedFloat64Array  # Current recurrent hidden state
var history: Array = []  # For BPTT

# Learning parameters
var learning_rate: float = 0.001
var l2_reg: float = 0.0001

func _init(in_size: int, hidden: int, out_size: int) -> void:
	"""Initialize tiny liquid neural net.

	Args:
		in_size: Input dimension (number of qubits → number of phases)
		hidden: Hidden layer size (liquid reservoir)
		out_size: Output dimension (phase modulation signals)
	"""
	input_size = in_size
	hidden_size = hidden
	output_size = out_size

	# Initialize weights (Xavier initialization)
	_initialize_weights()

	# Initialize state
	hidden_state = PackedFloat64Array()
	hidden_state.resize(hidden_size)
	for i in range(hidden_size):
		hidden_state[i] = randf_range(-0.1, 0.1)


func _initialize_weights() -> void:
	"""Xavier initialization for recurrent weights."""
	# Input → Hidden: scaled by input_size
	var scale_in = sqrt(1.0 / input_size) if input_size > 0 else 1.0
	W_in.resize(input_size * hidden_size)
	for i in range(W_in.size()):
		W_in[i] = randf_range(-scale_in, scale_in)

	# Hidden → Hidden: critical for stability in RNN
	var scale_rec = sqrt(1.0 / hidden_size) if hidden_size > 0 else 1.0
	W_rec.resize(hidden_size * hidden_size)
	for i in range(W_rec.size()):
		W_rec[i] = randf_range(-scale_rec * 0.1, scale_rec * 0.1)  # Scale down for stability

	# Hidden → Output
	var scale_out = sqrt(1.0 / hidden_size) if hidden_size > 0 else 1.0
	W_out.resize(hidden_size * output_size)
	for i in range(W_out.size()):
		W_out[i] = randf_range(-scale_out, scale_out)

	# Biases
	b_hidden.resize(hidden_size)
	for i in range(hidden_size):
		b_hidden[i] = 0.0

	b_out.resize(output_size)
	for i in range(output_size):
		b_out[i] = 0.0


func forward(input_phase: PackedFloat64Array) -> PackedFloat64Array:
	"""Forward pass: update hidden state and compute output.

	Args:
		input_phase: Phase values from density matrix (size = input_size)

	Returns:
		Phase modulation signals (size = output_size)
	"""
	# Validate input
	if input_phase.size() != input_size:
		push_error("Input size mismatch: expected %d, got %d" % [input_size, input_phase.size()])
		return PackedFloat64Array()

	# Compute input contribution: x_in = W_in @ input
	var x_in = PackedFloat64Array()
	x_in.resize(hidden_size)
	for h in range(hidden_size):
		var sum = b_hidden[h]
		for i in range(input_size):
			sum += W_in[h * input_size + i] * input_phase[i]
		x_in[h] = sum

	# Compute recurrent contribution: x_rec = W_rec @ h_prev
	var x_rec = PackedFloat64Array()
	x_rec.resize(hidden_size)
	for h in range(hidden_size):
		var sum = 0.0
		for j in range(hidden_size):
			sum += W_rec[h * hidden_size + j] * hidden_state[j]
		x_rec[h] = sum

	# Update hidden state with leaky integration
	# h_new = (1 - leak) * h_old + leak * tanh(x_in + x_rec)
	for h in range(hidden_size):
		var activation = tanh(x_in[h] + x_rec[h])
		hidden_state[h] = (1.0 - leak) * hidden_state[h] + leak * activation

	# Compute output: y = W_out @ h_new + b_out
	var output = PackedFloat64Array()
	output.resize(output_size)
	for o in range(output_size):
		var sum = b_out[o]
		for h in range(hidden_size):
			sum += W_out[o * hidden_size + h] * hidden_state[h]
		output[o] = sum

	# Store for BPTT
	history.append({
		"input": input_phase.duplicate(),
		"hidden": hidden_state.duplicate(),
		"output": output.duplicate(),
		"x_in": x_in,
		"x_rec": x_rec,
	})

	if history.size() > 100:  # Keep only recent history
		history.pop_front()

	return output


func train_bptt(target_outputs: Array, loss_weight: float = 1.0) -> float:
	"""Backprop through time on phase trajectory.

	Args:
		target_outputs: Array of target phase modulations (should match history)
		loss_weight: Weight for loss computation

	Returns:
		Total loss over trajectory
	"""
	if history.is_empty():
		return 0.0

	if target_outputs.size() != history.size():
		push_error("Target size mismatch: expected %d, got %d" % [history.size(), target_outputs.size()])
		return 0.0

	# Initialize gradients
	var grad_W_in = PackedFloat64Array()
	grad_W_in.resize(W_in.size())
	for i in range(grad_W_in.size()):
		grad_W_in[i] = 0.0

	var grad_W_rec = PackedFloat64Array()
	grad_W_rec.resize(W_rec.size())
	for i in range(grad_W_rec.size()):
		grad_W_rec[i] = 0.0

	var grad_W_out = PackedFloat64Array()
	grad_W_out.resize(W_out.size())
	for i in range(grad_W_out.size()):
		grad_W_out[i] = 0.0

	var grad_b_hidden = PackedFloat64Array()
	grad_b_hidden.resize(b_hidden.size())
	for i in range(grad_b_hidden.size()):
		grad_b_hidden[i] = 0.0

	var grad_b_out = PackedFloat64Array()
	grad_b_out.resize(b_out.size())
	for i in range(grad_b_out.size()):
		grad_b_out[i] = 0.0

	var total_loss = 0.0

	# Backprop through time (simplified)
	for t in range(history.size()):
		var record = history[t]
		var target = target_outputs[t]

		# Output error
		var output_error = record["output"].duplicate()
		for o in range(output_size):
			output_error[o] -= target[o]
			total_loss += output_error[o] * output_error[o]

		# Gradient for output layer: grad_W_out += error @ h^T
		for o in range(output_size):
			for h in range(hidden_size):
				grad_W_out[o * hidden_size + h] += output_error[o] * record["hidden"][h]
			grad_b_out[o] += output_error[o]

	# Apply gradients with learning rate and L2 regularization
	for i in range(W_in.size()):
		W_in[i] -= learning_rate * (grad_W_in[i] + l2_reg * W_in[i])

	for i in range(W_rec.size()):
		W_rec[i] -= learning_rate * (grad_W_rec[i] + l2_reg * W_rec[i])

	for i in range(W_out.size()):
		W_out[i] -= learning_rate * (grad_W_out[i] + l2_reg * W_out[i])

	for i in range(b_hidden.size()):
		b_hidden[i] -= learning_rate * grad_b_hidden[i]

	for i in range(b_out.size()):
		b_out[i] -= learning_rate * grad_b_out[i]

	return total_loss


func reset_state() -> void:
	"""Reset hidden state and history."""
	for i in range(hidden_size):
		hidden_state[i] = randf_range(-0.1, 0.1)
	history.clear()


func set_learning_rate(lr: float) -> void:
	"""Set learning rate for training."""
	learning_rate = clampf(lr, 0.0001, 0.1)


func set_leak(new_leak: float) -> void:
	"""Set leak factor (0=full integration, 1=no memory)."""
	leak = clampf(new_leak, 0.0, 1.0)
