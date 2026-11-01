#!/bin/bash
# Development launcher for WSL2 with GPU acceleration
# Routes OpenGL through Mesa's D3D12 Gallium driver → Intel HD Graphics 620

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/godot_runtime_env.sh"

# D3D12 GPU acceleration via Mesa Gallium (not zink)
# OpenGL → d3d12 Gallium → D3D12 → Intel HD 620
sw_prepare_runtime_env "interactive"

# project.godot now defaults to gl_compatibility, so --rendering-driver opengl3
# is the only override needed (forces OpenGL instead of Vulkan)
sw_godot --rendering-driver opengl3 --path . "$@"
