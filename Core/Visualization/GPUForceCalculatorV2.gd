## GPU V2: Async multi-biome force computation with angular momentum

extends RefCounted
class_name GPUForceCalculatorV2

# Shader cache (class-level)

static var _shared_shader: RID = RID()
static var _shared_pipeline: RID = RID()
static var _shared_rd: RenderingDevice = null
static var _shader_compiled: bool = false

# Instance state

var rd: RenderingDevice = null
var gpu_available: bool = false
var force_shader: RID = RID()
var force_pipeline: RID = RID()

enum ComputeState { IDLE, COMPUTING }
var _compute_state: ComputeState = ComputeState.IDLE
var _pending_buffers: Dictionary = {}
var _pending_num_nodes: int = 0
var _pending_callback: Callable = Callable()

# Persistent buffers
var _position_buffer: RID = RID()
var _velocity_buffer: RID = RID()
var _angular_vel_buffer: RID = RID()
var _mi_buffer: RID = RID()
var _bloch_buffer: RID = RID()
var _frozen_buffer: RID = RID()
var _node_biome_buffer: RID = RID()
var _biome_centers_buffer: RID = RID()
var _out_position_buffer: RID = RID()
var _out_velocity_buffer: RID = RID()
var _out_angular_vel_buffer: RID = RID()
var _buffer_capacity: int = 0

var last_dispatch_time_ms: float = 0.0
var last_readback_time_ms: float = 0.0

func _init():
	_init_gpu()

static func pre_compile_shader() -> Dictionary:
	"""Pre-compile shader (called once, shared across instances)."""
	if _shader_compiled:
		return {
			"success": true,
			"device_name": _shared_rd.get_device_name() if _shared_rd else "unknown",
			"message": "Shader already compiled (cached)",
			"version": "v2",
		}

	var start_time = Time.get_ticks_msec()

	_shared_rd = RenderingServer.create_local_rendering_device()
	if not _shared_rd:
		return {
			"success": false,
			"device_name": "unknown",
			"message": "Failed to create RenderingDevice",
		}

	var device_name = _shared_rd.get_device_name()

	# Load shader from file
	var shader_path = "res://shaders/compute_forces_v2.glsl"
	var shader_code = _load_shader_source(shader_path)
	if shader_code.is_empty():
		_shared_rd.free()
		_shared_rd = null
		return {
			"success": false,
			"device_name": device_name,
			"message": "Failed to load shader: %s" % shader_path,
		}

	var rd_shader_source = RDShaderSource.new()
	rd_shader_source.source_compute = shader_code

	var shader_spirv = _shared_rd.shader_compile_spirv_from_source(rd_shader_source)
	if shader_spirv.compile_error_compute != "":
		_shared_rd.free()
		_shared_rd = null
		return {
			"success": false,
			"device_name": device_name,
			"message": "Shader compile error: %s" % shader_spirv.compile_error_compute,
		}

	_shared_shader = _shared_rd.shader_create_from_spirv(shader_spirv)
	if _shared_shader == RID():
		_shared_rd.free()
		_shared_rd = null
		return {
			"success": false,
			"device_name": device_name,
			"message": "Failed to create shader RID",
		}

	_shared_pipeline = _shared_rd.compute_pipeline_create(_shared_shader)
	if _shared_pipeline == RID():
		_shared_rd.free_rid(_shared_shader)
		_shared_rd.free()
		_shared_rd = null
		_shared_shader = RID()
		return {
			"success": false,
			"device_name": device_name,
			"message": "Failed to create compute pipeline",
		}

	_shader_compiled = true

	return {
		"success": true,
		"device_name": device_name,
		"message": "GPUForceCalculatorV2 shader compiled",
		"version": "v2",
		"duration_ms": Time.get_ticks_msec() - start_time,
	}

