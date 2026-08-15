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
import subprocess
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


def test_windows_binary_declares_a_version_and_a_copyright():
    """Right-click → Properties must not contradict the game inside.

    These four fields are the ONE version surface that does not read through
    BuildInfo: Windows accepts only `a.b.c.d`, so they cannot hold "0.1.0-alpha"
    and cannot be derived from config/version by the packaging script. Left at
    Godot's default they report FileVersion 1.0.0.0 — which is what the rc3
    .exe actually shipped, a binary claiming 1.0 final while the title screen
    said rc3. Relabelling the release does not move them, so they need their own
    assertion or they drift again.
    """
    src = _read(ROOT / "export_presets.cfg")
    for field in ("application/file_version", "application/product_version"):
        m = re.search(rf'^{re.escape(field)}="([^"]*)"', src, re.M)
        assert m, f"{field} vanished from export_presets.cfg"
        assert re.fullmatch(r"\d+\.\d+\.\d+\.\d+", m.group(1)), (
            f"{field} must be four integers (Windows accepts nothing else); got {m.group(1)!r}"
        )
    copyright_m = re.search(r'^application/copyright="([^"]*)"', src, re.M)
    assert copyright_m and copyright_m.group(1).strip(), (
        "application/copyright is empty — the shipped .exe carries no LegalCopyright"
    )


