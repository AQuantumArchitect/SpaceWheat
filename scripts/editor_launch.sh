#!/bin/bash
# Launch Godot editor for WSL2 development

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/godot_runtime_env.sh"

sw_prepare_runtime_env "interactive"
sw_godot --rendering-driver opengl3 --rendering-method gl_compatibility -e
