## GPUForceCalculator - Offload force calculations to GPU via RenderingDevice
##
## Computes force-directed physics for quantum nodes on GPU compute shader.
## One compute shader invocation per node, perfect parallelization.

extends RefCounted

class_name GPUForceCalculator

var rd: RenderingDevice = null
var gpu_available: bool = false

var force_pipeline: RID = RID()
var position_buffer: RID = RID()
var velocity_buffer: RID = RID()
var mi_buffer: RID = RID()
var bloch_buffer: RID = RID()
var frozen_buffer: RID = RID()
var out_position_buffer: RID = RID()
var out_velocity_buffer: RID = RID()

func _init():
	"""Initialize GPU compute on construction."""
	_init_gpu()

func _init_gpu() -> void:
	"""Try to initialize GPU compute."""
	# Create local rendering device for compute
	rd = RenderingServer.create_local_rendering_device()
	if not rd:
		print("GPUForceCalculator: Failed to create RenderingDevice")
		return

	# Compile force compute shader
	if not _compile_force_shader():
		print("GPUForceCalculator: Failed to compile force shader")
		rd.free()
		rd = null
		return

	gpu_available = true
	print("GPUForceCalculator: GPU acceleration ENABLED")


func _compile_force_shader() -> bool:
	"""Compile force calculation compute shader."""
	# In Godot 4.5, we create shader directly from GLSL source
	var shader_code = _get_force_shader_glsl()

	# Create RDShaderSource with compute shader code
	var rd_shader_source = RDShaderSource.new()
	rd_shader_source.source_compute = shader_code

	# Create shader from source
	var shader_spirv = rd.shader_compile_spirv_from_source(rd_shader_source)
	if shader_spirv.compile_error_compute != "":
		print("GPUForceCalculator: Shader compile error: ", shader_spirv.compile_error_compute)
		return false

	# Create shader RID
	var shader_rid = rd.shader_create_from_spirv(shader_spirv)
	if shader_rid == RID():
		print("GPUForceCalculator: Failed to create shader RID")
		return false

	# Create pipeline
	force_pipeline = rd.compute_pipeline_create(shader_rid)

	return force_pipeline != RID()


func _get_force_shader_glsl() -> String:
	"""Return inline force calculation shader source."""
	return """
#version 450

layout(local_size_x = 24, local_size_y = 1, local_size_z = 1) in;

// Input buffers
layout(std430, binding = 0) readonly buffer Positions {
	vec2 pos[];
};

layout(std430, binding = 1) readonly buffer Velocities {
	vec2 vel[];
};

layout(std430, binding = 2) readonly buffer MutualInfo {
	float mi[];
};

layout(std430, binding = 3) readonly buffer BlochVectors {
	vec4 bloch[];
};

layout(std430, binding = 4) readonly buffer FrozenMask {
	uint frozen[];
};

// Output buffers
layout(std430, binding = 5) writeonly buffer OutPositions {
	vec2 new_pos[];
};

layout(std430, binding = 6) writeonly buffer OutVelocities {
	vec2 new_vel[];
};

// Push constants
layout(push_constant) uniform PushConstants {
	vec2 biome_center;
	float dt;
	uint num_nodes;
	uint num_qubits;
	float purity_radial_spring;
	float phase_angular_spring;
	float correlation_spring;
	float repulsion_strength;
	float damping;
	float base_distance;
	float min_distance;
} pc;

const float PI = 3.14159265359;
const float EPSILON = 0.001;

void main() {
	uint node_id = gl_GlobalInvocationID.x;
	if (node_id >= pc.num_nodes) return;

	if (frozen[node_id] > 0u) {
		new_pos[node_id] = pos[node_id];
		new_vel[node_id] = vel[node_id];
		return;
	}

	vec2 force = vec2(0.0);
	vec2 node_pos = pos[node_id];

	// Parity radial force (purity-based)
	if (node_id < pc.num_qubits) {
		float purity = bloch[node_id].w;
		float target_radius = 250.0 * (1.0 - purity);
		vec2 radial = node_pos - pc.biome_center;
		float current_radius = length(radial);

		if (current_radius > EPSILON) {
			vec2 radial_dir = radial / current_radius;
			float radius_error = current_radius - target_radius;
			force += radial_dir * radius_error * pc.purity_radial_spring;
		}
	}

	// Pairwise forces (correlation + repulsion)
	for (uint j = 0u; j < pc.num_nodes; j++) {
		if (j == node_id) continue;

		vec2 to_other = pos[j] - node_pos;
		float dist = length(to_other);

		if (dist > EPSILON) {
			// MI-based correlation spring
			float mi_val = 0.0;
			if (node_id < j && node_id < 24u && j < 24u) {
				uint mi_idx = node_id * 24u + j - (node_id * (node_id + 1u)) / 2u;
				if (mi_idx < mi.length()) {
					mi_val = mi[mi_idx];
				}
			}

			float spring_length = pc.base_distance / (1.0 + 3.0 * mi_val);
			float spring_force = (dist - spring_length) * pc.correlation_spring;
			force += normalize(to_other) * spring_force;

			// Repulsion
			if (dist < 15.0) {
				force += normalize(to_other) * pc.repulsion_strength;
			} else if (dist < pc.base_distance * 0.5) {
				float repel_mag = pc.repulsion_strength / (dist * dist + 1.0);
				force += normalize(to_other) * repel_mag;
			}
		}
	}

	// Integration
	vec2 new_velocity = (vel[node_id] + force * pc.dt) * pc.damping;

	// Clamp velocity
	float vel_mag = length(new_velocity);
	if (vel_mag > 500.0) {
		new_velocity = normalize(new_velocity) * 500.0;
	}

	vec2 new_position = node_pos + new_velocity * pc.dt;

	// Clamp to bounding box
	float max_extent = 375.0;
	new_position.x = clamp(new_position.x, pc.biome_center.x - max_extent, pc.biome_center.x + max_extent);
	new_position.y = clamp(new_position.y, pc.biome_center.y - max_extent, pc.biome_center.y + max_extent);

	new_pos[node_id] = new_position;
	new_vel[node_id] = new_velocity;
}
"""


