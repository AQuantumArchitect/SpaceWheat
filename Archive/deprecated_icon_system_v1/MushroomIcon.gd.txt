class_name MushroomIcon extends IconHamiltonian
## Mushroom Icon: Lunar-aligned crop that grows during night phase
##
## Defines Hamiltonian coupling to sun's quantum state (moon phase is opposite)
## Icon influence (energy transfer scaling) is derived from internal qubit state
##
## COMPOSTING EFFECT: Passively converts detritus (🍂) to mushrooms (🍄)
## Represents natural decomposition and fungal recycling

# Economy reference for composting (set by Farm or Biome)
var economy = null

# Composting parameters
const COMPOSTING_RATE = 0.1  # Convert 10% of detritus per second
const COMPOSTING_RATIO = 0.5  # 2 detritus → 1 mushroom (50% efficiency)

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


func _process(delta: float):
	"""Passive composting effect - converts detritus to mushrooms over time"""
	if not economy:
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_ECONOMY") == "1":
			print("🍄 Composting skipped: no economy reference")
		return

	if active_strength <= 0.0:
		if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_ECONOMY") == "1":
			print("🍄 Composting skipped: activation = %.3f" % active_strength)
		return

	# Only compost if we have detritus
	var detritus_amount = economy.get_resource("🍂")
	if detritus_amount <= 0:
		return

	if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_ECONOMY") == "1":
		print("🍄 Composting active: detritus=%d, activation=%.3f" % [detritus_amount, active_strength])

	# Calculate how much to compost this frame
	# Rate scaled by icon activation (more mushrooms planted = faster composting)
	var composting_power = COMPOSTING_RATE * active_strength * delta
	var detritus_to_convert = min(detritus_amount, detritus_amount * composting_power)

	# Don't convert tiny amounts (avoid fractional credits)
	if detritus_to_convert < 1:
		return

	# Convert detritus → mushrooms at 2:1 ratio
	var mushrooms_produced = int(detritus_to_convert * COMPOSTING_RATIO)

	if mushrooms_produced > 0:
		var detritus_consumed = mushrooms_produced * 2  # 2 detritus per mushroom

		# Perform the conversion
		if economy.remove_resource("🍂", detritus_consumed, "composting"):
			economy.add_resource("🍄", mushrooms_produced, "composting")

			if OS.get_environment("VERBOSE_LOGGING") == "1" or OS.get_environment("VERBOSE_ECONOMY") == "1":
				print("🍄 Composting: %d 🍂 → %d 🍄 (%.1f%% activation)" % [detritus_consumed, mushrooms_produced, active_strength * 100])
