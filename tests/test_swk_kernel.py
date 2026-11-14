"""Tests for the swk density-matrix kernel (native/kernel): standalone C++ tests,
the engine-independence guard, and the C interface through ctypes. Stdlib only."""
import importlib.util
import math
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
KERNEL = PROJECT_ROOT / "native" / "kernel"
SWK_PY = KERNEL / "python" / "swk.py"


# ---------------------------------------------------------------------------
# Guard test: needs no compiler.
# ---------------------------------------------------------------------------
def _kernel_files():
    for p in KERNEL.rglob("*"):
        if p.is_file() and "build" not in p.relative_to(KERNEL).parts:
            yield p


def test_kernel_is_engine_free() -> None:
    needle = "god" + "ot"  # spelled in two pieces so this file does not trip the check itself
    offenders = []
    for p in _kernel_files():
        if needle in p.read_bytes().decode("utf-8", "ignore").lower():
            offenders.append(str(p.relative_to(PROJECT_ROOT)))
    assert offenders == []

    bad = []
    for p in (KERNEL / "include").rglob("*"):
        if not p.is_file():
            continue
        for line in p.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if s.startswith("#") and s[1:].strip().startswith("include"):
                target = s[1:].strip()[len("include"):].strip().strip('<>"').lower()
                if target.startswith(needle) or "gd" + "extension" in target:
                    bad.append((str(p.name), s))
    assert bad == []


# ---------------------------------------------------------------------------
# Build fixture.
# ---------------------------------------------------------------------------
@pytest.fixture(scope="module")
def swk():
    make = shutil.which("mingw32-make") or shutil.which("make")
    if make is None or shutil.which("g++") is None:
        pytest.skip("make and g++ are required to build the kernel")
    proc = subprocess.run([make, "-C", str(KERNEL), "test", "capi"], capture_output=True,
                          text=True, timeout=900)
    assert proc.returncode == 0, proc.stdout[-2000:] + proc.stderr[-2000:]
    assert "all " in proc.stdout and "checks" in proc.stdout

    spec = importlib.util.spec_from_file_location("swk_ctypes", SWK_PY)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["swk_ctypes"] = mod
    spec.loader.exec_module(mod)
    mod.load()
    return mod


# ---------------------------------------------------------------------------
# Helpers.
# ---------------------------------------------------------------------------
def packed(rows):
    out = []
    for row in rows:
        for v in row:
            c = complex(v)
            out += [c.real, c.imag]
    return out


def ket_dm(psi):
    n = len(psi)
    return packed([[psi[i] * psi[j].conjugate() for j in range(n)] for i in range(n)])


def basis_dm(dim, k):
    return ket_dm([1.0 if i == k else 0.0 for i in range(dim)])


def run_engine(swk, dim, h=None, lindblads=(), rho=None, dt=1.0, max_dt=0.0, coherent=True):
    eng = swk.Engine()
    eng.set_dimension(dim)
    if h is not None:
        eng.set_hamiltonian_packed(packed(h))
    for trip in lindblads:
        eng.add_lindblad_triplets(trip)
    eng.set_coherent(coherent)
    eng.finalize()
    return eng, eng.evolve(rho, dt, max_dt)


# ---------------------------------------------------------------------------
# (a) Rabi oscillation.
# ---------------------------------------------------------------------------
def test_rabi_matches_closed_form(swk) -> None:
    # H = (W/2) sx, |psi0> = |0>. U = cos(a) I - i sin(a) sx with a = W t / 2, so
    # |psi> = (cos a, -i sin a). Then rho01 = psi0 * conj(psi1) = i sin a cos a
    # = i sin(W t) / 2. The kernel defines Bloch y = -2 Im rho01 = -sin(W t) and
    # z = rho00 - rho11 = cos^2 a - sin^2 a = cos(W t).
    W = 2.3
    for t in (0.0, 0.4, 1.0, 2.7):
        eng, rho = run_engine(swk, 2, h=[[0, W / 2], [W / 2, 0]], rho=basis_dm(2, 0), dt=t)
        b = swk.bloch_metrics(rho, 1)
        assert len(b) == swk.bloch_stride() == 9
        assert abs(b[4] - math.cos(W * t)) < 1e-12
        assert abs(b[3] - (-math.sin(W * t))) < 1e-12
        assert abs(b[2]) < 1e-12
        tr = swk.trace(rho, 2)
        assert abs(tr[0] - 1) < 1e-12 and abs(tr[1]) < 1e-12
        assert abs(swk.purity(rho, 2) - 1) < 1e-12


