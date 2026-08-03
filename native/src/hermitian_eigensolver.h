#pragma once

#include "complex_matrix.h"

#include <vector>

namespace spacewheat {

struct EigenResult {
    std::vector<double> eigenvalues;
    ComplexMatrix eigenvectors; // columns are eigenvectors when backend supports them
    bool used_external_backend = false;
    bool eigenvectors_available = false;
    int iterations = 0;
    double residual = 0.0;
};

class HermitianEigensolver {
public:
    // Eigen's SelfAdjointEigenSolver. max_iterations/tolerance are accepted and
    // ignored — the solve is direct, not iterative.
    //
    // There used to be a second implementation here: a real-symmetric Jacobi
    // rotation gated behind `#if __has_include(<Eigen/Dense>)`, for builds without
    // vendored Eigen. No such build exists — every Makefile, CI job and platform
    // script (linux/windows/macos/web) passes -I./include, and Eigen is vendored
    // and tracked there; several headers in the same translation-unit set include
    // <Eigen/Dense> unconditionally, so the library cannot link without it. The
    // fallback was also wrong on its own terms: it projected H onto its real part
    // (h(r,c).real()) before diagonalizing, silently discarding the imaginary
    // off-diagonals that carry the phase of every genuinely complex Hermitian
    // coupling in this engine. Deleted rather than left as a trap.
    static EigenResult solve(const ComplexMatrix &h, int max_iterations = 128, double tolerance = 1e-10);
};

} // namespace spacewheat
