// swk/measurement.hpp - marginals, projective collapse, partial drain, Born outcome.
//
// Ported from the GDScript reference implementation (get_marginal, _project_qubit,
// drain_qubit, ComplexMatrix.renormalize_trace). The kernel owns no random numbers:
// the caller supplies the uniform sample to born_outcome.
//
// Conventions: qubit q of n lives at bit n-1-q; pole 0 is north, pole 1 is south.
// rho must be square with side 2^n. Range errors return a Status (and, when a sink
// is given, an Error diagnostic); rho is left untouched in that case.
#ifndef SWK_MEASUREMENT_HPP
#define SWK_MEASUREMENT_HPP

#include "types.hpp"

#include <cmath>
#include <complex>
#include <string>

namespace swk {

namespace detail {

// Validates (rho, qubit, num_qubits, pole). `who` names the caller in the message.
inline Status check_measure_args(const CMatrix& rho, int qubit, int num_qubits, int pole,
                                 const char* who, const DiagnosticSink* sink) {
    if (num_qubits < 1 || num_qubits > 30) {
        emit(sink, Severity::Error,
             std::string(who) + ": num_qubits " + std::to_string(num_qubits) + " out of range [1, 30]");
        return Status::InvalidArgument;
    }
    if (qubit < 0 || qubit >= num_qubits) {
        emit(sink, Severity::Error,
             std::string(who) + ": qubit " + std::to_string(qubit) + " out of range [0, " +
                 std::to_string(num_qubits) + ")");
        return Status::IndexOutOfRange;
    }
    if (pole != 0 && pole != 1) {
        emit(sink, Severity::Error,
             std::string(who) + ": pole " + std::to_string(pole) + " must be 0 or 1");
        return Status::InvalidArgument;
    }
    const int dim = 1 << num_qubits;
    if (rho.rows() != dim || rho.cols() != dim) {
        emit(sink, Severity::Error,
             std::string(who) + ": rho is " + std::to_string(rho.rows()) + "x" +
                 std::to_string(rho.cols()) + ", expected " + std::to_string(dim) + "x" +
                 std::to_string(dim));
        return Status::SizeMismatch;
    }
    return Status::Ok;
}

}  // namespace detail

// Scale rho so |Tr(rho)| = 1 (every element multiplied by 1/|Tr|). If |Tr| < 1e-14 the
// matrix is left unchanged, a Warning is sent to the sink, and Ok is returned (as the
// reference implementation returns silently apart from the warning).
inline Status renormalize_trace(CMatrix& rho, const DiagnosticSink* sink = nullptr) {
    const int n = static_cast<int>(rho.rows() < rho.cols() ? rho.rows() : rho.cols());
    double sum_re = 0.0;
    double sum_im = 0.0;
    for (int i = 0; i < n; i++) {
        sum_re += rho(i, i).real();
        sum_im += rho(i, i).imag();
    }
    double tr_val = std::sqrt(sum_re * sum_re + sum_im * sum_im);

    if (tr_val < 1e-14) {
        detail::emit(sink, Severity::Warning, "Cannot renormalize: trace is essentially zero");
        return Status::Ok;
    }

    double s = 1.0 / tr_val;
    for (int i = 0; i < rho.rows(); i++) {
        for (int j = 0; j < rho.cols(); j++) {
            rho(i, j) = Complex(rho(i, j).real() * s, rho(i, j).imag() * s);
        }
    }
    return Status::Ok;
}

// P(qubit = pole): sum of the real diagonal over basis states whose bit equals pole,
// clamped to [0, 1]. `out` is set to 0.0 on error.
inline Status marginal(const CMatrix& rho, int qubit, int num_qubits, int pole, double& out,
                       const DiagnosticSink* sink = nullptr) {
    out = 0.0;
    Status st = detail::check_measure_args(rho, qubit, num_qubits, pole, "swk::marginal", sink);
    if (st != Status::Ok) return st;

    const int dim = 1 << num_qubits;
    const int shift = num_qubits - 1 - qubit;
    double prob = 0.0;

    for (int i = 0; i < dim; i++) {
        if (((i >> shift) & 1) == pole) {
            prob += rho(i, i).real();
        }
    }

    out = prob < 0.0 ? 0.0 : (prob > 1.0 ? 1.0 : prob);
    return Status::Ok;
}

// Projective collapse: rho -> P rho P / |Tr(P rho P)|. Everything outside the
// (pole, pole) block is zeroed, then the trace is renormalised.
inline Status project_qubit(CMatrix& rho, int qubit, int num_qubits, int pole,
                            const DiagnosticSink* sink = nullptr) {
    Status st = detail::check_measure_args(rho, qubit, num_qubits, pole, "swk::project_qubit", sink);
    if (st != Status::Ok) return st;

    const int dim = 1 << num_qubits;
    const int shift = num_qubits - 1 - qubit;
    CMatrix rho_new = CMatrix::Zero(dim, dim);

    for (int i = 0; i < dim; i++) {
        int qubit_i = (i >> shift) & 1;
        if (qubit_i != pole) continue;

        for (int j = 0; j < dim; j++) {
            int qubit_j = (j >> shift) & 1;
            if (qubit_j != pole) continue;

            rho_new(i, j) = rho(i, j);
        }
    }

    rho = rho_new;
    return renormalize_trace(rho, sink);
}

// Partial ensemble measurement: populations of the (pole, pole) block scale by (1 - eta),
// coherences touching the pole by sqrt(1 - eta), the other block is untouched, then the
// trace is renormalised. eta is clamped to [0, 1]; eta < 1e-12 is a no-op returning Ok.
inline Status drain_qubit(CMatrix& rho, int qubit, int num_qubits, int pole, double eta,
                          const DiagnosticSink* sink = nullptr) {
    Status st = detail::check_measure_args(rho, qubit, num_qubits, pole, "swk::drain_qubit", sink);
    if (st != Status::Ok) return st;

    eta = eta < 0.0 ? 0.0 : (eta > 1.0 ? 1.0 : eta);
    if (eta < 1e-12) {
        return Status::Ok;  // No-op drain
    }

    const int dim = 1 << num_qubits;
    const int shift = num_qubits - 1 - qubit;
    const double pop_scale = 1.0 - eta;
    const double coh_scale = std::sqrt(1.0 - eta);

    for (int i = 0; i < dim; i++) {
        int qi = (i >> shift) & 1;
        for (int j = 0; j < dim; j++) {
            int qj = (j >> shift) & 1;

            if (qi == pole && qj == pole) {
                rho(i, j) = Complex(rho(i, j).real() * pop_scale, rho(i, j).imag() * pop_scale);
            } else if (qi == pole || qj == pole) {
                rho(i, j) = Complex(rho(i, j).real() * coh_scale, rho(i, j).imag() * coh_scale);
            }
        }
    }

    return renormalize_trace(rho, sink);
}

// Pole 0 (north) when u < p_north, else pole 1 (south). u is a uniform sample in [0, 1).
inline int born_outcome(double p_north, double u) { return u < p_north ? 0 : 1; }

}  // namespace swk

#endif  // SWK_MEASUREMENT_HPP
