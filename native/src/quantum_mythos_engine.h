#pragma once

#include "mythos_graph_core.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <memory>

namespace godot {

class QuantumMythosEngine : public RefCounted {
    GDCLASS(QuantumMythosEngine, RefCounted)

public:
    QuantumMythosEngine();
    ~QuantumMythosEngine() override;

    void clear();
    void configure_default_axes();

    int add_emoji(String emoji, double self_energy = 0.0, double decay = 0.0);
    int add_icon(Dictionary icon);
    int add_faction(String name, PackedFloat64Array bits, PackedStringArray sig);

    void compose_hamiltonian();
    void initialize_density_uniform();
    void initialize_density_pure_emoji(String emoji);
    void step(double dt, double decoherence = 0.0);

    void apply_icon_learned(String pole_0, String pole_1, double strength = 0.02);

    Dictionary get_axis_marginal(int axis_index) const;
    Array get_faction_projection_for_icon(String pole_0, String pole_1, int limit = 12) const;
    PackedFloat64Array get_faction_diagonal() const;
    Dictionary get_hamiltonian_eigen_summary(int limit = 8) const;
    double get_icon_expectation(String pole_0, String pole_1) const;

    // ====== Faction density facade (replaces GDScript FactionDensityMatrix math) ======
    void faction_pump(String name, double rate);
    void faction_kick_coherence(String name_a, String name_b, double re, double im);
    void faction_apply_lindblad_decay(double dt, double tau);
    void faction_apply_axis_bias(int axis_i, int bit_b, double strength);
    void faction_initialize_uniform();
    void faction_renormalize_trace();

    double faction_get_weight(String name) const;
    Vector2 faction_get_coherence(String name_a, String name_b) const;
    Dictionary faction_partial_trace_axis(int axis_i) const;

    int faction_hamming_distance(String name_a, String name_b) const;
    double faction_affinity_for_emoji(String emoji) const;
    PackedStringArray faction_factions_speaking(String emoji) const;
    double faction_purity() const;
    double faction_diagonal_sum() const;
    int faction_get_size() const;
    PackedStringArray faction_get_names() const;
    int faction_get_index(String name) const;

    Dictionary faction_serialize() const;
    void faction_deserialize(Dictionary data);

    // Dominant mode of ρ_factions + its projection onto the 12 axial dimensions.
    // principal_mode returns {eigenvalue, amplitudes (PackedFloat64Array, length F)}.
    // principal_axis_projection returns a PackedFloat64Array of length 12, each
    // value in [0,1] representing P(axis=1 | dominant mode).
    Dictionary faction_principal_mode() const;
    PackedFloat64Array faction_principal_axis_projection() const;

protected:
    static void _bind_methods();

private:
    std::unique_ptr<spacewheat::MythosGraphCore> core_;

    static std::string to_std(const String &s);
    static String to_godot(const std::string &s);
};

} // namespace godot
