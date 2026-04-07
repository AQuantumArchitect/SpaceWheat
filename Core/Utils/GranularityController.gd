extends RefCounted
class_name GranularityController

## Shared granularity control logic for quantum evolution substep size
## Used by: QuantumInstrumentInput, VisualBubbleTest, and any other tools

## Adjust granularity by 10x the substep size
## - Smaller dt = finer granularity = more accurate but slower
## - Larger dt = coarser granularity = faster but less accurate

const MIN_DT: float = 0.0001  # 0.1ms - ultra fine (10^-4)
const MAX_DT: float = 10000.0 # 10000s - ultra coarse (10^4, symmetric with MIN)
const MIN_TIME_SCALE: float = 0.0009765625  # 1/1024x
const MAX_TIME_SCALE: float = 16.0

static func decrease_granularity(biomes: Array) -> Dictionary:
	"""Make substeps finer (more accurate, slower) - triggered by `-` key.

	Returns: {current_dt: float, new_dt: float, biome_count: int}
	"""
	if biomes.is_empty():
		return {current_dt = 0.02, new_dt = 0.02, biome_count = 0}

	# Get current granularity from first biome
	var current_dt = 0.02
	var first_biome = biomes[0]
	if "max_evolution_dt" in first_biome:
		current_dt = first_biome.max_evolution_dt

	# 10x finer substep size = finer granularity
	var new_dt = max(current_dt * 0.1, MIN_DT)

	# Apply to all biomes
	var biome_count = 0
	for biome in biomes:
		if "max_evolution_dt" in biome:
			biome.max_evolution_dt = new_dt
			biome_count += 1

	return {
		"current_dt": current_dt,
		"new_dt": new_dt,
		"biome_count": biome_count
	}


static func increase_granularity(biomes: Array) -> Dictionary:
	"""Make substeps coarser (faster, less accurate) - triggered by `=` key.

	Returns: {current_dt: float, new_dt: float, biome_count: int}
	"""
	if biomes.is_empty():
		return {current_dt = 0.02, new_dt = 0.02, biome_count = 0}

	# Get current granularity from first biome
	var current_dt = 0.02
	var first_biome = biomes[0]
	if "max_evolution_dt" in first_biome:
		current_dt = first_biome.max_evolution_dt

	# 10x coarser substep size = coarser granularity
	var new_dt = min(current_dt * 10.0, MAX_DT)

	# Apply to all biomes
	var biome_count = 0
	for biome in biomes:
		if "max_evolution_dt" in biome:
			biome.max_evolution_dt = new_dt
			biome_count += 1

	return {
		"current_dt": current_dt,
		"new_dt": new_dt,
		"biome_count": biome_count
	}


## ============================================================================
## OBSERVATION STRIDE CONTROLS
## ============================================================================

const MIN_STRIDE: int = 0    # locked (no advancement)
const MAX_STRIDE: int = 256   # 256x fast forward

static func increase_stride(biomes: Array) -> Dictionary:
	"""Double observation stride (faster playback). 0→1 unlocks.

	Returns: {current_stride: int, new_stride: int, biome_count: int}
	"""
	if biomes.is_empty():
		return {"current_stride": 1, "new_stride": 1, "biome_count": 0}

	var current_stride: int = 1
	var first_biome = biomes[0]
	if "observation_stride" in first_biome:
		current_stride = first_biome.observation_stride

	# 0→1 unlocks, otherwise double
	var new_stride: int
	if current_stride <= 0:
		new_stride = 1
	else:
		new_stride = mini(current_stride * 2, MAX_STRIDE)

	var biome_count = 0
	for biome in biomes:
		if "observation_stride" in biome:
			biome.observation_stride = new_stride
			biome_count += 1

	return {
		"current_stride": current_stride,
		"new_stride": new_stride,
		"biome_count": biome_count
	}


static func decrease_stride(biomes: Array) -> Dictionary:
	"""Halve observation stride (slower playback). 1→0 locks.

	Returns: {current_stride: int, new_stride: int, biome_count: int}
	"""
	if biomes.is_empty():
		return {"current_stride": 1, "new_stride": 1, "biome_count": 0}

	var current_stride: int = 1
	var first_biome = biomes[0]
	if "observation_stride" in first_biome:
		current_stride = first_biome.observation_stride

	# 1→0 locks, otherwise halve
	var new_stride: int
	if current_stride <= 1:
		new_stride = 0
	else:
		new_stride = maxi(current_stride / 2, 1)

	var biome_count = 0
	for biome in biomes:
		if "observation_stride" in biome:
			biome.observation_stride = new_stride
			biome_count += 1

	return {
		"current_stride": current_stride,
		"new_stride": new_stride,
		"biome_count": biome_count
	}


static func get_current_stride(biomes: Array) -> int:
	"""Get current observation_stride from first biome."""
	if biomes.is_empty():
		return 1
	var first_biome = biomes[0]
	if "observation_stride" in first_biome:
		return first_biome.observation_stride
	return 1


static func get_current_granularity(biomes: Array) -> float:
	"""Get current max_evolution_dt from first biome."""
	if biomes.is_empty():
		return 0.02

	var first_biome = biomes[0]
	if "max_evolution_dt" in first_biome:
		return first_biome.max_evolution_dt

	return 0.02


## ============================================================================
## SIMULATION SPEED CONTROLS
## ============================================================================

static func increase_time_scale(biomes: Array) -> Dictionary:
	"""Double quantum_time_scale (faster simulation)."""
	if biomes.is_empty():
		return {"current_time_scale": 0.5, "new_time_scale": 0.5, "biome_count": 0}

	var current_time_scale: float = 0.5
	var first_biome = biomes[0]
	if "quantum_time_scale" in first_biome:
		current_time_scale = float(first_biome.quantum_time_scale)

	var new_time_scale: float = min(current_time_scale * 2.0, MAX_TIME_SCALE)
	var biome_count: int = 0
	for biome in biomes:
		if "quantum_time_scale" in biome:
			biome.quantum_time_scale = new_time_scale
			biome_count += 1

	return {
		"current_time_scale": current_time_scale,
		"new_time_scale": new_time_scale,
		"biome_count": biome_count
	}


static func decrease_time_scale(biomes: Array) -> Dictionary:
	"""Halve quantum_time_scale (slower simulation)."""
	if biomes.is_empty():
		return {"current_time_scale": 0.5, "new_time_scale": 0.5, "biome_count": 0}

	var current_time_scale: float = 0.5
	var first_biome = biomes[0]
	if "quantum_time_scale" in first_biome:
		current_time_scale = float(first_biome.quantum_time_scale)

	var new_time_scale: float = max(current_time_scale * 0.5, MIN_TIME_SCALE)
	var biome_count: int = 0
	for biome in biomes:
		if "quantum_time_scale" in biome:
			biome.quantum_time_scale = new_time_scale
			biome_count += 1

	return {
		"current_time_scale": current_time_scale,
		"new_time_scale": new_time_scale,
		"biome_count": biome_count
	}


static func get_current_time_scale(biomes: Array) -> float:
	"""Get current quantum_time_scale from first biome."""
	if biomes.is_empty():
		return 0.5
	var first_biome = biomes[0]
	if "quantum_time_scale" in first_biome:
		return float(first_biome.quantum_time_scale)
	return 0.5
