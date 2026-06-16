#include "quantum_evolution_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <cmath>

using namespace godot;

namespace {
inline void enforce_density_matrix(Eigen::MatrixXcd &rho) {
    const int dim = std::min(rho.rows(), rho.cols());

    // 1. Enforce Hermiticity: ρ = (ρ + ρ†)/2
    rho = (rho + rho.adjoint()) * 0.5;

    // 2. Clamp negative diagonals AND zero their coherences.
    for (int i = 0; i < dim; i++) {
        double re = rho(i, i).real();
        if (re < 0.0) {
            rho(i, i) = std::complex<double>(0.0, 0.0);
            for (int k = 0; k < dim; k++) {
                if (k != i) {
                    rho(i, k) = std::complex<double>(0.0, 0.0);
                    rho(k, i) = std::complex<double>(0.0, 0.0);
                }
            }
        } else {
            rho(i, i) = std::complex<double>(re, 0.0);
        }
    }

    // 3. Renormalize to unit trace.
    double trace = 0.0;
    for (int i = 0; i < dim; i++) {
        trace += rho(i, i).real();
    }
    if (std::isfinite(trace) && trace > 1e-14) {
        rho *= (1.0 / trace);
    }

    // 4. Cap coherences so Tr(ρ²) ≤ 1 (enforce positive semidefiniteness).
    //    Euler integration can produce off-diagonals too large for the populations
    //    to support, making the matrix non-PSD. Scale off-diagonals down uniformly
    //    (physical interpretation: T₂ dephasing to keep state in Bloch ball).
    //
    //    Tr(ρ²) = Σ_i ρ_ii² + 2 Σ_{i<j} |ρ_ij|²
    //    If > 1, find α such that Σ_i ρ_ii² + α² × 2 Σ_{i<j} |ρ_ij|² = 1
    double diag_sq = 0.0;
    double offdiag_sq = 0.0;
    for (int i = 0; i < dim; i++) {
        double d = rho(i, i).real();
        diag_sq += d * d;
        for (int j = i + 1; j < dim; j++) {
            offdiag_sq += std::norm(rho(i, j));  // |ρ_ij|²
        }
    }
    double purity = diag_sq + 2.0 * offdiag_sq;
    if (purity > 1.0 && offdiag_sq > 1e-14) {
        // Scale factor: α = sqrt((1 - diag_sq) / (2 * offdiag_sq))
        double target_offdiag = 1.0 - diag_sq;
        if (target_offdiag < 0.0) target_offdiag = 0.0;
        double alpha = std::sqrt(target_offdiag / (2.0 * offdiag_sq));
        for (int i = 0; i < dim; i++) {
            for (int j = 0; j < dim; j++) {
                if (i != j) {
                    rho(i, j) *= alpha;
                }
            }
        }
    }
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

QuantumEvolutionEngine::QuantumEvolutionEngine()
    : m_dim(0), m_finalized(false), m_has_hamiltonian(false),
      m_coherent(true), m_eig_valid(false), m_U_dt(-1.0), m_U_valid(false) {}

QuantumEvolutionEngine::~QuantumEvolutionEngine() {}

void QuantumEvolutionEngine::set_dimension(int dim) {
    m_dim = dim;
    m_finalized = false;
    m_eig_valid = false;
    m_U_valid = false;
}

void QuantumEvolutionEngine::set_coherent(bool on) {
    m_coherent = on;  // gate only — does not change H or the eigendecomposition
}

void QuantumEvolutionEngine::set_hamiltonian(const PackedFloat64Array& H_packed) {
    if (m_dim == 0) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: set_dimension first!");
        return;
    }

    // Build sparse Hamiltonian from packed dense format
    // H_packed is row-major: [re00, im00, re01, im01, ..., renn, imnn]
    const double* ptr = H_packed.ptr();
    const double threshold = 1e-15;

    std::vector<Eigen::Triplet<std::complex<double>>> triplets;
    triplets.reserve(m_dim * 4);  // Estimate: sparse matrices typically have O(n) non-zeros

    for (int i = 0; i < m_dim; i++) {
        for (int j = 0; j < m_dim; j++) {
            int idx = (i * m_dim + j) * 2;
            double re = ptr[idx];
            double im = ptr[idx + 1];

            if (std::abs(re) > threshold || std::abs(im) > threshold) {
                triplets.emplace_back(i, j, std::complex<double>(re, im));
            }
        }
    }

    m_hamiltonian.resize(m_dim, m_dim);
    m_hamiltonian.setFromTriplets(triplets.begin(), triplets.end());
    m_hamiltonian.makeCompressed();

    m_has_hamiltonian = true;
    m_finalized = false;
    m_eig_valid = false;  // H changed → eigendecomposition + propagator stale
    m_U_valid = false;
}

void QuantumEvolutionEngine::add_lindblad_triplets(const PackedFloat64Array& triplets) {
    if (m_dim == 0) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: set_dimension first!");
        return;
    }

    // Parse triplets: [row0, col0, re0, im0, row1, col1, re1, im1, ...]
    int num_entries = triplets.size() / 4;
    std::vector<Eigen::Triplet<std::complex<double>>> eigen_triplets;
    eigen_triplets.reserve(num_entries);

    const double* ptr = triplets.ptr();
    for (int i = 0; i < num_entries; i++) {
        int row = static_cast<int>(ptr[i * 4]);
        int col = static_cast<int>(ptr[i * 4 + 1]);
        double re = ptr[i * 4 + 2];
        double im = ptr[i * 4 + 3];

        if (std::abs(re) > 1e-15 || std::abs(im) > 1e-15) {
            eigen_triplets.emplace_back(row, col, std::complex<double>(re, im));
        }
    }

    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> L(m_dim, m_dim);
    L.setFromTriplets(eigen_triplets.begin(), eigen_triplets.end());
    L.makeCompressed();

    m_lindblads.push_back(L);
    m_finalized = false;
}

