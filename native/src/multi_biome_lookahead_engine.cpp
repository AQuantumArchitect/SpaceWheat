#include "multi_biome_lookahead_engine.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <numeric>
#ifndef SPACEWHEAT_WEB_BUILD
#include <thread>  // For pacing (sleep between steps)
#endif
#include <mutex>

using namespace godot;

struct MultiBiomeLookaheadEngine::AsyncJobState {
    mutable std::mutex mutex;
#ifndef SPACEWHEAT_WEB_BUILD
    std::thread thread;
#endif
    bool running = false;
    bool complete = false;
    bool cancel_requested = false;
    std::vector<BiomeStepResult> results;
    int num_biomes = 0;
    int64_t batch_time_us = 0;
};

void MultiBiomeLookaheadEngine::_bind_methods() {
    ClassDB::bind_method(D_METHOD("register_biome", "dim", "H_packed", "lindblad_triplets", "num_qubits"),
                         &MultiBiomeLookaheadEngine::register_biome);
    ClassDB::bind_method(D_METHOD("reregister_biome", "biome_id", "dim", "H_packed", "lindblad_triplets", "num_qubits"),
                         &MultiBiomeLookaheadEngine::reregister_biome);
    ClassDB::bind_method(D_METHOD("set_biome_metadata", "biome_id", "metadata"),
                         &MultiBiomeLookaheadEngine::set_biome_metadata);
    ClassDB::bind_method(D_METHOD("set_biome_couplings", "biome_id", "couplings"),
                         &MultiBiomeLookaheadEngine::set_biome_couplings);
    ClassDB::bind_method(D_METHOD("set_biome_coherent", "biome_id", "on"),
                         &MultiBiomeLookaheadEngine::set_biome_coherent);
    ClassDB::bind_method(D_METHOD("clear_biomes"),
                         &MultiBiomeLookaheadEngine::clear_biomes);
    ClassDB::bind_method(D_METHOD("get_biome_count"),
                         &MultiBiomeLookaheadEngine::get_biome_count);

    // LNN methods
    ClassDB::bind_method(D_METHOD("enable_biome_lnn", "biome_id", "hidden_size"),
                         &MultiBiomeLookaheadEngine::enable_biome_lnn);
    ClassDB::bind_method(D_METHOD("disable_biome_lnn", "biome_id"),
                         &MultiBiomeLookaheadEngine::disable_biome_lnn);
    ClassDB::bind_method(D_METHOD("is_lnn_enabled", "biome_id"),
                         &MultiBiomeLookaheadEngine::is_lnn_enabled);

    ClassDB::bind_method(D_METHOD("evolve_all_lookahead", "biome_rhos", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::evolve_all_lookahead);
    ClassDB::bind_method(D_METHOD("submit_lookahead_job", "biome_rhos", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::submit_lookahead_job);
    ClassDB::bind_method(D_METHOD("is_lookahead_job_running"),
                         &MultiBiomeLookaheadEngine::is_lookahead_job_running);
    ClassDB::bind_method(D_METHOD("is_lookahead_job_complete"),
                         &MultiBiomeLookaheadEngine::is_lookahead_job_complete);
    ClassDB::bind_method(D_METHOD("take_completed_lookahead_job"),
                         &MultiBiomeLookaheadEngine::take_completed_lookahead_job);
    ClassDB::bind_method(D_METHOD("cancel_lookahead_job", "wait_for_completion"),
                         &MultiBiomeLookaheadEngine::cancel_lookahead_job);
    ClassDB::bind_method(D_METHOD("evolve_single_biome", "biome_id", "rho_packed", "steps", "dt", "max_dt"),
                         &MultiBiomeLookaheadEngine::evolve_single_biome);

    // Pacing methods (CPU-gentle mode)
    ClassDB::bind_method(D_METHOD("set_pacing_delay_ms", "delay_ms"),
                         &MultiBiomeLookaheadEngine::set_pacing_delay_ms);
    ClassDB::bind_method(D_METHOD("get_pacing_delay_ms"),
                         &MultiBiomeLookaheadEngine::get_pacing_delay_ms);

    ClassDB::bind_method(D_METHOD("set_enable_mi", "enabled"),
                         &MultiBiomeLookaheadEngine::set_enable_mi);
    ClassDB::bind_method(D_METHOD("set_enable_force", "enabled"),
                         &MultiBiomeLookaheadEngine::set_enable_force);
    ClassDB::bind_method(D_METHOD("is_mi_enabled"),
                         &MultiBiomeLookaheadEngine::is_mi_enabled);
    ClassDB::bind_method(D_METHOD("is_force_enabled"),
                         &MultiBiomeLookaheadEngine::is_force_enabled);

    // Biome center: must be updated when viewport/layout changes
    ClassDB::bind_method(D_METHOD("set_biome_center", "biome_id", "center"),
                         &MultiBiomeLookaheadEngine::set_biome_center);
}

MultiBiomeLookaheadEngine::MultiBiomeLookaheadEngine() {
    m_async = std::make_unique<AsyncJobState>();

    // Initialize force graph engine (shared across all biomes)
    m_force_engine.instantiate();
    m_force_engine->set_repulsion_strength(2500.0f);
    m_force_engine->set_damping(0.92f);
    m_force_engine->set_base_distance(100.0f);
    m_force_engine->set_min_distance(20.0f);
    m_force_engine->set_mi_spring(0.18f);
}

void MultiBiomeLookaheadEngine::set_pacing_delay_ms(int delay_ms) {
    m_pacing_delay_ms = (delay_ms >= 0) ? delay_ms : 0;
}

int MultiBiomeLookaheadEngine::get_pacing_delay_ms() const {
    return m_pacing_delay_ms;
}

void MultiBiomeLookaheadEngine::set_enable_mi(bool enabled) {
    m_enable_mi = enabled;
}

void MultiBiomeLookaheadEngine::set_enable_force(bool enabled) {
    m_enable_force = enabled;
}

bool MultiBiomeLookaheadEngine::is_mi_enabled() const {
    return m_enable_mi;
}

bool MultiBiomeLookaheadEngine::is_force_enabled() const {
    return m_enable_force;
}

MultiBiomeLookaheadEngine::~MultiBiomeLookaheadEngine() {
    cancel_lookahead_job(true);
    m_async.reset();
}

int MultiBiomeLookaheadEngine::register_biome(int dim, const PackedFloat64Array& H_packed,
                                               const Array& lindblad_triplets, int num_qubits) {
    // Create new QuantumEvolutionEngine for this biome
    Ref<QuantumEvolutionEngine> engine;
    engine.instantiate();

    // Configure dimension
    engine->set_dimension(dim);

    // Set Hamiltonian
    if (H_packed.size() > 0) {
        engine->set_hamiltonian(H_packed);
    }

    // Add Lindblad operators
    for (int i = 0; i < lindblad_triplets.size(); i++) {
        PackedFloat64Array triplets = lindblad_triplets[i];
        if (triplets.size() > 0) {
            engine->add_lindblad_triplets(triplets);
        }
    }

    // Finalize (precompute L†, L†L)
    engine->finalize();

    // Store engine and metadata
    int biome_id = static_cast<int>(m_engines.size());
    m_engines.push_back(engine);
    m_num_qubits.push_back(num_qubits);
    m_metadata.push_back(Dictionary());
    m_couplings.push_back(Dictionary());
    m_lnns.push_back(nullptr);  // LNN disabled by default

    // Initialize force graph data (positions for num_qubits nodes)
    PackedVector2Array initial_positions;
    initial_positions.resize(num_qubits);

    // Push default center FIRST so it exists before we read it below.
    const Vector2 default_center(960.0f, 540.0f);  // GDScript updates this via set_biome_center()
    m_biome_centers.push_back(default_center);

    // Initialize positions as a ring centred on the biome oval (world space).
    // Starting near the expected centre means the first convergence pass only travels
    // a short distance to reach equilibrium (rather than 1000+ px from the screen origin).
    for (int i = 0; i < num_qubits; i++) {
        float angle = (float(i) / float(num_qubits)) * 2.0f * 3.14159f;
        float radius = 80.0f;
        initial_positions[i] = default_center + Vector2(std::cos(angle) * radius, std::sin(angle) * radius);
    }

    m_node_positions.push_back(initial_positions);

    const int lindblad_op_count = static_cast<int>(lindblad_triplets.size());
    UtilityFunctions::print_verbose("MultiBiomeLookaheadEngine: Registered biome ",
                                    biome_id, " (dim=", dim, ", num_qubits=", num_qubits,
                                    ", lindblad_ops=", lindblad_op_count, ")");

    return biome_id;
}

bool MultiBiomeLookaheadEngine::reregister_biome(int biome_id, int dim,
        const PackedFloat64Array& H_packed, const Array& lindblad_triplets, int num_qubits) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: reregister_biome invalid id ", biome_id);
        return false;
    }

    // Build a fresh engine with the new operators and REPLACE the slot in place. The
    // biome's id (and thus its rho-array slot + LNN/metadata/position slots) stays stable.
    Ref<QuantumEvolutionEngine> engine;
    engine.instantiate();
    engine->set_dimension(dim);
    if (H_packed.size() > 0) {
        engine->set_hamiltonian(H_packed);
    }
    for (int i = 0; i < lindblad_triplets.size(); i++) {
        PackedFloat64Array triplets = lindblad_triplets[i];
        if (triplets.size() > 0) {
            engine->add_lindblad_triplets(triplets);
        }
    }
    engine->finalize();

    m_engines[biome_id] = engine;          // REPLACE — id stable, no orphan
    m_num_qubits[biome_id] = num_qubits;

    // Keep force-graph positions if the qubit count is unchanged; otherwise re-seed.
    if (static_cast<int>(m_node_positions[biome_id].size()) != num_qubits) {
        PackedVector2Array positions;
        positions.resize(num_qubits);
        Vector2 center = m_biome_centers[biome_id];
        for (int i = 0; i < num_qubits; i++) {
            float angle = (float(i) / float(num_qubits)) * 2.0f * 3.14159f;
            positions[i] = center + Vector2(std::cos(angle) * 80.0f, std::sin(angle) * 80.0f);
        }
        m_node_positions[biome_id] = positions;
    }

    UtilityFunctions::print_verbose("MultiBiomeLookaheadEngine: Re-registered biome ", biome_id,
                                    " in place (dim=", dim, ", lindblad_ops=",
                                    static_cast<int>(lindblad_triplets.size()), ")");
    return true;
}

