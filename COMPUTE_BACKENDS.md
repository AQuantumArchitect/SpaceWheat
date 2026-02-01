# Compute Backend System

## Overview

SpaceWheat uses an intelligent multi-tier compute backend system that automatically selects the best force calculation method for each platform.

## Architecture

```
ComputeBackendSelector
    ↓
Platform Detection → Backend Selection → Initialization
    ↓                     ↓                    ↓
Desktop/Web/Mobile   GPU/Native/GDScript   QuantumForceSystem
```

## Supported Backends

### 1. GPU Compute (Vulkan/WebGPU/Metal)
- **Best for:** Desktop with GPU, Web (WebGPU), Mobile
- **Performance:** Fastest, offloads CPU
- **Platforms:**
  - Desktop: Vulkan (Windows/Linux), Metal via MoltenVK (Mac)
  - Web: WebGPU
  - Mobile: Vulkan (Android), Metal (iOS)
- **Fallback:** Rejected if software renderer detected (llvmpipe, SwiftShader)

### 2. Native CPU (C++ GDExtension)
- **Best for:** Headless, old GPUs, software renderers
- **Performance:** 3-5x faster than GDScript
- **Platforms:** All (requires compiled GDExtension)
- **Fallback:** Used when GPU unavailable or slower

### 3. GDScript CPU
- **Best for:** Development, debugging, platforms without GDExtension
- **Performance:** Baseline (slowest)
- **Platforms:** All
- **Fallback:** Always available

## Platform Detection

| Platform | Detected Backend | Notes |
|----------|------------------|-------|
| Windows Desktop (GPU) | GPU Compute | Vulkan via RenderingDevice |
| Windows Desktop (old GPU) | Native CPU | Software renderer rejected |
| Linux Desktop (GPU) | GPU Compute | Vulkan via RenderingDevice |
| macOS Desktop | GPU Compute | Metal via MoltenVK |
| Web Browser (modern) | GPU Compute | WebGPU |
| Web Browser (old) | GDScript CPU | No WebGPU support |
| Android | GPU Compute | Vulkan |
| iOS | GPU Compute | Metal via MoltenVK |
| Headless/Server | Native CPU | No GPU available |
| WSL2 (Windows 10) | Native CPU | Vulkan unavailable or software |

## How It Works

### 1. Platform Detection
```gdscript
ComputeBackendSelector._detect_platform()
```
- Checks `OS.has_feature()` for platform
- Queries `RenderingServer.create_local_rendering_device()` for GPU
- Detects software renderers (llvmpipe, SwiftShader)

### 2. Backend Selection
```gdscript
ComputeBackendSelector._select_backend()
```
- Hardware GPU detected → Try GPU Compute
- Software renderer → Skip to Native CPU
- No RenderingDevice → Native CPU
- No GDExtension → GDScript fallback

### 3. Initialization
```gdscript
QuantumForceSystem._init()
```
- Creates appropriate calculator/engine
- Configures force constants
- Reports selected backend

## Force Override (Testing)

You can force a specific backend via command line or settings:

```bash
# Force GPU compute (even if slow)
godot --force-gpu-compute

# Force C++ native
godot --force-native-compute

# Force GDScript
godot --force-gdscript-compute
```

In code:
```gdscript
var selector = ComputeBackendSelector.new()
selector.force_backend = "gpu"  # or "native", "gdscript"
```

## Performance Characteristics

| Backend | Nodes | FPS | CPU Usage | GPU Usage |
|---------|-------|-----|-----------|-----------|
| GPU Compute (HW) | 1000 | 60+ | Low | High |
| GPU Compute (SW) | 1000 | 20-30 | High | Low |
| Native CPU | 1000 | 30-40 | High | Rendering only |
| GDScript CPU | 1000 | 10-15 | Very High | Rendering only |

## Future Improvements

### Benchmarking System
Add runtime performance testing:
```gdscript
func _benchmark_backends() -> Dictionary:
    # Test GPU vs CPU with 100 nodes for 1 second
    # Return { "gpu_ms": float, "cpu_ms": float }
```

### Adaptive Switching
Switch backends based on load:
- Start with GPU
- If FPS < 30 and CPU usage low → try CPU path
- If GPU overheats → switch to CPU

### Platform-Specific Tuning
Different force constants per backend:
```gdscript
const FORCE_CONFIGS = {
    "gpu": { "repulsion": 2500.0, "damping": 0.89 },
    "cpu": { "repulsion": 2000.0, "damping": 0.92 }
}
```

## Debugging

Enable verbose logging:
```gdscript
# In ComputeBackendSelector
var verbose: bool = true  # Prints detection details
```

Check current backend at runtime:
```gdscript
var force_system = QuantumForceSystem.new()
print("Using backend: ", force_system._gpu_enabled ? "GPU" :
                         force_system._native_enabled ? "Native" : "GDScript")
```

## WSL2 Special Case

WSL2 on Windows 10 lacks Vulkan passthrough:
- Zink translates Vulkan → OpenGL
- But often falls back to llvmpipe (software)
- System correctly rejects software renderer
- Falls back to Native CPU (optimal for this case)

For WSL2 users: Run on Windows natively for GPU compute, or accept Native CPU path.
