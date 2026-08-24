"""Mouse-first copy voice lints (2026-08-24 "say the click" pass).

The law (owner playtest, 2026-08-23: "still friction about clicking into
things"): every quest action has a real mouse path (docs/MOUSE_PARITY_AUDIT.md
closed the mechanics waves ago) but the copy kept speaking keyboard-only —
"press R to accept" over a row that is click-wired. Voice rule: the click
comes first, keys ride as bracketed accelerators; a string may name a bare
"press <key>" only if the same string also names a tap/click path.

Scope is deliberate: Act-0 curriculum (tutorial_arc.json) + the always-on
route speakers (UIProgression, PlayerEventBridge). The ~38 later-act
story_flags hints are a deferred pass — do NOT widen this lint to them until
their rewrite lands, or it fails on copy nobody has authored yet.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TUTORIAL_ARC = ROOT / "Core" / "Quests" / "data" / "tutorial_arc.json"
UI_PROGRESSION = ROOT / "UI" / "Core" / "UIProgression.gd"
EVENT_BRIDGE = ROOT / "Core" / "Story" / "PlayerEventBridge.gd"

PRESS_RE = re.compile(r"\bpress(es|ing)?\b", re.IGNORECASE)
CLICK_RE = re.compile(r"\b(tap|click)", re.IGNORECASE)


def _hints():
    data = json.loads(TUTORIAL_ARC.read_text(encoding="utf-8"))
    for step in data["steps"]:
        for field in ("tutorial_hint", "body"):
            text = str(step.get(field, "")).strip()
            if text:
                yield step.get("tutorial_teaches", "?"), field, text


def test_act0_hints_never_say_press_without_a_click_twin():
    """A hint that says 'press X' for an action with a hitbox must name the
    tap in the same breath — otherwise a mouse player reads an instruction
    they cannot follow (the 2026-08-17 haiku seat stalled on exactly this)."""
    for teaches, field, text in _hints():
        if PRESS_RE.search(text):
            assert CLICK_RE.search(text), (
                "step %r %s says 'press' with no tap/click twin: %r"
                % (teaches, field, text)
            )


def test_route_authorities_speak_click_first():
    """route_accept/route_claim are the ONE spelling of the accept and claim
    doors. They must lead with the click; every speaker composes from them."""
    src = UI_PROGRESSION.read_text(encoding="utf-8")
    for fn in ("route_accept", "route_claim"):
        m = re.search(r"func %s\(\) -> String:\n\treturn \"(.+?)\"" % fn, src)
        assert m, "UIProgression lost its %s() route authority" % fn
        assert m.group(1).startswith("tap "), (
            "%s no longer leads with the click: %r" % (fn, m.group(1))
        )
    # The banner's decorate lines and both fallback consts stay click-first.
    assert "route_accept()" in src and "route_claim()" in src
    for const in ("OFFER_LINE", "REDIRECT_FALLBACK"):
        cm = re.search(r"const %s := \"(.+?)\"" % const, src)
        assert cm and CLICK_RE.search(cm.group(1)), (
            "%s lost its click wording" % const
        )


def test_event_bridge_composes_toasts_from_the_route_authority():
    """The offer and ready toasts once spelled the same routes their own way
    ('C then U, then R on its row') and drifted from the banner. They must
    compose from UIProgression.route_* — one spelling, two speakers."""
    src = EVENT_BRIDGE.read_text(encoding="utf-8")
    assert "UIProgression.route_accept()" in src, "offer toast left the route authority"
    assert "UIProgression.route_claim()" in src, "ready toast left the route authority"
    assert 'preload("res://UI/Core/UIProgression.gd")' in src
    # No resurrected keyboard-only route spellings in player-facing strings.
    for line in src.splitlines():
        if "_push(" in line and PRESS_RE.search(line):
            assert CLICK_RE.search(line), (
                "keyboard-only 'press' crept back into a toast: %r" % line.strip()
            )
