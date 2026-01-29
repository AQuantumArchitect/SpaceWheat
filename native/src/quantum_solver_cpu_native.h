#ifndef QUANTUM_SOLVER_CPU_NATIVE_H
#define QUANTUM_SOLVER_CPU_NATIVE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include "quantum_solver_cpu.h"

using namespace godot;

/**
 * QuantumSolverCPUNative: Godot wrapper for high-performance CPU quantum solver
 *
 * Exposes C++ QuantumSolverCPU to GDScript with:
 * - Matrix exponential via scaled Pade approximation
 * - Lindblad master equation evolution
 * - SIMD vectorization and cache optimization
 * - Multi-threading for large systems (dim > 256)
 *
 * Performance: ~100-1000x faster than pure GDScript for quantum evolution
 */
class QuantumSolverCPUNative : public RefCounted {
    GDCLASS(QuantumSolverCPUNative, RefCounted);

private:
    QuantumSolverCPU* solver = nullptr;

protected:
    static void _bind_methods();

public:
    QuantumSolverCPUNative();
    ~QuantumSolverCPUNative();

    // ========================================================================
    // INITIALIZATION
    // ========================================================================

    /**
     * Initialize solver for system of given Hilbert space dimension
     * dim = 2^(num_qubits)
     */
    void initialize(int hilbert_dim);

    // ========================================================================
    // SYSTEM SETUP
    // ========================================================================

    /**
     * Set Hamiltonian from packed array
     * Array should be flattened complex matrix: [Re(H_00), Im(H_00), Re(H_01), Im(H_01), ...]
     * Shape: [2 * dim * dim] = [2 * 2^qubits * 2^qubits]
     */
    void set_hamiltonian_flat(const PackedFloat64Array& H_flat);

    /**
     * Add Lindblad dissipation operator
     * L_flat: flattened complex matrix [Re(L_00), Im(L_00), Re(L_01), Im(L_01), ...]
     */
    void add_lindblad_operator(const PackedFloat64Array& L_flat);

    /**
     * Clear all Lindblad operators
     */
    void clear_lindblad_operators();

    // ========================================================================
    // EVOLUTION
    // ========================================================================

    /**
     * Evolve density matrix under full Lindblad equation
     * rho_flat: flattened density matrix
     * dt: timestep
     * Returns: evolved density matrix
     *
     * Performs: ρ' = exp(-i H dt) ρ exp(i H dt) + Σ_k [L_k ρ L_k† - ...]
     */
    PackedFloat64Array evolve(const PackedFloat64Array& rho_flat, double dt);

    /**
     * Coherent evolution only (Hamiltonian)
     * Returns evolved density matrix
     */
    PackedFloat64Array evolve_unitary(const PackedFloat64Array& rho_flat, double dt);

    /**
     * Dissipative evolution only (Lindblad)
     * Returns evolved density matrix
     */
    PackedFloat64Array evolve_lindblad(const PackedFloat64Array& rho_flat, double dt);

    // ========================================================================
    // OBSERVABLES
    // ========================================================================

    /**
     * Compute expectation value <O> = Tr(O ρ)
     * Returns: [Re(<O>), Im(<O>)]
     */
    PackedFloat64Array expectation_value(const PackedFloat64Array& O_flat, const PackedFloat64Array& rho_flat);

    /**
     * Compute purity Tr(ρ²)
     * Returns: [purity] as single float
     */
    double purity(const PackedFloat64Array& rho_flat);

    /**
     * Compute trace Tr(ρ)
     * Returns: [Re(Tr), Im(Tr)]
     */
    PackedFloat64Array trace(const PackedFloat64Array& rho_flat);

    /**
     * Normalize density matrix ρ / Tr(ρ)
     * Returns: normalized density matrix
     */
    PackedFloat64Array normalize(const PackedFloat64Array& rho_flat);

    // ========================================================================
    // PERFORMANCE TUNING
    // ========================================================================

    /**
     * Set Pade approximation order for matrix exponential
     * Higher = more accurate but slower
     * Default: 13 (excellent accuracy, ~13 matrix multiplications)
     * Range: 3-13
     */
    void set_pade_order(int order);

    /**
     * Enable/disable multi-threading for large systems
     * Default: auto (enabled for dim > 256)
     */
    void set_multithreading(bool enabled);

    /**
     * Get performance metrics from last evolution
     * Returns: {
     *   "evolution_time_ms": float,
     *   "matrix_exp_time_ms": float,
     *   "lindblad_time_ms": float,
     *   "hilbert_dim": int
     * }
     */
    Dictionary get_metrics();
};

#endif // QUANTUM_SOLVER_CPU_NATIVE_H
