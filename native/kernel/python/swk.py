"""ctypes loader for the swk density-matrix kernel C interface (stdlib only).

Matrices are plain Python lists of floats in packed form: 2*dim*dim doubles,
row-major, interleaved [re00, im00, re01, im01, ...]. Every call that returns a
non-zero status raises SwkError carrying the status name.

    import swk
    swk.load()                      # or swk.load("/path/to/swk.dll"), or env SWK_LIB
    eng = swk.Engine(); eng.set_dimension(2) ...
"""
import ctypes
import os
import sys
from ctypes import (CFUNCTYPE, POINTER, c_char_p, c_double, c_int, c_int64,
                    c_void_p)
from pathlib import Path

__all__ = ["SwkError", "Engine", "load", "version", "bloch_stride", "purity",
           "trace", "bloch_metrics", "mutual_information_all", "marginal",
           "project_qubit", "drain_qubit", "born_outcome", "pack_real",
           "SEVERITY_WARNING", "SEVERITY_ERROR"]

SEVERITY_WARNING = 0
SEVERITY_ERROR = 1

_DIAG_FN = CFUNCTYPE(None, c_int, c_char_p, c_void_p)
_P_D = POINTER(c_double)
_lib = None


class SwkError(RuntimeError):
    def __init__(self, status, name, where=""):
        super().__init__("%s: %s (status %d)" % (where, name, status))
        self.status = status
        self.name = name


def _default_path():
    build = Path(__file__).resolve().parent.parent / "build"
    if sys.platform.startswith("win"):
        names = ["swk.dll"]
    elif sys.platform == "darwin":
        names = ["libswk.dylib"]
    else:
        names = ["libswk.so"]
    for n in names:
        if (build / n).exists():
            return build / n
    return build / names[0]


def load(path=None):
    """Load (or reload) the shared library; returns the ctypes handle."""
    global _lib
    path = path or os.environ.get("SWK_LIB") or _default_path()
    lib = ctypes.CDLL(str(path))
    H = c_void_p
    sig = {
        "swk_version": (c_char_p, []),
        "swk_status_name": (c_char_p, [c_int]),
        "swk_bloch_stride": (c_int, []),
        "swk_engine_create": (H, []),
        "swk_engine_destroy": (None, [H]),
        "swk_engine_set_diagnostic_callback": (c_int, [H, _DIAG_FN, c_void_p]),
        "swk_engine_set_dimension": (c_int, [H, c_int]),
        "swk_engine_set_hamiltonian_packed": (c_int, [H, _P_D, c_int64]),
        "swk_engine_add_lindblad_triplets": (c_int, [H, _P_D, c_int64]),
        "swk_engine_clear_operators": (c_int, [H]),
        "swk_engine_set_coherent": (c_int, [H, c_int]),
        "swk_engine_finalize": (c_int, [H]),
        "swk_engine_dimension": (c_int, [H]),
        "swk_engine_lindblad_count": (c_int, [H]),
        "swk_engine_is_finalized": (c_int, [H]),
        "swk_engine_last_substep_count": (c_int, [H]),
        "swk_engine_evolve": (c_int, [H, _P_D, c_int64, c_double, c_double, _P_D]),
        "swk_purity": (c_int, [_P_D, c_int64, c_int, _P_D]),
        "swk_trace": (c_int, [_P_D, c_int64, c_int, _P_D]),
        "swk_bloch_metrics": (c_int, [_P_D, c_int64, c_int, _P_D]),
        "swk_mutual_information_all": (c_int, [_P_D, c_int64, c_int, _P_D]),
        "swk_marginal": (c_int, [_P_D, c_int64, c_int, c_int, c_int, _P_D]),
        "swk_project_qubit": (c_int, [_P_D, c_int64, c_int, c_int, c_int]),
        "swk_drain_qubit": (c_int, [_P_D, c_int64, c_int, c_int, c_int, c_double]),
        "swk_born_outcome": (c_int, [c_double, c_double]),
    }
    for name, (res, args) in sig.items():
        fn = getattr(lib, name)
        fn.restype = res
        fn.argtypes = args
    _lib = lib
    return lib


def _L():
    return _lib if _lib is not None else load()


def _check(status, where):
    if status != 0:
        raise SwkError(status, _L().swk_status_name(status).decode(), where)


def _buf(values):
    vals = [float(v) for v in values]
    return (c_double * len(vals))(*vals), len(vals)


def pack_real(rows):
    """Pack a square matrix given as nested lists of real/complex numbers."""
    out = []
    for row in rows:
        for v in row:
            c = complex(v)
            out.extend((c.real, c.imag))
    return out


def version():
    return _L().swk_version().decode()


def bloch_stride():
    return _L().swk_bloch_stride()


def purity(rho, dim):
    b, n = _buf(rho)
    out = c_double()
    _check(_L().swk_purity(b, n, dim, ctypes.byref(out)), "purity")
    return out.value


