#ifndef QUANTUM_EVOLUTION_ENGINE_H
#define QUANTUM_EVOLUTION_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include "../kernel/include/swk/swk.hpp"
#include <Eigen/Dense>
#include <vector>
#include <complex>

namespace godot {

/**
 * QuantumEvolutionEngine - Godot wrapper over the swk density-matrix kernel.
 *
 * All maths lives in native/kernel (swk::EvolutionEngine, density.hpp). This
 * class only converts between Godot types and Eigen, forwards kernel
 * diagnostics to push_warning / push_error, and keeps the bound API stable.
 * Operators are registered once at setup, then each evolve is one native call.
 */
class QuantumEvolutionEngine : public RefCounted {
    GDCLASS(QuantumEvolutionEngine, RefCounted)

public:
    QuantumEvolutionEngine();
    ~QuantumEvolutionEngine();

    // Setup methods (called once during biome initialization)
    void set_dimension(int dim);
    void set_hamiltonian(const PackedFloat64Array& H_packed);
    void add_lindblad_triplets(const PackedFloat64Array& triplets);
    void clear_operators();
    void set_coherent(bool on);  // gate the -i[H,ρ] term (off = pure Lindbladian)
    void finalize();  // Precompute all cached values

    // Query methods
    int get_dimension() const;
    int get_lindblad_count() const;
    bool is_finalized() const;

    // Evolve ρ forward by dt, capping each internal substep at max_dt. The substep
    // size is otherwise chosen analytically from the purity constraint Tr(ρ'²) ≤ 1,
    // so fast dynamics shrink it and near-steady-state dynamics let it grow to max_dt.
    // This is the ONE integrator — evolve_step() below is this call with max_dt = dt.
    PackedFloat64Array evolve(const PackedFloat64Array& rho_data, float dt, float max_dt);

    // Evolve by dt in a single uncapped interval. Thin alias for evolve(ρ, dt, dt);
    // kept because it is GDExtension-bound. Deliberately NOT a second integrator.
    PackedFloat64Array evolve_step(const PackedFloat64Array& rho_data, float dt);

    // Mutual information computation (piggybacks on evolution)
    // Returns: [mi_01, mi_02, ..., mi_0n, mi_12, mi_13, ..., mi_(n-1)n] for all pairs
    // Format: num_qubits * (num_qubits - 1) / 2 values in upper triangular order
    PackedFloat64Array compute_all_mutual_information(const PackedFloat64Array& rho_data, int num_qubits);

    // OPTIMIZED: Adaptive MI computation with screening and high-purity approximation
    // - First call (force_full_scan=true): Screens ALL pairs to find candidates
    // - Subsequent calls: Only computes MI for candidates
    // - Uses linear entropy approximation when purity > 0.9 (no eigendecomp!)
    PackedFloat64Array compute_mi_adaptive(
        const PackedFloat64Array& rho_data, int num_qubits,
        double biome_purity, bool force_full_scan = false);

    // Clear MI candidates (call when biome state changes significantly)
    void clear_mi_candidates() { m_mi_screen.clear(); }

    // Combined evolution + MI computation (single call for both)
    // Returns Dictionary with "rho" (evolved state), "mi" (mutual information array),
    // "purity" (Tr(rho^2)), "trace_re"/"trace_im" (Tr(rho)),
    // and "bloch" (PackedFloat64Array of [p0,p1,x,y,z,r,theta,phi,r_xy] per qubit (stride 9))
    Dictionary evolve_with_mi(const PackedFloat64Array& rho_data, float dt, float max_dt, int num_qubits);

    // Basic observables
    double compute_purity(const Eigen::MatrixXcd& rho) const;
    std::complex<double> compute_trace(const Eigen::MatrixXcd& rho) const;
    PackedFloat64Array compute_bloch_metrics(const Eigen::MatrixXcd& rho, int num_qubits) const;
    double compute_purity_from_packed(const PackedFloat64Array& rho_data) const;
    PackedFloat64Array compute_bloch_metrics_from_packed(const PackedFloat64Array& rho_data, int num_qubits) const;
    // Eigenstate analysis (CPU-only, uses Eigen)
    // Returns Dictionary with "eigenvalues", "dominant_eigenvector", "dominant_eigenvalue"
    Dictionary compute_eigenstates(const PackedFloat64Array& rho_data) const;

    // Returns just the dominant eigenvector (largest eigenvalue) as PackedFloat64Array [re0, im0, re1, im1, ...]
    PackedFloat64Array compute_dominant_eigenvector(const PackedFloat64Array& rho_data) const;

    // Returns all eigenvalues sorted descending as PackedFloat64Array
    PackedFloat64Array compute_eigenvalues(const PackedFloat64Array& rho_data) const;

    // Compute cos²(θ) = |⟨ψ₁|ψ₂⟩|² similarity between two state vectors
    // state_a and state_b are packed as [re0, im0, re1, im1, ...]
    double compute_cos2_similarity(const PackedFloat64Array& state_a, const PackedFloat64Array& state_b) const;

    // Batch eigenstate analysis: returns Dictionary with biome_name -> eigenstate data
    // Input: Dictionary of biome_name -> rho_packed
    Dictionary compute_batch_eigenstates(const Dictionary& biome_rhos) const;

    // Compute pairwise cos² similarity matrix for multiple eigenstates
    // Input: Array of PackedFloat64Array eigenvectors
    // Returns: PackedFloat64Array in upper triangular order [sim_01, sim_02, ..., sim_12, ...]
    PackedFloat64Array compute_eigenstate_similarity_matrix(const Array& eigenvectors) const;

    // Integrator substeps spent inside the last evolve(). A diagnostic, not a control:
    // task #528 (an endgame biome quietly taking ~170 substeps per phrame) was invisible
    // for months because nothing counted the loop. Now the cost is observable.
    int get_last_substep_count() const;

protected:
    static void _bind_methods();

private:
    swk::EvolutionEngine m_engine;
    swk::MiScreen m_mi_screen;       // adaptive-MI candidate list
    swk::DiagnosticSink m_sink;      // forwards kernel diagnostics to Godot

    Eigen::MatrixXcd unpack_dense(const PackedFloat64Array& data) const;
    PackedFloat64Array pack_dense(const Eigen::MatrixXcd& mat) const;
};

}  // namespace godot

#endif  // QUANTUM_EVOLUTION_ENGINE_H
