# WSL2/llvmpipe Rendering Configuration Profile
## SpaceWheat - Frame Cost Analysis

**Date:** 2026-02-14
**Environment:** WSL2 with llvmpipe (LLVM 15.0.7, 256 bits) - CPU-based software rendering
**Test Scene:** VisualBubbleTest with 6 biomes, 24 quantum nodes

---

## Results Summary

### 🏆 Winner: `gl_compatibility + Zink + Native C++`

| Metric | Value | vs. 2nd Place | vs. 3rd Place |
|--------|-------|---------------|---------------|
| **FPS** | 21.1 | +4.5% | +7.7% |
| **Untracked Time** | 10.24 ms | **-63.5%** | **-66.1%** |
| **Total Frame Time** | 43.48 ms | -4.3% | -8.7% |
| **Rendering Efficiency** | 76.4% tracked | +38.1pp | +39.8pp |

---

## Detailed Comparison

### Test Configurations

| # | Renderer | Driver | Compute Backend | Result |
|---|----------|--------|-----------------|--------|
| 1 | mobile (Vulkan) | Zink | GPU_COMPUTE | 20.2 FPS, 28.05 ms untracked |
| **2** | **gl_compatibility** | **Zink** | **NATIVE_CPU** | **21.1 FPS, 10.24 ms untracked** ⭐ |
| 3 | gl_compatibility | Native OpenGL | NATIVE_CPU | 19.6 FPS, 30.20 ms untracked |

---

## Frame Time Breakdown

### Configuration 2: gl_compatibility + Zink (WINNER)
```
Total: 43.48 ms (21.1 FPS)
├─ _process():     6.42 ms  (14.8%) - GDScript logic
├─ _draw():       26.82 ms  (61.7%) - Drawing submission
├─ frame_gap:     46.71 ms           - Wait between frames
└─ UNTRACKED:     10.24 ms  (23.5%) - Rendering pipeline ⬅️ BEST
```

### Configuration 1: mobile + Zink + GPU
```
Total: 45.45 ms (20.2 FPS)
├─ _process():     3.75 ms  ( 8.3%)
├─ _draw():       13.66 ms  (30.0%)
├─ frame_gap:     47.52 ms
└─ UNTRACKED:     28.05 ms  (61.7%) - GPU compute overhead
```

### Configuration 3: gl_compatibility + Native OpenGL
```
Total: 47.62 ms (19.6 FPS)
├─ _process():     3.61 ms  ( 7.6%)
├─ _draw():       13.80 ms  (29.0%)
├─ frame_gap:     50.56 ms
└─ UNTRACKED:     30.20 ms  (63.4%) - OpenGL pipeline overhead
```

---

## Key Insights

### Why gl_compatibility + Zink Wins

1. **Simpler Rendering Pipeline**
   - `gl_compatibility` has fewer render passes than `mobile` renderer
   - No deferred/clustered rendering overhead
   - Optimized for 2D canvas operations

2. **Zink's Vulkan Translation is Efficient**
   - Translates OpenGL → Vulkan commands for llvmpipe
   - Better than Godot's native Vulkan renderer on software rasterizer
   - Produces more efficient command streams for llvmpipe

3. **Native C++ Compute is Sufficient**
   - GPU compute shaders don't help on llvmpipe (they're CPU-emulated anyway)
   - C++ GDExtension force calculation is fast enough
   - Avoiding GPU compute eliminates RenderingDevice overhead

### Rendering Pipeline Efficiency

The **untracked time** metric reveals rendering pipeline overhead:

- **gl_compat + Zink**: 10.24 ms (only 23.5% of frame time)
- **mobile + Zink**: 28.05 ms (61.7% of frame time) ❌
- **gl_compat + OpenGL**: 30.20 ms (63.4% of frame time) ❌

This means gl_compatibility + Zink spends **2.7x less time** in the rendering pipeline compared to the other configs.

### Top GDScript Costs (Config 2)

```
_draw bubbles:     26.18 ms  (60.2% of frame)
_process visuals:   2.43 ms  ( 5.6% of frame)
_draw edges:        0.35 ms  ( 0.8% of frame)
```

The bubble drawing dominates tracked time. Further optimization would focus here (batching, atlas, culling).

---

## Recommendations

### For WSL2/llvmpipe Development

✅ **Use `gl_compatibility + Zink`**

Launch with:
```bash
export DISPLAY=:0
export MESA_LOADER_DRIVER_OVERRIDE=zink
godot --rendering-method gl_compatibility
```

Benefits:
- **+7.7% FPS** vs. native OpenGL
- **-66% rendering overhead** vs. native OpenGL
- **No GPU compute needed** - C++ GDExtension is sufficient
- **Simplest pipeline** - best for debugging

### For Production (Real Hardware)

Test on real GPU hardware to determine if GPU compute shaders provide benefit. On llvmpipe they add overhead (28ms vs 10ms), but on real Vulkan hardware they may be faster than CPU compute.

### Next Optimization Targets

Based on profiling data:

1. **Bubble drawing batching** (26.18 ms) - Already uses `BatchedBubbleRenderer`, but could:
   - Reduce overdraw from transparent bubbles
   - Use opaque bubbles with cutout alpha
   - Implement frustum culling

2. **Viewport scaling** - Render at 75% resolution, upscale:
   - Fewer pixels for llvmpipe to rasterize
   - Could reduce untracked time by ~50%
   - Minimal visual impact on 2D

3. **Adaptive quality** - Auto-detect llvmpipe and:
   - Reduce bubble detail levels
   - Skip edge rendering
   - Lower force graph update rate

---

## Environment Details

```
Platform: WSL2 on Windows
Renderer: llvmpipe (LLVM 15.0.7, 256 bits)
Display: WSLg X11 (:0)
Godot: 4.5.stable.official.876b29033
CPU Rasterization: Yes (all configs)
Native Extensions: Enabled (ComplexMatrix/Eigen)
Scene Complexity: 6 biomes, 24 quantum nodes, ~101 edges
```

---

## Conclusion

**gl_compatibility + Zink** provides the best performance on WSL2/llvmpipe by:
- Minimizing rendering pipeline overhead (10.24 ms vs 28-30 ms)
- Leveraging Zink's efficient Vulkan command translation
- Using native C++ compute instead of emulated GPU shaders

This configuration is **7.7% faster** and uses **66% less rendering overhead** than the previous setup, bringing the frame budget closer to the 60 FPS target (21 FPS → targeting 30-40 FPS with further optimizations).
