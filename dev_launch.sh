#!/bin/bash
# Development launcher for WSL2 with GPU acceleration
# Routes OpenGL through Mesa's D3D12 Gallium driver → Intel HD Graphics 620

export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir
export DISPLAY=:0

# D3D12 GPU acceleration via Mesa Gallium (not zink)
# OpenGL → d3d12 Gallium → D3D12 → Intel HD 620
export GALLIUM_DRIVER=d3d12
export MESA_D3D12_DEFAULT_ADAPTER_NAME=Intel
unset LIBGL_ALWAYS_SOFTWARE
unset MESA_LOADER_DRIVER_OVERRIDE  # Don't use zink — d3d12 Gallium is direct

# project.godot now defaults to gl_compatibility, so --rendering-driver opengl3
# is the only override needed (forces OpenGL instead of Vulkan)
godot --rendering-driver opengl3 --path . "$@"