void QuantumEvolutionEngine::clear_operators() {
    m_lindblads.clear();
    m_lindblad_dags.clear();
    m_LdagLs.clear();
    m_hamiltonian.resize(0, 0);
    m_has_hamiltonian = false;
    m_finalized = false;
    m_eig_valid = false;
    m_U_valid = false;
}

void QuantumEvolutionEngine::finalize() {
    // Precompute L†, L†L for each Lindblad operator
    m_lindblad_dags.clear();
    m_LdagLs.clear();

    m_lindblad_dags.reserve(m_lindblads.size());
    m_LdagLs.reserve(m_lindblads.size());

    for (const auto& L : m_lindblads) {
        // L† (adjoint)
        Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> L_dag = L.adjoint();
        m_lindblad_dags.push_back(L_dag);

        // L†L
        Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> LdagL = L_dag * L;
        LdagL.makeCompressed();
        m_LdagLs.push_back(LdagL);
    }

    // Pre-allocate scratch buffers to avoid per-frame allocation
    if (m_dim > 0) {
        m_drho_buffer = Eigen::MatrixXcd::Zero(m_dim, m_dim);
        m_temp_buffer = Eigen::MatrixXcd::Zero(m_dim, m_dim);
    }

    // Eigendecompose the Hermitian H once: H = VΛV†. This powers the exact unitary
    // propagator U = exp(-iH·dt) = V·diag(e^{-iλdt})·V† used in the no-dissipation path.
    m_eig_valid = false;
    m_U_valid = false;
    if (m_has_hamiltonian && m_dim > 0) {
        Eigen::MatrixXcd H_dense(m_hamiltonian);
        H_dense = 0.5 * (H_dense + H_dense.adjoint());  // symmetrize for numerical safety
        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> es(H_dense);
        if (es.info() == Eigen::Success) {
            m_eig_vecs = es.eigenvectors();
            m_eig_vals = es.eigenvalues();
            m_eig_valid = true;
        }
    }

    m_finalized = true;
}

bool QuantumEvolutionEngine::can_unitary() const {
    // Exact unitary applies only when the dynamics ARE unitary: coherent generator on,
    // a Hamiltonian present and eigendecomposed, and NO dissipators.
    return m_coherent && m_has_hamiltonian && m_eig_valid && m_lindblads.empty();
}

const Eigen::MatrixXcd& QuantumEvolutionEngine::propagator_for(double dt) {
    if (m_U_valid && m_U_dt == dt) {
        return m_U;
    }
    // U = V · diag(e^{-iλ·dt}) · V†
    Eigen::VectorXcd phase(m_dim);
    for (int k = 0; k < m_dim; k++) {
        double a = -m_eig_vals(k) * dt;
        phase(k) = std::complex<double>(std::cos(a), std::sin(a));
    }
    m_U = m_eig_vecs * phase.asDiagonal() * m_eig_vecs.adjoint();
    m_U_dt = dt;
    m_U_valid = true;
    return m_U;
}

int QuantumEvolutionEngine::get_dimension() const {
    return m_dim;
}

int QuantumEvolutionEngine::get_lindblad_count() const {
    return static_cast<int>(m_lindblads.size());
}

bool QuantumEvolutionEngine::is_finalized() const {
    return m_finalized;
}

PackedFloat64Array QuantumEvolutionEngine::evolve_step(const PackedFloat64Array& rho_data, float dt) {
    if (!m_finalized) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: call finalize() first!");
        return rho_data;  // Return unchanged
    }

    // PRECONDITION: ρ must be a dim×dim complex matrix (2·dim² packed floats). Without this
    // check a mis-sized ρ (e.g. another biome's state handed to this engine) would make
    // unpack_dense read past the buffer → heap overread / SIGSEGV. Validate, never overread.
    const int64_t expected = static_cast<int64_t>(2) * m_dim * m_dim;
    if (rho_data.size() != expected) {
        UtilityFunctions::push_warning(
            "QuantumEvolutionEngine::evolve_step: ρ size mismatch (got ", rho_data.size(),
            ", expected ", expected, " for dim ", m_dim, ") — returning unchanged.");
        return rho_data;
    }

    // EXACT UNITARY PATH (coherent, no dissipation): ρ → U ρ U†, U = exp(-iH·dt).
    // Purity-exact (r=1), no Euler error, no enforce clamp. See can_unitary().
    if (can_unitary()) {
        Eigen::MatrixXcd rho_u = unpack_dense(rho_data);
        const Eigen::MatrixXcd& U = propagator_for(static_cast<double>(dt));
        rho_u = U * rho_u * U.adjoint();
        return pack_dense(rho_u);
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    Eigen::MatrixXcd drho = Eigen::MatrixXcd::Zero(m_dim, m_dim);

    // =========================================================================
    // Term 1: Hamiltonian evolution -i[H, ρ]  (coherent generator)
    // =========================================================================
    if (m_coherent && m_has_hamiltonian) {
        // [H, ρ] = Hρ - ρH
        Eigen::MatrixXcd commutator = m_hamiltonian * rho - rho * m_hamiltonian;
        drho += std::complex<double>(0.0, -1.0) * commutator;
    }

    // =========================================================================
    // Term 2: Lindblad dissipation Σ_k (L_k ρ L_k† - ½{L_k†L_k, ρ})
    // =========================================================================
    for (size_t k = 0; k < m_lindblads.size(); k++) {
        const auto& L = m_lindblads[k];
        const auto& L_dag = m_lindblad_dags[k];
        const auto& LdagL = m_LdagLs[k];

        // L ρ L† (sparse × dense × sparse)
        Eigen::MatrixXcd L_rho = L * rho;           // Sparse × Dense
        Eigen::MatrixXcd L_rho_Ldag = L_rho * L_dag; // Dense × Sparse

        // {L†L, ρ} = L†L ρ + ρ L†L (anticommutator with sparse L†L)
        Eigen::MatrixXcd LdagL_rho = LdagL * rho;   // Sparse × Dense
        Eigen::MatrixXcd rho_LdagL = rho * LdagL;   // Dense × Sparse

        // Dissipator: L ρ L† - 0.5 * (L†L ρ + ρ L†L)
        drho += L_rho_Ldag - 0.5 * (LdagL_rho + rho_LdagL);
    }

    // =========================================================================
    // Euler integration: ρ(t+dt) = ρ(t) + dt * dρ/dt
    // =========================================================================
    rho += static_cast<double>(dt) * drho;
    enforce_density_matrix(rho);

    return pack_dense(rho);
}

