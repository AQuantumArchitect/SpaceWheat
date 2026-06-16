#ifndef MULTI_BIOME_LOOKAHEAD_ENGINE_H
#define MULTI_BIOME_LOOKAHEAD_ENGINE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include "quantum_evolution_engine.h"
#include "liquid_neural_net.h"
#include "force_graph_engine.h"
#include <vector>
#include <memory>
#include <chrono>

namespace godot {

/**
 * MultiBiomeLookaheadEngine - Batched evolution for all biomes with lookahead
 *
 * Solves the performance problem of multiple bridge crossings by:
 * 1. Registering all biome QuantumEvolutionEngines ONCE at setup
 * 2. Single evolve_all_lookahead() call processes ALL biomes × N steps
 * 3. Returns all intermediate states for buffered rendering
 *
 * Performance gain: 4ms bridge cost amortized over (biomes × steps) evolutions
 * Example: 6 biomes × 5 steps = 30 evolutions for cost of 1 bridge crossing
 */
class MultiBiomeLookaheadEngine : public RefCounted {
    GDCLASS(MultiBiomeLookaheadEngine, RefCounted)

public:
    MultiBiomeLookaheadEngine();
    ~MultiBiomeLookaheadEngine();

    // ========================================================================
    // SETUP METHODS (called once during initialization)
    // ========================================================================

    /**
     * Register a biome's QuantumEvolutionEngine.
     * Call this for each biome after their operators are set up.
     *
     * @param dim Hilbert space dimension (2^num_qubits)
     * @param H_packed Hamiltonian (packed complex matrix)
     * @param lindblad_triplets Array of PackedFloat64Array (triplets for each L_k)
     * @param num_qubits Number of qubits in this biome (for MI computation)
     * @return biome_id for referencing in evolve calls
     */
    int register_biome(int dim, const PackedFloat64Array& H_packed,
                       const Array& lindblad_triplets, int num_qubits);

    /**
     * REPLACE an existing biome's engine in place (stable id), rebuilding its operators.
     * Use for runtime H/L changes (gate inject, mode switch, icon learn) instead of a
     * fresh register_biome() — appending would orphan the old engine and break the
     * rho-slot ↔ engine-id mapping (the rho would be evolved by a stale engine). Returns
     * false if biome_id is out of range.
     */
    bool reregister_biome(int biome_id, int dim, const PackedFloat64Array& H_packed,
                          const Array& lindblad_triplets, int num_qubits);

    /**
     * Clear all registered biomes (for reinitialization).
     */
    void clear_biomes();

    /**
     * Get number of registered biomes.
     */
    int get_biome_count() const;

    /**
     * Enable phase-shadow LNN for a biome.
     * Creates a LiquidNeuralNet that modulates density matrix phases.
     *
     * @param biome_id Which biome to enable LNN for
     * @param hidden_size Number of hidden neurons (typically dim/4)
     */
    void enable_biome_lnn(int biome_id, int hidden_size);

    /**
     * Disable phase-shadow LNN for a biome.
     */
    void disable_biome_lnn(int biome_id);

    /**
     * Check if LNN is enabled for a biome.
     */
    bool is_lnn_enabled(int biome_id) const;

    // ========================================================================
    // PACING CONFIGURATION (CPU-gentle mode)
    // ========================================================================

    /**
     * Set pacing delay between evolution steps (milliseconds).
     * When > 0, C++ sleeps between steps to spread CPU load over time.
     * This prevents CPU spikes without requiring more GDScript↔C++ calls.
     *
     * @param delay_ms Milliseconds to sleep between steps (0 = disabled, default 1)
     */
    void set_pacing_delay_ms(int delay_ms);

    /**
     * Get current pacing delay.
     */
    int get_pacing_delay_ms() const;

    // ========================================================================
    // RUNTIME FLAGS (headless optimizations)
    // ========================================================================

    void set_enable_mi(bool enabled);
    void set_enable_force(bool enabled);
    bool is_mi_enabled() const;
    bool is_force_enabled() const;

    // ========================================================================
    // BATCHED EVOLUTION (single call for ALL biomes, ALL steps)
    // ========================================================================

    /**
     * Evolve all registered biomes forward by 'steps' timesteps.
     *
     * This is the main optimization: single GDScript↔C++ bridge crossing
     * for ALL biomes × ALL lookahead steps.
     *
     * @param biome_rhos Array of PackedFloat64Array - current density matrix per biome
     *                   Order must match registration order (biome_id = array index)
     * @param steps Number of lookahead steps (e.g., 5 for 0.5s at 10Hz)
     * @param dt Time step per step (e.g., 0.1s for 10Hz physics)
     * @param max_dt Maximum substep for numerical stability (e.g., 0.02)
     *
     * @return Dictionary with:
     *   "results": Array<Array<PackedFloat64Array>>
     *              results[biome_id][step] = rho at t + step*dt
     *   "mi": Array<PackedFloat64Array>
     *         mi[biome_id] = mutual information array for last step (compat)
     *   "mi_steps": Array<Array<PackedFloat64Array>>
     *         mi_steps[biome_id][step] = mutual information array for step
     *   "bloch_steps": Array<Array<PackedFloat64Array>>
     *         bloch_steps[biome_id][step] = packed [p0,p1,x,y,z,r,theta,phi] per qubit
     *   "purity_steps": Array<Array<float>>
     *         purity_steps[biome_id][step] = Tr(rho^2)
     *   "position_steps": Array<Array<PackedVector2Array>>
     *         position_steps[biome_id][step] = node positions for step
     *   "metadata": Array<Dictionary>
     *         metadata[biome_id] = emoji/axis mapping payload
     *   "couplings": Array<Dictionary>
     *         couplings[biome_id] = hamiltonian/lindblad/sink flux payload
     *   "icon_maps": Array<Dictionary>
     *         icon_maps[biome_id] = cumulative emoji probability map (sorted)
     */
    Dictionary evolve_all_lookahead(const Array& biome_rhos, int steps,
                                    float dt, float max_dt);

