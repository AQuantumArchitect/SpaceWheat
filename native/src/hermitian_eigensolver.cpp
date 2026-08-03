#include "hermitian_eigensolver.h"

#include <stdexcept>

namespace spacewheat {

EigenResult HermitianEigensolver::solve(const Eigen::MatrixXcd &h, int max_iterations, double tolerance) {
    if (h.rows() != h.cols()) {
        throw std::invalid_argument("HermitianEigensolver requires square matrix");
    }

    // Eigen's SelfAdjointEigenSolver is a direct (non-iterative) tridiagonal QR
    // solve — it has no iteration budget or convergence tolerance to honour. The
    // parameters survive only because they are part of the published signature.
    (void)max_iterations;
    (void)tolerance;

    Eigen::SelfAdjointEigenSolver<Eigen::MatrixXcd> solver(h);
    EigenResult result;
    result.used_external_backend = true;
    result.eigenvectors_available = true;
    const Eigen::Index n = h.rows();
    result.eigenvalues.resize(static_cast<std::size_t>(n));
    for (Eigen::Index i = 0; i < n; ++i) {
        result.eigenvalues[static_cast<std::size_t>(i)] = solver.eigenvalues()[i];
    }
    result.eigenvectors = solver.eigenvectors();
    return result;
}

} // namespace spacewheat
