"""First-season Reap (#91): explore the whole field first; reap gathers every bank.

Static checks (Godot is not required): the refusal, the later-season freedom,
the bank sweep, and the lesson's E text.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROBE = (ROOT / "Core/Actions/ProbeActions.gd").read_text(encoding="utf-8")


def fn(name: str) -> str:
    return PROBE.split("func %s(" % name)[1].split("\nstatic func ")[0]


def test_first_season_refuses_unexplored_field() -> None:
    reap = fn("action_reap")
    gate = reap.split("reap_count_before == 0")[1].split("var reap_cost")[0]
    assert "_unexplored_plots" in gate
    assert "not_all_explored" in gate
    assert "Explore every bubble" in gate
    # refused before any cost is spent, and only when reap_count_before == 0
    assert reap.index("not_all_explored") < reap.index("_commit_cost")


def test_explored_means_bound_or_struck_since() -> None:
    dark = fn("_unexplored_plots")
    assert "is_register_bound" in dark
    assert "get_measured_terminal_for_register" in dark


def test_reap_gathers_every_bank_before_payout() -> None:
    reap = fn("action_reap")
    assert reap.index("_gather_all_banks") < reap.index("_collect_reap_rewards")
    assert "total_gathered" in reap
    sweep = fn("_gather_all_banks")
    assert "get_all_terminals" in sweep
    assert "banked_totals" in sweep
    assert "strikes.clear()" in sweep
    assert "release_terminal" not in sweep  # no state disturbance


def test_reap_lesson_explains_itself() -> None:
    arc = json.loads((ROOT / "Core/Quests/data/tutorial_arc.json").read_text(encoding="utf-8"))
    text = json.dumps(arc, ensure_ascii=False)
    assert "Everything that's explored pays out on its whole state" in text
    assert "explore every bubble before you reap" in text
