#!/bin/bash
# Open SpaceWheat in the Godot editor (Linux or WSL2).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/godot_runtime_env.sh"

sw_prepare_runtime_env "interactive"
sw_godot --rendering-driver opengl3 --rendering-method gl_compatibility --path "${PROJECT_DIR}" -e