PackedFloat64Array QuantumEvolutionEngine::evolve(const PackedFloat64Array& rho_data, float dt, float max_dt) {
    if (!m_finalized) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: call finalize() first!");
        return rho_data;
    }

    // PRECONDITION: ρ must match this engine's dimension (see evolve_step). Never overread.
    const int64_t expected = static_cast<int64_t>(2) * m_dim * m_dim;
    if (rho_data.size() != expected) {
        UtilityFunctions::push_warning(
            "QuantumEvolutionEngine::evolve: ρ size mismatch (got ", rho_data.size(),
            ", expected ", expected, " for dim ", m_dim, ") — returning unchanged.");
        return rho_data;
    }

    // =========================================================================
    // Adaptive Euler with analytic step size from purity constraint.
    //
    // After a step ρ' = ρ + h·D (D = dρ/dt):
    //   Tr(ρ'²) = Tr(ρ²) + 2h·Tr(ρD) + h²·Tr(D²)
    //
    // This quadratic in h tells us the EXACT largest step where Tr(ρ'²) ≤ 1.
    // When dynamics are fast (large ||D||), h shrinks. Near steady-state, h
    // grows to max_dt. No rejected steps, no fixed granularity.
    // =========================================================================
    // EXACT UNITARY PATH (coherent, no dissipation): one exact step ρ → U ρ U† over the
    // whole interval — U = exp(-iH·dt) is exact for any dt, so no substepping is needed.
    if (can_unitary()) {
        Eigen::MatrixXcd rho_u = unpack_dense(rho_data);
        const Eigen::MatrixXcd& U = propagator_for(static_cast<double>(dt));
        rho_u = U * rho_u * U.adjoint();
        return pack_dense(rho_u);
    }

    const float max_step = (max_dt > 0.0f) ? max_dt : dt;
    const float min_step = 1e-6f;

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    float remaining = dt;

    while (remaining > min_step * 0.5f) {
        // Compute dρ/dt = -i[H,ρ] + Σ D[L](ρ)
        Eigen::MatrixXcd drho = Eigen::MatrixXcd::Zero(m_dim, m_dim);

        if (m_coherent && m_has_hamiltonian) {
            Eigen::MatrixXcd comm = m_hamiltonian * rho - rho * m_hamiltonian;
            drho += std::complex<double>(0.0, -1.0) * comm;
        }

        for (size_t k = 0; k < m_lindblads.size(); k++) {
            const auto& L = m_lindblads[k];
            const auto& L_dag = m_lindblad_dags[k];
            const auto& LdagL = m_LdagLs[k];
            drho += L * rho * L_dag - 0.5 * (LdagL * rho + rho * LdagL);
        }

        // Three traces for the purity quadratic (O(N²), negligible)
        double tr_rho_sq = 0.0;  // Tr(ρ²) = Σ|ρ_ij|²
        double tr_rho_D  = 0.0;  // Tr(ρD)  (real for Hermitian ρ, D)
        double tr_D_sq   = 0.0;  // Tr(D²) = Σ|D_ij|²

        for (int i = 0; i < m_dim; i++) {
            for (int j = 0; j < m_dim; j++) {
                tr_rho_sq += std::norm(rho(i, j));
                tr_D_sq   += std::norm(drho(i, j));
                tr_rho_D  += (rho(i, j) * std::conj(drho(i, j))).real();
            }
        }

        // Solve a·h² + b·h + c ≤ 0 for h
        //   a = Tr(D²) ≥ 0
        //   b = 2·Tr(ρD)
        //   c = Tr(ρ²) - 1  (≤ 0 for valid state)
        float h_opt = max_step;

        if (tr_D_sq > 1e-14) {
            double a = tr_D_sq;
            double b = 2.0 * tr_rho_D;
            double c = tr_rho_sq - 1.0;
            double disc = b * b - 4.0 * a * c;

            if (c < -1e-10 && disc > 0.0) {
                // Valid state inside Bloch ball: positive root = max safe step
                double h_max = (-b + std::sqrt(disc)) / (2.0 * a);
                if (h_max > 0.0) {
                    h_opt = static_cast<float>(h_max * 0.9);  // 90% headroom
                }
            } else if (c >= -1e-10 && c < 1e-6) {
                // State AT the purity boundary (pure state, c ≈ 0).
                // Unitary (Hamiltonian-only) evolution preserves purity exactly,
                // so the constraint Tr(ρ'²) ≤ 1 is satisfied analytically.
                // Euler's discretization error is bounded and corrected by
                // enforce_density_matrix(). Use max_step to avoid 100k substeps.
                h_opt = max_step;
            } else {
                // State PAST purity boundary (c > 1e-6) — tiny step to recover
                h_opt = min_step;
            }
        }
        // else: D ≈ 0 (steady state), any step is fine → use max_step

        // Clamp to [min_step, max_step] and remaining time
        float step = std::min({h_opt, max_step, remaining});
        step = std::max(step, min_step);

        // Euler step + enforcement
        rho += static_cast<double>(step) * drho;
        enforce_density_matrix(rho);
        remaining -= step;
    }

    return pack_dense(rho);
}

Eigen::MatrixXcd QuantumEvolutionEngine::unpack_dense(const PackedFloat64Array& data) const {
    Eigen::MatrixXcd mat(m_dim, m_dim);
    const double* ptr = data.ptr();

    for (int i = 0; i < m_dim; i++) {
        for (int j = 0; j < m_dim; j++) {
            int idx = (i * m_dim + j) * 2;
            mat(i, j) = std::complex<double>(ptr[idx], ptr[idx + 1]);
        }
    }
    return mat;
}

