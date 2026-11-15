// swk/evolution.hpp - the Lindblad / unitary evolution engine.
//
// Moved, not rewritten. Quirks preserved on purpose:
//  - last_substep_count() is NOT reset by the exact-unitary path; it IS reset to
//    0 at the start of the RK4 path.
//  - the propagator cache is keyed on exact dt equality.
//  - add_lindblad_triplets installs the operator even when some entries were
//    dropped as out of range (the status reports the drop).
#ifndef SWK_EVOLUTION_HPP
#define SWK_EVOLUTION_HPP

#include "density.hpp"
#include "types.hpp"

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <utility>
#include <vector>

namespace swk {

class EvolutionEngine {
public:
    // Bound on ||h * drho/dt|| / ||rho|| per substep (an accuracy criterion).
    static constexpr double REL_CHANGE_PER_SUBSTEP = 0.1;
    // Hard ceiling on RK4 substeps per evolve() call.
    static constexpr int MAX_SUBSTEPS = 16;

    EvolutionEngine() = default;

    // Default sink discards everything.
    void set_diagnostic_sink(DiagnosticSink sink) { sink_ = std::move(sink); }

    void set_dimension(int dim) {
        dim_ = dim;
        finalized_ = false;
        eig_valid_ = false;
        U_valid_ = false;
    }

    // Gate the -i[H,rho] term (off = pure Lindbladian). Does not touch H or its eigendecomposition.
    void set_coherent(bool on) { coherent_ = on; }

    // 2*dim*dim doubles, row-major interleaved re/im. Entries with |re|,|im| <= 1e-15 are dropped.
    Status set_hamiltonian_packed(const double* data, std::int64_t count) {
        if (dim_ == 0) {
            detail::emit(&sink_, Severity::Warning, "QuantumEvolutionEngine: set_dimension first!");
            return Status::DimensionNotSet;
        }

        const std::int64_t expected = static_cast<std::int64_t>(2) * dim_ * dim_;
        if (count != expected || data == nullptr) {
            detail::emit(&sink_, Severity::Error,
                         "QuantumEvolutionEngine::set_hamiltonian: H size mismatch (got " +
                             detail::num(count) + ", expected " + detail::num(expected) + " for dim " +
                             std::to_string(dim_) + ") " + detail::em_dash() + " H not installed.");
            return Status::SizeMismatch;
        }

        const double* ptr = data;
        const double threshold = 1e-15;

        std::vector<Eigen::Triplet<std::complex<double>>> triplets;
        triplets.reserve(static_cast<std::size_t>(dim_) * 4);

        for (int i = 0; i < dim_; i++) {
            for (int j = 0; j < dim_; j++) {
                int idx = (i * dim_ + j) * 2;
                double re = ptr[idx];
                double im = ptr[idx + 1];

                if (std::abs(re) > threshold || std::abs(im) > threshold) {
                    triplets.emplace_back(i, j, std::complex<double>(re, im));
                }
            }
        }

        hamiltonian_.resize(dim_, dim_);
        hamiltonian_.setFromTriplets(triplets.begin(), triplets.end());
        hamiltonian_.makeCompressed();

        has_hamiltonian_ = true;
        finalized_ = false;
        eig_valid_ = false;
        U_valid_ = false;
        return Status::Ok;
    }

