"""The application icon reaches every shipped artifact.

#510 was open because project.godot had no `config/icon` at all and every
icon field in export_presets.cfg was `""` — so the Windows .exe, the taskbar,
Explorer, the itch app entry and the web favicon all carried the stock Godot
robot. The wiring is five separate fields across two files plus a generated
.ico, and a single empty one silently falls back to the robot with no error
anywhere. That is exactly the kind of gap that only a test notices.

These assert the WIRING, not the art: that each field is set, that what it
points at exists, and that the .ico really contains the frames Windows will
ask for. Changing the artwork is free; quietly unhooking it is not.

Regenerate everything with: bash scripts/build-app-icon.sh
"""
import struct
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

# Godot resource paths are res://-rooted; these are the fields that decide
# what each shipped artifact shows.
PROJECT_FIELDS = {
    "config/icon": "res://Assets/icon.svg",
    "config/windows_native_icon": "res://Assets/icon.ico",
}
PRESET_FIELDS = {
    "application/icon": "res://Assets/icon.ico",
    "application/console_wrapper_icon": "res://Assets/icon.ico",
    "progressive_web_app/icon_144x144": "res://Assets/icon_raster/icon_144.png",
    "progressive_web_app/icon_180x180": "res://Assets/icon_raster/icon_180.png",
    "progressive_web_app/icon_512x512": "res://Assets/icon_raster/icon_512.png",
}

# Windows picks a frame per context: 16 in the title bar, 32 in the taskbar,
# 48 in Explorer's medium view, 256 for the extra-large view and the modern
# alt-tab. Missing one means Windows rescales a neighbour and it looks soft.
REQUIRED_ICO_FRAMES = {16, 24, 32, 48, 64, 128, 256}


def _res_to_path(res: str) -> Path:
    assert res.startswith("res://"), f"not a res:// path: {res}"
    return ROOT / res[len("res://") :]


@pytest.fixture(scope="module")
def project_godot() -> str:
    return (ROOT / "project.godot").read_text(encoding="utf-8")


@pytest.fixture(scope="module")
def export_presets() -> str:
    return (ROOT / "export_presets.cfg").read_text(encoding="utf-8")


@pytest.mark.parametrize("key,expected", sorted(PROJECT_FIELDS.items()))
def test_project_godot_icon_fields(project_godot: str, key: str, expected: str) -> None:
    line = f'{key}="{expected}"'
    assert line in project_godot, (
        f"project.godot is missing {line!r}. With no {key} Godot falls back to its "
        f"built-in robot and nothing warns you."
    )
    assert _res_to_path(expected).is_file(), f"{key} points at a missing file: {expected}"


@pytest.mark.parametrize("key,expected", sorted(PRESET_FIELDS.items()))
def test_export_preset_icon_fields(export_presets: str, key: str, expected: str) -> None:
    assert f'{key}=""' not in export_presets, (
        f"export_presets.cfg has {key} empty — that artifact ships the stock Godot icon."
    )
    line = f'{key}="{expected}"'
    assert line in export_presets, f"export_presets.cfg is missing {line!r}"
    assert _res_to_path(expected).is_file(), f"{key} points at a missing file: {expected}"


def test_ico_carries_every_frame_windows_asks_for() -> None:
    """Parse the .ico directory directly rather than trusting Pillow, so this
    also catches a structurally malformed file that a lenient reader would
    happily open."""
    blob = (ROOT / "Assets/icon.ico").read_bytes()
    reserved, kind, count = struct.unpack_from("<HHH", blob, 0)
    assert reserved == 0 and kind == 1, "not an ICO file (bad ICONDIR header)"
    assert count > 0, "ICO declares zero frames"

    found = set()
    for i in range(count):
        w, h, _colours, _res, planes, bits, nbytes, offset = struct.unpack_from(
            "<BBBBHHII", blob, 6 + 16 * i
        )
        # A width byte of 0 encodes 256 — the format has no room for the real value.
        width = w or 256
        height = h or 256
        assert width == height, f"frame {i} is {width}x{height}, icons must be square"
        assert bits == 32, f"frame {width} is {bits}-bit; alpha needs 32"
        assert planes == 1, f"frame {width} declares {planes} colour planes"
        assert offset + nbytes <= len(blob), f"frame {width} runs past the end of the file"
        assert nbytes > 0, f"frame {width} is empty"
        found.add(width)

    missing = REQUIRED_ICO_FRAMES - found
    assert not missing, f"Assets/icon.ico is missing frames {sorted(missing)} (has {sorted(found)})"


def test_icon_svgs_are_generated_not_hand_edited() -> None:
    """Both SVGs must stay reproducible from tools/build_app_icon.py, because
    the whole point is that the icon tracks the game's live palette. A stray
    hand-edit would survive until the next regeneration silently reverted it."""
    for name in ("icon.svg", "icon_small.svg"):
        svg = (ROOT / "Assets" / name).read_text(encoding="utf-8")
        assert svg.startswith("<svg"), f"{name} does not start with <svg"
        assert "<title>SpaceWheat</title>" in svg, f"{name} lost its title"
        # The generator emits the ground rect first and the ripeness ring off
        # visual_themes.json's accent; both are load-bearing identity.
        assert 'rx="96"' in svg, f"{name} lost the rounded app-tile ground"
        assert "#FFCC4C" in svg or "#FFCC4D" in svg, f"{name} lost the accent gold ripeness ring"
