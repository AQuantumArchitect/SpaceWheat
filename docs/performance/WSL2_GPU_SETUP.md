# WSL2 GPU Acceleration Setup - WORKING ✅

**GPU:** Intel HD Graphics 620
**Performance:** 50+ FPS (vs 21 FPS on CPU)
**GPU Usage:** ~30% (room to grow!)

---

## ✅ Confirmed Working Configuration

The D3D12 driver successfully accesses your Intel HD 620 GPU through WSL2!

**Test Results:**
```
Device: D3D12 (Intel(R) HD Graphics 620)
Renderer: OpenGL 4.1 Mesa 23.2.1
FPS: 48-54 (stable)
Frame Time: 19-20ms (vs 43ms on llvmpipe CPU)
Performance Improvement: 2.4x faster
GPU Utilization: 30% (efficient, room for more)
```

---

## Environment Variables Required

Add these to enable GPU acceleration:

```bash
export GALLIUM_DRIVER=d3d12
export MESA_D3D12_DEFAULT_ADAPTER_NAME=AUTO
export MESA_LOADER_DRIVER_OVERRIDE=zink
unset LIBGL_ALWAYS_SOFTWARE  # Critical: allow GPU
```

Launch with:
```bash
godot --rendering-driver opengl3 --rendering-method gl_compatibility
```

---

## Updated Launch Scripts

### `dev_launch.sh` (Main Development)
✅ **Already updated** - Launches with D3D12 GPU by default

Usage:
```bash
./dev_launch.sh
```

### `🍄/🧪/🥛🖥️⚡.sh` (Milk Hunt Visual)
✅ **Already updated** - Runs rig listener with GPU

Usage:
```bash
./🍄/🧪/🥛🖥️⚡.sh
```

---

## Performance Comparison

| Configuration | FPS | Frame Time | GPU Usage | Notes |
|---------------|-----|------------|-----------|-------|
| **D3D12 + gl_compat** (NEW) | **50** | **20ms** | **30%** | ✅ **BEST** |
| llvmpipe + gl_compat + Zink | 21 | 43ms | 0% (CPU) | Old default |
| llvmpipe + mobile + Zink | 20 | 45ms | 0% (CPU) | GPU compute fails |
| llvmpipe + gl_compat + OpenGL | 20 | 48ms | 0% (CPU) | Slowest |

**Improvement: 2.4x FPS, GPU offloading frees CPU for quantum simulation!**

---

## Why It Works Now

1. **D3D12 Mesa driver** (`d3d12_dri.so`) translates OpenGL → D3D12 → Intel GPU
2. **Zink** provides efficient Vulkan backend for Mesa
3. **gl_compatibility** has lowest overhead on D3D12
4. **WSL2 /dev/dxg** passthrough device enables GPU access

---

## Troubleshooting

### If FPS drops back to 21:

Check environment variables are set:
```bash
echo $GALLIUM_DRIVER  # Should show: d3d12
echo $LIBGL_ALWAYS_SOFTWARE  # Should be empty or unset
```

### If Godot crashes:

Try forcing software as fallback:
```bash
export LIBGL_ALWAYS_SOFTWARE=1
./dev_launch.sh  # Will use llvmpipe CPU (21 FPS)
```

### Verify GPU is active:

```bash
# While Godot is running:
watch -n 1 "powershell.exe 'Get-Counter \"\\GPU Engine(*engtype_3D)\\Utilization Percentage\" | select -ExpandProperty CounterSamples | select InstanceName, CookedValue'"
```

Should show ~30% utilization on Intel GPU.

---

## Next Optimizations

With GPU at 30%, we have headroom for:

1. **Enable edge rendering** - Currently disabled, can re-enable
2. **Increase bubble detail** - More vertex precision
3. **Add post-processing** - Glow, blur effects
4. **Higher resolution** - 1920x1080 instead of 960x540

Goal: Maximize GPU usage while maintaining 50-60 FPS.

---

## Technical Details

### GPU Detection Log:
```
OpenGL API 4.1 (Core Profile) Mesa 23.2.1-1ubuntu3.1~22.04.3 - Compatibility
Using Device: Microsoft - D3D12 (Intel(R) HD Graphics 620)
[PerformanceOptimizer] GPU detected: D3D12 (Intel(R) HD Graphics 620)
```

### Why RenderingDevice fails:
```
[GPU] ⚠ Shader compilation failed: Failed to create RenderingDevice
[ComputeSelector] RenderingDevice unavailable - skipping GPU compute
```

**Reason:** Vulkan `RenderingDevice` doesn't work with OpenGL driver. This is expected - GPU compute shaders aren't available, but **rendering GPU acceleration works fine via D3D12**.

We use **Native C++ compute** instead of GPU compute shaders, which is actually better for this use case (quantum simulation on CPU, rendering on GPU).

---

## Summary

**Status:** ✅ **GPU ACCELERATION WORKING**

**Setup:** Automatic via updated launch scripts
**Performance:** 50 FPS, 30% GPU usage
**Bottleneck:** Now CPU-bound on quantum simulation (good - GPU freed up!)

**Launch:** Just run `./dev_launch.sh` - GPU acceleration is now the default!
