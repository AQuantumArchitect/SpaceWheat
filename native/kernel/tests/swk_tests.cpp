// Standalone tests for the swk kernel. No test framework: a tiny CHECK macro,
// PASS/FAIL lines, non-zero exit status on any failure.
#include "swk/swk.hpp"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

namespace swk_test {
double second_tu_purity();
}

static int g_checks = 0;
static int g_failures = 0;
static const char* g_current = "";

#define CHECK(cond)                                                                      \
    do {                                                                                 \
        ++g_checks;                                                                      \
        if (!(cond)) {                                                                   \
            ++g_failures;                                                                \
            std::printf("FAIL  %s: %s (line %d)\n", g_current, #cond, __LINE__);         \
        }                                                                                \
    } while (0)

#define CHECK_NEAR(a, b, tol) CHECK(std::fabs((a) - (b)) <= (tol))

using swk::CMatrix;
using swk::Complex;
using swk::Severity;
using swk::Status;

namespace {

const double kPi = 3.14159265358979323846;

struct Diag {
    int warnings = 0;
    int errors = 0;
    std::string last;
};

swk::DiagnosticSink sink_into(Diag& d) {
    return [&d](Severity s, const std::string& msg) {
        if (s == Severity::Warning) d.warnings++;
        else d.errors++;
        d.last = msg;
    };
}

std::vector<double> packed(const CMatrix& m) {
    std::vector<double> v(static_cast<std::size_t>(2 * m.rows() * m.rows()));
    swk::pack_dense(m, static_cast<int>(m.rows()), v.data());
    return v;
}

CMatrix ket_density(const std::vector<Complex>& psi) {
    int n = static_cast<int>(psi.size());
    CMatrix rho(n, n);
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) rho(i, j) = psi[i] * std::conj(psi[j]);
    return rho;
}

CMatrix sigma_x() {
    CMatrix m = CMatrix::Zero(2, 2);
    m(0, 1) = 1.0;
    m(1, 0) = 1.0;
    return m;
}

// Deterministic pseudo-random valid density matrix (A A^dagger / Tr).
CMatrix make_state(int dim, unsigned seed) {
    unsigned s = seed * 2654435761u + 12345u;
    auto next = [&s]() {
        s = s * 1664525u + 1013904223u;
        return (static_cast<double>((s >> 8) & 0xFFFF) / 65535.0) - 0.5;
    };
    CMatrix A(dim, dim);
    for (int i = 0; i < dim; i++)
        for (int j = 0; j < dim; j++) A(i, j) = Complex(next(), next());
    CMatrix rho = A * A.adjoint();
    double tr = 0.0;
    for (int i = 0; i < dim; i++) tr += rho(i, i).real();
    return rho / tr;
}

CMatrix random_hermitian(int dim, unsigned seed) {
    CMatrix A = make_state(dim, seed) - make_state(dim, seed + 99) * 0.7;
    return (A + A.adjoint()) * 0.5;
}

double max_abs_diff(const CMatrix& a, const CMatrix& b) {
    if (a.rows() != b.rows() || a.cols() != b.cols()) return 1e300;
    double m = 0.0;
    for (int i = 0; i < a.rows(); i++)
        for (int j = 0; j < a.cols(); j++) m = std::max(m, std::abs(a(i, j) - b(i, j)));
    return m;
}

int bit_of(int index, int qubit, int n) { return (index >> (n - 1 - qubit)) & 1; }

// Brute-force reduced matrix of the given qubits (first listed = most significant digit).
CMatrix brute_reduced(const CMatrix& rho, const std::vector<int>& qs, int n) {
    int k = static_cast<int>(qs.size());
    int side = 1 << k;
    CMatrix out = CMatrix::Zero(side, side);
    int dim = 1 << n;
    int keep_mask = 0;
    for (int q : qs) keep_mask |= 1 << (n - 1 - q);
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            if ((i & ~keep_mask) != (j & ~keep_mask)) continue;
            int ri = 0, rj = 0;
            for (int t = 0; t < k; t++) {
                ri = (ri << 1) | bit_of(i, qs[t], n);
                rj = (rj << 1) | bit_of(j, qs[t], n);
            }
            out(ri, rj) += rho(i, j);
        }
    }
    return out;
}

CMatrix to_dyn(const Eigen::Matrix<Complex, 4, 4>& m) { return CMatrix(m); }
CMatrix to_dyn(const Eigen::Matrix<Complex, 2, 2>& m) { return CMatrix(m); }

