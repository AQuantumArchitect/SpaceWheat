#include "quantum_evolution_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <algorithm>
#include <cmath>
#include <cstring>

using namespace godot;

namespace {
PackedFloat64Array to_packed(const std::vector<double>& v) {
    PackedFloat64Array out;
    out.resize(static_cast<int64_t>(v.size()));
    if (!v.empty()) {
        std::memcpy(out.ptrw(), v.data(), v.size() * sizeof(double));
    }
    return out;
}
}  // namespace

void QuantumEvolutionEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_dimension", "dim"),
                         &QuantumEvolutionEngine::set_dimension);
    ClassDB::bind_method(D_METHOD("set_hamiltonian", "H_packed"),
                         &QuantumEvolutionEngine::set_hamiltonian);
    ClassDB::bind_method(D_METHOD("add_lindblad_triplets", "triplets"),
                         &QuantumEvolutionEngine::add_lindblad_triplets);
    ClassDB::bind_method(D_METHOD("clear_operators"),
                         &QuantumEvolutionEngine::clear_operators);
    ClassDB::bind_method(D_METHOD("set_coherent", "on"),
                         &QuantumEvolutionEngine::set_coherent);
    ClassDB::bind_method(D_METHOD("finalize"),
                         &QuantumEvolutionEngine::finalize);

    ClassDB::bind_method(D_METHOD("get_dimension"),
                         &QuantumEvolutionEngine::get_dimension);
    ClassDB::bind_method(D_METHOD("get_lindblad_count"),
                         &QuantumEvolutionEngine::get_lindblad_count);
    ClassDB::bind_method(D_METHOD("is_finalized"),
                         &QuantumEvolutionEngine::is_finalized);

    ClassDB::bind_method(D_METHOD("evolve_step", "rho_data", "dt"),
                         &QuantumEvolutionEngine::evolve_step);
    ClassDB::bind_method(D_METHOD("get_last_substep_count"),
                         &QuantumEvolutionEngine::get_last_substep_count);
    ClassDB::bind_method(D_METHOD("evolve", "rho_data", "dt", "max_dt"),
                         &QuantumEvolutionEngine::evolve);

    // MI computation methods
    ClassDB::bind_method(D_METHOD("compute_all_mutual_information", "rho_data", "num_qubits"),
                         &QuantumEvolutionEngine::compute_all_mutual_information);
    ClassDB::bind_method(D_METHOD("compute_mi_adaptive", "rho_data", "num_qubits", "biome_purity", "force_full_scan"),
                         &QuantumEvolutionEngine::compute_mi_adaptive);
    ClassDB::bind_method(D_METHOD("clear_mi_candidates"),
                         &QuantumEvolutionEngine::clear_mi_candidates);
    ClassDB::bind_method(D_METHOD("evolve_with_mi", "rho_data", "dt", "max_dt", "num_qubits"),
                         &QuantumEvolutionEngine::evolve_with_mi);

    // Basic observables from packed data
    ClassDB::bind_method(D_METHOD("compute_purity_from_packed", "rho_data"),
                         &QuantumEvolutionEngine::compute_purity_from_packed);
    ClassDB::bind_method(D_METHOD("compute_bloch_metrics_from_packed", "rho_data", "num_qubits"),
                         &QuantumEvolutionEngine::compute_bloch_metrics_from_packed);

    // Eigenstate analysis methods
    ClassDB::bind_method(D_METHOD("compute_eigenstates", "rho_data"),
                         &QuantumEvolutionEngine::compute_eigenstates);
    ClassDB::bind_method(D_METHOD("compute_dominant_eigenvector", "rho_data"),
                         &QuantumEvolutionEngine::compute_dominant_eigenvector);
    ClassDB::bind_method(D_METHOD("compute_eigenvalues", "rho_data"),
                         &QuantumEvolutionEngine::compute_eigenvalues);
    ClassDB::bind_method(D_METHOD("compute_cos2_similarity", "state_a", "state_b"),
                         &QuantumEvolutionEngine::compute_cos2_similarity);
    ClassDB::bind_method(D_METHOD("compute_batch_eigenstates", "biome_rhos"),
                         &QuantumEvolutionEngine::compute_batch_eigenstates);
    ClassDB::bind_method(D_METHOD("compute_eigenstate_similarity_matrix", "eigenvectors"),
                         &QuantumEvolutionEngine::compute_eigenstate_similarity_matrix);
}

