// swk_c.cpp - C interface over the header-only swk kernel. No exception escapes.
#define SWK_BUILDING 1
#include "swk_c.h"

#include "swk/swk.hpp"

#include <cstddef>
#include <new>
#include <string>
#include <vector>

struct swk_engine {
    swk::EvolutionEngine engine;
    swk_diagnostic_fn cb = nullptr;
    void* user = nullptr;
};

namespace {

int st(swk::Status s) { return static_cast<int>(s); }

// Runs `fn` (returning int) with exceptions turned into SWK_ERR_INTERNAL.
template <typename F>
int guard(F&& fn) {
    try {
        return fn();
    } catch (...) {
        return SWK_ERR_INTERNAL;
    }
}

int forward(swk_engine* e, swk::Severity sev, const std::string& msg) {
    if (e->cb != nullptr) {
        e->cb(sev == swk::Severity::Error ? SWK_SEVERITY_ERROR : SWK_SEVERITY_WARNING, msg.c_str(),
              e->user);
    }
    return 0;
}

// Unpack a packed matrix of side `dim`, with the size check done by unpack_dense.
int unpack(const double* rho, int64_t count, int dim, swk::CMatrix& out) {
    if (rho == nullptr) return SWK_ERR_NULL_POINTER;
    if (dim <= 0 || dim > 4096) return SWK_ERR_INVALID_ARGUMENT;
    if (!swk::unpack_dense(rho, count, dim, out)) return SWK_ERR_SIZE_MISMATCH;
    return SWK_OK;
}

int unpack_qubits(const double* rho, int64_t count, int num_qubits, swk::CMatrix& out) {
    if (rho == nullptr) return SWK_ERR_NULL_POINTER;
    if (num_qubits < 1 || num_qubits > 12) return SWK_ERR_INVALID_ARGUMENT;
    return unpack(rho, count, 1 << num_qubits, out);
}

}  // namespace

extern "C" {

const char* swk_version(void) { return "swk 0.1.0"; }

const char* swk_status_name(int status) {
    switch (status) {
        case SWK_OK: return "Ok";
        case SWK_ERR_DIMENSION_NOT_SET: return "DimensionNotSet";
        case SWK_ERR_SIZE_MISMATCH: return "SizeMismatch";
        case SWK_ERR_NOT_FINALIZED: return "NotFinalized";
        case SWK_ERR_INDEX_OUT_OF_RANGE: return "IndexOutOfRange";
        case SWK_ERR_INVALID_ARGUMENT: return "InvalidArgument";
        case SWK_ERR_EIGEN_FAILURE: return "EigenFailure";
        case SWK_ERR_INTERNAL: return "Internal";
        case SWK_ERR_NULL_POINTER: return "NullPointer";
        default: return "Unknown";
    }
}

int swk_bloch_stride(void) { return swk::kBlochStride; }

swk_engine* swk_engine_create(void) {
    try {
        return new (std::nothrow) swk_engine();
    } catch (...) {
        return nullptr;
    }
}

void swk_engine_destroy(swk_engine* e) {
    try {
        delete e;
    } catch (...) {
    }
}

int swk_engine_set_diagnostic_callback(swk_engine* e, swk_diagnostic_fn cb, void* user) {
    if (e == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        e->cb = cb;
        e->user = user;
        if (cb == nullptr) {
            e->engine.set_diagnostic_sink(swk::DiagnosticSink());
        } else {
            e->engine.set_diagnostic_sink(
                [e](swk::Severity sev, const std::string& msg) { forward(e, sev, msg); });
        }
        return static_cast<int>(SWK_OK);
    });
}

int swk_engine_set_dimension(swk_engine* e, int dim) {
    if (e == nullptr) return SWK_ERR_NULL_POINTER;
    if (dim <= 0 || dim > 4096) return SWK_ERR_INVALID_ARGUMENT;
    return guard([&] {
        e->engine.set_dimension(dim);
        return static_cast<int>(SWK_OK);
    });
}

int swk_engine_set_hamiltonian_packed(swk_engine* e, const double* data, int64_t count) {
    if (e == nullptr || data == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] { return st(e->engine.set_hamiltonian_packed(data, count)); });
}

int swk_engine_add_lindblad_triplets(swk_engine* e, const double* data, int64_t count) {
    if (e == nullptr || data == nullptr) return SWK_ERR_NULL_POINTER;
    if (count < 0) return SWK_ERR_INVALID_ARGUMENT;
    return guard([&] { return st(e->engine.add_lindblad_triplets(data, count)); });
}

int swk_engine_clear_operators(swk_engine* e) {
    if (e == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        e->engine.clear_operators();
        return static_cast<int>(SWK_OK);
    });
}

int swk_engine_set_coherent(swk_engine* e, int on) {
    if (e == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        e->engine.set_coherent(on != 0);
        return static_cast<int>(SWK_OK);
    });
}

