#!/bin/bash
# Development launcher for WSL2 with GPU acceleration
# Uses D3D12 driver to access Intel HD Graphics 620 via WSL2 GPU passthrough

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0

# Enable D3D12 GPU acceleration (Intel HD Graphics 620)
# This gives 50+ FPS vs 21 FPS on llvmpipe (CPU)
export GALLIUM_DRIVER=d3d12
export MESA_D3D12_DEFAULT_ADAPTER_NAME=AUTO
export MESA_LOADER_DRIVER_OVERRIDE=zink
unset LIBGL_ALWAYS_SOFTWARE  # Allow GPU

# Force OpenGL3 + gl_compatibility for WSL2
# gl_compatibility has best performance on D3D12
godot --rendering-driver opengl3 --rendering-method gl_compatibility --path . "$@"
