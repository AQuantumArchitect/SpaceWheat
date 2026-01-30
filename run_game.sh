#!/bin/bash
# Launch SpaceWheat with software rendering (WSL2 workaround)
# The Intel D3D12 driver in WSL2 crashes - use Mesa software rasterizer instead

export LIBGL_ALWAYS_SOFTWARE=1
# Direct Godot's user data to a workspace path we control and
# make sure the internal logs/cache directories exist.
export XDG_DATA_HOME="${PWD}/Tests"
export APPLICATION_NAME="SpaceWheat - Quantum Farm"
export GODOT_USER_DIR="${XDG_DATA_HOME}/${APPLICATION_NAME}"

# Ensure the configured user dir has the usual subdirectories before launching.
if [ -n "$GODOT_USER_DIR" ]; then
  mkdir -p "$GODOT_USER_DIR/logs" "$GODOT_USER_DIR/cache"
fi

# Run Godot with all arguments passed through
godot "$@"
