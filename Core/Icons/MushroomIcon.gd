class_name MushroomIcon extends IconHamiltonian
## Mushroom Icon: Lunar-aligned crop that grows during night phase
##
## Defines Hamiltonian coupling to sun's quantum state (moon phase is opposite)
## Icon influence (energy transfer scaling) is derived from internal qubit state

func _ready():
	"""Initialize mushroom icon quantum state and Hamiltonian"""
	super._ready()  # Call parent class initialization

	# Internal qubit state representing icon's quantum properties
	# θ = 163° gives weak icon influence via cos²(81.5°) ≈ 0.023 (NERFED to wheat scale)
	var icon_qubit = DualEmojiQubit.new("🍄", "🍂", 163*PI/180)
	icon_qubit.radius = 1.0  # Icons always perfect coherence

	# Store reference for icon influence calculation
	internal_qubit = icon_qubit

	# Hamiltonian terms: Pure σ_z coupling (alignment to moon phase)
	# When sun_theta = π (midnight), moon phase aligns with mushroom growth
	# σ_z = |north⟩⟨north| - |south⟩⟨south|
	hamiltonian_terms = {
		"sigma_x": 0.0,     # No transverse field
		"sigma_y": 0.0,     # No rotation
		"sigma_z": 0.023,   # Weak coupling - mushrooms are more sensitive to sun damage than phase alignment
	}

	# Icon influence strength - used in energy transfer
	# Set to 0.04 for balanced growth (reduced from 0.023)
	icon_influence = 0.04

	# Stable point: mushroom naturally attracted to midnight (θ=π)
	stable_theta = PI
	spring_constant = 0.5  # Same rotational spring constant as wheat

	# Sun damage: fungi harmed by sunlight (5x stronger than base)
	sun_damage_strength = 0.05  # Max 0.05 damage/sec when aligned with sun
