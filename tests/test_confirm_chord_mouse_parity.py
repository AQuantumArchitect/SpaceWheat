"""Destructive-confirm mouse parity ratchet (2026-08-24, Wave 2.1).

The confirm chord's law (QuantumInstrumentInput._cancel_pending_confirm doc):
_cancel_pending_confirm is the ONE place that clears an armed confirm outside
of F actually consuming it, so "anything but confirming cancels" can never
diverge between keyboard and mouse (wave 15: a mouse tap left a confirm armed
and a LATER unrelated F tap fired it blind).

handle_bubble_tap violated that law with a bare `_confirm_pending = {}` —
a field tap cancelled SILENTLY, unlike every other cancel path. These lints
pin the repaired shape the way test_single_dispatch_authority.py pins
dispatch: source-level, so a refactor can't silently reopen it.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QII = ROOT / "UI" / "Core" / "QuantumInstrumentInput.gd"


def _src() -> str:
    return QII.read_text(encoding="utf-8")


def test_exactly_two_sites_clear_the_pending_confirm():
    """Empty-clears of _confirm_pending: the cancel authority's own body and
    the F-consume in _dispatch_action_key. A third is a silent-cancel bug
    (that was handle_bubble_tap); zero or one means the chord is broken."""
    clears = re.findall(r"_confirm_pending = \{\}", _src())
    assert len(clears) == 2, (
        "expected exactly 2 empty-clears of _confirm_pending "
        "(cancel authority + F-consume), found %d" % len(clears)
    )


def test_bubble_tap_cancels_through_the_loud_authority():
    src = _src()
    m = re.search(
        r"func handle_bubble_tap\(.*?\n(.*?)\nfunc ", src, re.DOTALL
    )
    assert m, "handle_bubble_tap not found"
    body = m.group(1)
    assert "_cancel_pending_confirm()" in body, (
        "handle_bubble_tap no longer routes its cancel through the authority"
    )
    assert "_confirm_pending = {}" not in body, (
        "handle_bubble_tap regained a silent direct clear"
    )


def test_confirm_banner_copy_names_the_tap():
    """The banner claims 'any other key or tap cancels' — true only while the
    bubble-tap cancel stays loud; both must hold together."""
    banners = re.findall(r"press \[b\]F\[/b\] to confirm([^\"]*)", _src())
    assert banners, "confirm banner copy not found"
    for tail in banners:
        assert "tap" in tail, (
            "confirm banner stopped naming the tap cancel: %r" % tail
        )