# ---------------------------------------------------------------------------
# (b) Closed 2-qubit evolution and last_substep_count.
# ---------------------------------------------------------------------------
def test_closed_two_qubit_and_substep_count(swk) -> None:
    h = [[0.3, 0.5, 0.2j, 0], [0.5, -0.1, 0, 0.4], [-0.2j, 0, 0.7, 0.6 + 0.1j],
         [0, 0.4, 0.6 - 0.1j, -0.5]]
    psi = [0.5, 0.5j, -0.5, 0.5]
    rho = ket_dm(psi)
    eng = swk.Engine()
    eng.set_dimension(4)
    eng.set_hamiltonian_packed(packed(h))
    assert not eng.is_finalized
    eng.finalize()
    assert eng.is_finalized and eng.dimension == 4 and eng.lindblad_count == 0
    for _ in range(5):
        rho = eng.evolve(rho, 0.37, 0.05)
    assert eng.last_substep_count == 0  # unitary path never touches it
    tr = swk.trace(rho, 4)
    assert abs(tr[0] - 1) < 1e-12 and abs(tr[1]) < 1e-12
    assert abs(swk.purity(rho, 4) - 1) < 1e-12

    # RK4 path (dissipative) sets the counter: dt/max_dt = 4 substeps at least, 16 at most-ish.
    eng.add_lindblad_triplets([0, 1, 0.1, 0])
    eng.finalize()
    rho = eng.evolve(rho, 0.4, 0.1)
    n_rk4 = eng.last_substep_count
    assert 4 <= n_rk4 <= 16
    # Dropping the operators returns to the unitary path, which leaves the counter alone.
    eng.clear_operators()
    eng.set_hamiltonian_packed(packed(h))
    eng.finalize()
    eng.evolve(rho, 0.4, 0.1)
    assert eng.last_substep_count == n_rk4
    eng.close()


# ---------------------------------------------------------------------------
# (c) Amplitude damping.
# ---------------------------------------------------------------------------
# Measured (gamma = 0.8, max_dt = 0.01): the error on the excited population against
# exp(-gamma t) is 9e-10 at t = 0.5, 2e-8 at t = 1 and 3e-7 at t = 2. The integrator
# never takes fewer than 16 substeps per call (floor step dt/16), so the error grows
# with t. We check t <= 1 against 1e-6, a 50x margin over the measured worst case.
def test_amplitude_damping_rate(swk) -> None:
    gamma = 0.8
    trip = [0, 1, math.sqrt(gamma), 0]  # L = sqrt(gamma) |0><1|, row 0 col 1
    for t in (0.5, 1.0):
        eng, rho = run_engine(swk, 2, lindblads=[trip], rho=basis_dm(2, 1), dt=t, max_dt=0.01)
        pop1 = swk.marginal(rho, 0, 1, 1)
        assert abs(pop1 - math.exp(-gamma * t)) < 1e-6
        tr = swk.trace(rho, 2)
        assert abs(tr[0] - 1) < 1e-6
        assert 1 <= eng.last_substep_count <= 16  # MAX_SUBSTEPS ceiling


# ---------------------------------------------------------------------------
# (d) project_qubit / marginal, Bell collapse.
# ---------------------------------------------------------------------------
def test_project_then_marginal(swk) -> None:
    s = 1 / math.sqrt(2)
    plus = ket_dm([s, s])
    out = swk.project_qubit(plus, 0, 1, 1)
    assert abs(swk.marginal(out, 0, 1, 1) - 1.0) < 1e-12
    assert abs(swk.marginal(out, 0, 1, 0)) < 1e-12

    bell = ket_dm([s, 0, 0, s])
    assert abs(swk.marginal(bell, 0, 2, 0) - 0.5) < 1e-12
    col = swk.project_qubit(bell, 0, 2, 1)
    assert abs(swk.marginal(col, 0, 2, 1) - 1.0) < 1e-12
    assert abs(swk.marginal(col, 1, 2, 1) - 1.0) < 1e-12  # qubit 1 collapsed too
    assert abs(swk.purity(col, 4) - 1) < 1e-12


