#[compute]
#version 450

// Quantum Force Graph - Multi-biome batching with angular momentum
// 5 forces: purity radial, phase angular, angular momentum, correlation, repulsion

layout(local_size_x = 64, local_size_y = 1, local_size_z = 1) in;

// Input buffers

layout(std430, binding = 0) readonly buffer Positions {
    vec2 pos[];
};

layout(std430, binding = 1) readonly buffer Velocities {
    vec2 vel[];
};

layout(std430, binding = 2) readonly buffer AngularVelocities {
    float angular_vel[];
};

layout(std430, binding = 3) readonly buffer MutualInfo {
    float mi[];
};

layout(std430, binding = 4) readonly buffer BlochPacket {
    float bloch[];  // [p0, p1, x, y, z, r, theta, phi] per qubit
};

layout(std430, binding = 5) readonly buffer FrozenMask {
    uint frozen[];
};

layout(std430, binding = 6) readonly buffer NodeBiomeIds {
    uint node_biome[];
};

layout(std430, binding = 7) readonly buffer BiomeCenters {
    vec2 biome_centers[];
};

// Output buffers

layout(std430, binding = 8) writeonly buffer OutPositions {
    vec2 new_pos[];
};

layout(std430, binding = 9) writeonly buffer OutVelocities {
    vec2 new_vel[];
};

layout(std430, binding = 10) writeonly buffer OutAngularVelocities {
    float new_angular_vel[];
};

// Push constants (128 bytes max)
layout(push_constant) uniform PushConstants {
    // Simulation parameters (16 bytes)
    float dt;
    uint num_nodes;
    uint num_biomes;
    float _pad0;

    // Radial forces (16 bytes)
    float purity_radial_spring;
    float max_biome_radius;
    float _pad1;
    float _pad2;

    // Angular forces (16 bytes)
    float phase_angular_spring;
    float angular_momentum_spring;
    float angular_damping;
    float orbit_speed_scale;

    // Correlation forces (16 bytes)
    float correlation_spring;
    float correlation_scaling;
    float base_distance;
    float min_distance;

    // Repulsion and damping (16 bytes)
    float repulsion_strength;
    float velocity_damping;
    float max_velocity;
    float _pad3;
} pc;

// Constants

const float PI = 3.14159265359;
const float TWO_PI = 6.28318530718;
const float EPSILON = 0.001;

// Helper functions

// Get MI index for pair (i, j) in upper triangular format
uint mi_index(uint i, uint j, uint n) {
    if (i > j) {
        uint tmp = i; i = j; j = tmp;
    }
    return i * n - (i * (i + 1u)) / 2u + j - i - 1u;
}

// Wrap angle to [-PI, PI]
float wrap_angle(float angle) {
    while (angle > PI) angle -= TWO_PI;
    while (angle < -PI) angle += TWO_PI;
    return angle;
}

// Main compute kernel

