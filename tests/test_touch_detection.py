"""Touch mode keys off the DisplayServer capability, not a mobile export flag."""

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
ENV = (ROOT / "Core/Config/RuntimeEnv.gd").read_text(encoding="utf-8")
LAYOUT = (ROOT / "UI/Managers/UILayoutManager.gd").read_text(encoding="utf-8")


def test_is_touch_asks_the_display_server_with_feature_fallback():
    m = re.search(r"static func is_touch\(\)[^\n]*\n(.*?)(?=\n\S)", ENV, re.S)
    assert m
    body = m.group(1)
    assert "DisplayServer.is_touchscreen_available()" in body
    assert 'OS.has_feature("touchscreen")' in body


def test_layout_manager_uses_the_helper_and_not_html5():
    assert "RuntimeEnv.is_touch()" in LAYOUT
    assert "HTML5" not in LAYOUT
    assert "_detect_mobile_browser" not in LAYOUT


def test_layout_manager_reevaluates_on_a_real_touch():
    assert "InputEventScreenTouch" in LAYOUT


def test_predicate_truth_table_headless():
    godot = shutil.which("godot") or shutil.which("godot4")
    if not godot:
        pytest.skip("godot not on PATH")
    script = ROOT / "tests/touch_detection_probe.gd"
    r = subprocess.run([godot, "--headless", "--path", str(ROOT), "-s", str(script)],
                       capture_output=True, text=True, timeout=120)
    assert "TOUCH_PROBE_OK" in r.stdout, r.stdout + r.stderr
