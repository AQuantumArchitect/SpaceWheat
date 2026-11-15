"""Gold objective banner: small "[E] more about this" line (issue #81).

Static contract checks (no Godot needed): the line exists, is gated on real
detail, E/Esc/tap toggle the detail with pause, and nothing on that path can
accept or complete a quest (only R accepts).
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BANNER = (ROOT / "UI/Widgets/ActFilament.gd").read_text()
SHELL = (ROOT / "UI/PlayerShell.gd").read_text()
PROG = (ROOT / "UI/Core/UIProgression.gd").read_text()


def _func(src: str, name: str) -> str:
    m = re.search(r"^(?:static )?func %s\(.*?(?=^(?:static )?func |\Z)" % name, src, re.S | re.M)
    assert m, name
    return m.group(0)


def test_line_text_and_gating():
    assert 'HINT_TEXT := "[E] more about this"' in BANNER
    assert "_more_label.visible = has_more() and not _expanded" in BANNER
    assert "UIProgression.objective_more()" in BANNER
    assert "static func objective_more()" in PROG


def test_e_esc_and_tap_toggle_detail():
    toggle = _func(SHELL, "toggle_objective_more")
    assert "expand_more()" in toggle and "_set_global_paused(true)" in toggle
    assert "_set_global_paused(false)" in toggle
    assert "KEY_ESCAPE" in SHELL.split("func _input")[1].split("event.keycode == KEY_E:")[0]
    assert "toggle_objective_more" in BANNER  # tap on the small line


def test_resume_collapses_detail():
    assert "collapse_more()" in _func(SHELL, "_set_global_paused")


def test_more_path_never_accepts():
    for fn in (_func(SHELL, "toggle_objective_more"),
               _func(BANNER, "expand_more"), _func(BANNER, "collapse_more"),
               _func(PROG, "objective_more")):
        # actions, not words: read-only helpers like route_claim are fine
        assert not re.search(
            r"accept_quest\(|_accept_selected\(|complete_quest\(|claim_quest\(|submit\(|\.accept\(",
            fn), fn


def test_held_lesson_line_reads_u_then_e_after_charge_attended():
    hint = _func(PROG, "objective_more_hint")
    assert '"[%s] then [E] for more" % SurfaceRooms.KEY_HELD' in hint
    assert '"[E] more about this"' in hint
    assert "charge_attended" in hint and "is_charge_hold" in hint
    assert '!= "ready"' in hint  # a claimable lesson keeps the plain line
    assert "objective_more_hint()" in BANNER and "_more_label.text = hint" in BANNER


def test_claim_on_charge_always_shows_the_line():
    more = _func(PROG, "objective_more")
    assert "_is_charge_ready(best)" in more and "_charge_route(best)" in more
    assert '"ready"' in _func(PROG, "_is_charge_ready")
    assert "route_claim(q)" in _func(PROG, "_charge_route")


def test_hint_never_accepts():
    for fn in (_func(PROG, "objective_more_hint"), _func(PROG, "_is_charge_ready")):
        assert not re.search(r"accept|submit", fn, re.I), fn
