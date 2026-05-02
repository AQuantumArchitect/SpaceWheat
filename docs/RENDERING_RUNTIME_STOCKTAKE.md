# Rendering Runtime Stocktake

This is the current live rendering/runtime picture for SpaceWheat after the recent cleanup pass.

## Live runtime path

The production path is already centered on CPU-native evolution and cached visualization payloads:

1. `BiomeEvolutionBatcher.gd`
   - drives native multi-biome evolution
   - maintains lookahead buffers
   - publishes force positions, Bloch payloads, purity, MI, and couplings

2. `QuantumForceGraph.gd`
   - coordinates the 2D graph frame
   - consumes cached payloads
   - gates redraw, particle updates, and force application

3. Renderer stack
   - `QuantumRegionRenderer.gd`: biome backdrops, heatmaps, trails
   - `QuantumProjectionFieldRenderer.gd`: self-energy contour fields
   - `QuantumInfraRenderer.gd`: gate and infrastructure lines
   - `QuantumEdgeRenderer.gd`: MI / Hamiltonian / Lindblad relationship lines
   - `QuantumEffectsRenderer.gd`: particles and lifecycle effects
   - `BatchedBubbleRenderer.gd`: bubble bodies + emoji top layer
   - `GeometryBatcher.gd` / atlas batchers: render submission reduction

4. Projection shaping
   - `QuantumProjectionBuilder.gd` is the current semantic field builder
   - it is pure data shaping, not physics authority and not a renderer

## What is stale

The repo still contains older terminology and tooling from a different backend story:

- scripts and comments that talk like compute shaders are the primary runtime
- scripts that force `DISPLAY=:0` as the default WSL lane
- launcher logic that hard-pins `MESA_D3D12_DEFAULT_ADAPTER_NAME=Intel`
- perf heuristics that treat generic `Mesa` as equivalent to software rendering

That older story no longer matches the live game path. The live game is currently:

- CPU via native C++ evolution
- cached viz payloads
- batched 2D rendering
- optional renderer/backend overrides for platform investigation

## Practical backend stance

For collaborator sanity, the repo should present one honest default:

- Godot version: `4.5+`
- runtime default: native project/export runtime first
- WSL default: Wayland first, not forced X11
- adapter selection: `AUTO`, not machine-specific vendor names

Anything beyond that should be framed as an experimental lane:

- `zink`
- `d3d12`
- future shader/compute acceleration

## Current cleanup priorities

1. Keep one shared launch helper as the source of truth for headed/headless runtime env.
2. Remove or rewrite stale profiling scripts that still report in terms of deleted GPU-compute selectors.
3. Keep CPU-native evolution as the production baseline until a new GPU compute path exists in live code again.
4. Treat future shader compute as an additive backend, not a competing authority.

## Windows collaboration note

The Windows side should assume:

- Godot `4.5+`
- the project runtime is authoritative
- performance/debug scripts may still contain stale Linux/WSL assumptions unless they use `scripts/lib/godot_runtime_env.sh`

Cross-OS runtime control is now supported through the shared launcher:

- set `SW_GODOT_BIN` (or `GODOT_BIN`) to a Windows Godot executable from WSL
- `sw_godot` rewrites WSL repo paths to Windows-visible paths
- headed/runtime profiler JSON outputs can round-trip back into the repo over `\\wsl.localhost\...`