// --------------------------------------------------------------------------

void test_link_two_tus() {
    g_current = "two_translation_units";
    CHECK_NEAR(swk_test::second_tu_purity(), 0.5, 1e-12);
}

void test_pack_unpack() {
    g_current = "pack_unpack";
    CMatrix rho = make_state(4, 1);
    std::vector<double> p = packed(rho);
    CHECK(p.size() == 32);
    CHECK(p[0] == rho(0, 0).real() && p[1] == rho(0, 0).imag());
    CHECK(p[2] == rho(0, 1).real() && p[3] == rho(0, 1).imag());  // row-major interleaved

    CMatrix back;
    CHECK(swk::unpack_dense(p.data(), static_cast<std::int64_t>(p.size()), 4, back));
    CHECK(max_abs_diff(back, rho) == 0.0);

    Diag d;
    swk::DiagnosticSink sink = sink_into(d);
    CMatrix bad = CMatrix::Ones(1, 1);
    CHECK(!swk::unpack_dense(p.data(), 31, 4, bad, &sink));
    CHECK(bad.rows() == 4 && bad.cols() == 4 && bad.norm() == 0.0);
    CHECK(d.errors == 1);
    CHECK(d.last.find("packed") != std::string::npos);

    CHECK(!swk::unpack_dense(p.data(), 32, 0, bad));
    CHECK(bad.rows() == 0 && bad.cols() == 0);
    CHECK(!swk::unpack_dense(p.data(), 32, -3, bad));
    CHECK(bad.rows() == 0);
}

void test_exact_unitary_matches_hand() {
    g_current = "exact_unitary_sigma_x";
    const double omega = 1.7;  // H = (omega/2) sigma_x
    const double dt = 0.6;
    CMatrix H = sigma_x() * (omega / 2.0);
    std::vector<double> hp = packed(H);

    swk::EvolutionEngine eng;
    eng.set_dimension(2);
    CHECK(eng.set_hamiltonian_packed(hp.data(), static_cast<std::int64_t>(hp.size())) == Status::Ok);
    eng.finalize();
    CHECK(eng.lindblad_count() == 0);
    CHECK(eng.is_finalized());

    CMatrix rho = ket_density({Complex(1, 0), Complex(0, 0)});
    CMatrix rho0 = rho;
    CHECK(eng.evolve(rho, dt, dt) == Status::Ok);

    // exp(-i H dt) = cos(th) I - i sin(th) sigma_x, th = omega*dt/2
    double th = omega * dt / 2.0;
    CMatrix U = CMatrix::Zero(2, 2);
    U(0, 0) = std::cos(th);
    U(1, 1) = std::cos(th);
    U(0, 1) = Complex(0.0, -std::sin(th));
    U(1, 0) = Complex(0.0, -std::sin(th));
    CMatrix expect = U * rho0 * U.adjoint();
    CHECK(max_abs_diff(rho, expect) < 1e-12);

    // Bloch vector: z = cos(omega t), y = -sin(omega t), x = 0.
    std::vector<double> b = swk::bloch_metrics(rho, 1);
    CHECK(b.size() == static_cast<std::size_t>(swk::kBlochStride));
    CHECK_NEAR(b[4], std::cos(omega * dt), 1e-12);
    CHECK_NEAR(b[3], -std::sin(omega * dt), 1e-12);
    CHECK_NEAR(b[2], 0.0, 1e-12);

    CHECK_NEAR(swk::purity(rho), 1.0, 1e-12);
    CHECK_NEAR(swk::trace(rho).real(), 1.0, 1e-12);
}

void test_closed_system_conserves() {
    g_current = "closed_system_conserves_trace_purity";
    const int dim = 8;
    CMatrix H = random_hermitian(dim, 3);
    std::vector<double> hp = packed(H);
    swk::EvolutionEngine eng;
    eng.set_dimension(dim);
    CHECK(eng.set_hamiltonian_packed(hp.data(), static_cast<std::int64_t>(hp.size())) == Status::Ok);
    eng.finalize();

    std::vector<Complex> psi(dim);
    for (int i = 0; i < dim; i++) psi[i] = Complex(0.1 * (i + 1), -0.05 * i);
    double nrm = 0.0;
    for (auto& c : psi) nrm += std::norm(c);
    for (auto& c : psi) c /= std::sqrt(nrm);
    CMatrix rho = ket_density(psi);

    for (int step = 0; step < 50; step++) CHECK(eng.evolve(rho, 0.137, 0.137) == Status::Ok);
    CHECK_NEAR(swk::trace(rho).real(), 1.0, 1e-11);
    CHECK_NEAR(swk::trace(rho).imag(), 0.0, 1e-11);
    CHECK_NEAR(swk::purity(rho), 1.0, 1e-11);
}