static func _load_shader_source(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("GPUForceCalculatorV2: Cannot open shader: %s" % path)
		return ""
	var content = file.get_as_text()
	file.close()
	return content

func _init_gpu() -> void:
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		return

	if _shader_compiled and _shared_shader != RID() and _shared_pipeline != RID():
		force_shader = _shared_shader
		force_pipeline = _shared_pipeline
		gpu_available = true
		return

	# Fallback: compile on-demand
	var result = pre_compile_shader()
	if result.get("success", false):
		force_shader = _shared_shader
		force_pipeline = _shared_pipeline
		gpu_available = true

# ============================================
# MULTI-BIOME DATA STRUCTURE
# ============================================

class BiomeForceData:
	var biome_id: int = 0
	var center: Vector2 = Vector2.ZERO
	var positions: PackedVector2Array = PackedVector2Array()
	var velocities: PackedVector2Array = PackedVector2Array()
	var angular_velocities: PackedFloat32Array = PackedFloat32Array()
	var bloch_packet: PackedFloat64Array = PackedFloat64Array()
	var mi_values: PackedFloat64Array = PackedFloat64Array()
	var frozen_mask: PackedInt32Array = PackedInt32Array()
	var num_qubits: int = 0

# ============================================
# ASYNC COMPUTE API
# ============================================

func is_computing() -> bool:
	return _compute_state == ComputeState.COMPUTING

func submit_multi_biome_forces(biome_data: Array[BiomeForceData], config: Dictionary = {}) -> bool:
	"""Submit async force computation for multiple biomes. Returns false if GPU busy/unavailable."""
	if not gpu_available or biome_data.is_empty():
		return false

	if _compute_state == ComputeState.COMPUTING:
		return false  # Previous compute still in progress

	var start_time = Time.get_ticks_usec()

	# Count total nodes across all biomes
	var total_nodes = 0
	for bd in biome_data:
		total_nodes += bd.positions.size()

	if total_nodes == 0:
		return false

	# Ensure buffers are large enough
	_ensure_buffer_capacity(total_nodes, biome_data.size())

	# Pack all biomes into unified buffers
	var packed = _pack_multi_biome_data(biome_data)

	# Upload to GPU buffers
	_upload_buffer(_position_buffer, packed.positions)
	_upload_buffer(_velocity_buffer, packed.velocities)
	_upload_buffer(_angular_vel_buffer, packed.angular_velocities)
	_upload_buffer(_mi_buffer, packed.mi_values)
	_upload_buffer(_bloch_buffer, packed.bloch_packet)
	_upload_buffer(_frozen_buffer, packed.frozen_mask)
	_upload_buffer(_node_biome_buffer, packed.node_biomes)
	_upload_buffer(_biome_centers_buffer, packed.biome_centers)

	# Create uniform set
	var uniforms: Array[RDUniform] = []
	var buffer_rids = [
		_position_buffer, _velocity_buffer, _angular_vel_buffer,
		_mi_buffer, _bloch_buffer, _frozen_buffer,
		_node_biome_buffer, _biome_centers_buffer,
		_out_position_buffer, _out_velocity_buffer, _out_angular_vel_buffer
	]

	for i in range(buffer_rids.size()):
		var u = RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = i
		u.add_id(buffer_rids[i])
		uniforms.append(u)

	var uniform_set = rd.uniform_set_create(uniforms, force_shader, 0)

	# Pack push constants
	var push_bytes = _pack_push_constants(total_nodes, biome_data.size(), config)

	# Dispatch
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, force_pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())

	var workgroups = ceili(float(total_nodes) / 64.0)
	rd.compute_list_dispatch(compute_list, workgroups, 1, 1)
	rd.compute_list_end()

	# Submit (non-blocking!)
	rd.submit()

	# Track state
	_compute_state = ComputeState.COMPUTING
	_pending_num_nodes = total_nodes
	last_dispatch_time_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	return true

func poll_results() -> Dictionary:
	"""Poll for computation results (non-blocking).

	Returns empty dict if still computing or no results.
	Returns {positions, velocities, angular_velocities} when ready.
	"""
	if _compute_state != ComputeState.COMPUTING:
		return {}

	# Sync and read results
	var start_time = Time.get_ticks_usec()
	rd.sync()  # Wait for GPU (could be made truly async with fences)

	# Read output buffers
	var pos_bytes = rd.buffer_get_data(_out_position_buffer)
	var vel_bytes = rd.buffer_get_data(_out_velocity_buffer)
	var ang_bytes = rd.buffer_get_data(_out_angular_vel_buffer)

	_compute_state = ComputeState.IDLE
	last_readback_time_ms = (Time.get_ticks_usec() - start_time) / 1000.0

	return {
		"positions": _unpack_vector2_from_bytes(pos_bytes, _pending_num_nodes),
		"velocities": _unpack_vector2_from_bytes(vel_bytes, _pending_num_nodes),
		"angular_velocities": _unpack_float32_from_bytes(ang_bytes, _pending_num_nodes),
		"num_nodes": _pending_num_nodes,
	}

