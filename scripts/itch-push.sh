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
VERSION="${1:-}"
DIST="$(dirname "$0")/../dist"

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