void test_rk4_rabi() {
    g_current = "rk4_rabi_matches_closed_form";
    // A Lindblad with no surviving entries forces the RK4 path with a purely coherent generator.
    const double omega = 2.0;
    CMatrix H = sigma_x() * (omega / 2.0);
    std::vector<double> hp = packed(H);
    swk::EvolutionEngine eng;
    eng.set_dimension(2);
    CHECK(eng.set_hamiltonian_packed(hp.data(), 8) == Status::Ok);
    double zero_trip[4] = {0, 1, 0.0, 0.0};
    CHECK(eng.add_lindblad_triplets(zero_trip, 4) == Status::Ok);
    CHECK(eng.lindblad_count() == 1);
    eng.finalize();

    CMatrix rho = ket_density({Complex(1, 0), Complex(0, 0)});
    const double dt = 0.05;
    const int steps = 20;  // t = 1
    for (int i = 0; i < steps; i++) CHECK(eng.evolve(rho, dt, dt) == Status::Ok);
    std::vector<double> b = swk::bloch_metrics(rho, 1);
    CHECK_NEAR(b[4], std::cos(omega * 1.0), 1e-5);
    CHECK_NEAR(b[3], -std::sin(omega * 1.0), 1e-5);
    CHECK(eng.last_substep_count() >= 1);
}

void test_amplitude_damping() {
    g_current = "amplitude_damping_rate";
    const double gamma = 0.8;
    swk::EvolutionEngine eng;
    eng.set_dimension(2);
    // L = sqrt(gamma) |0><1|  -> triplet (row 0, col 1)
    double trip[4] = {0, 1, std::sqrt(gamma), 0.0};
    CHECK(eng.add_lindblad_triplets(trip, 4) == Status::Ok);
    eng.finalize();

    CMatrix rho = ket_density({Complex(0, 0), Complex(1, 0)});  // |1>
    const double dt = 0.1;
    const int steps = 10;
    for (int i = 0; i < steps; i++) {
        CHECK(eng.evolve(rho, dt, dt) == Status::Ok);
        CHECK_NEAR(swk::trace(rho).real(), 1.0, 1e-12);
        CHECK(swk::purity(rho) <= 1.0 + 1e-12);
    }
    double t = dt * steps;
    CHECK_NEAR(rho(1, 1).real(), std::exp(-gamma * t), 1e-5);
    CHECK_NEAR(rho(0, 0).real(), 1.0 - std::exp(-gamma * t), 1e-5);
}

void test_open_system_single_interval() {
    g_current = "open_system_evolve_dt_dt";
    const int dim = 4;
    CMatrix H = random_hermitian(dim, 7);
    std::vector<double> hp = packed(H);
    swk::EvolutionEngine eng;
    eng.set_dimension(dim);
    CHECK(eng.set_hamiltonian_packed(hp.data(), static_cast<std::int64_t>(hp.size())) == Status::Ok);
    double trip[8] = {0, 1, 0.9, 0.0, 2, 3, 0.0, 0.6};
    CHECK(eng.add_lindblad_triplets(trip, 8) == Status::Ok);
    eng.finalize();

    std::vector<Complex> psi = {Complex(0.5, 0), Complex(0.5, 0), Complex(0.5, 0), Complex(0.5, 0)};
    CMatrix rho = ket_density(psi);
    CHECK(eng.evolve(rho, 1.0, 1.0) == Status::Ok);
    CHECK_NEAR(swk::trace(rho).real(), 1.0, 1e-12);
    CHECK(swk::purity(rho) <= 1.0 + 1e-12);
    CHECK(eng.last_substep_count() >= 1 && eng.last_substep_count() <= swk::EvolutionEngine::MAX_SUBSTEPS);
}

void test_set_coherent_false() {
    g_current = "set_coherent_false_skips_h";
    CMatrix H = sigma_x() * 1.3;
    std::vector<double> hp = packed(H);
    swk::EvolutionEngine eng;
    eng.set_dimension(2);
    CHECK(eng.set_hamiltonian_packed(hp.data(), 8) == Status::Ok);
    eng.set_coherent(false);
    eng.finalize();
    CMatrix rho = ket_density({Complex(1, 0), Complex(0, 0)});
    CMatrix rho0 = rho;
    CHECK(eng.evolve(rho, 0.5, 0.5) == Status::Ok);
    CHECK(max_abs_diff(rho, rho0) < 1e-12);  // H skipped: nothing moves

    eng.set_coherent(true);
    rho = rho0;
    CHECK(eng.evolve(rho, 0.5, 0.5) == Status::Ok);
    CHECK(max_abs_diff(rho, rho0) > 0.1);  // H applied: state rotates
}