    // Triplets [row, col, re, im, ...]; count is the number of doubles. Out-of-range entries
    // are dropped with an Error diagnostic (and the call returns IndexOutOfRange), but the
    // operator is still installed from the remaining entries, as the original did.
    Status add_lindblad_triplets(const double* data, std::int64_t count) {
        if (dim_ == 0) {
            detail::emit(&sink_, Severity::Warning, "QuantumEvolutionEngine: set_dimension first!");
            return Status::DimensionNotSet;
        }

        Status status = Status::Ok;
        int num_entries = static_cast<int>(count / 4);
        std::vector<Eigen::Triplet<std::complex<double>>> eigen_triplets;
        eigen_triplets.reserve(static_cast<std::size_t>(num_entries > 0 ? num_entries : 0));

        const double* ptr = data;
        for (int i = 0; i < num_entries; i++) {
            int row = static_cast<int>(ptr[i * 4]);
            int col = static_cast<int>(ptr[i * 4 + 1]);
            double re = ptr[i * 4 + 2];
            double im = ptr[i * 4 + 3];

            if (row < 0 || row >= dim_ || col < 0 || col >= dim_) {
                detail::emit(&sink_, Severity::Error,
                             "QuantumEvolutionEngine::add_lindblad_triplets: index (" +
                                 std::to_string(row) + "," + std::to_string(col) +
                                 ") out of range for dim " + std::to_string(dim_) + " " +
                                 detail::em_dash() + " entry dropped.");
                status = Status::IndexOutOfRange;
                continue;
            }

            if (std::abs(re) > 1e-15 || std::abs(im) > 1e-15) {
                eigen_triplets.emplace_back(row, col, std::complex<double>(re, im));
            }
        }

        SparseC L(dim_, dim_);
        L.setFromTriplets(eigen_triplets.begin(), eigen_triplets.end());
        L.makeCompressed();

        lindblads_.push_back(L);
        finalized_ = false;
        return status;
    }

    // Drops all operators. Does not change the dimension.
    void clear_operators() {
        lindblads_.clear();
        lindblad_dags_.clear();
        LdagLs_.clear();
        hamiltonian_.resize(0, 0);
        has_hamiltonian_ = false;
        finalized_ = false;
        eig_valid_ = false;
        U_valid_ = false;
    }

    // Precompute L^dagger, L^dagger L, and the eigendecomposition of H.
    void finalize() {
        lindblad_dags_.clear();
        LdagLs_.clear();

        lindblad_dags_.reserve(lindblads_.size());
        LdagLs_.reserve(lindblads_.size());

        for (const auto& L : lindblads_) {
            SparseC L_dag = L.adjoint();
            lindblad_dags_.push_back(L_dag);

            SparseC LdagL = L_dag * L;
            LdagL.makeCompressed();
            LdagLs_.push_back(LdagL);
        }

        // H = V Lambda V^dagger, powering the exact propagator U = exp(-iH dt).
        eig_valid_ = false;
        U_valid_ = false;
        if (has_hamiltonian_ && dim_ > 0) {
            CMatrix H_dense(hamiltonian_);
            H_dense = 0.5 * (H_dense + H_dense.adjoint());  // symmetrize for numerical safety
            Eigen::SelfAdjointEigenSolver<CMatrix> es(H_dense);
            if (es.info() == Eigen::Success) {
                eig_vecs_ = es.eigenvectors();
                eig_vals_ = es.eigenvalues();
                eig_valid_ = true;
            }
        }

        finalized_ = true;
    }

    int dimension() const { return dim_; }
    int lindblad_count() const { return static_cast<int>(lindblads_.size()); }
    bool is_finalized() const { return finalized_; }
    bool has_hamiltonian() const { return has_hamiltonian_; }
    bool coherent() const { return coherent_; }

    // Integrator substeps spent inside the last RK4 evolve(). Not touched by the unitary path.
    int last_substep_count() const { return last_substeps_; }

