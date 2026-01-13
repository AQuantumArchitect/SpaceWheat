#include "quantum_evolution_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <cmath>

using namespace godot;

void QuantumEvolutionEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("set_dimension", "dim"),
                         &QuantumEvolutionEngine::set_dimension);
    ClassDB::bind_method(D_METHOD("set_hamiltonian", "H_packed"),
                         &QuantumEvolutionEngine::set_hamiltonian);
    ClassDB::bind_method(D_METHOD("add_lindblad_triplets", "triplets"),
                         &QuantumEvolutionEngine::add_lindblad_triplets);
    ClassDB::bind_method(D_METHOD("clear_operators"),
                         &QuantumEvolutionEngine::clear_operators);
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
}

QuantumEvolutionEngine::QuantumEvolutionEngine()
    : m_dim(0), m_finalized(false), m_has_hamiltonian(false) {}

QuantumEvolutionEngine::~QuantumEvolutionEngine() {}

void QuantumEvolutionEngine::set_dimension(int dim) {
    m_dim = dim;
    m_finalized = false;
}

void QuantumEvolutionEngine::set_hamiltonian(const PackedFloat64Array& H_packed) {
    if (m_dim == 0) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: set_dimension first!");
        return;
    }

    m_hamiltonian = unpack_dense(H_packed);
    m_has_hamiltonian = true;
    m_finalized = false;
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

    m_finalized = true;
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

    Eigen::MatrixXcd rho = unpack_dense(rho_data);
    Eigen::MatrixXcd drho = Eigen::MatrixXcd::Zero(m_dim, m_dim);

    // =========================================================================
    // Term 1: Hamiltonian evolution -i[H, ρ]
    // =========================================================================
    if (m_has_hamiltonian) {
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

    return pack_dense(rho);
}

PackedFloat64Array QuantumEvolutionEngine::evolve(const PackedFloat64Array& rho_data, float dt, float max_dt) {
    if (!m_finalized) {
        UtilityFunctions::push_warning("QuantumEvolutionEngine: call finalize() first!");
        return rho_data;
    }

    // Subcycling for numerical stability
    if (dt <= max_dt) {
        return evolve_step(rho_data, dt);
    }

    // Multiple steps needed
    int num_steps = static_cast<int>(std::ceil(dt / max_dt));
    float sub_dt = dt / num_steps;

    // Unpack once, evolve multiple times, pack once
    Eigen::MatrixXcd rho = unpack_dense(rho_data);

    for (int step = 0; step < num_steps; step++) {
        Eigen::MatrixXcd drho = Eigen::MatrixXcd::Zero(m_dim, m_dim);

        // Term 1: Hamiltonian
        if (m_has_hamiltonian) {
            Eigen::MatrixXcd commutator = m_hamiltonian * rho - rho * m_hamiltonian;
            drho += std::complex<double>(0.0, -1.0) * commutator;
        }

        // Term 2: Lindblad
        for (size_t k = 0; k < m_lindblads.size(); k++) {
            const auto& L = m_lindblads[k];
            const auto& L_dag = m_lindblad_dags[k];
            const auto& LdagL = m_LdagLs[k];

            Eigen::MatrixXcd L_rho_Ldag = (L * rho) * L_dag;
            Eigen::MatrixXcd anticomm = LdagL * rho + rho * LdagL;
            drho += L_rho_Ldag - 0.5 * anticomm;
        }

        // Euler step
        rho += static_cast<double>(sub_dt) * drho;
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