void test_substep_quirk() {
    g_current = "last_substep_count_quirk";
    swk::EvolutionEngine eng;
    eng.set_dimension(2);
    double trip[4] = {0, 1, 1.0, 0.0};
    eng.add_lindblad_triplets(trip, 4);
    eng.finalize();
    CMatrix rho = ket_density({Complex(0, 0), Complex(1, 0)});
    CHECK(eng.evolve(rho, 0.1, 0.1) == Status::Ok);
    int n = eng.last_substep_count();
    CHECK(n >= 1);

    // Switch to the exact-unitary path: the counter must NOT be reset.
    eng.clear_operators();
    CMatrix H = sigma_x();
    std::vector<double> hp = packed(H);
    CHECK(eng.set_hamiltonian_packed(hp.data(), 8) == Status::Ok);
    eng.finalize();
    CHECK(eng.evolve(rho, 0.1, 0.1) == Status::Ok);
    CHECK(eng.last_substep_count() == n);

    // RK4 path resets to 0 first (dt = 0 takes no substeps).
    eng.set_coherent(false);
    CHECK(eng.evolve(rho, 0.0, 0.0) == Status::Ok);
    CHECK(eng.last_substep_count() == 0);
}

void test_guards() {
    g_current = "size_and_range_guards";
    Diag d;
    swk::EvolutionEngine eng;
    eng.set_diagnostic_sink(sink_into(d));

    // Before set_dimension.
    double dummy[8] = {0};
    CHECK(eng.set_hamiltonian_packed(dummy, 8) == Status::DimensionNotSet);
    CHECK(d.warnings == 1);
    CHECK(d.last == "QuantumEvolutionEngine: set_dimension first!");
    CHECK(eng.add_lindblad_triplets(dummy, 4) == Status::DimensionNotSet);
    CHECK(d.warnings == 2);

    eng.set_dimension(2);

    // Not finalized.
    CMatrix rho = ket_density({Complex(1, 0), Complex(0, 0)});
    CHECK(eng.evolve(rho, 0.1, 0.1) == Status::NotFinalized);
    CHECK(d.warnings == 3);
    CHECK(d.last == "QuantumEvolutionEngine: call finalize() first!");

    // Mis-sized Hamiltonian.
    CHECK(eng.set_hamiltonian_packed(dummy, 6) == Status::SizeMismatch);
    CHECK(d.errors == 1);
    CHECK(d.last.find("H size mismatch (got 6, expected 8 for dim 2)") != std::string::npos);
    CHECK(!eng.has_hamiltonian());

    // Out-of-range triplets refused, in-range ones kept.
    double trip[12] = {0, 1, 1.0, 0.0,   5, 0, 1.0, 0.0,   -1, 1, 1.0, 0.0};
    CHECK(eng.add_lindblad_triplets(trip, 12) == Status::IndexOutOfRange);
    CHECK(d.errors == 3);
    CHECK(d.last.find("index (-1,1) out of range for dim 2") != std::string::npos);
    CHECK(eng.lindblad_count() == 1);

    // Mis-sized rho after finalize.
    eng.finalize();
    CMatrix big = CMatrix::Identity(4, 4) * 0.25;
    CHECK(eng.evolve(big, 0.1, 0.1) == Status::SizeMismatch);
    CHECK(d.warnings == 4);
    CHECK(big.rows() == 4 && big(0, 0).real() == 0.25);

    // No sink installed: nothing crashes.
    swk::EvolutionEngine quiet;
    CMatrix r2 = CMatrix::Identity(2, 2) * 0.5;
    CHECK(quiet.evolve(r2, 0.1, 0.1) == Status::NotFinalized);
}

