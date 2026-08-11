"""The mouse seat's two structural promises, and the verb that feeds it.

`🍄/🧪/mouse_seat.py` exists so a mouse-only persona leg cannot cheat and
cannot guess:

  - it has NO keyboard, so "reached X by mouse alone" is true by construction
    rather than by the tester's honour (every earlier wave relied on the
    latter);
  - it REFUSES an ambiguous control name instead of clicking whichever row the
    tree walk reaches first — the "hit whatever it might" failure this campaign
    is specifically chartered to avoid.

Both are one-line-deletable, and deleting either would still leave a harness
that appears to work while quietly reporting nonsense. Wave 15's standing
lesson applies: the rig surface is code too, and nothing else tests it.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEAT = ROOT / "\U0001F344" / "\U0001F9EA" / "mouse_seat.py"
LISTENER = ROOT / "\U0001F344" / "\U0001F39B️" / "rig_listener.gd"


def test_the_seat_exists_and_is_executable() -> None:
    assert SEAT.exists(), "the mouse seat is the entry point every mouse leg drives"


def test_pressing_a_key_is_refused_without_booting_a_game() -> None:
    """The refusal must be structural, not a runtime check that needs a live
    listener — a leg that boots, plays, and only THEN discovers it had a
    keyboard has already invalidated its own run."""
    proc = subprocess.run(
        [sys.executable, str(SEAT), "press", "no_such_seat", "f"],
        cwd=str(ROOT), capture_output=True, text=True, timeout=60)
    out = json.loads(proc.stdout)
    assert out["ok"] is False
    assert out["error"] == "no_keyboard", (
        "the mouse seat must refuse key presses outright; got %r" % out)
    assert proc.returncode != 0, "a refused input must not exit 0"


def test_ambiguous_control_names_are_refused_not_guessed() -> None:
    src = SEAT.read_text(encoding="utf-8")
    click = src.split("def cmd_click(")[1].split("\ndef ")[0]
    assert "ambiguous_name" in click, (
        "cmd_click must refuse a name that resolves to more than one visible "
        "control. Every SelectionButtonRow names its chips SelectBtn_0..N "
        "independently, so SelectBtn_0 is live in the menu row, the biome row "
        "AND the hat row at once."
    )
    assert "clickables" in click, (
        "the ambiguity check must ask the live screen which controls carry the "
        "name, not consult a hardcoded list that will rot"
    )
    assert "--under" in click, "the refusal must tell the caller how to disambiguate"


def test_clickables_asks_whether_anything_listens_for_a_click() -> None:
    """Filtering on `is BaseButton` alone reported ZERO clickables on a screen
    full of them: this game's tabs, chips and rows are Labels made clickable by
    ClickWire.attach(), which connects gui_input."""
    src = LISTENER.read_text(encoding="utf-8")
    assert '"clickables":' in src, "the rig needs the clickables verb"
    verb = src.split('"clickables":')[1].split('\n\t\t"')[0]
    assert "gui_input.get_connections()" in verb, (
        "clickables must count gui_input listeners, or every ClickWire-attached "
        "Label — most of this game's chrome — is invisible to a mouse leg"
    )
    assert "MOUSE_FILTER_IGNORE" in verb, (
        "a control that cannot receive a click must not be listed; listing it "
        "promises a tap that silently does nothing"
    )
    assert "is_visible_in_tree()" in verb, (
        "a player cannot click what isn't on screen"
    )


def test_clickables_reports_where_to_aim() -> None:
    src = LISTENER.read_text(encoding="utf-8")
    verb = src.split('"clickables":')[1].split('\n\t\t"')[0]
    for field in ("center", "parent", "label"):
        assert '"%s"' % field in verb, (
            "clickables must report `%s`: without a centre there is nowhere to "
            "aim, without a parent an ambiguous name cannot be scoped, and "
            "without a label a persona must pick by node name rather than by "
            "what it reads on screen" % field
        )