# ---------------------------------------------------------------------------
# (e) drain_qubit.
# ---------------------------------------------------------------------------
def test_drain_eta_extremes(swk) -> None:
    s = 1 / math.sqrt(3)
    rho = ket_dm([s, s * 1j, s, 0])
    assert swk.drain_qubit(rho, 1, 2, 0, 0.0) == rho
    # eta = 1 empties the drained pole and keeps the other block, so it equals a
    # projection onto the OTHER pole (draining north == measuring south).
    drained = swk.drain_qubit(rho, 1, 2, 0, 1.0)
    proj = swk.project_qubit(rho, 1, 2, 1)
    assert max(abs(a - b) for a, b in zip(drained, proj)) < 1e-12
    half = swk.drain_qubit(rho, 1, 2, 0, 0.5)
    tr = swk.trace(half, 4)
    assert abs(tr[0] - 1) < 1e-12


# ---------------------------------------------------------------------------
# (f) born_outcome boundaries.
# ---------------------------------------------------------------------------
def test_born_outcome_boundaries(swk) -> None:
    p = 0.25
    below = math.nextafter(p, 0.0)
    above = math.nextafter(p, 1.0)
    assert swk.born_outcome(p, below) == 0
    assert swk.born_outcome(p, p) == 1  # u == p is south: north needs u < p
    assert swk.born_outcome(p, above) == 1
    assert swk.born_outcome(0.0, 0.0) == 1
    assert swk.born_outcome(1.0, 0.999999) == 0


# ---------------------------------------------------------------------------
# (g) Mis-sized inputs and diagnostics.
# ---------------------------------------------------------------------------
def test_size_mismatch_raises_and_reports(swk) -> None:
    eng = swk.Engine()
    got = []
    eng.set_diagnostic_callback(lambda sev, msg: got.append((sev, msg)))
    eng.set_dimension(2)
    with pytest.raises(swk.SwkError) as ei:
        eng.set_hamiltonian_packed([1.0, 0.0, 0.0])
    assert ei.value.name == "SizeMismatch" and ei.value.status == 2
    assert got and got[-1][0] == swk.SEVERITY_ERROR and "size mismatch" in got[-1][1]

    eng.set_hamiltonian_packed(packed([[0, 1], [1, 0]]))
    with pytest.raises(swk.SwkError) as ei:
        eng.evolve(basis_dm(2, 0), 0.1)
    assert ei.value.name == "NotFinalized"
    eng.finalize()
    n_before = len(got)
    with pytest.raises(swk.SwkError) as ei:
        eng.evolve([1.0, 0.0, 0.0], 0.1)
    assert ei.value.name == "SizeMismatch"
    assert len(got) > n_before

    # Stateless functions refuse bad sizes and arguments too.
    with pytest.raises(swk.SwkError) as ei:
        swk.purity([1.0, 0.0], 2)
    assert ei.value.name == "SizeMismatch"
    with pytest.raises(swk.SwkError) as ei:
        swk.marginal(basis_dm(2, 0), 3, 1, 0)
    assert ei.value.name == "IndexOutOfRange"
    with pytest.raises(swk.SwkError) as ei:
        swk.marginal(basis_dm(2, 0), 0, 1, 2)
    assert ei.value.name == "InvalidArgument"

    # Removing the callback silences it.
    eng.set_diagnostic_callback(None)
    n = len(got)
    with pytest.raises(swk.SwkError):
        eng.evolve([1.0], 0.1)
    assert len(got) == n
    eng.close()


def test_status_names_and_version(swk) -> None:
    lib = swk.load()
    names = [lib.swk_status_name(i).decode() for i in range(9)]
    assert names[:7] == ["Ok", "DimensionNotSet", "SizeMismatch", "NotFinalized",
                         "IndexOutOfRange", "InvalidArgument", "EigenFailure"]
    assert swk.version().startswith("swk ")
    assert swk.mutual_information_all(ket_dm([1, 0, 0, 0]), 2) == [0.0]


# ---------------------------------------------------------------------------
# (h) MSB qubit convention.
# ---------------------------------------------------------------------------
def test_msb_qubit_convention(swk) -> None:
    rho = basis_dm(4, 0b10)  # qubit 0 is the most significant bit: south; qubit 1: north
    assert swk.marginal(rho, 0, 2, 1) == 1.0
    assert swk.marginal(rho, 1, 2, 0) == 1.0
    b = swk.bloch_metrics(rho, 2)
    assert b[4] == -1.0  # qubit 0: z = -1 (south)
    assert b[9 + 4] == 1.0  # qubit 1: z = +1 (north)
