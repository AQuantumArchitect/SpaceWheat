"""The build must be able to say which build it is.

`config/version` sat at "0.9.0-beta.2" for 66 commits — through the whole
mouse-only campaign and the 3D field work — while releases/packages/ already
held v1.0-rc1 and v1.0-rc2. That string is not decoration: AppRoot paints it on
the title screen and EscapeMenu pastes it into the bug-report clipboard, so
every report filed in that window named a build nobody had played.

These tests pin the repair: one authority, three call sites reading through it,
and an export-time stamp that nobody types (and therefore nobody forgets).
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

BUILD_INFO = ROOT / "Core/Config/BuildInfo.gd"
PROJECT_GODOT = ROOT / "project.godot"
APP_ROOT = ROOT / "scenes/AppRoot.gd"
ESCAPE_MENU = ROOT / "UI/Overlays/EscapeMenu.gd"
BUILD_SCRIPT = ROOT / "scripts/build-desktop-local.sh"
# The stamp mechanics moved into a shared lib once the web lane needed them too,
# so a browser build is as traceable as a desktop one. Desktop-lane wiring
# (sourcing, trap, stamp→import→export order) is still asserted on the script;
# the stamp's own shape is asserted where it now lives.
STAMP_LIB = ROOT / "scripts/lib/build_stamp.sh"


def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_project_version_is_not_the_stale_beta():
    """The exact string that went stale must not silently come back."""
    version = re.search(r'^config/version="([^"]+)"', _read(PROJECT_GODOT), re.M)
    assert version, "project.godot lost its config/version line"
    assert version.group(1) != "0.9.0-beta.2", (
        "config/version is back at the string that sat stale for 66 commits"
    )


def test_package_and_push_take_their_version_from_the_game():
    """An artifact can never be named something the game does not claim.

    The archive name, the itch --userversion, and the title-screen stamp must
    all come from one place. If packaging took its own version (a --version
    default, a hand-edited constant), a zip could ship as v1.0-rc3 carrying a
    build whose title screen says something else — the same identity drift the
    stamp exists to end, just moved into the filename.

    Deliberately NOT asserted here: that config/version is absent from
    releases/packages/. Cutting a release puts the current version there, so
    that check fires on the correct workflow rather than on a defect. Two builds
    sharing a release name are already distinguishable by their commit stamp,
    which is the property that actually matters.
    """
    for script in ("scripts/package-desktop-builds.sh", "scripts/itch-push.sh"):
        src = _read(ROOT / script)
        assert "config/version" in src and "project.godot" in src, (
            f"{script} must derive its version from project.godot, not its own default"
        )


def test_build_info_is_the_single_authority():
    """No surface may read the raw setting behind BuildInfo's back."""
    assert BUILD_INFO.exists(), "Core/Config/BuildInfo.gd is missing"
    src = _read(BUILD_INFO)
    assert "class_name BuildInfo" in src
    for fn in ("func version(", "func stamp(", "func display("):
        assert fn in src, f"BuildInfo lost {fn}"

    raw = 'ProjectSettings.get_setting("application/config/version"'
    for path in (APP_ROOT, ESCAPE_MENU):
        assert raw not in _read(path), (
            f"{path.name} reads config/version directly instead of through BuildInfo"
        )


def test_every_version_surface_reads_build_info():
    """Title stamp, dev row, and the bug-report payload — all three."""
    assert "BuildInfo.display()" in _read(APP_ROOT), (
        "the title-screen version stamp no longer reads BuildInfo"
    )
    escape = _read(ESCAPE_MENU)
    assert escape.count("BuildInfo.display()") >= 2, (
        "EscapeMenu must use BuildInfo for both the dev row and the bug-report payload"
    )
    # The bug-report payload is the one that matters most: it is what a player
    # pastes into an issue. Pin it by name, not just by count.
    report = escape.split("func _gather_log_report()")[1]
    assert "BuildInfo.display()" in report.split("\nfunc ")[0], (
        "the bug-report clipboard payload dropped the build identity"
    )