void main() {
    uint node_id = gl_GlobalInvocationID.x;
    if (node_id >= pc.num_nodes) return;

    // Get node's biome (for multi-biome support)
    uint biome_id = node_biome[node_id];
    vec2 my_biome_center = biome_centers[biome_id];

    // Frozen nodes don't move
    if (frozen[node_id] > 0u) {
        new_pos[node_id] = pos[node_id];
        new_vel[node_id] = vel[node_id];
        new_angular_vel[node_id] = 0.0;
        return;
    }

    vec2 force = vec2(0.0);
    float angular_torque = 0.0;
    vec2 node_pos = pos[node_id];
    float my_angular_vel = angular_vel[node_id];

    // Radial vector from biome center
    vec2 radial = node_pos - my_biome_center;
    float current_radius = length(radial);
    vec2 radial_dir = current_radius > EPSILON ? radial / current_radius : vec2(1.0, 0.0);
    vec2 tangent_dir = vec2(-radial_dir.y, radial_dir.x);  // Perpendicular (CCW)

    // Extract Bloch data

    uint bloch_offset = node_id * 8u;
    float purity = 0.5;
    float phase_phi = 0.0;
    float phase_theta = 0.0;

    if (bloch_offset + 7u < bloch.length()) {
        float p0 = bloch[bloch_offset];      // |0> probability
        float p1 = bloch[bloch_offset + 1u]; // |1> probability
        float bx = bloch[bloch_offset + 2u]; // Bloch x
        float by = bloch[bloch_offset + 3u]; // Bloch y
        float bz = bloch[bloch_offset + 4u]; // Bloch z
        float br = bloch[bloch_offset + 5u]; // Bloch radius (purity)
        phase_theta = bloch[bloch_offset + 6u]; // Polar angle
        phase_phi = bloch[bloch_offset + 7u];   // Azimuthal angle (phase!)

        purity = br;  // Use Bloch radius as purity proxy
    }

    // 1. Purity radial force (pure -> center, mixed -> edge)

    float target_radius = pc.max_biome_radius * (1.0 - purity);
    float radius_error = target_radius - current_radius;
    force += radial_dir * (pc.purity_radial_spring * radius_error);

    // 2. Angular momentum (φ → ω, positive=CCW, negative=CW)
    float target_angular_vel = phase_phi * pc.orbit_speed_scale;
    float angular_error = target_angular_vel - my_angular_vel;
    angular_torque = angular_error * pc.angular_momentum_spring;

    // 3. Phase clustering (similar phases attract tangentially)

    for (uint j = 0u; j < pc.num_nodes; j++) {
        if (j == node_id) continue;
        if (node_biome[j] != biome_id) continue;  // Only same biome
        if (frozen[j] > 0u) continue;

        uint other_bloch_offset = j * 8u;
        if (other_bloch_offset + 7u >= bloch.length()) continue;

        float other_phi = bloch[other_bloch_offset + 7u];
        float phase_diff = wrap_angle(phase_phi - other_phi);

        if (abs(phase_diff) < PI / 4.0) {
            vec2 to_other = pos[j] - node_pos;
            float dist = length(to_other);

            if (dist > EPSILON && dist < pc.base_distance) {
                float strength = pc.phase_angular_spring * (1.0 - abs(phase_diff) / (PI / 4.0));
                force += normalize(to_other) * strength;
            }
        }
    }

    // 4. Correlation forces (high MI -> attract)

    for (uint j = 0u; j < pc.num_nodes; j++) {
        if (j == node_id) continue;
        if (node_biome[j] != biome_id) continue;  // Only same biome
        if (frozen[j] > 0u) continue;

        // Get MI value
        uint mi_idx = mi_index(node_id, j, pc.num_nodes);
        float mi_val = 0.0;
        if (mi_idx < mi.length()) {
            mi_val = mi[mi_idx];
        }
        if (mi_val < 0.000001) continue;

        vec2 delta = pos[j] - node_pos;
        float dist = length(delta);
        if (dist < EPSILON) continue;

        float target_distance = pc.base_distance / (1.0 + pc.correlation_scaling * mi_val);
        target_distance = max(target_distance, pc.min_distance);
        float error = dist - target_distance;
        force += normalize(delta) * (pc.correlation_spring * error);
    }

    // 5. Repulsion (inverse-square, prevent overlap)

    for (uint j = 0u; j < pc.num_nodes; j++) {
        if (j == node_id) continue;
        if (frozen[j] > 0u) continue;

        vec2 away = node_pos - pos[j];
        float dist = length(away);

        if (dist < EPSILON) {
            force += vec2(float(node_id & 0xFFu) * 0.1, float(j & 0xFFu) * 0.1);
        } else if (dist < pc.min_distance) {
            force += normalize(away) * pc.repulsion_strength;
        } else if (dist < pc.base_distance * 0.5) {
            float repel_mag = pc.repulsion_strength / (dist * dist + 1.0);
            force += normalize(away) * repel_mag;
        }
    }

    // Integration
    float updated_angular_vel = (my_angular_vel + angular_torque * pc.dt) * pc.angular_damping;
    float tangent_speed = updated_angular_vel * current_radius;
    force += tangent_dir * tangent_speed;

    vec2 new_velocity = (vel[node_id] + force * pc.dt) * pc.velocity_damping;
    float vel_mag = length(new_velocity);
    if (vel_mag > pc.max_velocity) {
        new_velocity = normalize(new_velocity) * pc.max_velocity;
    }

    vec2 new_position = node_pos + new_velocity * pc.dt;
    float max_extent = pc.max_biome_radius * 1.5;
    new_position.x = clamp(new_position.x,
                           my_biome_center.x - max_extent,
                           my_biome_center.x + max_extent);
    new_position.y = clamp(new_position.y,
                           my_biome_center.y - max_extent,
                           my_biome_center.y + max_extent);

    // Write outputs
    new_pos[node_id] = new_position;
    new_vel[node_id] = new_velocity;
    new_angular_vel[node_id] = updated_angular_vel;
}