def test_archives_carry_their_licence():
    """Twemoji is CC-BY 4.0 and attribution is its only condition.

    Every rc3 archive contained binaries only, so that condition was unmet in
    everything shipped so far. The notices file existing in the repo satisfies
    nothing — it has to travel inside the artifact, which is what the packaging
    script now guarantees (and refuses to build without).
    """
    assert (ROOT / "LICENSE").is_file(), "no LICENSE at repo root"
    notices = ROOT / "THIRD_PARTY_NOTICES.md"
    assert notices.is_file(), "no THIRD_PARTY_NOTICES.md at repo root"
    body = _read(notices)
    for owed in ("Twemoji", "CC-BY 4.0", "Eigen", "MPL", "Godot"):
        assert owed in body, f"THIRD_PARTY_NOTICES.md never mentions {owed}"
    packaging = _read(ROOT / "scripts/package-desktop-builds.sh")
    assert "THIRD_PARTY_NOTICES.md" in packaging and "LICENSE" in packaging, (
        "packaging script does not copy the licence files into the archives"
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
    # The derivation itself lives in ONE place now. Asserting the grep appears
    # in each script would pass on a comment that merely mentions config/version
    # — which is exactly what happened once the greps were centralised.
    authority = _read(ROOT / "scripts/lib/release_paths.sh")
    assert "sw_project_version" in authority and "config/version" in authority, (
        "release_paths.sh must hold the one config/version derivation"
    )
    for script in (
        "scripts/package-desktop-builds.sh",
        "scripts/package-web-build.sh",
        "scripts/validate-desktop-release.sh",
        "scripts/validate-web-release.sh",
        "scripts/release.sh",
    ):
        src = _read(ROOT / script)
        assert "sw_project_version" in src, (
            f"{script} must take its version from sw_project_version(), not its own default"
        )
    # itch-push.sh reads the version to label an upload but is not a build lane,
    # so it keeps its own standalone grep rather than sourcing the release libs.
    push = _read(ROOT / "scripts/itch-push.sh")
    assert "config/version" in push and "project.godot" in push, (
        "itch-push.sh must derive --userversion from project.godot"
    )


def test_the_web_packager_points_at_the_folder_the_web_builder_writes():
    """These two defaults disagreed, and nothing said so.

    package-web-build.sh defaulted to releases/web; build-web-local.sh has
    always written releases/web-local. So the web packager pointed at a folder
    nothing in this repo has ever produced, and a bare run simply refused —
    which is why the web zip kept getting assembled by hand instead. A default
    that names a nonexistent place is worse than no default.
    """
    paths = _read(ROOT / "scripts/lib/release_paths.sh")
    builder = _read(ROOT / "scripts/build-web-local.sh")
    packager = _read(ROOT / "scripts/package-web-build.sh")

    assert "sw_web_export_root" in paths, "release_paths.sh lost the web export root"
    assert "releases/web-local" in paths, (
        "the shared web export root must name the folder build-web-local.sh writes"
    )
    assert "releases/web-local" in builder, "build-web-local.sh changed where it writes"
    assert "sw_web_export_root" in packager, (
        "package-web-build.sh must ask the shared authority where the export is, "
        "rather than restating a path that can drift out from under it"
    )


def test_the_desktop_orchestrator_does_not_override_the_derived_version():
    """It used to default VERSION_TAG to "dev" and forward it unconditionally.

    docs/release/DESKTOP_RELEASE_WORKFLOW.md warns in writing that passing
    --version "reintroduces exactly the drift the default exists to prevent".
    The orchestrator that doc describes was doing it on every run, so archives
    cut through the documented path were named spacewheat-windows-dev.zip while
    the game inside claimed a real version.
    """
    src = _read(ROOT / "scripts/validate-desktop-release.sh")
    assert 'VERSION_TAG="${VERSION_TAG:-dev}"' not in src, (
        "the orchestrator is back to defaulting the release name to 'dev'"
    )
    assert "VERSION_EXPLICIT" in src, (
        "--version must only be forwarded when a human actually passed one"
    )


def test_every_platform_can_be_cut_by_one_command():
    """A release nobody can run in one command is a release assembled by memory.

    The desktop lane had an orchestrator; the web lane had all the same pieces
    and none. So a browser cut was reassembled by hand each time and whatever
    got skipped was invisible afterwards. build-all-platforms.sh is NOT this: it
    builds the three native extensions and prints the export commands.
    """
    release = ROOT / "scripts/release.sh"
    web = ROOT / "scripts/validate-web-release.sh"
    assert release.is_file() and web.is_file(), "the release orchestrators went missing"
    src = _read(release)
    for lane in ("validate-desktop-release.sh", "validate-web-release.sh"):
        assert lane in src, f"release.sh must drive {lane}"
    assert "sha256sum" in src, (
        "the manifest must record a checksum per artifact — otherwise 'which build "
        "is on itch' is answerable only by rebuilding it"
    )

    web_src = _read(web)
    for stage in ("test_web_extension_links.py", "gate-web-bundle.mjs", "package-web-build.sh"):
        assert stage in web_src, f"the web lane must run {stage}"
    assert "--skip-gate" in web_src, (
        "skipping the headers-absent browser gate must be an explicit choice, "
        "not what happens when a dependency is quietly missing"
    )


def test_a_build_whose_source_moved_is_refused():
    """An export reads the tree over minutes; a second agent edits it live.

    If the tree moves mid-export the artifact is a blend of two source states
    and its stamp — captured at one instant — honestly describes neither. The
    last desktop cut went out while its own inputs were still being written.
    """
    lib = _read(STAMP_LIB)
    assert "sw_capture_source_id" in lib and "sw_assert_source_unchanged" in lib, (
        "the stamp lib lost the moved-tree guard"
    )
    for script in ("scripts/release.sh", "scripts/validate-web-release.sh"):
        src = _read(ROOT / script)
        assert "sw_capture_source_id" in src and "sw_assert_source_unchanged" in src, (
            f"{script} must check that its source did not move under it"
        )


def test_the_web_lane_names_its_archive_the_way_the_desktop_lane_does():
    """The browser build was the one lane with no packaging authority.

    Desktop archives have been named from config/version since the alpha, and
    the assertion above pins it. The web zip was named by hand every time — so
    three materially different bundles (the broken alpha, the emsdk-pinned
    rebuild, the async-lookahead rebuild) all shipped as
    "spacewheat-web-0.1.0-alpha.zip", each overwriting the last. Neither the
    filename nor itch's upload list could tell them apart.
    """
    script = ROOT / "scripts/package-web-build.sh"
    assert script.is_file(), "the web lane lost its packaging script"
    src = _read(script)
    assert "build_id" in src, (
        "the web archive name must carry the build id, not the release name alone"
    )
    assert "Refusing to overwrite" in src, (
        "packaging must refuse to replace an existing archive — silently "
        "overwriting a shipped bundle is exactly the defect this script exists to end"
    )


def test_two_dirty_builds_are_told_apart():
    """"-dirty" says THAT there were edits, never WHICH.

    Another agent edits this repo concurrently, so building off a dirty tree is
    the normal case. Two dirty builds an hour apart are routinely different
    games, and under a bare "-dirty" suffix they carried identical stamps.
    """
    src = _read(STAMP_LIB)
    assert "build_id()" in src, "the stamp lib lost its shared build_id()"
    assert "diff HEAD" in src and "sha1sum" in src, (
        "a dirty stamp must hash the uncommitted delta, so two different dirty "
        "trees at the same commit get different build ids"
    )


def test_the_windows_version_fields_track_the_release():
    """Right-click → Properties must not name a different release than the game.

    These four integers cannot hold "0.1.1-alpha" and so cannot be derived from
    config/version by the packaging script — which is precisely why they drift:
    the rc3 .exe shipped FileVersion 1.0.0.0 while the title screen said rc3.
    Shape alone did not catch that; the numbers have to be compared.
    """
    version = re.search(r'^config/version="([^"]+)"', _read(PROJECT_GODOT), re.M).group(1)
    numeric = re.match(r"(\d+)\.(\d+)\.(\d+)", version)
    assert numeric, f"config/version {version!r} does not start with a.b.c"
    expected = ".".join(numeric.groups())

    src = _read(ROOT / "export_presets.cfg")
    for field in ("application/file_version", "application/product_version"):
        got = re.search(rf'^{re.escape(field)}="([^"]*)"', src, re.M).group(1)
        assert got.startswith(expected + "."), (
            f"{field} is {got!r} but the game calls itself {version!r} — "
            f"expected it to start with {expected}."
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

def test_no_desktop_archive_can_silently_replace_another():
    """The defect the web lane was fixed for was still live on the desktop side.

    Desktop archives were named spacewheat-<os>-<version> with no build id, and
    packaging did `rm -f` on that name first. So two different desktop builds at
    one version — a rebuild after a fix, a cut from a different tree — landed on
    the same filename and the earlier one vanished without a word. Identical in
    kind to the three browser bundles that all shipped as
    spacewheat-web-0.1.0-alpha.zip.
    """
    src = _read(ROOT / "scripts/package-desktop-builds.sh")
    assert "build_id" in src, "desktop archive names must carry the build id"
    assert "Refusing to overwrite" in src, (
        "packaging must refuse to replace an existing desktop archive"
    )
    for name in ("spacewheat-windows-${VERSION_TAG}-${BUILD_ID}.zip",
                 "spacewheat-linux-${VERSION_TAG}-${BUILD_ID}.tar.gz"):
        assert name in src, f"desktop archive name lost its build id: {name}"


def test_the_source_guard_baseline_survives_into_the_caller():
    """A behavioural test, because the bug was invisible to a string check.

    sw_capture_source_id assigns SW_SOURCE_ID_AT_START. Called as
    `x="$(sw_capture_source_id)"` the assignment happens in a command
    substitution — a subshell — and dies there, so the later comparison runs
    against an empty baseline and refuses a perfectly good build. That is
    exactly how the first full web cut died: export finished, guard rejected it.

    Every static assertion about this guard passed while it was broken. This
    one runs it.
    """
    script = f"""
    set -euo pipefail
    PROJECT_DIR={ROOT}
    log() {{ :; }}
    error() {{ echo "REFUSED"; exit 3; }}
    source "$PROJECT_DIR/scripts/lib/build_stamp.sh"
    sw_capture_source_id
    [ -n "${{SW_SOURCE_ID_AT_START:-}}" ] || {{ echo "BASELINE_LOST"; exit 4; }}
    sw_assert_source_unchanged
    echo OK
    """
    done = subprocess.run(["bash", "-c", script], capture_output=True, text=True)
    assert "BASELINE_LOST" not in done.stdout, (
        "sw_capture_source_id lost its baseline — it is being called in a "
        "subshell, so the guard will refuse every build it is asked to check"
    )
    assert done.returncode == 0 and "OK" in done.stdout, (
        f"the guard rejected an unchanged tree: rc={done.returncode} "
        f"out={done.stdout!r} err={done.stderr!r}"
    )


def test_the_lanes_do_not_capture_the_baseline_in_a_subshell():
    """The call shape is the bug, so pin the call shape too."""
    for name in ("scripts/release.sh", "scripts/validate-web-release.sh"):
        src = _read(ROOT / name)
        assert '"$(sw_capture_source_id)"' not in src, (
            f"{name} captures the source id in a command substitution; the "
            f"assignment dies in the subshell and the guard refuses everything"
        )
