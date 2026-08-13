#ifndef QUANTUM_EVOLUTION_ENGINE_H
#define QUANTUM_EVOLUTION_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <Eigen/Dense>
#include <Eigen/Sparse>
#include <vector>
#include <complex>

namespace godot {

/**
 * QuantumEvolutionEngine - Batched native quantum evolution
 *
 * Solves the performance problem of GDScript ↔ C++ bridge overhead by:
 * 1. Registering all operators ONCE at setup time
 * 2. Precomputing L†, L†L for each Lindblad operator
 * 3. Doing complete evolution step in single native call
 *
 * Expected speedup: 10-20× for typical biomes (Forest: 130ms → 7ms)
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
    void clear_mi_candidates() { m_mi_candidates.clear(); }

    // Combined evolution + MI computation (single call for both)
    // Returns Dictionary with "rho" (evolved state), "mi" (mutual information array),
    // "purity" (Tr(rho^2)), "trace_re"/"trace_im" (Tr(rho)),
    // and "bloch" (PackedFloat64Array of [p0,p1,x,y,z,r,theta,phi] per qubit)
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
    int m_dim;
    bool m_finalized;
    int m_num_qubits;  // Cached for MI computation

    // Sparse Hamiltonian (optional) - exploits ~99% sparsity in quantum coupling matrices
    Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor> m_hamiltonian;
    bool m_has_hamiltonian;

    // Coherent generator switch. When false the -i[H,ρ] term is skipped (pure Lindbladian).
    bool m_coherent;

    // EXACT UNITARY PROPAGATOR (coherent + no dissipation): U = exp(-iH·dt) built from the
    // eigendecomposition of the Hermitian H, H = VΛV† ⇒ U = V·diag(e^{-iλdt})·V†. This is
    // purity-exact (r=1 by construction) — no Euler integration, no enforce_density_matrix.
    Eigen::MatrixXcd m_eig_vecs;  // V (columns = eigenvectors of H)
    Eigen::VectorXd  m_eig_vals;  // λ (real eigenvalues of H)
    bool m_eig_valid;
    Eigen::MatrixXcd m_U;         // cached propagator for m_U_dt
    double m_U_dt;
    bool m_U_valid;

    // Sparse Lindblad operators
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_lindblads;

    // Cached values for efficiency
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_lindblad_dags;  // L†
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_LdagLs;        // L†L

    // Pre-allocated scratch buffers for evolution (avoid per-frame allocation)
    Eigen::MatrixXcd m_drho_buffer;      // Scratch for drho computation
    Eigen::MatrixXcd m_temp_buffer;      // Scratch for intermediate results

    // Adaptive MI optimization
    std::vector<int> m_mi_candidates;    // Pair indices with significant MI
    static constexpr double MI_SCREEN_THRESHOLD = 0.001;   // Product deviation threshold
    static constexpr double PURITY_HIGH_THRESHOLD = 0.9;   // Use linear approx above this

    // === Integrator (see evolve()) ==========================================
    // Bound on ||h·dρ/dt|| / ||ρ|| per substep — an accuracy criterion. Measured
    // against a 20k-step reference at dim 32: 0.1 costs ONE RK4 substep for a
    // 0.1s phrame at both Tr(ρ²)=0.5 and Tr(ρ²)=0.999, with max|Δρ| ≈ 1e-7.
    static constexpr double REL_CHANGE_PER_SUBSTEP = 0.1;

    // Hard ceiling on substeps per evolve() call. This is the guarantee that one
    // phrame costs bounded work no matter what state the player builds — the old
    // 1e-6s step floor allowed 100k substeps for the same phrame.
    static constexpr int MAX_SUBSTEPS = 16;

    int m_last_substeps = 0;

    // Helper methods
    Eigen::MatrixXcd unpack_dense(const PackedFloat64Array& data) const;
    PackedFloat64Array pack_dense(const Eigen::MatrixXcd& mat) const;

    // dρ/dt = -i[H,ρ] + Σ_k D[L_k](ρ) — the single generator, evaluated at each RK4 stage.
    Eigen::MatrixXcd liouvillian(const Eigen::MatrixXcd& rho) const;

    // Exact-unitary path: eligible when coherent, has H, eigendecomposition valid, no Lindblad.
    bool can_unitary() const;
    const Eigen::MatrixXcd& propagator_for(double dt);  // builds/caches U = exp(-iH·dt)

    // MI computation helpers (original)
    Eigen::MatrixXcd partial_trace_single(const Eigen::MatrixXcd& rho, int qubit, int num_qubits) const;
    Eigen::MatrixXcd partial_trace_complement(const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const;
    double von_neumann_entropy(const Eigen::MatrixXcd& reduced_rho) const;
    double mutual_information(const Eigen::MatrixXcd& rho, int qubit_a, int qubit_b, int num_qubits) const;

    // Adaptive MI helpers (new - optimized)
    double screen_product_deviation(
        const Eigen::Matrix<std::complex<double>, 4, 4>& rho_ab,
        const Eigen::Matrix<std::complex<double>, 2, 2>& rho_a,
        const Eigen::Matrix<std::complex<double>, 2, 2>& rho_b) const;
    double compute_mi_linear(
        const Eigen::Matrix<std::complex<double>, 4, 4>& rho_ab,
        const Eigen::Matrix<std::complex<double>, 2, 2>& rho_a,
        const Eigen::Matrix<std::complex<double>, 2, 2>& rho_b) const;
    double trace_rho_squared_2x2(const Eigen::Matrix<std::complex<double>, 2, 2>& rho) const;
    double trace_rho_squared_4x4(const Eigen::Matrix<std::complex<double>, 4, 4>& rho) const;
    Eigen::Matrix<std::complex<double>, 2, 2> partial_trace_single_2x2(
        const Eigen::MatrixXcd& rho, int qubit, int num_qubits) const;
    Eigen::Matrix<std::complex<double>, 4, 4> partial_trace_pair_4x4(
        const Eigen::MatrixXcd& rho, int qa, int qb, int num_qubits) const;
};

}  // namespace godot

#endif  // QUANTUM_EVOLUTION_ENGINE_H