void test_partial_traces() {
    g_current = "partial_traces_vs_brute_force";
    for (int n = 2; n <= 4; n++) {
        CMatrix rho = make_state(1 << n, 40 + n);
        for (int q = 0; q < n; q++) {
            CMatrix ref = brute_reduced(rho, {q}, n);
            CHECK(max_abs_diff(swk::partial_trace_single(rho, q, n), ref) < 1e-12);
            CHECK(max_abs_diff(to_dyn(swk::partial_trace_single_2x2(rho, q, n)), ref) < 1e-12);
        }
        for (int a = 0; a < n; a++) {
            for (int b = 0; b < n; b++) {
                if (a == b) continue;
                CMatrix ref = brute_reduced(rho, {a, b}, n);
                // Quirk kept from the original: the dynamic complement variant always orders its basis
                // (lower qubit index, higher qubit index), whatever order the caller passes.
                CMatrix ref_lohi = brute_reduced(rho, {std::min(a, b), std::max(a, b)}, n);
                CHECK(max_abs_diff(swk::partial_trace_complement(rho, a, b, n), ref_lohi) < 1e-12);
                CHECK(max_abs_diff(to_dyn(swk::partial_trace_pair_4x4(rho, a, b, n)), ref) < 1e-12);
                CHECK(max_abs_diff(to_dyn(swk::partial_trace_pair(rho, a, b, n)), ref) < 1e-12);
            }
        }
    }
}

void test_msb_convention() {
    g_current = "msb_qubit_convention";
    // 2 qubits, qubit 0 = |1>, qubit 1 = |0>  -> basis index 0b10 = 2.
    CMatrix rho = CMatrix::Zero(4, 4);
    rho(2, 2) = 1.0;
    double p = -1.0;
    CHECK(swk::marginal(rho, 0, 2, 1, p) == Status::Ok);
    CHECK(p == 1.0);
    CHECK(swk::marginal(rho, 0, 2, 0, p) == Status::Ok);
    CHECK(p == 0.0);
    CHECK(swk::marginal(rho, 1, 2, 0, p) == Status::Ok);
    CHECK(p == 1.0);
    CHECK(swk::marginal(rho, 1, 2, 1, p) == Status::Ok);
    CHECK(p == 0.0);

    std::vector<double> b = swk::bloch_metrics(rho, 2);
    CHECK_NEAR(b[0 * swk::kBlochStride + 4], -1.0, 1e-15);  // qubit 0 south: z = -1
    CHECK_NEAR(b[1 * swk::kBlochStride + 4], 1.0, 1e-15);   // qubit 1 north: z = +1
}

void test_bloch() {
    g_current = "bloch_stride_and_values";
    CHECK(swk::kBlochStride == 9);
    const double s = 1.0 / std::sqrt(2.0);

    std::vector<double> b0 = swk::bloch_metrics(ket_density({Complex(1, 0), Complex(0, 0)}), 1);
    CHECK(b0.size() == 9);
    CHECK_NEAR(b0[0], 1.0, 1e-15);
    CHECK_NEAR(b0[1], 0.0, 1e-15);
    CHECK_NEAR(b0[4], 1.0, 1e-15);
    CHECK_NEAR(b0[5], 1.0, 1e-15);
    CHECK_NEAR(b0[6], 0.0, 1e-15);
    CHECK_NEAR(b0[8], 0.0, 1e-15);

    std::vector<double> b1 = swk::bloch_metrics(ket_density({Complex(0, 0), Complex(1, 0)}), 1);
    CHECK_NEAR(b1[0], 0.0, 1e-15);
    CHECK_NEAR(b1[1], 1.0, 1e-15);
    CHECK_NEAR(b1[4], -1.0, 1e-15);
    CHECK_NEAR(b1[6], kPi, 1e-12);

    std::vector<double> bp = swk::bloch_metrics(ket_density({Complex(s, 0), Complex(s, 0)}), 1);
    CHECK_NEAR(bp[0], 0.5, 1e-15);
    CHECK_NEAR(bp[1], 0.5, 1e-15);
    CHECK_NEAR(bp[2], 1.0, 1e-15);
    CHECK_NEAR(bp[3], 0.0, 1e-15);
    CHECK_NEAR(bp[4], 0.0, 1e-15);
    CHECK_NEAR(bp[5], 1.0, 1e-15);
    CHECK_NEAR(bp[6], kPi / 2.0, 1e-12);
    CHECK_NEAR(bp[7], 0.0, 1e-15);
    CHECK_NEAR(bp[8], 1.0, 1e-15);

    // |+i> has y = +1 under the kernel's convention y = -2 Im(rho01)... check sign consistency.
    std::vector<double> by = swk::bloch_metrics(ket_density({Complex(s, 0), Complex(0, s)}), 1);
    CHECK_NEAR(by[3], 1.0, 1e-15);

    CHECK(swk::bloch_metrics(CMatrix::Identity(2, 2) * 0.5, 0).empty());
    CHECK(swk::bloch_metrics(CMatrix::Identity(2, 2) * 0.5, 3).empty());  // rho too small: refused
    CHECK(swk::bloch_metrics(make_state(8, 5), 3).size() == 27);
}

