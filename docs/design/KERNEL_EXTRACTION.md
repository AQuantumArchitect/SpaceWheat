# Kernel extraction: a Godot-free density-matrix core (`swk`)

**Status:** in progress on branch `kernel/extract-swk` (cut from
`overnight/2026-11-09-hive` @ `9c7ea468`). This is a design doc, not a spec of
shipped behaviour. Move it to `docs/history/` once the work lands.

## Why

The same density-matrix maths exists four times across Luke's projects:

| Where | Language | Bound to |
|---|---|---|
| `native/src/quantum_evolution_engine.*` (this repo) | C++ / Eigen | Godot (`RefCounted`, `PackedFloat64Array`, `Dictionary`) |
| `Core/Witness/` (this repo) | GDScript | SpaceWheat's `ComplexMatrix` |
| `umwelt` (`src/umwelt/substrate/`) | Python / numpy | nothing |
| `EnclaveCut` (`Source/EnclaveCut/Substrate/`) | C++ / Eigen | Unreal; closed systems only |

The goal is one kernel that all of them can use. This brief covers **stage 1
only**: pull the maths out of the Godot class into a plain C++ library, put the
Godot class back as a thin wrapper, and prove nothing changed. Enclave Cut,
Umwelt and the Witness adopt the kernel in later stages, in their own repos
and PRs.

## Rules for this stage

1. **Behaviour-preserving.** `QuantumEvolutionEngine` keeps every bound method,
   signature, return shape, warning and quirk. The floating-point operations
   happen in the same order as before. Do not fix, tidy or speed up the maths.
   Known quirks to keep:
   - `get_last_substep_count()` is not reset by the exact-unitary path.
   - `dt` and `max_dt` arrive as `float` and are widened to `double`.
   - The propagator cache is keyed on exact `dt` equality.
   - On a mis-sized ρ, `unpack_dense` reports an error and the caller carries on
     with a zero matrix; `evolve` instead warns and returns its input unchanged.
   - The Bloch packet has stride **9** (`p0,p1,x,y,z,r,theta,phi,r_xy`). The old
     header comment says 8; the code is right. Fixing that comment is allowed.
2. **No Godot in the kernel.** Nothing under `native/kernel/` may include a
   Godot header or mention a Godot type. It depends on Eigen and the C++17
   standard library only.
3. **No build-lane changes.** The kernel is header-only and the wrapper reaches
   it with a relative include (`"../kernel/include/swk/swk.hpp"`). `Makefile`,
   `Makefile.windows`, `SConstruct`, `scripts/build-all-platforms.*` and
   `.github/workflows/build-gdextension.yml` stay as they are. Only the Windows
   lane can be built on this host, so the Linux, macOS, MSVC and web lanes must
   keep working without edits.
4. **Portable C++17.** It has to compile under g++, clang, MSVC and Emscripten.
   Include every standard header you use (`<algorithm>`, `<cmath>`, `<cstdint>`,
   `<functional>`, `<string>`, `<vector>`). No GCC extensions, no `M_PI`.
5. **The kernel does not throw.** Unreal builds with exceptions off. Report
   failure through return values.
6. **Out of scope:** `multi_biome_lookahead_engine.*`, `quantum_matrix_native.*`,
   the mythos engine, the force graph, any GDScript game logic, and any other
   repo. `QuantumComputer.gd` stays the game's authority for measurement.
7. **Do not commit or push.** Leave changes in the working tree.

## Layout

```
native/kernel/
  README.md                what it is, how to build and test, the packing convention
  include/swk/
    swk.hpp                umbrella include
    types.hpp              aliases, Status, diagnostics sink, pack / unpack
    density.hpp            enforce_density_matrix, purity, trace, partial traces,
                           Bloch metrics, entropy, mutual information, eigen analysis
    evolution.hpp          class swk::EvolutionEngine
    measurement.hpp        marginal, project_qubit, drain_qubit, born_outcome  (new)
  capi/
    swk_c.h                C interface (opaque handle, plain arrays, int status)
    swk_c.cpp
  python/
    swk.py                 ctypes loader for the C interface
  tests/
    swk_tests.cpp          standalone test executable, no Godot
  Makefile                 `test` and `capi` targets; output in native/kernel/build/
```

`native/kernel/build/` is ignored by git.

## Conventions the kernel fixes in one place

- **Packed matrix:** `2·dim²` doubles, row-major, interleaved
  `[re00, im00, re01, im01, …]`.
- **Qubit order:** qubit `q` of `n` lives at bit `n − 1 − q` (most significant
  first). This matches `RegisterMap` and `HamiltonianBuilder` in GDScript.
- **Lindblad triplets:** `[row, col, re, im, …]`, entries with
  `|re|,|im| ≤ 1e-15` dropped, out-of-range entries refused.
- **Pole numbering:** pole 0 is north, pole 1 is south.

## Kernel interface (namespace `swk`)

