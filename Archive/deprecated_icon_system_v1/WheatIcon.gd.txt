class_name WheatIcon extends IconHamiltonian
## Wheat Icon: Solar-aligned crop that grows during day phase
##
## Defines Hamiltonian coupling to sun's quantum state
## Icon influence (energy transfer scaling) is derived from internal qubit state

func _ready():
	"""Initialize wheat icon quantum state and Hamiltonian"""
	super._ready()  # Call parent class initialization

	# Internal qubit state representing icon's quantum properties
	# θ = 165° gives weak icon influence via cos²(82.5°) ≈ 0.017
	var icon_qubit = DualEmojiQubit.new("🌾", "🏰", 11*PI/12)
	icon_qubit.radius = 1.0  # Icons always perfect coherence

	# Store reference for icon influence calculation
	internal_qubit = icon_qubit

	# Hamiltonian terms: Pure σ_z coupling (alignment to sun phase)
	# σ_z = |north⟩⟨north| - |south⟩⟨south|
	# Couples wheat phase to sun phase via energy matching
	hamiltonian_terms = {
		"sigma_x": 0.0,     # No transverse field (no superposition creation)
		"sigma_y": 0.0,     # No rotation
		"sigma_z": 0.1,     # Longitudinal field (phase alignment)
	}

	# Icon influence strength: cos²(θ_icon/2) - used in energy transfer
	# Wheat at 165° gives weak influence (0.017) so free field can still grow well
	icon_influence = pow(cos(icon_qubit.theta / 2.0), 2)

	# Stable point: wheat naturally attracted to mid-afternoon (π/4 ≈ 45°)
	stable_theta = PI / 4.0
	spring_constant = 0.5  # Rotational spring constant
