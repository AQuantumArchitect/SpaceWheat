class_name BellStateDetector
extends Node

## Bell State Detection System for Quantum Kitchen
##
## Analyzes spatial arrangement of 3 plots to determine Bell state configuration
##
## Triple Bell States:
## 1. GHZ State - Linear arrangement (horizontal, vertical, diagonal)
##    |000⟩ + |111⟩ configuration
##    All three qubits maximally correlated
##
## 2. W State - L-shape arrangement (corner patterns)
##    |001⟩ + |010⟩ + |100⟩ configuration
##    Any one qubit can be different
##
## 3. Cluster State - T-shape arrangement
##    Linear + perpendicular configuration
##    Useful for measurement-based computation
##
## Plot positions: Vector2i(x, y)

enum BellStateType {
	NONE,           # Not a valid Bell state
	GHZ_HORIZONTAL, # Three in a row (---)
	GHZ_VERTICAL,   # Three in a column (|)
	GHZ_DIAGONAL,   # Three diagonal (\\ or /)
	W_STATE,        # L-shape or corner
	CLUSTER_STATE   # T-shape or line + perpendicular
}

## Configuration of three plots
var plot_positions = []
var plot_types = []  # ["wheat", "water", "flour"] (order matters)

## Detected state
var detected_state: BellStateType = BellStateType.NONE
var state_strength: float = 0.0  # 0.0 = weak, 1.0 = perfect


func set_plots(positions, types):
	"""
	Set the three plots to analyze for Bell state

	positions: [Vector2i(x,y), Vector2i(x,y), Vector2i(x,y)] - plot positions
	types: ["wheat", "water", "flour"] - must be in this order for triplet
	"""
	if positions.size() != 3 or types.size() != 3:
		push_error("BellStateDetector requires exactly 3 plots")
		return

	plot_positions = positions
	plot_types = types

	_analyze_state()


func _analyze_state():
	"""Analyze spatial arrangement to detect Bell state type"""
	if plot_positions.size() != 3:
		detected_state = BellStateType.NONE
		state_strength = 0.0
		return

	# Sort positions to normalize
	var sorted_positions = plot_positions.duplicate()
	sorted_positions.sort_custom(_sort_positions)

	var p0 = sorted_positions[0]
	var p1 = sorted_positions[1]
	var p2 = sorted_positions[2]

	# Check for linear arrangements (GHZ states)
	if _is_horizontal_line(p0, p1, p2):
		detected_state = BellStateType.GHZ_HORIZONTAL
		state_strength = 1.0
		return

	if _is_vertical_line(p0, p1, p2):
		detected_state = BellStateType.GHZ_VERTICAL
		state_strength = 1.0
		return

	if _is_diagonal_line(p0, p1, p2):
		detected_state = BellStateType.GHZ_DIAGONAL
		state_strength = 1.0
		return

	# Check for L-shape (W state)
	if _is_l_shape(p0, p1, p2):
		detected_state = BellStateType.W_STATE
		state_strength = 1.0
		return

	# Check for T-shape (cluster state)
	if _is_t_shape(p0, p1, p2):
		detected_state = BellStateType.CLUSTER_STATE
		state_strength = 1.0
		return

	# No valid Bell state detected
	detected_state = BellStateType.NONE
	state_strength = 0.0


func _is_horizontal_line(p0: Vector2i, p1: Vector2i, p2: Vector2i) -> bool:
	"""Three plots in horizontal line: (x,y), (x+1,y), (x+2,y)"""
	if p0.y == p1.y and p1.y == p2.y:
		if p1.x == p0.x + 1 and p2.x == p1.x + 1:
			return true
		if p1.x == p0.x - 1 and p2.x == p1.x - 1:
			return true
	return false


func _is_vertical_line(p0: Vector2i, p1: Vector2i, p2: Vector2i) -> bool:
	"""Three plots in vertical line: (x,y), (x,y+1), (x,y+2)"""
	if p0.x == p1.x and p1.x == p2.x:
		if p1.y == p0.y + 1 and p2.y == p1.y + 1:
			return true
		if p1.y == p0.y - 1 and p2.y == p1.y - 1:
			return true
	return false