```cpp
using Complex = std::complex<double>;
using CMatrix = Eigen::MatrixXcd;
using SparseC = Eigen::SparseMatrix<Complex, Eigen::RowMajor>;

enum class Status { Ok, DimensionNotSet, SizeMismatch, NotFinalized,
                    IndexOutOfRange, InvalidArgument, EigenFailure };

enum class Severity { Warning, Error };
using DiagnosticSink = std::function<void(Severity, const std::string&)>;

bool unpack_dense(const double* data, std::int64_t count, int dim, CMatrix& out);
void pack_dense(const CMatrix& m, int dim, double* out);   // out holds 2·dim²

class EvolutionEngine {
public:
    void set_diagnostic_sink(DiagnosticSink sink);   // default: no-op
    void set_dimension(int dim);
    Status set_hamiltonian_packed(const double* data, std::int64_t count);
    Status add_lindblad_triplets(const double* data, std::int64_t count);
    void clear_operators();
    void set_coherent(bool on);
    void finalize();
    int  dimension() const;  int lindblad_count() const;  bool is_finalized() const;
    Status evolve(CMatrix& rho, double dt, double max_dt);   // in place
    int  last_substep_count() const;
    static constexpr double REL_CHANGE_PER_SUBSTEP = 0.1;
    static constexpr int MAX_SUBSTEPS = 16;
};
```

`density.hpp` holds free functions over `CMatrix` (`purity`, `trace`,
`partial_trace_single`, `partial_trace_pair`, `bloch_metrics` with
`kBlochStride = 9`, `von_neumann_entropy`, `mutual_information_all`,
`eigen_analysis`, `cos2_similarity`) and a small stateful `MiScreen` class that
carries the adaptive-MI candidate list.

Diagnostics: the kernel composes the same message text the Godot class prints
today and hands it to the sink. The wrapper's sink forwards to
`UtilityFunctions::push_warning` / `push_error`, so what the game logs does not
change.

`measurement.hpp` is **new native code**, ported from
`Core/QuantumSubstrate/QuantumComputer.gd` (`get_marginal`, `_project_qubit`,
`drain_qubit`) so that Enclave Cut and Umwelt have measurement without Godot.
The kernel owns no random numbers: `born_outcome(p_north, u)` returns pole 0
when `u < p_north`, matching `randf() < north_prob`, and the caller supplies `u`.
SpaceWheat does not call these yet.

## Proof that nothing changed

1. **Golden vectors.** `tests/kernel_golden_dump.gd` drives every bound method of
   `QuantumEvolutionEngine` with inputs from a fixed integer generator (no
   `randf`), across dimensions 2 to 64 and the closed, open, and
   pure-Lindbladian regimes, plus the error paths. It writes doubles as raw
   bytes in hex. The golden file is captured from the **unmodified** build.
   - On this host, same compiler and flags: the rewrapped build must match
     **bit for bit**.
   - Committed pytest (`tests/test_kernel_golden.py`): tolerance `1e-10`, so
     other platforms and compilers pass.
2. **Standalone kernel tests** (`native/kernel/tests/swk_tests.cpp`): trace and
   purity conserved under closed evolution; a one-qubit Rabi H rotates the
   Bloch vector as the closed form says; amplitude damping relaxes at the
   analytic rate; `project_qubit` pins the marginal; `drain_qubit` at η = 0 is
   a no-op and at η = 1 empties the drained pole, which equals projecting onto
   the other pole; partial traces agree with a
   brute-force reference; size and range guards refuse bad input.
3. **Existing tests** stay green: `tests/test_evolve_parity.gd`,
   `test_drain_qubit`, `test_closed_system`, `test_degenerate_rho`,
   `test_hermitian_eigen_path`, the `native_async_*` smokes, and the pytest floor
   `SW_SKIP_LONG=1 python -m pytest tests/ -q` compared against a baseline run
   on the unmodified tree with Godot on PATH.
4. **Guard test:** no file under `native/kernel/` contains the string `godot`
   (case-insensitive).

## Work packets

| # | Packet | Touches | Depends on |
|---|---|---|---|
| A | Kernel headers, standalone tests, Makefile, README | `native/kernel/` (not `capi/`, `python/`) | nothing |
| B | Golden-vector dump, compare script, pytest; capture golden from baseline DLL | `tests/` | baseline build |
| C | Rewrap `QuantumEvolutionEngine` over the kernel; rebuild the Windows DLL; run the proofs | `native/src/quantum_evolution_engine.{h,cpp}`, `native/bin/windows/` | A, B |
| D | C interface, ctypes loader, pytest against a numpy reference, guard test | `native/kernel/capi/`, `native/kernel/python/`, `tests/test_swk_kernel.py`, `.gitignore` | A |

## Building on this host

See the Windows recipe: WinLibs `g++` is on PATH, `make` is `mingw32-make`.

```
cd native
mingw32-make -f Makefile.windows -j8 CXX=g++ LDFLAGS="-shared -static -static-libgcc -static-libstdc++ ./lib/libgodot-cpp.windows.template_release.x86_64.a -pthread"
strip --strip-unneeded bin/windows/libquantummatrix.windows.template_release.x86_64.dll
cp bin/windows/libquantummatrix.windows.template_release.x86_64.dll bin/windows/libquantummatrix.windows.template_debug.x86_64.dll
```

Headless Godot loads the `template_debug` name. Godot-driven pytest needs
`/c/Users/lukes/Godot/bin` first on PATH or the tests skip silently.

## Known follow-ups (not this stage)

- The committed Linux `.so` and web `.wasm` are still built from the old
  source. Behaviour is identical, so nothing breaks, but they should be rebuilt
  through CI (`build-gdextension.yml`) before this merges.
- PR #70 (`native-parallel`) edits comments in `quantum_evolution_engine.*` and
  reworks the lookahead engine. Expect a small textual conflict in the wrapper.
- Move the lookahead batching onto the kernel; point the Witness at it; add the
  Umwelt native backend; swap Enclave Cut's kernel for this one.
