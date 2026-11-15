// swk/types.hpp - aliases, Status, diagnostics sink, pack / unpack.
//
// Depends on Eigen and the C++17 standard library only. Nothing here throws.
#ifndef SWK_TYPES_HPP
#define SWK_TYPES_HPP

#include <Eigen/Dense>
#include <Eigen/Sparse>

#include <complex>
#include <cstdint>
#include <functional>
#include <string>

namespace swk {

using Complex = std::complex<double>;
using CMatrix = Eigen::MatrixXcd;
using SparseC = Eigen::SparseMatrix<Complex, Eigen::RowMajor>;

enum class Status {
    Ok,
    DimensionNotSet,
    SizeMismatch,
    NotFinalized,
    IndexOutOfRange,
    InvalidArgument,
    EigenFailure
};

enum class Severity { Warning, Error };

// Diagnostics are plain text handed to a caller-supplied sink. An empty
// std::function means "discard".
using DiagnosticSink = std::function<void(Severity, const std::string&)>;

namespace detail {

// UTF-8 byte sequences for the two non-ASCII characters used in message text,
// spelled as escapes so the source is encoding-independent (MSVC included).
inline const char* rho_glyph() { return "\xCF\x81"; }          // U+03C1
inline const char* em_dash() { return "\xE2\x80\x94"; }        // U+2014

inline void emit(const DiagnosticSink* sink, Severity sev, const std::string& msg) {
    if (sink != nullptr && *sink) {
        (*sink)(sev, msg);
    }
}

inline std::string num(std::int64_t v) { return std::to_string(static_cast<long long>(v)); }

}  // namespace detail

// Unpack 2*dim*dim doubles (row-major, interleaved re/im) into `out`.
// On a size mismatch (or dim <= 0) returns false and sets `out` to a zero
// matrix (0x0 when dim <= 0), as the original engine did. If `sink` is given
// the original error text is sent to it as Severity::Error.
inline bool unpack_dense(const double* data, std::int64_t count, int dim, CMatrix& out,
                         const DiagnosticSink* sink = nullptr) {
    const std::int64_t expected = static_cast<std::int64_t>(2) * dim * dim;
    if (dim <= 0 || data == nullptr || count != expected) {
        detail::emit(sink, Severity::Error,
                     std::string("QuantumEvolutionEngine::unpack_dense: packed ") + detail::rho_glyph() +
                         " size mismatch (got " + detail::num(count) + ", expected " +
                         detail::num(expected) + " for dim " + std::to_string(dim) + ") " +
                         detail::em_dash() + " refusing to read, returning zero.");
        out = CMatrix::Zero(dim > 0 ? dim : 0, dim > 0 ? dim : 0);
        return false;
    }

    CMatrix mat(dim, dim);
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            mat(i, j) = Complex(data[idx], data[idx + 1]);
        }
    }
    out = mat;
    return true;
}

// Pack the top-left dim x dim block of `m` into `out` (2*dim*dim doubles).
inline void pack_dense(const CMatrix& m, int dim, double* out) {
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            int idx = (i * dim + j) * 2;
            out[idx] = m(i, j).real();
            out[idx + 1] = m(i, j).imag();
        }
    }
}

}  // namespace swk

#endif  // SWK_TYPES_HPP
