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
    // Uses Eigen's SelfAdjointEigenSolver when Eigen is available at compile time.
    // Otherwise falls back to a real-symmetric Jacobi solve on Re(H).
    static EigenResult solve(const ComplexMatrix &h, int max_iterations = 128, double tolerance = 1e-10);

private:
    static EigenResult solve_real_jacobi_projection(const ComplexMatrix &h, int max_iterations, double tolerance);
};

} // namespace spacewheat
