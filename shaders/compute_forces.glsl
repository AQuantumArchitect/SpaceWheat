#[compute]
#version 450

/**
 * Quantum Force Graph Compute Shader
 *
 * Computes force-directed physics for N quantum nodes in parallel.
 * One GPU thread per node.
 *
 * Forces:
 * - Purity radial: pure states -> center, mixed -> edge (based on Bloch radius)
 * - Phase angular: same phase -> cluster (tangential force)
 * - Correlation: high MI -> attract (spring force)
 * - Repulsion: prevent overlap (inverse-square)
 */

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
    vec4 bloch[];  // (x, y, z, r) per qubit where r = purity
};

layout(std430, binding = 4) readonly buffer FrozenMask {
    uint frozen[];  // 1 = frozen/measured, 0 = free
};

// Output buffers
layout(std430, binding = 5) writeonly buffer OutPositions {
    vec2 new_pos[];
};

layout(std430, binding = 6) writeonly buffer OutVelocities {
    vec2 new_vel[];
};

// Push constants: configuration
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
};

const float PI = 3.14159265359;
const float MI_SCALING = 3.0;  // Scale for MI-based spring length
const float MAX_RADIUS = 250.0;
const float EPSILON = 0.001;

void main() {
    uint node_id = gl_GlobalInvocationID.x;
    if (node_id >= num_nodes) return;

    // Skip if frozen
    if (frozen[node_id] > 0u) {
        new_pos[node_id] = pos[node_id];
        new_vel[node_id] = vel[node_id];
        return;
    }

    vec2 force = vec2(0.0);
    vec2 node_pos = pos[node_id];

    // ==========================================
    // 1. PURITY RADIAL FORCE
    // ==========================================
    // Pure states (purity ~= 1) stay near center
    // Mixed states (purity ~= 0) pushed toward edge

    if (node_id < num_qubits && node_id < bloch.length()) {
        float purity = bloch[node_id].w;  // w component is Bloch radius (purity proxy)

        // Target radius: max_radius * (1 - purity)
        float target_radius = MAX_RADIUS * (1.0 - purity);

        // Radial direction from biome center
        vec2 radial = node_pos - biome_center;
        float current_radius = length(radial);

        if (current_radius > EPSILON) {
            vec2 radial_dir = radial / current_radius;

            // Spring force toward target radius
            float radius_error = current_radius - target_radius;
            force += radial_dir * radius_error * purity_radial_spring;
        }
    }

    // ==========================================
    // 2. PHASE ANGULAR FORCE
    // ==========================================
    // Qubits with similar phase cluster together (tangent force)

    if (node_id < num_qubits && node_id < bloch.length()) {
        // Phase angle from Bloch vector
        vec3 bloch_vec = bloch[node_id].xyz;
        float phase = atan(bloch_vec.y, bloch_vec.x);  // azimuthal angle

        // Find nearest node with similar phase
        for (uint j = 0u; j < num_nodes; j++) {
            if (j == node_id) continue;
            if (j >= bloch.length()) continue;

            float other_phase = atan(bloch[j].xyz.y, bloch[j].xyz.x);
            float phase_diff = abs(phase - other_phase);

            // Normalize to [-π, π]
            if (phase_diff > PI) phase_diff = 2.0 * PI - phase_diff;

            // Only attract if phases are close (within 45°)
            if (phase_diff < PI / 4.0) {
                vec2 to_other = pos[j] - node_pos;
                float dist = length(to_other);

                if (dist > EPSILON) {
                    // Weak tangential clustering
                    force += normalize(to_other) * phase_angular_spring;
                }
            }
        }
    }

    // ==========================================
    // 3. CORRELATION FORCES (MI-based springs)
    // ==========================================
    // High MI -> strong attraction (coupled behavior)

    for (uint j = 0u; j < num_nodes; j++) {
        if (j == node_id) continue;

        // Get MI value (upper triangular matrix)
        float mi_val = 0.0;
        if (node_id < j) {
            uint mi_idx = node_id * num_nodes + j - (node_id * (node_id + 1u)) / 2u;
            if (mi_idx < mi.length()) {
                mi_val = mi[mi_idx];
            }
        } else if (j < node_id) {
            uint mi_idx = j * num_nodes + node_id - (j * (j + 1u)) / 2u;
            if (mi_idx < mi.length()) {
                mi_val = mi[mi_idx];
            }
        }

        vec2 to_other = pos[j] - node_pos;
        float dist = length(to_other);

        if (dist > EPSILON) {
            // Spring length decreases with MI (higher MI = closer)
            float spring_length = base_distance / (1.0 + MI_SCALING * mi_val);

            // Spring force: F = k(x - L) where x=dist, L=target
            float spring_force = (dist - spring_length) * correlation_spring;

            force += normalize(to_other) * spring_force;
        }
    }

    // ==========================================
    // 4. REPULSION FORCES
    // ==========================================
    // Prevent overlap (inverse-square, short-range)

    for (uint j = 0u; j < num_nodes; j++) {
        if (j == node_id) continue;

        vec2 away_from = node_pos - pos[j];
        float dist = length(away_from);

        if (dist < min_distance) {
            // Hard repulsion for very close nodes
            force += normalize(away_from) * repulsion_strength;
        } else if (dist > EPSILON && dist < base_distance * 0.5) {
            // Soft repulsion proportional to inverse-square
            float repel_mag = repulsion_strength / (dist * dist + 1.0);
            force += normalize(away_from) * repel_mag;
        }
    }

    // ==========================================
    // INTEGRATION: Velocity Verlet
    // ==========================================

    // Update velocity: v = v + a*dt, with damping
    vec2 acceleration = force;  // Assume unit mass
    vec2 new_velocity = (vel[node_id] + acceleration * dt) * damping;

    // Clamp velocity to prevent instability
    float vel_mag = length(new_velocity);
    if (vel_mag > 500.0) {
        new_velocity = normalize(new_velocity) * 500.0;
    }

    // Update position: x = x + v*dt
    vec2 new_position = node_pos + new_velocity * dt;

    // Clamp to bounding box (keep in view)
    float max_extent = MAX_RADIUS * 1.5;
    new_position.x = clamp(new_position.x,
                           biome_center.x - max_extent,
                           biome_center.x + max_extent);
    new_position.y = clamp(new_position.y,
                           biome_center.y - max_extent,
                           biome_center.y + max_extent);

    // Write results
    new_pos[node_id] = new_position;
    new_vel[node_id] = new_velocity;
}
