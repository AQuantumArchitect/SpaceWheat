#!/usr/bin/env bash
# scripts/lib/release_paths.sh — where a release lives, and what it is called.
#
# WHY THIS EXISTS
#
# Every release path in this repo used to be declared inline, as a
# `${VAR:-$PROJECT_DIR/releases/...}` default, in whichever script happened to
# need it. Eight scripts, each holding its own copy of the layout. Two of them
# drifted, and neither drift was visible from the outside:
#
#   - package-web-build.sh defaulted to releases/web while build-web-local.sh
#     wrote releases/web-local, so the web packager pointed at a folder nothing
#     in the repo has ever produced. Run with no arguments it simply refused.
#   - validate-desktop-release.sh defaulted VERSION_TAG to the literal "dev" and
#     forwarded it unconditionally, overriding the packager's config/version
#     default — the exact drift docs/release/DESKTOP_RELEASE_WORKFLOW.md warns
#     against in writing, performed by the orchestrator the doc describes.
#
# A layout that lives in eight places is not a layout, it is eight opinions.
# This file is the one place. Scripts source it and ask; they do not restate it.
#
# Callers must define PROJECT_DIR before sourcing.

# The exported game, before packaging. Desktop and web are exported by
# different lanes into different roots because they are different shapes: the
# desktop root holds one subfolder per platform, the web root IS the bundle.
sw_desktop_export_root() { printf '%s' "${OUTPUT_ROOT:-$PROJECT_DIR/releases/local}"; }
sw_web_export_root()     { printf '%s' "${WEB_OUTPUT_ROOT:-$PROJECT_DIR/releases/web-local}"; }

# Distributable archives — the only folder anything outside this repo reads.
# itch-push.sh uploads from here; nothing else should be uploaded from anywhere.
sw_package_root()        { printf '%s' "${PACKAGE_ROOT:-$PROJECT_DIR/releases/packages}"; }

# Gate output: smoke logs, profiles, and the release manifest, one dir per run.
sw_report_root()         { printf '%s' "${REPORT_ROOT:-$PROJECT_DIR/releases/validation}"; }

# The release name, from the one place that holds it: application/config/version
# in project.godot — the same string the title screen shows. Derived, never
# typed, so an archive cannot be named something the game inside does not claim.
#
# Passing --version to a packaging script overrides this and reintroduces
# exactly the drift the default exists to prevent. The orchestrators therefore
# forward --version only when a human explicitly passed one.
sw_project_version() {
    local v
    v="$(grep -oP '^config/version="\K[^"]+' "$PROJECT_DIR/project.godot" 2>/dev/null || true)"
    printf '%s' "${v:-dev}"
}
