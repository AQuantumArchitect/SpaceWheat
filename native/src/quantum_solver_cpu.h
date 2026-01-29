#ifndef QUANTUM_SOLVER_CPU_H
#define QUANTUM_SOLVER_CPU_H

#include <Eigen/Dense>
#include <Eigen/Sparse>
#include <vector>
#include <complex>

using Eigen::MatrixXcd;
using Eigen::VectorXcd;
using Eigen::SparseMatrix;

typedef std::complex<double> Complex;

/**
 * QuantumSolverCPU: High-performance quantum evolution solver
 *
 * Optimizations:
 * - SIMD vectorization (Eigen auto-detects AVX2/SSE4)
 * - Cache-friendly memory layout (column-major)
 * - Efficient matrix exponential (scaled Pade approximation)
 * - Inline hot-loop operations
 * - Optional multi-threading for large systems
 */
class QuantumSolverCPU {
public:
    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    QuantumSolverCPU(int hilbert_dim);
    ~QuantumSolverCPU() = default;

    /**
     * Set system Hamiltonian for coherent evolution
     * H is copied, stored column-major for cache efficiency
     */
    void set_hamiltonian(const MatrixXcd& H);

    /**
     * Add a Lindblad (dissipation/decoherence) operator
     * Stores: L, L†L for efficient computation
     * Total superoperator: D[ρ] = L ρ L† - (L†L ρ + ρ L†L) / 2
     */
    void add_lindblad_operator(const MatrixXcd& L);

    /**
     * Clear all Lindblad operators
     */
    void clear_lindblad_operators();

    // ========================================================================
    // EVOLUTION
    // ========================================================================

    /**
     * Evolve density matrix under Lindblad master equation
     * ρ' = U(t) ρ U†(t) + dissipation terms
     *
     * Uses:
     * - Scaled Pade approximation for matrix exponential
     * - Krylov subspace methods for large sparse systems (future)
     * - RK45 adaptive stepping (future)
     */
    void evolve(MatrixXcd& rho, double dt);

    /**
     * Coherent evolution only (Hamiltonian part)
     * ρ' = exp(-i H t) ρ exp(i H t)
     * Faster than full Lindblad when no dissipation
     */
    void evolve_unitary(MatrixXcd& rho, double dt);

    /**
     * Dissipative evolution only (Lindblad part)
     * ρ' = Σ_k [L_k ρ L_k† - (L_k† L_k ρ + ρ L_k† L_k) / 2]
     */
    void evolve_lindblad(MatrixXcd& rho, double dt);

    // ========================================================================
    // OBSERVABLES
    // ========================================================================

    /**
     * Compute expectation value <O> = Tr(O ρ)
     * Optimized: avoids full matrix multiplication
     */
    Complex expectation_value(const MatrixXcd& O, const MatrixXcd& rho);

    /**
     * Compute purity Tr(ρ²)
     */
    double purity(const MatrixXcd& rho);

    /**
     * Compute trace (should be ~1.0 for valid state)
     */
    Complex trace(const MatrixXcd& rho);

    /**
     * Normalize density matrix: ρ / Tr(ρ)
     */
    void normalize(MatrixXcd& rho);

    // ========================================================================
    // PERFORMANCE TUNING
    // ========================================================================

    /**
     * Set number of Pade approximation terms (higher = more accurate)
     * Default: 13 (excellent accuracy, minimal overhead)
     * Range: 3-20
     */
    void set_pade_order(int order);

    /**
     * Enable/disable multi-threading for large systems (dim > 256)
     * Default: enabled
     */
    void set_multithreading(bool enabled);

    /**
     * Get performance metrics
     */
    struct Metrics {
        double evolution_time_ms = 0.0;
        double matrix_exp_time_ms = 0.0;
        double lindblad_time_ms = 0.0;
        int pade_iterations = 0;
        int hilbert_dim = 0;
    };

    const Metrics& get_metrics() const { return metrics; }

private:
    // ========================================================================
    // PRIVATE IMPLEMENTATION
    // ========================================================================

    int hilbert_dim;
    MatrixXcd H;  // Hamiltonian
    std::vector<MatrixXcd> L_ops;    // Lindblad operators
    std::vector<MatrixXcd> LdL_ops;  // L† L for each operator

    int pade_order = 13;
    bool use_threading = true;
    Metrics metrics;

    // Matrix exponential via scaled Pade approximation
    // Computes exp(A) = U / (U - V) where:
    // U = I + (2^s / (2m)!) * A^(2m) * ...
    // V = I - (2^s / (2m)!) * A^(2m) * ...
    // Result: exp(A) = (result / 2^s)^(2^s)
    MatrixXcd matrix_exponential(const MatrixXcd& A);

    // Compute log_2(ceil(||A||_inf / theta))
    // Used for scaling in Pade approximation
    int compute_matrix_norm_scale(const MatrixXcd& A, double theta);

    // Power iteration for computing single matrix power efficiently
    MatrixXcd matrix_power_squared(const MatrixXcd& A, const MatrixXcd& A2);

    // In-place squaring: A := A * A
    void matrix_square_inplace(MatrixXcd& A);
};

#endif // QUANTUM_SOLVER_CPU_H
