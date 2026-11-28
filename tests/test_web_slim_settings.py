"""Web-Slim (GitHub Pages demo) must stay non-threaded and touch-ready.

Pages cannot send COOP/COEP, so a threaded export would boot to a refusal
notice. Taps must arrive as clicks, and the shell canvas must fill the window.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def _read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _webslim_options() -> dict:
    src = _read("export_presets.cfg")
    sections = re.split(r"(?m)^(?=\[preset\.\d+(?:\.options)?\]$)", src)
    idx = None
    for s in sections:
        m = re.match(r"\[preset\.(\d+)\]", s)
        if m and re.search(r'(?m)^name="Web-Slim"$', s):
            idx = m.group(1)
    assert idx is not None, "no Web-Slim preset"
    for s in sections:
        if s.startswith(f"[preset.{idx}.options]"):
            return dict(re.findall(r"(?m)^([\w/]+)=(.*)$", s))
    raise AssertionError("Web-Slim has no options section")


def test_threads_stay_off():
    assert _webslim_options()["variant/thread_support"] == "false"


def test_preset_shell_and_resize():
    o = _webslim_options()
    assert o["html/custom_html_shell"] == '"res://web/spacewheat_shell.html"'
    assert o["html/canvas_resize_policy"] == "2"
    assert o["html/focus_canvas_on_start"] == "true"


def test_touch_emulates_mouse_and_stretch_aspect_explicit():
    proj = _read("project.godot")
    assert re.search(r"(?m)^pointing/emulate_mouse_from_touch=true$", proj)
    assert re.search(r'(?m)^window/stretch/aspect="[a-z_]+"$', proj)


def test_shell_canvas_fills_viewport():
    shell = _read("web/spacewheat_shell.html")
    assert "width=device-width" in shell
    assert re.search(r"#canvas\s*\{[^}]*width:\s*100%[^}]*height:\s*100%", shell)


def test_build_script_requires_artifacts():
    s = _read("scripts/build-web-slim.sh")
    for f in ("index.html", "index.pck", "index.wasm", "libquantummatrix.nothreads.wasm", ".nojekyll"):
        assert f in s


def test_layout_manager_uses_godot4_platform_name():
    assert '"HTML5"' not in _read("UI/Managers/UILayoutManager.gd")
