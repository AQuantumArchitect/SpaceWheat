#pragma once

#include "axial_manifold.h"
#include "complex_matrix.h"
#include "emoji_graph_types.h"
#include "hermitian_eigensolver.h"

#include <string>
#include <unordered_map>
#include <vector>

namespace spacewheat {

class MythosGraphCore {
public:
    MythosGraphCore();

    void clear();

    int ensure_emoji(const std::string &emoji);
    void set_emoji_physics(const std::string &emoji, double self_energy, double decay = 0.0);

    int add_icon(const IconEdge &icon);
    int add_faction(const FactionField &faction);

    const std::vector<EmojiNode> &emojis() const { return emojis_; }
    const std::vector<IconEdge> &icons() const { return icons_; }
    const std::vector<FactionField> &factions() const { return factions_; }

    int emoji_index(const std::string &emoji) const;
    int icon_index_by_pair(const std::string &pole0, const std::string &pole1) const;
    int faction_index(const std::string &name) const;

    void compose_hamiltonian_from_icons();
    const ComplexMatrix &hamiltonian() const { return hamiltonian_; }

    void initialize_density_uniform();
    void initialize_density_pure_emoji(const std::string &emoji);
    void step_density(double dt, double decoherence = 0.0);

    const ComplexMatrix &density() const { return density_; }
    EigenResult solve_hamiltonian() const;

    void initialize_faction_density_uniform();
    void apply_icon_learned(const std::string &pole0, const std::string &pole1, double strength = 0.02);
    void apply_event(const MythosEvent &event);

    const ComplexMatrix &faction_density() const { return faction_density_; }
    std::vector<FactionProjection> project_factions_for_icon(const std::string &pole0, const std::string &pole1) const;
    std::vector<double> axis_marginal(int axis_index) const;

    double icon_expectation(const std::string &pole0, const std::string &pole1) const;
    AxialField embed_icon_pair(const std::string &pole0, const std::string &pole1) const;

    AxialManifold &axial() { return axial_; }
    const AxialManifold &axial() const { return axial_; }

    // ====== Faction density facade primitives (mirrors GDScript FactionDensityMatrix) ======
    static constexpr double DEFAULT_PUMP_SCALE = 0.01;
    static constexpr double DEFAULT_COHERENCE_SCALE = 0.02;
    static constexpr double DEFAULT_DECOHERENCE_TAU = 300.0;

    void faction_pump(const std::string &name, double rate);
    void faction_kick_coherence(const std::string &name_a, const std::string &name_b, double re, double im);
    void faction_apply_lindblad_decay(double dt, double tau);
    void faction_apply_axis_bias(int axis_i, int bit_b, double strength);
    void faction_initialize_uniform();
    void faction_renormalize_trace();

    double faction_get_weight(const std::string &name) const;
    void faction_get_coherence(const std::string &name_a, const std::string &name_b, double &re_out, double &im_out) const;
    void faction_partial_trace_axis(int axis_i, double &r00_out, double &r11_out, double &r01_re_out, double &r01_im_out) const;

    int faction_hamming_distance(const std::string &name_a, const std::string &name_b) const;
    double faction_affinity_for_emoji(const std::string &emoji) const;
    std::vector<std::string> factions_speaking(const std::string &emoji) const;
    double faction_purity() const;
    double faction_diagonal_sum() const;

    void faction_serialize(std::vector<std::string> &names_out, std::vector<double> &data_out) const;
    void faction_deserialize(const std::vector<std::string> &names_in, const std::vector<double> &data_in);

    // Principal mode of ρ_factions: dominant eigenvalue and its eigenvector
    // magnitudes (|ψ_k|², normalized to sum to 1). Returns false if ρ is
    // empty or too small; caller should fall back to uniform.
    bool faction_principal_mode(double &eigenvalue_out, std::vector<double> &amplitudes_out) const;

    // Project the dominant-mode amplitudes through each faction's 12-bit
    // coordinates to get a per-axis probability of bit=1. Returns axes_out
    // sized exactly AXIS_COUNT; values in [0,1]. Empty ρ → all 0.5.
    void faction_principal_axis_projection(std::vector<double> &axes_out) const;

private:
    AxialManifold axial_;
    std::vector<EmojiNode> emojis_;
    std::vector<IconEdge> icons_;
    std::vector<FactionField> factions_;

    std::unordered_map<std::string, int> emoji_to_index_;
    std::unordered_map<std::string, int> faction_to_index_;
    std::unordered_map<std::string, int> pair_to_icon_;

    ComplexMatrix hamiltonian_;
    ComplexMatrix density_;
    ComplexMatrix faction_density_;

    static std::string pair_key(const std::string &a, const std::string &b);
    static std::string unordered_pair_key(const std::string &a, const std::string &b);
    void reindex_pairs();
    void normalize_faction_density();

    // Faction density helpers
    void faction_scale_row_col(std::size_t i, double s);
    void faction_scale_off_diagonals_excluding(std::size_t i, double s);
    bool faction_bits_agree_except(std::size_t i, std::size_t j, int axis_skip) const;
    int faction_bit(std::size_t i, int axis) const;
};

} // namespace spacewheat
