# SpaceWheat Native GDExtension

**Clean, minimal build system - NO BLOAT**

## Structure

```
native/
├── src/                    Your 7 C++ files (3415 lines)
├── include/
│   ├── Eigen/              Linear algebra (header-only)
│   ├── unsupported/        Eigen matrix functions
│   └── godot_cpp/          GDExtension headers only
├── lib/
│   └── libgodot-cpp...a    Pre-compiled godot-cpp (81MB)
├── bin/
│   ├── linux/              Linux binaries (.so)
│   ├── windows/            Windows binaries (.dll)
│   ├── macos/              macOS frameworks
│   └── web/                WASM binaries
└── Makefile                Simple build (no scons)
```

## Build

```bash
make clean && make -j$(nproc)
```

**Build time:** ~30 seconds

## What's Compiled

Core engines (see `src/` for the full set — 25 files, ~6,600 lines total):

| File | Purpose |
|------|---------|
| `quantum_evolution_engine.cpp` | Core Lindblad solver (exact unitary propagator + adaptive Euler) |
| `multi_biome_lookahead_engine.cpp` | Batched multi-biome evolution |
| `parametric_selector_native.cpp` | Music Layer 4/5 parametric selection |
| `quantum_matrix_native.cpp` | General matrix ops |
| `force_graph_engine.cpp` | Bubble layout physics (MI-driven clustering) |
| `liquid_neural_net.cpp` | Phase modulation (disabled by default) |
| `quantum_mythos_engine.cpp` / `mythos_graph_core.cpp` | Experimental graph substrate |
| `register_types.cpp` | GDExtension registration |

## Classes Exposed to GDScript

- `QuantumMatrixNative` - Matrix operations (Eigen accelerated)
- `QuantumEvolutionEngine` - Lindblad evolution (10-20× speedup)
- `MultiBiomeLookaheadEngine` - Batched evolution (4ms amortized)
- `ForceGraphEngine` - Bubble physics (3-5× speedup)
- `ParametricSelectorNative` - Music selection (100× speedup)

## Dependencies

**External (header-only):**
- Eigen 3 - Linear algebra
- godot-cpp headers - GDExtension API

**Pre-compiled:**
- libgodot-cpp.linux.template_release.x86_64.a (81MB, built once)

**No runtime dependencies** - statically linked

## History

**2025-02-02:** Migrated from bloated scons build
- Removed 971 godot-cpp class compilations
- Build time: 20+ min → 30 sec
- No more zombie rendering/UI/physics code

**Previous implementation:** Archived at `~/ws/SpaceWheat/native_OLD_BLOATED_*`