    /**
     * Submit one lookahead packet to a native worker thread.
     *
     * Only one job may be in flight. The caller should poll completion, then call
     * take_completed_lookahead_job() on the main thread and merge the result.
     */
    bool submit_lookahead_job(const Array& biome_rhos, int steps, float dt, float max_dt);
    bool is_lookahead_job_running() const;
    bool is_lookahead_job_complete() const;
    Dictionary take_completed_lookahead_job();
    void cancel_lookahead_job(bool wait_for_completion = true);

    /**
     * Store per-biome metadata payload (emoji mapping, axes, etc.).
     * This is returned verbatim in evolve_* results.
     */
    void set_biome_metadata(int biome_id, const Dictionary& metadata);

    /**
     * Store per-biome coupling payload (hamiltonian/lindblad/sink flux).
     * This is returned verbatim in evolve_* results.
     */
    void set_biome_couplings(int biome_id, const Dictionary& couplings);

    /**
     * Gate the coherent −i[H,ρ] term for one biome's engine (the two-axis switch).
     * off = pure-Lindbladian (H ignored). Dissipation is gated by whether Lindblad
     * operators were registered. Default on.
     */
    void set_biome_coherent(int biome_id, bool on);

    /**
     * Update the biome center used for force-graph physics (purity radial,
     * phase angular forces).  Call this whenever the biome's visual oval
     * center changes (viewport resize, layout update).
     *
     * @param biome_id  Registration ID returned by register_biome()
     * @param center    World-space center of the biome oval
     */
    void set_biome_center(int biome_id, Vector2 center);

    // ========================================================================
    // SINGLE-BIOME EVOLUTION (for on-demand refill after user action)
    // ========================================================================

    /**
     * Evolve a single biome (when user action invalidates lookahead).
     *
     * @param biome_id Which biome to evolve
     * @param rho_packed Current density matrix
     * @param steps Number of lookahead steps
     * @param dt Time step per step
     * @param max_dt Maximum substep
     *
     * @return Dictionary with "results", "mi", "mi_steps", "bloch_steps", "purity_steps",
     *         "position_steps", and "icon_map" for this biome only
     */
    Dictionary evolve_single_biome(int biome_id, const PackedFloat64Array& rho_packed,
                                   int steps, float dt, float max_dt);

protected:
    static void _bind_methods();

private:
    // Registered biome engines (created during register_biome)
    std::vector<Ref<QuantumEvolutionEngine>> m_engines;
    std::vector<int> m_num_qubits;  // num_qubits per biome for MI
    std::vector<Dictionary> m_metadata;
    std::vector<Dictionary> m_couplings;

    // Pacing: sleep between steps to spread CPU load (0 = disabled)
    int m_pacing_delay_ms = 1;  // Default: 1ms sleep between steps (gentle)

    // Runtime toggles
    bool m_enable_mi = true;
    bool m_enable_force = true;

    // Phase-shadow LNN (one per biome, nullptr if disabled)
    std::vector<std::unique_ptr<LiquidNeuralNet>> m_lnns;

    // Force graph engine for computing node positions (shared across all biomes)
    Ref<ForceGraphEngine> m_force_engine;

    // Current node positions per biome (warm-start for the pure-function layout solve)
    std::vector<PackedVector2Array> m_node_positions;
    std::vector<Vector2> m_biome_centers;  // Center position per biome

    // Apply LNN phase modulation to density matrix diagonal
    void _apply_lnn_phase_modulation(int biome_id, PackedFloat64Array& rho_packed);

    // Helper: evolve one biome for multiple steps
    struct BiomeStepResult {
        std::vector<PackedFloat64Array> steps;
        std::vector<PackedFloat64Array> mi_steps;
        std::vector<PackedFloat64Array> bloch_steps;
        std::vector<double> purity_steps;
        std::vector<PackedVector2Array> position_steps;
        Dictionary icon_map;
    };

    BiomeStepResult
    _evolve_biome_steps(int biome_id, const PackedFloat64Array& rho_packed,
                        int steps, float dt, float max_dt,
                        bool compute_mi = true, bool build_icon_map = true);

    Dictionary _build_icon_map(int biome_id,
                               const std::vector<PackedFloat64Array>& bloch_steps);

    // Native async packet state is heap-owned so the Godot-facing object has a
    // small, controlled lifetime surface. Godot Variant containers are only
    // converted back to Dictionary on the main thread.
    struct AsyncJobState;
    std::unique_ptr<AsyncJobState> m_async;

    void _wait_for_job();
    Dictionary _evolve_all_lookahead_impl(const Array& biome_rhos, int steps,
                                          float dt, float max_dt);
    std::vector<PackedFloat64Array> _copy_rhos_to_vector(const Array& biome_rhos) const;
    std::vector<BiomeStepResult> _evolve_all_lookahead_raw(
        const std::vector<PackedFloat64Array>& biome_rhos, int steps,
        float dt, float max_dt, bool build_icon_maps);
    Dictionary _build_lookahead_dictionary(
        const std::vector<BiomeStepResult>& raw_results, int num_biomes,
        int64_t batch_time_us = 0, bool include_timing = false);

};

}  // namespace godot

#endif  // MULTI_BIOME_LOOKAHEAD_ENGINE_H