void MultiBiomeLookaheadEngine::clear_biomes() {
    cancel_lookahead_job(true);

    m_engines.clear();
    m_num_qubits.clear();
    m_metadata.clear();
    m_couplings.clear();
    m_lnns.clear();
    m_node_positions.clear();
    m_biome_centers.clear();
}

int MultiBiomeLookaheadEngine::get_biome_count() const {
    return static_cast<int>(m_engines.size());
}

void MultiBiomeLookaheadEngine::set_biome_metadata(int biome_id, const Dictionary& metadata) {
    if (is_lookahead_job_running()) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: metadata update skipped while async packet is running");
        return;
    }
    if (biome_id < 0 || biome_id >= static_cast<int>(m_metadata.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for metadata ", biome_id);
        return;
    }
    m_metadata[biome_id] = metadata;
}

void MultiBiomeLookaheadEngine::set_biome_couplings(int biome_id, const Dictionary& couplings) {
    if (is_lookahead_job_running()) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: coupling update skipped while async packet is running");
        return;
    }
    if (biome_id < 0 || biome_id >= static_cast<int>(m_couplings.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for couplings ", biome_id);
        return;
    }
    m_couplings[biome_id] = couplings;
}

void MultiBiomeLookaheadEngine::set_biome_coherent(int biome_id, bool on) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for set_coherent ", biome_id);
        return;
    }
    if (m_engines[biome_id].is_valid()) {
        m_engines[biome_id]->set_coherent(on);
    }
}

