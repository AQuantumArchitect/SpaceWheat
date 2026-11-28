"""Small / high-DPI windows: stretch aspect, overlay clamp, touch hit floor (#156).

The project.godot assertions always run. The layout assertions drive the REAL
UILayoutManager headless (tests/layout_touch_probe.gd) and skip when godot is
not on PATH.
"""
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PROBE = ROOT / "tests" / "layout_touch_probe.gd"
EDGE = 12.0  # UILayoutManager.OVERLAY_EDGE_MARGIN


def _setting(key: str) -> str:
    m = re.search(rf'^{re.escape(key)}=(.+)$', (ROOT / "project.godot").read_text(), re.M)
    assert m, f"{key} missing from project.godot"
    return m.group(1).strip()


def test_stretch_settings():
    assert _setting("window/stretch/mode") == '"canvas_items"'
    # expand: extra window area becomes more canvas rather than letterbox bars
    # or a squashed 16:9 layout (implicit "ignore").
    assert _setting("window/stretch/aspect") in ('"expand"', '"keep"')
    assert _setting("window/size/viewport_width") == "1280"
    assert _setting("window/size/viewport_height") == "720"


@pytest.fixture(scope="module")
def cases():
    if shutil.which("godot") is None:
        pytest.skip("godot not on PATH")
    proc = subprocess.run(["godot", "--headless", "--script", str(PROBE)],
                          cwd=ROOT, capture_output=True, text=True, timeout=300)
    line = next((l for l in proc.stdout.splitlines() if l.startswith('{"cases"')), None)
    assert line, f"probe emitted no JSON.\n{proc.stdout}\n{proc.stderr}"
    return json.loads(line)["cases"]


def test_overlays_fit_viewport(cases):
    for c in cases:
        w, h = c["size"]
        for mode, (mw, mh) in c["modals"].items():
            assert mw <= w - 2 * EDGE and mh <= h - 2 * EDGE, (c["size"], mode)


def test_desktop_overlays_unchanged_at_720p(cases):
    c = next(c for c in cases if c["size"] == [1280, 720] and not c["touch"])
    assert c["modals"]["medium"] == [704.0, 504.0]


def test_touch_floor(cases):
    for c in cases:
        if c["touch"]:
            assert c["touch_min"] >= 44 and c["chip_h_30"] >= 44
            assert c["action_row_h"] >= 44
        else:
            assert c["touch_min"] == 0 and c["chip_h_30"] == 30
        assert c["chip_h_60"] == 60
