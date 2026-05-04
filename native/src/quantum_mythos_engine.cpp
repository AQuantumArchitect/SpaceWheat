#include "quantum_mythos_engine.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>

namespace godot {

QuantumMythosEngine::QuantumMythosEngine()
    : core_(std::make_unique<spacewheat::MythosGraphCore>()) {}

QuantumMythosEngine::~QuantumMythosEngine() = default;

void QuantumMythosEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("clear"), &QuantumMythosEngine::clear);
    ClassDB::bind_method(D_METHOD("configure_default_axes"), &QuantumMythosEngine::configure_default_axes);
    ClassDB::bind_method(D_METHOD("add_emoji", "emoji", "self_energy", "decay"), &QuantumMythosEngine::add_emoji, DEFVAL(0.0), DEFVAL(0.0));
    ClassDB::bind_method(D_METHOD("add_icon", "icon"), &QuantumMythosEngine::add_icon);
    ClassDB::bind_method(D_METHOD("add_faction", "name", "bits", "sig"), &QuantumMythosEngine::add_faction);
    ClassDB::bind_method(D_METHOD("compose_hamiltonian"), &QuantumMythosEngine::compose_hamiltonian);
    ClassDB::bind_method(D_METHOD("initialize_density_uniform"), &QuantumMythosEngine::initialize_density_uniform);
    ClassDB::bind_method(D_METHOD("initialize_density_pure_emoji", "emoji"), &QuantumMythosEngine::initialize_density_pure_emoji);
    ClassDB::bind_method(D_METHOD("step", "dt", "decoherence"), &QuantumMythosEngine::step, DEFVAL(0.0));
    ClassDB::bind_method(D_METHOD("apply_icon_learned", "pole_0", "pole_1", "strength"), &QuantumMythosEngine::apply_icon_learned, DEFVAL(0.02));
    ClassDB::bind_method(D_METHOD("get_axis_marginal", "axis_index"), &QuantumMythosEngine::get_axis_marginal);
    ClassDB::bind_method(D_METHOD("get_faction_projection_for_icon", "pole_0", "pole_1", "limit"), &QuantumMythosEngine::get_faction_projection_for_icon, DEFVAL(12));
    ClassDB::bind_method(D_METHOD("get_faction_diagonal"), &QuantumMythosEngine::get_faction_diagonal);
    ClassDB::bind_method(D_METHOD("get_hamiltonian_eigen_summary", "limit"), &QuantumMythosEngine::get_hamiltonian_eigen_summary, DEFVAL(8));
    ClassDB::bind_method(D_METHOD("get_icon_expectation", "pole_0", "pole_1"), &QuantumMythosEngine::get_icon_expectation);

    // ====== Faction density facade bindings ======
    ClassDB::bind_method(D_METHOD("faction_pump", "name", "rate"), &QuantumMythosEngine::faction_pump);
    ClassDB::bind_method(D_METHOD("faction_kick_coherence", "name_a", "name_b", "re", "im"), &QuantumMythosEngine::faction_kick_coherence);
    ClassDB::bind_method(D_METHOD("faction_apply_lindblad_decay", "dt", "tau"), &QuantumMythosEngine::faction_apply_lindblad_decay);
    ClassDB::bind_method(D_METHOD("faction_apply_axis_bias", "axis_i", "bit_b", "strength"), &QuantumMythosEngine::faction_apply_axis_bias);
    ClassDB::bind_method(D_METHOD("faction_initialize_uniform"), &QuantumMythosEngine::faction_initialize_uniform);
    ClassDB::bind_method(D_METHOD("faction_renormalize_trace"), &QuantumMythosEngine::faction_renormalize_trace);
    ClassDB::bind_method(D_METHOD("faction_get_weight", "name"), &QuantumMythosEngine::faction_get_weight);
    ClassDB::bind_method(D_METHOD("faction_get_coherence", "name_a", "name_b"), &QuantumMythosEngine::faction_get_coherence);
    ClassDB::bind_method(D_METHOD("faction_partial_trace_axis", "axis_i"), &QuantumMythosEngine::faction_partial_trace_axis);
    ClassDB::bind_method(D_METHOD("faction_hamming_distance", "name_a", "name_b"), &QuantumMythosEngine::faction_hamming_distance);
    ClassDB::bind_method(D_METHOD("faction_affinity_for_emoji", "emoji"), &QuantumMythosEngine::faction_affinity_for_emoji);
    ClassDB::bind_method(D_METHOD("faction_factions_speaking", "emoji"), &QuantumMythosEngine::faction_factions_speaking);
    ClassDB::bind_method(D_METHOD("faction_purity"), &QuantumMythosEngine::faction_purity);
    ClassDB::bind_method(D_METHOD("faction_diagonal_sum"), &QuantumMythosEngine::faction_diagonal_sum);
    ClassDB::bind_method(D_METHOD("faction_get_size"), &QuantumMythosEngine::faction_get_size);
    ClassDB::bind_method(D_METHOD("faction_get_names"), &QuantumMythosEngine::faction_get_names);
    ClassDB::bind_method(D_METHOD("faction_get_index", "name"), &QuantumMythosEngine::faction_get_index);
    ClassDB::bind_method(D_METHOD("faction_serialize"), &QuantumMythosEngine::faction_serialize);
    ClassDB::bind_method(D_METHOD("faction_deserialize", "data"), &QuantumMythosEngine::faction_deserialize);
    ClassDB::bind_method(D_METHOD("faction_principal_mode"), &QuantumMythosEngine::faction_principal_mode);
    ClassDB::bind_method(D_METHOD("faction_principal_axis_projection"), &QuantumMythosEngine::faction_principal_axis_projection);
}

