#!/usr/bin/env bash
# itch-push.sh — push packaged desktop builds to itch.io via butler.
#
# One lane, no manual uploads: package first (package-desktop-builds.sh or
# build-all-platforms.sh), then run this. Requires `butler login` once.
#
# Usage:
#   ITCH_USER=yourname ITCH_GAME=spacewheat ./scripts/itch-push.sh [version]
set -euo pipefail

ITCH_USER="${ITCH_USER:?set ITCH_USER (your itch.io username)}"
ITCH_GAME="${ITCH_GAME:-spacewheat}"
# Default version = the in-game stamp (application/config/version in
# project.godot) so itch's build list matches what the title screen shows.
PROJECT_VERSION="$(grep -oP '^config/version="\K[^"]+' "$(dirname "$0")/../project.godot" 2>/dev/null || true)"
VERSION="${1:-$PROJECT_VERSION}"
# Packager output (package-desktop-builds.sh) is the default artifact source;
# override with DIST=… if you stage elsewhere.
DIST="${DIST:-$(dirname "$0")/../releases/packages}"

command -v butler >/dev/null || { echo "butler not found — https://itch.io/docs/butler/"; exit 1; }

push() { # push <glob> <channel>
  local artifact
  artifact=$(ls -t $DIST/$1 2>/dev/null | head -1) || true
  if [ -z "${artifact:-}" ]; then echo "skip $2: no artifact matching $1 in $DIST"; return; fi
  echo "→ butler push $artifact $ITCH_USER/$ITCH_GAME:$2 ${VERSION:+--userversion $VERSION}"
  butler push "$artifact" "$ITCH_USER/$ITCH_GAME:$2" ${VERSION:+--userversion "$VERSION"}
}

push "spacewheat-linux-*.tar.gz" linux
push "spacewheat-windows-*.zip" windows
echo "done — verify at https://$ITCH_USER.itch.io/$ITCH_GAME"