PackedFloat64Array QuantumEvolutionEngine::pack_dense(const Eigen::MatrixXcd& mat) const {
    PackedFloat64Array packed;
    packed.resize(m_dim * m_dim * 2);
    double* ptr = packed.ptrw();

    for (int i = 0; i < m_dim; i++) {
        for (int j = 0; j < m_dim; j++) {
            int idx = (i * m_dim + j) * 2;
            ptr[idx] = mat(i, j).real();
            ptr[idx + 1] = mat(i, j).imag();
        }
    }
    return packed;
}

// ============================================================================
// MUTUAL INFORMATION COMPUTATION
// ============================================================================

Eigen::MatrixXcd QuantumEvolutionEngine::partial_trace_single(
    const Eigen::MatrixXcd& rho, int qubit, int num_qubits) const {
    // Trace out all qubits except 'qubit', returning 2×2 reduced density matrix
    // Uses the formula: ρ_A = Tr_B(ρ) where B is the complement of qubit A

    int dim = 1 << num_qubits;
    Eigen::MatrixXcd reduced = Eigen::MatrixXcd::Zero(2, 2);

    // For each element (a, b) of the 2×2 reduced matrix (a, b ∈ {0, 1})
    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            std::complex<double> sum(0.0, 0.0);

            // Sum over all basis states where qubit has value a (row) and b (col)
            // and all other qubits have the same value (trace condition).
            // GDScript convention (RegisterMap, HamiltonianBuilder): qubit q lives at
            // bit position (num_qubits - 1 - q) — MSB. Must match here.
            for (int other_bits = 0; other_bits < (1 << (num_qubits - 1)); other_bits++) {
                int row_idx = 0, col_idx = 0;
                int bit_pos = 0;
                for (int q = 0; q < num_qubits; q++) {
                    int shift = num_qubits - 1 - q;
                    if (q == qubit) {
                        row_idx |= (a << shift);
                        col_idx |= (b << shift);
                    } else {
                        int other_bit = (other_bits >> bit_pos) & 1;
                        row_idx |= (other_bit << shift);
                        col_idx |= (other_bit << shift);
                        bit_pos++;
                    }
                }
                sum += rho(row_idx, col_idx);
            }
            reduced(a, b) = sum;
        }
    }
    return reduced;
}

