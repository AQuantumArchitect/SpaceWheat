#[compute]
#version 450

/**
 * Seasonal Shadow Influence Compute Shader
 *
 * Computes shadow influences for spinning bubble visualization.
 * When bubble B is in bubble A's dominant wedge direction AND they have
 * coupling, B's wedges get tinted toward A's dominant season color.
 *
 * O(n^2) on GPU = fast parallel computation
 */

layout(local_size_x = 32, local_size_y = 1, local_size_z = 1) in;

// Season constants
const float PI = 3.14159265359;
const float TAU = 6.28318530718;
const vec3 SEASON_ANGLES = vec3(0.0, TAU / 3.0, 2.0 * TAU / 3.0);  // 0, 120, 240 degrees
const vec3 SEASON_COLORS[3] = vec3[3](
    vec3(1.0, 0.3, 0.3),  // Red
    vec3(0.3, 1.0, 0.3),  // Green
    vec3(0.3, 0.3, 1.0)   // Blue
);

// Input buffers
layout(std430, binding = 0) readonly buffer Positions {
    vec2 pos[];  // Node positions
};

layout(std430, binding = 1) readonly buffer PhiValues {
    float phi_raw[];  // Raw phase angles
};

layout(std430, binding = 2) readonly buffer SeasonProjections {
    vec4 season_proj[];  // xyz = R,G,B projections, w = coherence
};

layout(std430, binding = 3) readonly buffer Couplings {
    float coupling[];  // NxN coupling matrix (flattened)
};

// Output buffer
layout(std430, binding = 4) writeonly buffer ShadowInfluences {
    vec4 shadow[];  // xyz = tint color, w = strength
};

// Push constants
layout(push_constant) uniform PushConstants {
    uint num_nodes;
    float max_influence_distance;  // Distance cutoff for influence
    float wedge_half_angle;        // Half-angle of wedge cone (radians)
};

// Wrap angle to [-PI, PI]
float wrap_angle(float angle) {
    while (angle > PI) angle -= TAU;
    while (angle < -PI) angle += TAU;
    return angle;
}

// Get dominant season index (0, 1, or 2)
int get_dominant_season(vec3 projections) {
    if (projections.x >= projections.y && projections.x >= projections.z) return 0;
    if (projections.y >= projections.x && projections.y >= projections.z) return 1;
    return 2;
}

void main() {
    uint node_b = gl_GlobalInvocationID.x;
    if (node_b >= num_nodes) return;

    vec3 accumulated_tint = vec3(1.0);  // Start white
    float accumulated_strength = 0.0;
    float total_weight = 0.0;

    vec2 pos_b = pos[node_b];

    // Check influence from all other nodes
    for (uint node_a = 0u; node_a < num_nodes; node_a++) {
        if (node_a == node_b) continue;

        vec2 pos_a = pos[node_a];
        vec3 proj_a = season_proj[node_a].xyz;
        float coherence_a = season_proj[node_a].w;

        // Skip if A has weak coherence (no clear season)
        if (coherence_a < 0.1) continue;

        // Get A's dominant season
        int dominant_idx = get_dominant_season(proj_a);
        float dominant_intensity = 0.0;
        if (dominant_idx == 0) dominant_intensity = proj_a.x;
        else if (dominant_idx == 1) dominant_intensity = proj_a.y;
        else dominant_intensity = proj_a.z;

        // Skip if dominant season is weak
        if (dominant_intensity < 0.2) continue;

        // A's wedge angle = season angle + phi rotation
        float wedge_angle = SEASON_ANGLES[dominant_idx] + phi_raw[node_a];

        // Angle from A to B
        vec2 a_to_b = pos_b - pos_a;
        float dist = length(a_to_b);

        // Skip if too far
        if (dist > max_influence_distance || dist < 0.001) continue;

        float angle_to_b = atan(a_to_b.y, a_to_b.x);

        // Check if B is within A's wedge cone
        float angle_diff = wrap_angle(wedge_angle - angle_to_b);

        if (abs(angle_diff) > wedge_half_angle) continue;

        // Get coupling strength from matrix
        uint coupling_idx = node_a * num_nodes + node_b;
        float coup = coupling[coupling_idx];

        // Skip if no coupling
        if (coup < 0.01) continue;

        // Compute influence strength
        float distance_factor = 1.0 - (dist / max_influence_distance);
        float angle_factor = 1.0 - abs(angle_diff) / wedge_half_angle;
        float strength = coup * distance_factor * angle_factor * dominant_intensity;

        // Accumulate weighted tint
        vec3 season_color = SEASON_COLORS[dominant_idx];
        accumulated_tint = mix(accumulated_tint, season_color, strength * 0.5);
        accumulated_strength += strength;
        total_weight += 1.0;
    }

    // Normalize and clamp strength
    accumulated_strength = clamp(accumulated_strength, 0.0, 1.0);

    // Write output
    shadow[node_b] = vec4(accumulated_tint, accumulated_strength);
}