void QuantumMythosEngine::clear() {
    core_->clear();
}

void QuantumMythosEngine::configure_default_axes() {
    // Constructor already does this. Method exists so GDScript can explicitly declare intent.
}

int QuantumMythosEngine::add_emoji(String emoji, double self_energy, double decay) {
    core_->set_emoji_physics(to_std(emoji), self_energy, decay);
    return core_->emoji_index(to_std(emoji));
}

int QuantumMythosEngine::add_icon(Dictionary icon) {
    spacewheat::IconEdge edge;
    edge.name = to_std(icon.get("name", ""));
    edge.id = to_std(icon.get("id", edge.name.c_str()));
    edge.pole0 = to_std(icon.get("pole_0", icon.get("pole0", "")));
    edge.pole1 = to_std(icon.get("pole_1", icon.get("pole1", "")));
    edge.faction = to_std(icon.get("faction", ""));
    edge.discovered = static_cast<bool>(icon.get("discovered", false));
    edge.coupling = static_cast<double>(icon.get("coupling", 0.1));
    edge.phase = static_cast<double>(icon.get("phase", 0.0));
    edge.visibility = static_cast<double>(icon.get("visibility", 1.0));

    if (icon.has("axial_mu")) {
        PackedFloat64Array mu = icon.get("axial_mu", PackedFloat64Array());
        for (int i = 0; i < spacewheat::AXIS_COUNT && i < mu.size(); ++i) {
            edge.field.mu[static_cast<std::size_t>(i)] = mu[i];
        }
    }

    return core_->add_icon(edge);
}

int QuantumMythosEngine::add_faction(String name, PackedFloat64Array bits, PackedStringArray sig) {
    spacewheat::FactionField faction;
    faction.name = to_std(name);
    for (int i = 0; i < bits.size(); ++i) {
        faction.bits.push_back(bits[i]);
    }
    for (int i = 0; i < sig.size(); ++i) {
        faction.sig.push_back(to_std(sig[i]));
    }
    faction.field = core_->axial().field_from_bits(faction.bits);
    return core_->add_faction(faction);
}

void QuantumMythosEngine::compose_hamiltonian() {
    core_->compose_hamiltonian_from_icons();
}

void QuantumMythosEngine::initialize_density_uniform() {
    core_->initialize_density_uniform();
}

void QuantumMythosEngine::initialize_density_pure_emoji(String emoji) {
    core_->initialize_density_pure_emoji(to_std(emoji));
}