QuantumEvolutionEngine::QuantumEvolutionEngine() {
    m_sink = [](swk::Severity sev, const std::string& msg) {
        if (sev == swk::Severity::Error) {
            UtilityFunctions::push_error(String::utf8(msg.c_str()));
        } else {
            UtilityFunctions::push_warning(String::utf8(msg.c_str()));
        }
    };
    m_engine.set_diagnostic_sink(m_sink);
}

QuantumEvolutionEngine::~QuantumEvolutionEngine() {}

void QuantumEvolutionEngine::set_dimension(int dim) { m_engine.set_dimension(dim); }

void QuantumEvolutionEngine::set_coherent(bool on) { m_engine.set_coherent(on); }

void QuantumEvolutionEngine::set_hamiltonian(const PackedFloat64Array& H_packed) {
    m_engine.set_hamiltonian_packed(H_packed.ptr(), H_packed.size());
}

void QuantumEvolutionEngine::add_lindblad_triplets(const PackedFloat64Array& triplets) {
    m_engine.add_lindblad_triplets(triplets.ptr(), triplets.size());
}

void QuantumEvolutionEngine::clear_operators() { m_engine.clear_operators(); }

void QuantumEvolutionEngine::finalize() { m_engine.finalize(); }

int QuantumEvolutionEngine::get_dimension() const { return m_engine.dimension(); }

int QuantumEvolutionEngine::get_lindblad_count() const { return m_engine.lindblad_count(); }

bool QuantumEvolutionEngine::is_finalized() const { return m_engine.is_finalized(); }

int QuantumEvolutionEngine::get_last_substep_count() const { return m_engine.last_substep_count(); }

PackedFloat64Array QuantumEvolutionEngine::evolve_step(const PackedFloat64Array& rho_data, float dt) {
    // One integrator: a single fixed step is evolve with max_dt = dt.
    return evolve(rho_data, dt, dt);
}

PackedFloat64Array QuantumEvolutionEngine::evolve(const PackedFloat64Array& rho_data, float dt, float max_dt) {
    if (!m_engine.is_finalized()) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: call finalize() first!");
        return rho_data;
    }

    // rho must match this engine's dimension. Never overread.
    const int dim = m_engine.dimension();
    const int64_t expected = static_cast<int64_t>(2) * dim * dim;
    if (rho_data.size() != expected) {
        UtilityFunctions::push_warning(
            "QuantumEvolutionEngine::evolve: ρ size mismatch (got ", rho_data.size(),
            ", expected ", expected, " for dim ", dim, ") — returning unchanged.");
        return rho_data;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    m_engine.evolve(rho, static_cast<double>(dt), static_cast<double>(max_dt));
    return pack_dense(rho);
}

Eigen::MatrixXcd QuantumEvolutionEngine::unpack_dense(const PackedFloat64Array& data) const {
    // On a size mismatch the kernel reports an error and yields a zero matrix.
    Eigen::MatrixXcd mat;
    swk::unpack_dense(data.ptr(), data.size(), m_engine.dimension(), mat, &m_sink);
    return mat;
}

PackedFloat64Array QuantumEvolutionEngine::pack_dense(const Eigen::MatrixXcd& mat) const {
    const int dim = m_engine.dimension();
    PackedFloat64Array packed;
    packed.resize(dim * dim * 2);
    if (dim > 0) {
        swk::pack_dense(mat, dim, packed.ptrw());
    }
    return packed;
}