func compute_forces_sync(biome_data: Array[BiomeForceData], config: Dictionary = {}) -> Dictionary:
	"""Synchronous compute (for compatibility/testing)."""
	if not submit_multi_biome_forces(biome_data, config):
		return {}
	return poll_results()

# ============================================
# BUFFER MANAGEMENT
# ============================================

func _ensure_buffer_capacity(num_nodes: int, num_biomes: int) -> void:
	"""Ensure buffers are large enough, creating/resizing as needed."""
	if num_nodes <= _buffer_capacity:
		return

	# Free old buffers
	_free_buffers()

	# Create new buffers with 20% headroom
	var capacity = int(num_nodes * 1.2)
	_buffer_capacity = capacity

	var pos_size = capacity * 8  # vec2 = 8 bytes
	var vel_size = capacity * 8
	var ang_size = capacity * 4  # float = 4 bytes
	var mi_size = max(4, (capacity * (capacity - 1) / 2) * 4)  # Upper triangular
	var bloch_size = capacity * 8 * 4  # 8 floats * 4 bytes
	var frozen_size = capacity * 4  # uint = 4 bytes
	var biome_id_size = capacity * 4
	var centers_size = max(4, num_biomes * 8)  # vec2 per biome

	_position_buffer = rd.storage_buffer_create(pos_size)
	_velocity_buffer = rd.storage_buffer_create(vel_size)
	_angular_vel_buffer = rd.storage_buffer_create(ang_size)
	_mi_buffer = rd.storage_buffer_create(mi_size)
	_bloch_buffer = rd.storage_buffer_create(bloch_size)
	_frozen_buffer = rd.storage_buffer_create(frozen_size)
	_node_biome_buffer = rd.storage_buffer_create(biome_id_size)
	_biome_centers_buffer = rd.storage_buffer_create(centers_size)
	_out_position_buffer = rd.storage_buffer_create(pos_size)
	_out_velocity_buffer = rd.storage_buffer_create(vel_size)
	_out_angular_vel_buffer = rd.storage_buffer_create(ang_size)

func _upload_buffer(buffer: RID, data: PackedByteArray) -> void:
	"""Upload data to GPU buffer."""
	if data.is_empty():
		return
	rd.buffer_update(buffer, 0, data.size(), data)

func _free_buffers() -> void:
	"""Free all GPU buffers."""
	var buffers = [
		_position_buffer, _velocity_buffer, _angular_vel_buffer,
		_mi_buffer, _bloch_buffer, _frozen_buffer,
		_node_biome_buffer, _biome_centers_buffer,
		_out_position_buffer, _out_velocity_buffer, _out_angular_vel_buffer
	]
	for buf in buffers:
		if buf != RID():
			rd.free_rid(buf)

	_position_buffer = RID()
	_velocity_buffer = RID()
	_angular_vel_buffer = RID()
	_mi_buffer = RID()
	_bloch_buffer = RID()
	_frozen_buffer = RID()
	_node_biome_buffer = RID()
	_biome_centers_buffer = RID()
	_out_position_buffer = RID()
	_out_velocity_buffer = RID()
	_out_angular_vel_buffer = RID()
	_buffer_capacity = 0

# ============================================
# DATA PACKING
# ============================================