void MultiBiomeLookaheadEngine::set_biome_center(int biome_id, Vector2 center) {
    if (is_lookahead_job_running()) {
		return;
	}
    if (biome_id < 0 || biome_id >= static_cast<int>(m_biome_centers.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for center ", biome_id);
        return;
    }
    m_biome_centers[biome_id] = center;
}

Dictionary MultiBiomeLookaheadEngine::evolve_all_lookahead(
    const Array& biome_rhos, int steps, float dt, float max_dt) {
    return _evolve_all_lookahead_impl(biome_rhos, steps, dt, max_dt);
}

bool MultiBiomeLookaheadEngine::submit_lookahead_job(
    const Array& biome_rhos, int steps, float dt, float max_dt) {
    if (!m_async) {
        m_async = std::make_unique<AsyncJobState>();
    }

#ifdef SPACEWHEAT_WEB_BUILD
    std::vector<PackedFloat64Array> biome_rhos_copy = _copy_rhos_to_vector(biome_rhos);
    auto job_started = std::chrono::steady_clock::now();
    std::vector<BiomeStepResult> raw_results =
        _evolve_all_lookahead_raw(biome_rhos_copy, steps, dt, max_dt, false);
    auto job_finished = std::chrono::steady_clock::now();
    int64_t batch_time_us = std::chrono::duration_cast<std::chrono::microseconds>(
        job_finished - job_started).count();

    std::lock_guard<std::mutex> lock(m_async->mutex);
    if (m_async->running) {
        return false;
    }
    m_async->results = std::move(raw_results);
    m_async->num_biomes = static_cast<int>(biome_rhos_copy.size());
    m_async->batch_time_us = batch_time_us;
    m_async->cancel_requested = false;
    m_async->running = false;
    m_async->complete = true;
    return true;
#else
    std::thread stale_thread;
    {
        std::lock_guard<std::mutex> lock(m_async->mutex);
        if (m_async->running) {
            return false;
        }
        if (m_async->thread.joinable()) {
            stale_thread = std::move(m_async->thread);
        }
        m_async->results.clear();
        m_async->num_biomes = 0;
        m_async->batch_time_us = 0;
        m_async->complete = false;
        m_async->cancel_requested = false;
    }

    if (stale_thread.joinable()) {
        stale_thread.join();
    }

    {
        std::lock_guard<std::mutex> lock(m_async->mutex);
        m_async->running = true;
    }

    std::vector<PackedFloat64Array> biome_rhos_copy = _copy_rhos_to_vector(biome_rhos);
    AsyncJobState* async = m_async.get();
    m_async->thread = std::thread([this, async, biome_rhos_copy, steps, dt, max_dt]() mutable {
        auto job_started = std::chrono::steady_clock::now();
        std::vector<BiomeStepResult> raw_results;
        raw_results = _evolve_all_lookahead_raw(biome_rhos_copy, steps, dt, max_dt, false);
        auto job_finished = std::chrono::steady_clock::now();
        int64_t batch_time_us = std::chrono::duration_cast<std::chrono::microseconds>(
            job_finished - job_started).count();

        std::lock_guard<std::mutex> lock(async->mutex);
        if (!async->cancel_requested) {
            async->results = std::move(raw_results);
            async->num_biomes = static_cast<int>(biome_rhos_copy.size());
            async->batch_time_us = batch_time_us;
            async->complete = true;
        } else {
            async->results.clear();
            async->num_biomes = 0;
            async->batch_time_us = 0;
            async->complete = false;
        }
        async->running = false;
    });

    return true;
#endif
}

bool MultiBiomeLookaheadEngine::is_lookahead_job_running() const {
    if (!m_async) {
        return false;
    }
    std::lock_guard<std::mutex> lock(m_async->mutex);
    return m_async->running;
}

bool MultiBiomeLookaheadEngine::is_lookahead_job_complete() const {
    if (!m_async) {
        return false;
    }
    std::lock_guard<std::mutex> lock(m_async->mutex);
    return m_async->complete;
}

Dictionary MultiBiomeLookaheadEngine::take_completed_lookahead_job() {
    if (!m_async) {
        return Dictionary();
    }

#ifdef SPACEWHEAT_WEB_BUILD
    std::vector<BiomeStepResult> raw_results;
    int num_biomes = 0;
    int64_t batch_time_us = 0;
    {
        std::lock_guard<std::mutex> lock(m_async->mutex);
        if (!m_async->complete) {
            return Dictionary();
        }
        raw_results = std::move(m_async->results);
        m_async->results.clear();
        num_biomes = m_async->num_biomes;
        batch_time_us = m_async->batch_time_us;
        m_async->num_biomes = 0;
        m_async->batch_time_us = 0;
        m_async->complete = false;
    }
    return _build_lookahead_dictionary(raw_results, num_biomes, batch_time_us, true);
#else
    std::thread join_thread;
    std::vector<BiomeStepResult> raw_results;
    int num_biomes = 0;
    int64_t batch_time_us = 0;
    {
        std::lock_guard<std::mutex> lock(m_async->mutex);
        if (!m_async->complete) {
            return Dictionary();
        }
        raw_results = std::move(m_async->results);
        m_async->results.clear();
        num_biomes = m_async->num_biomes;
        batch_time_us = m_async->batch_time_us;
        m_async->num_biomes = 0;
        m_async->batch_time_us = 0;
        m_async->complete = false;
        if (m_async->thread.joinable()) {
            join_thread = std::move(m_async->thread);
        }
    }
    if (join_thread.joinable()) {
        join_thread.join();
    }

    return _build_lookahead_dictionary(raw_results, num_biomes, batch_time_us, true);
#endif
}

void MultiBiomeLookaheadEngine::cancel_lookahead_job(bool wait_for_completion) {
    if (!m_async) {
        return;
    }

#ifdef SPACEWHEAT_WEB_BUILD
    std::lock_guard<std::mutex> lock(m_async->mutex);
    m_async->cancel_requested = false;
    m_async->running = false;
    m_async->complete = false;
    m_async->results.clear();
    m_async->num_biomes = 0;
    m_async->batch_time_us = 0;
    return;
#else
    std::thread stale_thread;
    {
        std::lock_guard<std::mutex> lock(m_async->mutex);
        if (!m_async->running && !m_async->complete) {
            if (m_async->thread.joinable()) {
                stale_thread = std::move(m_async->thread);
            }
        } else {
            m_async->cancel_requested = true;
        }
    }

    if (stale_thread.joinable()) {
        stale_thread.join();
        return;
    }

    if (wait_for_completion) {
        _wait_for_job();
    }
#endif
}

void MultiBiomeLookaheadEngine::_wait_for_job() {
    if (!m_async) {
        return;
    }

#ifdef SPACEWHEAT_WEB_BUILD
    std::lock_guard<std::mutex> lock(m_async->mutex);
    m_async->running = false;
    m_async->complete = false;
    m_async->cancel_requested = false;
    m_async->results.clear();
    m_async->num_biomes = 0;
    m_async->batch_time_us = 0;
#else
    std::thread join_thread;
    {
        std::lock_guard<std::mutex> lock(m_async->mutex);
        if (m_async->thread.joinable()) {
            join_thread = std::move(m_async->thread);
        }
    }
    if (join_thread.joinable()) {
        join_thread.join();
    }
    std::lock_guard<std::mutex> lock(m_async->mutex);
    m_async->running = false;
    m_async->complete = false;
    m_async->cancel_requested = false;
    m_async->results.clear();
    m_async->num_biomes = 0;
    m_async->batch_time_us = 0;
#endif
}

Dictionary MultiBiomeLookaheadEngine::_evolve_all_lookahead_impl(
    const Array& biome_rhos, int steps, float dt, float max_dt) {
    Dictionary result;
    Array all_results;
    Array all_mi;
    Array all_mi_steps;
    Array all_bloch_steps;
    Array all_purity_steps;
    Array all_position_steps;
    Array all_metadata;
    Array all_couplings;
    Array all_icon_maps;

    int num_biomes = static_cast<int>(biome_rhos.size());
    const int registered_biome_count = static_cast<int>(m_engines.size());
    if (num_biomes > registered_biome_count) {
        UtilityFunctions::push_warning(
            "MultiBiomeLookaheadEngine: More rhos than registered biomes (",
            num_biomes, " vs ", registered_biome_count, ")");
        num_biomes = registered_biome_count;
    }

    for (int biome_id = 0; biome_id < num_biomes; biome_id++) {
        PackedFloat64Array rho_packed = biome_rhos[biome_id];

        // DIMENSION GUARD: the rho slot ↔ engine mapping is by index, so a caller that
        // builds the rho array in a different order than registration would hand an engine
        // a wrong-sized ρ → overread (and garbage bloch/MI downstream). Skip + warn rather
        // than trust the index coupling. (The engine also guards internally.)
        if (!rho_packed.is_empty()) {
            const Ref<QuantumEvolutionEngine>& guard_eng = m_engines[biome_id];
            int guard_dim = guard_eng.is_valid() ? guard_eng->get_dimension() : 0;
            int64_t guard_expected = static_cast<int64_t>(2) * guard_dim * guard_dim;
            if (guard_dim <= 0 || rho_packed.size() != guard_expected) {
                UtilityFunctions::push_warning(
                    "MultiBiomeLookaheadEngine: ρ for biome_id ", biome_id, " size ",
                    rho_packed.size(), " != expected ", guard_expected, " (engine dim ",
                    guard_dim, ") — skipping (rho/engine order mismatch?).");
                rho_packed = PackedFloat64Array();  // treat as skip (empty)
            }
        }

        bool is_zero = rho_packed.is_empty();
        if (!is_zero) {
            bool all_zeros = true;
            for (int64_t i = 0; i < rho_packed.size(); i++) {
                if (rho_packed[i] != 0.0) {
                    all_zeros = false;
                    break;
                }
            }
            is_zero = all_zeros;
        }

        BiomeStepResult biome_result;
        if (!is_zero) {
            biome_result = _evolve_biome_steps(biome_id, rho_packed, steps, dt, max_dt);
        }

        Array biome_steps;
        for (const auto& step_rho : biome_result.steps) {
            biome_steps.push_back(step_rho);
        }
        all_results.push_back(biome_steps);

        Array biome_mi_steps;
        for (const auto& mi_step : biome_result.mi_steps) {
            biome_mi_steps.push_back(mi_step);
        }
        all_mi_steps.push_back(biome_mi_steps);
        all_mi.push_back(!biome_result.mi_steps.empty() ? biome_result.mi_steps.back() : PackedFloat64Array());

        Array biome_bloch_steps;
        for (const auto& bloch_step : biome_result.bloch_steps) {
            biome_bloch_steps.push_back(bloch_step);
        }
        all_bloch_steps.push_back(biome_bloch_steps);

        Array biome_purity_steps;
        for (double purity_val : biome_result.purity_steps) {
            biome_purity_steps.push_back(purity_val);
        }
        all_purity_steps.push_back(biome_purity_steps);

        Array biome_position_steps;
        for (const auto& position_step : biome_result.position_steps) {
            biome_position_steps.push_back(position_step);
        }
        all_position_steps.push_back(biome_position_steps);

        all_metadata.push_back(biome_id < static_cast<int>(m_metadata.size()) ? m_metadata[biome_id] : Dictionary());
        all_couplings.push_back(biome_id < static_cast<int>(m_couplings.size()) ? m_couplings[biome_id] : Dictionary());
        all_icon_maps.push_back(biome_result.icon_map);
    }

    result["results"] = all_results;
    result["mi"] = all_mi;
    result["mi_steps"] = all_mi_steps;
    result["bloch_steps"] = all_bloch_steps;
    result["purity_steps"] = all_purity_steps;
    result["position_steps"] = all_position_steps;
    result["metadata"] = all_metadata;
    result["couplings"] = all_couplings;
    result["icon_maps"] = all_icon_maps;
    return result;
}

std::vector<PackedFloat64Array> MultiBiomeLookaheadEngine::_copy_rhos_to_vector(const Array& biome_rhos) const {
    std::vector<PackedFloat64Array> out;
    out.reserve(biome_rhos.size());
    for (int i = 0; i < biome_rhos.size(); i++) {
        out.push_back(biome_rhos[i]);
    }
    return out;
}

std::vector<MultiBiomeLookaheadEngine::BiomeStepResult>
MultiBiomeLookaheadEngine::_evolve_all_lookahead_raw(
    const std::vector<PackedFloat64Array>& biome_rhos, int steps,
    float dt, float max_dt, bool build_icon_maps) {

    int num_biomes = static_cast<int>(biome_rhos.size());
    if (num_biomes > static_cast<int>(m_engines.size())) {
        num_biomes = static_cast<int>(m_engines.size());
    }

    std::vector<BiomeStepResult> raw_results;
    raw_results.resize(num_biomes);

    for (int biome_id = 0; biome_id < num_biomes; biome_id++) {
        PackedFloat64Array rho_packed = biome_rhos[biome_id];

        // DIMENSION GUARD: the rho slot ↔ engine mapping is by index, so a caller that
        // builds the rho array in a different order than registration would hand an engine
        // a wrong-sized ρ → overread (and garbage bloch/MI downstream). Skip + warn rather
        // than trust the index coupling. (The engine also guards internally.)
        if (!rho_packed.is_empty()) {
            const Ref<QuantumEvolutionEngine>& guard_eng = m_engines[biome_id];
            int guard_dim = guard_eng.is_valid() ? guard_eng->get_dimension() : 0;
            int64_t guard_expected = static_cast<int64_t>(2) * guard_dim * guard_dim;
            if (guard_dim <= 0 || rho_packed.size() != guard_expected) {
                UtilityFunctions::push_warning(
                    "MultiBiomeLookaheadEngine: ρ for biome_id ", biome_id, " size ",
                    rho_packed.size(), " != expected ", guard_expected, " (engine dim ",
                    guard_dim, ") — skipping (rho/engine order mismatch?).");
                rho_packed = PackedFloat64Array();  // treat as skip (empty)
            }
        }

        bool is_zero = rho_packed.is_empty();
        if (!is_zero) {
            bool all_zeros = true;
            for (int64_t i = 0; i < rho_packed.size(); i++) {
                if (rho_packed[i] != 0.0) {
                    all_zeros = false;
                    break;
                }
            }
            is_zero = all_zeros;
        }

        if (!is_zero) {
            raw_results[biome_id] = _evolve_biome_steps(
                biome_id, rho_packed, steps, dt, max_dt, true, build_icon_maps);
        }
    }

    return raw_results;
}

Dictionary MultiBiomeLookaheadEngine::_build_lookahead_dictionary(
    const std::vector<BiomeStepResult>& raw_results, int num_biomes,
    int64_t batch_time_us, bool include_timing) {

    Dictionary result;
    Array all_results;        // Array<Array<PackedFloat64Array>>
    Array all_mi;             // Array<PackedFloat64Array> (last step)
    Array all_mi_steps;       // Array<Array<PackedFloat64Array>>
    Array all_bloch_steps;    // Array<Array<PackedFloat64Array>>
    Array all_purity_steps;   // Array<Array<float>>
    Array all_position_steps; // Array<Array<PackedVector2Array>> (NEW: force positions)
    Array all_metadata;       // Array<Dictionary>
    Array all_couplings;      // Array<Dictionary>
    Array all_icon_maps;      // Array<Dictionary>

    num_biomes = std::min(num_biomes, static_cast<int>(raw_results.size()));
    num_biomes = std::min(num_biomes, static_cast<int>(m_engines.size()));

    for (int biome_id = 0; biome_id < num_biomes; biome_id++) {
        const BiomeStepResult& biome_result = raw_results[biome_id];

        // Convert step_results to Godot Array
        Array biome_steps;
        for (const auto& step_rho : biome_result.steps) {
            biome_steps.push_back(step_rho);
        }

        all_results.push_back(biome_steps);

        Array biome_mi_steps;
        for (const auto& mi_step : biome_result.mi_steps) {
            biome_mi_steps.push_back(mi_step);
        }
        all_mi_steps.push_back(biome_mi_steps);
        if (!biome_result.mi_steps.empty()) {
            all_mi.push_back(biome_result.mi_steps.back());
        } else {
            all_mi.push_back(PackedFloat64Array());
        }

        Array biome_bloch_steps;
        for (const auto& bloch_step : biome_result.bloch_steps) {
            biome_bloch_steps.push_back(bloch_step);
        }
        all_bloch_steps.push_back(biome_bloch_steps);

        Array biome_purity_steps;
        for (double purity_val : biome_result.purity_steps) {
            biome_purity_steps.push_back(purity_val);
        }
        all_purity_steps.push_back(biome_purity_steps);

        // Collect force graph position steps
        Array biome_position_steps;
        for (const auto& position_step : biome_result.position_steps) {
            biome_position_steps.push_back(position_step);
        }
        all_position_steps.push_back(biome_position_steps);

        if (biome_id < static_cast<int>(m_metadata.size())) {
            all_metadata.push_back(m_metadata[biome_id]);
        } else {
            all_metadata.push_back(Dictionary());
        }

        if (biome_id < static_cast<int>(m_couplings.size())) {
            all_couplings.push_back(m_couplings[biome_id]);
        } else {
            all_couplings.push_back(Dictionary());
        }

        if (!biome_result.icon_map.is_empty()) {
            all_icon_maps.push_back(biome_result.icon_map);
        } else {
            all_icon_maps.push_back(_build_icon_map(biome_id, biome_result.bloch_steps));
        }
    }

    result["results"] = all_results;
    result["mi"] = all_mi;
    result["mi_steps"] = all_mi_steps;
    result["bloch_steps"] = all_bloch_steps;
    result["purity_steps"] = all_purity_steps;
    result["position_steps"] = all_position_steps;
    result["metadata"] = all_metadata;
    result["couplings"] = all_couplings;
    result["icon_maps"] = all_icon_maps;
    if (include_timing) {
        result["batch_time_us"] = batch_time_us;
        result["error"] = false;
    }

    return result;
}

Dictionary MultiBiomeLookaheadEngine::evolve_single_biome(
    int biome_id, const PackedFloat64Array& rho_packed,
    int steps, float dt, float max_dt) {

    Dictionary result;

    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        UtilityFunctions::push_warning(
            "MultiBiomeLookaheadEngine: Invalid biome_id ", biome_id);
        return result;
    }

    // Skip empty or all-zero rhos (no Hamiltonian meaning)
    bool is_zero = rho_packed.is_empty();
    if (!is_zero) {
        // Check if all zeros
        bool all_zeros = true;
        for (int64_t i = 0; i < rho_packed.size(); i++) {
            if (rho_packed[i] != 0.0) {
                all_zeros = false;
                break;
            }
        }
        is_zero = all_zeros;
    }

    BiomeStepResult biome_result;
    if (!is_zero) {
        // Evolve this biome (only if valid state)
        biome_result = _evolve_biome_steps(biome_id, rho_packed, steps, dt, max_dt);
    }
    // else: biome_result remains empty (skip calculation)

    // Convert to Godot types
    Array biome_steps;
    for (const auto& step_rho : biome_result.steps) {
        biome_steps.push_back(step_rho);
    }

    result["results"] = biome_steps;
    if (!biome_result.mi_steps.empty()) {
        result["mi"] = biome_result.mi_steps.back();
    } else {
        result["mi"] = PackedFloat64Array();
    }

    Array biome_mi_steps;
    for (const auto& mi_step : biome_result.mi_steps) {
        biome_mi_steps.push_back(mi_step);
    }
    result["mi_steps"] = biome_mi_steps;

    Array biome_bloch_steps;
    for (const auto& bloch_step : biome_result.bloch_steps) {
        biome_bloch_steps.push_back(bloch_step);
    }
    result["bloch_steps"] = biome_bloch_steps;

    Array biome_purity_steps;
    for (double purity_val : biome_result.purity_steps) {
        biome_purity_steps.push_back(purity_val);
    }
    result["purity_steps"] = biome_purity_steps;

    // Force-graph positions (same format as evolve_all_lookahead but flat: step → positions)
    Array biome_position_steps;
    for (const auto& pos : biome_result.position_steps) {
        biome_position_steps.push_back(pos);
    }
    result["position_steps"] = biome_position_steps;

    if (biome_id >= 0 && biome_id < static_cast<int>(m_metadata.size())) {
        result["metadata"] = m_metadata[biome_id];
    }
    if (biome_id >= 0 && biome_id < static_cast<int>(m_couplings.size())) {
        result["couplings"] = m_couplings[biome_id];
    }
    result["icon_map"] = biome_result.icon_map;

    return result;
}

