"""Variation battery for the first-minute attention qubit.

A proxy, not a player. Each archetype is a different walk through the
intro surfaces. The NEW intro (story face, tap-for-more, Arc postcard)
must dominate the OLD intro (keymap wall, accept-toast, Arc formula)
on story fidelity and machine-leak, for every walk.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from intro_attention_qubit import (  # noqa: E402
    ARCHETYPES,
    NEW,
    OLD,
    compare_all,
    experience,
    spine_tokens,
)

ROOT = Path(__file__).resolve().parents[1]


def test_every_archetype_is_more_story_and_less_machine_on_the_new_intro():
    rows = compare_all()
    # Print a scorecard so a human can read the proxy, not just the asserts.
    print("\n=== intro attention qubit (old → new) ===")
    for row in rows:
        o, n = row["old"], row["new"]
        print(
            "%-12s  story %.2f→%.2f  leak %.2f→%.2f  ready %.2f→%.2f  mix %.2f→%.2f"
            % (
                row["archetype"],
                o["story_fidelity"],
                n["story_fidelity"],
                o["machine_leak"],
                n["machine_leak"],
                o["readiness"],
                n["readiness"],
                o["confusion"],
                n["confusion"],
            )
        )
        print("             %s" % row["note"])
    for row in rows:
        assert row["delta_story"] > 0.05, (
            "%s did not gain story fidelity on the new intro (Δ=%.3f)"
            % (row["archetype"], row["delta_story"])
        )
        assert row["delta_leak"] < -0.05, (
            "%s did not drop machine leak on the new intro (Δ=%.3f)"
            % (row["archetype"], row["delta_leak"])
        )


def test_lost_lamb_and_arc_first_are_held_by_the_postcard():
    """The two walks that land on Arc before the field. If Arc still speaks
    formula, they stay in |01⟩. The postcard has to pull them toward story."""
    for name in ("lost_lamb", "arc_first"):
        old = experience(name, OLD)
        new = experience(name, NEW)
        assert new["story_fidelity"] > 0.55, (
            "%s still isn't reading story after the Arc postcard (%.3f)"
            % (name, new["story_fidelity"])
        )
        assert new["story_fidelity"] > old["story_fidelity"]
        assert new["machine_leak"] < old["machine_leak"]


def test_masher_becomes_ready_once_the_field_is_visible():
    """Masher skips toast and Arc. The welcome glass + banner have to be
    enough to put some amplitude on |10⟩ (act with a story)."""
    new = experience("masher", NEW)
    old = experience("masher", OLD)
    assert new["readiness"] > old["readiness"], (
        "masher readiness did not rise when the field became visible"
    )
    assert new["story_fidelity"] > old["story_fidelity"]


def test_reader_ends_coherent_not_confused():
    """A reader who takes every door should not be mixed. Purity high,
    confusion low — they got one story."""
    new = experience("reader", NEW)
    assert new["purity"] > 0.70, "reader ended mixed (purity %.3f)" % new["purity"]
    assert new["story_fidelity"] > 0.80
    assert new["confusion"] < 0.35


def test_skip_welcome_still_has_a_spine():
    """Rig / returning player: no splash. Toast + banner must still agree
    and not dump them into engine dialect."""
    new = experience("skip_welcome", NEW)
    assert new["story_fidelity"] > 0.70
    assert new["machine_leak"] < 0.35


def test_all_seven_walks_are_named():
    assert set(ARCHETYPES) == {
        "reader",
        "masher",
        "lost_lamb",
        "mouse",
        "keyboard",
        "skip_welcome",
        "arc_first",
    }


def test_spine_tokens_agree_on_strike_as_the_first_ask():
    """The proxy's live-ask and the shipping copy have to name the same
    first verb. Source lint — IntroVoice + tutorial_arc + UIProgression
    — is the compiler for this claim; the qubit only records the intent."""
    tokens = spine_tokens()
    assert tokens["toast_live_ask"] == tokens["banner_live_ask"] == tokens["arc_featured"]
    assert tokens["toast_live_ask"] == "strike"
    assert tokens["first_harvest_role"] == "capstone"

    intro = (ROOT / "Core" / "Story" / "IntroVoice.gd").read_text(encoding="utf-8")
    assert '"core_loop"' in intro and 'return "strike"' in intro
    assert "The Demos sleeps" in intro

    overlay = (ROOT / "UI" / "Overlays" / "ControlsOverlay.gd").read_text(encoding="utf-8")
    assert "live_tutorial" in overlay, "Arc must feature the live tutorial as the NOW door"
    assert "soft_gate" not in overlay.split("func _make_arc_row")[1].split("func _make_arc_chapter_header")[0], (
        "Arc face (_make_arc_row) leaked a formula onto the postcard"
    )