PackedFloat64Array QuantumEvolutionEngine::compute_all_mutual_information(
    const PackedFloat64Array& rho_data, int num_qubits) {
    int num_pairs = num_qubits * (num_qubits - 1) / 2;
    PackedFloat64Array mi_values;
    mi_values.resize(num_pairs);

    if (num_qubits < 2) {
        return mi_values;  // No pairs for 0 or 1 qubit
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    std::vector<double> mi = swk::mutual_information_all(rho, num_qubits);
    const size_t n = std::min(mi.size(), static_cast<size_t>(num_pairs));
    if (n > 0) {
        std::memcpy(mi_values.ptrw(), mi.data(), n * sizeof(double));
    }
    return mi_values;
}

PackedFloat64Array QuantumEvolutionEngine::compute_mi_adaptive(
    const PackedFloat64Array& rho_data, int num_qubits,
    double biome_purity, bool force_full_scan) {
    int num_pairs = num_qubits * (num_qubits - 1) / 2;
    PackedFloat64Array mi_values;
    mi_values.resize(num_pairs);

    if (num_qubits < 2) {
        return mi_values;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    std::vector<double> mi = m_mi_screen.compute(rho, num_qubits, biome_purity, force_full_scan);
    const size_t n = std::min(mi.size(), static_cast<size_t>(num_pairs));
    if (n > 0) {
        std::memcpy(mi_values.ptrw(), mi.data(), n * sizeof(double));
    }
    return mi_values;
}

Dictionary QuantumEvolutionEngine::evolve_with_mi(
    const PackedFloat64Array& rho_data, float dt, float max_dt, int num_qubits) {
    Dictionary result;

    PackedFloat64Array evolved_rho = evolve(rho_data, dt, max_dt);
    result["rho"] = evolved_rho;

    PackedFloat64Array mi_values = compute_all_mutual_information(evolved_rho, num_qubits);
    result["mi"] = mi_values;

    Eigen::MatrixXcd rho = unpack_dense(evolved_rho);
    result["purity"] = compute_purity(rho);
    std::complex<double> tr = compute_trace(rho);
    result["trace_re"] = tr.real();
    result["trace_im"] = tr.imag();
    result["bloch"] = compute_bloch_metrics(rho, num_qubits);

    return result;
}

double QuantumEvolutionEngine::compute_purity(const Eigen::MatrixXcd& rho) const {
    return swk::purity(rho);
}

std::complex<double> QuantumEvolutionEngine::compute_trace(const Eigen::MatrixXcd& rho) const {
    return swk::trace(rho);
}

double QuantumEvolutionEngine::compute_purity_from_packed(const PackedFloat64Array& rho_data) const {
    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    return compute_purity(rho);
}

PackedFloat64Array QuantumEvolutionEngine::compute_bloch_metrics_from_packed(
    const PackedFloat64Array& rho_data, int num_qubits) const {
    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    return compute_bloch_metrics(rho, num_qubits);
}

PackedFloat64Array QuantumEvolutionEngine::compute_bloch_metrics(
    const Eigen::MatrixXcd& rho, int num_qubits) const {
    // Packed [p0,p1,x,y,z,r,theta,phi,r_xy] per qubit (stride 9).
    PackedFloat64Array out;
    if (num_qubits <= 0) {
        return out;
    }
    std::vector<double> bloch = swk::bloch_metrics(rho, num_qubits);
    out.resize(static_cast<int64_t>(num_qubits) * swk::kBlochStride);  // zero-filled
    const size_t n = std::min(bloch.size(), static_cast<size_t>(out.size()));
    if (n > 0) {
        std::memcpy(out.ptrw(), bloch.data(), n * sizeof(double));
    }
    return out;
}

// ============================================================================
// EIGENSTATE ANALYSIS
// ============================================================================

Dictionary QuantumEvolutionEngine::compute_eigenstates(const PackedFloat64Array& rho_data) const {
    Dictionary result;
    const int dim = m_engine.dimension();

    if (dim <= 0) {
        result["error"] = "dimension not set";
        return result;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    swk::EigenResult eig = swk::eigen_analysis(rho);

    if (!eig.ok) {
        result["error"] = "eigenvalue computation failed";
        return result;
    }

    result["eigenvalues"] = to_packed(eig.eigenvalues);
    result["dominant_eigenvector"] = to_packed(eig.dominant_eigenvector);
    result["dominant_eigenvalue"] = eig.dominant_eigenvalue;
    result["dimension"] = dim;

    return result;
}

PackedFloat64Array QuantumEvolutionEngine::compute_dominant_eigenvector(const PackedFloat64Array& rho_data) const {
    PackedFloat64Array result;
    if (m_engine.dimension() <= 0) {
        return result;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    swk::EigenResult eig = swk::eigen_analysis(rho);
    if (!eig.ok) {
        return result;
    }
    return to_packed(eig.dominant_eigenvector);
}

PackedFloat64Array QuantumEvolutionEngine::compute_eigenvalues(const PackedFloat64Array& rho_data) const {
    PackedFloat64Array result;
    if (m_engine.dimension() <= 0) {
        return result;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    swk::EigenResult eig = swk::eigen_analysis(rho);
    if (!eig.ok) {
        return result;
    }
    return to_packed(eig.eigenvalues);
}

double QuantumEvolutionEngine::compute_cos2_similarity(
    const PackedFloat64Array& state_a, const PackedFloat64Array& state_b) const {
    // cos^2(theta) = |<psi_a|psi_b>|^2, states packed as [re0, im0, re1, im1, ...]
    if (state_a.size() != state_b.size() || state_a.is_empty()) {
        return 0.0;
    }
    return swk::cos2_similarity(state_a.ptr(), state_b.ptr(), state_a.size());
}

Dictionary QuantumEvolutionEngine::compute_batch_eigenstates(const Dictionary& biome_rhos) const {
    // Input: {biome_name: rho_packed, ...}; the dimension is inferred per entry.
    Dictionary results;
    Array keys = biome_rhos.keys();

    for (int i = 0; i < keys.size(); i++) {
        String biome_name = keys[i];
        Variant rho_var = biome_rhos[biome_name];

        if (rho_var.get_type() != Variant::PACKED_FLOAT64_ARRAY) {
            continue;
        }

        PackedFloat64Array rho_data = rho_var;

        // rho is dim x dim complex, packed as dim*dim*2 doubles
        int data_size = rho_data.size();
        int dim_squared = data_size / 2;
        int dim = static_cast<int>(std::sqrt(static_cast<double>(dim_squared)));

        if (dim * dim * 2 != data_size || dim <= 0) {
            Dictionary err;
            err["error"] = "invalid rho dimensions";
            results[biome_name] = err;
            continue;
        }

        Eigen::MatrixXcd rho;
        swk::unpack_dense(rho_data.ptr(), data_size, dim, rho);

        swk::EigenResult eig = swk::eigen_analysis(rho);

        if (!eig.ok) {
            Dictionary err;
            err["error"] = "eigenvalue computation failed";
            results[biome_name] = err;
            continue;
        }

        Dictionary biome_result;
        biome_result["eigenvalues"] = to_packed(eig.eigenvalues);
        biome_result["dominant_eigenvector"] = to_packed(eig.dominant_eigenvector);
        biome_result["dominant_eigenvalue"] = eig.dominant_eigenvalue;
        biome_result["dimension"] = dim;
        biome_result["purity"] = compute_purity(rho);

        results[biome_name] = biome_result;
    }

    return results;
}

PackedFloat64Array QuantumEvolutionEngine::compute_eigenstate_similarity_matrix(
    const Array& eigenvectors) const {
    // Upper-triangular pairwise cos^2 similarities: [sim_01, sim_02, ..., sim_12, ...]
    int n = eigenvectors.size();
    int num_pairs = n * (n - 1) / 2;

    PackedFloat64Array result;
    result.resize(num_pairs);

    if (n < 2) {
        return result;
    }

    double* ptr = result.ptrw();
    int idx = 0;

    for (int i = 0; i < n; i++) {
        Variant vi = eigenvectors[i];
        if (vi.get_type() != Variant::PACKED_FLOAT64_ARRAY) {
            for (int j = i + 1; j < n; j++) {
                ptr[idx++] = 0.0;
            }
            continue;
        }
        PackedFloat64Array state_i = vi;

        for (int j = i + 1; j < n; j++) {
            Variant vj = eigenvectors[j];
            if (vj.get_type() != Variant::PACKED_FLOAT64_ARRAY) {
                ptr[idx++] = 0.0;
                continue;
            }
            PackedFloat64Array state_j = vj;

            ptr[idx++] = compute_cos2_similarity(state_i, state_j);
        }
    }

    return result;
}