    // Evolve rho (dim x dim) forward by dt, capping each substep at max_dt (max_dt <= 0 means dt).
    // In place. NotFinalized (with a warning) if finalize() has not been called since the last
    // change; SizeMismatch (with a warning) if rho is not dim x dim. On either, rho is untouched.
    Status evolve(CMatrix& rho, double dt, double max_dt) {
        if (!finalized_) {
            detail::emit(&sink_, Severity::Warning, "QuantumEvolutionEngine: call finalize() first!");
            return Status::NotFinalized;
        }

        if (rho.rows() != dim_ || rho.cols() != dim_) {
            const std::int64_t got = static_cast<std::int64_t>(2) * rho.rows() * rho.cols();
            const std::int64_t expected = static_cast<std::int64_t>(2) * dim_ * dim_;
            detail::emit(&sink_, Severity::Warning,
                         std::string("QuantumEvolutionEngine::evolve: ") + detail::rho_glyph() +
                             " size mismatch (got " + detail::num(got) + ", expected " +
                             detail::num(expected) + " for dim " + std::to_string(dim_) + ") " +
                             detail::em_dash() + " returning unchanged.");
            return Status::SizeMismatch;
        }

        // EXACT UNITARY PATH (coherent, no dissipation): rho -> U rho U^dagger over the whole dt.
        if (can_unitary()) {
            CMatrix rho_u = rho;
            const CMatrix& U = propagator_for(dt);
            rho_u = U * rho_u * U.adjoint();
            rho = rho_u;
            return Status::Ok;
        }

        const double max_step = (max_dt > 0.0) ? max_dt : dt;

        CMatrix rho_w = rho;
        double remaining = dt;
        last_substeps_ = 0;

        const double floor_step = dt / static_cast<double>(MAX_SUBSTEPS);

        while (remaining > 1e-12) {
            CMatrix k1 = liouvillian(rho_w);

            double rate = k1.norm();
            double scale = std::max(rho_w.norm(), 1e-9);
            double h = max_step;
            if (rate > 1e-14) {
                h = REL_CHANGE_PER_SUBSTEP * scale / rate;
            }
            h = std::min({h, max_step, remaining});
            h = std::max(h, std::min(floor_step, remaining));

            CMatrix k2 = liouvillian(rho_w + (h * 0.5) * k1);
            CMatrix k3 = liouvillian(rho_w + (h * 0.5) * k2);
            CMatrix k4 = liouvillian(rho_w + h * k3);
            rho_w += (h / 6.0) * (k1 + 2.0 * k2 + 2.0 * k3 + k4);

            enforce_density_matrix(rho_w);
            remaining -= h;
            last_substeps_++;
        }

        rho = rho_w;
        return Status::Ok;
    }

private:
    // drho/dt = -i[H,rho] + sum_k ( L rho L^dagger - 1/2 {L^dagger L, rho} ).
    CMatrix liouvillian(const CMatrix& rho) const {
        CMatrix drho = CMatrix::Zero(dim_, dim_);

        if (coherent_ && has_hamiltonian_) {
            drho += std::complex<double>(0.0, -1.0) * (hamiltonian_ * rho - rho * hamiltonian_);
        }

        for (std::size_t k = 0; k < lindblads_.size(); k++) {
            const auto& L = lindblads_[k];
            const auto& L_dag = lindblad_dags_[k];
            const auto& LdagL = LdagLs_[k];
            drho += L * rho * L_dag - 0.5 * (LdagL * rho + rho * LdagL);
        }

        return drho;
    }

    bool can_unitary() const {
        return coherent_ && has_hamiltonian_ && eig_valid_ && lindblads_.empty();
    }

    // U = V * diag(e^{-i lambda dt}) * V^dagger, cached on exact dt equality.
    const CMatrix& propagator_for(double dt) {
        if (U_valid_ && U_dt_ == dt) {
            return U_;
        }
        Eigen::VectorXcd phase(dim_);
        for (int k = 0; k < dim_; k++) {
            double a = -eig_vals_(k) * dt;
            phase(k) = std::complex<double>(std::cos(a), std::sin(a));
        }
        U_ = eig_vecs_ * phase.asDiagonal() * eig_vecs_.adjoint();
        U_dt_ = dt;
        U_valid_ = true;
        return U_;
    }

    int dim_ = 0;
    bool finalized_ = false;

    SparseC hamiltonian_;
    bool has_hamiltonian_ = false;
    bool coherent_ = true;

    CMatrix eig_vecs_;
    Eigen::VectorXd eig_vals_;
    bool eig_valid_ = false;
    CMatrix U_;
    double U_dt_ = -1.0;
    bool U_valid_ = false;

    std::vector<SparseC> lindblads_;
    std::vector<SparseC> lindblad_dags_;
    std::vector<SparseC> LdagLs_;

    int last_substeps_ = 0;

    DiagnosticSink sink_;
};

}  // namespace swk

#endif  // SWK_EVOLUTION_HPP