void test_measurement() {
    g_current = "measurement_project_drain";
    const int n = 3;
    CMatrix rho = make_state(1 << n, 11);

    // project pins the marginal
    for (int q = 0; q < n; q++) {
        for (int pole = 0; pole < 2; pole++) {
            CMatrix r = rho;
            double p_before = 0.0;
            swk::marginal(r, q, n, pole, p_before);
            CHECK(p_before > 0.0 && p_before < 1.0);
            CHECK(swk::project_qubit(r, q, n, pole) == Status::Ok);
            double p_after = 0.0, p_other = 0.0;
            swk::marginal(r, q, n, pole, p_after);
            swk::marginal(r, q, n, 1 - pole, p_other);
            CHECK_NEAR(p_after, 1.0, 1e-12);
            CHECK_NEAR(p_other, 0.0, 1e-12);
            CHECK_NEAR(swk::trace(r).real(), 1.0, 1e-12);
            // rho_ij = P rho P / p
            for (int i = 0; i < (1 << n); i++)
                for (int j = 0; j < (1 << n); j++) {
                    bool in = bit_of(i, q, n) == pole && bit_of(j, q, n) == pole;
                    Complex want = in ? rho(i, j) / p_before : Complex(0, 0);
                    CHECK(std::abs(r(i, j) - want) < 1e-12);
                }
        }
    }

    // drain eta = 0 is a no-op (bit exact)
    CMatrix r0 = rho;
    CHECK(swk::drain_qubit(r0, 1, n, 0, 0.0) == Status::Ok);
    CHECK(max_abs_diff(r0, rho) == 0.0);
    CHECK(swk::drain_qubit(r0, 1, n, 0, 1e-13) == Status::Ok);
    CHECK(max_abs_diff(r0, rho) == 0.0);
    CHECK(swk::drain_qubit(r0, 1, n, 0, -5.0) == Status::Ok);  // clamps to 0
    CHECK(max_abs_diff(r0, rho) == 0.0);

    // drain eta = 1 equals projection onto the other pole
    CMatrix r1 = rho, rp = rho;
    CHECK(swk::drain_qubit(r1, 1, n, 0, 1.0) == Status::Ok);
    CHECK(swk::project_qubit(rp, 1, n, 1) == Status::Ok);
    CHECK(max_abs_diff(r1, rp) < 1e-12);
    CMatrix r2 = rho;
    CHECK(swk::drain_qubit(r2, 1, n, 0, 7.5) == Status::Ok);  // clamps to 1
    CHECK(max_abs_diff(r2, rp) < 1e-12);

    // intermediate eta: trace 1, drained pole shrinks, hand-computed 1-qubit case
    CMatrix h = ket_density({Complex(std::sqrt(0.5), 0), Complex(std::sqrt(0.5), 0)});
    CHECK(swk::drain_qubit(h, 0, 1, 0, 0.5) == Status::Ok);
    // before: [[.5,.5],[.5,.5]]; after scale: rho00 = .25, rho01 = rho10 = .5*sqrt(.5), rho11 = .5; tr = .75
    double tr = 0.75;
    CHECK_NEAR(h(0, 0).real(), 0.25 / tr, 1e-14);
    CHECK_NEAR(h(0, 1).real(), 0.5 * std::sqrt(0.5) / tr, 1e-14);
    CHECK_NEAR(h(1, 1).real(), 0.5 / tr, 1e-14);
    CHECK_NEAR(swk::trace(h).real(), 1.0, 1e-14);

    // range errors
    Diag d;
    swk::DiagnosticSink sink = sink_into(d);
    CMatrix keep = rho;
    CHECK(swk::drain_qubit(keep, 3, n, 0, 0.5, &sink) == Status::IndexOutOfRange);
    CHECK(swk::drain_qubit(keep, -1, n, 0, 0.5, &sink) == Status::IndexOutOfRange);
    CHECK(swk::project_qubit(keep, 0, n, 2, &sink) == Status::InvalidArgument);
    CHECK(swk::project_qubit(keep, 0, 2, 0, &sink) == Status::SizeMismatch);
    CHECK(swk::marginal(keep, 0, 0, 0, tr, &sink) == Status::InvalidArgument);
    CHECK(d.errors == 5);
    CHECK(max_abs_diff(keep, rho) == 0.0);

    // near-zero trace: left alone with a warning
    CMatrix z = CMatrix::Zero(2, 2);
    d = Diag();
    CHECK(swk::renormalize_trace(z, &sink) == Status::Ok);
    CHECK(d.warnings == 1);
    CHECK(z.norm() == 0.0);

    // born outcome
    CHECK(swk::born_outcome(0.3, 0.0) == 0);
    CHECK(swk::born_outcome(0.3, 0.29) == 0);
    CHECK(swk::born_outcome(0.3, 0.3) == 1);
    CHECK(swk::born_outcome(0.3, 0.9) == 1);
    CHECK(swk::born_outcome(0.0, 0.0) == 1);
    CHECK(swk::born_outcome(1.0, 0.999) == 0);
}