MultiBiomeLookaheadEngine::BiomeStepResult
MultiBiomeLookaheadEngine::_evolve_biome_steps(
    int biome_id, const PackedFloat64Array& rho_packed,
    int steps, float dt, float max_dt, bool compute_mi, bool build_icon_map) {

    BiomeStepResult out;

    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        return out;
    }

    Ref<QuantumEvolutionEngine> engine = m_engines[biome_id];
    int num_qubits = m_num_qubits[biome_id];

    // Start with current rho
    PackedFloat64Array current_rho = rho_packed;

    // Get current force positions for this biome
    PackedVector2Array current_positions = m_node_positions[biome_id];
    Vector2 biome_center = m_biome_centers[biome_id];

    // Create frozen mask (all nodes active for now)
    PackedByteArray frozen_mask;
    frozen_mask.resize(num_qubits);
    for (int i = 0; i < num_qubits; i++) {
        frozen_mask[i] = 0;  // 0 = active, 1 = frozen
    }

    // Evolve for each step
    for (int step = 0; step < steps; step++) {
        // Single evolution step (with subcycling inside)
        PackedFloat64Array evolved_rho = engine->evolve(current_rho, dt, max_dt);

        // Apply phase-shadow LNN modulation (if enabled)
        _apply_lnn_phase_modulation(biome_id, evolved_rho);

        // Store result
        out.steps.push_back(evolved_rho);
        PackedFloat64Array bloch_packet = engine->compute_bloch_metrics_from_packed(evolved_rho, num_qubits);
        out.bloch_steps.push_back(bloch_packet);
        double purity = engine->compute_purity_from_packed(evolved_rho);
        out.purity_steps.push_back(purity);

        // OPTIMIZED MI: Adaptive computation with screening + high-purity approximation
        // - Step 0: Full scan to identify candidate pairs (pairs with MI > threshold)
        // - Steps 1+: Only compute for candidates, skip negligible pairs
        // - Uses linear entropy (no eigendecomp) when purity > 0.9
        PackedFloat64Array mi_values;
        if (compute_mi && m_enable_mi) {
            bool force_full_scan = (step == 0);  // Screen on first step only
            mi_values = engine->compute_mi_adaptive(
                evolved_rho, num_qubits, purity, force_full_scan);
            out.mi_steps.push_back(mi_values);
        } else {
            mi_values = PackedFloat64Array();  // Empty placeholder
            if (m_enable_mi) {
                out.mi_steps.push_back(mi_values);
            }
        }

        // Compute force-directed positions using Bloch + MI data
        if (m_enable_force && m_force_engine.is_valid()) {
            Dictionary force_result = m_force_engine->update_positions(
                current_positions,
                bloch_packet,
                mi_values,
                biome_center,
                dt,
                frozen_mask
            );

            // Extract updated positions
            current_positions = force_result.get("positions", current_positions);

            // Store for this step
            out.position_steps.push_back(current_positions);
        } else if (m_enable_force) {
            // No force engine - use previous positions
            out.position_steps.push_back(current_positions);
        }

        // Update for next step
        current_rho = evolved_rho;

        // CPU-gentle pacing: sleep between steps to spread load
        if (m_pacing_delay_ms > 0) {
#ifndef SPACEWHEAT_WEB_BUILD
            std::this_thread::sleep_for(std::chrono::milliseconds(m_pacing_delay_ms));
#endif
        }
    }

    if (build_icon_map) {
        out.icon_map = _build_icon_map(biome_id, out.bloch_steps);
    }

    // Update stored positions for next refill
    m_node_positions[biome_id] = current_positions;

    return out;
}

