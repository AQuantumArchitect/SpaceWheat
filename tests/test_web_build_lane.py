"""The browser build must be as traceable and as honest as a desktop one.

The web channel spent a release cycle written off as unbuildable. The cause was
not the toolchain: `build-all-platforms.sh` checked for `emcc` BEFORE running its
own `source ~/emsdk/emsdk_env.sh`, so from a clean shell it reported Emscripten
missing on a machine where emsdk was fully installed. A prerequisite check that
disagrees with the script containing it produces a confident false negative, and
that one cost a whole channel.

These tests pin the repair and the two properties a shipped browser bundle needs:
it carries its commit stamp, and it fails loudly rather than shipping a bundle
whose physics engine silently didn't make it in.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

ALL_PLATFORMS = ROOT / "scripts/build-all-platforms.sh"
WEB_LOCAL = ROOT / "scripts/build-web-local.sh"
DESKTOP_LOCAL = ROOT / "scripts/build-desktop-local.sh"
STAMP_LIB = ROOT / "scripts/lib/build_stamp.sh"
GDEXTENSION = ROOT / "quantum_matrix.gdextension"


def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8")


def test_emscripten_is_activated_before_it_is_checked_for():
    """The false negative that cost the web channel a release cycle."""
    src = _read(ALL_PLATFORMS)
    activate = src.index('source "$HOME/emsdk/emsdk_env.sh"')
    check = src.index("command -v emcc")
    assert activate < check, (
        "build-all-platforms.sh checks for emcc before activating emsdk — from a "
        "clean shell that reports 'Emscripten not found' on a machine where it is "
        "installed, which is how the web channel got written off as unbuildable"
    )


def test_emsdk_is_activated_in_exactly_one_place():
    """Two activations drifted below the check and neither could rescue it."""
    src = _read(ALL_PLATFORMS)
    activations = re.findall(r'^\s*source "\$HOME/emsdk/emsdk_env\.sh"', src, re.M)
    assert len(activations) == 1, (
        f"emsdk is activated {len(activations)} times; one authority, before the check"
    )


def test_both_export_lanes_share_one_build_stamp_authority():
    """A browser bug report must name its commit exactly like a desktop one."""
    assert STAMP_LIB.exists(), "scripts/lib/build_stamp.sh is missing"
    lib = _read(STAMP_LIB)
    assert "rev-parse --short HEAD" in lib, "the stamp must come from git, not by hand"
    assert "-dirty" in lib and "status --porcelain" in lib, (
        "a pack built off uncommitted edits must say so"
    )

    for lane in (WEB_LOCAL, DESKTOP_LOCAL):
        src = _read(lane)
        assert "lib/build_stamp.sh" in src, f"{lane.name} does not source the stamp authority"
        assert "trap remove_build_stamp EXIT" in src, (
            f"{lane.name} could leave a stamp behind for the next source run to claim"
        )
        assert "write_build_stamp" in src, f"{lane.name} never writes the stamp"


def test_web_lane_stamps_before_it_imports_before_it_exports():
    """Packing an unimported new file ships a bundle that reports 'source'."""
    src = _read(WEB_LOCAL)
    stamp_at = src.index("write_build_stamp\n")
    import_at = src.index("--import")
    export_at = src.index("--export-release")
    assert stamp_at < import_at < export_at, (
        "the web stamp must be written and imported before the export runs"
    )


def test_web_lane_refuses_a_bundle_without_its_physics_engine():
    """Godot omits a mismatched side-module and still exits 0.

    The threads/nothreads ABI trap is documented in quantum_matrix.gdextension
    because it already hid the web entry from the exporter for a full release
    cycle. When it bites, the export "succeeds" and the failure only appears once
    a browser tries to boot — and since the native-only cutover that failure is a
    refusal to start, not a slow game. The lane has to catch it.
    """
    src = _read(WEB_LOCAL)
    assert "Export produced no libquantummatrix.wasm" in src, (
        "the web lane must fail when the GDExtension does not reach the bundle"
    )
    # error() exits 1 — a warn() here would let an unplayable bundle ship.
    assert re.search(r"error\s*\\?\s*\n?\s*\"Export produced no libquantummatrix", src), (
        "the missing-extension case must call error() (exit 1), not merely warn"
    )
    # And it must refuse to even start an export with no extension built.
    assert "No web extension at" in src, (
        "the web lane must refuse to export when native/bin/web/*.wasm is absent"
    )


def test_gdextension_web_entry_names_the_variant_the_preset_ships():
    """A bare web.wasm32 key is rejected by a shared-memory engine at load."""
    ext = _read(GDEXTENSION)
    assert "web.threads.wasm32" in ext, (
        "the web GDExtension entry must name the threads variant explicitly"
    )
    preset = _read(ROOT / "export_presets.cfg")
    assert "variant/thread_support=true" in preset, (
        "the Web preset ships the threads engine — the .gdextension entry and the "
        "preset must agree, or the extension silently never loads"
    )
    assert "variant/extensions_support=true" in preset, (
        "the Web preset must enable GDExtension support or the physics cannot ship"
    )
