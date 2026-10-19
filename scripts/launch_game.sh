#!/usr/bin/env bash
# Play SpaceWheat from source (Linux or WSL), headed. Extra arguments go to Godot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/godot_runtime_env.sh"

sw_prepare_runtime_env "interactive"
sw_godot --path "${PROJECT_DIR}" "$@"