Eigen::MatrixXcd QuantumEvolutionEngine::partial_trace_complement(
    const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const {
    // Trace out all qubits except qubit_a and qubit_b, returning 4×4 reduced matrix
    // Basis order: |00⟩, |01⟩, |10⟩, |11⟩ where first digit is qubit_a, second is qubit_b

    int dim = 1 << num_qubits;
    Eigen::MatrixXcd reduced = Eigen::MatrixXcd::Zero(4, 4);

    // Ensure qubit_a < qubit_b for consistent ordering
    int q_lo = std::min(qubit_a, qubit_b);
    int q_hi = std::max(qubit_a, qubit_b);
    bool swapped = (qubit_a > qubit_b);

    // For each element of the 4×4 reduced matrix
    for (int row_ab = 0; row_ab < 4; row_ab++) {
        for (int col_ab = 0; col_ab < 4; col_ab++) {
            // Extract qubit values from 2-bit indices
            int a_row = swapped ? (row_ab & 1) : ((row_ab >> 1) & 1);
            int b_row = swapped ? ((row_ab >> 1) & 1) : (row_ab & 1);
            int a_col = swapped ? (col_ab & 1) : ((col_ab >> 1) & 1);
            int b_col = swapped ? ((col_ab >> 1) & 1) : (col_ab & 1);

            std::complex<double> sum(0.0, 0.0);

            // Sum over all other qubits (trace condition: same value in row and col)
            int other_qubits = num_qubits - 2;
            for (int other_bits = 0; other_bits < (1 << other_qubits); other_bits++) {
                int row_idx = 0, col_idx = 0;
                int bit_pos = 0;

                // MSB convention to match GDScript (qubit q at bit num_qubits-1-q).
                for (int q = 0; q < num_qubits; q++) {
                    int shift = num_qubits - 1 - q;
                    if (q == qubit_a) {
                        row_idx |= (a_row << shift);
                        col_idx |= (a_col << shift);
                    } else if (q == qubit_b) {
                        row_idx |= (b_row << shift);
                        col_idx |= (b_col << shift);
                    } else {
                        int other_bit = (other_bits >> bit_pos) & 1;
                        row_idx |= (other_bit << shift);
                        col_idx |= (other_bit << shift);
                        bit_pos++;
                    }
                }
                sum += rho(row_idx, col_idx);
            }
            reduced(row_ab, col_ab) = sum;
        }
    }
    return reduced;
}

double QuantumEvolutionEngine::von_neumann_entropy(const Eigen::MatrixXcd& reduced_rho) const {
    // S(ρ) = -Tr(ρ log ρ) = -Σ λ_i log λ_i (in bits)
    // Use eigenvalue decomposition

    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(reduced_rho);
    Eigen::VectorXd eigenvalues = solver.eigenvalues().real();

    double entropy = 0.0;
    const double eps = 1e-15;
    const double log2_e = 1.0 / std::log(2.0);  // Convert nats to bits

    for (int i = 0; i < eigenvalues.size(); i++) {
        double lambda = eigenvalues(i);
        if (lambda > eps) {
            entropy -= lambda * std::log(lambda) * log2_e;
        }
    }

    return std::max(entropy, 0.0);  // Ensure non-negative due to numerical errors
}

double QuantumEvolutionEngine::mutual_information(
    const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const {
    // I(A:B) = S(A) + S(B) - S(AB)

    Eigen::MatrixXcd rho_a = partial_trace_single(rho, qubit_a, num_qubits);
    Eigen::MatrixXcd rho_b = partial_trace_single(rho, qubit_b, num_qubits);
    Eigen::MatrixXcd rho_ab = partial_trace_complement(rho, qubit_a, qubit_b, num_qubits);

    double S_a = von_neumann_entropy(rho_a);
    double S_b = von_neumann_entropy(rho_b);
    double S_ab = von_neumann_entropy(rho_ab);

    // Subadditivity guarantees I(A:B) >= 0
    return std::max(S_a + S_b - S_ab, 0.0);
}

PackedFloat64Array QuantumEvolutionEngine::compute_all_mutual_information(
    const PackedFloat64Array& rho_data, int num_qubits) {
    // Compute MI for all qubit pairs in upper triangular order
    // Returns: [mi_01, mi_02, ..., mi_0(n-1), mi_12, mi_13, ..., mi_(n-2)(n-1)]
    // Total: n*(n-1)/2 values
    //
    // OPTIMIZATION: Cache single-qubit entropies S(i) to avoid recomputation
    // Old: 3 eigendecomps per pair × n(n-1)/2 pairs = O(3n²) eigendecomps
    // New: n + n(n-1)/2 eigendecomps = O(n² / 2) eigendecomps (~50% reduction)

    int num_pairs = num_qubits * (num_qubits - 1) / 2;
    PackedFloat64Array mi_values;
    mi_values.resize(num_pairs);

    if (num_qubits < 2) {
        return mi_values;  // No pairs for 0 or 1 qubit
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    double* ptr = mi_values.ptrw();

    // Pre-compute all single-qubit reduced density matrices and entropies
    std::vector<Eigen::MatrixXcd> single_rhos(num_qubits);
    std::vector<double> single_entropies(num_qubits);

    for (int q = 0; q < num_qubits; q++) {
        single_rhos[q] = partial_trace_single(rho, q, num_qubits);
        single_entropies[q] = von_neumann_entropy(single_rhos[q]);
    }

    // Now compute MI for each pair using cached single-qubit entropies
    // I(A:B) = S(A) + S(B) - S(AB)
    int idx = 0;
    for (int i = 0; i < num_qubits; i++) {
        for (int j = i + 1; j < num_qubits; j++) {
            // Only need to compute S(AB) - the two-qubit joint entropy
            Eigen::MatrixXcd rho_ab = partial_trace_complement(rho, i, j, num_qubits);
            double S_ab = von_neumann_entropy(rho_ab);

            // MI = S(i) + S(j) - S(ij) using cached single-qubit entropies
            double mi = single_entropies[i] + single_entropies[j] - S_ab;
            ptr[idx] = std::max(mi, 0.0);  // Ensure non-negative
            idx++;
        }
    }

    return mi_values;
}

// ============================================================================
// OPTIMIZED ADAPTIVE MI COMPUTATION
// ============================================================================

Eigen::Matrix<std::complex<double>, 2, 2> QuantumEvolutionEngine::partial_trace_single_2x2(
    const Eigen::MatrixXcd& rho, int qubit, int num_qubits) const {
    // Trace out all qubits except 'qubit', return fixed 2x2 matrix
    Eigen::Matrix<std::complex<double>, 2, 2> result;
    result.setZero();

    int dim = 1 << num_qubits;
    int qubit_mask = 1 << (num_qubits - 1 - qubit);

    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            // Check if indices differ only in the target qubit position
            int other_bits_i = i & ~qubit_mask;
            int other_bits_j = j & ~qubit_mask;
            if (other_bits_i != other_bits_j) continue;

            int qi = (i & qubit_mask) ? 1 : 0;
            int qj = (j & qubit_mask) ? 1 : 0;
            result(qi, qj) += rho(i, j);
        }
    }
    return result;
}

Eigen::Matrix<std::complex<double>, 4, 4> QuantumEvolutionEngine::partial_trace_pair_4x4(
    const Eigen::MatrixXcd& rho, int qa, int qb, int num_qubits) const {
    // Trace out all qubits except qa and qb, return fixed 4x4 matrix
    // Uses smart algorithm: O(4 × 2^(n-2)) instead of O(4^n)
    Eigen::Matrix<std::complex<double>, 4, 4> result;
    result.setZero();

    // Ensure consistent ordering
    int q_lo = std::min(qa, qb);
    int q_hi = std::max(qa, qb);
    bool swapped = (qa > qb);

    int other_qubits = num_qubits - 2;
    int other_dim = 1 << other_qubits;

    // For each element of the 4×4 reduced matrix
    for (int row_ab = 0; row_ab < 4; row_ab++) {
        for (int col_ab = 0; col_ab < 4; col_ab++) {
            // Extract qubit values from 2-bit indices
            int a_row = swapped ? (row_ab & 1) : ((row_ab >> 1) & 1);
            int b_row = swapped ? ((row_ab >> 1) & 1) : (row_ab & 1);
            int a_col = swapped ? (col_ab & 1) : ((col_ab >> 1) & 1);
            int b_col = swapped ? ((col_ab >> 1) & 1) : (col_ab & 1);

            std::complex<double> sum(0.0, 0.0);

            // Sum over all other qubits (trace condition: same value in row and col)
            for (int other_bits = 0; other_bits < other_dim; other_bits++) {
                int row_idx = 0, col_idx = 0;
                int bit_pos = 0;

                for (int q = 0; q < num_qubits; q++) {
                    int bit_val;
                    if (q == q_lo) {
                        row_idx |= (a_row << (num_qubits - 1 - q));
                        col_idx |= (a_col << (num_qubits - 1 - q));
                    } else if (q == q_hi) {
                        row_idx |= (b_row << (num_qubits - 1 - q));
                        col_idx |= (b_col << (num_qubits - 1 - q));
                    } else {
                        bit_val = (other_bits >> bit_pos) & 1;
                        row_idx |= (bit_val << (num_qubits - 1 - q));
                        col_idx |= (bit_val << (num_qubits - 1 - q));
                        bit_pos++;
                    }
                }

                sum += rho(row_idx, col_idx);
            }

            result(row_ab, col_ab) = sum;
        }
    }
    return result;
}

double QuantumEvolutionEngine::trace_rho_squared_2x2(
    const Eigen::Matrix<std::complex<double>, 2, 2>& rho) const {
    // Tr(ρ²) for Hermitian 2×2 = |ρ₀₀|² + 2|ρ₀₁|² + |ρ₁₁|²
    return std::norm(rho(0,0)) + 2.0*std::norm(rho(0,1)) + std::norm(rho(1,1));
}

double QuantumEvolutionEngine::trace_rho_squared_4x4(
    const Eigen::Matrix<std::complex<double>, 4, 4>& rho) const {
    // Tr(ρ²) for Hermitian 4×4
    double sum = 0.0;
    for (int i = 0; i < 4; i++) {
        sum += std::norm(rho(i,i));  // Diagonal terms
        for (int j = i+1; j < 4; j++) {
            sum += 2.0 * std::norm(rho(i,j));  // Off-diagonal (Hermitian symmetry)
        }
    }
    return sum;
}

double QuantumEvolutionEngine::screen_product_deviation(
    const Eigen::Matrix<std::complex<double>, 4, 4>& rho_ab,
    const Eigen::Matrix<std::complex<double>, 2, 2>& rho_a,
    const Eigen::Matrix<std::complex<double>, 2, 2>& rho_b) const {
    // Compute ||ρ_AB - ρ_A ⊗ ρ_B||²_F (Frobenius norm squared)
    // If small, state is nearly separable and MI ≈ 0
    double deviation = 0.0;
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 2; j++) {
            for (int k = 0; k < 2; k++) {
                for (int l = 0; l < 2; l++) {
                    int row = i * 2 + k;
                    int col = j * 2 + l;
                    auto expected = rho_a(i, j) * rho_b(k, l);
                    auto diff = rho_ab(row, col) - expected;
                    deviation += std::norm(diff);
                }
            }
        }
    }
    return deviation;
}

