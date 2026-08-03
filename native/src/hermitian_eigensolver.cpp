#include "hermitian_eigensolver.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <Eigen/Dense>

namespace spacewheat {

EigenResult HermitianEigensolver::solve(const ComplexMatrix &h, int max_iterations, double tolerance) {
    if (h.rows() != h.cols()) {
        throw std::invalid_argument("HermitianEigensolver requires square matrix");
    }

    // Eigen's SelfAdjointEigenSolver is a direct (non-iterative) tridiagonal QR
    // solve — it has no iteration budget or convergence tolerance to honour. The
    // parameters survive only because they are part of the published signature.
    (void)max_iterations;
    (void)tolerance;

    const int n = static_cast<int>(h.rows());
    Eigen::MatrixXcd m(n, n);
    for (int r = 0; r < n; ++r) {
        for (int c = 0; c < n; ++c) {
            m(r, c) = h(static_cast<std::size_t>(r), static_cast<std::size_t>(c));
        }
    }
    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(m);
    EigenResult result;
    result.used_external_backend = true;
    result.eigenvectors_available = true;
    result.eigenvalues.resize(static_cast<std::size_t>(n));
    for (int i = 0; i < n; ++i) {
        result.eigenvalues[static_cast<std::size_t>(i)] = solver.eigenvalues()[i];
    }
    result.eigenvectors = ComplexMatrix(static_cast<std::size_t>(n), static_cast<std::size_t>(n));
    const Eigen::MatrixXcd vecs = solver.eigenvectors();
    for (int r = 0; r < n; ++r) {
        for (int c = 0; c < n; ++c) {
            result.eigenvectors(static_cast<std::size_t>(r), static_cast<std::size_t>(c)) = vecs(r, c);
        }
    }
    return result;
}

} // namespace spacewheat
