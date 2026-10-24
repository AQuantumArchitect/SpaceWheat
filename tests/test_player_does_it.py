"""The game teaches by having the player do the thing, not by doing it for them.

Playtest 2026-10-23:
  * the Millwright lesson is the whole board loop: Accept on the Arc, take a
    contract on the Market (one is guaranteed), deliver it, claim on Charge
  * story beats with an objective are never claimed on Accept
  * the forest lesson explores the whole field first (Shift+F), then the
    Druid and the Operator act on what the player can see
  * F explores, R strikes as often as you like (each strike banks its
    harvest on the plot), Q gathers the bank and returns the plot to fog
  * Reap is Ctrl+Shift+F; Shift+F is mass explore
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def src(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def _steps() -> list:
    d = json.loads(src("Core/Quests/data/tutorial_arc.json"))
    return d.get("steps", d) if isinstance(d, dict) else d


def test_contracts_lesson_is_signed_and_guarantees_its_contract():
    step = next(s for s in _steps() if s.get("tutorial_teaches") == "contracts")
    assert step.get("signed") is True
    lo = step["lesson_offer"]
    assert lo["faction"] == "Millwright's Union" and lo["give"] == {"🌾": 2}
    assert step["state_predicates"][0]["type"] == "contracts_kept_gte"
    board = src("UI/Overlays/QuestBoard.gd")
    assert "_lesson_offers(bname)" in board.split("func _supply_offers")[1].split("\nfunc ")[0]
    guide = src("Core/Campaign/Guide.gd")
    deliver = guide.split("static func _deliver_to(")[1].split("\nstatic func ")[0]
    assert "lesson_offer" in deliver and "home_override" in deliver


def test_beats_with_an_objective_are_not_claimed_on_accept():
    hs = src("Core/Quests/QuestManager.gd").split("func _handshake_auto_claims(")[1].split("\nfunc ")[0]
    assert "story_flags_fired.has(src_flag)" not in hs
    assert "preds.is_empty()" in hs


def test_forest_lessons_survey_the_field_first():
    walks = json.loads(src("Core/Campaign/campaign.json"))["guide"]["walks"]
    for k in ("lesson:superposition", "lesson:entanglement"):
        w = walks[k]
        assert w.index("survey") < next(i for i, s in enumerate(w) if s.startswith("hat:")), k
    guide = src("Core/Campaign/Guide.gd")
    assert '"shift+" + _verb("explore")' in guide.split("static func _survey(")[1].split("\nstatic func ")[0]


def test_strike_banks_and_gather_pays_the_bank():
    term = src("Core/GameMechanics/Terminal.gd")
    assert "func bank_strike(" in term
    assert "return is_measured or has_banked()" in term
    probe = src("Core/Actions/ProbeActions.gd")
    measure = probe.split("static func action_measure(")[1].split("\nstatic func ")[0]
    assert "terminal.bank_strike(" in measure
    assert "_finalize_measurement_terminal(" not in measure, "a strike keeps the probe on the plot"
    pop = probe.split("static func _prepare_pop_result(")[1].split("\nstatic func ")[0]
    assert "_pay_bank(" in pop


def test_reap_is_ctrl_shift_f_and_shift_f_is_mass_explore():
    assert 'REAP_CHORD := "Ctrl+Shift+F"' in src("UI/Core/VerbGrammar.gd")
    qii = src("UI/Core/QuantumInstrumentInput.gd")
    assert "_mass_explore()" in qii and "elif shift and ctrl" in qii
    assert '"ctrl+shift+F"' in src("Core/Campaign/Guide.gd")


def test_free_probe_never_gathers_the_plots_the_step_needs():
    guide = src("Core/Campaign/Guide.gd")
    ft = guide.split("static func _free_terminal(")[1].split("\nstatic func ")[0]
    assert "protect.has(tcol)" in ft