void test_entropy_and_mi() {
    g_current = "entropy_and_mutual_information";
    // Bell pair on qubits 0,1 plus a product spectator qubit 2 in |0>.
    const double s = 1.0 / std::sqrt(2.0);
    std::vector<Complex> psi(8, Complex(0, 0));
    psi[0] = s;  // |000>
    psi[6] = s;  // |110>
    CMatrix rho = ket_density(psi);

    CMatrix r2 = swk::partial_trace_single(rho, 0, 3);
    CHECK_NEAR(swk::von_neumann_entropy(r2), 1.0, 1e-12);
    CHECK_NEAR(swk::von_neumann_entropy(rho), 0.0, 1e-12);

    std::vector<double> mi = swk::mutual_information_all(rho, 3);
    CHECK(mi.size() == 3);
    CHECK_NEAR(mi[0], 2.0, 1e-12);  // (0,1)
    CHECK_NEAR(mi[1], 0.0, 1e-12);  // (0,2)
    CHECK_NEAR(mi[2], 0.0, 1e-12);  // (1,2)
    CHECK_NEAR(swk::mutual_information(rho, 0, 1, 3), 2.0, 1e-12);

    // cached-entropy variant agrees with the per-pair variant on a generic state
    CMatrix g = make_state(8, 21);
    std::vector<double> all = swk::mutual_information_all(g, 3);
    int idx = 0;
    for (int i = 0; i < 3; i++)
        for (int j = i + 1; j < 3; j++) CHECK_NEAR(all[idx++], swk::mutual_information(g, i, j, 3), 1e-12);

    CHECK(swk::mutual_information_all(g, 1).empty());
    CHECK(swk::mutual_information_all(g, 0).empty());
    CHECK(swk::mutual_information_all(g, 5).size() == 10);  // rho too small: zeros, no overread
    CHECK(swk::mutual_information_all(g, 5)[0] == 0.0);

    // MiScreen
    swk::MiScreen screen;
    CHECK(screen.candidates().empty());
    std::vector<double> full = screen.compute(rho, 3, 1.0, true);  // high purity: linear path
    CHECK(full.size() == 3);
    CHECK(screen.candidates().size() == 1 && screen.candidates()[0] == 0);
    CHECK_NEAR(full[0], 1.0, 1e-12);  // linear MI of a Bell pair: 1 - .5 - .5 + 1
    screen.clear();
    CHECK(screen.candidates().empty());
}

void test_mi_screen_values() {
    g_current = "mi_screen_adaptive";
    const double s = 1.0 / std::sqrt(2.0);
    std::vector<Complex> psi(8, Complex(0, 0));
    psi[0] = s;
    psi[6] = s;
    CMatrix rho = ket_density(psi);

    swk::MiScreen screen;
    // Low purity argument forces the eigen-decomposition path.
    std::vector<double> full = screen.compute(rho, 3, 0.5, true);
    CHECK_NEAR(full[0], 2.0, 1e-12);
    CHECK_NEAR(full[1], 0.0, 1e-12);
    CHECK_NEAR(full[2], 0.0, 1e-12);
    CHECK(screen.candidates().size() == 1);

    // Subsequent frame without scan: only the candidate is computed
    std::vector<double> next = screen.compute(rho, 3, 0.5, false);
    CHECK_NEAR(next[0], 2.0, 1e-12);
    CHECK(next[1] == 0.0 && next[2] == 0.0);

    // After clear() with no scan, nothing is a candidate
    screen.clear();
    std::vector<double> none = screen.compute(rho, 3, 0.5, false);
    CHECK(none[0] == 0.0);

    // Linear approximation, high purity: 1 - P_A - P_B + P_AB = 1 - .5 - .5 + 1 = 1
    swk::MiScreen lin;
    std::vector<double> l = lin.compute(rho, 3, 0.99, true);
    CHECK_NEAR(l[0], 1.0, 1e-12);

    CHECK(lin.compute(rho, 1, 0.5, true).empty());
}

