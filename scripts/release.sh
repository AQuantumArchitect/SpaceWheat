#!/bin/bash
# release.sh - Cut a SpaceWheat release: every platform, one command, one manifest.
#
# WHY THIS EXISTS
#
# SpaceWheat had a desktop release lane and a web release lane, each complete on
# its own, and nothing above them. So "cut a release" meant remembering two
# sequences and stitching their outputs together by hand, and the thing that
# actually went to players — which archives, built from what source, gated how —
# existed only in whoever's head had just done it. build-all-platforms.sh sounds
# like this script but is not: it builds the three native EXTENSIONS and then
# prints the export commands for a human to run.
#
# The output that matters here is not the archives, it is RELEASE.md next to
# them: every artifact, its size, its sha256, the source id it was cut from, and
# which gates actually ran. A release you cannot describe afterwards is a
# release you cannot support.

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/build_stamp.sh"
source "$SCRIPT_DIR/lib/release_paths.sh"

PACKAGE_ROOT="$(sw_package_root)"
REPORT_ROOT="$(sw_report_root)"
VERSION_TAG="${VERSION_TAG:-$(sw_project_version)}"

DO_DESKTOP=true
DO_WEB=true
DO_PHYSICS_GATE=true
GATE_ADVISORY=false
PHYSICS_GATE_RESULT="not run"
WEB_EXTRA=()
DESKTOP_EXTRA=()

show_help() {
    cat << 'EOF'
Cut a full SpaceWheat release — desktop and browser — from the current checkout.

Usage:
  ./scripts/release.sh [OPTIONS]

Options:
  --desktop-only        Skip the browser lane
  --web-only            Skip the desktop lane
  --skip-physics-gate   Skip scripts/run_tests.sh before building
  --gate-advisory       Run the physics gate but do NOT stop on failure. The
                        manifest records exactly which state it ended in, so
                        the archives stay honestly labelled. For cutting a
                        build off a tree with known-red tests you have already
                        judged.
  --skip-web-gate       Pass --skip-gate to the web lane (ships UNVERIFIED
                        against a host that omits isolation headers)
  --skip-smoke          Pass --skip-smoke to both lanes
  --help                Show this help

What it runs:
  scripts/validate-desktop-release.sh   build → smoke → profile → package
  scripts/validate-web-release.sh       build → link → browser gate → smoke → package

Version:
  Derived from application/config/version in project.godot. Not a flag here on
  purpose — a release name is a property of the build, not of the invocation.
  Bump project.godot, then cut.

Outputs:
  releases/packages/                    the archives
  releases/packages/RELEASE-<version>-<build id>.md   the manifest
  releases/validation/<timestamp>/      every gate log from this run
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --desktop-only)      DO_WEB=false; shift ;;
        --web-only)          DO_DESKTOP=false; shift ;;
        --skip-physics-gate) DO_PHYSICS_GATE=false; shift ;;
        --gate-advisory)     GATE_ADVISORY=true; shift ;;
        --skip-web-gate)     WEB_EXTRA+=(--skip-gate); shift ;;
        --skip-smoke)        WEB_EXTRA+=(--skip-smoke); DESKTOP_EXTRA+=(--skip-smoke); shift ;;
        --help|-h)           show_help; exit 0 ;;
        *)                   error "Unknown option: $1" ;;
    esac
done

# One timestamp for the whole cut, so both lanes report into the same run dir
# instead of two adjacent directories nobody can tell apart later.
export SW_RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$REPORT_ROOT/$SW_RUN_TIMESTAMP"
mkdir -p "$RUN_DIR"

sw_capture_source_id
SOURCE_ID="$SW_SOURCE_ID_AT_START"
BRANCH="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"

log "SpaceWheat release  $VERSION_TAG"
echo "source id:   $SOURCE_ID"
echo "branch:      $BRANCH"
echo "desktop:     $DO_DESKTOP"
echo "web:         $DO_WEB"
echo "run dir:     $RUN_DIR"

# A dirty tree is normal here — a second agent edits this repo — so this is a
# statement of fact, not a refusal. What IS refused, by the lanes themselves, is
# a tree that moves DURING a build: that artifact is a blend of two source
# states and no single id describes it.
if [ -n "$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null)" ]; then
    warn "Working tree is dirty. The build id carries a delta hash, so this cut is"
    warn "distinguishable — but it is not reproducible from a commit alone."
    git -C "$PROJECT_DIR" status --porcelain > "$RUN_DIR/source-tree.txt"
    git -C "$PROJECT_DIR" diff HEAD > "$RUN_DIR/source-delta.patch" 2>/dev/null || true
    echo "  recorded: $RUN_DIR/source-tree.txt (+ source-delta.patch)"
fi

