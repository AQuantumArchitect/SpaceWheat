"""A save made while a signed tutorial step waits on the Arc keeps the lane.

Offers are session state (QuestManager.to_save_dict omits story_offers), so a
save banked at "Arc [Y] → The Loom → Accept [R]" reloaded with no active step
and no offer, and tutorial_seen blocked maybe_start_tutorial: the Loom and Reap
never came back (2026-11-09, reproduced from a strict-follower checkpoint).
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
QM = (ROOT / "Core/Quests/QuestManager.gd").read_text(encoding="utf-8")


def _body(name):
    return QM.split("func %s(" % name)[1].split("\nfunc ")[0]


def test_connect_to_farm_heals_the_tutorial_lane():
    assert "_heal_tutorial_lane(farm)" in _body("connect_to_farm")


def test_heal_reoffers_the_step_after_the_highest_completed():
    h = _body("_heal_tutorial_lane")
    assert 'has("tutorial_seen")' in h
    assert "active_quests.values()" in h and "story_offers.values()" in h
    assert "top + 1" in h and "offer_tutorial_quest(step)" in h
