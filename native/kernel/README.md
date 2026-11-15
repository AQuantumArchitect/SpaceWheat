# swk: the density-matrix kernel

A header-only C++17 library holding the density-matrix maths SpaceWheat needs:
Lindblad / unitary evolution, partial traces, Bloch metrics, entropy and mutual
information, eigen analysis, and measurement (marginal, projection, partial
drain). It depends on Eigen and the C++17 standard library only. It must never
include a header from the game engine or mention an engine type: the engine
binding is a thin wrapper that lives outside this directory.

Design and rules: `docs/design/KERNEL_EXTRACTION.md`.

## Conventions

- **Packed matrix:** `2*dim*dim` doubles, row-major, interleaved
  `[re00, im00, re01, im01, ...]`. `swk::pack_dense` / `swk::unpack_dense`.
  `unpack_dense` returns `false` and sets the output to a zero matrix on a size
  mismatch (0x0 when `dim <= 0`).
- **Qubit order:** qubit `q` of `n` lives at bit `n - 1 - q` (most significant
  first).
- **Lindblad triplets:** `[row, col, re, im, ...]`; entries with
  `|re|, |im| <= 1e-15` are dropped; out-of-range entries are refused with
  `Status::IndexOutOfRange` (the operator is still installed from the rest).
- **Poles:** pole 0 is north, pole 1 is south. `born_outcome(p_north, u)`
  returns 0 when `u < p_north`, else 1; the caller supplies `u`.
- **Bloch packet:** stride `swk::kBlochStride == 9`:
  `p0, p1, x, y, z, r, theta, phi, r_xy` per qubit.
- **Nothing throws.** Failure is a `swk::Status` return value.

## Diagnostics

Anything the original engine printed as a warning or error is composed as the
same text and sent to a `swk::DiagnosticSink`
(`std::function<void(Severity, const std::string&)>`).

- `EvolutionEngine` owns a sink: `set_diagnostic_sink(...)`. The default sink
  discards.
- Free functions that can report (`unpack_dense`, `renormalize_trace`,
  `marginal`, `project_qubit`, `drain_qubit`) take an optional trailing
  `const DiagnosticSink*` (default `nullptr`, meaning silent) and also return a
  `Status`.
- Other free functions are total: they return empty or zero results instead of
  reporting.

## Using it

Put the kernel's `include/` and Eigen on the include path, then:

```cpp
#include "swk/swk.hpp"   // or the individual headers under swk/
```

Everything is `inline`, in-class or a template, so any number of translation
units may include it. Headers: `types.hpp` (aliases, Status, sink, pack),
`density.hpp` (free functions and `MiScreen`), `evolution.hpp`
(`EvolutionEngine`), `measurement.hpp`.

## Build and test

From `native/kernel`:

```
mingw32-make test      # Windows (Git Bash)
make test              # elsewhere
```

This builds `tests/swk_tests.cpp` and `tests/swk_second_tu.cpp` (the second
file proves two translation units link) into `build/` and runs them. Eigen is
found at `../include` (the repository's `native/include`); override with
`CXXFLAGS` or `CXX` on the command line if needed. `build/` is git-ignored.

## C interface

`capi/swk_c.h` / `capi/swk_c.cpp` expose the kernel as plain C: an opaque
`swk_engine` handle (create, destroy, set_dimension, set_hamiltonian_packed,
add_lindblad_triplets, clear_operators, set_coherent, finalize, evolve and the
getters) plus stateless calls on packed matrices (purity, trace, bloch_metrics,
mutual_information_all, marginal, project_qubit, drain_qubit, born_outcome).
Functions return an `int` status whose values 0..6 equal `swk::Status`
(`SWK_OK == 0`), plus `SWK_ERR_INTERNAL` (a C++ exception was caught) and
`SWK_ERR_NULL_POINTER`; `swk_status_name(int)` names them. No exception crosses
the boundary and every pointer argument is null-checked. Engine diagnostics go to
an optional callback set with `swk_engine_set_diagnostic_callback`.

```
mingw32-make capi      # or: make capi
```

builds `build/swk.dll` (Windows, statically linked runtime: it imports only
system DLLs), `build/libswk.so` (Linux) or `build/libswk.dylib` (macOS).

`python/swk.py` is a stdlib-only ctypes loader. `swk.load()` looks in `build/`,
or takes an explicit path, or the `SWK_LIB` environment variable. Matrices are
plain lists of floats in packed form; a non-zero status raises `swk.SwkError`.
`tests/test_swk_kernel.py` (repository root) builds and exercises all of it.
