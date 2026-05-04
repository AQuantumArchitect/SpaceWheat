#include "hermitian_eigensolver.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>

#if defined(__has_include)
#  if __has_include(<Eigen/Dense>)
#    define SPACEWHEAT_HAS_EIGEN 1
#    include <Eigen/Dense>
#  endif
#endif

namespace spacewheat {

EigenResult HermitianEigensolver::solve(const ComplexMatrix &h, int max_iterations, double tolerance) {
    if (h.rows() != h.cols()) {
        throw std::invalid_argument("HermitianEigensolver requires square matrix");
    }

#if defined(SPACEWHEAT_HAS_EIGEN)
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
#else
    return solve_real_jacobi_projection(h, max_iterations, tolerance);
#endif
}

EigenResult HermitianEigensolver::solve_real_jacobi_projection(const ComplexMatrix &h, int max_iterations, double tolerance) {
    const std::size_t n = h.rows();
    std::vector<double> a(n * n, 0.0);
    std::vector<double> v(n * n, 0.0);

    for (std::size_t r = 0; r < n; ++r) {
        for (std::size_t c = 0; c < n; ++c) {
            a[r * n + c] = h(r, c).real();
        }
        v[r * n + r] = 1.0;
    }

    int iterations = 0;
    for (; iterations < max_iterations; ++iterations) {
        std::size_t p = 0;
        std::size_t q = 1;
        double max_offdiag = 0.0;
        for (std::size_t i = 0; i < n; ++i) {
            for (std::size_t j = i + 1; j < n; ++j) {
                const double value = std::abs(a[i * n + j]);
                if (value > max_offdiag) {
                    max_offdiag = value;
                    p = i;
                    q = j;
                }
            }
        }
        if (max_offdiag < tolerance || n < 2) {
            break;
        }

        const double app = a[p * n + p];
        const double aqq = a[q * n + q];
        const double apq = a[p * n + q];
        const double tau = (aqq - app) / (2.0 * apq);
        const double t = (tau >= 0.0 ? 1.0 : -1.0) / (std::abs(tau) + std::sqrt(1.0 + tau * tau));
        const double c = 1.0 / std::sqrt(1.0 + t * t);
        const double s = t * c;

        for (std::size_t k = 0; k < n; ++k) {
            if (k != p && k != q) {
                const double aik = a[k * n + p];
                const double akq = a[k * n + q];
                a[k * n + p] = c * aik - s * akq;
                a[p * n + k] = a[k * n + p];
                a[k * n + q] = s * aik + c * akq;
                a[q * n + k] = a[k * n + q];
            }
        }

        a[p * n + p] = c * c * app - 2.0 * s * c * apq + s * s * aqq;
        a[q * n + q] = s * s * app + 2.0 * s * c * apq + c * c * aqq;
        a[p * n + q] = 0.0;
        a[q * n + p] = 0.0;

        for (std::size_t k = 0; k < n; ++k) {
            const double vip = v[k * n + p];
            const double viq = v[k * n + q];
            v[k * n + p] = c * vip - s * viq;
            v[k * n + q] = s * vip + c * viq;
        }
    }

    EigenResult result;
    result.used_external_backend = false;
    result.eigenvectors_available = true;
    result.iterations = iterations;
    result.eigenvalues.resize(n);
    result.eigenvectors = ComplexMatrix(n, n);
    for (std::size_t i = 0; i < n; ++i) {
        result.eigenvalues[i] = a[i * n + i];
    }
    for (std::size_t r = 0; r < n; ++r) {
        for (std::size_t c = 0; c < n; ++c) {
            result.eigenvectors(r, c) = Complex(v[r * n + c], 0.0);
        }
    }

    double residual = 0.0;
    for (std::size_t i = 0; i < n; ++i) {
        for (std::size_t j = i + 1; j < n; ++j) {
            residual = std::max(residual, std::abs(a[i * n + j]));
        }
    }
    result.residual = residual;
    return result;
}

} // namespace spacewheat
