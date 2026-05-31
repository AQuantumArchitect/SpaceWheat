#!/bin/bash
# 🌳 authority-tree composer
#
# Generates the (faction × biome × hat × icons) authority tree using the
# pure-math AuthorityComposer (Core/Quantum/AuthorityComposer.gd) wrapped
# by the AuthorityAdapter (Core/Factions/AuthorityAdapter.gd).
#
# Usage:
#   🍄/🧪/🌳.sh                              # all factions × all biomes (compose)
#   🍄/🧪/🌳.sh "The Demos"                  # one faction (compose)
#   🍄/🧪/🌳.sh --synthetic                  # composer math test only
#   🍄/🧪/🌳.sh --topology [<faction_name>]  # icon-cloud → induced realization → topology
#
# Output: pretty summary to stdout + decorated JSON at
#   /tmp/authority_tree.json     (default compose mode)
#   /tmp/authority_topology.json (--topology mode)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

if [ "${1:-}" = "--synthetic" ]; then
    echo "🌳 composer math test (synthetic inputs)"
    exec godot --headless --script res://tests/test_authority_composer.gd
fi

if [ "${1:-}" = "--topology" ]; then
    shift
    if [ $# -gt 0 ]; then
        echo "🌳 compose authority topology — faction='$1'"
        exec godot --headless --script res://tests/run_authority_topology.gd -- "$1"
    else
        echo "🌳 compose authority topology — all factions"
        exec godot --headless --script res://tests/run_authority_topology.gd
    fi
fi

if [ $# -gt 0 ]; then
    echo "🌳 compose authority tree — faction='$1'"
    exec godot --headless --script res://tests/run_authority_compose.gd -- "$1"
else
    echo "🌳 compose authority tree — all factions"
    exec godot --headless --script res://tests/run_authority_compose.gd
fi