if [ "$DO_PHYSICS_GATE" = true ]; then
    log "Physics / smoke gate"
    # set -o pipefail is on, so a failing gate really does fail here rather
    # than being masked by tee's exit code.
    if "$PROJECT_DIR/scripts/run_tests.sh" 2>&1 | tee "$RUN_DIR/physics-gate.log"; then
        PHYSICS_GATE_RESULT="passed"
        success "Physics gate passed"
    elif [ "$GATE_ADVISORY" = true ]; then
        # Named in the manifest rather than swallowed. A build that shipped
        # past a red gate is allowed; a build that hides it is not.
        FAILED_NAMES="$(grep -oP '(?<=^FAILED )\S+' "$RUN_DIR/physics-gate.log" 2>/dev/null | head -20 | paste -sd, - || true)"
        PHYSICS_GATE_RESULT="FAILED, built anyway (advisory)${FAILED_NAMES:+ — $FAILED_NAMES}"
        warn "Physics gate FAILED. --gate-advisory is set, so the cut continues."
        warn "The manifest will say so: $PHYSICS_GATE_RESULT"
    else
        PHYSICS_GATE_RESULT="FAILED"
        error "Physics gate failed — see $RUN_DIR/physics-gate.log
Pass --gate-advisory to cut anyway; the manifest then records the failure."
    fi
else
    PHYSICS_GATE_RESULT="SKIPPED"
    warn "Skipping physics gate"
fi

DESKTOP_RESULT="skipped"
WEB_RESULT="skipped"

if [ "$DO_DESKTOP" = true ]; then
    log "===== DESKTOP LANE ====="
    if "$PROJECT_DIR/scripts/validate-desktop-release.sh" \
        --report-root "$REPORT_ROOT" "${DESKTOP_EXTRA[@]+"${DESKTOP_EXTRA[@]}"}"; then
        DESKTOP_RESULT="ok"
    else
        DESKTOP_RESULT="FAILED"
        error "Desktop lane failed — see $RUN_DIR"
    fi
fi

if [ "$DO_WEB" = true ]; then
    log "===== WEB LANE ====="
    if "$PROJECT_DIR/scripts/validate-web-release.sh" \
        --report-root "$REPORT_ROOT" "${WEB_EXTRA[@]+"${WEB_EXTRA[@]}"}"; then
        WEB_RESULT="ok"
    else
        WEB_RESULT="FAILED"
        error "Web lane failed — see $RUN_DIR/web"
    fi
fi

sw_assert_source_unchanged

# ---------------------------------------------------------------------------
# The manifest. This is the deliverable — the archives are just its subject.
# ---------------------------------------------------------------------------
BUILD_ID_SLUG="$(printf '%s' "$SOURCE_ID" | tr '.' '-')"
MANIFEST="$PACKAGE_ROOT/RELEASE-${VERSION_TAG}-${BUILD_ID_SLUG}.md"
mkdir -p "$PACKAGE_ROOT"

{
    echo "# SpaceWheat $VERSION_TAG"
    echo
    echo "| | |"
    echo "|---|---|"
    echo "| version | \`$VERSION_TAG\` (application/config/version) |"
    echo "| source id | \`$SOURCE_ID\` |"
    echo "| branch | \`$BRANCH\` |"
    echo "| cut | $(date -u '+%Y-%m-%d %H:%M UTC') |"
    echo "| desktop lane | $DESKTOP_RESULT |"
    echo "| web lane | $WEB_RESULT |"
    echo "| physics gate | $PHYSICS_GATE_RESULT |"
    echo "| gate logs | \`releases/validation/$SW_RUN_TIMESTAMP/\` |"
    echo
    if [[ "$SOURCE_ID" == *dirty* ]]; then
        echo "> Cut from a dirty working tree. The delta is recorded at"
        echo "> \`releases/validation/$SW_RUN_TIMESTAMP/source-delta.patch\`;"
        echo "> the commit alone does not reproduce this build."
        echo
    fi
    echo "## Artifacts"
    echo
    echo "| file | size | sha256 |"
    echo "|---|---:|---|"
    shopt -s nullglob
    for f in "$PACKAGE_ROOT"/*"$VERSION_TAG"*.zip "$PACKAGE_ROOT"/*"$VERSION_TAG"*.tar.gz; do
        printf '| `%s` | %s | `%s` |\n' \
            "$(basename "$f")" \
            "$(du -h "$f" | cut -f1)" \
            "$(sha256sum "$f" | cut -c1-16)…"
    done
    shopt -u nullglob
    echo
    echo "## Before uploading"
    echo
    echo "- itch, browser build: Embed options → Frame options → **SharedArrayBuffer"
    echo "  support** must be ticked. A threaded Godot export cannot start without"
    echo "  cross-origin isolation; with the box unticked the shell says so instead"
    echo "  of going black. It does **not** fix embedded Firefox (itch's isolation"
    echo "  rides on COEP credentialless, which Firefox does not implement) —"
    echo "  popping out of the frame works there."
    echo "- \`scripts/itch-push.sh\` uploads from \`releases/packages\` via butler."
} > "$MANIFEST"

echo ""
log "Release cut: $VERSION_TAG ($SOURCE_ID)"
cat "$MANIFEST"
echo ""
echo "  manifest: $MANIFEST"
echo "  packages: $PACKAGE_ROOT"
echo "  logs:     $RUN_DIR"