void test_eigen_and_cos2() {
    g_current = "eigen_analysis_and_cos2";
    CMatrix rho = CMatrix::Zero(3, 3);
    rho(0, 0) = 0.2;
    rho(1, 1) = 0.5;
    rho(2, 2) = 0.3;
    swk::EigenResult e = swk::eigen_analysis(rho);
    CHECK(e.ok && e.dimension == 3);
    CHECK(e.eigenvalues.size() == 3);
    CHECK_NEAR(e.eigenvalues[0], 0.5, 1e-14);
    CHECK_NEAR(e.eigenvalues[1], 0.3, 1e-14);
    CHECK_NEAR(e.eigenvalues[2], 0.2, 1e-14);
    CHECK_NEAR(e.dominant_eigenvalue, 0.5, 1e-14);
    CHECK(e.dominant_eigenvector.size() == 6);
    CHECK_NEAR(std::norm(Complex(e.dominant_eigenvector[2], e.dominant_eigenvector[3])), 1.0, 1e-14);

    swk::EigenResult bad = swk::eigen_analysis(CMatrix());
    CHECK(!bad.ok);
    swk::EigenResult nonsq = swk::eigen_analysis(CMatrix::Zero(2, 3));
    CHECK(!nonsq.ok);

    double a[4] = {1.0, 0.0, 0.0, 0.0};
    double b[4] = {0.0, 0.0, 1.0, 0.0};
    double c[4] = {0.6, 0.0, 0.0, 0.8};
    CHECK_NEAR(swk::cos2_similarity(a, a, 4), 1.0, 1e-15);
    CHECK_NEAR(swk::cos2_similarity(a, b, 4), 0.0, 1e-15);
    CHECK_NEAR(swk::cos2_similarity(a, c, 4), 0.36, 1e-15);
    CHECK(swk::cos2_similarity(a, b, 0) == 0.0);
}

void test_enforce_density() {
    g_current = "enforce_density_matrix";
    CMatrix rho = CMatrix::Zero(2, 2);
    rho(0, 0) = 0.9;
    rho(1, 1) = -0.1;  // negative diagonal: clamped and its coherences zeroed
    rho(0, 1) = Complex(0.2, 0.1);
    rho(1, 0) = Complex(0.2, -0.1);
    swk::enforce_density_matrix(rho);
    CHECK(rho(1, 1) == Complex(0, 0));
    CHECK(rho(0, 1) == Complex(0, 0) && rho(1, 0) == Complex(0, 0));
    CHECK_NEAR(rho(0, 0).real(), 1.0, 1e-15);

    CMatrix big = CMatrix::Zero(2, 2);  // purity > 1: coherences capped
    big(0, 0) = 0.5;
    big(1, 1) = 0.5;
    big(0, 1) = 0.9;
    big(1, 0) = 0.9;
    swk::enforce_density_matrix(big);
    CHECK(swk::purity(big) <= 1.0 + 1e-12);
    CHECK_NEAR(swk::trace(big).real(), 1.0, 1e-14);
}

}  // namespace

#define RUN(fn) do { int before_ = g_failures; fn(); std::printf("%s  %s\n", g_failures == before_ ? "PASS" : "FAIL", #fn); } while (0)

int main() {
    RUN(test_link_two_tus);
    RUN(test_pack_unpack);
    RUN(test_exact_unitary_matches_hand);
    RUN(test_closed_system_conserves);
    RUN(test_rk4_rabi);
    RUN(test_amplitude_damping);
    RUN(test_open_system_single_interval);
    RUN(test_set_coherent_false);
    RUN(test_substep_quirk);
    RUN(test_guards);
    RUN(test_partial_traces);
    RUN(test_msb_convention);
    RUN(test_bloch);
    RUN(test_measurement);
    RUN(test_entropy_and_mi);
    RUN(test_mi_screen_values);
    RUN(test_eigen_and_cos2);
    RUN(test_enforce_density);

    if (g_failures == 0) {
        std::printf("PASS  all %d checks\n", g_checks);
        return 0;
    }
    std::printf("FAIL  %d of %d checks failed\n", g_failures, g_checks);
    return 1;
}