// ============================================================================
// PHASE-SHADOW LNN METHODS
// ============================================================================

void MultiBiomeLookaheadEngine::enable_biome_lnn(int biome_id, int hidden_size) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_engines.size())) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid biome_id for LNN ", biome_id);
        return;
    }

    // Get dimension from the engine
    int dim = m_engines[biome_id]->get_dimension();
    if (dim <= 0) {
        UtilityFunctions::push_warning("MultiBiomeLookaheadEngine: Invalid dimension for LNN");
        return;
    }

    // Create LNN: input = dim phases, output = dim phase modulations
    m_lnns[biome_id] = std::make_unique<LiquidNeuralNet>(dim, hidden_size, dim);

    UtilityFunctions::print_verbose("MultiBiomeLookaheadEngine: LNN enabled for biome ", biome_id,
                                    " (dim=", dim, ", hidden=", hidden_size, ")");
}

void MultiBiomeLookaheadEngine::disable_biome_lnn(int biome_id) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_lnns.size())) {
        return;
    }
    m_lnns[biome_id].reset();
}

bool MultiBiomeLookaheadEngine::is_lnn_enabled(int biome_id) const {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_lnns.size())) {
        return false;
    }
    return m_lnns[biome_id] != nullptr;
}

void MultiBiomeLookaheadEngine::_apply_lnn_phase_modulation(int biome_id, PackedFloat64Array& rho_packed) {
    if (biome_id < 0 || biome_id >= static_cast<int>(m_lnns.size()) || !m_lnns[biome_id]) {
        return;
    }

    LiquidNeuralNet* lnn = m_lnns[biome_id].get();
    int dim = static_cast<int>(std::sqrt(rho_packed.size() / 2));
    if (dim * dim * 2 != rho_packed.size()) {
        return;
    }

    // Extract diagonal phases: phase[i] = arg(rho[i,i])
    std::vector<double> phases(dim);
    for (int i = 0; i < dim; i++) {
        int idx = (i * dim + i) * 2;  // Diagonal element rho[i,i]
        double re = rho_packed[idx];
        double im = rho_packed[idx + 1];
        phases[i] = std::atan2(im, re);
    }

    // Forward pass through LNN
    std::vector<double> phase_deltas = lnn->forward(phases);

    // Apply phase modulation to diagonal elements
    // rho[i,i] *= exp(i * delta_phase[i])
    for (int i = 0; i < dim && i < static_cast<int>(phase_deltas.size()); i++) {
        int idx = (i * dim + i) * 2;
        double re = rho_packed[idx];
        double im = rho_packed[idx + 1];

        // Scale delta to be small modulation (0.01 radians max)
        double delta = phase_deltas[i] * 0.01;

        // exp(i*delta) = cos(delta) + i*sin(delta)
        double cos_d = std::cos(delta);
        double sin_d = std::sin(delta);

        // (re + i*im) * (cos_d + i*sin_d) = (re*cos_d - im*sin_d) + i*(re*sin_d + im*cos_d)
        rho_packed[idx] = re * cos_d - im * sin_d;
        rho_packed[idx + 1] = re * sin_d + im * cos_d;
    }
}

