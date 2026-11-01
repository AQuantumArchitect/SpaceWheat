"""A beat other beats require cannot be dismissed, and the guide never goes
silent on a beat it has no step for.

Found by 🍄/🧪/perturbed_walk.py: one stray Dismiss on "The Teaching"
(lumber_flows) discarded the beat that teaches 🪵/🪓; its child woodlot_wakes
then asked the player to plant a word they never learned, the guide had no
step, and the banner fell back to a stale "[C] then [R] Claim".
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def test_a_gate_cannot_be_dismissed():
    qm = src("Core/Quests/QuestManager.gd")
    dismiss = qm.split("func dismiss_story_offer")[1].split("\nfunc ")[0]
    assert "_flag_is_on_the_road(flag_id)" in dismiss
    assert "return false" in dismiss.split("_flag_is_on_the_road(flag_id)")[1].split("guidance_dismissed")[0]
    assert "Guide.gate_flags(self)" in qm.split("func _flag_is_on_the_road")[1].split("\nfunc ")[0]
    # an old dismissal of a gate no longer counts, and its offer is not swept
    assert "_flag_is_on_the_road(flag_id)" in qm.split("func is_guidance_dismissed")[1].split("\nfunc ")[0]
    assert "_flag_is_on_the_road(src)" in qm.split("func _arc_offer_is_spent")[1].split("\nfunc ")[0]


def test_the_guide_walks_down_its_ranked_beats():
    g = src("Core/Campaign/Guide.gd")
    nxt = g.split("static func next_step()")[1].split("\nstatic func ")[0]
    assert "ranked_beats()" in nxt and "for q in ranked" in nxt
    assert "static func ranked_beats(" in g
    live = g.split("static func live_beat(")[1].split("\nstatic func ")[0]
    assert "ranked_beats(qm)" in live


def test_the_charge_tab_is_live():
    c = src("UI/Overlays/ControlsOverlay.gd")
    assert "func _tick_charge_live" in c
    assert "_tick_charge_live(delta)" in c.split("func _process(")[1].split("\nfunc ")[0]
    assert "_render_all()" in c.split("func _on_activated")[1].split("\nfunc ")[0]
