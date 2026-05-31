#!/bin/bash
# deploy-windows-desktop.sh - Copy a built Windows desktop export into a player folder.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SOURCE_ROOT="${SOURCE_ROOT:-$PROJECT_DIR/releases/local/windows-native}"
source "$PROJECT_DIR/scripts/lib/windows_desktop_deploy.sh"
TARGET_ROOT="${TARGET_ROOT:-$(sw_windows_player_root)}"
CREATE_LAUNCHER="${CREATE_LAUNCHER:-1}"

log() { echo -e "\n\033[1;34m▶ $1\033[0m"; }
success() { echo -e "\033[1;32m✓ $1\033[0m"; }
error() { echo -e "\033[1;31m✗ $1\033[0m" >&2; exit 1; }

show_help() {
    cat << 'EOF'
Copy the built Windows desktop export into the player-facing Windows folder.

Usage:
  ./scripts/deploy-windows-desktop.sh [OPTIONS]

Options:
  --source-root PATH       Source export folder (default: ./releases/local/windows-native)
  --target-root PATH       Target Windows folder (default: /mnt/c/Games/🌾🚀🌌SpaceWheat)
  --no-launcher            Do not write launch.bat
  --help                   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --source-root)
            SOURCE_ROOT="$2"
            shift 2
            ;;
        --target-root)
            TARGET_ROOT="$2"
            shift 2
            ;;
        --no-launcher)
            CREATE_LAUNCHER=0
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

log "Deploying Windows desktop build"
sw_windows_deploy_tree "$SOURCE_ROOT" "$TARGET_ROOT" "$CREATE_LAUNCHER"

success "Windows build deployed to $TARGET_ROOT"
echo ""
echo "Launch with:"
echo "  $TARGET_ROOT/SpaceWheat.exe"
if [ "$CREATE_LAUNCHER" = "1" ]; then
    echo "  $TARGET_ROOT/launch.bat"
fi
