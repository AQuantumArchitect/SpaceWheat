class_name VerboseConfig
extends Node

## Global verbose logging configuration
## Set VERBOSE_LOGGING to true to see detailed debug output
## Individual subsystems can be controlled separately

# Main verbose flag
var verbose_logging: bool = false

# Per-subsystem control
var verbose_forest: bool = false      # Forest ecosystem evolution
var verbose_quantum: bool = false      # Quantum state measurements & calculations
var verbose_biome: bool = false        # Biome initialization & state
var verbose_vocabulary: bool = false   # Vocabulary evolution & spawning
var verbose_farm: bool = false         # Farm initialization details
var verbose_network: bool = false      # Conspiracy network state

func _ready():
	# Check for --verbose flag or VERBOSE_LOGGING env var
	var args = OS.get_cmdline_args()
	if "--verbose" in args or OS.get_environment("VERBOSE_LOGGING") == "1":
		verbose_logging = true
		print("🔍 VERBOSE LOGGING ENABLED")
	else:
		# Check for subsystem-specific flags
		var env = OS.get_environment("VERBOSE_FOREST")
		if env == "1":
			verbose_forest = true
			print("🌲 VERBOSE FOREST LOGGING ENABLED")

func is_verbose(subsystem: String = "") -> bool:
	"""Check if we should show verbose output for a subsystem"""
	if verbose_logging:
		return true

	match subsystem:
		"forest":
			return verbose_forest
		"quantum":
			return verbose_quantum
		"biome":
			return verbose_biome
		"vocabulary":
			return verbose_vocabulary
		"farm":
			return verbose_farm
		"network":
			return verbose_network
		_:
			return false