func _is_diagonal_line(p0: Vector2i, p1: Vector2i, p2: Vector2i) -> bool:
	"""Three plots in diagonal line: (x,y), (x+1,y+1), (x+2,y+2) or similar"""
	# Forward slash diagonal
	if (p1.x == p0.x + 1 and p1.y == p0.y + 1 and
		p2.x == p1.x + 1 and p2.y == p1.y + 1):
		return true

	# Backward slash diagonal
	if (p1.x == p0.x + 1 and p1.y == p0.y - 1 and
		p2.x == p1.x + 1 and p2.y == p1.y - 1):
		return true

	# Reverse forward slash
	if (p1.x == p0.x - 1 and p1.y == p0.y - 1 and
		p2.x == p1.x - 1 and p2.y == p1.y - 1):
		return true

	# Reverse backward slash
	if (p1.x == p0.x - 1 and p1.y == p0.y + 1 and
		p2.x == p1.x - 1 and p2.y == p1.y + 1):
		return true

	return false


func _is_l_shape(p0: Vector2i, p1: Vector2i, p2: Vector2i) -> bool:
	"""L-shape: two in line, one perpendicular"""
	# Check all permutations to find L pattern
	var points = [p0, p1, p2]

	for i in range(3):
		for j in range(3):
			if i == j:
				continue
			for k in range(3):
				if k == i or k == j:
					continue

				var corner = points[i]
				var horizontal = points[j]
				var vertical = points[k]

				# Check if corner is at bend of L
				if corner.x == horizontal.x and corner.y == vertical.y:
					# corner is at intersection
					if abs(horizontal.x - corner.x) == 1 and abs(vertical.y - corner.y) == 1:
						return true

	return false


func _is_t_shape(p0: Vector2i, p1: Vector2i, p2: Vector2i) -> bool:
	"""T-shape: linear arrangement with perpendicular offset"""
	var points = [p0, p1, p2]

	# Check if any point is perpendicular to the line of other two
	for i in range(3):
		var center = points[i]
		var other0 = points[(i + 1) % 3]
		var other1 = points[(i + 2) % 3]

		# Check if other two are collinear on x or y, and center is offset perpendicularly
		if other0.x == other1.x:
			# others are vertical line, center should be offset horizontally
			if center.x != other0.x and (center.y == other0.y or center.y == other1.y):
				if abs(center.x - other0.x) == 1:
					return true

		if other0.y == other1.y:
			# others are horizontal line, center should be offset vertically
			if center.y != other0.y and (center.x == other0.x or center.x == other1.x):
				if abs(center.y - other0.y) == 1:
					return true

	return false


func get_state_type() -> BellStateType:
	"""Get detected Bell state type"""
	return detected_state


func get_state_name() -> String:
	"""Get human-readable name of detected state"""
	match detected_state:
		BellStateType.NONE:
			return "None"
		BellStateType.GHZ_HORIZONTAL:
			return "GHZ (Horizontal)"
		BellStateType.GHZ_VERTICAL:
			return "GHZ (Vertical)"
		BellStateType.GHZ_DIAGONAL:
			return "GHZ (Diagonal)"
		BellStateType.W_STATE:
			return "W State"
		BellStateType.CLUSTER_STATE:
			return "Cluster State"
		_:
			return "Unknown"


func get_state_strength() -> float:
	"""Get quality of Bell state (0.0 = none, 1.0 = perfect)"""
	return state_strength


func is_valid_triplet() -> bool:
	"""Check if a valid Bell state is configured"""
	return detected_state != BellStateType.NONE and state_strength > 0.5


func get_state_description() -> String:
	"""Get quantum description of the Bell state"""
	match detected_state:
		BellStateType.GHZ_HORIZONTAL:
			return "|000⟩ + |111⟩ (horizontal alignment, maximally entangled)"
		BellStateType.GHZ_VERTICAL:
			return "|000⟩ + |111⟩ (vertical alignment, maximally entangled)"
		BellStateType.GHZ_DIAGONAL:
			return "|000⟩ + |111⟩ (diagonal alignment, maximally entangled)"
		BellStateType.W_STATE:
			return "|001⟩ + |010⟩ + |100⟩ (any one different, robust to loss)"
		BellStateType.CLUSTER_STATE:
			return "Measurement-based state (one-way computation ready)"
		_:
			return "Not a valid Bell state"


func _sort_positions(a: Vector2i, b: Vector2i) -> bool:
	"""Sort positions left-to-right, then top-to-bottom"""
	if a.x != b.x:
		return a.x < b.x
	return a.y < b.y