// ============================================================================
// ICON MAP BUILDING
// ============================================================================

Dictionary MultiBiomeLookaheadEngine::_build_icon_map(
    int biome_id, const std::vector<PackedFloat64Array>& bloch_steps) {

    Dictionary icon_map;

    if (biome_id < 0 || biome_id >= static_cast<int>(m_num_qubits.size())) {
        return icon_map;
    }
    if (bloch_steps.empty()) {
        return icon_map;
    }
    if (biome_id < 0 || biome_id >= static_cast<int>(m_metadata.size())) {
        return icon_map;
    }

    Dictionary metadata = m_metadata[biome_id];
    if (metadata.is_empty()) {
        return icon_map;
    }

    Array emoji_list = metadata.get("emoji_list", Array());
    Dictionary emoji_to_qubit = metadata.get("emoji_to_qubit", Dictionary());
    Dictionary emoji_to_pole = metadata.get("emoji_to_pole", Dictionary());

    if (emoji_list.is_empty() || emoji_to_qubit.is_empty() || emoji_to_pole.is_empty()) {
        return icon_map;
    }

    int num_qubits = m_num_qubits[biome_id];
    const int stride = 9;
    const int expected = num_qubits * stride;

    std::vector<double> totals;
    totals.resize(emoji_list.size(), 0.0);

    for (const auto& bloch_step : bloch_steps) {
        if (bloch_step.is_empty() || bloch_step.size() < expected) {
            continue;
        }

        const double* ptr = bloch_step.ptr();
        for (int i = 0; i < emoji_list.size(); i++) {
            Variant emoji_var = emoji_list[i];
            if (emoji_var.get_type() != Variant::STRING) {
                continue;
            }
            String emoji = emoji_var;
            if (!emoji_to_qubit.has(emoji) || !emoji_to_pole.has(emoji)) {
                continue;
            }

            int qubit = static_cast<int>(emoji_to_qubit[emoji]);
            int pole = static_cast<int>(emoji_to_pole[emoji]);
            if (qubit < 0 || qubit >= num_qubits || (pole != 0 && pole != 1)) {
                continue;
            }

            int base = qubit * stride;
            double p0 = ptr[base + 0];
            double p1 = ptr[base + 1];
            double prob = (pole == 0) ? p0 : p1;
            totals[i] += prob;
        }
    }

    std::vector<int> order(totals.size());
    std::iota(order.begin(), order.end(), 0);
    std::sort(order.begin(), order.end(), [&totals](int a, int b) {
        return totals[a] > totals[b];
    });

    Array sorted_emojis;
    PackedFloat64Array sorted_weights;
    sorted_weights.resize(static_cast<int>(order.size()));

    Dictionary by_emoji;
    double total_sum = 0.0;
    int out_idx = 0;
    for (int idx : order) {
        Variant emoji_var = emoji_list[idx];
        if (emoji_var.get_type() != Variant::STRING) {
            continue;
        }
        String emoji = emoji_var;
        double weight = totals[idx];
        sorted_emojis.push_back(emoji);
        sorted_weights.set(out_idx, weight);
        out_idx += 1;
        by_emoji[emoji] = weight;
        total_sum += weight;
    }

    icon_map["emojis"] = sorted_emojis;
    icon_map["weights"] = sorted_weights;
    icon_map["by_emoji"] = by_emoji;
    icon_map["steps"] = static_cast<int>(bloch_steps.size());
    icon_map["total"] = total_sum;
    icon_map["num_qubits"] = num_qubits;

    return icon_map;
}