func _pack_multi_biome_data(biome_data: Array[BiomeForceData]) -> Dictionary:
	"""Pack all biomes into unified buffers for GPU."""
	var positions = PackedByteArray()
	var velocities = PackedByteArray()
	var angular_velocities = PackedByteArray()
	var bloch_packet = PackedByteArray()
	var mi_values = PackedByteArray()
	var frozen_mask = PackedByteArray()
	var node_biomes = PackedByteArray()
	var biome_centers = PackedByteArray()

	# Pack biome centers first
	for bd in biome_data:
		biome_centers.append_array(PackedFloat32Array([bd.center.x, bd.center.y]).to_byte_array())

	# Pack nodes per biome
	for bd in biome_data:
		var biome_id_bytes = PackedInt32Array([bd.biome_id]).to_byte_array()

		for i in range(bd.positions.size()):
			# Position
			var p = bd.positions[i]
			positions.append_array(PackedFloat32Array([p.x, p.y]).to_byte_array())

			# Velocity
			var v = bd.velocities[i] if i < bd.velocities.size() else Vector2.ZERO
			velocities.append_array(PackedFloat32Array([v.x, v.y]).to_byte_array())

			# Angular velocity
			var av = bd.angular_velocities[i] if i < bd.angular_velocities.size() else 0.0
			angular_velocities.append_array(PackedFloat32Array([av]).to_byte_array())

			# Node biome ID
			node_biomes.append_array(biome_id_bytes)

			# Frozen mask
			var frozen = bd.frozen_mask[i] if i < bd.frozen_mask.size() else 0
			frozen_mask.append_array(PackedInt32Array([frozen]).to_byte_array())

		# Pack bloch data (8 floats per qubit)
		for j in range(bd.bloch_packet.size()):
			bloch_packet.append_array(PackedFloat32Array([bd.bloch_packet[j]]).to_byte_array())

		# Pack MI (already in upper triangular format)
		for j in range(bd.mi_values.size()):
			mi_values.append_array(PackedFloat32Array([bd.mi_values[j]]).to_byte_array())

	# Ensure minimum sizes
	if mi_values.is_empty():
		mi_values = PackedByteArray([0, 0, 0, 0])
	if bloch_packet.is_empty():
		bloch_packet = PackedByteArray([0, 0, 0, 0])

	return {
		"positions": positions,
		"velocities": velocities,
		"angular_velocities": angular_velocities,
		"mi_values": mi_values,
		"bloch_packet": bloch_packet,
		"frozen_mask": frozen_mask,
		"node_biomes": node_biomes,
		"biome_centers": biome_centers,
	}

func _pack_push_constants(num_nodes: int, num_biomes: int, config: Dictionary) -> PackedByteArray:
	"""Pack push constants matching shader layout (128 bytes)."""
	var bytes = PackedByteArray()

	# Block 1: Simulation parameters (16 bytes)
	var dt = config.get("dt", 0.016)
	bytes.append_array(PackedFloat32Array([dt]).to_byte_array())
	bytes.append_array(PackedInt32Array([num_nodes]).to_byte_array())
	bytes.append_array(PackedInt32Array([num_biomes]).to_byte_array())
	bytes.append_array(PackedFloat32Array([0.0]).to_byte_array())  # pad

	# Block 2: Radial forces (16 bytes)
	bytes.append_array(PackedFloat32Array([
		config.get("purity_radial_spring", 0.08),
		config.get("max_biome_radius", 250.0),
		0.0, 0.0  # padding
	]).to_byte_array())

	# Block 3: Angular forces (16 bytes)
	bytes.append_array(PackedFloat32Array([
		config.get("phase_angular_spring", 0.04),
		config.get("angular_momentum_spring", 0.15),
		config.get("angular_damping", 0.95),
		config.get("orbit_speed_scale", 0.5),
	]).to_byte_array())

	# Block 4: Correlation forces (16 bytes)
	bytes.append_array(PackedFloat32Array([
		config.get("correlation_spring", 0.12),
		config.get("correlation_scaling", 3.0),
		config.get("base_distance", 120.0),
		config.get("min_distance", 15.0),
	]).to_byte_array())

	# Block 5: Repulsion and damping (16 bytes)
	bytes.append_array(PackedFloat32Array([
		config.get("repulsion_strength", 1500.0),
		config.get("velocity_damping", 0.89),
		config.get("max_velocity", 500.0),
		0.0  # padding
	]).to_byte_array())

	return bytes

# ============================================
# DATA UNPACKING
# ============================================

func _unpack_vector2_from_bytes(bytes: PackedByteArray, count: int) -> PackedVector2Array:
	"""Unpack Vector2 array from GPU data."""
	var result = PackedVector2Array()
	var floats = bytes.to_float32_array()
	for i in range(min(count, floats.size() / 2)):
		result.append(Vector2(floats[i * 2], floats[i * 2 + 1]))
	return result

func _unpack_float32_from_bytes(bytes: PackedByteArray, count: int) -> PackedFloat32Array:
	"""Unpack float32 array from GPU data."""
	var floats = bytes.to_float32_array()
	var result = PackedFloat32Array()
	result.resize(min(count, floats.size()))
	for i in range(result.size()):
		result[i] = floats[i]
	return result

# ============================================
# CLEANUP
# ============================================

func cleanup():
	"""Free all GPU resources."""
	_free_buffers()
	if rd:
		rd.free()
		rd = null
	gpu_available = false