int swk_engine_finalize(swk_engine* e) {
    if (e == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        e->engine.finalize();
        return static_cast<int>(SWK_OK);
    });
}

int swk_engine_dimension(const swk_engine* e) { return e ? e->engine.dimension() : 0; }
int swk_engine_lindblad_count(const swk_engine* e) { return e ? e->engine.lindblad_count() : 0; }
int swk_engine_is_finalized(const swk_engine* e) { return (e && e->engine.is_finalized()) ? 1 : 0; }
int swk_engine_last_substep_count(const swk_engine* e) {
    return e ? e->engine.last_substep_count() : 0;
}

int swk_engine_evolve(swk_engine* e, const double* rho_in, int64_t count, double dt, double max_dt,
                      double* rho_out) {
    if (e == nullptr || rho_in == nullptr || rho_out == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        const int dim = e->engine.dimension();
        if (dim == 0) {
            forward(e, swk::Severity::Warning, "QuantumEvolutionEngine: set_dimension first!");
            return static_cast<int>(SWK_ERR_DIMENSION_NOT_SET);
        }
        swk::CMatrix rho;
        const swk::DiagnosticSink sink = [e](swk::Severity sev, const std::string& msg) {
            forward(e, sev, msg);
        };
        if (!swk::unpack_dense(rho_in, count, dim, rho, &sink)) {
            return static_cast<int>(SWK_ERR_SIZE_MISMATCH);
        }
        const swk::Status s = e->engine.evolve(rho, dt, max_dt);
        if (s == swk::Status::Ok) swk::pack_dense(rho, dim, rho_out);
        return st(s);
    });
}

int swk_purity(const double* rho, int64_t count, int dim, double* out) {
    if (out == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        swk::CMatrix m;
        int s = unpack(rho, count, dim, m);
        if (s != SWK_OK) return s;
        *out = swk::purity(m);
        return static_cast<int>(SWK_OK);
    });
}

int swk_trace(const double* rho, int64_t count, int dim, double* out_re_im) {
    if (out_re_im == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        swk::CMatrix m;
        int s = unpack(rho, count, dim, m);
        if (s != SWK_OK) return s;
        const swk::Complex t = swk::trace(m);
        out_re_im[0] = t.real();
        out_re_im[1] = t.imag();
        return static_cast<int>(SWK_OK);
    });
}

int swk_bloch_metrics(const double* rho, int64_t count, int num_qubits, double* out) {
    if (out == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        swk::CMatrix m;
        int s = unpack_qubits(rho, count, num_qubits, m);
        if (s != SWK_OK) return s;
        const std::vector<double> v = swk::bloch_metrics(m, num_qubits);
        if (v.size() != static_cast<std::size_t>(num_qubits) * swk::kBlochStride)
            return static_cast<int>(SWK_ERR_INTERNAL);
        for (std::size_t i = 0; i < v.size(); i++) out[i] = v[i];
        return static_cast<int>(SWK_OK);
    });
}

int swk_mutual_information_all(const double* rho, int64_t count, int num_qubits, double* out) {
    if (out == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        swk::CMatrix m;
        int s = unpack_qubits(rho, count, num_qubits, m);
        if (s != SWK_OK) return s;
        const std::vector<double> v = swk::mutual_information_all(m, num_qubits);
        for (std::size_t i = 0; i < v.size(); i++) out[i] = v[i];
        return static_cast<int>(SWK_OK);
    });
}

int swk_marginal(const double* rho, int64_t count, int qubit, int num_qubits, int pole,
                 double* out) {
    if (out == nullptr) return SWK_ERR_NULL_POINTER;
    return guard([&] {
        swk::CMatrix m;
        int s = unpack_qubits(rho, count, num_qubits, m);
        if (s != SWK_OK) return s;
        double p = 0.0;
        s = st(swk::marginal(m, qubit, num_qubits, pole, p));
        if (s == SWK_OK) *out = p;
        return s;
    });
}

int swk_project_qubit(double* rho, int64_t count, int qubit, int num_qubits, int pole) {
    return guard([&] {
        swk::CMatrix m;
        int s = unpack_qubits(rho, count, num_qubits, m);
        if (s != SWK_OK) return s;
        s = st(swk::project_qubit(m, qubit, num_qubits, pole));
        if (s == SWK_OK) swk::pack_dense(m, 1 << num_qubits, rho);
        return s;
    });
}

int swk_drain_qubit(double* rho, int64_t count, int qubit, int num_qubits, int pole, double eta) {
    return guard([&] {
        swk::CMatrix m;
        int s = unpack_qubits(rho, count, num_qubits, m);
        if (s != SWK_OK) return s;
        s = st(swk::drain_qubit(m, qubit, num_qubits, pole, eta));
        if (s == SWK_OK) swk::pack_dense(m, 1 << num_qubits, rho);
        return s;
    });
}

int swk_born_outcome(double p_north, double u) { return swk::born_outcome(p_north, u); }

}  // extern "C"
