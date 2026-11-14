// swk/density.hpp - free functions over density matrices.
//
// Moved, not rewritten, from the original engine: floating-point expressions,
// loop order and thresholds are unchanged. Both partial-trace variants are kept
// on purpose (the dynamic ones and the fixed-size 2x2 / 4x4 ones sum in
// different orders, and different callers use different ones).
#ifndef SWK_DENSITY_HPP
#define SWK_DENSITY_HPP

#include "types.hpp"

#include <algorithm>
#include <cmath>
#include <complex>
#include <cstddef>
#include <cstdint>
#include <vector>

namespace swk {

// Packet stride of bloch_metrics: p0,p1,x,y,z,r,theta,phi,r_xy.
inline constexpr int kBlochStride = 9;

// ---------------------------------------------------------------------------
// enforce_density_matrix: Hermitise, clamp negative diagonals (zeroing their
// coherences), renormalise to unit trace, cap coherences so Tr(rho^2) <= 1.
// ---------------------------------------------------------------------------
inline void enforce_density_matrix(CMatrix& rho) {
    const int dim = static_cast<int>(std::min(rho.rows(), rho.cols()));

    // 1. Enforce Hermiticity: rho = (rho + rho^dagger)/2
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

    // 4. Cap coherences so Tr(rho^2) <= 1.
    double diag_sq = 0.0;
    double offdiag_sq = 0.0;
    for (int i = 0; i < dim; i++) {
        double d = rho(i, i).real();
        diag_sq += d * d;
        for (int j = i + 1; j < dim; j++) {
            offdiag_sq += std::norm(rho(i, j));
        }
    }
    double purity = diag_sq + 2.0 * offdiag_sq;
    if (purity > 1.0 && offdiag_sq > 1e-14) {
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

// ---------------------------------------------------------------------------
// Purity and trace.
// ---------------------------------------------------------------------------

// Tr(rho^2) / [Tr(rho)]^2 (trace taken as the real diagonal sum); 0 if trace < 1e-14.
inline double purity(const CMatrix& rho) {
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

inline std::complex<double> trace(const CMatrix& rho) {
    std::complex<double> tr(0.0, 0.0);
    int n = static_cast<int>(std::min(rho.rows(), rho.cols()));
    for (int i = 0; i < n; i++) {
        tr += rho(i, i);
    }
    return tr;
}

// ---------------------------------------------------------------------------
// Partial traces. Qubit q of n lives at bit n-1-q (most significant first).
// ---------------------------------------------------------------------------

// Dynamic variant: reduced 2x2 matrix of `qubit`.
inline CMatrix partial_trace_single(const CMatrix& rho, int qubit, int num_qubits) {
    CMatrix reduced = CMatrix::Zero(2, 2);

    for (int a = 0; a < 2; a++) {
        for (int b = 0; b < 2; b++) {
            std::complex<double> sum(0.0, 0.0);

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

// Dynamic variant: reduced 4x4 matrix of (qubit_a, qubit_b). Basis |00>,|01>,|10>,|11>,
// first digit is qubit_a.
inline CMatrix partial_trace_complement(const CMatrix& rho, int qubit_a, int qubit_b,
                                        int num_qubits) {
    CMatrix reduced = CMatrix::Zero(4, 4);

    bool swapped = (qubit_a > qubit_b);

    for (int row_ab = 0; row_ab < 4; row_ab++) {
        for (int col_ab = 0; col_ab < 4; col_ab++) {
            int a_row = swapped ? (row_ab & 1) : ((row_ab >> 1) & 1);
            int b_row = swapped ? ((row_ab >> 1) & 1) : (row_ab & 1);
            int a_col = swapped ? (col_ab & 1) : ((col_ab >> 1) & 1);
            int b_col = swapped ? ((col_ab >> 1) & 1) : (col_ab & 1);

            std::complex<double> sum(0.0, 0.0);

            int other_qubits = num_qubits - 2;
            for (int other_bits = 0; other_bits < (1 << other_qubits); other_bits++) {
                int row_idx = 0, col_idx = 0;
                int bit_pos = 0;

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

// Fixed-size variant used by the adaptive MI screen.
inline Eigen::Matrix<std::complex<double>, 2, 2> partial_trace_single_2x2(
    const CMatrix& rho, int qubit, int num_qubits) {
    Eigen::Matrix<std::complex<double>, 2, 2> result;
    result.setZero();

    int dim = 1 << num_qubits;
    int qubit_mask = 1 << (num_qubits - 1 - qubit);

    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
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

// Fixed-size variant used by the adaptive MI screen.
inline Eigen::Matrix<std::complex<double>, 4, 4> partial_trace_pair_4x4(
    const CMatrix& rho, int qa, int qb, int num_qubits) {
    Eigen::Matrix<std::complex<double>, 4, 4> result;
    result.setZero();

    int q_lo = std::min(qa, qb);
    int q_hi = std::max(qa, qb);
    bool swapped = (qa > qb);

    int other_qubits = num_qubits - 2;
    int other_dim = 1 << other_qubits;

    for (int row_ab = 0; row_ab < 4; row_ab++) {
        for (int col_ab = 0; col_ab < 4; col_ab++) {
            int a_row = swapped ? (row_ab & 1) : ((row_ab >> 1) & 1);
            int b_row = swapped ? ((row_ab >> 1) & 1) : (row_ab & 1);
            int a_col = swapped ? (col_ab & 1) : ((col_ab >> 1) & 1);
            int b_col = swapped ? ((col_ab >> 1) & 1) : (col_ab & 1);

            std::complex<double> sum(0.0, 0.0);

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

// Alias for the brief's name; identical to partial_trace_pair_4x4.
inline Eigen::Matrix<std::complex<double>, 4, 4> partial_trace_pair(
    const CMatrix& rho, int qa, int qb, int num_qubits) {
    return partial_trace_pair_4x4(rho, qa, qb, num_qubits);
}

// ---------------------------------------------------------------------------
// Entropy and mutual information.
// ---------------------------------------------------------------------------

// S(rho) = -sum lambda log2 lambda (bits), via SelfAdjointEigenSolver.
inline double von_neumann_entropy(const CMatrix& reduced_rho) {
    Eigen::SelfAdjointEigenSolver<CMatrix> solver(reduced_rho);
    Eigen::VectorXd eigenvalues = solver.eigenvalues().real();

    double entropy = 0.0;
    const double eps = 1e-15;
    const double log2_e = 1.0 / std::log(2.0);

    for (int i = 0; i < eigenvalues.size(); i++) {
        double lambda = eigenvalues(i);
        if (lambda > eps) {
            entropy -= lambda * std::log(lambda) * log2_e;
        }
    }

    return std::max(entropy, 0.0);
}

// I(A:B) = S(A) + S(B) - S(AB), uncached (three eigensolves).
inline double mutual_information(const CMatrix& rho, int qubit_a, int qubit_b, int num_qubits) {
    CMatrix rho_a = partial_trace_single(rho, qubit_a, num_qubits);
    CMatrix rho_b = partial_trace_single(rho, qubit_b, num_qubits);
    CMatrix rho_ab = partial_trace_complement(rho, qubit_a, qubit_b, num_qubits);

    double S_a = von_neumann_entropy(rho_a);
    double S_b = von_neumann_entropy(rho_b);
    double S_ab = von_neumann_entropy(rho_ab);

    return std::max(S_a + S_b - S_ab, 0.0);
}

// MI for all pairs in upper-triangular order [01,02,..,0(n-1),12,..], with the
// single-qubit entropies cached. Returns num_qubits*(num_qubits-1)/2 values
// (zeros when num_qubits < 2, or when rho is smaller than 2^num_qubits).
inline std::vector<double> mutual_information_all(const CMatrix& rho, int num_qubits) {
    int num_pairs = num_qubits * (num_qubits - 1) / 2;
    std::vector<double> mi_values(static_cast<std::size_t>(num_pairs > 0 ? num_pairs : 0), 0.0);

    if (num_qubits < 2) {
        return mi_values;
    }
    // Guard against reading outside rho (the original read out of bounds here).
    if (num_qubits >= 31 || rho.rows() < (static_cast<Eigen::Index>(1) << num_qubits) ||
        rho.cols() < (static_cast<Eigen::Index>(1) << num_qubits)) {
        return mi_values;
    }

    std::vector<CMatrix> single_rhos(static_cast<std::size_t>(num_qubits));
    std::vector<double> single_entropies(static_cast<std::size_t>(num_qubits));

    for (int q = 0; q < num_qubits; q++) {
        single_rhos[q] = partial_trace_single(rho, q, num_qubits);
        single_entropies[q] = von_neumann_entropy(single_rhos[q]);
    }

    int idx = 0;
    for (int i = 0; i < num_qubits; i++) {
        for (int j = i + 1; j < num_qubits; j++) {
            CMatrix rho_ab = partial_trace_complement(rho, i, j, num_qubits);
            double S_ab = von_neumann_entropy(rho_ab);

            double mi = single_entropies[i] + single_entropies[j] - S_ab;
            mi_values[idx] = std::max(mi, 0.0);
            idx++;
        }
    }

    return mi_values;
}

// ---------------------------------------------------------------------------
// Adaptive MI helpers and the MiScreen class.
// ---------------------------------------------------------------------------

inline double trace_rho_squared_2x2(const Eigen::Matrix<std::complex<double>, 2, 2>& rho) {
    return std::norm(rho(0, 0)) + 2.0 * std::norm(rho(0, 1)) + std::norm(rho(1, 1));
}

inline double trace_rho_squared_4x4(const Eigen::Matrix<std::complex<double>, 4, 4>& rho) {
    double sum = 0.0;
    for (int i = 0; i < 4; i++) {
        sum += std::norm(rho(i, i));
        for (int j = i + 1; j < 4; j++) {
            sum += 2.0 * std::norm(rho(i, j));
        }
    }
    return sum;
}

// ||rho_AB - rho_A (x) rho_B||_F^2
inline double screen_product_deviation(const Eigen::Matrix<std::complex<double>, 4, 4>& rho_ab,
                                       const Eigen::Matrix<std::complex<double>, 2, 2>& rho_a,
                                       const Eigen::Matrix<std::complex<double>, 2, 2>& rho_b) {
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

// Linear-entropy MI: max(0, 1 - P_A - P_B + P_AB).
inline double mutual_information_linear(const Eigen::Matrix<std::complex<double>, 4, 4>& rho_ab,
                                        const Eigen::Matrix<std::complex<double>, 2, 2>& rho_a,
                                        const Eigen::Matrix<std::complex<double>, 2, 2>& rho_b) {
    double purity_a = trace_rho_squared_2x2(rho_a);
    double purity_b = trace_rho_squared_2x2(rho_b);
    double purity_ab = trace_rho_squared_4x4(rho_ab);

    return std::max(0.0, 1.0 - purity_a - purity_b + purity_ab);
}

// Adaptive MI with a screening pass. The candidate list (indices into the
// upper-triangular pair order) is state that persists between calls.
class MiScreen {
public:
    static constexpr double kScreenThreshold = 0.001;  // product-deviation threshold
    static constexpr double kPurityHigh = 0.9;         // use linear approximation above this

    void clear() { candidates_.clear(); }
    const std::vector<int>& candidates() const { return candidates_; }

    // Returns num_qubits*(num_qubits-1)/2 values (zeros when num_qubits < 2, or
    // when rho is smaller than 2^num_qubits).
    std::vector<double> compute(const CMatrix& rho, int num_qubits, double biome_purity,
                                bool force_full_scan = false) {
        int num_pairs = num_qubits * (num_qubits - 1) / 2;
        std::vector<double> mi_values(static_cast<std::size_t>(num_pairs > 0 ? num_pairs : 0), 0.0);

        if (num_qubits < 2) {
            return mi_values;
        }
        if (num_qubits >= 31 || rho.rows() < (static_cast<Eigen::Index>(1) << num_qubits) ||
        rho.cols() < (static_cast<Eigen::Index>(1) << num_qubits)) {
            return mi_values;
        }

        double* ptr = mi_values.data();

        std::vector<Eigen::Matrix<std::complex<double>, 2, 2>> single_rhos(
            static_cast<std::size_t>(num_qubits));
        for (int q = 0; q < num_qubits; q++) {
            single_rhos[q] = partial_trace_single_2x2(rho, q, num_qubits);
        }

        bool use_linear = (biome_purity > kPurityHigh);

        if (force_full_scan) {
            candidates_.clear();
        }

        int idx = 0;
        for (int i = 0; i < num_qubits; i++) {
            for (int j = i + 1; j < num_qubits; j++) {
                if (force_full_scan) {
                    auto rho_ab = partial_trace_pair_4x4(rho, i, j, num_qubits);
                    double deviation = screen_product_deviation(rho_ab, single_rhos[i], single_rhos[j]);

                    if (deviation < kScreenThreshold) {
                        ptr[idx] = 0.0;
                        idx++;
                        continue;
                    }

                    candidates_.push_back(idx);

                    if (use_linear) {
                        ptr[idx] = mutual_information_linear(rho_ab, single_rhos[i], single_rhos[j]);
                    } else {
                        double S_a = von_neumann_entropy(single_rhos[i]);
                        double S_b = von_neumann_entropy(single_rhos[j]);
                        double S_ab = von_neumann_entropy(rho_ab);
                        ptr[idx] = std::max(0.0, S_a + S_b - S_ab);
                    }
                } else {
                    bool is_candidate =
                        std::find(candidates_.begin(), candidates_.end(), idx) != candidates_.end();

                    if (!is_candidate) {
                        ptr[idx] = 0.0;
                        idx++;
                        continue;
                    }

                    auto rho_ab = partial_trace_pair_4x4(rho, i, j, num_qubits);

                    if (use_linear) {
                        ptr[idx] = mutual_information_linear(rho_ab, single_rhos[i], single_rhos[j]);
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

        return mi_values;
    }

private:
    std::vector<int> candidates_;
};

// ---------------------------------------------------------------------------
// Bloch metrics, stride kBlochStride: [p0,p1,x,y,z,r,theta,phi,r_xy] per qubit.
// Empty when num_qubits <= 0 (or rho is smaller than 2^num_qubits).
// ---------------------------------------------------------------------------
inline std::vector<double> bloch_metrics(const CMatrix& rho, int num_qubits) {
    std::vector<double> out;
    if (num_qubits <= 0) {
        return out;
    }
    if (num_qubits >= 31 || rho.rows() < (static_cast<Eigen::Index>(1) << num_qubits) ||
        rho.cols() < (static_cast<Eigen::Index>(1) << num_qubits)) {
        return out;
    }
    out.assign(static_cast<std::size_t>(num_qubits) * kBlochStride, 0.0);
    double* ptr = out.data();

    for (int q = 0; q < num_qubits; q++) {
        CMatrix reduced = partial_trace_single(rho, q, num_qubits);
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

        int base = q * kBlochStride;
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

// ---------------------------------------------------------------------------
// Eigen analysis of a Hermitian matrix.
// ---------------------------------------------------------------------------
struct EigenResult {
    bool ok = false;                           // false: empty/non-square input or solver failure
    int dimension = 0;
    std::vector<double> eigenvalues;           // descending
    std::vector<double> dominant_eigenvector;  // packed [re0,im0,...]; last column of the ascending solve
    double dominant_eigenvalue = 0.0;
};

inline EigenResult eigen_analysis(const CMatrix& rho) {
    EigenResult res;
    if (rho.rows() <= 0 || rho.rows() != rho.cols()) {
        return res;
    }
    const int dim = static_cast<int>(rho.rows());

    Eigen::SelfAdjointEigenSolver<CMatrix> solver(rho);
    if (solver.info() != Eigen::Success) {
        return res;
    }

    Eigen::VectorXd eigenvalues = solver.eigenvalues().real();
    CMatrix eigenvectors = solver.eigenvectors();

    int dominant_idx = dim - 1;
    res.dominant_eigenvalue = eigenvalues(dominant_idx);
    Eigen::VectorXcd dominant_vec = eigenvectors.col(dominant_idx);

    res.eigenvalues.resize(static_cast<std::size_t>(dim));
    for (int i = 0; i < dim; i++) {
        res.eigenvalues[i] = eigenvalues(dim - 1 - i);
    }

    res.dominant_eigenvector.resize(static_cast<std::size_t>(dim) * 2);
    for (int i = 0; i < dim; i++) {
        res.dominant_eigenvector[i * 2] = dominant_vec(i).real();
        res.dominant_eigenvector[i * 2 + 1] = dominant_vec(i).imag();
    }

    res.dimension = dim;
    res.ok = true;
    return res;
}

// |<a|b>|^2 for two packed state vectors. `count` is the number of doubles in
// each array (2 per amplitude); returns 0.0 when count <= 0.
inline double cos2_similarity(const double* a, const double* b, std::int64_t count) {
    if (count <= 0 || a == nullptr || b == nullptr) {
        return 0.0;
    }

    int dim = static_cast<int>(count / 2);

    std::complex<double> inner_product(0.0, 0.0);
    for (int i = 0; i < dim; i++) {
        std::complex<double> a_i(a[i * 2], a[i * 2 + 1]);
        std::complex<double> b_i(b[i * 2], b[i * 2 + 1]);
        inner_product += std::conj(a_i) * b_i;
    }

    return std::norm(inner_product);
}

}  // namespace swk

#endif  // SWK_DENSITY_HPP