void QuantumMythosEngine::step(double dt, double decoherence) {
    core_->step_density(dt, decoherence);
}

void QuantumMythosEngine::apply_icon_learned(String pole_0, String pole_1, double strength) {
    core_->apply_icon_learned(to_std(pole_0), to_std(pole_1), strength);
}

Dictionary QuantumMythosEngine::get_axis_marginal(int axis_index) const {
    Dictionary out;
    const std::vector<double> marginal = core_->axis_marginal(axis_index);
    out["low"] = marginal.size() > 0 ? marginal[0] : 0.0;
    out["high"] = marginal.size() > 1 ? marginal[1] : 0.0;
    return out;
}

Array QuantumMythosEngine::get_faction_projection_for_icon(String pole_0, String pole_1, int limit) const {
    Array out;
    const std::vector<spacewheat::FactionProjection> projections = core_->project_factions_for_icon(to_std(pole_0), to_std(pole_1));
    const int n = std::min(limit, static_cast<int>(projections.size()));
    for (int i = 0; i < n; ++i) {
        Dictionary d;
        d["name"] = to_godot(projections[static_cast<std::size_t>(i)].name);
        d["mass"] = projections[static_cast<std::size_t>(i)].mass;
        d["overlap"] = projections[static_cast<std::size_t>(i)].overlap;
        out.push_back(d);
    }
    return out;
}

PackedFloat64Array QuantumMythosEngine::get_faction_diagonal() const {
    PackedFloat64Array out;
    if (core_->faction_density().empty()) {
        return out;
    }
    const std::vector<double> diag = core_->faction_density().real_diagonal();
    for (double v : diag) {
        out.push_back(v);
    }
    return out;
}

Dictionary QuantumMythosEngine::get_hamiltonian_eigen_summary(int limit) const {
    Dictionary out;
    // Guard against an empty Hamiltonian — the Eigen solver asserts on empty
    // matrices. When compose_hamiltonian() has never been called (or the
    // substrate has zero emojis), return an empty summary rather than crash.
    if (core_->hamiltonian().empty()) {
        out["eigenvalues"] = PackedFloat64Array();
        out["used_external_backend"] = false;
        out["eigenvectors_available"] = false;
        out["iterations"] = 0;
        out["residual"] = 1.0;
        return out;
    }
    spacewheat::EigenResult result = core_->solve_hamiltonian();
    PackedFloat64Array values;
    const int n = std::min(limit, static_cast<int>(result.eigenvalues.size()));
    for (int i = 0; i < n; ++i) {
        values.push_back(result.eigenvalues[static_cast<std::size_t>(i)]);
    }
    out["eigenvalues"] = values;
    out["used_external_backend"] = result.used_external_backend;
    out["eigenvectors_available"] = result.eigenvectors_available;
    out["iterations"] = result.iterations;
    out["residual"] = result.residual;
    return out;
}

double QuantumMythosEngine::get_icon_expectation(String pole_0, String pole_1) const {
    return core_->icon_expectation(to_std(pole_0), to_std(pole_1));
}

std::string QuantumMythosEngine::to_std(const String &s) {
    return std::string(s.utf8().get_data());
}

String QuantumMythosEngine::to_godot(const std::string &s) {
    return String::utf8(s.c_str());
}

// ====== Faction density facade implementations ======

void QuantumMythosEngine::faction_pump(String name, double rate) {
    core_->faction_pump(to_std(name), rate);
}

void QuantumMythosEngine::faction_kick_coherence(String name_a, String name_b, double re, double im) {
    core_->faction_kick_coherence(to_std(name_a), to_std(name_b), re, im);
}

void QuantumMythosEngine::faction_apply_lindblad_decay(double dt, double tau) {
    core_->faction_apply_lindblad_decay(dt, tau);
}

void QuantumMythosEngine::faction_apply_axis_bias(int axis_i, int bit_b, double strength) {
    core_->faction_apply_axis_bias(axis_i, bit_b, strength);
}

void QuantumMythosEngine::faction_initialize_uniform() {
    core_->faction_initialize_uniform();
}