def trace(rho, dim):
    """Returns (re, im)."""
    b, n = _buf(rho)
    out = (c_double * 2)()
    _check(_L().swk_trace(b, n, dim, out), "trace")
    return out[0], out[1]


def bloch_metrics(rho, num_qubits):
    """Flat list, stride bloch_stride(): p0,p1,x,y,z,r,theta,phi,r_xy per qubit."""
    b, n = _buf(rho)
    out = (c_double * (bloch_stride() * num_qubits))()
    _check(_L().swk_bloch_metrics(b, n, num_qubits, out), "bloch_metrics")
    return list(out)


def mutual_information_all(rho, num_qubits):
    b, n = _buf(rho)
    pairs = num_qubits * (num_qubits - 1) // 2
    out = (c_double * max(pairs, 1))()
    _check(_L().swk_mutual_information_all(b, n, num_qubits, out), "mutual_information_all")
    return list(out)[:pairs]


def marginal(rho, qubit, num_qubits, pole):
    b, n = _buf(rho)
    out = c_double()
    _check(_L().swk_marginal(b, n, qubit, num_qubits, pole, ctypes.byref(out)), "marginal")
    return out.value


def project_qubit(rho, qubit, num_qubits, pole):
    """Returns a new packed list; the input is not modified."""
    b, n = _buf(rho)
    _check(_L().swk_project_qubit(b, n, qubit, num_qubits, pole), "project_qubit")
    return list(b)


def drain_qubit(rho, qubit, num_qubits, pole, eta):
    """Returns a new packed list; the input is not modified."""
    b, n = _buf(rho)
    _check(_L().swk_drain_qubit(b, n, qubit, num_qubits, pole, float(eta)), "drain_qubit")
    return list(b)


def born_outcome(p_north, u):
    return _L().swk_born_outcome(float(p_north), float(u))


class Engine:
    """Wraps swk_engine. Use as a context manager or call close()."""

    def __init__(self):
        self._lib = _L()
        self._h = self._lib.swk_engine_create()
        if not self._h:
            raise MemoryError("swk_engine_create failed")
        self._cb = None
        self.messages = []  # (severity, text) received through the default diagnostic hook

    def set_diagnostic_callback(self, fn):
        """fn(severity, message) or None. Pass `True` to collect into self.messages."""
        if fn is True:
            fn = lambda sev, msg: self.messages.append((sev, msg))  # noqa: E731
        if fn is None:
            self._cb = None
            _check(self._lib.swk_engine_set_diagnostic_callback(self._h, _DIAG_FN(), None),
                   "set_diagnostic_callback")
            return

        def tramp(sev, msg, _user):
            fn(sev, msg.decode("utf-8", "replace") if msg else "")

        self._cb = _DIAG_FN(tramp)  # keep a reference alive
        _check(self._lib.swk_engine_set_diagnostic_callback(self._h, self._cb, None),
               "set_diagnostic_callback")

    def close(self):
        if self._h:
            self._lib.swk_engine_destroy(self._h)
            self._h = None

    __enter__ = lambda self: self  # noqa: E731

    def __exit__(self, *exc):
        self.close()

    def __del__(self):
        try:
            self.close()
        except Exception:
            pass

    def set_dimension(self, dim):
        _check(self._lib.swk_engine_set_dimension(self._h, dim), "set_dimension")

    def set_hamiltonian_packed(self, packed):
        b, n = _buf(packed)
        _check(self._lib.swk_engine_set_hamiltonian_packed(self._h, b, n), "set_hamiltonian_packed")

    def add_lindblad_triplets(self, triplets):
        b, n = _buf(triplets)
        _check(self._lib.swk_engine_add_lindblad_triplets(self._h, b, n), "add_lindblad_triplets")

    def clear_operators(self):
        _check(self._lib.swk_engine_clear_operators(self._h), "clear_operators")

    def set_coherent(self, on):
        _check(self._lib.swk_engine_set_coherent(self._h, 1 if on else 0), "set_coherent")

    def finalize(self):
        _check(self._lib.swk_engine_finalize(self._h), "finalize")

    @property
    def dimension(self):
        return self._lib.swk_engine_dimension(self._h)

    @property
    def lindblad_count(self):
        return self._lib.swk_engine_lindblad_count(self._h)

    @property
    def is_finalized(self):
        return bool(self._lib.swk_engine_is_finalized(self._h))

    @property
    def last_substep_count(self):
        return self._lib.swk_engine_last_substep_count(self._h)

    def evolve(self, rho, dt, max_dt=0.0):
        """Returns the evolved packed matrix (new list)."""
        b, n = _buf(rho)
        out = (c_double * n)()
        _check(self._lib.swk_engine_evolve(self._h, b, n, float(dt), float(max_dt), out), "evolve")
        return list(out)