double QuantumEvolutionEngine::compute_mi_linear(
    const Eigen::Matrix<std::complex<double>, 4, 4>& rho_ab,
    const Eigen::Matrix<std::complex<double>, 2, 2>& rho_a,
    const Eigen::Matrix<std::complex<double>, 2, 2>& rho_b) const {
    // Linear entropy approximation: S_lin(ρ) = 1 - Tr(ρ²)
    // I_lin = S_lin(A) + S_lin(B) - S_lin(AB)
    //       = (1 - P_A) + (1 - P_B) - (1 - P_AB)
    //       = 1 - P_A - P_B + P_AB
    double purity_a = trace_rho_squared_2x2(rho_a);
    double purity_b = trace_rho_squared_2x2(rho_b);
    double purity_ab = trace_rho_squared_4x4(rho_ab);

    return std::max(0.0, 1.0 - purity_a - purity_b + purity_ab);
}

PackedFloat64Array QuantumEvolutionEngine::compute_mi_adaptive(
    const PackedFloat64Array& rho_data, int num_qubits,
    double biome_purity, bool force_full_scan) {
    // OPTIMIZED MI computation:
    // 1. On first call (force_full_scan): Screen all pairs to find candidates
    // 2. On subsequent calls: Only compute for candidates
    // 3. Use linear entropy (no eigendecomp) when purity > 0.9

    int num_pairs = num_qubits * (num_qubits - 1) / 2;
    PackedFloat64Array mi_values;
    mi_values.resize(num_pairs);

    if (num_qubits < 2) {
        return mi_values;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    double* ptr = mi_values.ptrw();

    // Pre-compute single-qubit reduced density matrices (2x2 fixed size)
    std::vector<Eigen::Matrix<std::complex<double>, 2, 2>> single_rhos(num_qubits);
    for (int q = 0; q < num_qubits; q++) {
        single_rhos[q] = partial_trace_single_2x2(rho, q, num_qubits);
    }

    // Decide if we use linear approximation (cheap) or full eigendecomp
    bool use_linear = (biome_purity > PURITY_HIGH_THRESHOLD);

    // If force_full_scan, clear and rebuild candidates
    if (force_full_scan) {
        m_mi_candidates.clear();
    }

    int idx = 0;
    for (int i = 0; i < num_qubits; i++) {
        for (int j = i + 1; j < num_qubits; j++) {
            if (force_full_scan) {
                // SCREENING PHASE: Check if pair is a candidate
                auto rho_ab = partial_trace_pair_4x4(rho, i, j, num_qubits);
                double deviation = screen_product_deviation(rho_ab, single_rhos[i], single_rhos[j]);

                if (deviation < MI_SCREEN_THRESHOLD) {
                    // Not a candidate - MI is negligible
                    ptr[idx] = 0.0;
                    idx++;
                    continue;
                }

                // Mark as candidate
                m_mi_candidates.push_back(idx);

                // Compute MI for this candidate
                if (use_linear) {
                    ptr[idx] = compute_mi_linear(rho_ab, single_rhos[i], single_rhos[j]);
                } else {
                    // Fallback to full eigendecomp
                    double S_a = von_neumann_entropy(single_rhos[i]);
                    double S_b = von_neumann_entropy(single_rhos[j]);
                    double S_ab = von_neumann_entropy(rho_ab);
                    ptr[idx] = std::max(0.0, S_a + S_b - S_ab);
                }
            } else {
                // SUBSEQUENT FRAMES: Only compute for known candidates
                bool is_candidate = std::find(m_mi_candidates.begin(), m_mi_candidates.end(), idx)
                                    != m_mi_candidates.end();

                if (!is_candidate) {
                    ptr[idx] = 0.0;
                    idx++;
                    continue;
                }

                // Compute MI for candidate
                auto rho_ab = partial_trace_pair_4x4(rho, i, j, num_qubits);

                if (use_linear) {
                    ptr[idx] = compute_mi_linear(rho_ab, single_rhos[i], single_rhos[j]);
                } else {
                    double S_a = von_neumann_entropy(single_rhos[i]);
                    double S_b = von_neumann_entropy(single_rhos[j]);
                    double S_ab = von_neumann_entropy(rho_ab);
                    ptr[idx] = std::max(0.0, S_a + S_b - S_ab);
                }
            }
            idx++;
        }
    }

    // Debug: Report candidate count on full scan (disabled - too spammy for main game)
    // if (force_full_scan) {
    //     UtilityFunctions::print(String("[TEST] [MI_ADAPTIVE] q=") + String::num_int64(num_qubits) +
    //         String(" candidates=") + String::num_int64((int64_t)m_mi_candidates.size()) +
    //         String("/") + String::num_int64(num_pairs) +
    //         String(" purity=") + String::num(biome_purity, 3) +
    //         String(" linear=") + (use_linear ? String("Y") : String("N")));
    // }

    return mi_values;
}

Dictionary QuantumEvolutionEngine::evolve_with_mi(
    const PackedFloat64Array& rho_data, float dt, float max_dt, int num_qubits) {
    // Combined evolution + MI computation in single call
    // Avoids multiple GDScript ↔ C++ round trips

    Dictionary result;

    // Evolve the state
    PackedFloat64Array evolved_rho = evolve(rho_data, dt, max_dt);
    result["rho"] = evolved_rho;

    // Compute MI on the evolved state
    PackedFloat64Array mi_values = compute_all_mutual_information(evolved_rho, num_qubits);
    result["mi"] = mi_values;

    // Compute purity and trace on the evolved state
    Eigen::MatrixXcd rho = unpack_dense(evolved_rho);
    result["purity"] = compute_purity(rho);
    std::complex<double> tr = compute_trace(rho);
    result["trace_re"] = tr.real();
    result["trace_im"] = tr.imag();
    result["bloch"] = compute_bloch_metrics(rho, num_qubits);

    return result;
}

double QuantumEvolutionEngine::compute_purity(const Eigen::MatrixXcd& rho) const {
    // Tr(ρ²) / [Tr(ρ)]² — normalized so Euler trace drift doesn't inflate purity.
    // For a valid density matrix with Tr(ρ)=1, this equals Tr(ρ²).
    double trace = 0.0;
    for (int i = 0; i < rho.rows(); i++) {
        trace += rho(i, i).real();
    }
    if (trace < 1e-14) return 0.0;

    double sum_sq = 0.0;
    for (int i = 0; i < rho.rows(); i++) {
        for (int j = 0; j < rho.cols(); j++) {
            sum_sq += std::norm(rho(i, j));
        }
    }
    return sum_sq / (trace * trace);
}

std::complex<double> QuantumEvolutionEngine::compute_trace(const Eigen::MatrixXcd& rho) const {
    std::complex<double> tr(0.0, 0.0);
    int n = std::min(rho.rows(), rho.cols());
    for (int i = 0; i < n; i++) {
        tr += rho(i, i);
    }
    return tr;
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
    // Returns packed [p0,p1,x,y,z,r,theta,phi,r_xy] per qubit (stride=9)
    PackedFloat64Array out;
    if (num_qubits <= 0) {
        return out;
    }
    out.resize(num_qubits * 9);
    double* ptr = out.ptrw();

    for (int q = 0; q < num_qubits; q++) {
        Eigen::MatrixXcd reduced = partial_trace_single(rho, q, num_qubits);
        // reduced is 2x2
        std::complex<double> rho00 = reduced(0, 0);
        std::complex<double> rho11 = reduced(1, 1);
        std::complex<double> rho01 = reduced(0, 1);

        double p0 = rho00.real();
        double p1 = rho11.real();
        double x = 2.0 * rho01.real();
        double y = -2.0 * rho01.imag();
        double z = p0 - p1;

        double r = std::sqrt(x * x + y * y + z * z);
        double r_xy = std::sqrt(x * x + y * y);
        double theta = 0.0;
        double phi = 0.0;
        if (r > 1e-12) {
            double cz = z / r;
            if (cz > 1.0) cz = 1.0;
            if (cz < -1.0) cz = -1.0;
            theta = std::acos(cz);
            phi = std::atan2(y, x);
        }

        int base = q * 9;
        ptr[base + 0] = p0;
        ptr[base + 1] = p1;
        ptr[base + 2] = x;
        ptr[base + 3] = y;
        ptr[base + 4] = z;
        ptr[base + 5] = r;
        ptr[base + 6] = theta;
        ptr[base + 7] = phi;
        ptr[base + 8] = r_xy;
    }

    return out;
}

// ============================================================================
// EIGENSTATE ANALYSIS (CPU-only, Eigen SelfAdjointEigenSolver)
// ============================================================================

Dictionary QuantumEvolutionEngine::compute_eigenstates(const PackedFloat64Array& rho_data) const {
    Dictionary result;

    if (m_dim <= 0) {
        result["error"] = "dimension not set";
        return result;
    }

    // Unpack density matrix
    Eigen::MatrixXcd rho = unpack_dense(rho_data);

    // Density matrices are Hermitian, use SelfAdjointEigenSolver for efficiency
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(rho);

    if (solver.info() != Eigen::Success) {
        result["error"] = "eigenvalue computation failed";
        return result;
    }

    // Eigenvalues are returned in ascending order by Eigen
    Eigen::VectorXd eigenvalues = solver.eigenvalues().real();
    Eigen::MatrixXcd eigenvectors = solver.eigenvectors();

    // Find dominant eigenvalue (largest)
    int dominant_idx = m_dim - 1;  // Last one is largest for SelfAdjoint solver
    double dominant_eigenvalue = eigenvalues(dominant_idx);
    Eigen::VectorXcd dominant_vec = eigenvectors.col(dominant_idx);

    // Pack eigenvalues (descending order for convenience)
    PackedFloat64Array packed_eigenvalues;
    packed_eigenvalues.resize(m_dim);
    double* ev_ptr = packed_eigenvalues.ptrw();
    for (int i = 0; i < m_dim; i++) {
        ev_ptr[i] = eigenvalues(m_dim - 1 - i);  // Reverse to descending
    }

    // Pack dominant eigenvector as [re0, im0, re1, im1, ...]
    PackedFloat64Array packed_dominant;
    packed_dominant.resize(m_dim * 2);
    double* dom_ptr = packed_dominant.ptrw();
    for (int i = 0; i < m_dim; i++) {
        dom_ptr[i * 2] = dominant_vec(i).real();
        dom_ptr[i * 2 + 1] = dominant_vec(i).imag();
    }

    result["eigenvalues"] = packed_eigenvalues;
    result["dominant_eigenvector"] = packed_dominant;
    result["dominant_eigenvalue"] = dominant_eigenvalue;
    result["dimension"] = m_dim;

    return result;
}

PackedFloat64Array QuantumEvolutionEngine::compute_dominant_eigenvector(const PackedFloat64Array& rho_data) const {
    PackedFloat64Array result;

    if (m_dim <= 0) {
        return result;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(rho);

    if (solver.info() != Eigen::Success) {
        return result;
    }

    // Get dominant eigenvector (last column, largest eigenvalue)
    int dominant_idx = m_dim - 1;
    Eigen::VectorXcd dominant_vec = solver.eigenvectors().col(dominant_idx);

    // Pack as [re0, im0, re1, im1, ...]
    result.resize(m_dim * 2);
    double* ptr = result.ptrw();
    for (int i = 0; i < m_dim; i++) {
        ptr[i * 2] = dominant_vec(i).real();
        ptr[i * 2 + 1] = dominant_vec(i).imag();
    }

    return result;
}

PackedFloat64Array QuantumEvolutionEngine::compute_eigenvalues(const PackedFloat64Array& rho_data) const {
    PackedFloat64Array result;

    if (m_dim <= 0) {
        return result;
    }

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(rho);

    if (solver.info() != Eigen::Success) {
        return result;
    }

    // Pack eigenvalues in descending order
    Eigen::VectorXd eigenvalues = solver.eigenvalues().real();
    result.resize(m_dim);
    double* ptr = result.ptrw();
    for (int i = 0; i < m_dim; i++) {
        ptr[i] = eigenvalues(m_dim - 1 - i);  // Descending
    }

    return result;
}

double QuantumEvolutionEngine::compute_cos2_similarity(
    const PackedFloat64Array& state_a, const PackedFloat64Array& state_b) const {
    // cos²(θ) = |⟨ψ_a|ψ_b⟩|² for quantum state overlap
    // States packed as [re0, im0, re1, im1, ...]

    if (state_a.size() != state_b.size() || state_a.is_empty()) {
        return 0.0;
    }

    int dim = state_a.size() / 2;
    const double* ptr_a = state_a.ptr();
    const double* ptr_b = state_b.ptr();

    // Compute complex inner product ⟨a|b⟩ = Σ conj(a_i) * b_i
    std::complex<double> inner_product(0.0, 0.0);
    for (int i = 0; i < dim; i++) {
        std::complex<double> a_i(ptr_a[i * 2], ptr_a[i * 2 + 1]);
        std::complex<double> b_i(ptr_b[i * 2], ptr_b[i * 2 + 1]);
        inner_product += std::conj(a_i) * b_i;
    }

    // |⟨a|b⟩|²
    return std::norm(inner_product);
}

Dictionary QuantumEvolutionEngine::compute_batch_eigenstates(const Dictionary& biome_rhos) const {
    // Compute eigenstates for multiple biomes in a single call
    // Input: {biome_name: rho_packed, ...}
    // Output: {biome_name: {eigenvalues, dominant_eigenvector, dominant_eigenvalue}, ...}

    Dictionary results;
    Array keys = biome_rhos.keys();

    for (int i = 0; i < keys.size(); i++) {
        String biome_name = keys[i];
        Variant rho_var = biome_rhos[biome_name];

        if (rho_var.get_type() != Variant::PACKED_FLOAT64_ARRAY) {
            continue;
        }

        PackedFloat64Array rho_data = rho_var;

        // Temporarily set dimension from data size
        // rho is dim×dim complex, packed as dim*dim*2 floats
        int data_size = rho_data.size();
        int dim_squared_2 = data_size;
        int dim_squared = dim_squared_2 / 2;
        int dim = static_cast<int>(std::sqrt(static_cast<double>(dim_squared)));

        if (dim * dim * 2 != data_size || dim <= 0) {
            Dictionary err;
            err["error"] = "invalid rho dimensions";
            results[biome_name] = err;
            continue;
        }

        // Unpack and compute
        Eigen::MatrixXcd rho(dim, dim);
        const double* ptr = rho_data.ptr();
        for (int r = 0; r < dim; r++) {
            for (int c = 0; c < dim; c++) {
                int idx = (r * dim + c) * 2;
                rho(r, c) = std::complex<double>(ptr[idx], ptr[idx + 1]);
            }
        }

        Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(rho);

        if (solver.info() != Eigen::Success) {
            Dictionary err;
            err["error"] = "eigenvalue computation failed";
            results[biome_name] = err;
            continue;
        }

        Eigen::VectorXd eigenvalues = solver.eigenvalues().real();
        int dominant_idx = dim - 1;
        Eigen::VectorXcd dominant_vec = solver.eigenvectors().col(dominant_idx);

        // Pack results
        PackedFloat64Array packed_eigenvalues;
        packed_eigenvalues.resize(dim);
        double* ev_ptr = packed_eigenvalues.ptrw();
        for (int j = 0; j < dim; j++) {
            ev_ptr[j] = eigenvalues(dim - 1 - j);
        }

        PackedFloat64Array packed_dominant;
        packed_dominant.resize(dim * 2);
        double* dom_ptr = packed_dominant.ptrw();
        for (int j = 0; j < dim; j++) {
            dom_ptr[j * 2] = dominant_vec(j).real();
            dom_ptr[j * 2 + 1] = dominant_vec(j).imag();
        }

        Dictionary biome_result;
        biome_result["eigenvalues"] = packed_eigenvalues;
        biome_result["dominant_eigenvector"] = packed_dominant;
        biome_result["dominant_eigenvalue"] = eigenvalues(dominant_idx);
        biome_result["dimension"] = dim;
        biome_result["purity"] = compute_purity(rho);

        results[biome_name] = biome_result;
    }

    return results;
}

PackedFloat64Array QuantumEvolutionEngine::compute_eigenstate_similarity_matrix(
    const Array& eigenvectors) const {
    // Compute pairwise cos² similarities for an array of eigenvectors
    // Returns upper triangular matrix in packed form: [sim_01, sim_02, ..., sim_12, ...]

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