def test_unstamped_builds_say_source_rather_than_guessing():
    """A missing stamp is a mode, not a failure — and must not be faked."""
    src = _read(BUILD_INFO)
    assert '"source"' in src, "BuildInfo must report 'source' when unstamped"
    assert '"required": false' in src, (
        "the stamp must load as optional — a source run has no stamp and that is not an error"
    )


def test_build_script_stamps_then_removes():
    """The stamp is written from git, packed, and then cleaned up."""
    src = _read(BUILD_SCRIPT)
    assert "write_build_stamp" in src and "remove_build_stamp" in src
    assert "rev-parse --short HEAD" in _read(STAMP_LIB), (
        "the stamp must come from git, not by hand"
    )
    assert "trap remove_build_stamp EXIT" in src, (
        "a failed export must not leave a stamp behind for the next source run to claim"
    )
    # Order matters: stamp, import, then export. Packing an unimported new file
    # ships a build that reports 'source' while claiming to be a release.
    stamp_at = src.index("write_build_stamp\n")
    import_at = src.index("--import")
    export_at = src.index("--export-release")
    assert stamp_at < import_at < export_at, (
        "build stamp must be written and imported before the export runs"
    )


def test_dirty_trees_are_marked_in_the_stamp():
    """A pack built off uncommitted edits must not claim to be its commit."""
    src = _read(STAMP_LIB)
    assert "-dirty" in src and "status --porcelain" in src, (
        "the stamp must mark builds cut from a dirty tree"
    )


def test_stamp_is_not_tracked_by_git():
    """The stamp belongs to a pack, never to the tree."""
    ignored = _read(ROOT / ".gitignore")
    assert "Core/Config/build_stamp.json" in ignored
    assert not (ROOT / "Core/Config/build_stamp.json").exists(), (
        "a build stamp is sitting in the tree — a source run would claim to be that build"
    )


def test_boot_announces_the_build_identity():
    """First line of every boot, so a log names its build even if boot dies."""
    boot = _read(ROOT / "Core/Boot/BootManager.gd")
    ready = boot.split("func _ready()")[1].split("\nfunc ")[0]
    assert "BuildInfo.display()" in ready, (
        "BootManager._ready must announce the build identity"
    )
    # Before the native-class check, which can quit(1) — a build that dies at the
    # native gate is exactly the one whose identity you need in the report.
    assert ready.index("BuildInfo.display()") < ready.index("REQUIRED_NATIVE_CLASSES"), (
        "the identity line must come before the boot gate that can quit"
    )


def test_export_smoke_refuses_an_unstamped_pack():
    """Shipping an unstamped release must fail the gate, not warn."""
    smoke = _read(ROOT / "scripts/smoke-test-desktop-export.sh")
    assert "· source" in smoke, "the smoke test must detect an unstamped pack"
    assert 'error "Export shipped unstamped' in smoke, (
        "an unstamped pack must fail the export gate, not merely log"
    )


def test_stamp_shape_matches_what_build_info_reads():
    """The writer's keys and the reader's keys must be the same keys."""
    # The printf template names its keys inline; pull them from the format string.
    fmt = re.search(r"printf '(\{.*\})\\n'", _read(STAMP_LIB))
    assert fmt, "could not find the stamp's printf template"
    written = set(re.findall(r'"(\w+)":', fmt.group(1)))
    assert written == {"commit", "branch", "built"}, f"stamp writes {written}"

    # Only the stamp dictionary `s`, not JsonFileLoader's `res` envelope.
    read = set(re.findall(r'(?<![\w.])s\.get\("(\w+)"', _read(BUILD_INFO)))
    assert read <= written, f"BuildInfo reads {read - written} which the build script never writes"
    assert {"commit", "built"} <= read, "the display line must name the commit and the build date"