func compute_forces(
	positions: PackedVector2Array,
	velocities: PackedVector2Array,
	mi_values: PackedFloat64Array,
	bloch_data: PackedFloat64Array,
	num_qubits: int,
	biome_center: Vector2,
	delta: float,
	config: Dictionary = {}
) -> Dictionary:
	"""Compute forces on GPU, return updated positions/velocities."""

	if not gpu_available or positions.is_empty():
		return {}

	var num_nodes = positions.size()

	# Get config with defaults
	var purity_spring = config.get("purity_radial_spring", 0.08)
	var phase_spring = config.get("phase_angular_spring", 0.04)
	var corr_spring = config.get("correlation_spring", 0.12)
	var repulsion = config.get("repulsion_strength", 1500.0)
	var damping = config.get("damping", 0.89)
	var base_dist = config.get("base_distance", 120.0)
	var min_dist = config.get("min_distance", 15.0)

	# Pack data as bytes
	var pos_bytes = _pack_vector2_to_bytes(positions)
	var vel_bytes = _pack_vector2_to_bytes(velocities)
	var mi_bytes = _pack_float64_to_bytes(mi_values)
	var bloch_bytes = _pack_float64_to_bytes(bloch_data)

	var frozen = PackedByteArray()
	for _i in range(num_nodes):
		frozen.append(0)

	# Create/update input buffers
	position_buffer = rd.storage_buffer_create(pos_bytes.size(), pos_bytes)
	velocity_buffer = rd.storage_buffer_create(vel_bytes.size(), vel_bytes)
	mi_buffer = rd.storage_buffer_create(mi_bytes.size(), mi_bytes)
	bloch_buffer = rd.storage_buffer_create(bloch_bytes.size(), bloch_bytes)
	frozen_buffer = rd.storage_buffer_create(frozen.size(), frozen)
	out_position_buffer = rd.storage_buffer_create(pos_bytes.size())
	out_velocity_buffer = rd.storage_buffer_create(vel_bytes.size())

	# Create uniform set
	var uniforms = []
	for i in range(7):
		var u = RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = i
		uniforms.append(u)

	uniforms[0].add_id(position_buffer)
	uniforms[1].add_id(velocity_buffer)
	uniforms[2].add_id(mi_buffer)
	uniforms[3].add_id(bloch_buffer)
	uniforms[4].add_id(frozen_buffer)
	uniforms[5].add_id(out_position_buffer)
	uniforms[6].add_id(out_velocity_buffer)

	var uniform_set = rd.uniform_set_create(uniforms, force_pipeline, 0)

	# Pack push constants (must match shader exactly)
	var push_const = PackedFloat32Array([
		biome_center.x, biome_center.y,
		delta,
		float(num_nodes),
		float(num_qubits),
		purity_spring,
		phase_spring,
		corr_spring,
		repulsion,
		damping,
		base_dist,
		min_dist,
	])

	# Dispatch compute
	var compute_list = rd.compute_list_begin()
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)

	var push_bytes = push_const.to_byte_array()
	rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())

	var workgroups = ceilf(float(num_nodes) / 24.0)
	rd.compute_list_dispatch(compute_list, int(workgroups), 1, 1)
	rd.compute_list_end()

	# Wait for GPU
	rd.submit()
	rd.sync()

	# Read results
	var new_pos_bytes = rd.buffer_get_data(out_position_buffer)
	var new_vel_bytes = rd.buffer_get_data(out_velocity_buffer)

	# Cleanup
	rd.free_rid(position_buffer)
	rd.free_rid(velocity_buffer)
	rd.free_rid(mi_buffer)
	rd.free_rid(bloch_buffer)
	rd.free_rid(frozen_buffer)
	rd.free_rid(out_position_buffer)
	rd.free_rid(out_velocity_buffer)

	return {
		"positions": _unpack_vector2_from_bytes(new_pos_bytes),
		"velocities": _unpack_vector2_from_bytes(new_vel_bytes),
	}


func _pack_vector2_to_bytes(arr: PackedVector2Array) -> PackedByteArray:
	var bytes = PackedByteArray()
	for v in arr:
		bytes.append_array(var_to_bytes(v))
	return bytes

func _unpack_vector2_from_bytes(bytes: PackedByteArray) -> PackedVector2Array:
	var result = PackedVector2Array()
	var pos = 0
	while pos + 8 <= bytes.size():
		var v = bytes_to_var(bytes.slice(pos, pos + 8))
		if v is Vector2:
			result.append(v)
		pos += 8
	return result

func _pack_float64_to_bytes(arr: PackedFloat64Array) -> PackedByteArray:
	var bytes = PackedByteArray()
	for f in arr:
		bytes.append_array(var_to_bytes(f))
	return bytes

func cleanup():
	"""Free GPU resources."""
	if rd:
		if position_buffer != RID():
			rd.free_rid(position_buffer)
		if velocity_buffer != RID():
			rd.free_rid(velocity_buffer)
		if mi_buffer != RID():
			rd.free_rid(mi_buffer)
		if bloch_buffer != RID():
			rd.free_rid(bloch_buffer)
		if frozen_buffer != RID():
			rd.free_rid(frozen_buffer)
		if out_position_buffer != RID():
			rd.free_rid(out_position_buffer)
		if out_velocity_buffer != RID():
			rd.free_rid(out_velocity_buffer)
		rd.free()
		rd = null
