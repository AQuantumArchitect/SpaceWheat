#ifndef QUANTUM_EVOLUTION_ENGINE_H
#define QUANTUM_EVOLUTION_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
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
    void finalize();  // Precompute all cached values

    // Query methods
    int get_dimension() const;
    int get_lindblad_count() const;
    bool is_finalized() const;

    // Evolution (single call per frame!)
    PackedFloat64Array evolve_step(const PackedFloat64Array& rho_data, float dt);

    // Batch evolution with subcycling
    PackedFloat64Array evolve(const PackedFloat64Array& rho_data, float dt, float max_dt);

protected:
    static void _bind_methods();

private:
    int m_dim;
    bool m_finalized;

    // Dense Hamiltonian (optional)
    Eigen::MatrixXcd m_hamiltonian;
    bool m_has_hamiltonian;

    // Sparse Lindblad operators
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_lindblads;

    // Cached values for efficiency
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_lindblad_dags;  // L†
    std::vector<Eigen::SparseMatrix<std::complex<double>, Eigen::RowMajor>> m_LdagLs;        // L†L

    // Helper methods
    Eigen::MatrixXcd unpack_dense(const PackedFloat64Array& data) const;
    PackedFloat64Array pack_dense(const Eigen::MatrixXcd& mat) const;
};

}  // namespace godot

#endif  // QUANTUM_EVOLUTION_ENGINE_H