void QuantumMythosEngine::faction_renormalize_trace() {
    core_->faction_renormalize_trace();
}

double QuantumMythosEngine::faction_get_weight(String name) const {
    return core_->faction_get_weight(to_std(name));
}

Vector2 QuantumMythosEngine::faction_get_coherence(String name_a, String name_b) const {
    double re = 0.0, im = 0.0;
    core_->faction_get_coherence(to_std(name_a), to_std(name_b), re, im);
    return Vector2(static_cast<float>(re), static_cast<float>(im));
}

Dictionary QuantumMythosEngine::faction_partial_trace_axis(int axis_i) const {
    Dictionary out;
    double r00 = 0.0, r11 = 0.0, r01_re = 0.0, r01_im = 0.0;
    core_->faction_partial_trace_axis(axis_i, r00, r11, r01_re, r01_im);
    out["r00"] = r00;
    out["r11"] = r11;
    out["r01"] = Vector2(static_cast<float>(r01_re), static_cast<float>(r01_im));
    return out;
}

int QuantumMythosEngine::faction_hamming_distance(String name_a, String name_b) const {
    return core_->faction_hamming_distance(to_std(name_a), to_std(name_b));
}

double QuantumMythosEngine::faction_affinity_for_emoji(String emoji) const {
    return core_->faction_affinity_for_emoji(to_std(emoji));
}

PackedStringArray QuantumMythosEngine::faction_factions_speaking(String emoji) const {
    PackedStringArray out;
    for (const auto &name : core_->factions_speaking(to_std(emoji))) {
        out.push_back(to_godot(name));
    }
    return out;
}

double QuantumMythosEngine::faction_purity() const {
    return core_->faction_purity();
}

double QuantumMythosEngine::faction_diagonal_sum() const {
    return core_->faction_diagonal_sum();
}

int QuantumMythosEngine::faction_get_size() const {
    return static_cast<int>(core_->factions().size());
}

PackedStringArray QuantumMythosEngine::faction_get_names() const {
    PackedStringArray out;
    for (const auto &f : core_->factions()) {
        out.push_back(to_godot(f.name));
    }
    return out;
}

int QuantumMythosEngine::faction_get_index(String name) const {
    return core_->faction_index(to_std(name));
}

Dictionary QuantumMythosEngine::faction_serialize() const {
    Dictionary out;
    std::vector<std::string> names;
    std::vector<double> data;
    core_->faction_serialize(names, data);
    PackedStringArray names_arr;
    for (const auto &n : names) names_arr.push_back(to_godot(n));
    PackedFloat64Array data_arr;
    for (double v : data) data_arr.push_back(v);
    out["version"] = 2;
    out["names"] = names_arr;
    out["data"] = data_arr;
    return out;
}

void QuantumMythosEngine::faction_deserialize(Dictionary data) {
    if (!data.has("names") || !data.has("data")) return;
    PackedStringArray names_arr = data["names"];
    PackedFloat64Array data_arr = data["data"];
    std::vector<std::string> names;
    std::vector<double> data_vec;
    for (int i = 0; i < names_arr.size(); ++i) {
        names.push_back(to_std(names_arr[i]));
    }
    for (int i = 0; i < data_arr.size(); ++i) {
        data_vec.push_back(data_arr[i]);
    }
    core_->faction_deserialize(names, data_vec);
}

Dictionary QuantumMythosEngine::faction_principal_mode() const {
    Dictionary out;
    double eigenvalue = 0.0;
    std::vector<double> amps;
    const bool ok = core_->faction_principal_mode(eigenvalue, amps);
    out["ok"] = ok;
    out["eigenvalue"] = eigenvalue;
    PackedFloat64Array packed;
    for (double v : amps) {
        packed.push_back(v);
    }
    out["amplitudes"] = packed;
    return out;
}

PackedFloat64Array QuantumMythosEngine::faction_principal_axis_projection() const {
    PackedFloat64Array out;
    std::vector<double> axes;
    core_->faction_principal_axis_projection(axes);
    for (double v : axes) {
        out.push_back(v);
    }
    return out;
}

} // namespace godot
