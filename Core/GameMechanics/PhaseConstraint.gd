class_name PhaseConstraint
extends Resource

## Phase Constraint System
## Controls whether wheat can move on the Bloch sphere
## Used by different plot types to restrict quantum evolution

# Constraint types
enum ConstraintType {
	FREE,        # No restrictions - full quantum dynamics
	FROZEN,      # Theta and phi locked - scalar-only growth
}

var constraint_type: ConstraintType = ConstraintType.FREE
var frozen_theta: float = 0.0  # Locked theta value (when FROZEN)
var frozen_phi: float = 0.0    # Locked phi value (when FROZEN)


func _init(p_type: ConstraintType = ConstraintType.FREE, p_theta: float = 0.0, p_phi: float = 0.0):
	constraint_type = p_type
	frozen_theta = p_theta
	frozen_phi = p_phi


## Apply constraint to qubit
func apply_constraint(qubit: Resource) -> void:
	"""Apply phase constraint to wheat qubit

	If FROZEN: locks theta and phi to specific values
	If FREE: no effect
	"""
	if not qubit:
		return

	if constraint_type == ConstraintType.FROZEN:
		# Lock theta and phi to frozen values
		qubit.theta = frozen_theta
		qubit.phi = frozen_phi


## Query functions
func is_frozen() -> bool:
	return constraint_type == ConstraintType.FROZEN


func can_evolve_phase() -> bool:
	return constraint_type == ConstraintType.FREE


